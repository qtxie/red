Red [
	Title:	 "Red run-time debugging and helping tools"
	Author:	 "Nenad Rakocevic"
	File:	 %tools.red
	Tabs:	 4
	Rights:	 "Copyright (C) 2021 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

system/tools: context [
	fun-stk:   make block! 10
	expr-stk:  make block! 10
	watching:  make block! 10
	profiling: make block! 10
	
	indent: 0
	hist-length: none
	
	dbg-usage: next {
	`help` or `?`: print a list of debugger's commands.
	`next` or `n` or just ENTER: evaluate next value.
	`continue` or `c`: exit debugging console but continue evaluation.
	`quit` or `q`: exit debugger and stop evaluation.
	`stack` or `s`: display the current calls and expression stack.
	`parents` or `p`: display the parents call stack.
	`:word`: outputs the value of `word`. If it is a `function!`, outputs the local context.
	`:a/b/c`: outputs the value of `a/b/c` path.
	`watch <word1> <word2>...`: watch one or more words. `w` can be used as shortcut for `watch`.
	`-watch <word1> <word2>...`: stop watching one or more words. `-w` can be used as shortcut for `-watch`.
	`+stack`  or `+s`: outputs expression stack on each new event.
	`-stack`  or `-s`: do not output expression stack on each new event.
	`+locals` or `+l`: output local context for each entry in the callstack.
	`-locals` or `-l`: do not output local context for each entry in the callstack.
	`+indent` or `+i`: indent the output of the expression stack.
	`-indent` or `-i`: do not indent the output of the expression stack.
	}
	
	options: context [
		debug: context [
			active?:		no
			show-stack?:	yes
			show-parents?:	no
			show-locals?:	no
			stack-indent?:	no
		]
		trace: context [
			indent?:		yes
		]
		profile: context [
			sort-by: 		'count
			types:			make typeset! [function! action! native! op!]
		]
	]
	
	calc-max: func [used [integer!] return: [integer!]][
		either system/console [system/console/size/x - used][72 - used]
	]
	
	show-context: function [ctx [function! object!]][
		foreach w words-of :ctx [
			prin out: rejoin ["  > " pad mold :w 10 ": "]
			prin mold/flat/part try [get/any :w] calc-max length? out
			either find [none true false unset] :w [print " (word!)"][prin lf]
		]
	]
	
	show-parents: function [event [word!]][
		collect-calls list: make block! 10
		unless empty? fun-stk [
			remove/part list find list first first skip tail fun-stk pick -2x-1 event = 'call
		]
		foreach [w pos] reverse/skip list 2 [
			if all [not unset? get/any w function? get/any w][
				if :w = 'debug [exit]					;-- avoid showing debugger's own call stack
				print ["Call:" w]
				if options/debug/show-locals? [show-context get :w]
			]
		]
	]
	
	show-stack: function [][
		prin either empty? head expr-stk ["^/-empty stack-"][lf]
		indent: 0
		foreach frame head expr-stk [
			unless integer? frame [
				forall frame [
					prin "Stack: "
					if options/debug/stack-indent? [loop indent [prin "  "]]
					print mold/part/flat first frame calc-max 7 + (indent * 2)
					if head? frame [indent: indent + 1]
				]
			]
		]
		prin lf
	]
	
	show-watching: function [][
		foreach w watching [
			prin out: rejoin ["Watch: " mold w ": "]
			print mold/flat/part get/any w calc-max length? out
		]
	]
	
	do-command: function [event [word!]][
		if value? 'ask [								;-- `ask` needs a console sub-system
			watch: [
				list: next list
				either add? [append watching list][
					foreach w list [try [remove find watching to-word w]]
				]
			]
			do [										;-- prevents `ask` from being compiled
				until [
					cmd: trim ask "debug> "
					case [
						cmd/1 = #":" [
							print ["==" mold get/any load next cmd]
						]
						find "+-" cmd/1 [
							add?: cmd/1 = #"+"
							switch first list: load/all next cmd [
								watch w	  [do watch]
								parents p [options/debug/show-parents?: add?]
								stack   s [options/debug/show-stack?:   add?]
								locals  l [options/debug/show-locals?:  add?]
								indent  i [options/debug/stack-indent?: add?]
							]
						]
						'else [
							unless empty? list: load/all cmd [
								switch/default list/1 [
									watch w	  	[add?: yes do watch]
									parents p	[show-parents event]
									stack s		[show-stack]
									next n		[clear cmd]
									continue c  [options/debug/active?: no clear cmd]
									quit q		[halt]
									help ?		[print dbg-usage]
								][
									print "Unknown command!"
								]
							]
						]
					]
					empty? cmd
				]
			]
		]
	]

	debugger: function [
		event  [word!]
		code   [any-block! none!]
		offset [integer!]
		value  [any-type!]
		ref	   [any-type!]
		frame  [pair!]
		/extern expr-stk hist-length
	][
		store: [
			either empty? expr-stk [
				append/only expr-stk to-paren reduce [:value]
			][
				append/only last expr-stk :value
			]
		]
		switch event [
			fetch [
				switch :value [@stop [options/debug/active?: yes] @go [options/debug/active?: no]]
				if paren? expr-stk/1 [remove expr-stk]
			]
			enter [
				unless empty? head expr-stk [
					append expr-stk index? expr-stk
					expr-stk: tail expr-stk
				]
			]
			exit [
				either head? expr-stk [clear expr-stk][
					if paren? expr-stk/1 [set/any 'value expr-stk/1/1]
					idx: first pos: find/reverse tail expr-stk integer!
					clear pos
					expr-stk: at head expr-stk idx
					do store
				]
			]
			open [
				append/only expr-stk reduce [:value]
			]
			push [
				either find [set-word! set-path!] type?/word :value [
					append/only expr-stk reduce [:value]
				][
					do store
				]
			]
			prolog [append/only fun-stk last expr-stk]
			epilog [unless empty? fun-stk [take/last fun-stk]]
			set 
			return [
				take/last expr-stk
				do store
			]
			error [options/debug/active?: yes]			;-- forces debug console activation
			init end  [
				clear fun-stk
				clear expr-stk: head expr-stk
				indent: 0
				sch: system/console/history
				if event = 'init [hist-length: length? sch]
				if event = 'end [
					options/debug/active?: no
					remove/part sch (length? sch) - hist-length
				]
			]
		]
		if all [
			options/debug/active?
			not find [init end enter exit prolog epilog expr] event
		][
			if event = 'fetch [event: 'eval]
			prin out: rejoin ["-----> " uppercase mold event space]
			if event = 'set [
				append out set-ref: rejoin [ref space]
				prin set-ref
			]
			limit: calc-max (length? out) + 1
			print either all [any-function? :value not find [set return push] event][
				prin mold/part/flat :ref limit
				rejoin [" (" mold type? :value #")"]
			][
				mold/part/flat :value limit
			]
			if :code [print ["Input:" mold/only/part/flat skip :code offset calc-max 8]]
			
			unless empty? watching			[show-watching]
			if options/debug/show-parents?	[show-parents event]
			if options/debug/show-stack?	[show-stack]
			
			do-command event
			if event = 'error [options/debug/active?: no]
		]
	]
	
	tracers: context [
	
		emit: :print									;-- overridden by the tests suite
		
		;; yet another incarnation of this func
		;@@ remove it when we have smarter `ellipsize` func in runtime
		opening-marker: charset "([{<^""
		closing-markers: "()[]{}<>^"^""
		mold-part: function [value [any-type!] part [integer!] /only] [
			r: mold/flat/part/:only :value part + 1
			if part < length? r [
				open: find/part r opening-marker skip tail r -5
				clear either open [
					close: select closing-markers open/1 
					change change skip tail r -5 "..." close 
				][
					change skip tail r -4 "..."
				]
				clear skip r part						;-- when part < 3-4
			]
			r
		]		
				
		dumper: function [
			event  [word!]
			code   [any-block! none!]
			offset [integer!]
			value  [any-type!]
			ref	   [any-type!]
			frame  [pair!]
		][
			do [system/tools/tracers/emit [uppercase form event offset system/tools/tracers/mold-part :ref 30 system/tools/tracers/mold-part :value 30 frame]]
		]
		
		;; helpers to keep code readable, unlike `change/only back back tail series last series`
		push:   func [s [series!] i [any-type!] /dup n [integer!]] [append/only/dup s :i any [n 1]]
		drop:   func [s [series!] n [integer!]] [clear skip tail s negate n]
		pop:    func [s [series!]] [take/last s]
		top-of: func [s [series!]] [back tail s]
		step:   func [s [series!] /down][change s s/1 + pick [-1 1] down]
		
		;; to display all fetched data in its original unmodified state it is molded
		;; this controls max molded length of every single value before it gets ellipsized
		mold-size: 30
		
		;; free list of blocks to minimize tracer's side effects
		free: context [
			list: make block! 20
			put:  func [block [block!]] [if 100 > length? block [append/only list clear head block]]
			get:  does [any [take/last list  make block! 10]]
			loop 20 [put make block! 10]
		]
		
		;; context for trace data collected by 'collector' tracer and its options
		data: context [
			;; input of collector:
			debug?:          no							;-- /debug refinement (raw events output)
			inspect:         none						;-- inspect function to call
			event-filter:    none						;-- events accepted by this inspect function (none = unfiltered)
			scope-filter:    none						;-- list of scopes accepted by this inspect fn (none = unfiltered)
			inspect-sub-exprs?: none					;-- whether to call inspect on subexpressions
			;; tracked parameters:
			func-depth:      0							;-- function call depth (prolog to epilog)
			expr-depth:      0							;-- nesting level of expressions in each block ('open to return)
			path:            []							;-- path of refs up to current scope (starts empty)
			fetched:         []							;-- original fetched values list
			fetched':        []							;-- same as 'fetched' but everything molded to preserve it
			pushed:          []							;-- pushed and returned values list, making partially evaluated exprs
			pushed':         []							;-- same as 'pushed' but everything molded to preserve it
			subexprs:        []							;-- offsets within pushed/pushed' of last subexpr start (a stack)
			;; saved states to unroll on exception:
			stack:           []							;-- stack of internal call frame (pairs)
			;-- Word list kept for documentation / stack-period. Stage1 does not
			;-- bind words inside object-literal blocks, so get/set word on this
			;-- list would look up globals ("fetched has no value"). save/unroll
			;-- use explicit field access instead.
			saved:           [func-depth expr-depth fetched fetched' pushed pushed' subexprs]
			stack-period:    2 + length? saved			;-- +frame +path size
			
			save-level: function ["Save current nesting level on the stack" frame [pair!] /local d][
				d: system/tools/tracers/data
				append/only d/stack frame
				append/only d/stack length? d/path
				append/only d/stack d/func-depth  d/func-depth: 0
				append/only d/stack d/expr-depth  d/expr-depth: 0
				append/only d/stack d/fetched     d/fetched:  system/tools/tracers/free/get
				append/only d/stack d/fetched'    d/fetched': system/tools/tracers/free/get
				append/only d/stack d/pushed      d/pushed:   system/tools/tracers/free/get
				append/only d/stack d/pushed'     d/pushed':  system/tools/tracers/free/get
				append/only d/stack d/subexprs    d/subexprs: system/tools/tracers/free/get
			]
			unroll-level: function ["Unroll last nesting level from the stack" /local d][
				d: system/tools/tracers/data
				if block? d/subexprs [system/tools/tracers/free/put d/subexprs]
				d/subexprs: take/last d/stack
				if block? d/pushed' [system/tools/tracers/free/put d/pushed']
				d/pushed': take/last d/stack
				if block? d/pushed [system/tools/tracers/free/put d/pushed]
				d/pushed: take/last d/stack
				if block? d/fetched' [system/tools/tracers/free/put d/fetched']
				d/fetched': take/last d/stack
				if block? d/fetched [system/tools/tracers/free/put d/fetched]
				d/fetched: take/last d/stack
				d/expr-depth: take/last d/stack
				d/func-depth: take/last d/stack
				clear skip d/path take/last d/stack
				take/last d/stack
			]
	
			reset: function ["Reset collector's data" /local d][
				d: system/tools/tracers/data
				clear d/path
				clear d/stack
				d/func-depth: 0
				d/expr-depth: 0
				clear d/fetched
				clear d/fetched'
				clear d/pushed
				clear d/pushed'
				clear d/subexprs
			]
			
			;-- Stage1 does not bind nested object methods' bare field words.
			;-- Collector always goes through `d: system/tools/tracers/data`.
			collector: function [
				"Generic tracer that collects high-level tracing info"
				event  [word!]							;-- Event name
				code   [default!]						;-- Currently evaluated block
				offset [integer!]						;-- Offset in evaluated block
				value  [any-type!]						;-- Value currently processed
				ref	   [any-type!]						;-- Reference of current call
				frame  [pair!]							;-- Stack frame start/top positions
				/local d call saved-frame isop? bgn
			][
				d: system/tools/tracers/data
				call: [
					all [								;-- filtering by events, scope, expression level:
						any [none? d/event-filter  find d/event-filter event]
						any [none? d/scope-filter  none? code  find/same/only d/scope-filter code]
						any [
							d/inspect-sub-exprs?
							find [error throw] event
							0 = d/expr-depth
							all [1 = d/expr-depth  find [call return] event]
						]
						d/inspect d event code offset :value :ref frame
					]
				]
				
				;; unroll multiple enter/exit levels at once, after throw/error
				if find [return catch] event [
					saved-frame: pick tail d/stack negate d/stack-period
					while [unless tail? d/stack [saved-frame/1 > frame/1]] [
						d/unroll-level
						saved-frame: pick tail d/stack negate d/stack-period
					]
				]
				
				if find [return epilog exit expr error throw] event [do call]
				
				switch event [
					prolog [d/func-depth: d/func-depth + 1]
					epilog [d/func-depth: d/func-depth - 1]
					
					fetch [
						if any [d/inspect-sub-exprs? not path? code] [
							append/only d/fetched :value
							append/only d/fetched' system/tools/tracers/mold-part :value system/tools/tracers/mold-size
						]
					]
					push  [
						if any [d/inspect-sub-exprs? not path? code] [
							append/only d/pushed :value
							append/only d/pushed' system/tools/tracers/mold-part :value system/tools/tracers/mold-size
						]
					]
					
					open [
						isop?: any [op? :value op? if word? :value [attempt [get/any value]]]
						append/only d/subexprs index? d/pushed
						d/pushed:  either isop? [back tail d/pushed][tail d/pushed]
						d/pushed': either isop? [back tail d/pushed'][tail d/pushed']
						append/only d/pushed  :value
						append/only d/pushed' system/tools/tracers/mold-part :value system/tools/tracers/mold-size
						d/expr-depth: d/expr-depth + 1
					]
					call [
						append/only d/path any [if path? ref [:ref/1] ref <anon>]
					]
					return [
						take/last d/path
						d/expr-depth: d/expr-depth - 1
						bgn: any [take/last d/subexprs 1]
						d/pushed:  at head clear d/pushed bgn
						d/pushed': at head clear d/pushed' bgn
						append/only d/pushed  :value
						append/only d/pushed' system/tools/tracers/mold-part :value system/tools/tracers/mold-size
					]
					enter [
						unless path? code [d/save-level frame]
					]
					exit [
						unless path? code [d/unroll-level]
						if paren? code [
							append/only d/pushed  :value
							append/only d/pushed' system/tools/tracers/mold-part :value system/tools/tracers/mold-size
						]
					]
					expr [
						clear d/fetched
						clear d/fetched'
						clear d/pushed
						clear d/pushed'
					]
				]
				
				unless find [return epilog exit expr error throw] event [do call]
				
				if d/debug? [
					do [system/tools/tracers/emit [
						uppercase pad event 7
						pad type? code 6
						pad :ref 12
						pad frame 6
						pad system/tools/tracers/mold-part :value 20 22
						pad form/part d/fetched' 60 62
						pad d/func-depth 3
						pad d/expr-depth 3
						d/subexprs
					]]
				]
			];; collector function
		];; data context
	
		guided-trace: function [
			"Trace a block of code, providing 'inspect' tracer with collected data"
			inspect [function!] "func [data [object!] event code offset value ref frame]"
			code    [any-type!]
			all?    [logic!]    "Trace all sub-expressions of each expression"
			deep?   [logic!]    "Enter functions and natives"
			debug?  [logic!]    "Dump all events encountered"
		][
			if tracing? [exit]							;-- impossible to hot-swap tracers atm
			data/reset
			data/debug?:       debug?
			data/inspect:      :inspect
			data/inspect-sub-exprs?: all?
			data/event-filter: if block? b: first body-of :inspect [b]
			data/scope-filter: if all [not deep?  any-list? :code] [
				to hash! collect [
					keep/only head code
					parse code rule: [any [
						ahead set b any-block! (keep/only head b) into rule | skip
					]]
				] 
			] 
			do-handler :code :data/collector
		]

		inspector: context [
		
			fixed-width:    none								;-- used in tests to remove environment effects
			last-path:      []									;-- cached, reported only when changed
			constants:      [yes no on off true false none]		;-- common constant names
			type-names:     to [] any-type!						;-- common type names defined in runtime
			; Avoid compose [(constants) (type-names)]: Stage1 redbin can emit those
			; words as globals during object construction, causing "constants has no value".
			ignored-words:  make hash! append copy [yes no on off true false none] to [] any-type!
			; Precomputed from data/saved: [func-depth expr-depth fetched fetched' pushed pushed' subexprs]
			; (index? find saved 'fetched) - (length? saved) - 1 = 3-7-1 = -5. Avoid data/saved path
			; during object construction under Stage1 (path binding gaps).
			fetched-index:  -5
			fetched'-index: -4
						
		 	inspect: function [
		 		data   [object!]						;-- collector's stats
				event  [word!]							;-- Event name
				code   [default!]						;-- Currently evaluated block
				offset [integer!]						;-- Offset in evaluated block
				value  [any-type!]						;-- Value currently processed
				ref	   [any-type!]						;-- Reference of current call
				/local word
			][
				[expr error throw push return]
				report?: all select [
					expr [
						not data/inspect-sub-exprs?
						data/expr-depth = 0				;-- don't report sub-exprs
						not paren? code					;-- don't report paren as top-level, even if it technically is
					]
					error [true]
					throw [true]
					push [
						data/inspect-sub-exprs?
						set/any 'word last data/fetched
						any [word? :word get-word? :word]
						not find system/tools/tracers/inspector/ignored-words word
						word <> last data/pushed		;-- lit/get-args preserve the word - no need to report it
					]
					return [data/inspect-sub-exprs?] 
				] event
				any [report? exit]
				
				full:    any [system/tools/tracers/inspector/fixed-width attempt [system/console/size/1] 80]
				width:   full - 7						;-- last column(1) + " => "(4) + min. indent(2)
				left:    min 60 to integer! width / 2	;-- cap at 60 as we don't want it to be huge
				right:   width - left
				indent:  append/dup clear ""          " " full - 1		;-- indent for code
				indent2: append/dup clear skip "  " 2 "`" full - 3		;-- indent for paths: prefixed by "  "
				level:   (length? data/stack) / data/stack-period - 1
				level:   level % 10 + 1 * 2				;-- cap at 20 as we don't want indent to occupy whole column
				
				expr: case [
					not data/inspect-sub-exprs? [data/fetched']
					event = 'push [back tail data/fetched']
					'else [data/pushed']
				]
				if paren? expr [expr: as [] expr]		;-- otherwise /only won't remove brackets
				if path?  code [expr: as path! expr]
				
				;; print current path, only works in non-/all mode
				unless any [data/inspect-sub-exprs?  data/path == system/tools/tracers/inspector/last-path] [
					path: uppercase system/tools/tracers/mold-part as path! data/path full - 1 - level
					p: change skip indent2 level path			;-- add path of refs
					
					unless empty? pexpr: pick tail data/stack system/tools/tracers/inspector/fetched'-index [
						orig-expr: pick tail data/stack system/tools/tracers/inspector/fetched-index
						name: either path? :orig-expr/1 [:orig-expr/1/1][:orig-expr/1]
						if :name = last data/path [				;-- don't duplicate last path item if orig expr starts with it
							pexpr: next pexpr
						]
						change change p " " form/part pexpr (length? p) - 1		;-- add parent expr to path
					]
					do [system/tools/tracers/emit indent2]
					
					append clear system/tools/tracers/inspector/last-path data/path
				]
				
				;; print expression and result
				change        skip indent level       form/part expr left - level
				change change skip indent left " => " system/tools/tracers/mold-part :value right
				do [system/tools/tracers/emit indent]
			];; inspect function
		];; inspector context
	];; tracers context

	profiler: function [
		event  [word!]
		code   [any-block! none!]
		offset [integer!]
		value  [any-type!]
		ref	   [any-type!]
		frame  [pair!]
	][
		[init call return prolog epilog]				;-- request only those events
		anon: [0]
		
		switch event [
			prolog [									;-- entering a function!
				time: now/precise
				poke skip tail fun-stk -2 1 time		;-- update start-time
			]
			epilog [									;-- exiting a function!
				poke back tail fun-stk 1 now/precise	;-- update start-time
			]
			call   [
				if all [typeset? opt: options/profile/types find opt type? :value][
					if any-function? :ref [ref: append copy <anon> anon/1: anon/1 + 1]
					either pos: find/only/skip profiling ref 3 [
						pos/2: pos/2 + 1
					][
						repend profiling [ref 1 0]
					]
					repend fun-stk [ref now/precise none] ;-- [name start-time end-time]
				]
			]
			return [
				time: now/precise
				unless empty? fun-stk [
					entry: skip tail fun-stk -3
					pos: find/only/skip profiling first entry 3
					pos/3: pos/3 + difference any [entry/3 time] entry/2
					clear entry
				]
			]
			init [
				clear profiling
				clear fun-stk
			]
		]
	]
	
	do-handler: func [code [any-type!] handler [function!]][
		either find [file! url!] type?/word :code [
			do-file code :handler none					;-- delay handler triggering once resource is acquired
		][
			do/trace :code :handler none
		]
	]
	
	set 'profile function [
		"Profile the argument code, counting calls and their cumulative duration, then print a report"
		code [any-type!] "Code to profile"
		/by
			cat [word!]	 "Sort by: 'name, 'count, 'time"
	][
		saved: values-of options/profile
		options/profile/sort-by: any [cat 'count]
		
		set/any 'res do-handler :code :profiler
		if value? 'res [print ["==" mold/part :res calc-max 2 lf]]
		
		by: select [name 1 count 2 time 3] options/profile/sort-by
		either by = 1 [
			sort/skip/compare profiling 3 by			;-- sort in alphabetical order
		][
			sort/skip/reverse/compare profiling 3 by	;-- sort count/time in decreasing order
		]
		rank: 1
		foreach [name cnt duration] profiling [			;-- generate report
			if unset? name [name: "<anonymous>"]
			print [pad append copy "#" rank 4 pad name 16 #"|" pad cnt 10 #"|" pad duration 10]
			rank: rank + 1
		]
		set options/profile saved
		()
	]
	
	set 'trace func [
		"Runs argument code and prints an evaluation trace; also turns on/off tracing"
		code [any-type!] "Code to trace or tracing mode (logic!)"
		/raw   "Switch to raw interpreter events tracing (incompatible with other modes)"
		/deep  "Trace into functions and natives"
		/all   "Trace all sub-expressions of each expression"
		/debug "Used internally to debug the tracer itself (outputs all events)"
	][
		either logic? :code [
			#system [
				use [bool [red-logic!]][
					bool: as red-logic! ~code			;@@ implement a clean way to access locals from R/S code
					assert TYPE_OF(bool) = TYPE_LOGIC
					interpreter/tracing?: bool/value and interpreter/trace?
				]
			]
		][
			either raw [
				do-handler :code :tracers/dumper
			][
				tracers/guided-trace :tracers/inspector/inspect :code all deep debug
			]
		]
	]
	
	set 'debug func [
		"Runs argument code through an interactive debugger"
		code [any-type!] "Code to debug"
		/later			 "Enters the interactive debugger later, on reading @stop value"
	][
		saved: values-of options/debug
		options/debug/active?: not later
		do-handler :code :debugger
		set options/debug saved
		()
	]
]
