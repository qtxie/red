Red/System [
	Title: "Compact RSIR to Windows x64 code generator"
	File:  %x64-codegen.reds
]

#include %x64-encoder.reds

rsir-header!: alias struct! [
	module-kind      [integer!]
	entry-function   [integer!]
	type-count       [integer!]
	import-count     [integer!]
	function-count   [integer!]
	instruction-count [integer!]
	global-count     [integer!]
]

rsir-type!: alias struct! [
	kind         [integer!]
	target       [integer!]
	flags        [integer!]
	first-member [integer!]
	member-count [integer!]
]

rsir-member!: alias struct! [
	type  [integer!]
	flags [integer!]
]

rsir-import!: alias struct! [
	library         [integer!]
	library-size    [integer!]
	external        [integer!]
	external-size   [integer!]
	type             [integer!]
	flags            [integer!]
	first-parameter  [integer!]
	parameter-count  [integer!]
]

rsir-global!: alias struct! [
	name      [integer!]
	name-size [integer!]
	type      [integer!]
	low       [integer!]
	high      [integer!]
]

rsir-function!: alias struct! [
	name              [integer!]
	name-size         [integer!]
	return-type       [integer!]
	flags             [integer!]
	first-parameter   [integer!]
	parameter-count   [integer!]
	instruction-count [integer!]
]

rsir-parameter!: alias struct! [
	type  [integer!]
	flags [integer!]
]

rsir-instruction!: alias struct! [
	opcode     [integer!]
	result     [integer!]
	operand    [integer!]
	immediate  [integer!]
]

codegen-header!: alias struct! [
	size            [integer!]
	module-kind     [integer!]
	entry-function  [integer!]
	function-count  [integer!]
	import-count    [integer!]
	reference-count [integer!]
	names-size      [integer!]
	code-offset     [integer!]
	code-size       [integer!]
	data-size       [integer!]
	global-count    [integer!]
]

codegen-function!: alias struct! [
	name            [integer!]
	name-size       [integer!]
	code-offset     [integer!]
	code-size       [integer!]
	frame-size      [integer!]
	bitmap-offset   [integer!]
	bitmap-size     [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

codegen-global!: alias struct! [
	name            [integer!]
	name-size       [integer!]
	data-offset     [integer!]
	data-size       [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

codegen-import!: alias struct! [
	library         [integer!]
	library-size    [integer!]
	external        [integer!]
	external-size   [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

x64-codegen: context [
	RSIR_HEADER_SIZE:      28
	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_GLOBAL_SIZE:      20
	RSIR_FUNCTION_SIZE:    28
	RSIR_PARAMETER_SIZE:    8
	RSIR_INSTRUCTION_SIZE: 16

	RETURN_VALUE: 4
	VARIABLE_FLAGS: 56
	FUNCTION_FLAGS: 511

	IMAGE_HEADER_SIZE:   44
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   24
	IMAGE_IMPORT_SIZE:   24
	BITMAP_SIZE:         16

	INVALID_IR:   -1
	UNSUPPORTED:  -2
	OUTPUT_FULL: -3
	VALUE_NONE:    0
	VALUE_LITERAL: 1
	VALUE_PARAM:   2
	VALUE_RAX:     3
	VALUE_STRING:  4

	align: func [value boundary [integer!] return: [integer!]
		/local remainder padding [integer!]
	][
		if any [value < 0 boundary <= 0][return -1]
		remainder: value // boundary
		if remainder = 0 [return value]
		padding: boundary - remainder
		either value > (2147483647 - padding) [-1][value + padding]
	]

	valid-type-ref?: func [
		ref count [integer!]
		return: [logic!]
	][
		any [
			all [ref > 0 ref <= count]
			all [ref < 0 ref >= -12]
		]
	]

	logical-kind: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local record [rsir-type!]
			steps kind [integer!]
	][
		if ref < 0 [return 0 - ref]
		if any [ref = 0 ref > count][return 0]
		steps: 0
		while [steps < count][
			record: as rsir-type! (data + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			unless kind = -1 [return kind]
			ref: record/target
			if ref < 0 [return 0 - ref]
			if any [ref = 0 ref > count][return 0]
			steps: steps + 1
		]
		0
	]

	aggregate-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref data count
		any [kind = -2 kind = -3]
	]

	integer32-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref data count
		any [kind = 5 kind = 6]
	]

	scalar32-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref data count
		any [kind = 5 kind = 6 kind = 11]
	]

	pointer-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref data count
		any [kind = 12 kind = -2 kind = -3 kind = -4 kind = -5]
	]

	scalar-width: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local kind [integer!]
	][
		kind: logical-kind ref data count
		case [
			any [kind = 5 kind = 6 kind = 11][4]
			any [kind = 12 kind = -2 kind = -3 kind = -4 kind = -5][8]
			true [0]
		]
	]

	cstring-function-width: func [
		fn [rsir-function!]
		parameters types [byte-ptr!]
		type-count [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			width [integer!]
	][
		width: scalar-width fn/return-type types type-count
		unless all [
			width > 0
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			fn/parameter-count = 1
		][return 0]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		either all [
			pointer-ref? parameter/type types type-count
			parameter/flags = 0
		][width][0]
	]

	cstring-import-width: func [
		fn [rsir-import!]
		parameters types [byte-ptr!]
		type-count [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			width [integer!]
	][
		width: scalar-width fn/type types type-count
		unless all [
			width > 0
			(fn/flags and 3) <> 0
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			fn/parameter-count = 1
		][return 0]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		either all [
			pointer-ref? parameter/type types type-count
			parameter/flags = 0
		][width][0]
	]

	call2-function-width: func [
		fn [rsir-function!]
		parameters types [byte-ptr!]
		type-count first-width second-width [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			width [integer!]
	][
		width: scalar-width fn/return-type types type-count
		unless all [
			width > 0
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			fn/parameter-count = 2
		][return 0]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		unless all [
			parameter/flags = 0
			(scalar-width parameter/type types type-count) = first-width
		][return 0]
		parameter: parameter + 1
		either all [
			parameter/flags = 0
			(scalar-width parameter/type types type-count) = second-width
		][width][0]
	]

	call2-import-width: func [
		fn [rsir-import!]
		parameters types [byte-ptr!]
		type-count first-width second-width [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			width [integer!]
	][
		width: scalar-width fn/type types type-count
		unless all [
			width > 0
			(fn/flags and 3) <> 0
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			fn/parameter-count = 2
		][return 0]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		unless all [
			parameter/flags = 0
			(scalar-width parameter/type types type-count) = first-width
		][return 0]
		parameter: parameter + 1
		either all [
			parameter/flags = 0
			(scalar-width parameter/type types type-count) = second-width
		][width][0]
	]

	i32-function?: func [
		fn [rsir-function!]
		parameters types [byte-ptr!]
		type-count parameter-count [integer!]
		return: [logic!]
		/local parameter [rsir-parameter!]
	][
		unless all [
			integer32-ref? fn/return-type types type-count
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			fn/parameter-count = parameter-count
		][return false]
		if parameter-count = 0 [return true]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		all [
			integer32-ref? parameter/type types type-count
			parameter/flags = 0
		]
	]

	i32-import?: func [
		fn [rsir-import!]
		parameters types [byte-ptr!]
		type-count parameter-count [integer!]
		return: [logic!]
		/local parameter [rsir-parameter!]
	][
		unless all [
			(fn/flags and 3) <> 0
			(fn/flags and (FUNCTION_FLAGS - 3)) = 0
			integer32-ref? fn/type types type-count
			fn/parameter-count = parameter-count
		][return false]
		if parameter-count = 0 [return true]
		parameter: as rsir-parameter! (parameters
			+ (fn/first-parameter * RSIR_PARAMETER_SIZE))
		all [
			integer32-ref? parameter/type types type-count
			parameter/flags = 0
		]
	]

	layout-type: func [
		ref [integer!]
		inline? [logic!]
		types fields [byte-ptr!]
		type-count depth [integer!]
		size-out align-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!]
			field [rsir-member!]
			kind id field-index member-size member-align size alignment [integer!]
	][
		if any [ref = 0 depth > type-count][return false]
		kind: 0
		either ref < 0 [
			kind: 0 - ref
		][
			if ref > type-count [return false]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
		]

		if kind > 0 [
			size: case [
				kind <= 2 [1]
				kind <= 4 [2]
				any [kind = 5 kind = 6 kind = 9 kind = 11][4]
				any [kind = 7 kind = 8 kind = 10 kind = 12][8]
				true [0]
			]
			if size = 0 [return false]
			size-out/1: size
			align-out/1: size
			return true
		]

		if kind = -1 [
			return layout-type record/target inline? types fields type-count
				(depth + 1) size-out align-out
		]
		if any [kind = -4 kind = -5][
			size-out/1: 8
			align-out/1: 8
			return true
		]
		unless any [kind = -2 kind = -3][return false]
		unless inline? [
			size-out/1: 8
			align-out/1: 8
			return true
		]

		field-index: record/first-member
		size: 0
		alignment: 1
		id: 0
		while [id < record/member-count][
			field: as rsir-member! (fields
				+ ((field-index + id) * RSIR_MEMBER_SIZE))
			member-size: 0
			member-align: 0
			unless layout-type field/type (field/flags = 1) types fields
				type-count (depth + 1) :member-size :member-align [
				return false
			]
			if member-align > alignment [alignment: member-align]
			either kind = -2 [
				size: align size member-align
				if any [
					size < 0
					size > (2147483647 - member-size)
				][return false]
				size: size + member-size
			][
				if member-size > size [size: member-size]
			]
			id: id + 1
		]
		size: align size alignment
		if size < 0 [return false]
		size-out/1: size
		align-out/1: alignment
		true
	]

	layout-member: func [
		ref index [integer!]
		types fields [byte-ptr!]
		type-count [integer!]
		offset-out [int-ptr!]
		return: [integer!]
		/local record [rsir-type!]
			field [rsir-member!]
			steps kind id offset member-size member-align width [integer!]
	][
		if any [ref <= 0 ref > type-count index < 0][return -1]
		steps: 0
		while [steps < type-count][
			if ref > type-count [return -1]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			unless kind = -1 [break]
			ref: record/target
			if ref <= 0 [return 0]
			steps: steps + 1
		]
		if kind = -1 [return -1]
		unless any [kind = -2 kind = -3][return 0]
		if index >= record/member-count [return -1]

		offset: 0
		id: 0
		while [id <= index][
			field: as rsir-member! (fields
				+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
			member-size: 0
			member-align: 0
			unless layout-type field/type (field/flags = 1) types fields
				type-count 0 :member-size :member-align [
				return -1
			]
			if kind = -2 [
				offset: align offset member-align
				if offset < 0 [return -1]
			]
			if id = index [
				if field/flags <> 0 [return 0]
				width: scalar-width field/type types type-count
				if width = 0 [return 0]
				offset-out/1: offset
				return width
			]
			if kind = -2 [
				if offset > (2147483647 - member-size)[return -1]
				offset: offset + member-size
			]
			id: id + 1
		]
		-1
	]

	select-function: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		plans import-refs [int-ptr!]
		parameters function-data import-data global-data type-data member-data
			image-data strings [byte-ptr!]
		type-count function-count import-count global-count strings-size [integer!]
		entry? [logic!]
		global-reference-count literal-size [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			callee [rsir-function!]
			imported [rsir-import!]
			variable [rsir-global!]
			image-global [codegen-global!]
			literal [byte-ptr!]
			index form plan value-id value-kind next-value argument-kind
			import-id global-id function-size part-size unused-size unused-align
			parameter-count value-width result-width target-width literal-end
			member-offset pending-arguments first-width second-width [integer!]
			shadow? terminated? call? parameter-live? [logic!]
	][
		parameter-count: fn/parameter-count
		unless any [
			all [
				fn/return-type = 0
				(fn/flags and (FUNCTION_FLAGS - 3)) = 0
				parameter-count = 0
			]
			all [
				parameter-count <= 1
				i32-function? fn parameters type-data type-count parameter-count
			]
		][return UNSUPPORTED]
		if all [entry? parameter-count > 0][return UNSUPPORTED]

		function-size: x64-encoder/form-size x64-encoder/PROLOG
		next-value: parameter-count
		value-id: 0
		value-kind: VALUE_NONE
		value-width: 0
		pending-arguments: 0
		first-width: 0
		second-width: 0
		unused-size: 0
		unused-align: 0
		shadow?: false
		terminated?: false
		parameter-live?: parameter-count = 1
		index: 1
		while [index <= fn/instruction-count][
			if terminated? [return INVALID_IR]
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			form: x64-encoder/NONE
			plan: form
			import-id: 0
			global-id: 0
			call?: false
			case [
				instruction/opcode = 1 [
					unless all [
						instruction/result = (next-value + 1)
						instruction/operand = 0
					][return INVALID_IR]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_LITERAL
					value-width: 4
				]
				instruction/opcode = 5 [
					unless all [
						instruction/result = (next-value + 1)
						instruction/immediate = 0
						valid-type-ref? instruction/operand type-count
						layout-type instruction/operand true type-data member-data
							type-count 0 :unused-size :unused-align
					][return INVALID_IR]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_LITERAL
					value-width: 4
				]
				instruction/opcode = 9 [
					unless all [
						instruction/result = (next-value + 1)
						instruction/operand >= 0
						instruction/immediate > 0
						instruction/immediate <= strings-size
						instruction/operand <= (strings-size - instruction/immediate)
					][return INVALID_IR]
					literal-end: instruction/operand + instruction/immediate
					literal: strings + (literal-end - 1)
					if literal/1 <> as byte! 0 [return INVALID_IR]
					if literal-end > literal-size/1 [literal-size/1: literal-end]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_STRING
					value-width: 8
				]
				instruction/opcode = 4 [
					unless all [
						instruction/result = (next-value + 1)
						any [
							pending-arguments = 0
							all [
								pending-arguments = 2
								instruction/immediate = 0
							]
						]
					][return INVALID_IR]
					argument-kind: VALUE_NONE
					if all [
						pending-arguments = 0
						instruction/immediate <> 0
					][
						case [
							all [
								instruction/immediate = value-id
								value-kind = VALUE_LITERAL
							][argument-kind: VALUE_LITERAL]
							all [
								instruction/immediate = value-id
								value-kind = VALUE_RAX
							][argument-kind: VALUE_RAX]
							all [
								instruction/immediate = value-id
								value-kind = VALUE_STRING
							][argument-kind: VALUE_STRING]
							all [
								instruction/immediate = 1
								parameter-count = 1
								parameter-live?
							][argument-kind: VALUE_PARAM]
							true [return INVALID_IR]
						]
					]
					result-width: 0
					either instruction/operand > 0 [
						if instruction/operand > function-count [return INVALID_IR]
						callee: as rsir-function! (function-data
							+ ((instruction/operand - 1) * RSIR_FUNCTION_SIZE))
						case [
							pending-arguments = 2 [
								result-width: call2-function-width callee parameters
									type-data type-count first-width second-width
								if result-width = 0 [return UNSUPPORTED]
								form: x64-encoder/I32_CALL
							]
							argument-kind = VALUE_STRING [
								result-width: cstring-function-width callee parameters
									type-data type-count
								if result-width = 0 [return UNSUPPORTED]
								form: x64-encoder/CSTRING_CALL
							]
							true [
								unless i32-function? callee parameters type-data type-count
									either instruction/immediate = 0 [0][1] [
									return UNSUPPORTED
								]
								result-width: 4
								form: case [
									argument-kind = VALUE_NONE [x64-encoder/I32_CALL]
									argument-kind = VALUE_LITERAL [
										x64-encoder/I32_CALL_LITERAL
									]
									argument-kind = VALUE_PARAM [
										x64-encoder/I32_CALL_PARAM
									]
									argument-kind = VALUE_RAX [
										x64-encoder/I32_CALL_RAX
									]
									true [return INVALID_IR]
								]
							]
						]
					][
						import-id: 0 - instruction/operand
						if any [import-id <= 0 import-id > import-count][return INVALID_IR]
						imported: as rsir-import! (import-data
							+ ((import-id - 1) * RSIR_IMPORT_SIZE))
						case [
							pending-arguments = 2 [
								result-width: call2-import-width imported parameters
									type-data type-count first-width second-width
								if result-width = 0 [return UNSUPPORTED]
								form: x64-encoder/I32_IMPORT
							]
							argument-kind = VALUE_STRING [
								result-width: cstring-import-width imported parameters
									type-data type-count
								if result-width = 0 [return UNSUPPORTED]
								form: x64-encoder/CSTRING_IMPORT
							]
							true [
								unless i32-import? imported parameters type-data type-count
									either instruction/immediate = 0 [0][1] [
									return UNSUPPORTED
								]
								result-width: 4
								form: case [
									argument-kind = VALUE_NONE [x64-encoder/I32_IMPORT]
									argument-kind = VALUE_LITERAL [
										x64-encoder/I32_IMPORT_LITERAL
									]
									argument-kind = VALUE_PARAM [
										x64-encoder/I32_IMPORT_PARAM
									]
									argument-kind = VALUE_RAX [
										x64-encoder/I32_IMPORT_RAX
									]
									true [return INVALID_IR]
								]
							]
						]
					]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_RAX
					value-width: result-width
					pending-arguments: 0
					parameter-live?: false
					call?: true
				]
				instruction/opcode = 6 [
					global-id: instruction/operand
					unless all [
						instruction/result = (next-value + 1)
						global-id > 0
						global-id <= global-count
						instruction/immediate = 0
					][return INVALID_IR]
					variable: as rsir-global! (global-data
						+ ((global-id - 1) * RSIR_GLOBAL_SIZE))
					unless integer32-ref? variable/type type-data type-count [
						return UNSUPPORTED
					]
					form: x64-encoder/I32_GLOBAL
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_RAX
					value-width: 4
				]
				instruction/opcode = 7 [
					import-id: instruction/operand
					unless all [
						instruction/result = (next-value + 1)
						import-id > 0
						import-id <= import-count
						instruction/immediate = 0
					][return INVALID_IR]
					imported: as rsir-import! (import-data
						+ ((import-id - 1) * RSIR_IMPORT_SIZE))
					target-width: scalar-width imported/type type-data type-count
					unless all [imported/flags = 0 target-width > 0][
						return UNSUPPORTED
					]
					form: either target-width = 4 [
						x64-encoder/I32_IMPORT_LOAD
					][x64-encoder/PTR_IMPORT_LOAD]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_RAX
					value-width: target-width
				]
				instruction/opcode = 8 [
					import-id: instruction/operand
					unless all [
						instruction/result = 0
						import-id > 0
						import-id <= import-count
					][return INVALID_IR]
					imported: as rsir-import! (import-data
						+ ((import-id - 1) * RSIR_IMPORT_SIZE))
					unless all [
						imported/flags = 0
						scalar32-ref? imported/type type-data type-count
					][return UNSUPPORTED]
					form: x64-encoder/SCALAR_IMPORT_STORE
					if value-kind = VALUE_RAX [
						value-id: 0
						value-kind: VALUE_NONE
						value-width: 0
					]
				]
				instruction/opcode = 10 [
					global-id: instruction/operand
					unless all [
						instruction/result = 0
						global-id > 0
						global-id <= global-count
						instruction/immediate = value-id
						value-kind = VALUE_RAX
					][return INVALID_IR]
					variable: as rsir-global! (global-data
						+ ((global-id - 1) * RSIR_GLOBAL_SIZE))
					target-width: scalar-width variable/type type-data type-count
					unless target-width = value-width [return UNSUPPORTED]
					form: either target-width = 4 [
						x64-encoder/I32_GLOBAL_STORE
					][x64-encoder/PTR_GLOBAL_STORE]
				]
				instruction/opcode = 11 [
					unless all [
						instruction/result = (next-value + 1)
						instruction/operand = 0
						instruction/immediate = 0
					][return INVALID_IR]
					form: x64-encoder/STACK_TOP
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_RAX
					value-width: 8
				]
				instruction/opcode = 12 [
					import-id: instruction/operand
					unless all [
						instruction/result = 0
						import-id > 0
						import-id <= import-count
						instruction/immediate = value-id
						value-kind = VALUE_RAX
					][return INVALID_IR]
					imported: as rsir-import! (import-data
						+ ((import-id - 1) * RSIR_IMPORT_SIZE))
					target-width: scalar-width imported/type type-data type-count
					unless all [
						imported/flags = 0
						target-width > 0
						target-width = value-width
					][return UNSUPPORTED]
					form: either target-width = 4 [
						x64-encoder/I32_IMPORT_STORE
					][x64-encoder/PTR_IMPORT_STORE]
				]
				instruction/opcode = 13 [
					import-id: instruction/operand
					unless all [
						instruction/result = (next-value + 1)
						import-id > 0
						import-id <= import-count
						instruction/immediate >= 0
					][return INVALID_IR]
					imported: as rsir-import! (import-data
						+ ((import-id - 1) * RSIR_IMPORT_SIZE))
					unless imported/flags = 0 [return UNSUPPORTED]
					member-offset: 0
					result-width: layout-member imported/type instruction/immediate
						type-data member-data type-count :member-offset
					if result-width < 0 [return INVALID_IR]
					if result-width = 0 [return UNSUPPORTED]
					form: either result-width = 4 [
						x64-encoder/I32_IMPORT_MEMBER
					][x64-encoder/PTR_IMPORT_MEMBER]
					next-value: instruction/result
					value-id: next-value
					value-kind: VALUE_RAX
					value-width: result-width
				]
				instruction/opcode = 14 [
					unless all [
						instruction/result = 0
						instruction/immediate = value-id
					][return INVALID_IR]
					case [
						all [
							instruction/operand = 1
							pending-arguments = 0
							value-kind = VALUE_RAX
							value-width = 8
						][
							form: x64-encoder/PTR_ARG1_RAX
							first-width: value-width
							pending-arguments: 1
						]
						all [
							instruction/operand = 2
							pending-arguments = 1
							value-kind = VALUE_LITERAL
							value-width = 4
						][
							form: x64-encoder/I32_ARG2_LITERAL
							second-width: value-width
							pending-arguments: 2
						]
						true [return UNSUPPORTED]
					]
				]
				instruction/opcode = 2 [
					unless all [
						fn/return-type = 0
						instruction/result = 0
						instruction/operand = 0
						instruction/immediate = 0
						pending-arguments = 0
						index = fn/instruction-count
					][return INVALID_IR]
					form: either entry? [x64-encoder/ENTRY_VOID][
						x64-encoder/RETURN_VOID
					]
					terminated?: true
					call?: entry?
				]
				instruction/opcode = 3 [
					unless all [
						fn/return-type <> 0
						instruction/result = 0
						instruction/immediate = 0
						pending-arguments = 0
						index = fn/instruction-count
					][return INVALID_IR]
					argument-kind: case [
						all [
							instruction/operand = value-id
							value-kind = VALUE_LITERAL
						][VALUE_LITERAL]
						all [
							instruction/operand = value-id
							value-kind = VALUE_RAX
						][VALUE_RAX]
						all [
							instruction/operand = 1
							parameter-count = 1
							parameter-live?
						][VALUE_PARAM]
						true [return INVALID_IR]
					]
					form: case [
						all [entry? argument-kind = VALUE_LITERAL][
								x64-encoder/ENTRY_LITERAL
						]
						all [entry? argument-kind = VALUE_RAX][
								x64-encoder/ENTRY_RAX
						]
						all [entry? argument-kind = VALUE_PARAM][
								x64-encoder/ENTRY_PARAM
						]
						argument-kind = VALUE_LITERAL [x64-encoder/RETURN_LITERAL]
						argument-kind = VALUE_RAX [x64-encoder/RETURN_RAX]
						argument-kind = VALUE_PARAM [x64-encoder/RETURN_PARAM]
						true [return INVALID_IR]
					]
					terminated?: true
					call?: entry?
				]
				true [return UNSUPPORTED]
			]
			plan: form

			if import-id > 0 [
				if import-refs/import-id = 2147483647 [return OUTPUT_FULL]
				import-refs/import-id: import-refs/import-id + 1
			]
			if global-id > 0 [
				image-global: as codegen-global! (image-data
					+ (function-count * IMAGE_FUNCTION_SIZE)
					+ ((global-id - 1) * IMAGE_GLOBAL_SIZE))
				if any [
					image-global/reference-count = 2147483647
					global-reference-count/1 = 2147483647
				][return OUTPUT_FULL]
				image-global/reference-count: image-global/reference-count + 1
				global-reference-count/1: global-reference-count/1 + 1
			]
			if all [call? not shadow?][
				plan: form + x64-encoder/SHADOW_FLAG
				part-size: x64-encoder/form-size x64-encoder/SHADOW
				if function-size > (2147483647 - part-size)[return OUTPUT_FULL]
				function-size: function-size + part-size
				shadow?: true
			]
			plans/index: plan
			part-size: x64-encoder/form-size form
			if any [
				part-size < 0
				function-size > (2147483647 - part-size)
			][return OUTPUT_FULL]
			function-size: function-size + part-size
			index: index + 1
		]
		unless terminated? [return INVALID_IR]
		function-size
	]

	release: func [scratch [byte-ptr!] result [integer!] return: [integer!]][
		unless null? scratch [free scratch]
		result
	]

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local header [rsir-header!]
			ir-type [rsir-type!]
			ir-member [rsir-member!]
			ir-import [rsir-import!]
			ir-global [rsir-global!]
			ir-function [rsir-function!]
			ir-parameter [rsir-parameter!]
			instruction [rsir-instruction!]
			image [codegen-header!]
			image-function callee-record [codegen-function!]
			image-global [codegen-global!]
			image-import [codegen-import!]
			references import-refs plans function-plans [int-ptr!]
			type-data member-data import-data global-data function-data
				parameter-data instruction-data
				function-instructions strings name
				names-output code data-output
				cursor finish scratch [byte-ptr!]
			type-bytes member-bytes import-bytes global-bytes function-bytes
				parameter-bytes instruction-bytes
				strings-start strings-size metadata-size member-count parameter-count
				names-size function-names-size global-names-size code-offset code-size
				function-code-size literal-size data-offset image-data-size total-size
				id record-offset next-instruction function-size entry-size code-cursor
				name-cursor encoded value argument target call-next form plan
				cursor-offset current-literal current-string plan-index scratch-count
				exit-reference-id
				library-offset external-offset variable-mode import-id global-id reference-id
				used-import-count image-import-count import-reference-count reference-count
				import-names-size output-import-id first-reference last-library count
				global-size global-align global-offset global-reference-count [integer!]
			entry? current-entry? [logic!]
	][
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		if any [opt-level < 0 opt-level > 1][return UNSUPPORTED]

		header: as rsir-header! data
		if any [
			header/type-count < 0
			header/import-count < 0
			header/global-count < 0
			header/function-count <= 0
			header/instruction-count <= 0
		][return INVALID_IR]
		if any [header/module-kind < 1 header/module-kind > 3][return INVALID_IR]
		entry?: header/module-kind = 3
		if any [
			all [entry? any [
				header/entry-function <= 0
				header/entry-function > header/function-count
			]]
			all [not entry? header/entry-function <> 0]
		][
			return INVALID_IR
		]

		if header/type-count > ((size - RSIR_HEADER_SIZE) / RSIR_TYPE_SIZE) [
			return INVALID_IR
		]
		type-bytes: header/type-count * RSIR_TYPE_SIZE
		type-data: data + RSIR_HEADER_SIZE
		member-data: type-data + type-bytes
		member-count: 0
		id: 1
		while [id <= header/type-count][
			ir-type: as rsir-type! (type-data + ((id - 1) * RSIR_TYPE_SIZE))
			if any [
				ir-type/member-count < 0
				ir-type/first-member <> member-count
				ir-type/flags < 0
				ir-type/flags > FUNCTION_FLAGS
				(ir-type/flags and 3) = 3
			][return INVALID_IR]
			variable-mode: ir-type/flags and VARIABLE_FLAGS
			unless any [
				variable-mode = 0
				variable-mode = 8
				variable-mode = 16
				variable-mode = 32
			][return INVALID_IR]
			case [
				ir-type/kind = -1 [
					if any [
						ir-type/flags <> 0
						ir-type/member-count <> 0
						not valid-type-ref? ir-type/target header/type-count
					][return INVALID_IR]
				]
				any [ir-type/kind = -2 ir-type/kind = -3][
					if any [
						ir-type/target <> 0
						ir-type/flags <> 0
					][return INVALID_IR]
				]
				any [ir-type/kind = -4 ir-type/kind = -5][
					if any [
						all [
							ir-type/target <> 0
							not valid-type-ref? ir-type/target header/type-count
						]
						all [
							(ir-type/flags and RETURN_VALUE) <> 0
							any [
								ir-type/target = 0
								not aggregate-ref? ir-type/target type-data
									header/type-count
							]
						]
					][return INVALID_IR]
				]
				all [ir-type/kind > 0 ir-type/kind <= 12][
					if any [
						ir-type/target <> 0
						ir-type/flags <> 0
						ir-type/member-count <> 0
					][return INVALID_IR]
				]
				true [return INVALID_IR]
			]
			if member-count > (2147483647 - ir-type/member-count) [
				return INVALID_IR
			]
			member-count: member-count + ir-type/member-count
			id: id + 1
		]
		if member-count > (
			(size - RSIR_HEADER_SIZE - type-bytes) / RSIR_MEMBER_SIZE
		)[return INVALID_IR]
		member-bytes: member-count * RSIR_MEMBER_SIZE
		id: 1
		while [id <= member-count][
			ir-member: as rsir-member! (member-data
				+ ((id - 1) * RSIR_MEMBER_SIZE))
			if any [
				not valid-type-ref? ir-member/type header/type-count
				ir-member/flags < 0
				ir-member/flags > 1
				all [
					ir-member/flags = 1
					not aggregate-ref? ir-member/type type-data header/type-count
				]
			][return INVALID_IR]
			id: id + 1
		]
		if header/import-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes)
			/ RSIR_IMPORT_SIZE
		)[return INVALID_IR]
		import-bytes: header/import-count * RSIR_IMPORT_SIZE
		import-data: member-data + member-bytes
		parameter-count: 0
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (import-data
				+ ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				ir-import/flags < 0
				ir-import/flags > FUNCTION_FLAGS
				(ir-import/flags and 3) = 3
				ir-import/first-parameter <> parameter-count
				ir-import/parameter-count < 0
			][return INVALID_IR]
			either ir-import/flags = 0 [
				if any [
					not valid-type-ref? ir-import/type header/type-count
					ir-import/parameter-count <> 0
				][return INVALID_IR]
			][
				if any [
					(ir-import/flags and 3) = 0
					all [
						ir-import/type <> 0
						not valid-type-ref? ir-import/type header/type-count
					]
				][return INVALID_IR]
				variable-mode: ir-import/flags and VARIABLE_FLAGS
				unless any [
					variable-mode = 0
					variable-mode = 8
					variable-mode = 16
					variable-mode = 32
				][return INVALID_IR]
				if all [
					(ir-import/flags and RETURN_VALUE) <> 0
					any [
						ir-import/type = 0
						not aggregate-ref? ir-import/type type-data
							header/type-count
					]
				][return INVALID_IR]
			]
			if parameter-count > (2147483647 - ir-import/parameter-count) [
				return INVALID_IR
			]
			parameter-count: parameter-count + ir-import/parameter-count
			id: id + 1
		]
		if header/global-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes - import-bytes)
			/ RSIR_GLOBAL_SIZE
		)[return INVALID_IR]
		global-bytes: header/global-count * RSIR_GLOBAL_SIZE
		global-data: import-data + import-bytes
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data
				+ ((id - 1) * RSIR_GLOBAL_SIZE))
			unless valid-type-ref? ir-global/type header/type-count [
				return INVALID_IR
			]
			id: id + 1
		]
		if header/function-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes - import-bytes
				- global-bytes)
			/ RSIR_FUNCTION_SIZE
		)[
			return INVALID_IR
		]
		function-bytes: header/function-count * RSIR_FUNCTION_SIZE
		function-data: global-data + global-bytes
		next-instruction: 0
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				all [
					ir-function/return-type <> 0
					not valid-type-ref? ir-function/return-type header/type-count
				]
				ir-function/flags < 0
				ir-function/flags > FUNCTION_FLAGS
				(ir-function/flags and 3) = 3
				ir-function/first-parameter <> parameter-count
				ir-function/parameter-count < 0
				ir-function/instruction-count <= 0
			][return INVALID_IR]
			variable-mode: ir-function/flags and VARIABLE_FLAGS
			unless any [
				variable-mode = 0
				variable-mode = 8
				variable-mode = 16
				variable-mode = 32
			][return INVALID_IR]
			if all [
				(ir-function/flags and RETURN_VALUE) <> 0
				any [
					ir-function/return-type = 0
					not aggregate-ref? ir-function/return-type type-data
						header/type-count
				]
			][return INVALID_IR]
			if parameter-count > (2147483647 - ir-function/parameter-count) [
				return INVALID_IR
			]
			parameter-count: parameter-count + ir-function/parameter-count
			if next-instruction > (2147483647 - ir-function/instruction-count) [
				return INVALID_IR
			]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		if next-instruction <> header/instruction-count [return INVALID_IR]
		parameter-data: function-data + function-bytes
		if parameter-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes - import-bytes
				- global-bytes - function-bytes)
			/ RSIR_PARAMETER_SIZE
		)[return INVALID_IR]
		parameter-bytes: parameter-count * RSIR_PARAMETER_SIZE
		id: 1
		while [id <= parameter-count][
			ir-parameter: as rsir-parameter! (parameter-data
				+ ((id - 1) * RSIR_PARAMETER_SIZE))
			if any [
				not valid-type-ref? ir-parameter/type header/type-count
				ir-parameter/flags < 0
				ir-parameter/flags > 1
				all [
					ir-parameter/flags = 1
					not aggregate-ref? ir-parameter/type type-data header/type-count
				]
			][return INVALID_IR]
			id: id + 1
		]
		if header/instruction-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes - import-bytes
				- global-bytes - function-bytes - parameter-bytes)
			/ RSIR_INSTRUCTION_SIZE
		)[return INVALID_IR]
		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		instruction-data: parameter-data + parameter-bytes
		strings-start: RSIR_HEADER_SIZE + type-bytes + member-bytes + import-bytes
			+ global-bytes + function-bytes + parameter-bytes + instruction-bytes
		strings-size: size - strings-start

		strings: data + strings-start
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (import-data
				+ ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				ir-import/library < 0
				ir-import/library-size <= 0
				ir-import/library-size > strings-size
				ir-import/library > (strings-size - ir-import/library-size)
				ir-import/external < 0
				ir-import/external-size <= 0
				ir-import/external-size > strings-size
				ir-import/external > (strings-size - ir-import/external-size)
			][return INVALID_IR]
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data
				+ ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				ir-global/name < 0
				ir-global/name-size <= 0
				ir-global/name-size > strings-size
				ir-global/name > (strings-size - ir-global/name-size)
			][return INVALID_IR]
			id: id + 1
		]
		if any [
			capacity < IMAGE_HEADER_SIZE
			header/function-count > (
				(capacity - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE
			)
		][return OUTPUT_FULL]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > (
			(capacity - metadata-size) / IMAGE_GLOBAL_SIZE
		)[return OUTPUT_FULL]
		global-names-size: 0
		image-data-size: BITMAP_SIZE
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data
				+ ((id - 1) * RSIR_GLOBAL_SIZE))
			global-size: 0
			global-align: 0
			unless layout-type ir-global/type false type-data member-data
				header/type-count 0 :global-size :global-align [
				return INVALID_IR
			]
			if all [
				global-size > 8
				any [ir-global/low <> 0 ir-global/high <> 0]
			][return INVALID_IR]
			global-offset: align image-data-size global-align
			if any [
				global-offset < 0
				global-offset > (2147483647 - global-size)
				global-names-size > (2147483647 - ir-global/name-size)
			][return OUTPUT_FULL]
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/data-offset: global-offset
			image-global/data-size: global-size
			image-global/first-reference: 0
			image-global/reference-count: 0
			image-data-size: global-offset + global-size
			global-names-size: global-names-size + ir-global/name-size
			id: id + 1
		]
		if header/import-count > (2147483647 - header/instruction-count)[
			return OUTPUT_FULL
		]
		scratch-count: header/import-count + header/instruction-count
		if scratch-count > (2147483647 / 4)[return OUTPUT_FULL]
		scratch: allocate (scratch-count * 4)
		if null? scratch [return OUTPUT_FULL]
		import-refs: as int-ptr! scratch
		plans: import-refs + header/import-count
		id: 1
		while [id <= header/import-count][
			import-refs/id: 0
			id: id + 1
		]

		id: 1
		next-instruction: 1
		function-names-size: 0
		code-size: 0
		literal-size: 0
		entry-size: 0
		global-reference-count: 0
		while [id <= header/function-count][
			record-offset: (id - 1) * RSIR_FUNCTION_SIZE
			ir-function: as rsir-function! (function-data + record-offset)
			if any [
				ir-function/name < 0
				ir-function/name-size <= 0
				ir-function/name-size > strings-size
				ir-function/name > (strings-size - ir-function/name-size)
				ir-function/instruction-count > (
					header/instruction-count - next-instruction + 1
				)
			][return release scratch INVALID_IR]
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			function-size: select-function
				ir-function
				function-instructions
				(plans + (next-instruction - 1))
				import-refs
				parameter-data function-data import-data global-data
				type-data member-data (output + IMAGE_HEADER_SIZE) strings
				header/type-count header/function-count header/import-count
				header/global-count strings-size current-entry?
				:global-reference-count :literal-size
			if function-size < 0 [return release scratch function-size]
			image-function/code-size: function-size
			image-function/frame-size: x64-encoder/FRAME_SIZE
			if function-names-size > (2147483647 - ir-function/name-size) [
				return release scratch INVALID_IR
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size)[
				return release scratch INVALID_IR
			]
			code-size: code-size + function-size
			if current-entry? [entry-size: function-size]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		if next-instruction <> (header/instruction-count + 1)[
			return release scratch INVALID_IR
		]
		if all [entry? entry-size <= 0][return release scratch INVALID_IR]
		function-code-size: code-size
		if code-size > (2147483647 - literal-size)[
			return release scratch OUTPUT_FULL
		]
		code-size: code-size + literal-size

		used-import-count: 0
		import-reference-count: 0
		import-names-size: 0
		last-library: -1
		id: 1
		while [id <= header/import-count][
			count: import-refs/id
			if count > 0 [
				ir-import: as rsir-import! (import-data
					+ ((id - 1) * RSIR_IMPORT_SIZE))
				used-import-count: used-import-count + 1
				if import-reference-count > (2147483647 - count)[
					return release scratch OUTPUT_FULL
				]
				import-reference-count: import-reference-count + count
				if ir-import/library <> last-library [
					if import-names-size > (2147483647 - ir-import/library-size)[
						return release scratch OUTPUT_FULL
					]
					import-names-size: import-names-size + ir-import/library-size
					last-library: ir-import/library
				]
				if import-names-size > (2147483647 - ir-import/external-size)[
					return release scratch OUTPUT_FULL
				]
				import-names-size: import-names-size + ir-import/external-size
			]
			id: id + 1
		]
		image-import-count: used-import-count
		if global-reference-count > (2147483647 - import-reference-count)[
			return release scratch OUTPUT_FULL
		]
		reference-count: global-reference-count + import-reference-count
		if entry? [
			if any [
				image-import-count = 2147483647
				reference-count = 2147483647
			][return release scratch OUTPUT_FULL]
			image-import-count: image-import-count + 1
			reference-count: reference-count + 1
		]

		if header/function-count > (
			(2147483647 - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE
		)[return release scratch OUTPUT_FULL]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > (
			(2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE
		)[return release scratch OUTPUT_FULL]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if image-import-count > (
			(2147483647 - metadata-size) / IMAGE_IMPORT_SIZE
		)[return release scratch OUTPUT_FULL]
		metadata-size: metadata-size + (image-import-count * IMAGE_IMPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release scratch OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: function-names-size
		if names-size > (2147483647 - global-names-size)[
			return release scratch OUTPUT_FULL
		]
		names-size: names-size + global-names-size
		if names-size > (2147483647 - import-names-size)[
			return release scratch OUTPUT_FULL
		]
		names-size: names-size + import-names-size
		if entry? [
			if names-size > (2147483647 - 23)[
				return release scratch OUTPUT_FULL
			]
			names-size: names-size + 23
		]
		if metadata-size > (2147483647 - names-size - 15)[
			return release scratch OUTPUT_FULL
		]
		code-offset: align (metadata-size + names-size) 16
		if code-offset > (2147483647 - code-size - 3)[
			return release scratch OUTPUT_FULL
		]
		data-offset: align (code-offset + code-size) 4
		if data-offset > (2147483647 - image-data-size)[
			return release scratch OUTPUT_FULL
		]
		total-size: data-offset + image-data-size
		if any [
			metadata-size < 0
			names-size < 0
			code-offset < 0
			data-offset < 0
			total-size < 0
			total-size > capacity
		][return release scratch OUTPUT_FULL]

		image: as codegen-header! output
		image/size: total-size
		image/module-kind: header/module-kind
		image/entry-function: header/entry-function
		image/function-count: header/function-count
		image/import-count: image-import-count
		image/reference-count: reference-count
		image/names-size: names-size
		image/code-offset: code-offset
		image/code-size: code-size
		image/data-size: image-data-size
		image/global-count: header/global-count


		names-output: output + metadata-size
		name-cursor: 0
		code-cursor: entry-size
		id: 1
		while [id <= header/function-count][
			record-offset: (id - 1) * RSIR_FUNCTION_SIZE
			ir-function: as rsir-function! (function-data + record-offset)
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			function-size: image-function/code-size
			image-function/name: name-cursor
			image-function/name-size: ir-function/name-size
			image-function/code-offset: either current-entry? [0][code-cursor]
			image-function/code-size: function-size
			image-function/bitmap-offset: 0
			image-function/bitmap-size: BITMAP_SIZE
			image-function/first-reference: 0
			image-function/reference-count: 0
			unless current-entry? [code-cursor: code-cursor + function-size]
			name: strings + ir-function/name
			copy-memory (names-output + name-cursor) name ir-function/name-size
			name-cursor: name-cursor + ir-function/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data
				+ ((id - 1) * RSIR_GLOBAL_SIZE))
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/name: name-cursor
			image-global/name-size: ir-global/name-size
			copy-memory (names-output + name-cursor)
				(strings + ir-global/name) ir-global/name-size
			name-cursor: name-cursor + ir-global/name-size
			id: id + 1
		]

		references: as int-ptr! (output + IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
			+ (header/global-count * IMAGE_GLOBAL_SIZE)
			+ (image-import-count * IMAGE_IMPORT_SIZE))
		first-reference: 1
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			count: image-global/reference-count
			image-global/first-reference: either count > 0 [first-reference][0]
			first-reference: first-reference + count
			image-global/reference-count: 0
			id: id + 1
		]
		output-import-id: 0
		exit-reference-id: 0
		last-library: -1
		library-offset: 0
		id: 1
		while [id <= header/import-count][
			count: import-refs/id
			if count > 0 [
				ir-import: as rsir-import! (import-data
					+ ((id - 1) * RSIR_IMPORT_SIZE))
				if ir-import/library <> last-library [
					library-offset: name-cursor
					copy-memory (names-output + name-cursor)
						(strings + ir-import/library) ir-import/library-size
					name-cursor: name-cursor + ir-import/library-size
					last-library: ir-import/library
				]
				external-offset: name-cursor
				copy-memory (names-output + name-cursor)
					(strings + ir-import/external) ir-import/external-size
				name-cursor: name-cursor + ir-import/external-size
				image-import: as codegen-import! (output + IMAGE_HEADER_SIZE
					+ (header/function-count * IMAGE_FUNCTION_SIZE)
					+ (header/global-count * IMAGE_GLOBAL_SIZE)
					+ (output-import-id * IMAGE_IMPORT_SIZE))
				image-import/library: library-offset
				image-import/library-size: ir-import/library-size
				image-import/external: external-offset
				image-import/external-size: ir-import/external-size
				image-import/first-reference: first-reference
				image-import/reference-count: count
				import-refs/id: first-reference
				first-reference: first-reference + count
				output-import-id: output-import-id + 1
			]
			id: id + 1
		]

		if entry? [
			image-import: as codegen-import! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ (header/global-count * IMAGE_GLOBAL_SIZE)
				+ (output-import-id * IMAGE_IMPORT_SIZE))
			library-offset: name-cursor
			external-offset: library-offset + 12
			image-import/library: library-offset
			image-import/library-size: 12
			image-import/external: external-offset
			image-import/external-size: 11
			image-import/first-reference: first-reference
			image-import/reference-count: 1
			exit-reference-id: first-reference
			copy-memory (names-output + library-offset)
				(as byte-ptr! "kernel32.dll") 12
			copy-memory (names-output + external-offset)
				(as byte-ptr! "ExitProcess") 11
		]

		cursor: names-output + names-size
		finish: output + code-offset
		while [cursor < finish][
			cursor/1: as byte! 0
			cursor: cursor + 1
		]
		code: output + code-offset
		next-instruction: 1
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			function-plans: plans + (next-instruction - 1)
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			cursor: code + image-function/code-offset
			cursor-offset: 0
			encoded: x64-encoder/encode cursor image-function/code-size
				x64-encoder/PROLOG 0 0
			if encoded <> (x64-encoder/form-size x64-encoder/PROLOG)[
				return release scratch OUTPUT_FULL
			]
			cursor: cursor + encoded
			cursor-offset: cursor-offset + encoded
			current-literal: 0
			current-string: 0
			plan-index: 1
			while [plan-index <= ir-function/instruction-count][
				instruction: as rsir-instruction! (function-instructions
					+ ((plan-index - 1) * RSIR_INSTRUCTION_SIZE))
				plan: function-plans/plan-index
				if (plan and x64-encoder/SHADOW_FLAG) <> 0 [
					encoded: x64-encoder/encode cursor
						(image-function/code-size - cursor-offset)
						x64-encoder/SHADOW 0 0
					if encoded <> (x64-encoder/form-size x64-encoder/SHADOW)[
						return release scratch OUTPUT_FULL
					]
					cursor: cursor + encoded
					cursor-offset: cursor-offset + encoded
				]
				form: plan and x64-encoder/FORM_MASK
				value: 0
				argument: 0
				case [
					instruction/opcode = 1 [current-literal: instruction/immediate]
					instruction/opcode = 5 [
						unless layout-type instruction/operand true type-data member-data
							header/type-count 0 :value :argument [
							return release scratch INVALID_IR
						]
						current-literal: value
					]
					instruction/opcode = 9 [current-string: instruction/operand]
					instruction/opcode = 4 [
						if any [
							form = x64-encoder/I32_CALL
							form = x64-encoder/I32_CALL_LITERAL
							form = x64-encoder/I32_CALL_PARAM
							form = x64-encoder/I32_CALL_RAX
							form = x64-encoder/CSTRING_CALL
						][
							target: instruction/operand
							callee-record: as codegen-function! (output + IMAGE_HEADER_SIZE
								+ ((target - 1) * IMAGE_FUNCTION_SIZE))
							call-next: x64-encoder/call-next form
							value: callee-record/code-offset - (
								image-function/code-offset + cursor-offset + call-next
							)
						]
						if any [
							form = x64-encoder/I32_CALL_LITERAL
							form = x64-encoder/I32_IMPORT_LITERAL
						][argument: current-literal]
						if any [
							form = x64-encoder/CSTRING_CALL
							form = x64-encoder/CSTRING_IMPORT
						][
							argument: (function-code-size + current-string) - (
								image-function/code-offset + cursor-offset + 7
							)
						]
					]
					instruction/opcode = 13 [
						import-id: instruction/operand
						ir-import: as rsir-import! (import-data
							+ ((import-id - 1) * RSIR_IMPORT_SIZE))
						target: layout-member ir-import/type instruction/immediate
							type-data member-data header/type-count :value
						if target <= 0 [return release scratch INVALID_IR]
					]
					all [
						instruction/opcode = 14
						form = x64-encoder/I32_ARG2_LITERAL
					][value: current-literal]
					instruction/opcode = 8 [value: instruction/immediate]
					all [
						instruction/opcode = 3
						any [
							form = x64-encoder/RETURN_LITERAL
							form = x64-encoder/ENTRY_LITERAL
						]
					][value: current-literal]
					true []
				]
				if form <> x64-encoder/NONE [
					encoded: x64-encoder/encode cursor
						(image-function/code-size - cursor-offset)
						form value argument
					if encoded <> (x64-encoder/form-size form)[
						return release scratch OUTPUT_FULL
					]
					if any [
						all [form >= x64-encoder/I32_IMPORT
							form <= x64-encoder/I32_IMPORT_RAX]
						form = x64-encoder/I32_IMPORT_LOAD
						form = x64-encoder/SCALAR_IMPORT_STORE
						form = x64-encoder/CSTRING_IMPORT
						form = x64-encoder/PTR_IMPORT_LOAD
						form = x64-encoder/I32_IMPORT_STORE
						form = x64-encoder/PTR_IMPORT_STORE
						form = x64-encoder/I32_IMPORT_MEMBER
						form = x64-encoder/PTR_IMPORT_MEMBER
					][
						import-id: either instruction/opcode = 4 [
							0 - instruction/operand
						][instruction/operand]
						reference-id: import-refs/import-id
						references/reference-id: image-function/code-offset
							+ cursor-offset + (x64-encoder/reference-offset form)
						import-refs/import-id: reference-id + 1
					]
					if any [
						form = x64-encoder/I32_GLOBAL
						form = x64-encoder/I32_GLOBAL_STORE
						form = x64-encoder/PTR_GLOBAL_STORE
					][
						global-id: instruction/operand
						image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
							+ (header/function-count * IMAGE_FUNCTION_SIZE)
							+ ((global-id - 1) * IMAGE_GLOBAL_SIZE))
						reference-id: image-global/first-reference
							+ image-global/reference-count
						references/reference-id: image-function/code-offset
							+ cursor-offset + (x64-encoder/reference-offset form)
						image-global/reference-count: image-global/reference-count + 1
					]
					if all [
						form >= x64-encoder/ENTRY_VOID
						form <= x64-encoder/ENTRY_LITERAL
					][
						if exit-reference-id <= 0 [return release scratch INVALID_IR]
						references/exit-reference-id: image-function/code-offset
							+ cursor-offset + (x64-encoder/reference-offset form)
					]
					cursor: cursor + encoded
					cursor-offset: cursor-offset + encoded
				]
				plan-index: plan-index + 1
			]
			if cursor-offset <> image-function/code-size [
				return release scratch INVALID_IR
			]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		if all [entry? exit-reference-id <= 0][return release scratch INVALID_IR]
		if literal-size > 0 [
			copy-memory (code + function-code-size) strings literal-size
		]
		cursor: code + code-size
		data-output: output + data-offset
		while [cursor < data-output][
			cursor/1: as byte! 0
			cursor: cursor + 1
		]
		finish: data-output + image-data-size
		cursor: data-output
		while [cursor < finish][
			cursor/1: as byte! 0
			cursor: cursor + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data
				+ ((id - 1) * RSIR_GLOBAL_SIZE))
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			cursor: data-output + image-global/data-offset
			case [
				image-global/data-size = 1 [cursor/1: as byte! ir-global/low]
				image-global/data-size = 2 [
					cursor/1: as byte! ir-global/low
					cursor/2: as byte! (ir-global/low >>> 8)
				]
				image-global/data-size = 4 [
					x64-encoder/write-i32 cursor ir-global/low
				]
				image-global/data-size = 8 [
					x64-encoder/write-i32 cursor ir-global/low
					x64-encoder/write-i32 (cursor + 4) ir-global/high
				]
				true [0]
			]
			id: id + 1
		]
		release scratch total-size
	]
]
