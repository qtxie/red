Red [
	Title: "Red-hosted Red/System compiler entrypoint"
	File:  %red-system-selfhost.red
]

#include %system/compiler.red

check-core: does [
	checks: reduce [
		object? system-dialect
		object? system-dialect/compiler
		function? :system-dialect/compiler/run
		object? emitter
		emitter/target/target = 'IA-32
		object? linker
		object? static-link
		static-link/library? "fixture.obj"
	]
	either all checks [
		print "current Red/System compiler core load: OK"
		0
	][
		print ["current Red/System compiler core load mismatch:" mold checks]
		1
	]
]

check-compile: has [options result checks][
	options: make system-dialect/options-class [
		OS: 'Windows
		format: 'PE
		type: 'exe
		target: 'IA-32
		link?: false
		runtime?: false
		dev-mode?: true
		build-prefix: none
		verbosity: 0
	]
	set/any 'result try [
		system-dialect/compile/options
			%tools/self_hosting/fixtures/backend/minimal.reds
			options
	]
	if error? :result [
		print ["current Red/System compiler execution error:" mold result]
		return 1
	]
	result: system-dialect/last-result
	checks: reduce [
		block? result
		(length? result) = 4
		(length? emitter/code-buf) > 0
		to logic! find system-dialect/compiler/functions 'answer
		to logic! find emitter/symbols 'answer
	]
	either all checks [
		print [
			"current Red/System compiler execution: OK"
			"code-bytes:" length? emitter/code-buf
			"data-bytes:" length? emitter/data-buf
		]
		0
	][
		print ["current Red/System compiler execution mismatch:" mold checks]
		1
	]
]

check-link-pe: has [
	options result output buffer pe-offset icon image-size image-offset image checks
	source requested parts
][
	options: make system-dialect/options-class [
		OS: 'Windows
		format: 'PE
		type: 'exe
		target: 'IA-32
		link?: true
		runtime?: false
		dev-mode?: true
		build-prefix: %build/self-hosting/
		build-basename: %selfhost-linked-ia32
		verbosity: 0
	]
	source: %tools/self_hosting/fixtures/backend/linked-windows-ia32.reds
	if (length? args) >= 2 [
		requested: to-red-file args/2
		parts: split-path requested
		options/build-prefix: parts/1
		options/build-basename: parts/2
	]
	if (length? args) >= 3 [source: to-red-file args/3]
	set/any 'result try [
		system-dialect/compile/options source options
	]
	if error? :result [
		print ["current PE link error:" mold result]
		return 1
	]
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
		print [
			"current PE link: OK"
			"file:" output
			"bytes:" length? buffer
		]
		0
	][
		print ["current PE link mismatch:" mold checks]
		1
	]
]

check-link-elf: has [options result output buffer checks source requested parts][
	options: make system-dialect/options-class [
		OS: 'Linux
		format: 'ELF
		type: 'exe
		target: 'IA-32
		dynamic-linker: "/lib/ld-linux.so.2"
		stack-align-16?: true
		link?: true
		runtime?: false
		dev-mode?: true
		build-prefix: %build/self-hosting/
		build-basename: %selfhost-linked-linux-ia32
		verbosity: 0
	]
	source: %tools/self_hosting/fixtures/backend/linked-linux-ia32.reds
	if (length? args) >= 2 [
		requested: to-red-file args/2
		parts: split-path requested
		options/build-prefix: parts/1
		options/build-basename: parts/2
	]
	if (length? args) >= 3 [source: to-red-file args/3]
	set/any 'result try [
		system-dialect/compile/options source options
	]
	if error? :result [
		print ["current ELF link error:" mold result]
		return 1
	]
	result: system-dialect/last-result
	output: result/4
	buffer: read/binary output
	checks: reduce [
		file? output
		exists? output
		(copy/part buffer 4) = #{7F454C46}
		buffer/5 = 1
		buffer/6 = 1
		(copy/part at buffer 19 2) = #{0300}
		(length? buffer) = result/3
		to logic! find buffer to-binary ".text"
		to logic! find buffer to-binary ".dynamic"
		to logic! find buffer to-binary "libc.so.6"
		to logic! find buffer to-binary "exit"
	]
	either all checks [
		print [
			"current ELF link: OK"
			"file:" output
			"bytes:" length? buffer
		]
		0
	][
		print ["current ELF link mismatch:" mold checks]
		1
	]
]

args: system/options/args
either empty? args [
	print "Usage: red-system-selfhost --check-core | --check-compile | --check-link-pe | --check-link-elf"
	quit/return 2
][
	switch/default first args [
		"--check-core" [quit/return check-core]
		"--check-compile" [quit/return check-compile]
		"--check-link-pe" [quit/return check-link-pe]
		"--check-link-elf" [quit/return check-link-elf]
	][
		print "Usage: red-system-selfhost --check-core | --check-compile | --check-link-pe | --check-link-elf"
		quit/return 2
	]
]
