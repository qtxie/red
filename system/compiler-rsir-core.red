Red [
	Title: "Hybrid Red/System compiler RSIR core"
	File:  %compiler-rsir-core.red
]

; This core connects the compact frontend, native codegen, and linker directly.
; It grows by moving complete semantics here, never by importing the legacy
; emitter, machine IR, or a compatibility adapter.
system-dialect: context [
	MAX-CODE-BYTES: 16777216
	verbose: 0
	job: none
	last-result: none
	last-rsir: none
	last-code: none
	last-status: -1
	backend-mode: 'rsir
	loader: compiler-system-loader
	options-class: compiler-system-job/prototype

	compiler: context [
		job: none
		pc: none
		script: none
		definitions: make block! 32
		keywords-list: make block! 32
		verbose: 0

		quit-on-error: does [
			if system/options/args [quit/return 1]
			halt
		]

		throw-error: func [err [word! string! block!]][
			print [
				"*** Compilation Error:"
				either word? err [
					join uppercase/part mold err 1 " error"
				][reform err]
				"^/*** in file:" mold script
			]
			if pc [print ["*** near:" mold copy/part pc 8]]
			quit-on-error
		]
	]

	job-backend-mode: func [/local slot][
		slot: in job 'backend-mode
		either slot [get slot]['legacy]
	]

	validate-job: does [
		case [
			job-backend-mode <> 'rsir [
				compiler/throw-error "hybrid compiler requires the RSIR backend mode"
			]
			job/OS <> 'Windows [
				compiler/throw-error "RSIR frontend currently supports only Windows"
			]
			job/format <> 'PE [
				compiler/throw-error "RSIR frontend currently supports only PE targets"
			]
			job/target <> 'X86-64 [
				compiler/throw-error "RSIR frontend currently supports only X86-64"
			]
			job/ABI <> 'win64 [
				compiler/throw-error "RSIR frontend currently supports only the Win64 ABI"
			]
			job/type <> 'exe [
				compiler/throw-error "RSIR frontend currently supports only executable modules"
			]
			job/runtime? [
				compiler/throw-error "RSIR frontend does not yet support the Red/System runtime"
			]
			job/red-pass? [
				compiler/throw-error "RSIR frontend does not yet support Red-generated modules"
			]
			any [job/PIC? job/PIE? job/static-link?] [
				compiler/throw-error "RSIR frontend does not yet support PIC, PIE, or static linking"
			]
			any [job/debug? not none? job/o2-ir-dump] [
				compiler/throw-error "RSIR frontend does not yet support debug or O2 IR output"
			]
			any [
				not integer? job/opt-level
				job/opt-level < 0
				job/opt-level > 1
			][
				compiler/throw-error "RSIR frontend currently supports only O0 and O1"
			]
			any [job/need-main? job/red-only? job/libRed? job/libRedRT? job/libRedRT-update?][
				compiler/throw-error "RSIR frontend received unsupported module lifecycle options"
			]
			true [true]
		]
	]

	make-job: func [opts [object!] file [file!] /local data result pos base][
		data: copy/deep body-of opts
		forall data [if lit-word? data/1 [data/1: to word! data/1]]
		result: construct/with data linker/job-class
		file: last split-path file
		file: to file! either pos: find/reverse tail file #"." [copy/part file pos][file]
		base: get in result 'build-basename
		case [
			none? base [set in result 'build-basename file]
			all [not empty? base slash = last base][append base file]
		]
		result
	]

	set-verbose-level: func [level [integer!]][
		verbose: level
		loader/verbose: level
		compiler/verbose: level
		linker/verbose: level
	]

	reset-state: does [
		last-result: none
		last-rsir: none
		last-code: none
		last-status: -1
		compiler/pc: none
		clear compiler/definitions
		clear compiler/keywords-list
	]

	process-config: func [header [block!] /local configured][
		if job/red-pass? [return job]
		configured: compiler-system-job/apply-header job header
		unless configured [compiler/throw-error compiler-system-job/last-error/message]
		validate-job
	]

	compile-rsir: func [source [block!] file [file!] /local output error][
		compiler/script: clean-path file
		compiler/pc: source
		unless all [not tail? source source/1 = 'Red/System][
			compiler/throw-error "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2][
			compiler/throw-error "missing Red/System program header"
		]
		process-config source/2
		output: compiler-rsir-frontend/compile
			source
			'glue
		unless binary? output [
			error: compiler-rsir-frontend/last-error
			compiler/throw-error either error [error/message][
				"RSIR frontend failed without a diagnostic"
			]
		]
		last-rsir: output
	]

	finish-code: func [/local output message][
		output: make binary! MAX-CODE-BYTES
		last-status: codegen-module last-rsir output job/opt-level
		unless last-status = 0 [
			message: switch/default last-status [
				1 ["native codegen received invalid arguments"]
				2 ["native codegen rejected invalid RSIR"]
				3 ["native codegen does not support this RSIR yet"]
				4 ["native codegen output exceeds its reserved buffer"]
			]["native codegen returned an unknown status"]
			compiler/throw-error message
		]
		last-code: output
	]

	; Kept as a frontend API while resource lowering is still outside the first
	; RSIR slice. The backend fails closed before silently dropping such data.
	collect-resources: func [header [block!] resources [block!] file [file!]][
		if any [select header first [Icon:] select header first [Version:]][
			compiler/script: file
			compiler/throw-error "RSIR frontend does not yet support Windows resources"
		]
		resources
	]

	compile: func [
		files [file! block!]
		/options opts [object!]
		/loaded job-data [block!]
		/local started comp-time file-list file source output link-time buffer-size result error
	][
		started: now/time/precise
		reset-state
		file-list: either block? files [files][reduce [files]]
		unless (length? file-list) = 1 [
			compiler/throw-error "RSIR frontend supports exactly one source module"
		]
		unless opts [opts: make options-class []]
		file: first file-list
		job: make-job opts file
		backend-mode: job-backend-mode
		compiler/job: job
		compiler/script: file
		validate-job
		loader/job: job
		loader/connect-compiler-state compiler/definitions compiler/keywords-list
		loader/init
		set-verbose-level job/verbosity

		phase-timer/begin 'rs-loader
		either loaded [
			source: loader/process/with job-data/1 file
		][source: loader/process file]
		phase-timer/finish 'rs-loader
		unless block? source [
			error: loader/last-error
			compiler/throw-error either error [
				rejoin ["Red/System loader: " error/message]
			]["Red/System loader failed without a diagnostic"]
		]

		phase-timer/begin 'rsir-frontend
		compile-rsir source file
		phase-timer/finish 'rsir-frontend

		output: none
		link-time: none
		if job/link? [
			phase-timer/begin 'native-codegen
			finish-code
			phase-timer/finish 'native-codegen
			comp-time: now/time/precise - started
			link-time: now/time/precise
			phase-timer/begin 'link-load
			unless linker/load-codegen job last-code [
				compiler/throw-error any [
					linker/codegen-error
					"linker could not load native codegen output"
				]
			]
			phase-timer/finish 'link-load
			phase-timer/begin 'link-build
			output: linker/build job
			phase-timer/finish 'link-build
			link-time: now/time/precise - link-time
		]

		if job/link? [
			buffer-size: either binary? get in job 'buffer [length? get in job 'buffer][0]
			result: reduce [comp-time link-time buffer-size output]
			last-result: result
		]
		set-verbose-level 0
		none
	]
]
