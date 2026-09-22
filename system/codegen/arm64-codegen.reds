Red/System [
	Title: "Typed postfix RSIR to Apple AArch64 code generator"
	File:  %arm64-codegen.reds
]

#include %codegen-diag.reds
#include %arm64-encoder.reds
#include %codegen-rsir-reader.reds
#include %stack-bitmap.reds

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
	bitmap-index    [integer!]
	bitmap-slots    [integer!]
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
	;-- How many integer and vector registers the parameters up to and
	;-- including this one have claimed, so that a variadic call can carry the
	;-- same sequence on into its trailing arguments.
	integer-used   [integer!]
	float-used     [integer!]
]

arm64-reference-state!: alias struct! [
	counts    [int-ptr!]
	starts    [int-ptr!]
	cursors   [int-ptr!]
	references [int-ptr!]
]

arm64-codegen: context [
	IMAGE_HEADER_SIZE:   60
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   28
	IMAGE_IMPORT_SIZE:   28
	IMAGE_EXPORT_SIZE:   12

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
	RSIR_LINE_SIZE:        16
	RSIR_FILE_ENTRY_SIZE:   8

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
	ABI_APPLE_AARCH64: 3
	ABI_AAPCS64:       4
	; The process entry convention of the module being generated. Apple systems
	; arrive through dyld with argc/argv in X0/X1; a Linux entry starts on the
	; kernel stack with argc at [sp].
	target-abi: ABI_APPLE_AARCH64
	compiler-frame-register: arm64-encoder/FP
	compiler-frame-active?: false
	VISIBLE_FRAME_OFFSET: -32
	;-- Slot reserved for the function's stack-pointer bitmap offset. The
	;-- collector reads it at a fixed offset below the frame pointer (see
	;-- scan-stack-refs in runtime/collector.reds). x64 uses frm - 3; AArch64
	;-- already spends that slot on the unwind landing pad, so the bitmap gets
	;-- the slot just below the four the exception frame occupies.
	BITMAP_SLOT_OFFSET: -40
	FRAME_PREFIX_SLOTS: 5

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
	;-- A place whose frame slot holds a materialized address rather than the
	;-- addressed object. Only the deep-stack fallback of an address-of-code
	;-- operand produces it, and OP_REFERENCE is its only consumer.
	LOCATION_SPILL:     5

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
	;-- AAPCS64 and Apple's ARM64 ABI both make v16-v31 plain temporaries:
	;   v0-v7 carry arguments and results, and v8-v15 are the callee-saved
	;   "home" pair above. v31 is kept back as the move scratch, so the
	;   expression stack can own v16-v30. Eight was an arbitrary slice of
	;   them and turned a deep float expression -- create-diamond-pattern
	;   in the GTK backend is one -- into UNSUPPORTED.
	FLOAT_TEMP_REGISTER_COUNT: 15
	FLOAT_SCRATCH_REGISTER: 31

	INVALID_IR:  -1
	UNSUPPORTED: -2
	OUTPUT_FULL: -3
	INTERNAL_ERROR: -4
	RESOURCE_LIMIT: -5
	OUT_OF_MEMORY: -6

	fail-invalid: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail INVALID_IR codegen-diag/FILE_ARM64 site site-name
	]

	fail-unsupported: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail UNSUPPORTED codegen-diag/FILE_ARM64 site site-name
	]

	fail-internal: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail INTERNAL_ERROR codegen-diag/FILE_ARM64 site site-name
	]

	fail-limit: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail RESOURCE_LIMIT codegen-diag/FILE_ARM64 site site-name
	]

	fail-memory: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail OUT_OF_MEMORY codegen-diag/FILE_ARM64 site site-name
	]

	fail-code: func [code site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/propagate code codegen-diag/FILE_ARM64 site site-name
	]

	fail-output: func [required available site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail-values OUTPUT_FULL codegen-diag/FILE_ARM64 site site-name required available
	]

	fail-mismatch: func [required actual site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail-values INTERNAL_ERROR codegen-diag/FILE_ARM64 site site-name required actual
	]

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

	same-reference-category?: func [
		left-kind right-kind [integer!]
		return: [logic!]
	][
		any [
			all [
				any [left-kind = 16 right-kind = 16]
				reference-type-kind? left-kind
				reference-type-kind? right-kind
			]
			all [
				any [left-kind = 12 left-kind = -6]
				any [right-kind = 12 right-kind = -6]
			]
			all [
				left-kind = right-kind
				any [
					left-kind = 13 left-kind = -2 left-kind = -3
					left-kind = -4 left-kind = -7
				]
			]
		]
	]

	reference-type-kind?: func [kind [integer!] return: [logic!]
		/local result [logic!]
	][
		result: any [
			kind = 12 kind = 13 kind = 14 kind = 16
			kind = -2 kind = -3 kind = -4 kind = -6 kind = -7
		]
		result
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
		case [
			all [
				left-kind = right-kind
				any [left-kind = -6 left-kind = -2 left-kind = -3]
			][left]
			;-- Two edges can reach the same place carrying different integer
			;   widths -- `switch` leaves exactly that behind when one arm ends
			;   in a char! literal and the default in an integer!. They still
			;   describe one value: the wider of the two, the same answer a
			;   binary operation gets from integer-kind-widens?. Widening the
			;   merge is safe because every arm has already stored its value
			;   at full register width.
			all [
				left-kind >= 1 left-kind <= 8
				right-kind >= 1 right-kind <= 8
			][
				either integer-kind-widens? right-kind left-kind [left][
					either integer-kind-widens? left-kind right-kind [right][0]
				]
			]
			true [0]
		]
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
			stack-size slot [integer!]
			floating? aggregate? hfa? [logic!]
	][
		if any [parameter-count < 0 ordinal < 0 ordinal > parameter-count][
			return fail-invalid 1 "abi-parameter-location/parameter-count#1"
		]
		location/integer-used: 0
		location/float-used: 0
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
				unless aggregate-ref? ref view [return fail-invalid 2 "abi-parameter-location/aggregate-ref#2"]
				size: 0
				alignment: 0
				unless layout-type ref true view layout 0 :size :alignment [
					return fail-invalid 3 "abi-parameter-location/ref#3"
				]
				if any [size <= 0 alignment <= 0 alignment > 16][return fail-unsupported 4 "abi-parameter-location/alignment#4"]
				hfa?: classify-hfa ref INLINE view 0 :hfa-kind :hfa-count
				register-count: either hfa? [hfa-count][either size <= 16 [(size + 7) / 8][1]]
			]
			unless aggregate? [
				unless any [width = 1 width = 2 width = 4 width = 8][return fail-unsupported 5 "abi-parameter-location/aggregate#5"]
			]
			location/class: 0
			location/register-index: -1
			location/register-count: register-count
			location/stack-offset: -1
			location/copy-offset: -1
			location/size: size
			location/alignment: alignment
			location/hfa-width: either hfa? [either hfa-kind = 9 [4][8]][0]
			;-- AAPCS64 lays the stack arguments out a whole eight-byte slot at
			;-- a time -- the size of each one is rounded up, and the offset is
			;-- aligned to eight or to the argument's own alignment, whichever
			;-- is larger -- the way abi-trailing-argument already does. An
			;-- aggregate's slot holds a rounded-up copy of it, but only `size`
			;-- bytes of that slot are ever written.
			;-- Apple's ARM64 ABI does not round up: it packs each stack
			;-- argument at its own alignment. clang emits `probe8 1 2 3 4 5 6
			;-- 7 8 x y` with x at sp+0 and y at sp+4, and passes a char, a
			;-- short and an int at sp+0, sp+2 and sp+4, where gcc rounds every
			;-- one of those to eight bytes. `checkBigOverflow 1 2 3 4 5 6 7 s3
			;-- 8 42` is the case that shows it: tail at sp+16 and marker at
			;-- sp+20 on Darwin, sp+24 under AAPCS64.
			either target-abi = ABI_AAPCS64 [
				stack-align: either alignment > 8 [alignment][8]
				slot: align size 8
				if slot <= 0 [slot: 8]
			][
				stack-align: alignment
				slot: align size alignment
				if slot <= 0 [slot: alignment]
			]
			case [
				hfa? [
					either float-count <= (8 - hfa-count) [
						location/class: ABI_SIMD
						location/register-index: float-count
						float-count: float-count + hfa-count
					][
						float-count: 8
						offset: align offset stack-align
						if offset < 0 [return fail-limit 818 "abi-parameter-location/limit#1"]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - slot)[return fail-limit 819 "abi-parameter-location/limit#2"]
						offset: offset + slot
					]
				]
				all [aggregate? size > 16][
					if copy-size > (2147483647 - size)[return fail-limit 820 "abi-parameter-location/limit#3"]
					copy-size: align copy-size alignment
					if copy-size < 0 [return fail-limit 821 "abi-parameter-location/limit#4"]
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
						if offset < 0 [return fail-limit 822 "abi-parameter-location/limit#5"]
						location/stack-offset: offset
						if offset > (2147483647 - 8)[return fail-limit 823 "abi-parameter-location/limit#6"]
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
						offset: align offset stack-align
						if offset < 0 [return fail-limit 824 "abi-parameter-location/limit#7"]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - slot)[return fail-limit 825 "abi-parameter-location/limit#8"]
						offset: offset + slot
					]
				]
				floating? [
					either float-count < 8 [
						location/class: ABI_SIMD
						location/register-index: float-count
						float-count: float-count + 1
					][
						offset: align offset stack-align
						if offset < 0 [return fail-limit 826 "abi-parameter-location/limit#9"]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - slot)[return fail-limit 827 "abi-parameter-location/limit#10"]
						offset: offset + slot
					]
				]
				true [
					either integer-count < 8 [
						location/class: ABI_GPR
						location/register-index: integer-count
						integer-count: integer-count + 1
					][
						offset: align offset stack-align
						if offset < 0 [return fail-limit 828 "abi-parameter-location/limit#11"]
						location/class: ABI_STACK
						location/stack-offset: offset
						if offset > (2147483647 - slot)[return fail-limit 829 "abi-parameter-location/limit#12"]
						offset: offset + slot
					]
				]
			]
			if id = ordinal [
				location/integer-used: integer-count
				location/float-used: float-count
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
		if stack-size < 0 [return fail-limit 830 "abi-parameter-location/limit#13"]
		location/stack-size: stack-size
		copy-size: align copy-size 16
		if copy-size < 0 [return fail-limit 831 "abi-parameter-location/limit#14"]
		if stack-size > (2147483647 - copy-size)[return fail-limit 832 "abi-parameter-location/limit#15"]
		location/total-size: stack-size + copy-size
		0
	]

	;-- AAPCS64 hands the trailing arguments of a variadic call to the callee in
	;-- the very same registers a fixed parameter would have taken, so the
	;-- counters the fixed parameters leave behind carry on into them; Apple's
	;-- ARM64 ABI is the one that spills every trailing argument instead. Where
	;-- one lands depends on the ones before it, and the emitter walks arguments
	;-- back to front, so each is resolved by replaying the sequence from the
	;-- first trailing argument.
	abi-trailing-argument: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		argument-origin fixed-count ordinal [integer!]
		integer-used float-used [integer!]
		location [arm64-abi-location!]
		return: [integer!]
		/local id slot ref kind integer-count float-count offset [integer!]
	][
		integer-count: integer-used
		float-count: float-used
		offset: 0
		id: 1
		while [id <= ordinal][
			slot: argument-origin + fixed-count + id
			ref: scratch/stack-types/slot
			kind: type-kind ref view
			;-- C widens a trailing float! to double, and AAPCS64 gives every
			;-- argument, register or not, a whole eight-byte slot.
			either any [kind = 9 kind = 10][
				either float-count < 8 [
					location/class: ABI_SIMD
					location/register-index: float-count
					float-count: float-count + 1
				][
					location/class: ABI_STACK
					location/register-index: -1
					location/stack-offset: offset
					offset: offset + 8
				]
			][
				either integer-count < 8 [
					location/class: ABI_GPR
					location/register-index: integer-count
					integer-count: integer-count + 1
				][
					location/class: ABI_STACK
					location/register-index: -1
					location/stack-offset: offset
					offset: offset + 8
				]
			]
			id: id + 1
		]
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
			kind = -8 [
				size: 0
				alignment: 1
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
		/local target [rsir-global!] imported [rsir-import!]
			kind pointee source [integer!]
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
			initializer/a = IMPORT_ADDRESS [
				;-- An import's address is only known once the loader has run,
				;-- so the slot has to be one the loader can fill: a protected
				;-- global lives in the read-only section, where no dynamic
				;-- relocation may write.
				target: as rsir-global! (view/globals
					+ ((owner - 1) * RSIR_GLOBAL_SIZE))
				if (target/flags and PROTECTED) <> 0 [return false]
				if any [
					initializer/b <= 0
					initializer/b > view/header/import-count
				][return false]
				imported: as rsir-import! (view/imports
					+ ((initializer/b - 1) * RSIR_IMPORT_SIZE))
				if (imported/flags and SYSCALL_FLAG) <> 0 [return false]
				kind: type-kind source view
				any [source = 0 kind = 12 kind = -4 kind = -5 kind = -6]
			]
			true [false]
		]
	]

	;-- Functions, globals and imports share one reference space, in that
	;-- order: an import's slot is already the one its calls are recorded
	;-- against, so a static initializer needs no bookkeeping of its own.
	static-address-target-id: func [
		initializer [rsir-initializer!]
		view [rsir-view!]
		return: [integer!]
	][
		either initializer/a = GLOBAL_ADDRESS [
			view/header/function-count + initializer/b
		][
			either initializer/a = IMPORT_ADDRESS [
				view/header/function-count
					+ view/header/global-count + initializer/b
			][initializer/b]
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
		if target-id <= 0 [return fail-invalid 6 "record-reference/target-id#1"]
		either null? state/references [
			if state/counts/target-id = 2147483647 [return fail-limit 833 "record-reference/limit#1"]
			state/counts/target-id: state/counts/target-id + 1
		][
			if state/cursors/target-id >= state/counts/target-id [return fail-invalid 7 "record-reference/state/cursors#2"]
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
				if target > view/header/function-count [return fail-invalid 8 "resolve-call/view/header#1"]
				callee: as rsir-function! (view/functions
					+ ((target - 1) * RSIR_FUNCTION_SIZE))
				return-ref: callee/return-type
				flags: callee/flags
				first-parameter: callee/first-parameter
				parameter-count: callee/parameter-count
			]
				target < 0 [
				if target < (0 - view/header/import-count)[return fail-invalid 9 "resolve-call/view/header#2"]
				import-id: 0 - target
				imported: as rsir-import! (view/imports
					+ ((import-id - 1) * RSIR_IMPORT_SIZE))
				if imported/flags = 0 [return fail-invalid 10 "resolve-call/imported/flags#3"]
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
				unless valid-type-ref? signature view [return fail-invalid 11 "resolve-call/valid-type-ref#4"]
				base: canonical-type signature view
				if base <= 0 [return fail-invalid 12 "resolve-call/signature#5"]
				shape: as rsir-type! (view/types + ((base - 1) * RSIR_TYPE_SIZE))
				unless shape/kind = -4 [return fail-invalid 13 "resolve-call/view/types#6"]
				if shape/member-count < 0 [return fail-invalid 14 "resolve-call/shape/member-count#7"]
				return-ref: shape/target
				flags: shape/flags
				first-parameter: shape/first-member
				parameter-count: shape/member-count
				parameter-source-out/1: MEMBER_TABLE
			]
		]
		if all [return-ref <> 0 not valid-type-ref? return-ref view][
			return fail-invalid 15 "resolve-call/return-ref#8"
		]
		if flags < 0 [return fail-invalid 16 "resolve-call/flags#9"]
		either (flags and SYSCALL_FLAG) <> 0 [
			unless all [
				target < 0
				(flags and 2047) = (SYSCALL_FLAG or CDECL)
			][return fail-invalid 17 "resolve-call/flags#10"]
		][
			if flags > CALLABLE_FLAGS [return fail-invalid 18 "resolve-call/flags#11"]
		]
		;-- No convention check for a variadic callee: cdecl means real
		;-- varargs and anything else means the trailing arguments are packed
		;-- into a list, and both are lowered here. Which spelling a callee
		;-- carries is decided where it is *declared* -- and a runtime export
		;-- is stamped stdcall, so the import that mirrors it on the other side
		;-- of the dylib is too. The two agree on purpose; under AAPCS64 there
		;-- is one convention either way, so the spelling cannot be wrong.
		unless any [
			target >= 0
			(flags and SYSCALL_FLAG) <> 0
			(flags and 3) = 0
			(flags and 3) = CDECL
			(flags and 3) = STDCALL
		][return fail-unsupported 20 "resolve-call/flags#13"]
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
					][return fail-invalid 21 "prepare-global-data/global-children/target-id#1"]
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
				return fail-invalid 22 "prepare-global-data/global/flags#2"
			]
			inline?: (global/flags and INLINE) <> 0
			kind: type-kind global/type view
			if all [inline? not any [kind = -2 kind = -3 kind = -7]][
				return fail-invalid 23 "prepare-global-data/inline#3"
			]
			global-size: 0
			global-align: 0
			unless layout-type global/type inline? view layout 0
				:global-size :global-align [return fail-invalid 24 "prepare-global-data/global-size#4"]
			if any [global-size <= 0 global-align <= 0][return fail-invalid 25 "prepare-global-data/global-size#5"]
			global-sizes/id: global-size

			base: canonical-type global/type view
			array?: all [inline? base > 0 kind = -7]
			if all [array? global/initializer-count = 0][return fail-invalid 26 "prepare-global-data/global/initializer-count#6"]
			if global/initializer-count > 0 [
				initializer: as rsir-initializer! (view/initializers
					+ (global/first-initializer * RSIR_INITIALIZER_SIZE))
				either array? [
					array-type: as rsir-type! (view/types
						+ ((base - 1) * RSIR_TYPE_SIZE))
					either initializer/kind = BYTES_INITIALIZER [
						;-- A bytes initializer fills the array wholesale, so it
						;   fits any element width. UTF-16 literals are interned
						;   as 16-bit units: that is what gives the global the
						;   2-byte alignment the kernel demands of every
						;   WCHAR* it probes.
						if any [
							global/initializer-count <> 1
							initializer/a < 0 initializer/c <> 0
							all [array-type/flags <> 1 array-type/flags <> 2]
							initializer/b <> (array-type/member-count * array-type/flags)
							(canonical-type array-type/target view)
								<> either array-type/flags = 1 [-2][-4]
						][return fail-invalid 27 "prepare-global-data/view#7"]
					][
						if global/initializer-count <> array-type/member-count [
							return fail-invalid 28 "prepare-global-data/global/initializer-count#8"
						]
						initializer-id: 0
						while [initializer-id < global/initializer-count][
							initializer: as rsir-initializer! (view/initializers
								+ ((global/first-initializer + initializer-id)
									* RSIR_INITIALIZER_SIZE))
							case [
								initializer/kind = SCALAR_INITIALIZER [
									if initializer/c <> 0 [return fail-invalid 29 "prepare-global-data/initializer/c#9"]
								]
								initializer/kind = ADDRESS_INITIALIZER [
									if any [
										array-type/flags <> 8
										not valid-static-address-initializer? initializer
											array-type/target id view
									][return fail-invalid 30 "prepare-global-data/view#10"]
									target-id: static-address-target-id
										initializer view
									status: record-reference target-id 0 references
									if status < 0 [return fail-code status 397 "prepare-global-data/code#1"]
								]
								true [return fail-invalid 31 "prepare-global-data/status#11"]
							]
							initializer-id: initializer-id + 1
						]
					]
				][
					if global/initializer-count <> 1 [return fail-invalid 32 "prepare-global-data/global/initializer-count#12"]
					case [
						initializer/kind = SCALAR_INITIALIZER [
							if any [
								initializer/c <> 0 inline? global-size > 8
							][return fail-invalid 33 "prepare-global-data/initializer/c#13"]
						]
						initializer/kind = ADDRESS_INITIALIZER [
							if any [
								inline? global-size > 8
								not valid-static-address-initializer? initializer
									global/type id view
							][return fail-invalid 34 "prepare-global-data/view#14"]
							;-- A slot the loader has to fill with an address has to
							;-- be as wide as that address: the relocation a 64-bit
							;-- image carries is eight bytes, and on a narrower
							;-- global it would run past the end of the global and
							;-- overwrite the next one. Widen the footprint the
							;-- global occupies -- not its type -- so the
							;-- neighbours survive.
							if global-size < 8 [
								global-size: 8
								global-sizes/id: 8
							]
							target-id: static-address-target-id
									initializer view
								status: record-reference target-id 0 references
								if status < 0 [return fail-code status 398 "prepare-global-data/code#2"]
							]
						true [return fail-invalid 35 "prepare-global-data/status#15"]
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
						:global-offset :global-align [return fail-invalid 36 "prepare-global-data/global-offset#16"]
					either (global/flags and PROTECTED) <> 0 [
						global-offset: align rodata-size global-align
						if any [
							global-offset < 0
							global-offset > (2147483647 - global-size)
						][return fail-limit 834 "prepare-global-data/limit#3"]
						rodata-size: global-offset + global-size
					][
						global-offset: align data-size global-align
						if any [
							global-offset < 0
							global-offset > (2147483647 - global-size)
						][return fail-limit 835 "prepare-global-data/limit#4"]
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
		if placed <> view/header/global-count [return fail-invalid 37 "prepare-global-data/view/header#17"]
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
									return fail-invalid 38 "write-global-data/initializer/a#1"
								]
							]
							initializer/kind = ADDRESS_INITIALIZER [
								target-id: static-address-target-id
									initializer view
								source-offset: global-offsets/id + item-offset
								if source-offset > REFERENCE_OFFSET_MASK [
									return fail-limit 836 "write-global-data/limit#2"
								]
								reference: either (global/flags and PROTECTED) <> 0 [
									RODATA_REFERENCE_TAG or source-offset
								][DATA_REFERENCE_TAG or source-offset]
								status: record-reference target-id reference references
								if status < 0 [return fail-code status 399 "write-global-data/code#1"]
							]
							true [return fail-invalid 39 "write-global-data/status#2"]
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
				if status < 0 [return fail-code status 400 "emit-global-homes/code#1"]
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/page-address at (capacity - written) target
				if encoded < 0 [return fail-code encoded 401 "emit-global-homes/code#2"]
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
			if depths/target <> depth [
				;-- A path may leave a dead statement value behind, so a
				;-- shallower arrival wins and the extras are abandoned.
				if depth > depths/target [return false]
				depths/target: depth
			]
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
						if any [target <= 0 target > fn/instruction-count][return fail-invalid 40 "prepare-subroutine-effects/fn/instruction-count#1"]
						global-target: first + target - 1
						record-effect-use heads links targets global-target global-index
					]
					instruction/op = OP_BINARY [
						if instruction/b > 0 [
							target: instruction/b
							if target >= index [return fail-invalid 41 "prepare-subroutine-effects/instruction/b#2"]
							previous: as rsir-instruction! (view/instructions
								+ ((first + target - 2) * RSIR_INSTRUCTION_SIZE))
							unless previous/op = OP_OVERFLOW [return fail-invalid 42 "prepare-subroutine-effects/previous/op#3"]
							target: previous/a
							if any [target <= index target > fn/instruction-count][
								return fail-invalid 43 "prepare-subroutine-effects/fn/instruction-count#4"
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
						][return fail-invalid 44 "prepare-subroutine-effects/instruction/a#5"]
						global-target: first + instruction/c - 1
						record-effect-use heads links targets global-target global-index
						case-index: 0
						while [case-index < instruction/b][
							switch-id: instruction/a + case-index + 1
							switch-case: as rsir-switch! (view/switches
								+ ((switch-id - 1) * RSIR_SWITCH_SIZE))
							target: switch-case/target
							if any [target <= 0 target > fn/instruction-count][
								return fail-invalid 45 "prepare-subroutine-effects/fn/instruction-count#6"
							]
							global-target: first + target - 1
							record-switch-effect-use heads switch-links switch-users
								global-target global-index switch-id
							case-index: case-index + 1
						]
					]
					instruction/op = OP_SUB_CALL [
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return fail-invalid 46 "prepare-subroutine-effects/fn/instruction-count#7"]
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
							return fail-invalid 47 "prepare-control-targets/fn/instruction-count#1"
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
								return fail-invalid 48 "prepare-control-targets/fn/instruction-count#2"
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
						][return fail-invalid 49 "prepare-control-targets/instruction/c#3"]
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
							][return fail-invalid 50 "prepare-control-targets/fn/instruction-count#4"]
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
			][return fail-invalid 51 "prepare-exception-structure/level#1"]
			case [
				instruction/op = OP_CATCH [
					unless all [
						instruction/a > ordinal
						instruction/a <= fn/instruction-count
						instruction/b = (level + 1)
						instruction/c = 0
					][return fail-invalid 52 "prepare-exception-structure/instruction/c#2"]
					scope: as rsir-instruction! (view/instructions
						+ ((first-instruction + instruction/a - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						scope/op = OP_END_CATCH
						scope/a = ordinal
						scope/b = instruction/b
						scope/c = 0
					][return fail-invalid 53 "prepare-exception-structure/scope/c#3"]
					level: level + 1
					if level > capacity [capacity: level]
				]
				instruction/op = OP_END_CATCH [
					unless all [
						level > 0
						instruction/a > 0 instruction/a < ordinal
						instruction/b = level instruction/c = 0
					][return fail-invalid 54 "prepare-exception-structure/instruction/b#4"]
					scope: as rsir-instruction! (view/instructions
						+ ((first-instruction + instruction/a - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						scope/op = OP_CATCH
						scope/a = ordinal
						scope/b = instruction/b
						scope/c = 0
					][return fail-invalid 55 "prepare-exception-structure/scope/c#5"]
					level: level - 1
				]
				true []
			]
			index: index + 1
		]
		if level <> 0 [return fail-invalid 56 "prepare-exception-structure/level#6"]
		if capacity = 0 [
			plan/unwind: unwind
			plan/catch-capacity: 0
			plan/visible-frame-offset: either unwind = 1 [VISIBLE_FRAME_OFFSET][0]
			plan/frame-prefix-count: FRAME_PREFIX_SLOTS
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
						return fail-invalid 57 "prepare-exception-structure/target-depth#7"
					]
				]
				instruction/op = OP_BRANCH [
					target: instruction/a
					target-depth: catch-depths/target
					unless all [
						target > 0 target <= fn/instruction-count
						(target-depth - level) = 0
					][
						return fail-invalid 58 "prepare-exception-structure/target-depth#8"
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
						return fail-invalid 59 "prepare-exception-structure/target-depth#9"
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
					][return fail-invalid 60 "prepare-exception-structure/target-depth#10"]
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						target-depth: catch-depths/target
						unless all [
							target > 0 target <= fn/instruction-count
							(target-depth - level) = 0
						][return fail-invalid 61 "prepare-exception-structure/target-depth#11"]
						case-index: case-index + 1
					]
				]
				instruction/op = OP_CATCH [
					target: instruction/a
					target-depth: catch-depths/target
					expected-depth: level + 1
					unless (target-depth - expected-depth) = 0 [
						return fail-invalid 62 "prepare-exception-structure/target-depth#12"
					]
				]
				true []
			]
			index: index + 1
		]
		if capacity > ((2147483647 - 4) / 3)[return fail-limit 837 "prepare-exception-structure/limit#1"]
		plan/unwind: unwind
		plan/catch-capacity: capacity
		plan/visible-frame-offset: either unwind = 1 [VISIBLE_FRAME_OFFSET][0]
		plan/frame-prefix-count: FRAME_PREFIX_SLOTS
			+ either unwind = 1 [capacity * 3][0]
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
			next-instruction [rsir-instruction!]
			depths result-offsets [int-ptr!]
			id slot count width kind operation home-count home-mask home-register
			jump-depth
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
			fallthrough? stack-all? frame-anchor? escape? [logic!]
	][
		status: prepare-exception-structure view fn first-instruction unwind?
			scratch plan
		if status < 0 [return fail-code status 402 "plan-function/code#1"]
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
				:inline-size :inline-align [return fail-invalid 63 "plan-function/inline-size#1"]
			kind: 0
			width: 0
			if all [
				not classify-hfa fn/return-type INLINE view 0 :kind :width
				inline-size > 16
			][
				if plan/frame-prefix-count = 2147483647 [return fail-limit 838 "plan-function/limit#8"]
				plan/frame-prefix-count: plan/frame-prefix-count + 1
				plan/hidden-return-offset: 0 - (plan/frame-prefix-count * 8)
			]
		]
		if plan/frame-prefix-count = 2147483647 [return fail-limit 839 "plan-function/limit#9"]
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
			codegen-diag/mark-instruction (id + 1) as int-ptr! instruction
			;-- A stack slot deeper than the temp-register pool has no register
			;-- of its own: it lives in the region spill window. Reserve it
			;-- wherever the expression stack reaches that depth, because any
			;-- operation that runs out of temp registers computes into the
			;-- scratch registers and parks its result in that slot -- codegen
			;-- cannot invent the slot by then. Stated once here it covers
			;-- every operation, not just the ones that happen to be followed
			;-- by a call or a native.
			if all [depth > TEMP_REGISTER_COUNT depth > region-spill][
				region-spill: depth
			]
			if instruction/op = OP_ADDRESS [
				case [
					instruction/a = LOCAL_ADDRESS [
						slot: instruction/b
						if any [slot <= 0 slot > count][return fail-invalid 64 "plan-function/instruction/b#2"]
						parameter: as rsir-parameter! (view/parameters
							+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
						; An address that escapes as a reference (`:local`) must live in
						; memory; a register home has no frame address to hand out.
						escape?: false
						if (id + 1) < fn/instruction-count [
							next-instruction: as rsir-instruction! (view/instructions
								+ ((first-instruction + id + 1) * RSIR_INSTRUCTION_SIZE))
							escape?: next-instruction/op = OP_REFERENCE
						]
						case [
							parameter/flags = 0 [
								either escape? [
									scratch/storage-kinds/slot: STORAGE_FRAME
								][
									if scratch/storage-kinds/slot = 0 [
										scratch/storage-kinds/slot: STORAGE_REGISTER
									]
								]
							]
							; An inline aggregate only ever exists as memory, so
							; its slot goes straight to the frame instead of
							; waiting for a reference to demote it.
							parameter/flags = INLINE [
								scratch/storage-kinds/slot: STORAGE_FRAME
							]
							true [return fail-unsupported 65 "plan-function/scratch/storage-kinds#3"]
						]
					]
					instruction/a = GLOBAL_ADDRESS [
						slot: instruction/b
						if any [
							slot <= 0
							slot > view/header/global-count
							instruction/c <> 0
							scratch/global-homes/slot = 2147483647
						][return fail-invalid 66 "plan-function/scratch/global-homes#4"]
						scratch/global-homes/slot: scratch/global-homes/slot + 1
					]
					instruction/a = FUNCTION_ADDRESS [
						if any [
							instruction/b <= 0
							instruction/b > view/header/function-count
							not valid-type-ref? instruction/c view
							(type-kind instruction/c view) <> -4
						][return fail-invalid 67 "plan-function/instruction/c#5"]
					]
					instruction/a = IMPORT_ADDRESS [
						slot: instruction/b
						if any [slot <= 0 slot > view/header/import-count][
							return fail-invalid 68 "plan-function/view/header#6"
						]
						imported: as rsir-import! (view/imports
							+ ((slot - 1) * RSIR_IMPORT_SIZE))
						;-- A data import (flags = 0) carries no type in c; a
						;-- function import must carry its function type there.
						either imported/flags = 0 [
							if instruction/c <> 0 [return fail-invalid 69 "plan-function/instruction/c#7"]
						][
							unless all [
								valid-type-ref? instruction/c view
								(type-kind instruction/c view) = -4
							][return fail-invalid 70 "plan-function/instruction/c#8"]
						]
					]
					true [return fail-unsupported 71 "plan-function/c#9"]
				]
			]
			ordinal: id + 1
			if instruction/op = OP_ENTRY [
				; An entry is resumed from a BL or from the leading jump, so the
				; expression stack is empty there whichever way control arrives.
				if all [fallthrough? depth <> 0 depth <> 1][
					return fail-invalid 72 "plan-function/fallthrough#10"
				]
				if all [fallthrough? depth = 1][depth: 0]
				depths/ordinal: 0
				fallthrough?: false
			]
			if all [
				instruction/op = OP_SUB_RETURN
				instruction/a = 0
				depth = 1
			][depth: 0]
			;-- A value store can be joined by an edge that never produces the
			;-- value, because that edge ends in a call which does not return
			;-- (an error throw, for instance).  The dead edge must not shrink
			;-- the join, otherwise the store is dropped and its destination
			;-- keeps whatever the register held on entry.
			if all [fallthrough? depths/ordinal > depth][depth: depths/ordinal]
			either fallthrough? [
			if all [depths/ordinal >= 0 depths/ordinal <> depth][
				unless depth < depths/ordinal [
					return fail-invalid 73 "plan-function/depths/ordinal#11"
				]
				;-- The other path leaves a dead value; adopt the
				;-- shallower stack.
				depths/ordinal: depth
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
					if depth = 2147483647 [return fail-limit 840 "plan-function/limit#10"]
					depth: depth + 1
					scratch/stack-low/depth: either all [
						instruction/op = OP_ADDRESS
						instruction/a = LOCAL_ADDRESS
					][instruction/b][0]
				]
				instruction/op = OP_LOAD [
					if depth < 1 [return fail-invalid 74 "plan-function/depth#12"]
					scratch/stack-low/depth: 0
				]
				instruction/op = OP_SIZE [
					unless all [
						valid-type-ref? instruction/a view
						any [instruction/b = 0 instruction/b = 1]
					][return fail-invalid 75 "plan-function/instruction/b#13"]
					either instruction/b = 0 [
						if instruction/c <> 0 [return fail-invalid 76 "plan-function/instruction/c#14"]
						if depth = 2147483647 [return fail-limit 841 "plan-function/limit#11"]
						depth: depth + 1
					][
						if depth < 1 [return fail-invalid 77 "plan-function/depth#15"]
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
						][return fail-invalid 78 "plan-function/instruction/b#16"]
						register-width: 0
						register-id: cpu-register-id
							(view/strings + instruction/b) instruction/c :register-width
						if register-id < 0 [return fail-unsupported 79 "plan-function/register-id#17"]
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
							][return fail-invalid 80 "plan-function/instruction/b#18"]
						][if instruction/b <> 0 [return fail-invalid 81 "plan-function/instruction/b#19"]]
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
							if depth = 2147483647 [return fail-limit 842 "plan-function/limit#12"]
							depth: depth + 1
							scratch/stack-low/depth: 0
						]
						instruction/a = STACK_PUSH_NATIVE [
							if depth < 1 [return fail-invalid 82 "plan-function/depth#20"]
							depth: depth - 1
						]
						instruction/a = STACK_TOP_SET_NATIVE [
							if depth < 1 [return fail-invalid 83 "plan-function/depth#21"]
						]
						instruction/a = STACK_FRAME_SET_NATIVE [
							if depth < 1 [return fail-invalid 84 "plan-function/depth#22"]
							frame-anchor?: true
						]
						any [
							instruction/a = STACK_ALLOCATE_NATIVE
							instruction/a = STACK_ALLOCATE_ZERO_NATIVE
							instruction/a = LOG_B_NATIVE
						][if depth < 1 [return fail-invalid 85 "plan-function/depth#23"]]
						instruction/a = STACK_FREE_NATIVE [
							if depth < 1 [return fail-invalid 86 "plan-function/depth#24"]
							depth: depth - 1
						]
						instruction/a = CPU_REGISTER_SET_NATIVE [
							if depth < 1 [return fail-invalid 87 "plan-function/depth#25"]
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
							if depth < 1 [return fail-invalid 88 "plan-function/depth#26"]
							scratch/stack-low/depth: 0
						]
						instruction/a = ATOMIC_STORE_NATIVE [
							if depth < 2 [return fail-invalid 89 "plan-function/depth#27"]
							depth: depth - 2
						]
						instruction/a = ATOMIC_CAS_NATIVE [
							if depth < 3 [return fail-invalid 90 "plan-function/depth#28"]
							depth: depth - 2
							scratch/stack-low/depth: 0
						]
						instruction/a = ATOMIC_MATH_NATIVE [
							if depth < 2 [return fail-invalid 91 "plan-function/depth#29"]
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
						true [return fail-unsupported 92 "plan-function/has-call#30"]
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
					if depth < 1 [return fail-invalid 93 "plan-function/depth#31"]
					slot: scratch/stack-low/depth
					if slot > 0 [
						scratch/storage-kinds/slot: STORAGE_FRAME
						; Address arithmetic can observe neighboring declarations, so
						; every used storage slot must retain declaration-order layout.
						stack-all?: true
					]
				]
				instruction/op = OP_MEMBER [
					if depth < 1 [return fail-invalid 94 "plan-function/depth#32"]
				]
				instruction/op = OP_TAG [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth >= 1
					][return fail-invalid 95 "plan-function/depth#33"]
					scratch/stack-low/depth: 0
				]
				instruction/op = OP_OVERFLOW [
					unless all [instruction/b = 0 instruction/c = 0][
						return fail-invalid 96 "plan-function/instruction/b#34"
					]
					; The landing pad resumes the scope's own expression stack,
					; whichever tracked operation branched to it.
					if instruction/a <> 0 [
						unless record-plan-depth instruction/a depth fn depths [
							return fail-invalid 97 "plan-function/instruction/a#35"
						]
					]
				]
				instruction/op = OP_INDEX [
					case [
						instruction/b = 0 [
							if depth < 1 [return fail-invalid 98 "plan-function/depth#36"]
						]
						instruction/b = 1 [
							if depth < 2 [return fail-invalid 99 "plan-function/depth#37"]
							depth: depth - 1
						]
						true [return fail-invalid 100 "plan-function/depth#38"]
					]
				]
				instruction/op = OP_SET [
					;-- A no-return call may leave a dead fallthrough path
					;-- whose trailing SET lacks its value slot; the place's
					;-- storage demotion still applies.
					if depth < 1 [return fail-invalid 101 "plan-function/depth#39"]
					depth: depth - 1
				]
				instruction/op = OP_DROP [
					if depth > 0 [depth: depth - 1]
				]
				instruction/op = OP_BINARY [
					if depth < 2 [return fail-invalid 102 "plan-function/depth#40"]
					depth: depth - 1
				]
				instruction/op = OP_CALL [
					argument-count: instruction/b
					if argument-count < 0 [return fail-invalid 103 "plan-function/argument-count#41"]
					; A call through a pointer keeps the callee below its
					; arguments, so it claims one more live slot.
					callee-slots: either instruction/a = 0 [1][0]
					if argument-count > (depth - callee-slots)[return fail-invalid 104 "plan-function/argument-count#42"]
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
					if status < 0 [return fail-code status 403 "plan-function/code#2"]
					if (call-flags and TYPED) <> 0 [
						unless all [
							instruction/c > 0
							(type-kind instruction/c view) = -8
							typed-metadata/member-count = argument-count
							call-parameter-count = 2
						][return fail-invalid 105 "plan-function/call-parameter-count#43"]
						if argument-count > (2147483647 / 24)[return fail-limit 843 "plan-function/limit#13"]
						typed-size: argument-count * 24
						call-outgoing: align typed-size 16
						if call-outgoing < 0 [return fail-limit 844 "plan-function/limit#14"]
						if call-outgoing > outgoing-size [outgoing-size: call-outgoing]
						slot: 1
						while [slot <= argument-count][
							typed-member: as rsir-member! (view/members
								+ ((typed-metadata/first-member + slot - 1)
									* RSIR_MEMBER_SIZE))
							unless all [
								valid-type-ref? typed-member/type view
								typed-runtime-id? typed-member/flags
							][return fail-invalid 106 "plan-function/typed-member/flags#44"]
							slot: slot + 1
						]
					]
					if (call-flags and TYPED) = 0 [
						if any [
							all [
								(call-flags and VARIADIC) = 0
								(call-flags and CUSTOM) = 0
								argument-count <> call-parameter-count
							]
							all [
								(call-flags and VARIADIC) <> 0
								argument-count < call-parameter-count
							]
							all [instruction/a <> 0 instruction/c <> call-return]
						][return fail-invalid 107 "plan-function/instruction/a#45"]
						call-outgoing: 0
						either all [
							(call-flags and VARIADIC) <> 0
							(call-flags and 3) <> CDECL
						][
							if argument-count > (2147483647 / 8)[return fail-limit 845 "plan-function/limit#15"]
							call-outgoing: align (argument-count * 8) 16
						][
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count 0 abi-location
							if status < 0 [return fail-code status 404 "plan-function/code#3"]
							call-outgoing: abi-location/total-size
							if (call-flags and VARIADIC) <> 0 [
								if (argument-count - call-parameter-count)
									> ((2147483647 - call-outgoing) / 8) [
									return fail-limit 846 "plan-function/limit#16"
								]
								call-outgoing: call-outgoing
									+ ((argument-count - call-parameter-count) * 8)
							]
							call-outgoing: align call-outgoing 16
						]
						if call-outgoing < 0 [return fail-limit 847 "plan-function/limit#17"]
						if call-outgoing > outgoing-size [outgoing-size: call-outgoing]
					]
					has-call: 1
					; The spill window still covers the callee slot: it must
					; survive argument setup when it sits in a scratch register.
					if (depth - argument-count) > region-spill [
						region-spill: depth - argument-count
					]
					;-- Argument values built deeper than the temp pool live in
					;-- the region spill window; reserve it up front.
					if all [depth > TEMP_REGISTER_COUNT depth > region-spill] [
						region-spill: depth
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
					][return fail-invalid 108 "plan-function/instruction/a#46"]
					depth: 0
				]
				instruction/op = OP_END_CATCH [0]
				instruction/op = OP_THROW [
					if depth < 2 [return fail-invalid 109 "plan-function/depth#47"]
					depth: 0
					fallthrough?: false
				]
				instruction/op = OP_ENTRY [
					unless all [
						any [instruction/a = 0 instruction/a = 1]
						instruction/c = 0
						any [instruction/b = 0 valid-type-ref? instruction/b view]
					][return fail-invalid 110 "plan-function/instruction/b#48"]
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
					][return fail-invalid 111 "plan-function/instruction/c#49"]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + target - 1) * RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/op = OP_ENTRY
						sub-entry/a = 1
						sub-entry/b = instruction/b
					][return fail-invalid 112 "plan-function/sub-entry/b#50"]
					; The callee shares this frame and may rewrite any local, so
					; the whole live stack is parked before the branch.
					if depth > region-spill [region-spill: depth]
					has-call: 1
					target: first-instruction + instruction/a
					either (scratch/instruction-effects/target and EFFECT_RESUMES) = 0 [
						fallthrough?: false
					][
						if instruction/b <> 0 [
							if depth = 2147483647 [return fail-limit 848 "plan-function/limit#18"]
							depth: depth + 1
							scratch/stack-low/depth: 0
						]
					]
				]
				instruction/op = OP_SUB_RETURN [
					if any [
						region-ordinal = 0
						instruction/b <> 0 instruction/c <> 0
					][return fail-invalid 113 "plan-function/instruction/b#51"]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + region-ordinal - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/a = 1
						sub-entry/b = instruction/a
						either instruction/a = 0 [
							any [depth = 0 depth = 1]
						][depth = 1]
					][return fail-invalid 114 "plan-function/depth#52"]
					depth: 0
					fallthrough?: false
				]
				instruction/op = OP_JUMP [
					unless all [instruction/b = 0 instruction/c >= 0][
						return fail-unsupported 115 "plan-function/instruction/b#53"
					]
					;-- A no-value sub-return tolerates one leftover stack
					;-- slot, so paths arriving with depth 0 or 1 merge here.
					target: instruction/a
					jump-depth: depth
					if all [target > 0 target <= fn/instruction-count][
						sub-entry: as rsir-instruction! (view/instructions
							+ ((first-instruction + target - 1)
								* RSIR_INSTRUCTION_SIZE))
						if all [
							sub-entry/op = OP_SUB_RETURN
							sub-entry/a = 0
							jump-depth = 1
						][jump-depth: 0]
					]
					unless record-plan-depth target jump-depth fn depths [
						return fail-invalid 116 "plan-function/jump-depth#54"
					]
					fallthrough?: false
				]
				instruction/op = OP_BRANCH [
					if any [
						depth < 1 instruction/c <> 0
						not any [instruction/b = 0 instruction/b = 1]
					][return fail-invalid 117 "plan-function/instruction/b#55"]
					depth: depth - 1
					target: instruction/a
					jump-depth: depth
					if all [target > 0 target <= fn/instruction-count][
						sub-entry: as rsir-instruction! (view/instructions
							+ ((first-instruction + target - 1)
								* RSIR_INSTRUCTION_SIZE))
						if all [
							sub-entry/op = OP_SUB_RETURN
							sub-entry/a = 0
							jump-depth = 1
						][jump-depth: 0]
					]
					unless record-plan-depth target jump-depth fn depths [
						return fail-invalid 118 "plan-function/jump-depth#56"
					]
				]
				instruction/op = OP_SWITCH [
					if any [
						depth < 1 instruction/a < 0 instruction/b <= 0
						instruction/b > view/header/switch-count
						instruction/a > (view/header/switch-count - instruction/b)
					][return fail-invalid 119 "plan-function/instruction/a#57"]
					depth: depth - 1
					unless record-plan-depth instruction/c depth fn depths [
						return fail-invalid 120 "plan-function/instruction/c#58"
					]
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						unless record-plan-depth switch-case/target depth fn depths [
							return fail-invalid 121 "plan-function/depth#59"
						]
						case-index: case-index + 1
					]
					fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0 instruction/b = 0 instruction/c = 0
					][return fail-invalid 122 "plan-function/instruction/a#60"]
					fallthrough?: false
				]
				instruction/op = OP_RETURN [
					unless any [
						all [instruction/a = 0 depth = 0]
						all [instruction/a <> 0 depth = 1]
					][return fail-invalid 123 "plan-function/instruction/a#61"]
					depth: 0
					fallthrough?: false
				]
				true []
			]
			id: id + 1
		]
		if fallthrough? [return fail-invalid 124 "plan-function/fallthrough#62"]
		either region-ordinal = 0 [
			if region-spill > max-spill [max-spill: region-spill]
		][
			scratch/entry-spill-limits/region-ordinal: region-spill
		]
		if any [
			all [sub-entry-count > 0 main-entry-count <> 1]
			all [sub-entry-count = 0 main-entry-count <> 0]
		][return fail-invalid 125 "plan-function/sub-entry-count#63"]
		if sub-entry-count > 0 [has-call: 1]
		if frame-anchor? [
			home-register: available-home-register reserved-home-mask home-mask
			if home-register < 0 [return fail-limit 126 "plan-function/home-register-limit"]
			mask: 1 << (home-register - FIRST_HOME_REGISTER)
			reserved-home-mask: reserved-home-mask or mask
			home-mask: home-mask or mask
			home-count: home-count + 1
			plan/frame-anchor-register: home-register
		]
		;-- A value the allocator keeps in a home (callee-saved) register
		;-- survives an ordinary call, but not a `throw` this function catches:
		;-- the throw longjmps straight to the landing pad, skipping the
		;-- epilogues of the frames it unwinds, so those callee-saved registers
		;-- are left holding the unwound frames' values. The landing pad restores
		;-- only the expression stack, not home registers, so any value live
		;-- across the catch must be frame-homed -- persistent frame memory
		;-- survives the SP restore. Functions whose frame anchor is a home
		;-- register (they move SP through stack intrinsics) are excluded: their
		;-- catch record is addressed through that register, so they need the
		;-- separate anchor-preservation path, not this demotion.
		if all [plan/catch-capacity > 0 not frame-anchor?][stack-all?: true]
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
				if parameter/flags <> 0 [return fail-unsupported 127 "plan-function/parameter/flags#65"]
				kind: 0
				if parameter/type <> 0 [
					width: value-width parameter/type view
					kind: type-kind parameter/type view
					if width = 0 [return fail-invalid 128 "plan-function/view#66"]
					if width > 8 [return fail-unsupported 129 "plan-function#67"]
				]
				if id <= fn/parameter-count [
					status: abi-parameter-location view layout PARAMETER_TABLE
						fn/first-parameter fn/parameter-count id abi-location
					if status < 0 [return fail-code status 405 "plan-function/code#4"]
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
						:inline-size :inline-align [return fail-invalid 130 "plan-function/inline-size#68"]
					if any [inline-size <= 0 inline-align > 16][return fail-unsupported 131 "plan-function/inline-size#69"]
					if id <= fn/parameter-count [
						status: abi-parameter-location view layout PARAMETER_TABLE
							fn/first-parameter fn/parameter-count id abi-location
						if status < 0 [return fail-code status 406 "plan-function/code#5"]
					]
					slot: (inline-size + 7) / 8
					if frame-home-count > (2147483647 - slot)[return fail-limit 849 "plan-function/limit#19"]
					frame-home-count: frame-home-count + slot
				][
					width: value-width parameter/type view
					kind: type-kind parameter/type view
					if width = 0 [return fail-invalid 132 "plan-function/view#70"]
					if width > 8 [return fail-unsupported 133 "plan-function#71"]
					if id <= fn/parameter-count [
						status: abi-parameter-location view layout PARAMETER_TABLE
							fn/first-parameter fn/parameter-count id abi-location
						if status < 0 [return fail-code status 407 "plan-function/code#6"]
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
		if plan/frame-prefix-count > (2147483647 - home-count)[return fail-limit 850 "plan-function/limit#20"]
		total-slots: plan/frame-prefix-count + home-count
		if total-slots > (2147483647 - float-home-count)[return fail-limit 851 "plan-function/limit#21"]
		total-slots: total-slots + float-home-count
		if total-slots > (2147483647 - frame-home-count)[return fail-limit 852 "plan-function/limit#22"]
		total-slots: total-slots + frame-home-count
		plan/bitmap-slots: total-slots - 4
		if total-slots > (2147483647 - max-spill)[return fail-limit 853 "plan-function/limit#23"]
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
						return fail-limit 854 "plan-function/limit#24"
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
		if total-slots > (2147483647 / 8) [return fail-limit 855 "plan-function/limit#25"]
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
				if status < 0 [return fail-code status 408 "plan-function/code#7"]
				if (call-flags and RETURN_VALUE) <> 0 [
					unless aggregate-ref? call-return view [return fail-invalid 134 "plan-function/aggregate-ref#72"]
					result-size: 0
					result-align: 0
					unless layout-type call-return true view layout 0
						:result-size :result-align [return fail-invalid 135 "plan-function/result-size#73"]
					if any [result-size <= 0 result-align <= 0 result-align > 16][
						return fail-unsupported 136 "plan-function/result-size#74"
					]
					if result-used > (2147483647 - result-size)[return fail-limit 856 "plan-function/limit#26"]
					result-used: align (result-used + result-size) 16
					if result-used < 0 [return fail-limit 857 "plan-function/limit#27"]
					result-offsets/id: 0 - result-used
				]
			]
			id: id + 1
		]
		frame-allocation: result-used
		if frame-allocation > (2147483647 - outgoing-size)[return fail-limit 858 "plan-function/limit#28"]
		frame-allocation: align (frame-allocation + outgoing-size) 16
		if frame-allocation < 0 [return fail-limit 859 "plan-function/limit#29"]
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
			if plan/frame-anchor-offset = 0 [return fail-invalid 137 "plan-function/plan/frame-anchor-offset#75"]
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
		if written < 0 [return fail-code written 409 "emit-frame-normalize/code#1"]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP plan/frame-anchor-register 8
		if encoded < 0 [return fail-code encoded 410 "emit-frame-normalize/code#2"]
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
		if written < 0 [return fail-code written 411 "emit-visible-frame-restore/code#1"]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP arm64-encoder/X16 8
		if encoded < 0 [return fail-code encoded 412 "emit-visible-frame-restore/code#2"]
		written + encoded
	]

	mark-bitmap-type: func [
		record [int-ptr!] ref [integer!] inline? [logic!]
		displacement depth [integer!] view [rsir-view!] layout [arm64-layout-state!]
		return: [logic!]
		/local kind index offset [integer!] type [rsir-type!]
			member [rsir-member!] offsets [int-ptr!]
	][
		if depth > view/header/type-count [return false]
		ref: canonical-type ref view
		kind: type-kind ref view
		if all [inline? any [kind = -2 kind = -3 kind = -7]][
			type: as rsir-type! (view/types + ((ref - 1) * RSIR_TYPE_SIZE))
			index: 0
			while [index < type/member-count][
				either kind = -7 [
					unless mark-bitmap-type record type/target false
						(displacement + (index * type/flags)) (depth + 1) view layout [return false]
				][
					member: as rsir-member! (view/members
						+ ((type/first-member + index) * RSIR_MEMBER_SIZE))
					offsets: layout/member-offsets + type/first-member + index
					offset: offsets/value
					if offset < 0 [return false]
					unless mark-bitmap-type record member/type (member/flags = INLINE)
						(displacement + offset) (depth + 1) view layout [return false]
				]
				index: index + 1
			]
			return true
		]
		if any [kind = 12 kind = 13 kind = 16
			kind = -2 kind = -3 kind = -4 kind = -5 kind = -6 kind = -7][
			if (displacement // 8) <> 0 [return false]
			return stack-bitmap/mark record (((0 - displacement) / 8) - 5)
		]
		true
	]

	write-frame-bitmap: func [
		record [int-ptr!] view [rsir-view!] layout [arm64-layout-state!]
		fn [rsir-function!] scratch [arm64-function-scratch!] plan [arm64-function-plan!]
		return: [logic!]
		/local index [integer!] parameter [rsir-parameter!]
	][
		stack-bitmap/initialize record plan/bitmap-slots
		; Saved GPRs belong to the caller, whose types are unknown here.
		index: 1
		while [index <= plan/home-count][
			unless stack-bitmap/mark record (plan/frame-prefix-count + index - 5) [return false]
			index: index + 1
		]
		index: 1
		while [index <= (fn/parameter-count + fn/local-count)][
			if scratch/storage-kinds/index = STORAGE_FRAME [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
				unless mark-bitmap-type record parameter/type (parameter/flags = INLINE)
					scratch/homes/index 0 view layout [return false]
			]
			index: index + 1
		]
		true
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
		if written < 0 [return fail-code written 413 "emit-prologue/code#1"]
		if plan/hidden-return-offset <> 0 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-store at (capacity - written)
				arm64-encoder/X8 plan/hidden-return-offset 8
			if encoded < 0 [return fail-code encoded 414 "emit-prologue/code#2"]
			written: written + encoded
		]
		;-- Publish a stack-pointer bitmap offset where the collector looks for
		;-- one (scan-stack-refs in runtime/collector.reds). The slot has to
		;-- hold a bitmap-sized index whatever the table contains, because the
		;-- collector adds it to bitarrays-base unchecked; leaving the frame
		;-- slot untouched makes it read a stray value and walk off the table.
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-immediate at (capacity - written)
			arm64-encoder/X16 4 plan/bitmap-index 0
		if encoded < 0 [return fail-code encoded 415 "emit-prologue/code#3"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/register-store at (capacity - written)
			arm64-encoder/X16 arm64-encoder/FP BITMAP_SLOT_OFFSET 8
			arm64-encoder/X17
		if encoded < 0 [return fail-code encoded 416 "emit-prologue/code#4"]
		written: written + encoded
		plan/unwind-fixup: -1
		if plan/unwind = 1 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-store at (capacity - written)
				arm64-encoder/FP plan/visible-frame-offset 8
			if encoded < 0 [return fail-code encoded 417 "emit-prologue/code#5"]
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
			if encoded < 0 [return fail-code encoded 418 "emit-prologue/code#6"]
			written: written + encoded
			unless entry? [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-store at (capacity - written)
					arm64-encoder/X16 arm64-encoder/FP -24 8 arm64-encoder/X17
				if encoded < 0 [return fail-code encoded 419 "emit-prologue/code#7"]
				written: written + encoded
			]
			case [
				entry? [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/address-relative at (capacity - written)
						arm64-encoder/X16 16
					if encoded < 0 [return fail-code encoded 420 "emit-prologue/code#8"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/move-immediate at (capacity - written)
						arm64-encoder/X17 4 -1 0
					if encoded < 0 [return fail-code encoded 421 "emit-prologue/code#9"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/FP -16
					if encoded < 0 [return fail-code encoded 422 "emit-prologue/code#10"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at (capacity - written) 8
					if encoded < 0 [return fail-code encoded 423 "emit-prologue/code#11"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/trap at (capacity - written)
					if encoded < 0 [return fail-code encoded 424 "emit-prologue/code#12"]
					written: written + encoded
				]
				(fn/flags and CATCH_FLAG) <> 0 [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/move-immediate at (capacity - written)
						arm64-encoder/X17 4 -2 0
					if encoded < 0 [return fail-code encoded 425 "emit-prologue/code#13"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/ZR arm64-encoder/X17 arm64-encoder/FP -16
					if encoded < 0 [return fail-code encoded 426 "emit-prologue/code#14"]
					written: written + encoded
				]
				true [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/store-pair at (capacity - written)
						arm64-encoder/ZR arm64-encoder/ZR arm64-encoder/FP -16
					if encoded < 0 [return fail-code encoded 427 "emit-prologue/code#15"]
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
				if encoded < 0 [return fail-code encoded 428 "emit-prologue/code#16"]
				written: written + encoded
			]
			index: index + 1
		]
		if saved-count <> plan/home-count [return fail-invalid 138 "emit-prologue/plan/home-count#1"]
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				plan/frame-anchor-register arm64-encoder/FP 8
			if encoded < 0 [return fail-code encoded 429 "emit-prologue/code#17"]
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
			if encoded < 0 [return fail-code encoded 430 "emit-prologue/code#18"]
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
				if status < 0 [return fail-code status 431 "emit-prologue/code#19"]
				width: value-width parameter/type view
				kind: type-kind parameter/type view
				if parameter/flags = INLINE [
					if target > 0 [return fail-invalid 139 "emit-prologue/parameter/flags#2"]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/address-offset at (capacity - written)
						arm64-encoder/X14 compiler-frame-register target arm64-encoder/X16
					if encoded < 0 [return fail-code encoded 432 "emit-prologue/code#20"]
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
								if encoded < 0 [return fail-code encoded 433 "emit-prologue/code#21"]
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
								if encoded < 0 [return fail-code encoded 434 "emit-prologue/code#22"]
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
							if encoded < 0 [return fail-code encoded 435 "emit-prologue/code#23"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 abi-location/size
							if encoded < 0 [return fail-code encoded 436 "emit-prologue/code#24"]
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
							if encoded < 0 [return fail-code encoded 437 "emit-prologue/code#25"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 abi-location/size
							if encoded < 0 [return fail-code encoded 438 "emit-prologue/code#26"]
							written: written + encoded
						]
						true [return fail-invalid 140 "emit-prologue/written#3"]
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
							if encoded < 0 [return fail-code encoded 439 "emit-prologue/code#27"]
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
					true [return fail-invalid 141 "emit-prologue/arm64-encoder#4"]
				]
				if encoded < 0 [return fail-code encoded 440 "emit-prologue/code#28"]
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
			if encoded < 0 [return fail-code encoded 441 "emit-home-restore/code#1"]
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
					if encoded < 0 [return fail-code encoded 442 "emit-home-restore/code#2"]
					written: written + encoded
				]
			]
			index: index + 1
		]
		if saved-count <> plan/home-count [return fail-invalid 142 "emit-home-restore/plan/home-count#1"]
		if plan/frame-anchor-register <> arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: compiler-frame-load at (capacity - written)
				plan/frame-anchor-register plan/frame-anchor-offset 8 0 8
			if encoded < 0 [return fail-code encoded 443 "emit-home-restore/code#3"]
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
			if encoded < 0 [return fail-code encoded 444 "emit-epilogue/code#1"]
			written: written + encoded
		]
		compiler-frame-active?: true
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-home-restore plan at (capacity - written)
		if encoded < 0 [return fail-code encoded 445 "emit-epilogue/code#2"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-leave at (capacity - written)
		if encoded < 0 [return fail-code encoded 446 "emit-epilogue/code#3"]
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
			if encoded < 0 [return fail-code encoded 447 "emit-unwind-handler/code#1"]
			written: written + encoded
		]
		compiler-frame-active?: true
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-home-restore plan at (capacity - written)
		if encoded < 0 [return fail-code encoded 448 "emit-unwind-handler/code#2"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/unwind-frame at (capacity - written)
		if encoded < 0 [return fail-code encoded 449 "emit-unwind-handler/code#3"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X3
		if encoded < 0 [return fail-code encoded 450 "emit-unwind-handler/code#4"]
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
		if scratch/stack-kinds/stack-slot <> VALUE [return fail-invalid 143 "materialize/scratch/stack-kinds#1"]
		source-ref: scratch/stack-types/stack-slot
		source-width: value-width source-ref view
		target-width: value-width target-ref view
		if any [
			source-width = 0 source-width > 8
			target-width = 0 target-width > 8
		][return fail-unsupported 144 "materialize/target-width#2"]
		source-kind: type-kind source-ref view
		target-kind: type-kind target-ref view
		if any [
			source-kind = 9 source-kind = 10
			target-kind = 9 target-kind = 10
		][
			unless all [
				any [source-kind = 9 source-kind = 10]
				any [target-kind = 9 target-kind = 10]
			][return fail-unsupported 145 "materialize/target-kind#3"]
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
					if encoded < 0 [return fail-code encoded 451 "materialize/code#1"]
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
				true [return fail-invalid 146 "materialize/scratch/stack-low#4"]
			]
			if encoded < 0 [return fail-code encoded 452 "materialize/code#2"]
			written: written + encoded
			if source-width <> target-width [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/float-convert at (capacity - written)
					target target source-width target-width
				if encoded < 0 [return fail-code encoded 453 "materialize/code#3"]
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
			true [fail-internal 860 "materialize/invalid-location"]
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
		if written < 0 [return fail-code written 454 "emit-stack-resize/code#1"]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/add-immediate at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X16 1 8
		if encoded < 0 [return fail-code encoded 455 "emit-stack-resize/code#2"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/logical-immediate at (capacity - written)
			arm64-encoder/OP_AND arm64-encoder/X16 arm64-encoder/X16 8 -2 -1
		if encoded < 0 [return fail-code encoded 456 "emit-stack-resize/code#3"]
		written: written + encoded
		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X17 arm64-encoder/X16 8
			if encoded < 0 [return fail-code encoded 457 "emit-stack-resize/code#4"]
			written: written + encoded
		]
		operation: either allocate? [arm64-encoder/OP_SUB][arm64-encoder/OP_ADD]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/add-extended-register at (capacity - written)
			operation
			arm64-encoder/SP arm64-encoder/SP arm64-encoder/X16 8 0 3
		if encoded < 0 [return fail-code encoded 458 "emit-stack-resize/code#5"]
		written: written + encoded
		if allocate? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				result-register arm64-encoder/SP 8
			if encoded < 0 [return fail-code encoded 459 "emit-stack-resize/code#6"]
			written: written + encoded
		]
		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X16 arm64-encoder/SP 8
			if encoded < 0 [return fail-code encoded 460 "emit-stack-resize/code#7"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/branch-zero at (capacity - written)
				arm64-encoder/X17 8 16 false
			if encoded < 0 [return fail-code encoded 461 "emit-stack-resize/code#8"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store-post at (capacity - written)
				arm64-encoder/ZR arm64-encoder/X16 8 8
			if encoded < 0 [return fail-code encoded 462 "emit-stack-resize/code#9"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-immediate at (capacity - written)
				arm64-encoder/X17 arm64-encoder/X17 -1 8
			if encoded < 0 [return fail-code encoded 463 "emit-stack-resize/code#10"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/branch-zero at (capacity - written)
				arm64-encoder/X17 8 -8 true
			if encoded < 0 [return fail-code encoded 464 "emit-stack-resize/code#11"]
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
			if depths/target <> depth [
				;-- Dead statement values from deeper paths are abandoned:
				;-- the join keeps the shallower recorded depth, and this
				;-- path's extra slots are simply not part of the merge.
				either depth > depths/target [
					depth: depths/target
				][
					depths/target: depth
				]
			]
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

	;-- Control flow carries no register map across an edge, only a depth and a
	;-- type per slot, so every live slot has to sit where the target will look
	;-- for it: its canonical temp register, or -- once the stack outruns the
	;-- pool -- the slot the region reserves for that depth.
	canonicalize-stack: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth region-base region-limit [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			slot ref kind target limit width displacement written encoded [integer!]
			floating? [logic!]
	][
		written: 0
		slot: 1
		while [slot <= depth][
			if scratch/stack-kinds/slot <> VALUE [return fail-unsupported 147 "canonicalize-stack/scratch/stack-kinds#1"]
			ref: scratch/stack-types/slot
			kind: type-kind ref view
			floating?: any [kind = 9 kind = 10]
			target: either floating? [
				FIRST_FLOAT_TEMP_REGISTER + slot - 1
			][FIRST_TEMP_REGISTER + slot - 1]
			limit: either floating? [
				FIRST_FLOAT_TEMP_REGISTER + FLOAT_TEMP_REGISTER_COUNT
			][FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT]
			either target < limit [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: materialize view scratch slot target ref at (capacity - written)
				if encoded < 0 [return fail-code encoded 465 "canonicalize-stack/code#1"]
				written: written + encoded
				scratch/stack-locations/slot: LOCATION_REGISTER
				scratch/stack-low/slot: target
				scratch/stack-high/slot: 0
			][
				width: value-width ref view
				unless any [width = 1 width = 2 width = 4 width = 8][
					return fail-unsupported 394 "canonicalize-stack#2"
				]
				if (region-base + slot) > region-limit [
					return fail-internal 395 "canonicalize-stack/spill-plan"
				]
				target: either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: materialize view scratch slot target ref at (capacity - written)
				if encoded < 0 [return fail-code encoded 466 "canonicalize-stack/code#2"]
				written: written + encoded
				displacement: 0 - ((region-base + slot) * 8)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: either floating? [
					compiler-float-frame-store at (capacity - written)
						target displacement width
				][
					compiler-frame-store at (capacity - written)
						target displacement width
				]
				if encoded < 0 [return fail-code encoded 467 "canonicalize-stack/code#3"]
				written: written + encoded
				scratch/stack-locations/slot: LOCATION_FRAME
				scratch/stack-low/slot: displacement
				scratch/stack-high/slot: 0
			]
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
			slot ref width target displacement written encoded [integer!]
			floating? [logic!]
	][
		if (region-base + depth) > region-limit [return fail-internal 149 "spill-live-stack/spill-plan"]
		written: 0
		slot: 1
		while [slot <= depth][
			if any [
				scratch/stack-locations/slot = LOCATION_FLAGS
				scratch/stack-locations/slot = LOCATION_REGISTER
			][
				;-- Only a value can be parked. A place holds an address, and
				;-- LOCATION_FRAME on a place means "the addressed object lives
				;-- here", not "the address is stored here", so parking one
				;-- would silently retarget every member, load and store below
				;-- it. Nothing in the language leaves a place live across a
				;-- push-all anyway: the native consumes no operand, so it
				;-- cannot appear inside a path or an argument list, which is
				;-- the only place a place is ever live. Say so rather than
				;-- emit code that lies.
				if scratch/stack-kinds/slot <> VALUE [
					return fail-unsupported 396 "spill-live-stack/place#2"
				]
				ref: scratch/stack-types/slot
				width: value-width ref view
				unless any [width = 1 width = 2 width = 4 width = 8][
					return fail-unsupported 151 "spill-live-stack#3"
				]
				floating?: float-type? ref view
				target: either scratch/stack-locations/slot = LOCATION_REGISTER [
					scratch/stack-low/slot
				][either floating? [FLOAT_SCRATCH_REGISTER][arm64-encoder/X17]]
				if scratch/stack-locations/slot = LOCATION_FLAGS [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch slot target ref
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 468 "spill-live-stack/code#1"]
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
				if encoded < 0 [return fail-code encoded 469 "spill-live-stack/code#2"]
				written: written + encoded
				scratch/stack-locations/slot: LOCATION_FRAME
				scratch/stack-low/slot: displacement
				scratch/stack-high/slot: 0
			]
			slot: slot + 1
		]
		written
	]

			;-- Free a temp register by parking one live value in its frame slot. Only a
			;-- plain value can move: a place holds an address, and the frame tag of a
			;-- place means "the object lives here" rather than "the address is stored
			;-- here", so parking one would change what the slot denotes.
			;-- Returns the bytes written, or zero when nothing could be parked --
			;-- the caller then decides whether it can do without a register.
			spill-value-register: func [
				view [rsir-view!]
				scratch [arm64-function-scratch!]
				depth region-base region-limit [integer!]
				at [byte-ptr!]
				capacity [integer!]
				return: [integer!]
				/local slot ref width displacement encoded [integer!]
			][
				slot: depth - 1
				while [slot >= 1][
					if all [
						scratch/stack-kinds/slot = VALUE
						scratch/stack-locations/slot = LOCATION_REGISTER
						scratch/stack-high/slot = 0
						scratch/stack-low/slot >= FIRST_TEMP_REGISTER
						scratch/stack-low/slot < (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
						not float-type? scratch/stack-types/slot view
					][
						ref: scratch/stack-types/slot
						width: value-width ref view
						unless any [width = 1 width = 2 width = 4 width = 8][
							return fail-invalid 152 "spill-value-register#1"
						]
						if (region-base + slot) > region-limit [
							return fail-invalid 153 "spill-value-register/region-base#2"
						]
						displacement: 0 - ((region-base + slot) * 8)
						encoded: compiler-frame-store at capacity
							scratch/stack-low/slot displacement width
						if encoded < 0 [return fail-code encoded 470 "spill-value-register/code#1"]
						scratch/stack-locations/slot: LOCATION_FRAME
						scratch/stack-low/slot: displacement
						return encoded
					]
					slot: slot - 1
				]
				0
			]

			;-- Allocate a temp register, parking one live value in its frame
			;-- slot first when the pool is full. Operations whose result has
			;-- no frame home of its own -- a place, or an index -- need one,
			;-- and every slot below keeps working once it is frame-backed.
			;-- Returns the bytes written; out-register carries -1 when even
			;-- that could not free one, so the caller names its own site.
			take-temp-register: func [
				view [rsir-view!]
				scratch [arm64-function-scratch!]
				depth [integer!]
				floating? [logic!]
				reusable-slot region-base region-limit [integer!]
				at [byte-ptr!]
				capacity [integer!]
				out-register [int-ptr!]
				return: [integer!]
				/local written [integer!]
			][
				out-register/value: available-temp-register view scratch
					depth floating? reusable-slot
				if out-register/value >= 0 [return 0]
				written: spill-value-register view scratch depth
					region-base region-limit at capacity
				if written < 0 [return fail-code written 471 "take-temp-register/code#1"]
				out-register/value: available-temp-register view scratch
					depth floating? reusable-slot
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
				if encoded < 0 [return fail-code encoded 472 "emit-stack-all/code#1"]
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
				if encoded < 0 [return fail-code encoded 473 "emit-stack-all/code#2"]
				written: written + encoded
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/write-system-register at
					(capacity - written) system-register arm64-encoder/X16
				if encoded < 0 [return fail-code encoded 474 "emit-stack-all/code#3"]
				written: written + encoded
				system-register: system-register + 1
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-load at (capacity - written)
				arm64-encoder/LR arm64-encoder/SP 240 8 0 8 arm64-encoder/X16
			if encoded < 0 [return fail-code encoded 475 "emit-stack-all/code#4"]
			written: written + encoded
			register: 0
			while [register < 30][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/load-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP (register * 8)
				if encoded < 0 [return fail-code encoded 476 "emit-stack-all/code#5"]
				written: written + encoded
				register: register + 2
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/add-immediate at (capacity - written)
				arm64-encoder/SP arm64-encoder/SP STACK_ALL_SIZE 8
			if encoded < 0 [return fail-code encoded 477 "emit-stack-all/code#6"]
			written: written + encoded
		][
			encoded: arm64-encoder/stack-subtract code capacity STACK_ALL_SIZE
			if encoded < 0 [return fail-code encoded 478 "emit-stack-all/code#7"]
			written: written + encoded
			register: 0
			while [register < 30][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/store-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP (register * 8)
				if encoded < 0 [return fail-code encoded 479 "emit-stack-all/code#8"]
				written: written + encoded
				register: register + 2
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				arm64-encoder/LR arm64-encoder/SP 240 8 arm64-encoder/X16
			if encoded < 0 [return fail-code encoded 480 "emit-stack-all/code#9"]
			written: written + encoded
			system-register: arm64-encoder/SYSTEM_NZCV
			while [system-register <= arm64-encoder/SYSTEM_FPSR][
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/read-system-register at
					(capacity - written) arm64-encoder/X16 system-register
				if encoded < 0 [return fail-code encoded 481 "emit-stack-all/code#10"]
				written: written + encoded
				offset: 240 + (system-register * 8)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/register-store at (capacity - written)
					arm64-encoder/X16 arm64-encoder/SP offset 8 arm64-encoder/X17
				if encoded < 0 [return fail-code encoded 482 "emit-stack-all/code#11"]
				written: written + encoded
				system-register: system-register + 1
			]
			register: 0
			while [register < 32][
				offset: 272 + (register * 16)
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/store-vector-pair at (capacity - written)
					register (register + 1) arm64-encoder/SP offset
				if encoded < 0 [return fail-code encoded 483 "emit-stack-all/code#12"]
				written: written + encoded
				register: register + 2
			]
		]
		written
	]

	restore-control-stack: func [
		view [rsir-view!]
		scratch [arm64-function-scratch!]
		depth target region-base region-limit [integer!]
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
			either register < limit [
				scratch/stack-locations/slot: LOCATION_REGISTER
				scratch/stack-low/slot: register
			][
				;-- Past the pool the canonical home is the slot the region
				;-- reserves for this depth, which canonicalize-stack filled.
				if (region-base + slot) > region-limit [return false]
				scratch/stack-locations/slot: LOCATION_FRAME
				scratch/stack-low/slot: 0 - ((region-base + slot) * 8)
			]
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
		if level <= 0 [return fail-invalid 154 "emit-catch-open/level#1"]
		record-slot: FRAME_PREFIX_SLOTS + 1 + ((level - 1) * 3)
		pair-displacement: 0 - ((record-slot + 1) * 8)
		written: arm64-encoder/address-offset code capacity arm64-encoder/X2
			compiler-frame-register pair-displacement arm64-encoder/X16
		if written < 0 [return fail-code written 484 "emit-catch-open/code#1"]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/load-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 compiler-frame-register -16
		if encoded < 0 [return fail-code encoded 485 "emit-catch-open/code#2"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/X2 0
		if encoded < 0 [return fail-code encoded 486 "emit-catch-open/code#3"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/X16 arm64-encoder/SP 8
		if encoded < 0 [return fail-code encoded 487 "emit-catch-open/code#4"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/register-store at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X2 -8 8 arm64-encoder/X17
		if encoded < 0 [return fail-code encoded 488 "emit-catch-open/code#5"]
		written: written + encoded
		displacement: either null? code [0][
			target-offset - (current-offset + written)
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/address-relative at (capacity - written)
			arm64-encoder/X16 displacement
		if encoded < 0 [return fail-code encoded 489 "emit-catch-open/code#6"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X3 compiler-frame-register -16
		if encoded < 0 [return fail-code encoded 490 "emit-catch-open/code#7"]
		written + encoded
	]

	emit-catch-restore: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity level [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			record-slot pair-displacement written encoded [integer!]
	][
		if level <= 0 [return fail-invalid 155 "emit-catch-restore/level#1"]
		record-slot: FRAME_PREFIX_SLOTS + 1 + ((level - 1) * 3)
		pair-displacement: 0 - ((record-slot + 1) * 8)
		written: arm64-encoder/address-offset code capacity arm64-encoder/X2
			compiler-frame-register pair-displacement arm64-encoder/X16
		if written < 0 [return fail-code written 491 "emit-catch-restore/code#1"]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/load-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 arm64-encoder/X2 0
		if encoded < 0 [return fail-code encoded 492 "emit-catch-restore/code#2"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/store-pair at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X17 compiler-frame-register -16
		if encoded < 0 [return fail-code encoded 493 "emit-catch-restore/code#3"]
		written: written + encoded
		;-- Restore the CPU stack pointer only for a C-stack function, whose
		;-- expression stack rides SP. There SP = FP - frame-allocation exactly
		;-- (frame-enter is `mov x29,sp; sub sp,#frame-allocation`), so the frame
		;-- base recovers it -- and it must be recomputed, since the throw
		;-- landing arrives with SP pointing into an unwound inner frame.
		;--
		;-- A frame-anchor function is different: it keeps its Red values on a
		;-- SEPARATE stack addressed through the pinned anchor register, while
		;-- its CPU SP stays fixed at the frame it entered with (only outgoing
		;-- call args ride it). Both the throw unwind and a normal catch exit
		;-- already leave that fixed SP in place, so it needs no restore here.
		;-- Worse, touching it corrupts it: the anchor is on the other stack (so
		;-- `anchor - frame-allocation` is a wrong-stack, mis-aligned address),
		;-- and the record's saved-SP slot lives on the volatile anchor stack
		;-- where later value pushes overwrite it. So leave SP alone unless the
		;-- frame base is FP.
		if plan/frame-anchor-register = arm64-encoder/FP [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/address-offset at (capacity - written)
				arm64-encoder/X16 compiler-frame-register
				(0 - plan/frame-allocation) arm64-encoder/X17
			if encoded < 0 [return fail-code encoded 494 "emit-catch-restore/code#4"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/SP arm64-encoder/X16 8
			if encoded < 0 [return fail-code encoded 495 "emit-catch-restore/code#5"]
			written: written + encoded
		]
		written
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
		if encoded < 0 [return fail-code encoded 496 "emit-throw-unwind/code#1"]
		written: written + encoded
		if skip-current? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/frame-load at (capacity - written)
				arm64-encoder/X2 -24 8 0 8
			if encoded < 0 [return fail-code encoded 497 "emit-throw-unwind/code#2"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/jump-register at (capacity - written)
				arm64-encoder/X2
			if encoded < 0 [return fail-code encoded 498 "emit-throw-unwind/code#3"]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X1 -8 4 0 4
		if encoded < 0 [return fail-code encoded 499 "emit-throw-unwind/code#4"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/compare-register at (capacity - written)
			arm64-encoder/X1 arm64-encoder/X0 4
		if encoded < 0 [return fail-code encoded 500 "emit-throw-unwind/code#5"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/branch-condition at (capacity - written)
			arm64-encoder/CS 12
		if encoded < 0 [return fail-code encoded 501 "emit-throw-unwind/code#6"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X2 -24 8 0 8
		if encoded < 0 [return fail-code encoded 502 "emit-throw-unwind/code#7"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X2
		if encoded < 0 [return fail-code encoded 503 "emit-throw-unwind/code#8"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X1 -16 8 0 8
		if encoded < 0 [return fail-code encoded 504 "emit-throw-unwind/code#9"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/branch-zero at (capacity - written)
			arm64-encoder/X1 8 8 true
		if encoded < 0 [return fail-code encoded 505 "emit-throw-unwind/code#10"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/X1 arm64-encoder/LR 8
		if encoded < 0 [return fail-code encoded 506 "emit-throw-unwind/code#11"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-load at (capacity - written)
			arm64-encoder/X2 VISIBLE_FRAME_OFFSET 8 0 8
		if encoded < 0 [return fail-code encoded 507 "emit-throw-unwind/code#12"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-register at (capacity - written)
			arm64-encoder/FP arm64-encoder/X2 8
		if encoded < 0 [return fail-code encoded 508 "emit-throw-unwind/code#13"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/jump-register at (capacity - written)
			arm64-encoder/X1
		if encoded < 0 [return fail-code encoded 509 "emit-throw-unwind/code#14"]
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
			if encoded < 0 [return fail-code encoded 510 "emit-tracked-multiply/code#1"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-extended-register at
				(capacity - written) target target 8 4 signed
			if encoded < 0 [return fail-code encoded 511 "emit-tracked-multiply/code#2"]
			return written + encoded
		]
		; A 64-bit product needs both operands twice over, and only X16 and X17
		; are free once the result claims a register of its own.
		if any [
			left = arm64-encoder/X17 right = arm64-encoder/X16
			target = arm64-encoder/X16 target = arm64-encoder/X17
		][return fail-unsupported 156 "emit-tracked-multiply/arm64-encoder#1"]
		if left <> arm64-encoder/X16 [
			encoded: arm64-encoder/move-register code capacity
				arm64-encoder/X16 left 8
			if encoded < 0 [return fail-code encoded 512 "emit-tracked-multiply/code#3"]
			written: written + encoded
		]
		if right <> arm64-encoder/X17 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X17 right 8
			if encoded < 0 [return fail-code encoded 513 "emit-tracked-multiply/code#4"]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-register at (capacity - written)
			target arm64-encoder/X16 arm64-encoder/X17 8
		if encoded < 0 [return fail-code encoded 514 "emit-tracked-multiply/code#5"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-high at (capacity - written)
			arm64-encoder/X16 arm64-encoder/X16 arm64-encoder/X17 signed
		if encoded < 0 [return fail-code encoded 515 "emit-tracked-multiply/code#6"]
		written: written + encoded
		either signed = 1 [
			; Every bit the upper half keeps has to repeat the result's sign.
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/shift-immediate at (capacity - written)
				arm64-encoder/SHIFT_ARITHMETIC arm64-encoder/X17 target 63 8
			if encoded < 0 [return fail-code encoded 516 "emit-tracked-multiply/code#7"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-register at (capacity - written)
				arm64-encoder/X16 arm64-encoder/X17 8
		][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/compare-immediate at (capacity - written)
				arm64-encoder/X16 0 8
		]
		if encoded < 0 [return fail-code encoded 517 "emit-tracked-multiply/code#8"]
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
			return fail-invalid 157 "emit-pointer-binary/operation#1"
		]
		left-ref: scratch/stack-types/left-slot
		right-ref: scratch/stack-types/right-slot
		if address-type? right-ref view [
			;-- Two addresses combine as a raw 64-bit distance or
			;-- rebase (x64 parity); neither side is scaled.
			written: 0
			;-- A register-backed right operand may occupy the result target.
			;-- Save it before materializing the left operand over that register.
			if scratch/stack-locations/right-slot <> LOCATION_IMMEDIATE [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: materialize view scratch right-slot arm64-encoder/X17 right-ref
					at (capacity - written)
				if encoded < 0 [return fail-code encoded 518 "emit-pointer-binary/code#1"]
				written: written + encoded
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch left-slot target left-ref
				at (capacity - written)
			if encoded < 0 [return fail-code encoded 519 "emit-pointer-binary/code#2"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: either operation = ADD_OPERATION [
				arm64-encoder/add-register at (capacity - written)
					target target arm64-encoder/X17 8
			][
				arm64-encoder/subtract-register at (capacity - written)
					target target arm64-encoder/X17 8
			]
			if encoded < 0 [return fail-code encoded 520 "emit-pointer-binary/code#3"]
			return written + encoded
		]
		stride: pointer-stride left-ref view layout
		if stride <= 0 [return fail-unsupported 158 "emit-pointer-binary/stride#2"]
		written: 0
		; A register-backed right operand may occupy the result target. Save it
		; before materializing the left operand over that register.
		if scratch/stack-locations/right-slot <> LOCATION_IMMEDIATE [
			source-width: value-width right-ref view
			unless any [
				source-width = 1 source-width = 2
				source-width = 4 source-width = 8
			][return fail-unsupported 159 "emit-pointer-binary/source-width#3"]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: materialize view scratch right-slot arm64-encoder/X17 right-ref
				at (capacity - written)
			if encoded < 0 [return fail-code encoded 521 "emit-pointer-binary/code#4"]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: materialize view scratch left-slot target left-ref
			at (capacity - written)
		if encoded < 0 [return fail-code encoded 522 "emit-pointer-binary/code#5"]
		written: written + encoded
		if scratch/stack-locations/right-slot = LOCATION_IMMEDIATE [
			high: either scratch/stack-low/right-slot < 0 [-1][0]
			if scratch/stack-high/right-slot <> high [return fail-unsupported 160 "emit-pointer-binary/scratch/stack-high#4"]
			either scratch/stack-low/right-slot < 0 [
				limit: 80000000h / stride
				if scratch/stack-low/right-slot < limit [
					return fail-unsupported 161 "emit-pointer-binary/scratch/stack-low#5"
				]
			][
				limit: 7FFFFFFFh / stride
				if scratch/stack-low/right-slot > limit [
					return fail-unsupported 162 "emit-pointer-binary/scratch/stack-low#6"
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
			if encoded < 0 [return fail-code encoded 523 "emit-pointer-binary/code#6"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: either operation = ADD_OPERATION [
				arm64-encoder/add-register at (capacity - written)
					target target arm64-encoder/X17 8
			][
				arm64-encoder/subtract-register at (capacity - written)
					target target arm64-encoder/X17 8
			]
			if encoded < 0 [return fail-code encoded 524 "emit-pointer-binary/code#7"]
			return written + encoded
		]

		source-width: value-width right-ref view
		unless any [
			source-width = 1 source-width = 2
			source-width = 4 source-width = 8
		][return fail-unsupported 163 "emit-pointer-binary/source-width#7"]
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
			if encoded < 0 [return fail-code encoded 525 "emit-pointer-binary/code#8"]
			return written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/extend-register at (capacity - written)
			right right source-width source-signed
		if encoded < 0 [return fail-code encoded 526 "emit-pointer-binary/code#9"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/move-immediate at (capacity - written)
			arm64-encoder/X16 8 stride 0
		if encoded < 0 [return fail-code encoded 527 "emit-pointer-binary/code#10"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/multiply-register at (capacity - written)
			right right arm64-encoder/X16 8
		if encoded < 0 [return fail-code encoded 528 "emit-pointer-binary/code#11"]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: either operation = ADD_OPERATION [
			arm64-encoder/add-register at (capacity - written) target target right 8
		][
			arm64-encoder/subtract-register at (capacity - written) target target right 8
		]
		if encoded < 0 [return fail-code encoded 529 "emit-pointer-binary/code#12"]
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
			source = arm64-encoder/X16 source = arm64-encoder/X17][return fail-invalid 164 "emit-aggregate-chunk-load/source#1"]
		written: 0
		encoded: arm64-encoder/move-immediate code capacity target 8 0 0
		if encoded < 0 [return fail-code encoded 530 "emit-aggregate-chunk-load/code#1"]
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
			if encoded < 0 [return fail-code encoded 531 "emit-aggregate-chunk-load/code#2"]
			written: written + encoded
			shift: part-offset * 8
			if shift > 0 [
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/shift-immediate at (capacity - written)
					arm64-encoder/SHIFT_LEFT arm64-encoder/X16 arm64-encoder/X16 shift 8
				if encoded < 0 [return fail-code encoded 532 "emit-aggregate-chunk-load/code#3"]
				written: written + encoded
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/alu-register at (capacity - written)
				arm64-encoder/OP_OR target target arm64-encoder/X16 8 false
			if encoded < 0 [return fail-code encoded 533 "emit-aggregate-chunk-load/code#4"]
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
		][return fail-invalid 165 "emit-aggregate-chunk-store/destination#1"]
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
				if encoded < 0 [return fail-code encoded 534 "emit-aggregate-chunk-store/code#1"]
				written: written + encoded
				target: arm64-encoder/X17
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				target destination (offset + part-offset) part-width arm64-encoder/X16
			if encoded < 0 [return fail-code encoded 535 "emit-aggregate-chunk-store/code#2"]
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
		][return fail-invalid 166 "emit-memory-copy/destination#1"]
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
			if encoded < 0 [return fail-code encoded 536 "emit-memory-copy/code#1"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/register-store at (capacity - written)
				arm64-encoder/X16 destination offset width arm64-encoder/X17
			if encoded < 0 [return fail-code encoded 537 "emit-memory-copy/code#2"]
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
				chunk-offset chunk-size named-integers named-floats
				trap-number-register trap-immediate
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
				custom-call?
					reference-comparison? floating? region-link? tracked? right-ready?
					syscall? atomic-old? atomic-overflow? packed-call?
						aggregate-return? hfa-return? aggregate-copy? adopt-depth? [logic!]
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
		written: 0
		; A Linux entry starts on the kernel stack (argc at [sp]); preserve the
		; raw stack pointer before the frame moves SP. Apple's dyld hands the
		; arguments over in X0/X1 after the prologue instead.
		if all [startup? target-abi = ABI_AAPCS64] [
			at: either null? code [as byte-ptr! 0][code]
			encoded: arm64-encoder/move-register at capacity
				arm64-encoder/X19 arm64-encoder/SP 8
			if encoded < 0 [return fail-code encoded 538 "compile-function/code#1"]
			written: encoded
		]
		encoded: emit-prologue view fn entry? layout scratch plan
			(either null? code [as byte-ptr! 0][code + written]) (capacity - written)
		if encoded < 0 [return fail-code encoded 539 "compile-function/code#2"]
		written: written + encoded
		compiler-frame-active?: true
		; Keep the unwind landing pad beside its prologue ADR. A function body
		; can exceed ADR's signed 21-bit reach; its size must not affect this
		; address. The normal path skips the pad with one local branch.
		if all [plan/unwind = 1 not entry?] [
			if plan/unwind-fixup < 0 [return fail-invalid 389 "compile-function/plan/unwind-fixup#223"]
			encoded: emit-unwind-handler plan null 0
			if encoded < 0 [return fail-code encoded 540 "compile-function/code#3"]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/branch-relative at (capacity - written) (encoded + 4)
			if encoded < 0 [return fail-code encoded 541 "compile-function/code#4"]
			written: written + encoded
			handler-offset: written
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: emit-unwind-handler plan at (capacity - written)
			if encoded < 0 [return fail-code encoded 542 "compile-function/code#5"]
			written: written + encoded
			unless measure? [
				displacement: handler-offset - plan/unwind-fixup
				at: code + plan/unwind-fixup
				encoded: arm64-encoder/address-relative at
					(capacity - plan/unwind-fixup) arm64-encoder/X16 displacement
				if encoded <> 4 [return fail-mismatch 4 encoded 543 "compile-function/instruction-size"]
			]
		]
		if all [startup? target-abi = ABI_APPLE_AARCH64] [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X19 arm64-encoder/X0 8
			if encoded < 0 [return fail-code encoded 544 "compile-function/code#6"]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/move-register at (capacity - written)
				arm64-encoder/X20 arm64-encoder/X1 8
			if encoded < 0 [return fail-code encoded 545 "compile-function/code#7"]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-global-homes view scratch (function-base + written)
			references at (capacity - written)
		if encoded < 0 [return fail-code encoded 546 "compile-function/code#8"]
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
				instruction: as rsir-instruction! (view/instructions
					+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
				codegen-diag/mark-instruction ordinal as int-ptr! instruction
				if instruction/op = OP_ENTRY [
				; An entry is resumed from a BL or from the leading jump, so the
				; expression stack is empty there whichever way control arrives.
				if all [fallthrough? depth <> 0 depth <> 1][return fail-invalid 167 "compile-function/fallthrough#1"]
				if all [fallthrough? depth = 1][depth: 0]
				instruction-depths/ordinal: 0
				fallthrough?: false
			]
				if all [
					instruction/op = OP_SUB_RETURN
					instruction/a = 0
					depth = 1
				][depth: 0]
			;-- Mirrors the planning pass: a store joined by an edge that never
			;-- produces its value (that edge ends in a call which does not
			;-- return) must keep the depth the live edges recorded, or the
			;-- store is skipped and the destination keeps a stale register.
			adopt-depth?: all [fallthrough? instruction-depths/ordinal > depth]
			either fallthrough? [
				if control-uses/ordinal > 0 [
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						region-base region-limit at (capacity - written)
					if encoded < 0 [return fail-code encoded 547 "compile-function/code#9"]
					written: written + encoded
				]
				unless adopt-depth? [
					unless merge-control-target ordinal depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return fail-invalid 168 "compile-function/instruction-depths#2"
					]
				]
				if adopt-depth? [depth: instruction-depths/ordinal]
				if control-uses/ordinal > 0 [
					unless restore-control-stack view scratch depth ordinal
						region-base region-limit entry-types entry-kinds entry-flags [return fail-unsupported 169 "compile-function/entry-types#3"]
				]
			][
				if instruction-depths/ordinal < 0 [
					instruction-offsets/ordinal: written
					index: index + 1
					continue
				]
				depth: instruction-depths/ordinal
				unless restore-control-stack view scratch depth ordinal
					region-base region-limit entry-types entry-kinds entry-flags [return fail-unsupported 170 "compile-function/entry-types#4"]
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
			][return fail-unsupported 171 "compile-function/instruction/op#5"]
			case [
				instruction/op = OP_LITERAL [
					width: value-width instruction/a view
					kind: type-kind instruction/a view
					if width = 0 [return fail-invalid 172 "compile-function/instruction/a#6"]
					if width > 8 [return fail-unsupported 173 "compile-function/a#7"]
					depth: depth + 1
					scratch/stack-types/depth: instruction/a
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_IMMEDIATE
					scratch/stack-low/depth: instruction/b
					scratch/stack-high/depth: instruction/c
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_CAST [
					if depth = 0 [
						;-- Dead fallthrough after a no-return call: nothing
						;-- to cast, emit nothing.
						index: index + 1
						continue
					]
					unless all [
						depth > 0 scratch/stack-kinds/depth = VALUE
						valid-type-ref? instruction/a view
						instruction/b = 0
						any [instruction/c = 0 instruction/c = 1]
					][return fail-invalid 174 "compile-function/instruction/c#8"]
					ref: scratch/stack-types/depth
					target-ref: instruction/a
					unless scalar-cast-compatible? ref target-ref view [return fail-unsupported 175 "compile-function/scalar-cast-compatible#9"]
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
							return fail-unsupported 176 "compile-function#10"
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth target ref
							at (capacity - written)
						if encoded < 0 [return fail-code encoded 548 "compile-function/code#10"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 8
						if encoded < 0 [return fail-code encoded 549 "compile-function/code#11"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/condition-result at
							(capacity - written) target arm64-encoder/NE
						if encoded < 0 [return fail-code encoded 550 "compile-function/code#12"]
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
							][return fail-invalid 177 "compile-function/source-kind#11"]
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
							][return fail-invalid 178 "compile-function/target-kind#12"]
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
						][return fail-unsupported 179 "compile-function/target-kind#13"]
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
								if encoded < 0 [return fail-code encoded 551 "compile-function/code#13"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-move-from-register at
									(capacity - written) target arm64-encoder/X16 4
							]
							instruction/c = 1 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth
									FLOAT_SCRATCH_REGISTER ref at (capacity - written)
								if encoded < 0 [return fail-code encoded 552 "compile-function/code#14"]
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
								if encoded < 0 [return fail-code encoded 553 "compile-function/code#15"]
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
								if encoded < 0 [return fail-code encoded 554 "compile-function/code#16"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-to-integer at
									(capacity - written) target FLOAT_SCRATCH_REGISTER
									source-width 4 1
							]
						]
						if encoded < 0 [return fail-code encoded 555 "compile-function/code#17"]
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
									load-signed :folded [return fail-invalid 180 "compile-function/load-signed#14"]
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
					;-- A frame-backed slot can retag in place when the cast
					;-- narrows: a later read of the target width sees exactly
					;-- the truncated low bytes of the stored value.
					if all [
						integer-type? ref view integer-type? target-ref view
						scratch/stack-locations/depth = LOCATION_FRAME
						target-width <= source-width
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
						return fail-unsupported 181 "compile-function#15"
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 556 "compile-function/code#18"]
					written: written + encoded
					if target-kind = 11 [
						width: either source-width = 8 [8][4]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 width
						if encoded < 0 [return fail-code encoded 557 "compile-function/code#19"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/condition-result at
							(capacity - written) target 1
						if encoded < 0 [return fail-code encoded 558 "compile-function/code#20"]
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
						if encoded < 0 [return fail-code encoded 559 "compile-function/code#21"]
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
					][return fail-invalid 182 "compile-function/instruction/b#16"]
					either instruction/b = 0 [
						if instruction/c <> 0 [return fail-invalid 183 "compile-function/instruction/c#17"]
						if depth = 2147483647 [return fail-limit 861 "compile-function/limit#269"]
						depth: depth + 1
					][
						unless all [
							depth > 0
							scratch/stack-kinds/depth = VALUE
							scratch/stack-types/depth = ref
							scratch/stack-flags/depth = instruction/c
						][return fail-invalid 184 "compile-function/scratch/stack-flags#18"]
					]
					width: logical-size ref view layout
					if width <= 0 [return fail-invalid 185 "compile-function/ref#19"]
					kind: type-kind ref view
					either all [instruction/b = 1 kind = 13][
						target: FIRST_TEMP_REGISTER + depth - 1
						if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
							return fail-unsupported 186 "compile-function#20"
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth arm64-encoder/X16 ref
							at (capacity - written)
						if encoded < 0 [return fail-code encoded 560 "compile-function/code#22"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/c-string-size at (capacity - written)
							arm64-encoder/X16 target arm64-encoder/X17
						if encoded < 0 [return fail-code encoded 561 "compile-function/code#23"]
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
						][return fail-invalid 187 "compile-function/instruction/b#21"]
						register-width: 0
						register-id: cpu-register-id
							(view/strings + instruction/b) instruction/c :register-width
						if register-id < 0 [return fail-unsupported 188 "compile-function/register-id#22"]
						if cpu-pointer-ref = 0 [
							cpu-pointer-ref: integer-pointer-type view
						]
						if cpu-pointer-ref = 0 [return fail-invalid 189 "compile-function/cpu-pointer-ref#23"]
					][
						either instruction/a = ATOMIC_MATH_NATIVE [
							operation: instruction/b and 7
							unless all [
								operation >= 1 operation <= 5
								any [
									instruction/b = operation
									instruction/b = (operation + ATOMIC_OLD)
								]
							][return fail-invalid 190 "compile-function/instruction/b#24"]
						][if instruction/b <> 0 [return fail-invalid 191 "compile-function/instruction/b#25"]]
					]
					case [
						instruction/a = STACK_TOP_NATIVE [
							unless pointer-to-canonical? instruction/c -5 view [
								return fail-invalid 192 "compile-function/instruction/c#26"
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 193 "compile-function#27"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/SP 8
							if encoded < 0 [return fail-code encoded 562 "compile-function/code#24"]
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
							][return fail-invalid 194 "compile-function/scratch/stack-flags#28"]
							ref: scratch/stack-types/depth
							width: value-width ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return fail-unsupported 195 "compile-function#29"
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
							if encoded < 0 [return fail-code encoded 563 "compile-function/code#25"]
							written: written + encoded
							if any [kind = 9 kind = 10][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/float-move-to-register at
									(capacity - written) arm64-encoder/X16
									FLOAT_SCRATCH_REGISTER width
								if encoded < 0 [return fail-code encoded 564 "compile-function/code#26"]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/SP arm64-encoder/SP -8 8
							if encoded < 0 [return fail-code encoded 565 "compile-function/code#27"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X17 arm64-encoder/SP 8
							if encoded < 0 [return fail-code encoded 566 "compile-function/code#28"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/X17 0 8 arm64-encoder/X9
							if encoded < 0 [return fail-code encoded 567 "compile-function/code#29"]
							written: written + encoded
							depth: depth - 1
						]
						instruction/a = STACK_POP_NATIVE [
							if instruction/c <> 0 [return fail-invalid 196 "compile-function/instruction/c#30"]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 197 "compile-function#31"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X16 arm64-encoder/SP 8
							if encoded < 0 [return fail-code encoded 568 "compile-function/code#30"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-load at (capacity - written)
								target arm64-encoder/X16 0 8 0 8 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 569 "compile-function/code#31"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/SP arm64-encoder/SP 8 8
							if encoded < 0 [return fail-code encoded 570 "compile-function/code#32"]
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
								return fail-invalid 198 "compile-function/instruction/c#32"
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 199 "compile-function#33"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/FP 8
							if encoded < 0 [return fail-code encoded 571 "compile-function/code#33"]
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
							][return fail-invalid 200 "compile-function/scratch/stack-types#34"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X16
								instruction/c at (capacity - written)
							if encoded < 0 [return fail-code encoded 572 "compile-function/code#34"]
							written: written + encoded
							target: either instruction/a = STACK_TOP_SET_NATIVE [
								arm64-encoder/SP
							][arm64-encoder/FP]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written)
								target arm64-encoder/X16 8
							if encoded < 0 [return fail-code encoded 573 "compile-function/code#35"]
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
								return fail-invalid 201 "compile-function/instruction/c#35"
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 202 "compile-function#36"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) target arm64-encoder/SP 8
							if encoded < 0 [return fail-code encoded 574 "compile-function/code#36"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/logical-immediate at
								(capacity - written) arm64-encoder/OP_AND
								arm64-encoder/X16 target 8 -16 -1
							if encoded < 0 [return fail-code encoded 575 "compile-function/code#37"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) arm64-encoder/SP arm64-encoder/X16 8
							if encoded < 0 [return fail-code encoded 576 "compile-function/code#38"]
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
							][return fail-invalid 203 "compile-function/scratch/stack-types#37"]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 204 "compile-function#38"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-resize view scratch depth target true
								(instruction/a = STACK_ALLOCATE_ZERO_NATIVE)
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 577 "compile-function/code#39"]
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
							][return fail-invalid 205 "compile-function/scratch/stack-types#39"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-resize view scratch depth 0 false false
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 578 "compile-function/code#40"]
							written: written + encoded
							depth: depth - 1
						]
						any [
							instruction/a = STACK_PUSH_ALL_NATIVE
							instruction/a = STACK_POP_ALL_NATIVE
						][
							if instruction/c <> 0 [return fail-invalid 206 "compile-function/instruction/c#40"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: spill-live-stack view scratch depth
								region-base region-limit at (capacity - written)
							if encoded < 0 [return fail-code encoded 579 "compile-function/code#41"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-stack-all at (capacity - written)
								(instruction/a = STACK_POP_ALL_NATIVE)
							if encoded < 0 [return fail-code encoded 580 "compile-function/code#42"]
							written: written + encoded
							if instruction/a = STACK_POP_ALL_NATIVE [
								last-math-condition: -1
							]
						]
						instruction/a = PROGRAM_COUNTER_NATIVE [
							unless pointer-to-canonical? instruction/c -2 view [
								return fail-invalid 207 "compile-function/instruction/c#41"
							]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 208 "compile-function#42"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/program-counter at
								(capacity - written) target
							if encoded < 0 [return fail-code encoded 581 "compile-function/code#43"]
							written: written + encoded
							scratch/stack-types/depth: instruction/c
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = CPU_REGISTER_NATIVE [
							if depth = 2147483647 [return fail-limit 862 "compile-function/limit#270"]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 209 "compile-function#43"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either register-width = 4 [
								arm64-encoder/extend-register at (capacity - written)
									target register-id 4 0
							][
								arm64-encoder/move-register at (capacity - written)
									target register-id 8
							]
							if encoded < 0 [return fail-code encoded 582 "compile-function/code#44"]
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
							][return fail-invalid 210 "compile-function/scratch/stack-types#44"]
							; Explicit writes may alias a live volatile expression
							; register. Preserve only the values actually at risk.
							slot: 1
							while [slot < depth][
								if all [
									scratch/stack-locations/slot = LOCATION_REGISTER
									scratch/stack-low/slot = register-id
									not float-type? scratch/stack-types/slot view
								][
									if scratch/stack-kinds/slot <> VALUE [return fail-unsupported 211 "compile-function/scratch/stack-kinds#45"]
									width: value-width scratch/stack-types/slot view
									unless any [width = 1 width = 2 width = 4 width = 8][
										return fail-unsupported 212 "compile-function#46"
									]
									if (region-base + slot) > region-limit [return fail-invalid 213 "compile-function/region-base#47"]
									displacement: 0 - ((region-base + slot) * 8)
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-store at
										(capacity - written) register-id displacement width
									if encoded < 0 [return fail-code encoded 583 "compile-function/code#45"]
									written: written + encoded
									scratch/stack-locations/slot: LOCATION_FRAME
									scratch/stack-low/slot: displacement
									scratch/stack-high/slot: 0
								]
								slot: slot + 1
							]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 214 "compile-function#48"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target cpu-pointer-ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 584 "compile-function/code#46"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either all [register-width = 4 register-id = target][
								arm64-encoder/extend-register at (capacity - written)
									register-id register-id 4 0
							][
								arm64-encoder/move-register at (capacity - written)
									register-id target register-width
							]
							if encoded < 0 [return fail-code encoded 585 "compile-function/code#47"]
							written: written + encoded
							scratch/stack-types/depth: cpu-pointer-ref
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = CPU_OVERFLOW_NATIVE [
							if instruction/c <> -11 [return fail-invalid 215 "compile-function/instruction/c#49"]
							depth: depth + 1
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 216 "compile-function#50"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either last-math-condition >= 0 [
								arm64-encoder/condition-result at (capacity - written)
									target last-math-condition
							][
								arm64-encoder/move-immediate at (capacity - written)
									target 4 0 0
							]
							if encoded < 0 [return fail-code encoded 586 "compile-function/code#48"]
							written: written + encoded
							scratch/stack-types/depth: -11
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						instruction/a = ATOMIC_FENCE_NATIVE [
							if instruction/c <> 0 [return fail-invalid 217 "compile-function/instruction/c#51"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/memory-fence at (capacity - written)
							if encoded < 0 [return fail-code encoded 587 "compile-function/code#49"]
							written: written + encoded
						]
						instruction/a = ATOMIC_LOAD_NATIVE [
							unless all [
								instruction/c = -5 depth > 0
								scratch/stack-kinds/depth = VALUE
								scratch/stack-flags/depth = 0
								pointer-to-canonical? scratch/stack-types/depth -5 view
							][return fail-invalid 218 "compile-function/scratch/stack-types#52"]
							ref: scratch/stack-types/depth
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 219 "compile-function#53"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 588 "compile-function/code#50"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-load at (capacity - written)
								target target
							if encoded < 0 [return fail-code encoded 589 "compile-function/code#51"]
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
							][return fail-invalid 220 "compile-function/scratch/stack-types#54"]
							ref: scratch/stack-types/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 590 "compile-function/code#52"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17 -5
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 591 "compile-function/code#53"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/atomic-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 592 "compile-function/code#54"]
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
							][return fail-invalid 221 "compile-function/scratch/stack-types#55"]
							target: FIRST_TEMP_REGISTER + target-slot - 1
							right: FIRST_TEMP_REGISTER + depth - 1
							if any [
								target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
								right >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)
							][return fail-unsupported 222 "compile-function/right#56"]
							ref: scratch/stack-types/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 593 "compile-function/code#55"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot target -5
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 594 "compile-function/code#56"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth right -5
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 595 "compile-function/code#57"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at (capacity - written)
								arm64-encoder/X17 target 4
							if encoded < 0 [return fail-code encoded 596 "compile-function/code#58"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either target-abi = ABI_APPLE_AARCH64 [
								arm64-encoder/atomic-compare-exchange at
									(capacity - written) target right arm64-encoder/X16
							][
								arm64-encoder/atomic-compare-exchange-exclusive at
									(capacity - written) target right arm64-encoder/X16
									(FIRST_TEMP_REGISTER + source-slot - 1)
							]
							if encoded < 0 [return fail-code encoded 597 "compile-function/code#59"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-register at (capacity - written)
								target arm64-encoder/X17 4
							if encoded < 0 [return fail-code encoded 598 "compile-function/code#60"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/condition-result at
								(capacity - written) target arm64-encoder/EQ
							if encoded < 0 [return fail-code encoded 599 "compile-function/code#61"]
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
							][return fail-invalid 223 "compile-function/scratch/stack-types#57"]
							target: FIRST_TEMP_REGISTER + target-slot - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 224 "compile-function#58"
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
							if encoded < 0 [return fail-code encoded 600 "compile-function/code#62"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17 -5
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 601 "compile-function/code#63"]
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
								if encoded < 0 [return fail-code encoded 602 "compile-function/code#64"]
								written: written + encoded
							]
							opcode: case [
								operation <= 2 [arm64-encoder/OP_ADD]
								operation = 3 [arm64-encoder/OP_OR]
								operation = 4 [arm64-encoder/OP_XOR]
								true [arm64-encoder/OP_AND]
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: either target-abi = ABI_APPLE_AARCH64 [
								arm64-encoder/atomic-rmw at (capacity - written)
									opcode arm64-encoder/X17 target arm64-encoder/X16
							][
								; X0/X1 are outside the expression stack and home registers.
								arm64-encoder/atomic-rmw-exclusive at (capacity - written)
									opcode arm64-encoder/X17 target arm64-encoder/X16
									arm64-encoder/X0 arm64-encoder/X1
							]
							if encoded < 0 [return fail-code encoded 603 "compile-function/code#65"]
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
									if encoded < 0 [return fail-code encoded 604 "compile-function/code#66"]
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
								if encoded < 0 [return fail-code encoded 605 "compile-function/code#67"]
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
							][return fail-invalid 225 "compile-function/scratch/stack-types#59"]
							ref: scratch/stack-types/depth
							width: value-width ref view
							width: either width = 8 [8][4]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								;-- Deep-stack fallback: compute into the fixed
								;-- scratch register and park the result in the
								;-- region spill slot for this depth.
								if (region-base + depth) > region-limit [
									return fail-invalid 226 "compile-function/region-base#60"
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth
									arm64-encoder/X17 ref at (capacity - written)
								if encoded < 0 [return fail-code encoded 606 "compile-function/code#68"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/count-leading-zeros at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X17 width
								if encoded < 0 [return fail-code encoded 607 "compile-function/code#69"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/move-immediate at
									(capacity - written) arm64-encoder/X16 width
									((width * 8) - 1) 0
								if encoded < 0 [return fail-code encoded 608 "compile-function/code#70"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/subtract-register at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X16 arm64-encoder/X17 width
								if encoded < 0 [return fail-code encoded 609 "compile-function/code#71"]
								written: written + encoded
								displacement: 0 - ((region-base + depth) * 8)
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: compiler-frame-store at
									(capacity - written) arm64-encoder/X17
									displacement 8
								if encoded < 0 [return fail-code encoded 610 "compile-function/code#72"]
								written: written + encoded
								scratch/stack-types/depth: -5
								scratch/stack-kinds/depth: VALUE
								scratch/stack-locations/depth: LOCATION_FRAME
								scratch/stack-low/depth: displacement
								scratch/stack-high/depth: 0
								scratch/stack-flags/depth: 0
								index: index + 1
								continue
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth target ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 611 "compile-function/code#73"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/count-leading-zeros at
								(capacity - written) target target width
							if encoded < 0 [return fail-code encoded 612 "compile-function/code#74"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at (capacity - written)
								arm64-encoder/X16 width ((width * 8) - 1) 0
							if encoded < 0 [return fail-code encoded 613 "compile-function/code#75"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/subtract-register at
								(capacity - written) target arm64-encoder/X16 target width
							if encoded < 0 [return fail-code encoded 614 "compile-function/code#76"]
							written: written + encoded
							scratch/stack-types/depth: -5
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_REGISTER
							scratch/stack-low/depth: target
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
						]
						true [return fail-unsupported 227 "compile-function/scratch/stack-flags#61"]
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
							][return fail-unsupported 228 "compile-function/scratch/homes#62"]
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
							][return fail-invalid 229 "compile-function/instruction/c#63"]
							global: as rsir-global! (view/globals
								+ ((slot - 1) * RSIR_GLOBAL_SIZE))
							scratch/stack-types/depth: global/type
							target: scratch/global-homes/slot
							either target > 0 [
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: take-temp-register view scratch depth false depth
									region-base region-limit at (capacity - written) :target
								if encoded < 0 [return fail-code encoded 615 "compile-function/code#77"]
								written: written + encoded
								if target < 0 [return fail-limit 230 "compile-function/address-temporary-limit"]
								status: record-reference
									(view/header/function-count + slot)
									(function-base + written)
									references
								if status < 0 [return fail-code status 616 "compile-function/code#78"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/page-address at
									(capacity - written) target
								if encoded < 0 [return fail-code encoded 617 "compile-function/code#79"]
								written: written + encoded
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
							]
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: global/flags
						]
						instruction/a = FUNCTION_ADDRESS [
							unless all [
								slot > 0
								slot <= view/header/function-count
								valid-type-ref? instruction/c view
								(type-kind instruction/c view) = -4
							][return fail-invalid 231 "compile-function/instruction/c#65"]
							target: FIRST_TEMP_REGISTER + depth - 1
							either target < (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT) [
								; The linker rewrites the ADRP/ADD pair once it knows
								; where the callee landed in the code section.
								status: record-reference slot
									(function-base + written) references
								if status < 0 [return fail-code status 618 "compile-function/code#80"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/page-address at
									(capacity - written) target
								if encoded < 0 [return fail-code encoded 619 "compile-function/code#81"]
								written: written + encoded
								scratch/stack-types/depth: instruction/c
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
								scratch/stack-high/depth: 0
								scratch/stack-flags/depth: 0
							][
								;-- Deep-stack fallback: the expression stack
								;-- outgrew the temp pool, so park the formed
								;-- address in the region spill slot.
								if (region-base + depth) > region-limit [
									return fail-invalid 232 "compile-function/region-base#66"
								]
								status: record-reference slot
									(function-base + written) references
								if status < 0 [return fail-code status 620 "compile-function/code#82"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/page-address at
									(capacity - written) arm64-encoder/X17
								if encoded < 0 [return fail-code encoded 621 "compile-function/code#83"]
								written: written + encoded
								displacement: 0 - ((region-base + depth) * 8)
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: compiler-frame-store at
									(capacity - written) arm64-encoder/X17
									displacement 8
								if encoded < 0 [return fail-code encoded 622 "compile-function/code#84"]
								written: written + encoded
								scratch/stack-types/depth: instruction/c
								;-- The slot holds the address itself, so it is not the
								;-- frame home of an addressed object: mark it as a
								;-- spill, or OP_REFERENCE would overwrite the address
								;-- with the address of its own slot.
								scratch/stack-locations/depth: LOCATION_SPILL
								scratch/stack-low/depth: displacement
								scratch/stack-high/depth: 0
								scratch/stack-flags/depth: 0
							]
						]
						instruction/a = IMPORT_ADDRESS [
							unless all [
								slot > 0 slot <= view/header/import-count
							][return fail-invalid 233 "compile-function/view/header#67"]
							imported: as rsir-import! (view/imports
								+ ((slot - 1) * RSIR_IMPORT_SIZE))
							;-- Data imports (flags = 0) declare their value
							;-- type on the import record itself; function
							;-- imports carry the function type in c.
							either imported/flags = 0 [
								if instruction/c <> 0 [return fail-invalid 234 "compile-function/instruction/c#68"]
								ref: imported/type
							][
								unless all [
									valid-type-ref? instruction/c view
									(type-kind instruction/c view) = -4
								][return fail-invalid 235 "compile-function/instruction/c#69"]
								ref: instruction/c
								unless any [
									imported/flags = CDECL
									imported/flags = STDCALL
								][return fail-unsupported 236 "compile-function/imported/flags#70"]
							]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return fail-unsupported 237 "compile-function#71"
							]
							status: record-reference
								(view/header/function-count
									+ view/header/global-count + slot)
								(function-base + written) references
							if status < 0 [return fail-code status 623 "compile-function/code#85"]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/page-address at
							(capacity - written) target
						if encoded < 0 [return fail-code encoded 624 "compile-function/code#86"]
						written: written + encoded
						;-- An ADRP/ADD pair can only name a slot: an
						;-- imported symbol lives in a dylib at a distance
						;-- no ADRP can span, so Mach-O and ELF alike reach
						;-- it through the GOT entry the dynamic linker fills
						;-- in. The pair forms the address of that entry and
						;-- the load is what reaches the symbol: the address
						;-- of an imported variable, or the entry point of an
						;-- imported function.
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/load-register-indirect at
							(capacity - written) target
						if encoded < 0 [return fail-code encoded 625 "compile-function/code#87"]
						written: written + encoded
						scratch/stack-types/depth: ref
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
					]
					true [return fail-unsupported 238 "compile-function/scratch/stack-flags#72"]
					]
				]
				instruction/op = OP_LOAD [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = PLACE
					][return fail-invalid 239 "compile-function/scratch/stack-kinds#73"]
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
									return fail-unsupported 240 "compile-function#74"
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at
									(capacity - written) target compiler-frame-register
									scratch/homes/slot arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 626 "compile-function/code#88"]
								written: written + encoded
							]
							scratch/stack-locations/depth = LOCATION_REGISTER [
								target: scratch/stack-low/depth
								if scratch/stack-high/depth <> 0 [
									target: FIRST_TEMP_REGISTER + depth - 1
									if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
										return fail-unsupported 241 "compile-function#75"
									]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/address-offset at
										(capacity - written) target scratch/stack-low/depth
										scratch/stack-high/depth arm64-encoder/X16
									if encoded < 0 [return fail-code encoded 627 "compile-function/code#89"]
									written: written + encoded
								]
							]
							scratch/stack-locations/depth = LOCATION_FRAME [
								target: FIRST_TEMP_REGISTER + depth - 1
								if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
									;-- Deep-stack fallback: form the address in
									;-- the fixed scratch register and park it in
									;-- the region spill slot for this depth. An
									;-- inline aggregate *is* that address, so the
									;-- parked word is the loaded value: re-tag the
									;-- slot the way the register path does, or the
									;-- place survives into consumers that demand a
									;-- value (a call argument, for one).
									if (region-base + depth) > region-limit [
										return fail-invalid 242 "compile-function/region-base#76"
									]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/address-offset at
										(capacity - written) arm64-encoder/X17
										compiler-frame-register scratch/stack-low/depth
										arm64-encoder/X16
									if encoded < 0 [return fail-code encoded 628 "compile-function/code#90"]
									written: written + encoded
									displacement: 0 - ((region-base + depth) * 8)
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-store at
										(capacity - written) arm64-encoder/X17
										displacement 8
									if encoded < 0 [return fail-code encoded 629 "compile-function/code#91"]
									written: written + encoded
									scratch/stack-kinds/depth: VALUE
									scratch/stack-locations/depth: LOCATION_FRAME
									scratch/stack-low/depth: displacement
									scratch/stack-high/depth: 0
									scratch/stack-flags/depth: 0
									index: index + 1
									continue
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at
									(capacity - written) target compiler-frame-register
									scratch/stack-low/depth arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 630 "compile-function/code#92"]
								written: written + encoded
							]
							true [return fail-invalid 243 "compile-function/written#77"]
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
							if ref = 0 [return fail-invalid 244 "compile-function/ref#78"]
							target: scratch/homes/slot
							if target <= 0 [return fail-invalid 245 "compile-function/scratch/homes#79"]
						]
						scratch/stack-locations/depth = LOCATION_REGISTER [
							width: value-width ref view
							kind: type-kind ref view
							if width = 0 [return fail-invalid 246 "compile-function/ref#80"]
							if width > 8 [return fail-unsupported 247 "compile-function#81"]
							floating?: any [kind = 9 kind = 10]
							target: available-temp-register view scratch depth floating? depth
							either target >= 0 [
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
								if encoded < 0 [return fail-code encoded 631 "compile-function/code#93"]
								written: written + encoded
							][
								;-- Deep-stack fallback: the expression stack
								;-- outgrew the temp pool, so park the loaded
								;-- value in the region spill slot for this depth.
								if floating? [return fail-unsupported 248 "compile-function/floating#82"]
								if (region-base + depth) > region-limit [
									return fail-invalid 249 "compile-function/region-base#83"
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-load at
									(capacity - written) arm64-encoder/X17
									scratch/stack-low/depth scratch/stack-high/depth
									width 0 width arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 632 "compile-function/code#94"]
								written: written + encoded
								displacement: 0 - ((region-base + depth) * 8)
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: compiler-frame-store at
									(capacity - written) arm64-encoder/X17
									displacement width
								if encoded < 0 [return fail-code encoded 633 "compile-function/code#95"]
								written: written + encoded
								scratch/stack-types/depth: ref
								scratch/stack-kinds/depth: VALUE
								scratch/stack-locations/depth: LOCATION_FRAME
								scratch/stack-low/depth: displacement
								scratch/stack-high/depth: 0
								scratch/stack-flags/depth: 0
								index: index + 1
								continue
							]
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							width: value-width ref view
							kind: type-kind ref view
							if width = 0 [return fail-invalid 250 "compile-function/ref#84"]
							if width > 8 [return fail-unsupported 251 "compile-function#85"]
							floating?: any [kind = 9 kind = 10]
							target: available-temp-register view scratch depth floating? depth
							if target < 0 [
								;-- Deep-stack fallback: a frame-backed place
								;-- already holds the value in memory, so the
								;-- load is a pure re-tag of the same slot.
								scratch/stack-types/depth: ref
								scratch/stack-kinds/depth: VALUE
								scratch/stack-flags/depth: 0
								index: index + 1
								continue
							]
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
							if encoded < 0 [return fail-code encoded 634 "compile-function/code#96"]
							written: written + encoded
						]
						true [return fail-invalid 252 "compile-function/written#86"]
					]
					scratch/stack-types/depth: ref
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_SET [
					if depth = 1 [
						;-- Dead fallthrough after a no-return call: the
						;-- value slot does not exist, so the store is skipped.
						depth: 0
						index: index + 1
						continue
					]
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth >= 2 scratch/stack-kinds/depth = PLACE
					][return fail-invalid 253 "compile-function/scratch/stack-kinds#87"]
					source-slot: depth - 1
					if scratch/stack-kinds/source-slot <> VALUE [return fail-invalid 254 "compile-function/scratch/stack-kinds#88"]
					ref: scratch/stack-types/source-slot
					; The variant number leads the union, whose preserved base is
					; independent of any member dereference that follows.
					if tag-variant <> 0 [
						unless tag-slot = depth [return fail-unsupported 255 "compile-function/tag-slot#89"]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-load at (capacity - written)
							arm64-encoder/X17 plan/tag-offset 8 0 8
						if encoded < 0 [return fail-code encoded 635 "compile-function/code#97"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at (capacity - written)
							arm64-encoder/X16 4 tag-variant 0
						if encoded < 0 [return fail-code encoded 636 "compile-function/code#98"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/register-store at (capacity - written)
							arm64-encoder/X16 arm64-encoder/X17 0 tag-width-value
							arm64-encoder/X15
						if encoded < 0 [return fail-code encoded 637 "compile-function/code#99"]
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
								:return-size :return-align [return fail-invalid 256 "compile-function/return-size#90"]
							if any [return-size <= 0 return-align <= 0 return-align > 16][
								return fail-unsupported 257 "compile-function/return-size#91"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot arm64-encoder/X15
								ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 638 "compile-function/code#100"]
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
								true [fail-internal 863 "compile-function/aggregate-location"]
							]
							if encoded < 0 [return fail-code encoded 639 "compile-function/code#101"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-memory-copy at (capacity - written)
								arm64-encoder/X14 arm64-encoder/X15 return-size
							if encoded < 0 [return fail-code encoded 640 "compile-function/code#102"]
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
								if parameter/flags <> 0 [return fail-unsupported 258 "compile-function/parameter/flags#92"]
								width: value-width ref view
								kind: type-kind ref view
								if width = 0 [return fail-invalid 259 "compile-function/ref#93"]
								if any [width > 8 kind = 9 kind = 10][return fail-unsupported 260 "compile-function#94"]
								target-ref: ref
								scratch/storage-types/target-slot: ref
							]
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return fail-invalid 261 "compile-function/view#95"]
							target: scratch/homes/target-slot
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch source-slot target
								target-ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 641 "compile-function/code#103"]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_REGISTER [
							if (scratch/stack-flags/depth and PROTECTED) <> 0 [
								return fail-invalid 262 "compile-function/scratch/stack-flags#96"
							]
							target-ref: scratch/stack-types/depth
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return fail-invalid 263 "compile-function/view#97"]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return fail-invalid 264 "compile-function/target-ref#98"]
							if width > 8 [return fail-unsupported 265 "compile-function#99"]
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
								if encoded < 0 [return fail-code encoded 642 "compile-function/code#104"]
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
							if encoded < 0 [return fail-code encoded 643 "compile-function/code#105"]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							if (scratch/stack-flags/depth and PROTECTED) <> 0 [
								return fail-invalid 266 "compile-function/scratch/stack-flags#100"
							]
							target-ref: scratch/stack-types/depth
							unless implicitly-compatible? target-ref ref
								(scratch/stack-locations/source-slot = LOCATION_IMMEDIATE)
								view [return fail-invalid 267 "compile-function/view#101"]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return fail-invalid 268 "compile-function/target-ref#102"]
							if width > 8 [return fail-unsupported 269 "compile-function#103"]
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
								if encoded < 0 [return fail-code encoded 644 "compile-function/code#106"]
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
							if encoded < 0 [return fail-code encoded 645 "compile-function/code#107"]
							written: written + encoded
						]
						true [return fail-invalid 270 "compile-function/written#104"]
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
							scratch/stack-locations/depth = LOCATION_SPILL
							scratch/stack-locations/depth = 0
						]
						(value-width instruction/a view) = 8
						reference-type? instruction/a view
					][return fail-unsupported 271 "compile-function/instruction/a#105"]
					either scratch/stack-locations/depth = LOCATION_SPILL [
						;-- The address is already parked in the region slot, so
						;-- the reference is that slot's content. Forming the
						;-- address again would overwrite it with its own
						;-- location.
						scratch/stack-types/depth: instruction/a
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_FRAME
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						index: index + 1
						continue
					][
						either scratch/stack-locations/depth = LOCATION_FRAME [
							target: available-temp-register view scratch depth false depth
							either target >= 0 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									target compiler-frame-register scratch/stack-low/depth
									arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 646 "compile-function/code#108"]
								written: written + encoded
							][
								;-- Deep-stack fallback: the temp pool is exhausted,
								;-- so form the address in the fixed scratch register
								;-- and park it in the region spill slot.
								if (region-base + depth) > region-limit [
									return fail-invalid 272 "compile-function/region-base#106"
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									arm64-encoder/X17 compiler-frame-register
									scratch/stack-low/depth arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 647 "compile-function/code#109"]
								written: written + encoded
								displacement: 0 - ((region-base + depth) * 8)
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: compiler-frame-store at
									(capacity - written) arm64-encoder/X17
									displacement 8
								if encoded < 0 [return fail-code encoded 648 "compile-function/code#110"]
								written: written + encoded
								scratch/stack-types/depth: instruction/a
								scratch/stack-kinds/depth: VALUE
								scratch/stack-locations/depth: LOCATION_FRAME
								scratch/stack-low/depth: displacement
								scratch/stack-high/depth: 0
								scratch/stack-flags/depth: 0
								index: index + 1
								continue
							]
						][
							target: scratch/stack-low/depth
							if scratch/stack-high/depth <> 0 [
								target: available-temp-register view scratch depth false depth
								either target >= 0 [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/address-offset at (capacity - written)
										target scratch/stack-low/depth scratch/stack-high/depth
										arm64-encoder/X16
									if encoded < 0 [return fail-code encoded 649 "compile-function/code#111"]
									written: written + encoded
								][
									;-- Deep-stack fallback: park the formed address
									;-- in the region spill slot for this depth.
									if (region-base + depth) > region-limit [
										return fail-invalid 273 "compile-function/region-base#107"
									]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/address-offset at (capacity - written)
										arm64-encoder/X17 scratch/stack-low/depth
										scratch/stack-high/depth arm64-encoder/X16
									if encoded < 0 [return fail-code encoded 650 "compile-function/code#112"]
									written: written + encoded
									displacement: 0 - ((region-base + depth) * 8)
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-store at
										(capacity - written) arm64-encoder/X17
										displacement 8
									if encoded < 0 [return fail-code encoded 651 "compile-function/code#113"]
									written: written + encoded
									scratch/stack-types/depth: instruction/a
									scratch/stack-kinds/depth: VALUE
									scratch/stack-locations/depth: LOCATION_FRAME
									scratch/stack-low/depth: displacement
									scratch/stack-high/depth: 0
									scratch/stack-flags/depth: 0
									index: index + 1
									continue
								]
							]
						]
					scratch/stack-types/depth: instruction/a
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
					]
				]
				instruction/op = OP_INDEX [
					unless any [instruction/b = 0 instruction/b = 1][return fail-invalid 274 "compile-function/instruction/b#108"]
					target-slot: either instruction/b = 1 [depth - 1][depth]
					if any [
						target-slot <= 0
						scratch/stack-kinds/target-slot <> VALUE
					][return fail-invalid 275 "compile-function/scratch/stack-kinds#109"]
					ref: scratch/stack-types/target-slot
					member-type: 0
					unless pointee-type ref view :member-type [return fail-invalid 276 "compile-function/ref#110"]
					stride: pointer-stride ref view layout
					if stride <= 0 [return fail-unsupported 277 "compile-function/stride#111"]
					;-- A register-backed base needs no scratch register: the
					;-- constant-index result stays a (register, offset) pair.
					;-- Allocate a scratch register only to materialize a base
					;-- that lives outside the register pool.
					case [
						instruction/b = 0 [
							condition: either instruction/a < 0 [-1][0]
							if instruction/c <> condition [
								return fail-unsupported 278 "compile-function/instruction/c#112"
							]
							ordinal: instruction/a
							if any [
								all [ordinal < 0 ordinal < (80000000h / stride)]
								all [ordinal >= 0 ordinal > (7FFFFFFFh / stride)]
							][return fail-unsupported 279 "compile-function/ordinal#113"]
							scaled: ordinal * stride
							either (scratch/stack-locations/target-slot
								= LOCATION_REGISTER) [
								target: scratch/stack-low/target-slot
								scratch/stack-high/target-slot: scaled
							][
								target: available-temp-register view scratch depth
									false target-slot
								either target >= 0 [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: materialize view scratch target-slot target ref
										at (capacity - written)
									if encoded < 0 [return fail-code encoded 652 "compile-function/code#114"]
									written: written + encoded
									scratch/stack-high/target-slot: scaled
								][
									;-- Deep-stack fallback: the temp pool is
									;-- full, so form base+index in X17 and keep
									;-- a zero-offset PLACE there for OP_LOAD.
									if (region-base + depth) > region-limit [
										return fail-invalid 280 "compile-function/region-base#114"
									]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: materialize view scratch target-slot
										arm64-encoder/X17 ref at (capacity - written)
									if encoded < 0 [return fail-code encoded 653 "compile-function/code#115"]
									written: written + encoded
									if scaled <> 0 [
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/move-immediate at
											(capacity - written) arm64-encoder/X16
											8 scaled 0
										if encoded < 0 [return fail-code encoded 654 "compile-function/code#116"]
										written: written + encoded
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/add-register at
											(capacity - written) arm64-encoder/X17
											arm64-encoder/X17 arm64-encoder/X16 8
										if encoded < 0 [return fail-code encoded 655 "compile-function/code#117"]
										written: written + encoded
									]
									target: arm64-encoder/X17
									scaled: 0
									scratch/stack-high/target-slot: 0
								]
							]
						]
						instruction/b = 1 [
							if any [
								instruction/a <> 0 instruction/c <> 0
								depth < 2
								scratch/stack-kinds/depth <> VALUE
								(type-kind scratch/stack-types/depth view) <> 5
							][return fail-invalid 281 "compile-function/scratch/stack-types#115"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: take-temp-register view scratch depth false
								target-slot region-base region-limit at (capacity - written) :target
							if encoded < 0 [return fail-code encoded 656 "compile-function/code#118"]
							written: written + encoded
							if target < 0 [return fail-limit 282 "compile-function/index-temporary-limit"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17
								scratch/stack-types/depth at (capacity - written)
							if encoded < 0 [return fail-code encoded 657 "compile-function/code#119"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch target-slot target ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 658 "compile-function/code#120"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/add-immediate at (capacity - written)
								arm64-encoder/X17 arm64-encoder/X17 -1 4
							if encoded < 0 [return fail-code encoded 659 "compile-function/code#121"]
							written: written + encoded
							shift: power-shift stride
							either shift >= 0 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-extended-register at
									(capacity - written) arm64-encoder/OP_ADD
									target target arm64-encoder/X17 4 1 shift
								if encoded < 0 [return fail-code encoded 660 "compile-function/code#122"]
								written: written + encoded
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X17 4 1
								if encoded < 0 [return fail-code encoded 661 "compile-function/code#123"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/move-immediate at
									(capacity - written) arm64-encoder/X16 8 stride 0
								if encoded < 0 [return fail-code encoded 662 "compile-function/code#124"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/multiply-register at
									(capacity - written) arm64-encoder/X17
									arm64-encoder/X17 arm64-encoder/X16 8
								if encoded < 0 [return fail-code encoded 663 "compile-function/code#125"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-register at
									(capacity - written) target target arm64-encoder/X17 8
								if encoded < 0 [return fail-code encoded 664 "compile-function/code#126"]
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
					if any [depth <= 0 instruction/c <> 0][return fail-invalid 283 "compile-function/member-operands"]
					ref: scratch/stack-types/depth
					unless any [
						scratch/stack-kinds/depth = PLACE
						all [
							scratch/stack-kinds/depth = VALUE
							any [(type-kind ref view) = -2 (type-kind ref view) = -3]
						]
					][return fail-invalid 284 "compile-function/ref#118"]
					; A write through a tagged union carries the variant it
					; selects. The store itself waits for the OP_SET that closes
					; the path, so the value being assigned still sees whatever
					; tag the union held on the way in.
					if instruction/b <> 0 [
						unless all [
							instruction/b = (instruction/a + 1)
							tag-variant = 0
						][return fail-unsupported 285 "compile-function/tag-variant#119"]
						width: union-tag-width ref view
						if width = 0 [return fail-invalid 286 "compile-function/ref#120"]
						tag-variant: instruction/b
						tag-width-value: width
						tag-slot: depth
						; A tagged member can be dereferenced before OP_SET (for
						; example, union/pointer/value). Materialize the union base
						; now so the deferred tag store does not depend on that
						; later address computation.
						case [
							scratch/stack-locations/depth = LOCATION_REGISTER [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: take-temp-register view scratch depth false depth
									region-base region-limit at (capacity - written) :target
								if encoded < 0 [return fail-code encoded 665 "compile-function/code#127"]
								written: written + encoded
								if target < 0 [return fail-limit 287 "compile-function/member-temporary-limit"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									target scratch/stack-low/depth scratch/stack-high/depth
									arm64-encoder/X16
							]
							scratch/stack-locations/depth = LOCATION_FRAME [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: take-temp-register view scratch depth false depth
									region-base region-limit at (capacity - written) :target
								if encoded < 0 [return fail-code encoded 666 "compile-function/code#128"]
								written: written + encoded
								if target < 0 [return fail-limit 288 "compile-function/member-frame-temporary-limit"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									target compiler-frame-register scratch/stack-low/depth
									arm64-encoder/X16
							]
							true [return fail-unsupported 289 "compile-function/arm64-encoder#123"]
						]
						if encoded < 0 [return fail-code encoded 667 "compile-function/code#129"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-store at (capacity - written)
							target plan/tag-offset 8
						if encoded < 0 [return fail-code encoded 668 "compile-function/code#130"]
						written: written + encoded
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
						scratch/stack-high/depth: 0
					]
					member-type: 0
					member-flags: 0
					member-offset: 0
					unless layout-member ref instruction/a view layout
						:member-type :member-flags :member-offset [return fail-invalid 290 "compile-function/member-type#124"]
					case [
						scratch/stack-locations/depth = LOCATION_REGISTER [
							if member-offset >
								(2147483647 - scratch/stack-high/depth) [
								return fail-unsupported 291 "compile-function/scratch/stack-high#125"
							]
							scratch/stack-high/depth:
								scratch/stack-high/depth + member-offset
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							either scratch/stack-kinds/depth = PLACE [
								if scratch/stack-low/depth > (2147483647 - member-offset)[
									return fail-unsupported 292 "compile-function/scratch/stack-low#126"
								]
								scratch/stack-low/depth:
									scratch/stack-low/depth + member-offset
								scratch/stack-high/depth: 0
							][
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: take-temp-register view scratch depth false depth
									region-base region-limit at (capacity - written) :target
								if encoded < 0 [return fail-code encoded 669 "compile-function/code#131"]
								written: written + encoded
								if target < 0 [return fail-limit 293 "compile-function/member-offset-temporary-limit"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch depth target ref
									at (capacity - written)
								if encoded < 0 [return fail-code encoded 670 "compile-function/code#132"]
								written: written + encoded
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
								scratch/stack-high/depth: member-offset
							]
						]
						true [return fail-unsupported 294 "compile-function/scratch/stack-high#128"]
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
					][return fail-invalid 295 "compile-function/scratch/stack-flags#129"]
					ref: scratch/stack-types/depth
					width: union-tag-width ref view
					if width = 0 [return fail-invalid 296 "compile-function/ref#130"]
					target: FIRST_TEMP_REGISTER + depth - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return fail-unsupported 297 "compile-function#131"
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 671 "compile-function/code#133"]
					written: written + encoded
					; The variant number leads the union, so the tag sits at the
					; front of whatever the value points at.
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/register-load at (capacity - written)
						target target 0 width 0 4 arm64-encoder/X16
					if encoded < 0 [return fail-code encoded 672 "compile-function/code#134"]
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
					][return fail-invalid 298 "compile-function/target-catch-depth#132"]
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
					][return fail-invalid 299 "compile-function/scratch/stack-types#133"]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth arm64-encoder/X3 -5
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 673 "compile-function/code#135"]
					written: written + encoded
					target-offset: either null? code [0][instruction-offsets/target]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-catch-open at (capacity - written)
						instruction/b target-offset written
					if encoded < 0 [return fail-code encoded 674 "compile-function/code#136"]
					written: written + encoded
					depth: 0
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return fail-invalid 300 "compile-function/instruction-depths#134"
					]
				]
				instruction/op = OP_END_CATCH [
					catch-level: catch-depths/ordinal
					unless all [
						catch-level > 0
						instruction/b = catch-level
						instruction/a > 0 instruction/a < ordinal
					][return fail-invalid 301 "compile-function/instruction/a#135"]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-catch-restore plan at (capacity - written)
						catch-level
					if encoded < 0 [return fail-code encoded 675 "compile-function/code#137"]
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
					][return fail-invalid 302 "compile-function/scratch/stack-types#136"]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch source-slot arm64-encoder/X0 -5
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 676 "compile-function/code#138"]
					written: written + encoded
					case [
						scratch/stack-locations/target-slot = 0 [
							slot: scratch/stack-low/target-slot
							target: scratch/homes/slot
							if target <= 0 [return fail-invalid 303 "compile-function/scratch/homes#137"]
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
						true [return fail-invalid 304 "compile-function/scratch/stack-low#138"]
					]
					if encoded < 0 [return fail-code encoded 677 "compile-function/code#139"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-frame-normalize plan at (capacity - written)
					if encoded < 0 [return fail-code encoded 678 "compile-function/code#140"]
					written: written + encoded
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-throw-unwind at (capacity - written)
						((fn/flags and CATCH_FLAG) <> 0)
					if encoded < 0 [return fail-code encoded 679 "compile-function/code#141"]
					written: written + encoded
					depth: source-slot - 1
					fallthrough?: false
				]
				instruction/op = OP_CALL [
					call-target: instruction/a
					argument-count: instruction/b
					; A call through a pointer keeps the callee below its
					; arguments, so it claims one more live slot.
					callee-slots: either call-target = 0 [1][0]
					if any [
						argument-count < 0
						argument-count > (depth - callee-slots)
					][return fail-invalid 305 "compile-function/argument-count#139"]
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
					if status < 0 [return fail-code status 680 "compile-function/code#142"]
					call-mode: call-flags and (VARIADIC or TYPED or CUSTOM)
					custom-call?: call-mode = CUSTOM
					packed-call?: all [
						call-mode = VARIADIC
						(call-flags and 3) <> CDECL
					]
					if packed-call? [
						if any [call-parameter-count < 2 call-parameter-count > 3][
							return fail-invalid 306 "compile-function/call-parameter-count#140"
						]
						parameter: call-parameter view call-source call-first-parameter 1
						unless all [parameter/flags = 0 (type-kind parameter/type view) = 5][
							return fail-invalid 307 "compile-function/parameter/flags#141"
						]
						parameter: call-parameter view call-source call-first-parameter 2
						unless all [parameter/flags = 0 address-type? parameter/type view][
							return fail-invalid 308 "compile-function/parameter/flags#142"
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
						][return fail-invalid 309 "compile-function/call-parameter-count#143"]
					]
					if call-return <> 0 [
						aggregate-return?: (call-flags and RETURN_VALUE) <> 0
						either aggregate-return? [
							unless aggregate-ref? call-return view [return fail-invalid 310 "compile-function/aggregate-ref#144"]
							aggregate-size-value: 0
							aggregate-align: 0
							unless layout-type call-return true view layout 0
								:aggregate-size-value :aggregate-align [return fail-invalid 311 "compile-function/aggregate-size-value#145"]
							if aggregate-size-value <= 0 [return fail-invalid 312 "compile-function/aggregate-size-value#146"]
						][
							width: value-width call-return view
							kind: type-kind call-return view
							if any [width = 0 width > 8][return fail-unsupported 313 "compile-function/call-return#147"]
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
								(call-flags and CUSTOM) <> 0
						]
						any [
							(call-flags and TYPED) <> 0
							call-target = 0
							instruction/c = call-return
						]
					][return fail-invalid 314 "compile-function/instruction/c#148"]
					fixed-stack-size: 0
					if packed-call? [
						if argument-count > (2147483647 / 8)[return fail-limit 864 "compile-function/limit#272"]
						list-size: argument-count * 8
						list-capacity: either list-size < 8 [8][list-size]
						fixed-stack-size: align list-capacity 16
					]
					if all [(call-flags and TYPED) = 0 not packed-call? not custom-call?] [
						status: abi-parameter-location view layout call-source
							call-first-parameter call-parameter-count 0 abi-location
							if status < 0 [return fail-code status 681 "compile-function/code#143"]
						fixed-stack-size: abi-location/stack-size
					]
					if all [(call-flags and VARIADIC) <> 0 not packed-call?] [
						if (argument-count - call-parameter-count)
							> ((2147483647 - fixed-stack-size) / 8) [
							return fail-limit 865 "compile-function/limit#273"
						]
					]
					argument-origin: depth - argument-count
					if (region-base + argument-origin) > region-limit [
						return fail-invalid 315 "compile-function/region-base#149"
					]
					callee-slot: either callee-slots = 0 [0][argument-origin]
					argument-base: argument-origin - callee-slots
					if callee-slot > 0 [
						unless all [
							scratch/stack-kinds/callee-slot = VALUE
							scratch/stack-flags/callee-slot = 0
							compatible-types? call-signature
								scratch/stack-types/callee-slot view
						][return fail-invalid 316 "compile-function/scratch/stack-types#150"]
					]
					slot: 1
					while [slot <= argument-base][
						ref: scratch/stack-types/slot
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
								][return fail-unsupported 317 "compile-function#151"]
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
								if encoded < 0 [return fail-code encoded 682 "compile-function/code#144"]
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
							if encoded < 0 [return fail-code encoded 683 "compile-function/code#145"]
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
						if encoded < 0 [return fail-code encoded 684 "compile-function/code#146"]
						written: written + encoded
						scratch/stack-locations/callee-slot: LOCATION_FRAME
						scratch/stack-low/callee-slot: displacement
						scratch/stack-high/callee-slot: 0
					]
					aggregate-return?: (call-flags and RETURN_VALUE) <> 0
					if aggregate-return? [
						result-offset: result-offsets/ordinal
						if result-offset >= 0 [return fail-invalid 318 "compile-function/result-offset#152"]
					]
					; Copy indirect aggregate arguments before loading ABI registers.
					slot: 1
					while [all [not packed-call? not custom-call?
						(call-flags and TYPED) = 0
						slot <= call-parameter-count]][
						parameter: call-parameter view call-source call-first-parameter slot
						if parameter/flags = INLINE [
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count slot abi-location
							if status < 0 [return fail-code status 685 "compile-function/code#147"]
							if abi-location/class = ABI_INDIRECT [
								argument-slot: argument-origin + slot
								unless all [
									scratch/stack-kinds/argument-slot = VALUE
									compatible-types? parameter/type
										scratch/stack-types/argument-slot view
								][return fail-invalid 319 "compile-function/scratch/stack-types#153"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch argument-slot
									arm64-encoder/X15 parameter/type at (capacity - written)
								if encoded < 0 [return fail-code encoded 686 "compile-function/code#148"]
								written: written + encoded
								copy-offset: fixed-stack-size + abi-location/copy-offset
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/address-offset at (capacity - written)
									arm64-encoder/X14 arm64-encoder/SP copy-offset arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 687 "compile-function/code#149"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: emit-memory-copy at (capacity - written)
									arm64-encoder/X14 arm64-encoder/X15 abi-location/size
								if encoded < 0 [return fail-code encoded 688 "compile-function/code#150"]
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
							][return fail-invalid 320 "compile-function/typed-member/flags#154"]
							width: value-width ref view
							kind: type-kind ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return fail-unsupported 321 "compile-function#155"
							]
							record-offset: (slot - 1) * 24
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X16 4
								typed-member/flags 0
							if encoded < 0 [return fail-code encoded 689 "compile-function/code#151"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/X16 arm64-encoder/SP
								record-offset 4 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 690 "compile-function/code#152"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/ZR arm64-encoder/SP
								(record-offset + 4) 4 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 691 "compile-function/code#153"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) arm64-encoder/ZR arm64-encoder/SP
								(record-offset + 8) 8 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 692 "compile-function/code#154"]
							written: written + encoded
							floating?: float-type? ref view
							target: either floating? [
								FLOAT_SCRATCH_REGISTER
							][arm64-encoder/X16]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot target ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 693 "compile-function/code#155"]
							written: written + encoded
							if all [not floating? width < 4][
								load-signed: either signed-type? ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) target target width load-signed
								if encoded < 0 [return fail-code encoded 694 "compile-function/code#156"]
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
							if encoded < 0 [return fail-code encoded 695 "compile-function/code#157"]
							written: written + encoded
							either any [kind = 7 kind = 8][
								if width = 8 [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/shift-immediate at
										(capacity - written) arm64-encoder/SHIFT_RIGHT
										arm64-encoder/X17 arm64-encoder/X16 32 8
									if encoded < 0 [return fail-code encoded 696 "compile-function/code#158"]
									written: written + encoded
								]
								target: either width = 8 [arm64-encoder/X17][arm64-encoder/ZR]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/register-store at
									(capacity - written) target
									arm64-encoder/SP (record-offset + 16) 4 arm64-encoder/X16
								if encoded < 0 [return fail-code encoded 697 "compile-function/code#159"]
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
							if encoded < 0 [return fail-code encoded 698 "compile-function/code#160"]
							written: written + encoded
							slot: slot - 1
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at
							(capacity - written) arm64-encoder/X0 4 argument-count 0
						if encoded < 0 [return fail-code encoded 699 "compile-function/code#161"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-register at (capacity - written)
							arm64-encoder/X1 arm64-encoder/SP 8
						if encoded < 0 [return fail-code encoded 700 "compile-function/code#162"]
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
							][return fail-invalid 322 "compile-function/scratch/stack-flags#156"]
							ref: scratch/stack-types/argument-slot
							width: value-width ref view
							unless any [width = 1 width = 2 width = 4 width = 8][
								return fail-unsupported 323 "compile-function#157"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot
								arm64-encoder/X16 ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 701 "compile-function/code#163"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at (capacity - written)
								arm64-encoder/X16 arm64-encoder/SP ((slot - 1) * 8)
								8 arm64-encoder/X17
							if encoded < 0 [return fail-code encoded 702 "compile-function/code#164"]
							written: written + encoded
							slot: slot + 1
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at (capacity - written)
							arm64-encoder/X0 4 argument-count 0
						if encoded < 0 [return fail-code encoded 703 "compile-function/code#165"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-register at (capacity - written)
							arm64-encoder/X1 arm64-encoder/SP 8
						if encoded < 0 [return fail-code encoded 704 "compile-function/code#166"]
						written: written + encoded
						slot: 0
					]
					; Custom calls take no ABI arguments: the frontend already
					; materialized the single value, and the indirect path
					; injects the X0 move just before call-register.
					if custom-call? [slot: 0]
					;-- Under AAPCS64 the trailing arguments of a variadic call
					;-- carry on from the registers the fixed ones took, so
					;-- snapshot where those left off.
					named-integers: 0
					named-floats: 0
					if all [
						target-abi = ABI_AAPCS64
						(call-flags and VARIADIC) <> 0
						(call-flags and TYPED) = 0
						not packed-call?
						argument-count > call-parameter-count
					][
						status: abi-parameter-location view layout call-source
							call-first-parameter call-parameter-count
							call-parameter-count abi-location
						if status < 0 [return fail-code status 705 "compile-function/code#167"]
						named-integers: abi-location/integer-used
						named-floats: abi-location/float-used
					]
					while [slot > 0][
						argument-slot: argument-origin + slot
						if scratch/stack-kinds/argument-slot <> VALUE [return fail-invalid 324 "compile-function/scratch/stack-kinds#158"]
						ref: scratch/stack-types/argument-slot
						if all [slot <= call-parameter-count not packed-call?
							(call-flags and TYPED) = 0][
							parameter: call-parameter view call-source call-first-parameter slot
							status: abi-parameter-location view layout call-source
								call-first-parameter call-parameter-count slot abi-location
							if status < 0 [return fail-code status 706 "compile-function/code#168"]
							if parameter/flags = INLINE [
								unless all [
									aggregate-ref? parameter/type view
									aggregate-ref? ref view
									compatible-types? parameter/type ref view
								][return fail-invalid 325 "compile-function/compatible-types#159"]
								if syscall? [return fail-unsupported 326 "compile-function/syscall#160"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch argument-slot arm64-encoder/X15
									parameter/type at (capacity - written)
								if encoded < 0 [return fail-code encoded 707 "compile-function/code#169"]
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
											if encoded < 0 [return fail-code encoded 708 "compile-function/code#170"]
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
											if encoded < 0 [return fail-code encoded 709 "compile-function/code#171"]
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
										if encoded < 0 [return fail-code encoded 710 "compile-function/code#172"]
										written: written + encoded
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: emit-memory-copy at (capacity - written)
											arm64-encoder/X14 arm64-encoder/X15 abi-location/size
										if encoded < 0 [return fail-code encoded 711 "compile-function/code#173"]
										written: written + encoded
									]
									abi-location/class = ABI_INDIRECT [
										copy-offset: fixed-stack-size + abi-location/copy-offset
										at: either null? code [as byte-ptr! 0][code + written]
										encoded: arm64-encoder/address-offset at (capacity - written)
											arm64-encoder/X16 arm64-encoder/SP copy-offset
											arm64-encoder/X17
										if encoded < 0 [return fail-code encoded 712 "compile-function/code#174"]
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
										if encoded < 0 [return fail-code encoded 713 "compile-function/code#175"]
										written: written + encoded
									]
									true [return fail-invalid 327 "compile-function/written#161"]
								]
								slot: slot - 1
								continue
							]
						]
						either slot <= call-parameter-count [
							parameter: call-parameter view call-source
								call-first-parameter slot
							if parameter/flags <> 0 [return fail-unsupported 328 "compile-function/parameter/flags#162"]
							unless implicitly-compatible? parameter/type ref
								(scratch/stack-locations/argument-slot = LOCATION_IMMEDIATE) view [
								return fail-invalid 329 "compile-function/scratch/stack-locations#163"
							]
							target-ref: parameter/type
							stack-offset: abi-location/stack-offset
						][
							unless (call-flags and VARIADIC) <> 0 [return fail-invalid 330 "compile-function/call-flags#164"]
							kind: type-kind ref view
							target-ref: either kind = 9 [-10][ref]
							;-- Apple's ARM64 ABI spills every variadic
							;   argument to the stack, but an Objective-C
							;   message is not one: objc_msgSend is entered
							;   with self in x0 and op in x1 and the rest
							;   carrying on from there. The legacy ARM64
							;   target says the same thing -- apple-variadic?
							;   is `not objc-call?` there. Spilling all three
							;   of `objc_msgSend [cls sel arg]` leaves x0 and
							;   x1 holding whatever the argument computation
							;   last touched, and the runtime answers
							;   "unrecognized selector sent to class".
							either any [
								target-abi = ABI_AAPCS64
								(call-flags and OBJC) <> 0
							][
								status: abi-trailing-argument view scratch
									argument-origin call-parameter-count
									(slot - call-parameter-count)
									named-integers named-floats abi-location
								if status < 0 [return fail-code status 714 "compile-function/code#176"]
								stack-offset: either abi-location/class = ABI_STACK [
									abi-location/stack-offset
								][-1]
							][
								stack-offset: (slot - call-parameter-count - 1) * 8
							]
						]
						width: value-width target-ref view
						kind: type-kind target-ref view
						unless any [width = 1 width = 2 width = 4 width = 8][
							return fail-unsupported 331 "compile-function#165"
						]
						floating?: any [kind = 9 kind = 10]
						if all [syscall? floating?][return fail-unsupported 332 "compile-function/syscall#166"]
						either stack-offset < 0 [
							parameter-register: abi-location/register-index
							if any [parameter-register < 0 parameter-register >= 8][
								return fail-unsupported 333 "compile-function/parameter-register#167"
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch argument-slot
								parameter-register target-ref at (capacity - written)
							if encoded < 0 [return fail-code encoded 715 "compile-function/code#177"]
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
							if encoded < 0 [return fail-code encoded 716 "compile-function/code#178"]
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
							if encoded < 0 [return fail-code encoded 717 "compile-function/code#179"]
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
							if encoded < 0 [return fail-code encoded 718 "compile-function/code#180"]
							written: written + encoded
						]
					]
					if call-target = 0 [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch callee-slot
							arm64-encoder/X17 call-signature at (capacity - written)
						if encoded < 0 [return fail-code encoded 719 "compile-function/code#181"]
						written: written + encoded
					]
					unless syscall? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-frame-normalize plan at (capacity - written)
						if encoded < 0 [return fail-code encoded 720 "compile-function/code#182"]
						written: written + encoded
					]
					case [
						syscall? [
						;-- Darwin takes the call number in X16 behind
						;-- `svc #128`; Linux in X8 behind `svc #0`.
						either target-abi = ABI_AAPCS64 [
							trap-number-register: arm64-encoder/X8
							trap-immediate: 0
						][
							trap-number-register: arm64-encoder/X16
							trap-immediate: 128
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/move-immediate at
							(capacity - written) trap-number-register 8 syscall-id 0
						if encoded < 0 [return fail-code encoded 721 "compile-function/code#183"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/svc at
							(capacity - written) trap-immediate
					]
						call-target > 0 [
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
							if status < 0 [return fail-code status 722 "compile-function/code#184"]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/call-relative at
								(capacity - written) displacement
						]
						true [
							if custom-call? [
								;-- Custom calls pass their single integer
								;-- argument in the first register (X0).
								argument-slot: argument-origin + 1
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch argument-slot
									arm64-encoder/X0 scratch/stack-types/argument-slot
									at (capacity - written)
								if encoded < 0 [return fail-code encoded 723 "compile-function/code#185"]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/call-register at
								(capacity - written) arm64-encoder/X17
						]
					]
					if encoded < 0 [return fail-code encoded 724 "compile-function/code#186"]
					written: written + encoded
					unless syscall? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-visible-frame-restore plan at (capacity - written)
						if encoded < 0 [return fail-code encoded 725 "compile-function/code#187"]
						written: written + encoded
					]
					depth: argument-base
					if call-return <> 0 [
						either aggregate-return? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/address-offset at (capacity - written)
								arm64-encoder/X15 compiler-frame-register result-offset
								arm64-encoder/X16
							if encoded < 0 [return fail-code encoded 726 "compile-function/code#188"]
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
										if encoded < 0 [return fail-code encoded 727 "compile-function/code#189"]
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
										if encoded < 0 [return fail-code encoded 728 "compile-function/code#190"]
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
								if encoded < 0 [return fail-code encoded 729 "compile-function/code#191"]
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
					][return fail-invalid 334 "compile-function/depth#168"]
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
						if encoded < 0 [return fail-code encoded 730 "compile-function/code#192"]
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
					][return fail-invalid 335 "compile-function/instruction/c#169"]
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + sub-target - 1)
							* RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/op = OP_ENTRY
						sub-entry/a = 1
						sub-entry/b = instruction/b
					][return fail-invalid 336 "compile-function/sub-entry/b#170"]
					if (region-base + depth) > region-limit [return fail-invalid 337 "compile-function/region-base#171"]
					; The callee runs on this frame and may rewrite any local, so
					; every live value goes to this region's window first.
					slot: 1
					while [slot <= depth][
						if any [
							scratch/stack-locations/slot = LOCATION_FLAGS
							scratch/stack-locations/slot = LOCATION_REGISTER
						][
							if scratch/stack-kinds/slot <> VALUE [return fail-unsupported 338 "compile-function/scratch/stack-kinds#172"]
							ref: scratch/stack-types/slot
							width: value-width ref view
							unless any [
								width = 1 width = 2 width = 4 width = 8
							][return fail-unsupported 339 "compile-function#173"]
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
								if encoded < 0 [return fail-code encoded 731 "compile-function/code#193"]
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
							if encoded < 0 [return fail-code encoded 732 "compile-function/code#194"]
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
					if encoded < 0 [return fail-code encoded 733 "compile-function/code#195"]
					written: written + encoded
					target: first-instruction + instruction/a
					either (scratch/instruction-effects/target and EFFECT_RESUMES) = 0 [
						fallthrough?: false
					][
						if instruction/b <> 0 [
							ref: instruction/b
							width: value-width ref view
							if any [width = 0 width > 8][return fail-unsupported 340 "compile-function/ref#174"]
							if all [not float-type? ref view width < 4][
								load-signed: either signed-type? ref view [1][0]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/extend-register at
									(capacity - written) arm64-encoder/X0
									arm64-encoder/X0 width load-signed
								if encoded < 0 [return fail-code encoded 734 "compile-function/code#196"]
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
					][return fail-invalid 341 "compile-function/instruction/b#175"]
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
					][return fail-invalid 342 "compile-function/view#176"]
					if instruction/a <> 0 [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth arm64-encoder/X0
							instruction/a at (capacity - written)
						if encoded < 0 [return fail-code encoded 735 "compile-function/code#197"]
						written: written + encoded
					]
					depth: 0
					if region-link? [
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-load at (capacity - written)
							arm64-encoder/LR (0 - ((region-limit + 1) * 8)) 8 0 8
						if encoded < 0 [return fail-code encoded 736 "compile-function/code#198"]
						written: written + encoded
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/return-near at (capacity - written)
					if encoded < 0 [return fail-code encoded 737 "compile-function/code#199"]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_DROP [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
					][return fail-invalid 343 "compile-function/instruction/a#177"]
					if depth > 0 [depth: depth - 1]
				]
				instruction/op = OP_UNARY [
					unless all [
						instruction/a = NOT_OPERATION
						instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = VALUE
					][return fail-invalid 344 "compile-function/scratch/stack-kinds#178"]
					ref: scratch/stack-types/depth
					kind: type-kind ref view
					unless any [integer-type? ref view kind = 11][return fail-invalid 345 "compile-function/integer-type#179"]
					width: value-width ref view
					unless any [width = 1 width = 2 width = 4 width = 8][
						return fail-unsupported 346 "compile-function#180"
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
									return fail-invalid 347 "compile-function/folded#181"
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
						return fail-unsupported 348 "compile-function#182"
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth target ref
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 738 "compile-function/code#200"]
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
					if encoded < 0 [return fail-code encoded 739 "compile-function/code#201"]
					written: written + encoded
					if all [kind <> 11 width < 4][
						load-signed: either signed-type? ref view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							target target width load-signed
						if encoded < 0 [return fail-code encoded 740 "compile-function/code#202"]
						written: written + encoded
					]
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: target
					scratch/stack-high/depth: 0
					scratch/stack-flags/depth: 0
				]
				instruction/op = OP_BINARY [
					if depth < 2 [
						;-- Dead fallthrough after a no-return call: nothing
						;-- to operate on, emit nothing.
						index: index + 1
						continue
					]
					unless all [
						instruction/a >= ADD_OPERATION
						instruction/a <= LESS_EQUAL_OPERATION
						instruction/b >= 0 instruction/c >= 0 depth >= 2
					][return fail-unsupported 349 "compile-function/instruction/b#183"]
					source-slot: depth - 1
					unless all [
						scratch/stack-kinds/source-slot = VALUE
						scratch/stack-kinds/depth = VALUE
					][return fail-invalid 350 "compile-function/scratch/stack-kinds#184"]
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
							;-- A pointer difference between distinct address types
							;-- is a raw byte distance (x64 parity); the emitter
							;-- lowers it to an unscaled 64-bit subtract.
							operation = SUBTRACT_OPERATION
							address-type? right-ref view
						]
					]
					reference-comparison?: all [
						comparison?
						any [
							all [
								reference-type? left-ref view
								reference-type? right-ref view
								same-reference-category?
									(type-kind left-ref view)
									(type-kind right-ref view)
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
							;-- Null and function-type comparisons resolve
							;-- through the structural type compatibility
							;-- (its kind-14 branch pairs null with any
							;-- reference), matching the x64 gate.
							all [
								compatible-types? left-ref right-ref view
								any [
									operation <= NOT_EQUAL_OPERATION
									all [
										(type-kind left-ref view) <> 14
										(type-kind right-ref view) <> 14
										(type-kind left-ref view) <> -4
										(type-kind right-ref view) <> -4
									]
								]
								reference-type? left-ref view
							]
							;-- Integer-alias (-7) compared with a type it
							;-- is compatible with (x64 parity).
							all [
								any [
									all [
										(type-kind left-ref view) = -7
										compatible-types? right-ref left-ref view
									]
									all [
										(type-kind right-ref view) = -7
										compatible-types? left-ref right-ref view
									]
								]
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
					][return fail-invalid 351 "compile-function/address-type#185"]
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
						][return fail-invalid 352 "compile-function/overflow-anchor#186"]
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
						][return fail-invalid 353 "compile-function/floating#187"]
						kind: type-kind left-ref view
						case [
							operation <= MULTIPLY_OPERATION [
								unless all [
									instruction/c = 0
									integer-type? left-ref view
								][return fail-invalid 354 "compile-function/integer-type#188"]
							]
							operation <= MODULO_OPERATION [
								unless all [instruction/c = 0 kind = 5][
									return fail-invalid 355 "compile-function/instruction/c#189"
								]
							]
							operation = SHIFT_LEFT_OPERATION [
								shift-count: either any [kind = 7 kind = 8][63][31]
								unless all [
									instruction/c > 0
									instruction/c <= shift-count
								][return fail-invalid 356 "compile-function/instruction/c#190"]
								shift-count: instruction/c
							]
							true [return fail-invalid 357 "compile-function/instruction/c#191"]
						]
						; The landing pad resumes the scope's stack, so the slots
						; it keeps must be in their canonical registers before
						; any operand move can set the flags.
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: canonicalize-stack view scratch base-depth
							region-base region-limit at (capacity - written)
						if encoded < 0 [return fail-code encoded 741 "compile-function/code#203"]
						written: written + encoded
						unless merge-control-target overflow-target base-depth fn
							view scratch instruction-depths entry-types
							entry-kinds entry-flags [return fail-invalid 358 "compile-function/entry-kinds#192"]
					][
						if instruction/c <> 0 [return fail-invalid 359 "compile-function/instruction/c#193"]
					]
					if floating? [
						width: value-width operation-ref view
						target: FIRST_FLOAT_TEMP_REGISTER + source-slot - 1
						if target >= (FIRST_FLOAT_TEMP_REGISTER
							+ FLOAT_TEMP_REGISTER_COUNT)[return fail-limit 360 "compile-function/float-temporary-limit"]
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
							if encoded < 0 [return fail-code encoded 742 "compile-function/code#204"]
							written: written + encoded
							right: FLOAT_SCRATCH_REGISTER
							right-ready?: true
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot target
							operation-ref at (capacity - written)
						if encoded < 0 [return fail-code encoded 743 "compile-function/code#205"]
						written: written + encoded
						if all [right = FLOAT_SCRATCH_REGISTER not right-ready?][
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth right operation-ref
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 744 "compile-function/code#206"]
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
						if encoded < 0 [return fail-code encoded 745 "compile-function/code#207"]
						written: written + encoded
						depth: source-slot
						scratch/stack-types/depth: either comparison? [-11][operation-ref]
						scratch/stack-kinds/depth: VALUE
						either comparison? [
							condition: float-comparison-condition operation
							if condition < 0 [return fail-invalid 361 "compile-function/condition#195"]
							;-- The flags are one single resource, so the result
							;-- moves out of them before anything else can set them
							;-- again: into the slot's register, or, on a stack too
							;-- deep for that, into the region spill slot.
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER
								+ TEMP_REGISTER_COUNT)[
								if (region-base + depth) > region-limit [
									return fail-invalid 362 "compile-function/region-base#196"
								]
								target: arm64-encoder/X17
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/condition-result at
								(capacity - written) target condition
							if encoded < 0 [return fail-code encoded 746 "compile-function/code#208"]
							written: written + encoded
							either target = arm64-encoder/X17 [
								displacement: 0 - ((region-base + depth) * 8)
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: compiler-frame-store at
									(capacity - written) target displacement 8
								if encoded < 0 [return fail-code encoded 747 "compile-function/code#209"]
								written: written + encoded
								scratch/stack-locations/depth: LOCATION_FRAME
								scratch/stack-low/depth: displacement
							][
								scratch/stack-locations/depth: LOCATION_REGISTER
								scratch/stack-low/depth: target
							]
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
					][return fail-unsupported 363 "compile-function/result-width#197"]
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
						;-- Deep-stack fallback for the common integer
						;-- operations: the depth-indexed result register does
						;-- not exist, so compute with the fixed scratch
						;-- registers and park the result in the region spill
						;-- slot for the left operand.
						if any [floating? tracked?] [return fail-unsupported 364 "compile-function/floating#198"]
						if (region-base + source-slot) > region-limit [
							return fail-invalid 365 "compile-function/region-base#199"
						]
						if pointer? [
							;-- Pointer arithmetic scales by the pointee
							;-- stride; compute into the fixed scratch
							;-- register and park the result.
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: emit-pointer-binary view layout scratch
								source-slot depth arm64-encoder/X16 operation
								at (capacity - written)
							if encoded < 0 [return fail-code encoded 748 "compile-function/code#210"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-register at
								(capacity - written) arm64-encoder/X17
								arm64-encoder/X16 8
							if encoded < 0 [return fail-code encoded 749 "compile-function/code#211"]
							written: written + encoded
							depth: source-slot
							scratch/stack-types/depth: left-ref
							scratch/stack-kinds/depth: VALUE
							scratch/stack-locations/depth: LOCATION_FRAME
							scratch/stack-low/depth: 0 - ((region-base + depth) * 8)
							scratch/stack-high/depth: 0
							scratch/stack-flags/depth: 0
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: compiler-frame-store at
								(capacity - written) arm64-encoder/X17
								scratch/stack-low/depth 8
							if encoded < 0 [return fail-code encoded 750 "compile-function/code#212"]
							written: written + encoded
							last-math-condition: -1
							index: index + 1
							continue
						]
						;-- Both operands are copied into the fixed scratch
						;-- registers instead of being used where they lie: the
						;-- result lands in the right operand's register, and on
						;-- a stack this deep that register can be a local's home
						;-- -- writing it would silently rewrite the local.
						left: arm64-encoder/X16
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot left left-ref
							at (capacity - written)
						if encoded < 0 [return fail-code encoded 751 "compile-function/code#213"]
						written: written + encoded
						right: arm64-encoder/X17
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth right right-ref
							at (capacity - written)
						if encoded < 0 [return fail-code encoded 752 "compile-function/code#214"]
						written: written + encoded
						either comparison? [
							condition: case [
								operation = EQUAL_OPERATION [arm64-encoder/EQ]
								operation = NOT_EQUAL_OPERATION [arm64-encoder/NE]
								operation = GREATER_OPERATION [arm64-encoder/GT]
								operation = LESS_OPERATION [arm64-encoder/LT]
								operation = GREATER_EQUAL_OPERATION [arm64-encoder/GE]
								operation = LESS_EQUAL_OPERATION [arm64-encoder/LE]
								true [return fail-unsupported 366 "compile-function/operation#200"]
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-register at
								(capacity - written) left right width
							if encoded < 0 [return fail-code encoded 753 "compile-function/code#215"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/condition-result at
								(capacity - written) right condition
							if encoded < 0 [return fail-code encoded 754 "compile-function/code#216"]
							written: written + encoded
							depth: source-slot
							scratch/stack-types/depth: -11
						][
							unless any [
								operation = ADD_OPERATION
								operation = SUBTRACT_OPERATION
								operation = MULTIPLY_OPERATION
							][return fail-unsupported 367 "compile-function/operation#201"]
							at: either null? code [as byte-ptr! 0][code + written]
							case [
								operation = ADD_OPERATION [
									encoded: arm64-encoder/add-register at
										(capacity - written) right left right width
								]
								operation = SUBTRACT_OPERATION [
									encoded: arm64-encoder/subtract-register at
										(capacity - written) right left right width
								]
								true [
									encoded: arm64-encoder/multiply-register at
										(capacity - written) right left right width
								]
							]
							if encoded < 0 [return fail-code encoded 755 "compile-function/code#217"]
							written: written + encoded
							depth: source-slot
							scratch/stack-types/depth: left-ref
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: compiler-frame-store at
							(capacity - written) right
							(0 - ((region-base + depth) * 8)) 8
						if encoded < 0 [return fail-code encoded 756 "compile-function/code#218"]
						written: written + encoded
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_FRAME
						scratch/stack-low/depth: 0 - ((region-base + depth) * 8)
						scratch/stack-high/depth: 0
						scratch/stack-flags/depth: 0
						last-math-condition: -1
						index: index + 1
						continue
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
						if encoded < 0 [return fail-code encoded 757 "compile-function/code#219"]
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
						if encoded < 0 [return fail-code encoded 758 "compile-function/code#220"]
						written: written + encoded
					]
					if all [operation = SHIFT_LOGICAL_OPERATION result-width < 4][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							arm64-encoder/X16 left result-width 0
						if encoded < 0 [return fail-code encoded 759 "compile-function/code#221"]
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
									if encoded < 0 [return fail-code encoded 760 "compile-function/code#222"]
									written: written + encoded
								]
								right-ready?: true
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-negative-immediate
									at (capacity - written) right 1 width
								if encoded < 0 [return fail-code encoded 761 "compile-function/code#223"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/NE 12
								if encoded < 0 [return fail-code encoded 762 "compile-function/code#224"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-immediate at
									(capacity - written) left 1 width
								if encoded < 0 [return fail-code encoded 763 "compile-function/code#225"]
								written: written + encoded
								displacement: either null? code [0][
									instruction-offsets/overflow-target - written
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/VS displacement
								if encoded < 0 [return fail-code encoded 764 "compile-function/code#226"]
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
								][return fail-invalid 368 "compile-function/scratch/stack-low#202"]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/shift-immediate at
									(capacity - written) arm64-encoder/SHIFT_LEFT
									arm64-encoder/X17 left shift-count width
								if encoded < 0 [return fail-code encoded 765 "compile-function/code#227"]
								written: written + encoded
								condition: either load-signed = 1 [
									arm64-encoder/SHIFT_ARITHMETIC
								][arm64-encoder/SHIFT_RIGHT]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/shift-immediate at
									(capacity - written) condition arm64-encoder/X17
									arm64-encoder/X17 shift-count width
								if encoded < 0 [return fail-code encoded 766 "compile-function/code#228"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/compare-register at
									(capacity - written) arm64-encoder/X17 left width
								if encoded < 0 [return fail-code encoded 767 "compile-function/code#229"]
								written: written + encoded
								displacement: either null? code [0][
									instruction-offsets/overflow-target - written
								]
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-condition at
									(capacity - written) arm64-encoder/NE displacement
								if encoded < 0 [return fail-code encoded 768 "compile-function/code#230"]
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
								if encoded < 0 [return fail-code encoded 769 "compile-function/code#231"]
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
									if encoded < 0 [return fail-code encoded 770 "compile-function/code#232"]
									written: written + encoded
									left: arm64-encoder/X16
								]
								if right = target [
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: arm64-encoder/move-register at
										(capacity - written) arm64-encoder/X17 right width
									if encoded < 0 [return fail-code encoded 771 "compile-function/code#233"]
									written: written + encoded
									right: arm64-encoder/X17
								]
								at: either null? code [as byte-ptr! 0][code + written]
								load-signed: either signed-type? left-ref view [1][0]
								encoded: arm64-encoder/divide-register at
									(capacity - written) target left right width
									load-signed
								if encoded < 0 [return fail-code encoded 772 "compile-function/code#234"]
								written: written + encoded
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/multiply-subtract at
									(capacity - written) target target right left width
								if encoded < 0 [return fail-code encoded 773 "compile-function/code#235"]
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
					if encoded < 0 [return fail-code encoded 774 "compile-function/code#236"]
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
						if encoded < 0 [return fail-code encoded 775 "compile-function/code#237"]
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
							if encoded < 0 [return fail-code encoded 776 "compile-function/code#238"]
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
							if encoded < 0 [return fail-code encoded 777 "compile-function/code#239"]
							written: written + encoded
							displacement: either null? code [0][
								instruction-offsets/overflow-target - written
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-condition at
								(capacity - written) arm64-encoder/NE displacement
							if encoded < 0 [return fail-code encoded 778 "compile-function/code#240"]
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
						if encoded < 0 [return fail-code encoded 779 "compile-function/code#241"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/conditional-negate at
								(capacity - written) arm64-encoder/X16 right width
								arm64-encoder/MI
						if encoded < 0 [return fail-code encoded 780 "compile-function/code#242"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/compare-immediate at
							(capacity - written) target 0 width
						if encoded < 0 [return fail-code encoded 781 "compile-function/code#243"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/conditional-select at
							(capacity - written) arm64-encoder/X16 arm64-encoder/X16
								arm64-encoder/ZR
							width arm64-encoder/MI
						if encoded < 0 [return fail-code encoded 782 "compile-function/code#244"]
						written: written + encoded
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/add-register at
							(capacity - written) target target arm64-encoder/X16 width
						if encoded < 0 [return fail-code encoded 783 "compile-function/code#245"]
						written: written + encoded
					]
					if all [not comparison? result-width < 4][
						load-signed: either signed-type? left-ref view [1][0]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/extend-register at (capacity - written)
							target target result-width load-signed
						if encoded < 0 [return fail-code encoded 784 "compile-function/code#246"]
						written: written + encoded
					]
					depth: source-slot
					scratch/stack-types/depth: either comparison? [-11][left-ref]
					scratch/stack-kinds/depth: VALUE
					either comparison? [
						condition: comparison-condition operation (signed-type? left-ref view)
						if condition < 0 [return fail-invalid 369 "compile-function/condition#203"]
						;-- The flags are one single resource, so the result
						;-- leaves them right away for the slot's register.
						target: FIRST_TEMP_REGISTER + depth - 1
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/condition-result at
							(capacity - written) target condition
						if encoded < 0 [return fail-code encoded 785 "compile-function/code#247"]
						written: written + encoded
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: target
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
					][return fail-unsupported 370 "compile-function/instruction/c#204"]
						either plan/catch-capacity = 0 [
							if instruction/c <> 0 [return fail-invalid 371 "compile-function/instruction/c#205"]
						][
							target-catch-depth: catch-depths/target
							expected-catch-depth: current-catch-depth - instruction/c
							unless all [
								instruction/c <= current-catch-depth
								(target-catch-depth - expected-catch-depth) = 0
						][return fail-invalid 372 "compile-function/target-catch-depth#206"]
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						region-base region-limit at (capacity - written)
					if encoded < 0 [return fail-code encoded 786 "compile-function/code#248"]
					written: written + encoded
					catch-level: catch-depths/ordinal
					catch-unwind: instruction/c
					while [catch-unwind > 0][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: emit-catch-restore plan at (capacity - written)
							catch-level
						if encoded < 0 [return fail-code encoded 787 "compile-function/code#249"]
						written: written + encoded
						catch-level: catch-level - 1
						catch-unwind: catch-unwind - 1
					]
					;-- A no-value sub-return tolerates one leftover stack
					;-- slot, so a path arriving with depth 1 merges as 0.
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + target - 1)
							* RSIR_INSTRUCTION_SIZE))
					if all [
						target > 0 target <= fn/instruction-count
						sub-entry/op = OP_SUB_RETURN
						sub-entry/a = 0
						depth = 1
					][depth: 0]
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return fail-invalid 373 "compile-function/instruction-depths#207"
					]
					displacement: either null? code [0][
						instruction-offsets/target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at
						(capacity - written) displacement
					if encoded < 0 [return fail-code encoded 788 "compile-function/code#250"]
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
					][return fail-invalid 374 "compile-function/scratch/stack-types#208"]
					source-slot: depth
					if all [
						depth > 1
						scratch/stack-locations/source-slot <> LOCATION_IMMEDIATE
					][
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch source-slot arm64-encoder/X17
							-11 at (capacity - written)
						if encoded < 0 [return fail-code encoded 789 "compile-function/code#251"]
						written: written + encoded
						scratch/stack-locations/source-slot: LOCATION_REGISTER
						scratch/stack-low/source-slot: arm64-encoder/X17
						scratch/stack-high/source-slot: 0
					]
					depth: depth - 1
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						region-base region-limit at (capacity - written)
					if encoded < 0 [return fail-code encoded 790 "compile-function/code#252"]
					written: written + encoded
					;-- A no-value sub-return tolerates one leftover stack
					;-- slot, so a path arriving with depth 1 merges as 0.
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + target - 1)
							* RSIR_INSTRUCTION_SIZE))
					if all [
						target > 0 target <= fn/instruction-count
						sub-entry/op = OP_SUB_RETURN
						sub-entry/a = 0
						depth = 1
					][depth: 0]
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return fail-invalid 375 "compile-function/instruction-depths#209"
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
						true [return fail-invalid 376 "compile-function/instruction/b#210"]
					]
					if encoded < 0 [return fail-code encoded 791 "compile-function/code#253"]
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
					][return fail-invalid 377 "compile-function/scratch/stack-types#211"]
					ref: scratch/stack-types/depth
					width: value-width ref view
					result-width: either width = 8 [8][4]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch depth arm64-encoder/X17 ref
						at (capacity - written)
					if encoded < 0 [return fail-code encoded 792 "compile-function/code#254"]
					written: written + encoded
					depth: depth - 1
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: canonicalize-stack view scratch depth
						region-base region-limit at (capacity - written)
					if encoded < 0 [return fail-code encoded 793 "compile-function/code#255"]
					written: written + encoded
					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (view/switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						unless merge-control-target target depth fn view scratch
							instruction-depths entry-types entry-kinds entry-flags [
							return fail-invalid 378 "compile-function/instruction-depths#212"
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
							if encoded < 0 [return fail-code encoded 794 "compile-function/code#256"]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/compare-register at
								(capacity - written) arm64-encoder/X17
								arm64-encoder/X16 result-width
						]
						if encoded < 0 [return fail-code encoded 795 "compile-function/code#257"]
						written: written + encoded
						displacement: either null? code [0][
							instruction-offsets/target - written
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/branch-condition at
							(capacity - written) arm64-encoder/EQ displacement
						if encoded < 0 [return fail-code encoded 796 "compile-function/code#258"]
						written: written + encoded
						case-index: case-index + 1
					]
					target: instruction/c
					;-- A no-value sub-return tolerates one leftover stack
					;-- slot, so a path arriving with depth 1 merges as 0.
					sub-entry: as rsir-instruction! (view/instructions
						+ ((first-instruction + target - 1)
							* RSIR_INSTRUCTION_SIZE))
					if all [
						target > 0 target <= fn/instruction-count
						sub-entry/op = OP_SUB_RETURN
						sub-entry/a = 0
						depth = 1
					][depth: 0]
					unless merge-control-target target depth fn view scratch
						instruction-depths entry-types entry-kinds entry-flags [
						return fail-invalid 379 "compile-function/instruction-depths#213"
					]
					displacement: either null? code [0][
						instruction-offsets/target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at
						(capacity - written) displacement
					if encoded < 0 [return fail-code encoded 797 "compile-function/code#259"]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0 instruction/b = 0 instruction/c = 0
					][return fail-invalid 380 "compile-function/instruction/a#214"]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/trap at (capacity - written)
					if encoded < 0 [return fail-code encoded 798 "compile-function/code#260"]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_RETURN [
					if any [
						instruction/a <> fn/return-type
						instruction/c <> 0
						all [instruction/a = 0 instruction/b <> 0]
					][return fail-invalid 381 "compile-function/instruction/a#215"]
					either instruction/a = 0 [
						if depth <> 0 [return fail-invalid 382 "compile-function/depth#216"]
						if entry? [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/move-immediate at
								(capacity - written) arm64-encoder/X0 4 0 0
							if encoded < 0 [return fail-code encoded 799 "compile-function/code#261"]
							written: written + encoded
						]
					][
						unless all [
							depth = 1 instruction/b = 0
							implicitly-compatible? instruction/a scratch/stack-types/depth
								(scratch/stack-locations/depth = LOCATION_IMMEDIATE) view
						][return fail-invalid 383 "compile-function/scratch/stack-locations#217"]
						either (fn/flags and RETURN_VALUE) <> 0 [
							return-size: 0
							return-align: 0
							unless layout-type instruction/a true view layout 0
								:return-size :return-align [return fail-invalid 384 "compile-function/return-size#218"]
							if any [return-size <= 0 return-align <= 0 return-align > 16][
								return fail-unsupported 385 "compile-function/return-size#219"
							]
							return-hfa-kind: 0
							return-hfa-count: 0
							hfa-return?: classify-hfa instruction/a INLINE view 0
								:return-hfa-kind :return-hfa-count
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X15
								instruction/a at (capacity - written)
							if encoded < 0 [return fail-code encoded 800 "compile-function/code#262"]
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
										if encoded < 0 [return fail-code encoded 801 "compile-function/code#263"]
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
										if encoded < 0 [return fail-code encoded 802 "compile-function/code#264"]
										written: written + encoded
										return-chunk-offset: return-chunk-offset + 8
										case-index: case-index + 1
									]
								]
								true [
									if plan/hidden-return-offset = 0 [return fail-invalid 386 "compile-function/plan/hidden-return-offset#220"]
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: compiler-frame-load at
										(capacity - written) arm64-encoder/X14
										plan/hidden-return-offset 8 0 8
									if encoded < 0 [return fail-code encoded 803 "compile-function/code#265"]
									written: written + encoded
									at: either null? code [as byte-ptr! 0][code + written]
									encoded: emit-memory-copy at (capacity - written)
										arm64-encoder/X14 arm64-encoder/X15 return-size
									if encoded < 0 [return fail-code encoded 804 "compile-function/code#266"]
									written: written + encoded
								]
							]
						][
							if aggregate-ref? instruction/a view [
								unless all [
									scratch/stack-flags/depth = 0
									(value-width instruction/a view) = 8
								][return fail-invalid 387 "compile-function/instruction/a#221"]
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X0
								instruction/a at (capacity - written)
							if encoded < 0 [return fail-code encoded 805 "compile-function/code#267"]
							written: written + encoded
						]
						depth: 0
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-epilogue plan at (capacity - written)
					if encoded < 0 [return fail-code encoded 806 "compile-function/code#268"]
					written: written + encoded
					return-count: return-count + 1
					fallthrough?: false
				]
				true [return fail-unsupported 388 "compile-function/fallthrough#222"]
			]
			index: index + 1
		]
		either not fallthrough? [written][fail-invalid 866 "compile-function/invalid#274"]
	]

	release: func [memory [byte-ptr!] result [integer!] return: [integer!]][
		if not null? memory [free memory]
		result
	]

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity abi opt-level [integer!]
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
			ir-line [rsir-line-record!]
			file-entry [rsir-file-entry!]
			image-line [codegen-line-record!]
			img-entry [rsir-file-entry!]
			memory code names cursor finish image-globals image-imports image-exports
				rodata-output data-output debug-cursor img-table [byte-ptr!]
		function-sizes function-offsets function-frames bitmap-offsets bitmap-sizes
			function-unwind instruction-starts global-offsets global-sizes
				global-owners global-children global-siblings [int-ptr!]
		id first-instruction written code-size code-cursor
			metadata-size names-size code-offset rodata-offset data-offset
			data-size total-size name-cursor entry-id storage-count bitmap-base bitmap-size
			rodata-size reference-count line-offset debug-size fn-id record-index
				pass emitted img-offset [integer!]
			max-storage max-instructions words status member-id
		target-count target-id used-import-count last-library
			library-offset external-offset output-import-id [integer!]
			index changed callee-unwind unwind-value [integer!]
			entry? startup? startup-entry? unwind? is-entry match? [logic!]
	][
		codegen-diag/reset
		unless any [abi = ABI_APPLE_AARCH64 abi = ABI_AAPCS64][
			return fail-unsupported 393 "generate/abi"
		]
		target-abi: abi
		if any [null? output capacity < 0][return fail-invalid 390 "generate/output#1"]
		unless any [opt-level = 0 opt-level = 2][return fail-unsupported 391 "generate/opt-level#2"]
		status: codegen-rsir-reader/open data size view
		if status <> 0 [return status]
		header: view/header
		codegen-diag/bind-module header view/functions view/lines view/file-table view/strings
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
		if header/function-count > (2147483647 / 7)[return fail-limit 867 "generate/limit#9"]
		words: header/function-count * 7
		if max-storage > ((2147483647 - words) / 3)[return fail-limit 868 "generate/limit#10"]
		words: words + (max-storage * 3)
		if max-instructions > ((2147483647 - words) / 9)[return fail-limit 869 "generate/limit#11"]
		words: words + (max-instructions * 9)
		if header/instruction-count > ((2147483647 - words) / 9)[
			return fail-limit 870 "generate/limit#12"
		]
		words: words + (header/instruction-count * 9)
		if header/switch-count > ((2147483647 - words) / 2)[return fail-limit 871 "generate/limit#13"]
		words: words + (header/switch-count * 2)
		if header/global-count > ((2147483647 - words) / 6)[return fail-limit 872 "generate/limit#14"]
		words: words + (header/global-count * 6)
		if header/function-count > (2147483647 - header/global-count)[
			return fail-limit 873 "generate/limit#15"
		]
		target-count: header/function-count + header/global-count
		if target-count > (2147483647 - header/import-count)[return fail-limit 874 "generate/limit#16"]
		target-count: target-count + header/import-count
		if target-count > ((2147483647 - words) / 3)[return fail-limit 875 "generate/limit#17"]
		words: words + (target-count * 3)
		if header/type-count > ((2147483647 - words) / 2)[return fail-limit 876 "generate/limit#18"]
		words: words + (header/type-count * 2)
		if view/member-count > (2147483647 - words)[return fail-limit 877 "generate/limit#19"]
		words: words + view/member-count
		if words > (2147483647 / 4)[return fail-limit 878 "generate/limit#20"]
		memory: allocate words * 4
		if null? memory [return fail-memory 879 "generate/memory#21"]
		function-sizes: as int-ptr! memory
		function-offsets: function-sizes + header/function-count
		function-frames: function-offsets + header/function-count
		function-unwind: function-frames + header/function-count
		instruction-starts: function-unwind + header/function-count
		bitmap-offsets: instruction-starts + header/function-count
		bitmap-sizes: bitmap-offsets + header/function-count
		scratch/homes: bitmap-sizes + header/function-count
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
			codegen-diag/mark-phase "plan"
			codegen-diag/mark-function id
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
		if status < 0 [return release memory fail-code status 807 "generate/code#1"]
		status: prepare-control-targets view scratch
		if status < 0 [return release memory fail-code status 808 "generate/code#2"]

		data-size: 16
		rodata-size: 0
		status: prepare-global-data view layout reference-state
			global-offsets global-sizes global-owners global-children global-siblings
			:data-size :rodata-size
		if status < 0 [return release memory fail-code status 809 "generate/code#3"]

		bitmap-base: align data-size 8
		if any [bitmap-base < 0 bitmap-base > (2147483647 - 4)][return release memory fail-limit 880 "generate/limit#22"]
		bitmap-base: bitmap-base + 4
		bitmap-size: 0
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
			if status < 0 [return release memory fail-code status 810 "generate/code#4"]
			plan/bitmap-index: bitmap-size / 4
			bitmap-offsets/id: bitmap-base + bitmap-size
			bitmap-sizes/id: stack-bitmap/record-size plan/bitmap-slots
			if any [
				bitmap-size > ((0FFFFFFFh * 4) - bitmap-sizes/id)
				bitmap-sizes/id > (2147483647 - bitmap-base - bitmap-size)
			][return release memory fail-limit 881 "generate/limit#23"]
			bitmap-size: bitmap-size + bitmap-sizes/id
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
			codegen-diag/mark-phase "measure"
			codegen-diag/mark-function id
			written: compile-function view layout fn first-instruction entry?
				startup-entry? scratch plan reference-state as int-ptr! 0 0 null 0
			if written < 0 [return release memory fail-code written 811 "generate/code#5"]
			function-sizes/id: written
			if code-size > (2147483647 - written)[return release memory fail-limit 882 "generate/limit#24"]
			code-size: code-size + written
			first-instruction: first-instruction + fn/instruction-count
			id: id + 1
		]
		codegen-diag/mark-phase "layout"
		data-size: bitmap-base + bitmap-size
		reference-count: 0
		id: 1
		while [id <= target-count][
			reference-state/starts/id: either reference-state/counts/id > 0 [
				reference-count + 1
			][0]
			if reference-count > (2147483647 - reference-state/counts/id)[
				return release memory fail-limit 883 "generate/limit#25"
			]
			reference-count: reference-count + reference-state/counts/id
			id: id + 1
		]
		used-import-count: 0
		id: 1
		while [id <= header/import-count][
			target-id: header/function-count + header/global-count + id
			if reference-state/counts/target-id > 0 [
				if used-import-count = 2147483647 [return release memory fail-limit 884 "generate/limit#26"]
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
			return release memory fail-limit 885 "generate/limit#27"
		]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > ((2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return release memory fail-limit 886 "generate/limit#28"
		]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if used-import-count > ((2147483647 - metadata-size) / IMAGE_IMPORT_SIZE)[
			return release memory fail-limit 887 "generate/limit#29"
		]
		metadata-size: metadata-size + (used-import-count * IMAGE_IMPORT_SIZE)
		if header/export-count > ((2147483647 - metadata-size) / IMAGE_EXPORT_SIZE)[
			return release memory fail-limit 888 "generate/limit#30"
		]
		metadata-size: metadata-size + (header/export-count * IMAGE_EXPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release memory fail-limit 889 "generate/limit#31"
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			if names-size > (2147483647 - fn/name-size)[
				return release memory fail-limit 890 "generate/limit#32"
			]
			names-size: names-size + fn/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if names-size > (2147483647 - global/name-size)[
				return release memory fail-limit 891 "generate/limit#33"
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
						return release memory fail-limit 892 "generate/limit#34"
					]
					names-size: names-size + imported/library-size
					last-library: imported/library
				]
				if names-size > (2147483647 - imported/external-size)[
					return release memory fail-limit 893 "generate/limit#35"
				]
				names-size: names-size + imported/external-size
			]
			id: id + 1
		]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if names-size > (2147483647 - exported/name-size)[
				return release memory fail-limit 894 "generate/limit#36"
			]
			names-size: names-size + exported/name-size
			id: id + 1
		]
		if metadata-size > (2147483647 - names-size - 15)[
			return release memory fail-limit 895 "generate/limit#37"
		]
		code-offset: align (metadata-size + names-size) 16
		if any [code-offset < 0 code-offset > (2147483647 - code-size - 3)][
			return release memory fail-limit 896 "generate/limit#38"
		]
		rodata-offset: align (code-offset + code-size) 4
		if rodata-offset > (2147483647 - rodata-size - 3)[
			return release memory fail-limit 897 "generate/limit#39"
		]
		data-offset: align (rodata-offset + rodata-size) 4
		if data-offset > (2147483647 - data-size)[return release memory fail-limit 898 "generate/limit#40"]
		; Debug builds append the sparse line records and the source file table
				; with their name bytes directly after the data section. Without them
				; the image still ends at the data section's last byte.
		line-offset: align (data-offset + data-size) 4
		debug-size: (header/line-record-count * 12) + (header/file-count * 8)
		either debug-size > 0 [
			if debug-size > (2147483647 - line-offset)[return release memory fail-limit 899 "generate/limit#41"]
			id: 1
			while [id <= header/file-count][
				file-entry: as rsir-file-entry! (view/file-table + ((id - 1) * RSIR_FILE_ENTRY_SIZE))
				if debug-size > (2147483647 - file-entry/name-size)[
					return release memory fail-limit 900 "generate/limit#42"
				]
				debug-size: debug-size + file-entry/name-size
				id: id + 1
			]
			total-size: line-offset + debug-size
		][
			total-size: data-offset + data-size
		]
		if capacity < total-size [return release memory fail-output total-size capacity 812 "generate/output-capacity"]

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
		image/line-record-count: header/line-record-count
		image/file-count: header/file-count

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
			image-function/bitmap-offset: bitmap-offsets/id
			image-function/bitmap-size: bitmap-sizes/id
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
				image-import/flags: imported/flags
				output-import-id: output-import-id + 1
			]
			id: id + 1
		]
		if output-import-id <> used-import-count [return release memory fail-mismatch used-import-count output-import-id 901 "generate/import-count-mismatch"]
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
			codegen-diag/mark-phase "plan"
			codegen-diag/mark-function id
			status: plan-function view layout fn instruction-starts/id startup-entry?
				unwind? scratch plan
			if status < 0 [return release memory fail-code status 813 "generate/code#6"]
			plan/bitmap-index: (bitmap-offsets/id - bitmap-base) / 4
			unless write-frame-bitmap (as int-ptr! (output + data-offset + bitmap-offsets/id))
				view layout fn scratch plan [return release memory fail-internal 902 "generate/bitmap-plan"]
			codegen-diag/mark-phase "emit"
			codegen-diag/mark-function id
			written: compile-function view layout fn instruction-starts/id
				entry? startup-entry? scratch plan reference-state
				function-offsets function-offsets/id
				(code + function-offsets/id) function-sizes/id
			if written < 0 [return release memory fail-code written 814 "generate/code#7"]
			if written <> function-sizes/id [
				return release memory fail-mismatch function-sizes/id written 815 "generate/emission-size-mismatch"
			]
			id: id + 1
		]
		codegen-diag/mark-phase "metadata"
		rodata-output: output + rodata-offset
		data-output: output + data-offset
		status: write-global-data view reference-state global-offsets global-sizes
			rodata-output data-output
		if status < 0 [return release memory fail-code status 816 "generate/code#8"]
		id: 1
		while [id <= target-count][
			if reference-state/cursors/id <> reference-state/counts/id [
				return release memory fail-mismatch reference-state/counts/id reference-state/cursors/id 817 "generate/reference-count-mismatch"
			]
			id: id + 1
		]
		; Mirror the RSIR debug line records into the image: 12-byte
				; [code-offset line file-id] entries with 1-based code offsets, then the
				; source file table and its name bytes. The runtime scans records by
				; ascending code address, and the entry function occupies offset zero,
				; so emit the entry function's records first, then the rest in id order.
		if header/line-record-count > 0 [
			debug-cursor: output + line-offset
			entry-id: either header/module-kind = 3 [header/entry-function][0]
			pass: 0
			emitted: 0
			while [pass < 2][
				fn-id: 1
				id: 1
				while [fn-id <= header/function-count][
					is-entry: fn-id = entry-id
					match?: either pass = 0 [is-entry][not is-entry]
					while [id <= header/line-record-count][
						ir-line: as rsir-line-record! (view/lines + ((id - 1) * RSIR_LINE_SIZE))
						if ir-line/function-id <> fn-id [break]
						if match? [
							record-index: instruction-starts/fn-id + ir-line/instruction-index
							image-line: as codegen-line-record! debug-cursor
							image-line/code-offset: function-offsets/fn-id
								+ scratch/instruction-offsets/record-index + 1
							image-line/line: ir-line/line
							image-line/file-id: ir-line/file-id
							debug-cursor: debug-cursor + 12
							emitted: emitted + 1
						]
						id: id + 1
					]
					fn-id: fn-id + 1
				]
				pass: pass + 1
			]
			if emitted <> header/line-record-count [return release memory fail-mismatch header/line-record-count emitted 903 "generate/line-record-count-mismatch"]
			; Write the image's own file table with offsets into the name blob
			; that follows it, then copy the file names out of the RSIR strings.
			img-table: debug-cursor
			debug-cursor: debug-cursor + (header/file-count * RSIR_FILE_ENTRY_SIZE)
			img-offset: 0
			id: 1
			while [id <= header/file-count][
				file-entry: as rsir-file-entry! (view/file-table
					+ ((id - 1) * RSIR_FILE_ENTRY_SIZE))
				copy-memory (debug-cursor + img-offset)
					(view/strings + file-entry/name-offset) file-entry/name-size
				img-entry: as rsir-file-entry! (img-table + ((id - 1) * RSIR_FILE_ENTRY_SIZE))
				img-entry/name-offset: img-offset
				img-entry/name-size: file-entry/name-size
				img-offset: img-offset + file-entry/name-size
				id: id + 1
			]
		]
		release memory total-size
	]
]
