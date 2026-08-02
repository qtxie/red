Red [
	Title: "Shared ARM Red/System cross-suite builder"
	File:  %arm-red-system-suite-builder.red
]

; Shared implementation for the target-specific ARM and ARM64 suite builders.

; compiler-core shares these hooks with the Red frontend. Red/System jobs do
; not call them, but native compilation still resolves the words.
red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

recycle/on

arm-suite-builder: context [
	root-dir: source-dir: output-dir: target-name: none
	compiled: failures: 0
	resume?: false

	join-file: func [base [file!] relative [file!]][append copy base relative]

	fail: func [message][
		print ["*** ARM suite builder error:" message]
		quit/return 1
	]

	clean-output: func [dir [file!] /local entry path][
		make-dir/deep dir
		foreach entry read dir [
			path: join-file dir entry
			if dir? path [fail rejoin ["unexpected directory in suite output: " path]]
			delete path
		]
	]

	compile-source: func [
		source [file!]
		output [file!]
		/library
		/local options job result
	][
		if all [resume? exists? output][
			print ["reuse" output]
			return output
		]
		print ["compile" source "->" output]
		options: compiler-options/make-options
		compiler-options/option-set options 'target target-name
		compiler-options/option-set options 'source to string! source
		compiler-options/option-set options 'output to string! output
		compiler-options/option-set options 'release? true
		compiler-options/option-set options 'dll? library
		compiler-options/option-set options 'verbose 0
		job: compiler-options/to-job options
		if error? :job [
			fail rejoin ["job setup failed: " mold job]
		]
		compiler-system-job/job-set job 'link? true
		set/any 'result try [system-dialect/compile/options source job]
		if error? :result [
			fail rejoin ["compile failed for " source ": " mold result]
		]
		result: system-dialect/last-result
		unless all [block? result file? result/4 exists? result/4][
			fail rejoin ["compiler produced no output for " source " result: " mold result]
		]
		compiled: compiled + 1
		result/4
	]

	make-dylib-test: func [/local source text include-file][
		source: join-file output-dir %dylib-auto-test.reds
		text: read join-file source-dir %auto-tests/dylib-auto-test.reds
		replace/all text {"libtest-dll1.dll"} {"./libtest-dll1.so"}
		replace/all text {"libtest-dll2.dll"} {"./libtest-dll2.so"}
		include-file: join-file root-dir %quick-test/quick-test.reds
		replace text
			{#include %../../../../../quick-test/quick-test.reds}
			rejoin ["#include " mold include-file]
		write source text
		source
	]

	make-long-branch-test: func [/local source text iterations][
		iterations: 70000
		source: join-file output-dir %arm64-long-branch-smoke.reds
		text: make string! 4000000
		append text {Red/System [
	Title: "Generated ARM64 long conditional branch smoke test"
]

#if target = 'ARM64 [
	#syscall [sys-exit: 93 [status [integer!]]]

	long-forward: func [flag [logic!] return: [integer!] /local value [integer!]][
		value: 0
		if flag [
}
		repeat i iterations [append text "^-^-^-value: value + 1^/"]
		append text rejoin [{		]
		value
	]

	long-backward: func [return: [integer!] /local value [integer!]][
		value: 0
		until [
}]
		repeat i iterations [append text "^-^-^-value: value + 1^/"]
		append text rejoin [
			"^-^-^-value = " iterations "^/"
			{^-^-]
		value
	]

	if (long-forward false) <> 0 [sys-exit 1]
	if (long-forward true) <> } iterations { [sys-exit 2]
	if long-backward <> } iterations { [sys-exit 3]
	sys-exit 0
]
}]
		write source text
		source
	]

	copy-support-files: func [/local runner runner-text validator validator-text][
		runner: join-file output-dir %run-all.sh
		runner-text: read join-file root-dir %system/tests/run-all.sh
		replace/all runner-text "^M" ""
		write/binary runner to binary! runner-text
		either target-name = "Linux-ARM64" [
			validator: join-file output-dir %validate-arm64-elf.sh
			validator-text: read join-file root-dir %system/tests/validate-arm64-elf.sh
			replace/all validator-text "^M" ""
			write/binary validator to binary! validator-text
			write/binary join-file output-dir %structlib.c
				read/binary join-file source-dir %libs/structlib.c
		][
			write/binary join-file output-dir %libstructlib.so
				read/binary join-file source-dir %libs/libstructlib-armhf.so
		]
	]

	run: func [
		expected-target [string!]
		args [block! none!]
		/local unit-sources smoke-sources relative source output name
			dylib-source long-branch-source entry
	][
		unless all [block? args find [1 2] (length? args)][
			print ["Usage:" expected-target "output-directory [--resume]"]
			quit/return 2
		]
		target-name: expected-target
		resume?: all [(length? args) = 2 args/2 = "--resume"]
		if all [(length? args) = 2 not resume?][fail "second argument must be --resume"]

		root-dir: clean-path system/options/path
		unless exists? join-file root-dir %system/compiler.red [
			root-dir: clean-path join-file system/options/path %../../
		]
		unless exists? join-file root-dir %system/compiler.red [
			fail rejoin ["cannot locate repository root from: " system/options/path]
		]
		; compiler-system-loader snapshots this path at the beginning of each job.
		system/options/path: root-dir
		source-dir: join-file root-dir %system/tests/source/units/
		output-dir: clean-path join-file root-dir to-red-file to file! args/1
		unless (last output-dir) = #"/" [append output-dir #"/"]
		either resume? [make-dir/deep output-dir][clean-output output-dir]

		unit-sources: [
			%array-test.reds %logic-test.reds %byte-test.reds %c-string-test.reds
			%struct-test.reds %union-test.reds %pointer-test.reds %cast-test.reds
			%alias-test.reds %length-test.reds %null-test.reds %enum-test.reds
			%protect-test.reds %float-test.reds %float32-test.reds %lib-test.reds
			%get-pointer-test.reds %float-pointer-test.reds %namespace-test.reds
			%not-test.reds %size-test.reds %integer-test.reds %fixed-int-test.reds
			%int64-test.reds %function-test.reds %case-test.reds %switch-test.reds
			%subroutine-test.reds %use-test.reds %exit-test.reds %return-test.reds
			%exceptions-test.reds %modulo-test.reds %math-mixed-test.reds
			%overflow-test.reds %vararg-test.reds %infix-test.reds %conditional-test.reds
			%system-test.reds %atomic-test.reds %queue-test.reds %push-pop-test.reds
		]
		if target-name = "Linux-ARM64" [
			change find unit-sources %struct-test.reds %struct-x64-test.reds
			change find unit-sources %size-test.reds %size-x64-test.reds
		]

		compile-source/library join-file source-dir %libtest-dll1.reds
			join-file output-dir %libtest-dll1.so
		compile-source/library join-file source-dir %libtest-dll2.reds
			join-file output-dir %libtest-dll2.so

		foreach relative unit-sources [
			source: join-file source-dir relative
			name: to string! relative
			clear find/last name ".reds"
			output: join-file output-dir to file! name
			compile-source source output
		]

		if target-name = "Linux-ARM64" [
			smoke-sources: copy []
			foreach entry read source-dir [
				name: to string! entry
				if all [find/match name "arm64-" find name ".reds"][
					append smoke-sources entry
				]
			]
			smoke-sources: sort smoke-sources
			foreach relative smoke-sources [
				source: join-file source-dir relative
				name: to string! relative
				clear find/last name ".reds"
				output: join-file output-dir to file! name
				compile-source source output
			]

			long-branch-source: make-long-branch-test
			compile-source long-branch-source
				join-file output-dir %arm64-long-branch-smoke
			if exists? long-branch-source [delete long-branch-source]
		]

		dylib-source: make-dylib-test
		compile-source dylib-source join-file output-dir %dylib-auto-test
		if exists? dylib-source [delete dylib-source]
		copy-support-files

		print [
			"ARM Red/System suite build:" target-name
			"compiled:" compiled
			"failed:" failures
			"output:" output-dir
		]
		quit/return either zero? failures [0][1]
	]
]
