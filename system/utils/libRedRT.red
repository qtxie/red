Red [
	Title:   "Information extractor from Red runtime source code"
	Author:  "Nenad Rakocevic"
	File: 	 %libRedRT.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

libRedRT: context [
	funcs: vars: none
	user-funcs: none

	imports:	make block!  100
	template:	make string! 100'000
	extras:		make block!  100
	aliased:	make block!	 10							;-- [new old...]
	obj-path:	'red/objects

	lib-file:	  %libRedRT
	include-file: %libRedRT-include.red
	extras-file:  %libRedRT-extras.red
	defs-file:	  %libRedRT-defs.red
	exports-file: %libRedRT-exports.red
	; Stage0 writes generated include/defs below this directory.
	root-dir:	  system/options/path

	get-path: func [file [file!] /local names n path][
		names: reduce [file]
		if find form file ".red" [
			append names to-red-file replace copy form file ".red" ".r"
		]
		foreach n names [
			path: clean-path join root-dir n
			if exists? path [return path]
		]
		clean-path join root-dir file
	]

	get-source-path: func [file [file!] /local roots root path][
		roots: reduce [
			root-dir
			system/options/path
			clean-path join system/options/path %build/
			clean-path join system/options/path %build/self-hosting/
			clean-path join system/options/path %system/utils/
		]
		foreach root roots [
			path: clean-path join root file
			if exists? path [return path]
		]
		clean-path join system/options/path join %system/utils/ file
	]

	exports-data: get-source-path exports-file
	exports-data: read/binary exports-data
	exports-data: transcode exports-data
	funcs: first exports-data
	vars: second exports-data
	user-funcs: tail funcs

	get-include-file: func [job /local root data][
		data: read get-path include-file
		; Stage1 bootstrap is an exe: script/path may be none. Prefer options/path.
		root: any [system/script/path system/options/path]
		replace/all data "$ROOT-PATH$" remove mold root
		load data
	]

	revive-objects: func [value /local out pos body][
		if issue? value [
			case [
				value = #__libRedRT-none [return none]
				value = #__libRedRT-true [return true]
				value = #__libRedRT-false [return false]
			]
		]
		either block? value [
			if all [
				(length? value) = 2
				value/1 = #__libRedRT-object
				block? value/2
			][return construct revive-objects value/2]
			if all [
				(length? value) = 2
				value/1 = #__libRedRT-datatype
				word? value/2
			][return get value/2]
			out: make block! length? value
			pos: value
			while [not tail? pos][
				either all [
					pos/1 = 'make
					pos/2 = 'object!
					block? pos/3
				][
					body: revive-objects pos/3
					append/only out construct body
					pos: skip pos 3
				][
					append/only out revive-objects pos/1
					pos: next pos
				]
			]
			out
		][value]
	]

	get-definitions: func [/local data file][
		file: get-path defs-file
		data: relativize-red-types revive-objects load file
		foreach part [1 7 8][
			replace/all data/:part %"" to word! "%"
			replace/all data/:part ">>>" to word! ">>>"
		]
		data
	]

	init: does [
		clear aliased
	]

	init-extras: does [
		clear extras
		clear user-funcs
	]

	save-extras: has [file][
		unless empty? extras [
			file: get-path extras-file
			write file mold/only extras
		]
	]

	collect-extra: func [name [word!]][
		if all [
			not find extras name
			find/match form name "red/"
			not find/only funcs path: transcode/one form name	;-- funcs contains paths
			not find [get-root get-root-node] path/2
		][
			append extras name
		]
	]

	collect-aliased: func [new [word!] old [path!]][
		repend aliased [new old]
	]

	undecorate: func [sym [word! path!]][
		sym: form sym
		if find/match sym "exec/" [remove/part sym 5]
		sym
	]

	compiler-name: func [value [word! path!] /local spelling][
		spelling: form value
		replace/all spelling "/" ">"
		to word! spelling
	]

	runtime-exports: func [
		job
		/local selected output file data extra def type
	][
		selected: copy funcs
		if find [Windows macOS] job/OS [
			foreach def [
				red/image/push
				red/image/acquire-buffer
				red/image/release-buffer
			][
				unless find/only selected def [append/only selected def]
			]
		]
		file: get-path extras-file
		if exists? file [
			data: transcode read/binary file
			foreach extra data [
				unless find/only selected extra [append/only selected extra]
			]
		]
		output: make block! (2 * ((length? selected) + ((length? vars) / 2)))
		foreach def selected [
			unless all [none? job/GUI-engine def = 'exec/gui/OS-alert][
				repend output [def undecorate def]
			]
		]
		foreach [def type] vars [repend output [def undecorate def]]
		output
	]

	make-import-spec: func [value [block!] /local spec attrs pos][
		spec: relativize-red-types copy/deep value
		attrs: either block? spec/1 [spec/1][
			all [string? spec/1 block? spec/2 spec/2]
		]
		either attrs [
			unless find attrs 'red-internal [append attrs 'red-internal]
		][insert/only spec [red-internal]]
		if pos: find spec /local [clear pos]
		spec
	]

	relativize-red-types: func [spec [block!] /local pos value spelling][
		pos: spec
		while [not tail? pos][
			value: pos/1
			either block? value [
				relativize-red-types value
			][
				if word? value [
					spelling: form value
					if find/match spelling "red>" [pos/1: to word! skip spelling 4]
				]
			]
			pos: next pos
		]
		spec
	]

	make-exports: func [functions exports job /local name spelling file data extra entry spec attrs][
		foreach [name spec] functions [
			spelling: form name
			if all [
				find/match spelling "exec>"
				not find skip spelling 5 ">"
			][
				name: system-dialect/compiler/undecorate name
				if all [
					path? name
					(length? name) = 2
					name/1 = 'exec
				][
					append/only funcs name
				]
			]
		]
		if exists? file: get-path extras-file [
			data: read/binary file
			data: transcode data
			foreach extra data [
				unless find/only funcs extra [append/only funcs extra]
			]
		]
		foreach def funcs [
			unless all [none? job/GUI-engine def = 'exec/gui/OS-alert] [
				name: compiler-name def
				entry: system-dialect/compiler/find-functions name
				unless entry [
					print ["*** libRedRT Error: definition not found for" def]
					halt
				]
				; Keep the implementation on Red/System's private ABI. The generated
				; import uses the same ABI; only ordinary foreign calls use the OS ABI.
				spec: entry/2/4
				attrs: either block? spec/1 [spec/1][
					all [string? spec/1 block? spec/2 spec/2]
				]
				either attrs [
					unless find attrs 'red-internal [append attrs 'red-internal]
				][insert/only spec [red-internal]]
				system-dialect/compiler/flag-callback name none
				repend exports [entry/1 undecorate def]
			]
		]
		foreach [def type] vars [
			repend exports [compiler-name def undecorate def]
		]
	]

	obj-to-path: func [
		list tree /at path [path!]
		/local pos o field child-path sym obj ctx id proto opt w
	][
		unless at [path: obj-path]
		foreach [sym obj ctx id proto opt] list [
			if 2 < length? path [
				pos: find/same/skip next tree obj 6
				change/only pos to paren! reduce [append copy path sym]
			]
			if all [object? obj not none? sym][
				foreach w words-of obj [
					field: in obj w
					if field [
						o: get field
						if object? :o [
							child-path: append copy path transcode/one mold/flat sym
							obj-to-path/at reduce [w o none none none none] tree child-path
						]
					]
				]
			]
		]
		tree
	]

	save-files: func [
		job function-list specs
		/local name list pos tmpl words lits file lib-name globals contexts ctx spec
	][
		clear imports
		clear template
		lib-name: rejoin [
			form lib-file
			switch/default job/OS [Windows [".dll"] macOS [".dylib"]][".so"]
		]
		append template "^/red: context "

		append imports reduce [
			to issue! "include" %$ROOT-PATH$runtime/definitions.reds
			to issue! "include" %$ROOT-PATH$runtime/macros.reds
			to issue! "include" %$ROOT-PATH$runtime/structures.reds
		]
		append imports [
			cell!: alias struct! [
				header	[integer!]						;-- cell's header flags
				data1	[integer!]						;-- placeholders to make a 128-bit cell
				data2	[integer!]
				data3	[integer!]
			]
			series-buffer!: alias struct! [
				flags	[integer!]						;-- series flags
				node	[node-handle!]					;-- stable handle of the referring node
				size	[integer!]						;-- usable buffer size (series-buffer! struct excluded)
				offset	[cell!]							;-- series buffer offset pointer (insert at head optimization)
				tail	[cell!]							;-- series buffer tail pointer
			]

			root-base: as cell! 0

			get-root: func [
				idx		[integer!]
				return: [red-block!]
			][
				as red-block! root-base + idx
			]

			get-root-node: func [
				idx		[integer!]
				return: [node-handle!]
				/local
					obj [red-object!]
			][
				obj: as red-object! get-root idx
				obj/ctx
			]

		]
		foreach def function-list [					;-- functions
			unless all [none? job/GUI-engine def = 'exec/gui/OS-alert] [
				ctx: next def
				list: imports

				while [not tail? next ctx][
					unless pos: find list name: to set-word! ctx/1 [
						pos: tail list
						repend list [
							name 'context
							make block! 10
						]
						new-line skip tail list -3 yes
					]
					list: pos/3
					ctx: next ctx
				]
				either pos: find list #import [pos: pos/2/3][
					append list copy/deep [
						#import [libRedRT-file stdcall]
					]
					append/only last list pos: make block! 20
				]
				name: last ctx
				append pos to set-word! name
				new-line back tail pos yes
				name: compiler-name def
				append pos undecorate def
				unless spec: select specs name [
					print ["*** libRedRT Error: definition not found for" def]
					halt
				]
				append/only pos make-import-spec spec
			]
		]

		list: third second find imports #import			;-- aliased functions
		foreach [new old] aliased [
			name: compiler-name old
			unless spec: select specs name [
				print ["*** libRedRT Error: definition not found for" old]
				halt
			]
			repend list [to set-word! new form undecorate old make-import-spec spec]
			new-line skip tail list -3 yes
		]

		foreach [def type] vars [						;-- global variables
			list: either 2 < length? def [
				unless pos: find imports to set-word! def/2 [
					insert pos: tail imports compose/deep [
						(to set-word! def/2) context [
							#import [libRedRT-file stdcall []]
						]
					]
				]
				pos/3/2/3
			][
				pos: find imports #import
				pos/2/3
			]
			repend list [
				to set-word! last def form def reduce [type]
			]
			new-line skip tail list -3 yes
		]
		list: find imports to set-word! 'stack
		append list/3 [
			#enum flags! [FRAME_FUNCTION: 16777216]		;-- 01000000h
		]
		append imports [
			words: context [
				red/boot?: yes							;-- ensures words are in fixed memory area

				_body:		red/word/load "<body>"
				_anon:		red/word/load "<anon>"
				_remove:	red/word/load "remove"
				_take:		red/word/load "take"
				_clear:		red/word/load "clear"
				_insert:	red/word/load "insert"
				_poke:		red/word/load "poke"
				_put:		red/word/load "put"
				_moved:		red/word/load "moved"
				_changed:	red/word/load "changed"
				_reverse:	red/word/load "reverse"
				_lowercase:	red/word/load "lowercase"
				_uppercase:	red/word/load "uppercase"

				type:		red/symbol/make "type"
				face:	 	red/symbol/make "face"
				window:	 	red/symbol/make "window"
				offset:	 	red/symbol/make "offset"
				key:		red/symbol/make "key"
				picked:		red/symbol/make "picked"
				flags:	 	red/symbol/make "flags"
				away?:		red/symbol/make "away?"
				down?:		red/symbol/make "down?"
				mid-down?:	red/symbol/make "mid-down?"
				alt-down?:	red/symbol/make "alt-down?"
				aux-down?:	red/symbol/make "aux-down?"
				ctrl?:		red/symbol/make "ctrl?"
				shift?:	 	red/symbol/make "shift?"

				red/boot?: no
			]
		]

		append template mold imports
		replace/all template "libRedRT-file" mold lib-name
		tmpl: transcode/one replace/all mold template "[red/" "["

		file: get-path include-file
		write clean-path file tmpl

		; Stored symbol IDs define the root-slot order expected by generated code.
		words: make block! length? red/symbols
		loop length? red/symbols [append words none]
		foreach [name pos] red/symbols [poke words pos/2 name]
		remove-each w words [find form w #"~"]

		lits: copy red/literals
		while [pos: find lits 'get-root][
			remove/part skip pos -3 5
		]
		replace/all lits 'get-root-node 'get-root-node2
		globals: to block! red/globals
		contexts: make block! (2 * length? red/contexts)
		foreach [name pos] red/contexts [
			append contexts name
			append/only contexts pos
		]

		tmpl: mold/all reduce [
			new-line/all/skip to-block red/functions yes 2
			red/redbin/index
			globals
			obj-to-path list: copy/deep red/objects list
			contexts
			red/actions
			red/op-actions
			words
			lits
			red/s-counter
			red/needed
			red/shadow-funcs
		]
		replace/all tmpl "% " {%"" }
		replace/all tmpl ">>>" {">>>"}
		replace/all tmpl "red/red-" "red-"

		file: get-path defs-file
		write clean-path file tmpl
	]

	process: func [
		job functions exports
		/local name entry specs
	][
		if find [Windows macOS] job/OS [
			append funcs [
				red/image/push
				red/image/acquire-buffer
				red/image/release-buffer
			]
		]
		make-exports functions exports job
		specs: make map! (length? functions)
		foreach [name entry] functions [put specs name entry/4]
		save-files job funcs specs
	]

]
