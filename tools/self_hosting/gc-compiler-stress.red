Red [
	Title: "Stage1 repeated compiler-job GC stress test"
	File:  %gc-compiler-stress.red
	Config: [show: 'ARM64-ELF-only]
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

recycle/on

stress: context [
	root-dir: source-dir: output-dir: none
	sources: [
		%array-test.reds
		%float32-test.reds
		%function-test.reds
		%queue-test.reds
		%arm64-atomic-smoke.reds
		%arm64-call-args-smoke.reds
		%arm64-int64-smoke.reds
		%arm64-hfa-smoke.reds
	]

	fail: func [message][
		print ["FAIL compiler stress:" message]
		quit/return 1
	]

	compile-one: func [iteration [integer!] source [file!] /local options job result output][
		output: to file! rejoin [output-dir "stress-" iteration]
		options: compiler-options/make-options
		compiler-options/option-set options 'target "Linux-ARM64"
		compiler-options/option-set options 'source to string! source
		compiler-options/option-set options 'output to string! output
		compiler-options/option-set options 'release? true
		compiler-options/option-set options 'verbose 0
		job: compiler-options/to-job options
		if error? :job [fail rejoin ["job setup at " iteration ": " mold job]]
		compiler-system-job/job-set job 'link? true
		set/any 'result try [system-dialect/compile/options source job]
		if error? :result [fail rejoin ["job " iteration ": " mold result]]
		result: system-dialect/last-result
		unless all [block? result file? result/4 exists? result/4][
			fail rejoin ["no output at " iteration]
		]
	]

	run: func [args [block! none!] /local iterations iteration relative source pins bytes max-pins max-bytes][
		iterations: either all [block? args not empty? args][to integer! args/1][200]
		max-pins: max-bytes: 0
		root-dir: clean-path system/options/path
		unless exists? join root-dir %system/compiler.red [
			root-dir: clean-path join system/options/path %../../
		]
		unless exists? join root-dir %system/compiler.red [fail "repository root not found"]
		system/options/path: root-dir
		source-dir: join root-dir %system/tests/source/units/
		output-dir: join root-dir %build/gc-compiler-stress-out/
		make-dir/deep output-dir

		repeat iteration iterations [
			relative: pick sources (1 + ((iteration - 1) % (length? sources)))
			source: join source-dir relative
			print ["compile" iteration relative]
			compile-one iteration source
			pins: system/state/GC/pinned-frames
			bytes: system/state/GC/pinned-bytes
			if pins > max-pins [max-pins: pins]
			if bytes > max-bytes [max-bytes: bytes]
		]
		print [
			"PASS compiler stress:" iterations "jobs; max conservative pins:"
			max-pins "frames /" max-bytes "bytes"
		]
		quit/return 0
	]
]

stress/run system/options/args
