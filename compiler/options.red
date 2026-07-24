Red [
	Title: "Red compiler command-line options"
	File:  %compiler/options.red
]

compiler-options: context [
	make-options: does [
		make object! [
			target: form compiler-system-job/default-target
			output: none
			source: none
			release?: false
			debug?: false
			static?: false
			no-runtime?: false
			dynamic-lib?: false
			red-only?: false
			dev-mode: none
			no-view?: false
			view-engine: none
			no-compress?: false
			show-func-map?: false
			show: none
			update-libRedRT?: false
			verbose: 0
			config: none
			help?: false
			version?: false
		]
	]

	missing-value: func [option [string!]][
		make error! rejoin ["missing value for " option]
	]

	decode-config: func [source [string!] /local result][
		result: try [transcode source]
		either error? :result [:result][
			either block? result [result][make error! "invalid --config value"]
		]
	]

	decode-word: func [source [string!] /local result][
		result: try [transcode/one source]
		either all [not error? :result any [word? result lit-word? result]][
			to word! result
		][
			make error! rejoin ["expected a word, got: " source]
		]
	]

	parse-args: func [
		args [block!]
		/local options index token value decoded positional? converted
	][
		options: make-options
		index: 1
		positional?: false
		while [index <= length? args][
			token: to string! pick args index
			if all [not positional? token = "--"][
				positional?: true
				index: index + 1
				continue
			]
			either any [positional? empty? token (first token) <> #"-"][
				if options/source [return make error! "multiple source files"]
				options/source: token
			][
				switch/default token [
					"-h" [options/help?: true]
					"--help" [options/help?: true]
					"-V" [options/version?: true]
					"--version" [options/version?: true]
					"-c" [options/release?: false]
					"--compile" [options/release?: false]
					"-r" [options/release?: true options/dev-mode: false]
					"--release" [options/release?: true options/dev-mode: false]
					"-d" [options/debug?: true]
					"--debug" [options/debug?: true]
					"--debug-stabs" [options/debug?: true]
					"-s" [options/static?: true]
					"--static" [options/static?: true]
					"-n" [options/no-runtime?: true]
					"--no-runtime" [options/no-runtime?: true]
					"-dlib" [options/dynamic-lib?: true]
					"--dynamic-lib" [options/dynamic-lib?: true]
					"--red-only" [options/red-only?: true]
					"--dev" [options/dev-mode: true]
					"--no-view" [options/no-view?: true]
					"--no-compress" [options/no-compress?: true]
					"--show-func-map" [options/show-func-map?: true]
					"--show-expanded" [options/show: 'expanded]
					"-u" [options/update-libRedRT?: true options/dev-mode: false]
					"--update-libRedRT" [options/update-libRedRT?: true options/dev-mode: false]
					"-t" [
						index: index + 1
						if index > length? args [return missing-value token]
						options/target: to string! pick args index
					]
					"--target" [
						index: index + 1
						if index > length? args [return missing-value token]
						options/target: to string! pick args index
					]
					"-o" [
						index: index + 1
						if index > length? args [return missing-value token]
						options/output: to string! pick args index
					]
					"--output" [
						index: index + 1
						if index > length? args [return missing-value token]
						options/output: to string! pick args index
					]
					"-v" [
						index: index + 1
						if index > length? args [return missing-value token]
						value: pick args index
						converted: try [to integer! value]
						if error? :converted [return make error! "invalid verbosity"]
						options/verbose: converted
					]
					"--verbose" [
						index: index + 1
						if index > length? args [return missing-value token]
						value: pick args index
						converted: try [to integer! value]
						if error? :converted [return make error! "invalid verbosity"]
						options/verbose: converted
					]
					"--config" [
						index: index + 1
						if index > length? args [return missing-value token]
						decoded: decode-config to string! pick args index
						if error? :decoded [return :decoded]
						options/config: decoded
					]
					"--view" [
						index: index + 1
						if index > length? args [return missing-value token]
						decoded: decode-word to string! pick args index
						if error? :decoded [return :decoded]
						options/view-engine: decoded
					]
				][
					return make error! rejoin ["unknown option: " token]
				]
			]
			index: index + 1
		]
		options
	]

	to-job: func [options [object!] /local job overrides output parts][
		job: compiler-system-job/new options/target
		unless job [return make error! compiler-system-job/last-error/message]
		overrides: copy any [options/config []]
		repend overrides ['debug? options/debug?]
		repend overrides ['static-link? options/static?]
		repend overrides ['runtime? not options/no-runtime?]
		repend overrides ['red-only? options/red-only?]
		repend overrides ['redbin-compress? not options/no-compress?]
		repend overrides ['show-func-map? options/show-func-map?]
		repend overrides ['verbosity options/verbose]
		if options/show [repend overrides ['show options/show]]
		if options/dynamic-lib? [repend overrides ['type 'dll]]
		if logic? options/dev-mode [repend overrides ['dev-mode? options/dev-mode]]
		if options/no-view? [repend overrides ['GUI-engine none]]
		if options/view-engine [repend overrides ['GUI-engine options/view-engine]]
		if options/update-libRedRT? [repend overrides ['libRedRT-update? true]]
		job/command-line: copy/deep overrides
		unless compiler-system-job/apply-values job overrides [
			return make error! compiler-system-job/last-error/message
		]
		compiler-system-job/normalize job
		if options/source [
			compiler-system-job/for-source job to file! options/source
		]
		if options/output [
			output: to file! options/output
			either all [not empty? output (last output) = #"/"][
				job/build-prefix: output
			][
				parts: split-path output
				job/build-prefix: parts/1
				job/build-basename: parts/2
			]
		]
		job
	]
]
