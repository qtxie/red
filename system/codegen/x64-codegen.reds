Red/System [
	Title: "Compact RSIR to Windows x64 code generator"
	File:  %x64-codegen.reds
]

#include %x64-encoder.reds

rsir-header!: alias struct! [
	size             [integer!]
	module-kind      [integer!]
	entry-function   [integer!]
	module-name      [integer!]
	module-name-size [integer!]
	function-count   [integer!]
	instruction-count [integer!]
	strings-size     [integer!]
]

rsir-function!: alias struct! [
	name              [integer!]
	name-size         [integer!]
	return-type       [integer!]
	first-instruction [integer!]
	instruction-count [integer!]
	flags             [integer!]
]

rsir-instruction!: alias struct! [
	opcode     [integer!]
	value-type [integer!]
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
	RSIR_HEADER_SIZE:      32
	RSIR_FUNCTION_SIZE:    24
	RSIR_INSTRUCTION_SIZE: 20

	IMAGE_HEADER_SIZE:   40
	IMAGE_FUNCTION_SIZE: 36
	IMAGE_IMPORT_SIZE:   24
	BITMAP_SIZE:         16

	INVALID_IR:   -1
	UNSUPPORTED:  -2
	OUTPUT_FULL: -3

	align: func [value boundary [integer!] return: [integer!]
		/local remainder [integer!]
	][
		remainder: value // boundary
		either remainder = 0 [value][value + (boundary - remainder)]
	]

	shape-of: func [
		fn [rsir-function!]
		instructions [byte-ptr!]
		function-count [integer!]
		return: [integer!]
		/local instruction terminator [rsir-instruction!]
	][
		instruction: as rsir-instruction! instructions
		case [
			all [
				fn/return-type = 0
				fn/instruction-count = 1
				instruction/opcode = 2
				instruction/value-type = 0
				instruction/result = 0
				instruction/operand = 0
				instruction/immediate = 0
			][x64-encoder/VOID]
			all [
				fn/return-type = 1
				fn/instruction-count = 2
			][
				terminator: as rsir-instruction!
					(instructions + RSIR_INSTRUCTION_SIZE)
				unless all [
					terminator/opcode = 2
					terminator/value-type = 1
					terminator/result = 0
					terminator/operand = 1
					terminator/immediate = 0
				][return INVALID_IR]
				case [
					all [
						instruction/opcode = 1
						instruction/value-type = 1
						instruction/result = 1
						instruction/operand = 0
					][x64-encoder/I32_LITERAL]
					all [
						instruction/opcode = 3
						instruction/value-type = 1
						instruction/result = 1
						instruction/operand > 0
						instruction/operand <= function-count
						instruction/immediate = 0
					][x64-encoder/I32_CALL]
					true [UNSUPPORTED]
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
			shape = x64-encoder/VOID [x64-encoder/VOID_SIZE]
			shape = x64-encoder/I32_LITERAL [x64-encoder/I32_SIZE]
			shape = x64-encoder/I32_CALL [x64-encoder/CALL_SIZE]
			true [-1]
		]
	]

	exit-reference: func [shape [integer!] return: [integer!]][
		case [
			shape = x64-encoder/VOID [x64-encoder/VOID_EXIT_REF]
			shape = x64-encoder/I32_LITERAL [x64-encoder/I32_EXIT_REF]
			shape = x64-encoder/I32_CALL [x64-encoder/CALL_EXIT_REF]
			true [-1]
		]
	]

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local header [rsir-header!]
			ir-function callee-function [rsir-function!]
			instruction [rsir-instruction!]
			image [codegen-header!]
			image-function callee-record [codegen-function!]
			image-import [codegen-import!]
			references [int-ptr!]
			function-data instruction-data function-instructions strings name
				names-output code data-output
				cursor finish [byte-ptr!]
			function-bytes instruction-bytes strings-start metadata-size
				names-size function-names-size code-offset code-size data-offset total-size
				id record-offset next-instruction function-size entry-size code-cursor
				name-cursor shape entry-shape encoded value target relative
				library-offset external-offset [integer!]
			entry? current-entry? [logic!]
	][
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		if any [opt-level < 0 opt-level > 1][return UNSUPPORTED]

		header: as rsir-header! data
		if any [
			header/size <> size
			header/function-count <= 0
			header/instruction-count <= 0
			header/strings-size < 0
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

		if header/function-count > ((size - RSIR_HEADER_SIZE) / RSIR_FUNCTION_SIZE) [
			return INVALID_IR
		]
		function-bytes: header/function-count * RSIR_FUNCTION_SIZE
		if header/instruction-count > (
			(size - RSIR_HEADER_SIZE - function-bytes) / RSIR_INSTRUCTION_SIZE
		)[return INVALID_IR]
		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		strings-start: RSIR_HEADER_SIZE + function-bytes + instruction-bytes
		if strings-start < 0 [return INVALID_IR]
		if header/strings-size <> (size - strings-start) [return INVALID_IR]
		if header/module-name-size < 0 [return INVALID_IR]
		if header/module-name-size > 0 [
			if any [
				header/module-name < 0
				header/module-name > (header/strings-size - header/module-name-size)
			][return INVALID_IR]
		]

		function-data: data + RSIR_HEADER_SIZE
		instruction-data: function-data + function-bytes
		strings: data + strings-start

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
				ir-function/name-size > header/strings-size
				ir-function/name > (header/strings-size - ir-function/name-size)
				ir-function/first-instruction <> next-instruction
				ir-function/instruction-count <= 0
				ir-function/instruction-count > (
					header/instruction-count - next-instruction + 1
				)
				ir-function/flags <> 0
			][return INVALID_IR]
			function-instructions: instruction-data
				+ ((next-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			shape: shape-of ir-function function-instructions header/function-count
			if shape < 0 [return shape]
			if shape = x64-encoder/I32_CALL [
				instruction: as rsir-instruction! function-instructions
				callee-function: as rsir-function! (function-data
					+ ((instruction/operand - 1) * RSIR_FUNCTION_SIZE))
				if callee-function/return-type <> 1 [return INVALID_IR]
			]
			current-entry?: all [entry? id = header/entry-function]
			function-size: machine-size current-entry? shape
			if function-size < 0 [return UNSUPPORTED]
			if function-names-size > (2147483647 - ir-function/name-size) [
				return INVALID_IR
			]
			function-names-size: function-names-size + ir-function/name-size
			if code-size > (2147483647 - function-size) [return INVALID_IR]
			code-size: code-size + function-size
			if current-entry? [
				entry-size: function-size
				entry-shape: shape
			]
			next-instruction: next-instruction + ir-function/instruction-count
			id: id + 1
		]
		if next-instruction <> (header/instruction-count + 1) [return INVALID_IR]
		if all [entry? entry-shape < 0][return INVALID_IR]

		either entry? [
			if header/function-count > (
				(2147483647 - IMAGE_HEADER_SIZE - IMAGE_IMPORT_SIZE - 4)
				/ IMAGE_FUNCTION_SIZE
			)[return OUTPUT_FULL]
		][
			if header/function-count > (
				(2147483647 - IMAGE_HEADER_SIZE) / IMAGE_FUNCTION_SIZE
			)[return OUTPUT_FULL]
		]
		metadata-size: IMAGE_HEADER_SIZE
			+ (header/function-count * IMAGE_FUNCTION_SIZE)
		if entry? [metadata-size: metadata-size + IMAGE_IMPORT_SIZE + 4]
		names-size: function-names-size
		if entry? [
			if names-size > (2147483647 - 23) [return OUTPUT_FULL]
			names-size: names-size + 23
		]
		if metadata-size > (2147483647 - names-size - 15) [return OUTPUT_FULL]
		code-offset: align (metadata-size + names-size) 16
		if code-offset > (2147483647 - code-size - 3) [return OUTPUT_FULL]
		data-offset: align (code-offset + code-size) 4
		if data-offset > (2147483647 - BITMAP_SIZE) [return OUTPUT_FULL]
		total-size: data-offset + BITMAP_SIZE
		if any [
			metadata-size < 0
			names-size < 0
			code-offset < 0
			data-offset < 0
			total-size < 0
			total-size > capacity
		][return OUTPUT_FULL]

		image: as codegen-header! output
		image/size: total-size
		image/module-kind: header/module-kind
		image/entry-function: header/entry-function
		image/function-count: header/function-count
		image/import-count: either entry? [1][0]
		image/reference-count: either entry? [1][0]
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
			function-instructions: instruction-data
				+ ((ir-function/first-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			shape: shape-of ir-function function-instructions header/function-count
			current-entry?: all [entry? id = header/entry-function]
			function-size: machine-size current-entry? shape
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			image-function/name: name-cursor
			image-function/name-size: ir-function/name-size
			image-function/code-offset: either current-entry? [0][code-cursor]
			image-function/code-size: function-size
			image-function/frame-size: x64-encoder/FRAME_SIZE
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

		if entry? [
			image-import: as codegen-import!
				(output + IMAGE_HEADER_SIZE
					+ (header/function-count * IMAGE_FUNCTION_SIZE))
			library-offset: function-names-size
			external-offset: library-offset + 12
			image-import/library: library-offset
			image-import/library-size: 12
			image-import/external: external-offset
			image-import/external-size: 11
			image-import/first-reference: 1
			image-import/reference-count: 1
			references: as int-ptr!
				(output + IMAGE_HEADER_SIZE
					+ (header/function-count * IMAGE_FUNCTION_SIZE)
					+ IMAGE_IMPORT_SIZE)
			references/1: exit-reference entry-shape
		]

		if entry? [
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
		id: 1
		while [id <= header/function-count][
			ir-function: as rsir-function! (function-data
				+ ((id - 1) * RSIR_FUNCTION_SIZE))
			function-instructions: instruction-data
				+ ((ir-function/first-instruction - 1) * RSIR_INSTRUCTION_SIZE)
			instruction: as rsir-instruction! function-instructions
			shape: shape-of ir-function function-instructions header/function-count
			image-function: as codegen-function! (output + IMAGE_HEADER_SIZE
				+ ((id - 1) * IMAGE_FUNCTION_SIZE))
			value: case [
				shape = x64-encoder/I32_LITERAL [instruction/immediate]
				shape = x64-encoder/I32_CALL [
					target: instruction/operand
					callee-record: as codegen-function! (output + IMAGE_HEADER_SIZE
						+ ((target - 1) * IMAGE_FUNCTION_SIZE))
					relative: callee-record/code-offset
						- (image-function/code-offset + x64-encoder/CALL_NEXT)
					relative
				]
				true [0]
			]
			current-entry?: all [entry? id = header/entry-function]
			encoded: x64-encoder/encode
				(code + image-function/code-offset)
				image-function/code-size current-entry? shape value 0
			if encoded <> image-function/code-size [return OUTPUT_FULL]
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
		total-size
	]
]
