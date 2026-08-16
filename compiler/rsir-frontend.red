Red [
	Title: "Compact Red/System IR frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]

compiler-rsir-frontend: context [
	DEFAULT-MAX-BYTES: 16777216

	ERROR-ARGUMENTS: 1
	ERROR-KIND: 2
	ERROR-LIMIT: 3
	ERROR-NAME: 4
	ERROR-FUNCTION-COUNT: 5
	ERROR-UNSUPPORTED: 6
	ERROR-DUPLICATE: 7
	ERROR-REFERENCE: 8
	ERROR-CONTEXT: 9

	last-error: none
	module-kind: 0
	functions: make block! 96
	function-ids: make hash! 48
	contexts: make hash! 32
	types: make block! 256
	type-ids: make hash! 128
	pointer-types: make hash! 64
	constants: make hash! 256
	imports: make block! 256
	import-ids: make hash! 256
	libraries: make hash! 32
	globals: make hash! 1024
	global-data: make block! 1024
	module-code: make binary! 256
	function-code: make binary! 2048
	strings: make binary! 256
	string-ids: make hash! 128
	function-count: 0
	type-count: 0
	import-count: 0
	global-count: 0

	type-kinds: make hash! [
		int8! i8 byte! u8 uint8! u8 int16! i16 uint16! u16
		integer! i32 int32! i32 uint32! u32 int64! i64 uint64! u64
		float32! f32 float! f64 float64! f64 logic! logic
		pointer! pointer c-string! c-string struct! pointer union! pointer
		function! pointer subroutine! pointer array! pointer
		byte-ptr! pointer int-ptr! pointer ptr-ptr! pointer
		float32-ptr! pointer
	]

	type-codes: make hash! [
		i8 1 u8 2 i16 3 u16 4 i32 5 u32 6 i64 7 u64 8
		f32 9 f64 10 logic 11 pointer 12 c-string 13
		alias -1 struct -2 union -3 function -4 subroutine -5
		pointer-node -6
	]
	builtin-pointees: make hash! [
		byte-ptr! [byte!]
		int-ptr! [integer!]
		ptr-ptr! [pointer!]
		float32-ptr! [float32!]
	]

	return-value-flag: 4
	variadic-flag: 8
	typed-flag: 16
	custom-flag: 32
	callback-flag: 64
	objc-flag: 128
	catch-flag: 256

	; Semantic postfix operations. Operands are typed by the surrounding
	; declaration tables; no source-specific value IDs cross the boundary.
	literal-op: 1
	constant-op: 2
	address-op: 3
	load-op: 4
	set-op: 5
	member-op: 6
	call-op: 7
	cast-op: 8
	size-op: 9
	native-op: 10
	return-op: 11
	drop-op: 12
	duplicate-op: 13
	unary-op: 14
	binary-op: 15

	; Operation IDs follow the language families, not source spellings or x64
	; encodings. The postfix stream preserves the specified left-to-right order.
	not-operation: 1
	binary-operations: make hash! [
		+   1  -   2  *   3  /   4  %   5  //  6
		<<  7  >>  8  >>> 9  or 10  xor 11  and 12
		=  13  <> 14  >  15  <  16  >= 17  <= 18
	]

	local-address: 1
	global-address: 2
	import-address: 3
	function-address: 4

	stack-top-native: 1

	last-type: 0
	last-flags: 0
	static?: false
	static-ref: 0
	static-low: 0
	static-high: 0
	static-next: none

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
	]

	fail: func [code [integer!] message [string! block!] /local error][
		error: make object! [code: 0 message: none]
		error/code: code
		error/message: form either block? message [reduce message][message]
		last-error: error
		throw/name error 'rsir-error
	]

	valid-name?: func [name [string!]][
		all [not empty? name not find to binary! name 0]
	]

	qualified: func [scope [block!] value [word! path!] /local output item][
		output: make string! 48
		foreach item scope [
			unless empty? output [append output ">"]
			append output form item
		]
		foreach item either path? value [to block! value][reduce [value]][
			unless empty? output [append output ">"]
			append output form item
		]
		to word! output
	]

	extend-scope: func [scope [block!] value [word! path!] /local output item][
		output: copy scope
		foreach item either path? value [to block! value][reduce [value]][
			append output item
		]
		output
	]

	resolve-name: func [
		value [word! path!]
		scope uses [block!]
		names [hash!]
		/local depth key id imported
	][
		if path? value [
			if id: select names qualified copy [] value [return id]
			depth: length? scope
			while [depth > 0][
				key: qualified copy/part scope depth value
				if id: select names key [return id]
				depth: depth - 1
			]
			foreach imported uses [
				key: qualified imported value
				if id: select names key [return id]
			]
			return none
		]
		depth: length? scope
		while [depth >= 0][
			key: qualified copy/part scope depth value
			if id: select names key [return id]
			depth: depth - 1
		]
		foreach imported uses [
			key: qualified imported value
			if id: select names key [return id]
		]
		none
	]

	import-variable-id: func [
		value [word! path!]
		scope uses [block!]
		/local id record
	][
		unless id: resolve-name value scope uses import-ids [return none]
		record: skip imports ((id - 1) * 10)
		either record/5 = 'variable [id][none]
	]

	resolve-context: func [
		value [word! path!]
		scope uses [block!]
		/local depth key imported
	][
		if path? value [
			key: qualified copy [] value
			if select contexts key [return extend-scope copy [] value]
			depth: length? scope
			while [depth > 0][
				key: qualified copy/part scope depth value
				if select contexts key [
					return extend-scope copy/part scope depth value
				]
				depth: depth - 1
			]
			foreach imported uses [
				key: qualified imported value
				if select contexts key [return extend-scope imported value]
			]
			return none
		]
		depth: length? scope
		while [depth >= 0][
			key: qualified copy/part scope depth value
			if select contexts key [
				return extend-scope copy/part scope depth value
			]
			depth: depth - 1
		]
		foreach imported uses [
			key: qualified imported value
			if select contexts key [return extend-scope imported value]
		]
		none
	]

	intern-pointer: func [pointee [integer!] /local id kind][
		kind: ref-kind pointee
		unless find [i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 pointer] kind [
			fail ERROR-UNSUPPORTED "pointer pointee type is unsupported"
		]
		if id: select pointer-types pointee [return id]
		id: type-count + 1
		repend pointer-types [pointee id]
		append types none
		append types 'pointer
		append types pointee
		append/only types copy []
		append/only types copy []
		type-count: id
		id
	]

	type-kind: func [
		type [block!]
		scope uses [block!]
		/local name kind id record steps target
	][
		unless all [not empty? type any [word? type/1 path? type/1]][return none]
		name: type/1
		kind: all [word? name select type-kinds name]
		unless kind [
			unless id: resolve-name name scope uses type-ids [return none]
			steps: 0
			forever [
				steps: steps + 1
				if steps > type-count [fail ERROR-REFERENCE "cyclic type alias"]
				record: skip types ((id - 1) * 5)
				kind: record/2
				if kind <> 'alias [break]
				target: record/3
				if block? target [
					kind: type-kind target record/4 record/5
					break
				]
				name: target
				if all [word? name kind: select type-kinds name][break]
				unless id: resolve-name name record/4 record/5 type-ids [return none]
			]
		]
		case [
			find [struct union] kind [
				case [
					(length? type) = 1 ['pointer]
					all [(length? type) = 2 type/2 = 'value][kind]
					true [none]
				]
			]
			find [function subroutine] kind [
				either (length? type) = 1 ['pointer][none]
			]
			kind = 'pointer [
				case [
					(length? type) = 1 [kind]
					all [(length? type) = 2 block? type/2][kind]
					true [none]
				]
			]
			(length? type) = 1 [kind]
			true [none]
		]
	]

	type-ref: func [
		type [block!]
		scope uses [block!]
		/local name kind code id pointee
	][
		unless all [not empty? type any [word? type/1 path? type/1]][
			fail ERROR-UNSUPPORTED "invalid type reference"
		]
		name: type/1
		kind: type-kind type scope uses
		unless kind [fail ERROR-UNSUPPORTED ["unsupported type " mold type]]
		if all [word? name pointee: select builtin-pointees name][
			return intern-pointer type-ref pointee scope uses
		]
		if all [word? name name = 'pointer! (length? type) = 2][
			return intern-pointer type-ref type/2 scope uses
		]
		if all [
			word? name
			select type-kinds name
			code: select type-codes kind
		][return negate code]
		unless id: resolve-name name scope uses type-ids [
			fail ERROR-REFERENCE ["unknown type " mold name]
		]
		id
	]

	type-flags: func [type [block!] scope uses [block!] /local kind][
		either all [(length? type) = 2 type/2 = 'value][
			unless find [struct union] kind: type-kind type scope uses [
				fail ERROR-UNSUPPORTED "only aggregate types can be passed by value"
			]
			1
		][0]
	]

	ref-kind: func [ref [integer!] /local record kind name steps target][
		if ref < 0 [
			if ref < -13 [return none]
			return pick [i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string]
				negate ref
		]
		if any [ref = 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			if ref > type-count [return none]
			record: skip types ((ref - 1) * 5)
			kind: record/2
			unless kind = 'alias [return kind]
			target: record/3
			if block? target [return type-kind target record/4 record/5]
			name: target
			if all [word? name kind: select type-kinds name][
				return kind
			]
			unless ref: resolve-name name record/4 record/5 type-ids [return none]
			steps: steps + 1
		]
		none
	]

	canonical-ref: func [ref [integer!] /local record target steps][
		if ref <= 0 [return ref]
		steps: 0
		while [steps < type-count][
			if ref > type-count [return 0]
			record: skip types ((ref - 1) * 5)
			unless record/2 = 'alias [return ref]
			target: record/3
			target: either block? target [target][reduce [target]]
			ref: type-ref target record/4 record/5
			if ref <= 0 [return ref]
			steps: steps + 1
		]
		fail ERROR-REFERENCE "cyclic type alias"
	]

	member-info: func [
		ref [integer!]
		name [word!]
		/local record kind target spec index steps
	][
		if any [ref <= 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			record: skip types ((ref - 1) * 5)
			kind: record/2
			if kind = 'alias [
				target: record/3
				if block? target [
					ref: type-ref target record/4 record/5
					if ref <= 0 [return none]
				]
				if not block? target [
					if all [word? target select type-kinds target][return none]
					unless ref: resolve-name target record/4 record/5 type-ids [return none]
				]
				steps: steps + 1
				continue
			]
			unless find [struct union] kind [return none]
			spec: record/3
			index: 0
			while [not tail? spec][
				if spec/1 = name [
					return reduce [
						index
						type-ref spec/2 record/4 record/5
						type-flags spec/2 record/4 record/5
					]
				]
				index: index + 1
				spec: skip spec 2
			]
			return none
		]
		none
	]

	add-system-type: func [scope uses [block!] /local key id][
		if id: resolve-name 'system! scope uses type-ids [return id]
		key: to word! "system!"
		id: type-count + 1
		repend type-ids [key id]
		append types key
		append types 'struct
		append/only types [
			args-count [integer!]
			args-list [byte-ptr!]
			env-vars [byte-ptr!]
			stack [byte-ptr!]
			pc [byte-ptr!]
			cpu [byte-ptr!]
			fpu [byte-ptr!]
			alias [integer!]
			words [integer!]
			thrown [integer!]
			boot-data [byte-ptr!]
		]
		append/only types copy []
		append/only types copy []
		type-count: id
		id
	]

	add-system-import: func [
		library [binary!]
		scope uses [block!]
		/local key external ref id
	][
		key: to word! "system"
		if any [
			select import-ids key
			select function-ids key
			select globals key
		][fail ERROR-DUPLICATE "system is already declared"]
		external: to binary! "system"
		ref: add-system-type scope uses
		id: import-count + 1
		repend import-ids [key id]
		append imports key
		append/only imports library
		append/only imports external
		append/only imports [system!]
		append imports 'variable
		append/only imports scope
		append/only imports uses
		append imports ref
		append imports none
		append imports 0
		import-count: id
		id
	]

	signature-flags: func [attributes [block!] /local flags convention item bit][
		if (length? attributes) > 2 [
			fail ERROR-UNSUPPORTED "too many function attributes"
		]
		if all [
			(length? attributes) = 2
			attributes/1 = attributes/2
		][fail ERROR-UNSUPPORTED "duplicate function attribute"]
		flags: 0
		convention: 0
		foreach item attributes [
			unless word? item [fail ERROR-UNSUPPORTED "invalid function attribute"]
			bit: 0
			case [
				item = 'cdecl [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 1
				]
				item = 'stdcall [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 2
				]
				item = 'variadic [bit: variadic-flag]
				item = 'typed [bit: typed-flag]
				item = 'custom [bit: custom-flag]
				item = 'callback [bit: callback-flag]
				item = 'objc [bit: objc-flag]
				item = 'catch [bit: catch-flag]
				item = 'infix []
				item = 'red-internal []
				true [fail ERROR-UNSUPPORTED ["unknown function attribute " mold item]]
			]
			if all [
				bit >= variadic-flag
				bit <= custom-flag
				(flags and (variadic-flag + typed-flag + custom-flag)) <> 0
			][fail ERROR-UNSUPPORTED "conflicting variable-arity attributes"]
			flags: flags + bit
		]
		flags + convention
	]

	read-signature: func [
		spec scope uses [block!]
		/local position names-start names-end item name type params locals names flags
			ref type-flags-value
			return-ref value? locals?
	][
		position: spec
		if all [not tail? position string? position/1][position: next position]
		flags: 0
		if all [not tail? position block? position/1][
			flags: signature-flags position/1
			position: next position
		]
		if all [not tail? position string? position/1][position: next position]
		if all [not tail? position position/1 = 'red-internal][position: next position]

		params: make block! 12
		locals: make block! 12
		names: make hash! 16
		return-ref: 0
		value?: false
		locals?: false
		while [not tail? position][
			item: position/1
			case [
				refinement? item [
					unless all [item = /local not locals?][
						fail ERROR-UNSUPPORTED "function refinement is unsupported"
					]
					locals?: true
					position: next position
				]
				all [set-word? item not locals?][
					unless all [
						item = to set-word! 'return
						not value?
						(length? position) >= 2
						block? position/2
					][fail ERROR-UNSUPPORTED "invalid function return type"]
					type: position/2
					return-ref: type-ref type scope uses
					if (type-flags type scope uses) = 1 [
						flags: flags + return-value-flag
					]
					value?: true
					position: skip position 2
					if all [not tail? position string? position/1][position: next position]
				]
				word? item [
					if all [value? not locals?][
						fail ERROR-UNSUPPORTED "function parameter follows its return type"
					]
					names-start: position
					while [all [not tail? position word? position/1]][
						name: position/1
						if select names name [
							fail ERROR-UNSUPPORTED "duplicate function variable"
						]
						repend names [name true]
						position: next position
					]
					names-end: position
					either locals? [
						ref: 0
						type-flags-value: 0
						if all [not tail? position block? position/1][
							ref: type-ref position/1 scope uses
							type-flags-value: type-flags position/1 scope uses
							position: next position
						]
						while [names-start <> names-end][
							repend locals [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
					][
						unless all [not tail? position block? position/1][
							fail ERROR-UNSUPPORTED "function parameter is missing its type"
						]
						type: position/1
						ref: type-ref type scope uses
						type-flags-value: type-flags type scope uses
						while [names-start <> position][
							repend params [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
						position: next position
					]
					if all [not tail? position string? position/1][position: next position]
				]
				true [fail ERROR-UNSUPPORTED "function signature is unsupported"]
			]
		]
		reduce [return-ref params locals flags]
	]

	prepare-functions: func [/local record signature][
		record: functions
		while [not tail? record][
			signature: read-signature record/2 record/4 record/5
			record/6: signature/1
			record/7: signature/2
			record/8: signature/3
			record/9: signature/4
			record: skip record 10
		]
	]

	prepare-imports: func [/local record signature cc][
		record: imports
		while [not tail? record][
			cc: record/8
			either record/5 = 'function [
				signature: read-signature record/4 record/6 record/7
				unless empty? signature/3 [
					fail ERROR-UNSUPPORTED "import signature cannot declare locals"
				]
				if (signature/4 and 3) <> 0 [
					fail ERROR-UNSUPPORTED
						"import calling convention is specified twice"
				]
				record/8: signature/1
				record/9: signature/2
				record/10: signature/4 + either cc = 'cdecl [1][2]
			][
				record/8: type-ref record/4 record/6 record/7
				record/9: none
				record/10: 0
			]
			record: skip record 10
		]
	]

	add-module-function: func [/local key][
		key: to word! "***-main"
		if any [
			select function-ids key
			select import-ids key
			select globals key
		][fail ERROR-DUPLICATE "***-main is reserved for the module body"]
		append/only functions to binary! "***-main"
		append/only functions copy []
		append/only functions module-code
		append/only functions copy []
		append/only functions copy []
		append functions 0
		append/only functions copy []
		append/only functions copy []
		append functions 0
		append functions 0
		function-count: function-count + 1
	]

	lower-functions: func [/local record body count][
		clear function-code
		record: functions
		while [not tail? record][
			body: record/3
			count: either binary? body [
				unless ((length? body) // 16) = 0 [
					fail ERROR-UNSUPPORTED "invalid module instruction stream"
				]
				append function-code body
				(length? body) / 16
			][
				stack-body record/6 body record/4 record/5 function-code
					record/7 record/8 record/9
			]
			record/10: count
			record: skip record 10
		]
	]

	scan-enum: func [
		name [word!]
		values scope [block!]
		/local key position item value constant-key id
	][
		key: qualified scope name
		if select type-ids key [fail ERROR-DUPLICATE ["duplicate type " mold key]]
		id: type-count + 1
		repend type-ids [key id]
		append types key
		append types 'i32
		append/only types values
		append/only types copy scope
		append/only types copy []
		type-count: id
		value: 0
		position: values
		while [not tail? position][
			item: position/1
			case [
				word? item [position: next position]
				all [set-word? item (length? position) >= 2][
					item: to word! item
					case [
						integer? position/2 [value: position/2]
						word? position/2 [
							constant-key: qualified scope position/2
							unless integer? value: select constants constant-key [
								fail ERROR-REFERENCE [
									"unknown enum value " mold position/2
								]
							]
						]
						true [fail ERROR-UNSUPPORTED "invalid enum value"]
					]
					position: skip position 2
				]
				true [fail ERROR-UNSUPPORTED "invalid enum declaration"]
			]
			constant-key: qualified scope item
			if select constants constant-key [
				fail ERROR-DUPLICATE ["duplicate enum name " mold constant-key]
			]
			repend constants [constant-key value]
			value: value + 1
		]
	]

	scan-imports: func [
		definitions scope uses [block!]
		/local position library canonical cc entries entry name key external spec kind id
	][
		if empty? definitions [fail ERROR-UNSUPPORTED "import block is empty"]
		position: definitions
		while [not tail? position][
			unless all [
				(length? position) >= 3
				string? position/1
				find [cdecl stdcall] position/2
				block? position/3
			][fail ERROR-UNSUPPORTED "invalid import group"]
			unless valid-name? position/1 [
				fail ERROR-NAME "invalid import library name"
			]
			library: to binary! position/1
			either canonical: select libraries library [
				library: canonical
			][repend libraries [library library]]
			cc: position/2
			entries: position/3
			if empty? entries [
				fail ERROR-UNSUPPORTED "empty import group is unsupported"
			]
			entry: entries
			while [not tail? entry][
				unless all [
					(length? entry) >= 3
					set-word? entry/1
					string? entry/2
					block? entry/3
				][fail ERROR-UNSUPPORTED "invalid import declaration"]
				name: to word! entry/1
				key: qualified scope name
				if any [
					select import-ids key
					select function-ids key
					select globals key
				][
					fail ERROR-DUPLICATE ["duplicate import " mold key]
				]
				unless valid-name? entry/2 [
					fail ERROR-NAME "invalid external import name"
				]
				external: to binary! entry/2
				spec: entry/3
				kind: either any [
					all [(length? spec) = 1 not block? spec/1]
					all [
						(length? spec) = 2
						find [pointer! struct!] spec/1
						block? spec/2
					]
				]['variable]['function]
				id: import-count + 1
				repend import-ids [key id]
				append imports key
				append/only imports library
				append/only imports external
				append/only imports spec
				append imports kind
				append/only imports scope
				append/only imports uses
				append imports cc
				append imports none
				append imports none
				import-count: id
				entry: skip entry 3
			]
			position: skip position 3
		]
	]

	scan-block: func [
		values scope uses [block!]
		/local position name spec body child key kind target next-uses
			spelling id type-spec
	][
		position: values
		while [not tail? position][
			case [
				all [
					position/1 = 'comment
					(length? position) >= 2
				][position: skip position 2]
				all [
					issue? position/1
					position/1 = #script
					(length? position) >= 2
					file? position/2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					position: next position
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
					word? position/2
					block? position/3
				][
					scan-enum position/2 position/3 scope
					position: skip position 3
				]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
					block? position/2
				][
					scan-imports position/2 scope uses
					position: skip position 2
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][
					key: qualified scope to word! position/1
					if select type-ids key [
						fail ERROR-DUPLICATE ["duplicate alias " mold key]
					]
					case [
						position/3 = 'pointer! [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "pointer alias is missing its pointee"]
							kind: 'alias
							type-spec: reduce [position/3 position/4]
							position: skip position 4
						]
						find [struct! union! function! subroutine!] position/3 [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "alias type is missing its spec"]
							kind: case [
								position/3 = 'struct! ['struct]
								position/3 = 'union! ['union]
								position/3 = 'function! ['function]
								true ['subroutine]
							]
							type-spec: position/4
							position: skip position 4
						]
						any [word? position/3 path? position/3][
							kind: 'alias
							type-spec: position/3
							position: skip position 3
						]
						true [fail ERROR-UNSUPPORTED "invalid alias declaration"]
					]
					id: type-count + 1
					repend type-ids [key id]
					append types key
					append types kind
					append/only types type-spec
					append/only types copy scope
					append/only types copy/deep uses
					type-count: id
				]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][
					name: position/1
					spec: position/3
					body: position/4
					key: qualified scope to word! name
					spelling: form key
					unless valid-name? spelling [
						fail ERROR-NAME "invalid RSIR function name"
					]
					if any [
						select function-ids key
						select import-ids key
						select globals key
					][
						fail ERROR-DUPLICATE ["duplicate function " mold key]
					]
					id: function-count + 1
					repend function-ids [key id]
					append/only functions to binary! spelling
					append/only functions spec
					append/only functions body
					append/only functions copy scope
					append/only functions copy/deep uses
					append functions none
					append functions none
					append functions none
					append functions none
					append functions none
					function-count: id
					position: skip position 4
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					name: to word! position/1
					key: qualified scope name
					if select contexts key [
						fail ERROR-DUPLICATE ["duplicate context " mold key]
					]
					repend contexts [key true]
					child: append copy scope name
					scan-block position/3 child uses
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2]
					block? position/3
				][
					target: position/2
					unless child: resolve-context target scope uses [
						fail ERROR-CONTEXT ["unknown context " mold target]
					]
					next-uses: copy/deep uses
					append/only next-uses child
					scan-block position/3 scope next-uses
					position: skip position 3
				]
				set-word? position/1 [
					name: to word! position/1
					key: qualified scope name
					unless any [
						import-variable-id name scope uses
						resolve-name name scope uses globals
					][
						if any [select function-ids key select import-ids key][
							fail ERROR-DUPLICATE ["duplicate global " mold key]
						]
						global-count: global-count + 1
						repend globals [key global-count]
						spelling: form key
						unless valid-name? spelling [
							fail ERROR-NAME "invalid RSIR global name"
						]
						append/only global-data to binary! spelling
						append global-data none
						append global-data 0
						append global-data 0
					]
					position: next position
				]
				true [position: next position]
			]
		]
	]

	compile-source: func [source [block!] /local header][
		unless all [not tail? source source/1 = 'Red/System] [
			fail ERROR-ARGUMENTS "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2] [
			fail ERROR-ARGUMENTS "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]] [
			fail ERROR-ARGUMENTS "invalid Red/System program header"
		]

		scan-block skip source 2 copy [] copy []
		prepare-functions
		prepare-imports
		compile-module skip source 2 copy [] copy []
		if module-kind = 3 [
			emit module-code reduce [return-op 0 0 0]
			add-module-function
		]
		if all [module-kind <> 3 not empty? module-code][
			fail ERROR-UNSUPPORTED "runtime module body requires a glue module"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
		lower-functions
	]

	write-types: func [type-output members [binary!] /local position kind spec scope uses
		field field-type ref flags count code first signature params parameter target
	][
		first: 0
		position: types
		while [not tail? position][
			kind: position/2
			case [
				kind = 'alias [
					code: select type-codes 'alias
					target: either block? position/3 [position/3][reduce [position/3]]
					emit type-output reduce [
						code
						type-ref target position/4 position/5
						0
						first
						0
					]
				]
				kind = 'pointer [
					emit type-output reduce [
						select type-codes 'pointer-node position/3 0 first 0
					]
				]
				find [struct union] kind [
					code: select type-codes kind
					spec: position/3
					scope: position/4
					uses: position/5
					unless ((length? spec) // 2) = 0 [
						fail ERROR-UNSUPPORTED ["invalid aggregate type " mold position/1]
					]
					count: (length? spec) / 2
					emit type-output reduce [code 0 0 first count]
					while [not tail? spec][
						field: spec/1
						field-type: spec/2
						unless all [
							word? field
							block? field-type
						][
							fail ERROR-UNSUPPORTED [
								"invalid aggregate member " mold position/1
							]
						]
						ref: type-ref field-type scope uses
						flags: type-flags field-type scope uses
						emit members reduce [ref flags]
						spec: skip spec 2
					]
					first: first + count
				]
				find [function subroutine] kind [
					signature: read-signature position/3 position/4 position/5
					unless empty? signature/3 [
						fail ERROR-UNSUPPORTED "function type cannot declare locals"
					]
					params: signature/2
					count: (length? params) / 3
					emit type-output reduce [
						select type-codes kind
						signature/1
						signature/4
						first
						count
					]
					parameter: params
					while [not tail? parameter][
						emit members reduce [parameter/2 parameter/3]
						parameter: skip parameter 3
					]
					first: first + count
				]
				true [
					emit type-output reduce [(select type-codes kind) 0 0 first 0]
				]
			]
			position: skip position 5
		]
	]

	write-rsir: func [limit [integer!] /local output position name
		params locals flags record-offset param-count local-count first-param first-local
		instruction-count size entry id parameter import-records global-records
		function-records
		library external last-library library-offset external-offset names
		type-output members type-bytes member-bytes
	][
		type-output: make binary! (type-count * 20)
		members: make binary! 64
		write-types type-output members
		type-bytes: length? type-output
		member-bytes: length? members
		names: copy strings
		output: make binary! (28 + type-bytes + member-bytes + (length? strings)
			+ (length? function-code) + (import-count * 64)
			+ (global-count * 40) + (function-count * 112))
		append/dup output 0 28
		append output type-output
		append output members
		import-records: 29 + type-bytes + member-bytes
		global-records: import-records + (import-count * 32)
		function-records: global-records + (global-count * 20)
		append/dup output 0 (import-count * 32)
		append/dup output 0 (global-count * 20)
		append/dup output 0 (function-count * 36)

		position: imports
		last-library: none
		library-offset: 0
		first-param: 0
		id: 1
		while [not tail? position][
			library: position/2
			external: position/3
			unless same? library last-library [
				library-offset: length? names
				append names library
				last-library: library
			]
			external-offset: length? names
			append names external
			params: position/9
			param-count: either block? params [(length? params) / 3][0]
			record-offset: import-records + ((id - 1) * 32)
			change/part at output record-offset
				int-to-bin/to-bin32 library-offset 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? library) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 external-offset 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 (length? external) 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/8 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 position/10 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 param-count 4
			if block? params [
				parameter: params
				while [not tail? parameter][
					emit output reduce [parameter/2 parameter/3]
					parameter: skip parameter 3
				]
			]
			first-param: first-param + param-count
			id: id + 1
			position: skip position 10
		]

		position: global-data
		id: 1
		while [not tail? position][
			name: position/1
			unless integer? position/2 [
				fail ERROR-UNSUPPORTED ["global type is unresolved: " to string! name]
			]
			record-offset: global-records + ((id - 1) * 20)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/2 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 position/3 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/4 4
			append names name
			id: id + 1
			position: skip position 4
		]

		position: functions
		instruction-count: 0
		id: 1
		while [not tail? position][
			name: position/1
			params: position/7
			locals: position/8
			flags: position/9
			param-count: (length? params) / 3
			local-count: (length? locals) / 3
			first-local: first-param + param-count
			record-offset: function-records + ((id - 1) * 36)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/6 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 flags 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 param-count 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-local 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 local-count 4
			change/part at output (record-offset + 32)
				int-to-bin/to-bin32 position/10 4
			parameter: params
			while [not tail? parameter][
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			parameter: locals
			while [not tail? parameter][
				if parameter/2 = 0 [
					fail ERROR-UNSUPPORTED [
						"local type is unresolved: " mold parameter/1
					]
				]
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			append names name
			first-param: first-local + local-count
			instruction-count: instruction-count + position/10
			id: id + 1
			position: skip position 10
		]
		append output function-code
		append output names
		size: length? output
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [function-count][0]
		change/part output int-to-bin/to-bin32 module-kind 4
		change/part at output 5 int-to-bin/to-bin32 entry 4
		change/part at output 9 int-to-bin/to-bin32 type-count 4
		change/part at output 13 int-to-bin/to-bin32 import-count 4
		change/part at output 17 int-to-bin/to-bin32 function-count 4
		change/part at output 21 int-to-bin/to-bin32 instruction-count 4
		change/part at output 25 int-to-bin/to-bin32 global-count 4
		output
	]

	; Bodies lower directly to typed postfix values and places.
	resolve-stack-call: func [
		value [word! path!]
		scope uses [block!]
		return: [integer! none!]
		/local id record
	][
		id: resolve-name value scope uses function-ids
		if integer? id [return id]
		id: resolve-name value scope uses import-ids
		unless integer? id [return none]
		record: skip imports ((id - 1) * 10)
		either record/5 = 'function [0 - id][none]
	]

	stack-type-compatible?: func [
		expected actual [integer!]
		return: [logic!]
		/local expected-kind actual-kind
	][
		expected: canonical-ref expected
		actual: canonical-ref actual
		if expected = actual [return true]
		if any [expected = 0 actual = 0] [return false]
		expected-kind: ref-kind expected
		actual-kind: ref-kind actual
		either all [expected > 0 actual > 0][
			false
		][
			expected-kind = actual-kind
		]
	]

	integer-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [i8 u8 i16 u16 i32 u32 i64 u64] kind
	]

	float-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [f32 f64] kind
	]

	reference-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [pointer c-string struct union] kind
	]

	same-stack-type?: func [
		left left-flags right right-flags [integer!]
		return: [logic!]
	][
		all [
			(canonical-ref left) = canonical-ref right
			left-flags = right-flags
		]
	]

	stack-unary: func [
		operation [integer!]
		instructions [binary!]
		/local kind
	][
		kind: ref-kind last-type
		unless all [
			operation = not-operation
			last-flags = 0
			any [integer-kind? kind kind = 'logic]
		][fail ERROR-REFERENCE "invalid operand type for not"]
		emit instructions reduce [unary-op operation 0 0]
	]

	stack-binary: func [
		operation left left-flags [integer!]
		instructions [binary!]
		/local right right-flags left-kind right-kind valid? comparison?
	][
		right: last-type
		right-flags: last-flags
		left-kind: ref-kind left
		right-kind: ref-kind right
		valid?: false
		comparison?: operation >= 13

		case [
			operation <= 6 [
				valid?: any [
					all [
						integer-kind? left-kind
						integer-kind? right-kind
						left-flags = 0
						right-flags = 0
					]
					all [
						float-kind? left-kind
						left-kind = right-kind
						left-flags = 0
						right-flags = 0
						any [operation <= 4 left-kind = 'f32]
					]
					all [
						operation <= 2
						reference-kind? left-kind
						left-flags = 0
						any [
							all [integer-kind? right-kind right-flags = 0]
							all [reference-kind? right-kind right-flags = 0]
						]
					]
				]
			]
			operation <= 9 [
				valid?: all [
					integer-kind? left-kind
					right-kind = 'i32
					left-flags = 0
					right-flags = 0
				]
			]
			operation <= 12 [
				valid?: all [
					any [integer-kind? left-kind left-kind = 'logic]
					same-stack-type? left left-flags right right-flags
				]
			]
			comparison? [
				valid?: all [
					same-stack-type? left left-flags right right-flags
					any [
						integer-kind? left-kind
						float-kind? left-kind
						reference-kind? left-kind
						all [left-kind = 'logic operation <= 14]
					]
				]
			]
			true [valid?: false]
		]
		unless valid? [fail ERROR-REFERENCE "incompatible binary operands"]
		emit instructions reduce [binary-op operation 0 0]
		either comparison? [
			last-type: -11
			last-flags: 0
		][
			last-type: left
			last-flags: left-flags
		]
	]

	stack-storage-info: func [
		name [word!]
		params [block!]
		locals [block!]
		return: [block! none!]
		/local position index
	][
		position: params
		index: 1
		while [not tail? position][
			if position/1 = name [return reduce [index position]]
			position: skip position 3
			index: index + 1
		]
		position: locals
		while [not tail? position][
			if position/1 = name [return reduce [index position]]
			position: skip position 3
			index: index + 1
		]
		none
	]

	stack-read-type: func [
		position [block!]
		scope uses [block!]
		return: [block!]
		/local type token
	][
		unless all [not tail? position any [word? position/1 path? position/1]][
			fail ERROR-UNSUPPORTED "missing logical type"
		]
		token: position/1
		type: reduce [token]
		position: next position
		if all [
			word? token
			find [pointer! struct! union! function!] token
			not tail? position
			block? position/1
		][
			append/only type position/1
			position: next position
		]
		last-type: type-ref type scope uses
		last-flags: type-flags type scope uses
		reduce [position last-type last-flags]
	]

	stack-address: func [
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [logic!]
		/local id position member parts index base current flags info storage
	][
		if word? target [
			storage: stack-storage-info target params locals
			if block? storage [
				emit instructions reduce [address-op local-address storage/1 0]
				position: storage/2
				last-type: position/2
				last-flags: position/3
				return true
			]
		]
		id: resolve-name target scope uses globals
		if integer? id [
			emit instructions reduce [address-op global-address id 0]
			position: skip global-data ((id - 1) * 4)
			last-type: any [position/2 0]
			last-flags: 0
			return true
		]
		id: import-variable-id target scope uses
		if integer? id [
			emit instructions reduce [address-op import-address id 0]
			position: skip imports ((id - 1) * 10)
			last-type: position/8
			last-flags: 0
			return true
		]
		if word? target [return false]
		parts: to block! target
		if (length? parts) < 2 [return false]
		base: parts/1
		stack-value reduce [base] scope uses instructions params locals
		current: last-type
		flags: last-flags
		index: 2
		while [index <= length? parts][
			member: to word! parts/:index
			info: member-info current member
			unless block? info [
				fail ERROR-REFERENCE ["unknown member " mold member]
			]
			emit instructions reduce [member-op info/1 0 0]
			current: info/2
			flags: info/3
			if index < length? parts [
				emit instructions reduce [load-op 0 0 0]
				flags: 0
			]
			index: index + 1
		]
		last-type: current
		last-flags: flags
		true
	]

	stack-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local record return-ref parameters flags
			parameter count expected position-after
	][
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			return-ref: record/6
			parameters: record/7
			flags: record/9
		][
			record: skip imports (((0 - target) - 1) * 10)
			return-ref: record/8
			parameters: record/9
			flags: record/10
		]
		count: 0
		parameter: parameters
		position-after: next position
		while [not tail? parameter][
			position-after: stack-value position-after scope uses instructions params locals
			expected: parameter/2
			unless stack-type-compatible? expected last-type [
				fail ERROR-REFERENCE [
					"argument type does not match function " mold value
				]
			]
			count: count + 1
			parameter: skip parameter 3
		]
		emit instructions reduce [call-op target count return-ref]
		last-type: return-ref
		last-flags: either return-ref = 0 [0][flags and return-value-flag]
		position-after
	]

	stack-primary: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local value type-info target-ref target-flags next-position target
			id constant-key bytes offset inner
	][
		unless not tail? position [
			fail ERROR-UNSUPPORTED "missing expression"
		]
		value: position/1
		case [
			paren? value [
				inner: to block! value
				if empty? inner [fail ERROR-UNSUPPORTED "empty expression"]
				next-position: stack-value inner scope uses instructions params locals
				unless tail? next-position [
					fail ERROR-UNSUPPORTED "parenthesized expression is incomplete"
				]
				next position
			]
			value = 'not [
				next-position: stack-value next position scope uses instructions params locals
				stack-unary not-operation instructions
				next-position
			]
			value = 'as [
				unless (length? position) >= 2 [
					fail ERROR-UNSUPPORTED "cast is missing its type"
				]
				type-info: stack-read-type next position scope uses
				target-ref: type-info/2
				target-flags: type-info/3
				next-position: stack-value type-info/1 scope uses instructions params locals
				emit instructions reduce [cast-op target-ref target-flags 0]
				last-type: target-ref
				last-flags: target-flags
				next-position
			]
			value = 'size? [
				type-info: stack-read-type next position scope uses
				emit instructions reduce [size-op type-info/2 0 0]
				last-type: -5
				last-flags: 0
				type-info/1
			]
			integer? value [
				emit instructions reduce [
					literal-op -5 value either value < 0 [-1][0]
				]
				last-type: -5
				last-flags: 0
				next position
			]
			char? value [
				id: to integer! value
				if id > 255 [fail ERROR-UNSUPPORTED "byte literal is out of range"]
				emit instructions reduce [literal-op -2 id 0]
				last-type: -2
				last-flags: 0
				next position
			]
			logic? value [
				emit instructions reduce [literal-op -11 either value [1][0] 0]
				last-type: -11
				last-flags: 0
				next position
			]
			all [word? value find [true false yes no] value][
				emit instructions reduce [
					literal-op -11 either find [true yes] value [1][0] 0
				]
				last-type: -11
				last-flags: 0
				next position
			]
			string? value [
				bytes: to binary! value
				offset: select string-ids bytes
				unless integer? offset [
					offset: length? strings
					repend string-ids [bytes offset]
					append strings bytes
					append strings 0
				]
				emit instructions reduce [
					constant-op -13 offset ((length? bytes) + 1)
				]
				last-type: -13
				last-flags: 0
				next position
			]
			all [
				path? value
				(length? value) = 3
				value/1 = 'system
				value/2 = 'stack
				value/3 = 'top
			][
				emit instructions reduce [native-op stack-top-native 0 -12]
				last-type: -12
				last-flags: 0
				next position
			]
			any [word? value path? value] [
				constant-key: qualified scope value
				id: select constants constant-key
				either integer? id [
					emit instructions reduce [literal-op -5 id either id < 0 [-1][0]]
					last-type: -5
					last-flags: 0
					next position
				][
					target: resolve-stack-call value scope uses
					either integer? target [
						stack-call target value position scope uses instructions params locals
					][
						unless stack-address value scope uses instructions params locals [
							fail ERROR-REFERENCE [
								"unknown value or function " mold value
							]
						]
						if last-type = 0 [
							fail ERROR-REFERENCE ["value is used before initialization " mold value]
						]
						emit instructions reduce [load-op 0 0 0]
						last-flags: 0
						next position
					]
				]
			]
			true [
				fail ERROR-UNSUPPORTED ["unsupported expression " mold value]
			]
		]
	]

	stack-value: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local operation left left-flags
	][
		position: stack-primary position scope uses instructions params locals
		while [not tail? position][
			operation: select binary-operations position/1
			unless integer? operation [break]
			left: last-type
			left-flags: last-flags
			position: stack-primary next position scope uses instructions params locals
			stack-binary operation left left-flags instructions
		]
		position
	]

	stack-static: func [
		position [block!]
		scope uses [block!]
		return: [logic!]
		/local value type-info next-position
	][
		static?: false
		static-ref: 0
		static-low: 0
		static-high: 0
		static-next: position
		value: position/2
		case [
			integer? value [
				static?: true
				static-ref: -5
				static-low: value
				static-high: either value < 0 [-1][0]
				static-next: skip position 2
			]
			char? value [
				static-low: to integer! value
				if static-low > 255 [
					fail ERROR-UNSUPPORTED "byte literal is out of range"
				]
				static?: true
				static-ref: -2
				static-high: 0
				static-next: skip position 2
			]
			logic? value [
				static?: true
				static-ref: -11
				static-low: either value [1][0]
				static-next: skip position 2
			]
			all [word? value find [true false yes no] value][
				static?: true
				static-ref: -11
				static-low: either find [true yes] value [1][0]
				static-next: skip position 2
			]
			value = 'as [
				type-info: stack-read-type skip position 2 scope uses
				next-position: type-info/1
				if not tail? next-position [
					value: next-position/1
					if integer? value [
						static?: true
						static-ref: type-info/2
						static-low: value
						static-high: either value < 0 [-1][0]
						static-next: next next-position
					]
					if all [
						any [logic? value all [word? value find [true false yes no] value]]
						ref-kind type-info/2 = 'logic
					][
						static?: true
						static-ref: type-info/2
						static-low: either any [
							value = true
							all [word? value find [true yes] value]
						][1][0]
						static-next: next next-position
					]
				]
			]
		]
		static?
	]

	stack-assignment: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		fold? [logic!]
		return: [block!]
		/local target id record target-ref next-position storage
	][
		if (length? position) < 2 [fail ERROR-UNSUPPORTED "assignment value is missing"]
		target: either set-word? position/1 [
			to word! position/1
		][to path! position/1]
		storage: either word? target [stack-storage-info target params locals][none]
		id: either block? storage [none][resolve-name target scope uses globals]
		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 4)
			if all [
				not integer? record/2
				stack-static position scope uses
				static?
				any [
					tail? static-next
					none? select binary-operations static-next/1
				]
			][
				record/2: static-ref
				record/3: static-low
				record/4: static-high
				last-type: 0
				last-flags: 0
				return static-next
			]
		]
		unless stack-address target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		next-position: stack-value next position scope uses instructions params locals
		either block? storage [
			record: storage/2
			either record/2 = 0 [
				record/2: last-type
				record/3: last-flags
			][
				unless all [
					stack-type-compatible? record/2 last-type
					record/3 = last-flags
				][fail ERROR-REFERENCE ["local assignment changes type " mold target]]
			]
		][either integer? id [
			record: skip global-data ((id - 1) * 4)
			either integer? record/2 [
				unless stack-type-compatible? record/2 last-type [
					fail ERROR-REFERENCE ["global assignment changes type " mold target]
				]
			][record/2: last-type]
		][
			unless stack-type-compatible? target-ref last-type [
				fail ERROR-REFERENCE ["assignment changes type " mold target]
			]
		]]
		emit instructions reduce [set-op 0 0 0]
		next-position
	]

	stack-module: func [
		values scope uses [block!]
		/local position child target next-uses
	][
		position: values
		while [not tail? position][
			case [
				all [position/1 = 'comment (length? position) >= 2][
					position: skip position 2
				]
				all [
					issue? position/1
					find [#script #include] position/1
					(length? position) >= 2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					position: next position
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
				][position: skip position 3]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
				][position: skip position 2]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][position: skip position either find [
					pointer! struct! union! function! subroutine!
				] position/3 [4][3]]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][position: skip position 4]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					child: append copy scope to word! position/1
					stack-module position/3 child uses
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2]
					block? position/3
				][
					target: position/2
					unless child: resolve-context target scope uses [
						fail ERROR-CONTEXT ["unknown context " mold target]
					]
					next-uses: copy/deep uses
					append/only next-uses child
					stack-module position/3 scope next-uses
					position: skip position 3
				]
				any [set-word? position/1 set-path? position/1][
					position: stack-assignment position scope uses module-code [] [] true
					if last-type <> 0 [emit module-code reduce [drop-op 0 0 0]]
				]
				true [
					position: stack-value position scope uses module-code [] []
					if last-type <> 0 [
						emit module-code reduce [drop-op 0 0 0]
					]
				]
			]
		]
	]

	stack-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
		return: [integer!]
		/local position before result?
	][
		before: length? instructions
		position: body
		last-type: 0
		last-flags: 0
		if return-ref = 0 [
			while [not tail? position][
				either any [set-word? position/1 set-path? position/1][
					position: stack-assignment position scope uses instructions params locals false
				][
					position: stack-value position scope uses instructions params locals
				]
				if last-type <> 0 [emit instructions reduce [drop-op 0 0 0]]
			]
			emit instructions reduce [return-op 0 0 0]
			return to integer! (((length? instructions) - before) / 16)
		]
		if all [not tail? position position/1 = 'return][position: next position]
		result?: false
		while [not tail? position][
			either any [set-word? position/1 set-path? position/1][
				position: stack-assignment position scope uses instructions params locals false
			][
				position: stack-value position scope uses instructions params locals
			]
			either tail? position [
				if last-type = 0 [fail ERROR-UNSUPPORTED "function result is missing"]
				unless stack-type-compatible? return-ref last-type [
					fail ERROR-REFERENCE "function result type does not match signature"
				]
				result?: true
			][
				if last-type <> 0 [emit instructions reduce [drop-op 0 0 0]]
			]
		]
		unless result? [fail ERROR-UNSUPPORTED "function result is missing"]
		emit instructions reduce [return-op return-ref flags 0]
		to integer! (((length? instructions) - before) / 16)
	]

	set-global: func [
		position scope uses [block!]
	][
		stack-assignment position scope uses module-code [] [] true
	]

	compile-import-set: func [
		position scope uses [block!]
		instructions [binary!]
		module? [logic!]
	][
		stack-assignment position scope uses instructions [] [] module?
	]

	compile-module: func [
		values scope uses [block!]
	][
		stack-module values scope uses
	]

	compile-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
	][
		stack-body return-ref body scope uses instructions params locals flags
	]

	compile: func [
		source [block!]
		kind [word!]
		/limit max-bytes [integer!]
		/local result
	][
		last-error: none
		result: catch/name [
			module-kind: case [
				kind = 'user [1]
				kind = 'support [2]
				kind = 'glue [3]
				true [0]
			]
			if module-kind = 0 [
				fail ERROR-KIND "unsupported RSIR module kind"
			]

			clear functions
			clear function-ids
			clear contexts
			clear types
			clear type-ids
			clear pointer-types
			clear constants
			clear imports
			clear import-ids
			clear libraries
			clear globals
			clear global-data
			clear module-code
			clear function-code
			clear strings
			clear string-ids
			function-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
