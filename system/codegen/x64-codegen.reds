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

codegen-import!: alias struct! [
	library         [integer!]
	library-size    [integer!]
	external        [integer!]
	external-size   [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

x64-codegen: context [
	RSIR_HEADER_SIZE:      24
	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_FUNCTION_SIZE:    28
	RSIR_PARAMETER_SIZE:    8
	RSIR_INSTRUCTION_SIZE: 16

	RETURN_VALUE: 4
	VARIABLE_FLAGS: 56
	FUNCTION_FLAGS: 511

	IMAGE_HEADER_SIZE:   40
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_IMPORT_SIZE:   24
	BITMAP_SIZE:         16

	INVALID_IR:   -1
	UNSUPPORTED:  -2
	OUTPUT_FULL: -3

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

	aggregate-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local record [rsir-type!]
			steps [integer!]
	][
		if ref <= 0 [return false]
		steps: 0
		while [steps < count][
			record: as rsir-type! (data + ((ref - 1) * RSIR_TYPE_SIZE))
			case [
				record/kind = -1 [
					ref: record/target
					if ref <= 0 [return false]
				]
				any [record/kind = -2 record/kind = -3][return true]
				true [return false]
			]
			steps: steps + 1
		]
		false
	]

	integer32-ref?: func [
		ref [integer!]
		data [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local record [rsir-type!]
			steps kind [integer!]
	][
		if ref < 0 [return any [ref = -5 ref = -6]]
		if any [ref = 0 ref > count][return false]
		steps: 0
		while [steps < count][
			record: as rsir-type! (data + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			if any [kind = 5 kind = 6][return true]
			unless kind = -1 [return false]
			ref: record/target
			if ref < 0 [return any [ref = -5 ref = -6]]
			if any [ref = 0 ref > count][return false]
			steps: steps + 1
		]
		false
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

	shape-of: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		parameters [byte-ptr!]
		function-data import-data [byte-ptr!]
		type-data [byte-ptr!]
		type-count function-count import-count [integer!]
		return: [integer!]
		/local instruction call terminator [rsir-instruction!]
			callee [rsir-function!]
			imported [rsir-import!]
			parameter-count [integer!]
	][
		instruction: as rsir-instruction! instructions
		parameter-count: fn/parameter-count
		case [
			all [
				fn/return-type = 0
				(fn/flags and (FUNCTION_FLAGS - 3)) = 0
				parameter-count = 0
				fn/instruction-count = 1
				instruction/opcode = 2
				instruction/result = 0
				instruction/operand = 0
				instruction/immediate = 0
			][x64-encoder/VOID]
			all [
				i32-function? fn parameters type-data type-count 1
				fn/instruction-count = 1
				instruction/opcode = 3
				instruction/result = 0
				instruction/operand = 1
				instruction/immediate = 0
			][x64-encoder/I32_PARAM]
			all [
				parameter-count <= 1
				i32-function? fn parameters type-data type-count parameter-count
				fn/instruction-count = 2
				any [
					instruction/opcode = 1
					instruction/opcode = 5
					all [instruction/opcode = 4 instruction/immediate = 0]
				]
			][
				terminator: as rsir-instruction!
					(instructions + RSIR_INSTRUCTION_SIZE)
				unless all [
					terminator/opcode = 3
					terminator/result = 0
					terminator/operand = instruction/result
					terminator/immediate = 0
				][return INVALID_IR]
				case [
					all [
						instruction/opcode = 1
						instruction/result = (parameter-count + 1)
						instruction/operand = 0
					][x64-encoder/I32_LITERAL]
					all [
						instruction/opcode = 5
						instruction/result = (parameter-count + 1)
						instruction/immediate = 0
					][x64-encoder/I32_LITERAL]
					all [
						instruction/opcode = 4
						instruction/result = (parameter-count + 1)
						instruction/operand > 0
						instruction/operand <= function-count
						instruction/immediate = 0
					][
						callee: as rsir-function! (function-data
							+ ((instruction/operand - 1) * RSIR_FUNCTION_SIZE))
						either i32-function? callee parameters type-data type-count 0 [
							x64-encoder/I32_CALL
						][UNSUPPORTED]
					]
					all [
						instruction/opcode = 4
						instruction/result = (parameter-count + 1)
						instruction/operand < 0
						instruction/operand >= (0 - import-count)
						instruction/immediate = 0
					][
						imported: as rsir-import! (import-data
							+ (((0 - instruction/operand) - 1) * RSIR_IMPORT_SIZE))
						either i32-import? imported parameters type-data type-count 0 [
							x64-encoder/I32_IMPORT
						][UNSUPPORTED]
					]
					true [UNSUPPORTED]
				]
			]
			all [
				parameter-count <= 1
				i32-function? fn parameters type-data type-count parameter-count
				fn/instruction-count = 3
				instruction/opcode = 1
				instruction/result = (parameter-count + 1)
				instruction/operand = 0
			][
				call: as rsir-instruction! (instructions + RSIR_INSTRUCTION_SIZE)
				terminator: as rsir-instruction!
					(instructions + (RSIR_INSTRUCTION_SIZE * 2))
				unless all [
					call/opcode = 4
					call/result = (instruction/result + 1)
					any [
						all [call/operand > 0 call/operand <= function-count]
						all [
							call/operand < 0
							call/operand >= (0 - import-count)
						]
					]
					call/immediate = instruction/result
					terminator/opcode = 3
					terminator/result = 0
					terminator/operand = call/result
					terminator/immediate = 0
				][return INVALID_IR]
				either call/operand > 0 [
					callee: as rsir-function! (function-data
						+ ((call/operand - 1) * RSIR_FUNCTION_SIZE))
					either i32-function? callee parameters type-data type-count 1 [
						x64-encoder/I32_CALL_ARG_LITERAL
					][UNSUPPORTED]
				][
					imported: as rsir-import! (import-data
						+ (((0 - call/operand) - 1) * RSIR_IMPORT_SIZE))
					either i32-import? imported parameters type-data type-count 1 [
						x64-encoder/I32_IMPORT_ARG_LITERAL
					][UNSUPPORTED]
				]
			]
			all [
				i32-function? fn parameters type-data type-count 1
				fn/instruction-count = 2
				instruction/opcode = 4
				instruction/result = 2
				any [
					all [
						instruction/operand > 0
						instruction/operand <= function-count
					]
					all [
						instruction/operand < 0
						instruction/operand >= (0 - import-count)
					]
				]
				instruction/immediate = 1
			][
				terminator: as rsir-instruction!
					(instructions + RSIR_INSTRUCTION_SIZE)
				unless all [
					terminator/opcode = 3
					terminator/result = 0
					terminator/operand = 2
					terminator/immediate = 0
				][return INVALID_IR]
				either instruction/operand > 0 [
					callee: as rsir-function! (function-data
						+ ((instruction/operand - 1) * RSIR_FUNCTION_SIZE))
					either i32-function? callee parameters type-data type-count 1 [
						x64-encoder/I32_CALL_ARG_PARAM
					][INVALID_IR]
				][
					imported: as rsir-import! (import-data
						+ (((0 - instruction/operand) - 1) * RSIR_IMPORT_SIZE))
					either i32-import? imported parameters type-data type-count 1 [
						x64-encoder/I32_IMPORT_ARG_PARAM
					][INVALID_IR]
				]
			]
			true [UNSUPPORTED]
		]
	]

	machine-size: func [
		entry? [logic!]
		shape [integer!]
		return: [integer!]
	][
		case [
			all [entry? shape = x64-encoder/VOID] [x64-encoder/VOID_ENTRY_SIZE]
			all [entry? shape = x64-encoder/I32_LITERAL] [x64-encoder/I32_ENTRY_SIZE]
			all [entry? shape = x64-encoder/I32_CALL] [x64-encoder/CALL_ENTRY_SIZE]
			all [entry? shape = x64-encoder/I32_CALL_ARG_LITERAL][
				x64-encoder/CALL_ARG_LITERAL_ENTRY_SIZE
			]
			all [not entry? shape = x64-encoder/VOID][x64-encoder/VOID_SIZE]
			all [not entry? shape = x64-encoder/I32_LITERAL][x64-encoder/I32_SIZE]
			all [not entry? shape = x64-encoder/I32_CALL][x64-encoder/CALL_SIZE]
			all [not entry? shape = x64-encoder/I32_PARAM][x64-encoder/PARAM_SIZE]
			all [not entry? shape = x64-encoder/I32_CALL_ARG_LITERAL][
				x64-encoder/CALL_ARG_LITERAL_SIZE
			]
			all [not entry? shape = x64-encoder/I32_CALL_ARG_PARAM][
				x64-encoder/CALL_ARG_PARAM_SIZE
			]
			all [entry? shape = x64-encoder/I32_IMPORT][
				x64-encoder/IMPORT_CALL_ENTRY_SIZE
			]
			all [entry? shape = x64-encoder/I32_IMPORT_ARG_LITERAL][
				x64-encoder/IMPORT_CALL_ARG_LITERAL_ENTRY_SIZE
			]
			all [not entry? shape = x64-encoder/I32_IMPORT][
				x64-encoder/IMPORT_CALL_SIZE
			]
			all [not entry? shape = x64-encoder/I32_IMPORT_ARG_LITERAL][
				x64-encoder/IMPORT_CALL_ARG_LITERAL_SIZE
			]
			all [not entry? shape = x64-encoder/I32_IMPORT_ARG_PARAM][
				x64-encoder/IMPORT_CALL_ARG_PARAM_SIZE
			]
			true [-1]
		]
	]

	exit-reference: func [shape [integer!] return: [integer!]][
		case [
			shape = x64-encoder/VOID [x64-encoder/VOID_EXIT_REF]
			shape = x64-encoder/I32_LITERAL [x64-encoder/I32_EXIT_REF]
			shape = x64-encoder/I32_CALL [x64-encoder/CALL_EXIT_REF]
			shape = x64-encoder/I32_CALL_ARG_LITERAL [
				x64-encoder/CALL_ARG_LITERAL_EXIT_REF
			]
			shape = x64-encoder/I32_IMPORT [
				x64-encoder/IMPORT_CALL_EXIT_REF
			]
			shape = x64-encoder/I32_IMPORT_ARG_LITERAL [
				x64-encoder/IMPORT_CALL_ARG_LITERAL_EXIT_REF
			]
			true [-1]
		]
	]

	import-reference: func [shape [integer!] return: [integer!]][
		either shape = x64-encoder/I32_IMPORT_ARG_LITERAL [
			x64-encoder/IMPORT_CALL_ARG_LITERAL_REF
		][x64-encoder/IMPORT_CALL_REF]
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
			ir-function [rsir-function!]
			ir-parameter [rsir-parameter!]
			instruction call-instruction [rsir-instruction!]
			image [codegen-header!]
			image-function callee-record [codegen-function!]
			image-import [codegen-import!]
			references import-refs [int-ptr!]
			type-data member-data import-data function-data parameter-data instruction-data
				function-instructions strings name
				names-output code data-output
				cursor finish scratch [byte-ptr!]
			type-bytes member-bytes import-bytes function-bytes parameter-bytes instruction-bytes
				strings-start strings-size metadata-size member-count parameter-count
				names-size function-names-size code-offset code-size data-offset total-size
				id record-offset next-instruction function-size entry-size code-cursor
				name-cursor shape entry-shape encoded value argument target relative call-next
				library-offset external-offset variable-mode import-id reference-id
				used-import-count image-import-count import-reference-count reference-count
				import-names-size output-import-id first-reference last-library count [integer!]
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
		if header/function-count > (
			(size - RSIR_HEADER_SIZE - type-bytes - member-bytes - import-bytes)
			/ RSIR_FUNCTION_SIZE
		)[
			return INVALID_IR
		]
		function-bytes: header/function-count * RSIR_FUNCTION_SIZE
		function-data: import-data + import-bytes
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
				- function-bytes)
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
				- function-bytes - parameter-bytes)
			/ RSIR_INSTRUCTION_SIZE
		)[return INVALID_IR]
		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		instruction-data: parameter-data + parameter-bytes
		strings-start: RSIR_HEADER_SIZE + type-bytes + member-bytes + import-bytes
			+ function-bytes + parameter-bytes + instruction-bytes
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
		if any [
			capacity < IMAGE_HEADER_SIZE
			header/function-count > (
				(capacity - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE
			)
		][return OUTPUT_FULL]
		scratch: null
		import-refs: as int-ptr! 0
		if header/import-count > 0 [
			scratch: allocate (header/import-count * 4)
			if null? scratch [return OUTPUT_FULL]
			import-refs: as int-ptr! scratch
			id: 1
			while [id <= header/import-count][
				import-refs/id: 0
				id: id + 1
			]
		]

		id: 1
		next-instruction: 1
		function-names-size: 0
		code-size: 0
		entry-size: 0
		entry-shape: -1
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
			instruction: as rsir-instruction! function-instructions
			shape: shape-of ir-function function-instructions
				parameter-data function-data import-data type-data
				header/type-count header/function-count header/import-count
			if shape < 0 [return release scratch shape]
			if all [
				shape = x64-encoder/I32_LITERAL
				instruction/opcode = 5
				not valid-type-ref? instruction/operand header/type-count
			][return release scratch INVALID_IR]
			if any [
				shape = x64-encoder/I32_IMPORT
				shape = x64-encoder/I32_IMPORT_ARG_LITERAL
				shape = x64-encoder/I32_IMPORT_ARG_PARAM
			][
				call-instruction: instruction
				if shape = x64-encoder/I32_IMPORT_ARG_LITERAL [
					call-instruction: as rsir-instruction!
						(function-instructions + RSIR_INSTRUCTION_SIZE)
				]
				import-id: 0 - call-instruction/operand
				import-refs/import-id: import-refs/import-id + 1
			]
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			image-function/frame-size: shape
			current-entry?: all [entry? id = header/entry-function]
			if all [current-entry? ir-function/parameter-count > 0][
				return release scratch UNSUPPORTED
			]
			function-size: machine-size current-entry? shape
			if function-size < 0 [return release scratch UNSUPPORTED]
			if function-names-size > (2147483647 - ir-function/name-size) [
				return release scratch INVALID_IR
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size)[
				return release scratch INVALID_IR
			]
			code-size: code-size + function-size
			if current-entry? [
				entry-size: function-size
				entry-shape: shape
			]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		if next-instruction <> (header/instruction-count + 1)[
			return release scratch INVALID_IR
		]
		if all [entry? entry-shape < 0][return release scratch INVALID_IR]

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
		reference-count: import-reference-count
		if entry? [
			image-import-count: image-import-count + 1
			reference-count: reference-count + 1
		]

		if header/function-count > (
			(2147483647 - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE
		)[return release scratch OUTPUT_FULL]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if image-import-count > (
			(2147483647 - metadata-size) / IMAGE_IMPORT_SIZE
		)[return release scratch OUTPUT_FULL]
		metadata-size: metadata-size + (image-import-count * IMAGE_IMPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release scratch OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: function-names-size
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
		if data-offset > (2147483647 - BITMAP_SIZE)[
			return release scratch OUTPUT_FULL
		]
		total-size: data-offset + BITMAP_SIZE
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
		image/data-size: BITMAP_SIZE


		names-output: output + metadata-size
		name-cursor: 0
		code-cursor: entry-size
		id: 1
		while [id <= header/function-count][
			record-offset: (id - 1) * RSIR_FUNCTION_SIZE
			ir-function: as rsir-function! (function-data + record-offset)
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			shape: image-function/frame-size
			current-entry?: all [entry? id = header/entry-function]
			function-size: machine-size current-entry? shape
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

		references: as int-ptr! (output + IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
			+ (image-import-count * IMAGE_IMPORT_SIZE))
		output-import-id: 0
		first-reference: 1
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
				+ (output-import-id * IMAGE_IMPORT_SIZE))
			library-offset: name-cursor
			external-offset: library-offset + 12
			image-import/library: library-offset
			image-import/library-size: 12
			image-import/external: external-offset
			image-import/external-size: 11
			image-import/first-reference: first-reference
			image-import/reference-count: 1
			references/first-reference: exit-reference entry-shape
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
			instruction: as rsir-instruction! function-instructions
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			shape: image-function/frame-size
			call-instruction: instruction
			if any [
				shape = x64-encoder/I32_CALL_ARG_LITERAL
				shape = x64-encoder/I32_IMPORT_ARG_LITERAL
			][
				call-instruction: as rsir-instruction!
					(function-instructions + RSIR_INSTRUCTION_SIZE)
			]
			value: 0
			argument: 0
			value: case [
				shape = x64-encoder/I32_LITERAL [
					either instruction/opcode = 5 [
						unless layout-type instruction/operand true type-data member-data
							header/type-count 0 :value :argument [
							return release scratch INVALID_IR
						]
						value
					][instruction/immediate]
				]
				any [
					shape = x64-encoder/I32_CALL
					shape = x64-encoder/I32_CALL_ARG_LITERAL
					shape = x64-encoder/I32_CALL_ARG_PARAM
				][
					target: call-instruction/operand
					callee-record: as codegen-function! (output + IMAGE_HEADER_SIZE
						+ ((target - 1) * IMAGE_FUNCTION_SIZE))
					call-next: either shape = x64-encoder/I32_CALL_ARG_LITERAL [
						x64-encoder/CALL_ARG_LITERAL_NEXT
					][x64-encoder/CALL_NEXT]
					relative: callee-record/code-offset
						- (image-function/code-offset + call-next)
					relative
				]
				true [0]
			]
			argument: either any [
				shape = x64-encoder/I32_CALL_ARG_LITERAL
				shape = x64-encoder/I32_IMPORT_ARG_LITERAL
			][
				instruction/immediate
			][0]
			current-entry?: all [entry? id = header/entry-function]
			encoded: x64-encoder/encode
				(code + image-function/code-offset)
				image-function/code-size current-entry? shape value argument 0
			if encoded <> image-function/code-size [
				return release scratch OUTPUT_FULL
			]
			if any [
				shape = x64-encoder/I32_IMPORT
				shape = x64-encoder/I32_IMPORT_ARG_LITERAL
				shape = x64-encoder/I32_IMPORT_ARG_PARAM
			][
				import-id: 0 - call-instruction/operand
				reference-id: import-refs/import-id
				references/reference-id: image-function/code-offset
					+ (import-reference shape)
				import-refs/import-id: reference-id + 1
			]
			image-function/frame-size: x64-encoder/FRAME_SIZE
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		cursor: code + code-size
		data-output: output + data-offset
		while [cursor < data-output][
			cursor/1: as byte! 0
			cursor: cursor + 1
		]
		finish: data-output + BITMAP_SIZE
		while [data-output < finish][
			data-output/1: as byte! 0
			data-output: data-output + 1
		]
		release scratch total-size
	]
]
