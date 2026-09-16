Red/System [
	Title: "Hybrid codegen failure diagnostics"
	File:  %codegen-diag.reds
]

; Every code generator failure point returns through this module instead of
; returning a bare status constant. The reported site number is stable for the
; lifetime of the file, and the site name is written verbatim at the failing
; return, so grepping the printed name jumps straight to the offending line.
;
; The recorded IR context (function index, instruction index, opcode) is filled
; in by the generator loops, so a failure also answers which construct was being
; compiled, not only which source line rejected it.

codegen-diag: context [
	FILE_X64:    1
	FILE_ARM64:  2
	FILE_READER: 3

	status:            0
	site:              0
	site-file:         0
	name:              "unrecorded"
	function-index:    0
	instruction-index: 0
	op:                0

	file-text: func [id [integer!] return: [c-string!]][
		case [
			id = FILE_X64   ["x64-codegen.reds"]
			id = FILE_ARM64 ["arm64-codegen.reds"]
			true            ["codegen-rsir-reader.reds"]
		]
	]

	status-text: func [code [integer!] return: [c-string!]][
		case [
			code = -1 ["INVALID_IR"]
			code = -2 ["UNSUPPORTED"]
			true      ["OUTPUT_FULL"]
		]
	]

	fail: func [
		code file-id site-id [integer!]
		site-name [c-string!]
		return: [integer!]
		/local kind source [c-string!]
	][
		status: code
		site-file: file-id
		site: site-id
		name: site-name
		kind: status-text code
		source: file-text file-id
		print ["*** codegen " kind " site " site-id " (" site-name ") in " source
			" function=" function-index " instruction=" instruction-index
			" op=" op lf]
		code
	]

	mark-function: func [fn-index [integer!]][
		function-index: fn-index
		instruction-index: 0
		op: 0
	]

	mark-instruction: func [instruction opcode [integer!]][
		instruction-index: instruction
		op: opcode
	]

	reset: func [][
		status: 0
		site: 0
		site-file: 0
		name: "unrecorded"
		function-index: 0
		instruction-index: 0
		op: 0
	]
]
