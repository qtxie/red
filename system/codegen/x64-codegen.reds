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
	switch-count      [integer!]
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
	name              [integer!]
	name-size         [integer!]
	type              [integer!]
	flags             [integer!]
	first-initializer [integer!]
	initializer-count [integer!]
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

rsir-initializer!: alias struct! [
	kind [integer!]
	a    [integer!]
	b    [integer!]
	c    [integer!]
]

rsir-instruction!: alias struct! [
	op [integer!]
	a  [integer!]
	b  [integer!]
	c  [integer!]
]

rsir-switch!: alias struct! [
	low    [integer!]
	high   [integer!]
	target [integer!]
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
	rodata-size     [integer!]
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
	flags           [integer!]
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
	RSIR_HEADER_SIZE:      32
	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_GLOBAL_SIZE:      24
	RSIR_FUNCTION_SIZE:    36
	RSIR_PARAMETER_SIZE:    8
	RSIR_INITIALIZER_SIZE: 16
	RSIR_SWITCH_SIZE:      12
	RSIR_INSTRUCTION_SIZE: 16

	IMAGE_HEADER_SIZE:   48
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   28
	IMAGE_IMPORT_SIZE:   24
	BITMAP_SIZE:         16

	RETURN_VALUE:  4
	VARIADIC:      8
	TYPED:        16
	CUSTOM:       32
	OBJC:        128
	CALL_SHAPE_FLAGS: RETURN_VALUE + VARIADIC + TYPED + CUSTOM + OBJC
	VARIABLE_FLAGS: 56
	CDECL:          1
	FUNCTION_FLAGS: 511
	INLINE:          1
	PROTECTED:       2
	TAGGED_UNION:    1
	DATA_REFERENCE_TAG:   80000000h
	RODATA_REFERENCE_TAG: C0000000h
	REFERENCE_OFFSET_MASK: 3FFFFFFFh
	SCALAR_INITIALIZER:  1
	ADDRESS_INITIALIZER: 2
	BYTES_INITIALIZER:   3

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
	OP_JUMP:     16
	OP_BRANCH:   17
	OP_SWITCH:   18
	OP_FAIL:     19
	OP_REFERENCE: 20
	OP_INDEX:     21
	OP_TAG:       22

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
			all [ref < 0 ref >= -14]
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

	array-ref?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
	][
		(logical-kind ref types count) = -7
	]

	inline-object-ref?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
	][
		any [
			aggregate-ref? ref types count
			array-ref? ref types count
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

	tagged-union?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local base [integer!] record [rsir-type!]
	][
		base: canonical-type ref types count
		if base <= 0 [return false]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		all [record/kind = -3 record/flags = TAGGED_UNION]
	]

	union-tag-width: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local base [integer!] record [rsir-type!]
	][
		base: canonical-type ref types count
		if base <= 0 [return 0]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		unless all [record/kind = -3 record/flags = TAGGED_UNION][return 0]
		tag-width record/member-count
	]

	reference-kind?: func [kind [integer!] return: [logic!]][
		any [
			kind = 12 kind = 13 kind = 14
			kind = -2 kind = -3 kind = -4 kind = -6 kind = -7
		]
	]

	address-kind?: func [kind [integer!] return: [logic!]][
		any [
			kind = 12 kind = 13
			kind = -2 kind = -3 kind = -6 kind = -7
		]
	]

	compatible-types?: func [
		expected actual [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local left right left-kind right-kind target [integer!]
			left-record right-record [rsir-type!]
	][
		if expected = actual [return true]
		left: canonical-type expected types count
		right: canonical-type actual types count
		if any [left = 0 right = 0][return false]
		if left = right [return true]
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		if any [left-kind = 14 right-kind = 14][
			return all [reference-kind? left-kind reference-kind? right-kind]
		]
		if all [right-kind = -7 right > 0][
			right-record: as rsir-type! (types + ((right - 1) * RSIR_TYPE_SIZE))
			target: 0
			case [
				left-kind = 13 [target: -2]
				all [left-kind = -6 left > 0][
					left-record: as rsir-type! (types + ((left - 1) * RSIR_TYPE_SIZE))
					target: left-record/target
				]
				true [0]
			]
			if all [
				target <> 0
				(canonical-type target types count)
					= (canonical-type right-record/target types count)
			][return true]
		]
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
		layouts member-offsets size-out align-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			cache offset-slot [int-ptr!]
			kind id mode member-size member-align size alignment tag-size
			payload-offset element-size element-align
				[integer!]
			cached? [logic!]
	][
		if any [ref = 0 depth > type-count][return false]
		cache: as int-ptr! 0
		cached?: false
		kind: 0
		either ref < 0 [
			kind: 0 - ref
		][
			if ref > type-count [return false]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			if not null? as byte-ptr! layouts [
				mode: either inline? [0][2]
				cache: layouts + (((ref - 1) * 4) + mode)
				if cache/1 <> 0 [
					if cache/1 < 0 [return false]
					size-out/1: cache/1
					align-out/1: cache/2
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
						kind = 7 kind = 8 kind = 10 kind = 12 kind = 13 kind = 14
					][8]
					true [0]
				]
				if size = 0 [return false]
				alignment: size
			]
			kind = -1 [
				unless layout-type record/target inline? types members type-count
					(depth + 1) layouts member-offsets :size :alignment [
					return false
				]
			]
			any [kind = -4 kind = -5 kind = -6][
				size: 8
				alignment: 8
			]
			kind = -7 [
				unless all [
					record/member-count > 0
					any [record/flags = 1 record/flags = 2
						record/flags = 4 record/flags = 8]
				][return false]
				either inline? [
					element-size: 0
					element-align: 0
					unless layout-type record/target false types members type-count
						(depth + 1) layouts member-offsets
						:element-size :element-align [return false]
					unless element-size = record/flags [return false]
					if record/member-count > (2147483647 / record/flags)[
						return false
					]
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
						member: as rsir-member! (members
							+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
						member-size: 0
						member-align: 0
						unless layout-type member/type (member/flags = INLINE)
							types members type-count (depth + 1) layouts member-offsets
							:member-size :member-align [return false]
						if member-align > alignment [alignment: member-align]
						either kind = -2 [
							size: align size member-align
							if any [
								size < 0
								size > (2147483647 - member-size)
							][return false]
							if not null? as byte-ptr! member-offsets [
								offset-slot: (member-offsets + record/first-member) + id
								offset-slot/1: size
							]
							size: size + member-size
						][
							if member-size > size [size: member-size]
							if all [
								record/flags = 0
								not null? as byte-ptr! member-offsets
							][
								offset-slot: (member-offsets + record/first-member) + id
								offset-slot/1: 0
							]
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
						if not null? as byte-ptr! member-offsets [
							offset-slot: member-offsets + record/first-member
							id: 0
							while [id < record/member-count][
								offset-slot/1: payload-offset
								offset-slot: offset-slot + 1
								id: id + 1
							]
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
			cache/2: alignment
		]
		size-out/1: size
		align-out/1: alignment
		true
	]

	logical-size: func [
		ref [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local base size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref types type-count
		if base = 0 [return 0]
		if all [base > 0 (logical-kind base types type-count) = -7][
			record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
			return record/member-count
		]
		size: 0
		alignment: 0
		either layout-type ref true types members type-count 0 layouts member-offsets
			:size :alignment [size][0]
	]

	value-width: func [
		ref flags [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local size alignment [integer!]
	][
		size: 0
		alignment: 0
		either layout-type ref (flags = INLINE) types members type-count 0
			layouts member-offsets :size :alignment [size][0]
	]

	machine-value?: func [
		ref flags [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [logic!]
		/local width [integer!]
	][
		width: value-width ref flags types members type-count layouts member-offsets
		all [width > 0 width <= 8
			not all [flags = INLINE inline-object-ref? ref types type-count]]
	]

	win64-register-size?: func [size [integer!] return: [logic!]][
		any [size = 1 size = 2 size = 4 size = 8]
	]

	aggregate-size: func [
		ref [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local size alignment [integer!]
	][
		unless aggregate-ref? ref types type-count [return 0]
		size: 0
		alignment: 0
		either layout-type ref true types members type-count 0 layouts member-offsets
			:size :alignment [size][0]
	]

	win64-aggregate-width: func [
		ref [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local size [integer!]
	][
		size: aggregate-size ref types members type-count layouts member-offsets
		either win64-register-size? size [size][0]
	]

	win64-hidden-return?: func [
		ref flags [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [logic!]
	][
		all [
			(flags and RETURN_VALUE) <> 0
			aggregate-ref? ref types type-count
			(win64-aggregate-width ref types members type-count
				layouts member-offsets) = 0
		]
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

	integer-common-ref: func [
		left right [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		if any [
			left-kind < 1 left-kind > 8
			right-kind < 1 right-kind > 8
		][return 0]
		if compatible-types? left right types count [return left]
		if integer-kind-widens? right-kind left-kind [return left]
		if integer-kind-widens? left-kind right-kind [return right]
		0
	]

	reference-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref types count
		reference-kind? kind
	]

	address-type?: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
	][
		address-kind? logical-kind ref types count
	]

	pointer-stride: func [
		ref [integer!]
		types members [byte-ptr!]
		count [integer!]
		layouts member-offsets [int-ptr!]
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
			kind = -7 [
				record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
				size: record/flags
				unless any [size = 1 size = 2 size = 4 size = 8][return 0]
			]
			kind = -6 [
				record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
				unless layout-type record/target true types members count 0
					layouts member-offsets :size :alignment [
					return 0
				]
			]
			any [kind = -2 kind = -3][
				unless layout-type base true types members count 0 layouts member-offsets
					:size :alignment [
					return 0
				]
			]
			true [return 0]
		]
		size
	]

	pointee-type: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		result [int-ptr!]
		return: [logic!]
		/local base kind [integer!] record [rsir-type!]
	][
		base: canonical-type ref types count
		if base = 0 [return false]
		kind: logical-kind base types count
		if kind = 13 [result/1: -2 return true]
		unless all [any [kind = -6 kind = -7] base > 0][return false]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		result/1: record/target
		valid-type-ref? result/1 count
	]

	valid-static-address-initializer?: func [
		initializer [rsir-initializer!]
		expected owner global-count function-count [integer!]
		globals types [byte-ptr!]
		type-count [integer!]
		return: [logic!]
		/local target [rsir-global!] kind [integer!]
	][
		if any [
			initializer/kind <> ADDRESS_INITIALIZER
			initializer/c <> 0
		][return false]
		case [
			initializer/a = GLOBAL_ADDRESS [
				if any [
					initializer/b <= 0 initializer/b > global-count
					initializer/b = owner
				][return false]
				target: as rsir-global! (globals
					+ ((initializer/b - 1) * RSIR_GLOBAL_SIZE))
				all [
					(target/flags and INLINE) <> 0
					any [
						expected = 0
						compatible-types? expected target/type types type-count
					]
				]
			]
			initializer/a = FUNCTION_ADDRESS [
				if any [initializer/b <= 0 initializer/b > function-count][return false]
				kind: logical-kind expected types type-count
				any [expected = 0 kind = 12 kind = -4 kind = -5]
			]
			true [false]
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
			width = 4 [x64-encoder/write-i32 target low]
			width = 8 [
				x64-encoder/write-i32 target low
				x64-encoder/write-i32 (target + 4) high
			]
			true [return false]
		]
		true
	]

	load-operation-value: func [
		code [byte-ptr!]
		capacity target displacement ref flags operation-width [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local source-width signed encoded written [integer!] at [byte-ptr!]
	][
		source-width: value-width ref flags types members type-count
			layouts member-offsets
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
		member-offsets [int-ptr!]
		type-out flags-out offset-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			offset-slot [int-ptr!] base kind [integer!]
	][
		if null? as byte-ptr! member-offsets [return false]
		base: canonical-type ref types type-count
		if any [base <= 0 index < 0][return false]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		kind: record/kind
		unless any [kind = -2 kind = -3][return false]
		if index >= record/member-count [return false]
		member: as rsir-member! (members
			+ ((record/first-member + index) * RSIR_MEMBER_SIZE))
		offset-slot: (member-offsets + record/first-member) + index
		if offset-slot/1 < 0 [return false]
		type-out/1: member/type
		flags-out/1: member/flags
		offset-out/1: offset-slot/1
		true
	]

	slot-displacement: func [slot [integer!] return: [integer!]][
		0 - (x64-encoder/BASE_FRAME_SIZE + (slot * 8))
	]

	emit-variant-tags: func [
		code [byte-ptr!]
		capacity head tag-base instruction-count [integer!]
		instructions [byte-ptr!]
		tag-next tag-slots tag-widths [int-ptr!]
		return: [integer!]
		/local at [byte-ptr!] instruction [rsir-instruction!]
			node width encoded written steps [integer!]
	][
		written: 0
		steps: 0
		node: head
		while [node > 0][
			if any [node > instruction-count steps >= instruction-count][return -1]
			instruction: as rsir-instruction! (instructions
				+ ((node - 1) * RSIR_INSTRUCTION_SIZE))
			width: tag-widths/node
			if any [instruction/b <= 0 tag-slots/node <= 0
				not any [width = 1 width = 2 width = 4]][return -1]

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/frame-load at (capacity - written)
				x64-encoder/RDX slot-displacement (tag-base + tag-slots/node) 8 0
			if encoded < 0 [return encoded]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-immediate at (capacity - written)
				x64-encoder/RAX 4 instruction/b 0
			if encoded < 0 [return encoded]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/store-indirect at (capacity - written) width
			if encoded < 0 [return encoded]
			written: written + encoded
			node: tag-next/node
			steps: steps + 1
		]
		written
	]

	storage-displacement: func [offsets [int-ptr!] slot [integer!] return: [integer!]][
		offsets/slot
	]

	plan-storage: func [
		fn [rsir-function!]
		parameters types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets offsets [int-ptr!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			count index used size alignment [integer!]
	][
		count: fn/parameter-count + fn/local-count
		index: 1
		used: either win64-hidden-return? fn/return-type fn/flags
			types members type-count layouts member-offsets [8][0]
		while [index <= count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			size: 8
			alignment: 8
			if parameter/flags = INLINE [
				size: 0
				alignment: 0
				unless layout-type parameter/type true types members type-count 0
					layouts member-offsets :size :alignment [return INVALID_IR]
				if all [
					index <= fn/parameter-count
					not win64-register-size? size
				][
					size: 8
					alignment: 8
				]
			]
			if used > (2147483647 - size)[return INVALID_IR]
			used: align (used + size) alignment
			if used < 0 [return INVALID_IR]
			offsets/index: 0 - (x64-encoder/BASE_FRAME_SIZE + used)
			index: index + 1
		]
		align used 8
	]

	plan-call-results: func [
		fn [rsir-function!]
		instructions functions imports types members [byte-ptr!]
		function-count import-count type-count used [integer!]
		layouts member-offsets offsets [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			callee [rsir-function!] imported [rsir-import!] signature [rsir-type!]
			index target import-id ref flags size [integer!]
	][
		index: 1
		while [index <= fn/instruction-count][
			offsets/index: 0
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			if instruction/op = OP_CALL [
				target: instruction/a
				ref: 0
				flags: 0
				either target > 0 [
					if target > function-count [return INVALID_IR]
					callee: as rsir-function! (functions
						+ ((target - 1) * RSIR_FUNCTION_SIZE))
					ref: callee/return-type
					flags: callee/flags
				][either target < 0 [
					import-id: 0 - target
					if any [import-id <= 0 import-id > import-count][return INVALID_IR]
					imported: as rsir-import! (imports
						+ ((import-id - 1) * RSIR_IMPORT_SIZE))
					ref: imported/type
					flags: imported/flags
				][
					if any [
						not valid-type-ref? instruction/c type-count
						(logical-kind instruction/c types type-count) <> -4
					][return INVALID_IR]
					signature: as rsir-type! (types
						+ (((canonical-type instruction/c types type-count) - 1)
							* RSIR_TYPE_SIZE))
					ref: signature/target
					flags: signature/flags
				]
				]
				if (flags and RETURN_VALUE) <> 0 [
					size: aggregate-size ref types members type-count
						layouts member-offsets
					if any [size <= 0 used > (2147483647 - size)][
						return INVALID_IR
					]
					used: align (used + size) 16
					if used < 0 [return INVALID_IR]
					offsets/index: 0 - (x64-encoder/BASE_FRAME_SIZE + used)
				]
			]
			index: index + 1
		]
		align used 8
	]

	clear-frame-storage: func [
		code [byte-ptr!]
		capacity displacement size [integer!]
		return: [integer!]
		/local at [byte-ptr!] width encoded written [integer!]
	][
		written: 0
		while [size > 0][
			width: case [
				size >= 8 [8]
				size >= 4 [4]
				size >= 2 [2]
				true [1]
			]
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/frame-store at (capacity - written)
				x64-encoder/RAX displacement width
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			displacement: displacement + width
			size: size - width
		]
		written
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

	float-condition: func [operation [integer!] return: [integer!]][
		case [
			operation = EQUAL_OPERATION [4]
			operation = NOT_EQUAL_OPERATION [5]
			operation = GREATER_OPERATION [7]
			operation = LESS_OPERATION [2]
			operation = GREATER_EQUAL_OPERATION [3]
			operation = LESS_EQUAL_OPERATION [6]
			true [-1]
		]
	]

	float-parity: func [operation [integer!] return: [integer!]][
		case [
			operation = NOT_EQUAL_OPERATION [2]
			any [
				operation = EQUAL_OPERATION
				operation = LESS_OPERATION
				operation = LESS_EQUAL_OPERATION
			][1]
			true [0]
		]
	]

	float-opcode: func [operation [integer!] return: [integer!]][
		case [
			operation = ADD_OPERATION [58h]
			operation = SUBTRACT_OPERATION [5Ch]
			operation = MULTIPLY_OPERATION [59h]
			operation = DIVIDE_OPERATION [5Eh]
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

	merge-target: func [
		target depth instruction-count [integer!]
		instruction-depths entry-types entry-flags entry-kinds entry-tags
			stack-types stack-flags stack-kinds stack-tags [int-ptr!]
		types [byte-ptr!]
		type-count [integer!]
		return: [logic!]
	][
		if any [target <= 0 target > instruction-count][return false]
		if all [
			instruction-depths/target >= 0
			instruction-depths/target <> depth
		][return false]
		if all [
			instruction-depths/target >= 0
			depth > 0
			any [
				not compatible-types? entry-types/target stack-types/depth
					types type-count
				entry-flags/target <> stack-flags/depth
				entry-kinds/target <> stack-kinds/depth
				entry-tags/target <> stack-tags/depth
			]
		][return false]
		instruction-depths/target: depth
		if depth > 0 [
			entry-types/target: stack-types/depth
			entry-flags/target: stack-flags/depth
			entry-kinds/target: stack-kinds/depth
			entry-tags/target: stack-tags/depth
		]
		true
	]

	compile-function: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		stack-types stack-flags stack-kinds stack-tags storage-offsets result-offsets
			layouts member-offsets
			instruction-offsets instruction-depths entry-types entry-flags entry-kinds
			entry-tags tag-next tag-slots tag-widths import-refs references [int-ptr!]
		parameters functions imports globals types members switches image-data strings code
			[byte-ptr!]
		type-count function-count import-count global-count switch-count strings-size
			function-offset function-code-size capacity exit-reference-id [integer!]
		entry? [logic!]
		global-reference-count literal-size frame-size [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			switch-case [rsir-switch!]
			parameter [rsir-parameter!]
			callee [rsir-function!]
			imported [rsir-import!]
			signature [rsir-type!]
			global [rsir-global!]
			image-global [codegen-global!]
			target-function [codegen-function!]
			at [byte-ptr!]
			call-parameters [byte-ptr!]
			index depth max-depth kind ref flags width signed source-slot target-slot
			storage-count storage-slots storage-bytes storage-size storage-align
			tag-head tag-count tag-capacity tag-base tag-width-value
			operation left-ref right-ref left-flags right-flags
			left-kind right-kind operation-width condition stride
			encoded written frame-extra slot-bytes outgoing outgoing-end max-outgoing
			argument-index argument-base callee-slot
			argument-slot argument-width physical-slot target return-ref first-parameter
			parameter-count call-flags import-id global-id literal-end displacement
			member-type member-flags member-offset source-width target-width
			target-ref target-flags copy-size copy-align
			result-index reference-id target-offset instruction-start case-index
			operation-ref source-kind target-kind opcode parity keep-cast
			aggregate-width value-size result-offset temp-offset hidden-shift
			physical-count call-mode list-size list-capacity [integer!]
			measure? fallthrough? valid? comparison? floating? clear? aggregate-copy?
			return-value? hidden-return? aggregate-argument? indirect? packed-call? [logic!]
	][
		measure?: null? code
		tag-capacity: 0
		index: 1
		while [index <= fn/instruction-count][
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			if all [instruction/op = OP_MEMBER instruction/b > 0][
				tag-capacity: tag-capacity + 1
			]
			index: index + 1
		]
		storage-count: fn/parameter-count + fn/local-count
		storage-bytes: plan-storage fn parameters types members type-count
			layouts member-offsets storage-offsets
		if storage-bytes < 0 [return storage-bytes]
		storage-bytes: plan-call-results fn instructions functions imports types members
			function-count import-count type-count storage-bytes
			layouts member-offsets result-offsets
		if storage-bytes < 0 [return storage-bytes]
		storage-slots: storage-bytes / 8
		tag-base: storage-slots
		if storage-slots > (2147483647 - tag-capacity)[return OUTPUT_FULL]
		storage-slots: storage-slots + tag-capacity
		tag-count: 0
		return-value?: (fn/flags and RETURN_VALUE) <> 0
		either return-value? [
			if any [
				fn/return-type = 0
				(aggregate-size fn/return-type types members type-count
					layouts member-offsets) <= 0
			][return INVALID_IR]
		][
			if all [
				fn/return-type <> 0
				not machine-value? fn/return-type 0 types members type-count
					layouts member-offsets
			][return UNSUPPORTED]
		]
		hidden-return?: win64-hidden-return? fn/return-type fn/flags
			types members type-count layouts member-offsets
		if all [entry? fn/parameter-count <> 0][return UNSUPPORTED]

		depth: 0
		max-depth: 0
		max-outgoing: 0
		fallthrough?: true
		written: 0
		if measure? [
			index: 1
			while [index <= fn/instruction-count][
				instruction-depths/index: -1
				index: index + 1
			]
		]
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
		if hidden-return? [
			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/frame-store at (capacity - written)
				x64-encoder/RCX (0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		hidden-shift: either hidden-return? [1][0]
		index: 1
		while [index <= fn/parameter-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			aggregate-argument?: parameter/flags = INLINE
			either aggregate-argument? [
				unless aggregate-ref? parameter/type types type-count [return INVALID_IR]
				aggregate-width: win64-aggregate-width parameter/type
					types members type-count layouts member-offsets
				width: either aggregate-width = 0 [8][aggregate-width]
				signed: 0
				floating?: false
			][
				unless machine-value? parameter/type 0 types members type-count
					layouts member-offsets [
					return UNSUPPORTED
				]
				width: value-width parameter/type 0 types members type-count
					layouts member-offsets
				signed: either signed-type? parameter/type types type-count [1][0]
				floating?: float-type? parameter/type types type-count
			]
			target-slot: storage-displacement storage-offsets index
			physical-slot: index + hidden-shift
			either physical-slot <= 4 [
				at: as byte-ptr! 0
				if not measure? [at: code + written]
				encoded: either floating? [
					x64-encoder/xmm-frame-store at (capacity - written)
						(physical-slot - 1) target-slot width
				][
					source-slot: argument-register physical-slot
					x64-encoder/frame-store at (capacity - written)
						source-slot target-slot width
				]
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
			][
				displacement: 48 + ((physical-slot - 5) * 8)
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

		clear?: false
		index: fn/parameter-count + 1
		while [index <= storage-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			if parameter/flags = INLINE [
				unless clear? [
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/clear-register at (capacity - written)
						x64-encoder/RAX
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					clear?: true
				]
				storage-size: 0
				storage-align: 0
				unless layout-type parameter/type true types members type-count 0
					layouts member-offsets :storage-size :storage-align [
					return INVALID_IR
				]
				at: as byte-ptr! 0
				if not measure? [at: code + written]
				encoded: clear-frame-storage at (capacity - written)
					storage-displacement storage-offsets index storage-size
				if encoded < 0 [return encoded]
				written: written + encoded
			]
			index: index + 1
		]

		index: 1
		while [index <= fn/instruction-count][
			either fallthrough? [
				if measure? [
					if all [
						instruction-depths/index >= 0
						instruction-depths/index <> depth
					][return INVALID_IR]
					if all [
						instruction-depths/index >= 0
						depth > 0
						any [
							not compatible-types? entry-types/index stack-types/depth
								types type-count
							entry-flags/index <> stack-flags/depth
							entry-kinds/index <> stack-kinds/depth
							entry-tags/index <> stack-tags/depth
						]
					][return INVALID_IR]
				]
			][
				depth: either instruction-depths/index >= 0 [
					instruction-depths/index
				][0]
				if depth > 0 [
					stack-types/depth: entry-types/index
					stack-flags/depth: entry-flags/index
					stack-kinds/depth: entry-kinds/index
					stack-tags/depth: entry-tags/index
				]
			]
			if measure? [
				instruction-depths/index: depth
				if depth > 0 [
					entry-types/index: stack-types/depth
					entry-flags/index: stack-flags/depth
					entry-kinds/index: stack-kinds/depth
					entry-tags/index: stack-tags/depth
				]
			]
			if measure? [instruction-offsets/index: written]
			instruction-start: written
			fallthrough?: true
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			case [
				instruction/op = OP_LITERAL [
					ref: instruction/a
					unless all [
						valid-type-ref? ref type-count
						machine-value? ref 0 types members type-count
							layouts member-offsets
					][return INVALID_IR]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					width: value-width ref 0 types members type-count
						layouts member-offsets
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
						x64-encoder/RAX slot-displacement (storage-slots + depth)
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
					stack-tags/depth: 0
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
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8
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
							encoded: either all [
								instruction/b <= fn/parameter-count
								parameter/flags = INLINE
								(win64-aggregate-width parameter/type types members
									type-count layouts member-offsets) = 0
							][
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX
									storage-displacement storage-offsets instruction/b 8 0
							][
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RAX
									storage-displacement storage-offsets instruction/b
							]
						]
						instruction/a = GLOBAL_ADDRESS [
							global-id: instruction/b
							if any [global-id <= 0 global-id > global-count][return INVALID_IR]
							global: as rsir-global! (globals
								+ ((global-id - 1) * RSIR_GLOBAL_SIZE))
							ref: global/type
							flags: global/flags and INLINE
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
							either imported/flags = 0 [
								if instruction/c <> 0 [return INVALID_IR]
								ref: imported/type
							][
								ref: instruction/c
								unless all [
									valid-type-ref? ref type-count
									(logical-kind ref types type-count) = -4
								][return INVALID_IR]
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/rip-load at (capacity - written)
								x64-encoder/RAX 0
						]
						instruction/a = FUNCTION_ADDRESS [
							target: instruction/b
							if any [target <= 0 target > function-count][return INVALID_IR]
							ref: instruction/c
							unless all [
								valid-type-ref? ref type-count
								(logical-kind ref types type-count) = -4
							][return INVALID_IR]
							displacement: 0
							if not measure? [
								target-function: as codegen-function! (image-data
									+ ((target - 1) * IMAGE_FUNCTION_SIZE))
								displacement: target-function/code-offset
									- (function-offset + written + 7)
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/rip-address at (capacity - written)
								x64-encoder/RAX displacement
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
					stack-tags/depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_LOAD [
					if any [depth <= 0 stack-kinds/depth <> PLACE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					either all [
						flags = INLINE
						inline-object-ref? ref types type-count
					][
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
					][
						unless machine-value? ref flags types members type-count
							layouts member-offsets [
							return UNSUPPORTED
						]
						width: value-width ref flags types members type-count
							layouts member-offsets
						signed: either signed-type? ref types type-count [1][0]
						floating?: float-type? ref types type-count
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							x64-encoder/xmm-load-indirect at (capacity - written)
								x64-encoder/XMM0 x64-encoder/RAX width
						][x64-encoder/load-indirect at (capacity - written) width signed]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							x64-encoder/xmm-frame-store at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) width
						][
							target-width: either width = 8 [8][4]
							x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement (storage-slots + depth)
								target-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						stack-kinds/depth: VALUE
					]
				]
				instruction/op = OP_REFERENCE [
					if any [depth <= 0 stack-kinds/depth <> PLACE][return INVALID_IR]
					unless all [
						instruction/b = 0 instruction/c = 0
						valid-type-ref? instruction/a type-count
						reference-type? instruction/a types type-count
						machine-value? instruction/a 0 types members type-count
							layouts member-offsets
					][return INVALID_IR]
					stack-types/depth: instruction/a
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
				]
				instruction/op = OP_INDEX [
					unless any [instruction/b = 0 instruction/b = 1][return INVALID_IR]
					if all [instruction/b = 1 any [instruction/a <> 0 instruction/c <> 0]][
						return INVALID_IR
					]
					target-slot: either instruction/b = 1 [depth - 1][depth]
					if any [target-slot <= 0 stack-kinds/target-slot <> VALUE][
						return INVALID_IR
					]
					ref: stack-types/target-slot
					flags: stack-flags/target-slot
					if flags <> 0 [return INVALID_IR]
					member-type: 0
					unless pointee-type ref types type-count :member-type [return INVALID_IR]
					stride: pointer-stride ref types members type-count
						layouts member-offsets
					if stride <= 0 [return UNSUPPORTED]
					if instruction/b = 1 [
						if any [
							depth < 2 stack-kinds/depth <> VALUE
							stack-flags/depth <> 0
							(logical-kind stack-types/depth types type-count) <> 5
						][return INVALID_IR]
					]

					if any [
						instruction/b = 1 instruction/a <> 0 instruction/c <> 0
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + target-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded

						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either instruction/b = 1 [
							load-operation-value at (capacity - written)
								x64-encoder/RDX slot-displacement (storage-slots + depth)
								stack-types/depth 0 8 types members type-count
								layouts member-offsets
						][
							x64-encoder/move-immediate at (capacity - written)
								x64-encoder/RDX 8 instruction/a instruction/c
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded

						if instruction/b = 1 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/add-immediate at (capacity - written)
								x64-encoder/RDX -1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if stride <> 1 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/multiply-immediate at (capacity - written)
								x64-encoder/RDX x64-encoder/RDX stride 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							01h x64-encoder/RAX x64-encoder/RDX 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + target-slot) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					depth: target-slot
					stack-types/depth: member-type
					stack-flags/depth: 0
					stack-kinds/depth: PLACE
				]
				instruction/op = OP_SET [
					target-slot: depth - 1
					if any [depth < 2 stack-kinds/target-slot <> PLACE
						stack-kinds/depth <> VALUE][return INVALID_IR]
					target-ref: stack-types/target-slot
					target-flags: stack-flags/target-slot
					tag-head: stack-tags/target-slot
					ref: stack-types/depth
					flags: stack-flags/depth
					aggregate-copy?: all [
						target-flags = INLINE flags = 0
						aggregate-ref? target-ref types type-count
						aggregate-ref? ref types type-count
						compatible-types? target-ref ref types type-count
					]
					either aggregate-copy? [
						copy-size: 0
						copy-align: 0
						unless layout-type target-ref true types members type-count 0
							layouts member-offsets :copy-size :copy-align [
							return INVALID_IR
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RCX slot-displacement (storage-slots + depth) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RDX slot-displacement (storage-slots + target-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/copy-indirect at (capacity - written) copy-size
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						depth: target-slot
						stack-types/depth: target-ref
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
					][
						unless all [
							compatible-types? target-ref ref types type-count
							target-flags = flags
							machine-value? ref flags types members type-count
								layouts member-offsets
						][return INVALID_IR]
						width: value-width ref flags types members type-count
							layouts member-offsets
						signed: either signed-type? ref types type-count [1][0]
						floating?: float-type? ref types type-count
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							x64-encoder/xmm-frame-load at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) width
						][
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement (storage-slots + depth)
								width signed
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RDX slot-displacement (storage-slots + depth - 1) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							x64-encoder/xmm-store-indirect at (capacity - written)
								x64-encoder/RDX x64-encoder/XMM0 width
						][x64-encoder/store-indirect at (capacity - written) width]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						depth: depth - 1
						stack-types/depth: ref
						stack-flags/depth: flags
						stack-kinds/depth: VALUE
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							x64-encoder/xmm-frame-store at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) width
						][
							target-width: either width = 8 [8][4]
							x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement (storage-slots + depth)
								target-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: emit-variant-tags at (capacity - written) tag-head tag-base
						fn/instruction-count instructions tag-next tag-slots tag-widths
					if encoded < 0 [return encoded]
					written: written + encoded
					stack-tags/depth: 0
				]
				instruction/op = OP_MEMBER [
					if any [depth <= 0 instruction/c <> 0][return INVALID_IR]
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
						member-offsets
						:member-type :member-flags :member-offset [return INVALID_IR]
					tag-width-value: 0
					if instruction/b <> 0 [
						unless all [
							instruction/b = (instruction/a + 1)
							tagged-union? ref types type-count
						][return INVALID_IR]
						tag-width-value: union-tag-width ref types type-count
						if tag-width-value = 0 [return INVALID_IR]
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if instruction/b <> 0 [
						tag-count: tag-count + 1
						if tag-count > tag-capacity [return INVALID_IR]
						either measure? [
							tag-next/index: stack-tags/depth
							tag-slots/index: tag-count
							tag-widths/index: tag-width-value
						][unless all [
							tag-next/index = stack-tags/depth
							tag-slots/index = tag-count
							tag-widths/index = tag-width-value
						][return INVALID_IR]]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (tag-base + tag-count) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						stack-tags/depth: index
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/add-immediate at (capacity - written)
						x64-encoder/RAX member-offset
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: member-type
					stack-flags/depth: member-flags
					stack-kinds/depth: PLACE
				]
				instruction/op = OP_TAG [
					if any [
						instruction/a <> 0 instruction/b <> 0 instruction/c <> 0
						depth <= 0 stack-kinds/depth <> VALUE
						stack-flags/depth <> 0
					][return INVALID_IR]
					width: union-tag-width stack-types/depth types type-count
					if width = 0 [return INVALID_IR]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/load-indirect at (capacity - written) width 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
				]
				instruction/op = OP_CALL [
					target: instruction/a
					argument-index: instruction/b
					indirect?: target = 0
					return-ref: 0
					first-parameter: 0
					parameter-count: 0
					call-flags: 0
					import-id: 0
					call-parameters: parameters
					either target > 0 [
						if target > function-count [return INVALID_IR]
						callee: as rsir-function! (functions
							+ ((target - 1) * RSIR_FUNCTION_SIZE))
						return-ref: callee/return-type
						first-parameter: callee/first-parameter
						parameter-count: callee/parameter-count
						call-flags: callee/flags
					][either target < 0 [
						import-id: 0 - target
						if any [import-id <= 0 import-id > import-count][return INVALID_IR]
						imported: as rsir-import! (imports
							+ ((import-id - 1) * RSIR_IMPORT_SIZE))
						if imported/flags = 0 [return INVALID_IR]
						return-ref: imported/type
						first-parameter: imported/first-parameter
						parameter-count: imported/parameter-count
						call-flags: imported/flags
					][
						if any [
							not valid-type-ref? instruction/c type-count
							(logical-kind instruction/c types type-count) <> -4
						][return INVALID_IR]
						signature: as rsir-type! (types
							+ (((canonical-type instruction/c types type-count) - 1)
								* RSIR_TYPE_SIZE))
						return-ref: signature/target
						first-parameter: signature/first-member
						parameter-count: signature/member-count
						call-flags: signature/flags
						call-parameters: members
					]]
					call-mode: call-flags and VARIABLE_FLAGS
					if any [call-mode = TYPED call-mode = CUSTOM][return UNSUPPORTED]
					packed-call?: all [
						call-mode = VARIADIC
						(call-flags and 3) <> CDECL
					]
					if packed-call? [
						either target < 0 [
							unless parameter-count = 0 [return INVALID_IR]
						][
							unless any [parameter-count = 2 parameter-count = 3][
								return INVALID_IR
							]
							parameter: as rsir-parameter! (call-parameters
								+ (first-parameter * RSIR_PARAMETER_SIZE))
							unless all [parameter/flags = 0
								(logical-kind parameter/type types type-count) = 5][
								return INVALID_IR
							]
							parameter: as rsir-parameter! (call-parameters
								+ ((first-parameter + 1) * RSIR_PARAMETER_SIZE))
							unless all [parameter/flags = 0
								address-kind? (logical-kind parameter/type types type-count)][
								return INVALID_IR
							]
							if parameter-count = 3 [
								parameter: as rsir-parameter! (call-parameters
									+ ((first-parameter + 2) * RSIR_PARAMETER_SIZE))
								unless all [parameter/flags = 0
									(logical-kind parameter/type types type-count) = 5][
									return INVALID_IR
								]
							]
						]
					]
					unless all [
						argument-index >= 0 argument-index <= depth
						any [indirect? instruction/c = return-ref]
						any [
							packed-call?
							argument-index = parameter-count
							all [call-mode = VARIADIC
								argument-index >= parameter-count]
						]
					][return INVALID_IR]
					return-value?: (call-flags and RETURN_VALUE) <> 0
					if return-value? [
						unless all [
							return-ref <> 0
							aggregate-ref? return-ref types type-count
							(aggregate-size return-ref types members type-count
								layouts member-offsets) > 0
						][return INVALID_IR]
					]
					hidden-return?: win64-hidden-return? return-ref call-flags
						types members type-count layouts member-offsets
					hidden-shift: either hidden-return? [1][0]
					physical-count: either packed-call? [3][argument-index]
					if physical-count > (2147483647 - hidden-shift)[return OUTPUT_FULL]
					physical-count: physical-count + hidden-shift
					if physical-count > (((2147483647 - 32) / 8) + 4)[
						return OUTPUT_FULL
					]
					outgoing: 32
					if physical-count > 4 [
						outgoing: outgoing + ((physical-count - 4) * 8)
					]
					if outgoing > max-outgoing [max-outgoing: outgoing]
					either indirect? [
						callee-slot: depth - argument-index
						if any [
							callee-slot <= 0
							stack-kinds/callee-slot <> VALUE
							stack-flags/callee-slot <> 0
							not compatible-types? instruction/c stack-types/callee-slot
								types type-count
						][return INVALID_IR]
						argument-base: callee-slot
						result-index: callee-slot - 1
					][
						argument-base: depth - argument-index
						result-index: argument-base
					]
					temp-offset: align outgoing 16
					if temp-offset < 0 [return OUTPUT_FULL]

					; Copy indirect aggregates before loading volatile argument registers.
					source-slot: 1
					while [all [not packed-call? source-slot <= argument-index]][
						argument-slot: argument-base + source-slot
						ref: stack-types/argument-slot
						flags: stack-flags/argument-slot
						if stack-kinds/argument-slot <> VALUE [return INVALID_IR]
						aggregate-argument?: false
						either source-slot <= parameter-count [
							parameter: as rsir-parameter! (call-parameters
								+ ((first-parameter + source-slot - 1)
									* RSIR_PARAMETER_SIZE))
							aggregate-argument?: parameter/flags = INLINE
							either aggregate-argument? [
								unless all [
									flags = 0
									aggregate-ref? ref types type-count
									compatible-types? parameter/type ref types type-count
								][return INVALID_IR]
							][
								unless all [
									compatible-types? parameter/type ref types type-count
									parameter/flags = flags
								][return INVALID_IR]
								unless machine-value? ref flags types members type-count
									layouts member-offsets [
									return UNSUPPORTED
								]
							]
						][
							unless machine-value? ref flags types members type-count
								layouts member-offsets [
								return UNSUPPORTED
							]
						]
						if aggregate-argument? [
							aggregate-width: win64-aggregate-width parameter/type
								types members type-count layouts member-offsets
							if aggregate-width = 0 [
								value-size: aggregate-size parameter/type
									types members type-count layouts member-offsets
								if any [
									value-size <= 0
									temp-offset > (2147483647 - value-size)
								][return OUTPUT_FULL]
								outgoing-end: temp-offset + value-size
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RCX slot-displacement
										(storage-slots + argument-slot) 8 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/stack-address at (capacity - written)
									x64-encoder/RDX temp-offset
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/copy-indirect at
									(capacity - written) value-size
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if outgoing-end > max-outgoing [max-outgoing: outgoing-end]
								temp-offset: align outgoing-end 16
								if temp-offset < 0 [return OUTPUT_FULL]
							]
						]
						source-slot: source-slot + 1
					]

					if packed-call? [
						if argument-index > (2147483647 / 8)[return OUTPUT_FULL]
						list-size: argument-index * 8
						list-capacity: either list-size < 8 [8][list-size]
						if temp-offset > (2147483647 - list-capacity)[return OUTPUT_FULL]
						outgoing-end: temp-offset + list-capacity
						if outgoing-end > max-outgoing [max-outgoing: outgoing-end]
						source-slot: 1
						while [source-slot <= argument-index][
							argument-slot: argument-base + source-slot
							ref: stack-types/argument-slot
							flags: stack-flags/argument-slot
							unless all [
								stack-kinds/argument-slot = VALUE
								flags = 0
								machine-value? ref flags types members type-count
									layouts member-offsets
							][return INVALID_IR]
							width: value-width ref flags types members type-count
								layouts member-offsets
							if width <= 0 [return UNSUPPORTED]
							signed: either signed-type? ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + argument-slot) width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/outgoing-store at (capacity - written)
								(temp-offset + ((source-slot - 1) * 8)) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							source-slot: source-slot + 1
						]
						target-slot: argument-register (hidden-shift + 1)
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-immediate at (capacity - written)
							target-slot 4 argument-index 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						target-slot: argument-register (hidden-shift + 2)
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/stack-address at (capacity - written)
							target-slot temp-offset
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						target-slot: argument-register (hidden-shift + 3)
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-immediate at (capacity - written)
							target-slot 4 list-size 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					temp-offset: align outgoing 16
					source-slot: 1
					while [all [not packed-call? source-slot <= argument-index]][
						argument-slot: argument-base + source-slot
						ref: stack-types/argument-slot
						flags: stack-flags/argument-slot
						aggregate-argument?: false
						aggregate-width: 0
						if source-slot <= parameter-count [
							parameter: as rsir-parameter! (call-parameters
								+ ((first-parameter + source-slot - 1)
									* RSIR_PARAMETER_SIZE))
							aggregate-argument?: parameter/flags = INLINE
							if aggregate-argument? [
								aggregate-width: win64-aggregate-width parameter/type
									types members type-count layouts member-offsets
							]
						]
						physical-slot: source-slot + hidden-shift
						either aggregate-argument? [
							either aggregate-width = 0 [
								value-size: aggregate-size parameter/type
									types members type-count layouts member-offsets
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/stack-address at (capacity - written)
									x64-encoder/RAX temp-offset
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								argument-width: 8
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + argument-slot) 8 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/load-indirect at
									(capacity - written) aggregate-width 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								argument-width: aggregate-width
							]
							target-width: either argument-width = 8 [8][4]
							either physical-slot <= 4 [
								target-slot: argument-register physical-slot
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									target-slot x64-encoder/RAX target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/outgoing-store at (capacity - written)
									(32 + ((physical-slot - 5) * 8))
									target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							if aggregate-width = 0 [
								outgoing-end: temp-offset + value-size
								temp-offset: align outgoing-end 16
							]
						][
							argument-width: value-width ref flags types members type-count
								layouts member-offsets
							signed: either signed-type? ref types type-count [1][0]
							floating?: float-type? ref types type-count
							either physical-slot <= 4 [
								target-slot: argument-register physical-slot
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: either floating? [
									x64-encoder/xmm-frame-load at (capacity - written)
										(physical-slot - 1) slot-displacement
											(storage-slots + argument-slot) argument-width
								][
									x64-encoder/frame-load at (capacity - written)
										target-slot slot-displacement
											(storage-slots + argument-slot)
										argument-width signed
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if all [floating? (call-flags and VARIADIC) <> 0][
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										target-slot slot-displacement
											(storage-slots + argument-slot)
										argument-width 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + argument-slot)
									argument-width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								target-width: either argument-width = 8 [8][4]
								encoded: x64-encoder/outgoing-store at (capacity - written)
									(32 + ((physical-slot - 5) * 8))
									target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
						source-slot: source-slot + 1
					]
					if hidden-return? [
						result-offset: result-offsets/index
						if result-offset >= 0 [return INVALID_IR]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-address at (capacity - written)
							x64-encoder/RCX result-offset
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if indirect? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + callee-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
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
					case [
						target > 0 [
							encoded: x64-encoder/call-relative at
								(capacity - written) displacement
						]
						target < 0 [
							encoded: x64-encoder/call-import at (capacity - written) 0
						]
						true [
							encoded: x64-encoder/call-register at
								(capacity - written) x64-encoder/RAX
						]
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
						depth: depth + 1
						stack-types/depth: return-ref
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
						stack-tags/depth: 0
						either return-value? [
							result-offset: result-offsets/index
							aggregate-width: win64-aggregate-width return-ref
								types members type-count layouts member-offsets
							if any [
								result-offset >= 0
								all [aggregate-width = 0 not hidden-return?]
							][return INVALID_IR]
							if not hidden-return? [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX result-offset aggregate-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-address at (capacity - written)
								x64-encoder/RAX result-offset
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8
						][
							unless machine-value? return-ref 0 types members type-count
								layouts member-offsets [
								return UNSUPPORTED
							]
							width: value-width return-ref 0 types members type-count
								layouts member-offsets
							floating?: float-type? return-ref types type-count
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) width
							][
								target-width: either width = 8 [8][4]
								x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) target-width
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_CAST [
					if any [depth <= 0 stack-kinds/depth <> VALUE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					source-width: value-width ref flags types members type-count
						layouts member-offsets
					target-width: value-width instruction/a instruction/b
						types members type-count layouts member-offsets
					keep-cast: instruction/c
					unless all [
						valid-type-ref? instruction/a type-count
						any [keep-cast = 0 keep-cast = 1]
						machine-value? ref flags types members type-count
							layouts member-offsets
						machine-value? instruction/a instruction/b types members type-count
							layouts member-offsets
					][return UNSUPPORTED]
					source-kind: logical-kind ref types type-count
					target-kind: logical-kind instruction/a types type-count
					if all [source-kind = 14 not reference-kind? target-kind][
						return INVALID_IR
					]
					floating?: any [
						any [source-kind = 9 source-kind = 10]
						any [target-kind = 9 target-kind = 10]
					]
					if any [source-kind = -4 target-kind = -4][
						valid?: either source-kind = -4 [
							any [target-kind = 5 target-kind = 12
								target-kind = -6 target-kind = -4]
						][
							any [
								source-kind = 5 source-kind = 12 source-kind = 13
								source-kind = 14
								source-kind = -2 source-kind = -3 source-kind = -4
								source-kind = -6 source-kind = -7
							]
						]
						unless valid? [return INVALID_IR]
					]
					if floating? [
						valid?: all [
							flags = 0 instruction/b = 0
							either keep-cast = 1 [
								any [
									source-kind = target-kind
									all [source-kind = 5 target-kind = 9]
									all [source-kind = 9 target-kind = 5]
								]
							][
								any [
									all [any [source-kind = 9 source-kind = 10]
										any [target-kind = 9 target-kind = 10]]
									all [source-kind = 5 any [target-kind = 9 target-kind = 10]]
									all [any [source-kind = 9 source-kind = 10] target-kind = 5]
								]
							]
						]
						unless valid? [return INVALID_IR]
					]
					either floating? [
						case [
							any [keep-cast = 1 source-kind = target-kind][
								signed: either signed-type? ref types type-count [1][0]
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) source-width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) target-width
							]
							source-kind = 5 [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) 4 1
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/integer-to-xmm at (capacity - written)
									x64-encoder/XMM0 x64-encoder/RAX 4 target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) target-width
							]
							target-kind = 5 [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) source-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-to-integer at (capacity - written)
									x64-encoder/RAX x64-encoder/XMM0 source-width 4
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) 4
							]
							true [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) source-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-convert at (capacity - written)
									x64-encoder/XMM0 x64-encoder/XMM0
									source-width target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) target-width
							]
						]
					][
						signed: either signed-type? ref types type-count [1][0]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
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
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							width
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: instruction/a
					stack-flags/depth: instruction/b
					stack-tags/depth: 0
				]
				instruction/op = OP_SIZE [
					ref: instruction/a
					unless valid-type-ref? ref type-count [return INVALID_IR]
					width: logical-size ref types members type-count
						layouts member-offsets
					if width <= 0 [return INVALID_IR]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/move-immediate at (capacity - written)
						x64-encoder/RAX 4 width 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 4
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
					stack-tags/depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/stack-top at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8
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
					tag-head: stack-tags/depth
					width: either kind = PLACE [8][
						value-width ref flags types members type-count
							layouts member-offsets
					]
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth)
						width signed
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: kind
					stack-tags/depth: tag-head
					target-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth)
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
							layouts member-offsets
					][return INVALID_IR]
					width: value-width ref flags types members type-count
						layouts member-offsets
					operation-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth)
						ref flags operation-width types members type-count
						layouts member-offsets
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
						x64-encoder/RAX slot-displacement (storage-slots + depth)
						operation-width
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-tags/depth: 0
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
					operation-ref: 0
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
									address-type? left-ref types type-count
									left-flags = 0 right-flags = 0
									any [
										integer-type? right-ref types type-count
										address-type? right-ref types type-count
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
							operation-ref: integer-common-ref left-ref right-ref
								types type-count
							valid?: any [
								all [
									left-flags = 0 right-flags = 0
									operation-ref <> 0
								]
							all [
								compatible-types? left-ref right-ref types type-count
								left-flags = right-flags
								any [
									operation <= NOT_EQUAL_OPERATION
									all [
										left-kind <> 14 right-kind <> 14
										left-kind <> -4 right-kind <> -4
									]
								]
								any [
										float-type? left-ref types type-count
										reference-type? left-ref types type-count
										all [
											left-kind = 11
											operation <= NOT_EQUAL_OPERATION
										]
									]
								]
							]
						]
						true [valid?: false]
					]
					unless valid? [return INVALID_IR]
					floating?: any [
						float-type? left-ref types type-count
						float-type? right-ref types type-count
					]
					unless all [
						machine-value? left-ref left-flags types members type-count
							layouts member-offsets
						machine-value? right-ref right-flags types members type-count
							layouts member-offsets
					][return UNSUPPORTED]

					either floating? [
						width: value-width left-ref left-flags types members type-count
							layouts member-offsets
						operation-width: width
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/xmm-frame-load at (capacity - written)
							x64-encoder/XMM0 slot-displacement
								(storage-slots + target-slot) operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/xmm-frame-load at (capacity - written)
							x64-encoder/XMM1 slot-displacement
								(storage-slots + depth) operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						either comparison? [
							encoded: x64-encoder/xmm-compare at (capacity - written)
								x64-encoder/XMM0 x64-encoder/XMM1 operation-width
						][
							opcode: float-opcode operation
							if opcode < 0 [return UNSUPPORTED]
							encoded: x64-encoder/xmm-binary at (capacity - written)
								opcode x64-encoder/XMM0 x64-encoder/XMM1 operation-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if comparison? [
							condition: float-condition operation
							parity: float-parity operation
							if condition < 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/float-condition-result
								at (capacity - written) condition parity
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					][
					ref: either operation-ref <> 0 [operation-ref][left-ref]
					width: value-width ref left-flags types members type-count
						layouts member-offsets
					operation-width: either any [
						width = 8
						reference-type? ref types type-count
					][8][4]
					signed: either signed-type? ref types type-count [1][0]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement
						(storage-slots + target-slot) left-ref left-flags
						operation-width types members type-count layouts member-offsets
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					source-slot: either all [
						operation >= DIVIDE_OPERATION
						operation <= SHIFT_LOGICAL_OPERATION
					][x64-encoder/RCX][x64-encoder/RDX]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						source-slot slot-displacement (storage-slots + depth)
						right-ref right-flags operation-width types members type-count
						layouts member-offsets
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					if all [
						address-type? left-ref types type-count
						integer-type? right-ref types type-count
					][
						stride: pointer-stride left-ref types members type-count
							layouts member-offsets
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
					stack-tags/depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: either all [floating? not comparison?][
						x64-encoder/xmm-frame-store at (capacity - written)
							x64-encoder/XMM0 slot-displacement
								(storage-slots + depth) operation-width
					][
						x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							operation-width
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_JUMP [
					target: instruction/a
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/b >= 0 instruction/b <= depth
						instruction/c = 0
					][return INVALID_IR]
					depth: depth - instruction/b
					if measure? [
						unless merge-target target depth fn/instruction-count
							instruction-depths entry-types entry-flags entry-kinds entry-tags
							stack-types stack-flags stack-kinds stack-tags types type-count [
							return INVALID_IR
						]
					]
					displacement: 0
					if not measure? [
						target-offset: index + 1
						displacement: instruction-offsets/target
							- instruction-offsets/target-offset
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/jump-relative at (capacity - written)
						displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_BRANCH [
					target: instruction/a
					unless all [
						target > 0 target <= fn/instruction-count
						any [instruction/b = 0 instruction/b = 1]
						instruction/c = 0 depth > 0
						stack-kinds/depth = VALUE
						compatible-types? -11 stack-types/depth types type-count
						stack-flags/depth = 0
					][return INVALID_IR]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 4 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1
					if measure? [
						unless merge-target target depth fn/instruction-count
							instruction-depths entry-types entry-flags entry-kinds entry-tags
							stack-types stack-flags stack-kinds stack-tags types type-count [
							return INVALID_IR
						]
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/test-register at (capacity - written)
						x64-encoder/RAX 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					displacement: 0
					if not measure? [
						target-offset: index + 1
						displacement: instruction-offsets/target
							- instruction-offsets/target-offset
					]
					condition: either instruction/b = 1 [5][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/jump-condition at (capacity - written)
						condition displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_SWITCH [
					unless all [
						instruction/a >= 0
						instruction/b > 0
						instruction/b <= switch-count
						instruction/a <= (switch-count - instruction/b)
						instruction/c > 0
						instruction/c <= fn/instruction-count
						depth > 0
						stack-kinds/depth = VALUE
						stack-flags/depth = 0
						integer-type? stack-types/depth types type-count
					][return INVALID_IR]
					ref: stack-types/depth
					width: value-width ref 0 types members type-count
						layouts member-offsets
					operation-width: either width = 8 [8][4]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth)
						ref 0 operation-width types members type-count layouts member-offsets
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1

					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						if any [target <= 0 target > fn/instruction-count][
							return INVALID_IR
						]
						if measure? [
							unless merge-target target depth fn/instruction-count
								instruction-depths entry-types entry-flags entry-kinds entry-tags
								stack-types stack-flags stack-kinds stack-tags types type-count [
								return INVALID_IR
							]
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-immediate at (capacity - written)
							x64-encoder/RDX operation-width switch-case/low switch-case/high
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							39h x64-encoder/RAX x64-encoder/RDX operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						displacement: 0
						if not measure? [
							displacement: instruction-offsets/target
							target-offset: instruction-offsets/index
							displacement: displacement - target-offset
							displacement: displacement
								- ((written - instruction-start) + 6)
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/jump-condition at (capacity - written)
							4 displacement
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						case-index: case-index + 1
					]

					target: instruction/c
					if measure? [
						unless merge-target target depth fn/instruction-count
							instruction-depths entry-types entry-flags entry-kinds entry-tags
							stack-types stack-flags stack-kinds stack-tags types type-count [
							return INVALID_IR
						]
					]
					displacement: 0
					if not measure? [
						displacement: instruction-offsets/target
						target-offset: instruction-offsets/index
						displacement: displacement - target-offset
						displacement: displacement
							- ((written - instruction-start) + 5)
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/jump-relative at (capacity - written)
						displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0
						instruction/b = 0
						instruction/c = 0
					][return INVALID_IR]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/trap at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_RETURN [
					return-ref: instruction/a
					return-value?: (fn/flags and RETURN_VALUE) <> 0
					hidden-return?: win64-hidden-return? fn/return-type fn/flags
						types members type-count layouts member-offsets
					if any [
						return-ref <> fn/return-type
						instruction/c <> 0
						all [return-ref = 0 instruction/b <> 0]
						all [entry? return-value?]
					][return INVALID_IR]
					if return-ref <> 0 [
						if any [depth < 1 stack-kinds/depth <> VALUE][return INVALID_IR]
						either return-value? [
							unless all [
								instruction/b = 0
								stack-flags/depth = 0
								aggregate-ref? stack-types/depth types type-count
								compatible-types? return-ref stack-types/depth types type-count
							][return INVALID_IR]
						][
							unless all [
								compatible-types? return-ref stack-types/depth types type-count
								stack-flags/depth = instruction/b
								machine-value? return-ref instruction/b
									types members type-count layouts member-offsets
							][return INVALID_IR]
						]
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
								layouts member-offsets
							signed: either signed-type? return-ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-slots + depth) width
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
							either return-value? [
								aggregate-width: win64-aggregate-width return-ref
									types members type-count layouts member-offsets
								either hidden-return? [
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RCX slot-displacement
											(storage-slots + depth) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RDX
										(0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									value-size: aggregate-size return-ref
										types members type-count layouts member-offsets
									if value-size <= 0 [return INVALID_IR]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/copy-indirect at
										(capacity - written) value-size
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX
										(0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8 0
								][
									if aggregate-width = 0 [return INVALID_IR]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX slot-displacement
											(storage-slots + depth) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/load-indirect at
										(capacity - written) aggregate-width 0
								]
							][
								width: value-width return-ref instruction/b
									types members type-count layouts member-offsets
								signed: either signed-type? return-ref types type-count [1][0]
								floating?: float-type? return-ref types type-count
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: either floating? [
									x64-encoder/xmm-frame-load at (capacity - written)
										x64-encoder/XMM0 slot-displacement
											(storage-slots + depth) width
								][
									x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX slot-displacement
											(storage-slots + depth) width signed
								]
							]
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
					fallthrough?: false
				]
				true [return UNSUPPORTED]
			]
			index: index + 1
		]
		if measure? [
			target-offset: fn/instruction-count + 1
			instruction-offsets/target-offset: written
		]
		if tag-count <> tag-capacity [return INVALID_IR]
		if fallthrough? [return INVALID_IR]

		if measure? [
			if storage-slots > (2147483647 / 8)[return OUTPUT_FULL]
			slot-bytes: storage-slots * 8
			if max-depth > ((2147483647 - slot-bytes) / 8)[return OUTPUT_FULL]
			slot-bytes: slot-bytes + (max-depth * 8)
			if slot-bytes > (2147483647 - max-outgoing)[return OUTPUT_FULL]
			frame-extra: align (slot-bytes + max-outgoing) 16
			if any [
				frame-extra < 0
				frame-extra > (2147483647 - x64-encoder/BASE_FRAME_SIZE)
			][return OUTPUT_FULL]
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
			ir-type array-type [rsir-type!]
			ir-member [rsir-member!]
			ir-import [rsir-import!]
			ir-global target-global [rsir-global!]
			ir-function [rsir-function!]
			ir-parameter [rsir-parameter!]
			initializer [rsir-initializer!]
			image [codegen-header!]
			image-function target-image-function [codegen-function!]
			image-global target-image-global [codegen-global!]
			image-import [codegen-import!]
			import-refs function-sizes function-frames instruction-offsets
				instruction-depths entry-types entry-flags entry-kinds entry-tags
				stack-types stack-flags stack-kinds stack-tags tag-next tag-slots
				tag-widths result-offsets storage-offsets layouts member-offsets
				references [int-ptr!]
			type-data member-data import-data global-data function-data
				parameter-data initializer-data switch-data instruction-data strings
				function-instructions
				name names-output code rodata-output data-output cursor finish scratch
				[byte-ptr!]
			type-bytes member-bytes import-bytes global-bytes function-bytes
				parameter-bytes initializer-bytes switch-bytes instruction-bytes remaining
				member-count parameter-count initializer-count next-parameter
				strings-size metadata-size function-names-size global-names-size
				import-names-size names-size code-offset code-size function-code-size
				literal-size rodata-offset data-offset image-rodata-size image-data-size
				total-size scratch-count
				id next-instruction next-offset instruction-count function-size entry-size
				code-cursor name-cursor global-size global-align global-offset
				global-reference-count used-import-count import-reference-count
				image-import-count reference-count count first-reference last-library
				library-offset external-offset output-import-id exit-reference-id
				reference-id record-offset variable-mode written base initializer-id
				slot-width item-offset [integer!]
			entry? current-entry? array? protected? [logic!]
	][
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		if any [opt-level < 0 opt-level > 1][return UNSUPPORTED]
		header: as rsir-header! data
		if any [
			header/type-count < 0 header/import-count < 0 header/global-count < 0
			header/switch-count < 0
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
			unless any [variable-mode = 0 variable-mode = VARIADIC
				variable-mode = TYPED variable-mode = CUSTOM][return INVALID_IR]
			case [
				ir-type/kind = -1 [
					if any [ir-type/flags <> 0 ir-type/member-count <> 0
						not valid-type-ref? ir-type/target header/type-count][
						return INVALID_IR
					]
				]
				ir-type/kind = -2 [
					if any [
						ir-type/target <> 0 ir-type/flags <> 0
						ir-type/member-count <= 0
					][return INVALID_IR]
				]
				ir-type/kind = -3 [
					if any [
						ir-type/target <> 0
						not any [ir-type/flags = 0 ir-type/flags = TAGGED_UNION]
						ir-type/member-count <= 0
					][return INVALID_IR]
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
				ir-type/kind = -7 [
					if any [
						not valid-type-ref? ir-type/target header/type-count
						ir-type/member-count <= 0
						not any [ir-type/flags = 1 ir-type/flags = 2
							ir-type/flags = 4 ir-type/flags = 8]
					][return INVALID_IR]
				]
				all [ir-type/kind > 0 ir-type/kind <= 14][
					if any [ir-type/target <> 0 ir-type/flags <> 0
						ir-type/member-count <> 0][return INVALID_IR]
				]
				true [return INVALID_IR]
			]
			if ir-type/kind <> -7 [
				if member-count > (2147483647 - ir-type/member-count)[return INVALID_IR]
				member-count: member-count + ir-type/member-count
			]
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
				ir-member/flags < 0 ir-member/flags > INLINE
				all [ir-member/flags = INLINE
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
			variable-mode: ir-import/flags and VARIABLE_FLAGS
			unless any [variable-mode = 0 variable-mode = VARIADIC
				variable-mode = TYPED variable-mode = CUSTOM][return INVALID_IR]
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
		initializer-count: 0
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				not valid-type-ref? ir-global/type header/type-count
				ir-global/flags < 0 ir-global/flags > (INLINE or PROTECTED)
				all [(ir-global/flags and INLINE) <> 0
					not inline-object-ref? ir-global/type type-data header/type-count]
				ir-global/first-initializer < 0 ir-global/initializer-count < 0
				all [ir-global/initializer-count = 0
					ir-global/first-initializer <> 0]
				all [ir-global/initializer-count > 0
					ir-global/first-initializer <> initializer-count]
			][return INVALID_IR]
			if initializer-count > (2147483647 - ir-global/initializer-count)[
				return INVALID_IR
			]
			initializer-count: initializer-count + ir-global/initializer-count
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
			variable-mode: ir-function/flags and VARIABLE_FLAGS
			unless any [variable-mode = 0 variable-mode = VARIADIC
				variable-mode = TYPED variable-mode = CUSTOM][return INVALID_IR]
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
				ir-parameter/flags < 0 ir-parameter/flags > INLINE
				all [ir-parameter/flags = INLINE
					not aggregate-ref? ir-parameter/type type-data header/type-count]
			][return INVALID_IR]
			id: id + 1
		]

		if initializer-count > (remaining / RSIR_INITIALIZER_SIZE)[return INVALID_IR]
		initializer-bytes: initializer-count * RSIR_INITIALIZER_SIZE
		initializer-data: parameter-data + parameter-bytes
		remaining: remaining - initializer-bytes
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			base: canonical-type ir-global/type type-data header/type-count
			array?: all [
				(ir-global/flags and INLINE) <> 0
				base > 0
				(logical-kind base type-data header/type-count) = -7
			]
			if all [array? ir-global/initializer-count = 0][return INVALID_IR]
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializer-data
					+ (ir-global/first-initializer * RSIR_INITIALIZER_SIZE))
				either array? [
					array-type: as rsir-type! (type-data
						+ ((base - 1) * RSIR_TYPE_SIZE))
					either initializer/kind = BYTES_INITIALIZER [
						if any [
							ir-global/initializer-count <> 1
							initializer/a < 0 initializer/c <> 0
							array-type/flags <> 1
							initializer/b <> array-type/member-count
							(canonical-type array-type/target type-data header/type-count)
								<> -2
						][return INVALID_IR]
					][
						if ir-global/initializer-count <> array-type/member-count [
							return INVALID_IR
						]
						initializer-id: 0
						while [initializer-id < ir-global/initializer-count][
							initializer: as rsir-initializer! (initializer-data
								+ ((ir-global/first-initializer + initializer-id)
									* RSIR_INITIALIZER_SIZE))
							case [
								initializer/kind = SCALAR_INITIALIZER [
									if initializer/c <> 0 [return INVALID_IR]
								]
								initializer/kind = ADDRESS_INITIALIZER [
									if any [
										array-type/flags <> 8
										not valid-static-address-initializer? initializer
											array-type/target id header/global-count
											header/function-count global-data type-data
											header/type-count
									][return INVALID_IR]
								]
								true [return INVALID_IR]
							]
							initializer-id: initializer-id + 1
						]
					]
				][
					if ir-global/initializer-count <> 1 [return INVALID_IR]
					case [
						initializer/kind = SCALAR_INITIALIZER [
							if any [
								initializer/c <> 0
								(ir-global/flags and INLINE) <> 0
								not machine-value? ir-global/type 0 type-data member-data
									header/type-count null null
							][return INVALID_IR]
						]
						initializer/kind = ADDRESS_INITIALIZER [
							if any [
								(ir-global/flags and INLINE) <> 0
								not valid-static-address-initializer? initializer
									ir-global/type id header/global-count
									header/function-count global-data type-data
									header/type-count
							][return INVALID_IR]
						]
						true [return INVALID_IR]
					]
				]
			]
			id: id + 1
		]

		if header/switch-count > (remaining / RSIR_SWITCH_SIZE)[return INVALID_IR]
		switch-bytes: header/switch-count * RSIR_SWITCH_SIZE
		switch-data: initializer-data + initializer-bytes
		remaining: remaining - switch-bytes

		if header/instruction-count > (remaining / RSIR_INSTRUCTION_SIZE)[
			return INVALID_IR
		]
		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		instruction-data: switch-data + switch-bytes
		remaining: remaining - instruction-bytes
		strings: instruction-data + instruction-bytes
		strings-size: remaining

		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializer-data
					+ (ir-global/first-initializer * RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = BYTES_INITIALIZER
					any [
						initializer/b > strings-size
						initializer/a > (strings-size - initializer/b)
					]
				][return INVALID_IR]
			]
			id: id + 1
		]

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
		image-rodata-size: 0
		image-data-size: BITMAP_SIZE
		global-reference-count: 0
		id: 1
		while [id <= header/function-count][
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			image-function/first-reference: 0
			image-function/reference-count: 0
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				ir-global/name < 0 ir-global/name-size < 0
				ir-global/name-size > strings-size
				ir-global/name > (strings-size - ir-global/name-size)
			][return INVALID_IR]
			global-size: 0
			global-align: 0
			unless layout-type ir-global/type ((ir-global/flags and INLINE) <> 0)
				type-data member-data
				header/type-count 0 null null :global-size :global-align [
					return INVALID_IR
				]
			protected?: (ir-global/flags and PROTECTED) <> 0
			either protected? [
				global-offset: align image-rodata-size global-align
			][
				global-offset: align image-data-size global-align
			]
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
			image-global/flags: ir-global/flags and PROTECTED
			either protected? [
				image-rodata-size: global-offset + global-size
			][
				image-data-size: global-offset + global-size
			]
			global-names-size: global-names-size + ir-global/name-size
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < ir-global/initializer-count][
				initializer: as rsir-initializer! (initializer-data
					+ ((ir-global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if initializer/kind = ADDRESS_INITIALIZER [
					image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
						+ (header/function-count * IMAGE_FUNCTION_SIZE)
						+ ((id - 1) * IMAGE_GLOBAL_SIZE))
					if image-global/data-offset > REFERENCE_OFFSET_MASK [return OUTPUT_FULL]
					case [
						initializer/a = GLOBAL_ADDRESS [
							target-image-global: as codegen-global! (output
								+ IMAGE_HEADER_SIZE
								+ (header/function-count * IMAGE_FUNCTION_SIZE)
								+ ((initializer/b - 1) * IMAGE_GLOBAL_SIZE))
							if target-image-global/reference-count = 2147483647 [
								return OUTPUT_FULL
							]
							target-image-global/reference-count:
								target-image-global/reference-count + 1
						]
						initializer/a = FUNCTION_ADDRESS [
							target-image-function: as codegen-function! (output
								+ IMAGE_HEADER_SIZE
								+ ((initializer/b - 1) * IMAGE_FUNCTION_SIZE))
							if target-image-function/reference-count = 2147483647 [
								return OUTPUT_FULL
							]
							target-image-function/reference-count:
								target-image-function/reference-count + 1
						]
						true [return INVALID_IR]
					]
					if global-reference-count = 2147483647 [return OUTPUT_FULL]
					global-reference-count: global-reference-count + 1
				]
				initializer-id: initializer-id + 1
			]
			id: id + 1
		]

		if header/function-count > ((2147483647 - header/import-count) / 3)[
			return OUTPUT_FULL
		]
		scratch-count: header/import-count + (header/function-count * 3)
		if header/instruction-count > ((2147483647 - scratch-count) / 14)[
			return OUTPUT_FULL
		]
		scratch-count: scratch-count + (header/instruction-count * 14)
		if parameter-count > (2147483647 - scratch-count)[return OUTPUT_FULL]
		scratch-count: scratch-count + parameter-count
		if header/type-count > ((2147483647 - scratch-count) / 4)[
			return OUTPUT_FULL
		]
		scratch-count: scratch-count + (header/type-count * 4)
		if member-count > (2147483647 - scratch-count)[return OUTPUT_FULL]
		scratch-count: scratch-count + member-count
		if scratch-count > (2147483647 / 4)[return OUTPUT_FULL]
		scratch: allocate (scratch-count * 4)
		if null? scratch [return OUTPUT_FULL]
		import-refs: as int-ptr! scratch
		function-sizes: import-refs + header/import-count
		function-frames: function-sizes + header/function-count
		instruction-offsets: function-frames + header/function-count
		instruction-depths: instruction-offsets + header/instruction-count
			+ header/function-count
		entry-types: instruction-depths + header/instruction-count
		entry-flags: entry-types + header/instruction-count
		entry-kinds: entry-flags + header/instruction-count
		entry-tags: entry-kinds + header/instruction-count
		stack-types: entry-tags + header/instruction-count
		stack-flags: stack-types + header/instruction-count
		stack-kinds: stack-flags + header/instruction-count
		stack-tags: stack-kinds + header/instruction-count
		tag-next: stack-tags + header/instruction-count
		tag-slots: tag-next + header/instruction-count
		tag-widths: tag-slots + header/instruction-count
		result-offsets: tag-widths + header/instruction-count
		storage-offsets: result-offsets + header/instruction-count
		layouts: storage-offsets + parameter-count
		member-offsets: layouts + (header/type-count * 4)
		id: 1
		while [id <= header/import-count][import-refs/id: 0 id: id + 1]
		count: header/type-count * 4
		id: 1
		while [id <= count][layouts/id: 0 id: id + 1]
		id: 1
		while [id <= member-count][member-offsets/id: -1 id: id + 1]
		id: 1
		while [id <= header/type-count][
			global-size: 0
			global-align: 0
			unless layout-type id true type-data member-data header/type-count 0
				layouts member-offsets :global-size :global-align [
				return release scratch INVALID_IR
			]
			id: id + 1
		]

		function-names-size: 0
		code-size: 0
		literal-size: 0
		entry-size: 0
		next-instruction: 1
		next-offset: 1
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
				stack-types stack-flags stack-kinds stack-tags storage-offsets
				(result-offsets + (next-instruction - 1))
				layouts member-offsets
				(instruction-offsets + (next-offset - 1))
				(instruction-depths + (next-instruction - 1))
				(entry-types + (next-instruction - 1))
				(entry-flags + (next-instruction - 1))
				(entry-kinds + (next-instruction - 1))
				(entry-tags + (next-instruction - 1))
				(tag-next + (next-instruction - 1))
				(tag-slots + (next-instruction - 1))
				(tag-widths + (next-instruction - 1)) import-refs null
				parameter-data function-data import-data global-data type-data member-data
				switch-data (output + IMAGE_HEADER_SIZE) strings null
				header/type-count header/function-count header/import-count
				header/global-count header/switch-count strings-size 0 0 0 0 current-entry?
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
			next-offset: next-offset + ir-function/instruction-count + 1
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
		rodata-offset: align (code-offset + code-size) 4
		if any [
			rodata-offset < 0
			rodata-offset > (2147483647 - image-rodata-size - 3)
		][return release scratch OUTPUT_FULL]
		data-offset: align (rodata-offset + image-rodata-size) 4
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
		image/rodata-size: image-rodata-size

		names-output: output + metadata-size
		name-cursor: 0
		code-cursor: entry-size
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			count: image-function/reference-count
			current-entry?: all [entry? id = header/entry-function]
			image-function/name: name-cursor
			image-function/name-size: ir-function/name-size
			image-function/code-offset: either current-entry? [0][code-cursor]
			image-function/code-size: function-sizes/id
			image-function/frame-size: function-frames/id
			image-function/bitmap-offset: 0
			image-function/bitmap-size: BITMAP_SIZE
			image-function/first-reference: 0
			image-function/reference-count: count
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
		while [id <= header/function-count][
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			count: image-function/reference-count
			image-function/first-reference: either count > 0 [first-reference][0]
			first-reference: first-reference + count
			image-function/reference-count: 0
			id: id + 1
		]
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
		next-offset: 1
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
				stack-types stack-flags stack-kinds stack-tags storage-offsets
				(result-offsets + (next-instruction - 1))
				layouts member-offsets
				(instruction-offsets + (next-offset - 1))
				(instruction-depths + (next-instruction - 1))
				(entry-types + (next-instruction - 1))
				(entry-flags + (next-instruction - 1))
				(entry-kinds + (next-instruction - 1))
				(entry-tags + (next-instruction - 1))
				(tag-next + (next-instruction - 1))
				(tag-slots + (next-instruction - 1))
				(tag-widths + (next-instruction - 1)) import-refs references
				parameter-data function-data import-data global-data type-data member-data
				switch-data (output + IMAGE_HEADER_SIZE) strings
				(code + image-function/code-offset)
				header/type-count header/function-count header/import-count
				header/global-count header/switch-count strings-size image-function/code-offset
				function-code-size image-function/code-size exit-reference-id current-entry?
				:global-reference-count :literal-size (function-frames + (id - 1))
			if written <> image-function/code-size [return release scratch INVALID_IR]
			next-instruction: next-instruction + ir-function/instruction-count
			next-offset: next-offset + ir-function/instruction-count + 1
			id: id + 1
		]

		if literal-size > 0 [copy-memory (code + function-code-size) strings literal-size]
		cursor: code + code-size
		rodata-output: output + rodata-offset
		while [cursor < rodata-output][cursor/1: as byte! 0 cursor: cursor + 1]
		finish: rodata-output + image-rodata-size
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
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
			either (image-global/flags and PROTECTED) <> 0 [
				cursor: rodata-output + image-global/data-offset
			][
				cursor: data-output + image-global/data-offset
			]
			base: canonical-type ir-global/type type-data header/type-count
			array?: all [
				(ir-global/flags and INLINE) <> 0
				base > 0
				(logical-kind base type-data header/type-count) = -7
			]
			slot-width: image-global/data-size
			if array? [
				array-type: as rsir-type! (type-data + ((base - 1) * RSIR_TYPE_SIZE))
				slot-width: array-type/flags
			]
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializer-data
					+ (ir-global/first-initializer * RSIR_INITIALIZER_SIZE))
				either initializer/kind = BYTES_INITIALIZER [
					copy-memory cursor (strings + initializer/a) initializer/b
				][
					initializer-id: 0
					item-offset: 0
					while [initializer-id < ir-global/initializer-count][
						initializer: as rsir-initializer! (initializer-data
							+ ((ir-global/first-initializer + initializer-id)
								* RSIR_INITIALIZER_SIZE))
						case [
							initializer/kind = SCALAR_INITIALIZER [
								unless write-static-scalar (cursor + item-offset) slot-width
									initializer/a initializer/b [
									return release scratch INVALID_IR
								]
							]
							initializer/kind = ADDRESS_INITIALIZER [
								reference-id: 0
								case [
									initializer/a = GLOBAL_ADDRESS [
										target-image-global: as codegen-global! (output
											+ IMAGE_HEADER_SIZE
											+ (header/function-count * IMAGE_FUNCTION_SIZE)
											+ ((initializer/b - 1) * IMAGE_GLOBAL_SIZE))
										reference-id: target-image-global/first-reference
											+ target-image-global/reference-count
										target-image-global/reference-count:
											target-image-global/reference-count + 1
									]
									initializer/a = FUNCTION_ADDRESS [
										target-image-function: as codegen-function! (output
											+ IMAGE_HEADER_SIZE
											+ ((initializer/b - 1) * IMAGE_FUNCTION_SIZE))
										reference-id: target-image-function/first-reference
											+ target-image-function/reference-count
										target-image-function/reference-count:
											target-image-function/reference-count + 1
									]
									true [return release scratch INVALID_IR]
								]
								global-offset: image-global/data-offset + item-offset
								if global-offset > REFERENCE_OFFSET_MASK [
									return release scratch OUTPUT_FULL
								]
								references/reference-id: either
									(image-global/flags and PROTECTED) <> 0 [
										RODATA_REFERENCE_TAG or global-offset
									][DATA_REFERENCE_TAG or global-offset]
							]
							true [return release scratch INVALID_IR]
						]
						initializer-id: initializer-id + 1
						item-offset: item-offset + slot-width
					]
				]
			]
			id: id + 1
		]
		release scratch total-size
	]
]
