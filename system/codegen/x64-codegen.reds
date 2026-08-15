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

	generate: func [
		data [byte-ptr!]
		size [integer!]
		output [byte-ptr!]
		capacity opt-level [integer!]
		return: [integer!]
		/local header [rsir-header!]
			ir-function [rsir-function!]
			instruction next-instruction [rsir-instruction!]
			image [codegen-header!]
			image-function [codegen-function!]
			image-import [codegen-import!]
			references [int-ptr!]
			function-data instruction-data strings name names-output code data-output
				cursor finish [byte-ptr!]
			instruction-bytes strings-start expected-size metadata-size names-size
			code-offset code-size data-offset total-size encoded literal exit-reference
			library-offset external-offset [integer!]
			entry? result? [logic!]
	][
		if any [null? data null? output size < RSIR_HEADER_SIZE capacity < 0][
			return INVALID_IR
		]
		if any [opt-level < 0 opt-level > 1][return UNSUPPORTED]

		header: as rsir-header! data
		if any [
			header/size <> size
			header/function-count <> 1
			header/instruction-count <= 0
			header/strings-size < 0
		][return INVALID_IR]
		if any [header/module-kind < 1 header/module-kind > 3][return INVALID_IR]
		entry?: header/module-kind = 3
		if any [
			all [entry? header/entry-function <> 1]
			all [not entry? header/entry-function <> 0]
		][
			return INVALID_IR
		]

		instruction-bytes: header/instruction-count * RSIR_INSTRUCTION_SIZE
		if instruction-bytes < 0 [return INVALID_IR]
		strings-start: RSIR_HEADER_SIZE + RSIR_FUNCTION_SIZE + instruction-bytes
		if strings-start < 0 [return INVALID_IR]
		expected-size: strings-start + header/strings-size
		if expected-size <> size [return INVALID_IR]
		if header/module-name-size < 0 [return INVALID_IR]
		if header/module-name-size > 0 [
			if any [
				header/module-name < 0
				header/module-name > (header/strings-size - header/module-name-size)
			][return INVALID_IR]
		]

		function-data: data + RSIR_HEADER_SIZE
		instruction-data: function-data + RSIR_FUNCTION_SIZE
		strings: data + strings-start
		ir-function: as rsir-function! function-data
		if any [
			ir-function/name < 0
			ir-function/name-size <= 0
			ir-function/name-size > header/strings-size
			ir-function/name > (header/strings-size - ir-function/name-size)
			ir-function/first-instruction <> 1
			ir-function/instruction-count <> header/instruction-count
			ir-function/flags <> 0
		][return INVALID_IR]

		instruction: as rsir-instruction! instruction-data
		result?: false
		literal: 0
		case [
			all [
				ir-function/return-type = 0
				header/instruction-count = 1
				instruction/opcode = 2
				instruction/value-type = 0
				instruction/result = 0
				instruction/operand = 0
				instruction/immediate = 0
			][result?: false]
			all [
				ir-function/return-type = 1
				header/instruction-count = 2
				instruction/opcode = 1
				instruction/value-type = 1
				instruction/result = 1
				instruction/operand = 0
			][
				next-instruction: as rsir-instruction!
					(instruction-data + RSIR_INSTRUCTION_SIZE)
				unless all [
					next-instruction/opcode = 2
					next-instruction/value-type = 1
					next-instruction/result = 0
					next-instruction/operand = 1
					next-instruction/immediate = 0
				][return INVALID_IR]
				result?: true
				literal: instruction/immediate
			]
			true [return UNSUPPORTED]
		]

		code-size: case [
			all [entry? result?] [x64-encoder/I32_ENTRY_SIZE]
			entry? [x64-encoder/VOID_ENTRY_SIZE]
			result? [x64-encoder/I32_SIZE]
			true [x64-encoder/VOID_SIZE]
		]
		exit-reference: case [
			all [entry? result?] [x64-encoder/I32_EXIT_REF]
			entry? [x64-encoder/VOID_EXIT_REF]
			true [0]
		]
		metadata-size: IMAGE_HEADER_SIZE + IMAGE_FUNCTION_SIZE
		if entry? [metadata-size: metadata-size + IMAGE_IMPORT_SIZE + 4]
		names-size: ir-function/name-size
		if entry? [names-size: names-size + 23]
		code-offset: align (metadata-size + names-size) 16
		data-offset: align (code-offset + code-size) 4
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
		image/entry-function: either entry? [1][0]
		image/function-count: 1
		image/import-count: either entry? [1][0]
		image/reference-count: either entry? [1][0]
		image/names-size: names-size
		image/code-offset: code-offset
		image/code-size: code-size
		image/data-size: BITMAP_SIZE

		image-function: as codegen-function! (output + IMAGE_HEADER_SIZE)
		image-function/name: 0
		image-function/name-size: ir-function/name-size
		image-function/code-offset: 0
		image-function/code-size: code-size
		image-function/frame-size: x64-encoder/FRAME_SIZE
		image-function/bitmap-offset: 0
		image-function/bitmap-size: BITMAP_SIZE
		image-function/first-reference: 0
		image-function/reference-count: 0

		if entry? [
			image-import: as codegen-import!
				(output + IMAGE_HEADER_SIZE + IMAGE_FUNCTION_SIZE)
			library-offset: ir-function/name-size
			external-offset: library-offset + 12
			image-import/library: library-offset
			image-import/library-size: 12
			image-import/external: external-offset
			image-import/external-size: 11
			image-import/first-reference: 1
			image-import/reference-count: 1
			references: as int-ptr!
				(output + IMAGE_HEADER_SIZE + IMAGE_FUNCTION_SIZE + IMAGE_IMPORT_SIZE)
			references/1: exit-reference
		]

		name: strings + ir-function/name
		names-output: output + metadata-size
		copy-memory names-output name ir-function/name-size
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
		encoded: x64-encoder/encode code code-size entry? result? literal 0
		if encoded <> code-size [return OUTPUT_FULL]
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
