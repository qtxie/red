Red [
	Title: "Red compiler source loader"
	File:  %compiler/source-loader.red
]

compiler-source-loader: context [
	config: none
	root-file: none
	included: make block! 128
	include-stack: make block! 16
	dependencies: make block! 128
	sources: make block! 32
	last-error: none
	max-depth: 128

	directive-include: to issue! "include"
	directive-include-binary: to issue! "include-binary"
	directive-system: to issue! "system"
	directive-system-global: to issue! "system-global"
	marker-include: to issue! "compiler-include"
	marker-include-binary: to issue! "compiler-include-binary"

	make-loader-error: func [message path /local record][
		record: make object! [
			message: none
			file: none
			stack: none
		]
		record/message: message
		record/file: path
		record/stack: copy include-stack
		last-error: record
		none
	]

	path-key: func [path [file!] /local key][
		key: to string! either compiler-resource-store/virtual? path [
			compiler-resource-store/virtual-path path
		][clean-path path]
		if system/platform = 'Windows [lowercase key]
		key
	]

	resolve: func [name [file! string!] parent [file!] /local path spelling base][
		path: to file! name
		if compiler-resource-store/virtual? path [
			return compiler-resource-store/virtual-path path
		]
		if compiler-resource-store/virtual? parent [
			return compiler-resource-store/resolve path parent
		]
		spelling: to string! path
		unless any [
			all [not empty? spelling spelling/1 = #"/"]
			all [(length? spelling) >= 2 spelling/2 = #":"]
		][
			base: first split-path parent
			path: to file! rejoin [base path]
		]
		clean-path/only path
	]

	make-record: func [path header body tokens digest /local record][
		record: make object! [
			file: none
			header: none
			code: none
			tokens: none
			sha256: none
		]
		record/file: path
		record/header: header
		record/code: body
		record/tokens: tokens
		record/sha256: digest
		record
	]

	header-marker?: func [value][
		all [
			any [word? :value path? :value]
			find ["Red" "Red/System"] form value
		]
	]

	split-source: func [values [block!] required? [logic!] path [file!] /local header body][
		either all [
			2 <= length? values
			header-marker? values/1
			block? values/2
		][
			header: copy/deep values/2
			body: copy/deep skip values 2
		][
			if required? [
				make-loader-error "source is missing a Red or Red/System header" path
				return none
			]
			header: none
			body: copy/deep values
		]
		reduce [header body]
	]

	mark-includes: func [code [block! paren!] /local out pos item nested][
		out: copy/deep code
		pos: head out
		while [not tail? pos][
			item: pos/1
			case [
				all [
					issue? :item
					any [item = directive-system item = directive-system-global]
				][
					pos: skip pos min 2 length? pos
					continue
				]
				all [issue? :item item = directive-include][
					pos/1: marker-include
				]
				all [issue? :item item = directive-include-binary][
					pos/1: marker-include-binary
				]
				any [block? :item paren? :item][
					nested: mark-includes item
					change/only pos either paren? :item [to paren! nested][nested]
				]
			]
			pos: next pos
		]
		out
	]

	append-values: func [target [block!] values [block!] /local value][
		foreach value values [append/only target :value]
		target
	]

	load-raw: func [
		path [file!]
		header-required? [logic!]
		/local data values parts record
	][
		unless either compiler-resource-store/virtual? path [
			compiler-resource-store/exists? path
		][exists? path][
			make-loader-error rejoin ["source file not found: " mold path] path
			return none
		]
		data: either compiler-resource-store/virtual? path [
			compiler-resource-store/read-binary path
		][read/binary path]
		values: compiler-lexer/process/file data path
		if compiler-lexer/last-error [
			last-error: compiler-lexer/last-error
			return none
		]
		parts: split-source values header-required? path
		unless parts [return none]
		record: make-record
			path
			parts/1
			parts/2
			copy compiler-lexer/tokens
			checksum data 'SHA256
		append/only sources record
		record
	]

	expand-markers: func [
		code [block! paren!]
		current-file [file!]
		depth [integer!]
		/local output pos item name child nested data path
	][
		if depth > max-depth [
			make-loader-error "include nesting limit exceeded" current-file
			return none
		]
		output: make block! length? code
		pos: head code
		while [not tail? pos][
			item: pos/1
			case [
				all [
					issue? :item
					any [item = directive-system item = directive-system-global]
				][
					append/only output item
					if not tail? next pos [
						append/only output pos/2
						pos: skip pos 2
						continue
					]
				]
				all [issue? :item item = marker-include][
					unless all [
						not tail? next pos
						any [file? pos/2 string? pos/2]
					][
						make-loader-error "invalid #include directive" current-file
						return none
					]
					name: pos/2
					child: load-include name current-file depth + 1
					if last-error [return none]
					append-values output child
					pos: skip pos 2
					continue
				]
				all [issue? :item item = marker-include-binary][
					unless all [
						not tail? next pos
						any [file? pos/2 string? pos/2]
					][
						make-loader-error "invalid #include-binary directive" current-file
						return none
					]
					path: resolve pos/2 current-file
					unless either compiler-resource-store/virtual? path [
						compiler-resource-store/exists? path
					][exists? path][
						make-loader-error rejoin ["binary include not found: " mold path] path
						return none
					]
					data: either compiler-resource-store/virtual? path [
						compiler-resource-store/read-binary path
					][read/binary path]
					append/only output data
					append/only dependencies reduce [
						'kind 'binary
						'file path
						'sha256 checksum data 'SHA256
					]
					pos: skip pos 2
					continue
				]
				any [block? :item paren? :item][
					nested: expand-markers item current-file depth + 1
					if last-error [return none]
					append/only output either paren? :item [to paren! nested][nested]
				]
				true [append/only output :item]
			]
			pos: next pos
		]
		output
	]

	load-include: func [
		name [file! string!]
		parent [file!]
		depth [integer!]
		/local path key record marked expanded result
	][
		path: resolve name parent
		key: path-key path
		if find include-stack key [
			make-loader-error rejoin ["include cycle: " mold path] path
			return none
		]
		if find included key [return copy []]
		append include-stack key
		record: load-raw path false
		unless record [
			take/last include-stack
			return none
		]
		marked: mark-includes record/code
		expanded: compiler-preprocessor/expand/file marked config path
		if compiler-preprocessor/last-error [
			last-error: compiler-preprocessor/last-error
			take/last include-stack
			return none
		]
		result: expand-markers expanded path depth
		take/last include-stack
		if last-error [return none]
		append included key
		append/only dependencies reduce [
			'kind 'source
			'file path
			'sha256 record/sha256
		]
		result
	]

	load: func [
		path [file! string!]
		job [object! none!]
		/local file record marked expanded
	][
		config: job
		last-error: none
		clear included
		clear include-stack
		clear dependencies
		clear sources
		file: either compiler-resource-store/virtual? path [
			compiler-resource-store/virtual-path path
		][clean-path/only to file! path]
		root-file: file
		record: load-raw file true
		unless record [return none]
		marked: mark-includes record/code
		expanded: compiler-preprocessor/expand/clean/file marked job file
		if compiler-preprocessor/last-error [
			last-error: compiler-preprocessor/last-error
			return none
		]
		record/code: expand-markers expanded file 0
		either last-error [none][record]
	]
]
