REBOL [
	Title:   "Information extractor from Red runtime source code"
	Author:  "Nenad Rakocevic"
	File: 	 %libRedRT.r
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

libRedRT: context [
	funcs: vars: none
	
	set [funcs vars] load-cache %system/utils/libRedRT-exports.r
	user-funcs: tail funcs
		
	imports:	make block!  100
	template:	make string! 100'000
	extras:		make block!  100
	aliased:	make block!	 10							;-- [new old...]
	obj-path:	'red/objects
	
	lib-file:	  %libRedRT
	include-file: %libRedRT-include.red
	extras-file:  %libRedRT-extras.r
	defs-file:	  %libRedRT-defs.r
	red-defs-file: %libRedRT-defs.red
	root-dir:	  %./
	
	get-path: func [file][
		either all [system/version/4 = 3 root-dir = %./][
			file
		][
			root-dir/:file
		]
	]
	
	get-include-file: func [job][
		data: read get-path include-file
		replace/all data "$ROOT-PATH$" remove mold system/script/path
		load data
	]
	
	get-definitions: func [/local data][
		data: load get-path defs-file
		foreach part [1 7 8][
			replace/all data/:part %"" to word! "%"
			replace/all data/:part ">>>" to word! ">>>"
		]
		data
	]

	to-red-moldable: func [value /local type out item word][
		type: type?/word get/any 'value
		switch/default type [
			none! [to issue! "__libRedRT-none"]
			logic! [to issue! either value ["__libRedRT-true"]["__libRedRT-false"]]
			integer! decimal! word! set-word! lit-word! get-word!
			refinement! issue! char! file! url! path! set-path! lit-path! get-path!
			pair! time! date! money! percent! [value]
			string! binary! [copy value]
			block! [
				out: make block! length? value
				foreach item value [append/only out to-red-moldable get/any 'item]
				out
			]
			paren! [
				out: to paren! copy []
				foreach item value [append/only out to-red-moldable get/any 'item]
				out
			]
			hash! [
				out: make block! length? value
				foreach item value [append/only out to-red-moldable get/any 'item]
				out
			]
			object! [
				out: make block! 2 * length? first value
				foreach word next first value [
					append out to set-word! word
					append/only out to-red-moldable get in value word
				]
				reduce [to issue! "__libRedRT-object" out]
			]
			datatype! [reduce [to issue! "__libRedRT-datatype" to word! form value]]
		][none]
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
			not find/only funcs path: load form name	;-- funcs contains paths
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
	
	make-exports: func [functions exports job /local name file spec attrs][
		foreach [name spec] functions [
			if all [
				pos: find/match form name "exec/"
				not find pos slash
			][
				append/only funcs load form name
			]
		]
		if exists? file: get-path extras-file [
			funcs: unique append funcs load/all file
		]
		foreach def funcs [
			unless all [none? job/GUI-engine def = 'exec/gui/OS-alert] [
				name: to word! form def
				repend exports [name undecorate def]
				unless select/only functions name [
					print ["*** libRedRT Error: definition not found for" def]
					halt
				]
				; Keep the implementation on Red/System's private ABI. The generated
				; import uses the same ABI; only ordinary foreign calls use the OS ABI.
				spec: functions/:name/4
				attrs: either block? spec/1 [spec/1][
					all [string? spec/1 block? spec/2 spec/2]
				]
				either attrs [
					unless find attrs 'red-internal [append attrs 'red-internal]
				][insert/only spec [red-internal]]
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
						append obj-path load mold/flat sym	;-- clean-up unwanted newlines hints
						obj-to-path reduce [w o none none none none] tree
						remove back tail obj-path
					]
				]
			]
		]
		tree
	]
	
	process: func [job functions exports /local name list pos tmpl words lits file base-dir data lib-name][
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
		tmpl: load replace/all mold template "[red/" "["
		
		file: get-path include-file
		if all [not encap? slash <> first file][file: join %../ file]
		write clean-path file tmpl
		
		words: to-block extract red/symbols 2
		remove-each w words [find form w #"~"]
		
		lits: copy red/literals
		while [pos: find lits 'get-root][
			remove/part skip pos -3 5
		]
		replace/all lits 'get-root-node 'get-root-node2
		
		data: reduce [
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
		tmpl: mold/all data
		replace/all tmpl "% " {%"" }
		replace/all tmpl ">>>" {">>>"}
		replace/all tmpl "red/red-" "red-"

		file: get-path defs-file
		if all [not encap? slash <> first file][file: join %../ file]
		write clean-path file tmpl

		file: get-path red-defs-file
		if all [not encap? slash <> first file][file: join %../ file]
		write clean-path file mold to-red-moldable data
	]
	
]
