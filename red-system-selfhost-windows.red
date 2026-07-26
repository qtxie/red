Red [
	Title: "Windows bootstrap Red/System compiler"
	File:  %red-system-selfhost-windows.red
]

#include %system/compiler-windows-bootstrap.red

command-status: 1

print-usage: does [
	print "Usage: red-system-selfhost-windows --check-core | --check-compile | --check-link-pe | --compile-reds <source.reds> [output.exe]"
	print "       red-system-selfhost-windows [-c] [-t Windows|MSDOS|IA-32] [-dlib] -o <output> <source.reds>"
]

make-windows-options: func [
	link? [logic!]
	runtime? [logic!]
	output-type [word!]
	/local options
][
	options: make system-dialect/options-class [
		OS: 'Windows
		format: 'PE
		type: output-type
		target: 'IA-32
		build-prefix: %build/self-hosting/
		verbosity: 0
	]
	options/link?: link?
	options/runtime?: runtime?
	options/dev-mode?: not runtime?
	options
]

check-core: does [
	checks: reduce [
		object? system-dialect
		object? system-dialect/compiler
		function? :system-dialect/compiler/run
		object? emitter
		emitter/target/target = 'IA-32
		object? linker
		object? external-linker
		object? system-format-PE
		not external-linker/framework? "fixture.framework/X"
	]
	either all checks [
		print "Windows bootstrap compiler core: OK"
		0
	][
		print ["Windows bootstrap compiler core mismatch:" mold checks]
		1
	]
]

check-compile: has [options result checks local-spec][
	options: make-windows-options false false 'exe
	system-dialect/compile/options
		%tools/self_hosting/fixtures/backend/minimal.reds
		options
	result: system-dialect/last-result
	if error? :result [
		print ["Windows bootstrap compile error:" mold result]
		return 1
	]
	checks: reduce [
		block? result
		(length? result) = 4
		(length? emitter/code-buf) > 0
		to logic! find system-dialect/compiler/functions 'answer
		to logic! find system-dialect/compiler/functions 'box-value-address
		to logic! find emitter/symbols 'answer
	]

	; Red's loose word comparison considers /local equal to local. Compile a
	; context field with that spelling and ensure its relocation stays namespaced.
	system-dialect/compile/options
		%tools/self_hosting/fixtures/backend/context-local.reds
		options
	local-spec: select emitter/symbols 'refs>local
	append checks reduce [
		none? select system-dialect/compiler/globals 'local
		none? select emitter/symbols 'local
		block? local-spec
		all [block? local-spec local-spec/1 = 'global not empty? local-spec/3]
	]
	either all checks [
		print [
			"Windows bootstrap compiler execution: OK"
			"code-bytes:" length? emitter/code-buf
			"data-bytes:" length? emitter/data-buf
		]
		command-status: 0
	][
		print ["Windows bootstrap compiler execution mismatch:" mold checks]
		command-status: 1
	]
	none
]

check-link-pe: has [
	options result output buffer pe-offset icon image-size image-offset image checks
][
	options: make-windows-options true false 'exe
	options/build-basename: %selfhost-windows-bootstrap-fixture
	system-dialect/compile/options
		%tools/self_hosting/fixtures/backend/linked-windows-ia32.reds
		options
	result: system-dialect/last-result
	output: result/4
	buffer: read/binary output
	pe-offset: 1 + to integer! reverse copy/part at buffer 61 4
	icon: system-format-PE/default-icon
	image-size: to integer! reverse copy/part skip icon 14 4
	image-offset: to integer! reverse copy/part skip icon 18 4
	image: copy/part skip icon image-offset image-size
	checks: reduce [
		file? output
		exists? output
		(copy/part buffer 2) = #{4D5A}
		(copy/part at buffer pe-offset 4) = #{50450000}
		(length? buffer) = result/3
		to logic! find buffer to-binary ".rsrc"
		to logic! find buffer image
	]
	either all checks [
		print ["Windows bootstrap PE link: OK" "file:" output "bytes:" length? buffer]
		command-status: 0
	][
		print ["Windows bootstrap PE link mismatch:" mold checks]
		command-status: 1
	]
	none
]

compile-reds: has [source output options result parts][
	if (length? args) < 2 [print-usage return 2]
	source: to-red-file args/2
	unless exists? source [
		print ["Cannot access Red/System source:" source]
		return 1
	]
	options: make-windows-options true true 'exe
	if (length? args) >= 3 [
		output: to-red-file args/3
		parts: split-path output
		options/build-prefix: parts/1
		options/build-basename: parts/2
	]
	system-dialect/compile/options source options
	result: system-dialect/last-result
	if error? :result [
		print ["Windows bootstrap compile error:" mold result]
		return 1
	]
	print ["Windows executable:" result/4 "bytes:" result/3]
	command-status: 0
	none
]

compile-standard: has [
	position argument source output output-type target options result parts
][
	position: args
	source: output: target: none
	output-type: 'exe
	while [not tail? position][
		argument: first position
		switch/default argument [
			"-c" [none]
			"-dlib" [output-type: 'dll]
			"-o" [
				position: next position
				if tail? position [print "Missing output path after -o" return 2]
				output: to-red-file first position
			]
			"-t" [
				position: next position
				if tail? position [print "Missing target after -t" return 2]
				target: first position
			]
		][
			either all [string? argument argument/1 = #"-"][
				print ["Unsupported Windows bootstrap option:" argument]
				return 2
			][
				source: to-red-file argument
			]
		]
		position: next position
	]
	unless all [source output][print-usage return 2]
	if all [target not find ["Windows" "MSDOS" "IA-32"] target][
		print ["Unsupported Windows bootstrap target:" target]
		return 2
	]
	unless exists? source [
		print ["Cannot access Red/System source:" source]
		return 1
	]

	options: make-windows-options true true output-type
	parts: split-path output
	options/build-prefix: parts/1
	options/build-basename: parts/2
	system-dialect/compile/options source options
	result: system-dialect/last-result
	if error? :result [
		print ["Windows bootstrap compile error:" mold result]
		return 1
	]
	print ["...output file size :" result/3 "bytes"]
	0
]

args: system/options/args
either empty? args [
	print-usage
	quit/return 2
][
	switch/default first args [
		"--check-core" [quit/return check-core]
		"--check-compile" [check-compile quit/return command-status]
		"--check-link-pe" [check-link-pe quit/return command-status]
		"--compile-reds" [compile-reds quit/return command-status]
	][quit/return compile-standard]
]
