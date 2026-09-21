Red [
	Title: "Hybrid debug mode (-d) RSIR line-record integration"
]

#include %../../../system/compiler-test-common.red
#include %../../../system/system-diagnostics.red
#include %../../../system/codegen-bridge.red
#include %../../../system/rsir-frontend.red
#include %../../../system/compiler-rsir-core.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

debug-try-result: none

check: func [condition [logic!] message [string! block!]][
	unless condition [fail message]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ ((either high > 127 [high - 256][high]) * 16777216)
]

;-- The checks live inside a function on purpose: compiled top-level words
;-- share the global context with the included RSIR frontend, so a test word
;-- like `at` would shadow the frontend's free `at` references (it compiles
;-- as a variable fetch and breaks every change/part at output ... call).
run: func [
	/local debug-source debug-ir release-ir line-count file-count
	type-count import-count function-count instruction-count global-count
	switch-count export-count type-at member-count id import-at global-at
	function-at export-at param-count record param-at initializer-count
	initializer-at switch-at instruction-at lines-at file-table-at names-at
	previous-function previous-index fn-id instr-index line-no file-id at
	names-size name-offset name-size
][
	debug-source: {
Red/System []
alpha: func [a [integer!] return: [integer!]][
	a + 1
]
beta: func [b [integer!]][
	alpha b
	alpha b + 1
]
beta 2
}

	debug-ir: do [
		;-- Mirror compile-rsir's setup: the main file seeds the debug file table.
		compiler-rsir-frontend/source-file: %fixture-debug-source.reds
		set/any 'debug-try-result try [
			compiler-rsir-frontend/compile/debug load debug-source 'glue
		]
		either error? :debug-try-result [
			probe debug-try-result
			fail "debug frontend raised"
		][:debug-try-result]
	]
	check binary? debug-ir [
		"debug frontend failed: " mold compiler-rsir-frontend/last-error
	]

	;-- Debug builds append two header fields: the sparse line-record count and
	;-- the source file count. Both must be present and consistent.
	line-count: word-at debug-ir 36
	file-count: word-at debug-ir 40
	check line-count > 0 "debug RSIR has no line records"
	check file-count > 0 "debug RSIR has no source files"

	;-- Walk the section topology exactly as the native reader does.
	type-count: word-at debug-ir 8
	import-count: word-at debug-ir 12
	function-count: word-at debug-ir 16
	instruction-count: word-at debug-ir 20
	global-count: word-at debug-ir 24
	switch-count: word-at debug-ir 28
	export-count: word-at debug-ir 32

	type-at: 44
	member-count: 0
	id: 0
	while [id < type-count][
		if (word-at debug-ir (type-at + (id * 20))) <> -7 [
			member-count: member-count + word-at debug-ir (type-at + (id * 20) + 16)
		]
		id: id + 1
	]
	import-at: type-at + (type-count * 20) + (member-count * 8)
	global-at: import-at + (import-count * 32)
	function-at: global-at + (global-count * 24)
	export-at: function-at + (function-count * 36)
	param-count: 0
	id: 0
	while [id < import-count][
		param-count: param-count + word-at debug-ir (import-at + (id * 32) + 28)
		id: id + 1
	]
	id: 0
	while [id < function-count][
		record: function-at + (id * 36)
		param-count: param-count + word-at debug-ir (record + 20)
			+ word-at debug-ir (record + 28)
		id: id + 1
	]
	param-at: export-at + (export-count * 12)
	initializer-count: 0
	id: 0
	while [id < global-count][
		initializer-count: initializer-count
			+ word-at debug-ir (global-at + (id * 24) + 20)
		id: id + 1
	]
	initializer-at: param-at + (param-count * 8)
	switch-at: initializer-at + (initializer-count * 16)
	instruction-at: switch-at + (switch-count * 12)
	lines-at: instruction-at + (instruction-count * 16)
	file-table-at: lines-at + (line-count * 16)
	names-at: file-table-at + (file-count * 8)

	;-- Every line record must stay inside its function's instruction stream,
	;-- ascend by (function-id, instruction-index), and point at a real file.
	previous-function: 0
	previous-index: 0
	id: 0
	while [id < line-count][
		at: lines-at + (id * 16)
		fn-id: word-at debug-ir at
		instr-index: word-at debug-ir (at + 4)
		line-no: word-at debug-ir (at + 8)
		file-id: word-at debug-ir (at + 12)
		check all [
			fn-id >= 1 fn-id <= function-count
			instr-index >= 1
			instr-index <= word-at debug-ir (function-at + ((fn-id - 1) * 36) + 32)
			line-no >= 1
			file-id >= 1 file-id <= file-count
		]["debug line record out of range: " mold reduce [fn-id instr-index line-no file-id]]
		if fn-id = previous-function [
			check instr-index > previous-index
				"debug line records do not ascend by instruction index"
		]
		check fn-id >= previous-function "debug line records are not grouped by function"
		either fn-id = previous-function [
			previous-index: instr-index
		][
			previous-function: fn-id
			previous-index: instr-index
		]
		id: id + 1
	]

	;-- File table entries must point into the names blob that follows them.
	names-size: (length? debug-ir) - names-at
	id: 0
	while [id < file-count][
		at: file-table-at + (id * 8)
		name-offset: word-at debug-ir at
		name-size: word-at debug-ir (at + 4)
		check all [
			name-size > 0
			name-size <= names-size
			name-offset <= (names-size - name-size)
		]["debug file table entry out of range: " mold reduce [name-offset name-size]]
		id: id + 1
	]

	;-- Release builds carry neither line records nor source files.
	release-ir: do [
		compiler-rsir-frontend/source-file: %fixture-debug-source.reds
		compiler-rsir-frontend/compile load debug-source 'glue
	]
	check binary? release-ir [
		"release frontend failed: " mold compiler-rsir-frontend/last-error
	]
	check (word-at release-ir 36) = 0 "release RSIR unexpectedly carries line records"
	check (word-at release-ir 40) = 0 "release RSIR unexpectedly carries source files"

	print "hybrid-debug-mode-test OK"
]

run
