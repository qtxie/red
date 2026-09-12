Red/System [
	Title: "Typed postfix RSIR to Apple AArch64 code generator"
	File:  %arm64-codegen.reds
]

#include %arm64-encoder.reds
#include %codegen-rsir-reader.reds

arm64-function-scratch!: alias struct! [
	homes           [int-ptr!]
	storage-types   [int-ptr!]
	storage-kinds   [int-ptr!]
	stack-types     [int-ptr!]
	stack-kinds     [int-ptr!]
	stack-locations [int-ptr!]
	stack-low       [int-ptr!]
	stack-high      [int-ptr!]
	stack-flags     [int-ptr!]
	plan-depths     [int-ptr!]
	entry-spill-bases  [int-ptr!]
	entry-spill-limits [int-ptr!]
	instruction-offsets [int-ptr!]
	instruction-depths  [int-ptr!]
	catch-depths        [int-ptr!]
	entry-types         [int-ptr!]
	entry-kinds         [int-ptr!]
	entry-flags         [int-ptr!]
	control-uses        [int-ptr!]
	result-offsets      [int-ptr!]
	instruction-effects [int-ptr!]
	switch-effect-links [int-ptr!]
	switch-effect-users [int-ptr!]
	global-homes    [int-ptr!]
]

arm64-function-plan!: alias struct! [
	storage-count   [integer!]
	home-count      [integer!]
	home-mask       [integer!]
	float-home-count [integer!]
	frame-home-count [integer!]
	spill-count     [integer!]
	has-call        [integer!]
	unwind          [integer!]
	catch-capacity  [integer!]
	frame-prefix-count [integer!]
	hidden-return-offset [integer!]
	tag-offset      [integer!]
	frame-anchor-register [integer!]
	frame-anchor-offset [integer!]
	visible-frame-offset [integer!]
	unwind-fixup    [integer!]
	frame-allocation [integer!]
]

arm64-layout-state!: alias struct! [
	sizes          [int-ptr!]
	alignments     [int-ptr!]
	member-offsets [int-ptr!]
]

arm64-abi-location!: alias struct! [
	class          [integer!]
	register-index [integer!]
	register-count [integer!]
	stack-offset   [integer!]
	copy-offset    [integer!]
	size           [integer!]
	alignment      [integer!]
	hfa-width      [integer!]
	stack-size     [integer!]
	total-size     [integer!]
]

arm64-reference-state!: alias struct! [
	counts    [int-ptr!]
	starts    [int-ptr!]
	cursors   [int-ptr!]
	references [int-ptr!]
]

arm64-codegen: context [
	IMAGE_HEADER_SIZE:   52
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   28
	IMAGE_IMPORT_SIZE:   24
	IMAGE_EXPORT_SIZE:   12
	BITMAP_SIZE:         16

	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_GLOBAL_SIZE:      24
	RSIR_FUNCTION_SIZE:    36
	RSIR_EXPORT_SIZE:      12
	RSIR_PARAMETER_SIZE:    8
	RSIR_INITIALIZER_SIZE: 16
	RSIR_INSTRUCTION_SIZE: 16
	RSIR_SWITCH_SIZE:      12

	CDECL:        1
	STDCALL:      2
	RETURN_VALUE: 4
	VARIADIC:     8
	TYPED:       16
	CUSTOM:      32
	OBJC:       128
	CALLBACK:    64
	RED_INTERNAL: 512
	CALLABLE_FLAGS: 1023
	CALL_SHAPE_FLAGS: RETURN_VALUE + VARIADIC + TYPED + CUSTOM + OBJC
	INLINE:       1
	PROTECTED:    2
	TAGGED_UNION: 1

	SCALAR_INITIALIZER:  1
	ADDRESS_INITIALIZER: 2
	BYTES_INITIALIZER:   3
	DATA_REFERENCE_TAG:   80000000h
	RODATA_REFERENCE_TAG: C0000000h
	REFERENCE_OFFSET_MASK: 3FFFFFFFh
	last-compile-ordinal: 0
	last-plan-ordinal: 0
	compiler-frame-register: arm64-encoder/FP
	compiler-frame-active?: false
	VISIBLE_FRAME_OFFSET: -32

	EFFECT_RETURNS: 1
	EFFECT_LIVE: 2
	EFFECT_FUNCTION_START: 4
	EFFECT_RESUMES: 8

	OP_LITERAL: 1
	OP_ADDRESS: 3
	OP_LOAD:    4
	OP_SET:     5
	OP_MEMBER:  6
	OP_CALL:    7
	OP_CAST:    8
	OP_SIZE:    9
	OP_NATIVE: 10
	OP_RETURN:  11
	OP_DROP:    12
	OP_UNARY:  14
	OP_BINARY:  15
	OP_JUMP:    16
	OP_BRANCH:  17
	OP_SWITCH:  18
	OP_FAIL:    19
	OP_REFERENCE: 20
	OP_INDEX:     21
	OP_TAG:       22
	OP_OVERFLOW:  23
	OP_CATCH:     24
	OP_END_CATCH: 25
	OP_THROW:     26
	OP_ENTRY:     27
	OP_SUB_CALL:  28
	OP_SUB_RETURN: 29

	NOT_OPERATION:           1
	ADD_OPERATION:           1
	SUBTRACT_OPERATION:      2
	MULTIPLY_OPERATION:      3
	DIVIDE_OPERATION:        4
	REMAINDER_OPERATION:     5
	MODULO_OPERATION:        6
	SHIFT_LEFT_OPERATION:    7
	SHIFT_RIGHT_OPERATION:   8
	SHIFT_LOGICAL_OPERATION: 9
	OR_OPERATION:           10
	XOR_OPERATION:          11
	AND_OPERATION:          12
	EQUAL_OPERATION:        13
	NOT_EQUAL_OPERATION:    14
	GREATER_OPERATION:      15
	LESS_OPERATION:         16
	GREATER_EQUAL_OPERATION: 17
	LESS_EQUAL_OPERATION:    18

	LOCAL_ADDRESS:    1
	GLOBAL_ADDRESS:   2
	IMPORT_ADDRESS:   3
	FUNCTION_ADDRESS: 4

	STACK_TOP_NATIVE:           1
	STACK_PUSH_NATIVE:          2
	STACK_POP_NATIVE:           3
	STACK_FRAME_NATIVE:         4
	STACK_TOP_SET_NATIVE:       5
	STACK_FRAME_SET_NATIVE:     6
	STACK_ALIGN_NATIVE:         7
	STACK_ALLOCATE_NATIVE:      8
	STACK_ALLOCATE_ZERO_NATIVE: 9
	STACK_FREE_NATIVE:         10
	STACK_PUSH_ALL_NATIVE:     11
	STACK_POP_ALL_NATIVE:      12
	PROGRAM_COUNTER_NATIVE:    13
	CPU_REGISTER_NATIVE:       14
	CPU_REGISTER_SET_NATIVE:   15
	CPU_OVERFLOW_NATIVE:       16
	ATOMIC_FENCE_NATIVE:       17
	ATOMIC_LOAD_NATIVE:        18
	ATOMIC_STORE_NATIVE:       19
	ATOMIC_CAS_NATIVE:         20
	ATOMIC_MATH_NATIVE:        21
	ATOMIC_OLD:                 8
	LOG_B_NATIVE:              22
	STACK_ALL_SIZE:           784
	CATCH_FLAG:                256
	SYSCALL_FLAG:              1024
	SYSCALL_ID_SHIFT:          11

	; A call's parameter descriptors live in the parameter table for declared
	; functions and imports, and in the type table's member rows for the
	; function type a call through a pointer names.
	PARAMETER_TABLE: 0
	MEMBER_TABLE:    1

	VALUE: 1
	PLACE: 2

	LOCATION_IMMEDIATE: 1
	LOCATION_REGISTER:  2
	LOCATION_FLAGS:     3
	LOCATION_FRAME:     4

	STORAGE_REGISTER: 1
	STORAGE_FRAME:    2

	ABI_GPR:      1
	ABI_SIMD:     2
	ABI_STACK:    3
	ABI_INDIRECT: 4

	FIRST_HOME_REGISTER: 19
	HOME_REGISTER_COUNT: 10
	FIRST_TEMP_REGISTER: 9
	TEMP_REGISTER_COUNT: 7
	FIRST_FLOAT_HOME_REGISTER: 8
	FLOAT_HOME_REGISTER_COUNT: 8
	FIRST_FLOAT_TEMP_REGISTER: 16
	FLOAT_TEMP_REGISTER_COUNT: 8
	FLOAT_SCRATCH_REGISTER: 31

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

	canonical-type: func [
		ref [integer!]
		view [rsir-view!]
		return: [integer!]
		/local type [rsir-type!] steps [integer!]
	][
		if ref < 0 [return either ref = -15 [-2][ref]]
		steps: 0
		while [steps < view/header/type-count][
			if any [ref <= 0 ref > view/header/type-count][return 0]
			type: as rsir-type! (view/types + ((ref - 1) * RSIR_TYPE_SIZE))
			unless type/kind = -1 [return ref]
			ref: type/target
			if ref < 0 [return either ref = -15 [-2][ref]]
			steps: steps + 1
		]
		0
	]

	type-kind: func [
		ref [integer!]
		view [rsir-view!]
		return: [integer!]
		/local base [integer!] type [rsir-type!]
	][
		base: canonical-type ref view
		if base < 0 [return 0 - base]
		if base = 0 [return 0]
		type: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
		type/kind
	]

	valid-type-ref?: func [ref [integer!] view [rsir-view!] return: [logic!]][
		any [
			all [ref > 0 ref <= view/header/type-count]
			all [ref < 0 ref >= -15]
		]
	]

	integer-pointer-type: func [
		view [rsir-view!]
		return: [integer!]
		/local id [integer!] type [rsir-type!]
	][
		id: 1
		while [id <= view/header/type-count][
			type: as rsir-type! (view/types + ((id - 1) * RSIR_TYPE_SIZE))
			if all [
				type/kind = -6
				(canonical-type type/target view) = -5
			][return id]
			id: id + 1
		]
		0
	]

	cpu-register-id: func [
		name [byte-ptr!]
		size [integer!]
		width [int-ptr!]
		return: [integer!]
		/local index digit number [integer!]
	][
		if any [null? name null? width size < 2 size > 3][return -1]
		width/1: 0
		if all [
			size = 2
			name/1 = as byte! 73h
			name/2 = as byte! 70h
		][
			width/1: 8
			return arm64-encoder/SP
		]
		unless any [
			name/1 = as byte! 78h
			name/1 = as byte! 77h
		][return -1]
		number: 0
		index: 2
		while [index <= size][
			digit: (as integer! name/index) - 48
			if any [digit < 0 digit > 9][return -1]
			number: (number * 10) + digit
			index: index + 1
		]
		if number > 30 [return -1]
		width/1: either name/1 = as byte! 78h [8][4]
		number
	]

	available-home-register: func [
		reserved used [integer!]
		return: [integer!]
		/local index mask [integer!]
	][
		index: 0
		mask: reserved or used
		while [all [
			index < HOME_REGISTER_COUNT
			(mask and (1 << index)) <> 0
		]][index: index + 1]
		either index = HOME_REGISTER_COUNT [-1][FIRST_HOME_REGISTER + index]
	]

	startup-registers-used?: func [
		view [rsir-view!]
		return: [logic!]
		/local instruction [rsir-instruction!]
			index register-width register-id [integer!]
	][
		index: 0
		while [index < view/header/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ (index * RSIR_INSTRUCTION_SIZE))
			if all [
				instruction/op = OP_NATIVE
				any [
					instruction/a = CPU_REGISTER_NATIVE
					instruction/a = CPU_REGISTER_SET_NATIVE
				]
				instruction/b >= 0 instruction/c > 0
				instruction/c <= view/strings-size
				instruction/b <= (view/strings-size - instruction/c)
			][
				register-width: 0
				register-id: cpu-register-id
					(view/strings + instruction/b) instruction/c :register-width
				if any [register-id = 19 register-id = 20][return true]
			]
			index: index + 1
		]
		false
	]

	value-width: func [
		ref [integer!]
		view [rsir-view!]
		return: [integer!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		case [
			any [
				kind = -2 kind = -3 kind = -4
				kind = -5 kind = -6 kind = -7
			][8]
			kind <= 0 [0]
			kind <= 2 [1]
			kind <= 4 [2]
			any [kind = 5 kind = 6 kind = 9 kind = 11][4]
			any [
				kind = 7 kind = 8 kind = 10 kind = 12
				kind = 13 kind = 14 kind = 16
			][8]
			kind = 15 [1]
			true [0]
		]
	]

	reference-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		any [
			kind = 12 kind = 13 kind = 14 kind = 16
			kind = -2 kind = -3 kind = -4 kind = -6 kind = -7
		]
	]

	address-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		any [
			kind = 12 kind = 13 kind = 16
			kind = -2 kind = -3 kind = -6 kind = -7
		]
	]

	address-integer-kind?: func [kind [integer!] return: [logic!]][
		any [kind = 5 kind = 6 kind = 7 kind = 8]
	]

	compatible-types?: func [
		expected actual [integer!]
		view [rsir-view!]
		return: [logic!]
		/local left right left-kind right-kind target [integer!]
			left-record right-record [rsir-type!]
	][
		if expected = actual [return true]
		left: canonical-type expected view
		right: canonical-type actual view
		if any [left = 0 right = 0][return false]
		if left = right [return true]
		left-kind: type-kind left view
		right-kind: type-kind right view
		if any [left-kind = 14 right-kind = 14][
			return all [reference-type? left view reference-type? right view]
		]
		if all [
			any [left = -12 right = -12]
			any [left-kind = 12 left-kind = -6]
			any [right-kind = 12 right-kind = -6]
		][return true]
		if all [right-kind = -7 right > 0][
			right-record: as rsir-type! (view/types
				+ ((right - 1) * RSIR_TYPE_SIZE))
			target: 0
			case [
				left-kind = 13 [target: -15]
				all [left-kind = -6 left > 0][
					left-record: as rsir-type! (view/types
						+ ((left - 1) * RSIR_TYPE_SIZE))
					target: left-record/target
				]
				true [0]
			]
			if all [
				target <> 0
				(canonical-type target view)
					= (canonical-type right-record/target view)
			][return true]
		]
		all [left-kind > 0 left-kind = right-kind]
	]

	function-call-shape: func [flags [integer!] return: [integer!]
		/local shape [integer!]
	][
		shape: flags and CALL_SHAPE_FLAGS
		if all [
			(shape and VARIADIC) <> 0
			(flags and CDECL) <> 0
		][shape: shape or CDECL]
		shape
	]

	; Function types are structural: distinct type rows are compatible when their
	; calling convention, result, parameter flags, and recursively nested types
	; agree. Keep visited pairs so recursive callback signatures terminate.
	function-types-compatible?: func [
		expected actual [integer!]
		view [rsir-view!]
		return: [logic!]
		/local memory [byte-ptr!]
			pair-left pair-right next-left next-right [int-ptr!]
			capacity count cursor pair-id id left right left-kind right-kind [integer!]
			left-type right-type [rsir-type!]
			left-member right-member [rsir-member!]
	][
		capacity: view/header/type-count
		if capacity <= 0 [return false]
		memory: allocate capacity * 8
		if null? memory [return false]
		pair-left: as int-ptr! memory
		pair-right: pair-left + capacity
		pair-left/1: expected
		pair-right/1: actual
		count: 1
		cursor: 1
		while [cursor <= count][
			left: canonical-type pair-left/cursor view
			right: canonical-type pair-right/cursor view
			if any [left <= 0 right <= 0][
						free memory
						return false
					]
			if left <> right [
				left-kind: type-kind left view
				right-kind: type-kind right view
				unless all [left-kind = -4 right-kind = -4][
					free memory
					return false
				]
				left-type: as rsir-type! (view/types + ((left - 1) * RSIR_TYPE_SIZE))
					right-type: as rsir-type! (view/types + ((right - 1) * RSIR_TYPE_SIZE))
					if any [
						(function-call-shape left-type/flags)
							<> (function-call-shape right-type/flags)
						left-type/member-count <> right-type/member-count
						all [
							any [left-type/target = 0 right-type/target = 0]
							left-type/target <> right-type/target
						]
					][
						free memory
						return false
					]
					id: -1
					while [id < left-type/member-count][
						either id < 0 [
							next-left: :left-type/target
							next-right: :right-type/target
						][
							left-member: as rsir-member! (view/members
								+ ((left-type/first-member + id) * RSIR_MEMBER_SIZE))
							right-member: as rsir-member! (view/members
								+ ((right-type/first-member + id) * RSIR_MEMBER_SIZE))
							if left-member/flags <> right-member/flags [
								free memory
								return false
							]
							next-left: :left-member/type
							next-right: :right-member/type
						]
						if next-left/1 <> 0 [
							unless compatible-types? next-left/1 next-right/1 view [
								left-kind: type-kind next-left/1 view
								right-kind: type-kind next-right/1 view
								unless all [left-kind = -4 right-kind = -4][
									free memory
									return false
								]
								left: canonical-type next-left/1 view
								right: canonical-type next-right/1 view
								pair-id: 1
								while [all [pair-id <= count any [
									pair-left/pair-id <> left pair-right/pair-id <> right
								]]][pair-id: pair-id + 1]
								if pair-id > count [
									if count = capacity [
										free memory
										return false
									]
									count: count + 1
									pair-left/count: left
									pair-right/count: right
								]
							]
						]
						id: id + 1
					]
			]
			cursor: cursor + 1
		]
		free memory
		true
	]

	merged-type: func [
		left right [integer!]
		view [rsir-view!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		if compatible-types? left right view [
			left-kind: type-kind left view
			if left-kind = 14 [
				right-kind: type-kind right view
				if reference-type? right view [return -14]
			]
			return left
		]
		left-kind: type-kind left view
		right-kind: type-kind right view
		either all [
			left-kind = right-kind
			any [left-kind = -6 left-kind = -2 left-kind = -3]
		][left][0]
	]

	integer-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		all [kind >= 1 kind <= 8]
	]

	float-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		any [kind = 9 kind = 10]
	]

	available-temp-register: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth [integer!]
		floating? [logic!]
		reusable-slot [integer!]
		return: [integer!]
		/local slot register limit [integer!] used? [logic!]
	][
		register: either floating? [FIRST_FLOAT_TEMP_REGISTER][FIRST_TEMP_REGISTER]
		limit: either floating? [FLOAT_TEMP_REGISTER_COUNT][TEMP_REGISTER_COUNT]
		limit: register + limit
		while [register < limit][
			used?: false
			slot: 1
			while [all [slot <= depth not used?]][
				if all [
					slot <> reusable-slot
					scratch/stack-locations/slot = LOCATION_REGISTER
				][
					used?: all [
						scratch/stack-low/slot = register
						either floating? [
							all [scratch/stack-kinds/slot = VALUE
								float-type? scratch/stack-types/slot view]
						][
							any [
								scratch/stack-kinds/slot = PLACE
								all [scratch/stack-kinds/slot = VALUE
									not float-type? scratch/stack-types/slot view]
							]
						]
					]
				]
				slot: slot + 1
			]
			if not used? [return register]
			register: register + 1
		]
		-1
	]

	typed-runtime-id?: func [id [integer!] return: [logic!]][
		any [
			all [id >= 1 id <= 17]
			id >= 1000
		]
	]

	float-common-ref: func [
		left right [integer!]
		view [rsir-view!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		left-kind: type-kind left view
		right-kind: type-kind right view
		unless all [
			any [left-kind = 9 left-kind = 10]
			any [right-kind = 9 right-kind = 10]
		][return 0]
		either any [left-kind = 9 right-kind = 9][-9][-10]
	]

	integer-kind-widens?: func [
		source-kind target-kind [integer!]
		return: [logic!]
		/local source-rank target-rank [integer!]
			source-signed? target-signed? [logic!]
	][
		if any [
			source-kind < 1 source-kind > 8
			target-kind < 1 target-kind > 8
		][return false]
		source-rank: (source-kind + 1) / 2
		target-rank: (target-kind + 1) / 2
		if target-rank <= source-rank [return false]
		source-signed?: (source-kind and 1) = 1
		target-signed?: (target-kind and 1) = 1
		any [
			source-signed? = target-signed?
			all [not source-signed? target-signed?]
		]
	]

	signed-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		any [kind = 1 kind = 3 kind = 5 kind = 7]
	]

	comparison-condition: func [
		operation [integer!]
		signed? [logic!]
		return: [integer!]
	][
		case [
			operation = EQUAL_OPERATION [arm64-encoder/EQ]
			operation = NOT_EQUAL_OPERATION [arm64-encoder/NE]
			operation = GREATER_OPERATION [
				either signed? [arm64-encoder/GT][arm64-encoder/HI]
			]
			operation = LESS_OPERATION [
				either signed? [arm64-encoder/LT][arm64-encoder/CC]
			]
			operation = GREATER_EQUAL_OPERATION [
				either signed? [arm64-encoder/GE][arm64-encoder/CS]
			]
			operation = LESS_EQUAL_OPERATION [
				either signed? [arm64-encoder/LE][arm64-encoder/LS]
			]
			true [-1]
		]
	]

	float-comparison-condition: func [operation [integer!] return: [integer!]][
		case [
			operation = EQUAL_OPERATION [arm64-encoder/EQ]
			operation = NOT_EQUAL_OPERATION [arm64-encoder/NE]
			operation = GREATER_OPERATION [arm64-encoder/GT]
			operation = LESS_OPERATION [arm64-encoder/MI]
			operation = GREATER_EQUAL_OPERATION [arm64-encoder/GE]
			operation = LESS_EQUAL_OPERATION [arm64-encoder/LS]
			true [-1]
		]
	]

	call-parameter: func [
		view [rsir-view!]
		source first ordinal [integer!]
		return: [rsir-parameter!]
	][
		; Member rows and parameter rows share the (type, flags) layout.
		either source = MEMBER_TABLE [
			as rsir-parameter! (view/members
				+ ((first + ordinal - 1) * RSIR_MEMBER_SIZE))
		][
			as rsir-parameter! (view/parameters
				+ ((first + ordinal - 1) * RSIR_PARAMETER_SIZE))
		]
	]

	abi-parameter-register: func [
		view [rsir-view!]
		source first-parameter ordinal [integer!]
		floating? [logic!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			id index kind [integer!] parameter-floating? [logic!]
	][
		if ordinal <= 0 [return -1]
		id: 1
		index: 0
		while [id <= ordinal][
			parameter: call-parameter view source first-parameter id
			kind: type-kind parameter/type view
			parameter-floating?: any [kind = 9 kind = 10]
			if parameter-floating? = floating? [
				if id = ordinal [return index]
				index: index + 1
			]
			id: id + 1
		]
		-1
	]

	; Return a fixed parameter's outgoing stack offset, -1 when it is passed
	; in a register, or the total stack size when ordinal is zero.
	abi-parameter-stack: func [
		view [rsir-view!]
		source first-parameter parameter-count ordinal [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			id width kind integer-count float-count register-index offset next
				[integer!]
			floating? [logic!]
	][
		if any [parameter-count < 0 ordinal < 0 ordinal > parameter-count][
			return -2
		]
		id: 1
		integer-count: 0
		float-count: 0
		offset: 0
		while [id <= parameter-count][
			parameter: call-parameter view source first-parameter id
			if parameter/flags <> 0 [return -2]
			width: value-width parameter/type view
			kind: type-kind parameter/type view
			unless any [width = 1 width = 2 width = 4 width = 8][return -2]
			floating?: any [kind = 9 kind = 10]
			either floating? [
				register-index: float-count
				float-count: float-count + 1
			][
				register-index: integer-count
				integer-count: integer-count + 1
			]
			either register-index < 8 [
				if id = ordinal [return -1]
			][
				offset: align offset width
				if offset < 0 [return -2]
				if id = ordinal [return offset]
				if offset > (2147483647 - width)[return -2]
				next: offset + width
				offset: next
			]
			id: id + 1
		]
		either ordinal = 0 [offset][-2]
	]

	aggregate-ref?: func [
		ref [integer!]
		view [rsir-view!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		any [kind = -2 kind = -3 kind = -7]
	]

	aggregate-size: func [
		ref [integer!]
		view [rsir-view!]
		layout [arm64-layout-state!]
		return: [integer!]
		/local size alignment [integer!]
	][
		unless aggregate-ref? ref view [return 0]
		size: 0
		alignment: 0
		either layout-type ref true view layout 0 :size :alignment [size][0]
	]

	; Classify a homogeneous floating aggregate recursively. Empty aggregates,
	; unions, arrays, and mixed leaf types are not HFAs.
	classify-hfa: func [
		ref inline-flag [integer!]
		view [rsir-view!]
		depth [integer!]
		leaf-kind-out leaf-count-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			base kind id leaf-kind leaf-count member-kind member-count [integer!]
	][
		if any [depth > view/header/type-count ref = 0][return false]
		base: canonical-type ref view
		kind: type-kind base view
		if any [kind = 9 kind = 10][
			leaf-kind-out/1: kind
			leaf-count-out/1: 1
			return true
		]
		unless all [base > 0 kind = -2 inline-flag = INLINE][return false]
		record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
		if record/member-count <= 0 [return false]
		leaf-kind: 0
		leaf-count: 0
		id: 0
		while [id < record/member-count][
			member: as rsir-member! (view/members
				+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
			member-kind: 0
			member-count: 0
			unless classify-hfa member/type member/flags view (depth + 1)
				:member-kind :member-count [return false]
			if all [leaf-kind <> 0 leaf-kind <> member-kind][return false]
			leaf-kind: member-kind
			if leaf-count > (4 - member-count)[return false]
			leaf-count: leaf-count + member-count
			id: id + 1
		]
		unless all [leaf-count > 0 leaf-count <= 4][return false]
		leaf-kind-out/1: leaf-kind
		leaf-count-out/1: leaf-count
		true
	]

	; Walk the fixed parameter list from the start so register exhaustion and
	; compact stack packing make exactly the same decision at every call site.
	abi-parameter-location: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		source first-parameter parameter-count ordinal [integer!]
		location [arm64-abi-location!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			id ref flags width kind integer-count float-count offset copy-size
			size alignment hfa-kind hfa-count register-count stack-align
			stack-size [integer!]
			floating? aggregate? hfa? [logic!]
	][
		if any [parameter-count < 0 ordinal < 0 ordinal > parameter-count][
			return INVALID_IR
		]
		integer-count: 0
		float-count: 0
		offset: 0
		copy-size: 0
		id: 1
		while [id <= parameter-count][
			parameter: call-parameter view source first-parameter id
			ref: parameter/type
			flags: parameter/flags
			kind: type-kind ref view
			width: value-width ref view
			aggregate?: flags = INLINE
			floating?: all [not aggregate? any [kind = 9 kind = 10]]
			size: width
			alignment: width
			hfa-kind: 0
			hfa-count: 0
			hfa?: false
			register-count: 1
			if aggregate? [
				unless aggregate-ref? ref view [return INVALID_IR]
				size: 0
				alignment: 0
				unless layout-type ref true view layout 0 :size :alignment [
					return INVALID_IR
				]
				if any [size <= 0 alignment <= 0 alignment > 16][return UNSUPPORTED]
				hfa?: classify-hfa ref INLINE view 0 :hfa-kind :hfa-count
				register-count: either hfa? [hfa-count][either size <= 16 [(size + 7) / 8][1]]
			]
			unless aggregate? [
				unless any [width = 1 width = 2 width = 4 width = 8][return UNSUPPORTED]
			]
			location/class: 0
			location/register-index: -1
			location/register-count: register-count
			location/stack-offset: -1
			location/copy-offset: -1
			location/size: size
			location/alignment: alignment
			location/hfa-width: either hfa? [either hfa-kind = 9 [4][8]][0]
			case [
				hfa? [
					either float-count <= (8 - hfa-count) [
						location/class: ABI_SIMD
						location/register-index: float-count
						float-count: float-count + hfa-count
					][
						float-count: 8
						stack-align: alignment
						offset: align offset stack-align
						if offset < 0 [return OUTPUT_FULL]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - size)[return OUTPUT_FULL]
						offset: offset + size
					]
				]
				all [aggregate? size > 16][
					if copy-size > (2147483647 - size)[return OUTPUT_FULL]
					copy-size: align copy-size alignment
					if copy-size < 0 [return OUTPUT_FULL]
					location/copy-offset: copy-size
					copy-size: copy-size + size
					either integer-count < 8 [
						location/class: ABI_INDIRECT
						location/register-index: integer-count
						integer-count: integer-count + 1
					][
						location/class: ABI_INDIRECT
						location/register-index: -1
						offset: align offset 8
						if offset < 0 [return OUTPUT_FULL]
						location/stack-offset: offset
						if offset > (2147483647 - 8)[return OUTPUT_FULL]
						offset: offset + 8
					]
				]
				all [aggregate? size <= 16][
					either integer-count <= (8 - register-count) [
						location/class: ABI_GPR
						location/register-index: integer-count
						integer-count: integer-count + register-count
					][
						integer-count: 8
						offset: align offset alignment
						if offset < 0 [return OUTPUT_FULL]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - size)[return OUTPUT_FULL]
						offset: offset + size
					]
				]
				floating? [
					either float-count < 8 [
						location/class: ABI_SIMD
						location/register-index: float-count
						float-count: float-count + 1
					][
						offset: align offset width
						if offset < 0 [return OUTPUT_FULL]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - width)[return OUTPUT_FULL]
						offset: offset + width
					]
				]
				true [
					either integer-count < 8 [
						location/class: ABI_GPR
						location/register-index: integer-count
						integer-count: integer-count + 1
					][
						offset: align offset width
						if offset < 0 [return OUTPUT_FULL]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - width)[return OUTPUT_FULL]
						offset: offset + width
					]
				]
			]
			if id = ordinal [
				location/stack-size: -1
				location/total-size: -1
				return 0
			]
			id: id + 1
		]
		location/class: 0
		location/register-index: -1
		location/register-count: 0
		location/stack-offset: -1
		location/copy-offset: -1
		location/size: 0
		location/alignment: 1
		location/hfa-width: 0
		stack-size: align offset 16
		if stack-size < 0 [return OUTPUT_FULL]
		location/stack-size: stack-size
		copy-size: align copy-size 16
		if copy-size < 0 [return OUTPUT_FULL]
		if stack-size > (2147483647 - copy-size)[return OUTPUT_FULL]
		location/total-size: stack-size + copy-size
		0
	]

	; Argument setup uses X16/X17 as scratch. Expression temporaries and
	; callee-saved homes can therefore remain live across it.
	call-safe-register?: func [register [integer!] return: [logic!]][
		any [
			all [
				register >= FIRST_TEMP_REGISTER
				register < (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
			]
			all [
				register >= FIRST_HOME_REGISTER
				register < (FIRST_HOME_REGISTER + HOME_REGISTER_COUNT)
			]
		]
	]

	volatile-register-value?: func [
		ref register [integer!]
		view [rsir-view!]
		return: [logic!]
	][
		either float-type? ref view [
			any [register < FIRST_FLOAT_HOME_REGISTER
				register >= FIRST_FLOAT_TEMP_REGISTER]
		][register < FIRST_HOME_REGISTER]
	]

	fold-integer32: func [
		operation left right [integer!]
		result [int-ptr!]
		return: [logic!]
	][
		case [
			operation = ADD_OPERATION [result/1: left + right true]
			operation = SUBTRACT_OPERATION [result/1: left - right true]
			operation = MULTIPLY_OPERATION [result/1: left * right true]
			operation = OR_OPERATION [result/1: left or right true]
			operation = XOR_OPERATION [result/1: left xor right true]
			operation = AND_OPERATION [result/1: left and right true]
			true [false]
		]
	]

	normalize-integer32: func [
		value width signed [integer!]
		result [int-ptr!]
		return: [logic!]
	][
		case [
			width = 1 [
				value: value and FFh
				if all [signed = 1 value >= 128][value: value - 256]
			]
			width = 2 [
				value: value and FFFFh
				if all [signed = 1 value >= 32768][value: value - 65536]
			]
			width = 4 [0]
			true [return false]
		]
		result/1: value
		true
	]

	compatible-literal?: func [
		expected actual [integer!]
		view [rsir-view!]
		return: [logic!]
	][
		compatible-types? expected actual view
	]

	implicitly-compatible?: func [
		expected actual [integer!]
		literal? [logic!]
		view [rsir-view!]
		return: [logic!]
		/local expected-kind actual-kind [integer!]
	][
		if compatible-types? expected actual view [return true]
		if all [
			(type-kind expected view) = -4
			(type-kind actual view) = -4
			function-types-compatible? expected actual view
		][return true]
		expected-kind: type-kind expected view
		actual-kind: type-kind actual view
		any [
			integer-kind-widens? actual-kind expected-kind
			all [literal? expected-kind = 9 actual-kind = 10]
		]
	]

	scalar-cast-compatible?: func [
		source target [integer!]
		view [rsir-view!]
		return: [logic!]
		/local source-kind target-kind source-width target-width [integer!]
	][
		source-kind: type-kind source view
		target-kind: type-kind target view
		source-width: value-width source view
		target-width: value-width target view
		if any [
			source-width = 0 source-width > 8
			target-width = 0 target-width > 8
		][return false]
		if any [
			source-kind = 9 source-kind = 10
			target-kind = 9 target-kind = 10
		][
			return any [
				all [
					any [source-kind = 9 source-kind = 10]
					any [target-kind = 9 target-kind = 10]
				]
				all [source-kind = 5 any [target-kind = 9 target-kind = 10]]
				all [any [source-kind = 9 source-kind = 10] target-kind = 5]
			]
		]
		any [
			any [
				all [integer-type? source view integer-type? target view]
				all [
					source-kind = 11
					target-kind = 11
					source-width = target-width
				]
			]
			all [source-kind = 11 any [integer-type? target view target-kind = 11]]
			all [target-kind = 11 any [
				integer-type? source view
				reference-type? source view
				source-kind = -2 source-kind = -3
			]]
			all [reference-type? source view reference-type? target view]
			all [
				reference-type? source view
				address-integer-kind? target-kind
			]
			all [
				address-integer-kind? source-kind
				reference-type? target view
			]
		]
	]

	tag-width: func [count [integer!] return: [integer!]][
		case [
			count <= 0 [0]
			count <= 255 [1]
			count <= 65535 [2]
			true [4]
		]
	]

	; A tagged union stores its variant number in the leading tag field, so a
	; VARIANT? test or a SWITCH selector only needs that field's width.
	union-tag-width: func [
		ref [integer!]
		view [rsir-view!]
		return: [integer!]
		/local base [integer!] record [rsir-type!]
	][
		base: canonical-type ref view
		if base <= 0 [return 0]
		record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
		unless all [record/kind = -3 record/flags = TAGGED_UNION][return 0]
		tag-width record/member-count
	]

	layout-type: func [
		ref [integer!]
		inline? [logic!]
		view [rsir-view!]
		layout [arm64-layout-state!]
		depth [integer!]
		size-out align-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			cache offset-slot [int-ptr!]
			kind id member-size member-align size alignment tag-size
			payload-offset element-size element-align [integer!]
			cached? [logic!]
	][
		if any [ref = 0 depth > view/header/type-count][return false]
		if ref = -15 [ref: -2]
		cache: as int-ptr! 0
		cached?: false
		kind: 0
		either ref < 0 [
			kind: 0 - ref
		][
			if ref > view/header/type-count [return false]
			record: as rsir-type! (view/types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			if inline? [
				cache: layout/sizes + (ref - 1)
				if cache/1 <> 0 [
					if cache/1 < 0 [return false]
					size-out/1: cache/1
					align-out/1: layout/alignments/ref
					return true
				]
				cache/1: -1
				cached?: true
			]
		]

		size: 0
		alignment: 1
		case [
			kind > 0 [
				size: case [
					kind <= 2 [1]
					kind <= 4 [2]
					any [kind = 5 kind = 6 kind = 9 kind = 11][4]
					any [
						kind = 7 kind = 8 kind = 10 kind = 12
						kind = 13 kind = 14 kind = 16
					][8]
					true [0]
				]
				if size = 0 [return false]
				alignment: size
			]
			kind = -1 [
				unless layout-type record/target inline? view layout (depth + 1)
					:size :alignment [return false]
			]
			any [kind = -4 kind = -5 kind = -6][
				size: 8
				alignment: 8
			]
			kind = -7 [
				unless all [
					record/member-count > 0
					any [
						record/flags = 1 record/flags = 2
						record/flags = 4 record/flags = 8
					]
				][return false]
				either inline? [
					element-size: 0
					element-align: 0
					unless layout-type record/target false view layout (depth + 1)
						:element-size :element-align [return false]
					unless element-size = record/flags [return false]
					if record/member-count > (2147483647 / record/flags)[return false]
					size: record/member-count * record/flags
					alignment: record/flags
				][
					size: 8
					alignment: 8
				]
			]
			any [kind = -2 kind = -3][
				either inline? [
					size: 0
					alignment: 1
					id: 0
					while [id < record/member-count][
						member: as rsir-member! (view/members
							+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
						member-size: 0
						member-align: 0
						unless layout-type member/type (member/flags = INLINE)
							view layout (depth + 1) :member-size :member-align [
							return false
						]
						if member-align > alignment [alignment: member-align]
						either kind = -2 [
							size: align size member-align
							if any [
								size < 0
								size > (2147483647 - member-size)
							][return false]
							offset-slot: (layout/member-offsets
								+ record/first-member) + id
							offset-slot/1: size
							size: size + member-size
						][
							if member-size > size [size: member-size]
							offset-slot: (layout/member-offsets
								+ record/first-member) + id
							offset-slot/1: 0
						]
						id: id + 1
					]
					if all [kind = -3 record/flags = TAGGED_UNION][
						tag-size: tag-width record/member-count
						if tag-size = 0 [return false]
						payload-offset: align tag-size alignment
						if any [
							payload-offset < 0
							payload-offset > (2147483647 - size)
						][return false]
						size: payload-offset + size
						if tag-size > alignment [alignment: tag-size]
						offset-slot: layout/member-offsets + record/first-member
						id: 0
						while [id < record/member-count][
							offset-slot/1: payload-offset
							offset-slot: offset-slot + 1
							id: id + 1
						]
					]
					size: align size alignment
					if size < 0 [return false]
				][
					size: 8
					alignment: 8
				]
			]
			true [return false]
		]
		if cached? [
			cache/1: size
			layout/alignments/ref: alignment
		]
		size-out/1: size
		align-out/1: alignment
		true
	]

	layout-member: func [
		ref index [integer!]
		view [rsir-view!]
		layout [arm64-layout-state!]
		type-out flags-out offset-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			offset-slot [int-ptr!] base kind size alignment [integer!]
	][
		base: canonical-type ref view
		if any [base <= 0 index < 0][return false]
		record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
		kind: record/kind
		unless any [kind = -2 kind = -3][return false]
		if index >= record/member-count [return false]
		size: 0
		alignment: 0
		unless layout-type base true view layout 0 :size :alignment [return false]
		member: as rsir-member! (view/members
			+ ((record/first-member + index) * RSIR_MEMBER_SIZE))
		offset-slot: (layout/member-offsets + record/first-member) + index
		type-out/1: member/type
		flags-out/1: member/flags
		offset-out/1: offset-slot/1
		true
	]

	logical-size: func [
		ref [integer!]
		view [rsir-view!]
		layout [arm64-layout-state!]
		return: [integer!]
		/local base kind size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref view
		if base = 0 [return 0]
		kind: type-kind base view
		; Array values use their element count as the Red SIZE? result.
		if all [base > 0 kind = -7][
			record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
			return record/member-count
		]
		size: 0
		alignment: 0
		either layout-type ref true view layout 0 :size :alignment [size][0]
	]

	pointee-type: func [
		ref [integer!]
		view [rsir-view!]
		result [int-ptr!]
		return: [logic!]
		/local base kind [integer!] record [rsir-type!]
	][
		base: canonical-type ref view
		if base = 0 [return false]
		kind: type-kind base view
		if kind = 13 [result/1: -15 return true]
		if any [kind = -2 kind = -3][result/1: base return true]
		unless all [any [kind = -6 kind = -7] base > 0][return false]
		record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
		result/1: record/target
		valid-type-ref? result/1 view
	]

	pointer-stride: func [
		ref [integer!]
		view [rsir-view!]
		layout [arm64-layout-state!]
		return: [integer!]
		/local base kind size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref view
		if base = 0 [return 0]
		kind: type-kind base view
		if any [kind = 12 kind = 13 kind = 16][return 1]
		size: 0
		alignment: 0
		case [
			kind = -7 [
				record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
				size: record/flags
				unless any [size = 1 size = 2 size = 4 size = 8][return 0]
			]
			kind = -6 [
				record: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
				unless layout-type record/target true view layout 0 :size :alignment [
					return 0
				]
			]
			any [kind = -2 kind = -3][
				unless layout-type base true view layout 0 :size :alignment [return 0]
			]
			true [return 0]
		]
		size
	]

	static-address-representation-compatible?: func [
		target source [integer!]
		view [rsir-view!]
		return: [logic!]
		/local target-kind source-kind [integer!]
	][
		if compatible-types? target source view [return true]
		target-kind: type-kind target view
		source-kind: type-kind source view
		case [
			any [source-kind = 12 source-kind = 13 source-kind = -6][
				any [
					address-integer-kind? target-kind
					target-kind = 12 target-kind = 13
					target-kind = -2 target-kind = -3 target-kind = -4
					target-kind = -6 target-kind = -7
				]
			]
			source-kind = -4 [
				any [
					address-integer-kind? target-kind
					target-kind = 12
					target-kind = -4 target-kind = -6
				]
			]
			true [false]
		]
	]

	valid-static-address-initializer?: func [
		initializer [rsir-initializer!]
		expected owner [integer!]
		view [rsir-view!]
		return: [logic!]
		/local target [rsir-global!] kind pointee source [integer!]
	][
		if initializer/kind <> ADDRESS_INITIALIZER [return false]
		source: either initializer/c = 0 [expected][initializer/c]
		if all [
			initializer/c <> 0
			any [
				not valid-type-ref? source view
				not static-address-representation-compatible? expected source view
			]
		][return false]
		case [
			initializer/a = GLOBAL_ADDRESS [
				if any [
					initializer/b <= 0
					initializer/b > view/header/global-count
					initializer/b = owner
				][return false]
				target: as rsir-global! (view/globals
					+ ((initializer/b - 1) * RSIR_GLOBAL_SIZE))
				if source = 0 [return true]
				if compatible-types? source target/type view [return true]
				pointee: 0
				unless pointee-type source view :pointee [return false]
				compatible-types? pointee target/type view
			]
			initializer/a = FUNCTION_ADDRESS [
				if any [
					initializer/b <= 0
					initializer/b > view/header/function-count
				][return false]
				kind: type-kind source view
				any [source = 0 kind = 12 kind = -4 kind = -5 kind = -6]
			]
			true [false]
		]
	]

	power-shift: func [value [integer!] return: [integer!]][
		case [
			value = 1 [0]
			value = 2 [1]
			value = 4 [2]
			value = 8 [3]
			value = 16 [4]
			true [-1]
		]
	]

	write-static-scalar: func [
		target [byte-ptr!]
		width low high [integer!]
		return: [logic!]
	][
		case [
			width = 1 [target/1: as byte! low]
			width = 2 [
				target/1: as byte! low
				target/2: as byte! (low >>> 8)
			]
			width = 4 [arm64-encoder/write-i32 target low]
			width = 8 [
				arm64-encoder/write-i32 target low
				arm64-encoder/write-i32 (target + 4) high
			]
			true [return false]
		]
		true
	]

	record-reference: func [
		target-id offset [integer!]
		state [arm64-reference-state!]
		return: [integer!]
		/local reference-id [integer!]
	][
		if target-id <= 0 [return INVALID_IR]
		either null? state/references [
			if state/counts/target-id = 2147483647 [return OUTPUT_FULL]
			state/counts/target-id: state/counts/target-id + 1
		][
			if state/cursors/target-id >= state/counts/target-id [return INVALID_IR]
			reference-id: state/starts/target-id + state/cursors/target-id
			state/references/reference-id: offset
			state/cursors/target-id: state/cursors/target-id + 1
		]
		0
	]

	resolve-call: func [
		target signature [integer!]
		view [rsir-view!]
		return-ref-out first-parameter-out parameter-count-out
			reference-target-out parameter-source-out flags-out [int-ptr!]
		return: [integer!]
		/local callee [rsir-function!]
			imported [rsir-import!]
			shape [rsir-type!]
			import-id return-ref flags first-parameter parameter-count
			base [integer!]
	][
		reference-target-out/1: 0
		parameter-source-out/1: PARAMETER_TABLE
		case [
			target > 0 [
				if target > view/header/function-count [return INVALID_IR]
				callee: as rsir-function! (view/functions
					+ ((target - 1) * RSIR_FUNCTION_SIZE))
				return-ref: callee/return-type
				flags: callee/flags
				first-parameter: callee/first-parameter
				parameter-count: callee/parameter-count
			]
				target < 0 [
				if target < (0 - view/header/import-count)[return INVALID_IR]
				import-id: 0 - target
				imported: as rsir-import! (view/imports
					+ ((import-id - 1) * RSIR_IMPORT_SIZE))
				if imported/flags = 0 [return INVALID_IR]
				return-ref: imported/type
				flags: imported/flags
				first-parameter: imported/first-parameter
				parameter-count: imported/parameter-count
					reference-target-out/1: either
						(imported/flags and SYSCALL_FLAG) <> 0 [
							0
						][
							view/header/function-count
							+ view/header/global-count + import-id
						]
			]
			true [
				; A call through a pointer names its shape with a function type
				; whose member rows describe the parameters.
				unless valid-type-ref? signature view [return INVALID_IR]
				base: canonical-type signature view
				if base <= 0 [return INVALID_IR]
				shape: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
				unless shape/kind = -4 [return INVALID_IR]
				if shape/member-count < 0 [return INVALID_IR]
				return-ref: shape/target
				flags: shape/flags
				first-parameter: shape/first-member
				parameter-count: shape/member-count
				parameter-source-out/1: MEMBER_TABLE
			]
		]
		if all [return-ref <> 0 not valid-type-ref? return-ref view][
			return INVALID_IR
		]
		if (flags and CUSTOM) <> 0 [return UNSUPPORTED]
		if flags < 0 [return INVALID_IR]
		either (flags and SYSCALL_FLAG) <> 0 [
			unless all [
				target < 0
				(flags and 2047) = (SYSCALL_FLAG or CDECL)
			][return INVALID_IR]
		][
			if flags > CALLABLE_FLAGS [return INVALID_IR]
		]
		if (flags and VARIADIC) <> 0 [
			unless any [
				(flags and 3) = CDECL
				all [target > 0 (flags and 3) = 0]
			][return UNSUPPORTED]
		]
		unless any [
			target >= 0
			(flags and SYSCALL_FLAG) <> 0
			(flags and 3) = 0
			(flags and 3) = CDECL
			(flags and 3) = STDCALL
		][return UNSUPPORTED]
		return-ref-out/1: return-ref
		first-parameter-out/1: first-parameter
		parameter-count-out/1: parameter-count
		flags-out/1: flags
		0
	]

	prepare-global-data: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		references [arm64-reference-state!]
		global-offsets global-sizes global-owners global-children global-siblings
			[int-ptr!]
		data-size-out rodata-size-out [int-ptr!]
		return: [integer!]
		/local global target-global [rsir-global!]
			array-type [rsir-type!]
			initializer [rsir-initializer!]
			id initializer-id base kind global-size global-align
			global-offset target-id status data-size rodata-size
			root current child owner placed [integer!]
			inline? array? [logic!]
	][
		data-size: data-size-out/1
		rodata-size: rodata-size-out/1
		id: 1
		while [id <= view/header/global-count][
			global-owners/id: 0
			global-children/id: 0
			global-siblings/id: 0
			id: id + 1
		]
		; Count static global references before claiming anonymous payloads. A
		; payload belongs to its earlier pointer owner only when that initializer
		; is its sole incoming static global reference.
		id: 1
		while [id <= view/header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < global/initializer-count][
				initializer: as rsir-initializer! (view/initializers
					+ ((global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
				][
					target-id: initializer/b
					if any [
						target-id <= 0 target-id > view/header/global-count
						global-children/target-id = 2147483647
					][return INVALID_IR]
					global-children/target-id: global-children/target-id + 1
				]
				initializer-id: initializer-id + 1
			]
			id: id + 1
		]
		id: 1
		while [id <= view/header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < global/initializer-count][
				initializer: as rsir-initializer! (view/initializers
					+ ((global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
					initializer/b > id
					initializer/b <= view/header/global-count
				][
					target-id: initializer/b
					if global-children/target-id = 1 [
						target-global: as rsir-global! (view/globals
							+ ((target-id - 1) * RSIR_GLOBAL_SIZE))
						if target-global/name-size = 0 [global-owners/target-id: id]
					]
				]
				initializer-id: initializer-id + 1
			]
			id: id + 1
		]
		id: view/header/global-count
		while [id > 0][
			global-children/id: 0
			global-siblings/id: 0
			id: id - 1
		]
		id: view/header/global-count
		while [id > 0][
			owner: global-owners/id
			if owner > 0 [
				global-siblings/id: global-children/owner
				global-children/owner: id
			]
			id: id - 1
		]
		id: 1
		while [id <= view/header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [global/flags < 0 global/flags > (INLINE or PROTECTED)][
				return INVALID_IR
			]
			inline?: (global/flags and INLINE) <> 0
			kind: type-kind global/type view
			if all [inline? not any [kind = -2 kind = -3 kind = -7]][
				return INVALID_IR
			]
			global-size: 0
			global-align: 0
			unless layout-type global/type inline? view layout 0
				:global-size :global-align [return INVALID_IR]
			if any [global-size <= 0 global-align <= 0][return INVALID_IR]
			global-sizes/id: global-size

			base: canonical-type global/type view
			array?: all [inline? base > 0 kind = -7]
			if all [array? global/initializer-count = 0][return INVALID_IR]
			if global/initializer-count > 0 [
				initializer: as rsir-initializer! (view/initializers
					+ (global/first-initializer * RSIR_INITIALIZER_SIZE))
				either array? [
					array-type: as rsir-type! (view/types
						+ ((base - 1) * RSIR_TYPE_SIZE))
					either initializer/kind = BYTES_INITIALIZER [
						if any [
							global/initializer-count <> 1
							initializer/a < 0 initializer/c <> 0
							array-type/flags <> 1
							initializer/b <> array-type/member-count
							(canonical-type array-type/target view) <> -2
						][return INVALID_IR]
					][
						if global/initializer-count <> array-type/member-count [
							return INVALID_IR
						]
						initializer-id: 0
						while [initializer-id < global/initializer-count][
							initializer: as rsir-initializer! (view/initializers
								+ ((global/first-initializer + initializer-id)
									* RSIR_INITIALIZER_SIZE))
							case [
								initializer/kind = SCALAR_INITIALIZER [
									if initializer/c <> 0 [return INVALID_IR]
								]
								initializer/kind = ADDRESS_INITIALIZER [
									if any [
										array-type/flags <> 8
										not valid-static-address-initializer? initializer
											array-type/target id view
									][return INVALID_IR]
									target-id: either initializer/a = GLOBAL_ADDRESS [
										view/header/function-count + initializer/b
									][initializer/b]
									status: record-reference target-id 0 references
									if status < 0 [return status]
								]
								true [return INVALID_IR]
							]
							initializer-id: initializer-id + 1
						]
					]
				][
					if global/initializer-count <> 1 [return INVALID_IR]
					case [
						initializer/kind = SCALAR_INITIALIZER [
							if any [
								initializer/c <> 0 inline? global-size > 8
							][return INVALID_IR]
						]
						initializer/kind = ADDRESS_INITIALIZER [
							if any [
								inline? global-size <> 8
								not valid-static-address-initializer? initializer
									global/type id view
							][return INVALID_IR]
							target-id: either initializer/a = GLOBAL_ADDRESS [
								view/header/function-count + initializer/b
							][initializer/b]
							status: record-reference target-id 0 references
							if status < 0 [return status]
						]
						true [return INVALID_IR]
					]
				]
			]

			id: id + 1
		]
		; Walk roots and their anonymous children depth-first. Hidden payload IDs
		; are appended after all named globals, but their storage remains adjacent
		; to the pointer slots that own them.
		placed: 0
		id: 1
		while [id <= view/header/global-count][
			if global-owners/id = 0 [
				root: id
				current: id
				while [current > 0][
					global: as rsir-global! (view/globals
						+ ((current - 1) * RSIR_GLOBAL_SIZE))
					global-size: global-sizes/current
					global-offset: 0
					global-align: 0
					unless layout-type global/type
						((global/flags and INLINE) <> 0) view layout 0
						:global-offset :global-align [return INVALID_IR]
					either (global/flags and PROTECTED) <> 0 [
						global-offset: align rodata-size global-align
						if any [
							global-offset < 0
							global-offset > (2147483647 - global-size)
						][return OUTPUT_FULL]
						rodata-size: global-offset + global-size
					][
						global-offset: align data-size global-align
						if any [
							global-offset < 0
							global-offset > (2147483647 - global-size)
						][return OUTPUT_FULL]
						data-size: global-offset + global-size
					]
					global-offsets/current: global-offset
					placed: placed + 1
					child: global-children/current
					either child > 0 [
						current: child
					][
						while [all [
							current <> root
							global-siblings/current = 0
						]][current: global-owners/current]
						either current = root [
							current: 0
						][current: global-siblings/current]
					]
				]
			]
			id: id + 1
		]
		if placed <> view/header/global-count [return INVALID_IR]
		data-size-out/1: data-size
		rodata-size-out/1: rodata-size
		0
	]

	write-global-data: func [
		view [rsir-view!]
		references [arm64-reference-state!]
		global-offsets global-sizes [int-ptr!]
		rodata-output data-output [byte-ptr!]
		return: [integer!]
		/local global [rsir-global!]
			array-type [rsir-type!]
			initializer [rsir-initializer!]
			cursor [byte-ptr!]
			id initializer-id base kind slot-width item-offset
			target-id source-offset reference status [integer!]
			array? [logic!]
	][
		id: 1
		while [id <= view/header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			cursor: either (global/flags and PROTECTED) <> 0 [
				rodata-output + global-offsets/id
			][data-output + global-offsets/id]
			base: canonical-type global/type view
			kind: type-kind base view
			array?: all [
				(global/flags and INLINE) <> 0
				base > 0 kind = -7
			]
			slot-width: global-sizes/id
			if array? [
				array-type: as rsir-type! (view/types
					+ ((base - 1) * RSIR_TYPE_SIZE))
				slot-width: array-type/flags
			]
			if global/initializer-count > 0 [
				initializer: as rsir-initializer! (view/initializers
					+ (global/first-initializer * RSIR_INITIALIZER_SIZE))
				either initializer/kind = BYTES_INITIALIZER [
					copy-memory cursor (view/strings + initializer/a) initializer/b
				][
					initializer-id: 0
					item-offset: 0
					while [initializer-id < global/initializer-count][
						initializer: as rsir-initializer! (view/initializers
							+ ((global/first-initializer + initializer-id)
								* RSIR_INITIALIZER_SIZE))
						case [
							initializer/kind = SCALAR_INITIALIZER [
								unless write-static-scalar (cursor + item-offset)
									slot-width initializer/a initializer/b [
									return INVALID_IR
								]
							]
							initializer/kind = ADDRESS_INITIALIZER [
								target-id: either initializer/a = GLOBAL_ADDRESS [
									view/header/function-count + initializer/b
								][initializer/b]
								source-offset: global-offsets/id + item-offset
								if source-offset > REFERENCE_OFFSET_MASK [
									return OUTPUT_FULL
								]
								reference: either (global/flags and PROTECTED) <> 0 [
									RODATA_REFERENCE_TAG or source-offset
								][DATA_REFERENCE_TAG or source-offset]
								print ["ARM64 data reference owner=" id
									" source=" source-offset " target=" target-id
									" kind=" initializer/a " id=" initializer/b lf]
								status: record-reference target-id reference references
								if status < 0 [return status]
							]
							true [return INVALID_IR]
						]
						initializer-id: initializer-id + 1
						item-offset: item-offset + slot-width
					]
				]
			]
			id: id + 1
		]
		0
	]

	emit-global-homes: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		function-position [integer!]
		references [arm64-reference-state!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] id target written encoded status [integer!]
	][
		written: 0
		id: 1
		while [id <= view/header/global-count][
			target: scratch/global-homes/id
			if target > 0 [
				status: record-reference (view/header/function-count + id)
					(function-position + written)
					references
				if status < 0 [return status]
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/page-address at (capacity - written) target
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			id: id + 1
		]
		written
	]

	record-plan-depth: func [
		target depth [integer!]
		fn [rsir-function!]
		depths [int-ptr!]
		return: [logic!]
	][
		if any [target <= 0 target > fn/instruction-count][return false]
		either depths/target < 0 [
			depths/target: depth
		][
			if depths/target <> depth [return false]
		]
		true
	]

	queue-effect: func [
		effects queue [int-ptr!]
		tail [int-ptr!]
		index bit [integer!]
		/local position [integer!]
	][
		if (effects/index and bit) = 0 [
			effects/index: effects/index or bit
			position: tail/value + 1
			tail/value: position
			queue/position: index
		]
	]

	record-effect-use: func [
		heads links targets [int-ptr!]
		target user [integer!]
	][
		links/user: heads/target
		heads/target: user
		targets/user: target
	]

	record-switch-effect-use: func [
		heads links users [int-ptr!]
		target user slot [integer!]
	][
		links/slot: heads/target
		users/slot: user
		heads/target: 0 - slot
	]

	update-sub-call-effects: func [
		effects targets return-queue resume-queue [int-ptr!]
		return-tail resume-tail [int-ptr!]
		index instruction-count [integer!]
		/local next-index target [integer!]
			next? target-returns? target-resumes? [logic!]
	][
		target: targets/index
		next-index: index + 1
		next?: all [
			next-index <= instruction-count
			(effects/next-index and EFFECT_FUNCTION_START) = 0
		]
		target-returns?: (effects/target and EFFECT_RETURNS) <> 0
		target-resumes?: (effects/target and EFFECT_RESUMES) <> 0
		if any [
			target-returns?
			all [
				target-resumes? next?
				(effects/next-index and EFFECT_RETURNS) <> 0
			]
		][queue-effect effects return-queue return-tail index EFFECT_RETURNS]
		if all [
			target-resumes? next?
			(effects/next-index and EFFECT_RESUMES) <> 0
		][queue-effect effects resume-queue resume-tail index EFFECT_RESUMES]
	]

	; A subroutine call may leave its continuation unreachable when the body
	; returns from the enclosing function instead of reaching OP_SUB_RETURN.
	prepare-subroutine-effects: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		return: [integer!]
		/local fn [rsir-function!] instruction previous [rsir-instruction!]
			switch-case [rsir-switch!]
			effects heads links targets switch-links switch-users return-queue
				resume-queue return-tail-ptr resume-tail-ptr [int-ptr!]
			id index first global-index target global-target user edge switch-id
				case-index queue-head return-tail resume-head resume-tail [integer!]
	][
		effects: scratch/instruction-effects
		heads: scratch/instruction-offsets
		links: scratch/catch-depths
		targets: scratch/control-uses
		switch-links: scratch/switch-effect-links
		switch-users: scratch/switch-effect-users
		return-queue: scratch/instruction-depths
		resume-queue: scratch/entry-types
		return-tail-ptr: scratch/entry-kinds
		resume-tail-ptr: scratch/entry-flags
		return-tail-ptr/value: 0
		resume-tail-ptr/value: 0
		index: 1
		while [index <= view/header/instruction-count][
			effects/index: 0
			heads/index: 0
			links/index: 0
			targets/index: 0
			index: index + 1
		]
		index: 1
		while [index <= view/header/switch-count][
			switch-links/index: 0
			switch-users/index: 0
			index: index + 1
		]
		first: 1
		id: 1
		while [id <= view/header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			index: 1
			while [index <= fn/instruction-count][
				global-index: first + index - 1
				if index = 1 [effects/global-index: EFFECT_FUNCTION_START]
				instruction: as rsir-instruction! (view/instructions
					+ ((global-index - 1) * RSIR_INSTRUCTION_SIZE))
				case [
					instruction/op = OP_RETURN [
						queue-effect effects return-queue return-tail-ptr
							global-index EFFECT_RETURNS
					]
					instruction/op = OP_SUB_RETURN [
						queue-effect effects resume-queue resume-tail-ptr
							global-index EFFECT_RESUMES
					]
					any [
						instruction/op = OP_JUMP
						instruction/op = OP_BRANCH
						instruction/op = OP_CATCH
					][
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: first + target - 1
						record-effect-use heads links targets global-target global-index
					]
					instruction/op = OP_BINARY [
						if instruction/b > 0 [
							target: instruction/b
							if target >= index [return INVALID_IR]
							previous: as rsir-instruction! (view/instructions
								+ ((first + target - 2) * RSIR_INSTRUCTION_SIZE))
							unless previous/op = OP_OVERFLOW [return INVALID_IR]
							target: previous/a
							if any [target <= index target > fn/instruction-count][
								return INVALID_IR
							]
							global-target: first + target - 1
							record-effect-use heads links targets global-target global-index
						]
					]
					instruction/op = OP_SWITCH [
						if any [
							instruction/c <= 0 instruction/c > fn/instruction-count
							instruction/a < 0 instruction/b <= 0
							instruction/b > view/header/switch-count
							instruction/a > (view/header/switch-count - instruction/b)
						][return INVALID_IR]
						global-target: first + instruction/c - 1
						record-effect-use heads links targets global-target global-index
						case-index: 0
						while [case-index < instruction/b][
							switch-id: instruction/a + case-index + 1
							switch-case: as rsir-switch! (view/switches
								+ ((switch-id - 1) * RSIR_SWITCH_SIZE))
							target: switch-case/target
							if any [target <= 0 target > fn/instruction-count][
								return INVALID_IR
							]
							global-target: first + target - 1
							record-switch-effect-use heads switch-links switch-users
								global-target global-index switch-id
							case-index: case-index + 1
						]
					]
					instruction/op = OP_SUB_CALL [
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: first + target - 1
						record-effect-use heads links targets global-target global-index
					]
					true []
				]
				index: index + 1
			]
			first: first + fn/instruction-count
			id: id + 1
		]
		queue-head: 1
		resume-head: 1
		while [any [
			queue-head <= return-tail-ptr/value
			resume-head <= resume-tail-ptr/value
		]][
			either queue-head <= return-tail-ptr/value [
				index: return-queue/queue-head
				queue-head: queue-head + 1
			][
				index: resume-queue/resume-head
				resume-head: resume-head + 1
			]
			if (effects/index and EFFECT_FUNCTION_START) = 0 [
				user: index - 1
				previous: as rsir-instruction! (view/instructions
					+ ((user - 1) * RSIR_INSTRUCTION_SIZE))
				case [
					previous/op = OP_SUB_CALL [
						update-sub-call-effects effects targets return-queue resume-queue
							return-tail-ptr resume-tail-ptr user
							view/header/instruction-count
					]
					any [
						previous/op = OP_JUMP previous/op = OP_SWITCH
						previous/op = OP_FAIL previous/op = OP_THROW
						previous/op = OP_RETURN previous/op = OP_SUB_RETURN
					][0]
					true [
						if (effects/index and EFFECT_RETURNS) <> 0 [
							queue-effect effects return-queue return-tail-ptr user EFFECT_RETURNS
						]
						if (effects/index and EFFECT_RESUMES) <> 0 [
							queue-effect effects resume-queue resume-tail-ptr user EFFECT_RESUMES
						]
					]
				]
			]
			edge: heads/index
			while [edge <> 0][
				either edge > 0 [
					user: edge
					edge: links/user
				][
					switch-id: 0 - edge
					user: switch-users/switch-id
					edge: switch-links/switch-id
				]
				previous: as rsir-instruction! (view/instructions
					+ ((user - 1) * RSIR_INSTRUCTION_SIZE))
				either previous/op = OP_SUB_CALL [
					update-sub-call-effects effects targets return-queue resume-queue
						return-tail-ptr resume-tail-ptr user view/header/instruction-count
				][
					if (effects/index and EFFECT_RETURNS) <> 0 [
						queue-effect effects return-queue return-tail-ptr user EFFECT_RETURNS
					]
					if (effects/index and EFFECT_RESUMES) <> 0 [
						queue-effect effects resume-queue resume-tail-ptr user EFFECT_RESUMES
					]
				]
			]
		]
		0
	]

	prepare-control-targets: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		return: [integer!]
		/local fn [rsir-function!] instruction [rsir-instruction!]
			switch-case [rsir-switch!]
			id index first target case-index switch-id [integer!]
	][
		id: 1
		while [id <= view/header/instruction-count][
			scratch/instruction-offsets/id: 0
			scratch/instruction-depths/id: -1
			scratch/entry-types/id: 0
			scratch/entry-kinds/id: 0
			scratch/entry-flags/id: 0
			scratch/control-uses/id: 0
			id: id + 1
		]
		first: 0
		id: 1
		while [id <= view/header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			index: 0
			while [index < fn/instruction-count][
				instruction: as rsir-instruction! (view/instructions
					+ ((first + index) * RSIR_INSTRUCTION_SIZE))
				case [
					any [
						instruction/op = OP_JUMP
						instruction/op = OP_BRANCH
						instruction/op = OP_CATCH
					][
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][
							return INVALID_IR
						]
						target: first + target
						scratch/control-uses/target: 1
					]
					instruction/op = OP_OVERFLOW [
						; A scope without a tracked operation never gets its
						; landing pad patched in, so a zero target is normal.
						target: instruction/a
						if target <> 0 [
							if any [target <= 0 target > fn/instruction-count][
								return INVALID_IR
							]
							target: first + target
							scratch/control-uses/target: 1
						]
					]
					instruction/op = OP_SWITCH [
						if any [
							instruction/a < 0 instruction/b <= 0
							instruction/b > view/header/switch-count
							instruction/a > (view/header/switch-count - instruction/b)
							instruction/c <= 0 instruction/c > fn/instruction-count
						][return INVALID_IR]
						target: first + instruction/c
						scratch/control-uses/target: 1
						case-index: 0
						while [case-index < instruction/b][
							switch-id: instruction/a + case-index
							switch-case: as rsir-switch! (view/switches
								+ (switch-id * RSIR_SWITCH_SIZE))
							if any [
								switch-case/target <= 0
								switch-case/target > fn/instruction-count
							][return INVALID_IR]
							target: first + switch-case/target
							scratch/control-uses/target: 1
							case-index: case-index + 1
						]
					]
					true []
				]
				index: index + 1
			]
			first: first + fn/instruction-count
			id: id + 1
		]
		0
	]

	prepare-exception-structure: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction [integer!]
		unwind? [logic!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		return: [integer!]
		/local instruction scope [rsir-instruction!]
			switch-case [rsir-switch!]
			catch-depths [int-ptr!]
			index ordinal level capacity target case-index unwind target-depth expected-depth [integer!]
	][
		catch-depths: scratch/catch-depths + first-instruction
		level: 0
		capacity: 0
		unwind: either unwind? [1][0]
		index: 0
		while [index < fn/instruction-count][
			ordinal: index + 1
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			catch-depths/ordinal: level
			if any [
				instruction/op = OP_CATCH
				instruction/op = OP_THROW
			][unwind: 1]
			if all [
				any [instruction/op = OP_ENTRY instruction/op = OP_SUB_RETURN]
				level <> 0
			][return INVALID_IR]
			case [
				instruction/op = OP_CATCH [
					unless all [
						instruction/a > ordinal
						instruction/a <= fn/instruction-count
						instruction/b = (level + 1)
						instruction/c = 0
					][return INVALID_IR]
					scope: as rsir-instruction! (view/instructions
						+ ((first-instruction + instruction/a - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						scope/op = OP_END_CATCH
						scope/a = ordinal
						scope/b = instruction/b
						scope/c = 0
					][return INVALID_IR]
					level: level + 1
					if level > capacity [capacity: level]
				]
				instruction/op = OP_END_CATCH [
					unless all [
						level > 0
						instruction/a > 0 instruction/a < ordinal
						instruction/b = level instruction/c = 0
					][return INVALID_IR]
					scope: as rsir-instruction! (view/instructions
						+ ((first-instruction + instruction/a - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						scope/op = OP_CATCH
						scope/a = ordinal
						scope/b = instruction/b
						scope/c = 0
					][return INVALID_IR]
					level: level - 1
				]
				true []
			]
			index: index + 1
		]
		if level <> 0 [return INVALID_IR]
		if capacity = 0 [
			plan/unwind: unwind
			plan/catch-capacity: 0
			plan/visible-frame-offset: either unwind = 1 [VISIBLE_FRAME_OFFSET][0]
			plan/frame-prefix-count: either unwind = 1 [4][0]
			return 0
		]

		; Lexical scopes are not ordinary CFG state: only a JUMP can leave
		; them, and its unwind count must name exactly the target's depth.
		index: 0
		while [index < fn/instruction-count][
			ordinal: index + 1
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			level: catch-depths/ordinal
			case [
				instruction/op = OP_JUMP [
					target: instruction/a
					target-depth: catch-depths/target
					expected-depth: level - instruction/c
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/c >= 0 instruction/c <= level
						(target-depth - expected-depth) = 0
					][
						return INVALID_IR
					]
				]
				instruction/op = OP_BRANCH [
					target: instruction/a
					target-depth: catch-depths/target
					unless all [
						target > 0 target <= fn/instruction-count
						(target-depth - level) = 0
					][
						return INVALID_IR
					]
				]
				instruction/op = OP_OVERFLOW [
					target: instruction/a
					target-depth: either target = 0 [0][catch-depths/target]
					if all [
						target <> 0
						any [
							target <= 0 target > fn/instruction-count
							(target-depth - level) <> 0
						]
					][
						return INVALID_IR
					]
				]
				instruction/op = OP_SWITCH [
					target: instruction/c
					target-depth: catch-depths/target
					unless all [
						instruction/a >= 0 instruction/b > 0
						instruction/b <= view/header/switch-count
						instruction/a <=
							(view/header/switch-count - instruction/b)
						target > 0 target <= fn/instruction-count
						(target-depth - level) = 0
					][return INVALID_IR]
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						target-depth: catch-depths/target
						unless all [
							target > 0 target <= fn/instruction-count
							(target-depth - level) = 0
						][return INVALID_IR]
						case-index: case-index + 1
					]
				]
				instruction/op = OP_CATCH [
					target: instruction/a
					target-depth: catch-depths/target
					expected-depth: level + 1
					unless (target-depth - expected-depth) = 0 [
						return INVALID_IR
					]
				]
				true []
			]
			index: index + 1
		]
		if capacity > ((2147483647 - 4) / 3)[return OUTPUT_FULL]
		plan/unwind: unwind
		plan/catch-capacity: capacity
		plan/visible-frame-offset: either unwind = 1 [VISIBLE_FRAME_OFFSET][0]
		plan/frame-prefix-count: either unwind = 1 [4 + (capacity * 3)][0]
		0
	]

	; A subroutine body runs on the link register the BL that reached it wrote,
	; so it only has to preserve LR when it can issue a branch-and-link itself.
	entry-clobbers-link?: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction ordinal [integer!]
		return: [logic!]
		/local instruction [rsir-instruction!] index [integer!]
	][
		index: ordinal
		while [index < fn/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			if instruction/op = OP_ENTRY [return false]
			if any [
				instruction/op = OP_CALL
				instruction/op = OP_SUB_CALL
			][return true]
			index: index + 1
		]
		false
	]

	pointer-to-canonical?: func [
		ref target [integer!]
		view [rsir-view!]
		return: [logic!]
		/local pointee [integer!]
	][
		pointee: 0
		all [
			valid-type-ref? ref view
			pointee-type ref view :pointee
			(canonical-type pointee view) = target
		]
	]

	; A multiply needs its otherwise-dead high half only when a later native
	; query consumes it. Transparent value moves between the two keep NZCV live.
	overflow-query-follows?: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction index [integer!]
		return: [logic!]
		/local instruction [rsir-instruction!]
	][
		index: index + 1
		while [index < fn/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			if all [
				instruction/op = OP_NATIVE
				instruction/a = CPU_OVERFLOW_NATIVE
			][return true]
			if all [
				instruction/op = OP_NATIVE
				any [
					instruction/a = ATOMIC_CAS_NATIVE
					instruction/a = ATOMIC_MATH_NATIVE
				]
			][return false]
			if any [
				instruction/op = OP_BINARY
				instruction/op = OP_CAST
				instruction/op = OP_CALL
				instruction/op = OP_SUB_CALL
				instruction/op = OP_JUMP
				instruction/op = OP_BRANCH
				instruction/op = OP_SWITCH
				instruction/op = OP_ENTRY
				instruction/op = OP_RETURN
				instruction/op = OP_SUB_RETURN
				instruction/op = OP_FAIL
			][return false]
			index: index + 1
		]
		false
	]

	plan-function: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		fn [rsir-function!]
		first-instruction [integer!]
		startup? [logic!]
		unwind? [logic!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			abi-location [arm64-abi-location! value]
			imported [rsir-import!]
			instruction [rsir-instruction!]
			typed-metadata [rsir-type!]
			typed-member [rsir-member!]
			switch-case [rsir-switch!]
			sub-entry [rsir-instruction!]
			depths result-offsets [int-ptr!]
			id slot count width kind operation home-count home-mask home-register
			reserved-home-mask register-id register-width mask
			float-home-count frame-allocation outgoing-size call-outgoing
			typed-size
			depth max-spill has-call argument-count frame-home-count total-slots status
			call-return call-first-parameter call-parameter-count call-flags
			call-reference call-source call-signature callee-slots
			region-ordinal region-spill entry-base
			main-entry-count sub-entry-count
			ordinal target case-index result-size result-align result-used
			inline-size inline-align
				[integer!]
			fallthrough? stack-all? frame-anchor? [logic!]
	][
		status: prepare-exception-structure view fn first-instruction unwind?
			scratch plan
		if status < 0 [return status]
		plan/hidden-return-offset: 0
		plan/frame-anchor-register: arm64-encoder/FP
		plan/frame-anchor-offset: 0
		if all [
			(fn/flags and RETURN_VALUE) <> 0
			aggregate-ref? fn/return-type view
		][
			inline-size: 0
			inline-align: 0
			unless layout-type fn/return-type true view layout 0
				:inline-size :inline-align [return INVALID_IR]
			kind: 0
			width: 0
			if all [
				not classify-hfa fn/return-type INLINE view 0 :kind :width
				inline-size > 16
			][
				if plan/frame-prefix-count = 2147483647 [return OUTPUT_FULL]
				plan/frame-prefix-count: plan/frame-prefix-count + 1
				plan/hidden-return-offset: 0 - (plan/frame-prefix-count * 8)
			]
		]
		if plan/frame-prefix-count = 2147483647 [return OUTPUT_FULL]
		plan/frame-prefix-count: plan/frame-prefix-count + 1
		plan/tag-offset: 0 - (plan/frame-prefix-count * 8)
		count: fn/parameter-count + fn/local-count
		id: 1
		while [id <= view/header/global-count][
			scratch/global-homes/id: 0
			id: id + 1
		]
		id: 1
		while [id <= count][
			parameter: as rsir-parameter! (view/parameters
				+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
			scratch/homes/id: 0
			scratch/storage-types/id: parameter/type
			scratch/storage-kinds/id: 0
			id: id + 1
		]
		depths: scratch/plan-depths
		result-offsets: scratch/result-offsets + first-instruction
		id: 1
		while [id <= fn/instruction-count][
			depths/id: -1
			scratch/entry-spill-bases/id: 0
			scratch/entry-spill-limits/id: 0
			result-offsets/id: 0
			id: id + 1
		]
		depth: 0
		max-spill: 0
		outgoing-size: 0
		has-call: plan/unwind
		stack-all?: false
		frame-anchor?: false
		home-mask: 0
		home-count: 0
		; Apple's process entry arrives with argc/argv in X0/X1. X19/X20 keep
		; them live across the runtime startup calls, matching the legacy backend.
		reserved-home-mask: 0
		if startup? [
			reserved-home-mask: reserved-home-mask or 3
			home-mask: home-mask or 3
			home-count: 2
		]
		; Region 0 is the straight-line body of a function without subroutines,
		; or the leading jump of one that has them. Every OP_ENTRY opens a new
		; region with its own expression-stack window, so a subroutine cannot
		; overwrite the values its caller left parked.
		region-ordinal: 0
		region-spill: 0
		main-entry-count: 0
		sub-entry-count: 0
		fallthrough?: true
		id: 0
		while [id < fn/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + id) * RSIR_INSTRUCTION_SIZE))
			if instruction/op = OP_ADDRESS [
				case [
					instruction/a = LOCAL_ADDRESS [
						slot: instruction/b
						if any [slot <= 0 slot > count][return INVALID_IR]
						parameter: as rsir-parameter! (view/parameters
							+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
						case [
							parameter/flags = 0 [
								if scratch/storage-kinds/slot = 0 [
									scratch/storage-kinds/slot: STORAGE_REGISTER
								]
							]
							; An inline aggregate only ever exists as memory, so
							; its slot goes straight to the frame instead of
							; waiting for a reference to demote it.
							parameter/flags = INLINE [
								scratch/storage-kinds/slot: STORAGE_FRAME
							]
							true [return UNSUPPORTED]
						]
					]
					instruction/a = GLOBAL_ADDRESS [
						slot: instruction/b
						if any [
							slot <= 0
							slot > view/header/global-count
							instruction/c <> 0
							scratch/global-homes/slot = 2147483647
						][return INVALID_IR]
						scratch/global-homes/slot: scratch/global-homes/slot + 1
					]
					instruction/a = FUNCTION_ADDRESS [
						if any [
							instruction/b <= 0
							instruction/b > view/header/function-count
							not valid-type-ref? instruction/c view
							(type-kind instruction/c view) <> -4
						][return INVALID_IR]
					]
					instruction/a = IMPORT_ADDRESS [
						slot: instruction/b
						if any [
							slot <= 0 slot > view/header/import-count
							not valid-type-ref? instruction/c view
							(type-kind instruction/c view) <> -4
						][return INVALID_IR]
						imported: as rsir-import! (view/imports
							+ ((slot - 1) * RSIR_IMPORT_SIZE))
						unless any [imported/flags = CDECL imported/flags = STDCALL][
							return UNSUPPORTED
						]
					]
					true [return UNSUPPORTED]
				]
			]
			ordinal: id + 1
			last-plan-ordinal: ordinal
			if instruction/op = OP_ENTRY [
				; An entry is resumed from a BL or from the leading jump, so the
				; expression stack is empty there whichever way control arrives.
				if all [fallthrough? depth <> 0][
					print ["ARM64 plan entry fallthrough ordinal=" ordinal
						" depth=" depth lf]
					return INVALID_IR
				]
				depths/ordinal: 0
				fallthrough?: false
			]
			either fallthrough? [
				if all [depths/ordinal >= 0 depths/ordinal <> depth][
					print ["ARM64 plan sequential merge ordinal=" ordinal
						" expected=" depths/ordinal " depth=" depth lf]
					return INVALID_IR
				]
				depths/ordinal: depth
			][
				if depths/ordinal < 0 [
					id: id + 1
					continue
				]
				depth: depths/ordinal
				fallthrough?: true
			]
			case [
				any [instruction/op = OP_LITERAL instruction/op = OP_ADDRESS][
					if depth = 2147483647 [return OUTPUT_FULL]
					depth: depth + 1
					scratch/stack-low/depth: either all [
						instruction/op = OP_ADDRESS
						instruction/a = LOCAL_ADDRESS
					][instruction/b][0]
				]
				instruction/op = OP_LOAD [
					if depth < 1 [return INVALID_IR]
					scratch/stack-low/depth: 0
				]
				instruction/op = OP_SIZE [
					unless all [
						valid-type-ref? instruction/a view
						any [instruction/b = 0 instruction/b = 1]
					][return INVALID_IR]
					either instruction/b = 0 [
						if instruction/c <> 0 [return INVALID_IR]
						if depth = 2147483647 [return OUTPUT_FULL]
						depth: depth + 1
					][
						if depth < 1 [return INVALID_IR]
					]
					scratch/stack-low/depth: 0
				]
				instruction/op = OP_NATIVE [
					either any [
						instruction/a = CPU_REGISTER_NATIVE
						instruction/a = CPU_REGISTER_SET_NATIVE
					][
						unless all [
							instruction/b >= 0 instruction/c > 0
							instruction/c <= view/strings-size
							instruction/b <= (view/strings-size - instruction/c)
						][return INVALID_IR]
						register-width: 0
						register-id: cpu-register-id
							(view/strings + instruction/b) instruction/c :register-width
						if register-id < 0 [return UNSUPPORTED]
						if all [
							register-id >= FIRST_HOME_REGISTER
							register-id < (FIRST_HOME_REGISTER + HOME_REGISTER_COUNT)
						][
							mask: 1 << (register-id - FIRST_HOME_REGISTER)
							reserved-home-mask: reserved-home-mask or mask
							if all [
								instruction/a = CPU_REGISTER_SET_NATIVE
								(home-mask and mask) = 0
							][
								home-mask: home-mask or mask
								home-count: home-count + 1
							]
						]
					][
						either instruction/a = ATOMIC_MATH_NATIVE [
							operation: instruction/b and 7
							unless all [
								operation >= 1 operation <= 5
								any [
									instruction/b = operation
									instruction/b = (operation + ATOMIC_OLD)
								]
							][return INVALID_IR]
						][if instruction/b <> 0 [return INVALID_IR]]
					]
					case [
						any [
							instruction/a = STACK_TOP_NATIVE
							instruction/a = STACK_POP_NATIVE
							instruction/a = STACK_FRAME_NATIVE
							instruction/a = STACK_ALIGN_NATIVE
							instruction/a = PROGRAM_COUNTER_NATIVE
							instruction/a = CPU_OVERFLOW_NATIVE
							instruction/a = CPU_REGISTER_NATIVE
						][
							if depth = 2147483647 [return OUTPUT_FULL]
							depth: depth + 1
							scratch/stack-low/depth: 0
						]
						instruction/a = STACK_PUSH_NATIVE [
							if depth < 1 [return INVALID_IR]
							depth: depth - 1
						]
						instruction/a = STACK_TOP_SET_NATIVE [
							if depth < 1 [return INVALID_IR]
						]
						instruction/a = STACK_FRAME_SET_NATIVE [
							if depth < 1 [return INVALID_IR]
							frame-anchor?: true
						]
						any [
							instruction/a = STACK_ALLOCATE_NATIVE
							instruction/a = STACK_ALLOCATE_ZERO_NATIVE
							instruction/a = LOG_B_NATIVE
						][if depth < 1 [return INVALID_IR]]
						instruction/a = STACK_FREE_NATIVE [
							if depth < 1 [return INVALID_IR]
							depth: depth - 1
						]
						instruction/a = CPU_REGISTER_SET_NATIVE [
							if depth < 1 [return INVALID_IR]
							if register-id = arm64-encoder/FP [frame-anchor?: true]
							; A write can alias a volatile register holding an older
							; expression. Reserve its indexed spill slot only when that
							; is possible; ordinary register access remains frameless.
							if all [
								register-id <= arm64-encoder/X17
								depth > 1
							][
								if (depth - 1) > region-spill [region-spill: depth - 1]
								has-call: 1
							]
						]
						instruction/a = ATOMIC_FENCE_NATIVE [0]
						instruction/a = ATOMIC_LOAD_NATIVE [
							if depth < 1 [return INVALID_IR]
							scratch/stack-low/depth: 0
						]
						instruction/a = ATOMIC_STORE_NATIVE [
							if depth < 2 [return INVALID_IR]
							depth: depth - 2
						]
						instruction/a = ATOMIC_CAS_NATIVE [
							if depth < 3 [return INVALID_IR]
							depth: depth - 2
							scratch/stack-low/depth: 0
						]
						instruction/a = ATOMIC_MATH_NATIVE [
							if depth < 2 [return INVALID_IR]
							depth: depth - 1
							scratch/stack-low/depth: 0
						]
						any [
							instruction/a = STACK_PUSH_ALL_NATIVE
							instruction/a = STACK_POP_ALL_NATIVE
						][
							stack-all?: true
							if depth > region-spill [region-spill: depth]
							has-call: 1
						]
						true [
							print ["ARM64 plan native unsupported ordinal=" ordinal
								" native=" instruction/a " arg=" instruction/b lf]
							return UNSUPPORTED
						]
					]
					; Stack intrinsics may move SP and need FP to restore the frame.
					if all [
						instruction/a >= STACK_TOP_NATIVE
						instruction/a <= STACK_FREE_NATIVE
					][has-call: 1]
					if all [
						any [
							instruction/a = CPU_REGISTER_NATIVE
							instruction/a = CPU_REGISTER_SET_NATIVE
						]
						register-id = arm64-encoder/SP
					][has-call: 1]
				]
				instruction/op = OP_REFERENCE [
					if depth < 1 [return INVALID_IR]
					slot: scratch/stack-low/depth
					if slot > 0 [
						scratch/storage-kinds/slot: STORAGE_FRAME
						; Address arithmetic can observe neighboring declarations, so
						; every used storage slot must retain declaration-order layout.
						stack-all?: true
					]
				]
				instruction/op = OP_MEMBER [
					if depth < 1 [return INVALID_IR]
				]
				instruction/op = OP_TAG [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth >= 1
					][return INVALID_IR]
					scratch/stack-low/depth: 0
				]
				instruction/op = OP_OVERFLOW [
					unless all [instruction/b = 0 instruction/c = 0][
						return INVALID_IR
					]
					; The landing pad resumes the scope's own expression stack,
					; whichever tracked operation branched to it.
					if instruction/a <> 0 [
						unless record-plan-depth instruction/a depth fn depths [
							return INVALID_IR
						]
					]
				]
				instruction/op = OP_INDEX [
					case [
						instruction/b = 0 [
							if depth < 1 [return INVALID_IR]
						]
						instruction/b = 1 [
							if depth < 2 [return INVALID_IR]
							depth: depth - 1
						]
						true [return INVALID_IR]
					]
				]
				instruction/op = OP_SET [
					if depth < 2 [return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_DROP [
					if depth < 1 [return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_BINARY [
					if depth < 2 [return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_CALL [
					argument-count: instruction/b
					if argument-count < 0 [return INVALID_IR]
					; A call through a pointer keeps the callee below its
					; arguments, so it claims one more live slot.
					callee-slots: either instruction/a = 0 [1][0]
					if argument-count > (depth - callee-slots)[return INVALID_IR]
					call-return: 0
					call-first-parameter: 0
					call-parameter-count: 0
					call-reference: 0
					call-source: PARAMETER_TABLE
					call-flags: 0
					call-signature: instruction/c
					if all [
						call-signature > 0
						(type-kind call-signature view) = -8
					][
						typed-metadata: as rsir-type! (view/types
							+ (((canonical-type call-signature view) - 1)
								* RSIR_TYPE_SIZE))
						call-signature: typed-metadata/target
					]
					status: resolve-call instruction/a call-signature view
						:call-return :call-first-parameter :call-parameter-count
						:call-reference :call-source :call-flags
					if status < 0 [return status]
					if (call-flags and TYPED) <> 0 [
						unless all [
							instruction/c > 0
							(type-kind instruction/c view) = -8
							typed-metadata/member-count = argument-count
							call-parameter-count = 2
						][return INVALID_IR]
						if argument-count > (2147483647 / 24)[return OUTPUT_FULL]
						typed-size: argument-count * 24
						call-outgoing: align typed-size 16
						if call-outgoing < 0 [return OUTPUT_FULL]
						if call-outgoing > outgoing-size [outgoing-size: call-outgoing]
						slot: 1
						while [slot <= argument-count][
							typed-member: as rsir-member! (view/members
								+ ((typed-metadata/first-member + slot - 1)
									* RSIR_MEMBER_SIZE))
							unless all [
								valid-type-ref? typed-member/type view
								typed-runtime-id? typed-member/flags
							][return INVALID_IR]
							slot: slot + 1
						]
					]
					if (call-flags and TYPED) = 0 [
						if any [
							all [
								(call-flags and VARIADIC) = 0
								argument-count <> call-parameter-count
							]
							all [
								(call-flags and VARIADIC) <> 0
								argument-count < call-parameter-count
							]
							all [instruction/a <> 0 instruction/c <> call-return]
						][return INVALID_IR]
						call-outgoing: 0
						either all [
							(call-flags and VARIADIC) <> 0
							(call-flags and 3) <> CDECL
						][
							if argument-count > (2147483647 / 8)[return OUTPUT_FULL]
							call-outgoing: align (argument-count * 8) 16
						][
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count 0 abi-location
							if status < 0 [return status]
							call-outgoing: abi-location/total-size
							if (call-flags and VARIADIC) <> 0 [
								if (argument-count - call-parameter-count)
									> ((2147483647 - call-outgoing) / 8) [
									return OUTPUT_FULL
								]
								call-outgoing: call-outgoing
									+ ((argument-count - call-parameter-count) * 8)
							]
							call-outgoing: align call-outgoing 16
						]
						if call-outgoing < 0 [return OUTPUT_FULL]
						if call-outgoing > outgoing-size [outgoing-size: call-outgoing]
					]
					has-call: 1
					; The spill window still covers the callee slot: it must
					; survive argument setup when it sits in a scratch register.
					if (depth - argument-count) > region-spill [
						region-spill: depth - argument-count
					]
					depth: depth - argument-count - callee-slots
					if call-return <> 0 [
						depth: depth + 1
						scratch/stack-low/depth: 0
					]
				]
				instruction/op = OP_CATCH [
					unless all [
						depth = 1
						record-plan-depth instruction/a 0 fn depths
					][return INVALID_IR]
					depth: 0
				]
				instruction/op = OP_END_CATCH [0]
				instruction/op = OP_THROW [
					if depth < 2 [return INVALID_IR]
					depth: 0
					fallthrough?: false
				]
				instruction/op = OP_ENTRY [
					unless all [
						any [instruction/a = 0 instruction/a = 1]
						instruction/c = 0
						any [instruction/b = 0 valid-type-ref? instruction/b view]
					][return INVALID_IR]
					either instruction/a = 0 [
						main-entry-count: main-entry-count + 1
					][sub-entry-count: sub-entry-count + 1]
					either region-ordinal = 0 [
						if region-spill > max-spill [max-spill: region-spill]
					][
						scratch/entry-spill-limits/region-ordinal: region-spill
					]
					region-ordinal: ordinal
					region-spill: 0
				]
				instruction/op = OP_SUB_CALL [
					target: instruction/a
					if any [
						target <= 0 target > fn/instruction-count
						target = region-ordinal
						instruction/c <> 0
					][return INVALID_IR]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + target - 1) * RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/op = OP_ENTRY
						sub-entry/a = 1
						sub-entry/b = instruction/b
					][return INVALID_IR]
					; The callee shares this frame and may rewrite any local, so
					; the whole live stack is parked before the branch.
					if depth > region-spill [region-spill: depth]
					has-call: 1
					target: first-instruction + instruction/a
					either (scratch/instruction-effects/target and EFFECT_RESUMES) = 0 [
						fallthrough?: false
					][
						if instruction/b <> 0 [
							if depth = 2147483647 [return OUTPUT_FULL]
							depth: depth + 1
							scratch/stack-low/depth: 0
						]
					]
				]
				instruction/op = OP_SUB_RETURN [
					if any [
						region-ordinal = 0
						instruction/b <> 0 instruction/c <> 0
					][return INVALID_IR]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + region-ordinal - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/a = 1
						sub-entry/b = instruction/a
						either instruction/a = 0 [
							any [depth = 0 depth = 1]
						][depth = 1]
					][return INVALID_IR]
					depth: 0
					fallthrough?: false
				]
				instruction/op = OP_JUMP [
					unless all [instruction/b = 0 instruction/c >= 0][
						return UNSUPPORTED
					]
					unless record-plan-depth instruction/a depth fn depths [
						return INVALID_IR
					]
					fallthrough?: false
				]
				instruction/op = OP_BRANCH [
					if any [
						depth < 1 instruction/c <> 0
						not any [instruction/b = 0 instruction/b = 1]
					][return INVALID_IR]
					depth: depth - 1
					unless record-plan-depth instruction/a depth fn depths [
						return INVALID_IR
					]
				]
				instruction/op = OP_SWITCH [
					if any [
						depth < 1 instruction/a < 0 instruction/b <= 0
						instruction/b > view/header/switch-count
						instruction/a > (view/header/switch-count - instruction/b)
					][
						print ["ARM64 plan switch invalid ordinal=" ordinal
							" depth=" depth " first=" instruction/a
							" count=" instruction/b " total=" view/header/switch-count lf]
						return INVALID_IR
					]
					depth: depth - 1
					unless record-plan-depth instruction/c depth fn depths [
						print ["ARM64 plan switch default merge ordinal=" ordinal
							" target=" instruction/c " depth=" depth lf]
						return INVALID_IR
					]
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						unless record-plan-depth switch-case/target depth fn depths [
							print ["ARM64 plan switch case merge ordinal=" ordinal
								" case=" case-index " target=" switch-case/target
								" depth=" depth lf]
							return INVALID_IR
						]
						case-index: case-index + 1
					]
					fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0 instruction/b = 0 instruction/c = 0
					][return INVALID_IR]
					fallthrough?: false
				]
				instruction/op = OP_RETURN [
					unless any [
						all [instruction/a = 0 depth = 0]
						all [instruction/a <> 0 depth = 1]
					][
						print ["ARM64 plan return invalid ordinal=" ordinal
							" ref=" instruction/a " depth=" depth
							" region=" region-ordinal lf]
						return INVALID_IR
					]
					depth: 0
					fallthrough?: false
				]
				true []
			]
			id: id + 1
		]
		if fallthrough? [
			print ["ARM64 plan fallthrough ordinal=" last-plan-ordinal
				" depth=" depth " region=" region-ordinal lf]
			return INVALID_IR
		]
		either region-ordinal = 0 [
			if region-spill > max-spill [max-spill: region-spill]
		][
			scratch/entry-spill-limits/region-ordinal: region-spill
		]
		if any [
			all [sub-entry-count > 0 main-entry-count <> 1]
			all [sub-entry-count = 0 main-entry-count <> 0]
		][
			print ["ARM64 plan entry counts main=" main-entry-count
				" sub=" sub-entry-count " ordinal=" last-plan-ordinal lf]
			return INVALID_IR
		]
		if sub-entry-count > 0 [has-call: 1]
		if frame-anchor? [
			home-register: available-home-register reserved-home-mask home-mask
			if home-register < 0 [return UNSUPPORTED]
			mask: 1 << (home-register - FIRST_HOME_REGISTER)
			reserved-home-mask: reserved-home-mask or mask
			home-mask: home-mask or mask
			home-count: home-count + 1
			plan/frame-anchor-register: home-register
		]
		if stack-all? [
			id: 1
			while [id <= count][
				if scratch/storage-kinds/id = STORAGE_REGISTER [
					scratch/storage-kinds/id: STORAGE_FRAME
				]
				id: id + 1
			]
		]
		float-home-count: 0
		frame-home-count: 0
		id: 1
		while [id <= count][
			if scratch/storage-kinds/id = STORAGE_REGISTER [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
				if parameter/flags <> 0 [
					print ["ARM64 plan register flags id=" id " flags=" parameter/flags lf]
					return UNSUPPORTED
				]
				kind: 0
				if parameter/type <> 0 [
					width: value-width parameter/type view
					kind: type-kind parameter/type view
					if width = 0 [return INVALID_IR]
					if width > 8 [
						print ["ARM64 plan register width id=" id " type=" parameter/type
							" width=" width lf]
						return UNSUPPORTED
					]
				]
				if id <= fn/parameter-count [
					status: abi-parameter-location view layout PARAMETER_TABLE
						fn/first-parameter fn/parameter-count id abi-location
					if status < 0 [
						print ["ARM64 plan ABI location id=" id " status=" status
							" params=" fn/parameter-count lf]
						return status
					]
				]
				either any [kind = 9 kind = 10][
					either float-home-count = FLOAT_HOME_REGISTER_COUNT [
						scratch/storage-kinds/id: STORAGE_FRAME
					][
						float-home-count: float-home-count + 1
						scratch/homes/id: FIRST_FLOAT_HOME_REGISTER
							+ float-home-count - 1
					]
				][
					home-register: available-home-register reserved-home-mask home-mask
					either home-register < 0 [
						scratch/storage-kinds/id: STORAGE_FRAME
					][
						home-count: home-count + 1
						mask: 1 << (home-register - FIRST_HOME_REGISTER)
						home-mask: home-mask or mask
						scratch/homes/id: home-register
					]
				]
			]
			if scratch/storage-kinds/id = STORAGE_FRAME [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
				either parameter/flags = INLINE [
					; The whole aggregate lives in the frame, so it claims as
					; many eight-byte slots as its layout needs. Pointing the
					; home at the last of them puts the base at the lowest
					; address of the run.
					inline-size: 0
					inline-align: 0
					unless layout-type parameter/type true view layout 0
						:inline-size :inline-align [return INVALID_IR]
					if any [inline-size <= 0 inline-align > 16][
						print ["ARM64 plan inline layout id=" id " size=" inline-size
							" align=" inline-align lf]
						return UNSUPPORTED
					]
					if id <= fn/parameter-count [
						status: abi-parameter-location view layout PARAMETER_TABLE
							fn/first-parameter fn/parameter-count id abi-location
						if status < 0 [return status]
					]
					slot: (inline-size + 7) / 8
					if frame-home-count > (2147483647 - slot)[return OUTPUT_FULL]
					frame-home-count: frame-home-count + slot
				][
					width: value-width parameter/type view
					kind: type-kind parameter/type view
					if width = 0 [return INVALID_IR]
					if width > 8 [
						print ["ARM64 plan frame width id=" id " type=" parameter/type
							" width=" width " flags=" parameter/flags lf]
						return UNSUPPORTED
					]
					if id <= fn/parameter-count [
						status: abi-parameter-location view layout PARAMETER_TABLE
							fn/first-parameter fn/parameter-count id abi-location
						if status < 0 [return status]
					]
					frame-home-count: frame-home-count + 1
				]
				scratch/homes/id: 0 - frame-home-count
			]
			id: id + 1
		]
		id: 1
		while [id <= view/header/global-count][
			either scratch/global-homes/id > 1 [
				home-register: available-home-register reserved-home-mask home-mask
				either home-register >= 0 [
					home-count: home-count + 1
					mask: 1 << (home-register - FIRST_HOME_REGISTER)
					home-mask: home-mask or mask
					scratch/global-homes/id: home-register
				][scratch/global-homes/id: -1]
			][
				if scratch/global-homes/id > 0 [scratch/global-homes/id: -1]
			]
			id: id + 1
		]
		id: 1
		while [id <= count][
			if scratch/storage-kinds/id = STORAGE_FRAME [
				slot: 0 - scratch/homes/id
				scratch/homes/id: 0 - ((plan/frame-prefix-count
					+ home-count + float-home-count + slot) * 8)
			]
			id: id + 1
		]
		if plan/frame-prefix-count > (2147483647 - home-count)[return OUTPUT_FULL]
		total-slots: plan/frame-prefix-count + home-count
		if total-slots > (2147483647 - float-home-count)[return OUTPUT_FULL]
		total-slots: total-slots + float-home-count
		if total-slots > (2147483647 - frame-home-count)[return OUTPUT_FULL]
		total-slots: total-slots + frame-home-count
		if total-slots > (2147483647 - max-spill)[return OUTPUT_FULL]
		total-slots: total-slots + max-spill
		; Lay the per-region windows out in instruction order, each followed by
		; the slot that holds the link register while that subroutine runs.
		entry-base: total-slots
		if sub-entry-count > 0 [
			id: 1
			while [id <= fn/instruction-count][
				instruction: as rsir-instruction! (view/instructions
					+ ((first-instruction + id - 1) * RSIR_INSTRUCTION_SIZE))
				if instruction/op = OP_ENTRY [
					region-spill: scratch/entry-spill-limits/id
					if entry-base > (2147483647 - region-spill - 1)[
						return OUTPUT_FULL
					]
					scratch/entry-spill-bases/id: entry-base
					entry-base: entry-base + region-spill
					scratch/entry-spill-limits/id: entry-base
					if instruction/a = 1 [entry-base: entry-base + 1]
				]
				id: id + 1
			]
		]
		total-slots: entry-base
		if total-slots > (2147483647 / 8) [return OUTPUT_FULL]
		frame-allocation: total-slots * 8
		result-used: frame-allocation
		id: 1
		while [id <= fn/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + id - 1) * RSIR_INSTRUCTION_SIZE))
			if instruction/op = OP_CALL [
				call-return: 0
				call-first-parameter: 0
				call-parameter-count: 0
				call-reference: 0
				call-source: PARAMETER_TABLE
				call-flags: 0
				call-signature: instruction/c
				if all [call-signature > 0 (type-kind call-signature view) = -8][
					typed-metadata: as rsir-type! (view/types
						+ (((canonical-type call-signature view) - 1) * RSIR_TYPE_SIZE))
					call-signature: typed-metadata/target
				]
				status: resolve-call instruction/a call-signature view
					:call-return :call-first-parameter :call-parameter-count
					:call-reference :call-source :call-flags
				if status < 0 [return status]
				if (call-flags and RETURN_VALUE) <> 0 [
					unless aggregate-ref? call-return view [return INVALID_IR]
					result-size: 0
					result-align: 0
					unless layout-type call-return true view layout 0
						:result-size :result-align [return INVALID_IR]
					if any [result-size <= 0 result-align <= 0 result-align > 16][
						return UNSUPPORTED
					]
					if result-used > (2147483647 - result-size)[return OUTPUT_FULL]
					result-used: align (result-used + result-size) 16
					if result-used < 0 [return OUTPUT_FULL]
					result-offsets/id: 0 - result-used
				]
			]
			id: id + 1
		]
		frame-allocation: result-used
		if frame-allocation > (2147483647 - outgoing-size)[return OUTPUT_FULL]
		frame-allocation: align (frame-allocation + outgoing-size) 16
		if frame-allocation < 0 [return OUTPUT_FULL]
		plan/storage-count: fn/parameter-count + fn/local-count
		plan/home-count: home-count
		plan/home-mask: home-mask
		plan/float-home-count: float-home-count
		plan/frame-home-count: frame-home-count
		plan/spill-count: max-spill
		plan/has-call: has-call
		if plan/frame-anchor-register <> arm64-encoder/FP [
			mask: 1 << (plan/frame-anchor-register - FIRST_HOME_REGISTER)
			slot: 0
			id: 0
			while [id < HOME_REGISTER_COUNT][
				mask: 1 << id
				if (home-mask and mask) <> 0 [slot: slot + 1]
				if mask = (1 << (plan/frame-anchor-register
					- FIRST_HOME_REGISTER)) [
					plan/frame-anchor-offset: 0
						- ((plan/frame-prefix-count + slot) * 8)
					break
				]
				id: id + 1
			]
			if plan/frame-anchor-offset = 0 [return INVALID_IR]
		]
		plan/frame-allocation: frame-allocation
		0
	]

	compiler-frame-load: func [
		code [byte-ptr!]
		capacity target displacement width signed result-width [integer!]
		return: [integer!]
	][
		if compiler-frame-active? [
			return arm64-encoder/register-load code capacity target
				compiler-frame-register displacement width signed result-width
				arm64-encoder/X16
		]
		arm64-encoder/frame-load code capacity target displacement width signed
			result-width
	]

	compiler-frame-store: func [
		code [byte-ptr!]
		capacity source displacement width [integer!]
		return: [integer!]
	][
		if compiler-frame-active? [
			return arm64-encoder/register-store code capacity source
				compiler-frame-register displacement width arm64-encoder/X16
		]
		arm64-encoder/frame-store code capacity source displacement width
	]

	compiler-float-frame-load: func [
		code [byte-ptr!]
		capacity target displacement width [integer!]
		return: [integer!]
	][
		if compiler-frame-active? [
			return arm64-encoder/float-register-load code capacity target
				compiler-frame-register displacement width arm64-encoder/X16
		]
		arm64-encoder/float-frame-load code capacity target displacement width
	]

	compiler-float-frame-store: func [
		code [byte-ptr!]
		capacity source displacement width [integer!]
		return: [integer!]
	][
		if compiler-frame-active? [
			return arm64-encoder/float-register-store code capacity source
				compiler-frame-register displacement width arm64-encoder/X16
		]
		arm64-encoder/float-frame-store code capacity source displacement width
	]

	emit-frame-normalize: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded [integer!]
	][
		if any [
			plan/frame-anchor-register = arm64-encoder/FP
			plan/visible-frame-offset = 0
		][return 0]
		written: compiler-frame-store code capacity arm64-encoder/FP
			plan/visible-frame-offset 8
		if written < 0 [return OUTPUT_FULL]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP plan/frame-anchor-register 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-visible-frame-restore: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded [integer!]
	][
		if any [
			plan/frame-anchor-register = arm64-encoder/FP
			plan/visible-frame-offset = 0
		][return 0]
		written: compiler-frame-load code capacity arm64-encoder/X16
			plan/visible-frame-offset 8 0 8
		if written < 0 [return OUTPUT_FULL]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP arm64-encoder/X16 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-prologue: func [
		view [rsir-view!]
		fn [rsir-function!]
		entry? [logic!]
		layout [arm64-layout-state!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			abi-location [arm64-abi-location! value]
			at [byte-ptr!]
			written encoded index slot width transfer-width target signed kind
				parameter-register register mask saved-count status
				source offset remaining copy-width [integer!]
	][
		if all [
			plan/home-count = 0
			plan/float-home-count = 0
			plan/frame-home-count = 0
			plan/has-call = 0
			plan/hidden-return-offset = 0
			plan/tag-offset = 0
		][return 0]
		written: arm64-encoder/frame-enter code capacity plan/frame-allocation
		if written < 0 [return OUTPUT_FULL]
		if plan/hidden-return-offset <> 0 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-store at (capacity - written)
				arm64-encoder/X8 plan/hidden-return-offset 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		plan/unwind-fixup: -1
		if plan/unwind = 1 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-store at (capacity - written)
				arm64-encoder/FP plan/visible-frame-offset 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			either entry? [
				encoded: compiler-frame-store at (capacity - written)
					arm64-encoder/ZR -24 8
			][
				plan/unwind-fixup: written
				encoded: arm64-encoder/address-relative at (capacity - written)
					arm64-encoder/X16 0
			]
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			unless entry? [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-store at (capacity - written)
					arm64-encoder/X16 arm64-encoder/FP -24 8 arm64-encoder/X17
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			case [
				entry? [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/address-relative at (capacity - written)
						arm64-encoder/X16 16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/move-immediate at (capacity - written)
						arm64-encoder/X17 4 -1 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/FP -16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at (capacity - written) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/trap at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				(fn/flags and CATCH_FLAG) <> 0 [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/move-immediate at (capacity - written)
						arm64-encoder/X17 4 -2 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/ZR arm64-encoder/X17 arm64-encoder/FP -16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				true [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/ZR arm64-encoder/ZR arm64-encoder/FP -16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
			]
		]
		saved-count: 0
		index: 0
		while [index < HOME_REGISTER_COUNT][
			mask: 1 << index
			if (plan/home-mask and mask) <> 0 [
				saved-count: saved-count + 1
				register: FIRST_HOME_REGISTER + index
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-store at (capacity - written)
					register arm64-encoder/FP
					(0 - ((plan/frame-prefix-count + saved-count) * 8)) 8
					arm64-encoder/X16
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			index: index + 1
		]
		if saved-count <> plan/home-count [return INVALID_IR]
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				plan/frame-anchor-register arm64-encoder/FP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		compiler-frame-active?: true
		index: 0
		while [index < plan/float-home-count][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-float-frame-store at (capacity - written)
				(FIRST_FLOAT_HOME_REGISTER + index)
				(0 - ((plan/frame-prefix-count + plan/home-count
					+ index + 1) * 8)) 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			index: index + 1
		]
		slot: 1
		while [slot <= fn/parameter-count][
			target: scratch/homes/slot
			if target <> 0 [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
				status: abi-parameter-location view layout PARAMETER_TABLE
					fn/first-parameter fn/parameter-count slot abi-location
				if status < 0 [return status]
				width: value-width parameter/type view
				kind: type-kind parameter/type view
				if parameter/flags = INLINE [
					if target > 0 [return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/address-offset at (capacity - written)
						arm64-encoder/X14 compiler-frame-register target arm64-encoder/X16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					case [
						abi-location/class = ABI_GPR [
							offset: 0
							index: 0
							while [index < abi-location/register-count][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-store at (capacity - written)
									(abi-location/register-index + index) arm64-encoder/X14
									offset 8 arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								offset: offset + 8
								index: index + 1
							]
						]
						abi-location/class = ABI_SIMD [
							offset: 0
							index: 0
							while [index < abi-location/register-count][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-register-store at
									(capacity - written) (abi-location/register-index + index)
									arm64-encoder/X14 offset abi-location/hfa-width
									arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								offset: offset + abi-location/hfa-width
								index: index + 1
							]
						]
						abi-location/class = ABI_STACK [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/address-offset at (capacity - written)
								arm64-encoder/X15 arm64-encoder/FP
								(16 + abi-location/stack-offset) arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 abi-location/size
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						abi-location/class = ABI_INDIRECT [
							either abi-location/register-index >= 0 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/move-register at (capacity - written)
									arm64-encoder/X15 abi-location/register-index 8
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-load at (capacity - written)
									arm64-encoder/X15 arm64-encoder/FP
									(16 + abi-location/stack-offset) 8 0 8
									arm64-encoder/X16
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 abi-location/size
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						true [return INVALID_IR]
					]
					slot: slot + 1
					continue
				]
				transfer-width: either width = 8 [8][4]
				parameter-register: abi-location/register-index
				case [
					abi-location/class = ABI_GPR [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: either target > 0 [
							either width < 4 [
								signed: either signed-type? parameter/type view [1][0]
								arm64-encoder/extend-register at (capacity - written)
									target parameter-register width signed
							][
								arm64-encoder/move-register at (capacity - written)
									target parameter-register transfer-width
							]
						][
							compiler-frame-store at (capacity - written)
								parameter-register target width
						]
					]
					abi-location/class = ABI_SIMD [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: either target > 0 [
							arm64-encoder/float-move-register at (capacity - written)
								target parameter-register width
						][
							compiler-float-frame-store at (capacity - written)
								parameter-register target width
						]
					]
					abi-location/class = ABI_STACK [
						parameter-register: either target > 0 [target][
							either any [kind = 9 kind = 10][
								FLOAT_SCRATCH_REGISTER
							][arm64-encoder/X17]
						]
						signed: either signed-type? parameter/type view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: either any [kind = 9 kind = 10][
							arm64-encoder/float-register-load at (capacity - written)
								parameter-register arm64-encoder/FP
								(16 + abi-location/stack-offset) width arm64-encoder/X16
						][
							arm64-encoder/register-load at (capacity - written)
								parameter-register arm64-encoder/FP
								(16 + abi-location/stack-offset) width signed
								transfer-width arm64-encoder/X16
						]
						if target <= 0 [
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either any [kind = 9 kind = 10][
								compiler-float-frame-store at (capacity - written)
									FLOAT_SCRATCH_REGISTER target width
							][
								compiler-frame-store at (capacity - written)
									arm64-encoder/X17 target width
							]
						]
					]
					true [return INVALID_IR]
				]
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			slot: slot + 1
		]
		written
	]

	emit-home-restore: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			written encoded index register mask saved-count [integer!]
	][
		written: 0
		index: 0
		while [index < plan/float-home-count][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-float-frame-load at (capacity - written)
				(FIRST_FLOAT_HOME_REGISTER + index)
				(0 - ((plan/frame-prefix-count + plan/home-count
					+ index + 1) * 8)) 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			index: index + 1
		]
		index: 0
		saved-count: 0
		while [index < HOME_REGISTER_COUNT][
			mask: 1 << index
			if (plan/home-mask and mask) <> 0 [
				saved-count: saved-count + 1
				register: FIRST_HOME_REGISTER + index
				if register <> plan/frame-anchor-register [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: compiler-frame-load at (capacity - written)
						register
						(0 - ((plan/frame-prefix-count + saved-count) * 8)) 8 0 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
			]
			index: index + 1
		]
		if saved-count <> plan/home-count [return INVALID_IR]
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-load at (capacity - written)
				plan/frame-anchor-register plan/frame-anchor-offset 8 0 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
	]

	emit-epilogue: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded [integer!]
	][
		if all [
			plan/home-count = 0
			plan/float-home-count = 0
			plan/frame-home-count = 0
			plan/has-call = 0
			plan/hidden-return-offset = 0
			plan/tag-offset = 0
		][
			return arm64-encoder/return-near code capacity
		]
		written: 0
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/FP plan/frame-anchor-register 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		compiler-frame-active?: true
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-home-restore plan at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-leave at (capacity - written)
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-unwind-handler: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded [integer!]
	][
		written: 0
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/FP plan/frame-anchor-register 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		compiler-frame-active?: true
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-home-restore plan at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/unwind-frame at (capacity - written)
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X3
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	materialize: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		stack-slot target target-ref [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			source-ref source-width target-width source-kind target-kind
			operation-width signed high written encoded [integer!]
			direct-immediate? [logic!]
	][
		if scratch/stack-kinds/stack-slot <> VALUE [return INVALID_IR]
		source-ref: scratch/stack-types/stack-slot
		source-width: value-width source-ref view
		target-width: value-width target-ref view
		if any [
			source-width = 0 source-width > 8
			target-width = 0 target-width > 8
		][return UNSUPPORTED]
		source-kind: type-kind source-ref view
		target-kind: type-kind target-ref view
		if any [
			source-kind = 9 source-kind = 10
			target-kind = 9 target-kind = 10
		][
			unless all [
				any [source-kind = 9 source-kind = 10]
				any [target-kind = 9 target-kind = 10]
			][return UNSUPPORTED]
			written: 0
			case [
				scratch/stack-locations/stack-slot = LOCATION_IMMEDIATE [
					direct-immediate?: true
					encoded: arm64-encoder/float-move-immediate code capacity target
						source-width scratch/stack-low/stack-slot
						scratch/stack-high/stack-slot
					if encoded < 0 [
						direct-immediate?: false
						encoded: arm64-encoder/move-immediate code capacity
							arm64-encoder/X16 source-width
							scratch/stack-low/stack-slot scratch/stack-high/stack-slot
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					either direct-immediate? [
						encoded: 0
					][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/float-move-from-register at
							(capacity - written) target arm64-encoder/X16 source-width
					]
				]
				scratch/stack-locations/stack-slot = LOCATION_REGISTER [
					encoded: arm64-encoder/float-move-register code capacity target
						scratch/stack-low/stack-slot source-width
				]
				scratch/stack-locations/stack-slot = LOCATION_FRAME [
					encoded: compiler-float-frame-load code capacity target
						scratch/stack-low/stack-slot source-width
				]
				true [return INVALID_IR]
			]
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			if source-width <> target-width [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/float-convert at (capacity - written)
					target target source-width target-width
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			return written
		]
		operation-width: either target-width = 8 [8][4]
		signed: either signed-type? source-ref view [1][0]
		case [
			scratch/stack-locations/stack-slot = LOCATION_IMMEDIATE [
				high: scratch/stack-high/stack-slot
				if all [
					target-width = 8 source-width < 8
					integer-type? source-ref view
				][
					high: either all [
						signed = 1 scratch/stack-low/stack-slot < 0
					][-1][0]
				]
				arm64-encoder/move-immediate code capacity target operation-width
					scratch/stack-low/stack-slot high
			]
			scratch/stack-locations/stack-slot = LOCATION_REGISTER [
				either all [
					target-width = 8
					source-width < 8
					integer-type? source-ref view
				][
					arm64-encoder/extend-register code capacity target
						scratch/stack-low/stack-slot source-width signed
				][
					either scratch/stack-low/stack-slot = target [0][
						arm64-encoder/move-register code capacity target
							scratch/stack-low/stack-slot operation-width
					]
				]
			]
			scratch/stack-locations/stack-slot = LOCATION_FLAGS [
				arm64-encoder/condition-result code capacity target
					scratch/stack-low/stack-slot
			]
			scratch/stack-locations/stack-slot = LOCATION_FRAME [
				compiler-frame-load code capacity target
					scratch/stack-low/stack-slot source-width signed operation-width
			]
			true [INVALID_IR]
		]
	]

	emit-stack-resize: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		stack-slot result-register [integer!]
		allocate? clear? [logic!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded operation [integer!]
	][
		written: materialize view scratch stack-slot arm64-encoder/X16 -7
			code capacity
		if written < 0 [return written]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/add-immediate at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X16 1 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/logical-immediate at (capacity - written)
			arm64-encoder/OP_AND arm64-encoder/X16 arm64-encoder/X16 8 -2 -1
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X17 arm64-encoder/X16 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		operation: either allocate? [arm64-encoder/OP_SUB][arm64-encoder/OP_ADD]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/add-extended-register at (capacity - written)
			operation
			arm64-encoder/SP arm64-encoder/SP arm64-encoder/X16 8 0 3
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if allocate? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				result-register arm64-encoder/SP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X16 arm64-encoder/SP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/branch-zero at (capacity - written)
				arm64-encoder/X17 8 16 false
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store-post at (capacity - written)
				arm64-encoder/ZR arm64-encoder/X16 8 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-immediate at (capacity - written)
				arm64-encoder/X17 arm64-encoder/X17 -1 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/branch-zero at (capacity - written)
				arm64-encoder/X17 8 -8 true
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
	]

	merge-control-target: func [
		target depth [integer!]
		fn [rsir-function!]
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depths entry-types entry-kinds entry-flags [int-ptr!]
		return: [logic!]
		/local ref [integer!]
	][
		if any [target <= 0 target > fn/instruction-count][return false]
		either depths/target >= 0 [
			if depths/target <> depth [return false]
			if depth > 0 [
				ref: merged-type entry-types/target scratch/stack-types/depth view
				if any [
					ref = 0
					entry-kinds/target <> scratch/stack-kinds/depth
					entry-flags/target <> scratch/stack-flags/depth
				][return false]
				entry-types/target: ref
			]
		][
			depths/target: depth
			if depth > 0 [
				entry-types/target: scratch/stack-types/depth
				entry-kinds/target: scratch/stack-kinds/depth
				entry-flags/target: scratch/stack-flags/depth
			]
		]
		true
	]

	canonicalize-stack: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			slot ref kind target limit written encoded [integer!]
	][
		written: 0
		slot: 1
		while [slot <= depth][
			if scratch/stack-kinds/slot <> VALUE [return UNSUPPORTED]
			ref: scratch/stack-types/slot
			kind: type-kind ref view
			target: either any [kind = 9 kind = 10][
				FIRST_FLOAT_TEMP_REGISTER + slot - 1
			][FIRST_TEMP_REGISTER + slot - 1]
			limit: either any [kind = 9 kind = 10][
				FIRST_FLOAT_TEMP_REGISTER + FLOAT_TEMP_REGISTER_COUNT
			][FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT]
			if target >= limit [return UNSUPPORTED]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch slot target ref at (capacity - written)
			if encoded < 0 [return encoded]
			written: written + encoded
			scratch/stack-locations/slot: LOCATION_REGISTER
			scratch/stack-low/slot: target
			scratch/stack-high/slot: 0
			slot: slot + 1
		]
		written
	]

	spill-live-stack: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth region-base region-limit [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			slot ref kind width target displacement written encoded [integer!]
			floating? [logic!]
	][
		if (region-base + depth) > region-limit [return INVALID_IR]
		written: 0
		slot: 1
		while [slot <= depth][
			if any [
				scratch/stack-locations/slot = LOCATION_FLAGS
				scratch/stack-locations/slot = LOCATION_REGISTER
			][
				kind: scratch/stack-kinds/slot
				unless any [kind = VALUE kind = PLACE][return INVALID_IR]
				ref: scratch/stack-types/slot
				width: either kind = PLACE [8][value-width ref view]
				unless any [width = 1 width = 2 width = 4 width = 8][
					return UNSUPPORTED
				]
				floating?: all [kind = VALUE float-type? ref view]
				target: either scratch/stack-locations/slot = LOCATION_REGISTER [
					scratch/stack-low/slot
				][either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]]
				if scratch/stack-locations/slot = LOCATION_FLAGS [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch slot target ref
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
				]
				displacement: 0 - ((region-base + slot) * 8)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: either floating? [
					compiler-float-frame-store at (capacity - written)
						target displacement width
				][
					compiler-frame-store at (capacity - written)
						target displacement width
				]
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				scratch/stack-locations/slot: LOCATION_FRAME
				scratch/stack-low/slot: displacement
				scratch/stack-high/slot: 0
			]
			slot: slot + 1
		]
		written
	]

	emit-stack-all: func [
		code [byte-ptr!]
		capacity [integer!]
		restore? [logic!]
		return: [integer!]
		/local at [byte-ptr!]
			written encoded register offset system-register [integer!]
	][
		written: 0
		either restore? [
			register: 0
			while [register < 32][
				offset: 272 + (register * 16)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/load-vector-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP offset
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				register: register + 2
			]
			system-register: arm64-encoder/SYSTEM_NZCV
			while [system-register <= arm64-encoder/SYSTEM_FPSR][
				offset: 240 + (system-register * 8)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-load at (capacity - written)
					arm64-encoder/X16 arm64-encoder/SP offset 8 0 8
					arm64-encoder/X17
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/write-system-register at
					(capacity - written) system-register arm64-encoder/X16
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				system-register: system-register + 1
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-load at (capacity - written)
				arm64-encoder/LR arm64-encoder/SP 240 8 0 8 arm64-encoder/X16
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			register: 0
			while [register < 30][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/load-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP (register * 8)
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				register: register + 2
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-immediate at (capacity - written)
				arm64-encoder/SP arm64-encoder/SP STACK_ALL_SIZE 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		][
			encoded: arm64-encoder/stack-subtract code capacity STACK_ALL_SIZE
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			register: 0
			while [register < 30][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/store-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP (register * 8)
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				register: register + 2
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				arm64-encoder/LR arm64-encoder/SP 240 8 arm64-encoder/X16
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			system-register: arm64-encoder/SYSTEM_NZCV
			while [system-register <= arm64-encoder/SYSTEM_FPSR][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/read-system-register at
					(capacity - written) arm64-encoder/X16 system-register
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				offset: 240 + (system-register * 8)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-store at (capacity - written)
					arm64-encoder/X16 arm64-encoder/SP offset 8 arm64-encoder/X17
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				system-register: system-register + 1
			]
			register: 0
			while [register < 32][
				offset: 272 + (register * 16)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/store-vector-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP offset
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				register: register + 2
			]
		]
		written
	]

	restore-control-stack: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth target [integer!]
		entry-types entry-kinds entry-flags [int-ptr!]
		return: [logic!]
		/local slot kind register limit [integer!]
	][
		if depth > 0 [
			scratch/stack-types/depth: entry-types/target
			scratch/stack-kinds/depth: entry-kinds/target
			scratch/stack-flags/depth: entry-flags/target
		]
		slot: 1
		while [slot <= depth][
			if scratch/stack-kinds/slot <> VALUE [return false]
			kind: type-kind scratch/stack-types/slot view
			register: either any [kind = 9 kind = 10][
				FIRST_FLOAT_TEMP_REGISTER + slot - 1
			][FIRST_TEMP_REGISTER + slot - 1]
			limit: either any [kind = 9 kind = 10][
				FIRST_FLOAT_TEMP_REGISTER + FLOAT_TEMP_REGISTER_COUNT
			][FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT]
			if register >= limit [return false]
			scratch/stack-locations/slot: LOCATION_REGISTER
			scratch/stack-low/slot: register
			scratch/stack-high/slot: 0
			slot: slot + 1
		]
		true
	]

	emit-catch-open: func [
		code [byte-ptr!]
		capacity level target-offset current-offset [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			record-slot pair-displacement displacement written encoded [integer!]
	][
		if level <= 0 [return INVALID_IR]
		record-slot: 5 + ((level - 1) * 3)
		pair-displacement: 0 - ((record-slot + 1) * 8)
		written: arm64-encoder/address-offset code capacity arm64-encoder/X2
			compiler-frame-register pair-displacement arm64-encoder/X16
		if written < 0 [return OUTPUT_FULL]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/load-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 compiler-frame-register -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/X2 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/X16 arm64-encoder/SP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/register-store at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X2 -8 8 arm64-encoder/X17
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		displacement: either null? code [0][
			target-offset - (current-offset + written)
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/address-relative at (capacity - written)
			arm64-encoder/X16 displacement
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X3 compiler-frame-register -16
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-catch-restore: func [
		code [byte-ptr!]
		capacity level [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			record-slot pair-displacement written encoded [integer!]
	][
		if level <= 0 [return INVALID_IR]
		record-slot: 5 + ((level - 1) * 3)
		pair-displacement: 0 - ((record-slot + 1) * 8)
		written: arm64-encoder/address-offset code capacity arm64-encoder/X2
			compiler-frame-register pair-displacement arm64-encoder/X16
		if written < 0 [return OUTPUT_FULL]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/load-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/X2 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 compiler-frame-register -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/register-load at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X2 -8 8 0 8 arm64-encoder/X17
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/SP arm64-encoder/X16 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-throw-unwind: func [
		code [byte-ptr!]
		capacity [integer!]
		skip-current? [logic!]
		return: [integer!]
		/local at [byte-ptr!] encoded written loop-offset [integer!]
	][
		written: 0
		; X3 remains the throw-search continuation while cleanup stubs pop
		; skipped frames and branch back into this loop.
		loop-offset: either skip-current? [12][4]
		encoded: arm64-encoder/address-relative code capacity
			arm64-encoder/X3 loop-offset
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if skip-current? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/frame-load at (capacity - written)
				arm64-encoder/X2 -24 8 0 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/jump-register at (capacity - written)
				arm64-encoder/X2
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X1 -8 4 0 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/compare-register at (capacity - written)
			arm64-encoder/X1 arm64-encoder/X0 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/branch-condition at (capacity - written)
			arm64-encoder/CS 12
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X2 -24 8 0 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X2
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X1 -16 8 0 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/branch-zero at (capacity - written)
			arm64-encoder/X1 8 8 true
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/X1 arm64-encoder/LR 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X2 VISIBLE_FRAME_OFFSET 8 0 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP arm64-encoder/X2 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X1
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	; A tracked multiplication keeps the half of the product its own type drops,
	; so the flags left behind answer whether anything was lost: NE is overflow.
	emit-tracked-multiply: func [
		target left right result-width signed [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded [integer!]
	][
		written: 0
		if result-width = 4 [
			encoded: arm64-encoder/multiply-long code capacity target left right
				signed
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-extended-register at
				(capacity - written) target target 8 4 signed
			if encoded < 0 [return OUTPUT_FULL]
			return written + encoded
		]
		; A 64-bit product needs both operands twice over, and only X16 and X17
		; are free once the result claims a register of its own.
		if any [
			left = arm64-encoder/X17 right = arm64-encoder/X16
			target = arm64-encoder/X16 target = arm64-encoder/X17
		][return UNSUPPORTED]
		if left <> arm64-encoder/X16 [
			encoded: arm64-encoder/move-register code capacity
				arm64-encoder/X16 left 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		if right <> arm64-encoder/X17 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X17 right 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-register at (capacity - written)
			target arm64-encoder/X16 arm64-encoder/X17 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-high at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X16 arm64-encoder/X17 signed
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		either signed = 1 [
			; Every bit the upper half keeps has to repeat the result's sign.
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/shift-immediate at (capacity - written)
				arm64-encoder/SHIFT_ARITHMETIC arm64-encoder/X17 target 63 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-register at (capacity - written)
				arm64-encoder/X16 arm64-encoder/X17 8
		][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-immediate at (capacity - written)
				arm64-encoder/X16 0 8
		]
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-pointer-binary: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		scratch [arm64-function-scratch!]
		left-slot right-slot target operation [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			left-ref right-ref source-width stride shift scaled high limit opcode
			written encoded right immediate source-signed [integer!]
	][
		unless any [operation = ADD_OPERATION operation = SUBTRACT_OPERATION][
			return INVALID_IR
		]
		left-ref: scratch/stack-types/left-slot
		right-ref: scratch/stack-types/right-slot
		if address-type? right-ref view [
			unless operation = SUBTRACT_OPERATION [return INVALID_IR]
			written: 0
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch left-slot target left-ref
				at (capacity - written)
			if encoded < 0 [return encoded]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch right-slot arm64-encoder/X17 right-ref
				at (capacity - written)
			if encoded < 0 [return encoded]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/subtract-register at (capacity - written)
				target target arm64-encoder/X17 8
			if encoded < 0 [return OUTPUT_FULL]
			return written + encoded
		]
		stride: pointer-stride left-ref view layout
		if stride <= 0 [return UNSUPPORTED]
		written: 0
		; A register-backed right operand may occupy the result target. Save it
		; before materializing the left operand over that register.
		if scratch/stack-locations/right-slot <> LOCATION_IMMEDIATE [
			source-width: value-width right-ref view
			unless any [
				source-width = 1 source-width = 2
				source-width = 4 source-width = 8
			][return UNSUPPORTED]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch right-slot arm64-encoder/X17 right-ref
				at (capacity - written)
			if encoded < 0 [return encoded]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: materialize view scratch left-slot target left-ref
			at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
		if scratch/stack-locations/right-slot = LOCATION_IMMEDIATE [
			high: either scratch/stack-low/right-slot < 0 [-1][0]
			if scratch/stack-high/right-slot <> high [return UNSUPPORTED]
			either scratch/stack-low/right-slot < 0 [
				limit: 80000000h / stride
				if scratch/stack-low/right-slot < limit [
					return UNSUPPORTED
				]
			][
				limit: 7FFFFFFFh / stride
				if scratch/stack-low/right-slot > limit [
					return UNSUPPORTED
				]
			]
			scaled: scratch/stack-low/right-slot * stride
			immediate: either operation = ADD_OPERATION [scaled][0 - scaled]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-immediate at (capacity - written)
				target target immediate 8
			if encoded >= 0 [return written + encoded]
			high: either scaled < 0 [-1][0]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-immediate at (capacity - written)
				arm64-encoder/X17 8 scaled high
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: either operation = ADD_OPERATION [
				arm64-encoder/add-register at (capacity - written)
					target target arm64-encoder/X17 8
			][
				arm64-encoder/subtract-register at (capacity - written)
					target target arm64-encoder/X17 8
			]
			if encoded < 0 [return OUTPUT_FULL]
			return written + encoded
		]

		source-width: value-width right-ref view
		unless any [
			source-width = 1 source-width = 2
			source-width = 4 source-width = 8
		][return UNSUPPORTED]
		right: arm64-encoder/X17
		shift: power-shift stride
		source-signed: either signed-type? right-ref view [1][0]
		opcode: either operation = ADD_OPERATION [
			arm64-encoder/OP_ADD
		][arm64-encoder/OP_SUB]
		if shift >= 0 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-extended-register at (capacity - written)
				opcode target target right source-width
				source-signed shift
			if encoded < 0 [return OUTPUT_FULL]
			return written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/extend-register at (capacity - written)
			right right source-width source-signed
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-immediate at (capacity - written)
			arm64-encoder/X16 8 stride 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-register at (capacity - written)
			right right arm64-encoder/X16 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: either operation = ADD_OPERATION [
			arm64-encoder/add-register at (capacity - written) target target right 8
		][
			arm64-encoder/subtract-register at (capacity - written) target target right 8
		]
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	; Load an exact object chunk without reading beyond its physical size.
	emit-aggregate-chunk-load: func [
		code [byte-ptr!]
		capacity target source offset size [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded part-width part-offset shift [integer!]
	][
		if any [size <= 0 size > 8 target = arm64-encoder/X16
			source = arm64-encoder/X16 source = arm64-encoder/X17][return INVALID_IR]
		written: 0
		encoded: arm64-encoder/move-immediate code capacity target 8 0 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		part-offset: 0
		while [part-offset < size][
			part-width: case [
				(size - part-offset) >= 4 [4]
				(size - part-offset) >= 2 [2]
				true [1]
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-load at (capacity - written)
				arm64-encoder/X16 source (offset + part-offset) part-width 0 8
				arm64-encoder/X17
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			shift: part-offset * 8
			if shift > 0 [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/shift-immediate at (capacity - written)
					arm64-encoder/SHIFT_LEFT arm64-encoder/X16 arm64-encoder/X16 shift 8
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/alu-register at (capacity - written)
				arm64-encoder/OP_OR target target arm64-encoder/X16 8 false
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			part-offset: part-offset + part-width
		]
		written
	]

	emit-aggregate-chunk-store: func [
		code [byte-ptr!]
		capacity source destination offset size [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded part-offset part-width target [integer!]
	][
		if any [
			size <= 0 size > 8
			source = arm64-encoder/X16 source = arm64-encoder/X17
			destination = arm64-encoder/X16 destination = arm64-encoder/X17
		][return INVALID_IR]
		written: 0
		part-offset: 0
		while [part-offset < size][
			part-width: case [
				(size - part-offset) >= 8 [8]
				(size - part-offset) >= 4 [4]
				(size - part-offset) >= 2 [2]
				true [1]
			]
			target: source
			if part-offset > 0 [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/shift-immediate at (capacity - written)
					arm64-encoder/SHIFT_RIGHT arm64-encoder/X17 source
					(part-offset * 8) 8
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				target: arm64-encoder/X17
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				target destination (offset + part-offset) part-width arm64-encoder/X16
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			part-offset: part-offset + part-width
		]
		written
	]

	emit-memory-copy: func [
		code [byte-ptr!]
		capacity destination source size [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded offset width transfer-width [integer!]
	][
		if any [
			size < 0
			destination = arm64-encoder/X16 source = arm64-encoder/X16
			destination = arm64-encoder/X17 source = arm64-encoder/X17
		][return INVALID_IR]
		written: 0
		offset: 0
		while [size > 0][
			width: case [
				size >= 8 [8]
				size >= 4 [4]
				size >= 2 [2]
				true [1]
			]
			transfer-width: either width = 8 [8][4]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-load at (capacity - written)
				arm64-encoder/X16 source offset width 0 transfer-width arm64-encoder/X17
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				arm64-encoder/X16 destination offset width arm64-encoder/X17
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			offset: offset + width
			size: size - width
		]
		written
	]

	compile-function: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		fn [rsir-function!]
		first-instruction [integer!]
		entry? [logic!]
		startup? [logic!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		references [arm64-reference-state!]
		function-offsets [int-ptr!]
		function-base [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local instruction next-instruction following-instruction [rsir-instruction!]
			switch-case [rsir-switch!]
			parameter [rsir-parameter!]
			abi-location [arm64-abi-location! value]
			typed-metadata [rsir-type!]
			typed-member [rsir-member!]
			global [rsir-global!]
			imported [rsir-import!]
			sub-entry [rsir-instruction!]
			overflow-scope [rsir-instruction!]
			at [byte-ptr!]
			instruction-offsets instruction-depths result-offsets entry-types entry-kinds
				entry-flags control-uses catch-depths [int-ptr!]
			index ordinal written encoded depth slot source-slot target-slot
			ref target-ref left-ref right-ref width kind operation opcode target left right folded
			source-width target-width source-kind target-kind
			operation-ref parameter-register cpu-pointer-ref register-id register-width
			displacement condition argument-count argument-base argument-slot
			argument-origin callee-slot callee-slots
			call-target call-return call-first-parameter call-signature call-source
							call-parameter-count call-reference call-flags status load-signed
							result-width stack-offset stack-size fixed-stack-size
				call-mode list-size list-capacity copy-size copy-align copy-offset
					result-offset aggregate-size-value aggregate-align hfa-kind hfa-count
					chunk-offset chunk-size
					record-offset typed-size runtime-id
							region-base region-limit region-entry sub-target link-slot
								catch-level catch-record catch-unwind target-offset
								current-catch-depth target-catch-depth expected-catch-depth
				case-index return-count handler-offset return-size return-align return-hfa-kind
					return-hfa-count return-chunk-offset return-chunk-size return-width
			overflow-anchor overflow-target overflow-condition base-depth
				shift-count last-math-condition
				[integer!]
			member-type member-flags member-offset stride scaled shift
				[integer!]
			tag-variant tag-width-value tag-slot
				[integer!]
				fallthrough? measure? comparison? literal? immediate? taken? pointer?
					reference-comparison? floating? region-link? tracked? right-ready?
					syscall? atomic-old? atomic-overflow? packed-call?
						aggregate-return? hfa-return? aggregate-copy? [logic!]
			syscall-id [integer!]
	][
		instruction-offsets: scratch/instruction-offsets + first-instruction
		instruction-depths: scratch/instruction-depths + first-instruction
		result-offsets: scratch/result-offsets + first-instruction
		entry-types: scratch/entry-types + first-instruction
		entry-kinds: scratch/entry-kinds + first-instruction
		entry-flags: scratch/entry-flags + first-instruction
		control-uses: scratch/control-uses + first-instruction
		catch-depths: scratch/catch-depths + first-instruction
		measure?: null? code
		if measure? [
			index: 1
			while [index <= fn/instruction-count][
				instruction-depths/index: -1
				entry-types/index: 0
				entry-kinds/index: 0
				entry-flags/index: 0
				index: index + 1
			]
		]
		compiler-frame-register: plan/frame-anchor-register
		compiler-frame-active?: false
		written: emit-prologue view fn entry? layout scratch plan code capacity
		if written < 0 [return written]
		compiler-frame-active?: true
		if startup? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X19 arm64-encoder/X0 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X20 arm64-encoder/X1 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-global-homes view scratch (function-base + written)
			references at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
		depth: 0
		fallthrough?: true
		return-count: 0
		tag-variant: 0
		tag-width-value: 0
		tag-slot: 0
		; Region 0 covers a function without subroutines; each OP_ENTRY switches
		; to the window plan-function reserved for that region.
		region-base: plan/frame-prefix-count + plan/home-count + plan/float-home-count
			+ plan/frame-home-count
		region-limit: region-base + plan/spill-count
		region-entry: 0
		region-link?: false
		last-math-condition: -1
		cpu-pointer-ref: 0
		index: 0
		while [index < fn/instruction-count][
			ordinal: index + 1
			last-compile-ordinal: ordinal
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			if all [any [ordinal = 1498 ordinal = 1519]
				fn/instruction-count = 3722] [
				print ["ARM64 call trace ordinal=" ordinal " depth=" depth
					" target=" instruction/a " args=" instruction/b
					" return=" instruction/c lf]
			]
			if all [ordinal <= 5 fn/instruction-count = 2042] [
				print ["ARM64 function2042 before ordinal=" ordinal
					" op=" instruction/op " depth=" depth
					" fallthrough=" fallthrough? lf]
			]
			if instruction/op = OP_ENTRY [
				; An entry is resumed from a BL or from the leading jump, so the
				; expression stack is empty there whichever way control arrives.
				if all [fallthrough? depth <> 0][return INVALID_IR]
				instruction-depths/ordinal: 0
				fallthrough?: false
			]
			either fallthrough? [
				if control-uses/ordinal > 0 [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
				]
				unless merge-control-target ordinal depth fn view scratch
					instruction-depths entry-types entry-kinds entry-flags [
					return INVALID_IR
				]
				if control-uses/ordinal > 0 [
					unless restore-control-stack view scratch depth ordinal
						entry-types entry-kinds entry-flags [return UNSUPPORTED]
				]
			][
				if instruction-depths/ordinal < 0 [
					instruction-offsets/ordinal: written
					index: index + 1
					continue
				]
				depth: instruction-depths/ordinal
				unless restore-control-stack view scratch depth ordinal
					entry-types entry-kinds entry-flags [return UNSUPPORTED]
				fallthrough?: true
			]
			instruction-offsets/ordinal: written
			if any [
				instruction/op = OP_CAST
				instruction/op = OP_CALL
				instruction/op = OP_SUB_CALL
				instruction/op = OP_JUMP
				instruction/op = OP_BRANCH
				instruction/op = OP_SWITCH
				instruction/op = OP_ENTRY
				instruction/op = OP_CATCH
			][last-math-condition: -1]
			; A pending variant tag names one place, so that place cannot
			; be discarded before the store lands on it.
			if all [
				tag-variant <> 0
				depth = tag-slot
				any [
					instruction/op = OP_REFERENCE
					instruction/op = OP_DROP
				]
			][return UNSUPPORTED]
			case [
				instruction/op = OP_LITERAL [
					width: value-width instruction/a view
					kind: type-kind instruction/a view
					if width = 0 [return INVALID_IR]
					if width > 8 [return UNSUPPORTED]
					depth: depth + 1
					scratch/stack-types/depth: instruction/a
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_IMMEDIATE
					scratch/stack-low/depth: instruction/b
					scratch/stack-high/depth: instruction/c
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_CAST [
					unless all [
						depth > 0 scratch/stack-kinds/depth = VALUE
						valid-type-ref? instruction/a view
						instruction/b = 0
						any [instruction/c = 0 instruction/c = 1]
					][return INVALID_IR]
					ref: scratch/stack-types/depth
					target-ref: instruction/a
					unless scalar-cast-compatible? ref target-ref view [return UNSUPPORTED]
					source-width: value-width ref view
					target-width: value-width target-ref view
					source-kind: type-kind ref view
					target-kind: type-kind target-ref view
					floating?: any [
						source-kind = 9 source-kind = 10
						target-kind = 9 target-kind = 10
					]
					if all [
						instruction/c = 0
						target-kind = 11
						any [
							reference-type? ref view
							(source-kind = -2)
							(source-kind = -3)
						]
					][
						target: FIRST_TEMP_REGISTER + depth - 1
						if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
							return UNSUPPORTED
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth target ref
							at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/condition-result at
							(capacity - written) target arm64-encoder/NE
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						scratch/stack-types/depth: target-ref
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					if floating? [
						either instruction/c = 1 [
							unless any [
								source-kind = target-kind
								all [source-kind = 5 target-kind = 9]
								all [source-kind = 9 target-kind = 5]
							][return INVALID_IR]
						][
							unless any [
								all [
									any [source-kind = 9 source-kind = 10]
									any [target-kind = 9 target-kind = 10]
								]
								all [source-kind = 5
									any [target-kind = 9 target-kind = 10]]
								all [any [source-kind = 9 source-kind = 10]
									target-kind = 5]
							][return INVALID_IR]
						]
						target: either any [target-kind = 9 target-kind = 10][
							FIRST_FLOAT_TEMP_REGISTER + depth - 1
						][FIRST_TEMP_REGISTER + depth - 1]
						if any [
							all [any [target-kind = 9 target-kind = 10]
								target >= (FIRST_FLOAT_TEMP_REGISTER
									+ FLOAT_TEMP_REGISTER_COUNT)]
							all [target-kind = 5
								target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)]
						][return UNSUPPORTED]
						encoded: 0
						case [
							all [instruction/c = 1 source-kind = target-kind][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth target target-ref
									at (capacity - written)
							]
							all [instruction/c = 1 source-kind = 5][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth arm64-encoder/X16 ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-move-from-register at
									(capacity - written) target arm64-encoder/X16 4
							]
							instruction/c = 1 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth
									FLOAT_SCRATCH_REGISTER ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-move-to-register at
									(capacity - written) target FLOAT_SCRATCH_REGISTER 4
							]
							all [
								any [source-kind = 9 source-kind = 10]
								any [target-kind = 9 target-kind = 10]
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth target target-ref
									at (capacity - written)
							]
							source-kind = 5 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth arm64-encoder/X16 ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/integer-to-float at
									(capacity - written) target arm64-encoder/X16
									4 target-width 1
							]
							true [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth
									FLOAT_SCRATCH_REGISTER ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-to-integer at
									(capacity - written) target FLOAT_SCRATCH_REGISTER
									source-width 4 1
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						scratch/stack-types/depth: target-ref
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					if scratch/stack-locations/depth = LOCATION_IMMEDIATE [
						if target-kind = 11 [
							scratch/stack-low/depth: either any [
								scratch/stack-low/depth <> 0
								scratch/stack-high/depth <> 0
							][1][0]
							scratch/stack-high/depth: 0
						]
						if integer-type? target-ref view [
							folded: scratch/stack-low/depth
							if target-width < 4 [
								load-signed: either signed-type? target-ref view [1][0]
								unless normalize-integer32 folded target-width
									load-signed :folded [return INVALID_IR]
							]
							scratch/stack-low/depth: folded
							if target-width < 8 [
								scratch/stack-high/depth: either all [
									signed-type? target-ref view folded < 0
								][-1][0]
							]
						]
						scratch/stack-types/depth: target-ref
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					if all [
						integer-type? ref view integer-type? target-ref view
						scratch/stack-locations/depth = LOCATION_REGISTER
						any [
							target-width = 4
							all [source-width = target-width
								compatible-types? ref target-ref view]
							all [target-width < 8
								integer-kind-widens? source-kind target-kind]
							all [source-width = 8 target-width = 8]
						]
					][
						scratch/stack-types/depth: target-ref
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					if any [
						all [
							reference-type? ref view
							any [
								reference-type? target-ref view
								all [address-integer-kind? target-kind target-width = 8]
							]
						]
						all [
							address-integer-kind? source-kind source-width = 8
							reference-type? target-ref view
						]
					][
						scratch/stack-types/depth: target-ref
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					target: FIRST_TEMP_REGISTER + depth - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					if target-kind = 11 [
						width: either source-width = 8 [8][4]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/condition-result at
							(capacity - written) target 1
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if integer-type? target-ref view [
						encoded: 0
						case [
							target-width < 4 [
								load-signed: either signed-type? target-ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) target target
									target-width load-signed
							]
							all [target-width = 8 source-width < 8][
								load-signed: either signed-type? ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) target target
									source-width load-signed
							]
							true [0]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					scratch/stack-types/depth: target-ref
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_SIZE [
					ref: instruction/a
					unless all [
						valid-type-ref? ref view
						any [instruction/b = 0 instruction/b = 1]
					][return INVALID_IR]
					either instruction/b = 0 [
						if instruction/c <> 0 [return INVALID_IR]
						if depth = 2147483647 [return OUTPUT_FULL]
						depth: depth + 1
					][
						unless all [
							depth > 0
							scratch/stack-kinds/depth = VALUE
							scratch/stack-types/depth = ref
							scratch/stack-flags/depth = instruction/c
						][return INVALID_IR]
					]
					width: logical-size ref view layout
					if width <= 0 [return INVALID_IR]
					kind: type-kind ref view
					either all [instruction/b = 1 kind = 13][
						target: FIRST_TEMP_REGISTER + depth - 1
						if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
							return UNSUPPORTED
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth arm64-encoder/X16 ref
							at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/c-string-size at (capacity - written)
							arm64-encoder/X16 target arm64-encoder/X17
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
					][
						scratch/stack-locations/depth: LOCATION_IMMEDIATE
						scratch/stack-low/depth: width
						scratch/stack-high/depth: 0
					]
					scratch/stack-types/depth: -5
					scratch/stack-kinds/depth: VALUE
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_NATIVE [
					either any [
						instruction/a = CPU_REGISTER_NATIVE
						instruction/a = CPU_REGISTER_SET_NATIVE
					][
						unless all [
							instruction/b >= 0 instruction/c > 0
							instruction/c <= view/strings-size
							instruction/b <= (view/strings-size - instruction/c)
						][return INVALID_IR]
						register-width: 0
						register-id: cpu-register-id
							(view/strings + instruction/b) instruction/c :register-width
						if register-id < 0 [return UNSUPPORTED]
						if cpu-pointer-ref = 0 [
							cpu-pointer-ref: integer-pointer-type view
						]
						if cpu-pointer-ref = 0 [return INVALID_IR]
					][
						either instruction/a = ATOMIC_MATH_NATIVE [
							operation: instruction/b and 7
							unless all [
								operation >= 1 operation <= 5
								any [
									instruction/b = operation
									instruction/b = (operation + ATOMIC_OLD)
								]
							][return INVALID_IR]
						][if instruction/b <> 0 [return INVALID_IR]]
					]
					case [
						instruction/a = STACK_TOP_NATIVE [
							unless pointer-to-canonical? instruction/c -5 view [
								return INVALID_IR
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/SP 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = STACK_PUSH_NATIVE [
							unless all [
								instruction/c = 0 depth > 0
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
							][return INVALID_IR]
							ref: scratch/stack-types/depth
							width: value-width ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return UNSUPPORTED
							]
							kind: type-kind ref view
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either any [kind = 9 kind = 10][
								materialize view scratch depth FLOAT_SCRATCH_REGISTER ref
									at (capacity - written)
							][
								materialize view scratch depth arm64-encoder/X16 ref
									at (capacity - written)
							]
							if encoded < 0 [return encoded]
							written: written + encoded
							if any [kind = 9 kind = 10][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-move-to-register at
									(capacity - written) arm64-encoder/X16
									FLOAT_SCRATCH_REGISTER width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/SP arm64-encoder/SP -8 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X17 arm64-encoder/SP 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/X17 0 8 arm64-encoder/X9
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth - 1
						]
						instruction/a = STACK_POP_NATIVE [
							if instruction/c <> 0 [return INVALID_IR]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X16 arm64-encoder/SP 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-load at (capacity - written)
								target arm64-encoder/X16 0 8 0 8 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/SP arm64-encoder/SP 8 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: -5
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = STACK_FRAME_NATIVE [
							unless pointer-to-canonical? instruction/c -5 view [
								return INVALID_IR
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/FP 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						any [
							instruction/a = STACK_TOP_SET_NATIVE
							instruction/a = STACK_FRAME_SET_NATIVE
						][
							unless all [
								pointer-to-canonical? instruction/c -5 view
								depth > 0 scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								compatible-types? instruction/c
									scratch/stack-types/depth view
							][return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X16
								instruction/c at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							target: either instruction/a = STACK_TOP_SET_NATIVE [
								arm64-encoder/SP
							][arm64-encoder/FP]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written)
								target arm64-encoder/X16 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: arm64-encoder/X16
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = STACK_ALIGN_NATIVE [
							unless pointer-to-canonical? instruction/c -5 view [
								return INVALID_IR
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/SP 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/logical-immediate at
								(capacity - written) arm64-encoder/OP_AND
								arm64-encoder/X16 target 8 -16 -1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) arm64-encoder/SP arm64-encoder/X16 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						any [
							instruction/a = STACK_ALLOCATE_NATIVE
							instruction/a = STACK_ALLOCATE_ZERO_NATIVE
						][
							unless all [
								pointer-to-canonical? instruction/c -5 view
								depth > 0 scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								(type-kind scratch/stack-types/depth view) = 5
							][return INVALID_IR]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-resize view scratch depth target true
								(instruction/a = STACK_ALLOCATE_ZERO_NATIVE)
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = STACK_FREE_NATIVE [
							unless all [
								instruction/c = 0 depth > 0
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								(type-kind scratch/stack-types/depth view) = 5
							][return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-resize view scratch depth 0 false false
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							depth: depth - 1
						]
						any [
							instruction/a = STACK_PUSH_ALL_NATIVE
							instruction/a = STACK_POP_ALL_NATIVE
						][
							if instruction/c <> 0 [return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: spill-live-stack view scratch depth
								region-base region-limit at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-all at (capacity - written)
								(instruction/a = STACK_POP_ALL_NATIVE)
							if encoded < 0 [return encoded]
							written: written + encoded
							if instruction/a = STACK_POP_ALL_NATIVE [
								last-math-condition: -1
							]
						]
						instruction/a = PROGRAM_COUNTER_NATIVE [
							unless pointer-to-canonical? instruction/c -2 view [
								return INVALID_IR
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/program-counter at
								(capacity - written) target
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = CPU_REGISTER_NATIVE [
							if depth = 2147483647 [return OUTPUT_FULL]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either register-width = 4 [
								arm64-encoder/extend-register at (capacity - written)
									target register-id 4 0
							][
								arm64-encoder/move-register at (capacity - written)
									target register-id 8
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: cpu-pointer-ref
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = CPU_REGISTER_SET_NATIVE [
							unless all [
								depth > 0 scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								compatible-types? cpu-pointer-ref
									scratch/stack-types/depth view
							][return INVALID_IR]
							; Explicit writes may alias a live volatile expression
							; register. Preserve only the values actually at risk.
							slot: 1
							while [slot < depth][
								if all [
									scratch/stack-locations/slot = LOCATION_REGISTER
									scratch/stack-low/slot = register-id
									not float-type? scratch/stack-types/slot view
								][
									if scratch/stack-kinds/slot <> VALUE [return UNSUPPORTED]
									width: value-width scratch/stack-types/slot view
									unless any [width = 1 width = 2 width = 4 width = 8][
										return UNSUPPORTED
									]
									if (region-base + slot) > region-limit [return INVALID_IR]
									displacement: 0 - ((region-base + slot) * 8)
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-store at
										(capacity - written) register-id displacement width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									scratch/stack-locations/slot: LOCATION_FRAME
									scratch/stack-low/slot: displacement
									scratch/stack-high/slot: 0
								]
								slot: slot + 1
							]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target cpu-pointer-ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either all [register-width = 4 register-id = target][
								arm64-encoder/extend-register at (capacity - written)
									register-id register-id 4 0
							][
								arm64-encoder/move-register at (capacity - written)
									register-id target register-width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: cpu-pointer-ref
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = CPU_OVERFLOW_NATIVE [
							if instruction/c <> -11 [return INVALID_IR]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either last-math-condition >= 0 [
								arm64-encoder/condition-result at (capacity - written)
									target last-math-condition
							][
								arm64-encoder/move-immediate at (capacity - written)
									target 4 0 0
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: -11
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = ATOMIC_FENCE_NATIVE [
							if instruction/c <> 0 [return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/memory-fence at (capacity - written)
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						instruction/a = ATOMIC_LOAD_NATIVE [
							unless all [
								instruction/c = -5 depth > 0
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								pointer-to-canonical? scratch/stack-types/depth -5 view
							][return INVALID_IR]
							ref: scratch/stack-types/depth
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-load at (capacity - written)
								target target
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: -5
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = ATOMIC_STORE_NATIVE [
							target-slot: depth - 1
							unless all [
								instruction/c = 0 depth > 1
								scratch/stack-kinds/target-slot = VALUE
								scratch/stack-flags/target-slot = 0
								pointer-to-canonical?
									scratch/stack-types/target-slot -5 view
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								(canonical-type scratch/stack-types/depth view) = -5
							][return INVALID_IR]
							ref: scratch/stack-types/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17 -5
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth - 2
						]
						instruction/a = ATOMIC_CAS_NATIVE [
							target-slot: depth - 2
							source-slot: depth - 1
							unless all [
								instruction/c = -11 depth > 2
								scratch/stack-kinds/target-slot = VALUE
								scratch/stack-flags/target-slot = 0
								pointer-to-canonical?
									scratch/stack-types/target-slot -5 view
								scratch/stack-kinds/source-slot = VALUE
								scratch/stack-flags/source-slot = 0
								(canonical-type scratch/stack-types/source-slot view) = -5
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								(canonical-type scratch/stack-types/depth view) = -5
							][return INVALID_IR]
							target: FIRST_TEMP_REGISTER + target-slot - 1
							right: FIRST_TEMP_REGISTER + depth - 1
							if any [
								target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
								right >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
							][return UNSUPPORTED]
							ref: scratch/stack-types/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot target -5
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth right -5
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X17 target 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-compare-exchange at
								(capacity - written) target right arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-register at (capacity - written)
								target arm64-encoder/X17 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/condition-result at
								(capacity - written) target arm64-encoder/EQ
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							last-math-condition: -1
							depth: target-slot
							scratch/stack-types/depth: -11
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = ATOMIC_MATH_NATIVE [
							target-slot: depth - 1
							operation: instruction/b and 7
							atomic-old?: (instruction/b and ATOMIC_OLD) <> 0
							unless all [
								instruction/c = -5
								operation >= 1 operation <= 5 depth > 1
								scratch/stack-kinds/target-slot = VALUE
								scratch/stack-flags/target-slot = 0
								pointer-to-canonical?
									scratch/stack-types/target-slot -5 view
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								(canonical-type scratch/stack-types/depth view) = -5
							][return INVALID_IR]
							target: FIRST_TEMP_REGISTER + target-slot - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							atomic-overflow?: all [
								operation <= 2
								overflow-query-follows? view fn first-instruction index
							]
							last-math-condition: -1
							ref: scratch/stack-types/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17 -5
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							if any [operation = 2 operation = 5][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: either operation = 2 [
									arm64-encoder/negate-register at (capacity - written)
										arm64-encoder/X17 arm64-encoder/X17 4
								][
									arm64-encoder/move-not-register at (capacity - written)
										arm64-encoder/X17 arm64-encoder/X17 4
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							opcode: case [
								operation <= 2 [arm64-encoder/OP_ADD]
								operation = 3 [arm64-encoder/OP_OR]
								operation = 4 [arm64-encoder/OP_XOR]
								true [arm64-encoder/OP_AND]
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-rmw at (capacity - written)
								opcode arm64-encoder/X17 target arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if any [(not atomic-old?) atomic-overflow?][
								if any [operation = 2 operation = 5][
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: either operation = 2 [
										arm64-encoder/negate-register at (capacity - written)
											arm64-encoder/X17 arm64-encoder/X17 4
									][
										arm64-encoder/move-not-register at (capacity - written)
											arm64-encoder/X17 arm64-encoder/X17 4
									]
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
								right: either atomic-old? [arm64-encoder/X16][target]
								opcode: case [
									operation = 1 [arm64-encoder/OP_ADD]
									operation = 2 [arm64-encoder/OP_SUB]
									operation = 3 [arm64-encoder/OP_OR]
									operation = 4 [arm64-encoder/OP_XOR]
									true [arm64-encoder/OP_AND]
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/alu-register at (capacity - written)
									opcode right target arm64-encoder/X17 4 atomic-overflow?
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							if atomic-overflow? [last-math-condition: arm64-encoder/VS]
							depth: target-slot
							scratch/stack-types/depth: -5
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = LOG_B_NATIVE [
							unless all [
								instruction/c = -5 depth > 0
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								integer-type? scratch/stack-types/depth view
							][return INVALID_IR]
							ref: scratch/stack-types/depth
							width: value-width ref view
							width: either width = 8 [8][4]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/count-leading-zeros at
								(capacity - written) target target width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at (capacity - written)
								arm64-encoder/X16 width ((width * 8) - 1) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/subtract-register at
								(capacity - written) target arm64-encoder/X16 target width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: -5
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						true [return UNSUPPORTED]
					]
				]
				instruction/op = OP_ADDRESS [
					slot: instruction/b
					depth: depth + 1
					scratch/stack-kinds/depth: PLACE
					case [
						instruction/a = LOCAL_ADDRESS [
							unless all [
								slot > 0
								slot <= plan/storage-count
								instruction/c = 0
								scratch/homes/slot <> 0
							][return UNSUPPORTED]
							scratch/stack-types/depth: scratch/storage-types/slot
							parameter: as rsir-parameter! (view/parameters
								+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
							target: scratch/homes/slot
							either target > 0 [
								scratch/stack-locations/depth: 0
								scratch/stack-low/depth: slot
								scratch/stack-high/depth: 0
							][
								scratch/stack-locations/depth: LOCATION_FRAME
								scratch/stack-low/depth: target
								scratch/stack-high/depth: 0
							]
							scratch/stack-flags/depth: parameter/flags
						]
						instruction/a = GLOBAL_ADDRESS [
							unless all [
								slot > 0
								slot <= view/header/global-count
								instruction/c = 0
							][return INVALID_IR]
							global: as rsir-global! (view/globals
								+ ((slot - 1) * RSIR_GLOBAL_SIZE))
							print ["ARM64 global address ordinal=" ordinal " slot=" slot
								" type=" global/type " flags=" global/flags
								" home=" scratch/global-homes/slot lf]
							scratch/stack-types/depth: global/type
							target: scratch/global-homes/slot
							if target <= 0 [
								target: available-temp-register view scratch depth false depth
								if target < 0 [return UNSUPPORTED]
								status: record-reference
									(view/header/function-count + slot)
									(function-base + written)
									references
								if status < 0 [return status]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/page-address at
									(capacity - written) target
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: global/flags
							if all [global/flags = INLINE (type-kind global/type view) = -7][
								print ["ARM64 array address slot=" slot " ordinal=" ordinal
									" flags-set=" scratch/stack-flags/depth lf]
							]
						]
						instruction/a = FUNCTION_ADDRESS [
							unless all [
								slot > 0
								slot <= view/header/function-count
								valid-type-ref? instruction/c view
								(type-kind instruction/c view) = -4
							][return INVALID_IR]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							; The linker rewrites the ADRP/ADD pair once it knows
							; where the callee landed in the code section.
							status: record-reference slot
								(function-base + written) references
							if status < 0 [return status]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/page-address at
								(capacity - written) target
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = IMPORT_ADDRESS [
							unless all [
								slot > 0 slot <= view/header/import-count
								valid-type-ref? instruction/c view
								(type-kind instruction/c view) = -4
							][return INVALID_IR]
							imported: as rsir-import! (view/imports
								+ ((slot - 1) * RSIR_IMPORT_SIZE))
							unless any [
								imported/flags = CDECL
								imported/flags = STDCALL
							][return UNSUPPORTED]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							status: record-reference
								(view/header/function-count
									+ view/header/global-count + slot)
								(function-base + written) references
							if status < 0 [return status]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/page-address at
								(capacity - written) target
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						true [return UNSUPPORTED]
					]
				]
				instruction/op = OP_LOAD [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = PLACE
					][return INVALID_IR]
					ref: scratch/stack-types/depth
					if all [
						(scratch/stack-flags/depth and INLINE) <> 0
						any [(type-kind ref view) = -2 (type-kind ref view) = -3
							(type-kind ref view) = -7]
					][
						case [
							scratch/stack-locations/depth = 0 [
								slot: scratch/stack-low/depth
								target: FIRST_TEMP_REGISTER + depth - 1
								if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
									return UNSUPPORTED
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at
									(capacity - written) target compiler-frame-register
									scratch/homes/slot arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							scratch/stack-locations/depth = LOCATION_REGISTER [
								target: scratch/stack-low/depth
								if scratch/stack-high/depth <> 0 [
									target: FIRST_TEMP_REGISTER + depth - 1
									if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
										return UNSUPPORTED
									]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/address-offset at
										(capacity - written) target scratch/stack-low/depth
										scratch/stack-high/depth arm64-encoder/X16
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							]
							scratch/stack-locations/depth = LOCATION_FRAME [
								target: FIRST_TEMP_REGISTER + depth - 1
								if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
									return UNSUPPORTED
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at
									(capacity - written) target compiler-frame-register
									scratch/stack-low/depth arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							true [return INVALID_IR]
						]
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					case [
						scratch/stack-locations/depth = 0 [
							slot: scratch/stack-low/depth
							ref: scratch/storage-types/slot
							if ref = 0 [return INVALID_IR]
							target: scratch/homes/slot
							if target <= 0 [return INVALID_IR]
						]
						scratch/stack-locations/depth = LOCATION_REGISTER [
							width: value-width ref view
							kind: type-kind ref view
							if width = 0 [return INVALID_IR]
							if width > 8 [return UNSUPPORTED]
							floating?: any [kind = 9 kind = 10]
							target: available-temp-register view scratch depth floating? depth
							if target < 0 [return UNSUPPORTED]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								arm64-encoder/float-register-load at
									(capacity - written) target scratch/stack-low/depth
									scratch/stack-high/depth width arm64-encoder/X16
							][
								load-signed: either signed-type? ref view [1][0]
								result-width: either width = 8 [8][4]
								arm64-encoder/register-load at
									(capacity - written) target scratch/stack-low/depth
									scratch/stack-high/depth width
									load-signed result-width arm64-encoder/X16
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							width: value-width ref view
							kind: type-kind ref view
							if width = 0 [return INVALID_IR]
							if width > 8 [return UNSUPPORTED]
							floating?: any [kind = 9 kind = 10]
							target: available-temp-register view scratch depth floating? depth
							if target < 0 [return UNSUPPORTED]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								compiler-float-frame-load at (capacity - written)
									target scratch/stack-low/depth width
							][
								load-signed: either signed-type? ref view [1][0]
								result-width: either width = 8 [8][4]
								compiler-frame-load at
									(capacity - written) target scratch/stack-low/depth
									width load-signed result-width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						true [return INVALID_IR]
					]
					scratch/stack-types/depth: ref
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_SET [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth >= 2 scratch/stack-kinds/depth = PLACE
					][return INVALID_IR]
					source-slot: depth - 1
					if scratch/stack-kinds/source-slot <> VALUE [return INVALID_IR]
					ref: scratch/stack-types/source-slot
					; The variant number leads the union, whose preserved base is
					; independent of any member dereference that follows.
					if tag-variant <> 0 [
						unless tag-slot = depth [return UNSUPPORTED]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-load at (capacity - written)
							arm64-encoder/X17 plan/tag-offset 8 0 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at (capacity - written)
							arm64-encoder/X16 4 tag-variant 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/register-store at (capacity - written)
							arm64-encoder/X16 arm64-encoder/X17 0 tag-width-value
							arm64-encoder/X15
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						tag-variant: 0
					]
					case [
						all [
							scratch/stack-flags/depth = INLINE
							scratch/stack-flags/source-slot = 0
							aggregate-ref? scratch/stack-types/depth view
							aggregate-ref? ref view
							compatible-types? scratch/stack-types/depth ref view
						][
							target-ref: scratch/stack-types/depth
							return-size: 0
							return-align: 0
							unless layout-type target-ref true view layout 0
								:return-size :return-align [return INVALID_IR]
							if any [return-size <= 0 return-align <= 0 return-align > 16][
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot arm64-encoder/X15
								ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: case [
								scratch/stack-locations/depth = LOCATION_REGISTER [
									arm64-encoder/address-offset at (capacity - written)
										arm64-encoder/X14 scratch/stack-low/depth
										scratch/stack-high/depth arm64-encoder/X16
								]
								scratch/stack-locations/depth = LOCATION_FRAME [
									arm64-encoder/address-offset at (capacity - written)
										arm64-encoder/X14 compiler-frame-register
										scratch/stack-low/depth arm64-encoder/X16
								]
								true [INVALID_IR]
							]
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 return-size
							if encoded < 0 [return encoded]
							written: written + encoded
							target: arm64-encoder/X14
						]
						scratch/stack-locations/depth = 0 [
							target-slot: scratch/stack-low/depth
							target-ref: scratch/storage-types/target-slot
							if target-ref = 0 [
								parameter: as rsir-parameter! (view/parameters
									+ ((fn/first-parameter + target-slot - 1)
										* RSIR_PARAMETER_SIZE))
								if parameter/flags <> 0 [return UNSUPPORTED]
								width: value-width ref view
								kind: type-kind ref view
								if width = 0 [return INVALID_IR]
								if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
								target-ref: ref
								scratch/storage-types/target-slot: ref
							]
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return INVALID_IR]
							target: scratch/homes/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot target
								target-ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_REGISTER [
							if (scratch/stack-flags/depth and PROTECTED) <> 0 [
								return INVALID_IR
							]
							target-ref: scratch/stack-types/depth
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return INVALID_IR]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return INVALID_IR]
							if width > 8 [return UNSUPPORTED]
							floating?: any [kind = 9 kind = 10]
							target: either (scratch/stack-locations/source-slot
								= LOCATION_REGISTER) [scratch/stack-low/source-slot][
								either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]
							]
							if any [
								target = arm64-encoder/X17
								all [floating? target = FLOAT_SCRATCH_REGISTER]
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch source-slot target
									target-ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								arm64-encoder/float-register-store at
									(capacity - written) target scratch/stack-low/depth
									scratch/stack-high/depth width arm64-encoder/X16
							][
								arm64-encoder/register-store at
									(capacity - written) target scratch/stack-low/depth
									scratch/stack-high/depth width arm64-encoder/X16
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							if (scratch/stack-flags/depth and PROTECTED) <> 0 [
								return INVALID_IR
							]
							target-ref: scratch/stack-types/depth
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return INVALID_IR]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return INVALID_IR]
							if width > 8 [return UNSUPPORTED]
							floating?: any [kind = 9 kind = 10]
							target: either (scratch/stack-locations/source-slot
								= LOCATION_REGISTER) [
								scratch/stack-low/source-slot
							][either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]]
							if any [
								target = arm64-encoder/X17
								all [floating? target = FLOAT_SCRATCH_REGISTER]
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch source-slot target
									target-ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								compiler-float-frame-store at (capacity - written)
									target scratch/stack-low/depth width
							][
								compiler-frame-store at
									(capacity - written) target scratch/stack-low/depth width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						true [return INVALID_IR]
					]
					depth: source-slot
					scratch/stack-types/depth: target-ref
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_REFERENCE [
					unless all [
						instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = PLACE
						any [
							scratch/stack-locations/depth = LOCATION_REGISTER
							scratch/stack-locations/depth = LOCATION_FRAME
						]
						(value-width instruction/a view) = 8
						reference-type? instruction/a view
					][return UNSUPPORTED]
					either scratch/stack-locations/depth = LOCATION_FRAME [
						target: available-temp-register view scratch depth false depth
						if target < 0 [return UNSUPPORTED]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/address-offset at (capacity - written)
							target compiler-frame-register scratch/stack-low/depth
							arm64-encoder/X16
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					][
						target: scratch/stack-low/depth
						if scratch/stack-high/depth <> 0 [
							target: available-temp-register view scratch depth false depth
							if target < 0 [return UNSUPPORTED]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/address-offset at (capacity - written)
								target scratch/stack-low/depth scratch/stack-high/depth
								arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					scratch/stack-types/depth: instruction/a
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_INDEX [
					unless any [instruction/b = 0 instruction/b = 1][return INVALID_IR]
					target-slot: either instruction/b = 1 [depth - 1][depth]
					if any [
						target-slot <= 0
						scratch/stack-kinds/target-slot <> VALUE
					][return INVALID_IR]
					ref: scratch/stack-types/target-slot
					member-type: 0
					unless pointee-type ref view :member-type [return INVALID_IR]
					stride: pointer-stride ref view layout
					if stride <= 0 [return UNSUPPORTED]
					target: available-temp-register view scratch depth false target-slot
					if target < 0 [return UNSUPPORTED]
					case [
						instruction/b = 0 [
							condition: either instruction/a < 0 [-1][0]
							if instruction/c <> condition [
								return UNSUPPORTED
							]
							ordinal: instruction/a
							if any [
								all [ordinal < 0 ordinal < (80000000h / stride)]
								all [ordinal >= 0 ordinal > (7FFFFFFFh / stride)]
							][return UNSUPPORTED]
							scaled: ordinal * stride
							either (scratch/stack-locations/target-slot
								= LOCATION_REGISTER) [
								target: scratch/stack-low/target-slot
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch target-slot target ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							scratch/stack-high/target-slot: scaled
						]
						instruction/b = 1 [
							if any [
								instruction/a <> 0 instruction/c <> 0
								depth < 2
								scratch/stack-kinds/depth <> VALUE
								(type-kind scratch/stack-types/depth view) <> 5
							][return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17
								scratch/stack-types/depth at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot target ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/X17 arm64-encoder/X17 -1 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							shift: power-shift stride
							either shift >= 0 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-extended-register at
									(capacity - written) arm64-encoder/OP_ADD
									target target arm64-encoder/X17 4 1 shift
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X17 4 1
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/move-immediate at
									(capacity - written) arm64-encoder/X16 8 stride 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/multiply-register at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X17 arm64-encoder/X16 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-register at
									(capacity - written) target target arm64-encoder/X17 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							depth: target-slot
							scratch/stack-high/target-slot: 0
						]
					]
					scratch/stack-types/target-slot: member-type
					scratch/stack-kinds/target-slot: PLACE
					scratch/stack-locations/target-slot: LOCATION_REGISTER
					scratch/stack-low/target-slot: target
				]
				instruction/op = OP_MEMBER [
					if any [depth <= 0 instruction/c <> 0][return UNSUPPORTED]
					ref: scratch/stack-types/depth
					unless any [
						scratch/stack-kinds/depth = PLACE
						all [
							scratch/stack-kinds/depth = VALUE
							any [(type-kind ref view) = -2 (type-kind ref view) = -3]
						]
					][return INVALID_IR]
					; A write through a tagged union carries the variant it
					; selects. The store itself waits for the OP_SET that closes
					; the path, so the value being assigned still sees whatever
					; tag the union held on the way in.
					if instruction/b <> 0 [
						unless all [
							instruction/b = (instruction/a + 1)
							tag-variant = 0
						][return UNSUPPORTED]
						width: union-tag-width ref view
						if width = 0 [return INVALID_IR]
						tag-variant: instruction/b
						tag-width-value: width
						tag-slot: depth
						; A tagged member can be dereferenced before OP_SET (for
						; example, union/pointer/value). Materialize the union base
						; now so the deferred tag store does not depend on that
						; later address computation.
						case [
							scratch/stack-locations/depth = LOCATION_REGISTER [
								target: available-temp-register view scratch depth false depth
								if target < 0 [return UNSUPPORTED]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									target scratch/stack-low/depth scratch/stack-high/depth
									arm64-encoder/X16
							]
							scratch/stack-locations/depth = LOCATION_FRAME [
								target: available-temp-register view scratch depth false depth
								if target < 0 [return UNSUPPORTED]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									target compiler-frame-register scratch/stack-low/depth
									arm64-encoder/X16
							]
							true [return UNSUPPORTED]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-store at (capacity - written)
							target plan/tag-offset 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
					]
					member-type: 0
					member-flags: 0
					member-offset: 0
					unless layout-member ref instruction/a view layout
						:member-type :member-flags :member-offset [return INVALID_IR]
					case [
						scratch/stack-locations/depth = LOCATION_REGISTER [
							if member-offset >
								(2147483647 - scratch/stack-high/depth) [
								return UNSUPPORTED
							]
							scratch/stack-high/depth:
								scratch/stack-high/depth + member-offset
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							either scratch/stack-kinds/depth = PLACE [
								if scratch/stack-low/depth > (2147483647 - member-offset)[
									return UNSUPPORTED
								]
								scratch/stack-low/depth:
									scratch/stack-low/depth + member-offset
								scratch/stack-high/depth: 0
							][
								target: available-temp-register view scratch depth false depth
								if target < 0 [return UNSUPPORTED]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth target ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
								scratch/stack-high/depth: member-offset
							]
						]
						true [return UNSUPPORTED]
					]
					scratch/stack-types/depth: member-type
					scratch/stack-kinds/depth: PLACE
					scratch/stack-flags/depth: member-flags
				]
				instruction/op = OP_TAG [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = VALUE
						scratch/stack-flags/depth = 0
					][return INVALID_IR]
					ref: scratch/stack-types/depth
					width: union-tag-width ref view
					if width = 0 [return INVALID_IR]
					target: FIRST_TEMP_REGISTER + depth - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					; The variant number leads the union, so the tag sits at the
					; front of whatever the value points at.
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/register-load at (capacity - written)
						target target 0 width 0 4 arm64-encoder/X16
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					scratch/stack-types/depth: -5
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_OVERFLOW [
					; The scope itself emits nothing: it only names the landing
					; pad the operations inside it branch to.
					target: instruction/a
					current-catch-depth: catch-depths/ordinal
					target-catch-depth: either target = 0 [0][catch-depths/target]
					unless all [
						instruction/b = 0 instruction/c = 0
						any [
							target = 0
							all [
								target > ordinal target <= fn/instruction-count
									(target-catch-depth - current-catch-depth) = 0
							]
						]
					][return INVALID_IR]
				]
				instruction/op = OP_CATCH [
					target: instruction/a
					current-catch-depth: catch-depths/ordinal
					target-catch-depth: catch-depths/target
					expected-catch-depth: instruction/b - 1
					unless all [
						instruction/b > 0
						(current-catch-depth - expected-catch-depth) = 0
						(target-catch-depth - instruction/b) = 0
						depth = 1
						scratch/stack-kinds/depth = VALUE
						scratch/stack-flags/depth = 0
						compatible-types? -5 scratch/stack-types/depth view
					][return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth arm64-encoder/X3 -5
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					target-offset: either null? code [0][instruction-offsets/target]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-catch-open at (capacity - written)
						instruction/b target-offset written
					if encoded < 0 [return encoded]
					written: written + encoded
					depth: 0
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return INVALID_IR
					]
				]
				instruction/op = OP_END_CATCH [
					catch-level: catch-depths/ordinal
					unless all [
						catch-level > 0
						instruction/b = catch-level
						instruction/a > 0 instruction/a < ordinal
					][return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-catch-restore at (capacity - written)
						catch-level
					if encoded < 0 [return encoded]
					written: written + encoded
				]
				instruction/op = OP_THROW [
					source-slot: depth - 1
					target-slot: depth
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 1
						scratch/stack-kinds/source-slot = VALUE
						scratch/stack-flags/source-slot = 0
						compatible-types? -5 scratch/stack-types/source-slot view
						scratch/stack-kinds/target-slot = PLACE
						scratch/stack-flags/target-slot = 0
						(scratch/stack-flags/target-slot and PROTECTED) = 0
						compatible-types? -5 scratch/stack-types/target-slot view
					][return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch source-slot arm64-encoder/X0 -5
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					case [
						scratch/stack-locations/target-slot = 0 [
							slot: scratch/stack-low/target-slot
							target: scratch/homes/slot
							if target <= 0 [return INVALID_IR]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/X0 4
						]
						scratch/stack-locations/target-slot = LOCATION_REGISTER [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/X0
								scratch/stack-low/target-slot
								scratch/stack-high/target-slot 4 arm64-encoder/X16
						]
						scratch/stack-locations/target-slot = LOCATION_FRAME [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: compiler-frame-store at (capacity - written)
								arm64-encoder/X0 scratch/stack-low/target-slot 4
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-frame-normalize plan at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-throw-unwind at (capacity - written)
						((fn/flags and CATCH_FLAG) <> 0)
					if encoded < 0 [return encoded]
					written: written + encoded
					depth: source-slot - 1
					fallthrough?: false
				]
				instruction/op = OP_CALL [
					call-target: instruction/a
					argument-count: instruction/b
					if call-target = 46 [
						print ["ARM64 call46 begin ordinal=" ordinal
							" depth=" depth " args=" argument-count lf]
					]
					; A call through a pointer keeps the callee below its
					; arguments, so it claims one more live slot.
					callee-slots: either call-target = 0 [1][0]
					if any [
						argument-count < 0
						argument-count > (depth - callee-slots)
					][return INVALID_IR]
					call-return: 0
					call-first-parameter: 0
					call-parameter-count: 0
					call-reference: 0
					call-source: PARAMETER_TABLE
					call-flags: 0
					syscall?: false
					syscall-id: 0
					call-signature: instruction/c
					if all [
						call-signature > 0
						(type-kind call-signature view) = -8
					][
						typed-metadata: as rsir-type! (view/types
							+ (((canonical-type call-signature view) - 1)
								* RSIR_TYPE_SIZE))
						call-signature: typed-metadata/target
					]
					status: resolve-call call-target call-signature view
						:call-return :call-first-parameter :call-parameter-count
						:call-reference :call-source :call-flags
					if call-target = 46 [
						print ["ARM64 call46 resolved status=" status
							" return=" call-return " params=" call-parameter-count
							" flags=" call-flags " signature=" call-signature lf]
					]
					if status < 0 [return status]
					call-mode: call-flags and (VARIADIC or TYPED or CUSTOM)
					packed-call?: all [
						call-mode = VARIADIC
						(call-flags and 3) <> CDECL
					]
					if packed-call? [
						if any [call-parameter-count < 2 call-parameter-count > 3][
							return INVALID_IR
						]
						parameter: call-parameter view call-source call-first-parameter 1
						unless all [parameter/flags = 0 (type-kind parameter/type view) = 5][
							return INVALID_IR
						]
						parameter: call-parameter view call-source call-first-parameter 2
						unless all [parameter/flags = 0 address-type? parameter/type view][
							return INVALID_IR
						]
					]
					if call-target < 0 [
						imported: as rsir-import! (view/imports
							+ (((0 - call-target) - 1) * RSIR_IMPORT_SIZE))
						syscall?: (imported/flags and SYSCALL_FLAG) <> 0
						if syscall? [syscall-id: imported/flags / 2048]
					]
					if (call-flags and TYPED) <> 0 [
						unless all [
							instruction/c > 0
							(type-kind instruction/c view) = -8
							typed-metadata/member-count = argument-count
							call-parameter-count = 2
						][
							print ["ARM64 typed plan shape c=" instruction/c
								" kind=" type-kind instruction/c view
								" members=" typed-metadata/member-count
								" args=" argument-count " params=" call-parameter-count lf]
							return INVALID_IR
						]
					]
					if call-return <> 0 [
						aggregate-return?: (call-flags and RETURN_VALUE) <> 0
						either aggregate-return? [
							unless aggregate-ref? call-return view [return INVALID_IR]
							aggregate-size-value: 0
							aggregate-align: 0
							unless layout-type call-return true view layout 0
								:aggregate-size-value :aggregate-align [return INVALID_IR]
							if aggregate-size-value <= 0 [return INVALID_IR]
						][
							width: value-width call-return view
							kind: type-kind call-return view
							if any [width = 0 width > 8][return UNSUPPORTED]
						]
					]
					unless all [
						any [
							packed-call?
							(call-flags and TYPED) <> 0
							all [
								(call-flags and VARIADIC) = 0
								argument-count = call-parameter-count
							]
							all [
								(call-flags and VARIADIC) <> 0
								argument-count >= call-parameter-count
							]
						]
						any [
							(call-flags and TYPED) <> 0
							call-target = 0
							instruction/c = call-return
						]
					][
						print ["ARM64 call shape ordinal=" ordinal
							" target=" call-target " args=" argument-count
							" params=" call-parameter-count " flags=" call-flags
							" signature=" instruction/c " return=" call-return lf]
						return INVALID_IR
					]
					fixed-stack-size: 0
					if packed-call? [
						if argument-count > (2147483647 / 8)[return OUTPUT_FULL]
						list-size: argument-count * 8
						list-capacity: either list-size < 8 [8][list-size]
						fixed-stack-size: align list-capacity 16
					]
					if all [(call-flags and TYPED) = 0 not packed-call?] [
						if call-target = 46 [print ["ARM64 call46 classify" lf]]
						status: abi-parameter-location view layout call-source
							call-first-parameter call-parameter-count 0 abi-location
						if status < 0 [return status]
						fixed-stack-size: abi-location/stack-size
					]
					if all [(call-flags and VARIADIC) <> 0 not packed-call?] [
						if (argument-count - call-parameter-count)
							> ((2147483647 - fixed-stack-size) / 8) [
							return OUTPUT_FULL
						]
					]
					argument-origin: depth - argument-count
					if any [call-target = 46
						all [ordinal = 1498 fn/instruction-count = 3722]] [
						print ["ARM64 call arguments ordinal=" ordinal
							" origin=" argument-origin " depth=" depth lf]
						slot: 1
						while [slot <= depth][
							print ["  slot=" slot
								" type=" scratch/stack-types/slot
								" kind=" scratch/stack-kinds/slot
								" location=" scratch/stack-locations/slot
								" low=" scratch/stack-low/slot lf]
							slot: slot + 1
						]
					]
					if call-target = 46 [
						print ["ARM64 call46 origins argument=" argument-origin
							" region=" region-base " limit=" region-limit lf]
					]
					if (region-base + argument-origin) > region-limit [
						return INVALID_IR
					]
					callee-slot: either callee-slots = 0 [0][argument-origin]
					argument-base: argument-origin - callee-slots
					if callee-slot > 0 [
						unless all [
							scratch/stack-kinds/callee-slot = VALUE
							scratch/stack-flags/callee-slot = 0
							compatible-types? call-signature
								scratch/stack-types/callee-slot view
						][return INVALID_IR]
					]
					slot: 1
					while [slot <= argument-base][
						ref: scratch/stack-types/slot
						if call-target = 46 [
							print ["ARM64 call46 preserve slot=" slot
								" location=" scratch/stack-locations/slot
								" register=" scratch/stack-low/slot
								" volatile=" volatile-register-value? ref
									scratch/stack-low/slot view lf]
						]
						if any [
							scratch/stack-locations/slot = LOCATION_FLAGS
							all [
								scratch/stack-locations/slot = LOCATION_REGISTER
								volatile-register-value? ref scratch/stack-low/slot view
							]
							][
								width: value-width ref view
								unless any [
									width = 1 width = 2 width = 4 width = 8
								][return UNSUPPORTED]
							floating?: float-type? ref view
							target: either scratch/stack-locations/slot = LOCATION_REGISTER [
								scratch/stack-low/slot
							][
								either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]
							]
							if any [
								target = arm64-encoder/X17
								all [floating? target = FLOAT_SCRATCH_REGISTER]
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch slot target ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							displacement: 0 - ((region-base + slot) * 8)
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								compiler-float-frame-store at
									(capacity - written) target displacement width
							][
								compiler-frame-store at
									(capacity - written) target displacement width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-locations/slot: LOCATION_FRAME
							scratch/stack-low/slot: displacement
							scratch/stack-high/slot: 0
						]
						slot: slot + 1
					]
					; The callee pointer waits until the arguments are in place,
					; because X17 is the only register the argument moves leave
					; alone. A pointer parked anywhere the moves can reach goes
					; to its spill slot first.
					if all [
						callee-slot > 0
						scratch/stack-locations/callee-slot = LOCATION_REGISTER
						not call-safe-register? scratch/stack-low/callee-slot
					][
						displacement: 0 - ((region-base + callee-slot) * 8)
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-store at (capacity - written)
							scratch/stack-low/callee-slot displacement 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						scratch/stack-locations/callee-slot: LOCATION_FRAME
						scratch/stack-low/callee-slot: displacement
						scratch/stack-high/callee-slot: 0
					]
					aggregate-return?: (call-flags and RETURN_VALUE) <> 0
					if aggregate-return? [
						result-offset: result-offsets/ordinal
						if result-offset >= 0 [
							print ["ARM64 aggregate result offset ordinal=" ordinal
								" offset=" result-offset " return=" call-return
								" flags=" call-flags lf]
							return INVALID_IR
						]
					]
					; Copy indirect aggregate arguments before loading ABI registers.
					slot: 1
					while [all [not packed-call? (call-flags and TYPED) = 0
						slot <= call-parameter-count]][
						parameter: call-parameter view call-source call-first-parameter slot
						if parameter/flags = INLINE [
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count slot abi-location
							if status < 0 [return status]
							if abi-location/class = ABI_INDIRECT [
								argument-slot: argument-origin + slot
								unless all [
									scratch/stack-kinds/argument-slot = VALUE
									compatible-types? parameter/type
										scratch/stack-types/argument-slot view
								][return INVALID_IR]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch argument-slot
									arm64-encoder/X15 parameter/type at (capacity - written)
								if encoded < 0 [
									print ["ARM64 indirect materialize ordinal=" ordinal
										" slot=" slot " status=" encoded
										" expected=" parameter/type
										" actual=" scratch/stack-types/argument-slot lf]
									return encoded
								]
								written: written + encoded
								copy-offset: fixed-stack-size + abi-location/copy-offset
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									arm64-encoder/X14 arm64-encoder/SP copy-offset arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: emit-memory-copy at (capacity - written)
									arm64-encoder/X14 arm64-encoder/X15 abi-location/size
								if encoded < 0 [return encoded]
								written: written + encoded
							]
						]
						slot: slot + 1
					]
					slot: argument-count
					if (call-flags and TYPED) <> 0 [
						while [slot > 0][
							argument-slot: argument-origin + slot
							ref: scratch/stack-types/argument-slot
							typed-member: as rsir-member! (view/members
								+ ((typed-metadata/first-member + slot - 1)
									* RSIR_MEMBER_SIZE))
							unless all [
								scratch/stack-kinds/argument-slot = VALUE
								scratch/stack-flags/argument-slot = 0
								compatible-types? typed-member/type ref view
								typed-runtime-id? typed-member/flags
							][return INVALID_IR]
							width: value-width ref view
							kind: type-kind ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return UNSUPPORTED
							]
							record-offset: (slot - 1) * 24
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X16 4
								typed-member/flags 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/X16 arm64-encoder/SP
								record-offset 4 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/ZR arm64-encoder/SP
								(record-offset + 4) 4 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/ZR arm64-encoder/SP
								(record-offset + 8) 8 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							floating?: float-type? ref view
							target: either floating? [
								FLOAT_SCRATCH_REGISTER
							][arm64-encoder/X16]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot target ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							if all [not floating? width < 4][
								load-signed: either signed-type? ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) target target width load-signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								arm64-encoder/float-register-store at
									(capacity - written) target arm64-encoder/SP
									(record-offset + 8) width arm64-encoder/X16
							][
								arm64-encoder/register-store at (capacity - written)
									target arm64-encoder/SP (record-offset + 8) 8
									arm64-encoder/X17
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							either any [kind = 7 kind = 8][
								if width = 8 [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/shift-immediate at
										(capacity - written) arm64-encoder/SHIFT_RIGHT
										arm64-encoder/X17 arm64-encoder/X16 32 8
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
								target: either width = 8 [arm64-encoder/X17][arm64-encoder/ZR]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-store at
									(capacity - written) target
									arm64-encoder/SP (record-offset + 16) 4 arm64-encoder/X16
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-store at
									(capacity - written) arm64-encoder/ZR arm64-encoder/SP
									(record-offset + 20) 4 arm64-encoder/X17
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-store at
									(capacity - written) arm64-encoder/ZR arm64-encoder/SP
									(record-offset + 16) 8 arm64-encoder/X17
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							slot: slot - 1
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at
							(capacity - written) arm64-encoder/X0 4 argument-count 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-register at (capacity - written)
							arm64-encoder/X1 arm64-encoder/SP 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						slot: 0
					]
					if packed-call? [
						slot: 1
						while [slot <= argument-count][
							argument-slot: argument-origin + slot
							unless all [
								scratch/stack-kinds/argument-slot = VALUE
								scratch/stack-flags/argument-slot = 0
							][return INVALID_IR]
							ref: scratch/stack-types/argument-slot
							width: value-width ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/SP ((slot - 1) * 8)
								8 arm64-encoder/X17
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							slot: slot + 1
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at (capacity - written)
							arm64-encoder/X0 4 argument-count 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-register at (capacity - written)
							arm64-encoder/X1 arm64-encoder/SP 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						slot: 0
					]
					while [slot > 0][
						argument-slot: argument-origin + slot
						if call-target = 46 [
							print ["ARM64 call46 argument slot=" slot
								" physical=" argument-slot
								" kind=" scratch/stack-kinds/argument-slot
								" type=" scratch/stack-types/argument-slot
								" location=" scratch/stack-locations/argument-slot
								" flags=" scratch/stack-flags/argument-slot lf]
						]
						if scratch/stack-kinds/argument-slot <> VALUE [return INVALID_IR]
						ref: scratch/stack-types/argument-slot
						if all [slot <= call-parameter-count not packed-call?
							(call-flags and TYPED) = 0][
							parameter: call-parameter view call-source call-first-parameter slot
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count slot abi-location
							if status < 0 [return status]
							if parameter/flags = INLINE [
								unless all [
									aggregate-ref? parameter/type view
									aggregate-ref? ref view
									compatible-types? parameter/type ref view
								][return INVALID_IR]
								if syscall? [return UNSUPPORTED]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch argument-slot arm64-encoder/X15
									parameter/type at (capacity - written)
								if encoded < 0 [
									print ["ARM64 aggregate materialize ordinal=" ordinal
										" slot=" slot " status=" encoded
										" class=" abi-location/class
										" expected=" parameter/type " actual=" ref lf]
									return encoded
								]
								written: written + encoded
								case [
									abi-location/class = ABI_GPR [
										chunk-offset: 0
										case-index: 0
										while [case-index < abi-location/register-count][
											chunk-size: abi-location/size - chunk-offset
											if chunk-size > 8 [chunk-size: 8]
											at: either null? code [as byte-ptr! 0][code + written]
											encoded: emit-aggregate-chunk-load at (capacity - written)
												(abi-location/register-index + case-index) arm64-encoder/X15
												chunk-offset chunk-size
											if encoded < 0 [return encoded]
											written: written + encoded
											chunk-offset: chunk-offset + 8
											case-index: case-index + 1
										]
									]
									abi-location/class = ABI_SIMD [
										chunk-offset: 0
										case-index: 0
										while [case-index < abi-location/register-count][
											at: either null? code [as byte-ptr! 0][code + written]
											encoded: arm64-encoder/float-register-load at
												(capacity - written) (abi-location/register-index + case-index)
												arm64-encoder/X15 chunk-offset abi-location/hfa-width
												arm64-encoder/X16
											if encoded < 0 [return OUTPUT_FULL]
											written: written + encoded
											chunk-offset: chunk-offset + abi-location/hfa-width
											case-index: case-index + 1
										]
									]
									abi-location/class = ABI_STACK [
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/address-offset at (capacity - written)
											arm64-encoder/X14 arm64-encoder/SP
											abi-location/stack-offset arm64-encoder/X16
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: emit-memory-copy at (capacity - written)
											arm64-encoder/X14 arm64-encoder/X15 abi-location/size
										if encoded < 0 [return encoded]
										written: written + encoded
									]
									abi-location/class = ABI_INDIRECT [
										copy-offset: fixed-stack-size + abi-location/copy-offset
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/address-offset at (capacity - written)
											arm64-encoder/X16 arm64-encoder/SP copy-offset
											arm64-encoder/X17
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										either abi-location/register-index >= 0 [
											at: either null? code [as byte-ptr! 0][code + written]
											encoded: arm64-encoder/move-register at (capacity - written)
												abi-location/register-index arm64-encoder/X16 8
										][
											at: either null? code [as byte-ptr! 0][code + written]
											encoded: arm64-encoder/register-store at (capacity - written)
												arm64-encoder/X16 arm64-encoder/SP
												abi-location/stack-offset 8 arm64-encoder/X17
										]
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									true [return INVALID_IR]
								]
								slot: slot - 1
								continue
							]
						]
						either slot <= call-parameter-count [
							parameter: call-parameter view call-source
								call-first-parameter slot
							if call-target = 46 [
								print ["ARM64 call46 scalar expected=" parameter/type
									" flags=" parameter/flags " actual=" ref lf]
							]
							if parameter/flags <> 0 [return UNSUPPORTED]
							unless implicitly-compatible? parameter/type ref
								(scratch/stack-locations/argument-slot = LOCATION_IMMEDIATE) view [
								return INVALID_IR
							]
							target-ref: parameter/type
							stack-offset: abi-location/stack-offset
							if call-target = 46 [
								print ["ARM64 call46 scalar stack=" stack-offset lf]
							]
						][
							unless (call-flags and VARIADIC) <> 0 [return INVALID_IR]
							kind: type-kind ref view
							target-ref: either kind = 9 [-10][ref]
							stack-offset: (slot - call-parameter-count - 1) * 8
						]
						width: value-width target-ref view
						kind: type-kind target-ref view
						unless any [width = 1 width = 2 width = 4 width = 8][
							return UNSUPPORTED
						]
						floating?: any [kind = 9 kind = 10]
						if all [syscall? floating?][return UNSUPPORTED]
						either stack-offset < 0 [
							parameter-register: abi-location/register-index
							if all [ordinal = 1498 fn/instruction-count = 3722] [
								print ["ARM64 argument trace slot=" slot
									" argument-slot=" argument-slot
									" parameter-register=" parameter-register
									" floating=" floating?
									" location=" scratch/stack-locations/argument-slot
									" low=" scratch/stack-low/argument-slot lf]
							]
							if call-target = 46 [
								print ["ARM64 call46 scalar register=" parameter-register
									" floating=" floating? " width=" width lf]
							]
							if any [parameter-register < 0 parameter-register >= 8][
								return UNSUPPORTED
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot
								parameter-register target-ref at (capacity - written)
							if encoded < 0 [
								if call-target = 46 [
									print ["ARM64 call46 scalar materialize status=" encoded
										" target=" parameter-register " type=" target-ref lf]
								]
								return encoded
							]
							written: written + encoded
						][
							if slot > call-parameter-count [
								stack-offset: stack-offset + fixed-stack-size
							]
							target: either floating? [
								FLOAT_SCRATCH_REGISTER
							][arm64-encoder/X16]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot target
								target-ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								arm64-encoder/float-register-store at
									(capacity - written) target arm64-encoder/SP
									stack-offset width arm64-encoder/X16
							][
								arm64-encoder/register-store at (capacity - written)
									target arm64-encoder/SP stack-offset width arm64-encoder/X17
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						slot: slot - 1
					]
					displacement: 0
					if aggregate-return? [
						hfa-kind: 0
						hfa-count: 0
						hfa-return?: classify-hfa call-return INLINE view 0
							:hfa-kind :hfa-count
						aggregate-copy?: all [not hfa-return? aggregate-size-value > 16]
						if aggregate-copy? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/address-offset at (capacity - written)
								arm64-encoder/X8 compiler-frame-register result-offset
								arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					if call-target = 0 [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch callee-slot
							arm64-encoder/X17 call-signature at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
					]
					unless syscall? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-frame-normalize plan at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
					]
					if call-target = 46 [print ["ARM64 call46 dispatch" lf]]
					case [
						syscall? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X16 8 syscall-id 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/svc at
								(capacity - written) 128
						]
						call-target > 0 [
							if call-target = 46 [print ["ARM64 call46 direct" lf]]
							if not null? code [
								target: function-offsets/call-target
								displacement: target - function-base
								displacement: displacement - written
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/call-relative at
								(capacity - written) displacement
						]
						call-target < 0 [
							status: record-reference call-reference
								(function-base + written) references
							if status < 0 [return status]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/call-relative at
								(capacity - written) displacement
						]
						true [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/call-register at
								(capacity - written) arm64-encoder/X17
						]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					unless syscall? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-visible-frame-restore plan at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
					]
					if call-target = 46 [
						print ["ARM64 call46 called return=" call-return
							" aggregate=" aggregate-return? lf]
					]
					depth: argument-base
					if call-return <> 0 [
						either aggregate-return? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/address-offset at (capacity - written)
								arm64-encoder/X15 compiler-frame-register result-offset
								arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							case [
								aggregate-copy? []
								hfa-return? [
									width: either hfa-kind = 9 [4][8]
									case-index: 0
									while [case-index < hfa-count][
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/float-register-store at
											(capacity - written) case-index arm64-encoder/X15
											(case-index * width) width arm64-encoder/X16
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										case-index: case-index + 1
									]
								]
								true [
									chunk-offset: 0
									case-index: 0
									while [chunk-offset < aggregate-size-value][
										chunk-size: aggregate-size-value - chunk-offset
										if chunk-size > 8 [chunk-size: 8]
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: emit-aggregate-chunk-store at
											(capacity - written) case-index arm64-encoder/X15
											chunk-offset chunk-size
										if encoded < 0 [return encoded]
										written: written + encoded
										chunk-offset: chunk-offset + 8
										case-index: case-index + 1
									]
								]
							]
							depth: depth + 1
							scratch/stack-types/depth: call-return
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: arm64-encoder/X15
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						][
							width: value-width call-return view
							if all [not float-type? call-return view width < 4][
								load-signed: either signed-type? call-return view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) arm64-encoder/X0
									arm64-encoder/X0 width load-signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							depth: depth + 1
							scratch/stack-types/depth: call-return
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: arm64-encoder/X0
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
					]
				]
				instruction/op = OP_ENTRY [
					unless all [
						any [instruction/a = 0 instruction/a = 1]
						instruction/c = 0
						depth = 0
					][return INVALID_IR]
					region-entry: ordinal
					region-base: scratch/entry-spill-bases/ordinal
					region-limit: scratch/entry-spill-limits/ordinal
					region-link?: all [
						instruction/a = 1
						entry-clobbers-link? view fn first-instruction ordinal
					]
					if region-link? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-store at (capacity - written)
							arm64-encoder/LR (0 - ((region-limit + 1) * 8)) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_SUB_CALL [
					sub-target: instruction/a
					unless all [
						sub-target > 0
						sub-target <= fn/instruction-count
						sub-target <> region-entry
						instruction/c = 0
					][return INVALID_IR]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + sub-target - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/op = OP_ENTRY
						sub-entry/a = 1
						sub-entry/b = instruction/b
					][return INVALID_IR]
					if (region-base + depth) > region-limit [return INVALID_IR]
					; The callee runs on this frame and may rewrite any local, so
					; every live value goes to this region's window first.
					slot: 1
					while [slot <= depth][
						if any [
							scratch/stack-locations/slot = LOCATION_FLAGS
							scratch/stack-locations/slot = LOCATION_REGISTER
						][
							if scratch/stack-kinds/slot <> VALUE [return UNSUPPORTED]
							ref: scratch/stack-types/slot
							width: value-width ref view
							unless any [
								width = 1 width = 2 width = 4 width = 8
							][return UNSUPPORTED]
							floating?: float-type? ref view
							target: either (scratch/stack-locations/slot
								= LOCATION_REGISTER) [scratch/stack-low/slot][
								either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]
							]
							if any [
								target = arm64-encoder/X17
								all [floating? target = FLOAT_SCRATCH_REGISTER]
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch slot target ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							displacement: 0 - ((region-base + slot) * 8)
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either floating? [
								compiler-float-frame-store at
									(capacity - written) target displacement width
							][
								compiler-frame-store at
									(capacity - written) target displacement width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-locations/slot: LOCATION_FRAME
							scratch/stack-low/slot: displacement
							scratch/stack-high/slot: 0
						]
						slot: slot + 1
					]
					displacement: either null? code [0][
						instruction-offsets/sub-target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/call-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					target: first-instruction + instruction/a
					either (scratch/instruction-effects/target and EFFECT_RESUMES) = 0 [
						fallthrough?: false
					][
						if instruction/b <> 0 [
							ref: instruction/b
							width: value-width ref view
							if any [width = 0 width > 8][return UNSUPPORTED]
							if all [not float-type? ref view width < 4][
								load-signed: either signed-type? ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) arm64-encoder/X0
									arm64-encoder/X0 width load-signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							depth: depth + 1
							scratch/stack-types/depth: ref
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: arm64-encoder/X0
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
					]
				]
				instruction/op = OP_SUB_RETURN [
					if any [
						region-entry = 0
						instruction/b <> 0 instruction/c <> 0
					][return INVALID_IR]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + region-entry - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/a = 1
						sub-entry/b = instruction/a
						either instruction/a = 0 [
							any [
								depth = 0
								all [depth = 1 scratch/stack-kinds/depth = VALUE]
							]
						][
							all [
								depth = 1
								scratch/stack-kinds/depth = VALUE
								implicitly-compatible? instruction/a
									scratch/stack-types/depth
									(scratch/stack-locations/depth = LOCATION_IMMEDIATE)
									view
							]
						]
					][return INVALID_IR]
					if instruction/a <> 0 [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth arm64-encoder/X0
							instruction/a at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
					]
					depth: 0
					if region-link? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-load at (capacity - written)
							arm64-encoder/LR (0 - ((region-limit + 1) * 8)) 8 0 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/return-near at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_DROP [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0 depth > 0
					][return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_UNARY [
					unless all [
						instruction/a = NOT_OPERATION
						instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = VALUE
					][return INVALID_IR]
					ref: scratch/stack-types/depth
					kind: type-kind ref view
					unless any [integer-type? ref view kind = 11][return INVALID_IR]
					width: value-width ref view
					unless any [width = 1 width = 2 width = 4 width = 8][
						return UNSUPPORTED
					]
					if scratch/stack-locations/depth = LOCATION_IMMEDIATE [
						either kind = 11 [
							scratch/stack-low/depth: either
								scratch/stack-low/depth = 0 [1][0]
							scratch/stack-high/depth: 0
						][
							folded: scratch/stack-low/depth xor -1
							if width < 4 [
								load-signed: either signed-type? ref view [1][0]
								unless normalize-integer32 folded width load-signed :folded [
									return INVALID_IR
								]
							]
							scratch/stack-low/depth: folded
							scratch/stack-high/depth: either width = 8 [
								scratch/stack-high/depth xor -1
							][either folded < 0 [-1][0]]
						]
						index: index + 1
						continue
					]
					target: FIRST_TEMP_REGISTER + depth - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					result-width: either width = 8 [8][4]
					encoded: either kind = 11 [
						arm64-encoder/logical-immediate at (capacity - written)
							arm64-encoder/OP_XOR target target 4 1 0
					][
						arm64-encoder/move-not-register at (capacity - written)
							target target result-width
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if all [kind <> 11 width < 4][
						load-signed: either signed-type? ref view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							target target width load-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_BINARY [
					unless all [
						instruction/a >= ADD_OPERATION
						instruction/a <= LESS_EQUAL_OPERATION
						instruction/b >= 0 instruction/c >= 0 depth >= 2
					][return UNSUPPORTED]
					source-slot: depth - 1
					unless all [
						scratch/stack-kinds/source-slot = VALUE
						scratch/stack-kinds/depth = VALUE
					][return INVALID_IR]
					left-ref: scratch/stack-types/source-slot
					right-ref: scratch/stack-types/depth
					operation: instruction/a
					comparison?: operation >= EQUAL_OPERATION
					operation-ref: float-common-ref left-ref right-ref view
					floating?: operation-ref <> 0
					pointer?: all [
						any [operation = ADD_OPERATION operation = SUBTRACT_OPERATION]
						address-type? left-ref view
						any [
							integer-type? right-ref view
							all [
								operation = SUBTRACT_OPERATION
								address-type? right-ref view
								compatible-types? left-ref right-ref view
							]
						]
					]
					reference-comparison?: all [
						comparison?
						any [
							all [
								reference-type? left-ref view
								reference-type? right-ref view
								compatible-types? left-ref right-ref view
								any [
									operation <= NOT_EQUAL_OPERATION
									all [
										address-type? left-ref view
										address-type? right-ref view
									]
								]
							]
							all [
								(type-kind left-ref view) = 11
								(type-kind right-ref view) = 11
								operation <= NOT_EQUAL_OPERATION
							]
						]
					]
					unless any [
						pointer?
						reference-comparison?
						all [
							floating?
							any [
								operation <= DIVIDE_OPERATION
								operation >= EQUAL_OPERATION
							]
						]
						all [
							any [integer-type? left-ref view (type-kind left-ref view) = 11]
							any [integer-type? right-ref view (type-kind right-ref view) = 11]
							any [
								compatible-literal? left-ref right-ref view
								; Arithmetic and comparisons happen in one of the
								; two operand types, and a shift count is always
								; a plain 32-bit integer, so none of those need
								; the operands to share a type.
								operation <= MODULO_OPERATION
								operation >= EQUAL_OPERATION
								all [
									operation >= SHIFT_LEFT_OPERATION
									operation <= SHIFT_LOGICAL_OPERATION
									(type-kind right-ref view) = 5
								]
							]
						]
						; Integer-left address arithmetic is deliberately raw:
						; unlike pointer-left arithmetic, the address is not scaled.
						all [
							operation <= SUBTRACT_OPERATION
							(type-kind left-ref view) = 5
							address-type? right-ref view
						]
					][return INVALID_IR]
					; A comparison of two integer types happens in the wider of
					; them, so neither operand reaches the compare truncated.
					if all [
						comparison? not floating? not pointer?
						integer-type? left-ref view
						integer-type? right-ref view
						(value-width right-ref view) > (value-width left-ref view)
					][left-ref: right-ref]
					; A tracked operation names the OVERFLOW? scope it belongs
					; to, and branches to that scope's landing pad instead of
					; letting a wrapped result reach the program.
					tracked?: instruction/b <> 0
					last-math-condition: -1
					if all [
						not tracked?
						not comparison?
						integer-type? left-ref view
						overflow-query-follows? view fn first-instruction index
					][
						case [
							operation = ADD_OPERATION [
								last-math-condition: either signed-type? left-ref view [
									arm64-encoder/VS
								][arm64-encoder/CS]
							]
							operation = SUBTRACT_OPERATION [
								last-math-condition: either signed-type? left-ref view [
									arm64-encoder/VS
								][arm64-encoder/CC]
							]
							operation = MULTIPLY_OPERATION [
								last-math-condition: arm64-encoder/NE
							]
							true [0]
						]
						load-signed: either signed-type? left-ref view [1][0]
					]
					overflow-target: 0
					overflow-condition: -1
					base-depth: 0
					shift-count: 0
					right-ready?: false
					either tracked? [
						overflow-anchor: instruction/b
						if any [
							overflow-anchor <= 0 overflow-anchor >= ordinal
						][return INVALID_IR]
						overflow-scope: as rsir-instruction! (view/instructions
							+ ((first-instruction + overflow-anchor - 1)
								* RSIR_INSTRUCTION_SIZE))
						overflow-target: overflow-scope/a
						base-depth: instruction-depths/overflow-anchor
						unless all [
							overflow-scope/op = OP_OVERFLOW
							overflow-scope/b = 0 overflow-scope/c = 0
							overflow-target > overflow-anchor
							overflow-target <= fn/instruction-count
							base-depth >= 0 base-depth <= (depth - 2)
							not floating? not pointer? not comparison?
						][return INVALID_IR]
						kind: type-kind left-ref view
						case [
							operation <= MULTIPLY_OPERATION [
								unless all [
									instruction/c = 0
									integer-type? left-ref view
								][return INVALID_IR]
							]
							operation <= MODULO_OPERATION [
								unless all [instruction/c = 0 kind = 5][
									return INVALID_IR
								]
							]
							operation = SHIFT_LEFT_OPERATION [
								shift-count: either any [kind = 7 kind = 8][63][31]
								unless all [
									instruction/c > 0
									instruction/c <= shift-count
								][return INVALID_IR]
								shift-count: instruction/c
							]
							true [return INVALID_IR]
						]
						; The landing pad resumes the scope's stack, so the slots
						; it keeps must be in their canonical registers before
						; any operand move can set the flags.
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: canonicalize-stack view scratch base-depth
							at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						unless merge-control-target overflow-target base-depth fn
							view scratch instruction-depths entry-types
							entry-kinds entry-flags [return INVALID_IR]
					][
						if instruction/c <> 0 [return INVALID_IR]
					]
					if floating? [
						width: value-width operation-ref view
						target: FIRST_FLOAT_TEMP_REGISTER + source-slot - 1
						if target >= (FIRST_FLOAT_TEMP_REGISTER
							+ FLOAT_TEMP_REGISTER_COUNT)[return UNSUPPORTED]
						right: FLOAT_SCRATCH_REGISTER
						if all [
							scratch/stack-locations/depth = LOCATION_REGISTER
							(value-width right-ref view) = width
						][right: scratch/stack-low/depth]
						right-ready?: false
						; Preserve a right operand already occupying the result
						; register before the left operand is materialized over it.
						if right = target [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth FLOAT_SCRATCH_REGISTER
								operation-ref at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							right: FLOAT_SCRATCH_REGISTER
							right-ready?: true
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot target
							operation-ref at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						if all [right = FLOAT_SCRATCH_REGISTER not right-ready?][
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth right operation-ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: case [
							operation = ADD_OPERATION [
								arm64-encoder/float-binary at (capacity - written)
									arm64-encoder/OP_ADD target target right width
							]
							operation = SUBTRACT_OPERATION [
								arm64-encoder/float-binary at (capacity - written)
									arm64-encoder/OP_SUB target target right width
							]
							operation = MULTIPLY_OPERATION [
								arm64-encoder/float-multiply at (capacity - written)
									target target right width
							]
							operation = DIVIDE_OPERATION [
								arm64-encoder/float-divide at (capacity - written)
									target target right width
							]
							comparison? [
								arm64-encoder/float-compare at (capacity - written)
									target right width
							]
							true [-1]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						depth: source-slot
						scratch/stack-types/depth: either comparison? [-11][operation-ref]
						scratch/stack-kinds/depth: VALUE
						either comparison? [
							condition: float-comparison-condition operation
							if condition < 0 [return INVALID_IR]
							scratch/stack-locations/depth: LOCATION_FLAGS
							scratch/stack-low/depth: condition
						][
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
						]
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					result-width: either pointer? [8][value-width left-ref view]
					unless any [
						result-width = 1 result-width = 2
						result-width = 4 result-width = 8
					][return UNSUPPORTED]
					width: either result-width = 8 [8][4]
					folded: 0
					if all [
						not pointer?
						not tracked?
						last-math-condition < 0
						result-width = 4
						scratch/stack-locations/source-slot = LOCATION_IMMEDIATE
						scratch/stack-locations/depth = LOCATION_IMMEDIATE
						fold-integer32 operation scratch/stack-low/source-slot
							scratch/stack-low/depth :folded
					][
						depth: source-slot
						scratch/stack-types/depth: left-ref
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_IMMEDIATE
						scratch/stack-low/depth: folded
						scratch/stack-high/depth: either folded < 0 [-1][0]
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					]
					target: FIRST_TEMP_REGISTER + source-slot - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
					if all [
						not comparison? not tracked?
						(index + 2) < fn/instruction-count
					][
						next-instruction: as rsir-instruction! (view/instructions
							+ ((first-instruction + index + 1) * RSIR_INSTRUCTION_SIZE))
						following-instruction: as rsir-instruction! (view/instructions
							+ ((first-instruction + index + 2) * RSIR_INSTRUCTION_SIZE))
						if all [
							next-instruction/op = OP_ADDRESS
							next-instruction/a = LOCAL_ADDRESS
							next-instruction/b > 0
							next-instruction/b <= plan/storage-count
							next-instruction/c = 0
							following-instruction/op = OP_SET
							following-instruction/a = 0
							following-instruction/b = 0
							following-instruction/c = 0
						][
							slot: next-instruction/b
							if scratch/homes/slot > 0 [target: scratch/homes/slot]
						]
					]
					if pointer? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-pointer-binary view layout scratch source-slot depth
							target operation at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						depth: source-slot
						scratch/stack-types/depth: left-ref
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
						index: index + 1
						continue
					]
					left: arm64-encoder/X16
					either scratch/stack-locations/source-slot = LOCATION_REGISTER [
						left: scratch/stack-low/source-slot
					][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot left left-ref
							at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
					]
					if all [operation = SHIFT_LOGICAL_OPERATION result-width < 4][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							arm64-encoder/X16 left result-width 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						left: arm64-encoder/X16
					]
					literal?: scratch/stack-locations/depth = LOCATION_IMMEDIATE
					immediate?: all [
						literal?
						any [
							width = 4
							all [scratch/stack-low/depth >= 0
								scratch/stack-high/depth = 0]
							all [scratch/stack-low/depth < 0
								scratch/stack-high/depth = -1]
						]
					]
					; The flags an ADDS or a SUBS leaves are the whole point of a
					; tracked sum, and an immediate that folds a subtraction into
					; an addition would report the wrong carry.
					if all [tracked? operation <= SUBTRACT_OPERATION][
						immediate?: false
					]
					if tracked? [
						load-signed: either signed-type? left-ref view [1][0]
						case [
							all [
								operation >= DIVIDE_OPERATION
								operation <= MODULO_OPERATION
							][
								; Only INT_MIN / -1 leaves the quotient's type, and
								; both operands have to be live to say so: x - 1
								; overflows for INT_MIN alone, x + 1 is zero for -1
								; alone.
								right: arm64-encoder/X17
								either all [
									scratch/stack-locations/depth
										= LOCATION_REGISTER
									any [
										width = 4
										(value-width right-ref view) = 8
									]
								][
									right: scratch/stack-low/depth
								][
									at: either null? code [as byte-ptr! 0][
										code + written
									]
									encoded: materialize view scratch depth right
										left-ref at (capacity - written)
									if encoded < 0 [return encoded]
									written: written + encoded
								]
								right-ready?: true
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-negative-immediate
									at (capacity - written) right 1 width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/NE 12
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-immediate at
									(capacity - written) left 1 width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								displacement: either null? code [0][
									instruction-offsets/overflow-target - written
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/VS displacement
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							all [
								operation = SHIFT_LEFT_OPERATION
								result-width >= 4
							][
								; Shifting the count back has to return the value
								; the source held, otherwise a bit left the type.
								unless all [
									immediate?
									scratch/stack-low/depth = shift-count
								][return INVALID_IR]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/shift-immediate at
									(capacity - written) arm64-encoder/SHIFT_LEFT
									arm64-encoder/X17 left shift-count width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								condition: either load-signed = 1 [
									arm64-encoder/SHIFT_ARITHMETIC
								][arm64-encoder/SHIFT_RIGHT]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/shift-immediate at
									(capacity - written) condition arm64-encoder/X17
									arm64-encoder/X17 shift-count width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-register at
									(capacity - written) arm64-encoder/X17 left width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								displacement: either null? code [0][
									instruction-offsets/overflow-target - written
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/NE displacement
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							true [0]
						]
					]
					encoded: -1
					case [
						operation = ADD_OPERATION [
							if immediate? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: either last-math-condition >= 0 [
									arm64-encoder/add-immediate-flags at
										(capacity - written) target left
										scratch/stack-low/depth width
								][
									arm64-encoder/add-immediate at
										(capacity - written) target left
										scratch/stack-low/depth width
								]
							]
						]
						operation = SUBTRACT_OPERATION [
							if immediate? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: either last-math-condition >= 0 [
									arm64-encoder/add-immediate-flags at
										(capacity - written) target left
										(0 - scratch/stack-low/depth) width
								][
									arm64-encoder/add-immediate at
										(capacity - written) target left
										(0 - scratch/stack-low/depth) width
								]
							]
						]
						all [
							operation >= SHIFT_LEFT_OPERATION
							operation <= SHIFT_LOGICAL_OPERATION
						][
							if immediate? [
								condition: case [
									operation = SHIFT_LEFT_OPERATION [
										arm64-encoder/SHIFT_LEFT
									]
									operation = SHIFT_RIGHT_OPERATION [
										either signed-type? left-ref view [
											arm64-encoder/SHIFT_ARITHMETIC
										][arm64-encoder/SHIFT_RIGHT]
									]
									true [arm64-encoder/SHIFT_RIGHT]
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/shift-immediate at
									(capacity - written) condition target left
									scratch/stack-low/depth width
							]
						]
						all [operation >= OR_OPERATION operation <= AND_OPERATION][
							if literal? [
								condition: case [
									operation = OR_OPERATION [arm64-encoder/OP_OR]
									operation = XOR_OPERATION [arm64-encoder/OP_XOR]
									true [arm64-encoder/OP_AND]
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/logical-immediate at
									(capacity - written) condition target left width
									scratch/stack-low/depth scratch/stack-high/depth
							]
						]
						operation >= EQUAL_OPERATION [
							if all [immediate? scratch/stack-low/depth >= 0][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-immediate at
									(capacity - written) left
									scratch/stack-low/depth width
							]
						]
						true [-1]
					]
					if encoded < 0 [
						unless right-ready? [
							right: arm64-encoder/X17
							either all [
								scratch/stack-locations/depth = LOCATION_REGISTER
								any [width = 4 (value-width right-ref view) = 8]
							][
								right: scratch/stack-low/depth
							][
								; The operation runs in the left operand's type,
								; so a narrower right operand is extended into it
								; rather than used as it stands.
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth right left-ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: case [
							operation = ADD_OPERATION [
								arm64-encoder/alu-register at (capacity - written)
									arm64-encoder/OP_ADD target left right width
									any [tracked? last-math-condition >= 0]
							]
							operation = SUBTRACT_OPERATION [
								arm64-encoder/alu-register at (capacity - written)
									arm64-encoder/OP_SUB target left right width
									any [tracked? last-math-condition >= 0]
							]
							all [tracked? operation = MULTIPLY_OPERATION
								result-width >= 4
							][
								emit-tracked-multiply target left right
									result-width load-signed at (capacity - written)
							]
							operation = MULTIPLY_OPERATION [
								either all [
									last-math-condition >= 0 result-width >= 4
								][
									emit-tracked-multiply target left right result-width
										load-signed
										at (capacity - written)
								][
									arm64-encoder/multiply-register at
										(capacity - written) target left right width
								]
							]
							operation = DIVIDE_OPERATION [
								load-signed: either signed-type? left-ref view [1][0]
								arm64-encoder/divide-register at (capacity - written)
									target left right width
									load-signed
							]
							any [
								operation = REMAINDER_OPERATION
								operation = MODULO_OPERATION
							][
								; MSUB still needs both operands after DIV writes target.
								if left = target [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/move-register at
										(capacity - written) arm64-encoder/X16 left width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									left: arm64-encoder/X16
								]
								if right = target [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/move-register at
										(capacity - written) arm64-encoder/X17 right width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									right: arm64-encoder/X17
								]
								at: either null? code [as byte-ptr! 0][code + written]
								load-signed: either signed-type? left-ref view [1][0]
								encoded: arm64-encoder/divide-register at
									(capacity - written) target left right width
									load-signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/multiply-subtract at
									(capacity - written) target target right left width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								0
							]
							operation = OR_OPERATION [
								arm64-encoder/alu-register at (capacity - written)
									arm64-encoder/OP_OR target left right
									width false
							]
							operation = XOR_OPERATION [
								arm64-encoder/alu-register at (capacity - written)
									arm64-encoder/OP_XOR target left right
									width false
							]
							operation = AND_OPERATION [
								arm64-encoder/alu-register at (capacity - written)
									arm64-encoder/OP_AND target left right
									width false
							]
							all [
								operation >= SHIFT_LEFT_OPERATION
								operation <= SHIFT_LOGICAL_OPERATION
							][
								condition: case [
									operation = SHIFT_LEFT_OPERATION [
										arm64-encoder/SHIFT_LEFT
									]
									operation = SHIFT_RIGHT_OPERATION [
										either signed-type? left-ref view [
											arm64-encoder/SHIFT_ARITHMETIC
										][arm64-encoder/SHIFT_RIGHT]
									]
									true [arm64-encoder/SHIFT_RIGHT]
								]
								arm64-encoder/shift-register at (capacity - written)
									condition target left right width
							]
							operation >= EQUAL_OPERATION [
								arm64-encoder/compare-register at (capacity - written)
									left right width
							]
							true [-1]
						]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if all [
						not tracked?
						last-math-condition >= 0
						result-width < 4
						operation <= MULTIPLY_OPERATION
					][
						load-signed: either signed-type? left-ref view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-extended-register at
							(capacity - written) target target 4 result-width load-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						last-math-condition: arm64-encoder/NE
					]
					if tracked? [
						load-signed: either signed-type? left-ref view [1][0]
						if result-width >= 4 [
							overflow-condition: case [
								operation = ADD_OPERATION [
									either load-signed = 1 [
										arm64-encoder/VS
									][arm64-encoder/CS]
								]
								operation = SUBTRACT_OPERATION [
									either load-signed = 1 [
										arm64-encoder/VS
									][arm64-encoder/CC]
								]
								operation = MULTIPLY_OPERATION [arm64-encoder/NE]
								true [-1]
							]
						]
						if overflow-condition >= 0 [
							displacement: either null? code [0][
								instruction-offsets/overflow-target - written
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-condition at
								(capacity - written) overflow-condition displacement
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if result-width < 4 [
							; A narrow result is computed 32 bits wide, so it has
							; overflowed exactly when it no longer survives being
							; re-extended from its own type.
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-extended-register at
								(capacity - written) target target width result-width
								load-signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							displacement: either null? code [0][
								instruction-offsets/overflow-target - written
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-condition at
								(capacity - written) arm64-encoder/NE displacement
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					if all [
						operation = MODULO_OPERATION
						signed-type? left-ref view
						][
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-immediate at
								(capacity - written) right 0 width
						if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/conditional-negate at
								(capacity - written) arm64-encoder/X16 right width
								arm64-encoder/MI
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/conditional-select at
							(capacity - written) arm64-encoder/X16 arm64-encoder/X16
								arm64-encoder/ZR
							width arm64-encoder/MI
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/add-register at
							(capacity - written) target target arm64-encoder/X16 width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if all [not comparison? result-width < 4][
						load-signed: either signed-type? left-ref view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							target target result-width load-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					depth: source-slot
					scratch/stack-types/depth: either comparison? [-11][left-ref]
					scratch/stack-kinds/depth: VALUE
					either comparison? [
						condition: comparison-condition operation (signed-type? left-ref view)
						if condition < 0 [return INVALID_IR]
						scratch/stack-locations/depth: LOCATION_FLAGS
						scratch/stack-low/depth: condition
					][
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
					]
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_JUMP [
					target: instruction/a
					current-catch-depth: catch-depths/ordinal
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/b = 0
						instruction/c >= 0
					][return UNSUPPORTED]
						either plan/catch-capacity = 0 [
							if instruction/c <> 0 [return INVALID_IR]
						][
							target-catch-depth: catch-depths/target
							expected-catch-depth: current-catch-depth - instruction/c
							unless all [
								instruction/c <= current-catch-depth
								(target-catch-depth - expected-catch-depth) = 0
						][return INVALID_IR]
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					catch-level: catch-depths/ordinal
					catch-unwind: instruction/c
					while [catch-unwind > 0][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-catch-restore at (capacity - written)
							catch-level
						if encoded < 0 [return encoded]
						written: written + encoded
						catch-level: catch-level - 1
						catch-unwind: catch-unwind - 1
					]
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return INVALID_IR
					]
					displacement: either null? code [0][
						instruction-offsets/target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_BRANCH [
					target: instruction/a
					current-catch-depth: catch-depths/ordinal
					target-catch-depth: catch-depths/target
					unless all [
						target > 0 target <= fn/instruction-count
						(target-catch-depth - current-catch-depth) = 0
						any [instruction/b = 0 instruction/b = 1]
						instruction/c = 0 depth > 0
						compatible-literal? -11 scratch/stack-types/depth view
					][return INVALID_IR]
					source-slot: depth
					if all [
						depth > 1
						scratch/stack-locations/source-slot <> LOCATION_IMMEDIATE
					][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot arm64-encoder/X17
							-11 at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						scratch/stack-locations/source-slot: LOCATION_REGISTER
						scratch/stack-low/source-slot: arm64-encoder/X17
						scratch/stack-high/source-slot: 0
					]
					depth: depth - 1
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return INVALID_IR
					]
					displacement: either null? code [0][
						instruction-offsets/target - written
					]
					encoded: 0
					case [
						scratch/stack-locations/source-slot = LOCATION_IMMEDIATE [
							taken?: either instruction/b = 1 [
								scratch/stack-low/source-slot <> 0
							][scratch/stack-low/source-slot = 0]
							if taken? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-relative at
									(capacity - written) displacement
							]
						]
						scratch/stack-locations/source-slot = LOCATION_FLAGS [
							condition: scratch/stack-low/source-slot
							if instruction/b = 0 [condition: condition xor 1]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-condition at
								(capacity - written) condition displacement
						]
						scratch/stack-locations/source-slot = LOCATION_REGISTER [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-zero at
								(capacity - written) scratch/stack-low/source-slot 4
								displacement (instruction/b = 1)
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_SWITCH [
					target: instruction/c
					current-catch-depth: catch-depths/ordinal
					target-catch-depth: catch-depths/target
					unless all [
						instruction/a >= 0 instruction/b > 0
						instruction/b <= view/header/switch-count
						instruction/a <= (view/header/switch-count - instruction/b)
						target > 0 target <= fn/instruction-count
						(target-catch-depth - current-catch-depth) = 0
						depth > 0 scratch/stack-kinds/depth = VALUE
						scratch/stack-flags/depth = 0
						integer-type? scratch/stack-types/depth view
					][return INVALID_IR]
					ref: scratch/stack-types/depth
					width: value-width ref view
					result-width: either width = 8 [8][4]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth arm64-encoder/X17 ref
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					depth: depth - 1
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						unless merge-control-target target depth fn view scratch
							instruction-depths entry-types entry-kinds entry-flags [
							return INVALID_IR
						]
						at: either null? code [as byte-ptr! 0][code + written]
						either all [
							switch-case/high = 0
							switch-case/low >= 0 switch-case/low <= 4095
						][
							encoded: arm64-encoder/compare-immediate at
								(capacity - written) arm64-encoder/X17
								switch-case/low result-width
						][
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X16 result-width
								switch-case/low switch-case/high
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-register at
								(capacity - written) arm64-encoder/X17
								arm64-encoder/X16 result-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						displacement: either null? code [0][
							instruction-offsets/target - written
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/branch-condition at
							(capacity - written) arm64-encoder/EQ displacement
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						case-index: case-index + 1
					]
					target: instruction/c
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return INVALID_IR
					]
					displacement: either null? code [0][
						instruction-offsets/target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0 instruction/b = 0 instruction/c = 0
					][return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/trap at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_RETURN [
					if any [
						instruction/a <> fn/return-type
						instruction/c <> 0
						all [instruction/a = 0 instruction/b <> 0]
					][return INVALID_IR]
					either instruction/a = 0 [
						if depth <> 0 [return INVALID_IR]
						if entry? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X0 4 0 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					][
						unless all [
							depth = 1 instruction/b = 0
							implicitly-compatible? instruction/a scratch/stack-types/depth
								(scratch/stack-locations/depth = LOCATION_IMMEDIATE) view
						][return INVALID_IR]
						either (fn/flags and RETURN_VALUE) <> 0 [
							return-size: 0
							return-align: 0
							unless layout-type instruction/a true view layout 0
								:return-size :return-align [return INVALID_IR]
							if any [return-size <= 0 return-align <= 0 return-align > 16][
								return UNSUPPORTED
							]
							return-hfa-kind: 0
							return-hfa-count: 0
							hfa-return?: classify-hfa instruction/a INLINE view 0
								:return-hfa-kind :return-hfa-count
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X15
								instruction/a at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							case [
								hfa-return? [
									return-width: either return-hfa-kind = 9 [4][8]
									case-index: 0
									while [case-index < return-hfa-count][
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/float-register-load at
											(capacity - written) case-index arm64-encoder/X15
											(case-index * return-width) return-width
											arm64-encoder/X16
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										case-index: case-index + 1
									]
								]
								return-size <= 16 [
									return-chunk-offset: 0
									case-index: 0
									while [return-chunk-offset < return-size][
										return-chunk-size: return-size - return-chunk-offset
										if return-chunk-size > 8 [return-chunk-size: 8]
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: emit-aggregate-chunk-load at
											(capacity - written) case-index arm64-encoder/X15
											return-chunk-offset return-chunk-size
										if encoded < 0 [return encoded]
										written: written + encoded
										return-chunk-offset: return-chunk-offset + 8
										case-index: case-index + 1
									]
								]
								true [
									if plan/hidden-return-offset = 0 [return INVALID_IR]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-load at
										(capacity - written) arm64-encoder/X14
										plan/hidden-return-offset 8 0 8
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: emit-memory-copy at (capacity - written)
										arm64-encoder/X14 arm64-encoder/X15 return-size
									if encoded < 0 [return encoded]
									written: written + encoded
								]
							]
						][
							if aggregate-ref? instruction/a view [
								unless all [
									scratch/stack-flags/depth = 0
									(value-width instruction/a view) = 8
								][return INVALID_IR]
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X0
								instruction/a at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						depth: 0
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-epilogue plan at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					return-count: return-count + 1
					fallthrough?: false
				]
				true [return UNSUPPORTED]
			]
			index: index + 1
		]
		if all [plan/unwind = 1 not entry?] [
			if plan/unwind-fixup < 0 [return INVALID_IR]
			handler-offset: written
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: emit-unwind-handler plan at (capacity - written)
			if encoded < 0 [return encoded]
			written: written + encoded
			unless measure? [
				displacement: handler-offset - plan/unwind-fixup
				at: code + plan/unwind-fixup
				encoded: arm64-encoder/address-relative at
					(capacity - plan/unwind-fixup) arm64-encoder/X16 displacement
				if encoded <> 4 [return OUTPUT_FULL]
			]
		]
		either not fallthrough? [written][INVALID_IR]
	]

	release: func [memory [byte-ptr!] result [integer!] return: [integer!]][
		if not null? memory [free memory]
		result
	]

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local view [rsir-view! value]
			scratch [arm64-function-scratch! value]
			plan [arm64-function-plan! value]
			layout [arm64-layout-state! value]
			reference-state [arm64-reference-state! value]
			header [rsir-header!]
			fn [rsir-function!]
			global [rsir-global!]
			imported [rsir-import!]
			exported [rsir-export!]
			image [codegen-header!]
			image-function [codegen-function!]
			image-global [codegen-global!]
			image-import [codegen-import!]
			image-export [codegen-export!]
			instruction [rsir-instruction!]
			memory code names cursor finish image-globals image-imports image-exports
				rodata-output data-output [byte-ptr!]
		function-sizes function-offsets function-frames
			function-unwind instruction-starts global-offsets global-sizes
				global-owners global-children global-siblings [int-ptr!]
			id first-instruction written code-size code-cursor
			metadata-size names-size code-offset rodata-offset data-offset
			data-size total-size name-cursor entry-id storage-count
			rodata-size reference-count
			max-storage max-instructions words status member-id
			target-count target-id used-import-count last-library
			library-offset external-offset output-import-id [integer!]
			index changed callee-unwind unwind-value [integer!]
			entry? startup? startup-entry? unwind? [logic!]
	][
		if any [null? output capacity < 0][return INVALID_IR]
		unless any [opt-level = 0 opt-level = 2][return UNSUPPORTED]
		if (codegen-rsir-reader/open data size view) <> 0 [
			print ["ARM64 reader failure size=" size lf]
			return INVALID_IR
		]
		header: view/header
		startup?: all [
			header/module-kind = 3
			startup-registers-used? view
		]
		max-storage: 0
		max-instructions: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			storage-count: fn/parameter-count + fn/local-count
			if storage-count > max-storage [max-storage: storage-count]
			if fn/instruction-count > max-instructions [
				max-instructions: fn/instruction-count
			]
			id: id + 1
		]
		if header/function-count > (2147483647 / 5)[return OUTPUT_FULL]
		words: header/function-count * 5
		if max-storage > ((2147483647 - words) / 3)[return OUTPUT_FULL]
		words: words + (max-storage * 3)
		if max-instructions > ((2147483647 - words) / 9)[return OUTPUT_FULL]
		words: words + (max-instructions * 9)
		if header/instruction-count > ((2147483647 - words) / 9)[
			return OUTPUT_FULL
		]
		words: words + (header/instruction-count * 9)
		if header/switch-count > ((2147483647 - words) / 2)[return OUTPUT_FULL]
		words: words + (header/switch-count * 2)
		if header/global-count > ((2147483647 - words) / 6)[return OUTPUT_FULL]
		words: words + (header/global-count * 6)
		if header/function-count > (2147483647 - header/global-count)[
			return OUTPUT_FULL
		]
		target-count: header/function-count + header/global-count
		if target-count > (2147483647 - header/import-count)[return OUTPUT_FULL]
		target-count: target-count + header/import-count
		if target-count > ((2147483647 - words) / 3)[return OUTPUT_FULL]
		words: words + (target-count * 3)
		if header/type-count > ((2147483647 - words) / 2)[return OUTPUT_FULL]
		words: words + (header/type-count * 2)
		if view/member-count > (2147483647 - words)[return OUTPUT_FULL]
		words: words + view/member-count
		if words > (2147483647 / 4)[return OUTPUT_FULL]
		memory: allocate words * 4
		if null? memory [return OUTPUT_FULL]
		function-sizes: as int-ptr! memory
		function-offsets: function-sizes + header/function-count
		function-frames: function-offsets + header/function-count
		function-unwind: function-frames + header/function-count
		instruction-starts: function-unwind + header/function-count
		scratch/homes: instruction-starts + header/function-count
		scratch/storage-types: scratch/homes + max-storage
		scratch/storage-kinds: scratch/storage-types + max-storage
		scratch/stack-types: scratch/storage-kinds + max-storage
		scratch/stack-kinds: scratch/stack-types + max-instructions
		scratch/stack-locations: scratch/stack-kinds + max-instructions
		scratch/stack-low: scratch/stack-locations + max-instructions
		scratch/stack-high: scratch/stack-low + max-instructions
		scratch/stack-flags: scratch/stack-high + max-instructions
		scratch/plan-depths: scratch/stack-flags + max-instructions
		scratch/entry-spill-bases: scratch/plan-depths + max-instructions
		scratch/entry-spill-limits: scratch/entry-spill-bases + max-instructions
		scratch/instruction-offsets:
			scratch/entry-spill-limits + max-instructions
		scratch/instruction-depths:
			scratch/instruction-offsets + header/instruction-count
		scratch/catch-depths:
			scratch/instruction-depths + header/instruction-count
		scratch/entry-types: scratch/catch-depths + header/instruction-count
		scratch/entry-kinds: scratch/entry-types + header/instruction-count
		scratch/entry-flags: scratch/entry-kinds + header/instruction-count
		scratch/control-uses: scratch/entry-flags + header/instruction-count
		scratch/result-offsets: scratch/control-uses + header/instruction-count
		scratch/instruction-effects:
			scratch/result-offsets + header/instruction-count
		scratch/switch-effect-links:
			scratch/instruction-effects + header/instruction-count
		scratch/switch-effect-users:
			scratch/switch-effect-links + header/switch-count
		scratch/global-homes: scratch/switch-effect-users + header/switch-count
		global-offsets: scratch/global-homes + header/global-count
		global-sizes: global-offsets + header/global-count
		global-owners: global-sizes + header/global-count
		global-children: global-owners + header/global-count
		global-siblings: global-children + header/global-count
		reference-state/counts: global-siblings + header/global-count
		reference-state/starts: reference-state/counts + target-count
		reference-state/cursors: reference-state/starts + target-count
		reference-state/references: as int-ptr! 0
		layout/sizes: reference-state/cursors + target-count
		layout/alignments: layout/sizes + header/type-count
		layout/member-offsets: layout/alignments + header/type-count
		id: 1
		while [id <= header/type-count][
			layout/sizes/id: 0
			layout/alignments/id: 0
			id: id + 1
		]
		member-id: 1
		while [member-id <= view/member-count][
			layout/member-offsets/member-id: 0
			member-id: member-id + 1
		]
		id: 1
		while [id <= target-count][
			reference-state/counts/id: 0
			reference-state/cursors/id: 0
			id: id + 1
		]

		; Exception metadata is needed only on call paths that can actually
		; unwind.  Seed the direct throw/catch functions, then propagate that
		; property through direct and indirect calls before planning frames.
		first-instruction: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			instruction-starts/id: first-instruction
			function-unwind/id: either (fn/flags and CATCH_FLAG) <> 0 [1][0]
			index: 0
			while [index < fn/instruction-count][
				instruction: as rsir-instruction! (view/instructions
					+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
				if any [instruction/op = OP_CATCH instruction/op = OP_THROW][
					function-unwind/id: 1
				]
				if all [instruction/op = OP_CALL instruction/a = 0][
					function-unwind/id: 1
				]
				index: index + 1
			]
			first-instruction: first-instruction + fn/instruction-count
			id: id + 1
		]
		changed: 1
		while [changed = 1][
			changed: 0
			id: 1
			while [id <= header/function-count][
				unwind-value: function-unwind/id
				if unwind-value = 0 [
					fn: as rsir-function! (view/functions
						+ ((id - 1) * RSIR_FUNCTION_SIZE))
					first-instruction: instruction-starts/id
					index: 0
					while [index < fn/instruction-count][
						instruction: as rsir-instruction! (view/instructions
							+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
						if instruction/op = OP_CALL [
							target-id: instruction/a
							if target-id = 0 [
								function-unwind/id: 1
								changed: 1
							]
							if all [
								target-id > 0
								target-id <= header/function-count
							][
								callee-unwind: function-unwind/target-id
								if callee-unwind <> 0 [
									function-unwind/id: 1
									changed: 1
								]
							]
						]
						index: index + 1
					]
				]
				id: id + 1
			]
		]
		status: prepare-subroutine-effects view scratch
		if status < 0 [return release memory status]
		status: prepare-control-targets view scratch
		if status < 0 [
			print ["ARM64 control-target failure status=" status
				" functions=" header/function-count
				" instructions=" header/instruction-count lf]
			return release memory status
		]

		if header/function-count > (2147483647 / BITMAP_SIZE)[
			return release memory OUTPUT_FULL
		]
		data-size: header/function-count * BITMAP_SIZE
		rodata-size: 0
		status: prepare-global-data view layout reference-state
			global-offsets global-sizes global-owners global-children global-siblings
			:data-size :rodata-size
		if status < 0 [
			print ["ARM64 global-data failure status=" status
				" globals=" header/global-count
				" types=" header/type-count lf]
			return release memory status
		]

		code-size: 0
		first-instruction: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			instruction-starts/id: first-instruction
			entry?: all [header/module-kind = 3 id = header/entry-function]
			startup-entry?: all [entry? startup?]
			unwind-value: function-unwind/id
			unwind?: unwind-value <> 0
			status: plan-function view layout fn first-instruction startup-entry?
				unwind? scratch plan
			if status < 0 [
				print ["ARM64 measure plan failure function=" id " status=" status
					" ordinal=" last-plan-ordinal
					" flags=" fn/flags " instructions=" fn/instruction-count lf]
				index: 0
				while [index < fn/instruction-count][
					instruction: as rsir-instruction! (view/instructions
						+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
					print ["  ir[" (index + 1) "]=" instruction/op "/"
						instruction/a "/" instruction/b "/" instruction/c lf]
					index: index + 1
				]
				return release memory status
			]
			function-frames/id: either all [
				plan/home-count = 0
				plan/float-home-count = 0
				plan/frame-home-count = 0
				plan/has-call = 0
				plan/hidden-return-offset = 0
				plan/tag-offset = 0
			][0][
				16 + plan/frame-allocation
			]
			written: compile-function view layout fn first-instruction entry?
				startup-entry? scratch plan reference-state as int-ptr! 0 0 null 0
			if written < 0 [
				print ["ARM64 measure compile failure function=" id " status=" written
					" ordinal=" last-compile-ordinal
					" flags=" fn/flags " instructions=" fn/instruction-count lf]
				index: 0
				while [index < fn/instruction-count][
					instruction: as rsir-instruction! (view/instructions
						+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
					print ["  ir[" (index + 1) "]=" instruction/op "/"
						instruction/a "/" instruction/b "/" instruction/c lf]
					index: index + 1
				]
				return release memory written
			]
			function-sizes/id: written
			if code-size > (2147483647 - written)[return release memory OUTPUT_FULL]
			code-size: code-size + written
			first-instruction: first-instruction + fn/instruction-count
			id: id + 1
		]
		reference-count: 0
		id: 1
		while [id <= target-count][
			reference-state/starts/id: either reference-state/counts/id > 0 [
				reference-count + 1
			][0]
			if reference-count > (2147483647 - reference-state/counts/id)[
				return release memory OUTPUT_FULL
			]
			reference-count: reference-count + reference-state/counts/id
			id: id + 1
		]
		used-import-count: 0
		id: 1
		while [id <= header/import-count][
			target-id: header/function-count + header/global-count + id
			if reference-state/counts/target-id > 0 [
				if used-import-count = 2147483647 [return release memory OUTPUT_FULL]
				used-import-count: used-import-count + 1
			]
			id: id + 1
		]

		entry-id: either header/module-kind = 3 [header/entry-function][0]
		code-cursor: 0
		if entry-id > 0 [
			function-offsets/entry-id: 0
			code-cursor: function-sizes/entry-id
		]
		id: 1
		while [id <= header/function-count][
			if id <> entry-id [
				function-offsets/id: code-cursor
				code-cursor: code-cursor + function-sizes/id
			]
			id: id + 1
		]

		if header/function-count > ((2147483647 - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE)[
			return release memory OUTPUT_FULL
		]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > ((2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return release memory OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if used-import-count > ((2147483647 - metadata-size) / IMAGE_IMPORT_SIZE)[
			return release memory OUTPUT_FULL
		]
		metadata-size: metadata-size + (used-import-count * IMAGE_IMPORT_SIZE)
		if header/export-count > ((2147483647 - metadata-size) / IMAGE_EXPORT_SIZE)[
			return release memory OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/export-count * IMAGE_EXPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release memory OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			if names-size > (2147483647 - fn/name-size)[
				return release memory OUTPUT_FULL
			]
			names-size: names-size + fn/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if names-size > (2147483647 - global/name-size)[
				return release memory OUTPUT_FULL
			]
			names-size: names-size + global/name-size
			id: id + 1
		]
		last-library: -1
		id: 1
		while [id <= header/import-count][
			target-id: header/function-count + header/global-count + id
			if reference-state/counts/target-id > 0 [
				imported: as rsir-import! (view/imports + ((id - 1) * RSIR_IMPORT_SIZE))
				if imported/library <> last-library [
					if names-size > (2147483647 - imported/library-size)[
						return release memory OUTPUT_FULL
					]
					names-size: names-size + imported/library-size
					last-library: imported/library
				]
				if names-size > (2147483647 - imported/external-size)[
					return release memory OUTPUT_FULL
				]
				names-size: names-size + imported/external-size
			]
			id: id + 1
		]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if names-size > (2147483647 - exported/name-size)[
				return release memory OUTPUT_FULL
			]
			names-size: names-size + exported/name-size
			id: id + 1
		]
		if metadata-size > (2147483647 - names-size - 15)[
			return release memory OUTPUT_FULL
		]
		code-offset: align (metadata-size + names-size) 16
		if any [code-offset < 0 code-offset > (2147483647 - code-size - 3)][
			return release memory OUTPUT_FULL
		]
		rodata-offset: align (code-offset + code-size) 4
		if rodata-offset > (2147483647 - rodata-size - 3)[
			return release memory OUTPUT_FULL
		]
		data-offset: align (rodata-offset + rodata-size) 4
		if data-offset > (2147483647 - data-size)[return release memory OUTPUT_FULL]
		total-size: data-offset + data-size
		if capacity < total-size [return release memory OUTPUT_FULL]

		cursor: output
		finish: output + total-size
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
		image: as codegen-header! output
		image/size: total-size
		image/module-kind: header/module-kind
		image/entry-function: header/entry-function
		image/function-count: header/function-count
		image/import-count: used-import-count
		image/reference-count: reference-count
		image/names-size: names-size
		image/code-offset: code-offset
		image/code-size: code-size
		image/data-size: data-size
		image/global-count: header/global-count
		image/rodata-size: rodata-size
		image/export-count: header/export-count

		image-globals: output + IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		image-imports: image-globals + (header/global-count * IMAGE_GLOBAL_SIZE)
		image-exports: image-imports + (used-import-count * IMAGE_IMPORT_SIZE)
		reference-state/references: as int-ptr! (image-exports
			+ (header/export-count * IMAGE_EXPORT_SIZE))
		names: output + metadata-size
		name-cursor: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			image-function/name: name-cursor
			image-function/name-size: fn/name-size
			image-function/code-offset: function-offsets/id
			image-function/code-size: function-sizes/id
			image-function/frame-size: function-frames/id
			image-function/bitmap-offset: (id - 1) * BITMAP_SIZE
			image-function/bitmap-size: BITMAP_SIZE
			image-function/first-reference: reference-state/starts/id
			image-function/reference-count: reference-state/counts/id
			copy-memory (names + name-cursor) (view/strings + fn/name) fn/name-size
			name-cursor: name-cursor + fn/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			target-id: header/function-count + id
			image-global/name: name-cursor
			image-global/name-size: global/name-size
			image-global/data-offset: global-offsets/id
			image-global/data-size: global-sizes/id
			image-global/first-reference: reference-state/starts/target-id
			image-global/reference-count: reference-state/counts/target-id
			image-global/flags: global/flags and PROTECTED
			copy-memory (names + name-cursor)
				(view/strings + global/name) global/name-size
			name-cursor: name-cursor + global/name-size
			id: id + 1
		]
		output-import-id: 0
		last-library: -1
		library-offset: 0
		id: 1
		while [id <= header/import-count][
			target-id: header/function-count + header/global-count + id
			if reference-state/counts/target-id > 0 [
				imported: as rsir-import! (view/imports + ((id - 1) * RSIR_IMPORT_SIZE))
				if imported/library <> last-library [
					library-offset: name-cursor
					copy-memory (names + name-cursor)
						(view/strings + imported/library) imported/library-size
					name-cursor: name-cursor + imported/library-size
					last-library: imported/library
				]
				external-offset: name-cursor
				copy-memory (names + name-cursor)
					(view/strings + imported/external) imported/external-size
				name-cursor: name-cursor + imported/external-size
				image-import: as codegen-import! (image-imports
					+ (output-import-id * IMAGE_IMPORT_SIZE))
				image-import/library: library-offset
				image-import/library-size: imported/library-size
				image-import/external: external-offset
				image-import/external-size: imported/external-size
				image-import/first-reference: reference-state/starts/target-id
				image-import/reference-count: reference-state/counts/target-id
				output-import-id: output-import-id + 1
			]
			id: id + 1
		]
		if output-import-id <> used-import-count [return release memory INVALID_IR]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			image-export: as codegen-export! (image-exports
				+ ((id - 1) * IMAGE_EXPORT_SIZE))
			image-export/symbol: exported/symbol
			image-export/name: name-cursor
			image-export/name-size: exported/name-size
			copy-memory (names + name-cursor)
				(view/strings + exported/name) exported/name-size
			name-cursor: name-cursor + exported/name-size
			id: id + 1
		]

		code: output + code-offset
		id: 1
		while [id <= target-count][
			reference-state/cursors/id: 0
			id: id + 1
		]
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			entry?: all [header/module-kind = 3 id = header/entry-function]
			startup-entry?: all [entry? startup?]
			unwind-value: function-unwind/id
			unwind?: unwind-value <> 0
			status: plan-function view layout fn instruction-starts/id startup-entry?
				unwind? scratch plan
			if status < 0 [
				print ["ARM64 plan failure function=" id " status=" status
					" flags=" fn/flags " instructions=" fn/instruction-count lf]
				return release memory status
			]
			written: compile-function view layout fn instruction-starts/id
				entry? startup-entry? scratch plan reference-state
				function-offsets function-offsets/id
				(code + function-offsets/id) function-sizes/id
			if written <> function-sizes/id [
				print ["ARM64 compile failure function=" id " status=" written
					" expected=" function-sizes/id " flags=" fn/flags
					" instructions=" fn/instruction-count lf]
				return release memory either written < 0 [written][INVALID_IR]
			]
			id: id + 1
		]
		rodata-output: output + rodata-offset
		data-output: output + data-offset
		status: write-global-data view reference-state global-offsets global-sizes
			rodata-output data-output
		if status < 0 [return release memory status]
		id: 1
		while [id <= target-count][
			if reference-state/cursors/id <> reference-state/counts/id [
				return release memory INVALID_IR
			]
			id: id + 1
		]
		release memory total-size
	]
]
