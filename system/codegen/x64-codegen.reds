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

; The type and member tables, the size/alignment cache layout-type fills in as
; it walks them, and the cache compatibility checks memoize their verdicts in.
; Everything that has to reason about an RSIR type ref takes one of these.
type-table!: alias struct! [
	types          [byte-ptr!]
	members        [byte-ptr!]
	type-count     [integer!]
	layouts        [int-ptr!]
	member-offsets [int-ptr!]
	signatures     [signature-pairs!]
]

; The RSIR tables every function in the module is read from.
rsir-module!: alias struct! [
	table             [type-table!]
	parameters        [byte-ptr!]
	functions         [byte-ptr!]
	imports           [byte-ptr!]
	globals           [byte-ptr!]
	switches          [byte-ptr!]
	instructions      [byte-ptr!]
	strings           [byte-ptr!]
	function-count    [integer!]
	import-count      [integer!]
	global-count      [integer!]
	switch-count      [integer!]
	instruction-count [integer!]
	strings-size      [integer!]
]

; Working memory for one module, carved out of a single allocation by
; `generate`. The function arrays, instruction arrays, switch arrays and shared
; stack/storage arrays all live here; effect inference temporarily reuses later
; phase arrays for its graph and worklists. `window-scratch` produces a second
; record of this shape holding one function's view: the per-instruction arrays
; rebased so index 1 is that function's first instruction, the rest unchanged.
codegen-scratch!: alias struct! [
	instructions        [byte-ptr!]
	argument-targets    [byte-ptr!]
	function-sizes      [int-ptr!]
	function-frames     [int-ptr!]
	function-outgoing   [int-ptr!]
	function-effects    [int-ptr!]
	instruction-effects [int-ptr!]
	instruction-offsets [int-ptr!]
	relaxed-offsets     [int-ptr!]
	instruction-depths  [int-ptr!]
	catch-depths        [int-ptr!]
	control-uses        [int-ptr!]
	entry-types         [int-ptr!]
	entry-flags         [int-ptr!]
	entry-kinds         [int-ptr!]
	entry-tags          [int-ptr!]
	tag-next            [int-ptr!]
	tag-slots           [int-ptr!]
	tag-widths          [int-ptr!]
	result-offsets      [int-ptr!]
	stack-types         [int-ptr!]
	stack-flags         [int-ptr!]
	stack-kinds         [int-ptr!]
	stack-tags          [int-ptr!]
	storage-offsets     [int-ptr!]
	import-refs         [int-ptr!]
	switch-effect-links [int-ptr!]
	switch-effect-users [int-ptr!]
	effect-queue-tail   [integer!]
	resume-queue-tail   [integer!]
]

; What survives from one instruction to the next while one function is compiled:
; the frame it was laid out with, how far the emitted code has got, how deep the
; abstract stack is, and what the machine still happens to be holding. The
; handlers split out of the instruction loop take this record and open the
; fields they touch into locals of the same name, so their bodies work on plain
; values; the loop does the same for the four it reads on almost every line.
machine-state!: alias struct! [
	; Frame layout, fixed before the first instruction is compiled.
	storage-count           [integer!]	; parameters plus locals
	storage-bytes           [integer!]
	storage-base            [integer!]
	storage-slots           [integer!]
	segment-slots           [integer!]
	tag-base                [integer!]
	tag-capacity            [integer!]
	catch-base              [integer!]
	catch-capacity          [integer!]
	sub-frame               [integer!]
	native-stack-slot       [integer!]
	hidden-shift            [integer!]
	return-value?           [logic!]
	hidden-return?          [logic!]
	unstable-stack?         [logic!]
	; Nesting and entry counts the pre-scan accumulates and then checks.
	catch-level             [integer!]
	current-sub             [integer!]
	main-entry-count        [integer!]
	sub-entry-count         [integer!]
	tag-count               [integer!]
	; The emit cursor and the abstract stack.
	written                 [integer!]
	depth                   [integer!]
	max-depth               [integer!]
	max-outgoing            [integer!]
	current-entry           [integer!]
	fallthrough?            [logic!]
	; What a machine register still holds, and what may still be folded into the
	; next instruction rather than emitted for this one.
	location                [integer!]
	location-depth          [integer!]
	location-source         [integer!]
	location-reference      [integer!]
	source-location         [integer!]
	source-depth            [integer!]
	resident?               [logic!]
	resident-slot           [integer!]
	resident-width          [integer!]
	resident-mark           [integer!]
	resident-clean?         [logic!]
	incoming-arguments      [integer!]
	flags-condition         [integer!]
	last-math-operation     [integer!]
	pending-immediate-index [integer!]
	pending-immediate-value [integer!]
	pending-immediate-kind  [integer!]
	cpu-pointer-ref         [integer!]
]

; One function to compile and the image slot its code lands in. Sizes are
; measured first with `code` and `references` null, then the same task is
; replayed with both set; the four trailing fields carry results of the
; measuring pass back to the caller and into the emitting pass.
codegen-task!: alias struct! [
	fn                     [rsir-function!]
	first-instruction      [integer!]
	first-offset           [integer!]
	image-data             [byte-ptr!]
	code                   [byte-ptr!]
	references             [int-ptr!]
	function-offset        [integer!]
	function-code-size     [integer!]
	capacity               [integer!]
	exit-reference-id      [integer!]
	entry?                 [logic!]
	frame-size             [integer!]
	outgoing-size          [integer!]
	global-reference-count [integer!]
	literal-size           [integer!]
]

; Per-function state shared by the validation, layout, prologue, and emission
; phases. Keeping these four records together avoids passing a long list of
; phase inputs and makes the compile pipeline explicit.
x64-function-context!: alias struct! [
	module  [rsir-module!]
	task    [codegen-task!]
	scratch [codegen-scratch!]
	state   [machine-state!]
]

; Values prepared once per instruction and consumed by opcode-family emitters.
; Keeping these together avoids growing every emitter signature as the shared
; cursor preparation evolves.
x64-instruction-state!: alias struct! [
	next-index            [integer!]
	advance               [integer!]
	next-instruction      [rsir-instruction!]
	instruction-start     [integer!]
	allocation-size       [integer!]
	linear?               [logic!]
	paired?               [logic!]
	set-pair?             [logic!]
	address-pair?         [logic!]
	load-pair?            [logic!]
]

; What `generate` threads from one module-wide phase to the next: the input
; module being read, the image being written, the three records every function
; pass works from, and the running figures the image layout is derived from.
; Each phase opens the fields it touches into locals of the same name, exactly
; as the per-function phases do with x64-function-context!.
x64-module-context!: alias struct! [
	header                  [rsir-header!]
	module                  [rsir-module!]
	scratch                 [codegen-scratch!]
	task                    [codegen-task!]
	data                    [byte-ptr!]
	size                    [integer!]
	output                  [byte-ptr!]
	capacity                [integer!]
	opt-level               [integer!]
	entry?                  [logic!]
	; The two input tables rsir-module! does not carry, the walk over the input
	; the table phases claim from, and the row counts they validated.
	exports                 [byte-ptr!]
	initializers            [byte-ptr!]
	cursor                  [byte-ptr!]
	remaining               [integer!]
	member-count            [integer!]
	parameter-count         [integer!]
	initializer-count       [integer!]
	; The single scratch allocation every working array is carved out of.
	memory                  [byte-ptr!]
	; Static data areas, sized while the globals are laid out and placed.
	global-names-size       [integer!]
	export-names-size       [integer!]
	rodata-size             [integer!]
	data-size               [integer!]
	global-reference-count  [integer!]
	; Code and literals, measured before any of the image is written.
	function-names-size     [integer!]
	code-size               [integer!]
	function-code-size      [integer!]
	literal-size            [integer!]
	entry-size              [integer!]
	; Image layout, derived once the code size and the used imports are known.
	import-count            [integer!]
	reference-count         [integer!]
	metadata-size           [integer!]
	names-size              [integer!]
	code-offset             [integer!]
	rodata-offset           [integer!]
	data-offset             [integer!]
	total-size              [integer!]
	; The name area and the reference table, filled as the metadata is written.
	names                   [byte-ptr!]
	name-cursor             [integer!]
	references              [int-ptr!]
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
	EFFECT_SHORT_BRANCH:   128
	EFFECT_SHORT_JUMP:     256
	EFFECT_SHORT:          384
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
	; A scalar parameter still resides in its incoming Win64 argument register.
	LOCATION_ARGUMENT:       9
	; Zero means no stack tag, positive values are variant-chain instruction
	; indexes, and -1 marks a direct binary64 literal without colliding with them.
	FLOAT_LITERAL_TAG: -1
	ANY_POINTER_REF: -16

	INVALID_IR:  -1
	UNSUPPORTED: -2
	OUTPUT_FULL: -3
	PREPARE_SKIPPED: 1

	align: func [value boundary [integer!] return: [integer!]
		/local remainder padding [integer!]
	][
		if any [value < 0 boundary <= 0][return -1]
		remainder: value // boundary
		if remainder = 0 [return value]
		padding: boundary - remainder
		either value > (2147483647 - padding) [-1][value + padding]
	]

	valid-type-ref?: func [ref [integer!] table [type-table!] return: [logic!]][
		any [
			all [ref > 0 ref <= table/type-count]
			all [ref < 0 ref >= -15]
		]
	]

	canonical-type: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local record [rsir-type!] steps [integer!]
	][
		if ref < 0 [return either ref = -15 [-2][ref]]
		steps: 0
		while [steps < table/type-count][
			if any [ref <= 0 ref > table/type-count][return 0]
			record: as rsir-type! (table/types + ((ref - 1) * RSIR_TYPE_SIZE))
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
		table [type-table!]
		return: [integer!]
		/local record [rsir-type!] base [integer!]
	][
		base: canonical-type ref table
		if base < 0 [return 0 - base]
		if base = 0 [return 0]
		record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
		record/kind
	]

	aggregate-ref?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref table
		any [kind = -2 kind = -3]
	]

	array-ref?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
	][
		(logical-kind ref table) = -7
	]

	inline-object-ref?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
	][
		any [
			aggregate-ref? ref table
			array-ref? ref table
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
		table [type-table!]
		return: [logic!]
		/local base [integer!] record [rsir-type!]
	][
		base: canonical-type ref table
		if base <= 0 [return false]
		record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
		all [record/kind = -3 record/flags = TAGGED_UNION]
	]

	union-tag-width: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local base [integer!] record [rsir-type!]
	][
		base: canonical-type ref table
		if base <= 0 [return 0]
		record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
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
		table [type-table!]
		return: [logic!]
		/local left right left-kind right-kind target [integer!]
			left-record right-record [rsir-type!]
	][
		if expected = actual [return true]
		left: canonical-type expected table
		right: canonical-type actual table
		if any [left = 0 right = 0][return false]
		if left = right [return true]
		left-kind: logical-kind left table
		right-kind: logical-kind right table
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
			right-record: as rsir-type! (table/types + ((right - 1) * RSIR_TYPE_SIZE))
			target: 0
			case [
				left-kind = 13 [target: -15]
				all [left-kind = -6 left > 0][
					left-record: as rsir-type! (table/types + ((left - 1) * RSIR_TYPE_SIZE))
					target: left-record/target
				]
				true [0]
			]
			if all [
				target <> 0
				(canonical-type target table)
					= (canonical-type right-record/target table)
			][return true]
		]
		all [left-kind > 0 left-kind = right-kind]
	]

	integer-pointer-type: func [
		table [type-table!]
		return: [integer!]
		/local id [integer!] record [rsir-type!]
	][
		id: 1
		while [id <= table/type-count][
			record: as rsir-type! (table/types + ((id - 1) * RSIR_TYPE_SIZE))
			if all [
				record/kind = -6
				(canonical-type record/target table) = -5
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
		table [type-table!]
		return: [integer!]
		/local left-kind right-kind
	][
		if compatible-types? left right table [
			left-kind: logical-kind left table
			if left-kind = 14 [
				right-kind: logical-kind right table
				if reference-kind? right-kind [return ANY_POINTER_REF]
			]
			return left
		]
		left-kind: logical-kind left table
		right-kind: logical-kind right table
		either all [
			left-kind = right-kind
			any [left-kind = -6 left-kind = -2 left-kind = -3]
		][left][0]
	]

	signed-type?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref table
		any [kind = 1 kind = 3 kind = 5 kind = 7]
	]

	float-type?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref table
		any [kind = 9 kind = 10]
	]

	layout-type: func [
		ref [integer!]
		inline? [logic!]
		table [type-table!]
		depth [integer!]
		size-out align-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			cache offset-slot [int-ptr!]
			kind id mode member-size member-align size alignment tag-size
			payload-offset element-size element-align
				[integer!]
			cached? [logic!]
	][
		if any [ref = 0 depth > table/type-count][return false]
		if ref = -15 [ref: -2]
		cache: as int-ptr! 0
		cached?: false
		kind: 0
		either ref < 0 [
			kind: 0 - ref
		][
			if ref > table/type-count [return false]
			record: as rsir-type! (table/types + ((ref - 1) * RSIR_TYPE_SIZE))
			kind: record/kind
			if not null? as byte-ptr! table/layouts [
				mode: either inline? [0][2]
				cache: table/layouts + (((ref - 1) * 4) + mode)
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
				unless layout-type record/target inline? table (depth + 1) :size :alignment [
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
					unless layout-type record/target false table (depth + 1)
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
						member: as rsir-member! (table/members
							+ ((record/first-member + id) * RSIR_MEMBER_SIZE))
						member-size: 0
						member-align: 0
						unless layout-type member/type (member/flags = INLINE)
							table (depth + 1) :member-size :member-align [return false]
						if member-align > alignment [alignment: member-align]
						either kind = -2 [
							size: align size member-align
							if any [
								size < 0
								size > (2147483647 - member-size)
							][return false]
							if not null? as byte-ptr! table/member-offsets [
								offset-slot: (table/member-offsets + record/first-member) + id
								offset-slot/1: size
							]
							size: size + member-size
						][
							if member-size > size [size: member-size]
							if all [
								record/flags = 0
								not null? as byte-ptr! table/member-offsets
							][
								offset-slot: (table/member-offsets + record/first-member) + id
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
						if not null? as byte-ptr! table/member-offsets [
							offset-slot: table/member-offsets + record/first-member
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
		table [type-table!]
		return: [integer!]
		/local base size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref table
		if base = 0 [return 0]
		if all [base > 0 (logical-kind base table) = -7][
			record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
			return record/member-count
		]
		size: 0
		alignment: 0
		either layout-type ref true table 0 :size :alignment [size][0]
	]

	value-width: func [
		ref flags [integer!]
		table [type-table!]
		return: [integer!]
		/local size alignment [integer!]
	][
		size: 0
		alignment: 0
		either layout-type ref (flags = INLINE) table 0 :size :alignment [size][0]
	]

	machine-value?: func [
		ref flags [integer!]
		table [type-table!]
		return: [logic!]
		/local width [integer!]
	][
		width: value-width ref flags table
		all [width > 0 width <= 8
			not all [flags = INLINE inline-object-ref? ref table]]
	]

	win64-register-size?: func [size [integer!] return: [logic!]][
		any [size = 1 size = 2 size = 4 size = 8]
	]

	aggregate-size: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local size alignment [integer!]
	][
		unless aggregate-ref? ref table [return 0]
		size: 0
		alignment: 0
		either layout-type ref true table 0 :size :alignment [size][0]
	]

	win64-aggregate-width: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local size [integer!]
	][
		size: aggregate-size ref table
		either win64-register-size? size [size][0]
	]

	win64-hidden-return?: func [
		ref flags [integer!]
		table [type-table!]
		return: [logic!]
	][
		all [
			(flags and RETURN_VALUE) <> 0
			aggregate-ref? ref table
			(win64-aggregate-width ref table) = 0
		]
	]

	integer-type?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref table
		all [kind >= 1 kind <= 8]
	]

	address-integer-kind?: func [kind [integer!] return: [logic!]][
		any [kind = 5 kind = 6 kind = 7 kind = 8]
	]

	cast-kind: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local record [rsir-type!] kind steps [integer!]
	][
		; Canonical arithmetic aliases byte! to uint8!, but the cast matrix does not.
		if ref = -15 [return 15]
		if ref < 0 [return 0 - ref]
		steps: 0
		while [steps < table/type-count][
			if any [ref <= 0 ref > table/type-count][return 0]
			record: as rsir-type! (table/types + ((ref - 1) * RSIR_TYPE_SIZE))
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
		table [type-table!]
		return: [integer!]
		/local left right left-kind right-kind pair-index hash status [integer!]
			data slots stamps slot hash-slot stamp [int-ptr!]
	][
		if expected = actual [return 1]
		if compatible-types? expected actual table [return 1]
		left: canonical-type expected table
		right: canonical-type actual table
		if any [left <= 0 right <= 0][return 0]
		left-kind: logical-kind left table
		right-kind: logical-kind right table
		unless all [left-kind = -4 right-kind = -4][return 0]
		data: as int-ptr! table/signatures/memory
		slots: data + (table/signatures/pair-capacity * 2)
		stamps: slots + table/signatures/slot-capacity
		hash: ((left * 65599) xor right) and (table/signatures/slot-capacity - 1)
		hash-slot: slots + hash
		stamp: stamps + hash
		while [stamp/1 = table/signatures/epoch][
			pair-index: hash-slot/1 - 1
			slot: data + (pair-index * 2)
			if all [slot/1 = left slot/2 = right][return 1]
			hash: (hash + 1) and (table/signatures/slot-capacity - 1)
			hash-slot: slots + hash
			stamp: stamps + hash
		]
		if table/signatures/pair-count = table/signatures/pair-capacity [
			status: grow-signature-pairs table/signatures
			if status < 0 [return status]
			data: as int-ptr! table/signatures/memory
			slots: data + (table/signatures/pair-capacity * 2)
			stamps: slots + table/signatures/slot-capacity
			hash: ((left * 65599) xor right) and (table/signatures/slot-capacity - 1)
			hash-slot: slots + hash
			stamp: stamps + hash
			while [stamp/1 = table/signatures/epoch][
				hash: (hash + 1) and (table/signatures/slot-capacity - 1)
				hash-slot: slots + hash
				stamp: stamps + hash
			]
		]
		slot: data + (table/signatures/pair-count * 2)
		slot/1: left
		slot/2: right
		hash-slot/1: table/signatures/pair-count + 1
		stamp/1: table/signatures/epoch
		table/signatures/pair-count: table/signatures/pair-count + 1
		1
	]

	function-types-compatible: func [
		expected actual [integer!]
		table [type-table!]
		return: [integer!]
		/local cursor id status [integer!]
			slot [int-ptr!] left-type right-type [rsir-type!]
			left-member right-member [rsir-member!]
	][
		status: reset-signature-pairs table/signatures
		if status < 0 [return status]
		status: queue-compatible-types expected actual table
		if status <> 1 [return status]
		cursor: 0
		while [cursor < table/signatures/pair-count][
			slot: (as int-ptr! table/signatures/memory) + (cursor * 2)
			left-type: as rsir-type! (table/types + ((slot/1 - 1) * RSIR_TYPE_SIZE))
			right-type: as rsir-type! (table/types + ((slot/2 - 1) * RSIR_TYPE_SIZE))
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
				status: queue-compatible-types left-type/target right-type/target table
				if status <> 1 [return status]
			]
			id: 0
			while [id < left-type/member-count][
				left-member: as rsir-member! (table/members
					+ ((left-type/first-member + id) * RSIR_MEMBER_SIZE))
				right-member: as rsir-member! (table/members
					+ ((right-type/first-member + id) * RSIR_MEMBER_SIZE))
				if left-member/flags <> right-member/flags [return 0]
				status: queue-compatible-types left-member/type right-member/type table
				if status <> 1 [return status]
				id: id + 1
			]
			cursor: cursor + 1
		]
		1
	]

	sink-compatible-types: func [
		expected actual [integer!]
		table [type-table!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		if compatible-types? expected actual table [return 1]
		left-kind: logical-kind expected table
		right-kind: logical-kind actual table
		unless all [left-kind = -4 right-kind = -4][return 0]
		function-types-compatible expected actual table
	]

	implicitly-compatible-types: func [
		expected actual tag [integer!]
		allow-float-literal? [logic!]
		table [type-table!]
		return: [integer!]
		/local expected-kind actual-kind status [integer!]
	][
		status: sink-compatible-types expected actual table
		if status <> 0 [return status]
		expected-kind: logical-kind expected table
		actual-kind: logical-kind actual table
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
		table [type-table!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		left-kind: logical-kind left table
		right-kind: logical-kind right table
		if any [
			left-kind < 1 left-kind > 8
			right-kind < 1 right-kind > 8
		][return 0]
		if compatible-types? left right table [return left]
		if integer-kind-widens? right-kind left-kind [return left]
		if integer-kind-widens? left-kind right-kind [return right]
		0
	]

	float-common-ref: func [
		left right [integer!]
		table [type-table!]
		return: [integer!]
		/local left-kind right-kind [integer!]
	][
		left-kind: logical-kind left table
		right-kind: logical-kind right table
		unless all [
			any [left-kind = 9 left-kind = 10]
			any [right-kind = 9 right-kind = 10]
		][return 0]
		either any [left-kind = 9 right-kind = 9][-9][-10]
	]

	reference-type?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: logical-kind ref table
		reference-kind? kind
	]

	address-type?: func [
		ref [integer!]
		table [type-table!]
		return: [logic!]
	][
		address-kind? logical-kind ref table
	]

	; A pointer offset literal must survive its stride multiplication inside the
	; sign-extended imm32 form. Both the literal pairing decision and the
	; immediate fold read this one rule.
	scaled-pointer-literal?: func [
		value ref [integer!]
		table [type-table!]
		return: [logic!]
		/local stride [integer!]
	][
		stride: pointer-stride ref table
		if stride <= 0 [return false]
		either value < 0 [
			value >= (80000000h / stride)
		][value <= (7FFFFFFFh / stride)]
	]

	pointer-stride: func [
		ref [integer!]
		table [type-table!]
		return: [integer!]
		/local base kind size alignment [integer!] record [rsir-type!]
	][
		base: canonical-type ref table
		if base = 0 [return 0]
		kind: logical-kind base table
		if any [kind = 12 kind = 13 kind = 16][return 1]
		size: 0
		alignment: 0
		case [
			kind = -7 [
				record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
				size: record/flags
				unless any [size = 1 size = 2 size = 4 size = 8][return 0]
			]
			kind = -6 [
				record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
				unless layout-type record/target true table 0 :size :alignment [
					return 0
				]
			]
			any [kind = -2 kind = -3][
				unless layout-type base true table 0 :size :alignment [return 0]
			]
			true [return 0]
		]
		size
	]

	pointee-type: func [
		ref [integer!]
		table [type-table!]
		result [int-ptr!]
		return: [logic!]
		/local base kind [integer!] record [rsir-type!]
	][
		base: canonical-type ref table
		if base = 0 [return false]
		kind: logical-kind base table
		if kind = 13 [result/1: -15 return true]
		if any [kind = -2 kind = -3][result/1: base return true]
		unless all [any [kind = -6 kind = -7] base > 0][return false]
		record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
		result/1: record/target
		valid-type-ref? result/1 table
	]

	static-address-representation-compatible?: func [
		target source [integer!]
		table [type-table!]
		return: [logic!]
		/local target-kind source-kind [integer!]
	][
		if compatible-types? target source table [return true]
		target-kind: logical-kind target table
		source-kind: logical-kind source table
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
		globals [byte-ptr!]
		table [type-table!]
		return: [logic!]
		/local target [rsir-global!] kind pointee source [integer!]
	][
		if initializer/kind <> ADDRESS_INITIALIZER [return false]
		source: either initializer/c = 0 [expected][initializer/c]
		if all [
			initializer/c <> 0
			any [
				not valid-type-ref? source table
				not static-address-representation-compatible? expected source table
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
				if compatible-types? source target/type table [return true]
				pointee: 0
				unless pointee-type source table :pointee [return false]
				compatible-types? pointee target/type table
			]
			initializer/a = FUNCTION_ADDRESS [
				if any [initializer/b <= 0 initializer/b > function-count][return false]
				kind: logical-kind source table
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
		capacity target displacement [integer!]
		source-width operation-width signed [integer!]
		return: [integer!]
		/local encoded written [integer!] at [byte-ptr!]
	][
		if source-width <= 0 [return -1]
		encoded: x64-encoder/frame-load code capacity target displacement
			source-width signed
		if encoded < 0 [return encoded]
		written: encoded
		if all [operation-width = 8 source-width < 8 signed = 1][
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/sign-extend-register at (capacity - written) target target
			if encoded < 0 [return encoded]
			written: written + encoded
		]
		written
	]

	move-operation-value: func [
		code [byte-ptr!]
		capacity target source [integer!]
		source-width operation-width signed [integer!]
		return: [integer!]
		/local transfer-width encoded written [integer!]
	][
		unless all [
			source-width > 0
			any [operation-width = 4 operation-width = 8]
		][return -1]
		transfer-width: either all [
			operation-width = 8 source-width = 8
		][8][4]
		; MOVSXD already reads the narrow source, so the transfer and the
		; extension are one instruction.
		if all [operation-width = 8 source-width < 8 signed = 1][
			return x64-encoder/sign-extend-register code capacity target source
		]
		written: 0
		if target <> source [
			encoded: x64-encoder/move-register code capacity target source transfer-width
			if encoded < 0 [return encoded]
			written: encoded
		]
		written
	]

	layout-member: func [
		ref index [integer!]
		table [type-table!]
		type-out flags-out offset-out [int-ptr!]
		return: [logic!]
		/local record [rsir-type!] member [rsir-member!]
			offset-slot [int-ptr!] base kind [integer!]
	][
		if null? as byte-ptr! table/member-offsets [return false]
		base: canonical-type ref table
		if any [base <= 0 index < 0][return false]
		record: as rsir-type! (table/types + ((base - 1) * RSIR_TYPE_SIZE))
		kind: record/kind
		unless any [kind = -2 kind = -3][return false]
		if index >= record/member-count [return false]
		member: as rsir-member! (table/members
			+ ((record/first-member + index) * RSIR_MEMBER_SIZE))
		offset-slot: (table/member-offsets + record/first-member) + index
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RAX 80000000h
		if encoded < 0 [return encoded]
		written: written + encoded

		tail-size: x64-encoder/compare-immediate null 0 x64-encoder/RCX -1
		if tail-size < 0 [return tail-size]
		tail-size: tail-size + 6
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 5 tail-size
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RCX -1
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: jump-condition-to at (capacity - written) 4 target
			(current + written)
		if encoded < 0 [return encoded]
		written + encoded
	]

	shift-overflow-check: func [
		code [byte-ptr!]
		capacity source-width operation-width signed count target-displacement [integer!]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RDX x64-encoder/RAX operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		original: x64-encoder/RAX
		alignment: (operation-width - source-width) * 8
		if alignment > 0 [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/shift-immediate at (capacity - written)
				x64-encoder/RDX 4 alignment operation-width
			if encoded < 0 [return encoded]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/R8 x64-encoder/RDX operation-width
			if encoded < 0 [return encoded]
			written: written + encoded
			original: x64-encoder/R8
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RDX 4 count operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		mode: either signed = 1 [7][5]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RDX mode count operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			39h x64-encoder/RDX original operation-width
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: jump-condition-to at (capacity - written) 5
			target-displacement written
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/RAX upper
		if encoded < 0 [return encoded]
		written: written + encoded
		condition: either signed = 1 [15][7]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: jump-condition-to at (capacity - written) condition target
			(current + written)
		if encoded < 0 [return encoded]
		written: written + encoded
		if signed = 1 [
			lower: either width = 1 [-128][-32768]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/compare-immediate at (capacity - written)
				x64-encoder/RAX lower
			if encoded < 0 [return encoded]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: jump-condition-to at (capacity - written) 12 target
				(current + written)
			if encoded < 0 [return encoded]
			written: written + encoded
		]
		written
	]

	emit-variant-tags: func [
		code [byte-ptr!]
		capacity head [integer!]
		state [machine-state!]
		fn [rsir-function!]
		scratch [codegen-scratch!]
		return: [integer!]
		/local at [byte-ptr!] instruction [rsir-instruction!]
			node width encoded written steps [integer!]
	][
		written: 0
		steps: 0
		node: head
		while [node > 0][
			if any [node > fn/instruction-count steps >= fn/instruction-count][return -1]
			instruction: as rsir-instruction! (scratch/instructions
				+ ((node - 1) * RSIR_INSTRUCTION_SIZE))
			width: scratch/tag-widths/node
			if any [instruction/b <= 0 scratch/tag-slots/node <= 0
				not any [width = 1 width = 2 width = 4]][return -1]

			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/frame-load at (capacity - written)
				x64-encoder/RDX slot-displacement
					(state/tag-base + scratch/tag-slots/node) 8 0
			if encoded < 0 [return encoded]
			written: written + encoded

			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-immediate-compact at (capacity - written)
				x64-encoder/RAX 4 instruction/b 0
			if encoded < 0 [return encoded]
			written: written + encoded

			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/store-indirect at (capacity - written) width
			if encoded < 0 [return encoded]
			written: written + encoded
			node: scratch/tag-next/node
			steps: steps + 1
		]
		written
	]

	storage-displacement: func [offsets [int-ptr!] slot [integer!] return: [integer!]][
		offsets/slot
	]

	; Lays out the frame homes of one function's parameters and locals and returns
	; the bytes they occupy. Slots left at 0 need no home at all.
	plan-storage: func [
		module [rsir-module!]
		fn [rsir-function!]
		offsets [int-ptr!]
		return: [integer!]
		/local parameter [rsir-parameter!]
			table [type-table!]
			parameters [byte-ptr!]
			count index used size alignment hidden-shift physical-slot [integer!]
	][
		table:      module/table
		parameters: module/parameters
		count: fn/parameter-count + fn/local-count
		index: 1
		hidden-shift: either win64-hidden-return? fn/return-type fn/flags
			table [1][0]
		used: hidden-shift * 8
		while [index <= count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			physical-slot: index + hidden-shift
			case [
				all [
					index <= fn/parameter-count
					physical-slot <= 4
					offsets/index = 0
				][
					; An unused or directly forwarded register parameter has no home.
					offsets/index: 0
				]
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
						unless layout-type parameter/type true table 0 :size :alignment [return INVALID_IR]
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

	; Gives every live call whose result cannot travel in a register a frame slot
	; above the storage already planned, and returns the bytes now in use.
	; The scratch record is already windowed to this function.
	plan-call-results: func [
		module [rsir-module!]
		fn [rsir-function!]
		scratch [codegen-scratch!]
		used [integer!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			callee [rsir-function!] imported [rsir-import!]
			signature metadata [rsir-type!]
			table [type-table!]
			functions imports instructions [byte-ptr!]
			instruction-effects function-effects offsets [int-ptr!]
			function-count import-count
			index target import-id ref flags size signature-ref [integer!]
	][
		table:     module/table
		functions: module/functions
		imports:   module/imports
		function-count: module/function-count
		import-count:   module/import-count
		instructions:        scratch/instructions
		instruction-effects: scratch/instruction-effects
		function-effects:    scratch/function-effects
		offsets:             scratch/result-offsets
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
					(logical-kind signature-ref table) = -8
				][
					signature-ref: canonical-type signature-ref table
					if signature-ref <= 0 [return INVALID_IR]
					metadata: as rsir-type! (table/types
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
						not valid-type-ref? signature-ref table
						(logical-kind signature-ref table) <> -4
					][return INVALID_IR]
					signature: as rsir-type! (table/types
						+ (((canonical-type signature-ref table) - 1)
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
						win64-hidden-return? ref flags table
					]
				][
					size: aggregate-size ref table
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
			at: either null? code [as byte-ptr! 0][code + written]
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

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 7 count width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 31h
			x64-encoder/RCX x64-encoder/RAX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 29h
			x64-encoder/RCX x64-encoder/RAX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RDX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 7 count width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written) 21h
			x64-encoder/RAX x64-encoder/RCX width
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX -8 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX slot-displacement record-slot 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX -16 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX slot-displacement (record-slot + 1) 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RSP slot-displacement (record-slot + 2) 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement filter-slot 4 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -8 4
		if encoded < 0 [return encoded]
		written: written + encoded

		displacement: either null? code [0][target - (current + written + 7)]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/rip-address at (capacity - written)
			x64-encoder/RAX displacement
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement record-slot 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -8 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX slot-displacement (record-slot + 1) 8 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX -16 8
		if encoded < 0 [return encoded]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
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

	; Sets one effect bit and, if that is news, queues the instruction for
	; propagation. EFFECT_RESUMES travels on its own worklist; EFFECT_RETURNS and
	; EFFECT_LIVE share the main one and are never propagated at the same time.
	queue-effect: func [
		scratch [codegen-scratch!]
		index bit [integer!]
		/local effects queue [int-ptr!] position [integer!]
	][
		effects: scratch/instruction-effects
		if (effects/index and bit) = 0 [
			effects/index: effects/index or bit
			either bit = EFFECT_RESUMES [
				queue: scratch/entry-types
				position: scratch/resume-queue-tail + 1
				scratch/resume-queue-tail: position
			][
				queue: scratch/instruction-depths
				position: scratch/effect-queue-tail + 1
				scratch/effect-queue-tail: position
			]
			queue/position: index
		]
	]

	record-effect-use: func [
		scratch [codegen-scratch!]
		target user [integer!]
		/local heads links targets [int-ptr!]
	][
		heads:   scratch/instruction-offsets
		links:   scratch/catch-depths
		targets: scratch/control-uses
		links/user: heads/target
		heads/target: user
		targets/user: target
	]

	record-switch-effect-use: func [
		scratch [codegen-scratch!]
		target user slot [integer!]
		/local heads links users [int-ptr!]
	][
		heads: scratch/instruction-offsets
		links: scratch/switch-effect-links
		users: scratch/switch-effect-users
		links/slot: heads/target
		users/slot: user
		heads/target: 0 - slot
	]

	update-call-effects: func [
		scratch [codegen-scratch!]
		index instruction-count [integer!]
		sub-call? [logic!]
		/local effects targets [int-ptr!]
			next-index target [integer!]
			next? target-returns? target-resumes? [logic!]
	][
		effects: scratch/instruction-effects
		targets: scratch/control-uses
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
				queue-effect scratch index EFFECT_RETURNS
			]
			if all [
				target-resumes? next?
				(effects/next-index and EFFECT_RESUMES) <> 0
			][
				queue-effect scratch index EFFECT_RESUMES
			]
		][
			target-returns?: any [
				target = 0
				(effects/target and EFFECT_RETURNS) <> 0
			]
			if all [target-returns? next?][
				if (effects/next-index and EFFECT_RETURNS) <> 0 [
					queue-effect scratch index EFFECT_RETURNS
				]
				if (effects/next-index and EFFECT_RESUMES) <> 0 [
					queue-effect scratch index EFFECT_RESUMES
				]
			]
		]
	]

	; Marks every instruction that can reach a return or a subroutine resume,
	; folds literal logic branches at O2, then keeps only what is reachable.
	; Functions whose entry never returns are flagged NO_RETURN for the caller.
	infer-effects: func [
		module [rsir-module!]
		scratch [codegen-scratch!]
		opt-level [integer!]
		return: [integer!]
		/local fn [rsir-function!]
			instruction previous [rsir-instruction!]
			overflow-scope [rsir-instruction!]
			switch-case [rsir-switch!]
			functions instructions switches [byte-ptr!]
			function-starts function-effects effects heads links targets
				switch-links switch-users queue resume-queue [int-ptr!]
			function-count instruction-count switch-count
			id index global-index function-base target global-target
			case-index switch-id edge user queue-head resume-head
				next-index effect-bit [integer!]
			catch-caller? constant? taken? [logic!]
	][
		functions:    module/functions
		instructions: module/instructions
		switches:     module/switches
		function-count:    module/function-count
		instruction-count: module/instruction-count
		switch-count:      module/switch-count
		function-starts:  scratch/function-sizes
		function-effects: scratch/function-effects
		effects:          scratch/instruction-effects
		heads:            scratch/instruction-offsets
		links:            scratch/catch-depths
		targets:          scratch/control-uses
		switch-links:     scratch/switch-effect-links
		switch-users:     scratch/switch-effect-users
		queue:            scratch/instruction-depths
		resume-queue:     scratch/entry-types

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

		scratch/effect-queue-tail: 0
		scratch/resume-queue-tail: 0
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
						queue-effect scratch global-index EFFECT_RETURNS
					]
					instruction/op = OP_SUB_RETURN [
						queue-effect scratch global-index EFFECT_RESUMES
					]
					any [
						instruction/op = OP_JUMP
						instruction/op = OP_BRANCH
						instruction/op = OP_CATCH
					][
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: function-base + target - 1
						record-effect-use scratch global-target global-index
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
							record-effect-use scratch global-target global-index
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
						record-effect-use scratch global-target global-index
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
							record-switch-effect-use scratch global-target global-index switch-id
							case-index: case-index + 1
						]
					]
					instruction/op = OP_CALL [
						if instruction/a > 0 [
							if instruction/a > function-count [return INVALID_IR]
							unless catch-caller? [
								target: instruction/a
								global-target: function-starts/target
								record-effect-use scratch global-target global-index
							]
						]
					]
					instruction/op = OP_SUB_CALL [
						target: instruction/a
						if any [target <= 0 target > fn/instruction-count][return INVALID_IR]
						global-target: function-base + target - 1
						record-effect-use scratch global-target global-index
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
		while [any [
			queue-head <= scratch/effect-queue-tail
			resume-head <= scratch/resume-queue-tail
		]][
			either queue-head <= scratch/effect-queue-tail [
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
						update-call-effects scratch user instruction-count
							(instruction/op = OP_SUB_CALL)
					]
					instruction/op = OP_BRANCH [
						constant?: (effects/user and EFFECT_CONSTANT_BRANCH) <> 0
						taken?: (effects/user and EFFECT_BRANCH_TAKEN) <> 0
						unless all [constant? taken?][
							queue-effect scratch user effect-bit
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
					true [queue-effect scratch user effect-bit]
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
						update-call-effects scratch user instruction-count
							(instruction/op = OP_SUB_CALL)
					][
						queue-effect scratch user effect-bit
					]
				]
			]
		]

		; Switch links are no longer needed after the fixed point. Reuse them for
		; the exact global case targets consumed by the forward reachability walk.
		queue-head: 1
		scratch/effect-queue-tail: 0
		id: 1
		while [id <= function-count][
			fn: as rsir-function! (functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			function-base: function-starts/id
			queue-effect scratch function-base EFFECT_LIVE
			index: 1
			while [index <= fn/instruction-count][
				global-index: function-base + index - 1
				instruction: as rsir-instruction! (instructions
					+ ((global-index - 1) * RSIR_INSTRUCTION_SIZE))
				if instruction/op = OP_ENTRY [
					queue-effect scratch global-index EFFECT_LIVE
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

		while [queue-head <= scratch/effect-queue-tail][
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
					queue-effect scratch targets/index EFFECT_LIVE
				]
				instruction/op = OP_BRANCH [
					constant?: (effects/index and EFFECT_CONSTANT_BRANCH) <> 0
					taken?: (effects/index and EFFECT_BRANCH_TAKEN) <> 0
					either constant? [
						either taken? [
							queue-effect scratch targets/index EFFECT_LIVE
						][
							if next-index > 0 [
								queue-effect scratch next-index EFFECT_LIVE
							]
						]
					][
						queue-effect scratch targets/index EFFECT_LIVE
						if next-index > 0 [
							queue-effect scratch next-index EFFECT_LIVE
						]
					]
				]
				instruction/op = OP_SWITCH [
					queue-effect scratch targets/index EFFECT_LIVE
					case-index: 0
					while [case-index < instruction/b][
						switch-id: instruction/a + case-index + 1
						queue-effect scratch switch-links/switch-id EFFECT_LIVE
						case-index: case-index + 1
					]
				]
				any [instruction/op = OP_BINARY instruction/op = OP_CATCH][
					if targets/index > 0 [
						queue-effect scratch targets/index EFFECT_LIVE
					]
					if next-index > 0 [
						queue-effect scratch next-index EFFECT_LIVE
					]
				]
				instruction/op = OP_CALL [
					if all [
						next-index > 0
						any [
							target = 0
							(effects/target and EFFECT_RETURNS) <> 0
						]
					][queue-effect scratch next-index EFFECT_LIVE]
				]
				instruction/op = OP_SUB_CALL [
					if all [
						next-index > 0
						(effects/target and EFFECT_RESUMES) <> 0
					][queue-effect scratch next-index EFFECT_LIVE]
				]
				true [
					if next-index > 0 [
						queue-effect scratch next-index EFFECT_LIVE
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

	boolean-diamond-branch?: func [
		index instruction-count [integer!]
		instructions [byte-ptr!]
		effects catch-depths control-uses [int-ptr!]
		return: [logic!]
		/local consumer [rsir-instruction!] consumer-index [integer!]
	][
		unless boolean-diamond? index instruction-count instructions
			catch-depths control-uses [return false]
		consumer-index: index + 4
		consumer: as rsir-instruction! (instructions
			+ ((consumer-index - 1) * RSIR_INSTRUCTION_SIZE))
		all [
			control-uses/consumer-index = 1
			(effects/consumer-index and EFFECT_LIVE) <> 0
			(effects/consumer-index and EFFECT_ELIDED) = 0
			(effects/consumer-index and EFFECT_CONSTANT_BRANCH) = 0
			consumer/op = OP_BRANCH
			any [consumer/b = 0 consumer/b = 1]
			consumer/c = 0
		]
	]

	relax-branches: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		effects offsets relaxed catch-depths control-uses [int-ptr!]
		return: [integer!]
		/local instruction [rsir-instruction!]
			index next-index target displacement reduction shrink marker pass [integer!]
			changed? constant? taken? [logic!]
	][
		index: 1
		while [index <= fn/instruction-count][
			effects/index: effects/index and 127
			index: index + 1
		]
		changed?: true
		pass: 0
		while [changed?][
			pass: pass + 1
			if pass > 32 [return -1]
			reduction: 0
			index: 1
			while [index <= (fn/instruction-count + 1)][
				relaxed/index: offsets/index - reduction
				if index <= fn/instruction-count [
					case [
						(effects/index and EFFECT_SHORT_BRANCH) <> 0 [
							reduction: reduction + 4
						]
						(effects/index and EFFECT_SHORT_JUMP) <> 0 [
							reduction: reduction + 3
						]
						true [0]
					]
				]
				index: index + 1
			]

			changed?: false
			index: 1
			while [index <= fn/instruction-count][
				if all [
					(effects/index and EFFECT_LIVE) <> 0
					(effects/index and EFFECT_ELIDED) = 0
					(effects/index and EFFECT_SHORT) = 0
				][
					instruction: as rsir-instruction! (instructions
						+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
					if all [
						instruction/op = OP_BRANCH
						(effects/index and EFFECT_CONSTANT_BRANCH) = 0
						boolean-diamond? index fn/instruction-count instructions
							catch-depths control-uses
					][
						index: index + 4
						continue
					]
					marker: 0
					shrink: 0
					case [
						all [instruction/op = OP_JUMP instruction/c = 0][
							marker: EFFECT_SHORT_JUMP
							shrink: 3
						]
						instruction/op = OP_BRANCH [
							constant?: (effects/index and EFFECT_CONSTANT_BRANCH) <> 0
							taken?: (effects/index and EFFECT_BRANCH_TAKEN) <> 0
							case [
								all [constant? taken?][
									marker: EFFECT_SHORT_JUMP
									shrink: 3
								]
								all [
									not constant?
									not boolean-diamond? index fn/instruction-count
										instructions catch-depths control-uses
								][
									marker: EFFECT_SHORT_BRANCH
									shrink: 4
								]
								true [0]
							]
						]
						true [0]
					]
					if marker <> 0 [
						target: instruction/a
						if all [target > 0 target <= fn/instruction-count][
							next-index: index + 1
							displacement: relaxed/target - relaxed/next-index
							if target <= index [displacement: displacement + shrink]
							if x64-encoder/fits-i8? displacement [
								effects/index: effects/index or marker
								changed?: true
							]
						]
					]
				]
				index: index + 1
			]
		]
		index: 1
		while [index <= (fn/instruction-count + 1)][
			offsets/index: relaxed/index
			index: index + 1
		]
		reduction
	]

	merge-target: func [
		target depth [integer!]
		fn [rsir-function!]
		scratch [codegen-scratch!]
		table [type-table!]
		return: [logic!]
		/local
			target-instruction [rsir-instruction!]
			entry-tag stack-tag merged [integer!]
	][
		if any [target <= 0 target > fn/instruction-count][return false]
		target-instruction: as rsir-instruction! (scratch/instructions
			+ ((target - 1) * RSIR_INSTRUCTION_SIZE))
		; A resultless subroutine return discards one optional expression value.
		; Normalize it before joining control-flow edges at that return.
		if all [
			target-instruction/op = OP_SUB_RETURN
			target-instruction/a = 0
			depth = 1
		][
			if scratch/stack-kinds/depth <> VALUE [return false]
			depth: 0
		]
		either scratch/instruction-depths/target >= 0 [
			if scratch/instruction-depths/target <> depth [return false]
			if depth > 0 [
				entry-tag: scratch/entry-tags/target
				stack-tag: scratch/stack-tags/depth
				if entry-tag < 0 [entry-tag: 0]
				if stack-tag < 0 [stack-tag: 0]
				merged: merged-type scratch/entry-types/target
					scratch/stack-types/depth table
				if any [
					merged = 0
					scratch/entry-flags/target <> scratch/stack-flags/depth
					scratch/entry-kinds/target <> scratch/stack-kinds/depth
					entry-tag <> stack-tag
				][return false]
				scratch/entry-types/target: merged
				scratch/entry-tags/target: entry-tag
			]
		][
			scratch/instruction-depths/target: depth
			if depth > 0 [
				scratch/entry-types/target: scratch/stack-types/depth
				scratch/entry-flags/target: scratch/stack-flags/depth
				scratch/entry-kinds/target: scratch/stack-kinds/depth
				stack-tag: scratch/stack-tags/depth
				scratch/entry-tags/target: either stack-tag < 0 [0][stack-tag]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/compare-immediate at (capacity - written)
			x64-encoder/R8 count
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		load-size: x64-encoder/register-load null 0 target x64-encoder/R10 displacement
		if load-size < 0 [return OUTPUT_FULL]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 12 load-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/R8 count-displacement 4 1
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		clear-size: x64-encoder/clear-register null 0 x64-encoder/R8
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 13 clear-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/clear-register at (capacity - written) x64-encoder/R8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R9 x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			01h x64-encoder/RAX x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-store at (capacity - written)
			x64-encoder/RAX count-displacement 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RCX x64-encoder/R8 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RCX -4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		clear-size: x64-encoder/clear-register null 0 x64-encoder/RCX
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 13 clear-size
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/clear-register at (capacity - written) x64-encoder/RCX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RAX 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			29h x64-encoder/RSP x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/and-immediate at (capacity - written)
			x64-encoder/RSP -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R10 x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/R10 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/stack-address at (capacity - written) x64-encoder/RDX 32
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		patch: written + 2
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 14 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		loop-start: written
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/register-load at (capacity - written)
			x64-encoder/RAX x64-encoder/R10 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/register-store at (capacity - written)
			x64-encoder/RAX x64-encoder/RDX 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/R10 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RDX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RCX -1
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/test-register at (capacity - written) x64-encoder/RCX 4
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		displacement: loop-start - (written + 6)
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/jump-condition at (capacity - written) 15 displacement
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if not null? code [
			x64-encoder/write-i32 (code + patch) (written - (patch + 4))
		]

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/R10 x64-encoder/R9 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/R9 4 24
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/RDX 2 8
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: emit-custom-argument at (capacity - written) x64-encoder/RCX 1 0
		if encoded < 0 [return encoded]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX source 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 8 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/and-immediate at (capacity - written)
			x64-encoder/RSP -16
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 4 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RCX x64-encoder/RAX 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/binary-register at (capacity - written)
			29h x64-encoder/RSP x64-encoder/RAX 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		if clear? [
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/R9 x64-encoder/RDI 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RDI x64-encoder/RSP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/clear-register at (capacity - written)
				x64-encoder/RAX
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/repeat-store-quad at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RDI x64-encoder/R9 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/move-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RSP 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/frame-load at (capacity - written)
			x64-encoder/RAX displacement 4 0
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/sign-extend-register at (capacity - written)
			x64-encoder/RAX x64-encoder/RAX
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
		encoded: x64-encoder/shift-immediate at (capacity - written)
			x64-encoder/RAX 4 3 8
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded
		at: either null? code [as byte-ptr! 0][code + written]
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
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/fxrstor-stack at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/register-load at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 512
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RSP x64-encoder/RAX 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/pop-flags at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			register: 15
			while [register >= 0][
				if register <> x64-encoder/RSP [
					at: either null? code [as byte-ptr! 0][code + written]
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
					at: either null? code [as byte-ptr! 0][code + written]
					encoded: x64-encoder/push-register at (capacity - written)
						register
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
				]
				register: register + 1
			]
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/push-flags at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/move-register at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/and-immediate at (capacity - written)
				x64-encoder/RSP -16
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/allocate-frame at (capacity - written) 528
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/fxsave-stack at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either null? code [as byte-ptr! 0][code + written]
			encoded: x64-encoder/register-store at (capacity - written)
				x64-encoder/RAX x64-encoder/RSP 512
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
	]

	keep-incoming-arguments: func [
		available index control-use [integer!]
		instruction [rsir-instruction!]
		return: [integer!]
	][
		if any [
			control-use <> 0
			all [instruction/op = OP_ENTRY index > 1]
			any [
				instruction/op = OP_CALL
				instruction/op = OP_SUB_CALL
				instruction/op = OP_NATIVE
				instruction/op = OP_SET
				instruction/op = OP_MEMBER
				instruction/op = OP_INDEX
				instruction/op = OP_CATCH
				instruction/op = OP_END_CATCH
				instruction/op = OP_THROW
				instruction/op = OP_JUMP
				instruction/op = OP_BRANCH
				instruction/op = OP_SWITCH
				instruction/op = OP_FAIL
			]
			all [
				instruction/op = OP_BINARY
				instruction/a = SHIFT_LEFT_OPERATION
				instruction/b <> 0
			]
		][return 0]
		either any [
			instruction/op = OP_ENTRY
			instruction/op = OP_ADDRESS
			instruction/op = OP_LOAD
		][available][available and 12]
	]

	; Rebases the per-instruction scratch arrays so that index 1 is the first
	; instruction of one function, and copies the shared ones across unchanged.
	; Instruction offsets carry one extra entry per function, for the end of its
	; epilogue, so they have a base of their own.
	window-scratch: func [
		work view [codegen-scratch!]
		first-instruction first-offset [integer!]
		/local base [integer!]
	][
		base: first-instruction - 1
		view/instructions:        work/instructions + (base * RSIR_INSTRUCTION_SIZE)
		view/argument-targets:    work/argument-targets + base
		view/function-sizes:      work/function-sizes
		view/function-frames:     work/function-frames
		view/function-outgoing:   work/function-outgoing
		view/function-effects:    work/function-effects
		view/instruction-effects: work/instruction-effects + base
		view/instruction-offsets: work/instruction-offsets + (first-offset - 1)
		view/relaxed-offsets:     work/relaxed-offsets + (first-offset - 1)
		view/instruction-depths:  work/instruction-depths + base
		view/catch-depths:        work/catch-depths + base
		view/control-uses:        work/control-uses + base
		view/entry-types:         work/entry-types + base
		view/entry-flags:         work/entry-flags + base
		view/entry-kinds:         work/entry-kinds + base
		view/entry-tags:          work/entry-tags + base
		view/tag-next:            work/tag-next + base
		view/tag-slots:           work/tag-slots + base
		view/tag-widths:          work/tag-widths + base
		view/result-offsets:      work/result-offsets + base
		view/stack-types:         work/stack-types
		view/stack-flags:         work/stack-flags
		view/stack-kinds:         work/stack-kinds
		view/stack-tags:          work/stack-tags
		view/storage-offsets:     work/storage-offsets
		view/import-refs:         work/import-refs
		view/switch-effect-links: work/switch-effect-links
		view/switch-effect-users: work/switch-effect-users
		view/effect-queue-tail:   work/effect-queue-tail
		view/resume-queue-tail:   work/resume-queue-tail
	]

	; Initializes the per-function context and creates its scratch window.
	initialize-function-context: func [
		context [x64-function-context!]
		module [rsir-module!]
		work [codegen-scratch!]
		task [codegen-task!]
		return: [integer!]
	][
		window-scratch work context/scratch task/first-instruction task/first-offset
		context/module: module
		context/task: task
		0
	]

	; Validates function structure and records control-flow metadata.
	validate-function-structure: func [
		context [x64-function-context!]
		return: [integer!]
		/local module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			instruction [rsir-instruction!]
			catch-scope [rsir-instruction!]
			sub-entry [rsir-instruction!]
			switch-case [rsir-switch!]
			table [type-table!]
			instructions strings code switches [byte-ptr!]
			instruction-effects instruction-depths catch-depths control-uses storage-offsets [int-ptr!]
			switch-count strings-size [integer!]
			index source-slot register-id case-index catch-unwind [integer!]
			measure? live? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		switches: module/switches
		strings: module/strings
		switch-count: module/switch-count
		strings-size: module/strings-size
		code: task/code
		instructions: view/instructions
		instruction-effects: view/instruction-effects
		instruction-depths: view/instruction-depths
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		storage-offsets: view/storage-offsets

		measure?: null? code
		if measure? [
			index: 1
			while [index <= fn/instruction-count][
				instruction-depths/index: -1
				control-uses/index: 0
				index: index + 1
			]
		]
		state/sub-frame: either measure? [8][
			if task/outgoing-size < 0 [return INVALID_IR]
			if task/outgoing-size > (2147483647 - 23)[return OUTPUT_FULL]
			(align task/outgoing-size 16) + 8
		]
		state/tag-capacity: 0
		state/catch-level: 0
		state/catch-capacity: 0
		state/current-sub: -1
		; RAX still holds the value it wrote into a frame slot until the next
		; emitted byte. A following load of that slot reuses the register.
		state/resident?: false
		state/resident-slot: 0
		state/resident-width: 0
		state/resident-mark: 0
		state/resident-clean?: false
		state/location: LOCATION_NONE
		state/location-depth: 0
		state/location-source: 0
		state/location-reference: 0
		state/source-location: LOCATION_NONE
		state/source-depth: 0
		state/main-entry-count: 0
		state/sub-entry-count: 0
		state/unstable-stack?: false
		state/last-math-operation: 0
		state/flags-condition: -1
		state/pending-immediate-index: -1
		state/pending-immediate-value: 0
		state/pending-immediate-kind: 0
		state/cpu-pointer-ref: 0
		state/storage-count: fn/parameter-count + fn/local-count
		; Before layout, storage offsets also mark which local slots are referenced.
		index: 1
		while [index <= state/storage-count][
			storage-offsets/index: 0
			index: index + 1
		]
		index: 1
		while [index <= fn/instruction-count][
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			live?: (instruction-effects/index and EFFECT_LIVE) <> 0
			catch-depths/index: state/catch-level
			if instruction/op = OP_ENTRY [
				if any [state/catch-level <> 0 state/current-sub >= 0][return INVALID_IR]
				case [
					instruction/a = 0 [
						if any [instruction/b <> 0 instruction/c <> 0][return INVALID_IR]
						state/main-entry-count: state/main-entry-count + 1
						state/current-sub: 0
					]
					instruction/a = 1 [
						unless all [
							any [instruction/b = 0 valid-type-ref? instruction/b table]
							instruction/c = 0
						][return INVALID_IR]
						if all [
							instruction/b <> 0
							not machine-value? instruction/b 0 table
						][return UNSUPPORTED]
						state/sub-entry-count: state/sub-entry-count + 1
						state/current-sub: index
					]
					true [return INVALID_IR]
				]
			]
			if instruction/op = OP_SUB_CALL [
				unless all [
					instruction/a > 0 instruction/a <= fn/instruction-count
					instruction/a <> state/current-sub
				][return INVALID_IR]
				sub-entry: as rsir-instruction! (instructions
					+ ((instruction/a - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					sub-entry/op = OP_ENTRY sub-entry/a = 1
					instruction/b = sub-entry/b instruction/c = 0
				][return INVALID_IR]
			]
			if instruction/op = OP_SUB_RETURN [
				if state/current-sub <= 0 [return INVALID_IR]
				sub-entry: as rsir-instruction! (instructions
					+ ((state/current-sub - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					state/catch-level = 0
					instruction/a = sub-entry/b
					instruction/b = 0 instruction/c = 0
				][return INVALID_IR]
				state/current-sub: -1
			]
			if instruction/op = OP_CATCH [
				catch-unwind: state/catch-level + 1
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
				state/catch-level: state/catch-level + 1
				if live? [
					if state/catch-level > state/catch-capacity [state/catch-capacity: state/catch-level]
				]
			]
			if instruction/op = OP_END_CATCH [
				unless all [
					state/catch-level > 0 instruction/b = state/catch-level instruction/c = 0
					instruction/a > 0 instruction/a < index
				][return INVALID_IR]
				catch-scope: as rsir-instruction! (instructions
					+ ((instruction/a - 1) * RSIR_INSTRUCTION_SIZE))
				unless all [
					catch-scope/op = OP_CATCH catch-scope/a = index
					catch-scope/b = instruction/b
				][return INVALID_IR]
				state/catch-level: state/catch-level - 1
			]
			if all [instruction/op = OP_JUMP any [
				instruction/c < 0 instruction/c > state/catch-level
			]][return INVALID_IR]
			if all [live? instruction/op = OP_MEMBER instruction/b > 0][
				state/tag-capacity: state/tag-capacity + 1
			]
			if all [
				live?
				instruction/op = OP_ADDRESS
				instruction/a = LOCAL_ADDRESS
				instruction/b > fn/parameter-count
				instruction/b <= state/storage-count
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
			][state/unstable-stack?: true]
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
				][state/unstable-stack?: true]
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
			state/catch-level <> 0 state/current-sub > 0
			all [state/sub-entry-count > 0 state/main-entry-count <> 1]
			all [state/sub-entry-count = 0 state/main-entry-count <> 0]
		][return INVALID_IR]
		; A register parameter needs no frame home when its only live reference is
		; one linear load from the still-available ABI register. -1 marks that
		; single candidate; any other or repeated reference restores the home.

		0
	]

	; Identifies parameters that can remain in their incoming ABI registers.
	analyze-function-arguments: func [
		context [x64-function-context!]
		return: [integer!]
		/local module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			instruction [rsir-instruction!]
			next-instruction [rsir-instruction!]
			argument-address [rsir-instruction!]
			parameter [rsir-parameter!]
			table [type-table!]
			instructions parameters [byte-ptr!]
			instruction-effects catch-depths control-uses storage-offsets [int-ptr!]
			index source-slot physical-slot next-index incoming-mask [integer!]
			direct-parameter? live? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		parameters: module/parameters
		instructions: view/instructions
		instruction-effects: view/instruction-effects
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		storage-offsets: view/storage-offsets

		state/hidden-shift: either win64-hidden-return? fn/return-type fn/flags
			table [1][0]
		state/incoming-arguments: 15
		index: 1
		while [index <= fn/instruction-count][
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			live?: (instruction-effects/index and EFFECT_LIVE) <> 0
			if live? [
				state/incoming-arguments: keep-incoming-arguments state/incoming-arguments index
					control-uses/index instruction
				if instruction/op = OP_LOAD [
					direct-parameter?: false
					if index > 1 [
						argument-address: as rsir-instruction! (instructions
							+ ((index - 2) * RSIR_INSTRUCTION_SIZE))
						source-slot: argument-address/b
						direct-parameter?: all [
							argument-address/op = OP_ADDRESS
							argument-address/a = LOCAL_ADDRESS
							source-slot > 0
							source-slot <= fn/parameter-count
							storage-offsets/source-slot = -1
						]
					]
					unless direct-parameter? [
						; Other loads may use the ordinary RAX path. Conservatively
						; release the low incoming slots without replaying locations.
						state/incoming-arguments: state/incoming-arguments and 12
					]
				]
				if all [
					instruction/op = OP_ADDRESS
					instruction/a = LOCAL_ADDRESS
					instruction/b > 0
					instruction/b <= fn/parameter-count
				][
					source-slot: instruction/b
					physical-slot: source-slot + state/hidden-shift
					direct-parameter?: false
					if all [
						physical-slot >= 1 physical-slot <= 4
						index < fn/instruction-count
					][
						parameter: as rsir-parameter! (parameters
							+ ((fn/first-parameter + source-slot - 1)
								* RSIR_PARAMETER_SIZE))
						next-index: index + 1
						next-instruction: as rsir-instruction! (instructions
							+ ((next-index - 1) * RSIR_INSTRUCTION_SIZE))
						incoming-mask: 1 << (physical-slot - 1)
						direct-parameter?: all [
							parameter/flags = 0
							(state/incoming-arguments and incoming-mask) <> 0
							next-instruction/op = OP_LOAD
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							(instruction-effects/next-index and EFFECT_ELIDED) = 0
							control-uses/next-index = 0
							catch-depths/next-index = catch-depths/index
							machine-value? parameter/type 0 table
						]
					]
					either direct-parameter? [
						either storage-offsets/source-slot = 0 [
							storage-offsets/source-slot: -1
						][storage-offsets/source-slot: 1]
					][storage-offsets/source-slot: 1]
				]
			]
			index: index + 1
		]
		index: 1
		while [index <= fn/parameter-count][
			if storage-offsets/index = -1 [storage-offsets/index: 0]
			index: index + 1
		]

		0
	]

	; Plans local storage, result slots, and exception metadata.
	plan-function-frame: func [
		context [x64-function-context!]
		return: [integer!]
		/local module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			table [type-table!]
			storage-offsets [int-ptr!]
			entry? [logic!]
			storage-slots [integer!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		entry?: task/entry?
		storage-offsets: view/storage-offsets

		state/storage-bytes: plan-storage module fn storage-offsets
		if state/storage-bytes < 0 [return state/storage-bytes]
		state/storage-bytes: plan-call-results module fn view state/storage-bytes
		if state/storage-bytes < 0 [return state/storage-bytes]
		state/native-stack-slot: 0
		if state/unstable-stack? [
			if state/storage-bytes > (2147483647 - 8)[return OUTPUT_FULL]
			state/storage-bytes: state/storage-bytes + 8
			state/native-stack-slot: state/storage-bytes / 8
		]
		storage-slots: state/storage-bytes / 8
		state/tag-base: storage-slots
		if storage-slots > (2147483647 - state/tag-capacity)[return OUTPUT_FULL]
		storage-slots: storage-slots + state/tag-capacity
		state/catch-base: storage-slots
		if state/catch-capacity > ((2147483647 - storage-slots) / 3)[return OUTPUT_FULL]
		storage-slots: storage-slots + (state/catch-capacity * 3)
		state/storage-base: storage-slots
		state/segment-slots: 0
		state/tag-count: 0
		state/return-value?: (fn/flags and RETURN_VALUE) <> 0
		either state/return-value? [
			if any [
				fn/return-type = 0
				(aggregate-size fn/return-type table) <= 0
			][return INVALID_IR]
		][
			if all [
				fn/return-type <> 0
				not machine-value? fn/return-type 0 table
			][return UNSUPPORTED]
		]
		state/hidden-return?: win64-hidden-return? fn/return-type fn/flags table
		if all [entry? fn/parameter-count <> 0][return UNSUPPORTED]

		state/storage-slots: storage-slots
		0
	]

	; Emits the function prologue and materializes incoming parameters.
	emit-function-prologue: func [
		context [x64-function-context!]
		return: [integer!]
		/local module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			parameter [rsir-parameter!]
			at [byte-ptr!]
			table [type-table!]
			code parameters [byte-ptr!]
			storage-offsets [int-ptr!]
			capacity [integer!]
			entry? [logic!]
			index width signed source-slot target-slot storage-size storage-align
				encoded written frame-extra physical-slot displacement aggregate-width
				target-offset catch-threshold allocation-size [integer!]
			measure? floating? clear? aggregate-argument? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		parameters: module/parameters
		code: task/code
		capacity: task/capacity
		entry?: task/entry?
		storage-offsets: view/storage-offsets

		measure?: null? code
		state/max-depth: 0
		state/max-outgoing: 0
		state/current-entry: 0
		state/fallthrough?: true
		written: 0
		if entry? [
			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/prolog at (capacity - written) 0 -1
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/allocate-frame at (capacity - written) 32
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			target-offset: x64-encoder/frame-store null 0
				x64-encoder/RAX -16 8
			if target-offset < 0 [return OUTPUT_FULL]
			displacement: target-offset + 5
			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/rip-address at (capacity - written)
				x64-encoder/RAX displacement
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/frame-store at (capacity - written)
				x64-encoder/RAX -16 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded

			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/call-relative at (capacity - written) 2
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/trap at (capacity - written)
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		catch-threshold: either (fn/flags and CATCH_FLAG) <> 0 [-2][0]
		at: either measure? [as byte-ptr! 0][code + written]
		encoded: x64-encoder/prolog at (capacity - written) 0 catch-threshold
		if encoded < 0 [return OUTPUT_FULL]
		written: written + encoded

		allocation-size: 0
		if not measure? [
			frame-extra: task/frame-size - x64-encoder/BASE_FRAME_SIZE
			if frame-extra < 0 [return INVALID_IR]
			at: code + written
			encoded: x64-encoder/allocate-frame at (capacity - written) frame-extra
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
			allocation-size: encoded
		]
		if state/hidden-return? [
			at: either measure? [as byte-ptr! 0][code + written]
			encoded: x64-encoder/frame-store at (capacity - written)
				x64-encoder/RCX (0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]

		state/hidden-shift: either state/hidden-return? [1][0]
		; Incoming Win64 arguments stay available until another operation needs
		; their register class, or an ABI or control boundary invalidates them.
		state/incoming-arguments: 15
		index: 1
		while [index <= fn/parameter-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			aggregate-argument?: parameter/flags = INLINE
			either aggregate-argument? [
				unless aggregate-ref? parameter/type table [return INVALID_IR]
				aggregate-width: win64-aggregate-width parameter/type table
				width: either aggregate-width = 0 [8][aggregate-width]
				signed: 0
				floating?: false
			][
				unless machine-value? parameter/type 0 table [
					return UNSUPPORTED
				]
				width: value-width parameter/type 0 table
				signed: either signed-type? parameter/type table [1][0]
				floating?: float-type? parameter/type table
			]
			target-slot: storage-displacement storage-offsets index
			physical-slot: index + state/hidden-shift
			if all [target-slot <> 0 physical-slot <= 4][
				at: either measure? [as byte-ptr! 0][code + written]
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
		while [index <= state/storage-count][
			parameter: as rsir-parameter! (parameters
				+ ((fn/first-parameter + index - 1) * RSIR_PARAMETER_SIZE))
			if all [storage-offsets/index <> 0 parameter/flags = INLINE][
				unless clear? [
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/clear-register at (capacity - written)
						x64-encoder/RAX
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					clear?: true
				]
				storage-size: 0
				storage-align: 0
				unless layout-type parameter/type true table 0 :storage-size :storage-align [
					return INVALID_IR
				]
				at: either measure? [as byte-ptr! 0][code + written]
				encoded: clear-frame-storage at (capacity - written)
					storage-displacement storage-offsets index storage-size
				if encoded < 0 [return encoded]
				written: written + encoded
			]
			index: index + 1
		]

		state/written: written
		0
	]
	; Verifies the completed control-flow state and records the frame size
	; discovered during the measurement pass.
	finalize-function: func [
		context [x64-function-context!]
		return: [integer!]
		/local task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			instruction-offsets [int-ptr!]
			storage-slots written target-offset slot-bytes frame-extra encoded [integer!]
			measure? [logic!]
	][
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		storage-slots: state/storage-slots
		written: state/written
		measure?: null? task/code
		instruction-offsets: view/instruction-offsets
		if measure? [
			target-offset: fn/instruction-count + 1
			instruction-offsets/target-offset: written
		]
		if state/tag-count <> state/tag-capacity [return INVALID_IR]
		if state/fallthrough? [return INVALID_IR]
		if all [not measure? state/max-outgoing <> task/outgoing-size][return INVALID_IR]

		if measure? [
			task/outgoing-size: state/max-outgoing
			if storage-slots > (2147483647 / 8)[return OUTPUT_FULL]
			slot-bytes: storage-slots * 8
			if state/max-depth > ((2147483647 - slot-bytes) / 8)[return OUTPUT_FULL]
			slot-bytes: slot-bytes + (state/max-depth * 8)
			if slot-bytes > (2147483647 - state/max-outgoing)[return OUTPUT_FULL]
			frame-extra: align (slot-bytes + state/max-outgoing) 16
			if any [
				frame-extra < 0
				frame-extra > (2147483647 - x64-encoder/BASE_FRAME_SIZE)
			][return OUTPUT_FULL]
			task/frame-size: x64-encoder/BASE_FRAME_SIZE + frame-extra
			encoded: x64-encoder/allocate-frame null 0 frame-extra
			if encoded < 0 [return OUTPUT_FULL]
			written: written + encoded
		]
		written
	]

	; Compiles one function of the module and returns its size in bytes, or a
	; negative error code. Each pass follows the same explicit phase pipeline.
	compile-function: func [
		module [rsir-module!]
		work   [codegen-scratch!]
		task   [codegen-task!]
		return: [integer!]
		/local context [x64-function-context! value]
			scratch [codegen-scratch! value]
			state [machine-state! value]
			result [integer!]
	][
		context/scratch: scratch
		context/state: state
		result: initialize-function-context context module work task
		if result < 0 [return result]
		result: validate-function-structure context
		if result < 0 [return result]
		result: analyze-function-arguments context
		if result < 0 [return result]
		result: plan-function-frame context
		if result < 0 [return result]
		result: emit-function-prologue context
		if result < 0 [return result]
		result: emit-function-body context
		if result < 0 [return result]
		finalize-function context
	]


	; Emits literals, addresses, loads, stores, members, and tags.
	emit-value-operation: func [
		context [x64-function-context!]
		instruction [rsir-instruction!]
		index [integer!]
		prepared [x64-instruction-state!]
		return: [integer!]
		/local
			module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			written [integer!]
			next-instruction [rsir-instruction!]
			following-instruction [rsir-instruction!]
			parameter [rsir-parameter!]
			imported [rsir-import!]
			global [rsir-global!]
			image-global [codegen-global!]
			target-function [codegen-function!]
			at [byte-ptr!]
			table [type-table!]
			instructions [byte-ptr!]
			argument-targets [byte-ptr!]
			image-data [byte-ptr!]
			strings [byte-ptr!]
			code [byte-ptr!]
			parameters [byte-ptr!]
			imports [byte-ptr!]
			globals [byte-ptr!]
			instruction-effects [int-ptr!]
			catch-depths [int-ptr!]
			control-uses [int-ptr!]
			tag-next [int-ptr!]
			tag-slots [int-ptr!]
			tag-widths [int-ptr!]
			stack-types [int-ptr!]
			stack-flags [int-ptr!]
			stack-kinds [int-ptr!]
			stack-tags [int-ptr!]
			storage-offsets [int-ptr!]
			import-refs [int-ptr!]
			references [int-ptr!]
			function-count [integer!]
			import-count [integer!]
			global-count [integer!]
			strings-size [integer!]
			function-offset [integer!]
			function-code-size [integer!]
			capacity [integer!]
			depth [integer!]
			ref [integer!]
			flags [integer!]
			width [integer!]
			signed [integer!]
			source-signed [integer!]
			source-slot [integer!]
			target-slot [integer!]
			storage-slots [integer!]
			tag-head [integer!]
			tag-width-value [integer!]
			operation [integer!]
			stride [integer!]
			encoded [integer!]
			physical-slot [integer!]
			target [integer!]
			register-id [integer!]
			import-id [integer!]
			global-id [integer!]
			literal-end [integer!]
			displacement [integer!]
			member-type [integer!]
			member-flags [integer!]
			member-offset [integer!]
			target-width [integer!]
			target-ref [integer!]
			target-flags [integer!]
			copy-size [integer!]
			copy-align [integer!]
			reference-id [integer!]
			target-offset [integer!]
			location [integer!]
			next-index [integer!]
			global-reference-id [integer!]
			incoming-mask [integer!]
			incoming-register [integer!]
			compatibility [integer!]
			measure? [logic!]
			valid? [logic!]
			floating? [logic!]
			aggregate-copy? [logic!]
			tracked? [logic!]
			linear? [logic!]
			global-target? [logic!]
			defer-global? [logic!]
			paired? [logic!]
			set-pair? [logic!]
			address-pair? [logic!]
			load-pair? [logic!]
			direct-store? [logic!]
			spill-next? [logic!]
			imm-pair? [logic!]
			imm-call? [logic!]
			direct-parameter? [logic!]
			forward-argument? [logic!]
			imm-set? [logic!]
			set-fused? [logic!]
			set-next? [logic!]
			scaled-immediate? [logic!]
			source-located? [logic!]
			direct-frame-target? [logic!]
			resident-hit? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		parameters: module/parameters
		imports: module/imports
		globals: module/globals
		strings: module/strings
		function-count: module/function-count
		import-count: module/import-count
		global-count: module/global-count
		strings-size: module/strings-size
		image-data: task/image-data
		code: task/code
		references: task/references
		function-offset: task/function-offset
		function-code-size: task/function-code-size
		capacity: task/capacity
		instructions: view/instructions
		argument-targets: view/argument-targets
		instruction-effects: view/instruction-effects
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		tag-next: view/tag-next
		tag-slots: view/tag-slots
		tag-widths: view/tag-widths
		stack-types: view/stack-types
		stack-flags: view/stack-flags
		stack-kinds: view/stack-kinds
		stack-tags: view/stack-tags
		storage-offsets: view/storage-offsets
		import-refs: view/import-refs
		measure?: null? code
		written: state/written
		depth: state/depth
		location: state/location
		storage-slots: state/storage-slots
		linear?: prepared/linear?
		paired?: prepared/paired?
		set-pair?: prepared/set-pair?
		address-pair?: prepared/address-pair?
		load-pair?: prepared/load-pair?
		next-index: prepared/next-index
		next-instruction: prepared/next-instruction
			case [
				instruction/op = OP_LITERAL [
					ref: instruction/a
					unless all [
						valid-type-ref? ref table
						machine-value? ref 0 table
					][return INVALID_IR]
					depth: depth + 1
					if depth > state/max-depth [state/max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: either (logical-kind ref table) = 10 [
						FLOAT_LITERAL_TAG
					][0]
					width: value-width ref 0 table
					target-width: either width = 8 [8][4]
					floating?: float-type? ref table
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
						(logical-kind ref table) <> 11
						next-instruction/op = OP_ADDRESS
						next-instruction/a = LOCAL_ADDRESS
						next-instruction/b > 0
						next-instruction/b <= state/storage-count
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
						integer-type? ref table
						next-instruction/op = OP_BINARY
						any [
							next-instruction/a = ADD_OPERATION
							next-instruction/a = SUBTRACT_OPERATION
						]
						address-type? stack-types/target-slot table
					][
						scaled-immediate?: scaled-pointer-literal? instruction/b
							stack-types/target-slot table
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
								integer-type? stack-types/target-slot table
								(value-width stack-types/target-slot 0 table) = 4
							]
							all [
								address-type? stack-types/target-slot table
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
						(logical-kind ref table) <> 11
						next-instruction/op = OP_CALL
						next-instruction/b = 1
						(instruction-effects/next-index and EFFECT_LIVE) <> 0
						(instruction-effects/next-index and EFFECT_ELIDED) = 0
					]
					case [
						imm-set? [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-immediate-store at
								(capacity - written)
								storage-displacement storage-offsets next-instruction/b
								instruction/b target-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							state/pending-immediate-index: index
							state/pending-immediate-value: instruction/b
							state/pending-immediate-kind: 2
							location: LOCATION_NONE
							state/location-depth: 0
						]
						imm-pair? [
							state/pending-immediate-index: index
							state/pending-immediate-value: instruction/b
							state/pending-immediate-kind: 1
							; A GPR located below the pending immediate is the left
							; operand: keep it in RAX for the consuming operation.
							unless location = LOCATION_GPR [
								location: LOCATION_NONE
								state/location-depth: 0
							]
						]
						imm-call? [
							state/pending-immediate-index: index
							state/pending-immediate-value: instruction/b
							state/pending-immediate-kind: 3
							location: LOCATION_GPR
							state/location-depth: depth
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
								(logical-kind ref table) <> 11
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
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either direct-store? [
								x64-encoder/frame-immediate-store at (capacity - written)
									slot-displacement (storage-slots + depth)
									instruction/b target-width
							][
								x64-encoder/move-immediate-compact at (capacity - written)
									register-id target-width instruction/b instruction/c
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if all [floating? any [paired? all [linear? not direct-store?]]][
								at: either measure? [as byte-ptr! 0][code + written]
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
									state/location-depth: depth
								]
								all [linear? not direct-store?][
									location: either floating? [LOCATION_XMM][LOCATION_GPR]
									state/location-depth: depth
								]
								true [
									location: LOCATION_NONE
									state/location-depth: 0
									unless direct-store? [
										at: either measure? [as byte-ptr! 0][code + written]
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
						valid-type-ref? ref table
						instruction/b >= 0 instruction/c > 0
						instruction/c <= strings-size
						instruction/b <= (strings-size - instruction/c)
					][return INVALID_IR]
					at: strings + literal-end - 1
					if at/1 <> as byte! 0 [return INVALID_IR]
					if all [measure? literal-end > task/literal-size][
						task/literal-size: literal-end
					]
					depth: depth + 1
					if depth > state/max-depth [state/max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					displacement: 0
					if not measure? [
						displacement: (function-code-size + instruction/b)
							- (function-offset + written + 7)
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/rip-address at (capacity - written)
						x64-encoder/RAX displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					either linear? [
						location: LOCATION_GPR
						state/location-depth: depth
					][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_ADDRESS [
					state/source-location: either any [set-pair? address-pair?][
						location
					][LOCATION_NONE]
					state/source-depth: either state/source-location <> LOCATION_NONE [depth][0]
					ref: 0
					flags: 0
					import-id: 0
					global-id: 0
					defer-global?: false
					physical-slot: as integer! argument-targets/index
					register-id: either physical-slot = 0 [
						x64-encoder/RAX
					][argument-register physical-slot]
					if register-id < 0 [return INVALID_IR]
					case [
						instruction/a = LOCAL_ADDRESS [
							unless all [
								instruction/b > 0
								instruction/b <= state/storage-count
							][return INVALID_IR]
								parameter: as rsir-parameter! (parameters
									+ ((fn/first-parameter + instruction/b - 1)
										* RSIR_PARAMETER_SIZE))
							ref: parameter/type
							flags: parameter/flags
							valid?: all [
								instruction/b <= fn/parameter-count
								parameter/flags = INLINE
								(win64-aggregate-width parameter/type table) = 0
							]
							state/location-source: storage-displacement storage-offsets instruction/b
							physical-slot: instruction/b + state/hidden-shift
							direct-parameter?: false
							if all [physical-slot >= 1 physical-slot <= 4][
								incoming-mask: 1 << (physical-slot - 1)
								direct-parameter?: all [
									instruction/b <= fn/parameter-count
									parameter/flags = 0
									(state/incoming-arguments and incoming-mask) <> 0
									linear?
									next-instruction/op = OP_LOAD
									(instruction-effects/next-index and EFFECT_LIVE) <> 0
									(instruction-effects/next-index and EFFECT_ELIDED) = 0
									machine-value? ref flags table
								]
							]
							if all [state/location-source = 0 not direct-parameter?][return INVALID_IR]
							either direct-parameter? [
								location: LOCATION_ARGUMENT
								state/location-source: physical-slot
								encoded: 0
							][either linear? [
								location: either valid? [
									LOCATION_FRAME_INDIRECT
								][LOCATION_FRAME]
								encoded: 0
							][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: either valid? [
									x64-encoder/frame-load at (capacity - written)
										register-id state/location-source 8 0
								][
									x64-encoder/frame-address at (capacity - written)
										register-id state/location-source
								]
							]]
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
								machine-value? ref flags table
							][
								defer-global?: any [
									next-instruction/op = OP_LOAD
									next-instruction/op = OP_SET
								]
							]
							either defer-global? [
								encoded: 0
							][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/rip-address at (capacity - written)
									register-id 0
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
									valid-type-ref? ref table
									(logical-kind ref table) = -4
								][return INVALID_IR]
							]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/rip-load at (capacity - written)
								register-id 0
						]
						instruction/a = FUNCTION_ADDRESS [
							target: instruction/b
							if any [target <= 0 target > function-count][return INVALID_IR]
							ref: instruction/c
							unless all [
								valid-type-ref? ref table
								(logical-kind ref table) = -4
							][return INVALID_IR]
							displacement: 0
							if not measure? [
								target-function: as codegen-function! (image-data
									+ ((target - 1) * IMAGE_FUNCTION_SIZE))
								displacement: target-function/code-offset
									- (function-offset + written + 7)
							]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/rip-address at (capacity - written)
								register-id displacement
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
								task/global-reference-count = 2147483647
							][return OUTPUT_FULL]
							image-global/reference-count: image-global/reference-count + 1
							task/global-reference-count: task/global-reference-count + 1
						][
							reference-id: image-global/first-reference
								+ image-global/reference-count
							either defer-global? [
								state/location-reference: reference-id
							][
								references/reference-id:
									function-offset + written + encoded - 4
							]
							image-global/reference-count: image-global/reference-count + 1
						]
					]
					written: written + encoded
					depth: depth + 1
					if depth > state/max-depth [state/max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: PLACE
					stack-tags/depth: 0
					either defer-global? [
						location: LOCATION_GLOBAL
						state/location-source: global-id
					][
						if all [linear? location = LOCATION_NONE][
							location: LOCATION_ADDRESS
							state/location-source: 0
						]
					]
					either location <> LOCATION_NONE [
						state/location-depth: depth
					][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						state/location-source: 0
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
						inline-object-ref? ref table
					][
						if tracked? [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: case [
								location = LOCATION_FRAME [
									x64-encoder/frame-address at (capacity - written)
										x64-encoder/RAX state/location-source
								]
								location = LOCATION_FRAME_INDIRECT [
									x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX state/location-source 8 0
								]
								location = LOCATION_GLOBAL [return INVALID_IR]
								location = LOCATION_ADDRESS [
									x64-encoder/add-immediate at (capacity - written)
										x64-encoder/RAX state/location-source
								]
								true [return INVALID_IR]
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
						location: LOCATION_NONE
						state/location-source: 0
						either all [linear? tracked?][
							location: LOCATION_GPR
							state/location-depth: depth
						][
							if tracked? [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX
									slot-displacement (storage-slots + depth) 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
					][
						unless machine-value? ref flags table [
							return UNSUPPORTED
						]
						width: value-width ref flags table
						signed: either signed-type? ref table [1][0]
						floating?: float-type? ref table
						physical-slot: as integer! argument-targets/index
						register-id: either physical-slot = 0 [
							either load-pair? [
								either floating? [x64-encoder/XMM1][x64-encoder/RDX]
							][either floating? [x64-encoder/XMM0][x64-encoder/RAX]]
						][either floating? [
							physical-slot - 1
						][argument-register physical-slot]]
						if register-id < 0 [return INVALID_IR]
						if all [
							load-pair?
								not any [
									location = LOCATION_FRAME
									location = LOCATION_GLOBAL
									location = LOCATION_ARGUMENT
								]
						][return INVALID_IR]
						; A parameter consumed by the next CALL can retain its ABI source
						; until that call fixes the destination argument register.
						forward-argument?: all [
							location = LOCATION_ARGUMENT
							linear?
							next-instruction/op = OP_CALL
							next-instruction/b > 0
							(instruction-effects/next-index and EFFECT_LIVE) <> 0
							(instruction-effects/next-index and EFFECT_ELIDED) = 0
						]
						; The value this local just received is still in RAX, so a
						; load of the same home reuses the register. Only a following
						; CALL retargets a producer register, so it keeps the load.
						resident-hit?: all [
							state/resident?
							written = state/resident-mark
							location = LOCATION_FRAME
							state/location-source = state/resident-slot
							width = state/resident-width
							not floating?
							not load-pair?
							physical-slot = 0
							next-instruction/op <> OP_CALL
						]
						either any [
							forward-argument?
							all [resident-hit? state/resident-clean?]
						][
							encoded: 0
						][
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: case [
								location = LOCATION_FRAME [
									case [
										; Only the low half is known, so this normalizes it.
										resident-hit? [
											x64-encoder/move-register at (capacity - written)
												register-id register-id 4
										]
										floating? [
											x64-encoder/xmm-frame-load at (capacity - written)
												register-id state/location-source width
										]
										true [
											x64-encoder/frame-load at (capacity - written)
												register-id state/location-source width signed
										]
									]
								]
								location = LOCATION_FRAME_INDIRECT [
									x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX state/location-source 8 0
								]
								location = LOCATION_ARGUMENT [
									incoming-register: either floating? [
										state/location-source - 1
									][argument-register state/location-source]
									either floating? [
										either register-id = incoming-register [0][
											x64-encoder/xmm-move-register at (capacity - written)
												register-id incoming-register width
										]
									][
										either width = 8 [
											move-operation-value at (capacity - written)
												register-id incoming-register width 8 signed
										][
											move-operation-value at (capacity - written)
												register-id incoming-register width 4 signed
										]
									]
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
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if global-target? [
							unless measure? [
								reference-id: state/location-reference
								references/reference-id: function-offset + written - 4
							]
						]
						if all [
							not forward-argument?
							location = LOCATION_ARGUMENT
							width < 4
						][
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/extend-narrow-register at
								(capacity - written) register-id register-id width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if location <> LOCATION_ARGUMENT [
							state/incoming-arguments: state/incoming-arguments and 12
						]
					if all [
						not any [
							location = LOCATION_FRAME
							location = LOCATION_ARGUMENT
						]
						not global-target?
					][
							displacement: either location = LOCATION_ADDRESS [
								state/location-source
							][0]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either floating? [
								x64-encoder/xmm-load-indirect at (capacity - written)
									register-id x64-encoder/RAX
									displacement width
							][
								x64-encoder/register-load-indirect at
									(capacity - written) register-id x64-encoder/RAX
									displacement width signed
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						stack-kinds/depth: VALUE
						either forward-argument? [
							state/location-depth: depth
						][
							location: LOCATION_NONE
							state/location-source: 0
							state/location-reference: 0
							either linear? [
								location: either load-pair? [
									either floating? [LOCATION_XMM_PAIR][LOCATION_GPR_PAIR]
								][either floating? [LOCATION_XMM][LOCATION_GPR]]
								state/location-depth: depth
							][
								at: either measure? [as byte-ptr! 0][code + written]
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
					]
					state/source-location: LOCATION_NONE
					state/source-depth: 0
				]
				instruction/op = OP_REFERENCE [
					if any [depth <= 0 stack-kinds/depth <> PLACE][return INVALID_IR]
					unless all [
						instruction/b = 0 instruction/c = 0
						valid-type-ref? instruction/a table
						reference-type? instruction/a table
						machine-value? instruction/a 0 table
					][return INVALID_IR]
					tracked?: location <> LOCATION_NONE
					physical-slot: as integer! argument-targets/index
					register-id: either physical-slot = 0 [
						x64-encoder/RAX
					][argument-register physical-slot]
					if register-id < 0 [return INVALID_IR]
					if tracked? [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: case [
							location = LOCATION_FRAME [
								x64-encoder/frame-address at (capacity - written)
									register-id state/location-source
							]
							location = LOCATION_FRAME_INDIRECT [
								x64-encoder/frame-load at (capacity - written)
									register-id state/location-source 8 0
							]
							location = LOCATION_ADDRESS [
								either register-id = x64-encoder/RAX [
									x64-encoder/add-immediate at (capacity - written)
										x64-encoder/RAX state/location-source
								][
									encoded: x64-encoder/move-register at
										(capacity - written) register-id x64-encoder/RAX 8
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									x64-encoder/add-immediate at (capacity - written)
										register-id state/location-source
								]
							]
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
					state/location-source: 0
					if tracked? [
						either linear? [
							location: LOCATION_GPR
							state/location-depth: depth
						][
							at: either measure? [as byte-ptr! 0][code + written]
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
					unless pointee-type ref table :member-type [return INVALID_IR]
					stride: pointer-stride ref table
					if stride <= 0 [return UNSUPPORTED]
					if instruction/b = 1 [
						if any [
							depth < 2 stack-kinds/depth <> VALUE
							stack-flags/depth <> 0
							(logical-kind stack-types/depth table) <> 5
						][return INVALID_IR]
					]

					if any [
						instruction/b = 1 instruction/a <> 0 instruction/c <> 0
					][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + target-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded

						at: either measure? [as byte-ptr! 0][code + written]
						encoded: either instruction/b = 1 [
							source-signed: either signed-type? stack-types/depth table [1][0]
							load-operation-value at (capacity - written)
								x64-encoder/RDX slot-displacement (storage-slots + depth)
								(value-width stack-types/depth 0 table) 8 source-signed
						][
							x64-encoder/move-immediate-compact at (capacity - written)
								x64-encoder/RDX 8 instruction/a instruction/c
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded

						if instruction/b = 1 [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/add-immediate at (capacity - written)
								x64-encoder/RDX -1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if stride <> 1 [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/multiply-immediate at (capacity - written)
								x64-encoder/RDX x64-encoder/RDX stride 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							01h x64-encoder/RAX x64-encoder/RDX 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
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
					source-located?: state/source-location <> LOCATION_NONE
					global-target?: location = LOCATION_GLOBAL
					direct-frame-target?: all [
						source-located?
						location = LOCATION_FRAME
					]
					target-offset: state/location-source
					global-reference-id: state/location-reference
					target-ref: stack-types/target-slot
					target-flags: stack-flags/target-slot
					tag-head: stack-tags/target-slot
					ref: stack-types/source-slot
					flags: stack-flags/source-slot
					aggregate-copy?: all [
						target-flags = INLINE flags = 0
						aggregate-ref? target-ref table
						aggregate-ref? ref table
						compatible-types? target-ref ref table
					]
					either aggregate-copy? [
						copy-size: 0
						copy-align: 0
						unless layout-type target-ref true table 0 :copy-size :copy-align [
							return INVALID_IR
						]
					][
						compatibility: implicitly-compatible-types target-ref ref
							stack-tags/source-slot false table
						if compatibility < 0 [return compatibility]
						unless all [
							compatibility = 1
							target-flags = flags
							machine-value? ref flags table
							machine-value? target-ref target-flags table
						][
							return INVALID_IR
						]
						target-width: value-width target-ref target-flags table
						floating?: float-type? target-ref table
						source-signed: either signed-type? ref table [1][0]
					]

					; The literal two instructions back already stored its
					; immediate straight into the local slot.
					set-fused?: all [
						state/pending-immediate-kind = 2
						state/pending-immediate-index = (index - 2)
						not aggregate-copy?
						not floating?
					]
					unless set-fused? [
						displacement: either location = LOCATION_ADDRESS [state/location-source][0]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: case [
						location = LOCATION_FRAME [
							either source-located? [0][
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RDX state/location-source
							]
						]
						location = LOCATION_FRAME_INDIRECT [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX state/location-source 8 0
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
					if all [aggregate-copy? displacement <> 0][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/add-immediate at (capacity - written)
							x64-encoder/RDX displacement
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						displacement: 0
					]
					location: LOCATION_NONE
					state/location-depth: 0
					state/location-source: 0
					state/location-reference: 0

					either aggregate-copy? [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RCX slot-displacement
								(storage-slots + source-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
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
								state/source-location = LOCATION_XMM
							][state/source-location = LOCATION_GPR]
							unless valid? [return INVALID_IR]
						]
						unless source-located? [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either floating? [
								x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
										(storage-slots + source-slot) target-width
							][
								load-operation-value at (capacity - written)
									x64-encoder/RAX slot-displacement
									(storage-slots + source-slot)
									(value-width ref flags table) target-width source-signed
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						at: either measure? [as byte-ptr! 0][code + written]
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
										x64-encoder/RDX x64-encoder/XMM0
										displacement target-width
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
									x64-encoder/register-store-indirect at
										(capacity - written) x64-encoder/RDX
										x64-encoder/RAX displacement target-width
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
							at: either measure? [as byte-ptr! 0][code + written]
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
						state/pending-immediate-index: -1
						state/pending-immediate-kind: 0
						location: LOCATION_NONE
						state/location-depth: 0
						state/location-source: 0
						state/location-reference: 0
						depth: source-slot
						stack-types/depth: target-ref
						stack-flags/depth: target-flags
						stack-kinds/depth: VALUE
					]
					state/source-location: LOCATION_NONE
					state/source-depth: 0
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: emit-variant-tags at (capacity - written) tag-head state fn view
					if encoded < 0 [return encoded]
					written: written + encoded
					stack-tags/depth: 0
					if all [
						not aggregate-copy?
						not set-fused?
						not floating?
						direct-frame-target?
						tag-head = 0
						any [target-width = 4 target-width = 8]
					][
						state/resident?: true
						state/resident-slot: target-offset
						state/resident-width: target-width
						state/resident-clean?: any [target-width = 8 not source-located?]
						state/resident-mark: written
					]
					if all [not aggregate-copy? not set-fused? linear? tag-head = 0][
						location: either floating? [LOCATION_XMM][LOCATION_GPR]
						state/location-depth: depth
					]
				]
				instruction/op = OP_MEMBER [
					if any [depth <= 0 instruction/c <> 0][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					unless any [
						stack-kinds/depth = PLACE
						all [stack-kinds/depth = VALUE flags = 0 aggregate-ref? ref table]
					][return INVALID_IR]
					member-type: 0
					member-flags: 0
					member-offset: 0
					unless layout-member ref instruction/a table
						:member-type :member-flags :member-offset [return INVALID_IR]
					tag-width-value: 0
					if instruction/b <> 0 [
						unless all [
							instruction/b = (instruction/a + 1)
							tagged-union? ref table
						][return INVALID_IR]
						tag-width-value: union-tag-width ref table
						if tag-width-value = 0 [return INVALID_IR]
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: case [
						location = LOCATION_FRAME [
							either instruction/b <> 0 [
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RAX state/location-source
							][0]
						]
						location = LOCATION_FRAME_INDIRECT [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX state/location-source 8 0
						]
						location = LOCATION_ADDRESS [
							either instruction/b <> 0 [
								x64-encoder/add-immediate at (capacity - written)
									x64-encoder/RAX state/location-source
							][0]
						]
						location = LOCATION_GPR [0]
						location = LOCATION_NONE [
							x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX
								slot-displacement (storage-slots + depth) 8 0
						]
						true [return INVALID_IR]
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					case [
						location = LOCATION_FRAME [
							if instruction/b <> 0 [
								location: LOCATION_ADDRESS
								state/location-source: 0
							]
						]
						location = LOCATION_ADDRESS [
							if instruction/b <> 0 [state/location-source: 0]
						]
						any [
							location = LOCATION_FRAME_INDIRECT
							location = LOCATION_GPR
							location = LOCATION_NONE
						][
							location: LOCATION_ADDRESS
							state/location-source: 0
						]
						true [0]
					]
					if instruction/b <> 0 [
						state/tag-count: state/tag-count + 1
						if state/tag-count > state/tag-capacity [return INVALID_IR]
						either measure? [
							tag-next/index: stack-tags/depth
							tag-slots/index: state/tag-count
							tag-widths/index: tag-width-value
						][unless all [
							tag-next/index = stack-tags/depth
							tag-slots/index = state/tag-count
							tag-widths/index = tag-width-value
						][return INVALID_IR]]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (state/tag-base + state/tag-count) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						stack-tags/depth: index
					]
					if state/location-source > (2147483647 - member-offset)[return OUTPUT_FULL]
					state/location-source: state/location-source + member-offset
					stack-types/depth: member-type
					stack-flags/depth: member-flags
					stack-kinds/depth: PLACE
					either linear? [
						state/location-depth: depth
					][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: case [
							location = LOCATION_FRAME [
								x64-encoder/frame-address at (capacity - written)
									x64-encoder/RAX state/location-source
							]
							location = LOCATION_ADDRESS [
								x64-encoder/add-immediate at (capacity - written)
									x64-encoder/RAX state/location-source
							]
							true [return INVALID_IR]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth) 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						location: LOCATION_NONE
						state/location-source: 0
					]
				]
				instruction/op = OP_TAG [
					if any [
						instruction/a <> 0 instruction/b <> 0 instruction/c <> 0
						depth <= 0 stack-kinds/depth <> VALUE
						stack-flags/depth <> 0
					][return INVALID_IR]
					width: union-tag-width stack-types/depth table
					if width = 0 [return INVALID_IR]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/load-indirect at (capacity - written) width 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/frame-store at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
				]
			true [return UNSUPPORTED]
		]
		state/written: written
		state/depth: depth
		state/location: location
		state/storage-slots: storage-slots
		0
	]

	; Emits direct, indirect, imported, custom, and typed calls.
	emit-call-operation: func [
		context [x64-function-context!]
		instruction [rsir-instruction!]
		index [integer!]
		prepared [x64-instruction-state!]
		return: [integer!]
		/local
			module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			written [integer!]
			following-instruction [rsir-instruction!]
			argument-instruction [rsir-instruction!]
			argument-address [rsir-instruction!]
			parameter [rsir-parameter!]
			callee [rsir-function!]
			imported [rsir-import!]
			signature [rsir-type!]
			typed-metadata [rsir-type!]
			list-type [rsir-type!]
			typed-member [rsir-member!]
			target-function [codegen-function!]
			at [byte-ptr!]
			call-parameters [byte-ptr!]
			table [type-table!]
			instructions [byte-ptr!]
			argument-targets [byte-ptr!]
			image-data [byte-ptr!]
			code [byte-ptr!]
			parameters [byte-ptr!]
			functions [byte-ptr!]
			imports [byte-ptr!]
			function-effects [int-ptr!]
			instruction-offsets [int-ptr!]
			result-offsets [int-ptr!]
			stack-types [int-ptr!]
			stack-flags [int-ptr!]
			stack-kinds [int-ptr!]
			stack-tags [int-ptr!]
			import-refs [int-ptr!]
			references [int-ptr!]
			function-count [integer!]
			import-count [integer!]
			function-offset [integer!]
			capacity [integer!]
			depth [integer!]
			kind [integer!]
			ref [integer!]
			flags [integer!]
			width [integer!]
			signed [integer!]
			source-signed [integer!]
			source-slot [integer!]
			target-slot [integer!]
			storage-slots [integer!]
			encoded [integer!]
			outgoing [integer!]
			outgoing-end [integer!]
			argument-index [integer!]
			argument-base [integer!]
			callee-slot [integer!]
			argument-slot [integer!]
			argument-width [integer!]
			physical-slot [integer!]
			target [integer!]
			return-ref [integer!]
			first-parameter [integer!]
			register-id [integer!]
			parameter-count [integer!]
			call-flags [integer!]
			import-id [integer!]
			displacement [integer!]
			source-width [integer!]
			target-width [integer!]
			target-ref [integer!]
			target-flags [integer!]
			result-index [integer!]
			reference-id [integer!]
			aggregate-width [integer!]
			value-size [integer!]
			result-offset [integer!]
			temp-offset [integer!]
			physical-count [integer!]
			call-mode [integer!]
			list-size [integer!]
			list-capacity [integer!]
			signature-ref [integer!]
			record-offset [integer!]
			location [integer!]
			incoming-register [integer!]
			compatibility [integer!]
			argument-producer [integer!]
			measure? [logic!]
			floating? [logic!]
			aggregate-copy? [logic!]
			aggregate-argument? [logic!]
			indirect? [logic!]
			packed-call? [logic!]
			typed-call? [logic!]
			custom-call? [logic!]
			list-call? [logic!]
			tracked? [logic!]
			located? [logic!]
			linear? [logic!]
			imm-call? [logic!]
			direct-argument? [logic!]
			forward-argument? [logic!]
			immediate? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		parameters: module/parameters
		functions: module/functions
		imports: module/imports
		function-count: module/function-count
		import-count: module/import-count
		image-data: task/image-data
		code: task/code
		references: task/references
		function-offset: task/function-offset
		capacity: task/capacity
		instructions: view/instructions
		function-effects: view/function-effects
		instruction-offsets: view/instruction-offsets
		argument-targets: view/argument-targets
		stack-types: view/stack-types
		stack-flags: view/stack-flags
		stack-kinds: view/stack-kinds
		stack-tags: view/stack-tags
		result-offsets: view/result-offsets
		import-refs: view/import-refs
		measure?: null? code
		written: state/written
		depth: state/depth
		location: state/location
		storage-slots: state/storage-slots
		linear?: prepared/linear?

		case [
				instruction/op = OP_CALL [
					target: instruction/a
					argument-index: instruction/b
					indirect?: target = 0
					signature-ref: instruction/c
					typed-call?: all [
						signature-ref > 0
						(logical-kind signature-ref table) = -8
					]
					if typed-call? [
						target-ref: canonical-type signature-ref table
						if target-ref <= 0 [return INVALID_IR]
						typed-metadata: as rsir-type! (table/types
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
							not valid-type-ref? signature-ref table
							(logical-kind signature-ref table) <> -4
						][return INVALID_IR]
						signature: as rsir-type! (table/types
							+ (((canonical-type signature-ref table) - 1)
								* RSIR_TYPE_SIZE))
						return-ref: signature/target
						first-parameter: signature/first-member
						parameter-count: signature/member-count
						call-flags: signature/flags
						call-parameters: table/members
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
								(logical-kind parameter/type table) = 5][
								return INVALID_IR
							]
							parameter: as rsir-parameter! (call-parameters
								+ ((first-parameter + 1) * RSIR_PARAMETER_SIZE))
							unless all [parameter/flags = 0
								address-kind? (logical-kind parameter/type table)][
								return INVALID_IR
							]
							if parameter-count = 3 [
								parameter: as rsir-parameter! (call-parameters
									+ ((first-parameter + 2) * RSIR_PARAMETER_SIZE))
								unless all [parameter/flags = 0
									(logical-kind parameter/type table) = 5][
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
							(logical-kind parameter/type table) = 5
						][return INVALID_IR]
						parameter: as rsir-parameter! (call-parameters
							+ ((first-parameter + 1) * RSIR_PARAMETER_SIZE))
						target-ref: 0
						unless all [
							parameter/flags = 0
							pointee-type parameter/type table :target-ref
						][return INVALID_IR]
						target-ref: canonical-type target-ref table
						if target-ref <= 0 [return INVALID_IR]
						list-type: as rsir-type! (table/types
							+ ((target-ref - 1) * RSIR_TYPE_SIZE))
						unless all [
							list-type/kind = -2
							any [
								list-type/member-count = 3
								list-type/member-count = 4
								list-type/member-count = 5
							]
							(aggregate-size target-ref table) = 24
						][return INVALID_IR]
						typed-member: as rsir-member! (table/members
							+ (list-type/first-member * RSIR_MEMBER_SIZE))
						unless all [
							typed-member/flags = 0
							(logical-kind typed-member/type table) = 5
						][return INVALID_IR]
						if list-type/member-count >= 4 [
							typed-member: as rsir-member! (table/members
								+ ((list-type/first-member + 1) * RSIR_MEMBER_SIZE))
							unless all [
								typed-member/flags = 0
								(logical-kind typed-member/type table) = 5
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
								(logical-kind stack-types/depth table) = 5
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
					state/return-value?: (call-flags and RETURN_VALUE) <> 0
					if state/return-value? [
						unless all [
							return-ref <> 0
							aggregate-ref? return-ref table
							(aggregate-size return-ref table) > 0
						][return INVALID_IR]
					]
					state/hidden-return?: win64-hidden-return? return-ref call-flags table
					if all [custom-call? state/hidden-return?][return UNSUPPORTED]
					state/hidden-shift: either state/hidden-return? [1][0]
					physical-count: case [
						custom-call? [0]
						typed-call? [2]
						packed-call? [3]
						true [argument-index]
					]
					if physical-count > (2147483647 - state/hidden-shift)[return OUTPUT_FULL]
					physical-count: physical-count + state/hidden-shift
					if physical-count > (((2147483647 - 32) / 8) + 4)[
						return OUTPUT_FULL
					]
					outgoing: either custom-call? [0][32]
					if physical-count > 4 [
						outgoing: outgoing + ((physical-count - 4) * 8)
					]
					if outgoing > state/max-outgoing [state/max-outgoing: outgoing]
					either indirect? [
						callee-slot: depth - argument-index
						if any [
							callee-slot <= 0
							stack-kinds/callee-slot <> VALUE
							stack-flags/callee-slot <> 0
							not compatible-types? signature-ref stack-types/callee-slot
								table
						][return INVALID_IR]
						argument-base: callee-slot
						result-index: callee-slot - 1
					][
						argument-base: depth - argument-index
						result-index: argument-base
					]
					imm-call?: all [
						state/pending-immediate-kind = 3
						state/pending-immediate-index = (index - 1)
						argument-index = 1
						location = LOCATION_GPR
						state/location-depth = depth
					]
					if imm-call? [
						following-instruction: as rsir-instruction! (instructions
							+ ((state/pending-immediate-index - 1) * RSIR_INSTRUCTION_SIZE))
					]
					immediate?: all [imm-call? not custom-call? not list-call?]
					if all [imm-call? not immediate?][
						ref: stack-types/depth
						width: value-width ref 0 table
						if width <= 0 [return INVALID_IR]
						target-width: either width = 8 [8][4]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
							x64-encoder/RAX target-width following-instruction/b
							following-instruction/c
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						state/pending-immediate-index: -1
						state/pending-immediate-kind: 0
					]
					argument-producer: 0
					forward-argument?: location = LOCATION_ARGUMENT
					direct-argument?: false
					if all [
						index > 1
						argument-index > 0
						argument-index <= parameter-count
						any [
							location = LOCATION_GPR
							location = LOCATION_XMM
							location = LOCATION_ARGUMENT
						]
						state/location-depth = depth
					][
						argument-instruction: as rsir-instruction! (instructions
							+ ((index - 2) * RSIR_INSTRUCTION_SIZE))
						if argument-instruction/op = OP_LOAD [
							argument-producer: index - 1
						]
						if all [
							argument-producer = 0
							index > 2
							location = LOCATION_GPR
							argument-instruction/op = OP_REFERENCE
						][
							argument-address: as rsir-instruction! (instructions
								+ ((index - 3) * RSIR_INSTRUCTION_SIZE))
							if argument-address/op = OP_ADDRESS [
							argument-producer: either argument-address/a = LOCAL_ADDRESS [
								index - 1
							][index - 2]
							]
						]
					]
					located?: location <> LOCATION_NONE
					if located? [
						ref: stack-types/depth
						flags: stack-flags/depth
						floating?: float-type? ref table
						unless all [
							argument-index > 0
							state/location-depth = depth
							stack-kinds/depth = VALUE
							any [
								all [
									floating?
									any [
										location = LOCATION_XMM
										location = LOCATION_ARGUMENT
									]
								]
								all [
									not floating?
									any [
										location = LOCATION_GPR
										location = LOCATION_ARGUMENT
									]
								]
							]
						][return INVALID_IR]
						direct-argument?: all [
							argument-producer > 0
							not inline-object-ref? stack-types/depth table
							not aggregate-ref? stack-types/depth table
							not custom-call?
							not list-call?
							; A register-resident last argument keeps its producer's
							; value out of frame homes only when the ABI slot is a
							; dedicated argument register. Stack-bound values stay on
							; the materialized path where RAX remains shared scratch.
							(argument-index + state/hidden-shift) <= 4
							; CALL fills target slots from left to right. An incoming
							; argument in an earlier slot must first use the regular
							; RAX/XMM0 materialized path, or that earlier target would
							; overwrite it before the final argument is emitted.
							any [
								not forward-argument?
								state/location-source >= (argument-index + state/hidden-shift)
							]
						]
						if all [forward-argument? not direct-argument?][
							width: value-width ref flags table
							if width <= 0 [return INVALID_IR]
							incoming-register: either floating? [
								state/location-source - 1
							][argument-register state/location-source]
							register-id: either floating? [x64-encoder/XMM0][x64-encoder/RAX]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either floating? [
								either register-id = incoming-register [0][
									x64-encoder/xmm-move-register at (capacity - written)
										register-id incoming-register width
								]
							][
								signed: either signed-type? ref table [1][0]
								target-width: either width = 8 [8][4]
								move-operation-value at (capacity - written)
									register-id incoming-register width target-width signed
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if all [not floating? width < 4][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/extend-narrow-register at
									(capacity - written) register-id register-id width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							location: either floating? [LOCATION_XMM][LOCATION_GPR]
							state/location-source: register-id
							forward-argument?: false
						]
						unless forward-argument? [
							state/location-source: either floating? [
								x64-encoder/XMM0
							][x64-encoder/RAX]
						]
						if all [
							not direct-argument?
							any [
							typed-call?
							custom-call?
							aggregate-ref? ref table
							]
						][
							width: either inline-object-ref? ref table [8][
								value-width ref flags table
							]
							if width <= 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
							state/location-depth: 0
							state/location-source: 0
							located?: false
						]
					]
					if all [located? not immediate? not direct-argument?][
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
									state/unstable-stack?
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
							width: value-width ref flags table
							if width <= 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
							state/location-source: either floating? [
								x64-encoder/XMM4
							][x64-encoder/R11]
						]
					]
					temp-offset: align outgoing 16
					if temp-offset < 0 [return OUTPUT_FULL]
					if all [state/unstable-stack? not custom-call?][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-register at (capacity - written)
							x64-encoder/RAX x64-encoder/RSP 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement state/native-stack-slot 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						value-size: 0
						if not measure? [value-size: task/frame-size]
						at: either measure? [as byte-ptr! 0][code + written]
						; The frame size is known only while emitting, so this
						; immediate must keep one value-independent encoding.
						encoded: x64-encoder/move-immediate at (capacity - written)
							x64-encoder/RAX 8 value-size 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							29h x64-encoder/RSP x64-encoder/RAX 8
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
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
									aggregate-ref? ref table
									compatible-types? parameter/type ref table
								][return INVALID_IR]
							][
								compatibility: implicitly-compatible-types parameter/type ref
									stack-tags/argument-slot true table
								if compatibility < 0 [return compatibility]
								unless all [
									compatibility = 1
									parameter/flags = flags
								][return INVALID_IR]
								unless machine-value? ref flags table [
									return UNSUPPORTED
								]
							]
						][
							unless machine-value? ref flags table [
								return UNSUPPORTED
							]
						]
						if aggregate-argument? [
							aggregate-width: win64-aggregate-width parameter/type table
							if aggregate-width = 0 [
								value-size: aggregate-size parameter/type table
								if any [
									value-size <= 0
									temp-offset > (2147483647 - value-size)
								][return OUTPUT_FULL]
								outgoing-end: temp-offset + value-size
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RCX slot-displacement
										(storage-slots + argument-slot) 8 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/stack-address at (capacity - written)
									x64-encoder/RDX temp-offset
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/copy-indirect at
									(capacity - written) value-size
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if outgoing-end > state/max-outgoing [state/max-outgoing: outgoing-end]
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
						if outgoing-end > state/max-outgoing [state/max-outgoing: outgoing-end]
						source-slot: 1
						while [source-slot <= argument-index][
							argument-slot: argument-base + source-slot
							ref: stack-types/argument-slot
							flags: stack-flags/argument-slot
							unless all [
								stack-kinds/argument-slot = VALUE
								flags = 0
								machine-value? ref flags table
							][return INVALID_IR]
							width: value-width ref flags table
							if width <= 0 [return UNSUPPORTED]
							signed: either signed-type? ref table [1][0]
							tracked?: all [located? argument-slot = state/location-depth]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either tracked? [
								either location = LOCATION_XMM [
									x64-encoder/xmm-store-register at (capacity - written)
										x64-encoder/RAX state/location-source width
								][
									target-width: either width = 8 [8][4]
									either state/location-source = x64-encoder/RAX [0][
										x64-encoder/move-register at (capacity - written)
											x64-encoder/RAX state/location-source target-width
									]
								]
							][
								x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + argument-slot) width signed
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/outgoing-store at (capacity - written)
								(temp-offset + ((source-slot - 1) * 8)) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							source-slot: source-slot + 1
						]
						target-slot: argument-register (state/hidden-shift + 1)
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
							target-slot 4 argument-index 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						target-slot: argument-register (state/hidden-shift + 2)
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/stack-address at (capacity - written)
							target-slot temp-offset
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						target-slot: argument-register (state/hidden-shift + 3)
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
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
						if outgoing-end > state/max-outgoing [state/max-outgoing: outgoing-end]
						source-slot: 1
						while [source-slot <= argument-index][
							argument-slot: argument-base + source-slot
							ref: stack-types/argument-slot
							flags: stack-flags/argument-slot
							typed-member: as rsir-member! (table/members
								+ ((typed-metadata/first-member + source-slot - 1)
									* RSIR_MEMBER_SIZE))
							unless all [
								stack-kinds/argument-slot = VALUE
								flags = 0
								compatible-types? typed-member/type ref table
								machine-value? ref flags table
								typed-runtime-id? typed-member/flags
							][return INVALID_IR]
							width: value-width ref flags table
							if width <= 0 [return UNSUPPORTED]
							record-offset: temp-offset + ((source-slot - 1) * 24)
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/outgoing-immediate-store
								at (capacity - written) record-offset typed-member/flags
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/outgoing-immediate-store
								at (capacity - written) (record-offset + 4) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							floating?: float-type? ref table
							either floating? [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
									(storage-slots + argument-slot) width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/xmm-outgoing-store at
									(capacity - written) x64-encoder/XMM0
									(record-offset + 8) width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if width = 4 [
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/outgoing-immediate-store at
										(capacity - written) (record-offset + 12) 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							][
								signed: either signed-type? ref table [1][0]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
									(storage-slots + argument-slot) width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/outgoing-store at
									(capacity - written) (record-offset + 8) 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							kind: logical-kind ref table
							either any [kind = 7 kind = 8][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX
									((slot-displacement (storage-slots + argument-slot)) + 4)
									4 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/outgoing-store at
									(capacity - written) (record-offset + 16) 4
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/outgoing-immediate-store at
									(capacity - written) (record-offset + 16) 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/outgoing-immediate-store at
								(capacity - written) (record-offset + 20) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							source-slot: source-slot + 1
						]
						target-slot: argument-register (state/hidden-shift + 1)
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
							target-slot 4 argument-index 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						target-slot: argument-register (state/hidden-shift + 2)
						at: either measure? [as byte-ptr! 0][code + written]
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
								aggregate-width: win64-aggregate-width parameter/type table
							]
						]
						if all [
							source-slot > parameter-count
							call-mode = VARIADIC
							(call-flags and CDECL) <> 0
							(call-flags and OBJC) = 0
							(logical-kind ref table) = 9
						][
							target-ref: -10
							target-flags: 0
						]
						physical-slot: source-slot + state/hidden-shift
						; Win64 stack arguments always occupy complete 8-byte slots.
						either aggregate-argument? [
							either aggregate-width = 0 [
								value-size: aggregate-size parameter/type table
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/stack-address at (capacity - written)
									x64-encoder/RAX temp-offset
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								argument-width: 8
							][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + argument-slot) 8 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/load-indirect at
									(capacity - written) aggregate-width 0
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								argument-width: aggregate-width
							]
							target-width: either argument-width = 8 [8][4]
							either physical-slot <= 4 [
								target-slot: argument-register physical-slot
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									target-slot x64-encoder/RAX target-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							][
								at: either measure? [as byte-ptr! 0][code + written]
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
							source-width: value-width ref flags table
							source-signed: either signed-type? ref table [1][0]
							argument-width: value-width target-ref target-flags table
							floating?: float-type? target-ref table
							tracked?: all [located? argument-slot = state/location-depth]
							target-width: either argument-width = 8 [8][4]
								either physical-slot <= 4 [
									target-slot: argument-register physical-slot
									; Only the located stack-top argument owns the
									; recorded producer target; earlier slots keep
									; their own register assignments.
									if all [direct-argument? tracked?] [
										either forward-argument? [
											state/location-source: either floating? [
												state/location-source - 1
											][argument-register state/location-source]
											if state/location-source < 0 [return INVALID_IR]
										][
											either measure? [
												argument-targets/argument-producer:
													as byte! physical-slot
												; A narrow R8/R9 producer adds one REX byte after
												; its RAX measurement. Advance this CALL and all
												; following offsets without measuring the function again.
												if all [
													not floating?
													physical-slot >= 3
													source-width < 8
												][
													instruction-offsets/index: instruction-offsets/index + 1
													written: written + 1
												]
											][
												if argument-targets/argument-producer <>
													as byte! physical-slot [
													return INVALID_IR
												]
											]
											state/location-source: either floating? [
												physical-slot - 1
											][target-slot]
										]
									]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: either floating? [
									either tracked? [
										either source-width = argument-width [
											either (physical-slot - 1) = state/location-source [0][
												x64-encoder/xmm-move-register at
													(capacity - written) (physical-slot - 1)
													state/location-source source-width
											]
										][
											x64-encoder/xmm-convert at (capacity - written)
												(physical-slot - 1) state/location-source
												source-width argument-width
										]
									][
										x64-encoder/xmm-frame-load at (capacity - written)
											(physical-slot - 1) slot-displacement
												(storage-slots + argument-slot) source-width
									]
								][
									case [
										immediate? [
										x64-encoder/move-immediate-compact at (capacity - written)
												target-slot target-width following-instruction/b
												following-instruction/c
										]
										tracked? [
											move-operation-value at (capacity - written)
												target-slot state/location-source source-width
												target-width source-signed
										]
										true [
											load-operation-value at (capacity - written)
												target-slot slot-displacement
												(storage-slots + argument-slot)
												(value-width ref flags table) argument-width source-signed
										]
									]
								]
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								if all [
									direct-argument?
									tracked?
									forward-argument?
									not floating?
									source-width < 4
								][
									signed: either signed-type? ref table [1][0]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/extend-narrow-register at
										(capacity - written) target-slot target-slot source-width signed
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
								if all [
									floating? not tracked? source-width <> argument-width
								][
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/xmm-convert at
										(capacity - written) (physical-slot - 1)
										(physical-slot - 1) source-width argument-width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
								if all [floating? (call-flags and VARIADIC) <> 0][
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/xmm-store-register at
										(capacity - written) target-slot
										(physical-slot - 1) argument-width
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
								]
							][
								either tracked? [
									either floating? [
										register-id: state/location-source
										if source-width <> argument-width [
											at: either measure? [as byte-ptr! 0][code + written]
											encoded: x64-encoder/xmm-convert at
												(capacity - written) x64-encoder/XMM0
												state/location-source source-width argument-width
											if encoded < 0 [return OUTPUT_FULL]
											written: written + encoded
											register-id: x64-encoder/XMM0
										]
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-outgoing-store at
											(capacity - written) register-id
											(32 + ((physical-slot - 5) * 8)) argument-width
									][
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: move-operation-value at (capacity - written)
											x64-encoder/RAX state/location-source source-width
											target-width source-signed
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/outgoing-store at
											(capacity - written)
											(32 + ((physical-slot - 5) * 8)) 8
									]
								][
									either all [floating? source-width <> argument-width][
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + argument-slot)
											source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-convert at
											(capacity - written) x64-encoder/XMM0
											x64-encoder/XMM0 source-width argument-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-outgoing-store at
											(capacity - written) x64-encoder/XMM0
											(32 + ((physical-slot - 5) * 8)) argument-width
									][
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: load-operation-value at (capacity - written)
											x64-encoder/RAX slot-displacement
											(storage-slots + argument-slot)
											(value-width ref flags table) argument-width source-signed
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
										at: either measure? [as byte-ptr! 0][code + written]
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
						state/pending-immediate-index: -1
						state/pending-immediate-kind: 0
					]
					location: LOCATION_NONE
					state/location-depth: 0
					state/location-source: 0
					if state/hidden-return? [
						result-offset: result-offsets/index
						if result-offset >= 0 [return INVALID_IR]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-address at (capacity - written)
							x64-encoder/RCX result-offset
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if indirect? [
						target-slot: either custom-call? [
							x64-encoder/R11
						][x64-encoder/RAX]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							target-slot slot-displacement
								(storage-slots + callee-slot) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if custom-call? [
						at: either measure? [as byte-ptr! 0][code + written]
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
					at: either measure? [as byte-ptr! 0][code + written]
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
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RSP slot-displacement
								(storage-slots + depth) 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if all [state/unstable-stack? not custom-call?][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RSP slot-displacement state/native-stack-slot 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if all [
						target > 0
						(call-flags and NO_RETURN) <> 0
						(fn/flags and CATCH_FLAG) = 0
					][
						state/fallthrough?: false
					]
					depth: result-index
					if all [state/fallthrough? return-ref <> 0][
						depth: depth + 1
						stack-types/depth: return-ref
						stack-flags/depth: 0
						stack-kinds/depth: VALUE
						stack-tags/depth: 0
						either state/return-value? [
							result-offset: result-offsets/index
							aggregate-width: win64-aggregate-width return-ref table
							if any [
								result-offset >= 0
								all [aggregate-width = 0 not state/hidden-return?]
							][return INVALID_IR]
							if not state/hidden-return? [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX result-offset aggregate-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-address at (capacity - written)
								x64-encoder/RAX result-offset
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8
						][
							unless machine-value? return-ref 0 table [
								return UNSUPPORTED
							]
							width: value-width return-ref 0 table
							floating?: float-type? return-ref table
							tracked?: all [linear? state/fallthrough?]
							if all [tracked? not floating? width < 4][
								signed: either signed-type? return-ref table [1][0]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/extend-narrow-register at
									(capacity - written) x64-encoder/RAX x64-encoder/RAX
									width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either measure? [as byte-ptr! 0][code + written]
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
								state/location-depth: depth
								state/location-source: 0
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
			true [return UNSUPPORTED]
		]
		state/written: written
		state/depth: depth
		state/location: location
		state/storage-slots: storage-slots
		0
	]

	; Emits casts, native operations, and unary or binary arithmetic.
	emit-arithmetic-operation: func [
		context [x64-function-context!]
		instruction [rsir-instruction!]
		index [integer!]
		prepared [x64-instruction-state!]
		return: [integer!]
		/local
			module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			written [integer!]
			next-instruction [rsir-instruction!]
			overflow-scope [rsir-instruction!]
			at [byte-ptr!]
			table [type-table!]
			instructions [byte-ptr!]
			strings [byte-ptr!]
			code [byte-ptr!]
			instruction-effects [int-ptr!]
			instruction-offsets [int-ptr!]
			instruction-depths [int-ptr!]
			catch-depths [int-ptr!]
			control-uses [int-ptr!]
			stack-types [int-ptr!]
			stack-flags [int-ptr!]
			stack-kinds [int-ptr!]
			stack-tags [int-ptr!]
			strings-size [integer!]
			capacity [integer!]
			depth [integer!]
			kind [integer!]
			ref [integer!]
			flags [integer!]
			width [integer!]
			signed [integer!]
			source-signed [integer!]
			load-signed [integer!]
			source-slot [integer!]
			target-slot [integer!]
			storage-slots [integer!]
			tag-head [integer!]
			operation [integer!]
			left-ref [integer!]
			right-ref [integer!]
			left-flags [integer!]
			right-flags [integer!]
			left-kind [integer!]
			right-kind [integer!]
			operation-width [integer!]
			condition [integer!]
			stride [integer!]
			shift-count [integer!]
			encoded [integer!]
			target [integer!]
			register-id [integer!]
			source-width [integer!]
			target-width [integer!]
			target-ref [integer!]
			target-offset [integer!]
			instruction-start [integer!]
			operation-ref [integer!]
			source-kind [integer!]
			target-kind [integer!]
			opcode [integer!]
			parity [integer!]
			keep-cast [integer!]
			overflow-anchor [integer!]
			base-depth [integer!]
			overflow-limit [integer!]
			location [integer!]
			next-index [integer!]
			measure? [logic!]
			valid? [logic!]
			comparison? [logic!]
			floating? [logic!]
			atomic-old? [logic!]
			tracked? [logic!]
			located? [logic!]
			zero-extend? [logic!]
			linear? [logic!]
			paired? [logic!]
			fuse-branch? [logic!]
			immediate? [logic!]
			left-in-register? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		strings: module/strings
		strings-size: module/strings-size
		code: task/code
		capacity: task/capacity
		instructions: view/instructions
		instruction-effects: view/instruction-effects
		instruction-offsets: view/instruction-offsets
		instruction-depths: view/instruction-depths
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		stack-types: view/stack-types
		stack-flags: view/stack-flags
		stack-kinds: view/stack-kinds
		stack-tags: view/stack-tags
		measure?: null? code
		written: state/written
		depth: state/depth
		location: state/location
		storage-slots: state/storage-slots
		linear?: prepared/linear?
		paired?: prepared/paired?
		next-instruction: prepared/next-instruction
		instruction-start: prepared/instruction-start

		case [
				instruction/op = OP_CAST [
					if any [depth <= 0 stack-kinds/depth <> VALUE][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					source-width: value-width ref flags table
					target-width: value-width instruction/a instruction/b table
					keep-cast: instruction/c
					unless all [
						valid-type-ref? instruction/a table
						any [keep-cast = 0 keep-cast = 1]
						machine-value? ref flags table
						machine-value? instruction/a instruction/b table
					][return UNSUPPORTED]
					source-kind: cast-kind ref table
					target-kind: cast-kind instruction/a table
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
					state/location-depth: 0
					state/location-source: 0
					unless valid? [
						tracked?: true
						either floating? [
							case [
								keep-cast = 1 [
									either source-kind = 5 [
										at: either measure? [as byte-ptr! 0][code + written]
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
										at: either measure? [as byte-ptr! 0][code + written]
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
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/frame-load at
											(capacity - written) x64-encoder/RAX
											slot-displacement (storage-slots + depth) 4 1
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/integer-to-xmm at
										(capacity - written) x64-encoder/XMM0
										x64-encoder/RAX 4 target-width
								]
								target-kind = 5 [
									unless located? [
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + depth) source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/xmm-to-integer at
										(capacity - written) x64-encoder/RAX
										x64-encoder/XMM0 source-width 4
								]
								true [
									unless located? [
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/xmm-frame-load at
											(capacity - written) x64-encoder/XMM0
											slot-displacement (storage-slots + depth) source-width
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/xmm-convert at
										(capacity - written) x64-encoder/XMM0 x64-encoder/XMM0
										source-width target-width
								]
							]
						][
							signed: either signed-type? ref table [1][0]
							unless located? [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-load at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) source-width signed
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							encoded: 0
							either target-kind = 11 [
								width: either source-width = 8 [8][4]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/test-register at (capacity - written)
									x64-encoder/RAX width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/condition-result at
									(capacity - written) 5
							][
								if target-width < 4 [
									signed: either signed-type? instruction/a table [1][0]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/extend-narrow-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RAX
										target-width signed
								]
								if all [target-width = 4 source-width = 8][
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RAX 4
								]
								if all [target-width = 8 source-width < 8 signed = 1][
									at: either measure? [as byte-ptr! 0][code + written]
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
							state/location-depth: depth
						][
							at: either measure? [as byte-ptr! 0][code + written]
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
						valid-type-ref? ref table
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
					width: logical-size ref table
					if width <= 0 [return INVALID_IR]
					if depth > state/max-depth [state/max-depth: depth]
					stack-types/depth: -5
					stack-flags/depth: 0
					stack-kinds/depth: VALUE
					stack-tags/depth: 0
					at: either measure? [as byte-ptr! 0][code + written]
					kind: logical-kind ref table
					either all [instruction/b = 1 kind = 13][
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + depth) 8 0
					][
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
							x64-encoder/RAX 4 width 0
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					if all [instruction/b = 1 kind = 13][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/c-string-size at (capacity - written)
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: either measure? [as byte-ptr! 0][code + written]
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
						if state/cpu-pointer-ref = 0 [
							state/cpu-pointer-ref: integer-pointer-type table
						]
						if state/cpu-pointer-ref = 0 [return INVALID_IR]
					]
					target-ref: 0
					switch instruction/a [
						1 [						;-- system/stack/top
							unless all [
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
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
								machine-value? stack-types/depth stack-flags/depth table
							][return INVALID_IR]
							width: value-width stack-types/depth stack-flags/depth table
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) width 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/push-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth - 1
						]
						3 [						;-- POP
							unless instruction/c = 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/pop-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						4 [						;-- system/stack/frame
							unless all [
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: emit-stack-pointer at (capacity - written)
								x64-encoder/RBP slot-displacement
									(storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						5 [						;-- system/stack/top:
							unless all [
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatible-types? instruction/c stack-types/depth table
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								compatible-types? instruction/c stack-types/depth table
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
							][return INVALID_IR]
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: emit-stack-align at (capacity - written)
								slot-displacement (storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						8 [						;-- system/stack/allocate
							unless all [
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth table) = 5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -5
								depth > 0
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(logical-kind stack-types/depth table) = 5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
								(logical-kind stack-types/depth table) = 5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: emit-stack-free at (capacity - written)
								slot-displacement (storage-slots + depth)
							if encoded < 0 [return encoded]
							written: written + encoded
							depth: depth - 1
						]
						11 [					;-- system/stack/push-all
							unless instruction/c = 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: emit-stack-all at (capacity - written) false
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						12 [					;-- system/stack/pop-all
							unless instruction/c = 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: emit-stack-all at (capacity - written) true
							if encoded < 0 [return encoded]
							written: written + encoded
						]
						13 [					;-- system/pc
							unless all [
								valid-type-ref? instruction/c table
								pointee-type instruction/c table :target-ref
								(canonical-type target-ref table) = -2
							][return INVALID_IR]
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: instruction/c
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/call-relative at (capacity - written) 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/pop-register at (capacity - written)
								x64-encoder/RAX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						14 [					;-- system/cpu/<register>
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: state/cpu-pointer-ref
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							if register-id <> x64-encoder/RAX [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									x64-encoder/RAX register-id 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							at: either measure? [as byte-ptr! 0][code + written]
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
								compatible-types? state/cpu-pointer-ref stack-types/depth table
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if register-id <> x64-encoder/RAX [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/move-register at (capacity - written)
									register-id x64-encoder/RAX 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
							stack-types/depth: state/cpu-pointer-ref
							stack-flags/depth: 0
							stack-tags/depth: 0
						]
						16 [					;-- system/cpu/overflow?
							unless instruction/c = -11 [return INVALID_IR]
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either all [
								state/last-math-operation >= DIVIDE_OPERATION
								state/last-math-operation <= MODULO_OPERATION
							][
								x64-encoder/move-immediate-compact at (capacity - written)
									x64-encoder/RAX 4 0 0
							][
								x64-encoder/condition-result at (capacity - written) 0
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-store at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						17 [					;-- system/atomic/fence
							unless instruction/c = 0 [return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
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
								(logical-kind stack-types/depth table) = -6
								pointee-type stack-types/depth table :target-ref
								(canonical-type target-ref table) = -5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/register-load-indirect at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX 0 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
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
								(logical-kind stack-types/target-slot table) = -6
								pointee-type stack-types/target-slot table :target-ref
								(canonical-type target-ref table) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth table) = -5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/register-store-indirect at
								(capacity - written) x64-encoder/RDX x64-encoder/RAX 0 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
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
								(logical-kind stack-types/target-slot table) = -6
								pointee-type stack-types/target-slot table :target-ref
								(canonical-type target-ref table) = -5
								stack-kinds/source-slot = VALUE
								stack-flags/source-slot = 0
								(canonical-type stack-types/source-slot table) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth table) = -5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + source-slot) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/atomic-compare-exchange at
								(capacity - written) x64-encoder/RDX x64-encoder/RCX
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/condition-result at
								(capacity - written) 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							state/last-math-operation: 0
							depth: depth - 2
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
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
								(logical-kind stack-types/target-slot table) = -6
								pointee-type stack-types/target-slot table :target-ref
								(canonical-type target-ref table) = -5
								stack-kinds/depth = VALUE
								stack-flags/depth = 0
								(canonical-type stack-types/depth table) = -5
							][return INVALID_IR]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RDX slot-displacement
									(storage-slots + target-slot) 8 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RCX slot-displacement
									(storage-slots + depth) 4 1
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							case [
								operation <= 2 [
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/RAX x64-encoder/RCX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if operation = 2 [
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/negate-register at
											(capacity - written) x64-encoder/RAX 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/atomic-exchange-add at
										(capacity - written) x64-encoder/RDX x64-encoder/RAX
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if not atomic-old? [
										opcode: either operation = 1 [01h][29h]
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/binary-register at
											(capacity - written) opcode x64-encoder/RAX
											x64-encoder/RCX 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
								]
								true [
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/register-load-indirect at
										(capacity - written) x64-encoder/RAX x64-encoder/RDX 0 4 1
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									target-offset: written
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/move-register at
										(capacity - written) x64-encoder/R11 x64-encoder/RAX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									opcode: case [
										operation = 3 [09h]
										operation = 4 [31h]
										true [21h]
									]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/binary-register at
										(capacity - written) opcode x64-encoder/R11
										x64-encoder/RCX 4
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/atomic-compare-exchange at
										(capacity - written) x64-encoder/RDX x64-encoder/R11
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/jump-condition at
										(capacity - written) 5
										(target-offset - (written + 6))
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									if not atomic-old? [
										at: either measure? [as byte-ptr! 0][code + written]
										encoded: x64-encoder/move-register at
											(capacity - written) x64-encoder/RAX
											x64-encoder/R11 4
										if encoded < 0 [return OUTPUT_FULL]
										written: written + encoded
									]
								]
							]
							state/last-math-operation: case [
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
							at: either measure? [as byte-ptr! 0][code + written]
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
								integer-type? stack-types/depth table
							][return INVALID_IR]
							width: value-width stack-types/depth 0 table
							signed: either signed-type? stack-types/depth table [1][0]
							operation-width: either width = 8 [8][4]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: load-operation-value at (capacity - written)
								x64-encoder/RAX slot-displacement (storage-slots + depth)
								(value-width stack-types/depth 0 table) operation-width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/bit-scan-reverse at (capacity - written)
								x64-encoder/RAX x64-encoder/RAX operation-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							stack-types/depth: -5
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							at: either measure? [as byte-ptr! 0][code + written]
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
					state/location-depth: 0
					state/location-source: 0
					depth: depth - 1
				]
				instruction/op = OP_DUPLICATE [
					if depth <= 0 [return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					kind: stack-kinds/depth
					tag-head: stack-tags/depth
					width: either kind = PLACE [8][
						value-width ref flags table
					]
					signed: either signed-type? ref table [1][0]
					located?: all [
						kind = VALUE
						state/location-depth = depth
						any [location = LOCATION_GPR location = LOCATION_XMM]
					]
					unless located? [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							width signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if located? [
						at: either measure? [as byte-ptr! 0][code + written]
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
					if depth > state/max-depth [state/max-depth: depth]
					stack-types/depth: ref
					stack-flags/depth: flags
					stack-kinds/depth: kind
					stack-tags/depth: tag-head
					unless located? [
						target-width: either width = 8 [8][4]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-store at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							target-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if located? [state/location-depth: depth]
				]
				instruction/op = OP_UNARY [
					if any [
						instruction/a <> NOT_OPERATION
						instruction/b <> 0 instruction/c <> 0
						depth <= 0 stack-kinds/depth <> VALUE
					][return INVALID_IR]
					ref: stack-types/depth
					flags: stack-flags/depth
					kind: logical-kind ref table
					unless all [
						flags = 0
						any [integer-type? ref table kind = 11]
						machine-value? ref flags table
					][return INVALID_IR]
					width: value-width ref flags table
					operation-width: either width = 8 [8][4]
					signed: either signed-type? ref table [1][0]
					located?: location = LOCATION_GPR
					unless located? [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: load-operation-value at (capacity - written)
							x64-encoder/RAX slot-displacement (storage-slots + depth)
							(value-width ref flags table) operation-width signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					either kind = 11 [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/clear-register at (capacity - written)
							x64-encoder/RDX
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/binary-register at (capacity - written)
							39h x64-encoder/RAX x64-encoder/RDX operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/condition-result at (capacity - written) 4
					][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/not-register at (capacity - written)
							x64-encoder/RAX operation-width
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					state/location-depth: 0
					state/location-source: 0
					either linear? [
						if width < 4 [
							signed: either signed-type? ref table [1][0]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/extend-narrow-register at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX
								width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						location: LOCATION_GPR
						state/location-depth: depth
					][
						at: either measure? [as byte-ptr! 0][code + written]
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
					left-kind: logical-kind left-ref table
					right-kind: logical-kind right-ref table
					comparison?: operation >= EQUAL_OPERATION
					operation-ref: 0
					valid?: false
					case [
						operation <= MODULO_OPERATION [
							operation-ref: float-common-ref left-ref right-ref table
							valid?: any [
								all [
									integer-type? left-ref table
									integer-type? right-ref table
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
											address-type? left-ref table
											any [
												integer-type? right-ref table
												address-type? right-ref table
											]
										]
										all [
											left-kind = 5
											address-type? right-ref table
										]
									]
								]
							]
						]
						operation <= SHIFT_LOGICAL_OPERATION [
							valid?: all [
								integer-type? left-ref table
								right-kind = 5 left-flags = 0 right-flags = 0
							]
						]
						operation <= AND_OPERATION [
							valid?: all [
								any [integer-type? left-ref table left-kind = 11]
								compatible-types? left-ref right-ref table
								left-flags = right-flags
							]
						]
						comparison? [
							operation-ref: integer-common-ref left-ref right-ref table
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
											table]
										all [right-kind = -7 compatible-types? left-ref right-ref
											table]
									]
								]
								all [
									compatible-types? left-ref right-ref table
									left-flags = right-flags
									any [
										operation <= NOT_EQUAL_OPERATION
										all [
											left-kind <> 14 right-kind <> 14
											left-kind <> -4 right-kind <> -4
										]
									]
									any [
										float-type? left-ref table
										reference-type? left-ref table
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
						float-type? left-ref table
						float-type? right-ref table
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
									integer-type? left-ref table
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
							unless merge-target target base-depth fn view table [
								return INVALID_IR
							]
						]
					][
						if instruction/c <> 0 [return INVALID_IR]
					]
					unless all [
						machine-value? left-ref left-flags table
						machine-value? right-ref right-flags table
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
						width: value-width ref 0 table
						operation-width: width
						source-width: value-width right-ref right-flags table
						if located? [
							if any [
								location <> LOCATION_XMM_PAIR
								source-width <> operation-width
							][
								at: either measure? [as byte-ptr! 0][code + written]
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
						source-width: value-width left-ref left-flags table
						unless paired? [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/xmm-frame-load at (capacity - written)
								x64-encoder/XMM0 slot-displacement
									(storage-slots + target-slot) source-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if source-width <> operation-width [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/xmm-convert at (capacity - written)
								x64-encoder/XMM0 x64-encoder/XMM0 source-width operation-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						unless located? [
							source-width: value-width right-ref right-flags table
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/xmm-frame-load at (capacity - written)
								x64-encoder/XMM1 slot-displacement
									(storage-slots + depth) source-width
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							if source-width <> operation-width [
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/xmm-convert at (capacity - written)
									x64-encoder/XMM1 x64-encoder/XMM1
									source-width operation-width
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
						at: either measure? [as byte-ptr! 0][code + written]
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
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/float-condition-result
								at (capacity - written) condition parity
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					][
					ref: either operation-ref <> 0 [operation-ref][left-ref]
					width: value-width ref left-flags table
					operation-width: either any [
						width = 8
						reference-type? ref table
					][8][4]
					zero-extend?: operation = SHIFT_LOGICAL_OPERATION
					signed: either signed-type? ref table [1][0]
					load-signed: either zero-extend? [0][signed]
					source-signed: either signed-type? right-ref table [1][0]
					source-slot: either all [
						operation >= DIVIDE_OPERATION
						operation <= SHIFT_LOGICAL_OPERATION
					][x64-encoder/RCX][x64-encoder/RDX]
					; The preceding literal offered itself as the immediate
					; right operand. Pointer arithmetic scales it first, so the
					; scaled product must still fit a sign-extended imm32.
					immediate?: all [
						not floating?
						state/pending-immediate-kind = 1
						state/pending-immediate-index = (index - 1)
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
						state/location-depth = (depth - 1)
					]
					if all [located? not paired? not left-in-register?][
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: move-operation-value at (capacity - written)
							source-slot x64-encoder/RAX
							(value-width right-ref right-flags table)
							operation-width source-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					target-offset: 0
					if all [tracked? not measure?][
						target-offset: instruction-start
							+ (instruction-offsets/target - instruction-offsets/index)
					]
					unless any [paired? left-in-register?] [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: load-operation-value at (capacity - written)
							x64-encoder/RAX slot-displacement
							(storage-slots + target-slot)
							(value-width left-ref left-flags table) operation-width
							load-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					unless any [located? immediate?] [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: load-operation-value at (capacity - written)
							source-slot slot-displacement (storage-slots + depth)
							(value-width right-ref right-flags table) operation-width source-signed
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					if all [
						address-type? left-ref table
						integer-type? right-ref table
					][
						stride: pointer-stride left-ref table
						if stride <= 0 [return UNSUPPORTED]
						if stride <> 1 [
							either immediate? [
								state/pending-immediate-value: state/pending-immediate-value
									* stride
							][
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/multiply-immediate at
									(capacity - written)
									x64-encoder/RDX x64-encoder/RDX stride 8
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
							]
						]
					]

					if tracked? [
						at: either measure? [as byte-ptr! 0][code + written]
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
									operation-width signed instruction/c
									(target-offset - written)
							]
							true [0]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]

					at: either measure? [as byte-ptr! 0][code + written]
					case [
						operation = ADD_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									0 x64-encoder/RAX state/pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									01h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = SUBTRACT_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									5 x64-encoder/RAX state/pending-immediate-value
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
									x64-encoder/RAX state/pending-immediate-value
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
							shift-count: either immediate? [
								state/pending-immediate-value
							][instruction/c]
							encoded: either any [tracked? immediate?][
								x64-encoder/shift-immediate at (capacity - written)
									x64-encoder/RAX 4 shift-count operation-width
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
									state/pending-immediate-value operation-width
							][
								x64-encoder/shift-register at (capacity - written)
									x64-encoder/RAX condition operation-width
							]
						]
						operation = SHIFT_LOGICAL_OPERATION [
							encoded: either immediate? [
								x64-encoder/shift-immediate at (capacity - written)
									x64-encoder/RAX 5 state/pending-immediate-value
									operation-width
							][
								x64-encoder/shift-register at (capacity - written)
									x64-encoder/RAX 5 operation-width
							]
						]
						operation = OR_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									1 x64-encoder/RAX state/pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									09h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = XOR_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									6 x64-encoder/RAX state/pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									31h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						operation = AND_OPERATION [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									4 x64-encoder/RAX state/pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									21h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						comparison? [
							encoded: either immediate? [
								x64-encoder/alu-immediate at (capacity - written)
									7 x64-encoder/RAX state/pending-immediate-value
									operation-width
							][
								x64-encoder/binary-register at (capacity - written)
									39h x64-encoder/RAX x64-encoder/RDX operation-width
							]
						]
						true [encoded: -1]
					]
					if immediate? [state/pending-immediate-index: -1]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded

					if all [tracked? operation <= MULTIPLY_OPERATION][
						condition: either signed = 1 [0][2]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: jump-condition-to at (capacity - written) condition
							target-offset written
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						if width < 4 [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: narrow-overflow-check at (capacity - written)
								width signed target-offset written
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]

					if operation = REMAINDER_OPERATION [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-register at (capacity - written)
							x64-encoder/RAX x64-encoder/RDX operation-width
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					if operation = MODULO_OPERATION [
						at: either measure? [as byte-ptr! 0][code + written]
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
						next-index: prepared/next-index
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
							any [
								not boolean-diamond? (index + 1)
									fn/instruction-count instructions
									catch-depths control-uses
								boolean-diamond-branch? (index + 1)
									fn/instruction-count instructions instruction-effects
									catch-depths control-uses
							]
						]
						either fuse-branch? [
							state/flags-condition: condition
						][
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/condition-result at
								(capacity - written) condition
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					]
					unless floating? [state/last-math-operation: operation]

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
					state/location-depth: 0
					state/location-source: 0
					either fuse-branch? [
						; The result lives only in the compare flags and is
						; consumed by the adjacent branch before any other
						; instruction can clobber them.
						0
					][
					either linear? [
						if all [not floating? not comparison? width < 4][
							signed: either signed-type? ref table [1][0]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/extend-narrow-register at
								(capacity - written) x64-encoder/RAX x64-encoder/RAX
								width signed
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						location: either all [floating? not comparison?][
							LOCATION_XMM
						][LOCATION_GPR]
						state/location-depth: depth
					][
						at: either measure? [as byte-ptr! 0][code + written]
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
			true [return UNSUPPORTED]
		]
		state/written: written
		state/depth: depth
		state/location: location
		state/storage-slots: storage-slots
		0
	]

	; Emits exception, branch, subroutine, and return operations.
	emit-control-operation: func [
		context [x64-function-context!]
		instruction [rsir-instruction!]
		index [integer!]
		prepared [x64-instruction-state!]
		return: [integer!]
		/local
			module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			written [integer!]
			sub-entry [rsir-instruction!]
			switch-case [rsir-switch!]
			at [byte-ptr!]
			table [type-table!]
			instructions [byte-ptr!]
			code [byte-ptr!]
			switches [byte-ptr!]
			instruction-effects [int-ptr!]
			instruction-offsets [int-ptr!]
			catch-depths [int-ptr!]
			control-uses [int-ptr!]
			stack-types [int-ptr!]
			stack-flags [int-ptr!]
			stack-kinds [int-ptr!]
			stack-tags [int-ptr!]
			references [int-ptr!]
			switch-count [integer!]
			function-offset [integer!]
			capacity [integer!]
			exit-reference-id [integer!]
			entry? [logic!]
			depth [integer!]
			ref [integer!]
			flags [integer!]
			width [integer!]
			signed [integer!]
			source-slot [integer!]
			target-slot [integer!]
			storage-slots [integer!]
			tag-head [integer!]
			operation-width [integer!]
			condition [integer!]
			encoded [integer!]
			target [integer!]
			return-ref [integer!]
			displacement [integer!]
			target-width [integer!]
			target-offset [integer!]
			instruction-start [integer!]
			case-index [integer!]
			aggregate-width [integer!]
			value-size [integer!]
			catch-record [integer!]
			catch-unwind [integer!]
			allocation-size [integer!]
			location [integer!]
			compatibility [integer!]
			measure? [logic!]
			floating? [logic!]
			tracked? [logic!]
			fold-boolean? [logic!]
			fold-constant? [logic!]
			branch-taken? [logic!]
				direct-boolean? [logic!]
				sub-returns? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		switches: module/switches
		switch-count: module/switch-count
		code: task/code
		references: task/references
		function-offset: task/function-offset
		capacity: task/capacity
		exit-reference-id: task/exit-reference-id
		entry?: task/entry?
		instructions: view/instructions
		instruction-effects: view/instruction-effects
		instruction-offsets: view/instruction-offsets
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		stack-types: view/stack-types
		stack-flags: view/stack-flags
		stack-kinds: view/stack-kinds
		stack-tags: view/stack-tags
		measure?: null? code
		written: state/written
		depth: state/depth
		location: state/location
		storage-slots: state/storage-slots
		allocation-size: prepared/allocation-size
		instruction-start: prepared/instruction-start

		case [
				instruction/op = OP_CATCH [
					target: instruction/a
					state/catch-level: instruction/b
					catch-unwind: state/catch-level - 1
					unless all [
						target > index target <= fn/instruction-count
						state/catch-level > 0 state/catch-level <= state/catch-capacity
						instruction/c = 0
						catch-depths/index = catch-unwind
						catch-depths/target = state/catch-level
						depth > 0 stack-kinds/depth = VALUE
						stack-flags/depth = 0
						compatible-types? -5 stack-types/depth table
					][return INVALID_IR]
					catch-record: state/catch-base + ((state/catch-level - 1) * 3) + 1
					target-offset: 0
					if not measure? [
						target-offset: instruction-offsets/target + allocation-size
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: emit-catch-open at (capacity - written)
						catch-record (storage-slots + depth) target-offset written
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					depth: depth - 1
					if measure? [
						unless merge-target target depth fn view table [
							return INVALID_IR
						]
					]
				]
				instruction/op = OP_END_CATCH [
					state/catch-level: instruction/b
					unless all [
						instruction/a > 0 instruction/a < index
						state/catch-level > 0 state/catch-level <= state/catch-capacity
						instruction/c = 0
						catch-depths/index = state/catch-level
					][return INVALID_IR]
					catch-record: state/catch-base + ((state/catch-level - 1) * 3) + 1
					at: either measure? [as byte-ptr! 0][code + written]
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
						compatible-types? -5 stack-types/source-slot table
						stack-kinds/target-slot = PLACE
						stack-flags/target-slot = 0
						compatible-types? -5 stack-types/target-slot table
					][return INVALID_IR]
					tag-head: stack-tags/target-slot
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RAX slot-displacement
							(storage-slots + source-slot) 4 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/frame-load at (capacity - written)
						x64-encoder/RDX slot-displacement
							(storage-slots + target-slot) 8 0
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/store-indirect at (capacity - written) 4
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: emit-variant-tags at (capacity - written) tag-head state fn view
					if encoded < 0 [return encoded]
					written: written + encoded
					if tag-head > 0 [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written)
							x64-encoder/RAX slot-displacement
								(storage-slots + source-slot) 4 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					depth: source-slot - 1
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/throw-unwind at (capacity - written)
						((fn/flags and CATCH_FLAG) <> 0)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					state/fallthrough?: false
				]
				instruction/op = OP_JUMP [
					target: instruction/a
					state/catch-level: catch-depths/index
					catch-unwind: state/catch-level - instruction/c
					unless all [
						target > 0 target <= fn/instruction-count
						instruction/b >= 0 instruction/b <= depth
						instruction/c >= 0 instruction/c <= state/catch-level
						catch-depths/target = catch-unwind
					][return INVALID_IR]
					catch-unwind: instruction/c
					while [catch-unwind > 0][
						catch-record: state/catch-base + ((state/catch-level - 1) * 3) + 1
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: emit-catch-restore at (capacity - written) catch-record
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						state/catch-level: state/catch-level - 1
						catch-unwind: catch-unwind - 1
					]
					depth: depth - instruction/b
					if measure? [
						unless merge-target target depth fn view table [
							return INVALID_IR
						]
					]
					displacement: 0
					if not measure? [
						target-offset: index + 1
						displacement: instruction-offsets/target
							- instruction-offsets/target-offset
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: either
						(instruction-effects/index and EFFECT_SHORT_JUMP) <> 0
					[
						x64-encoder/jump-relative-short at (capacity - written)
							displacement
					][
						x64-encoder/jump-relative at (capacity - written)
							displacement
					]
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					state/fallthrough?: false
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
								compatible-types? -11 stack-types/depth table
								stack-flags/depth = 0
							]
						]
					][return INVALID_IR]
					either fold-constant? [
						if branch-taken? [
							if measure? [
								unless merge-target target depth fn view table [
									return INVALID_IR
								]
							]
							displacement: 0
							if not measure? [
								target-offset: index + 1
								displacement: instruction-offsets/target
									- instruction-offsets/target-offset
							]
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either
								(instruction-effects/index and EFFECT_SHORT_JUMP) <> 0
							[
								x64-encoder/jump-relative-short at (capacity - written)
									displacement
							][
								x64-encoder/jump-relative at (capacity - written)
									displacement
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							state/fallthrough?: false
						]
					][
						fold-boolean?: boolean-diamond? index fn/instruction-count
							instructions catch-depths control-uses
						at: as byte-ptr! 0
						tracked?: location = LOCATION_GPR
						unless any [tracked? state/flags-condition >= 0][
							if not measure? [at: code + written]
							encoded: x64-encoder/frame-load at (capacity - written)
								x64-encoder/RAX slot-displacement
									(storage-slots + depth) 4 0
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						if state/flags-condition < 0 [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/test-register at
								(capacity - written) x64-encoder/RAX 4
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
						either fold-boolean? [
							direct-boolean?: all [
								state/flags-condition >= 0
								boolean-diamond-branch? index fn/instruction-count
									instructions instruction-effects catch-depths control-uses
							]
							unless direct-boolean? [
								condition: either state/flags-condition >= 0 [state/flags-condition][5]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/condition-result at
									(capacity - written) condition
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: x64-encoder/frame-store at (capacity - written)
									x64-encoder/RAX slot-displacement
										(storage-slots + depth) 4
								if encoded < 0 [return OUTPUT_FULL]
								written: written + encoded
								state/flags-condition: -1
							]
							stack-types/depth: -11
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							location: LOCATION_NONE
							state/location-depth: 0
							state/location-source: 0
							if measure? [
								target-offset: index + 1
								while [target-offset <= (index + 3)][
									instruction-offsets/target-offset: written
									target-offset: target-offset + 1
								]
							]
							prepared/advance: 4
						][
							depth: depth - 1
							if measure? [
								unless merge-target target depth fn view table [
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
								state/flags-condition >= 0 [
									; Branch directly on the fused compare
									; flags; inversion is the adjacent cc.
									either instruction/b = 1 [
										state/flags-condition
									][state/flags-condition xor 1]
								]
								instruction/b = 1 [5]
								true [4]
							]
							state/flags-condition: -1
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: either
								(instruction-effects/index and EFFECT_SHORT_BRANCH) <> 0
							[
								x64-encoder/jump-condition-short at
									(capacity - written) condition displacement
							][
								x64-encoder/jump-condition at
									(capacity - written) condition displacement
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
							location: LOCATION_NONE
							state/location-depth: 0
							state/location-source: 0
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
						integer-type? stack-types/depth table
					][return INVALID_IR]
					ref: stack-types/depth
					width: value-width ref 0 table
					signed: either signed-type? ref table [1][0]
					operation-width: either width = 8 [8][4]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: load-operation-value at (capacity - written)
						x64-encoder/RAX slot-displacement (storage-slots + depth)
						(value-width ref 0 table) operation-width signed
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
							unless merge-target target depth fn view table [
								return INVALID_IR
							]
						]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/move-immediate-compact at (capacity - written)
							x64-encoder/RDX operation-width switch-case/low switch-case/high
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
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
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/jump-condition at (capacity - written)
							4 displacement
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						case-index: case-index + 1
					]

					target: instruction/c
					if catch-depths/target <> catch-depths/index [return INVALID_IR]
					if measure? [
						unless merge-target target depth fn view table [
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
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/jump-relative at (capacity - written)
						displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					state/fallthrough?: false
				]
				instruction/op = OP_ENTRY [
					if any [state/current-entry <> index depth <> 0][return INVALID_IR]
					if instruction/a = 1 [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/adjust-stack at (capacity - written)
							(0 - state/sub-frame)
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
				]
				instruction/op = OP_SUB_CALL [
					target: instruction/a
					if target = state/current-entry [return INVALID_IR]
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
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/call-relative at (capacity - written)
						displacement
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					sub-returns?: (instruction-effects/target and EFFECT_RESUMES) <> 0
					either not sub-returns? [
						state/fallthrough?: false
					][
						ref: instruction/b
						if ref <> 0 [
							depth: depth + 1
							if depth > state/max-depth [state/max-depth: depth]
							stack-types/depth: ref
							stack-flags/depth: 0
							stack-kinds/depth: VALUE
							stack-tags/depth: 0
							width: value-width ref 0 table
							floating?: float-type? ref table
							at: either measure? [as byte-ptr! 0][code + written]
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
					if state/current-entry <= 0 [
						return INVALID_IR
					]
					sub-entry: as rsir-instruction! (instructions
						+ ((state/current-entry - 1) * RSIR_INSTRUCTION_SIZE))
					return-ref: instruction/a
					compatibility: 0
					if all [
						return-ref <> 0 depth = 1 stack-kinds/depth = VALUE
						stack-flags/depth = 0
					][
						compatibility: implicitly-compatible-types return-ref stack-types/depth
							stack-tags/depth false table
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
								machine-value? stack-types/depth 0 table
							]
						]
					][
						return INVALID_IR
					]
					if return-ref <> 0 [
						ref: stack-types/depth
						signed: either signed-type? ref table [1][0]
						target-width: value-width return-ref 0 table
						floating?: float-type? return-ref table
						tracked?: location <> LOCATION_NONE
						if tracked? [
							if any [
								all [floating? location <> LOCATION_XMM]
								all [not floating? location <> LOCATION_GPR]
							][return INVALID_IR]
						]
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: either tracked? [
							either all [
								location = LOCATION_GPR
								target-width = 8
								(value-width ref 0 table) < 8
								signed-type? ref table
							][
								x64-encoder/sign-extend-register at (capacity - written)
									x64-encoder/RAX x64-encoder/RAX
							][0]
						][
							either floating? [
								x64-encoder/xmm-frame-load at (capacity - written)
									x64-encoder/XMM0 slot-displacement
									(storage-slots + depth) target-width
							][
								load-operation-value at (capacity - written)
									x64-encoder/RAX slot-displacement
									(storage-slots + depth)
									(value-width ref 0 table) target-width signed
							]
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/adjust-stack at (capacity - written) state/sub-frame
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/return-near at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					state/location-depth: 0
					state/location-source: 0
					depth: 0
					state/fallthrough?: false
				]
				instruction/op = OP_FAIL [
					unless all [
						instruction/a > 0
						instruction/b = 0
						instruction/c = 0
					][return INVALID_IR]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/trap at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					state/fallthrough?: false
				]
				instruction/op = OP_RETURN [
					return-ref: instruction/a
					state/return-value?: (fn/flags and RETURN_VALUE) <> 0
					state/hidden-return?: win64-hidden-return? fn/return-type fn/flags table
					if any [
						return-ref <> fn/return-type
						instruction/c <> 0
						all [return-ref = 0 instruction/b <> 0]
						all [entry? state/return-value?]
					][return INVALID_IR]
					if return-ref <> 0 [
						if any [depth < 1 stack-kinds/depth <> VALUE][return INVALID_IR]
						either state/return-value? [
							unless all [
								instruction/b = 0
								stack-flags/depth = 0
								aggregate-ref? stack-types/depth table
								compatible-types? return-ref stack-types/depth table
							][return INVALID_IR]
						][
							compatibility: implicitly-compatible-types return-ref stack-types/depth
								stack-tags/depth false table
							if compatibility < 0 [return compatibility]
							unless all [
								compatibility = 1
								stack-flags/depth = instruction/b
								machine-value? return-ref instruction/b table
								machine-value? stack-types/depth stack-flags/depth table
							][return INVALID_IR]
						]
					]
					either entry? [
						if state/max-outgoing < 32 [state/max-outgoing: 32]
						either return-ref = 0 [
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: x64-encoder/clear-register at (capacity - written)
								x64-encoder/RCX
						][
							ref: stack-types/depth
							flags: stack-flags/depth
							signed: either signed-type? ref table [1][0]
							target-width: value-width return-ref instruction/b table
							at: either measure? [as byte-ptr! 0][code + written]
							encoded: load-operation-value at (capacity - written)
								x64-encoder/RCX slot-displacement
								(storage-slots + depth)
								(value-width ref flags table) target-width signed
						]
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/call-import at (capacity - written) 0
						if encoded < 0 [return OUTPUT_FULL]
						if not measure? [
							if exit-reference-id <= 0 [return INVALID_IR]
							references/exit-reference-id: function-offset + written + 2
						]
						written: written + encoded
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/clear-register at (capacity - written)
							x64-encoder/RAX
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					][
						if return-ref <> 0 [
							either state/return-value? [
								aggregate-width: win64-aggregate-width return-ref table
								either state/hidden-return? [
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RCX slot-displacement
											(storage-slots + depth) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RDX
										(0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									value-size: aggregate-size return-ref table
									if value-size <= 0 [return INVALID_IR]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/copy-indirect at
										(capacity - written) value-size
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX
										(0 - (x64-encoder/BASE_FRAME_SIZE + 8)) 8 0
								][
									if aggregate-width = 0 [return INVALID_IR]
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/frame-load at (capacity - written)
										x64-encoder/RAX slot-displacement
											(storage-slots + depth) 8 0
									if encoded < 0 [return OUTPUT_FULL]
									written: written + encoded
									at: either measure? [as byte-ptr! 0][code + written]
									encoded: x64-encoder/load-indirect at
										(capacity - written) aggregate-width 0
								]
							][
								ref: stack-types/depth
								flags: stack-flags/depth
								signed: either signed-type? ref table [1][0]
								target-width: value-width return-ref instruction/b table
								floating?: float-type? return-ref table
								tracked?: location <> LOCATION_NONE
								if tracked? [
									if any [
										all [floating? location <> LOCATION_XMM]
										all [not floating? location <> LOCATION_GPR]
									][return INVALID_IR]
								]
								at: either measure? [as byte-ptr! 0][code + written]
								encoded: either tracked? [
									either all [
										location = LOCATION_GPR
										target-width = 8
										(value-width ref flags table) < 8
										signed-type? ref table
									][
										x64-encoder/sign-extend-register at
											(capacity - written) x64-encoder/RAX x64-encoder/RAX
									][0]
								][
									either floating? [
										x64-encoder/xmm-frame-load at (capacity - written)
											x64-encoder/XMM0 slot-displacement
												(storage-slots + depth) target-width
									][
										load-operation-value at (capacity - written)
											x64-encoder/RAX slot-displacement
											(storage-slots + depth)
											(value-width ref flags table) target-width signed
									]
								]
							]
							if encoded < 0 [return OUTPUT_FULL]
							written: written + encoded
						]
					]
					at: either measure? [as byte-ptr! 0][code + written]
					encoded: x64-encoder/leave-return at (capacity - written)
					if encoded < 0 [return OUTPUT_FULL]
					written: written + encoded
					location: LOCATION_NONE
					state/location-depth: 0
					state/location-source: 0
					depth: 0
					state/fallthrough?: false
				]
			true [return UNSUPPORTED]
		]
		state/written: written
		state/depth: depth
		state/location: location
		state/storage-slots: storage-slots
		0
	]

	; Prepares one live instruction for a family emitter. This is the single
	; place where control-flow merges, location pairing, and register flushing
	; update the shared machine cursor.
	prepare-instruction: func [
		context [x64-function-context!]
		instruction [rsir-instruction!]
		index [integer!]
		prepared [x64-instruction-state!]
		return: [integer!]
		/local module [rsir-module!]
			task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			fn [rsir-function!]
			next-instruction following-instruction [rsir-instruction!]
			parameter [rsir-parameter!]
			global [rsir-global!]
			at [byte-ptr!]
			table [type-table!]
			code instructions parameters globals [byte-ptr!]
			instruction-effects instruction-depths catch-depths control-uses
				instruction-offsets
				entry-types entry-flags entry-kinds entry-tags
				stack-types stack-flags stack-kinds stack-tags [int-ptr!]
			global-count capacity written depth location storage-slots
				tag-head ref target target-ref target-flags next-index instruction-start
							width encoded target-width flags [integer!]
			measure? linear? paired? set-pair? address-pair? load-pair?
				consume-location? valid? floating? [logic!]
	][
		module: context/module
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		table: module/table
		code: task/code
		instructions: view/instructions
		parameters: module/parameters
		globals: module/globals
		global-count: module/global-count
		capacity: task/capacity
		instruction-effects: view/instruction-effects
		instruction-offsets: view/instruction-offsets
		instruction-depths: view/instruction-depths
		catch-depths: view/catch-depths
		control-uses: view/control-uses
		entry-types: view/entry-types
		entry-flags: view/entry-flags
		entry-kinds: view/entry-kinds
		entry-tags: view/entry-tags
		stack-types: view/stack-types
		stack-flags: view/stack-flags
		stack-kinds: view/stack-kinds
		stack-tags: view/stack-tags
		measure?: null? code
		written: state/written
		depth: state/depth
		location: state/location
		storage-slots: state/storage-slots
		prepared/advance: 1
		next-instruction: null

		unless (instruction-effects/index and EFFECT_LIVE) <> 0 [
			if measure? [instruction-offsets/index: written]
			state/written: written
			state/depth: depth
			state/location: location
			state/storage-slots: storage-slots
			return PREPARE_SKIPPED
		]
		if all [
			instruction/op = OP_SUB_RETURN
			instruction/a = 0
			depth = 1
		][
			unless stack-kinds/depth = VALUE [return INVALID_IR]
			depth: 0
			location: LOCATION_NONE
			state/location-depth: 0
			state/location-source: 0
			state/source-location: LOCATION_NONE
			state/source-depth: 0
		]
		if instruction/op = OP_ENTRY [
			if state/fallthrough? [return INVALID_IR]
			if state/max-depth > (2147483647 - state/segment-slots)[return OUTPUT_FULL]
			state/segment-slots: state/segment-slots + state/max-depth
			if state/storage-base > (2147483647 - state/segment-slots)[return OUTPUT_FULL]
			storage-slots: state/storage-base + state/segment-slots
			depth: 0
			state/max-depth: 0
			state/current-entry: index
			state/fallthrough?: true
		]
		either state/fallthrough? [
			if instruction-depths/index >= 0 [
				if measure? [
					if instruction-depths/index <> depth [return INVALID_IR]
					if depth > 0 [
						tag-head: stack-tags/depth
						if tag-head < 0 [tag-head: 0]
						ref: merged-type entry-types/index stack-types/depth table
						if any [
							ref = 0
							entry-flags/index <> stack-flags/depth
							entry-kinds/index <> stack-kinds/depth
							entry-tags/index <> tag-head
						][return INVALID_IR]
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
			depth: either instruction-depths/index >= 0 [instruction-depths/index][0]
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
		state/incoming-arguments: keep-incoming-arguments state/incoming-arguments index
			control-uses/index instruction
		if state/resident? [
			if any [written <> state/resident-mark control-uses/index <> 0 instruction/op = OP_ENTRY][
				state/resident?: false
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
			valid-type-ref? instruction/a table
			machine-value? instruction/a 0 table
			(instruction-effects/next-index and EFFECT_LIVE) <> 0
			(instruction-effects/next-index and EFFECT_ELIDED) = 0
			next-instruction/op = OP_BINARY
			next-instruction/a >= ADD_OPERATION
			next-instruction/a <= LESS_EQUAL_OPERATION
		][
			paired?: either location = LOCATION_XMM [
				all [float-type? stack-types/depth table float-type? instruction/a table
					register-pair-operation? next-instruction/a true]
			][
				any [
					all [instruction/a = stack-types/depth integer-type? stack-types/depth table
						integer-type? instruction/a table register-pair-operation? next-instruction/a false]
					all [address-type? stack-types/depth table integer-type? instruction/a table
						any [next-instruction/a = ADD_OPERATION next-instruction/a = SUBTRACT_OPERATION]
						next-instruction/b = 0 (value-width instruction/a 0 table) = 4
						any [all [instruction/c = 0 instruction/b >= 0] all [instruction/c = -1 instruction/b < 0]]
						scaled-pointer-literal? instruction/b stack-types/depth table]
				]
			]
		]
		set-pair?: false
		address-pair?: false
		if all [
			linear? any [location = LOCATION_GPR location = LOCATION_XMM]
			instruction/op = OP_ADDRESS depth > 0 stack-kinds/depth = VALUE stack-flags/depth = 0
		][
			target-ref: 0
			target-flags: -1
			case [
				all [instruction/a = LOCAL_ADDRESS instruction/b > 0 instruction/b <= state/storage-count][
					parameter: as rsir-parameter! (parameters
						+ ((fn/first-parameter + instruction/b - 1) * RSIR_PARAMETER_SIZE))
					target-ref: parameter/type
					target-flags: parameter/flags
				]
				all [instruction/a = GLOBAL_ADDRESS instruction/b > 0 instruction/b <= global-count][
					global: as rsir-global! (globals + ((instruction/b - 1) * RSIR_GLOBAL_SIZE))
					target-ref: global/type
					target-flags: global/flags and INLINE
				]
				true [0]
			]
			if all [valid-type-ref? target-ref table target-flags = 0 machine-value? target-ref 0 table][
				floating?: float-type? target-ref table
				valid?: either floating? [location = LOCATION_XMM][all [location = LOCATION_GPR target-ref = stack-types/depth]]
				if valid? [
					set-pair?: all [target-ref = stack-types/depth
						(instruction-effects/next-index and EFFECT_LIVE) <> 0
						(instruction-effects/next-index and EFFECT_ELIDED) = 0 next-instruction/op = OP_SET]
					if all [next-instruction/op = OP_LOAD
						(instruction-effects/next-index and EFFECT_LIVE) <> 0
						(instruction-effects/next-index and EFFECT_ELIDED) = 0 next-index < fn/instruction-count][
						target: next-index + 1
						following-instruction: as rsir-instruction! (instructions + (next-index * RSIR_INSTRUCTION_SIZE))
						address-pair?: all [control-uses/target = 0 catch-depths/target = catch-depths/index
							following-instruction/op <> OP_ENTRY
							(instruction-effects/target and EFFECT_LIVE) <> 0
							(instruction-effects/target and EFFECT_ELIDED) = 0
							following-instruction/op = OP_BINARY following-instruction/a >= ADD_OPERATION
							following-instruction/a <= LESS_EQUAL_OPERATION
							register-pair-operation? following-instruction/a floating?]
					]
				]
			]
		]
		load-pair?: all [linear? instruction/op = OP_LOAD state/source-location <> LOCATION_NONE
			state/source-depth = (depth - 1)
			(instruction-effects/next-index and EFFECT_LIVE) <> 0
			(instruction-effects/next-index and EFFECT_ELIDED) = 0 next-instruction/op = OP_BINARY]
		if location <> LOCATION_NONE [
			unless any [all [state/location-depth = depth depth > 0 control-uses/index = 0]
				all [state/pending-immediate-kind = 1 state/pending-immediate-index = (index - 1)
					location = LOCATION_GPR state/location-depth = (depth - 1)]][return INVALID_IR]
			consume-location?: case [
				any [location = LOCATION_ADDRESS location = LOCATION_FRAME location = LOCATION_FRAME_INDIRECT
					location = LOCATION_GLOBAL location = LOCATION_ARGUMENT][
					any [instruction/op = OP_LOAD instruction/op = OP_REFERENCE instruction/op = OP_MEMBER
						instruction/op = OP_SET instruction/op = OP_CALL instruction/op = OP_DROP]
				]
				any [location = LOCATION_GPR location = LOCATION_XMM][
					any [all [instruction/op = OP_LITERAL paired?]
						all [instruction/op = OP_ADDRESS any [set-pair? address-pair?]] instruction/op = OP_DROP
						instruction/op = OP_DUPLICATE instruction/op = OP_CAST instruction/op = OP_BINARY
						instruction/op = OP_SUB_RETURN all [instruction/op = OP_CALL instruction/b > 0]
						all [instruction/op = OP_UNARY location = LOCATION_GPR]
						all [instruction/op = OP_RETURN not task/entry? (fn/flags and RETURN_VALUE) = 0]
						all [instruction/op = OP_MEMBER location = LOCATION_GPR]
						all [instruction/op = OP_BRANCH location = LOCATION_GPR
							(instruction-effects/index and EFFECT_CONSTANT_BRANCH) = 0]]
				]
				any [location = LOCATION_GPR_PAIR location = LOCATION_XMM_PAIR][instruction/op = OP_BINARY]
				true [false]
			]
			unless consume-location? [
				case [
					location = LOCATION_FRAME [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-address at (capacity - written) x64-encoder/RAX state/location-source
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					location = LOCATION_FRAME_INDIRECT [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/frame-load at (capacity - written) x64-encoder/RAX state/location-source 8 0
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					location = LOCATION_ADDRESS [
						at: either measure? [as byte-ptr! 0][code + written]
						encoded: x64-encoder/add-immediate at (capacity - written) x64-encoder/RAX state/location-source
						if encoded < 0 [return OUTPUT_FULL]
						written: written + encoded
					]
					location = LOCATION_ARGUMENT [return INVALID_IR]
					any [location = LOCATION_GPR location = LOCATION_XMM][0]
					location = LOCATION_GLOBAL [return INVALID_IR]
					any [location = LOCATION_GPR_PAIR location = LOCATION_XMM_PAIR][return INVALID_IR]
					true [return INVALID_IR]
				]
				ref: stack-types/depth
				flags: stack-flags/depth
				at: either measure? [as byte-ptr! 0][code + written]
				encoded: case [
					any [location = LOCATION_ADDRESS location = LOCATION_FRAME location = LOCATION_FRAME_INDIRECT][
						x64-encoder/frame-store at (capacity - written) x64-encoder/RAX
							slot-displacement (storage-slots + depth) 8]
					location = LOCATION_XMM [
						width: value-width ref flags table
						if width <= 0 [return INVALID_IR]
						x64-encoder/xmm-frame-store at (capacity - written) x64-encoder/XMM0
							slot-displacement (storage-slots + depth) width]
					location = LOCATION_GPR [
						width: either inline-object-ref? ref table [8][value-width ref flags table]
						if width <= 0 [return INVALID_IR]
						target-width: either width = 8 [8][4]
						x64-encoder/frame-store at (capacity - written) x64-encoder/RAX
							slot-displacement (storage-slots + depth) target-width]
					true [return INVALID_IR]
				]
				if encoded < 0 [return OUTPUT_FULL]
				written: written + encoded
				location: LOCATION_NONE
				state/location-depth: 0
				state/location-source: 0
			]
		]
		if (instruction-effects/index and EFFECT_ELIDED) <> 0 [
			if measure? [instruction-offsets/index: written]
			state/fallthrough?: true
			state/written: written
			state/depth: depth
			state/location: location
			state/storage-slots: storage-slots
			return PREPARE_SKIPPED
		]
		if measure? [instruction-offsets/index: written]
		instruction-start: written
		state/fallthrough?: true
		state/written: written
		state/depth: depth
		state/location: location
		state/storage-slots: storage-slots
		prepared/next-index: next-index
		prepared/next-instruction: next-instruction
		prepared/instruction-start: instruction-start
		prepared/linear?: linear?
		prepared/paired?: paired?
		prepared/set-pair?: set-pair?
		prepared/address-pair?: address-pair?
		prepared/load-pair?: load-pair?
		0
	]

	; Emits the analyzed instruction stream using the opcode-family handlers.
	emit-function-body: func [
		context [x64-function-context!]
		return: [integer!]
		/local task [codegen-task!]
			view [codegen-scratch!]
			state [machine-state!]
			prepared [x64-instruction-state! value]
			fn [rsir-function!]
			instruction [rsir-instruction!]
			instructions code [byte-ptr!]
			frame-extra allocation-size index [integer!]
			measure? [logic!]
			result [integer!]
		][
		; Open the records into locals once; the instruction-specific state stays
		; with the family emitters.
		task: context/task
		view: context/scratch
		state: context/state
		fn: task/fn
		instructions:        view/instructions
		code:               task/code

		measure?: null? code
		state/depth: 0
		state/location: LOCATION_NONE
		state/storage-slots: state/storage-base
		allocation-size: 0
		if not measure? [
			frame-extra: task/frame-size - x64-encoder/BASE_FRAME_SIZE
			if frame-extra < 0 [return INVALID_IR]
			allocation-size: x64-encoder/allocate-frame null 0 frame-extra
			if allocation-size < 0 [return OUTPUT_FULL]
		]
		prepared/allocation-size: allocation-size
		index: 1
		while [index <= fn/instruction-count][
			instruction: as rsir-instruction! (instructions
				+ ((index - 1) * RSIR_INSTRUCTION_SIZE))
			result: prepare-instruction context instruction index prepared
			if result = PREPARE_SKIPPED [
				index: index + prepared/advance
				continue
			]
			if result < 0 [return result]
			result: case [
				any [instruction/op = OP_LITERAL
					instruction/op = OP_CONSTANT
					instruction/op = OP_ADDRESS
					instruction/op = OP_LOAD
					instruction/op = OP_REFERENCE
					instruction/op = OP_INDEX
					instruction/op = OP_SET
					instruction/op = OP_MEMBER
					instruction/op = OP_TAG] [emit-value-operation context instruction index prepared]
				instruction/op = OP_CALL [emit-call-operation context instruction index prepared]
				any [instruction/op = OP_CAST
					instruction/op = OP_SIZE
					instruction/op = OP_NATIVE
					instruction/op = OP_DROP
					instruction/op = OP_DUPLICATE
					instruction/op = OP_UNARY
					instruction/op = OP_OVERFLOW
					instruction/op = OP_BINARY] [emit-arithmetic-operation context instruction index prepared]
				any [instruction/op = OP_CATCH
					instruction/op = OP_END_CATCH
					instruction/op = OP_THROW
					instruction/op = OP_JUMP
					instruction/op = OP_BRANCH
					instruction/op = OP_SWITCH
					instruction/op = OP_ENTRY
					instruction/op = OP_SUB_CALL
					instruction/op = OP_SUB_RETURN
					instruction/op = OP_FAIL
					instruction/op = OP_RETURN] [emit-control-operation context instruction index prepared]
				true [UNSUPPORTED]
			]
			if result < 0 [return result]
			index: index + prepared/advance
		]
		0
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

	; Claims the next table of the input: `count` rows of `row-size` bytes each,
	; starting where the previous table ended. Returns null when what is left of
	; the input cannot hold it.
	claim-table: func [
		ctx [x64-module-context!]
		count row-size [integer!]
		return: [byte-ptr!]
		/local table [byte-ptr!] bytes [integer!]
	][
		if count > (ctx/remaining / row-size)[return null]
		bytes: count * row-size
		table: ctx/cursor
		ctx/cursor: table + bytes
		ctx/remaining: ctx/remaining - bytes
		table
	]

	; Checks the arguments and the module header, then opens the input up for
	; the table phases that follow.
	validate-module-header: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!] data [byte-ptr!] size [integer!]
	][
		data: ctx/data
		size: ctx/size
		if any [
			null? data null? ctx/output size < RSIR_HEADER_SIZE ctx/capacity < 0
		][return INVALID_IR]
		unless any [ctx/opt-level = 0 ctx/opt-level = 2][return UNSUPPORTED]
		header: as rsir-header! data
		ctx/header: header
		if any [
			header/type-count < 0 header/import-count < 0 header/global-count < 0
			header/switch-count < 0 header/export-count < 0
			header/function-count <= 0 header/instruction-count <= 0
			header/module-kind < 1 header/module-kind > 4
			all [header/module-kind = 4 header/export-count = 0]
			all [header/module-kind <> 4 header/export-count <> 0]
		][return INVALID_IR]
		ctx/entry?: header/module-kind = 3
		if any [
			all [ctx/entry? any [header/entry-function <= 0
				header/entry-function > header/function-count]]
			all [not ctx/entry? header/entry-function <> 0]
		][return INVALID_IR]
		ctx/cursor: data + RSIR_HEADER_SIZE
		ctx/remaining: size - RSIR_HEADER_SIZE
		0
	]

	; Validates the type table and the member table its records size, filling in
	; the type table record every later type ref is resolved through.
	validate-module-types: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-type [rsir-type!]
			ir-member [rsir-member!]
			types members [byte-ptr!]
			id member-id member-count variable-mode [integer!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		types: claim-table ctx header/type-count RSIR_TYPE_SIZE
		if null? types [return INVALID_IR]
		; The layout cache lives in the scratch block, which cannot be sized
		; until the tables validate; until then layout-type runs unmemoized.
		table/types: types
		table/members: null
		table/type-count: header/type-count
		table/layouts: null
		table/member-offsets: null
		member-count: 0
		id: 1
		while [id <= header/type-count][
			ir-type: as rsir-type! (types + ((id - 1) * RSIR_TYPE_SIZE))
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
						not valid-type-ref? ir-type/target table][
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
							not valid-type-ref? ir-type/target table]
						all [
							(ir-type/flags and CATCH_FLAG) <> 0
							(ir-type/flags and CATCH_CONFLICT_FLAGS) <> 0
						]
					][return INVALID_IR]
				]
				ir-type/kind = -6 [
					if any [ir-type/flags <> 0 ir-type/member-count <> 0
						not valid-type-ref? ir-type/target table][
						return INVALID_IR
					]
				]
				ir-type/kind = -7 [
					if any [
						not valid-type-ref? ir-type/target table
						ir-type/member-count <= 0
						not any [ir-type/flags = 1 ir-type/flags = 2
							ir-type/flags = 4 ir-type/flags = 8]
					][return INVALID_IR]
				]
				ir-type/kind = -8 [
					if any [
						ir-type/flags <> 0
						ir-type/target <= 0
						not valid-type-ref? ir-type/target table
						(logical-kind ir-type/target table) <> -4
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
		members: claim-table ctx member-count RSIR_MEMBER_SIZE
		if null? members [return INVALID_IR]
		table/members: members
		id: 1
		while [id <= header/type-count][
			ir-type: as rsir-type! (types + ((id - 1) * RSIR_TYPE_SIZE))
			if ir-type/kind <> -7 [
				member-id: ir-type/first-member
				while [member-id < (ir-type/first-member + ir-type/member-count)][
					ir-member: as rsir-member! (members
						+ (member-id * RSIR_MEMBER_SIZE))
					if not valid-type-ref? ir-member/type table [
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
								not aggregate-ref? ir-member/type table
							]
						][return INVALID_IR]
					]
					member-id: member-id + 1
				]
			]
			id: id + 1
		]
		ctx/member-count: member-count
		0
	]

	; Validates the import, global, function and export tables, together with
	; the parameter, initializer and instruction counts they add up to.
	validate-module-symbols: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-import [rsir-import!]
			ir-global [rsir-global!]
			ir-function [rsir-function!]
			ir-export [rsir-export!]
			imports globals functions exports [byte-ptr!]
			id variable-mode next-parameter
			parameter-count initializer-count instruction-count [integer!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		imports: claim-table ctx header/import-count RSIR_IMPORT_SIZE
		if null? imports [return INVALID_IR]
		parameter-count: 0
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (imports + ((id - 1) * RSIR_IMPORT_SIZE))
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
				if any [not valid-type-ref? ir-import/type table
					ir-import/parameter-count <> 0][return INVALID_IR]
			][
				if any [
					(ir-import/flags and 3) = 0
					all [ir-import/type <> 0
						not valid-type-ref? ir-import/type table]
				][return INVALID_IR]
			]
			if parameter-count > (2147483647 - ir-import/parameter-count)[
				return INVALID_IR
			]
			parameter-count: parameter-count + ir-import/parameter-count
			id: id + 1
		]

		globals: claim-table ctx header/global-count RSIR_GLOBAL_SIZE
		if null? globals [return INVALID_IR]
		initializer-count: 0
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				not valid-type-ref? ir-global/type table
				ir-global/flags < 0 ir-global/flags > (INLINE or PROTECTED)
				all [(ir-global/flags and INLINE) <> 0
					not inline-object-ref? ir-global/type table]
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

		functions: claim-table ctx header/function-count RSIR_FUNCTION_SIZE
		if null? functions [return INVALID_IR]
		instruction-count: 0
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				all [ir-function/return-type <> 0
					not valid-type-ref? ir-function/return-type table]
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

		exports: claim-table ctx header/export-count RSIR_EXPORT_SIZE
		if null? exports [return INVALID_IR]
		id: 1
		while [id <= header/export-count][
			ir-export: as rsir-export! (exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				ir-export/symbol = 0
				all [ir-export/symbol > 0
					ir-export/symbol > header/function-count]
				all [ir-export/symbol < 0
					ir-export/symbol < (0 - header/global-count)]
			][return INVALID_IR]
			id: id + 1
		]

		module/imports: imports
		module/globals: globals
		module/functions: functions
		ctx/exports: exports
		ctx/parameter-count: parameter-count
		ctx/initializer-count: initializer-count
		0
	]

	; Validates the parameter table and the slice of it each callable declares.
	validate-module-parameters: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-import [rsir-import!]
			ir-function [rsir-function!]
			ir-parameter [rsir-parameter!]
			parameters imports functions [byte-ptr!]
			id parameter-id parameter-end parameter-count [integer!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		imports: module/imports
		functions: module/functions
		parameter-count: ctx/parameter-count
		parameters: claim-table ctx parameter-count RSIR_PARAMETER_SIZE
		if null? parameters [return INVALID_IR]
		id: 1
		while [id <= parameter-count][
			ir-parameter: as rsir-parameter! (parameters
				+ ((id - 1) * RSIR_PARAMETER_SIZE))
			if any [
				all [ir-parameter/type <> 0
					not valid-type-ref? ir-parameter/type table]
				ir-parameter/flags < 0 ir-parameter/flags > INLINE
				all [ir-parameter/flags = INLINE
					not aggregate-ref? ir-parameter/type table]
			][return INVALID_IR]
			id: id + 1
		]
		id: 1
		while [id <= header/import-count][
			ir-import: as rsir-import! (imports + ((id - 1) * RSIR_IMPORT_SIZE))
			parameter-id: ir-import/first-parameter
			parameter-end: parameter-id + ir-import/parameter-count
			while [parameter-id < parameter-end][
				ir-parameter: as rsir-parameter! (parameters
					+ (parameter-id * RSIR_PARAMETER_SIZE))
				if ir-parameter/type = 0 [return INVALID_IR]
				parameter-id: parameter-id + 1
			]
			id: id + 1
		]
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			parameter-id: ir-function/first-parameter
			parameter-end: ir-function/first-local
			while [parameter-id < parameter-end][
				ir-parameter: as rsir-parameter! (parameters
					+ (parameter-id * RSIR_PARAMETER_SIZE))
				if ir-parameter/type = 0 [return INVALID_IR]
				parameter-id: parameter-id + 1
			]
			id: id + 1
		]
		module/parameters: parameters
		0
	]

	; Validates the initializer table: one scalar or address value per ordinary
	; global, and a byte block or one value per item for an inline array.
	validate-module-initializers: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-global [rsir-global!]
			array-type [rsir-type!]
			initializer [rsir-initializer!]
			initializers globals types [byte-ptr!]
			id initializer-id base [integer!]
			array? [logic!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		types: table/types
		globals: module/globals
		initializers: claim-table ctx ctx/initializer-count RSIR_INITIALIZER_SIZE
		if null? initializers [return INVALID_IR]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			base: canonical-type ir-global/type table
			array?: all [
				(ir-global/flags and INLINE) <> 0
				base > 0
				(logical-kind base table) = -7
			]
			if all [array? ir-global/initializer-count = 0][return INVALID_IR]
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializers
					+ (ir-global/first-initializer * RSIR_INITIALIZER_SIZE))
				either array? [
					array-type: as rsir-type! (types
						+ ((base - 1) * RSIR_TYPE_SIZE))
					either initializer/kind = BYTES_INITIALIZER [
						if any [
							ir-global/initializer-count <> 1
							initializer/a < 0 initializer/c <> 0
							array-type/flags <> 1
							initializer/b <> array-type/member-count
							(canonical-type array-type/target table) <> -2
						][return INVALID_IR]
					][
						if ir-global/initializer-count <> array-type/member-count [
							return INVALID_IR
						]
						initializer-id: 0
						while [initializer-id < ir-global/initializer-count][
							initializer: as rsir-initializer! (initializers
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
											header/function-count globals table
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
								not machine-value? ir-global/type 0 table
							][return INVALID_IR]
						]
						initializer/kind = ADDRESS_INITIALIZER [
							if any [
								(ir-global/flags and INLINE) <> 0
								not valid-static-address-initializer? initializer
									ir-global/type id header/global-count
									header/function-count globals table
							][return INVALID_IR]
						]
						true [return INVALID_IR]
					]
				]
			]
			id: id + 1
		]
		ctx/initializers: initializers
		0
	]

	; Claims the switch, instruction and string areas, then checks every offset
	; into the string area the tables validated so far can hold.
	locate-module-strings: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			ir-global [rsir-global!]
			ir-import [rsir-import!]
			ir-export [rsir-export!]
			initializer [rsir-initializer!]
			switches instructions strings globals imports exports initializers [byte-ptr!]
			id strings-size export-names-size [integer!]
	][
		header: ctx/header
		module: ctx/module
		globals: module/globals
		imports: module/imports
		exports: ctx/exports
		initializers: ctx/initializers
		switches: claim-table ctx header/switch-count RSIR_SWITCH_SIZE
		if null? switches [return INVALID_IR]
		instructions: claim-table ctx header/instruction-count RSIR_INSTRUCTION_SIZE
		if null? instructions [return INVALID_IR]
		strings: ctx/cursor
		strings-size: ctx/remaining

		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializers
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
			ir-import: as rsir-import! (imports + ((id - 1) * RSIR_IMPORT_SIZE))
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
			ir-export: as rsir-export! (exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				ir-export/name < 0 ir-export/name-size <= 0
				ir-export/name-size > strings-size
				ir-export/name > (strings-size - ir-export/name-size)
				export-names-size > (2147483647 - ir-export/name-size)
			][return INVALID_IR]
			export-names-size: export-names-size + ir-export/name-size
			id: id + 1
		]

		module/switches: switches
		module/instructions: instructions
		module/strings: strings
		module/strings-size: strings-size
		module/function-count: header/function-count
		module/import-count: header/import-count
		module/global-count: header/global-count
		module/switch-count: header/switch-count
		module/instruction-count: header/instruction-count
		ctx/export-names-size: export-names-size
		0
	]

	; Sizes every global and seeds its image record with the alignment and size
	; the placement pass needs, and totals the global name area. The image
	; function records are cleared here so the same pass can count references
	; into them. Both areas double as scratch until the metadata is written.
	layout-module-globals: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-global [rsir-global!]
			image-function [codegen-function!]
			image-global [codegen-global!]
			image-functions image-globals globals [byte-ptr!]
			id capacity metadata-size strings-size
				global-size global-align global-names-size [integer!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		globals: module/globals
		strings-size: module/strings-size
		capacity: ctx/capacity
		image-functions: ctx/output + IMAGE_HEADER_SIZE
		image-globals: image-functions + (header/function-count * IMAGE_FUNCTION_SIZE)
		metadata-size: IMAGE_HEADER_SIZE + (header/function-count * IMAGE_FUNCTION_SIZE)
		if any [metadata-size < 0 metadata-size > capacity][return OUTPUT_FULL]
		if header/global-count > ((capacity - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return OUTPUT_FULL
		]
		global-names-size: 0
		ctx/rodata-size: 0
		ctx/data-size: BITMAP_SIZE
		ctx/global-reference-count: 0
		id: 1
		while [id <= header/function-count][
			image-function: as codegen-function! (image-functions
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			image-function/first-reference: 0
			image-function/reference-count: 0
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				ir-global/name < 0 ir-global/name-size < 0
				ir-global/name-size > strings-size
				ir-global/name > (strings-size - ir-global/name-size)
			][return INVALID_IR]
			global-size: 0
			global-align: 0
			unless layout-type ir-global/type ((ir-global/flags and INLINE) <> 0)
				table 0 :global-size :global-align [return INVALID_IR]
			if global-names-size > (2147483647 - ir-global/name-size) [
				return OUTPUT_FULL
			]
			image-global: as codegen-global! (image-globals
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
		ctx/global-names-size: global-names-size
		0
	]

	; Derives the ownership links between globals. A uniquely referenced
	; anonymous global is the static payload of the earlier pointer slot that
	; addresses it, so recording that relation lets the placement pass keep a
	; payload next to its owner without adding ownership records to RSIR. The
	; links are threaded through the image records the metadata pass overwrites
	; later: `name-size` holds the owner and `first-reference` and
	; `reference-count` the head and the next link of each owner's child list.
	link-anonymous-globals: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			ir-global target-global [rsir-global!]
			image-global target-image-global [codegen-global!]
			initializer [rsir-initializer!]
			image-globals globals initializers [byte-ptr!]
			id initializer-id owner [integer!]
	][
		header: ctx/header
		module: ctx/module
		globals: module/globals
		initializers: ctx/initializers
		image-globals: ctx/output + IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < ir-global/initializer-count][
				initializer: as rsir-initializer! (initializers
					+ ((ir-global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
				][
					target-image-global: as codegen-global! (image-globals
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
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < ir-global/initializer-count][
				initializer: as rsir-initializer! (initializers
					+ ((ir-global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = ADDRESS_INITIALIZER
					initializer/a = GLOBAL_ADDRESS
					initializer/b > id
				][
					target-global: as rsir-global! (globals
						+ ((initializer/b - 1) * RSIR_GLOBAL_SIZE))
					target-image-global: as codegen-global! (image-globals
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
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/first-reference: 0
			image-global/reference-count: 0
			id: id - 1
		]
		id: header/global-count
		while [id > 0][
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			owner: image-global/name-size
			if owner > 0 [
				target-image-global: as codegen-global! (image-globals
					+ ((owner - 1) * IMAGE_GLOBAL_SIZE))
				image-global/reference-count: target-image-global/first-reference
				target-image-global/first-reference: id
			]
			id: id - 1
		]
		0
	]

	; Places every global in the read-only or writable data area, walking each
	; owner tree so a payload lands next to the pointer that addresses it, then
	; counts the relocations the initializers need.
	place-module-globals: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			ir-global [rsir-global!]
			image-global target-image-global [codegen-global!]
			target-image-function [codegen-function!]
			initializer [rsir-initializer!]
			image-functions image-globals globals initializers [byte-ptr!]
			id initializer-id root current child placed status
				rodata-size data-size global-reference-count [integer!]
	][
		header: ctx/header
		module: ctx/module
		globals: module/globals
		initializers: ctx/initializers
		image-functions: ctx/output + IMAGE_HEADER_SIZE
		image-globals: image-functions + (header/function-count * IMAGE_FUNCTION_SIZE)
		rodata-size: ctx/rodata-size
		data-size: ctx/data-size
		placed: 0
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			if image-global/name-size = 0 [
				root: id
				current: id
				while [current > 0][
					image-global: as codegen-global! (image-globals
						+ ((current - 1) * IMAGE_GLOBAL_SIZE))
					status: place-global-data image-global :rodata-size :data-size
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
							image-global: as codegen-global! (image-globals
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
		ctx/rodata-size: rodata-size
		ctx/data-size: data-size
		if placed <> header/global-count [return INVALID_IR]
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/first-reference: 0
			image-global/reference-count: 0
			id: id + 1
		]
		global-reference-count: ctx/global-reference-count
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			initializer-id: 0
			while [initializer-id < ir-global/initializer-count][
				initializer: as rsir-initializer! (initializers
					+ ((ir-global/first-initializer + initializer-id)
						* RSIR_INITIALIZER_SIZE))
				if initializer/kind = ADDRESS_INITIALIZER [
					image-global: as codegen-global! (image-globals
						+ ((id - 1) * IMAGE_GLOBAL_SIZE))
					if image-global/data-offset > REFERENCE_OFFSET_MASK [return OUTPUT_FULL]
					case [
						initializer/a = GLOBAL_ADDRESS [
							target-image-global: as codegen-global! (image-globals
								+ ((initializer/b - 1) * IMAGE_GLOBAL_SIZE))
							if target-image-global/reference-count = 2147483647 [
								return OUTPUT_FULL
							]
							target-image-global/reference-count:
								target-image-global/reference-count + 1
						]
						initializer/a = FUNCTION_ADDRESS [
							target-image-function: as codegen-function! (image-functions
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
		ctx/global-reference-count: global-reference-count
		0
	]

	; Carves the one working allocation into every array the later phases and
	; the function passes read, and clears those whose missing entries have to
	; be told apart from a zero one.
	allocate-module-scratch: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			work [codegen-scratch!]
			task [codegen-task!]
			scratch argument-targets [byte-ptr!]
			import-refs layouts member-offsets [int-ptr!]
			id count scratch-count member-count parameter-count [integer!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		work: ctx/scratch
		task: ctx/task
		member-count: ctx/member-count
		parameter-count: ctx/parameter-count
		if header/function-count > ((2147483647 - header/import-count) / 6)[
			return OUTPUT_FULL
		]
		scratch-count: header/import-count + (header/function-count * 6)
		if header/instruction-count > ((2147483647 - scratch-count) / 18)[
			return OUTPUT_FULL
		]
		scratch-count: scratch-count + (header/instruction-count * 18)
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
		if scratch-count > ((2147483647 - header/instruction-count) / 4)[
			return OUTPUT_FULL
		]
		scratch: allocate ((scratch-count * 4) + header/instruction-count)
		if null? scratch [return OUTPUT_FULL]
		ctx/memory: scratch
		argument-targets: scratch + (scratch-count * 4)
		; The arrays are laid out in the order they are carved; the layout and
		; member-offset caches belong to the type table rather than the scratch
		; record, and the argument-target bytes trail the integer arrays.
		import-refs: as int-ptr! scratch
		work/import-refs:         import-refs
		work/instructions:        module/instructions
		work/argument-targets:    argument-targets
		work/function-sizes:      import-refs + header/import-count
		work/function-frames:     work/function-sizes + header/function-count
		work/function-outgoing:   work/function-frames + header/function-count
		work/function-effects:    work/function-outgoing + header/function-count
		work/instruction-offsets: work/function-effects + header/function-count
		work/relaxed-offsets:     work/instruction-offsets
			+ header/instruction-count + header/function-count
		work/instruction-depths:  work/relaxed-offsets
			+ header/instruction-count + header/function-count
		work/catch-depths:        work/instruction-depths + header/instruction-count
		work/control-uses:        work/catch-depths + header/instruction-count
		work/entry-types:         work/control-uses + header/instruction-count
		work/entry-flags:         work/entry-types + header/instruction-count
		work/entry-kinds:         work/entry-flags + header/instruction-count
		work/entry-tags:          work/entry-kinds + header/instruction-count
		work/stack-types:         work/entry-tags + header/instruction-count
		work/stack-flags:         work/stack-types + header/instruction-count
		work/stack-kinds:         work/stack-flags + header/instruction-count
		work/stack-tags:          work/stack-kinds + header/instruction-count
		work/tag-next:            work/stack-tags + header/instruction-count
		work/tag-slots:           work/tag-next + header/instruction-count
		work/tag-widths:          work/tag-slots + header/instruction-count
		work/result-offsets:      work/tag-widths + header/instruction-count
		work/storage-offsets:     work/result-offsets + header/instruction-count
		layouts: work/storage-offsets + parameter-count
		member-offsets: layouts + (header/type-count * 4)
		table/layouts: layouts
		table/member-offsets: member-offsets
		work/instruction-effects: member-offsets + member-count
		work/switch-effect-links: work/instruction-effects + header/instruction-count
		work/switch-effect-users: work/switch-effect-links + header/switch-count
		task/image-data: ctx/output + IMAGE_HEADER_SIZE
		id: 1
		while [id <= header/import-count][import-refs/id: 0 id: id + 1]
		count: header/type-count * 4
		id: 1
		while [id <= count][layouts/id: 0 id: id + 1]
		id: 1
		while [id <= member-count][member-offsets/id: -1 id: id + 1]
		id: 1
		while [id <= header/instruction-count][
			argument-targets/id: as byte! 0
			id: id + 1
		]
		0
	]

	; Infers the module effects, caches every declared type layout, then runs the
	; sizing pass: each function is compiled with no output slot, relaxed to its
	; short branch forms, and the resulting code, name and literal totals are
	; what the image layout is then computed from.
	measure-module-functions: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			work [codegen-scratch!]
			task [codegen-task!]
			ir-function [rsir-function!]
			functions instructions function-instructions [byte-ptr!]
			function-sizes function-frames function-outgoing instruction-effects
				instruction-offsets relaxed-offsets catch-depths control-uses [int-ptr!]
			id status next-instruction next-offset function-size strings-size
				global-size global-align function-names-size code-size
				literal-size entry-size [integer!]
			entry? current-entry? [logic!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		work: ctx/scratch
		task: ctx/task
		functions: module/functions
		instructions: module/instructions
		strings-size: module/strings-size
		entry?: ctx/entry?
		function-sizes: work/function-sizes
		function-frames: work/function-frames
		function-outgoing: work/function-outgoing
		instruction-effects: work/instruction-effects
		instruction-offsets: work/instruction-offsets
		relaxed-offsets: work/relaxed-offsets
		catch-depths: work/catch-depths
		control-uses: work/control-uses
		; Effect inference borrows later-phase arrays from this record for its
		; use lists and worklists; their permanent owners overwrite them later.
		status: infer-effects module work ctx/opt-level
		if status <> 0 [return status]
		id: 1
		while [id <= header/type-count][
			global-size: 0
			global-align: 0
			unless layout-type id true table 0 :global-size :global-align [
				return INVALID_IR
			]
			id: id + 1
		]

		function-names-size: 0
		code-size: 0
		entry-size: 0
		next-instruction: 1
		next-offset: 1
		; Sizing pass: no code is written, so the task carries no output slot.
		task/code: null
		task/references: null
		task/function-offset: 0
		task/function-code-size: 0
		task/capacity: 0
		task/exit-reference-id: 0
		task/global-reference-count: ctx/global-reference-count
		task/literal-size: 0
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				ir-function/name < 0 ir-function/name-size <= 0
				ir-function/name-size > strings-size
				ir-function/name > (strings-size - ir-function/name-size)
			][return INVALID_IR]
			function-instructions: instructions
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			current-entry?: all [entry? id = header/entry-function]
			task/fn: ir-function
			task/first-instruction: next-instruction
			task/first-offset: next-offset
			task/entry?: current-entry?
			function-size: compile-function module work task
			if function-size < 0 [return function-size]
			function-frames/id: task/frame-size
			function-outgoing/id: task/outgoing-size
			; Near forms are measured first, then every branch and jump whose
			; final distance fits one signed byte switches to its short form.
			status: relax-branches ir-function function-instructions
				(instruction-effects + (next-instruction - 1))
				(instruction-offsets + (next-offset - 1))
				(relaxed-offsets + (next-offset - 1))
				(catch-depths + (next-instruction - 1))
				(control-uses + (next-instruction - 1))
			if status < 0 [return INVALID_IR]
			if status > function-size [return INVALID_IR]
			function-size: function-size - status
			function-sizes/id: function-size
			if function-names-size > (2147483647 - ir-function/name-size)[
				return OUTPUT_FULL
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size)[return OUTPUT_FULL]
			code-size: code-size + function-size
			if current-entry? [entry-size: function-size]
			next-instruction: next-instruction + ir-function/instruction-count
			next-offset: next-offset + ir-function/instruction-count + 1
			id: id + 1
		]
		literal-size: task/literal-size
		if code-size > (2147483647 - literal-size)[return OUTPUT_FULL]
		ctx/global-reference-count: task/global-reference-count
		ctx/function-names-size: function-names-size
		ctx/function-code-size: code-size
		ctx/literal-size: literal-size
		ctx/entry-size: entry-size
		ctx/code-size: code-size + literal-size
		0
	]

	; Counts the imports the measured code actually calls, then derives the whole
	; image layout: the metadata block, the name area, and the aligned code,
	; read-only and writable data offsets the image is written at.
	plan-module-image: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			work [codegen-scratch!]
			ir-import [rsir-import!]
			import-refs [int-ptr!]
			imports [byte-ptr!]
			id count last-library used-import-count import-reference-count
				import-names-size import-count reference-count metadata-size
				names-size code-size rodata-size data-size [integer!]
			entry? [logic!]
	][
		header: ctx/header
		module: ctx/module
		work: ctx/scratch
		imports: module/imports
		import-refs: work/import-refs
		entry?: ctx/entry?
		code-size: ctx/code-size
		rodata-size: ctx/rodata-size
		data-size: ctx/data-size
		used-import-count: 0
		import-reference-count: 0
		import-names-size: 0
		last-library: -1
		id: 1
		while [id <= header/import-count][
			count: import-refs/id
			if count > 0 [
				ir-import: as rsir-import! (imports + ((id - 1) * RSIR_IMPORT_SIZE))
				used-import-count: used-import-count + 1
				if import-reference-count > (2147483647 - count)[return OUTPUT_FULL]
				import-reference-count: import-reference-count + count
				if ir-import/library <> last-library [
					if import-names-size > (2147483647 - ir-import/library-size)[
						return OUTPUT_FULL
					]
					import-names-size: import-names-size + ir-import/library-size
					last-library: ir-import/library
				]
				if import-names-size > (2147483647 - ir-import/external-size)[
					return OUTPUT_FULL
				]
				import-names-size: import-names-size + ir-import/external-size
			]
			id: id + 1
		]
		import-count: used-import-count
		reference-count: ctx/global-reference-count + import-reference-count
		if entry? [
			if any [import-count = 2147483647 reference-count = 2147483647][
				return OUTPUT_FULL
			]
			import-count: import-count + 1
			reference-count: reference-count + 1
		]

		metadata-size: IMAGE_HEADER_SIZE + (header/function-count * IMAGE_FUNCTION_SIZE)
		if header/global-count > ((2147483647 - metadata-size) / IMAGE_GLOBAL_SIZE)[
			return OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/global-count * IMAGE_GLOBAL_SIZE)
		if import-count > ((2147483647 - metadata-size) / IMAGE_IMPORT_SIZE)[
			return OUTPUT_FULL
		]
		metadata-size: metadata-size + (import-count * IMAGE_IMPORT_SIZE)
		if header/export-count > ((2147483647 - metadata-size) / IMAGE_EXPORT_SIZE)[
			return OUTPUT_FULL
		]
		metadata-size: metadata-size + (header/export-count * IMAGE_EXPORT_SIZE)
		if reference-count > ((2147483647 - metadata-size) / 4)[
			return OUTPUT_FULL
		]
		metadata-size: metadata-size + (reference-count * 4)
		names-size: ctx/function-names-size + ctx/global-names-size + import-names-size
		if names-size > (2147483647 - ctx/export-names-size)[return OUTPUT_FULL]
		names-size: names-size + ctx/export-names-size
		; The entry module reaches ExitProcess through one synthetic import whose
		; two names are the only ones not copied out of the input strings.
		if entry? [names-size: names-size + 23]
		if any [names-size < 0 metadata-size > (2147483647 - names-size - 15)][
			return OUTPUT_FULL
		]
		ctx/code-offset: align (metadata-size + names-size) 16
		if any [
			ctx/code-offset < 0
			ctx/code-offset > (2147483647 - code-size - 3)
		][return OUTPUT_FULL]
		ctx/rodata-offset: align (ctx/code-offset + code-size) 4
		if any [
			ctx/rodata-offset < 0
			ctx/rodata-offset > (2147483647 - rodata-size - 3)
		][return OUTPUT_FULL]
		ctx/data-offset: align (ctx/rodata-offset + rodata-size) 4
		if any [
			ctx/data-offset < 0
			ctx/data-offset > (2147483647 - data-size)
		][return OUTPUT_FULL]
		ctx/total-size: ctx/data-offset + data-size
		if ctx/total-size > ctx/capacity [return OUTPUT_FULL]
		ctx/import-count: import-count
		ctx/reference-count: reference-count
		ctx/metadata-size: metadata-size
		ctx/names-size: names-size
		0
	]

	; Writes the image header, then the function and global metadata together
	; with their names. Code offsets follow the measured sizes, with the entry
	; function first so it starts at offset zero.
	write-module-metadata: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			work [codegen-scratch!]
			image [codegen-header!]
			ir-function [rsir-function!]
			ir-global [rsir-global!]
			image-function [codegen-function!]
			image-global [codegen-global!]
			function-sizes function-frames [int-ptr!]
			output image-functions image-globals names functions globals strings [byte-ptr!]
			id count name-cursor code-cursor [integer!]
			entry? current-entry? [logic!]
	][
		header: ctx/header
		module: ctx/module
		work: ctx/scratch
		output: ctx/output
		functions: module/functions
		globals: module/globals
		strings: module/strings
		function-sizes: work/function-sizes
		function-frames: work/function-frames
		entry?: ctx/entry?
		image-functions: output + IMAGE_HEADER_SIZE
		image-globals: image-functions + (header/function-count * IMAGE_FUNCTION_SIZE)
		image: as codegen-header! output
		image/size: ctx/total-size
		image/module-kind: header/module-kind
		image/entry-function: header/entry-function
		image/function-count: header/function-count
		image/import-count: ctx/import-count
		image/reference-count: ctx/reference-count
		image/names-size: ctx/names-size
		image/code-offset: ctx/code-offset
		image/code-size: ctx/code-size
		image/data-size: ctx/data-size
		image/global-count: header/global-count
		image/rodata-size: ctx/rodata-size
		image/export-count: header/export-count

		names: output + ctx/metadata-size
		name-cursor: 0
		code-cursor: ctx/entry-size
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			image-function: as codegen-function! (image-functions
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
			copy-memory (names + name-cursor) (strings + ir-function/name)
				ir-function/name-size
			name-cursor: name-cursor + ir-function/name-size
			id: id + 1
		]

		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			image-global/name: name-cursor
			image-global/name-size: ir-global/name-size
			copy-memory (names + name-cursor)
				(strings + ir-global/name) ir-global/name-size
			name-cursor: name-cursor + ir-global/name-size
			id: id + 1
		]
		ctx/names: names
		ctx/name-cursor: name-cursor
		0
	]

	; Hands every function, global and used import a slice of the reference
	; table, and writes the import metadata and library names alongside. The
	; per-function reference counts are cleared so the emitting pass can refill
	; them as it hands out slots; `import-refs` becomes the first slot of each
	; import rather than its count.
	assign-module-references: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			work [codegen-scratch!]
			task [codegen-task!]
			ir-import [rsir-import!]
			image-function [codegen-function!]
			image-global [codegen-global!]
			image-import [codegen-import!]
			import-refs [int-ptr!]
			output image-functions image-globals image-imports names imports strings [byte-ptr!]
			id count first-reference name-cursor output-import-id last-library
				library-offset external-offset exit-reference-id [integer!]
			entry? [logic!]
	][
		header: ctx/header
		module: ctx/module
		work: ctx/scratch
		task: ctx/task
		output: ctx/output
		imports: module/imports
		strings: module/strings
		names: ctx/names
		name-cursor: ctx/name-cursor
		import-refs: work/import-refs
		entry?: ctx/entry?
		image-functions: output + IMAGE_HEADER_SIZE
		image-globals: image-functions + (header/function-count * IMAGE_FUNCTION_SIZE)
		image-imports: image-globals + (header/global-count * IMAGE_GLOBAL_SIZE)
		ctx/references: as int-ptr! (image-imports
			+ (ctx/import-count * IMAGE_IMPORT_SIZE)
			+ (header/export-count * IMAGE_EXPORT_SIZE))
		first-reference: 1
		id: 1
		while [id <= header/function-count][
			image-function: as codegen-function! (image-functions
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			count: image-function/reference-count
			image-function/first-reference: either count > 0 [first-reference][0]
			first-reference: first-reference + count
			image-function/reference-count: 0
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			image-global: as codegen-global! (image-globals
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
				ir-import: as rsir-import! (imports + ((id - 1) * RSIR_IMPORT_SIZE))
				if ir-import/library <> last-library [
					library-offset: name-cursor
					copy-memory (names + name-cursor)
						(strings + ir-import/library) ir-import/library-size
					name-cursor: name-cursor + ir-import/library-size
					last-library: ir-import/library
				]
				external-offset: name-cursor
				copy-memory (names + name-cursor)
					(strings + ir-import/external) ir-import/external-size
				name-cursor: name-cursor + ir-import/external-size
				image-import: as codegen-import! (image-imports
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

		; The two synthetic ExitProcess names sit at the end of the name area,
		; where the export names of a shared library would otherwise be; an entry
		; module never has any.
		if entry? [
			image-import: as codegen-import! (image-imports
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
			copy-memory (names + library-offset) (as byte-ptr! "kernel32.dll") 12
			copy-memory (names + external-offset) (as byte-ptr! "ExitProcess") 11
		]
		task/exit-reference-id: exit-reference-id
		ctx/name-cursor: name-cursor
		0
	]

	; Writes the export metadata and names, and clears the gap between the end of
	; the name area and the aligned start of the code.
	write-module-exports: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			ir-export [rsir-export!]
			image-export [codegen-export!]
			output image-exports names strings exports cursor finish [byte-ptr!]
			id name-cursor [integer!]
	][
		header: ctx/header
		module: ctx/module
		output: ctx/output
		exports: ctx/exports
		strings: module/strings
		names: ctx/names
		name-cursor: ctx/name-cursor
		image-exports: output + IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
			+ (header/global-count * IMAGE_GLOBAL_SIZE)
			+ (ctx/import-count * IMAGE_IMPORT_SIZE)
		id: 1
		while [id <= header/export-count][
			ir-export: as rsir-export! (exports + ((id - 1) * RSIR_EXPORT_SIZE))
			image-export: as codegen-export! (image-exports
				+ ((id - 1) * IMAGE_EXPORT_SIZE))
			image-export/symbol: ir-export/symbol
			image-export/name: name-cursor
			image-export/name-size: ir-export/name-size
			copy-memory (names + name-cursor)
				(strings + ir-export/name) ir-export/name-size
			name-cursor: name-cursor + ir-export/name-size
			id: id + 1
		]
		ctx/name-cursor: name-cursor
		cursor: names + ctx/names-size
		finish: output + ctx/code-offset
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
		0
	]

	; Replays the measured tasks with an output slot this time, appends the string
	; literals the code refers to, and clears the alignment gaps and the writable
	; data area the static initializers are then written into.
	emit-module-code: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			work [codegen-scratch!]
			task [codegen-task!]
			ir-function [rsir-function!]
			image-function [codegen-function!]
			function-frames function-outgoing [int-ptr!]
			output image-functions code strings cursor finish
				rodata-output data-output [byte-ptr!]
			id written next-instruction next-offset function-code-size [integer!]
			entry? current-entry? [logic!]
	][
		header: ctx/header
		module: ctx/module
		work: ctx/scratch
		task: ctx/task
		output: ctx/output
		strings: module/strings
		function-frames: work/function-frames
		function-outgoing: work/function-outgoing
		entry?: ctx/entry?
		function-code-size: ctx/function-code-size
		image-functions: output + IMAGE_HEADER_SIZE
		code: output + ctx/code-offset
		next-instruction: 1
		next-offset: 1
		; Emitting pass: same tasks replayed, now with a slot to write into.
		task/references: ctx/references
		task/function-code-size: function-code-size
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (module/functions
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			image-function: as codegen-function! (image-functions
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			current-entry?: all [entry? id = header/entry-function]
			task/fn: ir-function
			task/first-instruction: next-instruction
			task/first-offset: next-offset
			task/entry?: current-entry?
			task/code: code + image-function/code-offset
			task/function-offset: image-function/code-offset
			task/capacity: image-function/code-size
			task/frame-size: function-frames/id
			task/outgoing-size: function-outgoing/id
			written: compile-function module work task
			if written < 0 [return written]
			if written <> image-function/code-size [return INVALID_IR]
			next-instruction: next-instruction + ir-function/instruction-count
			next-offset: next-offset + ir-function/instruction-count + 1
			id: id + 1
		]

		if ctx/literal-size > 0 [
			copy-memory (code + function-code-size) strings ctx/literal-size
		]
		cursor: code + ctx/code-size
		rodata-output: output + ctx/rodata-offset
		while [cursor < rodata-output][cursor/1: as byte! 0 cursor: cursor + 1]
		finish: rodata-output + ctx/rodata-size
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
		data-output: output + ctx/data-offset
		while [cursor < data-output][cursor/1: as byte! 0 cursor: cursor + 1]
		finish: data-output + ctx/data-size
		cursor: data-output
		while [cursor < finish][cursor/1: as byte! 0 cursor: cursor + 1]
		0
	]

	; Writes the static initializer bytes of every global into the read-only or
	; writable data area, filling in one tagged reference-table entry for each
	; address initializer so the linker can relocate it.
	write-module-data: func [
		ctx [x64-module-context!]
		return: [integer!]
		/local header [rsir-header!]
			module [rsir-module!]
			table [type-table!]
			ir-global [rsir-global!]
			array-type [rsir-type!]
			initializer [rsir-initializer!]
			image-global target-image-global [codegen-global!]
			target-image-function [codegen-function!]
			references [int-ptr!]
			output image-functions image-globals globals initializers types strings
				rodata-output data-output cursor [byte-ptr!]
			id initializer-id base slot-width item-offset reference-id
				global-offset [integer!]
			array? [logic!]
	][
		header: ctx/header
		module: ctx/module
		table: module/table
		output: ctx/output
		types: table/types
		globals: module/globals
		strings: module/strings
		initializers: ctx/initializers
		references: ctx/references
		image-functions: output + IMAGE_HEADER_SIZE
		image-globals: image-functions + (header/function-count * IMAGE_FUNCTION_SIZE)
		rodata-output: output + ctx/rodata-offset
		data-output: output + ctx/data-offset
		id: 1
		while [id <= header/global-count][
			ir-global: as rsir-global! (globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			image-global: as codegen-global! (image-globals
				+ ((id - 1) * IMAGE_GLOBAL_SIZE))
			either (image-global/flags and PROTECTED) <> 0 [
				cursor: rodata-output + image-global/data-offset
			][
				cursor: data-output + image-global/data-offset
			]
			base: canonical-type ir-global/type table
			array?: all [
				(ir-global/flags and INLINE) <> 0
				base > 0
				(logical-kind base table) = -7
			]
			slot-width: image-global/data-size
			if array? [
				array-type: as rsir-type! (types + ((base - 1) * RSIR_TYPE_SIZE))
				slot-width: array-type/flags
			]
			if ir-global/initializer-count > 0 [
				initializer: as rsir-initializer! (initializers
					+ (ir-global/first-initializer * RSIR_INITIALIZER_SIZE))
				either initializer/kind = BYTES_INITIALIZER [
					copy-memory cursor (strings + initializer/a) initializer/b
				][
					initializer-id: 0
					item-offset: 0
					while [initializer-id < ir-global/initializer-count][
						initializer: as rsir-initializer! (initializers
							+ ((ir-global/first-initializer + initializer-id)
								* RSIR_INITIALIZER_SIZE))
						case [
							initializer/kind = SCALAR_INITIALIZER [
								unless write-static-scalar (cursor + item-offset)
									slot-width initializer/a initializer/b [
									return INVALID_IR
								]
							]
							initializer/kind = ADDRESS_INITIALIZER [
								reference-id: 0
								case [
									initializer/a = GLOBAL_ADDRESS [
										target-image-global: as codegen-global! (image-globals
											+ ((initializer/b - 1) * IMAGE_GLOBAL_SIZE))
										reference-id: target-image-global/first-reference
											+ target-image-global/reference-count
										target-image-global/reference-count:
											target-image-global/reference-count + 1
									]
									initializer/a = FUNCTION_ADDRESS [
										target-image-function: as codegen-function! (image-functions
											+ ((initializer/b - 1) * IMAGE_FUNCTION_SIZE))
										reference-id: target-image-function/first-reference
											+ target-image-function/reference-count
										target-image-function/reference-count:
											target-image-function/reference-count + 1
									]
									true [return INVALID_IR]
								]
								global-offset: image-global/data-offset + item-offset
								if global-offset > REFERENCE_OFFSET_MASK [
									return OUTPUT_FULL
								]
								references/reference-id: either
									(image-global/flags and PROTECTED) <> 0 [
										RODATA_REFERENCE_TAG or global-offset
									][DATA_REFERENCE_TAG or global-offset]
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

	; Generates a Windows x64 image for one RSIR module, returning the number of
	; bytes written to `output` or a negative error code. The phases run in the
	; order the image is laid out: the input tables are validated and claimed
	; first, then the static data is placed and the code measured, and only then
	; is anything written, because every offset in the image depends on totals
	; the measuring pass produces. One scratch block and one signature cache
	; serve the whole module, and both are released on every exit.
	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local ctx [x64-module-context! value]
			signature-cache [signature-pairs! value]
			table [type-table! value]
			ir-module [rsir-module! value]
			work [codegen-scratch! value]
			task [codegen-task! value]
			status [integer!]
	][
		signature-cache/memory: null
		table/signatures: signature-cache
		ir-module/table: table
		ctx/module: ir-module
		ctx/scratch: work
		ctx/task: task
		ctx/data: data
		ctx/size: size
		ctx/output: output
		ctx/capacity: capacity
		ctx/opt-level: opt-level
		ctx/memory: null
		status: validate-module-header ctx
		if status = 0 [status: validate-module-types ctx]
		if status = 0 [status: validate-module-symbols ctx]
		if status = 0 [status: validate-module-parameters ctx]
		if status = 0 [status: validate-module-initializers ctx]
		if status = 0 [status: locate-module-strings ctx]
		if status = 0 [status: layout-module-globals ctx]
		if status = 0 [status: link-anonymous-globals ctx]
		if status = 0 [status: place-module-globals ctx]
		if status = 0 [status: allocate-module-scratch ctx]
		if status = 0 [status: measure-module-functions ctx]
		if status = 0 [status: plan-module-image ctx]
		if status = 0 [status: write-module-metadata ctx]
		if status = 0 [status: assign-module-references ctx]
		if status = 0 [status: write-module-exports ctx]
		if status = 0 [status: emit-module-code ctx]
		if status = 0 [status: write-module-data ctx]
		if status = 0 [status: ctx/total-size]
		release ctx/memory signature-cache status
	]
]
