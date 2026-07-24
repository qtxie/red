Red [
	Title: "Red compiler virtual struct serializer"
	File:  %virtual-struct.red
]

virtual-struct: context [
	alignment: 4

	base-class: context [
		__vs-type: 'struct!
		__vs-spec: none
	]

	pad: func [buffer [binary! string!] boundary [integer!] /local remainder][
		unless any [
			empty? buffer
			zero? remainder: (length? buffer) // boundary
		][
			append/dup tail buffer null boundary - remainder
		]
	]

	is?: func [value [any-type!] /local marker][
		to logic! all [
			object? value
			marker: in value '__vs-type
			'struct! = get marker
		]
	]

	make-value: func [
		spec [block! object!]
		data [block! none!]
		/local value-object fields index
		][
		value-object: either object? spec [
			make spec []
		][
			fields: copy [__vs-spec: spec]
			foreach [name type] spec [
				append fields to set-word! name
			]
			append fields none
			make base-class fields
		]
		if data [
			fields: skip keys-of value-object 2
			index: 1
			while [
				all [
					index <= length? data
					index <= length? fields
				]
			][
				set in value-object fields/:index data/:index
				index: index + 1
			]
		]
		value-object
	]

	form-value: func [
		value-object [object!]
		/with boundary [integer!]
		/local marker members type value output align
	][
		unless all [
			marker: in value-object '__vs-type
			'struct! = get marker
		][
			make error! "invalid virtual struct value"
		]
		members: skip keys-of value-object 2
		align: any [boundary alignment]
		output: make binary! (4 * length? members)
		foreach name members [
			type: second find value-object/__vs-spec name
			value: get in value-object name
			switch/default type/1 [
				char [
					append output int-to-bin/to-bin8 any [value 0]
				]
				char! [
					append output int-to-bin/to-bin8 any [value 0]
				]
				byte! [
					append output int-to-bin/to-bin8 any [value 0]
				]
				short [
					pad output 2
					append output int-to-bin/to-bin16 any [value 0]
				]
				int [
					pad output 4
					append output int-to-bin/to-bin32 any [value 0]
				]
				integer! [
					pad output 4
					append output int-to-bin/to-bin32 any [value 0]
				]
				int64 [
					pad output 8
					append output int-to-bin/to-bin64 any [value 0]
				]
				uint64 [
					pad output 8
					append output int-to-bin/to-bin64 any [value 0]
				]
				decimal! [
					pad output 8
					append output either binary? value [
						value
					][
						make binary! 8
					]
				]
				float! [
					pad output 8
					append output ieee-754/to-binary64/rev any [value 0.0]
				]
			][
				make error! rejoin ["datatype not supported: " mold type/1]
			]
		]
		output
	]
]

; Compatibility names retained at one boundary while consumers move to the
; namespaced API.
struct?: :virtual-struct/is?
make-struct: :virtual-struct/make-value
form-struct: :virtual-struct/form-value
