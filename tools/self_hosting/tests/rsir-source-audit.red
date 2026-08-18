Red [
	Title: "RSIR frontend source audit"
]

#include %../../../system/compiler-windows-common.red

do %../../../compiler/rsir-frontend.red

rsir-source-audit: context [
	last-error: none
	runtime-file: clean-path join system/options/path %../../../system/runtime/common.reds

	compile-file: func [
		file [file!]
		return: [binary! none!]
		/local job definitions keywords runtime-source source output
	][
		last-error: none
		job: compiler-system-job/new 'Windows-X86-64
		unless object? job [
			last-error: compiler-system-job/last-error/message
			return none
		]
		compiler-system-job/job-set job 'backend-mode 'rsir
		compiler-system-job/job-set job 'link? false
		compiler-system-job/job-set job 'runtime? true
		compiler-system-job/job-set job 'debug? false
		compiler-system-job/job-set job 'opt-level 1
		compiler-system-job/job-set job 'o2-ir-dump none

		definitions: make block! 32
		keywords: make block! 32
		compiler-system-loader/job: job
		compiler-system-loader/connect-compiler-state definitions keywords
		compiler-system-loader/init
		runtime-source: compiler-system-loader/process runtime-file
		unless block? runtime-source [
			last-error: any [
				all [compiler-system-loader/last-error compiler-system-loader/last-error/message]
				"runtime loader failed"
			]
			return none
		]

		source: compiler-system-loader/process file
		unless block? source [
			last-error: any [
				all [compiler-system-loader/last-error compiler-system-loader/last-error/message]
				"source loader failed"
			]
			return none
		]
		unless compiler-system-job/apply-header job source/2 [
			last-error: compiler-system-job/last-error/message
			return none
		]

		append runtime-source skip source 2
		append runtime-source '***-normal-exit
		output: compiler-rsir-frontend/compile runtime-source 'glue
		unless binary? output [
			last-error: any [
				all [compiler-rsir-frontend/last-error compiler-rsir-frontend/last-error/message]
				"RSIR frontend failed"
			]
		]
		output
	]

	run: func [args [block! none!] /local passed failed value file output][
		unless all [block? args not empty? args][
			print "usage: red-console rsir-source-audit.red <source.reds> [...]"
			quit/return 1
		]
		passed: 0
		failed: 0
		foreach value args [
			file: clean-path to-red-file to file! value
			output: either exists? file [compile-file file][
				last-error: "source file does not exist"
				none
			]
			either binary? output [
				passed: passed + 1
				print ["PASS:" file]
			][
				failed: failed + 1
				print ["FAIL:" file "-" last-error]
			]
		]
		print ["RSIR source audit:" passed "passed," failed "failed"]
		quit/return either failed = 0 [0][1]
	]
]

rsir-source-audit/run system/options/args
