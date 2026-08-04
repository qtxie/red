Red [
	Title: "Self-hosted Windows bootstrap compiler options"
	File:  %bootstrap-options.red
]

compiler-options: context [
	; Literal object construction only. Stage1 object-path / make <proto> []
	; codegen is incomplete; get in / set in is the reliable field API.
	make-options: does [
		make object! [
			target: "MSDOS"
			output: none
			source: none
			release?: false
			debug?: false
			opt-level: 1
			red-only?: false
			no-compress?: false
			dll?: false
			update-libRedRT?: false
			verbose: 0
			help?: false
			version?: false
		]
	]

	option-get: func [options [object!] name [word!]][get in options name]
	option-set: func [options [object!] name [word!] value][set in options name :value :value]

	missing-value: func [option [string!]][
		make error! rejoin ["missing value for " option]
	]

	parse-args: func [args [block! none!] /local options position token][
		options: make-options
		either block? args [position: args][position: copy []]
		while [not tail? position][
			token: to string! position/1
			case [
				find ["-h" "--help"] token [option-set options 'help? true]
				find ["-V" "--version"] token [option-set options 'version? true]
				find ["-r" "--release"] token [option-set options 'release? true]
				find ["-d" "--debug" "--debug-stabs"] token [option-set options 'debug? true]
				token = "-O0" [option-set options 'opt-level 0]
				token = "-O1" [option-set options 'opt-level 1]
				token = "-O2" [option-set options 'opt-level 2]
				find ["-dlib" "--dll"] token [option-set options 'dll? true]
				find ["-u" "--update-libRedRT"] token [
					option-set options 'update-libRedRT? true
					option-set options 'release? true
				]
				token = "--red-only" [option-set options 'red-only? true]
				token = "--no-compress" [option-set options 'no-compress? true]
				find ["-t" "--target"] token [
					position: next position
					if tail? position [return missing-value token]
					option-set options 'target to string! position/1
				]
				find ["-o" "--output"] token [
					position: next position
					if tail? position [return missing-value token]
					option-set options 'output to string! position/1
				]
				find ["-v" "--verbose"] token [
					position: next position
					if tail? position [return missing-value token]
					option-set options 'verbose to integer! position/1
				]
				all [not empty? token (first token) = #"-"] [
					return make error! rejoin ["unknown option: " token]
				]
				option-get options 'source [return make error! "multiple source files"]
				true [option-set options 'source token]
			]
			position: next position
		]
		options
	]

	to-job: func [options [object!] /local job overrides output parts][
		job: compiler-system-job/new option-get options 'target
		unless job [return make error! compiler-system-job/last-error/message]
		release?: option-get options 'release?
		update?: option-get options 'update-libRedRT?
		dev?: not any [release? update?]
		overrides: reduce [
			'debug? option-get options 'debug?
			'opt-level option-get options 'opt-level
			'static-link? false
			'runtime? true
			'red-only? option-get options 'red-only?
			'redbin-compress? not option-get options 'no-compress?
			'verbosity option-get options 'verbose
			'dev-mode? dev?
			'libRedRT-update? update?
		]
		if option-get options 'dll? [append overrides reduce ['type 'dll]]
		compiler-system-job/job-set job 'command-line copy/deep overrides
		unless compiler-system-job/apply-values job overrides [
			return make error! compiler-system-job/last-error/message
		]
		compiler-system-job/normalize job
		if option-get options 'source [
			compiler-system-job/for-source job to file! option-get options 'source
		]
		if option-get options 'output [
			output: to-red-file to file! option-get options 'output
			either all [not empty? output (last output) = #"/"][
				compiler-system-job/job-set job 'build-prefix output
			][
				parts: split-path output
				compiler-system-job/job-set job 'build-prefix parts/1
				compiler-system-job/job-set job 'build-basename parts/2
			]
		]
		job
	]
]
