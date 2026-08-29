Red [
	Title: "Red/System compilation job configuration"
	File:  %compiler/system-job.red
]

compiler-system-job: context [
	last-error: none

	prototype: context [
		config-name: none
		OS: none
		OS-version: 0
		ABI: none
		link?: false
		debug?: false
		opt-level: 1
		o2-ir-dump: none
		backend-mode: 'legacy
		build-prefix: %builds/
		build-basename: none
		build-suffix: none
		format: none
		type: 'exe
		target: 'IA-32
		cpu-version: 6.0
		verbosity: 0
		sub-system: 'console
		runtime?: true
		use-natives?: false
		debug-safe?: true
		dev-mode?: none
		static-link?: false
		need-main?: false
		PIC?: false
		PIE?: false
		base-address: none
		dynamic-linker: none
		syscall: 'Linux
		export-ABI: none
		stack-align-16?: false
		literal-pool?: false
		unicode?: false
		red-pass?: false
		red-only?: false
		red-store-bodies?: true
		red-strict-check?: true
		red-tracing?: true
		red-help?: false
		redbin-compress?: true
		legacy: none
		gui-console?: false
		libRed?: false
		libRedRT?: false
		libRedRT-update?: false
		GUI-engine: 'native
		draw-engine: none
		modules: none
		show: none
		command-line: none
		show-func-map?: false
		packager: none
		bundle-signature: none
		compiler-version: none
		compiler-build-date: none
		compiler-git: none
	]

	; Stage1 object-path codegen for locals/params is incomplete. Use get in/set in
	; for field access so self-host compilation does not depend on static ctx indices.
	job-get: func [job [object!] name [word!]][get in job name]
	job-set: func [job [object!] name [word!] value][set in job name :value :value]

	make-job: does [
		make object! [
			config-name: none
			OS: none
			OS-version: 0
			ABI: none
			link?: false
			debug?: false
			opt-level: 1
			o2-ir-dump: none
			backend-mode: 'legacy
			build-prefix: %builds/
			build-basename: none
			build-suffix: none
			format: none
			type: 'exe
			target: 'IA-32
			cpu-version: 6.0
			verbosity: 0
			sub-system: 'console
			runtime?: true
			use-natives?: false
			debug-safe?: true
			dev-mode?: none
			static-link?: false
			need-main?: false
			PIC?: false
			PIE?: false
			base-address: none
			dynamic-linker: none
			syscall: 'Linux
			export-ABI: none
			stack-align-16?: false
			literal-pool?: false
			unicode?: false
			red-pass?: false
			red-only?: false
			red-store-bodies?: true
			red-strict-check?: true
			red-tracing?: true
			red-help?: false
			redbin-compress?: true
			legacy: none
			gui-console?: false
			libRed?: false
			libRedRT?: false
			libRedRT-update?: false
			GUI-engine: 'native
			draw-engine: none
			modules: none
			show: none
			command-line: none
			show-func-map?: false
			packager: none
			bundle-signature: none
			compiler-version: none
			compiler-build-date: none
			compiler-git: none
		]
	]

	fail: func [message [string!] field value /local record][
		record: make object! [
			message: none
			field: none
			value: none
		]
		set in record 'message message
		set in record 'field field
		set in record 'value :value
		last-error: record
		none
	]

	default-target: does [
		switch/default system/platform [
			Windows ['MSDOS]
			Linux ['Linux]
			macOS ['Darwin]
		]['MSDOS]
	]

	normalize: func [job [object!]][
		if job-get job 'PIE? [job-set job 'PIC? true]
		if (job-get job 'type) = 'dll [
			job-set job 'PIE? false
			if (job-get job 'OS) <> 'Windows [job-set job 'PIC? true]
		]
		unless block? job-get job 'modules [job-set job 'modules copy []]
		job
	]

	native-value: func [value][
		if lit-word? :value [return to word! value]
		if word? :value [
			switch/default value [
				true [return true]
				yes [return true]
				on [return true]
				false [return false]
				no [return false]
				off [return false]
				none [return none]
			][]
		]
		:value
	]

	apply-values: func [
		job [object!]
		values [block! object!]
		/local data pos key name value field
	][
		last-error: none
		data: either object? values [body-of values][values]
		pos: data
		while [not tail? pos][
			unless any [word? pos/1 set-word? pos/1][
				return fail "configuration field must be a word" none pos/1
			]
			if tail? next pos [
				return fail "configuration field is missing a value" to word! pos/1 none
			]
			key: pos/1
			name: to word! key
			field: in job name
			unless field [return fail "unknown configuration field" name pos/2]
			value: native-value pos/2
			if series? :value [value: copy/deep :value]
			set field :value
			pos: skip pos 2
		]
		job
	]

	new: func [target [word! string! none!] /local name spec job][
		last-error: none
		name: to word! any [target default-target]
		spec: select target-registry name
		unless spec [return fail "unknown compilation target" 'config-name name]
		job: make-job
		job-set job 'config-name name
		unless apply-values job spec [return none]
		normalize job
	]

	apply-header: func [job [object!] header [block!] /local spec][
		spec: select header to set-word! 'Config
		unless spec [return job]
		unless block? spec [
			return fail "Red header Config value must be a block" 'Config spec
		]
		unless apply-values job spec [return none]
		if block? job-get job 'command-line [
			unless apply-values job job-get job 'command-line [return none]
		]
		normalize job
	]

	for-source: func [job [object!] source [file! string!] /local file pos base][
		file: last split-path to file! source
		if pos: find/last file #"." [file: copy/part file pos]
		base: job-get job 'build-basename
		case [
			none? base [job-set job 'build-basename file]
			all [not empty? base (last base) = #"/"][
				job-set job 'build-basename append copy base file
			]
		]
		job
	]
]
