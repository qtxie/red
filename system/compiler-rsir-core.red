Red [
	Title: "Hybrid Red/System compiler RSIR core"
	File:  %compiler-rsir-core.red
]

#include %../compiler/wire-schema.red
#include %../compiler/wire-writer.red
#include %../compiler/wire-container.red
#include %../compiler/wire-string-table.red
#include %../compiler/wire-diagnostics.red
#include %../compiler/rsir-producer.red
#include %../compiler/rsir-sink.red
#include %../compiler/rscf-producer.red
#include %../compiler/hybrid-driver.red

; This core is the independent hybrid frontend boundary.  It starts with the
; smallest semantic slice accepted by the native backend and grows by moving
; frontend semantics here, never by importing the legacy emitter or machine IR.
system-dialect: context [
	verbose: 0
	job: none
	last-result: none
	last-rsir: none
	last-rscg: none
	last-diagnostics: none
	backend-mode: 'rsir
	rsir-state: none
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
			all [job/link? not compiler-hybrid-driver/installed?][
				compiler/throw-error "RSIR linking requires the Windows hybrid codegen package"
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
		last-rscg: none
		last-diagnostics: none
		rsir-state: none
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

	compile-module: func [source [block!] file [file!] /local header position name][
		compiler/script: clean-path file
		compiler/pc: source
		unless all [not tail? source source/1 = 'Red/System][
			compiler/throw-error "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2][
			compiler/throw-error "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]][
			compiler/throw-error "invalid Red/System program header"
		]
		process-config header
		position: skip source 2
		compiler/pc: position
		while [not tail? position][
			compiler/pc: position
			unless all [
				(length? position) >= 4
				set-word? position/1
				find [func function] position/2
				block? position/3
				block? position/4
			][
				compiler/throw-error
					"RSIR frontend currently supports only one empty function declaration"
			]
			name: to word! position/1
			unless compiler-rsir-sink/add-function rsir-state name position/3 position/4 [
				compiler/throw-error compiler-rsir-sink/last-error/message
			]
			position: skip position 4
		]
	]

	finish-rsir: func [/local output error][
		output: compiler-rsir-sink/finish rsir-state
		unless binary? output [
			error: compiler-rsir-sink/last-error
			compiler/throw-error either error [error/message][
				"RSIR semantic sink failed without a diagnostic"
			]
		]
		last-rsir: output
	]

	finish-rscg: func [/local output error][
		output: compiler-hybrid-driver/generate last-rsir job
		last-diagnostics: compiler-hybrid-driver/last-diagnostics
		unless binary? output [
			error: compiler-hybrid-driver/last-error
			compiler/throw-error either error [error/message][
				"native codegen failed without a diagnostic"
			]
		]
		last-rscg: output
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
		rsir-state: compiler-rsir-sink/new
			none
			compiler-wire-schema/WIRE_MODULE_KIND_GLUE
			compiler-wire-schema/WIRE_IMAGE_KIND_EXECUTABLE
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
		compile-module source file
		finish-rsir
		phase-timer/finish 'rsir-frontend

		output: none
		link-time: none
		if job/link? [
			phase-timer/begin 'native-codegen
			finish-rscg
			phase-timer/finish 'native-codegen
			comp-time: now/time/precise - started
			link-time: now/time/precise
			phase-timer/begin 'link-prepare
			unless compiler-hybrid-driver/adapt last-rscg job [
				error: compiler-hybrid-driver/last-error
				compiler/throw-error either error [error/message][
					"RSCG adapter failed without a diagnostic"
				]
			]
			phase-timer/finish 'link-prepare
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
