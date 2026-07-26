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
	; Rebol used %./. Stage0 writes include/defs next to the process cwd or under build/.
	root-dir:	  system/options/path

	get-path: func [file [file!] /local names n path][
		; Prefer cwd (Stage0 layout), then build/, then system/utils/.
		names: reduce [file]
		if find form file ".red" [
			append names to-red-file replace copy form file ".red" ".r"
		]
		foreach n names [
			if exists? n [return clean-path n]
			path: clean-path join root-dir n
			if exists? path [return path]
			path: clean-path join root-dir join %build/ n
			if exists? path [return path]
			path: clean-path join root-dir join %build/self-hosting/ n
			if exists? path [return path]
			path: clean-path join root-dir join %system/utils/ n
			if exists? path [return path]
		]
		clean-path join root-dir file
	]

	exports-data: transcode/one read/binary get-path exports-file
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
		data: revive-objects load file
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
		repend aliased [new to word! form old]
	]

	undecorate: func [sym [word! path!]][
		any [find/match sym: form sym "exec/" sym]
	]

	make-exports: func [functions exports job /local name file][
		foreach [name spec] functions [
			if all [
				pos: find/match form name "exec/"
				not find pos slash
			][
				append/only funcs transcode/one form name
			]
		]
		if exists? file: get-path extras-file [
			funcs: unique append funcs transcode read/binary file
		]
		foreach def funcs [
			unless all [none? job/GUI-engine def = 'exec/gui/OS-alert] [
				name: to word! form def
				repend exports [name undecorate def]
				unless select/only functions name [
					print ["*** libRedRT Error: definition not found for" def]
					halt
				]
				system-dialect/compiler/flag-callback name none
			]
		]
		foreach [def type] vars [
			repend exports [to word! form def undecorate def]
		]
	]

	obj-to-path: func [list tree /local pos o][
		foreach [sym obj ctx id proto opt] list [
			if 2 < length? obj-path [
				pos: find tree obj
				change/only pos to paren! reduce [append copy obj-path sym]
			]
			if object? obj [
				foreach w next first obj [
					if object? o: get in obj w [
						append obj-path transcode/one mold/flat sym	;-- clean-up unwanted newlines hints
						obj-to-path reduce [w o none none none none] tree
						remove back tail obj-path
					]
				]
			]
		]
		tree
	]

	process: func [job functions exports /local name list pos tmpl words lits file base-dir lib-name][
		if find [Windows macOS] job/OS [
			append funcs [
				red/image/push
				red/image/acquire-buffer
				red/image/release-buffer
			]
		]
		make-exports functions exports job

		clear imports
		clear template
		lib-name: rejoin [
			form lib-file
			switch/default job/OS [Windows [".dll"] macOS [".dylib"]][".so"]
		]
		append template "^/red: context "

		append imports [
			#include %$ROOT-PATH$runtime/definitions.reds
			#include %$ROOT-PATH$runtime/macros.reds
			#include %$ROOT-PATH$runtime/structures.reds

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
		foreach def funcs [								;-- functions
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
				name: to word! form def
				append pos undecorate def

				spec: copy/deep functions/:name/4
				clear find spec /local
				append/only pos spec
			]
		]

		list: third second find imports #import			;-- aliased functions
		foreach [new old] aliased [
			spec: copy/deep functions/:old/4
			clear find spec /local
			repend list [to set-word! new form undecorate old spec]
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

		words: to-block extract red/symbols 2
		remove-each w words [find form w #"~"]

		lits: copy red/literals
		while [pos: find lits 'get-root][
			remove/part skip pos -3 5
		]
		replace/all lits 'get-root-node 'get-root-node2

		tmpl: mold/all reduce [
			new-line/all/skip to-block red/functions yes 2
			red/redbin/index
			red/globals
			obj-to-path list: copy/deep red/objects list
			red/contexts
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

]
