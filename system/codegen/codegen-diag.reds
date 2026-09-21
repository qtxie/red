Red/System [
	Title: "Hybrid codegen failure diagnostics"
	File:  %codegen-diag.reds
]

#include %codegen-model.reds

; Record only terminal failures. Encoder probes may fail while selecting another
; encoding, so they return a status without touching this record. The first
; committed failure owns the diagnostic until the next generation attempt.

codegen-diag: context [
	FILE_X64:    1
	FILE_ARM64:  2
	FILE_READER: 3
	FILE_BRIDGE: 4

	INVALID_IR:     -1
	UNSUPPORTED:    -2
	OUTPUT_FULL:    -3
	INTERNAL_ERROR: -4
	RESOURCE_LIMIT: -5
	OUT_OF_MEMORY:  -6
	INVALID_ARGUMENTS: -7

	current-phase:       "validate"
	current-function:    0
	current-instruction: 0
	current-data:        as int-ptr! 0
	module-header:       as rsir-header! 0
	module-functions:    as byte-ptr! 0
	module-lines:        as byte-ptr! 0
	module-files:        as byte-ptr! 0
	module-strings:      as byte-ptr! 0

	status:            0
	site:              0
	site-file:         0
	name:              "unrecorded"
	function-index:    0
	instruction-index: 0
	op:                0
	a:                 0
	b:                 0
	c:                 0
	phase:             "validate"
	reason:            "unrecorded"
	has-details?:      false
	expected:          0
	actual:            0
	function-name:     as byte-ptr! 0
	function-name-size: 0
	source-name:       as byte-ptr! 0
	source-name-size:  0
	source-line:       0

	bind-module: func [
		header [rsir-header!] functions lines files strings [byte-ptr!]
	][
		module-header: header
		module-functions: functions
		module-lines: lines
		module-files: files
		module-strings: strings
	]

	capture-source: func [
		/local fn [rsir-function!] record [rsir-line-record!] file [rsir-file-entry!]
			low high middle [integer!]
	][
		if any [null? module-header function-index <= 0][exit]
		if function-index > module-header/function-count [exit]
		fn: as rsir-function! (module-functions + ((function-index - 1) * size? rsir-function!))
		function-name: module-strings + fn/name
		function-name-size: fn/name-size
		if instruction-index <= 0 [exit]
		; The validated sparse line table is ordered by function and instruction.
		low: 0
		high: module-header/line-record-count
		while [low < high][
			middle: low + ((high - low) / 2)
			record: as rsir-line-record! (module-lines + (middle * size? rsir-line-record!))
			either any [record/function-id < function-index all [
				record/function-id = function-index record/instruction-index <= instruction-index
			]][low: middle + 1][high: middle]
		]
		if low = 0 [exit]
		record: as rsir-line-record! (module-lines + ((low - 1) * size? rsir-line-record!))
		if record/function-id <> function-index [exit]
		file: as rsir-file-entry! (module-files + ((record/file-id - 1) * size? rsir-file-entry!))
		source-name: module-strings + file/name-offset
		source-name-size: file/name-size
		source-line: record/line
	]

	file-text: func [id [integer!] return: [c-string!]][
		case [
			id = FILE_X64   ["x64-codegen.reds"]
			id = FILE_ARM64 ["arm64-codegen.reds"]
			id = FILE_READER ["codegen-rsir-reader.reds"]
			id = FILE_BRIDGE ["codegen-bridge.reds"]
			true            ["unknown"]
		]
	]

	status-text: func [code [integer!] return: [c-string!]][
		case [
			code = INVALID_IR     ["INVALID_IR"]
			code = UNSUPPORTED    ["UNSUPPORTED"]
			code = OUTPUT_FULL    ["OUTPUT_FULL"]
			code = INTERNAL_ERROR ["INTERNAL_ERROR"]
			code = RESOURCE_LIMIT ["RESOURCE_LIMIT"]
			code = OUT_OF_MEMORY  ["OUT_OF_MEMORY"]
			code = INVALID_ARGUMENTS ["INVALID_ARGUMENTS"]
			true                  ["UNKNOWN_STATUS"]
		]
	]

	op-text: func [opcode [integer!] return: [c-string!]][
		switch opcode [
			1 ["LITERAL"] 2 ["CONSTANT"] 3 ["ADDRESS"] 4 ["LOAD"]
			5 ["SET"] 6 ["MEMBER"] 7 ["CALL"] 8 ["CAST"] 9 ["SIZE"]
			10 ["NATIVE"] 11 ["RETURN"] 12 ["DROP"] 13 ["DUPLICATE"]
			14 ["UNARY"] 15 ["BINARY"] 16 ["JUMP"] 17 ["BRANCH"]
			18 ["SWITCH"] 19 ["FAIL"] 20 ["REFERENCE"] 21 ["INDEX"]
			22 ["TAG"] 23 ["OVERFLOW"] 24 ["CATCH"] 25 ["END_CATCH"]
			26 ["THROW"] 27 ["ENTRY"] 28 ["SUB_CALL"] 29 ["SUB_RETURN"]
			default ["NONE/UNKNOWN"]
		]
	]

	fail: func [
		code file-id site-id [integer!]
		site-name [c-string!]
		return: [integer!]
	][
		if status <> 0 [return status]
		status: code
		site-file: file-id
		site: site-id
		name: site-name
		phase: current-phase
		function-index: current-function
		instruction-index: current-instruction
		if not null? current-data [
			op: current-data/1
			a: current-data/2
			b: current-data/3
			c: current-data/4
		]
		capture-source
		reason: case [
			code = INVALID_IR     ["RSIR validation failed"]
			code = UNSUPPORTED    ["target feature is not implemented"]
			code = OUTPUT_FULL    ["output buffer is too small"]
			code = INTERNAL_ERROR ["compiler invariant failed"]
			code = RESOURCE_LIMIT ["implementation limit exceeded"]
			code = OUT_OF_MEMORY  ["allocation failed"]
			code = INVALID_ARGUMENTS ["invalid codegen arguments"]
			true                  ["unexpected failure status"]
		]
		code
	]

	fail-values: func [
		code file-id site-id [integer!] site-name [c-string!]
		wanted found [integer!] return: [integer!]
	][
		if status <> 0 [return status]
		fail code file-id site-id site-name
		has-details?: true
		expected: wanted
		actual: found
		status
	]

	propagate: func [
		code file-id site-id [integer!] site-name [c-string!]
		return: [integer!]
	][
		if status <> 0 [return status]
		; Unrecorded negatives come from primitive encoders. Their -1 means
		; invalid operands; -3 means a write exceeded the measured function slice.
		fail INTERNAL_ERROR file-id site-id site-name
		reason: either code = OUTPUT_FULL [
			"emission exceeds its measured buffer"
		]["encoder rejected operands or returned an unexpected status"]
		has-details?: true
		expected: 0
		actual: code
		status
	]

	print-span: func [data [byte-ptr!] size [integer!]][
		while [size > 0][print [data/1] data: data + 1 size: size - 1]
	]

	report: func [/local kind source opcode [c-string!]][
		if status = 0 [exit]
		kind: status-text status
		source: file-text site-file
		opcode: op-text op
		print ["*** codegen " kind ": " reason lf
			"    check: " source " :: " name " (site " site ")" lf
			"    phase=" phase " function=" function-index
			" instruction=" instruction-index " op=" opcode " (" op ")"
			" operands=" a "," b "," c lf]
		if has-details? [print ["    expected=" expected " actual=" actual lf]]
		if function-name-size > 0 [
			print "    function: "
			print-span function-name function-name-size
			print lf
		]
		if source-name-size > 0 [
			print "    source: "
			print-span source-name source-name-size
			print [":" source-line lf]
		]
	]

	mark-phase: func [value [c-string!]][
		current-phase: value
		current-function: 0
		current-instruction: 0
		current-data: null
	]

	mark-function: func [fn-index [integer!]][
		current-function: fn-index
		current-instruction: 0
		current-data: null
	]

	mark-instruction: func [index [integer!] data [int-ptr!]][
		current-instruction: index
		current-data: data
	]

	reset: func [][
		status: 0
		site: 0
		site-file: 0
		name: "unrecorded"
		function-index: 0
		instruction-index: 0
		op: 0
		a: 0
		b: 0
		c: 0
		reason: "unrecorded"
		phase: "validate"
		has-details?: false
		expected: 0
		actual: 0
		module-header: null
		module-functions: null
		module-lines: null
		module-files: null
		module-strings: null
		function-name: null
		function-name-size: 0
		source-name: null
		source-name-size: 0
		source-line: 0
		mark-phase "validate"
	]
]
