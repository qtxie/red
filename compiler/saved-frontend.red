Red [
	Title: "Saved Red frontend artifact set"
	File:  %saved-frontend.red
]

compiler-saved-frontend: context [
	VERSION: 2
	fields: [
		version source-sha256 generated-sha256 redbin-sha256
		resources-sha256 dependencies target
	]
	script-marker: to issue! "script"
	last-error: none

	fail: func [message [string! block!] /local record][
		record: make object! [message: none]
		record/message: either block? message [rejoin message][message]
		last-error: record
		none
	]

	sidecar: func [base [file!] suffix [string!]][
		to file! rejoin [base suffix]
	]

	redbin-file: func [base [file!]][sidecar base ".redbin"]
	resources-file: func [base [file!]][sidecar base ".resources.red"]
	manifest-file: func [base [file!]][sidecar base ".manifest.red"]

	file-bytes: func [file [file!] label [string!] /local value][
		unless exists? file [return fail ["missing " label ": " file]]
		set/any 'value try [read/binary file]
		if error? :value [return fail ["cannot read " label ": " file]]
		value
	]

	resolve-dependency: func [file [file!] source [file!] /local candidate][
		candidate: to file! file
		if all [not empty? candidate (first candidate) <> #"/"][
			candidate: append copy first split-path source candidate
		]
		clean-path candidate
	]

	collect-script-files: func [
		value [block! paren!]
		files [block!]
		source [file!]
		/local position item dependency
	][
		position: value
		while [not tail? position][
			item: position/1
			either all [
				issue? :item
				item = script-marker
				not tail? next position
				file? position/2
			][
				dependency: resolve-dependency position/2 source
				unless any [dependency = source find files dependency][
					append files dependency
				]
				position: skip position 2
			][
				if any [block? :item paren? :item][
					collect-script-files item files source
				]
				position: next position
			]
		]
		files
	]

	dependency-records: func [
		generated-bytes [binary!]
		source [file!]
		/local value files records dependency bytes
	][
		set/any 'value try [load to string! generated-bytes]
		if error? :value [return fail "generated Red/System source is not valid Red data"]
		unless block? :value [
			return fail "generated Red/System source must contain a top-level block"
		]
		files: make block! 32
		collect-script-files :value files (clean-path source)
		sort files
		records: make block! ((length? files) * 2)
		foreach dependency files [
			bytes: file-bytes dependency "frontend dependency"
			unless binary? bytes [return none]
			repend records [dependency checksum bytes 'SHA256]
		]
		records
	]

	manifest-block: func [
		source-bytes generated-bytes redbin-bytes resources-bytes [binary!]
		dependencies [block!]
		target [word! string!]
	][
		reduce [
			'version VERSION
			'source-sha256 checksum source-bytes 'SHA256
			'generated-sha256 checksum generated-bytes 'SHA256
			'redbin-sha256 checksum redbin-bytes 'SHA256
			'resources-sha256 checksum resources-bytes 'SHA256
			'dependencies dependencies
			'target to word! target
		]
	]

	write-manifest: func [
		base source [file!]
		generated-bytes redbin-bytes resources-bytes [binary!]
		target [word! string!]
		/local source-bytes dependencies manifest
	][
		source-bytes: file-bytes source "source file"
		unless binary? source-bytes [return none]
		dependencies: dependency-records generated-bytes source
		unless block? dependencies [return none]
		manifest: manifest-block source-bytes generated-bytes redbin-bytes
			resources-bytes dependencies target
		write/binary manifest-file base to binary! mold manifest
		base
	]

	write-artifacts: func [
		base source [file!]
		generated [block!]
		redbin [binary!]
		resources [block!]
		target [word! string!]
		/local generated-bytes redbin-bytes resources-bytes
	][
		last-error: none
		generated-bytes: to binary! mold/only generated
		redbin-bytes: copy redbin
		resources-bytes: to binary! mold resources
		write/binary base generated-bytes
		write/binary redbin-file base redbin-bytes
		write/binary resources-file base resources-bytes
		write-manifest base source generated-bytes redbin-bytes resources-bytes target
	]

	seal-existing: func [
		base source [file!]
		target [word! string!]
		/local generated-bytes redbin-bytes resources-bytes resource-path value
	][
		last-error: none
		generated-bytes: file-bytes base "generated Red/System source"
		unless binary? generated-bytes [return none]
		redbin-bytes: file-bytes redbin-file base "Redbin payload"
		unless binary? redbin-bytes [return none]
		resource-path: resources-file base
		resources-bytes: either exists? resource-path [
			file-bytes resource-path "resource sidecar"
		][to binary! "[]"]
		unless binary? resources-bytes [return none]
		set/any 'value try [load to string! resources-bytes]
		unless block? :value [return fail "resource sidecar must contain one block"]
		resources-bytes: to binary! mold :value
		write/binary resource-path resources-bytes
		write-manifest base source generated-bytes redbin-bytes resources-bytes target
	]

	valid-manifest?: func [manifest /local position key seen value][
		unless all [block? manifest even? length? manifest][return false]
		seen: make block! length? fields
		position: manifest
		while [not tail? position][
			key: position/1
			unless all [word? key find fields key not find seen key][return false]
			append seen key
			position: skip position 2
		]
		unless (length? seen) = (length? fields) [return false]
		all [
			integer? select manifest 'version
			binary? select manifest 'source-sha256
			binary? select manifest 'generated-sha256
			binary? select manifest 'redbin-sha256
			binary? select manifest 'resources-sha256
			block? select manifest 'dependencies
			word? select manifest 'target
		]
	]

	valid-dependencies?: func [dependencies [block!] /local position][
		unless even? length? dependencies [return false]
		position: dependencies
		while [not tail? position][
			unless all [
				file? position/1
				binary? position/2
				(length? position/2) = 32
			][return false]
			position: skip position 2
		]
		true
	]

	load-artifacts: func [
		base source [file!]
		expected-target [word! string!]
		/local generated-bytes redbin-bytes resources-bytes manifest-bytes
			manifest resources dependencies value
	][
		last-error: none
		generated-bytes: file-bytes base "generated Red/System source"
		unless binary? generated-bytes [return none]
		redbin-bytes: file-bytes redbin-file base "Redbin payload"
		unless binary? redbin-bytes [return none]
		resources-bytes: file-bytes resources-file base "resource sidecar"
		unless binary? resources-bytes [return none]
		manifest-bytes: file-bytes manifest-file base "frontend manifest"
		unless binary? manifest-bytes [return none]
		set/any 'value try [load to string! manifest-bytes]
		if error? :value [return fail "frontend manifest is not valid Red data"]
		manifest: :value
		unless valid-manifest? manifest [return fail "frontend manifest has an invalid shape"]
		unless valid-dependencies? (select manifest 'dependencies) [
			return fail "frontend manifest has invalid dependency records"
		]
		unless (select manifest 'version) = VERSION [
			return fail ["unsupported frontend manifest version: " select manifest 'version]
		]
		unless (select manifest 'target) = (to word! expected-target) [
			return fail ["frontend target mismatch: " select manifest 'target]
		]
		unless exists? source [return fail ["missing source file: " source]]
		unless (checksum read/binary source 'SHA256) = (select manifest 'source-sha256) [
			return fail "saved frontend source checksum mismatch"
		]
		unless (checksum generated-bytes 'SHA256) = (select manifest 'generated-sha256) [
			return fail "saved frontend Red/System checksum mismatch"
		]
		dependencies: dependency-records generated-bytes source
		unless block? dependencies [return none]
		unless dependencies = (select manifest 'dependencies) [
			return fail "saved frontend dependency checksum mismatch"
		]
		unless (checksum redbin-bytes 'SHA256) = (select manifest 'redbin-sha256) [
			return fail "saved frontend Redbin checksum mismatch"
		]
		unless (checksum resources-bytes 'SHA256) = (select manifest 'resources-sha256) [
			return fail "saved frontend resource checksum mismatch"
		]
		set/any 'value try [load to string! resources-bytes]
		if error? :value [return fail "resource sidecar is not valid Red data"]
		resources: :value
		unless block? resources [return fail "resource sidecar must contain one block"]
		reduce [base 0:0:0 redbin-bytes resources]
	]
]
