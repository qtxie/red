Red [
	Title: "Red compiler runtime definition extractor"
	File:  %extractor.red
]

; Read the canonical runtime declarations once per compiler process. TRANSCODE
; handles the Red and Red/System lexical forms directly, so no Rebol-compatible
; source rewriting or generated definition copy is needed.
compiler-extractor: context [
	root: compiler-root
	enum-directive: to issue! "enum"
	enum-names: [datatypes! actions! natives!]
	definitions: make map! 512
	datatype-count: 0
	action-count: 0
	native-count: 0
	currencies: make block! 200
	scalars: context []
	scalars-without-view: none
	scalars-with-view: none
	extras: make block! 1

	fail: func [message [string! block!]][
		do make error! rejoin ["compiler extractor: " form message]
	]

	append-enum: func [body [block!] /local position item name id count][
		position: head body
		id: 0
		count: 0
		while [not tail? position][
			item: position/1
			case [
				set-word? :item [
					name: to word! item
					position: next position
					unless all [not tail? position integer? position/1][
						fail ["invalid explicit enum value for " mold name]
					]
					id: position/1
				]
				word? :item [name: item]
				true [fail ["invalid enum item: " mold item]]
			]
			put definitions name id
			id: id + 1
			count: count + 1
			position: next position
		]
		count
	]

	load-definitions: has [values position name count found][
		clear definitions
		datatype-count: 0
		action-count: 0
		native-count: 0
		values: transcode read/binary root/runtime/macros.reds
		position: head values
		found: 0
		while [not tail? position][
			if all [
				(length? position) >= 3
				issue? :position/1
				position/1 = enum-directive
				word? :position/2
				find enum-names position/2
				block? :position/3
			][
				name: position/2
				count: append-enum position/3
				switch name [
					datatypes! [datatype-count: count]
					actions! [action-count: count]
					natives! [native-count: count]
				]
				found: found + 1
				position: skip position 2
			]
			position: next position
		]
		unless all [
			found = 3
			datatype-count > 0
			action-count > 0
			native-count > 0
		][fail "runtime/macros.reds is missing a required enum"]
		definitions
	]

	find-context-body: func [code [block!] name [word!] /local position][
		position: head code
		while [not tail? position][
			if all [
				(length? position) >= 3
				set-word? :position/1
				(to word! position/1) = name
				word? :position/2
				position/2 = 'context
				block? :position/3
			][return position/3]
			position: next position
		]
		none
	]

	find-block-value: func [code [block!] name [word!] /local position][
		position: head code
		while [not tail? position][
			if all [
				(length? position) >= 2
				set-word? :position/1
				(to word! position/1) = name
				block? :position/2
			][return position/2]
			position: next position
		]
		none
	]

	load-currencies: has [values system-body locale-body currencies-body list][
		values: transcode read/binary root/environment/system.red
		system-body: find-context-body values 'system
		unless system-body [fail "system context is missing from environment/system.red"]
		locale-body: find-context-body system-body 'locale
		unless locale-body [fail "locale context is missing from environment/system.red"]
		currencies-body: find-context-body locale-body 'currencies
		unless currencies-body [fail "currencies context is missing from environment/system.red"]
		list: find-block-value currencies-body 'list
		unless list [fail "currency list is missing from environment/system.red"]
		currencies: copy list
	]

	load-scalars: func [job [object! none!] /local config values source expanded raw spec name value][
		config: any [job context [modules: copy []]]
		values: transcode read/binary root/environment/scalars.red
		source: find values to set-word! 'internal!
		unless source [fail "scalar declarations are missing from environment/scalars.red"]
		expanded: compiler-preprocessor/expand/clean copy source config
		unless expanded [
			fail ["cannot preprocess environment/scalars.red: " mold compiler-preprocessor/last-error]
		]
		raw: context expanded
		spec: make block! (2 * length? words-of raw)
		foreach name words-of raw [
			append spec to set-word! name
			value: get in raw name
			append/only spec to block! value
		]
		context spec
	]

	init: func [job [object! none!] /local view? modules-field][
		view?: false
		if all [
			job
			modules-field: in job 'modules
			block? (get modules-field)
			find (get modules-field) 'View
		][view?: true]
		either view? [
			unless scalars-with-view [scalars-with-view: load-scalars job]
			scalars: scalars-with-view
		][
			unless scalars-without-view [scalars-without-view: load-scalars job]
			scalars: scalars-without-view
		]
		clear extras
		compiler-extractor
	]
]

compiler-extractor/load-definitions
compiler-extractor/load-currencies
