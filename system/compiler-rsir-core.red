Red [
	Title: "Hybrid Red/System compiler RSIR core"
	File:  %compiler-rsir-core.red
]

runtime-path: %system/runtime/
red-runtime-path: %runtime/

builtin-source-path: func [path [file!]][
	either compiler-resource-store/installed? [
		compiler-resource-store/source-path path
	][
		secure-clean-path path
	]
]

; This core connects the compact frontend, native codegen, and linker directly.
; It grows by moving complete semantics here, never by importing the legacy
; emitter, machine IR, or a compatibility adapter.
system-dialect: context [
	INITIAL-CODE-BYTES: 16777216
	MAX-CODE-BYTES: 268435456
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
		definitions: make hash! 32
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
			if pc [
				print ["*** at line:" compiler-system-diagnostics/line-of pc]
				print ["*** near:" mold copy/part pc 8]
			]
			quit-on-error
		]
	]

	job-backend-mode: func [/local slot][
		slot: in job 'backend-mode
		either slot [get slot]['legacy]
	]

	; Red development executables import libRedRT. Release executables and the
	; libRedRT build itself carry the runtime in their native image.
	red-runtime-linkage: func [candidate [object!] return: [word!]][
		case [
			not candidate/red-pass? ['none]
			all [
				candidate/runtime?
				candidate/type = 'exe
				not candidate/libRedRT?
			][either candidate/dev-mode? ['external]['embedded]]
			all [
				candidate/dev-mode?
				candidate/runtime?
				candidate/type = 'dll
				candidate/libRedRT?
			]['embedded]
			true ['invalid]
		]
	]

	codegen-architecture: does [
		switch/default job/target [
			X86-64 [1]
			ARM64  [2]
		][0]
	]

	validate-job: does [
		case [
			job-backend-mode <> 'rsir [
				compiler/throw-error "hybrid compiler requires the RSIR backend mode"
			]
			not any [
				all [
					job/OS = 'Windows job/format = 'PE
					job/target = 'X86-64 job/ABI = 'win64
				]
				all [
					job/OS = 'macOS job/format = 'Mach-O
					job/target = 'ARM64 job/ABI = 'apple-aarch64
				]
			][
				compiler/throw-error
					"RSIR frontend supports Win64/PE and Apple AArch64/Mach-O targets"
			]
			not find [exe dll] job/type [
				compiler/throw-error "RSIR frontend currently supports only executable and DLL modules"
			]
			all [job/libRedRT? not all [
				job/red-pass?
				job/dev-mode?
				job/runtime?
				job/type = 'dll
			]][
				compiler/throw-error "invalid libRedRT shared-library lifecycle"
			]
			all [job/red-pass? (red-runtime-linkage job) = 'invalid][
				compiler/throw-error [
					"RSIR frontend supports development and release Red executables,"
					"and development libRedRT"
				]
			]
			any [
				job/static-link?
				all [job/OS = 'Windows any [job/PIC? job/PIE?]]
				all [job/OS = 'macOS not job/PIC?]
			][
				compiler/throw-error "invalid hybrid target linking mode"
			]
			job/debug? [
				compiler/throw-error "RSIR frontend does not yet support debug builds"
			]
			any [
				not integer? job/opt-level
				all [job/opt-level <> 0 job/opt-level <> 2]
			][
				compiler/throw-error "hybrid codegen supports O0 and O2, not O1"
			]
			any [job/need-main? job/red-only? job/libRed? job/libRedRT-update?][
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
		compiler-system-diagnostics/reset
		clear compiler/definitions
		clear compiler/keywords-list
	]

	process-config: func [header [block!] /local configured][
		if job/red-pass? [return job]
		configured: compiler-system-job/apply-header job header
		unless configured [compiler/throw-error compiler-system-job/last-error/message]
		validate-job
	]

	compile-rsir: func [
		source [block!] file [file!]
		/local output error runtime-exports kind
	][
		compiler/script: clean-path file
		compiler/pc: source
		compiler-rsir-frontend/build-date: any [job/compiler-build-date now/utc]
		unless all [not tail? source source/1 = 'Red/System][
			compiler/throw-error "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2][
			compiler/throw-error "missing Red/System program header"
		]
		compiler-rsir-frontend/definitions: compiler/definitions
		kind: either job/type = 'dll ['library]['glue]
		output: either job/libRedRT? [
			runtime-exports: libRedRT/runtime-exports job
			compiler-rsir-frontend/compile/runtime/red source 'library runtime-exports
		][
			either job/red-pass? [
				compiler-rsir-frontend/compile/red source kind
			][compiler-rsir-frontend/compile source kind]
		]
		foreach warning compiler-rsir-frontend/warnings [
			print ["*** Warning:" warning]
		]
		unless binary? output [
			error: compiler-rsir-frontend/last-error
			if all [error error/position][compiler/pc: error/position]
			compiler/throw-error either error [error/message][
				"RSIR frontend failed without a diagnostic"
			]
		]
		last-rsir: output
		if job/o2-ir-dump [
			write/binary to file! job/o2-ir-dump last-rsir
			print ["...RSIR dump       :" job/o2-ir-dump]
		]
	]

	finish-code: func [/local output message capacity][
		capacity: max INITIAL-CODE-BYTES ((length? last-rsir) * 4)
		capacity: min capacity MAX-CODE-BYTES
		forever [
			output: make binary! capacity
			last-status: codegen-module
				last-rsir output codegen-architecture job/opt-level
			if any [last-status <> 4 capacity = MAX-CODE-BYTES][break]
			capacity: min (capacity * 2) MAX-CODE-BYTES
		]
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

	collect-resources: func [
		header resources [block!]
		file [file!]
		/local icon icon-file name value info main-path base
	][
		info: make block! 8
		main-path: first split-path file
		base: join system/options/path %system/assets/

		append resources 'icon
		either icon: select header first [Icon:][
			either any-word? :icon [
				icon-file: select [
					default %red.ico
					flat    %red.ico
					old     %red-3D.ico
					mono    %red-mono.ico
				] :icon
				unless icon-file [
					compiler/script: file
					compiler/throw-error ["unknown built-in icon:" mold :icon]
				]
				append/only resources reduce [
					either find [default flat] :icon [
						compiler-assets/default-icon
					][join base icon-file]
				]
			][
				icon: either file? icon [reduce [icon]][icon]
				unless block? icon [
					compiler/script: file
					compiler/throw-error "Icon must be a file or block of files"
				]
				foreach icon-file icon [
					unless file? icon-file [
						compiler/script: file
						compiler/throw-error "Icon block accepts only files"
					]
					icon-file: either loader/relative-path? icon-file [
						join main-path icon-file
					][icon-file]
					unless exists? icon-file [
						compiler/script: file
						compiler/throw-error ["cannot find icon:" icon-file]
					]
					append info icon-file
				]
				append/only resources info
			]
		][append/only resources reduce [compiler-assets/default-icon]]

		info: make block! 8
		foreach name [
			Title: Version: Company: Comments: Notes:
			Rights: Trademarks: ProductName: ProductVersion:
		][
			if value: select header name [
				append info to word! name
				append/only info value
			]
		]
		append resources 'version
		append/only resources info
		resources
	]

	compile: func [
		files [file! block!]
		/options opts [object!]
		/loaded job-data [block!]
		/local started comp-time file-list file source runtime-source runtime-file
			red-runtime-source red-runtime-file sys-global-source
			runtime-linkage embed-red-runtime? output link-time buffer-size result error payload resources icon
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
		if all [job/red-pass? not loaded][
			compiler/throw-error "Red-generated modules require loaded frontend data"
		]
		if all [job/red-pass? not binary? job-data/3][
			compiler/throw-error "Red-generated module is missing its Redbin payload"
		]
		resources: either loaded [copy/deep job-data/4][make block! 8]
		loader/job: job
		loader/connect-compiler-state compiler/definitions compiler/keywords-list
		loader/init
		set-verbose-level job/verbosity
		runtime-linkage: red-runtime-linkage job
		embed-red-runtime?: runtime-linkage = 'embedded

		runtime-source: none
		if job/runtime? [
			runtime-file: builtin-source-path runtime-path/common.reds
			compiler/script: runtime-file
			phase-timer/begin 'runtime-loader
			runtime-source: loader/process runtime-file
			phase-timer/finish 'runtime-loader
			unless block? runtime-source [
				error: loader/last-error
				compiler/throw-error either error [
					rejoin ["Red/System runtime loader: " error/message]
				]["Red/System runtime loader failed without a diagnostic"]
			]
			if embed-red-runtime? [
				sys-global-source: none
				unless empty? red/sys-global [
					compiler/script: %***sys-global.reds
					phase-timer/begin 'rs-loader
					sys-global-source: loader/process red/sys-global
					phase-timer/finish 'rs-loader
					unless block? sys-global-source [
						error: loader/last-error
						compiler/throw-error either error [
							rejoin ["Red/System #system-global loader: " error/message]
						]["Red/System #system-global loader failed without a diagnostic"]
					]
				]
				red-runtime-file: builtin-source-path red-runtime-path/red.reds
				compiler/script: red-runtime-file
				phase-timer/begin 'runtime-red-loader
				red-runtime-source: loader/process red-runtime-file
				phase-timer/finish 'runtime-red-loader
				unless block? red-runtime-source [
					error: loader/last-error
					compiler/throw-error either error [
						rejoin ["Red runtime loader: " error/message]
					]["Red runtime loader failed without a diagnostic"]
				]
			]
		]

		compiler/script: file
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
		unless loaded [collect-resources source/2 resources file]
		process-config source/2

		if runtime-source [
			if job/red-pass? [
				payload: job-data/3
				unless embed-red-runtime? [
					append runtime-source #import
					append/only runtime-source [
						"libRedRT.dll" stdcall [
							__red-boot: "red/boot" []
						]
					]
					append runtime-source '__red-boot
				]
				append/only runtime-source first [system/boot-data:]
				append/only runtime-source payload
				if embed-red-runtime? [
					if sys-global-source [append runtime-source skip sys-global-source 2]
					append runtime-source skip red-runtime-source 2
				]
			]
			append runtime-source #user-code
			append/only runtime-source skip source 2
			if job/type = 'exe [append runtime-source '***-normal-exit]
			source: runtime-source
		]

		phase-timer/begin 'rsir-frontend
		compile-rsir source file
		phase-timer/finish 'rsir-frontend

		output: none
		link-time: none
		phase-timer/begin 'native-codegen
		finish-code
		phase-timer/finish 'native-codegen
		comp-time: now/time/precise - started
		if job/link? [
			link-time: now/time/precise
			phase-timer/begin 'link-load
			unless linker/load-codegen job last-code [
				compiler/throw-error any [
					linker/codegen-error
					"linker could not load native codegen output"
				]
			]
			if icon: find resources 'icon [
				insert skip icon 2 reduce ['group-icon icon/2]
			]
			append resources reduce ['manifest none]
			append get in job 'sections compose/deep/only [
				rsrc [- - (resources)]
			]
			phase-timer/finish 'link-load
			phase-timer/begin 'link-build
			output: linker/build job
			phase-timer/finish 'link-build
			if all [job/libRedRT? file? output exists? output][
				phase-timer/begin 'libRedRT-files
				libRedRT/save-files
					job
					compiler-rsir-frontend/runtime-functions
					compiler-rsir-frontend/runtime-specs
				phase-timer/finish 'libRedRT-files
			]
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
