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
	export-count      [integer!]
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

rsir-export!: alias struct! [
	symbol    [integer!]
	name      [integer!]
	name-size [integer!]
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
	export-count    [integer!]
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

codegen-export!: alias struct! [
	symbol    [integer!]
	name      [integer!]
	name-size [integer!]
]

signature-pairs!: alias struct! [
	memory        [byte-ptr!]
	pair-count    [integer!]
	pair-capacity [integer!]
	slot-capacity [integer!]
	epoch         [integer!]
]

x64-codegen: context [
	RSIR_HEADER_SIZE:      36
	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_GLOBAL_SIZE:      24
	RSIR_FUNCTION_SIZE:    36
	RSIR_EXPORT_SIZE:      12
	RSIR_PARAMETER_SIZE:    8
	RSIR_INITIALIZER_SIZE: 16
	RSIR_SWITCH_SIZE:      12
	RSIR_INSTRUCTION_SIZE: 16

	IMAGE_HEADER_SIZE:   52
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_GLOBAL_SIZE:   28
	IMAGE_IMPORT_SIZE:   24
	IMAGE_EXPORT_SIZE:   12
	BITMAP_SIZE:         16

	CDECL:          1
	STDCALL:        2
	RETURN_VALUE:  4
	VARIADIC:      8
	TYPED:        16
	CUSTOM:       32
	CALLBACK:      64
	OBJC:        128
	CATCH_FLAG:  256
	RED_INTERNAL: 512
	NO_RETURN:   1024
	EFFECT_RETURNS:        1
	EFFECT_LIVE:           2
	EFFECT_FUNCTION_START: 4
	EFFECT_RESUMES:        8
	EFFECT_CONSTANT_BRANCH: 16
	EFFECT_BRANCH_TAKEN:    32
	EFFECT_ELIDED:          64
	CALL_SHAPE_FLAGS: RETURN_VALUE + VARIADIC + TYPED + CUSTOM + OBJC
	CATCH_CONFLICT_FLAGS: CDECL + STDCALL + VARIADIC + TYPED + CUSTOM + CALLBACK + OBJC
	VARIABLE_FLAGS: 56
	CALLABLE_FLAGS: 1023
	FUNCTION_FLAGS: CALLABLE_FLAGS
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
	OP_OVERFLOW:  23
	OP_CATCH:     24
	OP_END_CATCH: 25
	OP_THROW:     26
	OP_ENTRY:     27
	OP_SUB_CALL:  28
	OP_SUB_RETURN: 29

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

	PLACE: 1
	VALUE: 2

	LOCATION_NONE:           0
	LOCATION_ADDRESS:        1
	LOCATION_FRAME:          2
	LOCATION_FRAME_INDIRECT: 3
	LOCATION_GPR:            4
	LOCATION_XMM:            5
	LOCATION_GLOBAL:         6
	; The two top stack values are held in RAX and RDX respectively.
	LOCATION_GPR_PAIR:       7
	; The two top stack values are held in XMM0 and XMM1 respectively.
	LOCATION_XMM_PAIR:       8
	; Zero means no stack tag, positive values are variant-chain instruction
	; indexes, and -1 marks a direct binary64 literal without colliding with them.
	FLOAT_LITERAL_TAG: -1
	ANY_POINTER_REF: -16

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
			all [ref < 0 ref >= -15]
		]
	]

	canonical-type: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local record [rsir-type!] steps [integer!]
	][
		if ref < 0 [return either ref = -15 [-2][ref]]
		steps: 0
		while [steps < count][
			if any [ref <= 0 ref > count][return 0]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			unless record/kind = -1 [return ref]
			ref: record/target
			if ref < 0 [return either ref = -15 [-2][ref]]
			steps: steps + 1
		]
		0
	]

	typed-runtime-id?: func [id [integer!] return: [logic!]][
		any [
			all [id >= 1 id <= 17]
			id >= 1000
		]
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
			kind = 12 kind = 13 kind = 14 kind = 16
			kind = -2 kind = -3 kind = -4 kind = -6 kind = -7
		]
	]

	address-kind?: func [kind [integer!] return: [logic!]][
		any [
			kind = 12 kind = 13 kind = 16
			kind = -2 kind = -3 kind = -6 kind = -7
		]
	]

	same-reference-category?: func [
		left-kind right-kind [integer!]
		return: [logic!]
	][
		any [
			all [
				any [left-kind = 16 right-kind = 16]
				reference-kind? left-kind
				reference-kind? right-kind
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
		if any [left = ANY_POINTER_REF right = ANY_POINTER_REF][
			return all [reference-kind? left-kind reference-kind? right-kind]
		]
		if any [left-kind = 14 right-kind = 14][
			return all [reference-kind? left-kind reference-kind? right-kind]
		]
		if all [
			any [left = -12 right = -12]
			any [left-kind = 12 left-kind = -6]
			any [right-kind = 12 right-kind = -6]
		][return true]
		if all [right-kind = -7 right > 0][
			right-record: as rsir-type! (types + ((right - 1) * RSIR_TYPE_SIZE))
			target: 0
			case [
				left-kind = 13 [target: -15]
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

	integer-pointer-type: func [
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local id [integer!] record [rsir-type!]
	][
		id: 1
		while [id <= count][
			record: as rsir-type! (types + ((id - 1) * RSIR_TYPE_SIZE))
			if all [
				record/kind = -6
				(canonical-type record/target types count) = -5
			][return id]
			id: id + 1
		]
		0
	]

	cpu-register-id: func [
		name [byte-ptr!]
		size [integer!]
		return: [integer!]
	][
		if any [null? name size < 2 size > 3 name/1 <> as byte! 72h][return -1]
		case [
			size = 2 [
				case [
					name/2 = as byte! 38h [x64-encoder/R8]
					name/2 = as byte! 39h [x64-encoder/R9]
					true [-1]
				]
			]
			name/2 = as byte! 31h [
				case [
					name/3 = as byte! 30h [x64-encoder/R10]
					name/3 = as byte! 31h [x64-encoder/R11]
					name/3 = as byte! 32h [x64-encoder/R12]
					name/3 = as byte! 33h [x64-encoder/R13]
					name/3 = as byte! 34h [x64-encoder/R14]
					name/3 = as byte! 35h [x64-encoder/R15]
					true [-1]
				]
			]
			true [
				case [
					all [name/2 = as byte! 61h name/3 = as byte! 78h][x64-encoder/RAX]
					all [name/2 = as byte! 63h name/3 = as byte! 78h][x64-encoder/RCX]
					all [name/2 = as byte! 64h name/3 = as byte! 78h][x64-encoder/RDX]
					all [name/2 = as byte! 62h name/3 = as byte! 78h][x64-encoder/RBX]
					all [name/2 = as byte! 73h name/3 = as byte! 70h][x64-encoder/RSP]
					all [name/2 = as byte! 62h name/3 = as byte! 70h][x64-encoder/RBP]
					all [name/2 = as byte! 73h name/3 = as byte! 69h][x64-encoder/RSI]
					all [name/2 = as byte! 64h name/3 = as byte! 69h][x64-encoder/RDI]
					true [-1]
				]
			]
		]
	]

	merged-type: func [
		left right [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local left-kind right-kind
	][
		if compatible-types? left right types count [
			left-kind: logical-kind left types count
			if left-kind = 14 [
				right-kind: logical-kind right types count
				if reference-kind? right-kind [return ANY_POINTER_REF]
			]
			return left
		]
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		either all [
			left-kind = right-kind
			any [left-kind = -6 left-kind = -2 left-kind = -3]
		][left][0]
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
		if ref = -15 [ref: -2]
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
						kind = 16
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
			kind = -8 [
				size: 0
				alignment: 1
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

	address-integer-kind?: func [kind [integer!] return: [logic!]][
		any [kind = 5 kind = 6 kind = 7 kind = 8]
	]

	cast-kind: func [
		ref [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local record [rsir-type!] kind steps [integer!]
	][
		; Canonical arithmetic aliases byte! to uint8!, but the cast matrix does not.
		if ref = -15 [return 15]
		if ref < 0 [return 0 - ref]
		steps: 0
		while [steps < count][
			if any [ref <= 0 ref > count][return 0]
			record: as rsir-type! (types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			unless kind = -1 [return either kind = -6 [12][kind]]
			ref: record/target
			if ref = -15 [return 15]
			if ref < 0 [return 0 - ref]
			steps: steps + 1
		]
		0
	]

	cast-compatible-kinds?: func [
		source-kind target-kind [integer!]
		return: [logic!]
	][
		if any [
			source-kind = 0 target-kind = 0
			source-kind = 14 target-kind = 14
		][return false]
		if source-kind = -4 [
			return any [
				target-kind = -4 target-kind = 12
				address-integer-kind? target-kind
			]
		]
		if target-kind = -4 [
			return any [
				source-kind = -4 source-kind = 12 source-kind = 13
				source-kind = -2 source-kind = -3 source-kind = -7
				address-integer-kind? source-kind
			]
		]
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
		if all [
			target-kind = 15
			any [
				source-kind = 12 source-kind = 13
				source-kind = -2 source-kind = -3
			]
		][return false]
		if all [
			any [
				target-kind = 12 target-kind = 13
				target-kind = -2 target-kind = -3
			]
			any [source-kind = 15 source-kind = 11]
		][return false]
		true
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

	function-call-shape: func [
		flags [integer!]
		return: [integer!]
		/local shape [integer!]
	][
		shape: flags and CALL_SHAPE_FLAGS
		if all [
			(shape and VARIADIC) <> 0
			(flags and CDECL) <> 0
		][shape: shape or CDECL]
		shape
	]

	reset-signature-pairs: func [
		pairs [signature-pairs!]
		return: [integer!]
		/local stamps [int-ptr!] index [integer!]
	][
		if null? pairs/memory [
			pairs/pair-capacity: 16
			pairs/slot-capacity: 32
			pairs/memory: allocate (pairs/pair-capacity * 24)
			if null? pairs/memory [return OUTPUT_FULL]
			pairs/epoch: 0
			stamps: as int-ptr! pairs/memory
			stamps: stamps + ((pairs/pair-capacity * 2) + pairs/slot-capacity)
			index: 1
			while [index <= pairs/slot-capacity][
				stamps/index: 0
				index: index + 1
			]
		]
		either pairs/epoch = 2147483647 [
			stamps: as int-ptr! pairs/memory
			stamps: stamps + ((pairs/pair-capacity * 2) + pairs/slot-capacity)
			index: 1
			while [index <= pairs/slot-capacity][
				stamps/index: 0
				index: index + 1
			]
			pairs/epoch: 1
		][pairs/epoch: pairs/epoch + 1]
		pairs/pair-count: 0
		0
	]

	grow-signature-pairs: func [
		pairs [signature-pairs!]
		return: [integer!]
		/local old-memory new-memory [byte-ptr!]
			new-pairs new-slots new-stamps slot hash-slot stamp [int-ptr!]
			new-capacity new-slot-capacity index hash [integer!]
	][
		if pairs/pair-capacity > (2147483647 / 48)[return OUTPUT_FULL]
		new-capacity: pairs/pair-capacity * 2
		new-slot-capacity: pairs/slot-capacity * 2
		new-memory: allocate (new-capacity * 24)
		if null? new-memory [return OUTPUT_FULL]
		new-pairs: as int-ptr! new-memory
		copy-memory new-memory pairs/memory (pairs/pair-count * 8)
		new-slots: new-pairs + (new-capacity * 2)
		new-stamps: new-slots + new-slot-capacity
		index: 1
		while [index <= new-slot-capacity][
			new-stamps/index: 0
			index: index + 1
		]
		index: 0
		while [index < pairs/pair-count][
			slot: new-pairs + (index * 2)
			hash: ((slot/1 * 65599) xor slot/2) and (new-slot-capacity - 1)
			hash-slot: new-slots + hash
			stamp: new-stamps + hash
			while [stamp/1 = pairs/epoch][
				hash: (hash + 1) and (new-slot-capacity - 1)
				hash-slot: new-slots + hash
				stamp: new-stamps + hash
			]
			hash-slot/1: index + 1
			stamp/1: pairs/epoch
			index: index + 1
		]
		old-memory: pairs/memory
		pairs/memory: new-memory
		pairs/pair-capacity: new-capacity
		pairs/slot-capacity: new-slot-capacity
		free old-memory
		0
	]

	free-signature-pairs: func [pairs [signature-pairs!]][
		unless null? pairs/memory [free pairs/memory]
		pairs/memory: null
		pairs/pair-count: 0
		pairs/pair-capacity: 0
		pairs/slot-capacity: 0
		pairs/epoch: 0
	]

	queue-compatible-types: func [
		expected actual [integer!]
		types [byte-ptr!]
		count [integer!]
		pairs [signature-pairs!]
		return: [integer!]
		/local left right left-kind right-kind pair-index hash status [integer!]
			data slots stamps slot hash-slot stamp [int-ptr!]
	][
		if expected = actual [return 1]
		if compatible-types? expected actual types count [return 1]
		left: canonical-type expected types count
		right: canonical-type actual types count
		if any [left <= 0 right <= 0][return 0]
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		unless all [left-kind = -4 right-kind = -4][return 0]
		data: as int-ptr! pairs/memory
		slots: data + (pairs/pair-capacity * 2)
		stamps: slots + pairs/slot-capacity
		hash: ((left * 65599) xor right) and (pairs/slot-capacity - 1)
		hash-slot: slots + hash
		stamp: stamps + hash
		while [stamp/1 = pairs/epoch][
			pair-index: hash-slot/1 - 1
			slot: data + (pair-index * 2)
			if all [slot/1 = left slot/2 = right][return 1]
			hash: (hash + 1) and (pairs/slot-capacity - 1)
			hash-slot: slots + hash
			stamp: stamps + hash
		]
		if pairs/pair-count = pairs/pair-capacity [
			status: grow-signature-pairs pairs
			if status < 0 [return status]
			data: as int-ptr! pairs/memory
			slots: data + (pairs/pair-capacity * 2)
			stamps: slots + pairs/slot-capacity
			hash: ((left * 65599) xor right) and (pairs/slot-capacity - 1)
			hash-slot: slots + hash
			stamp: stamps + hash
			while [stamp/1 = pairs/epoch][
				hash: (hash + 1) and (pairs/slot-capacity - 1)
				hash-slot: slots + hash
				stamp: stamps + hash
			]
		]
		slot: data + (pairs/pair-count * 2)
		slot/1: left
		slot/2: right
		hash-slot/1: pairs/pair-count + 1
		stamp/1: pairs/epoch
		pairs/pair-count: pairs/pair-count + 1
		1
	]

	function-types-compatible: func [
		expected actual [integer!]
		types members [byte-ptr!]
		count [integer!]
		pairs [signature-pairs!]
		return: [integer!]
		/local cursor id status [integer!]
			slot [int-ptr!] left-type right-type [rsir-type!]
			left-member right-member [rsir-member!]
	][
		status: reset-signature-pairs pairs
		if status < 0 [return status]
		status: queue-compatible-types expected actual types count pairs
		if status <> 1 [return status]
		cursor: 0
		while [cursor < pairs/pair-count][
			slot: (as int-ptr! pairs/memory) + (cursor * 2)
			left-type: as rsir-type! (types + ((slot/1 - 1) * RSIR_TYPE_SIZE))
			right-type: as rsir-type! (types + ((slot/2 - 1) * RSIR_TYPE_SIZE))
			if any [
				(function-call-shape left-type/flags)
					<> (function-call-shape right-type/flags)
				left-type/member-count <> right-type/member-count
				all [
					any [left-type/target = 0 right-type/target = 0]
					left-type/target <> right-type/target
				]
			][return 0]
			if left-type/target <> 0 [
				status: queue-compatible-types left-type/target right-type/target
					types count pairs
				if status <> 1 [return status]
			]
			id: 0
			while [id < left-type/member-count][
				left-member: as rsir-member! (members
					+ ((left-type/first-member + id) * RSIR_MEMBER_SIZE))
				right-member: as rsir-member! (members
					+ ((right-type/first-member + id) * RSIR_MEMBER_SIZE))
				if left-member/flags <> right-member/flags [return 0]
				status: queue-compatible-types left-member/type right-member/type
					types count pairs
				if status <> 1 [return status]
				id: id + 1
			]
			cursor: cursor + 1
		]
		1
	]

	sink-compatible-types: func [
		expected actual [integer!]
		types members [byte-ptr!]
		count [integer!]
		pairs [signature-pairs!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		if compatible-types? expected actual types count [return 1]
		left-kind: logical-kind expected types count
		right-kind: logical-kind actual types count
		unless all [left-kind = -4 right-kind = -4][return 0]
		function-types-compatible expected actual types members count pairs
	]

	implicitly-compatible-types: func [
		expected actual tag [integer!]
		allow-float-literal? [logic!]
		types members [byte-ptr!]
		count [integer!]
		pairs [signature-pairs!]
		return: [integer!]
		/local expected-kind actual-kind status [integer!]
	][
		status: sink-compatible-types expected actual types members count pairs
		if status <> 0 [return status]
		expected-kind: logical-kind expected types count
		actual-kind: logical-kind actual types count
		if integer-kind-widens? actual-kind expected-kind [return 1]
		either all [
			allow-float-literal?
			tag = FLOAT_LITERAL_TAG
			actual-kind = 10
			expected-kind = 9
		][1][0]
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

	float-common-ref: func [
		left right [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		left-kind: logical-kind left types count
		right-kind: logical-kind right types count
		unless all [
			any [left-kind = 9 left-kind = 10]
			any [right-kind = 9 right-kind = 10]
		][return 0]
		either any [left-kind = 9 right-kind = 9][-9][-10]
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
		if any [kind = 12 kind = 13 kind = 16][return 1]
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
		if kind = 13 [result/1: -15 return true]
		if any [kind = -2 kind = -3][result/1: base return true]
		unless all [any [kind = -6 kind = -7] base > 0][return false]
		record: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
		result/1: record/target
		valid-type-ref? result/1 count
	]

	static-address-representation-compatible?: func [
		target source [integer!]
		types [byte-ptr!]
		count [integer!]
		return: [logic!]
		/local target-kind source-kind [integer!]
	][
		if compatible-types? target source types count [return true]
		target-kind: logical-kind target types count
		source-kind: logical-kind source types count
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
		expected owner global-count function-count [integer!]
		globals types [byte-ptr!]
		type-count [integer!]
		return: [logic!]
		/local target [rsir-global!] kind pointee source [integer!]
	][
		if initializer/kind <> ADDRESS_INITIALIZER [return false]
		source: either initializer/c = 0 [expected][initializer/c]
		if all [
			initializer/c <> 0
			any [
				not valid-type-ref? source type-count
				not static-address-representation-compatible? expected source types type-count
			]
		][return false]
		case [
			initializer/a = GLOBAL_ADDRESS [
				if any [
					initializer/b <= 0 initializer/b > global-count
					initializer/b = owner
				][return false]
				target: as rsir-global! (globals
					+ ((initializer/b - 1) * RSIR_GLOBAL_SIZE))
				if source = 0 [return true]
				if compatible-types? source target/type types type-count [return true]
				pointee: 0
				unless pointee-type source types type-count :pointee [return false]
				compatible-types? pointee target/type types type-count
			]
			initializer/a = FUNCTION_ADDRESS [
				if any [initializer/b <= 0 initializer/b > function-count][return false]
				kind: logical-kind source types type-count
				any [source = 0 kind = 12 kind = -4 kind = -5 kind = -6]
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
		zero-extend? [logic!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local source-width signed encoded written [integer!] at [byte-ptr!]
	][
		source-width: value-width ref flags types members type-count
			layouts member-offsets
		if source-width <= 0 [return -1]
		signed: either zero-extend? [0][
			either signed-type? ref types type-count [1][0]
		]
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

	move-operation-value: func [
		code [byte-ptr!]
		capacity target source ref flags operation-width [integer!]
		types members [byte-ptr!]
		type-count [integer!]
		layouts member-offsets [int-ptr!]
		return: [integer!]
		/local source-width signed transfer-width encoded written [integer!]
			at [byte-ptr!]
	][
		source-width: value-width ref flags types members type-count
			layouts member-offsets
		unless all [
			source-width > 0
			any [operation-width = 4 operation-width = 8]
		][return -1]
		signed: either signed-type? ref types type-count [1][0]
		transfer-width: either all [
			operation-width = 8 source-width = 8
		][8][4]
		written: 0
		if target <> source [
			encoded: x64-encoder/move-register code capacity target source transfer-width
			if encoded < 0 [return encoded]
			written: encoded
		]
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

	jump-condition-to: func [
		code [byte-ptr!]
		capacity condition target current [integer!]
		return: [integer!]
		/local displacement [integer!]
	][
		displacement: either null? code [0][(target - current) - 6]
		x64-encoder/jump-condition code capacity condition displacement
	]

	division-overflow-check: func [
		code [byte-ptr!]
		capacity target current [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written tail-size [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RAX 80000000h
		if encoded < 0 [return encoded]
		written: written + encoded

		tail-size: x64-encoder/compare-immediate null 0 x64-encoder/RCX -1
		if tail-size < 0 [return tail-size]
		tail-size: tail-size + 6
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 5 tail-size
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RCX -1
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: jump-condition-to at (capacity - written) 4 target
			(current + written)
		if encoded < 0 [return encoded]
		written + encoded
	]

	shift-overflow-check: func [
		code [byte-ptr!]
		capacity source-width operation-width signed count target current [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written alignment original mode [integer!]
	][
		unless all [
			any [source-width = 1 source-width = 2 source-width = 4 source-width = 8]
			any [operation-width = 4 operation-width = 8]
			source-width <= operation-width
			any [signed = 0 signed = 1]
			count > 0 count < (operation-width * 8)
		][return -1]
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RDX x64-encoder/RAX operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		original: x64-encoder/RAX
		alignment: (operation-width - source-width) * 8
		if alignment > 0 [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/shift-immediate at (capacity - written)
				x64-encoder/RDX 4 alignment operation-width
			if encoded < 0 [return encoded]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/R8 x64-encoder/RDX operation-width
			if encoded < 0 [return encoded]
			written: written + encoded
			original: x64-encoder/R8
		]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RDX 4 count operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		mode: either signed = 1 [7][5]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RDX mode count operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			39h x64-encoder/RDX original operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: jump-condition-to at (capacity - written) 5 target
			(current + written)
		if encoded < 0 [return encoded]
		written + encoded
	]

	narrow-overflow-check: func [
		code [byte-ptr!]
		capacity width signed target current [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written lower upper condition [integer!]
	][
		unless all [any [width = 1 width = 2] any [signed = 0 signed = 1]][
			return -1
		]
		upper: case [
			width = 1 [either signed = 1 [127][255]]
			true [either signed = 1 [32767][65535]]
		]
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RAX upper
		if encoded < 0 [return encoded]
		written: written + encoded
		condition: either signed = 1 [15][7]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: jump-condition-to at (capacity - written) condition target
			(current + written)
		if encoded < 0 [return encoded]
		written: written + encoded
		if signed = 1 [
			lower: either width = 1 [-128][-32768]
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/compare-immediate at (capacity - written)
				x64-encoder/RAX lower
			if encoded < 0 [return encoded]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: jump-condition-to at (capacity - written) 12 target
				(current + written)
			if encoded < 0 [return encoded]
			written: written + encoded
		]
		written
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
			count index used size alignment hidden-shift physical-slot [integer!]
	][
		count: fn/parameter-count + fn/local-count
		index: 1
		hidden-shift: either win64-hidden-return? fn/return-type fn/flags
			types members type-count layouts member-offsets [1][0]
		used: hidden-shift * 8
		while [index <= count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			physical-slot: index + hidden-shift
			case [
				all [index <= fn/parameter-count physical-slot > 4][
					if parameter/type = 0 [return INVALID_IR]
					if (physical-slot - 5) > ((2147483647 - 48) / 8)[
						return OUTPUT_FULL
					]
					offsets/index: 48 + ((physical-slot - 5) * 8)
				]
				all [index > fn/parameter-count offsets/index = 0][
					offsets/index: 0
				]
				true [
					if parameter/type = 0 [return INVALID_IR]
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
				]
			]
			index: index + 1
		]
		align used 8
	]

	plan-call-results: func [
		fn [rsir-function!]
		instructions functions imports types members [byte-ptr!]
		function-count import-count type-count used [integer!]
		layouts member-offsets function-effects instruction-effects offsets [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			callee [rsir-function!] imported [rsir-import!]
			signature metadata [rsir-type!]
			index target import-id ref flags size signature-ref [integer!]
	][
		index: 1
		while [index <= fn/instruction-count][
			offsets/index: 0
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			if all [
				instruction/op = OP_CALL
				(instruction-effects/index and EFFECT_LIVE) <> 0
			][
				target: instruction/a
				signature-ref: instruction/c
				if all [
					signature-ref > 0
					(logical-kind signature-ref types type-count) = -8
				][
					signature-ref: canonical-type signature-ref types type-count
					if signature-ref <= 0 [return INVALID_IR]
					metadata: as rsir-type! (types
						+ ((signature-ref - 1) * RSIR_TYPE_SIZE))
					signature-ref: metadata/target
				]
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
						not valid-type-ref? signature-ref type-count
						(logical-kind signature-ref types type-count) <> -4
					][return INVALID_IR]
					signature: as rsir-type! (types
						+ (((canonical-type signature-ref types type-count) - 1)
							* RSIR_TYPE_SIZE))
					ref: signature/target
					flags: signature/flags
				]
				]
				if all [
					(flags and RETURN_VALUE) <> 0
					any [
						target <= 0
						(fn/flags and CATCH_FLAG) <> 0
						(function-effects/target and NO_RETURN) = 0
						win64-hidden-return? ref flags types members type-count
							layouts member-offsets
					]
				][
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

	register-pair-operation?: func [
		operation [integer!]
		floating? [logic!]
		return: [logic!]
	][
		either floating? [
			any [
				all [operation >= ADD_OPERATION operation <= DIVIDE_OPERATION]
				all [operation >= EQUAL_OPERATION operation <= LESS_EQUAL_OPERATION]
			]
		][
			any [
				all [operation >= ADD_OPERATION operation <= MULTIPLY_OPERATION]
				all [operation >= OR_OPERATION operation <= LESS_EQUAL_OPERATION]
			]
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

	emit-catch-open: func [
		code [byte-ptr!]
		capacity record-slot filter-slot target current [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written displacement [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX -8 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX slot-displacement record-slot 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX -16 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX slot-displacement (record-slot + 1) 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RSP slot-displacement (record-slot + 2) 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement filter-slot 4 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -8 4
		if encoded < 0 [return encoded]
		written: written + encoded

		displacement: either null? code [0][target - (current + written + 7)]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/rip-address at (capacity - written)
			x64-encoder/RAX displacement
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -16 8
		if encoded < 0 [return encoded]
		written + encoded
	]

	emit-catch-restore: func [
		code [byte-ptr!]
		capacity record-slot [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement record-slot 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -8 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement (record-slot + 1) 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -16 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RSP slot-displacement (record-slot + 2) 8 0
		if encoded < 0 [return encoded]
		written + encoded
	]

	release: func [
		scratch [byte-ptr!]
		signature-cache [signature-pairs!]
		result [integer!]
		return: [integer!]
	][
		free-signature-pairs signature-cache
		unless null? scratch [free scratch]
		result
	]

	queue-effect: func [
		index bit [integer!]
		effects queue tail [int-ptr!]
		/local position [integer!]
	][
		if (effects/index and bit) = 0 [
			effects/index: effects/index or bit
			position: tail/1 + 1
			tail/1: position
			queue/position: index
		]
	]

	record-effect-use: func [
		target user [integer!]
		heads links targets [int-ptr!]
	][
		links/user: heads/target
		heads/target: user
		targets/user: target
	]

	record-switch-effect-use: func [
		target user slot [integer!]
		heads links users [int-ptr!]
	][
		links/slot: heads/target
		users/slot: user
		heads/target: 0 - slot
	]

	update-call-effects: func [
		index instruction-count [integer!]
		sub-call? [logic!]
		effects targets return-queue resume-queue return-tail resume-tail [int-ptr!]
		/local next-index target [integer!]
			next? target-returns? target-resumes? [logic!]
	][
		next-index: index + 1
		next?: all [
			next-index <= instruction-count
			(effects/next-index and EFFECT_FUNCTION_START) = 0
		]
		target: targets/index
		either sub-call? [
			target-returns?: (effects/target and EFFECT_RETURNS) <> 0
			target-resumes?: (effects/target and EFFECT_RESUMES) <> 0
			if any [
				target-returns?
				all [
					target-resumes? next?
					(effects/next-index and EFFECT_RETURNS) <> 0
				]
			][
				queue-effect index EFFECT_RETURNS effects return-queue return-tail
			]
			if all [
				target-resumes? next?
				(effects/next-index and EFFECT_RESUMES) <> 0
			][
				queue-effect index EFFECT_RESUMES effects resume-queue resume-tail
			]
		][
			target-returns?: any [
				target = 0
				(effects/target and EFFECT_RETURNS) <> 0
			]
			if all [target-returns? next?][
				if (effects/next-index and EFFECT_RETURNS) <> 0 [
					queue-effect index EFFECT_RETURNS effects return-queue return-tail
				]
				if (effects/next-index and EFFECT_RESUMES) <> 0 [
					queue-effect index EFFECT_RESUMES effects resume-queue resume-tail
				]
			]
		]
	]

	infer-effects: func [
		functions instructions switches [byte-ptr!]
		function-count instruction-count switch-count opt-level [integer!]
		function-starts function-effects effects heads queue resume-queue links targets
			switch-links switch-users [int-ptr!]
		return: [integer!]
		/local fn [rsir-function!]
			instruction previous [rsir-instruction!]
			overflow-scope [rsir-instruction!]
			switch-case [rsir-switch!]
			id index global-index function-base target global-target
			case-index switch-id edge user queue-head queue-tail resume-head resume-tail
				next-index effect-bit [integer!]
			catch-caller? constant? taken? [logic!]
	][
		index: 1
		while [index <= instruction-count][
			effects/index: 0
			heads/index: 0
			links/index: 0
			targets/index: 0
			index: index + 1
		]
		index: 1
		while [index <= switch-count][
			switch-links/index: 0
			switch-users/index: 0
			index: index + 1
		]

		function-base: 1
		id: 1
		while [id <= function-count][
			fn: as rsir-function! (functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			function-starts/id: function-base
			function-base: function-base + fn/instruction-count
			id: id + 1
		]
		if function-base <> (instruction-count + 1) [return INVALID_IR]

		queue-tail: 0
		resume-tail: 0
		id: 1
		while [id <= function-count][
			fn: as rsir-function! (functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			function-base: function-starts/id
			catch-caller?: (fn/flags and CATCH_FLAG) <> 0
			index: 1
			while [index <= fn/instruction-count][
				global-index: function-base + index - 1
				if index = 1 [
					effects/global-index: effects/global-index or EFFECT_FUNCTION_START
				]
				instruction: as rsir-instruction! (instructions
					+ ((global-index - 1) * RSIR_INSTRUCTION_SIZE))
				if any [instruction/op < OP_LITERAL instruction/op > OP_SUB_RETURN][
					return INVALID_IR
				]
				if all [instruction/op = OP_FAIL any [
					instruction/a <= 0 instruction/b <> 0 instruction/c <> 0
				]][return INVALID_IR]
				case [
					instruction/op = OP_RETURN [
						queue-effect global-index EFFECT_RETURNS effects queue :queue-tail
					]
					instruction/op = OP_SUB_RETURN [
						queue-effect global-index EFFECT_RESUMES effects resume-queue :resume-tail
					]
					any [
						instruction/op = OP_JUMP
						instruction/op = OP_BRANCH
						instruction/op = OP_CATCH
					][
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: function-base + target - 1
						record-effect-use global-target global-index heads links targets
					]
					instruction/op = OP_BINARY [
						if instruction/b < 0 [return INVALID_IR]
						if instruction/b > 0 [
							target: instruction/b
							if target >= index [return INVALID_IR]
							overflow-scope: as rsir-instruction! (instructions
								+ ((function-base + target - 2) * RSIR_INSTRUCTION_SIZE))
							unless all [
								overflow-scope/op = OP_OVERFLOW
								overflow-scope/b = 0 overflow-scope/c = 0
							][return INVALID_IR]
							target: overflow-scope/a
							if any [target <= index target > fn/instruction-count][
								return INVALID_IR
							]
							global-target: function-base + target - 1
							record-effect-use global-target global-index heads links targets
						]
					]
					instruction/op = OP_SWITCH [
						if any [
							instruction/c <= 0 instruction/c > fn/instruction-count
							instruction/a < 0 instruction/b <= 0
							instruction/b > switch-count
							instruction/a > (switch-count - instruction/b)
						][return INVALID_IR]
						global-target: function-base + instruction/c - 1
						record-effect-use global-target global-index heads links targets
						case-index: 0
						while [case-index < instruction/b][
							switch-id: instruction/a + case-index + 1
							; Each dense switch record is one CFG edge and has one owner.
							if switch-users/switch-id <> 0 [return INVALID_IR]
							switch-case: as rsir-switch! (switches
								+ ((switch-id - 1) * RSIR_SWITCH_SIZE))
							target: switch-case/target
							if any [target <= 0 target > fn/instruction-count][
								return INVALID_IR
							]
							global-target: function-base + target - 1
							record-switch-effect-use global-target global-index switch-id
								heads switch-links switch-users
							case-index: case-index + 1
						]
					]
					instruction/op = OP_CALL [
						if instruction/a > 0 [
							if instruction/a > function-count [return INVALID_IR]
							unless catch-caller? [
								target: instruction/a
								global-target: function-starts/target
								record-effect-use global-target global-index heads links targets
							]
						]
					]
					instruction/op = OP_SUB_CALL [
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: function-base + target - 1
						record-effect-use global-target global-index heads links targets
					]
					true [0]
				]
				index: index + 1
			]
			id: id + 1
		]

		; O2 resolves a literal logic branch only when every path into the branch
		; executes the adjacent literal. The literal and its stack consumption then
		; disappear together; the fixed point sees only the selected CFG edge.
		if opt-level = 2 [
			id: 1
			while [id <= function-count][
				fn: as rsir-function! (functions + ((id - 1) * RSIR_FUNCTION_SIZE))
				function-base: function-starts/id
				index: 2
				while [index <= fn/instruction-count][
					global-index: function-base + index - 1
					instruction: as rsir-instruction! (instructions
						+ ((global-index - 1) * RSIR_INSTRUCTION_SIZE))
					if all [
						instruction/op = OP_BRANCH
						heads/global-index = 0
						any [instruction/b = 0 instruction/b = 1]
						instruction/c = 0
					][
						previous: as rsir-instruction! (instructions
							+ ((global-index - 2) * RSIR_INSTRUCTION_SIZE))
						if all [
							previous/op = OP_LITERAL
							previous/a = -11
							any [previous/b = 0 previous/b = 1]
							previous/c = 0
						][
							effects/global-index: effects/global-index
								or EFFECT_CONSTANT_BRANCH
							taken?: previous/b = instruction/b
							if taken? [
								effects/global-index: effects/global-index
									or EFFECT_BRANCH_TAKEN
							]
							target: global-index - 1
							effects/target: effects/target or EFFECT_ELIDED
						]
					]
					index: index + 1
				]
				id: id + 1
			]
		]

		queue-head: 1
		resume-head: 1
		while [any [queue-head <= queue-tail resume-head <= resume-tail]][
			either queue-head <= queue-tail [
				index: queue/queue-head
				queue-head: queue-head + 1
				effect-bit: EFFECT_RETURNS
			][
				index: resume-queue/resume-head
				resume-head: resume-head + 1
				effect-bit: EFFECT_RESUMES
			]
			if (effects/index and EFFECT_FUNCTION_START) = 0 [
				user: index - 1
				instruction: as rsir-instruction! (instructions
					+ ((user - 1) * RSIR_INSTRUCTION_SIZE))
				case [
					any [instruction/op = OP_CALL instruction/op = OP_SUB_CALL][
						update-call-effects user instruction-count
							(instruction/op = OP_SUB_CALL) effects targets
							queue resume-queue :queue-tail :resume-tail
					]
					instruction/op = OP_BRANCH [
						constant?: (effects/user and EFFECT_CONSTANT_BRANCH) <> 0
						taken?: (effects/user and EFFECT_BRANCH_TAKEN) <> 0
						unless all [constant? taken?][
							either effect-bit = EFFECT_RETURNS [
								queue-effect user effect-bit effects queue :queue-tail
							][
								queue-effect user effect-bit effects resume-queue :resume-tail
							]
						]
					]
					any [
						instruction/op = OP_JUMP
						instruction/op = OP_SWITCH
						instruction/op = OP_FAIL
						instruction/op = OP_THROW
						instruction/op = OP_RETURN
						instruction/op = OP_SUB_RETURN
					][0]
					true [
						either effect-bit = EFFECT_RETURNS [
							queue-effect user effect-bit effects queue :queue-tail
						][
							queue-effect user effect-bit effects resume-queue :resume-tail
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
				instruction: as rsir-instruction! (instructions
					+ ((user - 1) * RSIR_INSTRUCTION_SIZE))
				constant?: (effects/user and EFFECT_CONSTANT_BRANCH) <> 0
				taken?: (effects/user and EFFECT_BRANCH_TAKEN) <> 0
				unless all [
					instruction/op = OP_BRANCH
					constant?
					not taken?
				][
					either any [
						instruction/op = OP_CALL
						instruction/op = OP_SUB_CALL
					][
						update-call-effects user instruction-count
							(instruction/op = OP_SUB_CALL) effects targets
							queue resume-queue :queue-tail :resume-tail
					][
						either effect-bit = EFFECT_RETURNS [
							queue-effect user effect-bit effects queue :queue-tail
						][
							queue-effect user effect-bit effects resume-queue :resume-tail
						]
					]
				]
			]
		]

		; Switch links are no longer needed after the fixed point. Reuse them for
		; the exact global case targets consumed by the forward reachability walk.
		queue-head: 1
		queue-tail: 0
		id: 1
		while [id <= function-count][
			fn: as rsir-function! (functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			function-base: function-starts/id
			queue-effect function-base EFFECT_LIVE effects queue :queue-tail
			index: 1
			while [index <= fn/instruction-count][
				global-index: function-base + index - 1
				instruction: as rsir-instruction! (instructions
					+ ((global-index - 1) * RSIR_INSTRUCTION_SIZE))
				if instruction/op = OP_ENTRY [
					queue-effect global-index EFFECT_LIVE effects queue :queue-tail
				]
				if instruction/op = OP_SWITCH [
					case-index: 0
					while [case-index < instruction/b][
						switch-id: instruction/a + case-index + 1
						switch-case: as rsir-switch! (switches
							+ ((switch-id - 1) * RSIR_SWITCH_SIZE))
						switch-links/switch-id: function-base + switch-case/target - 1
						case-index: case-index + 1
					]
				]
				index: index + 1
			]
			id: id + 1
		]

		while [queue-head <= queue-tail][
			index: queue/queue-head
			queue-head: queue-head + 1
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			target: targets/index
			next-index: index + 1
			if any [
				next-index > instruction-count
				(effects/next-index and EFFECT_FUNCTION_START) <> 0
			][next-index: 0]
			case [
				any [
					instruction/op = OP_FAIL
					instruction/op = OP_THROW
					instruction/op = OP_RETURN
					instruction/op = OP_SUB_RETURN
				][0]
				instruction/op = OP_JUMP [
					queue-effect targets/index EFFECT_LIVE effects queue :queue-tail
				]
				instruction/op = OP_BRANCH [
					constant?: (effects/index and EFFECT_CONSTANT_BRANCH) <> 0
					taken?: (effects/index and EFFECT_BRANCH_TAKEN) <> 0
					either constant? [
						either taken? [
							queue-effect targets/index EFFECT_LIVE effects queue :queue-tail
						][
							if next-index > 0 [
								queue-effect next-index EFFECT_LIVE effects queue :queue-tail
							]
						]
					][
						queue-effect targets/index EFFECT_LIVE effects queue :queue-tail
						if next-index > 0 [
							queue-effect next-index EFFECT_LIVE effects queue :queue-tail
						]
					]
				]
				instruction/op = OP_SWITCH [
					queue-effect targets/index EFFECT_LIVE effects queue :queue-tail
					case-index: 0
					while [case-index < instruction/b][
						switch-id: instruction/a + case-index + 1
						queue-effect switch-links/switch-id EFFECT_LIVE effects queue :queue-tail
						case-index: case-index + 1
					]
				]
				any [instruction/op = OP_BINARY instruction/op = OP_CATCH][
					if targets/index > 0 [
						queue-effect targets/index EFFECT_LIVE effects queue :queue-tail
					]
					if next-index > 0 [
						queue-effect next-index EFFECT_LIVE effects queue :queue-tail
					]
				]
				instruction/op = OP_CALL [
					if all [
						next-index > 0
						any [
							target = 0
							(effects/target and EFFECT_RETURNS) <> 0
						]
					][queue-effect next-index EFFECT_LIVE effects queue :queue-tail]
				]
				instruction/op = OP_SUB_CALL [
					if all [
						next-index > 0
						(effects/target and EFFECT_RESUMES) <> 0
					][queue-effect next-index EFFECT_LIVE effects queue :queue-tail]
				]
				true [
					if next-index > 0 [
						queue-effect next-index EFFECT_LIVE effects queue :queue-tail
					]
				]
			]
		]

		id: 1
		while [id <= function-count][
			function-base: function-starts/id
			function-effects/id: either
				(effects/function-base and EFFECT_RETURNS) = 0
				[NO_RETURN][0]
			id: id + 1
		]
		0
	]

	record-control-use: func [
		uses [int-ptr!]
		target count [integer!]
	][
		if all [
			target > 0 target <= count
			uses/target < 2
		][uses/target: uses/target + 1]
	]

	; Collapse source-independent boolean materialization only when its three
	; interior instructions have no other control-flow entry.
	boolean-diamond?: func [
		index instruction-count [integer!]
		instructions [byte-ptr!]
		catch-depths control-uses [int-ptr!]
		return: [logic!]
		/local branch [rsir-instruction!]
			fall [rsir-instruction!]
			jump [rsir-instruction!]
			target [rsir-instruction!]
			fall-index jump-index target-index join-index [integer!]
	][
		if any [
			instruction-count < 4
			index > (instruction-count - 4)
		][return false]
		fall-index: index + 1
		jump-index: index + 2
		target-index: index + 3
		join-index: index + 4
		branch: as rsir-instruction! (instructions
			+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
		fall: as rsir-instruction! (instructions
			+ ((fall-index - 1) * RSIR_INSTRUCTION_SIZE))
		jump: as rsir-instruction! (instructions
			+ ((jump-index - 1) * RSIR_INSTRUCTION_SIZE))
		target: as rsir-instruction! (instructions
			+ ((target-index - 1) * RSIR_INSTRUCTION_SIZE))
		all [
			branch/op = OP_BRANCH
			branch/a = target-index
			any [branch/b = 0 branch/b = 1]
			branch/c = 0
			fall/op = OP_LITERAL
			fall/a = -11
			fall/b = (1 - branch/b)
			fall/c = 0
			jump/op = OP_JUMP
			jump/a = join-index
			jump/b = 0 jump/c = 0
			target/op = OP_LITERAL
			target/a = -11
			target/b = branch/b
			target/c = 0
			control-uses/fall-index = 0
			control-uses/jump-index = 0
			control-uses/target-index = 1
			catch-depths/fall-index = catch-depths/index
			catch-depths/jump-index = catch-depths/index
			catch-depths/target-index = catch-depths/index
			catch-depths/join-index = catch-depths/index
		]
	]

	merge-target: func [
		target depth instruction-count [integer!]
		instructions [byte-ptr!]
		instruction-depths entry-types entry-flags entry-kinds entry-tags
			stack-types stack-flags stack-kinds stack-tags [int-ptr!]
		types [byte-ptr!]
		type-count [integer!]
		return: [logic!]
		/local
			target-instruction [rsir-instruction!]
			entry-tag stack-tag merged [integer!]
	][
		if any [target <= 0 target > instruction-count][return false]
		target-instruction: as rsir-instruction! (instructions
			+ ((target - 1) * RSIR_INSTRUCTION_SIZE))
		; A resultless subroutine return discards one optional expression value.
		; Normalize it before joining control-flow edges at that return.
		if all [
			target-instruction/op = OP_SUB_RETURN
			target-instruction/a = 0
			depth = 1
		][
			if stack-kinds/depth <> VALUE [return false]
			depth: 0
		]
		either instruction-depths/target >= 0 [
			if instruction-depths/target <> depth [return false]
			if depth > 0 [
				entry-tag: entry-tags/target
				stack-tag: stack-tags/depth
				if entry-tag < 0 [entry-tag: 0]
				if stack-tag < 0 [stack-tag: 0]
				merged: merged-type entry-types/target stack-types/depth
					types type-count
				if any [
					merged = 0
					entry-flags/target <> stack-flags/depth
					entry-kinds/target <> stack-kinds/depth
					entry-tag <> stack-tag
				][return false]
				entry-types/target: merged
				entry-tags/target: entry-tag
			]
		][
			instruction-depths/target: depth
			if depth > 0 [
				entry-types/target: stack-types/depth
				entry-flags/target: stack-flags/depth
				entry-kinds/target: stack-kinds/depth
				stack-tag: stack-tags/depth
				entry-tags/target: either stack-tag < 0 [0][stack-tag]
			]
		]
		true
	]

	emit-custom-argument: func [
		code [byte-ptr!]
		capacity target count displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written load-size [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/R8 count
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		load-size: x64-encoder/register-load null 0 target x64-encoder/R10 displacement
		if load-size < 0 [return OUTPUT_FULL]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 12 load-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/register-load at (capacity - written)
			target x64-encoder/R10 displacement
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-custom-setup: func [
		code [byte-ptr!]
		capacity count-displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written clear-size loop-start patch displacement
			[integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/R8 count-displacement 4 1
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		clear-size: x64-encoder/clear-register null 0 x64-encoder/R8
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 13 clear-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/clear-register at (capacity - written) x64-encoder/R8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R9 x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			01h x64-encoder/RAX x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX count-displacement 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RCX x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RCX -4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		clear-size: x64-encoder/clear-register null 0 x64-encoder/RCX
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 13 clear-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/clear-register at (capacity - written) x64-encoder/RCX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RAX 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			29h x64-encoder/RSP x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/and-immediate at (capacity - written)
			x64-encoder/RSP -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R10 x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/R10 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/stack-address at (capacity - written) x64-encoder/RDX 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		patch: written + 2
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 14 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		loop-start: written
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/register-load at (capacity - written)
			x64-encoder/RAX x64-encoder/R10 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/register-store at (capacity - written)
			x64-encoder/RAX x64-encoder/RDX 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/R10 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RDX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RCX -1
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		displacement: loop-start - (written + 6)
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 15 displacement
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if not null? code [
			x64-encoder/write-i32 (code + patch) (written - (patch + 4))
		]

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R10 x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/R9 4 24
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/RDX 2 8
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/RCX 1 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/R8 3 16
		if encoded < 0 [return encoded]
		written + encoded
	]

	emit-stack-pointer: func [
		code [byte-ptr!]
		capacity source displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX source 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX displacement 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-stack-set: func [
		code [byte-ptr!]
		capacity target displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 8 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			target x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-stack-align: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/and-immediate at (capacity - written)
			x64-encoder/RSP -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX displacement 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-stack-allocate: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		clear? [logic!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 4 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if clear? [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RCX x64-encoder/RAX 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			29h x64-encoder/RSP x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		if clear? [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/R9 x64-encoder/RDI 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RDI x64-encoder/RSP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/clear-register at (capacity - written)
				x64-encoder/RAX
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/repeat-store-quad at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RDI x64-encoder/R9 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX displacement 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-stack-free: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 4 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			01h x64-encoder/RSP x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written + encoded
	]

	emit-stack-all: func [
		code [byte-ptr!]
		capacity [integer!]
		restore? [logic!]
		return: [integer!]
		/local at [byte-ptr!] encoded written register [integer!]
	][
		written: 0
		either restore? [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/fxrstor-stack at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/register-load at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 512
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RSP x64-encoder/RAX 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/pop-flags at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			register: 15
			while [register >= 0][
				if register <> x64-encoder/RSP [
					at: as byte-ptr! 0
					if not null? code [at: code + written]
					encoded: x64-encoder/pop-register at (capacity - written)
						register
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				register: register - 1
			]
		][
			register: 0
			while [register <= 15][
				if register <> x64-encoder/RSP [
					at: as byte-ptr! 0
					if not null? code [at: code + written]
					encoded: x64-encoder/push-register at (capacity - written)
						register
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				register: register + 1
			]
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/push-flags at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/and-immediate at (capacity - written)
				x64-encoder/RSP -16
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/allocate-frame at (capacity - written) 528
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/fxsave-stack at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: x64-encoder/register-store at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 512
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
	]

	compile-function: func [
		fn [rsir-function!]
		signature-cache [signature-pairs!]
		instructions [byte-ptr!]
		function-effects instruction-effects [int-ptr!]
		stack-types stack-flags stack-kinds stack-tags storage-offsets result-offsets
			layouts member-offsets
			instruction-offsets instruction-depths catch-depths control-uses
			entry-types entry-flags entry-kinds
			entry-tags tag-next tag-slots tag-widths import-refs references [int-ptr!]
		parameters functions imports globals types members switches image-data strings code
			[byte-ptr!]
		type-count function-count import-count global-count switch-count strings-size
			function-offset function-code-size capacity exit-reference-id [integer!]
		entry? [logic!]
		global-reference-count literal-size frame-size outgoing-size [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			next-instruction [rsir-instruction!]
			following-instruction [rsir-instruction!]
			overflow-scope [rsir-instruction!]
			catch-scope [rsir-instruction!]
			sub-entry [rsir-instruction!]
			switch-case [rsir-switch!]
			parameter [rsir-parameter!]
			callee [rsir-function!]
			imported [rsir-import!]
			signature typed-metadata list-type [rsir-type!]
			typed-member [rsir-member!]
			global [rsir-global!]
			image-global [codegen-global!]
			target-function [codegen-function!]
			at [byte-ptr!]
			call-parameters [byte-ptr!]
			index depth max-depth kind ref flags width signed source-slot target-slot
			storage-count storage-slots storage-base segment-slots storage-bytes
			storage-size storage-align
			tag-head tag-count tag-capacity tag-base tag-width-value
			operation left-ref right-ref left-flags right-flags
			left-kind right-kind operation-width condition stride
			last-math-operation
			encoded written frame-extra slot-bytes outgoing outgoing-end max-outgoing
			sub-frame
			argument-index argument-base callee-slot native-stack-slot
			argument-slot argument-width physical-slot target return-ref first-parameter
			register-id cpu-pointer-ref
			parameter-count call-flags import-id global-id literal-end displacement
			member-type member-flags member-offset source-width target-width
			target-ref target-flags copy-size copy-align
			result-index reference-id target-offset instruction-start case-index
			operation-ref source-kind target-kind opcode parity keep-cast
			aggregate-width value-size result-offset temp-offset hidden-shift
			physical-count call-mode list-size list-capacity signature-ref
			record-offset overflow-anchor base-depth overflow-limit
			catch-level catch-capacity catch-base catch-record catch-unwind
			catch-threshold allocation-size current-entry current-sub
			location location-depth location-source location-reference source-location
			source-depth
			next-index
			global-reference-id
			main-entry-count sub-entry-count compatibility flags-condition
			pending-immediate-index pending-immediate-value pending-immediate-kind
			[integer!]
			measure? fallthrough? valid? comparison? floating? clear? aggregate-copy?
			return-value? hidden-return? aggregate-argument? indirect? packed-call?
			typed-call? custom-call? list-call? unstable-stack? atomic-old?
			tracked? located? zero-extend? fold-boolean? fold-constant? branch-taken?
			linear? consume-location? global-target? defer-global? paired? set-pair?
			address-pair? load-pair? direct-store? spill-next? fuse-branch? imm-pair?
			imm-call?
			immediate? left-in-register? imm-set? set-fused? set-next?
			scaled-immediate?
			source-located? direct-frame-target? live?
			sub-returns? [logic!]
	][
		measure?: null? code
		if measure? [
			index: 1
			while [index <= fn/instruction-count][
				instruction-depths/index: -1
				control-uses/index: 0
				index: index + 1
			]
		]
		sub-frame: either measure? [8][
			if outgoing-size/1 < 0 [return INVALID_IR]
			if outgoing-size/1 > (2147483647 - 23)[return OUTPUT_FULL]
			(align outgoing-size/1 16) + 8
		]
		tag-capacity: 0
		catch-level: 0
		catch-capacity: 0
		current-sub: -1
		location: LOCATION_NONE
		location-depth: 0
		location-source: 0
		location-reference: 0
		source-location: LOCATION_NONE
		source-depth: 0
		main-entry-count: 0
		sub-entry-count: 0
		unstable-stack?: false
		last-math-operation: 0
		flags-condition: -1
		pending-immediate-index: -1
		pending-immediate-value: 0
		pending-immediate-kind: 0
		cpu-pointer-ref: 0
		storage-count: fn/parameter-count + fn/local-count
		; Before layout, storage offsets also mark which local slots are referenced.
		index: 1
		while [index <= storage-count][
			storage-offsets/index: 0
			index: index + 1
		]
		index: 1
		while [index <= fn/instruction-count][
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			live?: (instruction-effects/index and EFFECT_LIVE) <> 0
			catch-depths/index: catch-level
			if instruction/op = OP_ENTRY [
				if any [catch-level <> 0 current-sub >= 0][return INVALID_IR]
				case [
					instruction/a = 0 [
						if any [instruction/b <> 0 instruction/c <> 0][return INVALID_IR]
						main-entry-count: main-entry-count + 1
						current-sub: 0
					]
					instruction/a = 1 [
						unless all [
							any [instruction/b = 0 valid-type-ref? instruction/b type-count]
							instruction/c = 0
						][return INVALID_IR]
						if all [
							instruction/b <> 0
							not machine-value? instruction/b 0 types members type-count
								layouts member-offsets
						][return UNSUPPORTED]
						sub-entry-count: sub-entry-count + 1
						current-sub: index
					]
					true [return INVALID_IR]
				]
			]
			if instruction/op = OP_SUB_CALL [
				unless all [
					instruction/a > 0 instruction/a <= fn/instruction-count
					instruction/a <> current-sub
				][return INVALID_IR]
				sub-entry: as rsir-instruction! (instructions
					+ ((instruction/a - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					sub-entry/op = OP_ENTRY sub-entry/a = 1
					instruction/b = sub-entry/b instruction/c = 0
				][return INVALID_IR]
			]
			if instruction/op = OP_SUB_RETURN [
				if current-sub <= 0 [return INVALID_IR]
				sub-entry: as rsir-instruction! (instructions
					+ ((current-sub - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					catch-level = 0
					instruction/a = sub-entry/b
					instruction/b = 0 instruction/c = 0
				][return INVALID_IR]
				current-sub: -1
			]
			if instruction/op = OP_CATCH [
				catch-unwind: catch-level + 1
				unless all [
					instruction/a > index instruction/a <= fn/instruction-count
					instruction/b = catch-unwind
					instruction/c = 0
				][return INVALID_IR]
				catch-scope: as rsir-instruction! (instructions
					+ ((instruction/a - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					catch-scope/op = OP_END_CATCH
					catch-scope/a = index
					catch-scope/b = instruction/b
					catch-scope/c = 0
				][return INVALID_IR]
				catch-level: catch-level + 1
				if live? [
					if catch-level > catch-capacity [catch-capacity: catch-level]
				]
			]
			if instruction/op = OP_END_CATCH [
				unless all [
					catch-level > 0 instruction/b = catch-level instruction/c = 0
					instruction/a > 0 instruction/a < index
				][return INVALID_IR]
				catch-scope: as rsir-instruction! (instructions
					+ ((instruction/a - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					catch-scope/op = OP_CATCH catch-scope/a = index
					catch-scope/b = instruction/b
				][return INVALID_IR]
				catch-level: catch-level - 1
			]
			if all [instruction/op = OP_JUMP any [
				instruction/c < 0 instruction/c > catch-level
			]][return INVALID_IR]
			if all [live? instruction/op = OP_MEMBER instruction/b > 0][
				tag-capacity: tag-capacity + 1
			]
			if all [
				live?
				instruction/op = OP_ADDRESS
				instruction/a = LOCAL_ADDRESS
				instruction/b > 0
				instruction/b <= storage-count
			][
				source-slot: instruction/b
				storage-offsets/source-slot: 1
			]
			if all [
				live?
				instruction/op = OP_NATIVE
				any [
					instruction/a = 2
					instruction/a = 3
					all [instruction/a >= 5 instruction/a <= 12]
				]
			][unstable-stack?: true]
			if all [
				live?
				instruction/op = OP_NATIVE
				instruction/a = 15
				instruction/b >= 0 instruction/c > 0
				instruction/c <= strings-size
				instruction/b <= (strings-size - instruction/c)
			][
				register-id: cpu-register-id (strings + instruction/b) instruction/c
				if any [
					register-id = x64-encoder/RSP
					register-id = x64-encoder/RBP
				][unstable-stack?: true]
			]
			if all [measure? live?][
					case [
						any [
							instruction/op = OP_JUMP
							instruction/op = OP_OVERFLOW
							instruction/op = OP_CATCH
						][
							record-control-use control-uses instruction/a
								fn/instruction-count
						]
						instruction/op = OP_BRANCH [
							unless all [
								(instruction-effects/index
									and EFFECT_CONSTANT_BRANCH) <> 0
								(instruction-effects/index
									and EFFECT_BRANCH_TAKEN) = 0
							][
								record-control-use control-uses instruction/a
									fn/instruction-count
							]
						]
						instruction/op = OP_SWITCH [
						record-control-use control-uses instruction/c
							fn/instruction-count
						if all [
							instruction/a >= 0 instruction/b > 0
							instruction/b <= switch-count
							instruction/a <= (switch-count - instruction/b)
						][
							case-index: 0
							while [case-index < instruction/b][
								switch-case: as rsir-switch! (switches
									+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
								record-control-use control-uses switch-case/target
									fn/instruction-count
								case-index: case-index + 1
							]
						]
					]
					true []
				]
			]
			index: index + 1
		]
		if any [
			catch-level <> 0 current-sub > 0
			all [sub-entry-count > 0 main-entry-count <> 1]
			all [sub-entry-count = 0 main-entry-count <> 0]
		][return INVALID_IR]
		storage-bytes: plan-storage fn parameters types members type-count
			layouts member-offsets storage-offsets
		if storage-bytes < 0 [return storage-bytes]
		storage-bytes: plan-call-results fn instructions functions imports types members
			function-count import-count type-count storage-bytes
			layouts member-offsets function-effects instruction-effects result-offsets
		if storage-bytes < 0 [return storage-bytes]
		native-stack-slot: 0
		if unstable-stack? [
			if storage-bytes > (2147483647 - 8)[return OUTPUT_FULL]
			storage-bytes: storage-bytes + 8
			native-stack-slot: storage-bytes / 8
		]
		storage-slots: storage-bytes / 8
		tag-base: storage-slots
		if storage-slots > (2147483647 - tag-capacity)[return OUTPUT_FULL]
		storage-slots: storage-slots + tag-capacity
		catch-base: storage-slots
		if catch-capacity > ((2147483647 - storage-slots) / 3)[return OUTPUT_FULL]
		storage-slots: storage-slots + (catch-capacity * 3)
		storage-base: storage-slots
		segment-slots: 0
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
		current-entry: 0
		fallthrough?: true
		written: 0
		if entry? [
			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/prolog at (capacity - written) 0 -1
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/allocate-frame at (capacity - written) 32
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			target-offset: x64-encoder/frame-store null 0
				x64-encoder/RAX -16 8
			if target-offset < 0 [return OUTPUT_FULL]
			displacement: target-offset + 5
			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/rip-address at (capacity - written)
				x64-encoder/RAX displacement
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/frame-store at (capacity - written)
				x64-encoder/RAX -16 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/call-relative at (capacity - written) 2
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: as byte-ptr! 0
			if not measure? [at: code + written]
			encoded: x64-encoder/trap at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		catch-threshold: either (fn/flags and CATCH_FLAG) <> 0 [-2][0]
		at: as byte-ptr! 0
		if not measure? [at: code + written]
		encoded: x64-encoder/prolog at (capacity - written) 0 catch-threshold
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		allocation-size: 0
		if not measure? [
			frame-extra: frame-size/1 - x64-encoder/BASE_FRAME_SIZE
			if frame-extra < 0 [return INVALID_IR]
			at: code + written
			encoded: x64-encoder/allocate-frame at (capacity - written) frame-extra
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			allocation-size: encoded
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
			if physical-slot <= 4 [
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
			]
			index: index + 1
		]

		clear?: false
		index: fn/parameter-count + 1
		while [index <= storage-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			if all [storage-offsets/index <> 0 parameter/flags = INLINE][
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
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			unless (instruction-effects/index and EFFECT_LIVE) <> 0 [
				if measure? [instruction-offsets/index: written]
				index: index + 1
				continue
			]
			; A subroutine with no result consumes an optional expression value.
			; Frontend statement paths may reach the same return with or without it.
			if all [
				instruction/op = OP_SUB_RETURN
				instruction/a = 0
				depth = 1
			][
				unless stack-kinds/depth = VALUE [return INVALID_IR]
				depth: 0
				location: LOCATION_NONE
				location-depth: 0
				location-source: 0
				source-location: LOCATION_NONE
				source-depth: 0
			]
			if instruction/op = OP_ENTRY [
				if fallthrough? [
					return INVALID_IR
				]
				if max-depth > (2147483647 - segment-slots)[return OUTPUT_FULL]
				segment-slots: segment-slots + max-depth
				if storage-base > (2147483647 - segment-slots)[return OUTPUT_FULL]
				storage-slots: storage-base + segment-slots
				depth: 0
				max-depth: 0
				current-entry: index
				fallthrough?: true
			]
			either fallthrough? [
				if instruction-depths/index >= 0 [
					if measure? [
						if instruction-depths/index <> depth [
							return INVALID_IR
						]
						if depth > 0 [
							tag-head: stack-tags/depth
							if tag-head < 0 [tag-head: 0]
							ref: merged-type entry-types/index stack-types/depth
								types type-count
							if any [
								ref = 0
								entry-flags/index <> stack-flags/depth
								entry-kinds/index <> stack-kinds/depth
								entry-tags/index <> tag-head
							][
								return INVALID_IR
							]
							entry-types/index: ref
						]
					]
					if depth > 0 [
						stack-types/depth: entry-types/index
						stack-flags/depth: entry-flags/index
						stack-kinds/depth: entry-kinds/index
						stack-tags/depth: entry-tags/index
					]
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
			linear?: false
			next-index: index + 1
			if next-index <= fn/instruction-count [
				next-instruction: as rsir-instruction! (instructions
					+ ((next-index - 1) * RSIR_INSTRUCTION_SIZE))
				linear?: all [
					control-uses/next-index = 0
					catch-depths/next-index = catch-depths/index
					next-instruction/op <> OP_ENTRY
				]
			]
			paired?: false
			if all [
				linear?
				any [location = LOCATION_GPR location = LOCATION_XMM]
				instruction/op = OP_LITERAL
				depth > 0
				stack-kinds/depth = VALUE
				stack-flags/depth = 0
				valid-type-ref? instruction/a type-count
				machine-value? instruction/a 0 types members type-count
					layouts member-offsets
				(instruction-effects/next-index and EFFECT_LIVE) <> 0
				(instruction-effects/next-index and EFFECT_ELIDED) = 0
				next-instruction/op = OP_BINARY
				next-instruction/a >= ADD_OPERATION
				next-instruction/a <= LESS_EQUAL_OPERATION
			][
				paired?: either location = LOCATION_XMM [
					all [
						float-type? stack-types/depth types type-count
						float-type? instruction/a types type-count
						register-pair-operation? next-instruction/a true
					]
				][
					all [
						instruction/a = stack-types/depth
						integer-type? stack-types/depth types type-count
						integer-type? instruction/a types type-count
						register-pair-operation? next-instruction/a false
					]
				]
			]
			set-pair?: false
			address-pair?: false
			if all [
				linear?
				any [location = LOCATION_GPR location = LOCATION_XMM]
				instruction/op = OP_ADDRESS
				depth > 0
				stack-kinds/depth = VALUE
				stack-flags/depth = 0
			][
				target-ref: 0
				target-flags: -1
				case [
					all [
						instruction/a = LOCAL_ADDRESS
						instruction/b > 0
						instruction/b <= storage-count
					][
						parameter: as rsir-parameter! (parameters
							+ ((fn/first-parameter + instruction/b - 1)
								* RSIR_PARAMETER_SIZE))
						target-ref: parameter/type
						target-flags: parameter/flags
					]
					all [
						instruction/a = GLOBAL_ADDRESS
						instruction/b > 0
						instruction/b <= global-count
					][
						global: as rsir-global! (globals
							+ ((instruction/b - 1) * RSIR_GLOBAL_SIZE))
						target-ref: global/type
						target-flags: global/flags and INLINE
					]
					true [0]
				]
				if all [
					valid-type-ref? target-ref type-count
					target-flags = 0
					machine-value? target-ref 0 types members type-count
						layouts member-offsets
				][
					floating?: float-type? target-ref types type-count
					valid?: either floating? [
						location = LOCATION_XMM
					][
						all [
							location = LOCATION_GPR
							target-ref = stack-types/depth
						]
					]
					if valid? [
						set-pair?: all [
							target-ref = stack-types/depth
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							(instruction-effects/next-index and EFFECT_ELIDED) = 0
							next-instruction/op = OP_SET
						]
						if all [
							next-instruction/op = OP_LOAD
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							(instruction-effects/next-index and EFFECT_ELIDED) = 0
							next-index < fn/instruction-count
						][
							target: next-index + 1
							following-instruction: as rsir-instruction! (instructions
								+ (next-index * RSIR_INSTRUCTION_SIZE))
							address-pair?: all [
								control-uses/target = 0
								catch-depths/target = catch-depths/index
								(following-instruction/op <> OP_ENTRY)
								(instruction-effects/target and EFFECT_LIVE) <> 0
								(instruction-effects/target and EFFECT_ELIDED) = 0
								following-instruction/op = OP_BINARY
								following-instruction/a >= ADD_OPERATION
								following-instruction/a <= LESS_EQUAL_OPERATION
								register-pair-operation? following-instruction/a floating?
							]
						]
					]
				]
			]
			load-pair?: all [
				linear?
				instruction/op = OP_LOAD
				source-location <> LOCATION_NONE
				source-depth = (depth - 1)
				(instruction-effects/next-index and EFFECT_LIVE) <> 0
				(instruction-effects/next-index and EFFECT_ELIDED) = 0
				next-instruction/op = OP_BINARY
			]
			if location <> LOCATION_NONE [
				unless any [
					all [
						location-depth = depth
						depth > 0
						control-uses/index = 0
					]
					; The preceding literal folded into a pending immediate,
					; so this GPR location names the left operand one slot
					; below the top instead of the top itself.
					all [
						pending-immediate-kind = 1
						pending-immediate-index = (index - 1)
						location = LOCATION_GPR
						location-depth = (depth - 1)
					]
				][return INVALID_IR]
				consume-location?: case [
					any [
						location = LOCATION_ADDRESS
						location = LOCATION_FRAME
						location = LOCATION_FRAME_INDIRECT
						location = LOCATION_GLOBAL
					][
						any [
							instruction/op = OP_LOAD
							instruction/op = OP_REFERENCE
							instruction/op = OP_MEMBER
							instruction/op = OP_SET
							instruction/op = OP_DROP
						]
					]
					any [location = LOCATION_GPR location = LOCATION_XMM][
						any [
							all [instruction/op = OP_LITERAL paired?]
							all [
								instruction/op = OP_ADDRESS
								any [set-pair? address-pair?]
							]
							instruction/op = OP_DROP
							instruction/op = OP_DUPLICATE
							instruction/op = OP_CAST
							instruction/op = OP_BINARY
							instruction/op = OP_SUB_RETURN
							all [
								instruction/op = OP_CALL
								instruction/b > 0
							]
							all [
								instruction/op = OP_UNARY
								location = LOCATION_GPR
							]
					all [
						instruction/op = OP_RETURN
						not entry?
						(fn/flags and RETURN_VALUE) = 0
					]
							all [
								instruction/op = OP_MEMBER
								location = LOCATION_GPR
							]
							all [
								instruction/op = OP_BRANCH
								location = LOCATION_GPR
								(instruction-effects/index
									and EFFECT_CONSTANT_BRANCH) = 0
							]
						]
					]
					any [
						location = LOCATION_GPR_PAIR
						location = LOCATION_XMM_PAIR
					][instruction/op = OP_BINARY]
					true [false]
				]
				unless consume-location? [
					case [
						location = LOCATION_FRAME [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-address at (capacity - written)
								x64-encoder/RAX location-source
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						location = LOCATION_FRAME_INDIRECT [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX location-source 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						any [
							location = LOCATION_ADDRESS
							location = LOCATION_GPR
							location = LOCATION_XMM
						][0]
						location = LOCATION_GLOBAL [return INVALID_IR]
						any [
							location = LOCATION_GPR_PAIR
							location = LOCATION_XMM_PAIR
						][return INVALID_IR]
						true [return INVALID_IR]
					]
					ref: stack-types/depth
					flags: stack-flags/depth
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: case [
						any [
							location = LOCATION_ADDRESS
							location = LOCATION_FRAME
							location = LOCATION_FRAME_INDIRECT
						][
							x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX
								slot-displacement (storage-slots + depth) 8
						]
						location = LOCATION_XMM [
							width: value-width ref flags types members type-count
								layouts member-offsets
							if width <= 0 [return INVALID_IR]
							x64-encoder/xmm-frame-store at (capacity - written)
								x64-encoder/XMM0
								slot-displacement (storage-slots + depth) width
						]
						location = LOCATION_GPR [
							width: either inline-object-ref? ref types type-count [8][
								value-width ref flags types members type-count
									layouts member-offsets
							]
							if width <= 0 [return INVALID_IR]
							target-width: either width = 8 [8][4]
							x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX
								slot-displacement (storage-slots + depth) target-width
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					]
				]
			if (instruction-effects/index and EFFECT_ELIDED) <> 0 [
				if measure? [instruction-offsets/index: written]
				fallthrough?: true
				index: index + 1
				continue
			]
			if measure? [instruction-offsets/index: written]
			instruction-start: written
			fallthrough?: true
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
					stack-tags/depth: either (logical-kind ref types type-count) = 10 [
						FLOAT_LITERAL_TAG
					][0]
					width: value-width ref 0 types members type-count
						layouts member-offsets
					target-width: either width = 8 [8][4]
					floating?: float-type? ref types type-count
					register-id: either all [
						paired?
						location = LOCATION_GPR
					][x64-encoder/RDX][x64-encoder/RAX]
					; A 32-bit integer literal consumed by the adjacent binary
					; operation can become its immediate operand. Integer math
					; requires a 32-bit left value; pointer math first proves that
					; the scaled offset still fits the sign-extended imm32 form.
					target-slot: depth - 1
					; A literal stored straight into a local slot by the
					; following statement assignment skips the register
					; entirely: LITERAL, local ADDRESS, SET, then a dropped
					; statement value.
					imm-set?: false
					if all [
						linear?
						location = LOCATION_NONE
						not floating?
						(logical-kind ref types type-count) <> 11
						next-instruction/op = OP_ADDRESS
						next-instruction/a = LOCAL_ADDRESS
						next-instruction/b > 0
						next-instruction/b <= storage-count
						(index + 3) <= fn/instruction-count
					][
						target: index + 2
						target-offset: index + 3
						following-instruction: as rsir-instruction! (instructions
							+ ((index + 1) * RSIR_INSTRUCTION_SIZE))
						set-next?: following-instruction/op = OP_SET
						following-instruction: as rsir-instruction! (instructions
							+ ((index + 2) * RSIR_INSTRUCTION_SIZE))
						parameter: as rsir-parameter! (parameters
							+ ((fn/first-parameter + next-instruction/b - 1)
								* RSIR_PARAMETER_SIZE))
						imm-set?: all [
							set-next?
							following-instruction/op = OP_DROP
							parameter/type = ref
							parameter/flags = 0
							any [
								target-width = 4
								all [
									target-width = 8
									any [
										all [instruction/c = 0 instruction/b >= 0]
										all [instruction/c = -1 instruction/b < 0]
									]
								]
							]
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							(instruction-effects/next-index and EFFECT_ELIDED) = 0
							control-uses/target = 0
							catch-depths/target = catch-depths/index
							(instruction-effects/target and EFFECT_LIVE) <> 0
							(instruction-effects/target and EFFECT_ELIDED) = 0
							control-uses/target-offset = 0
							catch-depths/target-offset = catch-depths/index
							(instruction-effects/target-offset and EFFECT_LIVE) <> 0
							(instruction-effects/target-offset and EFFECT_ELIDED) = 0
						]
					]
					scaled-immediate?: false
					if all [
						linear?
						depth > 1
						target-width = 4
						integer-type? ref types type-count
						next-instruction/op = OP_BINARY
						any [
							next-instruction/a = ADD_OPERATION
							next-instruction/a = SUBTRACT_OPERATION
						]
						address-type? stack-types/target-slot types type-count
					][
						stride: pointer-stride stack-types/target-slot types members
							type-count layouts member-offsets
						scaled-immediate?: all [
							stride > 0
							either instruction/b < 0 [
								instruction/b >= (80000000h / stride)
							][
								instruction/b <= (7FFFFFFFh / stride)
							]
						]
					]
					imm-pair?: all [
						linear?
						any [
							location = LOCATION_NONE
							location = LOCATION_GPR
						]
						depth > 1
						target-width = 4
						next-instruction/op = OP_BINARY
						next-instruction/b = 0
						not floating?
						next-instruction/a >= ADD_OPERATION
						next-instruction/a <= LESS_EQUAL_OPERATION
						not any [
							next-instruction/a = DIVIDE_OPERATION
							next-instruction/a = REMAINDER_OPERATION
							next-instruction/a = MODULO_OPERATION
						]
						any [
							all [
								integer-type? stack-types/target-slot types type-count
								(value-width stack-types/target-slot 0 types members
									type-count layouts member-offsets) = 4
							]
							all [
								address-type? stack-types/target-slot types type-count
								any [
									next-instruction/a = ADD_OPERATION
									next-instruction/a = SUBTRACT_OPERATION
								]
								scaled-immediate?
							]
						]
						any [
							next-instruction/a < SHIFT_LEFT_OPERATION
							next-instruction/a > SHIFT_LOGICAL_OPERATION
							all [instruction/b >= 0 instruction/b <= 63]
						]
						any [
							all [instruction/c = 0 instruction/b >= 0]
							all [instruction/c = -1 instruction/b < 0]
						]
						(instruction-effects/next-index and EFFECT_LIVE) <> 0
						(instruction-effects/next-index and EFFECT_ELIDED) = 0
					]
					imm-call?: all [
						linear?
						location = LOCATION_NONE
						not floating?
						(logical-kind ref types type-count) <> 11
						next-instruction/op = OP_CALL
						next-instruction/b = 1
						(instruction-effects/next-index and EFFECT_LIVE) <> 0
						(instruction-effects/next-index and EFFECT_ELIDED) = 0
					]
					case [
						imm-set? [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-immediate-store at
								(capacity - written)
								storage-displacement storage-offsets next-instruction/b
								instruction/b target-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							pending-immediate-index: index
							pending-immediate-value: instruction/b
							pending-immediate-kind: 2
							location: LOCATION_NONE
							location-depth: 0
						]
						imm-pair? [
							pending-immediate-index: index
							pending-immediate-value: instruction/b
							pending-immediate-kind: 1
							; A GPR located below the pending immediate is the left
							; operand: keep it in RAX for the consuming operation.
							unless location = LOCATION_GPR [
								location: LOCATION_NONE
								location-depth: 0
							]
						]
						imm-call? [
							pending-immediate-index: index
							pending-immediate-value: instruction/b
							pending-immediate-kind: 3
							location: LOCATION_GPR
							location-depth: depth
						]
						true [
							; A linear literal stays in a register only when a consumer
							; can use it there. LITERAL, CONSTANT, and JUMP never read
							; the located top: they push fresh values or relocate the
							; stack, so the register copy would be flushed back to the
							; same slot before it is ever read. A literal followed by
							; another literal still stays located when that literal
							; pairs with this one for a register binary operation.
							spill-next?: either next-instruction/op = OP_LITERAL [
								either (index + 2) <= fn/instruction-count [
									following-instruction: as rsir-instruction! (instructions
										+ ((index + 1) * RSIR_INSTRUCTION_SIZE))
									any [
										following-instruction/op <> OP_BINARY
										following-instruction/a < ADD_OPERATION
										following-instruction/a > LESS_EQUAL_OPERATION
									]
								][true]
							][
								any [
									next-instruction/op = OP_CONSTANT
									next-instruction/op = OP_JUMP
								]
							]
							direct-store?: all [
								not paired?
								(logical-kind ref types type-count) <> 11
								any [
									target-width = 4
									all [
										target-width = 8
										any [
											all [instruction/c = 0 instruction/b >= 0]
											all [instruction/c = -1 instruction/b < 0]
										]
									]
								]
								any [not linear? spill-next?]
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either direct-store? [
								x64-encoder/frame-immediate-store at (capacity - written)
									slot-displacement (storage-slots + depth)
									instruction/b target-width
							][
								x64-encoder/move-immediate at (capacity - written)
									register-id target-width instruction/b instruction/c
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if all [floating? any [paired? all [linear? not direct-store?]]][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								register-id: either paired? [
									x64-encoder/XMM1
								][x64-encoder/XMM0]
								encoded: x64-encoder/xmm-load-register at
									(capacity - written) register-id x64-encoder/RAX width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							case [
								paired? [
									location: either floating? [
										LOCATION_XMM_PAIR
									][LOCATION_GPR_PAIR]
									location-depth: depth
								]
								all [linear? not direct-store?][
									location: either floating? [LOCATION_XMM][LOCATION_GPR]
									location-depth: depth
								]
								true [
									location: LOCATION_NONE
									location-depth: 0
									unless direct-store? [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/frame-store at
											(capacity - written) x64-encoder/RAX
											slot-displacement (storage-slots + depth) target-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
								]
							]
						]
					]
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
					either linear? [
						location: LOCATION_GPR
						location-depth: depth
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_ADDRESS [
					source-location: either any [set-pair? address-pair?][
						location
					][LOCATION_NONE]
					source-depth: either source-location <> LOCATION_NONE [depth][0]
					ref: 0
					flags: 0
					import-id: 0
					global-id: 0
					defer-global?: false
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
							valid?: all [
								instruction/b <= fn/parameter-count
								parameter/flags = INLINE
								(win64-aggregate-width parameter/type types members
									type-count layouts member-offsets) = 0
							]
							location-source: storage-displacement storage-offsets instruction/b
							if location-source = 0 [return INVALID_IR]
							either linear? [
								location: either valid? [
									LOCATION_FRAME_INDIRECT
								][LOCATION_FRAME]
								encoded: 0
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: either valid? [
									x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX location-source 8 0
								][
									x64-encoder/frame-address at (capacity - written)
										x64-encoder/RAX location-source
								]
							]
						]
						instruction/a = GLOBAL_ADDRESS [
							global-id: instruction/b
							if any [global-id <= 0 global-id > global-count][return INVALID_IR]
							global: as rsir-global! (globals
								+ ((global-id - 1) * RSIR_GLOBAL_SIZE))
							ref: global/type
							flags: global/flags and INLINE
							if all [
								linear?
								any [
									location = LOCATION_NONE
									set-pair?
									address-pair?
								]
								flags = 0
								machine-value? ref flags types members type-count
									layouts member-offsets
							][
								defer-global?: any [
									next-instruction/op = OP_LOAD
									next-instruction/op = OP_SET
								]
							]
							either defer-global? [
								encoded: 0
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/rip-address at (capacity - written)
									x64-encoder/RAX 0
							]
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
							either defer-global? [
								location-reference: reference-id
							][
								references/reference-id:
									function-offset + written + encoded - 4
							]
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
					either defer-global? [
						location: LOCATION_GLOBAL
						location-source: global-id
					][
						if all [linear? location = LOCATION_NONE][
							location: LOCATION_ADDRESS
						]
					]
					either location <> LOCATION_NONE [
						location-depth: depth
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						location-source: 0
					]
				]
				instruction/op = OP_LOAD [
					if any [depth <= 0 stack-kinds/depth <> PLACE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					tracked?: location <> LOCATION_NONE
					global-target?: location = LOCATION_GLOBAL
					either all [
						flags = INLINE
						inline-object-ref? ref types type-count
					][
						if tracked? [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: case [
								location = LOCATION_FRAME [
									x64-encoder/frame-address at (capacity - written)
										x64-encoder/RAX location-source
								]
								location = LOCATION_FRAME_INDIRECT [
									x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX location-source 8 0
								]
								location = LOCATION_GLOBAL [return INVALID_IR]
								location = LOCATION_ADDRESS [0]
								true [return INVALID_IR]
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
						location: LOCATION_NONE
						location-source: 0
						either all [linear? tracked?][
							location: LOCATION_GPR
							location-depth: depth
						][
							if tracked? [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX
									slot-displacement (storage-slots + depth) 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
					][
						unless machine-value? ref flags types members type-count
							layouts member-offsets [
							return UNSUPPORTED
						]
						width: value-width ref flags types members type-count
							layouts member-offsets
						signed: either signed-type? ref types type-count [1][0]
						floating?: float-type? ref types type-count
						register-id: either load-pair? [
							either floating? [x64-encoder/XMM1][x64-encoder/RDX]
						][either floating? [x64-encoder/XMM0][x64-encoder/RAX]]
						if all [
							load-pair?
							not any [
								location = LOCATION_FRAME
								location = LOCATION_GLOBAL
							]
						][return INVALID_IR]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: case [
							location = LOCATION_FRAME [
								either floating? [
									x64-encoder/xmm-frame-load at (capacity - written)
										register-id location-source width
								][
									x64-encoder/frame-load at (capacity - written)
										register-id location-source width signed
								]
							]
							location = LOCATION_FRAME_INDIRECT [
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX location-source 8 0
							]
							location = LOCATION_GLOBAL [
								either floating? [
									x64-encoder/xmm-rip-load at (capacity - written)
										register-id 0 width
								][
									x64-encoder/rip-value-load at (capacity - written)
										register-id 0 width signed
								]
							]
							location = LOCATION_ADDRESS [0]
							location = LOCATION_NONE [
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX
									slot-displacement (storage-slots + depth) 8 0
							]
							true [return INVALID_IR]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if global-target? [
							unless measure? [
								references/location-reference:
									function-offset + written - 4
							]
						]
						if all [location <> LOCATION_FRAME not global-target?][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-load-indirect at (capacity - written)
									x64-encoder/XMM0 x64-encoder/RAX width
							][x64-encoder/load-indirect at (capacity - written) width signed]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						stack-kinds/depth: VALUE
						location: LOCATION_NONE
						location-source: 0
						location-reference: 0
						either linear? [
							location: either load-pair? [
								either floating? [LOCATION_XMM_PAIR][LOCATION_GPR_PAIR]
							][either floating? [LOCATION_XMM][LOCATION_GPR]]
							location-depth: depth
						][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) width
							][
								target-width: either width = 8 [8][4]
								x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX
									slot-displacement (storage-slots + depth) target-width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					source-location: LOCATION_NONE
					source-depth: 0
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
					tracked?: location <> LOCATION_NONE
					if tracked? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: case [
							location = LOCATION_FRAME [
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RAX location-source
							]
							location = LOCATION_FRAME_INDIRECT [
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX location-source 8 0
							]
							location = LOCATION_ADDRESS [0]
							true [return INVALID_IR]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					stack-types/depth: instruction/a
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					location: LOCATION_NONE
					location-source: 0
					if tracked? [
						either linear? [
							location: LOCATION_GPR
							location-depth: depth
						][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX
								slot-displacement (storage-slots + depth) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
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
								stack-types/depth 0 8 false types members type-count
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
					; VALUE PLACE -> VALUE
					source-slot: depth - 1
					target-slot: depth
					if any [depth < 2 stack-kinds/source-slot <> VALUE
						stack-kinds/target-slot <> PLACE][
						return INVALID_IR
					]
					source-located?: source-location <> LOCATION_NONE
					global-target?: location = LOCATION_GLOBAL
					direct-frame-target?: all [
						source-located?
						location = LOCATION_FRAME
					]
					target-offset: location-source
					global-reference-id: location-reference
					target-ref: stack-types/target-slot
					target-flags: stack-flags/target-slot
					tag-head: stack-tags/target-slot
					ref: stack-types/source-slot
					flags: stack-flags/source-slot
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
					][
						compatibility: implicitly-compatible-types target-ref ref
							stack-tags/source-slot false types members type-count
							signature-cache
						if compatibility < 0 [return compatibility]
						unless all [
							compatibility = 1
							target-flags = flags
							machine-value? ref flags types members type-count
								layouts member-offsets
							machine-value? target-ref target-flags types members
								type-count layouts member-offsets
						][
							return INVALID_IR
						]
						target-width: value-width target-ref target-flags types members
							type-count layouts member-offsets
						floating?: float-type? target-ref types type-count
					]

					; The literal two instructions back already stored its
					; immediate straight into the local slot.
					set-fused?: all [
						pending-immediate-kind = 2
						pending-immediate-index = (index - 2)
						not aggregate-copy?
						not floating?
					]
					unless set-fused? [
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: case [
						location = LOCATION_FRAME [
							either source-located? [0][
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RDX location-source
							]
						]
						location = LOCATION_FRAME_INDIRECT [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX location-source 8 0
						]
						location = LOCATION_ADDRESS [
							x64-encoder/move-register at (capacity - written)
								x64-encoder/RDX x64-encoder/RAX 8
						]
						location = LOCATION_GLOBAL [0]
						location = LOCATION_NONE [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					location-reference: 0

					either aggregate-copy? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RCX slot-displacement
								(storage-slots + source-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/copy-indirect at (capacity - written) copy-size
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						depth: source-slot
						stack-types/depth: target-ref
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
					][
						if source-located? [
							valid?: either floating? [
								source-location = LOCATION_XMM
							][source-location = LOCATION_GPR]
							unless valid? [return INVALID_IR]
						]
						unless source-located? [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + source-slot) target-width
							][
								load-operation-value at (capacity - written)
									x64-encoder/RAX slot-displacement
									(storage-slots + source-slot) ref flags target-width false
									types members type-count layouts member-offsets
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either floating? [
							case [
								direct-frame-target? [
									x64-encoder/xmm-frame-store at (capacity - written)
										x64-encoder/XMM0 target-offset target-width
								]
								global-target? [
									x64-encoder/xmm-rip-store at (capacity - written)
										x64-encoder/XMM0 0 target-width
								]
								true [
									x64-encoder/xmm-store-indirect at (capacity - written)
										x64-encoder/RDX x64-encoder/XMM0 target-width
								]
							]
						][
							case [
								direct-frame-target? [
									x64-encoder/frame-store at (capacity - written)
										x64-encoder/RAX target-offset target-width
								]
								global-target? [
									x64-encoder/rip-value-store at (capacity - written)
										x64-encoder/RAX 0 target-width
								]
								true [
									x64-encoder/store-indirect at (capacity - written)
										target-width
								]
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if global-target? [
							unless measure? [
								references/global-reference-id:
									function-offset + written - 4
							]
						]
						depth: source-slot
						stack-types/depth: target-ref
						stack-flags/depth: target-flags
						stack-kinds/depth: VALUE
						unless all [linear? tag-head = 0][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) target-width
							][
								width: either target-width = 8 [8][4]
								x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX
									slot-displacement (storage-slots + depth) width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					]
					if set-fused? [
						pending-immediate-index: -1
						pending-immediate-kind: 0
						location: LOCATION_NONE
						location-depth: 0
						location-source: 0
						location-reference: 0
						depth: source-slot
						stack-types/depth: target-ref
						stack-flags/depth: target-flags
						stack-kinds/depth: VALUE
					]
					source-location: LOCATION_NONE
					source-depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: emit-variant-tags at (capacity - written) tag-head tag-base
						fn/instruction-count instructions tag-next tag-slots tag-widths
					if encoded < 0 [return encoded]
					written: written + encoded
					stack-tags/depth: 0
					if all [not aggregate-copy? not set-fused? linear? tag-head = 0][
						location: either floating? [LOCATION_XMM][LOCATION_GPR]
						location-depth: depth
					]
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
					encoded: case [
						location = LOCATION_FRAME [
							x64-encoder/frame-address at (capacity - written)
								x64-encoder/RAX location-source
						]
						location = LOCATION_FRAME_INDIRECT [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX location-source 8 0
						]
						any [
							location = LOCATION_ADDRESS
							location = LOCATION_GPR
						][0]
						location = LOCATION_NONE [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX
								slot-displacement (storage-slots + depth) 8 0
						]
						true [return INVALID_IR]
					]
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
					stack-types/depth: member-type
					stack-flags/depth: member-flags
					stack-kinds/depth: PLACE
					location: LOCATION_NONE
					location-source: 0
					either linear? [
						location: LOCATION_ADDRESS
						location-depth: depth
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
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
					signature-ref: instruction/c
					typed-call?: all [
						signature-ref > 0
						(logical-kind signature-ref types type-count) = -8
					]
					if typed-call? [
						target-ref: canonical-type signature-ref types type-count
						if target-ref <= 0 [return INVALID_IR]
						typed-metadata: as rsir-type! (types
							+ ((target-ref - 1) * RSIR_TYPE_SIZE))
						signature-ref: typed-metadata/target
					]
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
						call-flags: callee/flags or function-effects/target
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
							not valid-type-ref? signature-ref type-count
							(logical-kind signature-ref types type-count) <> -4
						][return INVALID_IR]
						signature: as rsir-type! (types
							+ (((canonical-type signature-ref types type-count) - 1)
								* RSIR_TYPE_SIZE))
						return-ref: signature/target
						first-parameter: signature/first-member
						parameter-count: signature/member-count
						call-flags: signature/flags
						call-parameters: members
					]]
					call-mode: call-flags and VARIABLE_FLAGS
					custom-call?: call-mode = CUSTOM
					unless typed-call? = (call-mode = TYPED) [return INVALID_IR]
					packed-call?: all [
						call-mode = VARIADIC
						(call-flags and 3) <> CDECL
					]
					list-call?: any [packed-call? typed-call?]
					if packed-call? [
						either all [
							target < 0
							(call-flags and RED_INTERNAL) = 0
						][
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
					if typed-call? [
						unless all [
							typed-metadata/member-count = argument-index
							parameter-count = 2
						][return INVALID_IR]
						parameter: as rsir-parameter! (call-parameters
							+ (first-parameter * RSIR_PARAMETER_SIZE))
						unless all [
							parameter/flags = 0
							(logical-kind parameter/type types type-count) = 5
						][return INVALID_IR]
						parameter: as rsir-parameter! (call-parameters
							+ ((first-parameter + 1) * RSIR_PARAMETER_SIZE))
						target-ref: 0
						unless all [
							parameter/flags = 0
							pointee-type parameter/type types type-count :target-ref
						][return INVALID_IR]
						target-ref: canonical-type target-ref types type-count
						if target-ref <= 0 [return INVALID_IR]
						list-type: as rsir-type! (types
							+ ((target-ref - 1) * RSIR_TYPE_SIZE))
						unless all [
							list-type/kind = -2
							any [
								list-type/member-count = 3
								list-type/member-count = 4
								list-type/member-count = 5
							]
							(aggregate-size target-ref types members type-count
								layouts member-offsets) = 24
						][return INVALID_IR]
						typed-member: as rsir-member! (members
							+ (list-type/first-member * RSIR_MEMBER_SIZE))
						unless all [
							typed-member/flags = 0
							(logical-kind typed-member/type types type-count) = 5
						][return INVALID_IR]
						if list-type/member-count >= 4 [
							typed-member: as rsir-member! (members
								+ ((list-type/first-member + 1) * RSIR_MEMBER_SIZE))
							unless all [
								typed-member/flags = 0
								(logical-kind typed-member/type types type-count) = 5
							][return INVALID_IR]
						]
					]
					unless all [
						argument-index >= 0 argument-index <= depth
						any [indirect? typed-call? instruction/c = return-ref]
						any [
							not custom-call?
							all [
								argument-index = 1
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth types type-count) = 5
							]
						]
						any [
							custom-call?
							list-call?
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
					if all [custom-call? hidden-return?][return UNSUPPORTED]
					hidden-shift: either hidden-return? [1][0]
					physical-count: case [
						custom-call? [0]
						typed-call? [2]
						packed-call? [3]
						true [argument-index]
					]
					if physical-count > (2147483647 - hidden-shift)[return OUTPUT_FULL]
					physical-count: physical-count + hidden-shift
					if physical-count > (((2147483647 - 32) / 8) + 4)[
						return OUTPUT_FULL
					]
					outgoing: either custom-call? [0][32]
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
							not compatible-types? signature-ref stack-types/callee-slot
								types type-count
						][return INVALID_IR]
						argument-base: callee-slot
						result-index: callee-slot - 1
					][
						argument-base: depth - argument-index
						result-index: argument-base
					]
					imm-call?: all [
						pending-immediate-kind = 3
						pending-immediate-index = (index - 1)
						argument-index = 1
						location = LOCATION_GPR
						location-depth = depth
					]
					if imm-call? [
						following-instruction: as rsir-instruction! (instructions
							+ ((pending-immediate-index - 1) * RSIR_INSTRUCTION_SIZE))
					]
					immediate?: all [imm-call? not custom-call? not list-call?]
					if all [imm-call? not immediate?][
						ref: stack-types/depth
						width: value-width ref 0 types members type-count
							layouts member-offsets
						if width <= 0 [return INVALID_IR]
						target-width: either width = 8 [8][4]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-immediate at (capacity - written)
							x64-encoder/RAX target-width following-instruction/b
							following-instruction/c
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						pending-immediate-index: -1
						pending-immediate-kind: 0
					]
					located?: location <> LOCATION_NONE
					if located? [
						ref: stack-types/depth
						flags: stack-flags/depth
						floating?: float-type? ref types type-count
						unless all [
							argument-index > 0
							location-depth = depth
							stack-kinds/depth = VALUE
							any [
								all [floating? location = LOCATION_XMM]
								all [not floating? location = LOCATION_GPR]
							]
						][return INVALID_IR]
						location-source: either floating? [
							x64-encoder/XMM0
						][x64-encoder/RAX]
						if any [
							typed-call?
							custom-call?
							aggregate-ref? ref types type-count
						][
							width: either inline-object-ref? ref types type-count [8][
								value-width ref flags types members type-count
									layouts member-offsets
							]
							if width <= 0 [return INVALID_IR]
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
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							location: LOCATION_NONE
							location-depth: 0
							location-source: 0
							located?: false
						]
					]
					if all [located? not immediate?][
						aggregate-copy?: false
						if all [location = LOCATION_GPR not packed-call?][
							source-slot: 1
							while [all [
								not aggregate-copy?
								source-slot < argument-index
								source-slot <= parameter-count
							]][
								parameter: as rsir-parameter! (call-parameters
									+ ((first-parameter + source-slot - 1)
										* RSIR_PARAMETER_SIZE))
								aggregate-copy?: parameter/flags = INLINE
								source-slot: source-slot + 1
							]
						]
						tracked?: any [
							all [
								location = LOCATION_GPR
								any [
									all [packed-call? argument-index > 1]
									unstable-stack?
									physical-count > 5
									aggregate-copy?
								]
							]
							all [
								location = LOCATION_XMM
								not packed-call?
								argument-index > 1
							]
						]
						if tracked? [
							width: value-width ref flags types members type-count
								layouts member-offsets
							if width <= 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-move-register at (capacity - written)
									x64-encoder/XMM4 x64-encoder/XMM0 width
							][
								target-width: either width = 8 [8][4]
								x64-encoder/move-register at (capacity - written)
									x64-encoder/R11 x64-encoder/RAX target-width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							location-source: either floating? [
								x64-encoder/XMM4
							][x64-encoder/R11]
						]
					]
					temp-offset: align outgoing 16
					if temp-offset < 0 [return OUTPUT_FULL]
					if all [unstable-stack? not custom-call?][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-register at (capacity - written)
							x64-encoder/RAX x64-encoder/RSP 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement native-stack-slot 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						value-size: 0
						if not measure? [value-size: frame-size/1]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/move-immediate at (capacity - written)
							x64-encoder/RAX 8 value-size 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							29h x64-encoder/RSP x64-encoder/RAX 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/and-immediate at (capacity - written)
							x64-encoder/RSP -16
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					; Copy indirect aggregates before loading volatile argument registers.
					source-slot: 1
					while [all [
						not custom-call? not list-call? source-slot <= argument-index
					]][
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
								compatibility: implicitly-compatible-types parameter/type ref
									stack-tags/argument-slot true types members type-count
									signature-cache
								if compatibility < 0 [return compatibility]
								unless all [
									compatibility = 1
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
							tracked?: all [located? argument-slot = location-depth]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either tracked? [
								either location = LOCATION_XMM [
									x64-encoder/xmm-store-register at (capacity - written)
										x64-encoder/RAX location-source width
								][
									target-width: either width = 8 [8][4]
									either location-source = x64-encoder/RAX [0][
										x64-encoder/move-register at (capacity - written)
											x64-encoder/RAX location-source target-width
									]
								]
							][
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + argument-slot) width signed
							]
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
					if typed-call? [
						if argument-index > (2147483647 / 24)[return OUTPUT_FULL]
						list-size: argument-index * 24
						list-capacity: either list-size < 8 [8][list-size]
						if temp-offset > (2147483647 - list-capacity)[
							return OUTPUT_FULL
						]
						outgoing-end: temp-offset + list-capacity
						if outgoing-end > max-outgoing [max-outgoing: outgoing-end]
						source-slot: 1
						while [source-slot <= argument-index][
							argument-slot: argument-base + source-slot
							ref: stack-types/argument-slot
							flags: stack-flags/argument-slot
							typed-member: as rsir-member! (members
								+ ((typed-metadata/first-member + source-slot - 1)
									* RSIR_MEMBER_SIZE))
							unless all [
								stack-kinds/argument-slot = VALUE
								flags = 0
								compatible-types? typed-member/type ref types type-count
								machine-value? ref flags types members type-count
									layouts member-offsets
								typed-runtime-id? typed-member/flags
							][return INVALID_IR]
							width: value-width ref flags types members type-count
								layouts member-offsets
							if width <= 0 [return UNSUPPORTED]
							record-offset: temp-offset + ((source-slot - 1) * 24)
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/outgoing-immediate-store
								at (capacity - written) record-offset typed-member/flags
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/outgoing-immediate-store
								at (capacity - written) (record-offset + 4) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							floating?: float-type? ref types type-count
							either floating? [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
									(storage-slots + argument-slot) width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-outgoing-store at
									(capacity - written) x64-encoder/XMM0
									(record-offset + 8) width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if width = 4 [
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/outgoing-immediate-store at
										(capacity - written) (record-offset + 12) 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							][
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
								encoded: x64-encoder/outgoing-store at
									(capacity - written) (record-offset + 8) 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							kind: logical-kind ref types type-count
							either any [kind = 7 kind = 8][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX
									((slot-displacement (storage-slots + argument-slot)) + 4)
									4 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/outgoing-store at
									(capacity - written) (record-offset + 16) 4
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/outgoing-immediate-store at
									(capacity - written) (record-offset + 16) 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/outgoing-immediate-store at
								(capacity - written) (record-offset + 20) 0
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
					]
					temp-offset: align outgoing 16
					source-slot: 1
					while [all [
						not custom-call? not list-call? source-slot <= argument-index
					]][
						argument-slot: argument-base + source-slot
						ref: stack-types/argument-slot
						flags: stack-flags/argument-slot
						target-ref: ref
						target-flags: flags
						aggregate-argument?: false
						aggregate-width: 0
						if source-slot <= parameter-count [
							parameter: as rsir-parameter! (call-parameters
								+ ((first-parameter + source-slot - 1)
									* RSIR_PARAMETER_SIZE))
							target-ref: parameter/type
							target-flags: parameter/flags
							aggregate-argument?: parameter/flags = INLINE
							if aggregate-argument? [
								aggregate-width: win64-aggregate-width parameter/type
									types members type-count layouts member-offsets
							]
						]
						if all [
							source-slot > parameter-count
							call-mode = VARIADIC
							(call-flags and CDECL) <> 0
							(call-flags and OBJC) = 0
							(logical-kind ref types type-count) = 9
						][
							target-ref: -10
							target-flags: 0
						]
						physical-slot: source-slot + hidden-shift
						; Win64 stack arguments always occupy complete 8-byte slots.
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
									8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							if aggregate-width = 0 [
								outgoing-end: temp-offset + value-size
								temp-offset: align outgoing-end 16
							]
						][
							source-width: value-width ref flags types members type-count
								layouts member-offsets
							argument-width: value-width target-ref target-flags types members
								type-count layouts member-offsets
							floating?: float-type? target-ref types type-count
							tracked?: all [located? argument-slot = location-depth]
							target-width: either argument-width = 8 [8][4]
							either physical-slot <= 4 [
								target-slot: argument-register physical-slot
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: either floating? [
									either tracked? [
										either source-width = argument-width [
											either (physical-slot - 1) = location-source [0][
												x64-encoder/xmm-move-register at
													(capacity - written) (physical-slot - 1)
													location-source source-width
											]
										][
											x64-encoder/xmm-convert at (capacity - written)
												(physical-slot - 1) location-source
												source-width argument-width
										]
									][
										x64-encoder/xmm-frame-load at (capacity - written)
											(physical-slot - 1) slot-displacement
												(storage-slots + argument-slot) source-width
									]
								][
									either immediate? [
										x64-encoder/move-immediate at (capacity - written)
											target-slot target-width following-instruction/b
											following-instruction/c
									][either tracked? [
										move-operation-value at (capacity - written)
											target-slot location-source ref flags target-width
											types members type-count layouts member-offsets
									][
										load-operation-value at (capacity - written)
											target-slot slot-displacement
											(storage-slots + argument-slot) ref flags
											argument-width false types members type-count
											layouts member-offsets
									]]
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if all [
									floating? not tracked? source-width <> argument-width
								][
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/xmm-convert at
										(capacity - written) (physical-slot - 1)
										(physical-slot - 1) source-width argument-width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
								if all [floating? (call-flags and VARIADIC) <> 0][
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/xmm-store-register at
										(capacity - written) target-slot
										(physical-slot - 1) argument-width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							][
								either tracked? [
									either floating? [
										register-id: location-source
										if source-width <> argument-width [
											at: as byte-ptr! 0
											if not measure? [at: code + written]
											encoded: x64-encoder/xmm-convert at
												(capacity - written) x64-encoder/XMM0
												location-source source-width argument-width
											if encoded < 0 [return OUTPUT_FULL]
											written: written + encoded
											register-id: x64-encoder/XMM0
										]
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-outgoing-store at
											(capacity - written) register-id
											(32 + ((physical-slot - 5) * 8)) argument-width
									][
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: move-operation-value at (capacity - written)
											x64-encoder/RAX location-source ref flags target-width
											types members type-count layouts member-offsets
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/outgoing-store at
											(capacity - written)
											(32 + ((physical-slot - 5) * 8)) 8
									]
								][
									either all [floating? source-width <> argument-width][
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + argument-slot)
											source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-convert at
											(capacity - written) x64-encoder/XMM0
											x64-encoder/XMM0 source-width argument-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-outgoing-store at
											(capacity - written) x64-encoder/XMM0
											(32 + ((physical-slot - 5) * 8)) argument-width
									][
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: load-operation-value at (capacity - written)
											x64-encoder/RAX slot-displacement
											(storage-slots + argument-slot) ref flags
											argument-width false types members type-count
											layouts member-offsets
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/outgoing-store at
											(capacity - written)
											(32 + ((physical-slot - 5) * 8)) 8
									]
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
						source-slot: source-slot + 1
					]
					if immediate? [
						pending-immediate-index: -1
						pending-immediate-kind: 0
					]
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
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
						target-slot: either custom-call? [
							x64-encoder/R11
						][x64-encoder/RAX]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							target-slot slot-displacement
								(storage-slots + callee-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if custom-call? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: emit-custom-setup at (capacity - written)
							slot-displacement (storage-slots + depth)
						if encoded < 0 [return encoded]
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
								(capacity - written) target-slot
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
					if custom-call? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RSP slot-displacement
								(storage-slots + depth) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if all [unstable-stack? not custom-call?][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RSP slot-displacement native-stack-slot 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if all [
						target > 0
						(call-flags and NO_RETURN) <> 0
						(fn/flags and CATCH_FLAG) = 0
					][
						fallthrough?: false
					]
					depth: result-index
					if all [fallthrough? return-ref <> 0][
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
							tracked?: all [linear? fallthrough?]
							if all [tracked? not floating? width < 4][
								signed: either signed-type? return-ref types type-count [1][0]
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/extend-narrow-register at
									(capacity - written) x64-encoder/RAX x64-encoder/RAX
									width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either tracked? [0][
								either floating? [
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
							if tracked? [
								location: either floating? [LOCATION_XMM][LOCATION_GPR]
								location-depth: depth
								location-source: 0
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
					source-kind: cast-kind ref types type-count
					target-kind: cast-kind instruction/a types type-count
					unless cast-compatible-kinds? source-kind target-kind [
						return INVALID_IR
					]
					floating?: any [
						any [source-kind = 9 source-kind = 10]
						any [target-kind = 9 target-kind = 10]
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
					valid?: any [
						all [
							flags = instruction/b
							source-kind = target-kind
							source-width = target-width
						]
						all [
							not floating?
							flags = 0 instruction/b = 0
							source-width = target-width
							any [
								all [
									reference-kind? source-kind
									reference-kind? target-kind
								]
								any [source-kind = -4 target-kind = -4]
							]
						]
					]
					located?: location <> LOCATION_NONE
					if any [
						all [
							located?
							any [source-kind = 9 source-kind = 10]
							location <> LOCATION_XMM
						]
						all [
							located?
							not any [source-kind = 9 source-kind = 10]
						location <> LOCATION_GPR
						]
					][return INVALID_IR]
					tracked?: located?
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					unless valid? [
						tracked?: true
						either floating? [
							case [
								keep-cast = 1 [
									either source-kind = 5 [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: either located? [
											x64-encoder/xmm-load-register at
												(capacity - written) x64-encoder/XMM0
												x64-encoder/RAX 4
										][
											x64-encoder/xmm-frame-load at
												(capacity - written) x64-encoder/XMM0
												slot-displacement (storage-slots + depth) 4
										]
									][
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: either located? [
											x64-encoder/xmm-store-register at
												(capacity - written) x64-encoder/RAX
												x64-encoder/XMM0 4
										][
											x64-encoder/frame-load at
												(capacity - written) x64-encoder/RAX
											slot-displacement (storage-slots + depth) 4 0
										]
									]
								]
								source-kind = 5 [
									unless located? [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/frame-load at
											(capacity - written) x64-encoder/RAX
											slot-displacement (storage-slots + depth) 4 1
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/integer-to-xmm at
										(capacity - written) x64-encoder/XMM0
										x64-encoder/RAX 4 target-width
								]
								target-kind = 5 [
									unless located? [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + depth) source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/xmm-to-integer at
										(capacity - written) x64-encoder/RAX
										x64-encoder/XMM0 source-width 4
								]
								true [
									unless located? [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + depth) source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/xmm-convert at
										(capacity - written) x64-encoder/XMM0 x64-encoder/XMM0
										source-width target-width
								]
							]
						][
							signed: either signed-type? ref types type-count [1][0]
							unless located? [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) source-width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							encoded: 0
							either target-kind = 11 [
								width: either source-width = 8 [8][4]
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/test-register at (capacity - written)
									x64-encoder/RAX width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/condition-result at
									(capacity - written) 5
							][
								if target-width < 4 [
									signed: either signed-type? instruction/a types type-count [1][0]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/extend-narrow-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RAX
										target-width signed
								]
								if all [target-width = 4 source-width = 8][
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RAX 4
								]
								if all [target-width = 8 source-width < 8 signed = 1][
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/sign-extend-eax at (capacity - written)
								]
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if tracked? [
						either linear? [
							location: either any [target-kind = 9 target-kind = 10][
								LOCATION_XMM
							][LOCATION_GPR]
							location-depth: depth
						][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either any [target-kind = 9 target-kind = 10][
								x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) target-width
							][
								width: either target-width = 8 [8][4]
								x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					stack-types/depth: instruction/a
					stack-flags/depth: instruction/b
					stack-tags/depth: 0
				]
				instruction/op = OP_SIZE [
					ref: instruction/a
					unless all [
						valid-type-ref? ref type-count
						any [instruction/b = 0 instruction/b = 1]
					][return INVALID_IR]
					either instruction/b = 0 [
						if instruction/c <> 0 [return INVALID_IR]
						depth: depth + 1
					][
						unless all [
							depth > 0
							stack-kinds/depth = VALUE
							stack-types/depth = ref
							stack-flags/depth = instruction/c
						][return INVALID_IR]
					]
					width: logical-size ref types members type-count
						layouts member-offsets
					if width <= 0 [return INVALID_IR]
					if depth > max-depth [max-depth: depth]
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					kind: logical-kind ref types type-count
					either all [instruction/b = 1 kind = 13][
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + depth) 8 0
					][
						encoded: x64-encoder/move-immediate at (capacity - written)
							x64-encoder/RAX 4 width 0
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if all [instruction/b = 1 kind = 13][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/c-string-size at (capacity - written)
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_NATIVE [
					valid?: case [
						all [instruction/a >= 14 instruction/a <= 15][
							all [
								instruction/b >= 0 instruction/c > 0
								instruction/c <= strings-size
								instruction/b <= (strings-size - instruction/c)
							]
						]
						instruction/a = 21 [
							any [
								all [instruction/b >= 1 instruction/b <= 5]
								all [instruction/b >= 9 instruction/b <= 13]
							]
						]
						true [instruction/b = 0]
					]
					unless valid? [return INVALID_IR]
					if all [instruction/a >= 14 instruction/a <= 15][
						register-id: cpu-register-id
							(strings + instruction/b) instruction/c
						if register-id < 0 [return UNSUPPORTED]
						if cpu-pointer-ref = 0 [
							cpu-pointer-ref: integer-pointer-type types type-count
						]
						if cpu-pointer-ref = 0 [return INVALID_IR]
					]
					switch instruction/a [
						1 [						;-- system/stack/top
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-pointer at (capacity - written)
								x64-encoder/RSP slot-displacement
									(storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						2 [						;-- PUSH
							unless instruction/c = 0 [return INVALID_IR]
							unless all [
								depth > 0
								stack-kinds/depth = VALUE
								machine-value? stack-types/depth stack-flags/depth
									types members type-count layouts member-offsets
							][return INVALID_IR]
							width: value-width stack-types/depth stack-flags/depth
								types members type-count layouts member-offsets
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) width 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/push-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth - 1
						]
						3 [						;-- POP
							unless instruction/c = 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/pop-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						4 [						;-- system/stack/frame
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-pointer at (capacity - written)
								x64-encoder/RBP slot-displacement
									(storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						5 [						;-- system/stack/top:
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatible-types? instruction/c stack-types/depth
									types type-count
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-set at (capacity - written)
								x64-encoder/RSP slot-displacement
									(storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
							stack-types/depth: instruction/c
							stack-tags/depth: 0
						]
						6 [						;-- system/stack/frame:
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatible-types? instruction/c stack-types/depth
									types type-count
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-set at (capacity - written)
								x64-encoder/RBP slot-displacement
									(storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
							stack-types/depth: instruction/c
							stack-tags/depth: 0
						]
						7 [						;-- system/stack/align
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-align at (capacity - written)
								slot-displacement (storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						8 [						;-- system/stack/allocate
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth types type-count) = 5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-allocate at (capacity - written)
								slot-displacement (storage-slots + depth) false
							if encoded < 0 [return encoded]
							written: written + encoded
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
						]
						9 [						;-- system/stack/allocate/zero
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth types type-count) = 5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-allocate at (capacity - written)
								slot-displacement (storage-slots + depth) true
							if encoded < 0 [return encoded]
							written: written + encoded
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
						]
						10 [					;-- system/stack/free
							unless all [
								instruction/c = 0
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth types type-count) = 5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-free at (capacity - written)
								slot-displacement (storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
							depth: depth - 1
						]
						11 [					;-- system/stack/push-all
							unless instruction/c = 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-all at (capacity - written) false
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						12 [					;-- system/stack/pop-all
							unless instruction/c = 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: emit-stack-all at (capacity - written) true
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						13 [					;-- system/pc
							unless all [
								valid-type-ref? instruction/c type-count
								pointee-type instruction/c types type-count :target-ref
								(canonical-type target-ref types type-count) = -2
							][return INVALID_IR]
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/call-relative at (capacity - written) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/pop-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						14 [					;-- system/cpu/<register>
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: cpu-pointer-ref
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							if register-id <> x64-encoder/RAX [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									x64-encoder/RAX register-id 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						15 [					;-- system/cpu/<register>:
							unless all [
								depth > 0 stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatible-types? cpu-pointer-ref stack-types/depth
									types type-count
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if register-id <> x64-encoder/RAX [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									register-id x64-encoder/RAX 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							stack-types/depth: cpu-pointer-ref
							stack-flags/depth: 0
							stack-tags/depth: 0
						]
						16 [					;-- system/cpu/overflow?
							unless instruction/c = -11 [return INVALID_IR]
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either all [
								last-math-operation >= DIVIDE_OPERATION
								last-math-operation <= MODULO_OPERATION
							][
								x64-encoder/move-immediate at (capacity - written)
									x64-encoder/RAX 4 0 0
							][
								x64-encoder/condition-result at (capacity - written) 0
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						17 [					;-- system/atomic/fence
							unless instruction/c = 0 [return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/memory-fence at (capacity - written)
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						18 [					;-- system/atomic/load
							unless all [
								instruction/c = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth types type-count) = -6
								pointee-type stack-types/depth types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/register-load-indirect at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
						]
						19 [					;-- system/atomic/store
							target-slot: depth - 1
							unless all [
								instruction/c = 0
								depth > 1
								stack-kinds/target-slot = VALUE
								stack-flags/target-slot = 0
								(logical-kind stack-types/target-slot types type-count) = -6
								pointee-type stack-types/target-slot types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth types type-count) = -5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/register-store-indirect at
								(capacity - written) x64-encoder/RDX x64-encoder/RAX 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/memory-fence at (capacity - written)
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth - 2
						]
						20 [					;-- system/atomic/cas
							target-slot: depth - 2
							source-slot: depth - 1
							unless all [
								instruction/c = -11
								depth > 2
								stack-kinds/target-slot = VALUE
								stack-flags/target-slot = 0
								(logical-kind stack-types/target-slot types type-count) = -6
								pointee-type stack-types/target-slot types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								stack-kinds/source-slot = VALUE
								stack-flags/source-slot = 0
								(canonical-type stack-types/source-slot types type-count) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth types type-count) = -5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + source-slot) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/atomic-compare-exchange at
								(capacity - written) x64-encoder/RDX x64-encoder/RCX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/condition-result at
								(capacity - written) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							last-math-operation: 0
							depth: depth - 2
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						21 [					;-- system/atomic/<math>
							target-slot: depth - 1
							operation: instruction/b and 7
							atomic-old?: (instruction/b and 8) <> 0
							unless all [
								instruction/c = -5
								operation >= 1 operation <= 5
								depth > 1
								stack-kinds/target-slot = VALUE
								stack-flags/target-slot = 0
								(logical-kind stack-types/target-slot types type-count) = -6
								pointee-type stack-types/target-slot types type-count :target-ref
								(canonical-type target-ref types type-count) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth types type-count) = -5
							][return INVALID_IR]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							case [
								operation <= 2 [
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RCX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if operation = 2 [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/negate-register at
											(capacity - written) x64-encoder/RAX 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/atomic-exchange-add at
										(capacity - written) x64-encoder/RDX x64-encoder/RAX
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if not atomic-old? [
										opcode: either operation = 1 [01h][29h]
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/binary-register at
											(capacity - written) opcode x64-encoder/RAX
											x64-encoder/RCX 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
								]
								true [
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/register-load-indirect at
										(capacity - written) x64-encoder/RAX x64-encoder/RDX 4 1
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									target-offset: written
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/R11 x64-encoder/RAX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									opcode: case [
										operation = 3 [09h]
										operation = 4 [31h]
										true [21h]
									]
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/binary-register at
										(capacity - written) opcode x64-encoder/R11
										x64-encoder/RCX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/atomic-compare-exchange at
										(capacity - written) x64-encoder/RDX x64-encoder/R11
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: as byte-ptr! 0
									if not measure? [at: code + written]
									encoded: x64-encoder/jump-condition at
										(capacity - written) 5
										(target-offset - (written + 6))
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if not atomic-old? [
										at: as byte-ptr! 0
										if not measure? [at: code + written]
										encoded: x64-encoder/move-register at
											(capacity - written) x64-encoder/RAX
											x64-encoder/R11 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
								]
							]
							last-math-operation: case [
								operation = 1 [ADD_OPERATION]
								operation = 2 [SUBTRACT_OPERATION]
								operation = 3 [OR_OPERATION]
								operation = 4 [XOR_OPERATION]
								true [AND_OPERATION]
							]
							depth: depth - 1
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						22 [					;-- LOG-B
							unless all [
								instruction/c = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								integer-type? stack-types/depth types type-count
							][return INVALID_IR]
							width: value-width stack-types/depth 0 types members
								type-count layouts member-offsets
							operation-width: either width = 8 [8][4]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: load-operation-value at (capacity - written)
								x64-encoder/RAX slot-displacement (storage-slots + depth)
								stack-types/depth 0 operation-width false types members
								type-count layouts member-offsets
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/bit-scan-reverse at (capacity - written)
								x64-encoder/RAX x64-encoder/RAX operation-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						default [return UNSUPPORTED]
					]
				]
				instruction/op = OP_DROP [
					if depth <= 0 [return INVALID_IR]
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
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
					located?: all [
						kind = VALUE
						location-depth = depth
						any [location = LOCATION_GPR location = LOCATION_XMM]
					]
					unless located? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							width signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if located? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either location = LOCATION_XMM [
							x64-encoder/xmm-frame-store at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) width
						][
							target-width: either width = 8 [8][4]
							x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) target-width
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					depth: depth + 1
					if depth > max-depth [max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: kind
					stack-tags/depth: tag-head
					unless located? [
						target-width: either width = 8 [8][4]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							target-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if located? [location-depth: depth]
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
					located?: location = LOCATION_GPR
					unless located? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: load-operation-value at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							ref flags operation-width false types members type-count
							layouts member-offsets
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
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
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					either linear? [
						if width < 4 [
							signed: either signed-type? ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/extend-narrow-register at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX
								width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						location: LOCATION_GPR
						location-depth: depth
					][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					stack-tags/depth: 0
				]
				instruction/op = OP_OVERFLOW [
					target: instruction/a
					unless all [
						instruction/b = 0 instruction/c = 0
						any [
							target = 0
							all [
								target > index
								target <= fn/instruction-count
								catch-depths/target = catch-depths/index
							]
						]
					][return INVALID_IR]
				]
				instruction/op = OP_BINARY [
					if any [
						instruction/b < 0 instruction/c < 0
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
					fuse-branch?: false
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
							operation-ref: float-common-ref left-ref right-ref
								types type-count
							valid?: any [
								all [
									integer-type? left-ref types type-count
									integer-type? right-ref types type-count
									left-flags = 0 right-flags = 0
								]
								all [
									operation-ref <> 0
									left-flags = 0 right-flags = 0
									any [operation <= DIVIDE_OPERATION operation-ref = -9]
								]
								all [
									operation <= SUBTRACT_OPERATION
									left-flags = 0 right-flags = 0
									any [
										all [
											address-type? left-ref types type-count
											any [
												integer-type? right-ref types type-count
												address-type? right-ref types type-count
											]
										]
										all [
											left-kind = 5
											address-type? right-ref types type-count
										]
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
									left-flags = right-flags
									same-reference-category? left-kind right-kind
									any [left-kind <> -4 operation <= NOT_EQUAL_OPERATION]
								]
								all [
									left-flags = 0 right-flags = 0
									any [
										all [left-kind = -7 compatible-types? right-ref left-ref
											types type-count]
										all [right-kind = -7 compatible-types? left-ref right-ref
											types type-count]
									]
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
					tracked?: instruction/b <> 0
					either tracked? [
						overflow-anchor: instruction/b
						unless all [overflow-anchor < index overflow-anchor > 0][
							return INVALID_IR
						]
						overflow-scope: as rsir-instruction! (instructions
							+ ((overflow-anchor - 1) * RSIR_INSTRUCTION_SIZE))
						target: overflow-scope/a
						unless all [
							overflow-scope/op = OP_OVERFLOW
							overflow-scope/b = 0 overflow-scope/c = 0
							target > index target <= fn/instruction-count
							not floating?
						][return INVALID_IR]
						valid?: false
						case [
							operation <= MULTIPLY_OPERATION [
								valid?: all [
									instruction/c = 0
									integer-type? left-ref types type-count
								]
							]
							operation <= MODULO_OPERATION [
								valid?: all [
									instruction/c = 0 left-kind = 5
								]
							]
							operation = SHIFT_LEFT_OPERATION [
								overflow-limit: either any [
									left-kind = 7 left-kind = 8
								][63][31]
								valid?: all [
									instruction/c > 0
									instruction/c <= overflow-limit
								]
							]
							true [valid?: false]
						]
						unless valid? [return INVALID_IR]
						base-depth: instruction-depths/overflow-anchor
						unless all [base-depth >= 0 base-depth <= (depth - 2)][
							return INVALID_IR
						]
						if measure? [
							unless merge-target target base-depth fn/instruction-count instructions
								instruction-depths entry-types entry-flags entry-kinds entry-tags
								stack-types stack-flags stack-kinds stack-tags types type-count [
								return INVALID_IR
							]
						]
					][
						if instruction/c <> 0 [return INVALID_IR]
					]
					unless all [
						machine-value? left-ref left-flags types members type-count
							layouts member-offsets
						machine-value? right-ref right-flags types members type-count
							layouts member-offsets
					][return UNSUPPORTED]
					located?: location <> LOCATION_NONE
					paired?: any [
						location = LOCATION_GPR_PAIR
						location = LOCATION_XMM_PAIR
					]
					if all [
						located?
						any [
							all [
								floating?
								not any [
									location = LOCATION_XMM
									location = LOCATION_XMM_PAIR
								]
							]
							all [
								not floating?
								not any [
									location = LOCATION_GPR
									location = LOCATION_GPR_PAIR
								]
							]
						]
					][return INVALID_IR]

					either floating? [
						ref: either operation-ref <> 0 [operation-ref][left-ref]
						width: value-width ref 0 types members type-count
							layouts member-offsets
						operation-width: width
						source-width: value-width right-ref right-flags types members
							type-count layouts member-offsets
						if located? [
							if any [
								location <> LOCATION_XMM_PAIR
								source-width <> operation-width
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: case [
									location = LOCATION_XMM_PAIR [
										x64-encoder/xmm-convert at (capacity - written)
											x64-encoder/XMM1 x64-encoder/XMM1
											source-width operation-width
									]
									source-width = operation-width [
										x64-encoder/xmm-move-register at (capacity - written)
											x64-encoder/XMM1 x64-encoder/XMM0 source-width
									]
									true [
										x64-encoder/xmm-convert at (capacity - written)
											x64-encoder/XMM1 x64-encoder/XMM0
											source-width operation-width
									]
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
						source-width: value-width left-ref left-flags types members
							type-count layouts member-offsets
						unless paired? [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/xmm-frame-load at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + target-slot) source-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if source-width <> operation-width [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/xmm-convert at (capacity - written)
								x64-encoder/XMM0 x64-encoder/XMM0 source-width operation-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						unless located? [
							source-width: value-width right-ref right-flags types members
								type-count layouts member-offsets
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/xmm-frame-load at (capacity - written)
								x64-encoder/XMM1 slot-displacement
									(storage-slots + depth) source-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if source-width <> operation-width [
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/xmm-convert at (capacity - written)
									x64-encoder/XMM1 x64-encoder/XMM1
									source-width operation-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
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
					zero-extend?: operation = SHIFT_LOGICAL_OPERATION
					signed: either signed-type? ref types type-count [1][0]
					source-slot: either all [
						operation >= DIVIDE_OPERATION
						operation <= SHIFT_LOGICAL_OPERATION
					][x64-encoder/RCX][x64-encoder/RDX]
					; The preceding literal offered itself as the immediate
					; right operand. Pointer arithmetic scales it first, so the
					; scaled product must still fit a sign-extended imm32.
					immediate?: all [
						not floating?
						pending-immediate-kind = 1
						pending-immediate-index = (index - 1)
						not any [
							operation = DIVIDE_OPERATION
							operation = REMAINDER_OPERATION
							operation = MODULO_OPERATION
						]
					]
					; A pending immediate means the GPR location names the
					; left operand already sitting in RAX.
					left-in-register?: all [
						immediate?
						location = LOCATION_GPR
						location-depth = (depth - 1)
					]
					if all [located? not paired? not left-in-register?][
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: move-operation-value at (capacity - written)
							source-slot x64-encoder/RAX right-ref right-flags
							operation-width types members type-count layouts member-offsets
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					target-offset: 0
					if all [tracked? not measure?][
						target-offset: instruction-start
							+ (instruction-offsets/target - instruction-offsets/index)
					]
					unless any [paired? left-in-register?] [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: load-operation-value at (capacity - written)
							x64-encoder/RAX slot-displacement
							(storage-slots + target-slot) left-ref left-flags
							operation-width zero-extend? types members type-count
							layouts member-offsets
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					unless any [located? immediate?] [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: load-operation-value at (capacity - written)
							source-slot slot-displacement (storage-slots + depth)
							right-ref right-flags operation-width false types members
							type-count layouts member-offsets
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					if all [
						address-type? left-ref types type-count
						integer-type? right-ref types type-count
					][
						stride: pointer-stride left-ref types members type-count
							layouts member-offsets
						if stride <= 0 [return UNSUPPORTED]
						if stride <> 1 [
							either immediate? [
								pending-immediate-value: pending-immediate-value
									* stride
							][
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: x64-encoder/multiply-immediate at
									(capacity - written)
									x64-encoder/RDX x64-encoder/RDX stride 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
					]

					if tracked? [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: case [
							all [
								operation >= DIVIDE_OPERATION
								operation <= MODULO_OPERATION
							][
								division-overflow-check at (capacity - written)
									target-offset written
							]
							operation = SHIFT_LEFT_OPERATION [
								shift-overflow-check at (capacity - written) width
									operation-width signed instruction/c target-offset written
							]
							true [0]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					at: as byte-ptr! 0
					if not measure? [at: code + written]
					case [
						operation = ADD_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									0 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									01h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = SUBTRACT_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									5 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									29h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = MULTIPLY_OPERATION [
							encoded: either immediate? [
								x64-encoder/multiply-immediate at
									(capacity - written) x64-encoder/RAX
									x64-encoder/RAX pending-immediate-value
									operation-width
							][
								either all [tracked? signed = 0][
									x64-encoder/unsigned-multiply-register at
										(capacity - written) x64-encoder/RDX operation-width
								][
									x64-encoder/multiply-register at (capacity - written)
										x64-encoder/RAX x64-encoder/RDX operation-width
								]
							]
						]
						all [
							operation >= DIVIDE_OPERATION
							operation <= MODULO_OPERATION
						][
							encoded: x64-encoder/divide-register at (capacity - written)
								operation-width signed
						]
						operation = SHIFT_LEFT_OPERATION [
							encoded: either any [tracked? immediate?][
								x64-encoder/shift-immediate at (capacity - written)
									x64-encoder/RAX 4 either immediate? [
										pending-immediate-value
									][instruction/c] operation-width
							][
								x64-encoder/shift-register at (capacity - written)
									x64-encoder/RAX 4 operation-width
							]
						]
						operation = SHIFT_RIGHT_OPERATION [
							condition: either signed = 1 [7][5]
							encoded: either immediate? [
								x64-encoder/shift-immediate at (capacity - written)
									x64-encoder/RAX condition
									pending-immediate-value operation-width
							][
								x64-encoder/shift-register at (capacity - written)
									x64-encoder/RAX condition operation-width
							]
						]
						operation = SHIFT_LOGICAL_OPERATION [
							encoded: either immediate? [
								x64-encoder/shift-immediate at (capacity - written)
									x64-encoder/RAX 5 pending-immediate-value
									operation-width
							][
								x64-encoder/shift-register at (capacity - written)
									x64-encoder/RAX 5 operation-width
							]
						]
						operation = OR_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									1 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									09h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = XOR_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									6 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									31h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = AND_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									4 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									21h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						comparison? [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									7 x64-encoder/RAX pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									39h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						true [encoded: -1]
					]
					if immediate? [pending-immediate-index: -1]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					if all [tracked? operation <= MULTIPLY_OPERATION][
						condition: either signed = 1 [0][2]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: jump-condition-to at (capacity - written) condition
							target-offset written
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if width < 4 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: narrow-overflow-check at (capacity - written)
								width signed target-offset written
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]

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
						; An integer compare consumed only by the adjacent
						; BRANCH never needs its boolean materialized: the
						; branch jumps straight on the compare flags.
						fuse-branch?: all [
							linear?
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							next-instruction/op = OP_BRANCH
							any [
								next-instruction/b = 0
								next-instruction/b = 1
							]
							next-instruction/c = 0
							(instruction-effects/next-index
								and EFFECT_CONSTANT_BRANCH) = 0
							not boolean-diamond? (index + 1)
								fn/instruction-count instructions
								catch-depths control-uses
						]
						either fuse-branch? [
							flags-condition: condition
						][
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/condition-result at
								(capacity - written) condition
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					]
					unless floating? [last-math-operation: operation]

					depth: depth - 1
					either comparison? [
						ref: -11
						flags: 0
						operation-width: 4
					][
						ref: either all [floating? operation-ref <> 0][
							operation-ref
						][left-ref]
						flags: left-flags
					]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					either fuse-branch? [
						; The result lives only in the compare flags and is
						; consumed by the adjacent branch before any other
						; instruction can clobber them.
						0
					][
					either linear? [
						if all [not floating? not comparison? width < 4][
							signed: either signed-type? ref types type-count [1][0]
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/extend-narrow-register at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX
								width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						location: either all [floating? not comparison?][
							LOCATION_XMM
						][LOCATION_GPR]
						location-depth: depth
					][
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
					]
				]
				instruction/op = OP_CATCH [
					target: instruction/a
					catch-level: instruction/b
					catch-unwind: catch-level - 1
					unless all [
						target > index target <= fn/instruction-count
						catch-level > 0 catch-level <= catch-capacity
						instruction/c = 0
						catch-depths/index = catch-unwind
						catch-depths/target = catch-level
						depth > 0 stack-kinds/depth = VALUE
						stack-flags/depth = 0
						compatible-types? -5 stack-types/depth types type-count
					][return INVALID_IR]
					catch-record: catch-base + ((catch-level - 1) * 3) + 1
					target-offset: 0
					if not measure? [
						target-offset: instruction-offsets/target + allocation-size
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: emit-catch-open at (capacity - written)
						catch-record (storage-slots + depth) target-offset written
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1
					if measure? [
						unless merge-target target depth fn/instruction-count instructions
							instruction-depths entry-types entry-flags entry-kinds entry-tags
							stack-types stack-flags stack-kinds stack-tags types type-count [
							return INVALID_IR
						]
					]
				]
				instruction/op = OP_END_CATCH [
					catch-level: instruction/b
					unless all [
						instruction/a > 0 instruction/a < index
						catch-level > 0 catch-level <= catch-capacity
						instruction/c = 0
						catch-depths/index = catch-level
					][return INVALID_IR]
					catch-record: catch-base + ((catch-level - 1) * 3) + 1
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: emit-catch-restore at (capacity - written) catch-record
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				instruction/op = OP_THROW [
					; VALUE PLACE -> no fallthrough
					source-slot: depth - 1
					target-slot: depth
					unless all [
						instruction/a = 0 instruction/b = 0 instruction/c = 0
						depth > 1
						stack-kinds/source-slot = VALUE
						stack-flags/source-slot = 0
						compatible-types? -5 stack-types/source-slot types type-count
						stack-kinds/target-slot = PLACE
						stack-flags/target-slot = 0
						compatible-types? -5 stack-types/target-slot types type-count
					][return INVALID_IR]
					tag-head: stack-tags/target-slot
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement
							(storage-slots + source-slot) 4 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RDX slot-displacement
							(storage-slots + target-slot) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/store-indirect at (capacity - written) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: emit-variant-tags at (capacity - written) tag-head tag-base
						fn/instruction-count instructions tag-next tag-slots tag-widths
					if encoded < 0 [return encoded]
					written: written + encoded
					if tag-head > 0 [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + source-slot) 4 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					depth: source-slot - 1
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/throw-unwind at (capacity - written)
						((fn/flags and CATCH_FLAG) <> 0)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					fallthrough?: false
				]
				instruction/op = OP_JUMP [
					target: instruction/a
					catch-level: catch-depths/index
					catch-unwind: catch-level - instruction/c
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/b >= 0 instruction/b <= depth
						instruction/c >= 0 instruction/c <= catch-level
						catch-depths/target = catch-unwind
					][return INVALID_IR]
					catch-unwind: instruction/c
					while [catch-unwind > 0][
						catch-record: catch-base + ((catch-level - 1) * 3) + 1
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: emit-catch-restore at (capacity - written) catch-record
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						catch-level: catch-level - 1
						catch-unwind: catch-unwind - 1
					]
					depth: depth - instruction/b
					if measure? [
						unless merge-target target depth fn/instruction-count instructions
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
					fold-constant?: (instruction-effects/index
						and EFFECT_CONSTANT_BRANCH) <> 0
					branch-taken?: (instruction-effects/index
						and EFFECT_BRANCH_TAKEN) <> 0
					unless all [
						target > 0 target <= fn/instruction-count
						catch-depths/target = catch-depths/index
						any [instruction/b = 0 instruction/b = 1]
						instruction/c = 0
						any [
							fold-constant?
							all [
								depth > 0
								stack-kinds/depth = VALUE
								compatible-types? -11 stack-types/depth types type-count
								stack-flags/depth = 0
							]
						]
					][return INVALID_IR]
					either fold-constant? [
						if branch-taken? [
							if measure? [
								unless merge-target target depth fn/instruction-count instructions
									instruction-depths entry-types entry-flags entry-kinds
									entry-tags stack-types stack-flags stack-kinds stack-tags
									types type-count [
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
					][
						fold-boolean?: boolean-diamond? index fn/instruction-count
							instructions catch-depths control-uses
						at: as byte-ptr! 0
						tracked?: location = LOCATION_GPR
						unless any [tracked? flags-condition >= 0][
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if flags-condition < 0 [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/test-register at
								(capacity - written) x64-encoder/RAX 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						either fold-boolean? [
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/condition-result at
								(capacity - written) 5
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							location: LOCATION_NONE
							location-depth: 0
							location-source: 0
							if measure? [
								target-offset: index + 1
								while [target-offset <= (index + 3)][
									instruction-offsets/target-offset: written
									target-offset: target-offset + 1
								]
							]
							index: index + 3
						][
							depth: depth - 1
							if measure? [
								unless merge-target target depth fn/instruction-count instructions
									instruction-depths entry-types entry-flags entry-kinds
									entry-tags stack-types stack-flags stack-kinds stack-tags
									types type-count [
									return INVALID_IR
								]
							]
							displacement: 0
							if not measure? [
								target-offset: index + 1
								displacement: instruction-offsets/target
									- instruction-offsets/target-offset
							]
							condition: case [
								flags-condition >= 0 [
									; Branch directly on the fused compare
									; flags; inversion is the adjacent cc.
									either instruction/b = 1 [
										flags-condition
									][flags-condition xor 1]
								]
								instruction/b = 1 [5]
								true [4]
							]
							flags-condition: -1
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: x64-encoder/jump-condition at
								(capacity - written) condition displacement
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							location: LOCATION_NONE
							location-depth: 0
							location-source: 0
						]
					]
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
						ref 0 operation-width false types members type-count
						layouts member-offsets
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1

					case-index: 0
					while [case-index < instruction/b][
						switch-case: as rsir-switch! (switches
							+ ((instruction/a + case-index) * RSIR_SWITCH_SIZE))
						target: switch-case/target
						if any [
							target <= 0 target > fn/instruction-count
							catch-depths/target <> catch-depths/index
						][
							return INVALID_IR
						]
						if measure? [
							unless merge-target target depth fn/instruction-count instructions
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
					if catch-depths/target <> catch-depths/index [return INVALID_IR]
					if measure? [
						unless merge-target target depth fn/instruction-count instructions
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
				instruction/op = OP_ENTRY [
					if any [current-entry <> index depth <> 0][return INVALID_IR]
					if instruction/a = 1 [
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: x64-encoder/adjust-stack at (capacity - written)
							(0 - sub-frame)
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_SUB_CALL [
					target: instruction/a
					if target = current-entry [return INVALID_IR]
					sub-entry: as rsir-instruction! (instructions
						+ ((target - 1) * RSIR_INSTRUCTION_SIZE))
					unless all [
						sub-entry/op = OP_ENTRY sub-entry/a = 1
						instruction/b = sub-entry/b instruction/c = 0
					][return INVALID_IR]
					displacement: 0
					if not measure? [
						displacement: (instruction-offsets/target
							- instruction-offsets/index) - 5
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/call-relative at (capacity - written)
						displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					sub-returns?: (instruction-effects/target and EFFECT_RESUMES) <> 0
					either not sub-returns? [
						fallthrough?: false
					][
						ref: instruction/b
						if ref <> 0 [
							depth: depth + 1
							if depth > max-depth [max-depth: depth]
							stack-types/depth: ref
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							width: value-width ref 0 types members type-count
								layouts member-offsets
							floating?: float-type? ref types type-count
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-store at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + depth) width
							][
								x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) width
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
				]
				instruction/op = OP_SUB_RETURN [
					if current-entry <= 0 [
						return INVALID_IR
					]
					sub-entry: as rsir-instruction! (instructions
						+ ((current-entry - 1) * RSIR_INSTRUCTION_SIZE))
					return-ref: instruction/a
					compatibility: 0
					if all [
						return-ref <> 0 depth = 1 stack-kinds/depth = VALUE
						stack-flags/depth = 0
					][
						compatibility: implicitly-compatible-types return-ref stack-types/depth
							stack-tags/depth false types members type-count signature-cache
						if compatibility < 0 [return compatibility]
					]
					unless all [
						sub-entry/op = OP_ENTRY sub-entry/a = 1
						return-ref = sub-entry/b instruction/b = 0 instruction/c = 0
						any [
							all [
								return-ref = 0
								any [
									depth = 0
									all [depth = 1 stack-kinds/depth = VALUE]
								]
							]
							all [
								return-ref <> 0 depth = 1 stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatibility = 1
								machine-value? stack-types/depth 0 types members type-count
									layouts member-offsets
							]
						]
					][
						return INVALID_IR
					]
					if return-ref <> 0 [
						ref: stack-types/depth
						target-width: value-width return-ref 0 types members type-count
							layouts member-offsets
						floating?: float-type? return-ref types type-count
						tracked?: location <> LOCATION_NONE
						if tracked? [
							if any [
								all [floating? location <> LOCATION_XMM]
								all [not floating? location <> LOCATION_GPR]
							][return INVALID_IR]
						]
						at: as byte-ptr! 0
						if not measure? [at: code + written]
						encoded: either tracked? [
							either all [
								location = LOCATION_GPR
								target-width = 8
								(value-width ref 0 types members type-count
									layouts member-offsets) < 8
								signed-type? ref types type-count
							][
								x64-encoder/sign-extend-register at (capacity - written)
									x64-encoder/RAX
							][0]
						][
							either floating? [
								x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) target-width
							][
								load-operation-value at (capacity - written)
									x64-encoder/RAX slot-displacement
									(storage-slots + depth) ref 0 target-width false
									types members type-count layouts member-offsets
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/adjust-stack at (capacity - written) sub-frame
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: as byte-ptr! 0
					if not measure? [at: code + written]
					encoded: x64-encoder/return-near at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
					depth: 0
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
							compatibility: implicitly-compatible-types return-ref stack-types/depth
								stack-tags/depth false types members type-count signature-cache
							if compatibility < 0 [return compatibility]
							unless all [
								compatibility = 1
								stack-flags/depth = instruction/b
								machine-value? return-ref instruction/b
									types members type-count layouts member-offsets
								machine-value? stack-types/depth stack-flags/depth
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
							ref: stack-types/depth
							flags: stack-flags/depth
							target-width: value-width return-ref instruction/b types members
								type-count layouts member-offsets
							at: as byte-ptr! 0
							if not measure? [at: code + written]
							encoded: load-operation-value at (capacity - written)
								x64-encoder/RCX slot-displacement
								(storage-slots + depth) ref flags target-width false
								types members type-count layouts member-offsets
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
								ref: stack-types/depth
								flags: stack-flags/depth
								target-width: value-width return-ref instruction/b
									types members type-count layouts member-offsets
								floating?: float-type? return-ref types type-count
								tracked?: location <> LOCATION_NONE
								if tracked? [
									if any [
										all [floating? location <> LOCATION_XMM]
										all [not floating? location <> LOCATION_GPR]
									][return INVALID_IR]
								]
								at: as byte-ptr! 0
								if not measure? [at: code + written]
								encoded: either tracked? [
									either all [
										location = LOCATION_GPR
										target-width = 8
										(value-width ref flags types members type-count
											layouts member-offsets) < 8
										signed-type? ref types type-count
									][
										x64-encoder/sign-extend-register at
											(capacity - written) x64-encoder/RAX
									][0]
								][
									either floating? [
										x64-encoder/xmm-frame-load at (capacity - written)
											x64-encoder/XMM0 slot-displacement
												(storage-slots + depth) target-width
									][
										load-operation-value at (capacity - written)
											x64-encoder/RAX slot-displacement
											(storage-slots + depth) ref flags target-width false
											types members type-count layouts member-offsets
									]
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
					location: LOCATION_NONE
					location-depth: 0
					location-source: 0
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
		if all [not measure? max-outgoing <> outgoing-size/1][return INVALID_IR]

		if measure? [
			outgoing-size/1: max-outgoing
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

	place-global-data: func [
		global [codegen-global!]
		rodata-size data-size [int-ptr!]
		return: [integer!]
		/local offset alignment [integer!]
	][
		alignment: global/name
		either (global/flags and PROTECTED) <> 0 [
			offset: align rodata-size/1 alignment
		][
			offset: align data-size/1 alignment
		]
		if any [
			offset < 0
			offset > (2147483647 - global/data-size)
		][return OUTPUT_FULL]
		global/data-offset: offset
		either (global/flags and PROTECTED) <> 0 [
			rodata-size/1: offset + global/data-size
		][
			data-size/1: offset + global/data-size
		]
		0
	]

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local header [rsir-header!]
			signature-cache [signature-pairs!]
			ir-type array-type [rsir-type!]
			ir-member [rsir-member!]
			ir-import [rsir-import!]
			ir-global target-global [rsir-global!]
			ir-function [rsir-function!]
			ir-export [rsir-export!]
			ir-parameter [rsir-parameter!]
			initializer [rsir-initializer!]
			image [codegen-header!]
			image-function target-image-function [codegen-function!]
			image-global target-image-global [codegen-global!]
			image-import [codegen-import!]
			image-export [codegen-export!]
			import-refs function-sizes function-frames function-outgoing function-effects
				instruction-offsets
				instruction-depths catch-depths control-uses entry-types entry-flags
				entry-kinds entry-tags
				stack-types stack-flags stack-kinds stack-tags tag-next tag-slots
				tag-widths result-offsets storage-offsets layouts member-offsets
				instruction-effects switch-effect-links switch-effect-users
				references [int-ptr!]
			type-data member-data import-data global-data function-data export-data
				parameter-data initializer-data switch-data instruction-data strings
				function-instructions
				name names-output code rodata-output data-output cursor finish scratch
				[byte-ptr!]
			type-bytes member-bytes import-bytes global-bytes function-bytes export-bytes
				parameter-bytes initializer-bytes switch-bytes instruction-bytes remaining
				member-count parameter-count initializer-count next-parameter
				strings-size metadata-size function-names-size global-names-size
				import-names-size export-names-size names-size code-offset code-size
				function-code-size
				literal-size rodata-offset data-offset image-rodata-size image-data-size
				total-size scratch-count
				id next-instruction next-offset instruction-count function-size entry-size
				code-cursor name-cursor global-size global-align global-offset
				parameter-id parameter-end
				global-reference-count used-import-count import-reference-count
				image-import-count reference-count count first-reference last-library
				library-offset external-offset output-import-id exit-reference-id
				reference-id record-offset variable-mode written base initializer-id
				slot-width item-offset member-id owner child root current placed
					status [integer!]
			entry? current-entry? array? protected? [logic!]
	][
		signature-cache: declare signature-pairs!
		signature-cache/memory: null
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		unless any [opt-level = 0 opt-level = 2][return UNSUPPORTED]
		header: as rsir-header! data
		if any [
			header/type-count < 0 header/import-count < 0 header/global-count < 0
			header/switch-count < 0 header/export-count < 0
			header/function-count <= 0 header/instruction-count <= 0
			header/module-kind < 1 header/module-kind > 4
			all [header/module-kind = 4 header/export-count = 0]
			all [header/module-kind <> 4 header/export-count <> 0]
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
				ir-type/flags < 0 ir-type/flags > CALLABLE_FLAGS
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
					if any [
						all [ir-type/target <> 0
							not valid-type-ref? ir-type/target header/type-count]
						all [
							(ir-type/flags and CATCH_FLAG) <> 0
							(ir-type/flags and CATCH_CONFLICT_FLAGS) <> 0
						]
					][return INVALID_IR]
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
				ir-type/kind = -8 [
					if any [
						ir-type/flags <> 0
						ir-type/target <= 0
						not valid-type-ref? ir-type/target header/type-count
						(logical-kind ir-type/target type-data header/type-count) <> -4
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
		while [id <= header/type-count][
			ir-type: as rsir-type! (type-data + ((id - 1) * RSIR_TYPE_SIZE))
			if ir-type/kind <> -7 [
				member-id: ir-type/first-member
				while [member-id < (ir-type/first-member + ir-type/member-count)][
					ir-member: as rsir-member! (member-data
						+ (member-id * RSIR_MEMBER_SIZE))
					if not valid-type-ref? ir-member/type header/type-count [
						return INVALID_IR
					]
					either ir-type/kind = -8 [
						unless typed-runtime-id? ir-member/flags [return INVALID_IR]
					][
						if any [
							ir-member/flags < 0
							ir-member/flags > INLINE
							all [
								ir-member/flags = INLINE
								not aggregate-ref? ir-member/type type-data
									header/type-count
							]
						][return INVALID_IR]
					]
					member-id: member-id + 1
				]
			]
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
				ir-import/flags < 0 ir-import/flags > CALLABLE_FLAGS
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
				all [
					(ir-function/flags and CATCH_FLAG) <> 0
					(ir-function/flags and CATCH_CONFLICT_FLAGS) <> 0
				]
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

		if header/export-count > (remaining / RSIR_EXPORT_SIZE)[return INVALID_IR]
		export-bytes: header/export-count * RSIR_EXPORT_SIZE
		export-data: function-data + function-bytes
		remaining: remaining - export-bytes
		id: 1
		while [id <= header/export-count][
			ir-export: as rsir-export! (export-data + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				ir-export/symbol = 0
				all [ir-export/symbol > 0
					ir-export/symbol > header/function-count]
				all [ir-export/symbol < 0
					ir-export/symbol < (0 - header/global-count)]
			][return INVALID_IR]
			id: id + 1
		]

		if parameter-count > (remaining / RSIR_PARAMETER_SIZE)[return INVALID_IR]
		parameter-bytes: parameter-count * RSIR_PARAMETER_SIZE
		parameter-data: export-data + export-bytes
		remaining: remaining - parameter-bytes
		id: 1
		while [id <= parameter-count][
			ir-parameter: as rsir-parameter! (parameter-data
				+ ((id - 1) * RSIR_PARAMETER_SIZE))
			if any [
				all [ir-parameter/type <> 0
					not valid-type-ref? ir-parameter/type header/type-count]
				ir-parameter/flags < 0 ir-parameter/flags > INLINE
				all [ir-parameter/flags = INLINE
					not aggregate-ref? ir-parameter/type type-data header/type-count]
			][return INVALID_IR]
			id: id + 1
		]
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (import-data + ((id - 1) * RSIR_IMPORT_SIZE))
			parameter-id: ir-import/first-parameter
			parameter-end: parameter-id + ir-import/parameter-count
			while [parameter-id < parameter-end][
				ir-parameter: as rsir-parameter! (parameter-data
					+ (parameter-id * RSIR_PARAMETER_SIZE))
				if ir-parameter/type = 0 [return INVALID_IR]
				parameter-id: parameter-id + 1
			]
			id: id + 1
		]
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			parameter-id: ir-function/first-parameter
			parameter-end: ir-function/first-local
			while [parameter-id < parameter-end][
				ir-parameter: as rsir-parameter! (parameter-data
					+ (parameter-id * RSIR_PARAMETER_SIZE))
				if ir-parameter/type = 0 [return INVALID_IR]
				parameter-id: parameter-id + 1
			]
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

		export-names-size: 0
		id: 1
		while [id <= header/export-count][
			ir-export: as rsir-export! (export-data + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				ir-export/name < 0 ir-export/name-size <= 0
				ir-export/name-size > strings-size
				ir-export/name > (strings-size - ir-export/name-size)
				export-names-size > (2147483647 - ir-export/name-size)
			][return INVALID_IR]
			export-names-size: export-names-size + ir-export/name-size
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
			if global-names-size > (2147483647 - ir-global/name-size) [
				return OUTPUT_FULL
			]
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			; Name fields hold alignment and owner only until final metadata is copied.
			image-global/name: global-align
			image-global/name-size: 0
			image-global/data-offset: 0
			image-global/data-size: global-size
			image-global/first-reference: 0
			image-global/reference-count: 0
			image-global/flags: ir-global/flags and PROTECTED
			global-names-size: global-names-size + ir-global/name-size
			id: id + 1
		]

		; A uniquely referenced anonymous global is the static payload owned by
		; its earlier pointer slot. Keep that object next to its owner without
		; adding ownership records to RSIR.
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (global-data + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < ir-global/initializer-count][
				initializer: as rsir-initializer! (initializer-data
					+ ((ir-global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
				][
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
				initializer-id: initializer-id + 1
			]
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
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
					initializer/b > id
				][
					target-global: as rsir-global! (global-data
						+ ((initializer/b - 1) * RSIR_GLOBAL_SIZE))
					target-image-global: as codegen-global! (output
						+ IMAGE_HEADER_SIZE
						+ (header/function-count * IMAGE_FUNCTION_SIZE)
						+ ((initializer/b - 1) * IMAGE_GLOBAL_SIZE))
					if all [
						target-global/name-size = 0
						target-image-global/reference-count = 1
					][target-image-global/name-size: id]
				]
				initializer-id: initializer-id + 1
			]
			id: id + 1
		]

		id: header/global-count
		while [id > 0][
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/first-reference: 0
			image-global/reference-count: 0
			id: id - 1
		]
		id: header/global-count
		while [id > 0][
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			owner: image-global/name-size
			if owner > 0 [
				target-image-global: as codegen-global! (output
					+ IMAGE_HEADER_SIZE
					+ (header/function-count * IMAGE_FUNCTION_SIZE)
					+ ((owner - 1) * IMAGE_GLOBAL_SIZE))
				image-global/reference-count: target-image-global/first-reference
				target-image-global/first-reference: id
			]
			id: id - 1
		]

		placed: 0
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			if image-global/name-size = 0 [
				root: id
				current: id
				while [current > 0][
					image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
						+ (header/function-count * IMAGE_FUNCTION_SIZE)
						+ ((current - 1) * IMAGE_GLOBAL_SIZE))
					status: place-global-data image-global
						:image-rodata-size :image-data-size
					if status <> 0 [return status]
					placed: placed + 1
					child: image-global/first-reference
					either child > 0 [
						current: child
					][
						while [all [
							current <> root
							image-global/reference-count = 0
						]][
							current: image-global/name-size
							image-global: as codegen-global! (output
								+ IMAGE_HEADER_SIZE
								+ (header/function-count * IMAGE_FUNCTION_SIZE)
								+ ((current - 1) * IMAGE_GLOBAL_SIZE))
						]
						either current = root [
							current: 0
						][current: image-global/reference-count]
					]
				]
			]
			id: id + 1
		]
		if placed <> header/global-count [return INVALID_IR]
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/first-reference: 0
			image-global/reference-count: 0
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

		if header/function-count > ((2147483647 - header/import-count) / 5)[
			return OUTPUT_FULL
		]
		scratch-count: header/import-count + (header/function-count * 5)
		if header/instruction-count > ((2147483647 - scratch-count) / 17)[
			return OUTPUT_FULL
		]
		scratch-count: scratch-count + (header/instruction-count * 17)
		if header/switch-count > ((2147483647 - scratch-count) / 2)[
			return OUTPUT_FULL
		]
		scratch-count: scratch-count + (header/switch-count * 2)
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
		function-outgoing: function-frames + header/function-count
		function-effects: function-outgoing + header/function-count
		instruction-offsets: function-effects + header/function-count
		instruction-depths: instruction-offsets + header/instruction-count
			+ header/function-count
		catch-depths: instruction-depths + header/instruction-count
		control-uses: catch-depths + header/instruction-count
		entry-types: control-uses + header/instruction-count
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
		instruction-effects: member-offsets + member-count
		switch-effect-links: instruction-effects + header/instruction-count
		switch-effect-users: switch-effect-links + header/switch-count
		id: 1
		while [id <= header/import-count][import-refs/id: 0 id: id + 1]
		count: header/type-count * 4
		id: 1
		while [id <= count][layouts/id: 0 id: id + 1]
		id: 1
		while [id <= member-count][member-offsets/id: -1 id: id + 1]
		status: infer-effects function-data instruction-data switch-data
			header/function-count header/instruction-count header/switch-count opt-level
			function-sizes function-effects instruction-effects instruction-offsets
			instruction-depths entry-types catch-depths control-uses
			switch-effect-links switch-effect-users
		if status <> 0 [return release scratch signature-cache status]
		id: 1
		while [id <= header/type-count][
			global-size: 0
			global-align: 0
			unless layout-type id true type-data member-data header/type-count 0
				layouts member-offsets :global-size :global-align [
				return release scratch signature-cache INVALID_IR
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
			][return release scratch signature-cache INVALID_IR]
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			current-entry?: all [entry? id = header/entry-function]
			function-size: compile-function ir-function signature-cache function-instructions
				function-effects (instruction-effects + (next-instruction - 1))
				stack-types stack-flags stack-kinds stack-tags storage-offsets
				(result-offsets + (next-instruction - 1))
				layouts member-offsets
				(instruction-offsets + (next-offset - 1))
				(instruction-depths + (next-instruction - 1))
				(catch-depths + (next-instruction - 1))
				(control-uses + (next-instruction - 1))
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
				(function-outgoing + (id - 1))
			if function-size < 0 [return release scratch signature-cache function-size]
			function-sizes/id: function-size
			if function-names-size > (2147483647 - ir-function/name-size)[
				return release scratch signature-cache OUTPUT_FULL
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size)[return release scratch signature-cache OUTPUT_FULL]
			code-size: code-size + function-size
			if current-entry? [entry-size: function-size]
			next-instruction: next-instruction + ir-function/instruction-count
			next-offset: next-offset + ir-function/instruction-count + 1
			id: id + 1
		]
		function-code-size: code-size
		if code-size > (2147483647 - literal-size)[return release scratch signature-cache OUTPUT_FULL]
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
					return release scratch signature-cache OUTPUT_FULL
				]
				import-reference-count: import-reference-count + count
				if ir-import/library <> last-library [
					if import-names-size > (2147483647 - ir-import/library-size)[
						return release scratch signature-cache OUTPUT_FULL
					]
					import-names-size: import-names-size + ir-import/library-size
					last-library: ir-import/library
				]
				if import-names-size > (2147483647 - ir-import/external-size)[
					return release scratch signature-cache OUTPUT_FULL
				]
				import-names-size: import-names-size + ir-import/external-size
			]
			id: id + 1
		]
		image-import-count: used-import-count
		reference-count: global-reference-count + import-reference-count
		if entry? [
			if any [image-import-count = 2147483647 reference-count = 2147483647][
				return release scratch signature-cache OUTPUT_FULL
			]
			image-import-count: image-import-count + 1
			reference-count: reference-count + 1
		]

		metadata-size: IMAGE_HEADER_SIZE + (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > ((2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return release scratch signature-cache OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if image-import-count > ((2147483647 - metadata-size) / IMAGE_IMPORT_SIZE)[
			return release scratch signature-cache OUTPUT_FULL
		]
		metadata-size: metadata-size + (image-import-count * IMAGE_IMPORT_SIZE)
		if header/export-count > ((2147483647 - metadata-size) / IMAGE_EXPORT_SIZE)[
			return release scratch signature-cache OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/export-count * IMAGE_EXPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return release scratch signature-cache OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: function-names-size + global-names-size + import-names-size
		if names-size > (2147483647 - export-names-size)[
			return release scratch signature-cache OUTPUT_FULL
		]
		names-size: names-size + export-names-size
		if entry? [names-size: names-size + 23]
		if any [names-size < 0 metadata-size > (2147483647 - names-size - 15)][
			return release scratch signature-cache OUTPUT_FULL
		]
		code-offset: align (metadata-size + names-size) 16
		if any [code-offset < 0 code-offset > (2147483647 - code-size - 3)][
			return release scratch signature-cache OUTPUT_FULL
		]
		rodata-offset: align (code-offset + code-size) 4
		if any [
			rodata-offset < 0
			rodata-offset > (2147483647 - image-rodata-size - 3)
		][return release scratch signature-cache OUTPUT_FULL]
		data-offset: align (rodata-offset + image-rodata-size) 4
		if any [data-offset < 0 data-offset > (2147483647 - image-data-size)][
			return release scratch signature-cache OUTPUT_FULL
		]
		total-size: data-offset + image-data-size
		if total-size > capacity [return release scratch signature-cache OUTPUT_FULL]

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
		image/export-count: header/export-count

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
			+ (image-import-count * IMAGE_IMPORT_SIZE)
			+ (header/export-count * IMAGE_EXPORT_SIZE))
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

		id: 1
		while [id <= header/export-count][
			ir-export: as rsir-export! (export-data + ((id - 1) * RSIR_EXPORT_SIZE))
			image-export: as codegen-export! (output + IMAGE_HEADER_SIZE
				+ (header/function-count * IMAGE_FUNCTION_SIZE)
				+ (header/global-count * IMAGE_GLOBAL_SIZE)
				+ (image-import-count * IMAGE_IMPORT_SIZE)
				+ ((id - 1) * IMAGE_EXPORT_SIZE))
			image-export/symbol: ir-export/symbol
			image-export/name: name-cursor
			image-export/name-size: ir-export/name-size
			copy-memory (names-output + name-cursor)
				(strings + ir-export/name) ir-export/name-size
			name-cursor: name-cursor + ir-export/name-size
			id: id + 1
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
			written: compile-function ir-function signature-cache function-instructions
				function-effects (instruction-effects + (next-instruction - 1))
				stack-types stack-flags stack-kinds stack-tags storage-offsets
				(result-offsets + (next-instruction - 1))
				layouts member-offsets
				(instruction-offsets + (next-offset - 1))
				(instruction-depths + (next-instruction - 1))
				(catch-depths + (next-instruction - 1))
				(control-uses + (next-instruction - 1))
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
				(function-outgoing + (id - 1))
			if written < 0 [return release scratch signature-cache written]
			if written <> image-function/code-size [return release scratch signature-cache INVALID_IR]
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
									return release scratch signature-cache INVALID_IR
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
									true [return release scratch signature-cache INVALID_IR]
								]
								global-offset: image-global/data-offset + item-offset
								if global-offset > REFERENCE_OFFSET_MASK [
									return release scratch signature-cache OUTPUT_FULL
								]
								references/reference-id: either
									(image-global/flags and PROTECTED) <> 0 [
										RODATA_REFERENCE_TAG or global-offset
									][DATA_REFERENCE_TAG or global-offset]
							]
							true [return release scratch signature-cache INVALID_IR]
						]
						initializer-id: initializer-id + 1
						item-offset: item-offset + slot-width
					]
				]
			]
			id: id + 1
		]
		release scratch signature-cache total-size
	]
]
