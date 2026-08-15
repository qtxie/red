Red [
	Title: "Red/System ABI type layout"
	File:  %compiler/system-layout.red
]

compiler-system-layout: context [
	target: compiler-system-target-model
	datatypes: none
	compiler-mode?: false

	types-model: [
		int8! 1 signed
		byte! 1 unsigned
		uint8! 1 unsigned
		int16! 2 signed
		uint16! 2 unsigned
		int32! 4 signed
		integer! 4 signed
		uint32! 4 unsigned
		int64! 8 signed
		uint64! 8 unsigned
		float32! 4 signed
		float64! 8 signed
		float! 8 signed
		logic! 4 -
		pointer! 4 -
		c-string! 4 -
		struct! 4 -
		union! 4 -
		function! 4 -
		subroutine! 4 -
		array! 4 -
	]

	datatype-ID: [
		logic! 1 integer! 2 int32! 2 byte! 3
		int8! 13 uint8! 14 int16! 15 uint16! 16 uint32! 17
		int64! 11 uint64! 12 float32! 4 float! 5 float64! 5
		c-string! 6 byte-ptr! 7 int-ptr! 8 function! 9 ptr-ptr! 10
		struct! 1000 union! 1001
	]

	connect: func [target-service [object!] /compiler /local model pos type][
		target: target-service
		compiler-mode?: to logic! compiler
		model: copy types-model
		foreach type [
			pointer! c-string! struct! union!
			function! subroutine! array!
		][
			if pos: find model type [pos/2: target/ptr-size]
		]
		datatypes: to hash! model
		self
	]

	find-aliased: func [name [word!]][
		either compiler-mode? [
			system-dialect/compiler/find-aliased name
		][compiler-system-types/find-aliased name]
	]

	integer-kind: func [type [word! block!]][
		either compiler-mode? [
			system-dialect/compiler/integer-kind type
		][compiler-system-types/integer-kind type]
	]

	union-spec?: func [spec [block!]][
		either compiler-mode? [
			system-dialect/compiler/union-spec? spec
		][compiler-system-types/union-spec? spec]
	]

	tagged-union?: func [spec [block!]][
		either compiler-mode? [
			system-dialect/compiler/tagged-union? spec
		][compiler-system-types/tagged-union? spec]
	]

	union-members: func [spec [block!]][
		either compiler-mode? [
			system-dialect/compiler/union-members spec
		][compiler-system-types/union-members spec]
	]

	union-variant-type?: func [spec [block!] name [word!]][
		either compiler-mode? [
			system-dialect/compiler/union-variant-type? spec name
		][compiler-system-types/union-variant-type? spec name]
	]

	resolve-aliased: func [type [block!] /silent][
		either compiler-mode? [
			either silent [
				system-dialect/compiler/resolve-aliased/silent type
			][system-dialect/compiler/resolve-aliased type]
		][
			either silent [
				compiler-system-types/resolve-aliased/silent type
			][compiler-system-types/resolve-aliased type]
		]
	]

	enumeration?: func [name [word!]][
		to logic! either compiler-mode? [
			find system-dialect/compiler/enumerations name
		][find compiler-system-types/enumerations name]
	]

	return-definition: does [
		either compiler-mode? [system-dialect/compiler/return-def][to set-word! 'return]
	]

	throw-error: func [message [string! block!]][
		either compiler-mode? [
			system-dialect/compiler/throw-error message
		][compiler-system-types/throw-error message]
	]

	base-type?: func [value][
		if block? value [value: value/1]
		to logic! find/skip datatypes value 3
	]

	align-offset?: func [offset [integer!] alignment [integer!] /local over][
		either zero? over: offset // alignment [
			offset
		][
			offset + alignment - over
		]
	]

	type-align?: func [type [word! block!] /local base alias kind][
		if block? type [
			if all [
				'value = last type
				alias: find-aliased type/1
			][
				if find [struct! union!] alias/1 [return aggregate-align? alias/2]
				type: alias
			]
			base: type/1
		]
		if word? type [base: type]
		if kind: integer-kind type [base: kind]
		case [
			find [int8! uint8! byte!] base [1]
			find [int16! uint16!] base [2]
			find [integer! int32! uint32! float32! logic!] base [4]
			find [int64! uint64! float! float64!] base [
				either target/ptr-size = 4 [4][8]
			]
			find [c-string! pointer! struct! union! function! subroutine! array!] base [
				target/ptr-size
			]
			true [target/struct-align-size]
		]
	]

	aggregate-align?: func [spec [block!] /local alignment member-alignment name type][
		if (union-spec? spec) [return union-payload-align? spec]
		alignment: 1
		foreach [name type] spec [
			member-alignment: type-align? type
			if member-alignment > alignment [alignment: member-alignment]
		]
		either target/ptr-size = 4 [
			max alignment target/struct-align-size
		][
			alignment
		]
	]

	union-payload-align?: func [spec [block!] /local alignment member-alignment name type][
		alignment: 1
		foreach [name type] (union-members spec) [
			member-alignment: type-align? type
			if member-alignment > alignment [alignment: member-alignment]
		]
		alignment
	]

	union-payload-offset?: func [spec [block!] /local tag-size][
		either (tagged-union? spec) [
			tag-size: size-of? spec/2
			align-offset? tag-size union-payload-align? spec
		][
			0
		]
	]

	union-size?: func [
		spec [block!]
		/local size alignment member-size member-alignment total name type
	][
		size: 0
		alignment: 1
		foreach [name type] (union-members spec) [
			member-size: size-of? type
			unless member-size [
				throw-error reduce ["invalid union member type:" mold type]
			]
			member-alignment: type-align? type
			if member-size > size [size: member-size]
			if member-alignment > alignment [alignment: member-alignment]
		]
		total: size + union-payload-offset? spec
		align-offset? total alignment
	]

	union-member-offset?: func [spec [block!] name [word! none!] /local type][
		either none? name [
			union-size? spec
		][
			type: union-variant-type? spec name
			unless type [
				throw-error reduce ["invalid union member" to lit-word! name]
			]
			union-payload-offset? spec
		]
	]

	member-offset?: func [
		spec [block!]
		name [word! none!]
		/local offset alignment field type
	][
		if (union-spec? spec) [return union-member-offset? spec name]
		offset: 0
		foreach [field type] spec [
			alignment: type-align? type
			offset: align-offset? offset alignment
			if field = name [return offset]
			offset: offset + size-of? type
		]
		align-offset? offset aggregate-align? spec
	]

	size-of?: func [type [word! block!] /local alias base][
		if block? type [
			if (union-spec? type) [return union-size? type]
			if 'value = last type [
				base: type/1
				alias: all [word? base find-aliased base]
				if alias [type: alias]
				if find [struct! union!] type/1 [
					return either type/1 = 'union! [
						union-size? type/2
					][
						member-offset? type/2 none
					]
				]
			]
			type: type/1
		]
		unless word? type [return none]
		any [
			select datatypes type
			all [enumeration? type select datatypes 'integer!]
			all [
				alias: find-aliased type
				select datatypes alias/1
			]
		]
	]

	get-size: func [type [block! word!] value][
		case [
			word? type [select datatypes type]
			'array! = first head type [second head type]
			type/1 = 'c-string! [reduce ['+ 1 reduce ['length? value]]]
			type/1 = 'struct! [member-offset? type/2 none]
			type/1 = 'union! [union-size? type/2]
			true [select datatypes type/1]
		]
	]

	signed?: func [type [word! block!]][
		if block? type [type: type/1]
		'signed = third any [find datatypes type [- - -]]
	]

	struct-slots?: func [spec [block!] /direct /check /local size][
		if check [
			unless all [
				spec: select spec return-definition
				'value = last :spec
			][return none]
		]
		unless direct [
			if not find [struct! union!] spec/1 [
				spec: find-aliased spec/1
				if not find [struct! union!] spec/1 [return none]
			]
			spec: spec/2
		]
		size: either (union-spec? spec) [
			union-size? spec
		][
			member-offset? spec none
		]
		to integer! round/ceiling (size / target/stack-width)
	]

	struct-size?: func [spec [block!] /direct /check][
		if check [
			unless all [
				spec: select spec return-definition
				'value = last :spec
			][return none]
		]
		unless direct [
			if not find [struct! union!] spec/1 [
				spec: find-aliased spec/1
				if not find [struct! union!] spec/1 [return none]
			]
			spec: spec/2
		]
		either (union-spec? spec) [union-size? spec][member-offset? spec none]
	]

	type-has-pointer?: func [type [block!] /local resolved][
		resolved: resolve-aliased type
		case [
			find [pointer! c-string! function!] resolved/1 [true]
			all [resolved/1 = 'struct! 'value <> last resolved] [true]
			all [resolved/1 = 'union! 'value <> last resolved] [true]
			all [resolved/1 = 'struct! 'value = last resolved] [
				struct-has-pointer? resolved/2
			]
			all [resolved/1 = 'union! 'value = last resolved] [
				union-has-pointer? resolved/2
			]
			true [false]
		]
	]

	struct-has-pointer?: func [spec [block!] /local found? name type][
		found?: false
		if block? spec/1 [spec: next spec]
		foreach [name type] spec [
			if type-has-pointer? type [found?: true break]
		]
		found?
	]

	union-has-pointer?: func [spec [block!] /local found? name type][
		found?: false
		foreach [name type] (union-members spec) [
			if type-has-pointer? type [found?: true break]
		]
		found?
	]
]
