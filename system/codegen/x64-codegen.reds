Red/System [
	Title: "Typed postfix RSIR to Windows x64 code generator"
	File:  %x64-codegen.reds
]

#include %x64-encoder.reds

rsir-header!: alias struct! [
	module-kind       [integer!]
	entry-function    [integer!]
	type-count        [integer!]
	import-count      [integer!]
	function-count    [integer!]
	instruction-count [integer!]
	global-count      [integer!]
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
	first-local       [integer!]
	local-count       [integer!]
	instruction-count [integer!]
]

rsir-parameter!: alias struct! [
	type  [integer!]
	flags [integer!]
]

rsir-instruction!: alias struct! [
	op [integer!]
	a  [integer!]
	b  [integer!]
	c  [integer!]
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
	RSIR_FUNCTION_SIZE:    36
	RSIR_PARAMETER_SIZE:    8
	RSIR_INSTRUCTION_SIZE: 16

	IMAGE_HEADER_SIZE:   44
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   24
	IMAGE_IMPORT_SIZE:   24
	BITMAP_SIZE:         16

	RETURN_VALUE:  4
	VARIADIC:      8
	VARIABLE_FLAGS: 56
	FUNCTION_FLAGS: 511

	OP_LITERAL:   1
	OP_CONSTANT:  2
	OP_ADDRESS:   3
	OP_LOAD:      4
	OP_SET:       5
	OP_MEMBER:    6
	OP_CALL:      7
	OP_CAST:      8
	OP_SIZE:      9
	OP_NATIVE:   10
	OP_RETURN:   11
	OP_DROP:     12
	OP_DUPLICATE: 13
	OP_UNARY:    14
	OP_BINARY:   15

	NOT_OPERATION:       1
	ADD_OPERATION:       1
	SUBTRACT_OPERATION:  2
	MULTIPLY_OPERATION:  3
	DIVIDE_OPERATION:    4
	REMAINDER_OPERATION: 5
	MODULO_OPERATION:    6
	SHIFT_LEFT_OPERATION:  7
	SHIFT_RIGHT_OPERATION: 8
	SHIFT_LOGICAL_OPERATION: 9
	OR_OPERATION:  10
	XOR_OPERATION: 11
	AND_OPERATION: 12
	EQUAL_OPERATION:         13
	NOT_EQUAL_OPERATION:     14
	GREATER_OPERATION:       15
	LESS_OPERATION:          16
	GREATER_EQUAL_OPERATION: 17
	LESS_EQUAL_OPERATION:    18

	LOCAL_ADDRESS:    1
	GLOBAL_ADDRESS:   2
	IMPORT_ADDRESS:   3
	FUNCTION_ADDRESS: 4

	STACK_TOP: 1

	PLACE: 1
	VALUE: 2

	INVALID_IR:  -1
	UNSUPPORTED: -2
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

	valid-type-ref?: func [ref count [integer!] return: [logic!]][
		any [
			all [ref > 0 ref <= count]
			all [ref < 0 ref >= -13]
		]
	]

	canonical-type: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local record [rsir-type!] steps [integer!]
	][
		if ref < 0 [return ref]
		steps: 0
		while [steps < count][
			if any [ref <= 0 ref > count][return 0]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			unless record/kind = -1 [return ref]
			ref: record/target
			if ref < 0 [return ref]
			steps: steps + 1
		]
		0
	]

	logical-kind: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local record [rsir-type!] base [integer!]
	][
		base: canonical-type ref types count
		if base < 0 [return 0 - base]
		if base = 0 [return 0]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		record/kind
	]

	aggregate-ref?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		any [kind = -2 kind = -3]
	]

	compatible-types?: func [
		expected actual [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local left right left-kind right-kind [integer!]
	][
		if expected = actual [return true]
		left: canonical-type expected types count
		right: canonical-type actual types count
		if any [left = 0 right = 0][return false]
		if left = right [return true]
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		all [left-kind > 0 left-kind = right-kind]
	]

	signed-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		any [kind = 1 kind = 3 kind = 5 kind = 7]
	]

	float-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		any [kind = 9 kind = 10]
	]

	layout-type: func [
		ref [integer!]
		inline? [logic!]
		types members [byte-ptr!]
		type-count depth [integer!]
		size-out align-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			kind id member-size member-align size alignment [integer!]
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
				any [kind = 7 kind = 8 kind = 10 kind = 12 kind = 13][8]
				true [0]
			]
			if size = 0 [return false]
			size-out/1: size
			align-out/1: size
			return true
		]

		if kind = -1 [
			return layout-type record/target inline? types members type-count
				(depth + 1) size-out align-out
		]
		if any [kind = -4 kind = -5][
			size-out/1: 8
			align-out/1: 8
			return true
		]
		if kind = -6 [
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

		size: 0
		alignment: 1
		id: 0
		while [id < record/member-count][
			member: as rsir-member! (members
				+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
			member-size: 0
			member-align: 0
			unless layout-type member/type (member/flags = 1) types members
				type-count (depth + 1) :member-size :member-align [
				return false
			]
			if member-align > alignment [alignment: member-align]
			either kind = -2 [
				size: align size member-align
				if any [size < 0 size > (2147483647 - member-size)][return false]
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

	value-width: func [
		ref flags [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		return: [integer!]
		/local size alignment [integer!]
	][
		size: 0
		alignment: 0
		either layout-type ref (flags = 1) types members type-count 0
			:size :alignment [size][0]
	]

	machine-value?: func [
		ref flags [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		return: [logic!]
		/local width [integer!]
	][
		if float-type? ref types type-count [return false]
		width: value-width ref flags types members type-count
		all [width > 0 width <= 8 not all [flags = 1 aggregate-ref? ref types type-count]]
	]

	integer-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		all [kind >= 1 kind <= 8]
	]

	reference-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		any [kind = 12 kind = 13 kind = -2 kind = -3 kind = -6]
	]

	pointer-stride: func [
		ref [integer!]
		types members [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local base kind size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref types count
		if base = 0 [return 0]
		kind: logical-kind base types count
		if any [kind = 12 kind = 13][return 1]
		size: 0
		alignment: 0
		case [
			kind = -6 [
			record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
			unless layout-type record/target true types members count 0 :size :alignment [
				return 0
			]
		]
			any [kind = -2 kind = -3][
				unless layout-type base true types members count 0 :size :alignment [
					return 0
				]
			]
			true [return 0]
		]
		size
	]

	load-operation-value: func [
		code [byte-ptr!]
		capacity target displacement ref flags operation-width [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		return: [integer!]
		/local source-width signed encoded written [integer!] at [byte-ptr!]
	][
		source-width: value-width ref flags types members type-count
		if source-width <= 0 [return -1]
		signed: either signed-type? ref types type-count [1][0]
		encoded: x64-encoder/frame-load code capacity target displacement
			source-width signed
		if encoded < 0 [return encoded]
		written: encoded
		if all [operation-width = 8 source-width < 8 signed = 1][
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/sign-extend-register at (capacity - written) target
			if encoded < 0 [return encoded]
			written: written + encoded
		]
		written
	]

	layout-member: func [
		ref index [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		type-out flags-out offset-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			base kind id offset member-size member-align [integer!]
	][
		base: canonical-type ref types type-count
		if any [base <= 0 index < 0][return false]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		kind: record/kind
		unless any [kind = -2 kind = -3][return false]
		if index >= record/member-count [return false]
		offset: 0
		id: 0
		while [id <= index][
			member: as rsir-member! (members
				+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
			member-size: 0
			member-align: 0
			unless layout-type member/type (member/flags = 1) types members
				type-count 0 :member-size :member-align [return false]
			if kind = -2 [
				offset: align offset member-align
				if offset < 0 [return false]
			]
			if id = index [
				type-out/1: member/type
				flags-out/1: member/flags
				offset-out/1: offset
				return true
			]
			if kind = -2 [
				if offset > (2147483647 - member-size)[return false]
				offset: offset + member-size
			]
			id: id + 1
		]
		false
	]

	slot-displacement: func [slot [integer!] return: [integer!]][
		0 - (x64-encoder/BASE_FRAME_SIZE + (slot * 8))
	]

	argument-register: func [index [integer!] return: [integer!]][
		case [
			index = 1 [x64-encoder/RCX]
			index = 2 [x64-encoder/RDX]
			index = 3 [x64-encoder/R8]
			index = 4 [x64-encoder/R9]
			true [-1]
		]
	]

	comparison-condition: func [
		operation signed [integer!]
		return: [integer!]
	][
		case [
			operation = EQUAL_OPERATION [4]
			operation = NOT_EQUAL_OPERATION [5]
			operation = GREATER_OPERATION [either signed = 1 [15][7]]
			operation = LESS_OPERATION [either signed = 1 [12][2]]
			operation = GREATER_EQUAL_OPERATION [either signed = 1 [13][3]]
			operation = LESS_EQUAL_OPERATION [either signed = 1 [14][6]]
			true [-1]
		]
	]

	normalize-modulo: func [
		code [byte-ptr!]
		capacity width [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written count [integer!]
	][
		written: 0
		at: code
		encoded: x64-encoder/move-register at capacity x64-encoder/RAX
			x64-encoder/RCX width
		if encoded < 0 [return encoded]
		written: written + encoded
		count: either width = 8 [63][31]

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 7 count width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 31h
			x64-encoder/RCX x64-encoder/RAX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 29h
			x64-encoder/RCX x64-encoder/RAX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RDX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 7 count width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 21h
			x64-encoder/RAX x64-encoder/RCX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 01h
			x64-encoder/RAX x64-encoder/RDX width
		if encoded < 0 [return encoded]
		written + encoded
	]

	release: func [scratch [byte-ptr!] result [integer!] return: [integer!]][
		unless null? scratch [free scratch]
		result
	]

	compile-function: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		stack-types stack-flags stack-kinds import-refs references [int-ptr!]
		parameters functions imports globals types members image-data strings code
			[byte-ptr!]
		type-count function-count import-count global-count strings-size
			function-offset function-code-size capacity exit-reference-id [integer!]
		entry? [logic!]
		global-reference-count literal-size frame-size [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			parameter [rsir-parameter!]
			callee [rsir-function!]
			imported [rsir-import!]
			global [rsir-global!]
			image-global [codegen-global!]
			target-function [codegen-function!]
			at [byte-ptr!]
			index depth max-depth kind ref flags width signed source-slot target-slot
			storage-count operation left-ref right-ref left-flags right-flags
			left-kind right-kind operation-width condition stride
			encoded written frame-extra slot-bytes outgoing max-outgoing argument-index
			argument-slot argument-width target return-ref first-parameter
			parameter-count call-flags import-id global-id literal-end displacement
			member-type member-flags member-offset source-width target-width
			result-index reference-id [integer!]
			measure? terminated? valid? comparison? [logic!]
	][
		measure?: null? code
		storage-count: fn/parameter-count + fn/local-count
		if any [
			fn/return-type <> 0
			not measure?
		][
			if all [
				fn/return-type <> 0
				not machine-value? fn/return-type
					(fn/flags and RETURN_VALUE) types members type-count
			][return UNSUPPORTED]
		]
		if all [entry? fn/parameter-count <> 0][return UNSUPPORTED]

		depth: 0
		max-depth: 0
		max-outgoing: 0
		terminated?: false
		written: 0
		at: as byte-ptr! 0
		if not measure? [at: code + written]
		encoded: x64-encoder/prolog at (capacity - written) 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		if not measure? [
			frame-extra: frame-size/1 - x64-encoder/BASE_FRAME_SIZE
			if frame-extra < 0 [return INVALID_IR]
			at: code + written
			encoded: x64-encoder/allocate-frame at (capacity - written) frame-extra
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		index: 1
		while [index <= fn/parameter-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			unless machine-value? parameter/type parameter/flags types members type-count [
				return UNSUPPORTED
			]
			width: value-width parameter/type parameter/flags types members type-count
			signed: either signed-type? parameter/type types type-count [1][0]
			target-slot: slot-displacement index
			either index <= 4 [
				source-slot: argument-register index
				at: as byte-ptr! 0
				if not measure? [at: code + written]
				encoded: x64-encoder/frame-store at (capacity - written)
					source-slot target-slot width
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			][
				displacement: 48 + ((index - 5) * 8)
				at: as byte-ptr! 0
				if not measure? [at: code + written]
				encoded: x64-encoder/frame-load at (capacity - written)
					x64-encoder/RAX displacement width signed
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				at: as byte-ptr! 0
				if not measure? [at: code + written]
				encoded: x64-encoder/frame-store at (capacity - written)
					x64-encoder/RAX target-slot width
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			index: index + 1
		]

		index: 1
		while [index <= fn/instruction-count][
			if terminated? [return INVALID_IR]
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			case [
				instruction/op = OP_LITERAL [
					ref: instruction/a
					unless all [
						valid-type-ref? ref type-count
						machine-value? ref 0 types members type-count
					][return INVALID_IR]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					width: value-width ref 0 types members type-count
					target-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/move-immediate at (capacity - written)
						x64-encoder/RAX target-width
						instruction/b instruction/c
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						target-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_CONSTANT [
					ref: instruction/a
					literal-end: instruction/b + instruction/c
					unless all [
						valid-type-ref? ref type-count
						instruction/b >= 0 instruction/c > 0
						instruction/c <= strings-size
						instruction/b <= (strings-size - instruction/c)
					][return INVALID_IR]
					at: strings + literal-end - 1
					if at/1 <> as byte! 0 [return INVALID_IR]
					if all [measure? literal-end > literal-size/1][
						literal-size/1: literal-end
					]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					displacement: 0
					if not measure? [
						displacement: (function-code-size + instruction/b)
							- (function-offset + written + 7)
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/rip-address at (capacity - written)
						x64-encoder/RAX displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_ADDRESS [
					ref: 0
					flags: 0
					import-id: 0
					global-id: 0
					case [
						instruction/a = LOCAL_ADDRESS [
							unless all [
								instruction/b > 0
								instruction/b <= storage-count
							][return INVALID_IR]
							parameter: as rsir-parameter! (parameters
								+ ((fn/first-parameter + instruction/b - 1)
									* RSIR_PARAMETER_SIZE))
							ref: parameter/type
							flags: parameter/flags
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-address at (capacity - written)
								x64-encoder/RAX slot-displacement instruction/b
						]
						instruction/a = GLOBAL_ADDRESS [
							global-id: instruction/b
							if any [global-id <= 0 global-id > global-count][return INVALID_IR]
							global: as rsir-global! (globals
								+ ((global-id - 1) * RSIR_GLOBAL_SIZE))
							ref: global/type
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/rip-address at (capacity - written)
								x64-encoder/RAX 0
						]
						instruction/a = IMPORT_ADDRESS [
							import-id: instruction/b
							if any [import-id <= 0 import-id > import-count][return INVALID_IR]
							imported: as rsir-import! (imports
								+ ((import-id - 1) * RSIR_IMPORT_SIZE))
							if imported/flags <> 0 [return INVALID_IR]
							ref: imported/type
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/rip-load at (capacity - written)
								x64-encoder/RAX 0
						]
						true [return UNSUPPORTED]
					]
					if encoded < 0 [return OUTPUT_FULL]
					if import-id > 0 [
						either measure? [
							if import-refs/import-id = 2147483647 [return OUTPUT_FULL]
							import-refs/import-id: import-refs/import-id + 1
						][
							reference-id: import-refs/import-id
							references/reference-id: function-offset + written + 3
							import-refs/import-id: reference-id + 1
						]
					]
					if global-id > 0 [
						image-global: as codegen-global! (image-data
							+ (function-count * IMAGE_FUNCTION_SIZE)
							+ ((global-id - 1) * IMAGE_GLOBAL_SIZE))
						either measure? [
							if any [
								image-global/reference-count = 2147483647
								global-reference-count/1 = 2147483647
							][return OUTPUT_FULL]
							image-global/reference-count: image-global/reference-count + 1
							global-reference-count/1: global-reference-count/1 + 1
						][
							reference-id: image-global/first-reference
								+ image-global/reference-count
							references/reference-id: function-offset + written + 3
							image-global/reference-count: image-global/reference-count + 1
						]
					]
					written: written + encoded
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: PLACE
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_LOAD [
					if any [depth <= 0 stack-kinds/depth <> PLACE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					unless machine-value? ref flags types members type-count [return UNSUPPORTED]
					width: value-width ref flags types members type-count
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/load-indirect at (capacity - written) width signed
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					target-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						target-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-kinds/depth: VALUE
				]
				instruction/op = OP_SET [
					target-slot: depth - 1
					if any [depth < 2 stack-kinds/target-slot <> PLACE
						stack-kinds/depth <> VALUE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					unless all [
						compatible-types? stack-types/target-slot ref types type-count
						stack-flags/target-slot = flags
						machine-value? ref flags types members type-count
					][return INVALID_IR]
					width: value-width ref flags types members type-count
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						width signed
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RDX slot-displacement (storage-count + depth - 1) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/store-indirect at (capacity - written) width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: VALUE
					target-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						target-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_MEMBER [
					if depth <= 0 [return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					unless any [
						stack-kinds/depth = PLACE
						all [stack-kinds/depth = VALUE flags = 0
							aggregate-ref? ref types type-count]
					][return INVALID_IR]
					member-type: 0
					member-flags: 0
					member-offset: 0
					unless layout-member ref instruction/a types members type-count
						:member-type :member-flags :member-offset [return INVALID_IR]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/add-immediate at (capacity - written) member-offset
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: member-type
					stack-flags/depth: member-flags
					stack-kinds/depth: PLACE
				]
				instruction/op = OP_CALL [
					target: instruction/a
					argument-index: instruction/b
					return-ref: 0
					first-parameter: 0
					parameter-count: 0
					call-flags: 0
					import-id: 0
					either target > 0 [
						if target > function-count [return INVALID_IR]
						callee: as rsir-function! (functions
							+ ((target - 1) * RSIR_FUNCTION_SIZE))
						return-ref: callee/return-type
						first-parameter: callee/first-parameter
						parameter-count: callee/parameter-count
						call-flags: callee/flags
					][
						import-id: 0 - target
						if any [import-id <= 0 import-id > import-count][return INVALID_IR]
						imported: as rsir-import! (imports
							+ ((import-id - 1) * RSIR_IMPORT_SIZE))
						if imported/flags = 0 [return INVALID_IR]
						return-ref: imported/type
						first-parameter: imported/first-parameter
						parameter-count: imported/parameter-count
						call-flags: imported/flags
					]
					unless all [
						argument-index >= 0 argument-index <= depth
						instruction/c = return-ref
						any [
							argument-index = parameter-count
							all [(call-flags and VARIADIC) <> 0
								argument-index >= parameter-count]
						]
					][return INVALID_IR]
					outgoing: 32
					if argument-index > 4 [outgoing: outgoing + ((argument-index - 4) * 8)]
					if outgoing > max-outgoing [max-outgoing: outgoing]
					result-index: depth - argument-index
					source-slot: 1
					while [source-slot <= argument-index][
						argument-slot: result-index + source-slot
						ref: stack-types/argument-slot
						flags: stack-flags/argument-slot
						if stack-kinds/argument-slot <> VALUE [return INVALID_IR]
						either source-slot <= parameter-count [
							parameter: as rsir-parameter! (parameters
								+ ((first-parameter + source-slot - 1)
									* RSIR_PARAMETER_SIZE))
							unless all [
								compatible-types? parameter/type ref types type-count
								parameter/flags = flags
							][return INVALID_IR]
						][0]
						unless machine-value? ref flags types members type-count [
							return UNSUPPORTED
						]
						argument-width: value-width ref flags types members type-count
						signed: either signed-type? ref types type-count [1][0]
						either source-slot <= 4 [
							target-slot: argument-register source-slot
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								target-slot slot-displacement
									(storage-count + argument-slot)
								argument-width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-count + argument-slot)
								argument-width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							target-width: either argument-width = 8 [8][4]
							encoded: x64-encoder/outgoing-store at (capacity - written)
								(32 + ((source-slot - 5) * 8))
								target-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						source-slot: source-slot + 1
					]
					displacement: 0
					if all [not measure? target > 0][
						target-function: as codegen-function! (image-data
							+ ((target - 1) * IMAGE_FUNCTION_SIZE))
						displacement: target-function/code-offset
							- (function-offset + written + 5)
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					either target > 0 [
						encoded: x64-encoder/call-relative at (capacity - written) displacement
					][
						encoded: x64-encoder/call-import at (capacity - written) 0
					]
					if encoded < 0 [return OUTPUT_FULL]
					if import-id > 0 [
						either measure? [
							if import-refs/import-id = 2147483647 [return OUTPUT_FULL]
							import-refs/import-id: import-refs/import-id + 1
						][
							reference-id: import-refs/import-id
							references/reference-id: function-offset + written + 2
							import-refs/import-id: reference-id + 1
						]
					]
					written: written + encoded
					depth: result-index
					if return-ref <> 0 [
						flags: either (call-flags and RETURN_VALUE) <> 0 [1][0]
						unless machine-value? return-ref flags types members type-count [
							return UNSUPPORTED
						]
						depth: depth + 1
						stack-types/depth: return-ref
						stack-flags/depth: flags
						stack-kinds/depth: VALUE
						width: value-width return-ref flags types members type-count
						target-width: either width = 8 [8][4]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
							target-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_CAST [
					if any [depth <= 0 stack-kinds/depth <> VALUE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					source-width: value-width ref flags types members type-count
					target-width: value-width instruction/a instruction/b
						types members type-count
					unless all [
						valid-type-ref? instruction/a type-count
						machine-value? ref flags types members type-count
						machine-value? instruction/a instruction/b types members type-count
					][return UNSUPPORTED]
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						source-width signed
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if all [target-width = 8 source-width < 8 signed = 1][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/sign-extend-eax at (capacity - written)
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					width: either target-width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: instruction/a
					stack-flags/depth: instruction/b
				]
				instruction/op = OP_SIZE [
					ref: instruction/a
					width: 0
					flags: 0
					unless all [
						valid-type-ref? ref type-count
						layout-type ref true types members type-count 0 :width :flags
					][return INVALID_IR]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/move-immediate at (capacity - written)
						x64-encoder/RAX 4 width 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_NATIVE [
					unless instruction/a = STACK_TOP [return UNSUPPORTED]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: instruction/c
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/stack-top at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_DROP [
					if depth <= 0 [return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_DUPLICATE [
					if depth <= 0 [return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					kind: stack-kinds/depth
					width: either kind = PLACE [8][
						value-width ref flags types members type-count
					]
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						width signed
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: kind
					target-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						target-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_UNARY [
					if any [
						instruction/a <> NOT_OPERATION
						instruction/b <> 0 instruction/c <> 0
						depth <= 0 stack-kinds/depth <> VALUE
					][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					kind: logical-kind ref types type-count
					unless all [
						flags = 0
						any [integer-type? ref types type-count kind = 11]
						machine-value? ref flags types members type-count
					][return INVALID_IR]
					width: value-width ref flags types members type-count
					operation-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						ref flags operation-width types members type-count
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					either kind = 11 [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/clear-register at (capacity - written)
							x64-encoder/RDX
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							39h x64-encoder/RAX x64-encoder/RDX operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/condition-result at (capacity - written) 4
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/not-register at (capacity - written)
							x64-encoder/RAX operation-width
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						operation-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_BINARY [
					if any [
						instruction/b <> 0 instruction/c <> 0
						instruction/a < ADD_OPERATION
						instruction/a > LESS_EQUAL_OPERATION
						depth < 2
					][return INVALID_IR]
					target-slot: depth - 1
					if any [
						stack-kinds/target-slot <> VALUE
						stack-kinds/depth <> VALUE
					][return INVALID_IR]
					operation: instruction/a
					left-ref: stack-types/target-slot
					left-flags: stack-flags/target-slot
					right-ref: stack-types/depth
					right-flags: stack-flags/depth
					left-kind: logical-kind left-ref types type-count
					right-kind: logical-kind right-ref types type-count
					comparison?: operation >= EQUAL_OPERATION
					valid?: false
					case [
						operation <= MODULO_OPERATION [
							valid?: any [
								all [
									integer-type? left-ref types type-count
									integer-type? right-ref types type-count
									left-flags = 0 right-flags = 0
								]
								all [
									float-type? left-ref types type-count
									compatible-types? left-ref right-ref types type-count
									left-flags = 0 right-flags = 0
									any [operation <= DIVIDE_OPERATION left-kind = 9]
								]
								all [
									operation <= SUBTRACT_OPERATION
									reference-type? left-ref types type-count
									left-flags = 0 right-flags = 0
									any [
										integer-type? right-ref types type-count
										reference-type? right-ref types type-count
									]
								]
							]
						]
						operation <= SHIFT_LOGICAL_OPERATION [
							valid?: all [
								integer-type? left-ref types type-count
								right-kind = 5 left-flags = 0 right-flags = 0
							]
						]
						operation <= AND_OPERATION [
							valid?: all [
								any [integer-type? left-ref types type-count left-kind = 11]
								compatible-types? left-ref right-ref types type-count
								left-flags = right-flags
							]
						]
						comparison? [
							valid?: all [
								compatible-types? left-ref right-ref types type-count
								left-flags = right-flags
								any [
									integer-type? left-ref types type-count
									float-type? left-ref types type-count
									reference-type? left-ref types type-count
									all [left-kind = 11 operation <= NOT_EQUAL_OPERATION]
								]
							]
						]
						true [valid?: false]
					]
					unless valid? [return INVALID_IR]
					if any [
						float-type? left-ref types type-count
						float-type? right-ref types type-count
					][return UNSUPPORTED]
					unless all [
						machine-value? left-ref left-flags types members type-count
						machine-value? right-ref right-flags types members type-count
					][return UNSUPPORTED]

					width: value-width left-ref left-flags types members type-count
					operation-width: either any [
						width = 8
						reference-type? left-ref types type-count
					][8][4]
					signed: either signed-type? left-ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement
						(storage-count + target-slot) left-ref left-flags
						operation-width types members type-count
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					source-slot: either all [
						operation >= DIVIDE_OPERATION
						operation <= SHIFT_LOGICAL_OPERATION
					][x64-encoder/RCX][x64-encoder/RDX]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						source-slot slot-displacement (storage-count + depth)
						right-ref right-flags operation-width types members type-count
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					if all [
						reference-type? left-ref types type-count
						integer-type? right-ref types type-count
					][
						stride: pointer-stride left-ref types members type-count
						if stride <= 0 [return UNSUPPORTED]
						if stride <> 1 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/multiply-immediate at (capacity - written)
								x64-encoder/RDX x64-encoder/RDX stride 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]

					at: as byte-ptr! 0
					if not measure? [at: code + written]
					case [
						operation = ADD_OPERATION [
							encoded: x64-encoder/binary-register at (capacity - written)
								01h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						operation = SUBTRACT_OPERATION [
							encoded: x64-encoder/binary-register at (capacity - written)
								29h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						operation = MULTIPLY_OPERATION [
							encoded: x64-encoder/multiply-register at (capacity - written)
								x64-encoder/RAX x64-encoder/RDX operation-width
						]
						all [
							operation >= DIVIDE_OPERATION
							operation <= MODULO_OPERATION
						][
							encoded: x64-encoder/divide-register at (capacity - written)
								operation-width signed
						]
						operation = SHIFT_LEFT_OPERATION [
							encoded: x64-encoder/shift-register at (capacity - written)
								x64-encoder/RAX 4 operation-width
						]
						operation = SHIFT_RIGHT_OPERATION [
							encoded: x64-encoder/shift-register at (capacity - written)
								x64-encoder/RAX 7 operation-width
						]
						operation = SHIFT_LOGICAL_OPERATION [
							encoded: x64-encoder/shift-register at (capacity - written)
								x64-encoder/RAX 5 operation-width
						]
						operation = OR_OPERATION [
							encoded: x64-encoder/binary-register at (capacity - written)
								09h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						operation = XOR_OPERATION [
							encoded: x64-encoder/binary-register at (capacity - written)
								31h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						operation = AND_OPERATION [
							encoded: x64-encoder/binary-register at (capacity - written)
								21h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						comparison? [
							encoded: x64-encoder/binary-register at (capacity - written)
								39h x64-encoder/RAX x64-encoder/RDX operation-width
						]
						true [encoded: -1]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					if operation = REMAINDER_OPERATION [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-register at (capacity - written)
							x64-encoder/RAX x64-encoder/RDX operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if operation = MODULO_OPERATION [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						either signed = 1 [
							encoded: normalize-modulo at (capacity - written) operation-width
						][
							encoded: x64-encoder/move-register at (capacity - written)
								x64-encoder/RAX x64-encoder/RDX operation-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if comparison? [
						condition: comparison-condition operation signed
						if condition < 0 [return INVALID_IR]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/condition-result at (capacity - written)
							condition
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					depth: depth - 1
					either comparison? [
						ref: -11
						flags: 0
						operation-width: 4
					][
						ref: left-ref
						flags: left-flags
					]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: VALUE
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-count + depth)
						operation-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_RETURN [
					unless index = fn/instruction-count [return INVALID_IR]
					return-ref: instruction/a
					if return-ref <> fn/return-type [return INVALID_IR]
					either return-ref = 0 [
						if depth <> 0 [return INVALID_IR]
					][
						if any [depth <> 1 stack-kinds/1 <> VALUE][return INVALID_IR]
						unless all [
							compatible-types? return-ref stack-types/1 types type-count
							stack-flags/1 = instruction/b
						][return INVALID_IR]
					]
					either entry? [
						if max-outgoing < 32 [max-outgoing: 32]
						either return-ref = 0 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/clear-register at (capacity - written)
								x64-encoder/RCX
						][
							width: value-width return-ref instruction/b types members type-count
							signed: either signed-type? return-ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-count + 1) width
								signed
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/call-import at (capacity - written) 0
						if encoded < 0 [return OUTPUT_FULL]
						if not measure? [
							if exit-reference-id <= 0 [return INVALID_IR]
							references/exit-reference-id: function-offset + written + 2
						]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/clear-register at (capacity - written)
							x64-encoder/RAX
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					][
						if return-ref <> 0 [
							width: value-width return-ref instruction/b types members type-count
							signed: either signed-type? return-ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-count + 1) width
								signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/leave-return at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: 0
					terminated?: true
				]
				true [return UNSUPPORTED]
			]
			index: index + 1
		]
		unless terminated? [return INVALID_IR]

		if measure? [
			slot-bytes: (storage-count + max-depth) * 8
			frame-extra: align (slot-bytes + max-outgoing) 16
			if frame-extra < 0 [return OUTPUT_FULL]
			frame-size/1: x64-encoder/BASE_FRAME_SIZE + frame-extra
			encoded: x64-encoder/allocate-frame null 0 frame-extra
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
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
			image [codegen-header!]
			image-function [codegen-function!]
			image-global [codegen-global!]
			image-import [codegen-import!]
			import-refs function-sizes function-frames stack-types stack-flags
				stack-kinds references [int-ptr!]
			type-data member-data import-data global-data function-data
				parameter-data instruction-data strings function-instructions
				name names-output code data-output cursor finish scratch [byte-ptr!]
			type-bytes member-bytes import-bytes global-bytes function-bytes
				parameter-bytes instruction-bytes remaining member-count parameter-count
				next-parameter
				strings-size metadata-size function-names-size global-names-size
				import-names-size names-size code-offset code-size function-code-size
				literal-size data-offset image-data-size total-size scratch-count
				id next-instruction instruction-count function-size entry-size
				code-cursor name-cursor global-size global-align global-offset
				global-reference-count used-import-count import-reference-count
				image-import-count reference-count count first-reference last-library
				library-offset external-offset output-import-id exit-reference-id
				record-offset variable-mode written [integer!]
			entry? current-entry? [logic!]
	][
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		if any [opt-level < 0 opt-level > 1][return UNSUPPORTED]
		header: as rsir-header! data
		if any [
			header/type-count < 0 header/import-count < 0 header/global-count < 0
			header/function-count <= 0 header/instruction-count <= 0
			header/module-kind < 1 header/module-kind > 3
		][return INVALID_IR]
		entry?: header/module-kind = 3
		if any [
			all [entry? any [header/entry-function <= 0
				header/entry-function > header/function-count]]
			all [not entry? header/entry-function <> 0]
		][return INVALID_IR]

		remaining: size - RSIR_HEADER_SIZE
		if header/type-count > (remaining / RSIR_TYPE_SIZE)[return INVALID_IR]
		type-bytes: header/type-count * RSIR_TYPE_SIZE
		type-data: data + RSIR_HEADER_SIZE
		remaining: remaining - type-bytes
		member-count: 0
		id: 1
		while [id <= header/type-count][
			ir-type: as rsir-type! (type-data + ((id - 1) * RSIR_TYPE_SIZE))
			if any [
				ir-type/member-count < 0 ir-type/first-member <> member-count
				ir-type/flags < 0 ir-type/flags > FUNCTION_FLAGS
				(ir-type/flags and 3) = 3
			][return INVALID_IR]
			variable-mode: ir-type/flags and VARIABLE_FLAGS
			unless any [variable-mode = 0 variable-mode = 8
				variable-mode = 16 variable-mode = 32][return INVALID_IR]
			case [
				ir-type/kind = -1 [
					if any [ir-type/flags <> 0 ir-type/member-count <> 0
						not valid-type-ref? ir-type/target header/type-count][
						return INVALID_IR
					]
				]
				any [ir-type/kind = -2 ir-type/kind = -3][
					if any [ir-type/target <> 0 ir-type/flags <> 0][return INVALID_IR]
				]
				any [ir-type/kind = -4 ir-type/kind = -5][
					if all [ir-type/target <> 0
						not valid-type-ref? ir-type/target header/type-count][return INVALID_IR]
				]
				ir-type/kind = -6 [
					if any [ir-type/flags <> 0 ir-type/member-count <> 0
						not valid-type-ref? ir-type/target header/type-count][
						return INVALID_IR
					]
				]
				all [ir-type/kind > 0 ir-type/kind <= 13][
					if any [ir-type/target <> 0 ir-type/flags <> 0
						ir-type/member-count <> 0][return INVALID_IR]
				]
				true [return INVALID_IR]
			]
			if member-count > (2147483647 - ir-type/member-count)[return INVALID_IR]
			member-count: member-count + ir-type/member-count
			id: id + 1
		]
		if member-count > (remaining / RSIR_MEMBER_SIZE)[return INVALID_IR]
		member-bytes: member-count * RSIR_MEMBER_SIZE
		member-data: type-data + type-bytes
		remaining: remaining - member-bytes
		id: 1
		while [id <= member-count][
			ir-member: as rsir-member! (member-data + ((id - 1) * RSIR_MEMBER_SIZE))
			if any [
				not valid-type-ref? ir-member/type header/type-count
				ir-member/flags < 0 ir-member/flags > 1
				all [ir-member/flags = 1
					not aggregate-ref? ir-member/type type-data header/type-count]
			][return INVALID_IR]
			id: id + 1
		]

		if header/import-count > (remaining / RSIR_IMPORT_SIZE)[return INVALID_IR]
		import-bytes: header/import-count * RSIR_IMPORT_SIZE
		import-data: member-data + member-bytes
		remaining: remaining - import-bytes
		parameter-count: 0
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (import-data + ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				ir-import/flags < 0 ir-import/flags > FUNCTION_FLAGS
				(ir-import/flags and 3) = 3
				ir-import/first-parameter <> parameter-count
				ir-import/parameter-count < 0
			][return INVALID_IR]
			either ir-import/flags = 0 [
				if any [not valid-type-ref? ir-import/type header/type-count
					ir-import/parameter-count <> 0][return INVALID_IR]
			][
				if any [
					(ir-import/flags and 3) = 0
					all [ir-import/type <> 0
						not valid-type-ref? ir-import/type header/type-count]
				][return INVALID_IR]
			]
			if parameter-count > (2147483647 - ir-import/parameter-count)[
				return INVALID_IR
			]
			parameter-count: parameter-count + ir-import/parameter-count
			id: id + 1
		]

		if header/global-count > (remaining / RSIR_GLOBAL_SIZE)[return INVALID_IR]
		global-bytes: header/global-count * RSIR_GLOBAL_SIZE
		global-data: import-data + import-bytes
		remaining: remaining - global-bytes
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			unless valid-type-ref? ir-global/type header/type-count [return INVALID_IR]
			id: id + 1
		]

		if header/function-count > (remaining / RSIR_FUNCTION_SIZE)[return INVALID_IR]
		function-bytes: header/function-count * RSIR_FUNCTION_SIZE
		function-data: global-data + global-bytes
		remaining: remaining - function-bytes
		instruction-count: 0
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				all [ir-function/return-type <> 0
					not valid-type-ref? ir-function/return-type header/type-count]
				ir-function/flags < 0 ir-function/flags > FUNCTION_FLAGS
				(ir-function/flags and 3) = 3
				ir-function/first-parameter <> parameter-count
				ir-function/parameter-count < 0
				ir-function/local-count < 0
				ir-function/instruction-count <= 0
			][return INVALID_IR]
			if parameter-count > (2147483647 - ir-function/parameter-count)[
				return INVALID_IR
			]
			next-parameter: parameter-count + ir-function/parameter-count
			if any [
				ir-function/first-local <> next-parameter
				next-parameter > (2147483647 - ir-function/local-count)
			][return INVALID_IR]
			parameter-count: next-parameter + ir-function/local-count
			if instruction-count > (2147483647 - ir-function/instruction-count)[
				return INVALID_IR
			]
			instruction-count: instruction-count + ir-function/instruction-count
			id: id + 1
		]
		if instruction-count <> header/instruction-count [return INVALID_IR]

		if parameter-count > (remaining / RSIR_PARAMETER_SIZE)[return INVALID_IR]
		parameter-bytes: parameter-count * RSIR_PARAMETER_SIZE
		parameter-data: function-data + function-bytes
		remaining: remaining - parameter-bytes
		id: 1
		while [id <= parameter-count][
			ir-parameter: as rsir-parameter! (parameter-data
				+ ((id - 1) * RSIR_PARAMETER_SIZE))
			if any [
				not valid-type-ref? ir-parameter/type header/type-count
				ir-parameter/flags < 0 ir-parameter/flags > 1
				all [ir-parameter/flags = 1
					not aggregate-ref? ir-parameter/type type-data header/type-count]
			][return INVALID_IR]
			id: id + 1
		]

		if header/instruction-count > (remaining / RSIR_INSTRUCTION_SIZE)[
			return INVALID_IR
		]
		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		instruction-data: parameter-data + parameter-bytes
		remaining: remaining - instruction-bytes
		strings: instruction-data + instruction-bytes
		strings-size: remaining

		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (import-data + ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				ir-import/library < 0 ir-import/library-size <= 0
				ir-import/library-size > strings-size
				ir-import/library > (strings-size - ir-import/library-size)
				ir-import/external < 0 ir-import/external-size <= 0
				ir-import/external-size > strings-size
				ir-import/external > (strings-size - ir-import/external-size)
			][return INVALID_IR]
			id: id + 1
		]

		metadata-size: IMAGE_HEADER_SIZE + (header/function-count * IMAGE_FUNCTION_SIZE)
		if any [metadata-size < 0 metadata-size > capacity][return OUTPUT_FULL]
		if header/global-count > ((capacity - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return OUTPUT_FULL
		]
		global-names-size: 0
		image-data-size: BITMAP_SIZE
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				ir-global/name < 0 ir-global/name-size <= 0
				ir-global/name-size > strings-size
				ir-global/name > (strings-size - ir-global/name-size)
			][return INVALID_IR]
			global-size: 0
			global-align: 0
			unless layout-type ir-global/type false type-data member-data
				header/type-count 0 :global-size :global-align [return INVALID_IR]
			if all [global-size > 8 any [ir-global/low <> 0 ir-global/high <> 0]][
				return INVALID_IR
			]
			global-offset: align image-data-size global-align
			if any [global-offset < 0 global-offset > (2147483647 - global-size)
				global-names-size > (2147483647 - ir-global/name-size)][
				return OUTPUT_FULL
			]
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

		if header/instruction-count > ((2147483647 - header/import-count
			- (header/function-count * 2)) / 3)[return OUTPUT_FULL]
		scratch-count: header/import-count + (header/function-count * 2)
			+ (header/instruction-count * 3)
		if scratch-count > (2147483647 / 4)[return OUTPUT_FULL]
		scratch: allocate (scratch-count * 4)
		if null? scratch [return OUTPUT_FULL]
		import-refs: as int-ptr! scratch
		function-sizes: import-refs + header/import-count
		function-frames: function-sizes + header/function-count
		stack-types: function-frames + header/function-count
		stack-flags: stack-types + header/instruction-count
		stack-kinds: stack-flags + header/instruction-count
		id: 1
		while [id <= header/import-count][import-refs/id: 0 id: id + 1]

		function-names-size: 0
		code-size: 0
		literal-size: 0
		entry-size: 0
		global-reference-count: 0
		next-instruction: 1
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				ir-function/name < 0 ir-function/name-size <= 0
				ir-function/name-size > strings-size
				ir-function/name > (strings-size - ir-function/name-size)
			][return release scratch INVALID_IR]
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			current-entry?: all [entry? id = header/entry-function]
			function-size: compile-function ir-function function-instructions
				stack-types stack-flags stack-kinds import-refs null
				parameter-data function-data import-data global-data type-data member-data
				(output + IMAGE_HEADER_SIZE) strings null
				header/type-count header/function-count header/import-count
				header/global-count strings-size 0 0 0 0 current-entry?
				:global-reference-count :literal-size (function-frames + (id - 1))
			if function-size < 0 [return release scratch function-size]
			function-sizes/id: function-size
			if function-names-size > (2147483647 - ir-function/name-size)[
				return release scratch OUTPUT_FULL
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size)[return release scratch OUTPUT_FULL]
			code-size: code-size + function-size
			if current-entry? [entry-size: function-size]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		function-code-size: code-size
		if code-size > (2147483647 - literal-size)[return release scratch OUTPUT_FULL]
		code-size: code-size + literal-size

		used-import-count: 0
		import-reference-count: 0
		import-names-size: 0
		last-library: -1
		id: 1
		while [id <= header/import-count][
			count: import-refs/id
			if count > 0 [
				ir-import: as rsir-import! (import-data + ((id - 1) * RSIR_IMPORT_SIZE))
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
		reference-count: global-reference-count + import-reference-count
		if entry? [
			if any [image-import-count = 2147483647 reference-count = 2147483647][
				return release scratch OUTPUT_FULL
			]
			image-import-count: image-import-count + 1
			reference-count: reference-count + 1
		]

		metadata-size: IMAGE_HEADER_SIZE + (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > ((2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return release scratch OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if image-import-count > ((2147483647 - metadata-size) / IMAGE_IMPORT_SIZE)[
			return release scratch OUTPUT_FULL
		]
		metadata-size: metadata-size + (image-import-count * IMAGE_IMPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release scratch OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: function-names-size + global-names-size + import-names-size
		if entry? [names-size: names-size + 23]
		if any [names-size < 0 metadata-size > (2147483647 - names-size - 15)][
			return release scratch OUTPUT_FULL
		]
		code-offset: align (metadata-size + names-size) 16
		if any [code-offset < 0 code-offset > (2147483647 - code-size - 3)][
			return release scratch OUTPUT_FULL
		]
		data-offset: align (code-offset + code-size) 4
		if any [data-offset < 0 data-offset > (2147483647 - image-data-size)][
			return release scratch OUTPUT_FULL
		]
		total-size: data-offset + image-data-size
		if total-size > capacity [return release scratch OUTPUT_FULL]

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
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			image-function/name: name-cursor
			image-function/name-size: ir-function/name-size
			image-function/code-offset: either current-entry? [0][code-cursor]
			image-function/code-size: function-sizes/id
			image-function/frame-size: function-frames/id
			image-function/bitmap-offset: 0
			image-function/bitmap-size: BITMAP_SIZE
			image-function/first-reference: 0
			image-function/reference-count: 0
			unless current-entry? [code-cursor: code-cursor + function-sizes/id]
			name: strings + ir-function/name
			copy-memory (names-output + name-cursor) name ir-function/name-size
			name-cursor: name-cursor + ir-function/name-size
			id: id + 1
		]

		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
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
				ir-import: as rsir-import! (import-data + ((id - 1) * RSIR_IMPORT_SIZE))
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
			copy-memory (names-output + library-offset) (as byte-ptr! "kernel32.dll") 12
			copy-memory (names-output + external-offset) (as byte-ptr! "ExitProcess") 11
		]

		cursor: names-output + names-size
		finish: output + code-offset
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
		code: output + code-offset
		next-instruction: 1
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			written: compile-function ir-function function-instructions
				stack-types stack-flags stack-kinds import-refs references
				parameter-data function-data import-data global-data type-data member-data
				(output + IMAGE_HEADER_SIZE) strings
				(code + image-function/code-offset)
				header/type-count header/function-count header/import-count
				header/global-count strings-size image-function/code-offset
				function-code-size image-function/code-size exit-reference-id current-entry?
				:global-reference-count :literal-size (function-frames + (id - 1))
			if written <> image-function/code-size [return release scratch INVALID_IR]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]

		if literal-size > 0 [copy-memory (code + function-code-size) strings literal-size]
		cursor: code + code-size
		data-output: output + data-offset
		while [cursor < data-output][cursor/1: as byte! 0 cursor: cursor + 1]
		finish: data-output + image-data-size
		cursor: data-output
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]

		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
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
				image-global/data-size = 4 [x64-encoder/write-i32 cursor ir-global/low]
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
