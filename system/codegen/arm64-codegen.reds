Red/System [
	Title: "Typed postfix RSIR to Apple AArch64 code generator"
	File:  %arm64-codegen.reds
]

#include %arm64-encoder.reds
#include %codegen-rsir-reader.reds

arm64-function-scratch!: alias struct! [
	homes           [int-ptr!]
	storage-types   [int-ptr!]
	stack-types     [int-ptr!]
	stack-kinds     [int-ptr!]
	stack-locations [int-ptr!]
	stack-low       [int-ptr!]
	stack-high      [int-ptr!]
	instruction-offsets [int-ptr!]
]

arm64-function-plan!: alias struct! [
	storage-count   [integer!]
	home-count      [integer!]
	spill-count     [integer!]
	has-call        [integer!]
	frame-allocation [integer!]
]

arm64-codegen: context [
	IMAGE_HEADER_SIZE:   52
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_EXPORT_SIZE:   12
	BITMAP_SIZE:         16

	RSIR_TYPE_SIZE:        20
	RSIR_FUNCTION_SIZE:    36
	RSIR_EXPORT_SIZE:      12
	RSIR_PARAMETER_SIZE:    8
	RSIR_INSTRUCTION_SIZE: 16

	RETURN_VALUE: 4

	OP_LITERAL: 1
	OP_ADDRESS: 3
	OP_LOAD:    4
	OP_SET:     5
	OP_CALL:    7
	OP_RETURN:  11
	OP_DROP:    12
	OP_BINARY:  15
	OP_JUMP:    16
	OP_BRANCH:  17

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

	LOCAL_ADDRESS: 1

	VALUE: 1
	PLACE: 2

	LOCATION_IMMEDIATE: 1
	LOCATION_REGISTER:  2
	LOCATION_FLAGS:     3
	LOCATION_FRAME:     4

	FIRST_HOME_REGISTER: 19
	HOME_REGISTER_COUNT: 10
	FIRST_TEMP_REGISTER: 9
	TEMP_REGISTER_COUNT: 7

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

	value-width: func [
		ref [integer!]
		view [rsir-view!]
		return: [integer!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		case [
			kind <= 0 [0]
			kind <= 2 [1]
			kind <= 4 [2]
			any [kind = 5 kind = 6 kind = 9 kind = 11][4]
			any [
				kind = 7 kind = 8 kind = 10 kind = 12
				kind = 13 kind = 14 kind = 16
			][8]
			true [0]
		]
	]

	integer-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		all [kind >= 1 kind <= 8]
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

	compatible-literal?: func [
		expected actual [integer!]
		view [rsir-view!]
		return: [logic!]
		/local left right [integer!]
	][
		if expected = actual [return true]
		left: canonical-type expected view
		right: canonical-type actual view
		all [left <> 0 left = right]
	]

	plan-function: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction [integer!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			callee [rsir-function!]
			instruction [rsir-instruction!]
			id slot count width kind home-count frame-allocation
			depth max-spill has-call argument-count [integer!]
	][
		if (fn/flags and RETURN_VALUE) <> 0 [return UNSUPPORTED]
		count: fn/parameter-count + fn/local-count
		id: 1
		while [id <= count][
			parameter: as rsir-parameter! (view/parameters
				+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
			scratch/homes/id: 0
			scratch/storage-types/id: parameter/type
			id: id + 1
		]
		depth: 0
		max-spill: 0
		has-call: 0
		id: 0
		while [id < fn/instruction-count][
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + id) * RSIR_INSTRUCTION_SIZE))
			if instruction/op = OP_ADDRESS [
				if instruction/a = LOCAL_ADDRESS [
					slot: instruction/b
					if any [slot <= 0 slot > count][return INVALID_IR]
					scratch/homes/slot: -1
				]
			]
			case [
				any [instruction/op = OP_LITERAL instruction/op = OP_ADDRESS][
					if depth = 2147483647 [return OUTPUT_FULL]
					depth: depth + 1
				]
				instruction/op = OP_LOAD []
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
					if any [
						instruction/a <= 0
						instruction/a > view/header/function-count
						argument-count < 0
						argument-count > depth
					][return UNSUPPORTED]
					callee: as rsir-function! (view/functions
						+ ((instruction/a - 1) * RSIR_FUNCTION_SIZE))
					if any [
						argument-count <> callee/parameter-count
						instruction/c <> callee/return-type
					][return INVALID_IR]
					has-call: 1
					if (depth - argument-count) > max-spill [
						max-spill: depth - argument-count
					]
					depth: depth - argument-count
					if callee/return-type <> 0 [depth: depth + 1]
				]
				instruction/op = OP_JUMP [
					if depth <> 0 [return UNSUPPORTED]
				]
				instruction/op = OP_BRANCH [
					if depth < 1 [return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_RETURN [
					unless any [
						all [instruction/a = 0 depth = 0]
						all [instruction/a <> 0 depth = 1]
					][return INVALID_IR]
					depth: 0
				]
				true []
			]
			id: id + 1
		]
		home-count: 0
		id: 1
		while [id <= count][
			if scratch/homes/id = -1 [
				if home-count = HOME_REGISTER_COUNT [return UNSUPPORTED]
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
				if parameter/flags <> 0 [return UNSUPPORTED]
				if parameter/type <> 0 [
					width: value-width parameter/type view
					kind: type-kind parameter/type view
					if width = 0 [return INVALID_IR]
					if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
				]
				if all [id <= fn/parameter-count id > 8][return UNSUPPORTED]
				home-count: home-count + 1
				scratch/homes/id: FIRST_HOME_REGISTER + home-count - 1
			]
			id: id + 1
		]
		if home-count > (2147483647 - max-spill) [return OUTPUT_FULL]
		count: home-count + max-spill
		if count > (2147483647 / 8) [return OUTPUT_FULL]
		frame-allocation: align (count * 8) 16
		if frame-allocation < 0 [return OUTPUT_FULL]
		plan/storage-count: fn/parameter-count + fn/local-count
		plan/home-count: home-count
		plan/spill-count: max-spill
		plan/has-call: has-call
		plan/frame-allocation: frame-allocation
		0
	]

	emit-prologue: func [
		view [rsir-view!]
		fn [rsir-function!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			at [byte-ptr!]
			written encoded index slot width target [integer!]
	][
		if all [plan/home-count = 0 plan/has-call = 0][return 0]
		written: arm64-encoder/frame-enter code capacity plan/frame-allocation
		if written < 0 [return OUTPUT_FULL]
		index: 0
		while [(index + 1) < plan/home-count][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/store-pair at (capacity - written)
				(FIRST_HOME_REGISTER + index) (FIRST_HOME_REGISTER + index + 1)
				arm64-encoder/FP (0 - ((index + 2) * 8))
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			index: index + 2
		]
		if index < plan/home-count [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/frame-store at (capacity - written)
				(FIRST_HOME_REGISTER + index) (0 - ((index + 1) * 8)) 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		slot: 1
		while [slot <= fn/parameter-count][
			target: scratch/homes/slot
			if target > 0 [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
				width: value-width parameter/type view
				width: either width = 8 [8][4]
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: arm64-encoder/move-register at (capacity - written)
					target (slot - 1) width
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			]
			slot: slot + 1
		]
		written
	]

	emit-epilogue: func [
		plan [arm64-function-plan!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local at [byte-ptr!] written encoded index [integer!]
	][
		if all [plan/home-count = 0 plan/has-call = 0][
			return arm64-encoder/return-near code capacity
		]
		written: 0
		index: 0
		while [(index + 1) < plan/home-count][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/load-pair at (capacity - written)
				(FIRST_HOME_REGISTER + index) (FIRST_HOME_REGISTER + index + 1)
				arm64-encoder/FP (0 - ((index + 2) * 8))
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			index: index + 2
		]
		if index < plan/home-count [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: arm64-encoder/frame-load at (capacity - written)
				(FIRST_HOME_REGISTER + index) (0 - ((index + 1) * 8)) 8 0 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: arm64-encoder/frame-leave at (capacity - written)
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
		/local width [integer!]
	][
		if scratch/stack-kinds/stack-slot <> VALUE [return INVALID_IR]
		width: value-width target-ref view
		if any [width = 0 width > 8][return UNSUPPORTED]
		width: either width = 8 [8][4]
		case [
			scratch/stack-locations/stack-slot = LOCATION_IMMEDIATE [
				arm64-encoder/move-immediate code capacity target width
					scratch/stack-low/stack-slot scratch/stack-high/stack-slot
			]
			scratch/stack-locations/stack-slot = LOCATION_REGISTER [
				either scratch/stack-low/stack-slot = target [0][
					arm64-encoder/move-register code capacity target
						scratch/stack-low/stack-slot width
				]
			]
			scratch/stack-locations/stack-slot = LOCATION_FLAGS [
				arm64-encoder/condition-result code capacity target
					scratch/stack-low/stack-slot
			]
			scratch/stack-locations/stack-slot = LOCATION_FRAME [
				arm64-encoder/frame-load code capacity target
					scratch/stack-low/stack-slot width 0 width
			]
			true [INVALID_IR]
		]
	]

	compile-function: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction [integer!]
		entry? [logic!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		function-offsets [int-ptr!]
		function-base [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local instruction next-instruction following-instruction [rsir-instruction!]
			parameter [rsir-parameter!]
			callee [rsir-function!]
			at [byte-ptr!]
			index ordinal written encoded depth slot source-slot target-slot
			ref target-ref left-ref right-ref width kind operation target left right folded
			displacement condition argument-count argument-base argument-slot
			call-target [integer!]
			returned? comparison? literal? immediate? signed? taken? [logic!]
	][
		written: emit-prologue view fn scratch plan code capacity
		if written < 0 [return written]
		depth: 0
		returned?: false
		index: 0
		while [index < fn/instruction-count][
			ordinal: index + 1
			scratch/instruction-offsets/ordinal: written
			instruction: as rsir-instruction! (view/instructions
				+ ((first-instruction + index) * RSIR_INSTRUCTION_SIZE))
			if returned? [return INVALID_IR]
			case [
				instruction/op = OP_LITERAL [
					width: value-width instruction/a view
					kind: type-kind instruction/a view
					if width = 0 [return INVALID_IR]
					if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
					depth: depth + 1
					scratch/stack-types/depth: instruction/a
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_IMMEDIATE
					scratch/stack-low/depth: instruction/b
					scratch/stack-high/depth: instruction/c
				]
				instruction/op = OP_ADDRESS [
					slot: instruction/b
					unless all [
						instruction/a = LOCAL_ADDRESS
						slot > 0
						slot <= plan/storage-count
						instruction/c = 0
						scratch/homes/slot > 0
					][return UNSUPPORTED]
					depth: depth + 1
					scratch/stack-types/depth: scratch/storage-types/slot
					scratch/stack-kinds/depth: PLACE
					scratch/stack-locations/depth: 0
					scratch/stack-low/depth: slot
					scratch/stack-high/depth: 0
				]
				instruction/op = OP_LOAD [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 0 scratch/stack-kinds/depth = PLACE
					][return INVALID_IR]
					slot: scratch/stack-low/depth
					ref: scratch/storage-types/slot
					if ref = 0 [return INVALID_IR]
					scratch/stack-types/depth: ref
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: scratch/homes/slot
				]
				instruction/op = OP_SET [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth >= 2 scratch/stack-kinds/depth = PLACE
					][return INVALID_IR]
					source-slot: depth - 1
					if scratch/stack-kinds/source-slot <> VALUE [return INVALID_IR]
					target-slot: scratch/stack-low/depth
					ref: scratch/stack-types/source-slot
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
					unless compatible-literal? target-ref ref view [return INVALID_IR]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: materialize view scratch source-slot
						scratch/homes/target-slot target-ref at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					depth: source-slot
					scratch/stack-types/depth: target-ref
					scratch/stack-kinds/depth: VALUE
					scratch/stack-locations/depth: LOCATION_REGISTER
					scratch/stack-low/depth: scratch/homes/target-slot
					scratch/stack-high/depth: 0
				]
				instruction/op = OP_CALL [
					call-target: instruction/a
					argument-count: instruction/b
					unless all [
						call-target > 0
						call-target <= view/header/function-count
						argument-count >= 0
						argument-count <= depth
					][return UNSUPPORTED]
					callee: as rsir-function! (view/functions
						+ ((call-target - 1) * RSIR_FUNCTION_SIZE))
					unless all [
						argument-count = callee/parameter-count
						argument-count <= 8
						instruction/c = callee/return-type
						(callee/flags and RETURN_VALUE) = 0
					][return INVALID_IR]
					argument-base: depth - argument-count
					if plan/spill-count < argument-base [return INVALID_IR]
					slot: 1
					while [slot <= argument-base][
						if any [
							scratch/stack-locations/slot = LOCATION_FLAGS
							all [
								scratch/stack-locations/slot = LOCATION_REGISTER
								scratch/stack-low/slot < FIRST_HOME_REGISTER
							]
						][
							ref: scratch/stack-types/slot
							width: value-width ref view
							unless any [width = 4 width = 8][return UNSUPPORTED]
							target: either scratch/stack-locations/slot = LOCATION_REGISTER [
								scratch/stack-low/slot
							][
								arm64-encoder/X17
							]
							if target = arm64-encoder/X17 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch slot target ref
									at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							displacement: 0 - ((plan/home-count + slot) * 8)
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/frame-store at
								(capacity - written) target displacement width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							scratch/stack-locations/slot: LOCATION_FRAME
							scratch/stack-low/slot: displacement
							scratch/stack-high/slot: 0
						]
						slot: slot + 1
					]
					slot: argument-count
					while [slot > 0][
						argument-slot: argument-base + slot
						if scratch/stack-kinds/argument-slot <> VALUE [return INVALID_IR]
						parameter: as rsir-parameter! (view/parameters
							+ ((callee/first-parameter + slot - 1)
								* RSIR_PARAMETER_SIZE))
						if parameter/flags <> 0 [return UNSUPPORTED]
						ref: scratch/stack-types/argument-slot
						unless compatible-literal? parameter/type ref view [
							return INVALID_IR
						]
						width: value-width parameter/type view
						kind: type-kind parameter/type view
						unless any [width = 4 width = 8][return UNSUPPORTED]
						if any [kind = 9 kind = 10][return UNSUPPORTED]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch argument-slot (slot - 1)
							parameter/type at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						slot: slot - 1
					]
					displacement: 0
					if not null? code [
						call-target: instruction/a
						target: function-offsets/call-target
						displacement: target - function-base
						displacement: displacement - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/call-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: argument-base
					if callee/return-type <> 0 [
						depth: depth + 1
						scratch/stack-types/depth: callee/return-type
						scratch/stack-kinds/depth: VALUE
						scratch/stack-locations/depth: LOCATION_REGISTER
						scratch/stack-low/depth: arm64-encoder/X0
						scratch/stack-high/depth: 0
					]
				]
				instruction/op = OP_DROP [
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0 depth > 0
					][return INVALID_IR]
					depth: depth - 1
				]
				instruction/op = OP_BINARY [
					unless all [
						instruction/a >= ADD_OPERATION
						instruction/a <= LESS_EQUAL_OPERATION
						instruction/b = 0 instruction/c = 0 depth >= 2
					][return UNSUPPORTED]
					source-slot: depth - 1
					unless all [
						scratch/stack-kinds/source-slot = VALUE
						scratch/stack-kinds/depth = VALUE
					][return INVALID_IR]
					left-ref: scratch/stack-types/source-slot
					right-ref: scratch/stack-types/depth
					unless all [
						integer-type? left-ref view
						integer-type? right-ref view
						compatible-literal? left-ref right-ref view
					][return INVALID_IR]
					width: value-width left-ref view
					unless any [width = 4 width = 8][return UNSUPPORTED]
					operation: instruction/a
					comparison?: operation >= EQUAL_OPERATION
					if any [operation = DIVIDE_OPERATION
						operation = REMAINDER_OPERATION operation = MODULO_OPERATION][
						return UNSUPPORTED
					]
					folded: 0
					if all [
						width = 4
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
						index: index + 1
						continue
					]
					target: FIRST_TEMP_REGISTER + source-slot - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
					if all [not comparison? (index + 2) < fn/instruction-count][
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
					encoded: -1
					case [
						operation = ADD_OPERATION [
							if immediate? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-immediate at
									(capacity - written) target left
									scratch/stack-low/depth width
							]
						]
						operation = SUBTRACT_OPERATION [
							if immediate? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/add-immediate at
									(capacity - written) target left
									(0 - scratch/stack-low/depth) width
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
						right: arm64-encoder/X17
						either scratch/stack-locations/depth = LOCATION_REGISTER [
							right: scratch/stack-low/depth
						][
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth right right-ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: case [
							operation = ADD_OPERATION [
								arm64-encoder/add-register at (capacity - written)
									target left right width
							]
							operation = SUBTRACT_OPERATION [
								arm64-encoder/subtract-register at (capacity - written)
									target left right width
							]
							operation = MULTIPLY_OPERATION [
								arm64-encoder/multiply-register at (capacity - written)
									target left right width
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
				]
				instruction/op = OP_JUMP [
					target: instruction/a
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/b = 0 instruction/c = 0 depth = 0
					][return UNSUPPORTED]
					displacement: either null? code [0][
						scratch/instruction-offsets/target - written
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/branch-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_BRANCH [
					target: instruction/a
					unless all [
						target > 0 target <= fn/instruction-count
						any [instruction/b = 0 instruction/b = 1]
						instruction/c = 0 depth > 0
						compatible-literal? -11 scratch/stack-types/depth view
					][return INVALID_IR]
					displacement: either null? code [0][
						scratch/instruction-offsets/target - written
					]
					encoded: 0
					case [
						scratch/stack-locations/depth = LOCATION_IMMEDIATE [
							taken?: either instruction/b = 1 [
								scratch/stack-low/depth <> 0
							][scratch/stack-low/depth = 0]
							if taken? [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: arm64-encoder/branch-relative at
									(capacity - written) displacement
							]
						]
						scratch/stack-locations/depth = LOCATION_FLAGS [
							condition: scratch/stack-low/depth
							if instruction/b = 0 [condition: condition xor 1]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-condition at
								(capacity - written) condition displacement
						]
						scratch/stack-locations/depth = LOCATION_REGISTER [
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/branch-zero at
								(capacity - written) scratch/stack-low/depth 4
								displacement (instruction/b = 1)
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1
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
							compatible-literal? instruction/a
								scratch/stack-types/depth view
						][return INVALID_IR]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch depth arm64-encoder/X0
							instruction/a at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						depth: 0
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: emit-epilogue plan at (capacity - written)
					if encoded < 0 [return encoded]
					written: written + encoded
					returned?: true
				]
				true [return UNSUPPORTED]
			]
			index: index + 1
		]
		either returned? [written][INVALID_IR]
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
			header [rsir-header!]
			fn [rsir-function!]
			exported [rsir-export!]
			image [codegen-header!]
			image-function [codegen-function!]
			image-export [codegen-export!]
			memory code names cursor finish [byte-ptr!]
			function-sizes function-offsets function-frames
				instruction-starts [int-ptr!]
			id first-instruction written code-size code-cursor
			metadata-size names-size code-offset rodata-offset data-offset
			data-size total-size name-cursor entry-id storage-count
			max-storage max-instructions words status [integer!]
			entry? [logic!]
	][
		if any [null? output capacity < 0][return INVALID_IR]
		unless any [opt-level = 0 opt-level = 2][return UNSUPPORTED]
		if (codegen-rsir-reader/open data size view) <> 0 [return INVALID_IR]
		header: view/header
		if any [header/import-count <> 0 header/global-count <> 0][return UNSUPPORTED]
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
		if header/function-count > (2147483647 / 4)[return OUTPUT_FULL]
		words: header/function-count * 4
		if max-storage > ((2147483647 - words) / 2)[return OUTPUT_FULL]
		words: words + (max-storage * 2)
		if max-instructions > ((2147483647 - words) / 6)[return OUTPUT_FULL]
		words: words + (max-instructions * 6)
		if words > (2147483647 / 4)[return OUTPUT_FULL]
		memory: allocate words * 4
		if null? memory [return OUTPUT_FULL]
		function-sizes: as int-ptr! memory
		function-offsets: function-sizes + header/function-count
		function-frames: function-offsets + header/function-count
		instruction-starts: function-frames + header/function-count
		scratch/homes: instruction-starts + header/function-count
		scratch/storage-types: scratch/homes + max-storage
		scratch/stack-types: scratch/storage-types + max-storage
		scratch/stack-kinds: scratch/stack-types + max-instructions
		scratch/stack-locations: scratch/stack-kinds + max-instructions
		scratch/stack-low: scratch/stack-locations + max-instructions
		scratch/stack-high: scratch/stack-low + max-instructions
		scratch/instruction-offsets: scratch/stack-high + max-instructions

		code-size: 0
		first-instruction: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			instruction-starts/id: first-instruction
			entry?: all [header/module-kind = 3 id = header/entry-function]
			status: plan-function view fn first-instruction scratch plan
			if status < 0 [return release memory status]
			function-frames/id: either all [
				plan/home-count = 0
				plan/has-call = 0
			][0][
				16 + plan/frame-allocation
			]
			written: compile-function view fn first-instruction entry?
				scratch plan as int-ptr! 0 0 null 0
			if written < 0 [return release memory written]
			function-sizes/id: written
			if code-size > (2147483647 - written)[return release memory OUTPUT_FULL]
			code-size: code-size + written
			first-instruction: first-instruction + fn/instruction-count
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
		if header/export-count > ((2147483647 - metadata-size) / IMAGE_EXPORT_SIZE)[
			return release memory OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/export-count * IMAGE_EXPORT_SIZE)
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
		if header/function-count > (2147483647 / BITMAP_SIZE)[
			return release memory OUTPUT_FULL
		]
		data-size: header/function-count * BITMAP_SIZE
		data-offset: rodata-offset
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
		image/import-count: 0
		image/reference-count: 0
		image/names-size: names-size
		image/code-offset: code-offset
		image/code-size: code-size
		image/data-size: data-size
		image/global-count: 0
		image/rodata-size: 0
		image/export-count: header/export-count

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
			image-function/first-reference: 0
			image-function/reference-count: 0
			copy-memory (names + name-cursor) (view/strings + fn/name) fn/name-size
			name-cursor: name-cursor + fn/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			image-export: as codegen-export! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
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
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			entry?: all [header/module-kind = 3 id = header/entry-function]
			status: plan-function view fn instruction-starts/id scratch plan
			if status < 0 [return release memory status]
			written: compile-function view fn instruction-starts/id
				entry? scratch plan function-offsets function-offsets/id
				(code + function-offsets/id) function-sizes/id
			if written <> function-sizes/id [
				return release memory either written < 0 [written][INVALID_IR]
			]
			id: id + 1
		]
		release memory total-size
	]
]
