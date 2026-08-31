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
	instruction-offsets [int-ptr!]
	global-homes    [int-ptr!]
]

arm64-function-plan!: alias struct! [
	storage-count   [integer!]
	home-count      [integer!]
	frame-home-count [integer!]
	spill-count     [integer!]
	has-call        [integer!]
	frame-allocation [integer!]
]

arm64-layout-state!: alias struct! [
	sizes          [int-ptr!]
	alignments     [int-ptr!]
	member-offsets [int-ptr!]
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

	CDECL:        1
	STDCALL:      2
	RETURN_VALUE: 4
	INLINE:       1
	PROTECTED:    2
	TAGGED_UNION: 1

	SCALAR_INITIALIZER:  1
	ADDRESS_INITIALIZER: 2
	BYTES_INITIALIZER:   3
	DATA_REFERENCE_TAG:   80000000h
	RODATA_REFERENCE_TAG: C0000000h
	REFERENCE_OFFSET_MASK: 3FFFFFFFh

	OP_LITERAL: 1
	OP_ADDRESS: 3
	OP_LOAD:    4
	OP_SET:     5
	OP_MEMBER:  6
	OP_CALL:    7
	OP_CAST:    8
	OP_RETURN:  11
	OP_DROP:    12
	OP_UNARY:  14
	OP_BINARY:  15
	OP_JUMP:    16
	OP_BRANCH:  17
	OP_REFERENCE: 20
	OP_INDEX:     21

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
	FUNCTION_ADDRESS: 4

	VALUE: 1
	PLACE: 2

	LOCATION_IMMEDIATE: 1
	LOCATION_REGISTER:  2
	LOCATION_FLAGS:     3
	LOCATION_FRAME:     4

	STORAGE_REGISTER: 1
	STORAGE_FRAME:    2

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

	valid-type-ref?: func [ref [integer!] view [rsir-view!] return: [logic!]][
		any [
			all [ref > 0 ref <= view/header/type-count]
			all [ref < 0 ref >= -15]
		]
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

	integer-type?: func [ref [integer!] view [rsir-view!] return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind ref view
		all [kind >= 1 kind <= 8]
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
		view [rsir-view!]
		return: [logic!]
		/local expected-kind actual-kind [integer!]
	][
		if compatible-types? expected actual view [return true]
		expected-kind: type-kind expected view
		actual-kind: type-kind actual view
		integer-kind-widens? actual-kind expected-kind
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
			source-kind = 9 source-kind = 10
			target-kind = 9 target-kind = 10
		][return false]
		any [
			all [integer-type? source view integer-type? target view]
			all [source-kind = 11 any [integer-type? target view target-kind = 11]]
			all [target-kind = 11 integer-type? source view]
			all [reference-type? source view reference-type? target view]
			all [
				reference-type? source view
				address-integer-kind? target-kind
				target-width = 8
			]
			all [
				address-integer-kind? source-kind
				source-width = 8
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
		target [integer!]
		view [rsir-view!]
		return-ref-out first-parameter-out parameter-count-out
			reference-target-out [int-ptr!]
		return: [integer!]
		/local callee [rsir-function!]
			imported [rsir-import!]
			import-id return-ref flags first-parameter parameter-count [integer!]
	][
		if target = 0 [return UNSUPPORTED]
		either target > 0 [
			if target > view/header/function-count [return INVALID_IR]
			callee: as rsir-function! (view/functions
				+ ((target - 1) * RSIR_FUNCTION_SIZE))
			return-ref: callee/return-type
			flags: callee/flags
			first-parameter: callee/first-parameter
			parameter-count: callee/parameter-count
			reference-target-out/1: 0
		][
			if target < (0 - view/header/import-count)[return INVALID_IR]
			import-id: 0 - target
			if import-id = 0 [return INVALID_IR]
			imported: as rsir-import! (view/imports
				+ ((import-id - 1) * RSIR_IMPORT_SIZE))
			unless any [imported/flags = CDECL imported/flags = STDCALL][
				return UNSUPPORTED
			]
			return-ref: imported/type
			flags: imported/flags
			first-parameter: imported/first-parameter
			parameter-count: imported/parameter-count
			reference-target-out/1: view/header/function-count
				+ view/header/global-count + import-id
		]
		if all [return-ref <> 0 not valid-type-ref? return-ref view][
			return INVALID_IR
		]
		if (flags and RETURN_VALUE) <> 0 [return UNSUPPORTED]
		return-ref-out/1: return-ref
		first-parameter-out/1: first-parameter
		parameter-count-out/1: parameter-count
		0
	]

	prepare-global-data: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		references [arm64-reference-state!]
		global-offsets global-sizes [int-ptr!]
		data-size-out rodata-size-out [int-ptr!]
		return: [integer!]
		/local global [rsir-global!]
			array-type [rsir-type!]
			initializer [rsir-initializer!]
			id initializer-id base kind global-size global-align
			global-offset target-id status data-size rodata-size [integer!]
			inline? array? [logic!]
	][
		data-size: data-size-out/1
		rodata-size: rodata-size-out/1
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
			global-offsets/id: global-offset
			id: id + 1
		]
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

	plan-function: func [
		view [rsir-view!]
		fn [rsir-function!]
		first-instruction [integer!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			instruction [rsir-instruction!]
			id slot count width kind home-count frame-allocation
			depth max-spill has-call argument-count frame-home-count total-slots status
			call-return call-first-parameter call-parameter-count
			call-reference
				[integer!]
	][
		if (fn/flags and RETURN_VALUE) <> 0 [return UNSUPPORTED]
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
		depth: 0
		max-spill: 0
		has-call: 0
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
						if parameter/flags <> 0 [return UNSUPPORTED]
						if scratch/storage-kinds/slot = 0 [
							scratch/storage-kinds/slot: STORAGE_REGISTER
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
					true [return UNSUPPORTED]
				]
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
				instruction/op = OP_REFERENCE [
					if depth < 1 [return INVALID_IR]
					slot: scratch/stack-low/depth
					if slot > 0 [scratch/storage-kinds/slot: STORAGE_FRAME]
				]
				instruction/op = OP_MEMBER [
					if depth < 1 [return INVALID_IR]
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
					if any [
						argument-count < 0
						argument-count > depth
					][return INVALID_IR]
					call-return: 0
					call-first-parameter: 0
					call-parameter-count: 0
					call-reference: 0
					status: resolve-call instruction/a view :call-return
						:call-first-parameter :call-parameter-count :call-reference
					if status < 0 [return status]
					if any [
						argument-count <> call-parameter-count
						instruction/c <> call-return
					][return INVALID_IR]
					has-call: 1
					if (depth - argument-count) > max-spill [
						max-spill: depth - argument-count
					]
					depth: depth - argument-count
					if call-return <> 0 [
						depth: depth + 1
						scratch/stack-low/depth: 0
					]
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
		frame-home-count: 0
		id: 1
		while [id <= count][
			if scratch/storage-kinds/id = STORAGE_REGISTER [
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
			if scratch/storage-kinds/id = STORAGE_FRAME [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + id - 1) * RSIR_PARAMETER_SIZE))
				width: value-width parameter/type view
				kind: type-kind parameter/type view
				if width = 0 [return INVALID_IR]
				if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
				if all [id <= fn/parameter-count id > 8][return UNSUPPORTED]
				frame-home-count: frame-home-count + 1
				scratch/homes/id: 0 - frame-home-count
			]
			id: id + 1
		]
		id: 1
		while [id <= view/header/global-count][
			either scratch/global-homes/id > 1 [
				either home-count < HOME_REGISTER_COUNT [
					home-count: home-count + 1
					scratch/global-homes/id: FIRST_HOME_REGISTER + home-count - 1
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
				scratch/homes/id: 0 - ((home-count + slot) * 8)
			]
			id: id + 1
		]
		if home-count > (2147483647 - frame-home-count)[return OUTPUT_FULL]
		total-slots: home-count + frame-home-count
		if total-slots > (2147483647 - max-spill)[return OUTPUT_FULL]
		total-slots: total-slots + max-spill
		if total-slots > (2147483647 / 8) [return OUTPUT_FULL]
		frame-allocation: align (total-slots * 8) 16
		if frame-allocation < 0 [return OUTPUT_FULL]
		plan/storage-count: fn/parameter-count + fn/local-count
		plan/home-count: home-count
		plan/frame-home-count: frame-home-count
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
			written encoded index slot width transfer-width target signed [integer!]
	][
		if all [
			plan/home-count = 0
			plan/frame-home-count = 0
			plan/has-call = 0
		][return 0]
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
			if target <> 0 [
				parameter: as rsir-parameter! (view/parameters
					+ ((fn/first-parameter + slot - 1) * RSIR_PARAMETER_SIZE))
				width: value-width parameter/type view
				transfer-width: either width = 8 [8][4]
				at: either null? code [as byte-ptr! 0][code + written]
				encoded: either target > 0 [
					either width < 4 [
						signed: either signed-type? parameter/type view [1][0]
						arm64-encoder/extend-register at (capacity - written)
							target (slot - 1) width signed
					][
						arm64-encoder/move-register at (capacity - written)
							target (slot - 1) transfer-width
					]
				][
					arm64-encoder/frame-store at (capacity - written)
						(slot - 1) target width
				]
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
		if all [
			plan/home-count = 0
			plan/frame-home-count = 0
			plan/has-call = 0
		][
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
		/local source-ref source-width target-width operation-width signed high [integer!]
	][
		if scratch/stack-kinds/stack-slot <> VALUE [return INVALID_IR]
		source-ref: scratch/stack-types/stack-slot
		source-width: value-width source-ref view
		target-width: value-width target-ref view
		if any [
			source-width = 0 source-width > 8
			target-width = 0 target-width > 8
		][return UNSUPPORTED]
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
				arm64-encoder/frame-load code capacity target
					scratch/stack-low/stack-slot source-width signed operation-width
			]
			true [INVALID_IR]
		]
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
			left-ref right-ref source-width stride shift scaled high opcode
			written encoded right immediate source-signed [integer!]
	][
		unless any [operation = ADD_OPERATION operation = SUBTRACT_OPERATION][
			return INVALID_IR
		]
		left-ref: scratch/stack-types/left-slot
		right-ref: scratch/stack-types/right-slot
		stride: pointer-stride left-ref view layout
		if stride <= 0 [return UNSUPPORTED]
		written: 0
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: materialize view scratch left-slot target left-ref
			at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
		if scratch/stack-locations/right-slot = LOCATION_IMMEDIATE [
			high: either scratch/stack-low/right-slot < 0 [-1][0]
			if scratch/stack-high/right-slot <> high [return UNSUPPORTED]
			if any [
				all [
					scratch/stack-low/right-slot < 0
					scratch/stack-low/right-slot < (80000000h / stride)
				]
				all [
					scratch/stack-low/right-slot >= 0
					scratch/stack-low/right-slot > (7FFFFFFFh / stride)
				]
			][return UNSUPPORTED]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: materialize view scratch right-slot right right-ref
			at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
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

	compile-function: func [
		view [rsir-view!]
		layout [arm64-layout-state!]
		fn [rsir-function!]
		first-instruction [integer!]
		entry? [logic!]
		scratch [arm64-function-scratch!]
		plan [arm64-function-plan!]
		references [arm64-reference-state!]
		function-offsets [int-ptr!]
		function-base [integer!]
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
		/local instruction next-instruction following-instruction [rsir-instruction!]
			parameter [rsir-parameter!]
			global [rsir-global!]
			at [byte-ptr!]
			index ordinal written encoded depth slot source-slot target-slot
			ref target-ref left-ref right-ref width kind operation target left right folded
			source-width target-width source-kind target-kind
			displacement condition argument-count argument-base argument-slot
			call-target call-return call-first-parameter
			call-parameter-count call-reference status load-signed result-width
				[integer!]
			member-type member-flags member-offset stride scaled shift
				[integer!]
			returned? comparison? literal? immediate? taken? pointer? [logic!]
	][
		written: emit-prologue view fn scratch plan code capacity
		if written < 0 [return written]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-global-homes view scratch (function-base + written)
			references at (capacity - written)
		if encoded < 0 [return encoded]
		written: written + encoded
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
							scratch/stack-flags/depth: 0
						]
						instruction/a = GLOBAL_ADDRESS [
							unless all [
								slot > 0
								slot <= view/header/global-count
								instruction/c = 0
							][return INVALID_IR]
							global: as rsir-global! (view/globals
								+ ((slot - 1) * RSIR_GLOBAL_SIZE))
							scratch/stack-types/depth: global/type
							target: scratch/global-homes/slot
							if target <= 0 [
								target: FIRST_TEMP_REGISTER + depth - 1
								if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
									return UNSUPPORTED
								]
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
							scratch/stack-flags/depth: global/flags and PROTECTED
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
							if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							load-signed: either signed-type? ref view [1][0]
							result-width: either width = 8 [8][4]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-load at
								(capacity - written) target scratch/stack-low/depth
								scratch/stack-high/depth width
								load-signed result-width arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							width: value-width ref view
							kind: type-kind ref view
							if width = 0 [return INVALID_IR]
							if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
							load-signed: either signed-type? ref view [1][0]
							result-width: either width = 8 [8][4]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/frame-load at
								(capacity - written) target scratch/stack-low/depth
								width load-signed result-width
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
					case [
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
							unless implicitly-compatible? target-ref ref view [return INVALID_IR]
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
							unless implicitly-compatible? target-ref ref view [return INVALID_IR]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return INVALID_IR]
							if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
							target: either (scratch/stack-locations/source-slot
								= LOCATION_REGISTER) [scratch/stack-low/source-slot][
								arm64-encoder/X17
							]
							if target = arm64-encoder/X17 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch source-slot target
									target-ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/register-store at
								(capacity - written) target scratch/stack-low/depth
								scratch/stack-high/depth width arm64-encoder/X16
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						scratch/stack-locations/depth = LOCATION_FRAME [
							if (scratch/stack-flags/depth and PROTECTED) <> 0 [
								return INVALID_IR
							]
							target-ref: scratch/stack-types/depth
							unless implicitly-compatible? target-ref ref view [return INVALID_IR]
							width: value-width target-ref view
							kind: type-kind target-ref view
							if width = 0 [return INVALID_IR]
							if any [width > 8 kind = 9 kind = 10][return UNSUPPORTED]
							target: either (scratch/stack-locations/source-slot
								= LOCATION_REGISTER) [
								scratch/stack-low/source-slot
							][arm64-encoder/X17]
							if target = arm64-encoder/X17 [
								at: either null? code [as byte-ptr! 0][code + written]
								encoded: materialize view scratch source-slot target
									target-ref at (capacity - written)
								if encoded < 0 [return encoded]
								written: written + encoded
							]
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: arm64-encoder/frame-store at
								(capacity - written) target scratch/stack-low/depth width
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
						target: FIRST_TEMP_REGISTER + depth - 1
						if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
							return UNSUPPORTED
						]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: arm64-encoder/address-offset at (capacity - written)
							target arm64-encoder/FP scratch/stack-low/depth
							arm64-encoder/X16
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					][
						target: scratch/stack-low/depth
						if scratch/stack-high/depth <> 0 [
							target: FIRST_TEMP_REGISTER + depth - 1
							if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
								return UNSUPPORTED
							]
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
					target: FIRST_TEMP_REGISTER + target-slot - 1
					if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
						return UNSUPPORTED
					]
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
							encoded: materialize view scratch target-slot target ref
								at (capacity - written)
							if encoded < 0 [return encoded]
							written: written + encoded
							at: either null? code [as byte-ptr! 0][code + written]
							encoded: materialize view scratch depth arm64-encoder/X17
								scratch/stack-types/depth at (capacity - written)
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
					if any [depth <= 0 instruction/b <> 0 instruction/c <> 0][
						return UNSUPPORTED
					]
					ref: scratch/stack-types/depth
					unless any [
						scratch/stack-kinds/depth = PLACE
						all [
							scratch/stack-kinds/depth = VALUE
							any [(type-kind ref view) = -2 (type-kind ref view) = -3]
						]
					][return INVALID_IR]
					member-type: 0
					member-flags: 0
					member-offset: 0
					unless layout-member ref instruction/a view layout
						:member-type :member-flags :member-offset [return INVALID_IR]
					case [
						scratch/stack-locations/depth = LOCATION_REGISTER [
							if scratch/stack-high/depth > (2147483647 - member-offset)[
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
								target: FIRST_TEMP_REGISTER + depth - 1
								if target >= (FIRST_TEMP_REGISTER + TEMP_REGISTER_COUNT)[
									return UNSUPPORTED
								]
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
				]
				instruction/op = OP_CALL [
					call-target: instruction/a
					argument-count: instruction/b
					if any [argument-count < 0 argument-count > depth][
						return INVALID_IR
					]
					call-return: 0
					call-first-parameter: 0
					call-parameter-count: 0
					call-reference: 0
					status: resolve-call call-target view :call-return
						:call-first-parameter :call-parameter-count :call-reference
					if status < 0 [return status]
					if call-return <> 0 [
						width: value-width call-return view
						kind: type-kind call-return view
						if any [width = 0 width > 8 kind = 9 kind = 10][
							return UNSUPPORTED
						]
					]
					unless all [
						argument-count = call-parameter-count
						argument-count <= 8
						instruction/c = call-return
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
								unless any [
									width = 1 width = 2 width = 4 width = 8
								][return UNSUPPORTED]
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
							displacement: 0 - ((
								plan/home-count + plan/frame-home-count + slot
							) * 8)
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
							+ ((call-first-parameter + slot - 1)
								* RSIR_PARAMETER_SIZE))
						if parameter/flags <> 0 [return UNSUPPORTED]
						ref: scratch/stack-types/argument-slot
						unless implicitly-compatible? parameter/type ref view [
							return INVALID_IR
						]
							width: value-width parameter/type view
							kind: type-kind parameter/type view
							unless any [
								width = 1 width = 2 width = 4 width = 8
							][return UNSUPPORTED]
						if any [kind = 9 kind = 10][return UNSUPPORTED]
						at: either null? code [as byte-ptr! 0][code + written]
						encoded: materialize view scratch argument-slot (slot - 1)
							parameter/type at (capacity - written)
						if encoded < 0 [return encoded]
						written: written + encoded
						slot: slot - 1
					]
					displacement: 0
					either call-target > 0 [
						if not null? code [
							target: function-offsets/call-target
							displacement: target - function-base
							displacement: displacement - written
						]
					][
						status: record-reference call-reference
							(function-base + written) references
						if status < 0 [return status]
					]
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: arm64-encoder/call-relative at
						(capacity - written) displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: argument-base
					if call-return <> 0 [
						width: value-width call-return view
						if width < 4 [
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
						instruction/b = 0 instruction/c = 0 depth >= 2
					][return UNSUPPORTED]
					source-slot: depth - 1
					unless all [
						scratch/stack-kinds/source-slot = VALUE
						scratch/stack-kinds/depth = VALUE
					][return INVALID_IR]
					left-ref: scratch/stack-types/source-slot
					right-ref: scratch/stack-types/depth
					operation: instruction/a
					pointer?: all [
						any [operation = ADD_OPERATION operation = SUBTRACT_OPERATION]
						address-type? left-ref view
						integer-type? right-ref view
					]
					unless any [
						pointer?
						all [
							integer-type? left-ref view
							integer-type? right-ref view
							compatible-literal? left-ref right-ref view
						]
					][return INVALID_IR]
					result-width: either pointer? [8][value-width left-ref view]
					unless any [
						result-width = 1 result-width = 2
						result-width = 4 result-width = 8
					][return UNSUPPORTED]
					width: either result-width = 8 [8][4]
					comparison?: operation >= EQUAL_OPERATION
					folded: 0
					if all [
						not pointer?
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
							implicitly-compatible? instruction/a
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
			memory code names cursor finish image-globals image-imports image-exports
				rodata-output data-output [byte-ptr!]
			function-sizes function-offsets function-frames
				instruction-starts global-offsets global-sizes [int-ptr!]
			id first-instruction written code-size code-cursor
			metadata-size names-size code-offset rodata-offset data-offset
			data-size total-size name-cursor entry-id storage-count
			rodata-size reference-count
			max-storage max-instructions words status member-id
			target-count target-id used-import-count last-library
			library-offset external-offset output-import-id [integer!]
			entry? [logic!]
	][
		if any [null? output capacity < 0][return INVALID_IR]
		unless any [opt-level = 0 opt-level = 2][return UNSUPPORTED]
		if (codegen-rsir-reader/open data size view) <> 0 [return INVALID_IR]
		header: view/header
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
		if max-storage > ((2147483647 - words) / 3)[return OUTPUT_FULL]
		words: words + (max-storage * 3)
		if max-instructions > ((2147483647 - words) / 7)[return OUTPUT_FULL]
		words: words + (max-instructions * 7)
		if header/global-count > ((2147483647 - words) / 3)[return OUTPUT_FULL]
		words: words + (header/global-count * 3)
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
		instruction-starts: function-frames + header/function-count
		scratch/homes: instruction-starts + header/function-count
		scratch/storage-types: scratch/homes + max-storage
		scratch/storage-kinds: scratch/storage-types + max-storage
		scratch/stack-types: scratch/storage-kinds + max-storage
		scratch/stack-kinds: scratch/stack-types + max-instructions
		scratch/stack-locations: scratch/stack-kinds + max-instructions
		scratch/stack-low: scratch/stack-locations + max-instructions
		scratch/stack-high: scratch/stack-low + max-instructions
		scratch/stack-flags: scratch/stack-high + max-instructions
		scratch/instruction-offsets: scratch/stack-flags + max-instructions
		scratch/global-homes: scratch/instruction-offsets + max-instructions
		global-offsets: scratch/global-homes + header/global-count
		global-sizes: global-offsets + header/global-count
		reference-state/counts: global-sizes + header/global-count
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

		if header/function-count > (2147483647 / BITMAP_SIZE)[
			return release memory OUTPUT_FULL
		]
		data-size: header/function-count * BITMAP_SIZE
		rodata-size: 0
		status: prepare-global-data view layout reference-state
			global-offsets global-sizes :data-size :rodata-size
		if status < 0 [return release memory status]

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
				plan/frame-home-count = 0
				plan/has-call = 0
			][0][
				16 + plan/frame-allocation
			]
			written: compile-function view layout fn first-instruction entry?
				scratch plan reference-state as int-ptr! 0 0 null 0
			if written < 0 [return release memory written]
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
			status: plan-function view fn instruction-starts/id scratch plan
			if status < 0 [return release memory status]
			written: compile-function view layout fn instruction-starts/id
				entry? scratch plan reference-state function-offsets function-offsets/id
				(code + function-offsets/id) function-sizes/id
			if written <> function-sizes/id [
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
