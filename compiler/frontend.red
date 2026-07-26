Red [
	Title:   "Red compiler"
	Author:  "Nenad Rakocevic"
	File: 	 %compiler.r
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]


; Top-level helper so frame capture uses true function locals under the native
; compiler. Object-method locals and `do [copy mark ...]` have both failed in Stage1.
red-compiler-take-frame: func [mark [series! none!] /local start][
	unless series? :mark [return make block! 0]
	start: copy mark
	clear mark
	start
]

; Top-level path join avoids method-local/`copy` issues seen in compiled Stage1.
red-compiler-emit-block: func [blk /with main-ctx /sub /local result][
	; Stage1-safe: avoid object-method refinements; use pending fields instead.
	compiler-redbin-emitter/pending-with-ctx: either with [main-ctx][none]
	compiler-redbin-emitter/pending-sub?: to logic! sub
	do [compiler-redbin-emitter/emit-block blk]
	compiler-redbin-emitter/pending-with-ctx: none
	compiler-redbin-emitter/pending-sub?: no
	result: compiler-redbin-emitter/last-index
	either integer? :result [result][0]
]

red-compiler-emit-context: func [
	name [word!] spec [block!] stack? [logic!] self? [logic!] type [word!] /root /local result
][
	compiler-redbin-emitter/pending-root?: to logic! root
	do [compiler-redbin-emitter/emit-context name spec stack? self? type]
	compiler-redbin-emitter/pending-root?: no
	result: compiler-redbin-emitter/last-index
	either integer? :result [result][0]
]

red-compiler-emit-word-root: func [
	word ctx [word! none!] ctx-idx [integer! none!] /set? /local result
][
	compiler-redbin-emitter/pending-root?: yes
	compiler-redbin-emitter/pending-set?: to logic! set?
	do [compiler-redbin-emitter/emit-word word ctx ctx-idx]
	compiler-redbin-emitter/pending-root?: no
	compiler-redbin-emitter/pending-set?: no
	result: compiler-redbin-emitter/word-index
	either integer? :result [result][0]
]

red-compiler-emit-string-root: func [value /local result][
	do [compiler-redbin-emitter/emit-string/root value]
	result: compiler-redbin-emitter/string-index
	either integer? :result [result][0]
]

red-compiler-emit-typeset-root: func [v1 [integer!] v2 [integer!] v3 [integer!] /local result][
	do [compiler-redbin-emitter/emit-typeset/root v1 v2 v3]
	result: compiler-redbin-emitter/typeset-index
	either integer? :result [result][0]
]

red-compiler-emit-native: func [id [word!] spec [block!] /action /local result][
	compiler-redbin-emitter/pending-action?: to logic! action
	do [compiler-redbin-emitter/emit-native id spec]
	compiler-redbin-emitter/pending-action?: no
	true
]

red-compiler-safe-copy: func [value][
	; Never call copy on none!/unset in compiled Stage1 paths.
	either series? :value [copy value][make block! 0]
]

red-compiler-join-obj-stack: func [stack item /local out value][
	unless path? :stack [stack: to path! 'objects]
	out: make block! 8
	foreach value to block! stack [append out value]
	either path? item [
		foreach value to block! item [append out value]
	][
		append out item
	]
	to path! out
]

red: context [
	verbose:	   0									;-- logs verbosity level
	job: 		   none									;-- reference the current job object
	script-name:   none
	script-path:   none
	script-file:   none									;-- #system metadata for R/S loader
	main-path:	   none
	runtime-path:  %runtime/
	include-stk:   make block! 3
	included-list: make block! 20
	script-stk:	   make block! 10
	needed:		   make block! 4
	symbols:	   make hash! 1000
	globals:	   make hash! 1000						;-- words defined in global context
	aliases: 	   make hash! 100
	contexts:	   make hash! 100						;-- storage for statically compiled contexts
	ctx-stack:	   make block! 8						;-- contexts access path
	shadow-funcs:  make block! 1000						;-- shadow functions contexts [symbol object! ctx...]
	objects:	   make block! 600						;-- shadow objects contexts [name object! ctx...]
	obj-stack:	   to path! 'objects					;-- current object access path
	container-obj?: none								;-- closest wrapping object
	func-objs:	   none									;-- points to 'objects first in-function object
	paths-stack:   make block! 4						;-- stack of generated code for handling dual codepaths for paths
	native-ts:	   make block! 200						;-- prepared native! typesets: [name [<ts-list>] ...]
	bindings:	   compiler-bindings
	binding-of:	   :context?
	rebol-gctx:	   binding-of 'rebol
	expr-stack:	   make block! 8
	current-call:  none
	currencies:	   none									;-- extra user-defined currency codes from script's header
	lexer:		   compiler-lexer
	extracts:	   compiler-extractor
	redbin:		   compiler-redbin-emitter
	preprocessor: compiler-preprocessor
	
	sys-global:    make block! 1
	lit-vars: 	   reduce [
		'block	   make hash! 1000
		'string	   make hash! 1000
		'context   make hash! 1000
		'typeset   make hash! 100
	]
	 
	pc: 		   none
	locals:		   none
	locals-stack:  make block! 32
	output:		   make block! 100
	frame-stack:   make block! 16					;-- nested set-word mark positions
	sym-table:	   make block! 1000
	literals:	   make block! 1000
	declarations:  make block! 1000
	boot-extras:   make block! 100
	bodies:		   make block! 1000
	ssa-names: 	   make block! 10						;-- unique names lookup table (SSA form)
	types-cache:   make hash!  100						;-- store compiled typesets [types array name...]
	last-type:	   none
	return-def:    to-set-word 'return					;-- return: keyword
	s-counter:	   0									;-- series suffix counter
	depth:		   0									;-- expression nesting level counter
	max-depth:	   0
	root-slots:	   0									;-- extra root block slots counter
	booting?:	   none									;-- YES: compiling boot script
	nl: 		   newline
	comment-marker: '------------|
	include-directive: to issue! "include"
	get-definition-directive: to issue! "get-definition"
 
	unboxed-set:   [integer! char! float! float32! logic!]
	block-set:	   [block! paren! path! set-path! lit-path! get-path!]
	string-set:	   [string! binary!]
	series-set:	   union block-set string-set
	
	actions: 	   make block! 100
	op-actions:	   make block! 20
	keywords: 	   make block! 10
	
	actions-prefix: to path! 'actions
	natives-prefix: to path! 'natives
	
	intrinsics:   [
		if unless either any all while until loop repeat
		forever foreach forall func function does has
		exit return switch case routine set get reduce
		context object construct try break continue
		remove-each
	]
	
	logic-words:  [true false yes no on off]
	operator-symbols: make map! [
		"+"  "op_add"
		"-"  "op_subtract"
		"*"  "op_multiply"
		"/"  "op_divide"
		"//" "op_modulo"
		"%"  "op_remainder"
		"="  "op_equal"
		"<>" "op_not_equal"
		"==" "op_strict_equal"
		"=?" "op_same"
		"<"  "op_lesser"
		">"  "op_greater"
		"<=" "op_lesser_equal"
		">=" "op_greater_equal"
		"<<" "op_shift_left"
		">>" "op_shift_right"
		">>>" "op_shift_logical"
		"**" "op_power"
	]
	
	word-iterators: [repeat foreach forall remove-each]	;-- only the ones using word(s) as counter(s)
	
	iterators: [loop until while repeat foreach forall forever remove-each]
	
	standard-modules: compiler-modules

	func-constructors: [
		'func | 'function | 'does | 'has | 'routine | 'make 'function!
	]

	functions: make hash! 1000
	append functions 'make
	append/only functions reduce [
		'action! 2 [type [datatype! word!] spec [any-type!]] none
	]											;-- MAKE must be pre-defined
	
	make-keywords: does [
		foreach [name spec] functions [
			if spec/1 = 'intrinsic! [
				repend keywords [name reduce [to word! join "comp-" name]]
			]
		]
		bind keywords self
	]

	set-last-none: does [copy [stack/reset none/push-last]]	;-- copy required for R/S line counting injection

	--not-implemented--: does [print "Feature not yet implemented!" halt]
	abs: :absolute
	
	quit-on-error: does [
		clean-up
		if system/options/args [quit/return 1]
		halt
	]
	
	cut-lines: func [s [string!] n [integer!] /local c p][
		c: 0
		parse s [any [#"^/" p: (if n <= (c: c + 1) [append clear p "...]"]) | skip]]
		s
	]

	throw-error: func [err [word! string! block!] /near code [block!]][
		print [
			"*** Compilation Error:"
			either word? err [
				join uppercase/part mold err 1 " error"
			][reform err]
			"^/*** in file:" any [attempt [to-local-file script-name] "??"]
			;either locals [join "^/*** in function: " func-name][""]
		]
		if pc [
			print [
				;"*** at line:" calc-line lf
				"*** near:" cut-lines mold any [code copy/part pc 8] 40
			]
		]
		quit-on-error
	]

	fail: func [err [string! block!] /near code [block!]][
		print ["*** Compiler Internal Error:" reform err]
		if pc [
			print [
				;"*** at line:" calc-line lf
				"*** near:" mold any [code copy/part pc 8]
			]
		]
		quit-on-error
	]
	
	dispatch-ctx-keywords: func [original [any-word! none!] /with alt-value][
		if path? alt-value [alt-value: alt-value/1]
		
		switch/default any [alt-value pc/1][
			func	  [comp-func]
			function  [comp-function]
			has		  [comp-has]
			does	  [comp-does]
			routine	  [comp-routine]
			construct [comp-construct]
			object
			context	  [
				either obj: is-object? pc/2 [
					comp-context/with/extend original obj
				][
					comp-context/with original
				]
			]
		][no]
	]
	
	relative-path?: func [file [file!] /local ch][
		if empty? file [return yes]
		ch: first file
		not find "/~" ch
	]

	resolve-include-file: func [file [file!] /local bases base candidate][
		unless relative-path? file [return clean-path file]
		bases: copy []
		if script-path [append bases script-path]
		unless empty? script-stk [
			append bases first split-path last script-stk
		]
		if main-path [
			append bases main-path
			append bases append copy main-path %system/
		]
		if all [value? 'system object? system/options system/options/path][
			append bases system/options/path
			append bases append copy system/options/path %system/
		]
		foreach base bases [
			candidate: clean-path append copy base file
			if exists? candidate [return candidate]
		]
		clean-path append copy any [script-path main-path %""] file
	]

	process-include-paths: func [code [block!] /local rule file nested saved-script-path][
		saved-script-path: script-path
		parse code rule: [
			some [
				include-directive file: (
					script-path: any [script-path main-path]
					if all [script-path relative-path? file/1][
						file/1: clean-path append copy script-path file/1
					]
					unless empty? script-stk [
						insert next file reduce [#script last script-stk]
					]
				)
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
		script-path: saved-script-path
	]
	
	process-calls: func [code [block!] /global /local rule pos mark nested][
		parse code rule: [
			some [
				#call pos: (
					mark: tail output
					process-call-directive pos/1 to logic! global
					change/part back pos mark 2
					clear mark
				)
				| #get pos: (process-get-directive pos/1 back pos)
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
	]
	
	process-routine-calls: func [code [block!] ctx [word!] ignore [block!] obj [object!] /local rule name nested][
		parse code rule: [
			some [
				name: word! (
					if all [in obj name/1 not find ignore name/1][
						name/1: decorate-obj-member name/1 ctx
					]
				)
				| path! | set-path! | lit-path!
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
	]
	
	; TRANSCODE has already decoded UTF-8 strings into Red's native string form.
	preprocess-strings: func [code [block!]][code]
	
	convert-to-block: func [mark [block!]][
		change/part/only mark copy/deep mark tail mark	;-- put code between [...]
		clear next mark									;-- remove code at "upper" level
	]
	
	insert-head-last: func [body [block!] /local mark][
		mark: tail output
		do body
		insert mark/-1 mark
		clear mark
	]
	
	to-nibbles: func [
		src [string! money!]
		/local out text negative? marker code digits point decimals
	][
		if money? :src [
			text: mold/all src
			negative?: find "+-" text/1
			if negative? [negative?: text/1 = #"-" remove text]
			marker: find text #"$"
			code: either marker = head text ["..."][copy/part text marker]
			digits: copy next marker
			replace/all digits "'" ""
			either point: find digits #"." [
				decimals: length? next point
				remove point
			][decimals: 0]
			append/dup digits #"0" 5 - decimals
			insert/dup digits #"0" 22 - length? digits
			return reduce [
				to logic! negative?
				to-currency-code code
				to-nibbles digits
			]
		]
		; Pack amount as string of char codes 0-255. Emitter stores c-string as
		; Latin-1 bytes (not UTF-8), so high nibbles stay single bytes.
		out: make string! 11
		foreach [high low] src [
			append out to char! add
				shift/left (to integer! high - #"0") 4
				to integer! low - #"0"
		]
		out
	]
	
	to-currency-code: func [code [string!] /local pos][
		code: to word! code
		case [
			pos: find extracts/currencies code [index? pos]
			all [currencies pos: find currencies code][(index? pos) + length? extracts/currencies]
			code = '... [0]
			'else [throw-error ["unknown money! currency" code ", add it to the Currencies: header."]]
		]
	]
	
	any-function?: func [value [word!]][
		find [native! action! op! function! routine!] value
	]
	
	scalar?: func [expr][
		find [
			unset!
			none!
			logic!
			datatype!
			char!
			integer!
			float!
			refinement!
			issue!
			lit-word!
			word! 
			get-word!
			set-word!
			pair!
			percent!
			point2D!
			point3D!
			money!
			tuple!
			ref!
			time!
			date!
		] type?/word :expr
	]
	
	local-bound?: func [original [any-word!] /local obj][
		all [
			not empty? locals-stack
			rebol-gctx <> obj: binding-of original
			bindings/shadow-entry-of obj
		]
	]
	
	local-word?: func [name [word!]][
		all [not empty? locals-stack find last locals-stack name]
	]
	
	insert-lf: func [pos][
		new-line skip tail output pos yes
	]
	
	emit: func [value][
		either block? value [append output value][append/only output value]
	]
		
	emit-src-comment: func [pos [block! paren! none!] /with cmt [string!]][
		unless cmt [
			cmt: trim/lines mold/only/flat clean-lf-deep copy/deep/part pos offset? pos pc
		]
		if 50 < length? cmt [cmt: append copy/part cmt 50 "..."]
		emit reduce [
			comment-marker (cmt)
		]
	]
	
	find-ssa: func [name [word!]][find/skip ssa-names name 2]
	
	select-ssa: func [name [word!] /local pos][
		all [pos: find/skip ssa-names name 2 pos/2]
	]
	
	parent-object?: func [obj [object!]][
		all [not empty? locals-stack object? container-obj? same? obj container-obj?]
	]
	
	find-binding: func [original [any-word!] /local ctx idx obj][
		all [
			ctx: all [
				rebol-gctx <> obj: binding-of original
				any [select-obj obj bindings/shadow-context-of obj]
			]
			attempt [idx: get-word-index/with to word! original ctx]
			reduce [ctx idx]
		]
	]
	
	select-object: func [ctx [word!] /local pos][
		pos: find objects ctx
		either object? pos/2 [pos/2][pos/-1]
	]

	bind-function: func [body [block!] shadow [object!] /local self* rule pos wrapper head-word][
		bind body shadow
		if 1 < length? obj-stack [
			wrapper: either path? :obj-stack [safe-eval-object-path obj-stack][none]
			if object? wrapper [
				; Red objects do not expose a real self word to in (unlike Rebol).
				; Build a word bound to the wrapper object, then rebind both bare SELF
				; and SELF path heads so method bodies resolve object fields.
				self*: any [
					in wrapper 'self
					first bind copy [self] wrapper
				]
				parse body rule: [
					any [
						pos: word! (
							if pos/1 = 'self [pos/1: self*]
						)
						| pos: [path! set-path! get-path! lit-path!] (
							head-word: pick pos/1 1
							if all [any-word? :head-word to word! head-word = 'self][
								change at pos/1 1 self*
							]
						)
						| pos: [block! | paren!] :pos into rule
						| skip
					]
				]
			]
		]
	]
	
	get-word-index: func [name [word!] /with c [word!] /local ctx pos list][
		if with [
			ctx: select contexts c
			return either pos: find ctx name [(index? pos) - 1][none]
		]
		list: tail ctx-stack
		until [											;-- search backward in parent contexts
			list: back list
			ctx: select contexts list/1
			if pos: find ctx name [
				return (index? pos) - 1					;-- 0-based access in context table
			]
			head? list
		]
		throw-error ["Should not happen: not found context for word: " mold name]
	]
	
	emit-word-ref: func [name [any-word!] /no-prefix /local obj idx ctx][
		case [
			rebol-gctx = obj: binding-of name [
				emit either no-prefix [decorate-symbol name][prefix-exec name]
			]
			all [ctx: select-obj obj attempt [idx: get-word-index/with name ctx]][
				emit 'word/push-local
				emit either parent-object? obj ['octx][ctx] ;-- optional parametrized context reference (octx)
				emit idx
			]
			ctx: bindings/shadow-context-of obj [
				emit 'word/push-local
				emit ctx
				emit get-word-index name					;@@ replace that
			]
			'else [throw-error ["Should not happen: undefined context for word:" name]]
		]
	]
	
	emit-push-from: func [
		name [any-word!] original [any-word!] type [word!] actions [block!]
		/local ctx obj idx
	][
		;-- Resolve object-local words: prefer binding of `original`, then current
		;-- obj-stack (Stage1 often leaves body words unbound after load).
		ctx: all [
			rebol-gctx <> obj: binding-of original
			select-obj obj
		]
		unless all [ctx attempt [idx: get-word-index/with name ctx]][
			if all [
				1 < length? obj-stack
				obj: attempt [safe-eval-object-path obj-stack]
				object? :obj
				ctx: select-obj obj
				attempt [idx: get-word-index/with name ctx]
			][0][ctx: none]
		]
		either all [ctx integer? idx][
			emit append to path! type actions/1
			emit either parent-object? obj ['octx][ctx] ;-- optional parametrized context reference (octx)
			emit idx
			insert-lf -3
		][
			emit append to path! type actions/2
			emit prefix-exec name
			insert-lf -2
		]
	]
	
	emit-push-word: func [name [any-word!] original [any-word!] /local type ctx obj][
		type: to word! form type? :name
		name: to word! :name
		
		either all [
			rebol-gctx <> obj: binding-of original
			ctx: bindings/shadow-context-of obj
			name <> 'self
		][
			emit append to path! type 'push-local
			emit ctx
			emit get-word-index name					;@@ replace that 
			insert-lf -3
		][
			emit-push-from name original type [push-local push]
		]
	]
	
	emit-get-word: func [name [word!] original [any-word!] /any? /literal /local new obj ctx][
		either all [
			rebol-gctx <> obj: binding-of original
			ctx: bindings/shadow-context-of obj
		][	
			either all [not empty? ctx-stack ctx <> last ctx-stack][
				emit 'word/get-local
				emit ctx
				emit get-word-index name				;-- word from another function context
				insert-lf -3
				exit
			][
				emit 'stack/push						;-- local word
			]
			emit decorate-symbol/no-alias name
		][
			if all [new: select-ssa name not find-function new new][name: new]
			emit case [									;-- global / object word
				all [
					literal
					obj = rebol-gctx
					;-- Stay on get-word/get only when not inside an object body.
					1 = length? obj-stack
				][
					'get-word/get
				]
				any?  ['word/get-any]
				'else [
					;-- Pass `original` so object binding (or obj-stack fallback) is kept
					emit-push-from name original 'word [get-local get]
					exit
				]
			]
			emit decorate-symbol name
		]
		insert-lf -2
	]
	
	get-path-word: func [
		original [any-word!] blk [block!] get? [logic!] first? [logic!]
		/local name new obj ctx idx
	][
		name: to word! original
		
		either all [
			rebol-gctx <> obj: binding-of original
			bindings/shadow-context-of obj
		][
			either get? [
				append blk decorate-symbol/no-alias name ;-- local word, point to value slot
			][
				append blk [as cell! get-root]
				append blk red-compiler-emit-word-root name select-obj obj none
			]
		][
			if all [new: select-ssa name not find-function new new][name: new]
			either get? [
				either all [
					rebol-gctx <> obj
					ctx: select-obj obj
					attempt [idx: get-word-index/with name ctx]
				][
					repend blk [
						pick [word/get-local word/push-local] get-word? original
						either parent-object? obj ['octx][ctx] ;-- optional parametrized context reference (octx)
						idx
					]
				][	
					unless first? [append/only blk '_context/get]
					append/only blk prefix-exec name
				]
			][
				append blk [as cell! get-root]
				append blk red-compiler-emit-word-root name none none
			]
			
		]
		blk
	]

	emit-open-frame: func [name [word!] /with type ctx-name /local symbol][
		symbol: either name = 'try-all ['try][name]
		unless find symbols symbol [add-symbol symbol]
		either any [
			type = 'function!
			'function! = all [
				not with
				type: find functions name
				first first next type
			]
		][
			emit 'stack/mark-func
			emit prefix-exec symbol
			emit get-func-ctx name ctx-name
			insert-lf -3
		][
			emit case [
				find iterators name ['stack/mark-loop]
				name = 'try			['stack/mark-try]
				name = 'try-all		['stack/mark-try-all]
				name = 'catch		['stack/mark-catch]
				'else				['stack/mark-native]
			]
			emit prefix-exec symbol
			insert-lf -2
		]
	]
	
	emit-close-frame: func [/last][
		emit pick [stack/unwind-last stack/unwind] to logic! last
		insert-lf -1
	]
	
	emit-stack-reset: does [
		emit 'stack/reset
		insert-lf -1
	]
	
	emit-dyn-check: does [
		;emit 'stack/check-call
		;insert-lf -1
	]
	
	build-exception-handler: has [body][
		body: make block! 8
		append body [
			0					[0]
		]
		unless find expr-stack 'while-cond [
			either empty? intersect iterators expr-stack [
				append body [
					RED_THROWN_BREAK
					RED_THROWN_CONTINUE [re-throw]
				]
			][
				append body [
					RED_THROWN_BREAK    [system/thrown: 0 break]
					RED_THROWN_CONTINUE [system/thrown: 0 continue]
				]
			]
		]
		append body [
			RED_THROWN_RETURN
		]
		append/only body pick [
			[re-throw]
			[stack/unroll stack/FRAME_FUNCTION ctx/values: saved system/thrown: 0 exit]
		] empty? locals-stack
		
		append body [
			RED_THROWN_EXIT
		]
		append/only body pick [
			[re-throw]
			[ctx/values: saved system/thrown: 0 exit]
		] empty? locals-stack

		append body [
			default [re-throw]
		]
		reduce [body]
	]
	
	emit-function: func [name [word!] /with ctx-name [word!]][
		emit decorate-func name
		insert-lf either with [emit ctx-name -2][-1]
	]
	
	emit-action: func [name [word!] /with options [block!]][
		emit join actions-prefix to word! join name #"*"
		insert-lf either with [
			emit options
			-1 - length? options
		][
			-1
		]
	]
	
	emit-native: func [name [word!] /with options [block!] /applied code [block!] /local wrap? pos body][
		if wrap?: to logic! find [parse do] name [
			emit compose [
				assert system/thrown = 0
				(either applied [first [system/thrown:]]['switch])
			]
		]
		either applied [
			emit code
			insert-lf -2
			if wrap? [
				emit [switch system/thrown]
				insert-lf -2
			]
		][
			emit join natives-prefix to word! join name #"*"
			emit 'true										;-- request run-time type-checking
			pos: either with [
				emit options
				-2 - length? options
			][
				-2
			]
			insert-lf pos - pick [1 0] wrap?
		]
		if wrap? [
			emit build-exception-handler
			emit [
				system/thrown: 0
			]
		]
	]
	
	emit-exit-function: does [
		emit [
			stack/unroll-to body-top yes
			ctx/values: saved
			exit
		]
		insert-lf -5
	]
	
	emit-deep-check: func [path [series!] fpath [path!] /local obj-stk list check check2 obj top? parent-ctx][
		check:  [
			'object/unchanged?
				prefix-exec path/1						;-- word (object! value)
				third obj: find-obj either path? :obj-stk [safe-eval-object-path obj-stk][none]		;-- class id (integer!)
		]
		check2: [
			'object/unchanged2?
				parent-ctx								;-- ctx (node!)
				get-word-index/with path/1 parent-ctx	;-- object slot in parent's ctx
				third obj: find-obj either path? :obj-stk [safe-eval-object-path obj-stk][none]		;-- class id
		]
		obj-stk: copy/part fpath (index? find fpath path/1) - 1
		obj-stk/1: either find-contexts path/1 ['func-objs]['objects]

		either 2 = length? path [
			append obj-stk path/1
			reduce check
		][
			list: make block! 3 * length? path
			while [not tail? next path][
				append obj-stk path/1
				repend list get pick [check check2] head? path
				parent-ctx: obj/2
				path: next path
			]
			new-line list on
			new-line skip list 3 on
			new-line/all/skip skip list 3 on 4
			reduce ['all list]
		]
	]
	
	get-native-ID: func [name [word!] native? [logic!] /local id][
		name: join pick ["NAT_" "ACT_"] native? replace/all uppercase form name #"-" #"_"
		id: select extracts/definitions to-word name
		unless integer? id [fail ["get-native-ID failed on:" name native?]]
		id
	]
	
	get-RS-type-ID: func [name [word! datatype!] /word /local type][ ;-- Red type name to R/S type ID
		name: either datatype? name [form name][
			head remove back tail form name				;-- remove ending #"!"
		]
		replace/all name #"-" #"_"
		type: to word! uppercase head insert name "TYPE_"
		either word [type][select extracts/definitions type]
	]
	
	make-typeset: func [
		spec [block!] option [block! none!] f-spec [block!] native? [logic!]
		/local bs ts word bit idx name current red-name
	][
		spec: sort spec									;-- sort types to reduce cache misses
		
		either bs: find/only/skip types-cache spec 4 [
			ts: bs/2
			name: bs/3
		][
			ts: copy [0 0 0]

			foreach type spec [
				unless block? type [
					case [
						find [red/cell! red-value!] type [type: 'any-type!]
						all [red-name: form type find/match red-name "red-"] [
							type: to word! skip red-name 4
						]
						true []
					]
					type: either word: in extracts/scalars type [get word][reduce [type]]

					foreach word type [
						bit: get-RS-type-ID name: word
						unless bit [throw-error/near ["invalid datatype name:" name] f-spec]
						idx: (to integer! (bit / 32)) + 1
						current: pick ts idx
						unless integer? current [
							throw-error/near ["datatype ID outside typeset range:" name bit] f-spec
						]
						poke ts idx current or (shift/logical -2147483648 (bit and 31))
					]
				]
			]
			
			idx: red-compiler-emit-typeset-root ts/1 ts/2 ts/3
			redirect-to literals [
				name: decorate-series-var 'ts
				emit compose [(to set-word! name) as red-typeset! get-root (idx)]
				insert-lf -5
			]
			append types-cache reduce [spec ts name idx]
		]
		spec: either option [
			option: to word! join "~" clean-lf-flag option/1
			reduce ['type-check-alt option name]
		][
			reduce ['type-check name]
		]
		if native? [
			clear back tail spec
			append spec compose [as red-typeset! get-root (any [idx bs/4])]
		]
		spec
	]
	
	emit-type-checking: func [name [any-word!] spec [block!] /native /local pos type][
		unless native [name: to word! next form name]	;-- remove prefix decoration
		
		either pos: any [
			find/same spec name
			find/same spec to lit-word! name
		][
			type: case [
				all [block? pos/2 not empty? pos/2]	[pos/2]
				all [string? pos/3 block? pos/3]	[pos/3]
				'else 								[[default!]]
			]
			make-typeset type find/reverse pos refinement! spec to logic! native
		][
			none
		]
	]
	
	symbol-index?: 	func [spec [block!] name [word!] /local c p][
		c: 0
		parse spec [
			some [
				p: [word! | refinement! | lit-word! | get-word!]
				   (if name = to word! p/1 [return c] c: c + 1)
				| skip
			]
		]
		fail ["symbol" mold name "not found in local context:" mold spec]
	]
	
	emit-argument-type-check: func [
		index [integer!] name [word!] slot [block! word! path!]
		/local spec count arg
	][
		spec: functions/:name/3
		count: 0
		forall spec [
			if find [word! lit-word! get-word!] type?/word spec/1 [
				either count = index [arg: spec/1 break][count: count + 1]
			]
		]

		emit emit-type-checking/native arg spec
		emit index
		emit slot
		insert-lf -7
	]
	
	get-func-ctx: func [name [word!] obj [word! none!] /local original alter entry][
		original: name
		if all [obj not find form name form obj][
			name: to word! rejoin [obj "~" clean-lf-flag name]
		]
		all [
			alter: get-prefix-func name
			find-function decorate-func alter name
			name: alter
		]
		all [alter: select-ssa name name: alter]
		any [
			all [
				entry: any [
					find shadow-funcs decorate-func name
					find shadow-funcs decorate-func original
				]
				decorate-exec-ctx entry/3
			]
			'null
		]
	]
	
	get-counter: does [s-counter: s-counter + 1]
	
	clean-lf-deep: func [blk [block! paren!] /local pos nested][
		blk: copy/deep blk
		parse blk rule: [
			pos: (new-line/all pos off)
			nested: [block! | paren!] :nested into rule | skip
		]
		blk
	]

	clean-lf-flag: func [name [word! lit-word! set-word! get-word! refinement!] /local text encoded][
		text: form name
		if all [
			any [get-word? name lit-word? name refinement? name]
			(not empty? text)
			find ":'/" text/1
		][remove text]
		if all [(set-word? name) (not empty? text) (last text) = #":"][remove back tail text]
		encoded: select operator-symbols text
		unless encoded [replace/all text "/" "_slash_"]
		any [encoded text]
	]
	
	prefix-func: func [word [word!] /with path /local obj ctx][
		; Prefer shadow object ctx so registration (ctx~method) matches
		; obj-func-path?/inherit-functions lookup via select-obj.
		if 1 < length? obj-stack [
			obj: any [
				all [path? :path safe-eval-object-path path]
				all [object? :container-obj? container-obj?]
				all [path? :obj-stack safe-eval-object-path obj-stack]
			]
			ctx: any [
				all [object? :obj select-obj obj]
				obj-func-call? word
				next any [path obj-stack]
			]
			word: decorate-obj-member word ctx
		]
		word
	]
	
	prefix-exec: func [word [word!]][
		either any [empty? locals-stack not find-contexts word][
			decorate-symbol word
		][
			decorate-exec-ctx decorate-symbol word ;-- 'exec prefix to access the word! and not the local value
		]
	]
	
	generate-anon-name: has [name][
		add-symbol name: to word! rejoin ["~anon" get-counter #"~"]
		name
	]
	
	decorate-obj-member: func [word [word!] path /local value][
		parse value: mold path [some [p: #"/" (p/1: #"~") | skip]]
		to word! rejoin [value #"~" word]
	]
	
	decorate-type: func [type [word!]][
		to word! join "red-" mold/flat type
	]
	
	decorate-exec-ctx: func [name [word!]][
		append to path! 'exec name
	]
	
	decorate-symbol: func [name [word!] /no-alias /local pos text result cleaned][
		if all [not no-alias not local-word? name pos: find/case/skip aliases name 2][name: pos/2]
		cleaned: clean-lf-flag name
		text: append copy "~" form cleaned
		set/any 'result try [to word! text]
		if error? :result [
			; Stage1/Red: some words cannot be re-loaded after ~ decoration
			; use hex-encoded spelling as a stable R/S identifier instead
			; word/load still uses the original symbol spelling via add-symbol.
			text: rejoin ["~s" enbase/base to binary! form cleaned 16]
			set/any 'result try [to word! text]
		]
		if error? :result [throw-error ["cannot decorate symbol" mold name "as" mold text]]
		result
	]
	
	decorate-func: func [name [any-word!] /strict /local new][
		name: to word! clean-lf-flag name
		if all [not strict new: select-ssa name][name: new]
		to word! join "f_" clean-lf-flag name
	]
	
	decorate-series-var: func [name [word!] /local new list][
		new: to word! append append mold/flat name "||" get-counter
		list: select lit-vars select [blk block str string ctx context ts typeset] name
		if all [list not find list new][append list new]
		new
	]
	
	declare-variable: func [name [string! word!] /init value /local var set-var][
		set-var: to set-word! var: to word! name

		unless find declarations set-var [
			repend declarations [set-var any [value 0]]	;-- declare variable at root level
			new-line skip tail declarations -2 yes
		]
		reduce [var set-var]
	]
	
	add-symbol: func [name [word!] /only /with original /local sym id alias][
		unless find/case symbols name [
			if find symbols name [
				if find/case/skip aliases name 2 [exit]
				alias: decorate-series-var name
				repend aliases [name alias]
			]
			sym: decorate-symbol name
			id: 1 + ((length? symbols) / 2)
			unless only [repend symbols [name reduce [sym id]]]
			repend sym-table [
				to set-word! sym 'word/load mold any [original name]
			]
			root-slots: root-slots + 1
			new-line skip tail sym-table -3 on
		]
	]
	
	add-global: func [name [word!]][
		unless any [
			local-word? name
			find globals name
		][
			repend globals [name 'unset!]
		]
	]
	
	push-call: func [name [word! tag!]][
		append expr-stack name
	]
	
	pop-call: does [
		remove back tail expr-stack
	]
	
	add-context: func [ctx [block!] /local name][
		append contexts name: decorate-series-var 'ctx
		append/only contexts ctx
		name
	]
	
	push-context: func [ctx [block!] /local name][
		append ctx-stack name: add-context ctx
		name
	]
	
	pop-context: does [
		clear back tail ctx-stack
	]
	
	find-contexts: func [name [word!]][
		ctx: tail ctx-stack
		while [not head? ctx][
			ctx: back ctx
			if find select contexts ctx/1 name [return ctx/1]
		]
		none
	]
	
	to-context-spec: func [spec [block! none!] /local pos fields name][
		spec: red-compiler-safe-copy spec
		if pos: find spec 'self [remove pos]			;-- avoid setting object/self to none (issue #5687)
		fields: make block! (2 * length? spec)
		foreach name spec [
			append fields to set-word! name
			append/only fields none
		]
		make object! fields
	]
	
	iterator-pending?: does [
		not empty? intersect expr-stack iterators
	]
	
	join-obj-stack: func [item [word! path!]][
		red-compiler-join-obj-stack obj-stack item
	]
	
	get-obj-base: func [name [any-word!]][
		either local-word? name [func-objs][objects]
	]
	
	get-obj-base-word: func [name [any-word!]][
		either local-word? name ['func-objs]['objects]
	]
	
	find-object: func [spec [word! object!] /by-name][
		case [
			by-name [find/skip objects spec 6]
			; Red object! equality is by value. Distinct shadow objects with the
			; same fields (e.g. two make object! [a: none]) collide under plain
			; find/select and reuse the first object's context (fcobj/a after sf1).
			; Rebol treated distinct objects as unequal, so identity was implicit.
			'else	[back find/same/skip next objects spec 6]
		]
	]

	; Identity lookup helpers for the objects registry (see find-object note).
	select-obj: func [obj [object! none!]][
		all [object? :obj select/same objects obj]
	]

	find-obj: func [obj [object! none!]][
		all [object? :obj find/same objects obj]
	]
	
	find-proto: func [obj [block!] fun [word!] /local proto o multi?][
		if proto: obj/4 [
			all [
				multi?: 2 = length? proto				;-- multiple inheritance case
				in proto/1 fun
				in proto/2 fun
				return obj/1							;-- method redefined in spec
			]
			if in proto/1 fun [return obj/1]			;-- check <spec> prototype
			if o: find-proto find-obj proto/1 fun [return o] ;-- recurse into previous prototypes
			
			unless proto/2 [return none]				;-- finish if simple inheritance case
			if in proto/2 fun [return proto/2]			;-- check <base> prototype
			if o: find-proto find-obj proto/2 fun [return o] ;-- recurse into previous prototypes
		]
		none
	]
	
	safe-eval-object-path: func [fpath [path!] /local root value pos name entry][
		; Walk object paths without `do path` (compiled Stage1 path access on
		; none escapes attempt and aborts the compiler).
		if any [none? :fpath empty? fpath][return none]
		either find [objects func-objs] fpath/1 [
			; Flat objects registry: [name obj ctx id proto events] * N
			; `func-objs` is a tail pointer into the same table for objects
			; declared inside the current function body. Search only from that
			; tail so function parameters named like prior globals (e.g. o/x)
			; do not resolve to earlier global shadow objects.
			unless all [2 <= length? fpath word? fpath/2][return none]
			entry: either all [
				fpath/1 = 'func-objs
				any-block? :func-objs
			][func-objs][objects]
			while [not tail? entry][
				if all [entry/1 = fpath/2 object? entry/2][
					value: entry/2
					pos: skip fpath 2
					while [not tail? pos][
						unless object? :value [return none]
						name: pos/1
						unless all [word? name in value name][return none]
						value: get in value name
						pos: next pos
					]
					return either object? :value [:value][none]
				]
				entry: skip entry 6
			]
			none
		][
			; Nested object tree rooted at a gettable word (rare under Stage1).
			attempt [set/any 'root get/any fpath/1]
			unless object? get/any 'root [return none]
			value: get/any 'root
			pos: next fpath
			while [not tail? pos][
				unless object? :value [return none]
				name: pos/1
				unless all [word? name in value name][return none]
				value: get in value name
				pos: next pos
			]
			either object? :value [:value][none]
		]
	]

	search-obj: func [path [path!] /local search base fpath found?][
		search: [
			fpath: head insert copy path base
			until [									;-- evaluate nested paths from longer to shorter
				remove back tail fpath
				any [
					tail? next fpath
					object? found?: safe-eval-object-path fpath
				]
			]
		]

		base: get-obj-base-word path/1
		do search									;-- check if path is an absolute object path
		if all [not found? 1 < length? obj-stack][
			base: obj-stack
			do search								;-- check if path is a relative object path			
			unless all [
				found?
				find fpath path/1					;-- check if the start of path is in the found path (avoids false positive)
			][
				return none							;-- not an object access path
			]
		]
		reduce [found? fpath base]
	]
	
	object-access?: func [path [series!] /local res self? wrapper][
		self?: path/1 = 'self
		either self? [
			; Prefer word binding; if it is not a registered shadow object (common
			; for method bodies after bind to the function context), use the
			; container object saved for deferred method compilation.
			res: binding-of path/1
			either all [object? :res find-obj res][
				res
			][
				any [
					all [object? :container-obj? container-obj?]
					all [path? :obj-stack safe-eval-object-path obj-stack]
				]
			]
		][
			wrapper: either path? :obj-stack [safe-eval-object-path obj-stack][none]
			all [
				1 < length? obj-stack
				object? wrapper
				in wrapper path/1
				insert path next obj-stack			;-- insert prefix into object path
			]
			search-obj to path! path
		]
	]
	
	is-object?: func [expr /local pos name entry found][
		; Prefer last registry match for a given access word. First-match returned
		; stale global shadows when the same word (e.g. `new`) was reused in later
		; scopes, breaking make-chain method inheritance (wrong TO_CTX / missing get-a).
		unless find [word! get-word! path! object!] type?/word expr [return none]
		if object? :expr [return expr]
		name: case [
			any [word? expr get-word? expr] [to word! expr]
			all [path? expr word? last expr] [last expr]
			true [none]
		]
		unless name [return none]
		found: none
		entry: objects
		while [not tail? entry][
			if all [entry/1 = name object? entry/2][found: entry/2]
			entry: skip entry 6
		]
		found
	]

	obj-func-call?: func [name [any-word!] /local obj][
		if any [rebol-gctx = obj: binding-of name bindings/shadow-context-of obj][return no]
		select-obj obj
	]
	
	obj-func-path?: func [
		path [path!]
		/local fpath base symbol found? fun origin name obj info ctx self? val method pos cand
	][
		self?: do [path/1 = 'self]
		either self? [
			found?: binding-of path/1
			unless all [object? :found? find-obj found?][
				found?: any [
					all [object? :container-obj? container-obj?]
					all [path? :obj-stack safe-eval-object-path obj-stack]
				]
			]
			unless all [object? :found? find-obj found?][return none]
			path: copy path
			path/1: pick find-obj found? -1
			fun: head insert copy path 'objects 
			fpath: head clear next copy path
		][
			set [found? fpath base] search-obj to path! path
			unless found? [
				if all [
					not empty? ctx-stack
					info: find-binding path/1
					ctx: find/skip skip objects 2 info/1 6
				][
					path: head insert copy path to word! form ctx/-2
					set [found? fpath base] search-obj to path! path
				]
				unless found? [return none]
			]

			fun: append copy fpath either base = obj-stack [ ;-- extract function access path without refinements
				pick path 1 + (length? fpath) - (length? obj-stack)
			][
				pick path length? fpath
			]
			; Multi-inherit copies real functions; static collection uses function! marker.
			val: attempt [either all [object? :found? word? last fun][get in found? last fun][do fun]]
			unless any [
				all [datatype? :val val = function!]
				function? :val
			][return none] ;-- not a function call
			remove fpath								;-- remove 'objects prefix
		]

		obj:	find-obj found?
		origin: find-proto obj last fun
		method: last fun
		name:	either origin [select-obj origin][all [obj obj/2]]
		; Methods register as ctx~method (prefix-func). Also accept access-word
		; decoration used by older fallback registration.
		symbol: none
		foreach cand reduce [
			all [name decorate-obj-member method name]
			all [obj obj/2 decorate-obj-member method obj/2]
			all [object? :found? select-obj found? decorate-obj-member method select-obj found?]
			all [object? :origin select-obj origin decorate-obj-member method select-obj origin]
			all [obj word? obj/-1 decorate-obj-member method obj/-1]
			all [object? :origin pos: find-obj origin word? pos/-1 decorate-obj-member method pos/-1]
			all [object? :found? pos: find-obj found? word? pos/-1 decorate-obj-member method pos/-1]
			all [path? :fun decorate-obj-member method head clear back tail copy fun]
			all [path? :fpath decorate-obj-member method fpath]
		][
			if all [word? :cand find functions cand][symbol: cand break]
		]
		
		either symbol [
			fpath: next find path last fpath			;-- point to function name
			reduce [
				either 1 = length? fpath [fpath/1][copy fpath]
				symbol
				either all [obj obj/2][obj/2][name]		;-- object instance ctx name
			]
		][
			none
		]
	]

	system-words-path?: func [path [path! set-path!] /local get?][
		if all [
			2 < length? path
			any [
				find/match path 'system/words
				all [get?: get-word? path/1 path/1 = 'system path/2 = 'words]
			]
		][
			remove/part path 2
			if paren? path/1 [path/1: do path/1]
			if get? [path/1: to get-word! path/1]
			either 1 = length? path [
				switch type?/word pc/1: any [attempt [load mold path] path/1][
					set-word!	[comp-set-word]
					word!		[comp-word]
					get-word!	[comp-word/literal]
				]
				path: none
			][
				path/1: bind path/1 'rebol				;-- force binding to global context
			]
		]
		path
	]
	
	push-locals: func [locals-list [block! none!]][
		append/only locals-stack any [locals-list make block! 0]
	]

	pop-locals: does [
		also
			last locals-stack
			remove back tail locals-stack
	]
	
	literal-first-arg?: func [spec [block!]][
		parse spec [
			any [
				word! 		(return no)
				| lit-word! (return yes)
				| get-word! (return yes)
				| /local	(return no)
				| skip
			]
		]
		no
	]
	
	infix?: func [pos [block! paren!] /local specs left][
		all [
			not tail? pos
			word? pos/1
			specs: select functions pos/1
			'op! = specs/1
			not all [									;-- check if a literal argument is not expected
				word? left: pos/-1
				not local-word? left
				specs: select functions left
				literal-first-arg? specs/3				;-- literal arg needed, disable infix mode
			]
		]
	]
	
	convert-types: func [spec [block!] /local value][
		forall spec [
			if spec/1 = /local [break]					;-- avoid processing local variable
			if all [
				block? value: spec/1
				not find [integer! logic! float!] value/1 
			][
				value/1: decorate-type either value/1 = 'any-type! ['value!][value/1]
			]
		]
	]
	
	rewrite-locals: func [code [block!] /local rule s pos word ctx p? nested][
		parse code rule: [
			some [
				[
					'stack/push (p?: yes)
					| 'set-path* (p?: no)
					| 'eval-path (p?: no)
				] pos: (
					if #"~" = first word: form pos/1 [
						if ctx: find-contexts word: to word! next word [
							pos: either p? [back pos][pos]
							change/part pos reduce [
								'word/get-local ctx get-word-index word
							] pick [2 1] p?
							new-line pos yes
							pos: next pos				;-- skip the value
						]
					]
				) :pos
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
	]
	
	find-function: func [name [word!] original [any-word!] /local entry bound?][
		all [
			entry: find functions name
			any [
				all [not bound?: local-bound? original head? functions]	;-- global case
				all [bound? not head? functions]		;-- local case
			]
			entry
		]
	]

	decode-attributes: func [spec [block!] /local do-error flags][
		do-error: [throw-error ["invalid function spec block:" mold pos]]
		flags: 0
		foreach attrib spec/1 [
			unless word? attrib [do do-error]
			flags: switch/default attrib [				;-- keep those flags synced with %runtime/definitions.reds
				trace	 [flags or to-integer #{00000400}]
				no-trace [flags or to-integer #{00000200}]
			][0]
		]
		flags
	]
	
	check-invalid-exit: func [name [word!]][
		if empty? locals-stack [
			pc: back pc
			throw-error [uppercase form name "used outside of a function"]
		]
	]
	
	check-redefined: func [name [word!] original [any-word!] /only /local pos entry obj][
		if all [
			not only
			pos: find-function name original
			not all [									;-- if name is not bound to an object
					rebol-gctx <> obj: binding-of original
				not bindings/shadow-context-of obj
			]
		][
			remove/part pos 2							;-- remove previous function definition
		]
		if all [
			pos: find get-obj-base name name
			not all [
				entry: local-bound? original			;-- retrieve shadow function
				block? select entry/3 name				;-- if type(s) specified, keep object definition
			]
		][
			pos/1: none
		]
		true
	]
	
	check-func-name: func [name [word!] /local new pos][
		if find functions name [
			new: to word! append append mold/flat name "||" get-counter
			either pos: find-ssa name [
				pos/2: new
			][
				repend ssa-names [name new]
			]
			name: new
		]
		name
	]
	
	check-cloned-function: func [new [word!] original /local name alter entry pos alias old type path][
		if any [
			all [
				get-word? pc/1
				name: to word! pc/1	
				all [
					alter: get-prefix-func name
					entry: find functions alter
					name: alter
				]
			]
			all [
				path? path: pc/1
				2 < length? path
				all [get?: get-word? path/1 path/1 = 'system path/2 = 'words]
				entry: find functions name: last path
			]
		][
			all [
				ctx: obj-func-call? original
				new: decorate-obj-member new ctx
			]
			if alter: select-ssa name [
				entry: find functions alter
			]
			repend functions [new entry/2]

			unless local-bound? pc/-1 [
				switch/default type: entry/2/1 [
					routine! [
						alias: new
						old: decorate-exec-ctx name
					]
					native! [
						alias: decorate-func new
						old: load rejoin ["red/" natives-prefix slash name #"*"]
					]
					action! [
						alias: decorate-func new
						old: load rejoin ["red/" actions-prefix slash name #"*"]
					]
				][
					alias: decorate-func new
					old: decorate-exec-ctx decorate-func name
				]
				;libRedRT/collect-aliased alias old
			]
			
			either pos: find-ssa new [					;-- add the real function name as alias
				pos/2: name
			][
				repend ssa-names [new name]
			]
		]
	]
	
	check-new-func-name: func [symbol [word!] ctx [word!] /local name][
		if any [
			set-word? name: pc/-1
			all [lit-word? name 'set = pc/-2]
		][
			name: to word! name
			repend functions [name append select functions symbol ctx]
			
			either pos: find-ssa name [					;-- add the real function name as alias
				pos/2: symbol
			][
				repend ssa-names [name symbol]
			]
		]
	]
	
	; Note: do not name a function local `locals` — the frontend object already
	; has a `locals` field (active locals stack). Compiled methods can bind that
	; field instead of a true local, which corrupts compiler state and can make
	; check-spec return a non-block for empty `does` specs.
	check-spec: func [spec [block!] /local spec-symbols word pos stop nb-locals return? loc? flags s][
		spec-symbols: make block! length? spec
		nb-locals: 0
		flags:	 0
		loc?:	 no
		return?: no
		stop: []
		
		unless parse spec [
			opt string!
			opt [pos: block! (flags: decode-attributes pos) opt string!]
			any [
				; Red PARSE equates /local refinement with word! local. Match refinement!
				; and require the value to be /local before entering the locals section.
				pos: refinement! if (pos/1 = /local) (
					if loc? [stop: [end skip]]
					append spec-symbols 'local
					loc?: yes
				) stop [
					any [
						pos: word! (
							unless find spec-symbols word: to word! pos/1 [
								append spec-symbols word
								nb-locals: nb-locals + 1
							]
						)
						pos: opt block! pos: opt string!
					]
				]
				| set-word! (
					if any [loc? return? pos/1 <> return-def][stop: [end skip]]
					return?: yes						;-- allow only one return: statement
				) stop pos: block! opt string!
				| [
					[word! | lit-word! | get-word!] opt block! opt string!
					| refinement! opt string! (if any [loc? return?][stop: [end skip]]) stop
				] (append spec-symbols to word! pos/1)
			]
		][
			throw-error ["invalid function spec block:" mold pos]
		]

		s: copy spec
		forall s [if any-word? s/1 [s/1: to word! s/1]]
		
		forall s [
			if all [
				word? s/1
				find next s s/1
			][
				pc: skip pc -2
				throw-error ["duplicate word definition:" s/1]
			]
		]
		reduce [spec-symbols nb-locals flags]
	]
	
	make-attributs: func [spec [block!] /prolog locals /epilog /local flags trace? no-trace? out][
		unless all [
			any [
				block? flags: spec/1
				block? flags: spec/2
			]
			any [
				trace?:    find flags 'trace
				no-trace?: find flags 'no-trace
			]
		][return ()]
		
		out: copy []
		either prolog [
			insert next find/tail locals 'saved [prev [logic!]]
			append out [
				prev: interpreter/tracing?
			]
			if trace? 	 [append out [interpreter/tracing?: interpreter/trace?]]
			if no-trace? [append out [interpreter/tracing?: no]]
		][
			append out [interpreter/tracing?: prev]
		]
		new-line back back tail out yes
		out
	]
	
	make-refs-table: func [spec [block!] /local mark pos arity arg-rule list ref args][
		arity: 0
		arg-rule: [word! | lit-word! | get-word!]
		parse spec [
			any [
				arg-rule (arity: arity + 1)
				| mark: refinement! (pos: mark) break
				| skip
			]
		]
		if all [pos pos/1 <> /local][
			list: make block! 8
			ref: 0
			parse pos [
				some [
					pos: refinement! opt string! (
						ref: ref + 1
						if pos/1 = /local [return reduce [list arity]]
						repend list [pos/1 ref 0]
						args: 0
					)
					| arg-rule opt block! opt string! (
						change back tail list args: args + 1	;@@ one argument by refinement max!!
					)
					| set-word! break
				]
			]
		]
		reduce [list arity]
	]
	
	get-prefix-func: func [name [word!] /local path word ctx value][
		unless path? :obj-stack [obj-stack: to path! 'objects]
		if 1 < length? obj-stack [
			path: red-compiler-safe-copy obj-stack
			while [1 < length? path][
				if all [
					o: safe-eval-object-path path word: either object? o [in o name][none]
					value: get word
					any [same? :value function! function? :value]
				][
					return prefix-func/with name path
				]
				remove back tail path
			]
		]
		if all [										;-- check for method case during function compilation stage
			container-obj?
			ctx: obj-func-call? name
		][
			return decorate-obj-member name ctx
		]
		name
	]
	
	add-function: func [name [word!] spec [block!] /type kind [word!] /local refs arity pos][
		set [refs arity] make-refs-table spec
		repend functions [name reduce [any [kind 'function!] arity spec refs]]
	]
	
	fetch-functions: func [
		pos [block!]
		/local name type spec refs arity nat? proto entry saved defer invalid-spec
	][
		if any [tail? pos not any-word? pos/1][
			pc: back pc
			throw-error "Non-compilable function definition"
		]
		invalid-spec: [throw-error ["invalid argument function to make op!:" mold copy/part at pos 4 2]]
		
		name: to word! pos/1
		if find functions name [return none]			;-- mainly intended for 'make (hardcoded)

		switch type: pos/3 [
			native! [nat?: yes if find intrinsics name [type: 'intrinsic!]]
			action! [append actions name]
			op!     [
				if find [has does] pos/4 [do invalid-spec]
				either find [func function] pos/4 [		;-- anon function case
					unless block? spec: pos/5 [do invalid-spec]
					defer: name
				][
					repend op-actions [name proto: get-prefix-func to word! pos/4]
				]
			]
		]
		unless spec [
			spec: either pos/3 = 'op! [
				either entry: find functions proto [
					if 1 < length? obj-stack [
						append entry/2 select-obj either path? :obj-stack [safe-eval-object-path obj-stack][none]	;-- append context name if method
					]
					entry/2/3
				][
					throw-error ["Cannot MAKE OP! from unknown function:" mold pos/4]
				]
			][
				clean-lf-deep pos/4/1
			]
		]
		if nat? [prepare-typesets name spec]
		set [refs arity] make-refs-table spec
		repend functions [name reduce [type arity spec refs]]
		defer
	]
	
	emit-path: func [
		path [path! set-path!] set? [logic!] alt? [logic!]
		/local idx pos words item blk get? mark
	][
		either set? [
			emit-open-frame 'eval-set-path
			either alt? [								;-- object path (fallback case)
				emit [									;-- get arguments just below the stack record
					if stack/arguments > stack/bottom [stack/push stack/arguments - 1]
				]
				insert-lf -5
			][
				comp-expression							;-- fetch assigned value (normal case)
			]
		][
			emit-open-frame 'eval-path
		]
		if all [1 <> length? obj-stack path/1 = last obj-stack][remove path]		;-- remove temp object prefix inserted by object-access? (mind #4567!)
		
		idx: either empty? ctx-stack [
			red-compiler-emit-block path
		][
			red-compiler-emit-block/with path last ctx-stack
		]
		emit 'eval-path*
		
		words: reduce [to word! form set? 'get-root idx]
		blk: make block! 20								;-- requires by get-path-word, returned as result
		forall path [
			append words either integer? item: path/1 [
				reduce ['integer/push item]
			][
				get?: to logic! any [head? path get-word? item]
				get-path-word item clear blk get? head? path
			]
		]
		new-line/all words no
		emit reduce [words]
		insert-lf -2
		emit-close-frame
	]
	
	get-return-type: func [spec [block!] /local type position][	;-- for routine spec blocks
		position: head spec
		while [all [not tail? position not set-word? :position/1]][position: next position]
		all [
			not tail? position
			position/1 = return-def
			type: pick position 2
			find [integer! logic! float!] type/1
			type
		]
	]
	
	emit-routine: func [name [word!] spec [block!] /local type cnt offset alter idx pos][
		idx: 0
		if block? spec/1 [spec: next spec]
		forall spec [
			if any [spec/1 = /local set-word? spec/1][break] ;-- avoid processing local variable
			if block? spec/1 [
				type: spec/1/1
				if type <> 'red-value! [					 ;-- any-type! => red-value! => no check
					if pos: find/match form type "red-" [type: to word! pos]
					type: reduce [type]
					emit make-typeset type none back spec yes ;-- inject type-checking calls for arguments
					emit idx
					either idx > 0 [
						emit reduce ['stack/arguments '+ idx]
						insert-lf -9
					][
						emit 'stack/arguments
						insert-lf -7
					]
				]
				idx: idx + 1
			]
		]
		spec: head spec
		
		declare-variable/init 'r_arg to paren! [as red-value! 0]
		emit [r_arg: stack/arguments]
		insert-lf -2

		offset: 0
		if type: get-return-type spec [
			offset: 1
			append/only output append to path! form get type/1 'box
		]
		if alter: select-ssa name [name: alter]
		emit name
		cnt: 0

		forall spec [
			if string? spec/1 [
				if tail? remove spec [break]
			]
			if any [spec/1 = /local set-word? spec/1][
				spec: head spec
				break									;-- avoid processing local variable	
			]
			unless block? spec/1 [
				unless block? spec/2 [
					insert/only next spec [red-value!]
				]
				either find [integer! logic! float!] spec/2/1 [
					type: either spec/2/1 = 'float! ['float][get spec/2/1]
					append/only output append to path! form type 'get
				][
					emit reduce ['as spec/2/1]
				]
				emit 'r_arg
				unless head? spec [emit reduce ['+ cnt]]
				cnt: cnt + 1
			]
		]
		insert-lf negate cnt * 2 + offset + 1
	]
	
	redirect-to: func [out [block!] body [block!] /local saved][
		saved: output
		output: out
		also
			do body
			output: saved
	]
	
	encode-UTC-time: func [time [time! none!] zone [time! none!]][
		to float! either time [either zone [time - zone][time]][0.0]
	]
	
	encode-date: func [value [date!] /with zone /local date][
		zone: any [zone value/zone 0:00]
		date:  (shift/left value/year 17)
			or (shift/left value/month 12)
			or (shift/left value/day 7)
			or (shift/left absolute zone/hour 2)
			or (to integer! ((absolute to integer! zone/minute) / 15))
		if negative? zone [date: date or 64]			;-- zone negative bit
		if value/time [date: date or 65536]				;-- time? flag
		date
	]

	emit-float: func [value [float!] /local bin][
		bin: to-binary value
		emit to integer! copy/part bin 4
		emit to integer! skip bin 4
	]
	
	comp-literal: func [
		/inactive /with val
		/local value name w make-block type idx zone bin size money-data value-type v
	][
		make-block: [
			value: to block! value
			either empty? ctx-stack [
				red-compiler-emit-block value
			][
				red-compiler-emit-block/with value last ctx-stack
			]
		]
		value: either with [val][pc/1]					;-- val can be NONE
		value-type: type?/word :value
		
		either any [
			char? :value
			percent? :value
			tuple? :value
			money? :value
			ref? :value
			datatype? :value
			scalar? :value
			map? :value
			find [point2D! point3D!] value-type
		][
			case [
				char? :value [
					emit 'char/push
					emit to integer! value
					insert-lf -2
				]
				percent? :value [
					emit 'percent/push64
					emit-float to float! value
					insert-lf -3
				]
				map? :value [
					;-- Real map! (Stage1). Encode as redbin TYPE_MAP via #!map! marker,
					;-- same runtime shape as Stage0: map/push as red-hash! get-root N.
					value: head insert copy to block! value #!map!
					emit compose [map/push as red-hash! get-root (red-compiler-emit-block value)]
					insert-lf -3
				]
				float? :value [
					emit 'float/push64
					emit-float value
					insert-lf -3
				]
				tuple? :value [
					bin: to binary! value
					size: length? bin
					append/dup bin 0 12 - size
					emit 'tuple/push
					emit size
					emit to integer! reverse copy/part bin 4
					emit to integer! reverse copy/part skip bin 4 4
					emit to integer! reverse copy/part skip bin 8 4
					insert-lf -5
				]
				money? :value [
					emit 'money/push
					money-data: to-nibbles value
					; R/S accepts word! true/false, not logic! values.
					emit pick [true false] money-data/1
					emit money-data/2
					emit money-data/3
					insert-lf -4
				]
				ref? :value [
					idx: red-compiler-emit-string-root value
					emit 'ref/push
					emit compose [as red-string! get-root (idx)]
					insert-lf -5
				]
				datatype? :value [
					emit 'datatype/push
					emit get-RS-type-ID value
					insert-lf -2
				]
				find [refinement! issue!] type?/word :value [
					; Match Rebol/encapper: form issue! drops leading '#'; symbol spelling
					; matches redbin emit-issue (form) so switch select-key* works.
					; Stage1/Red: to word! form fails for pure-digit issue spellings
					; ("12345678" loads as integer! -> invalid-chars). Use issue/load.
					either issue? :value [
						emit 'issue/load
						emit form value
						insert-lf -2
					][
						w: to word! form value
						add-symbol w
						type: to word! form type? :value
						either local-word? w [
							emit append to path! type 'push-local
							emit last ctx-stack
							emit get-word-index w
							insert-lf -3
						][
							emit to path! reduce [type 'push]
							emit to path! reduce ['exec decorate-symbol w]	;@@ replace by prefix-exec
							insert-lf -2
						]
					]
				]
				none? :value [
					emit 'none/push
					insert-lf -1
				]
				any-word? :value [
					add-symbol name: to word! :value
					either all [lit-word? :value not inactive][
						emit-push-word :name :value
					][
						emit-push-word :value :value
					]
				]
				pair? :value [
					emit 'pair/push
					emit reduce [value/1 value/2]
					insert-lf -3
				]
				time? :value [
					emit 'time/push
					emit to float! value
					insert-lf -2
				]
				date? :value [
					emit 'date/push
					emit reduce [encode-date value encode-UTC-time value/time value/zone]
					insert-lf -4
				]
				find [point2D! point3D!] value-type [
					value: either value-type = 'point2D! [
						reduce [value/x value/y]
					][reduce [value/x value/y value/z]]
					type: pick [point2D point3D] 2 = length? value
					emit append to-path type 'push
					foreach v value [emit reduce ['as-float32 either integer? v [to-float v][v]]]
					insert-lf -5
				]
				'else [
					emit to path! reduce [to word! form type? :value 'push]
					emit load mold :value
					insert-lf -2
				]
			]
		][
			switch/default type?/word value [
				block!	[
					emit compose [block/push get-root (do make-block)]
					insert-lf -3
				]
				paren!	[
					emit compose [paren/push get-root (do make-block)]
					insert-lf -3
				]
				path! set-path! lit-path! get-path!	[
					case [
						inactive [
							either get-path? :value [
								emit 'get-path/push
								emit [as red-path!]
							][
								emit to path! reduce [to word! form type? :value 'push]
								emit [as red-path!]
							]
						]
						lit-path? :value [
							emit 'path/push
							emit [as red-path!]
						]
						true [
							emit to path! reduce [to word! form type? :value 'push]
							emit [as red-path!]
						]
					]
					idx: do make-block
					emit reduce ['get-root idx]
					insert-lf -3
				]
				string!	file! url! tag! email! [
					idx: red-compiler-emit-string-root value
					emit to path! reduce [to word! form type? value 'push]
					emit compose [as red-string! get-root (idx)]
					insert-lf -5
				]
				binary!	[
					idx: red-compiler-emit-string-root value
					emit 'binary/push
					emit compose [as red-binary! get-root (idx)]
					insert-lf -5
				]
			][
				throw-error ["comp-literal: unsupported type" mold value]
			]
		]
		unless with [pc: next pc]
		name
	]

	rebind-body: func [
		symbol [word!] entry [block!] ctx [object!]
		/local rule pos self* nested
	][
		self*: in ctx 'self

		;-- rebind the new body to the parent object's context
		entry: bind/copy copy/part next entry 8 ctx
		
		if object? shadow: select shadow-funcs decorate-func/strict symbol [
			;-- rebind the body to the function's context
			bind entry/2 shadow
			;-- rebind 'self words in body block to new object
			parse entry/2 rule: [
				any [
					pos: 'self (pos/1: self*)
					| nested: [block! | paren!] :nested into rule
					| skip
				]
			]
		]
		entry
	]
	
	inherit-functions: func [							 ;-- multiple inheritance case
		new [object!] extend [object!]
		/local symbol name entry value pos path-ext path-new
	][
		;-- Stage0 algorithm with Stage1 object identity (select/same -> ctx).
		;-- objects layout: [symbol obj ctx id proto events] (skip 6).
		;-- select/same objects obj returns ctx (value after obj). Fallback must
		;-- use pos/2 (ctx), not pos/-1 (access symbol) — wrong decoration path
		;-- made find bodies pick an unrelated method and emit bad TO_CTX.
		foreach word words-of extend [
			value: get in extend word
			if any [same? :value function! value = function! function? :value][
				path-ext: select-obj extend
				unless path-ext [
					if pos: find-obj extend [path-ext: pos/2]
				]
				path-new: select-obj new
				unless path-new [
					if pos: find-obj new [path-new: pos/2]
				]
				if all [path-ext path-new][
					symbol: decorate-obj-member word path-ext
					if find functions symbol [
						name: decorate-obj-member word path-new
						repend functions [name select functions symbol]
						unless find bodies name [
							either entry: find bodies symbol [
								append bodies name
								append bodies do [rebind-body symbol entry new]
							][
								redirect-to literals [
									emit compose [#define (decorate-func name) (decorate-func symbol)]
								]
							]
							add-symbol name
						]
					]
				]
			]
		]
	]

	comp-context: func [
		/with word
		/extend proto [object!]
		/passive only? [logic!]
		/locals
			words ctx spec name id func? obj original body pos entry symbol
			body? ctx2 new blk list path on-set-info values w defer mark blk-idx
			event pos2 loc-s loc-d shadow-path path-values saved-pc saved set? evt-var type words-pos
			shadow-words shadow-spec callback on-change-callback on-deep-change-callback
	][
		saved-pc: pc
		either set-path? original: pc/-1 [
			path: original
		][
			name: to word! original: any [word original]
			check-redefined/only name original
		]
		words: make block! 8
		if proto [									;-- start from existing context
			foreach w words-of proto [
				append words w
				append/only words get in proto w
			]
		]
		list:  clear any [list []]
		values: make block! 8
		
		if proto [proto: reduce [proto]]
		
		either body?: block? pc/2 [
			parse body: pc/2 [							;-- collect words from body block
				some [
					(clear list)
					pos: set-word! (
						append list pos/1				;-- store new word
						value: pos
						until [
							value: next value
							any [tail? value not set-word? value/1]
						]
						value: value/1
						if all [not only? word? value][
							if find logic-words value [value: get value]
						]
						w: to word! pos/1
						either entry: find/skip values w 2 [ ;-- store first following value (CONSTRUCT)
							entry/2: value
						][
							repend values [w value]
						]
						func?: no
					)
					[func-constructors (func?: yes) | none] (
						foreach word list [
							either entry: find words word [
								if func? [entry/2: function!]
							][
								append words word
								append words either func? [function!][none]
							]
						]
					)
					| include-directive (comp-include/only pos) :pos
					| skip
				]
			]

			spec: make block! (length? words) / 2
			foreach [word type] words [append spec to word! word]
		][
			unless extend [
				pos: tail output						;-- defer it to runtime evaluation	
				pc: next pc
				either pc/-1 = 'object! [
					emit-open-frame 'make
					emit-get-word pc/-1 pc/-1
					comp-expression
					emit-action 'make
				][
					emit-open-frame 'context
					comp-expression
					emit-function 'context
				]
				emit-close-frame
				defer: copy pos
				clear pos
				return defer
			]
			obj:    find-obj proto/1				;-- simple inheritance case
			spec:   words-of obj/1
			words:  make block! (2 * length? spec)
			foreach w spec [
				append words w
				append/only words get in obj/1 w
			]
			
			unless find [context object object!] pc/1 [
				if all [not new: is-object? pc/2 not passive][
					comp-call 'make select functions 'make ;-- fallback to runtime creation
					return none
				]
				
				if all [passive not new][new: proto/1]
				ctx2: select-obj new		;-- multiple inheritance case
				spec: union spec words-of new
				insert proto new
				
				words-pos: words
				while [not tail? words-pos][
					if word: in new words-pos/1 [words-pos/2: get word]
					words-pos: skip words-pos 2
				]
				; NOTE: must not use `name` here — it holds the object access word
				; (e.g. new). Clobbering it registers multi-inherit under the last
				; field name (e.g. foo) and breaks later path/method lookup.
				foreach field words-of new [
					unless find words field [repend words [field get in new field]]
				]
			]
		]

		ctx: add-context spec
		blk-idx: red-compiler-emit-context/root ctx spec no yes 'object
		
		redirect-to literals [							;-- store spec and body blocks
			emit compose [
				(to set-word! ctx) get-root-node (blk-idx)	;-- assign context
			]
			insert-lf -3
		]
		
		symbol: either path [ctx][
			; Unbind previous access-word on both registries so is-object? name
			; lookup (and Stage0-style reuse of the word) hits the new shadow.
			if pos: find get-obj-base name name [pos/1: none] ;-- unbind word with previous object
			; Under compiled Red, context? of a freshly loaded set-word may not
			; compare equal with the boot-time rebol-gctx snapshot even when both
			; refer to the global context. Prefer the source name for globals and
			; function-local shadow bindings so nested objects/system/build paths work.
			obj: binding-of original
			either any [
				none? obj
				same? rebol-gctx obj
				rebol-gctx = obj
				bindings/shadow-context-of obj
				not local-word? name
			][name][ctx]
		]
		
		shadow-words: copy words
		on-change-callback: func [word old new][]
		on-deep-change-callback: func [owner word target action new index part][]
		if callback: find/skip shadow-words 'on-change* 2 [
			callback/2: to get-word! 'on-change-callback
		]
		if callback: find/skip shadow-words 'on-deep-change* 2 [
			callback/2: to get-word! 'on-deep-change-callback
		]
		; Red's make object! expects set-word/value pairs. Source collection may
		; already use set-words, but normalize so word/value pairs also work.
		shadow-spec: make block! length? shadow-words
		foreach [word value] shadow-words [
			append shadow-spec to set-word! word
			append/only shadow-spec :value
		]
		repend objects [								;-- register shadow object	
			symbol										;-- object access word
			obj: make object! shadow-spec				;-- shadow object
			ctx											;-- object's context name
			id: get-counter								;-- unique object ID
			proto										;-- optional prototype object
			none										;-- [idx loc idx2 loc2...] (for events)
		]

		on-set-info: back tail objects

		shadow-path: either all [
			with
			find [lit-word! lit-path!] type?/word saved-pc/-2
			saved-pc/-3 = 'set
		][
			set?: yes
			either lit-word? saved: saved-pc/-2 [		;-- from root level
				to path! reduce ['objects to word! saved]
			][
				head insert saved 'objects
			]
		][
			join-obj-stack either path [to path! path][name] ;-- account for current object stack
		]
		path-values: to block! shadow-path
		new-line/all path-values no
		shadow-path: to path! path-values
		
		either path [
			unless attempt [
				do reduce [to set-path! shadow-path obj] ;-- set object in shadow tree
			][
				path: symbol							;-- undefined object path, so use ctx name
			]
		][
			unless tail? next obj-stack [				;-- set object in shadow tree (if sub-object)
				unless attempt [
					do reduce [to set-path! shadow-path obj]
				][
					; Parent shadow path may still be incomplete; keep compiling.
					none
				]
			]
		]
		if body? [bind body obj]
		if passive [return []]

		unless all [empty? locals-stack not iterator-pending?][	;-- in a function or iteration block
			emit compose [
				(to set-word! ctx) _context/clone-words get-root (blk-idx) CONTEXT_OBJECT ;-- rebuild context
			]
			insert-lf -3
		]
		
		if proto [
			if body? [inherit-functions obj last proto]
			emit reduce ['object/clone-series select-obj (last proto) ctx 'true]
			insert-lf -4
		]
		if all [not body? not passive][
			; Stage0: inherit only from the second prototype object (`new`).
			inherit-functions obj new
			emit reduce ['object/transfer ctx2 ctx]
			insert-lf -3
		]

		emit-src-comment/with none rejoin [mold pc/-1 " context " mold spec]

		emit-open-frame 'body
		case [
			passive [									;-- CONSTRUCT support
				bind values obj
				foreach [name value] values [
					emit-open-frame 'set
					emit-push-word name name
					comp-literal/with value
					
					emit-native/with 'set [-1 -1 -1 -1]
					emit-close-frame
				]
				pc: skip pc 2
			]
			all [body? not empty? pc/2][
				unless path? :obj-stack [obj-stack: to path! 'objects]
				saved: red-compiler-safe-copy obj-stack		;-- preserve current object stack
				either set? [
					obj-stack: append to path! 'objects any [path name] ;-- from root
				][
					append obj-stack any [path name]	;-- from current objects stack
					path-values: to block! obj-stack
					new-line/all path-values off
					obj-stack: to path! path-values
				]
				pc: next pc
				;-- Sticky object ctx for redbin emit-block/with (issue #2920: d: [e]).
				;-- Not on ctx-stack (would break find-contexts / emit-deep-check).
				compiler-redbin-emitter/object-with-ctx: ctx
				comp-next-block yes
				compiler-redbin-emitter/object-with-ctx: none
				obj-stack: saved						;-- restore objects stack
			]
			'else [
				pc: skip pc 2
			]
		]
		pos: none
		
		defer: reduce ['object/init-push ctx id] ;-- deferred emission
		new-line defer yes
		
		;-- events definitions processing
		loc-s: loc-d: 0
		event: 'on-change*
		if pos: find spec event [
			pos: (index? pos) - 1					;-- 0-based contexts arrays
			unless entry: any [
				find functions decorate-obj-member event ctx
				all [proto find functions decorate-obj-member event select-obj proto/1]
			][
				pc: back pc
				throw-error ["invalid" event "event definition in object" name]
			]
			unless zero? loc-s: second check-spec entry/2/3 [
				loc-s: loc-s + 1					;-- account for /local
			]
		]
		event: 'on-deep-change*
		if pos2: find spec event [
			pos2: (index? pos2) - 1					;-- 0-based contexts arrays
			unless entry: any [
				find functions decorate-obj-member event ctx
				all [proto find functions decorate-obj-member event select-obj proto/1]
			][
				pc: back pc
				throw-error ["invalid" event "event definition in object" name]
			]
			unless zero? loc-d: second check-spec entry/2/3 [
				loc-d: loc-d + 1					;-- account for /local
			]
		]
		if any [pos pos2][
			unless pos  [pos:  -1]
			unless pos2 [pos2: -1]
			evt-var: to-word join 'evt form id
				redirect-to literals [
					emit compose [
						(to set-word! evt-var) 0
				]
				insert-lf -4
			]
			change/only on-set-info reduce [pos loc-s pos2 loc-d evt-var]	;-- cache values
			repend defer [to-set-word evt-var 'object/init-events ctx pos loc-s pos2 loc-d]
			new-line skip defer 3 yes
		]
		
		emit 'stack/revert
		insert-lf -1
		
		defer
	]
	
	comp-object: :comp-context
	
	comp-construct: has [only? with? body? obj defer mark][
		only?: with?: no
		
		if all [
			path? pc/1
			not parse pc/1 [skip 2 [opt ['only (only?: yes) | 'with (with?: yes)]]] ;@@ handle duplicates
		][
			throw-error "Invalid CONSTRUCT refinement"
		]
		body?: block? pc/2
		if all [
			find [set-word! set-path!] type?/word pc/-1
			any [all [body? not with?] all [with? obj: is-object? pc/3]]
		][
			either with? [
				comp-context/passive/extend only? obj
			][
				comp-context/passive only?
			]
		]
		pc: next pc
		mark: tail output
		emit-open-frame 'construct
		comp-expression
		if with? [comp-expression]
		emit-native/with 'construct reduce [pick [1 -1] with? pick [0 -1] only?]
		emit-close-frame
		defer: copy mark
		clear mark
		defer											;-- return object deferred block
	]
	
	comp-try: has [path all? keep? mark body call handlers][
		all?: keep?: no
		if path? path: pc/-1 [
			;-- /same: Red FIND would match get-word! :all to word! all (Rebol does not).
			;-- try/:all is dynamic; only static try/all selects mark-try-all.
			all?:  to logic! find/same path 'all
			keep?: to logic! find/same path 'keep
		]
		call: pick [try-all try] all?
		
		emit-open-frame 'body
		either block? pc/1 [
			emit-open-frame call
			emit [
				assert system/thrown = 0
				catch RED_THROWN_ERROR
			]
			insert-lf -2
			push-call call
			body: comp-sub-block 'try
			pop-call call
			if body/1 = 'stack/reset [remove body]
			mark: tail output
			insert body mark
			clear mark
			append body [
				stack/unwind
			]
			unless all? [
				emit [switch system/thrown]
				handlers: build-exception-handler
				insert handlers/1 compose/deep [
					RED_THROWN_ERROR  [
						natives/handle-thrown-error (pick [true false] keep?)
					]
				]
				emit handlers
			]
			if all [keep? all?][
				emit [
					error/capture as red-object! stack/get-top
				]
			]
			emit either all? [
				[
					stack/adjust-post-try
				]
			][
				[
					if system/thrown <> RED_THROWN_ERROR [stack/adjust-post-try]
				]
			]
			emit [
				system/thrown: 0
			]
		][
			emit-open-frame call						;-- fallback option
			comp-expression
			unless all? [
				emit 'switch
				insert-lf -1
			]
			emit-native/with 'try reduce [pick [0 -1] all? pick [0 -1] keep?]
			new-line back tail output no
			unless all? [emit build-exception-handler]
			emit-close-frame
		]
		emit-close-frame
	]
	
	comp-boolean-expressions: func [type [word!] test [block!] /local list body][
		list: back tail comp-chunked-block
		
		if empty? head list [
			emit set-last-none
			insert-lf -1
			exit
		]
		bind test 'body
		
		;-- most nested test first (identical for ANY and ALL)
		body: compose/deep [if logic/false? [(set-last-none)]]
		new-line body yes
		insert body list/1
		
		;-- emit expressions tree from leaf to root
		while [not head? list][
			list: back list
			
			insert/only body 'stack/reset
			new-line body yes
			
			body: reduce test
			new-line body yes
			
			insert body list/1
		]
		emit-open-frame type
		emit body
		emit-close-frame
	]
	
	comp-any: does [
		either all [block? pc/1 not check-infix-operators no][
			comp-boolean-expressions 'any ['if 'logic/false? body]
		][
			emit-open-frame 'any
			comp-expression
			emit-native 'any
			emit-close-frame
		]
	]
	
	comp-all: does [
		either all [block? pc/1 not check-infix-operators no][
			comp-boolean-expressions 'all [
				'either 'logic/false? set-last-none body
			]
		][
			emit-open-frame 'all
			comp-expression
			emit-native 'all
			emit-close-frame
		]
	]
		
	comp-if: does [
		emit-open-frame 'if
		comp-expression/close-path
		emit compose/deep [
			either logic/false? [(set-last-none)]
		]
		comp-sub-block 'if-body							;-- compile TRUE block
		emit-close-frame
	]
	
	comp-unless: does [
		emit-open-frame 'unless
		comp-expression/close-path
		emit [
			either logic/false?
		]
		comp-sub-block 'unless-body						;-- compile FALSE block
		append/only output set-last-none
		emit-close-frame
	]

	comp-either: does [
		emit-open-frame 'either
		comp-expression/close-path
		emit [
			either logic/true?
		]
		comp-sub-block 'either-true						;-- compile TRUE block
		comp-sub-block 'either-false					;-- compile FALSE block
		emit-close-frame
	]
	
	comp-loop: has [name set-name mark][
		depth: depth + 1
		if depth > max-depth [max-depth: depth]

		set [name set-name] declare-variable join "i" depth
		
		emit-open-frame 'loop
		comp-expression/close-path						;@@ optimize case for literal counter
		emit-argument-type-check 0 'loop 'stack/arguments
		
		emit compose [
			natives/coerce-counter*
			(set-name) integer/get*
		]
		insert-lf -2
		emit compose/deep [
			either (name) <= 0 [(set-last-none)]
		]
		mark: tail output
		emit compose [
			loop (name)
		]
		new-line skip tail output -3 off
		
		push-call 'loop
		comp-sub-block 'loop-body						;-- compile body
		pop-call

		new-line skip tail last output -3 on
		new-line skip tail last output -7 on
		depth: depth - 1
		
		convert-to-block mark
		emit-close-frame
	]
	
	comp-until: does [
		emit-open-frame 'until
		emit [
			until
		]
		push-call 'until
		comp-sub-block 'until-body						;-- compile body
		pop-call
		append/only last output 'logic/true?
		new-line back tail last output on
		emit-close-frame
	]
	
	comp-while: does [
		emit-open-frame 'while
		emit [
			while
		]
		push-call 'while-cond
		comp-sub-block 'while-condition					;-- compile condition
		append/only last output 'logic/true?
		new-line back tail last output on
		pop-call
		push-call 'while
		comp-sub-block 'while-body						;-- compile body
		pop-call
		emit-close-frame
	]
	
	comp-repeat: has [name][
		unless any-word? name: pc/1 [
			pc: back pc
			throw-error "REPEAT expects a word as first argument"
		]
		add-symbol name
		add-global name
		pc: next pc
		
		emit-open-frame 'repeat
		comp-expression									;-- fetch the upper limit for the counter
		emit 'natives/coerce-counter*					;-- eventually convert float to integer
		insert-lf -1
		emit-argument-type-check 1 'repeat 'stack/arguments

		emit-open-frame 'set
		emit-push-word name name						;-- push the word
		emit [
			integer/push 0
			word/set									;-- initialize the counter word to 0
		]
		emit-close-frame

		emit [loop integer/get stack/arguments]
		insert-lf -3
		push-call 'repeat
		comp-sub-block 'repeat-body
		pop-call
		insert-head-last [								;-- inject code at loop's head to pre-increment counter
			emit [										;-- forces a newline marker
				natives/inc-counter as red-word!		;-- increments the counter
			]
			emit-word-ref name
		]
		emit-close-frame/last
	]
	
	comp-forever: does [
		pc: back pc
		change/part pc [while [true]] 1
	]
		
	comp-foreach: has [word blk cond ctx idx][
		case [
			block? pc/1 [
				;TBD: raise error if not a block of words only
				foreach word blk: pc/1 [
					add-symbol word
					add-global word
				]
				idx: either ctx: find-contexts to word! blk/1 [
					red-compiler-emit-block/with blk ctx
				][
					red-compiler-emit-block blk
				]
			]
			word? pc/1 [
				add-symbol word: pc/1
				add-global word
			]
			'else [										;-- fallback option
				emit-open-frame 'foreach
				comp-expression
				comp-expression
				comp-expression
				emit-native 'foreach
				emit-close-frame
				exit
			]
		]
		pc: next pc
		
		emit-open-frame 'foreach
		comp-expression/close-path						;-- compile series argument
		emit-argument-type-check 1 'foreach 'stack/arguments
		
		either blk [
			cond: compose [natives/foreach-next-block (length? blk)]
			emit compose [block/push get-root (idx)]		;-- block argument
		][
			cond: compose [natives/foreach-next]
			emit-push-word word	word					;-- word argument
		]
		insert-lf -2
		
		emit-open-frame 'foreach
		emit compose/deep [
			while [(cond)]
		]
		push-call 'foreach
		comp-sub-block 'foreach-body					;-- compile body
		pop-call
		emit-close-frame
		emit-close-frame
	]
	
	comp-forall: has [word name mark][
		name: pc/1
		word: decorate-symbol name
		emit-get-word name name							;-- save series (for resetting on end)
		emit-push-word name name						;-- word argument
		pc: next pc
		
		emit-open-frame 'forall
		emit make-typeset [series!] none functions/forall/3 yes
		emit [0 stack/arguments - 2]					;-- index of first argument
		insert-lf -9
		
		emit [
			unless natives/forall-next? no
		]
		mark: tail output
		emit-open-frame 'forall
		emit 'forever
		insert-lf -1
		push-call 'forall
		comp-sub-block 'forall-body						;-- compile body
		pop-call
		
		append last output [							;-- inject at tail of body block
			if natives/forall-next? yes [break]			;-- move series to next position
		]
		emit [
			stack/unwind
			natives/forall-end							;-- reset series
			stack/unwind
		]
		convert-to-block mark
	]
	
	comp-remove-each: has [word blk cond ctx idx][
		either block? pc/1 [
			;TBD: raise error if not a block of words only
			foreach word blk: pc/1 [
				add-symbol word
				add-global word
			]
			idx: either ctx: find-contexts to word! blk/1 [
				red-compiler-emit-block/with blk ctx
			][
				red-compiler-emit-block blk
			]
		][
			add-symbol word: pc/1
			add-global word
		]
		pc: next pc
		
		emit-open-frame 'remove-each
		comp-expression/close-path						;-- compile series argument
		emit-argument-type-check 1 'remove-each [stack/arguments]
		emit [integer/push 0]							;-- store number of words to set
		insert-lf -2
		emit [stack/push stack/arguments]
		insert-lf -2

		either blk [
			cond: compose [natives/foreach-next-block (length? blk)]
			emit compose [block/push get-root (idx)]		;-- block argument
		][
			cond: compose [natives/foreach-next]
			emit-push-word word	word					;-- word argument
		]
		insert-lf -2

		emit-open-frame 'remove-each
		if blk [
			emit 'natives/remove-each-init
			insert-lf -1
		]
		emit compose/deep [
			while [(cond)]
		]
		push-call 'remove-each
		comp-sub-block 'remove-each-body				;-- compile body
		append last output compose [
			natives/remove-each-next (either blk [length? blk][1])
		]
		pop-call
		emit-close-frame
		emit-close-frame/last
	]
	
	comp-break: has [inner?][
		if empty? intersect iterators expr-stack [
			pc: back pc
			throw-error "BREAK used with no loop"
		]
		if inner?: 'forall = last intersect expr-stack iterators [
			emit 'natives/forall-end-adjust
			insert-lf -1
		]
		emit compose [stack/unroll-loop (to word! form inner?) break]
		insert-lf -3
	]
	
	comp-continue: has [loops][
		if empty? loops: intersect expr-stack iterators [
			pc: back pc
			throw-error "CONTINUE used with no loop"
		]
		if 'forall = last loops [
			emit copy/deep [if natives/forall-next? yes [break]] ;-- move series to next position
			insert-lf -3
		]
		emit [stack/unroll-loop yes continue]
		insert-lf -3
		insert-lf -1
	]
	
	comp-func-body: func [
		name [word!] spec [block!] body [block!] func-symbols [block!] locals-nb [integer!]
		/local init rs-locals blk args? tracing object-ctx
	][
		push-locals copy func-symbols					;-- prepare compiled spec block
		forall func-symbols [func-symbols/1: decorate-symbol/no-alias func-symbols/1]
		rs-locals: append copy [/local ctx [red-context!] saved [node-handle!] body-top [int-ptr!]] func-symbols ;-- function symbols can stay untyped as they are stored on the Red stack (GC protected)
		set/any 'tracing make-attributs/prolog spec rs-locals
		blk: either container-obj? [head insert copy rs-locals [octx [node-handle!]]][rs-locals]
		emit reduce [to set-word! decorate-func/strict name 'func blk]
		insert-lf -3

		object-ctx: all [object? :container-obj? select-obj container-obj?]
		compiler-redbin-emitter/object-with-ctx: object-ctx
		comp-sub-block/with 'func-body body				;-- compile function's body
		compiler-redbin-emitter/object-with-ctx: none

		;-- Function's prolog --
		pop-locals
		init: make block! 4 * length? func-symbols
		
		append init compose [							;-- point context values series to stack
			ctx: TO_CTX(to paren! last ctx-stack)
			saved: ctx/values
			ctx/values: stack/store-values stack/arguments
			(get/any 'tracing)
		]
		new-line skip tail init -4 on
		args?: yes
		
		forall func-symbols [						;-- assign local variable to Red arguments
			append init to set-word! func-symbols/1
			new-line back tail init on
			if func-symbols/1 = '~local [args?: no]		;-- signal end of arguments
			
			if all [
				args?
				blk: emit-type-checking func-symbols/1 spec
			][
				append init blk
				append init (index? func-symbols) - 1	;-- index of argument for the type-checker
			]
			either head? func-symbols [
				append/only init 'stack/arguments
			][
				repend init [func-symbols/-1 '+ 1]
			]
		]
		unless zero? locals-nb [						;-- init local words on stack
			append init compose [
				_function/init-locals (1 + locals-nb)	;-- +1 for /local refinement
			]
		]
		name: decorate-symbol name
		if find func-symbols name [name: decorate-exec-ctx name]
		
		append init compose [							;-- body stack frame
			stack/mark-func-body words/_body
			body-top: as int-ptr! stack/ctop
		]
		
		;-- Function's epilog --
		append last output compose [
			stack/unroll-to body-top no					;-- close leaked frames and the body, propagating the result
			ctx/values: saved							;-- restore context values pointer
			(make-attributs/epilog spec)
		]
		new-line skip tail last output -4 yes
		
		insert last output init
	]
	
	collect-words: func [spec [block!] body [block!] /local pos loc end ignore words word rule counter nested][
		; Red FIND matches refinement! /extern to word! extern (unlike Rebol).
		if all [pos: find spec /extern refinement? pos/1][
			either end: any [
				all [e: find next pos refinement! refinement? e/1 e]
				find next pos set-word!
			][
				ignore: copy/part next pos end
				remove/part pos end
			][
				ignore: copy next pos
				clear pos
			]
			unless empty? intersect ignore spec [
				pc: skip pc -2
				throw-error ["duplicate word definition in function:" pc/1]
			]
		]
		;-- Check if local words are duplicates of lit/get-word arguments
		; Red FIND matches refinement! /local to word! local (unlike Rebol). Require
		; the refinement! type. Also require lit/get-word! types on false-positive finds.
		if all [loc: find spec /local refinement? loc/1][
			pos: loc
			while [not tail? pos][
				either all [
					find [word! lit-word! get-word!] type?/word pos/1
					any [
						all [
							p: find/part spec to lit-word! pos/1 loc
							lit-word? p/1
						]
						all [
							p: find/part spec to get-word! pos/1 loc
							get-word? p/1
						]
					]
				][
					throw-error ["duplicate word definition in function:" pos/1]
				][
					pos: next pos
				]
			]
		]
		
		foreach item spec [								;-- add all arguments to ignore list
			if find [word! lit-word! get-word! refinement!] type?/word item [
				unless ignore [ignore: make block! 1]
				item: to word! :item
				unless find ignore item [append ignore item]
			]
		]
		words: make block! 1
		
		make-local: [
			unless any [
				all [ignore	find ignore word]
				find words word
			][
				append words word
			]
		]
		parse body rule: [
			any [
				pos: set-word! (
					word: to word! pos/1
					do make-local
				)
				| pos: word! (
					if all [
						find word-iterators pos/1
						counter: pos/2
					][
						foreach word any [
							all [block? counter counter]
							all [any-word? counter reduce [counter]]
							[]
						] [do make-local]
					]
				)
				| path! | lit-path! | set-path!
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
		unless empty? words [
			remove find words 'local					;-- #4998
			pos: tail spec
			; Only match a true refinement! /local (Red FIND/PARSE equate /local and local)
			either all [
				loc: find spec /local
				refinement? loc/1
				parse loc [refinement! any word! loc: to end]
			][
				insert loc words
			][
				append spec /local
				append spec words
			]
			new-line pos yes
			new-line/all next pos no
		]
	]
	
	comp-func: func [
		/collect_ /does_ /has_
		/local
			name word spec body func-symbols locals-nb spec-idx body-idx ctx pos octx
			src-name original global? path obj fpath shadow defer ctx-idx body-code
			alter entry mark flags spec-info
	][
		unless all [block? pc/2 any [does_ block? pc/3]][ ;-- fallback if no literal spec & body blocks
			word: pc/1
			all [
				alter: get-prefix-func word
				entry: find-function alter word
				name: alter
			]
			pc: next pc
			mark: tail output
			do [comp-call/thru word entry/2]
			defer: red-compiler-safe-copy mark
			if series? :mark [clear mark]
			return defer
		]
		original: pc/-1
		case [
			set-path? original [
				path: original
				either all [
					set [obj fpath] object-access? path 
					obj
				][
					do reduce [
						to set-path! append to block! fpath last path
						'function!
					] ;-- update shadow object info
					obj: find-obj obj
					name: to word! rejoin [any [obj/-1 obj/2] #"~" last path] 
					add-symbol name
				][
					name: generate-anon-name			;-- undetermined function assignment case
				]
			]
			any [
				all [set-word? :original]
				global?: all [lit-word? :original pc/-2 = 'set]
			][		
				src-name: to word! original
				unless global? [src-name: get-prefix-func src-name]
				name: check-func-name src-name
				add-symbol/with word: to word! clean-lf-flag name to word! clean-lf-flag original
				unless any [
					local-word? name
					1 < length? obj-stack
				][
					add-global word
				]
			]
			'else [name: generate-anon-name]			;-- unassigned function case
		]
		
		pc: next pc
		spec: pc/1										;-- #5030
		body: pc/2
		
		case [
			collect_ [collect-words spec body]
			does_	 [body: spec spec: make block! 1 pc: back pc]
			has_	 [spec: head insert (red-compiler-safe-copy spec) /local]
		]
		spec-info: check-spec spec
		either all [block? :spec-info 3 <= length? spec-info][
			func-symbols: any [all [block? spec-info/1 spec-info/1] make block! 0]
			locals-nb: any [all [integer? spec-info/2 spec-info/2] 0]
			flags: any [all [integer? spec-info/3 spec-info/3] 0]
		][
			func-symbols: make block! 0
			locals-nb: 0
			flags: 0
		]
		add-function name spec
		pos: head spec
		while [all [not tail? pos not set-word? :pos/1]][pos: next pos]
		if all [not tail? pos pos/1 = return-def][
			register-user-type/store name (pick pos 2)
		]

		
		push-locals (red-compiler-safe-copy func-symbols)	;-- store spec and body blocks
		ctx: push-context (red-compiler-safe-copy func-symbols)
		ctx-idx: red-compiler-emit-context/root ctx func-symbols yes no 'function
		spec-idx: red-compiler-emit-block spec
		redirect-to literals [
			emit compose [
				(to set-word! ctx) get-root-node (ctx-idx) ;-- build context with value on stack
			]
			insert-lf -3
		]
		pop-locals

		repend shadow-funcs [							;-- register a new shadow context
			decorate-func/strict name
			shadow: to-context-spec func-symbols
			ctx
			spec
		]
		bindings/register-shadow shadow ctx spec
		bind-function body shadow
		
		body-code: either job/red-store-bodies? [
			body-idx: red-compiler-emit-block/with body ctx
			reduce ['get-root body-idx]
		][
			[null]
		]
		
		octx: either 1 < length? obj-stack [select-obj either path? :obj-stack [safe-eval-object-path obj-stack][none]][0]
		if all [global? octx octx <> 0][append last functions octx]	;-- add origin obj ctx to function's entry
		
		defer: compose [
			_function/push get-root (spec-idx) (body-code) (ctx)
			as integer! (to get-word! decorate-func/strict name)
			(octx) (flags)
		]
		new-line defer yes
		new-line skip tail defer -4 no
		repend bodies [									;-- save context for deferred function compilation
			name spec body func-symbols locals-nb 
			copy locals-stack copy ssa-names copy ctx-stack
			all [1 < length? obj-stack path? :obj-stack safe-eval-object-path obj-stack]			;-- save optional wrapping object
		]
		pop-context
		pc: skip pc 2
		defer
	]
	
	comp-function: does [
		comp-func/collect_
	]
	
	comp-does: does [
		comp-func/does_
	]
	
	comp-has: does [
		comp-func/has_
	]
	
	comp-routine: has [name word spec spec* body spec-idx body-idx original ctx ret][
		unless set-word? original: pc/-1 [throw-error "a routine must have a name"]
		name: check-func-name get-prefix-func to word! original
		add-symbol word: to word! clean-lf-flag name
		add-global word
		
		pc: next pc
		set [spec body] pc

		preprocess-strings body							;-- encode strings for Red/System
		check-spec spec
		add-function/type name spec 'routine!
		
		process-calls body								;-- process #call directives
		if ctx: find-binding original [
			process-routine-calls body ctx/1 spec select-object ctx/1
		]
		clear find spec*: copy spec /local
		parse spec* [any [word! [pos: block! | (insert/only pos [any-type!])] | skip]]
		spec-idx: red-compiler-emit-block spec*
		body-idx: either job/red-store-bodies? [
			reduce [red-compiler-emit-block body]
		][
			-1
		]
		convert-types spec
		emit reduce [to set-word! name 'func]
		insert-lf -2
		if block? body/1 [insert body 'comment]			;-- disables eventual metadata initial block (used by Red's callbacks)
		append/only output spec
		append/only output body
		
		ret: any [
			all [ret: get-return-type spec get-RS-type-ID ret/1]
			-1
		]
		
		pc: skip pc 2
		compose [
			routine/push get-root (spec-idx) get-root (body-idx) as integer! (to get-word! name) (ret) no
		]
	]
	
	comp-exit: does [
		check-invalid-exit 'exit
		pc: next pc
		emit [
			copy-cell unset-value stack/arguments
		]
		emit-exit-function
	]

	comp-return: does [
		check-invalid-exit 'return
		comp-expression
		unless find expr-stack 'try-all [emit-exit-function]
	]
	
	comp-self: func [original [any-word!] /local obj ctx entry][
		either rebol-gctx = obj: binding-of original [
			pc: back pc									;-- backtrack and process word again
			comp-word/thru
		][
			; Method bodies often bind SELF to the function shadow context. Fall
			; back to the container object registered for deferred method compile.
			unless all [object? :obj entry: find-obj obj][
				obj: any [
					all [object? :container-obj? container-obj?]
					all [path? :obj-stack safe-eval-object-path obj-stack]
				]
				entry: either object? :obj [find-obj obj][none]
			]
			unless entry [throw-error ["cannot resolve SELF for word:" original]]
			obj: entry
			either obj/5 [
				ctx: either empty? locals-stack [obj/2]['octx]
				emit reduce ['object/push ctx obj/5/5 obj/3 obj/5/1 obj/5/2 obj/5/3 obj/5/4] ;-- event(s) case
				insert-lf -8
			][
				emit reduce ['object/init-push obj/2 obj/3]
				insert-lf -3
			]
		]
	]

	comp-switch: has [mark arg body list cnt pos default? value idx][
		if path? pc/-1 [
			foreach ref next pc/-1 [
				switch/default ref [
					default [default?: yes]
					;all []
				][throw-error ["SWITCH has no refinement called" ref]]
			]
		]
		push-call 'switch
		emit-open-frame 'switch
		mark: tail output								;-- pre-compile the SWITCH argument
		comp-expression/close-path
		arg: copy mark
		clear mark
		
		body: pc/1
		if any [not block? body empty? body][
			append output arg
			comp-expression								;-- compile cases argument
			if default? [comp-expression]				;-- optionally compile /default argument
			emit-native/with 'switch reduce [pick [2 -1] to logic! default?]
			emit-close-frame
			pop-call
			exit
		]
		list: make block! 4
		cnt: 1
		parse body [									;-- build a [value index] pairs list
			any [
				block! (cnt: cnt + 1)
				| value: skip (repend list [value/1 cnt])
			]
		]
		idx: red-compiler-emit-block list
		
		emit-open-frame 'select-key*					;-- SWITCH lookup frame
		emit arg
		emit compose [block/push get-root (idx)]
		insert-lf -3
		emit [select-key* no no]
		insert-lf -2
		emit-close-frame
		
		emit [switch integer/get-any*]
		insert-lf -2
		
		clear list
		cnt: 1
		parse body [									;-- build SWITCH cases
			any [skip to block! pos: (
				mark: tail output
				comp-sub-block/with 'switch-body pos/1
				pc: back pc								;-- restore PC position (no block consumed)
				repend list [cnt mark/1]
				clear mark
				cnt: cnt + 1
			) skip]
		]
		pc: next pc
		
		append list 'default							;-- process default case
		either default? [
			comp-sub-block 'switch-default				;-- compile default block
			append/only list last output
			clear back tail output
		][
			append/only list copy [0]					;-- placeholder for keeping R/S compiler happy
		]
		append/only output list
		emit-close-frame
		pop-call
	]
	
	comp-case: has [all? path saved list mark body chunk][
		if path? path: pc/-1 [
			either path/2 = 'all [all?: yes][
				throw-error ["CASE has no refinement called" path/2]
			]
		]
		unless block? pc/1 [
			throw-error "CASE expects a block as argument"
		]
		if empty? pc/1 [emit 'none/push insert-lf -1 exit]
		
		saved: pc
		pc: pc/1
		list: make block! length? pc
		push-call 'case
		
		while [not tail? pc][							;-- precompile all conditions and cases
			mark: tail output
			comp-expression/close-path					;-- process condition
			append/only list copy mark
			clear mark
			case [
				tail? pc [
					throw-error "CASE is missing a value"
				]
				block? pc/1 [
					append/only list comp-sub-block 'case	;-- process case block
					clear back tail output
				]
				'else [
					chunk: tail output
					comp-expression/no-infix/root
					all [								;-- fixes #512
						not empty? chunk
						chunk/1 <> 'stack/reset
						insert/only chunk 'stack/reset
					]
					append/only list copy chunk
					clear chunk
				]
			]
		]
		pc: next saved
		
		either all? [
			foreach [test body] list [					;-- /all mode
				emit-open-frame 'case
				emit test
				emit compose/deep [
					either logic/false? [(set-last-none)]
				]
				append/only output body
				emit-close-frame
			]
		][												;-- default single selection mode
			list: skip tail list -2
			body: reduce ['either 'logic/true? list/2 set-last-none]
			new-line body yes
			insert body list/1
			
			;-- emit expressions tree from leaf to root
			while [not head? list][
				list: skip list -2
				
				insert/only body 'stack/reset
				new-line body yes
				
				body: reduce ['either 'logic/true? list/2 body]
				new-line body yes
				insert body list/1
			]
			
			emit-open-frame 'case
			emit body
			emit-close-frame
		]
		pop-call
	]
	
	comp-reduce: has [list into?][
		push-call 'reduce
		
		into?: path? pc/-1
		unless block? pc/1 [
			emit-open-frame 'reduce
			comp-expression							;-- compile not-literal-block argument
			if into? [comp-expression]				;-- optionally compile /into argument
			emit-native/with 'reduce reduce [pick [1 -1] into?]
			emit-close-frame
			pop-call
			exit
		]
		
		list: either empty? pc/1 [
			pc: next pc								;-- pass the empty source block
			make block! 1
		][
			comp-chunked-block						;-- compile literal block
		]
		
		either path? pc/-2 [						;-- -2 => account for block argument
			comp-expression							;-- compile /into argument
		][
			emit 'block/push-only*					;-- create a fresh new block on stack only
			emit max 1 length? list
			insert-lf -2
		]
		emit-open-frame 'reduce
		foreach chunk list [
			emit chunk
			either into? [
				emit 'block/insert-thru
				insert-lf -1
			][
				emit 'block/append-thru
				insert-lf -1
			]
			emit-stack-reset
		]
		emit-close-frame
		pop-call
		emit [stack/pop 1]
	]
	
	comp-set: has [name call any? case? only? some? w][
		either all [lit-word? pc/1 not path? pc/-1][
			name: to word! pc/1
			either local-bound? pc/1 [
				pc: next pc
				comp-local-set name
			][
				comp-set-word/native
			]
		][
			either block? pc/1 [						;-- if words are literals, register them
				foreach w pc/1 [
					unless any-word? w [throw-error ["Invalid argument to SET:" mold pc/1]]
					add-symbol w: to word! w
					unless local-word? w [add-global w]	;-- register it as global
				]
			][
				if lit-word? pc/1 [
					add-symbol w: to word! pc/1
					unless local-word? w [add-global w]	;-- register it as global
				]
			]
			call: pc/-1
			foreach [flag opt][any? any case? case only? only some? some][
				;-- /same: avoid matching get-word refinements (set/:any) as static flags
				set flag pick [0 -1] to logic! all [path? call find/same call opt]
			]
			emit-open-frame 'set
			comp-expression
			comp-expression
			emit-native/with 'set reduce [any? case? only? some?]
			emit-close-frame
		]
	]
	
	comp-get: has [symbol original call any? case?][
		either lit-word? original: pc/1 [
			add-symbol symbol: to word! original
			either path? pc/-1 [						;@@ add check for validaty of refinements		
				emit-get-word/any? symbol original
			][
				emit-get-word symbol original
			]
			pc: next pc
		][
			call: pc/-1
			;-- /same: avoid matching get-word refinements (get/:any) as static flags
			case?: to logic! all [path? call find/same call 'case]
			any?:  to logic! all [path? call find/same call 'any]
			emit-open-frame 'get
			comp-substitute-expression
			emit-native/with 'get reduce [pick [0 -1] any? pick [0 -1] case?]
			emit-close-frame
		]
	]
	
	comp-path: func [
		root? [logic!]
		/set?
		/local 
			path value emit? get? entry alter saved after dynamic? ctx mark obj? new t? p
			fpath symbol obj self? true-blk defer obj-field? parent fire index breaks pos][
		path:  copy pc/1
		emit?: yes
		set?:  to logic! set?
		get?: get-path? :path
		if get? [path: to path! path]
		
		unless path: system-words-path? path [exit]
		
		if dynamic?: find path paren! [					;-- fallback to interpreter if parens found
			emit-open-frame 'body
			if set? [
				saved: pc
				pc: next pc
				comp-expression
				after: pc
				pc: saved
			]
			comp-literal
			pc: back pc
			
			unless set? [emit [stack/mark-native words/_body]]	;@@ not clean...
			emit compose [
				interpreter/eval-path stack/top - 1 null null null (to word! form set?) no (to word! form root?) no
			]
			unless set? [emit [stack/unwind-last]]
			
			emit-close-frame
			pc: either set? [after][next pc]
			exit
		]
		
		if all [not set? not get? defer: dispatch-ctx-keywords/with pc/1/1 path/1][
			if block? defer [emit defer]
			exit
		]
		
		forall path [									;-- preprocessing path
			switch/default type?/word value: path/1 [
				word! [
					if all [
						not set? not get?
						all [
							alter: get-prefix-func value
							entry: find-function alter value
							name: alter
						]
					][
						if head? path [
							if all [alter: select-ssa name name: alter][
								path/1: alter
								if new: find functions alter [entry: new]	;-- keep entry if alias target was redefined away
							]
							pc: next pc
							either ctx: any [
								obj-func-call? value
								pick entry/2 5
							][
								comp-call/with path entry/2 name ctx ;-- call function with refinements
							][
								comp-call path entry/2
							]
							exit
						]
					]
					add-symbol value					;-- ensure the word is defined in global context
				]
				get-word! [
					if head? path [
						get?: yes
						change path to word! path/1
					]
				]
				integer! paren! string!	[
					if head? path [probe "path-head-error"]
				]
			][
				throw-error ["cannot use" mold type? value "value in path:" pc/1]
			]
		]
		self?: do [path/1 = 'self]
		if all [
			not any [set? dynamic? find path integer!]
			set [fpath symbol ctx] obj-func-path? path
		][
			either get? [
				check-new-func-name symbol ctx
			][
				pc: next pc
				comp-call/with fpath functions/:symbol symbol ctx
				exit
			]
		]
		
		obj?: all [
			not any [dynamic? find path integer!]
			set [obj fpath] object-access? path
			obj
		]
		
		if set? [
			pc: next pc
			either obj? [									;-- fetch assigned value earlier
				unless defer: dispatch-ctx-keywords none [	;-- detect function/object declaration
					comp-expression
				]
			][
				defer: dispatch-ctx-keywords none
			]
			if block? defer [emit defer]
		]
		

		if obj-field?: all [
			obj? 
			word? last path								;-- not allow get-words to pass (#1141)
			any [self? (length? path) = length? fpath]	;-- allow only object-path/field forms
		][
			either self? [
				p: path
				until [										;-- process nested objects
					t?: tail? next p: next p
					obj: find-obj obj
					if all [not t? object? new: select obj/1 p/1][
						obj: new
						if t? [obj: find-obj obj]
					]
					t?
				]
			][
				obj: find-obj obj
			]
			ctx: second obj
			unless index: get-word-index/with last path ctx [
				; Shadow object may have fields missing from the static contexts table
				; (seen with make <proto> [] under nested contexts during self-host).
				; Rebuild the table from words-of so indices match runtime object layout.
				either all [
					object? first obj
					in first obj last path
				][
					pos: words-of first obj
					either select contexts ctx [
						clear select contexts ctx
						append select contexts ctx pos
					][
						repend contexts [ctx copy pos]
					]
					index: (index? find pos last path) - 1
				][
					throw-error ["word" last path "not defined in" path]
				]
			]
			
			true-blk: compose/deep pick [
				[[word/set-in-ctx (ctx) (index)]]
				[[word/get-local  (ctx) (index)]]
			] set?
			
			mark: none
			either self? [
				if all [not empty? locals-stack	container-obj?][
					true-blk/1/2: 'octx
				]
				mark: tail output
				emit first true-blk
			][
				emit compose [
					either (emit-deep-check path fpath) (true-blk)
				]
			]
			if all [set? obj/5 obj/5/1 <> -1][			;-- detect on-set callback 
				insert clear any [mark last output] compose [
					stack/keep							;-- save new value
					word/replace (ctx) (get-word-index/with last path ctx)	;-- push old, set new
				]
				fire: pick [
					object/loc-fire-on-set*
					object/fire-on-set*
				] to logic! local-word? first back back tail path
				
				parent: case [
					2 < length? path [						;-- extract word from parent context
						breaks: [-12 -9 -6 -1]
						set [obj fpath] object-access? copy/part path (length? path) - 1
						ctx: second obj: find-obj obj
						['word/from ctx get-word-index/with pick tail path -2 ctx]
					]
					self? [									;-- self/field
						breaks: [-10 -7 -4 -1]
						set [obj fpath] object-access? copy/part path 1
						ctx: second obj: find-obj obj
						fire: 'object/loc-ctx-fire-on-set*
						[ctx]
					]
					'else [
						breaks: [-10 -7 -4 -1]				;-- word is in global context
						[decorate-symbol path/1]
					]
				]
				repend any [mark last output] compose [
					fire
						(parent)
						decorate-exec-ctx decorate-symbol last path
				]
				append any [mark last output][
					stack/reset
				]
				foreach pos breaks [new-line skip tail any [mark last output] pos yes]
			]
		]
		mark: tail output
		
		;either any [obj? set? get? dynamic? not parse path [some word!]][
			unless self? [
				emit-path path set? to logic! any [obj? defer]
				unless obj-field? [obj?: no]			;-- static path emitted, not special anymore
			]
		;][
		;	append/only paths-stack path				;-- defer path generation
		;]
		
		if all [obj? not self?][change/only/part mark copy mark tail output]
		unless set? [pc: next pc]
	]
	
	comp-arguments: func [spec [block!] nb [integer!] /ref name [refinement!] /local word paths type][
		if ref [spec: find/tail spec name]
		paths: length? paths-stack
		
		repeat i nb [
			while [not any-word? spec/1][				;-- skip attributs and docstrings
				spec: next spec
			]
			switch type?/word spec/1 [
				lit-word! [
					either all [
						tail? pc
						all [spec/2 find spec/2 'any-type!]
					][
						emit 'unset/push				;-- provide unset as placeholder
						insert-lf -1
					][
						type: either all [path? pc/1 get-word? pc/1/1][
							'get-path!
						][type?/word pc/1]
						switch/default type [
							get-word! [
								add-symbol to word! pc/1
								comp-expression
							]
							lit-word! [
								add-symbol word: to word! pc/1
								emit 'lit-word/push
								emit decorate-symbol word
								insert-lf -2
								pc: next pc
							]
							word! [
								add-symbol word: to word! pc/1
								emit-push-word word	word	;@@ add specific type checking
								pc: next pc
							]
							lit-path! [comp-literal/inactive]
							paren! get-path! [comp-expression]
						][
							comp-literal
						]
					]
				]
				get-word! [comp-literal/inactive]
				word!     [comp-expression]
			]
			if paths < length? paths-stack [
				if 'stack/unwind = last output [i: i + 1] ;-- count nested argument with path
				repeat n nb - i + 1 [
					emit [stack/push pos +]
					emit n - 1
					insert-lf -4
				]
				return true								;-- stop compiling new arguments
			]
			spec: next spec
		]
		false
	]
		
	comp-call: func [
		call [word! path!]
		spec [block!]
		/with symbol ctx-name [word!]
		/thru
		/local 
			item name compact? refs ref? cnt pos ctx mark list offset emit-no-ref fctx
			args option stop? original get? dyn-list blk native? code type v id
	][
		either all [not thru spec/1 = 'intrinsic!][
			switch any [all [path? call call/1] call] keywords
		][
			if path? call [
				list: to block! call
				if (length? list) <> (length? unique list)[
					pc: back pc
					throw-error ["duplicate or invalid refinement usage:" call]
				]
			]
			compact?: spec/1 <> 'function!				;-- do not push refinements on stack
			refs: make block! 1							;-- refinements storage in compact mode
			cnt: 0
			
			name: original: either path? call [call/1][call]
			name: to word! clean-lf-flag name
			either all [with not empty? locals-stack not compact?][	;-- only if in a function's body
				fctx: get-func-ctx name ctx-name
				if fctx = 'null [fctx: ctx-name]		;-- path-generated wrapper fallback
				emit reduce [							;-- special case for path-generated wrapper functions
					'stack/mark-func 
					decorate-exec-ctx decorate-symbol name
					fctx
				]
				insert-lf -3
			][
				emit-open-frame/with name spec/1 ctx-name
			]
			current-call: call							;-- for error reporting
			pos: pc
			comp-arguments spec/3 spec/2				;-- fetch arguments
			unless any [none? spec/4 block? spec/4][
				fail ["invalid function refinement metadata:" name mold spec]
			]
			
			if all [path? call none? spec/4][
				pc: back pos
				throw-error [call/1 "has no refinement"]
			]
			
			either compact? [							;-- native/action/routine compact refinements case
				refs: either spec/4 [
					head insert/dup make block! 8 -1 (length? spec/4) / 3	;-- init with -1
				][
					[]									;-- function with no refinements
				]
				if path? call [
					cnt: spec/2							;-- function base arity
					get?: to-logic find call get-word!
					foreach ref next call [
						ref: to refinement! original: ref
						unless pos: find/skip spec/4 ref 3 [
							throw-error [call/1 "has no refinement called" ref]
						]
						either get? [
							unless dyn-list [dyn-list: make block! 2]
							redirect-to blk: make block! 4 either get-word? original [
								[emit-get-word to-word ref original]
							][
								[emit [logic/push true]]
							]
							repend dyn-list [to-paren blk pos/2 cnt pos/3]
						][
							poke refs pos/2 cnt				;-- set refinement's arguments base offset
						]
						unless stop? [
							stop?: comp-arguments/ref spec/3 pos/3 ref ;-- fetch refinement arguments
						]
						cnt: cnt + pos/3				;-- increase by nb of arguments
					]
					if dyn-list [
						insert dyn-list reduce [to-word form native?: spec/1 <> 'action! (length? spec/4) / 3]
						insert dyn-list get-native-ID name native?
						code: reduce ['call-with-array* dyn-list]
						either native? [emit-native/applied name code][emit code insert-lf -2]
						emit-close-frame
						exit
					]
				]
			][											;-- prepare function! stack layout
				emit-no-ref: [							;-- populate stack for unused refinement
					emit [logic/push false]				;-- unused refinement is set to FALSE
					insert-lf -2
					loop args [
						emit 'none/push					;-- unused arguments are set to NONE
						insert-lf -1
					]
				]
				either path? call [						;-- call with refinements?
					ctx: copy spec/4					;-- get a new context block
					foreach ref next call [
						unless find [word! get-word!] type?/word ref [throw-error ["incompatible type" ref "in" call]]
						option: to refinement! ref
						
						unless pos: find/skip spec/4 option 3 [
							throw-error [call/1 "has no refinement called" ref]
						]
						get?: get-word? ref
						offset: 2 + index? pos
						v: either not get? [true][
							unless dyn-list [dyn-list: make block! 2]
							repend dyn-list [ref  symbol-index? spec/3 to word! ref  pos/3]
							to-get-word ref
						]
						poke ctx index? pos v			;-- switch refinement to true or get-word in context
						unless zero? args: pos/3 [		;-- process refinement's arguments
							list: make block! 1
							ctx/:offset: list 			;-- compiled refinement arguments storage
							mark: tail output
							unless stop? [
								stop?: comp-arguments/ref spec/3 args option
							]
							append/only list copy mark
							clear mark
						]
					]
					forall ctx [						;-- push context values on stack
						switch type: type?/word ctx/1 [
							refinement! [				;-- unused refinement
								args: either block? ctx/3 [length? ctx/3][ctx/3]
								do emit-no-ref
							]
							logic!
							get-word! [					;-- used refinement
								emit compose [logic/push (pick [true false] type = 'logic!)]
								insert-lf -2
								if block? ctx/3 [
									foreach code ctx/3 [emit code] ;-- emit pre-compiled arguments
								]
							]
						]
					]
					if dyn-list [
						;-- while/skip instead of foreach [a b c]: Stage1-compiled
						;-- foreach-next-block can see a misaligned Red stack (series slot
						;-- holds an object with class=-1) and halt on resolve-series.
						pos: dyn-list
						while [not tail? pos][
							mark: tail output
							emit 'set-opt-refinement*
							emit-get-word to-word pos/1 pos/1
							emit reduce [pos/2 pos/3]
							new-line/all mark off
							insert-lf -5
							pos: skip pos 3
						]
					]
				][										;-- call with no refinements
					if spec/4 [
						foreach [ref offset args] spec/4 [do emit-no-ref]
					]
				]
			]
			
			switch spec/1 [
				intrinsic!								;-- fallback to native case
				native! 	[emit-native/with name refs]
				action! 	[emit-action/with name refs]
				op!			[]
				routine!	[emit-routine any [symbol name] spec/3]
				function! 	[
					emit decorate-func any [symbol name]
					insert-lf either with [emit ctx-name -2][-1]
				]
				
			]
			emit-close-frame
		]
	]
	
	comp-local-set: func [name [word!]][
		emit-open-frame 'set
		comp-expression
		emit [copy-cell stack/arguments]
		emit decorate-symbol name
		insert-lf -3
		emit-close-frame
	]
	
	comp-set-make: has [entry name][
		name: pc/-1
		switch/default pc/2 [
			datatype! [
				either any [
					pc/3 = get-definition-directive
					all [issue? pc/3 (form pc/3) = "get-definition"]
				][
					red-compiler-emit-word-root/set? name none none
					compiler-redbin-emitter/emit-datatype pc/4
					pc: skip pc 4
					yes
				][
					no
				]
			]
			action!
			native! [
				either all [
					block? pc/3
					(length? pc/3) >= 2
					any [
						pc/3/2 = get-definition-directive
						all [issue? pc/3/2 (form pc/3/2) = "get-definition"]
					]
				][
					red-compiler-emit-word-root/set? name none none
					either pc/2 = 'action! [
						red-compiler-emit-native/action pc/3/3 pc/3/1
					][
						red-compiler-emit-native pc/3/3 pc/3/1
					]
					fetch-functions back pc
					pc: skip pc 3
					yes
				][
					no
				]
			]
		][
			no
		]
	]
	
	comp-set-word: func [
		/native
		/local 
			name value ctx original obj obj-bound? deep? inherit? proto
			defer start preset? no-check?
	][
		name: original: pc/1
		pc: next pc
		unless local-word? name: to word! clean-lf-flag name [
			add-symbol name
			add-global name
		]
		
		if infix? pc [
			emit-push-word original original
			exit
		]
		if all [not booting? find intrinsics name][
			throw-error ["attempt to redefine a keyword:" name]
		]
		
		obj-bound?: all [
			rebol-gctx <> obj: binding-of original
			not bindings/shadow-context-of obj
		]
		;-- Stage1: body words may be unbound after load; use current object from stack.
		unless obj-bound? [
			if all [
				1 < length? obj-stack
				obj: attempt [safe-eval-object-path obj-stack]
				object? :obj
				select-obj obj
			][obj-bound?: yes]
		]
		deep?: 1 < length? obj-stack
		; Reentrant set-word frames: store mark series on frame-stack (object field).
		; Do not rely on method locals for the mark position under compiled Stage1.
		append/only frame-stack tail output
		start: none
		
		;-- Try to push the name/value pair into Redbin data --
		all [
			not deep?
			rebol-gctx = obj
			empty? expr-stack
			pc/1 = 'make
			comp-set-make
			take/last frame-stack
			exit
		]
		if all [word? name find [path! word!] type?/word pc/1 is-object? pc/1][
			register-object/store pc/1 name
			no-check?: yes
		]
		;-- General case: emit stack-oriented construction code --
		emit-open-frame 'set
		
		either native [									;-- 1st argument
			pc: back pc
			comp-expression								;-- fetch a value
		][
			unless obj-bound? [
				emit-push-word name	original 			;-- push set-word
			]
		]
		
		push-call 'set
		case [
			all [
				pc/1 = 'make
				any [pc/2 = 'object! proto: is-object? pc/2]
			][
				start: red-compiler-take-frame last frame-stack
				check-redefined name original
				pc: next pc
				defer: either proto [
					comp-context/with/extend original proto
				][
					comp-context/with original
				]
				unless defer [insert last frame-stack start]	;-- restore beginning of frame
			]
			all [
				any [word? pc/1 all [path? pc/1 not get-word? pc/1/1]]
				(
					start: red-compiler-take-frame last frame-stack
					not block? pc/1
				)
				any [not find [object context construct] pc/1 check-redefined name original]
				defer: dispatch-ctx-keywords/with original pc/1
			][]
			'else [
				if start [emit start]
				unless any [obj-bound? no-check?][check-redefined name original]
				check-cloned-function name original
				comp-substitute-expression				;-- fetch a value (2nd argument)
			]
		]
		pop-call
		
		if block? defer [								;-- object or function case
			emit start
			emit defer
		]
		take/last frame-stack
		
		either native [
			emit-native/with 'set [-1 -1 -1 -1]			;@@ refinement not handled yet
		][
			either all [obj-bound? ctx: select-obj obj][
				emit 'word/set-in
				emit either parent-object? obj ['octx][ctx] ;-- optional parametrized context reference (octx)
				emit get-word-index/with name ctx
				insert-lf -3
			][
				emit 'word/set
				insert-lf -1
			]
		]
		emit-close-frame
	]

	comp-word: func [/literal /final /thru /local name local? self? alter emit-word original new ctx defer][
		name: to word! original: pc/1
		local?: local-bound? original
		
		emit-word: [
			either lit-word? original [					;@@
				emit-push-word name original
			][
				either literal [
					emit-get-word/literal name original
				][
					emit-get-word name original
				]
			]
		]
		
		if all [
			not local?
			defer: dispatch-ctx-keywords original
		][
			if block? defer [emit defer]
			exit
		]
		pc: next pc										;@@ move it deeper

		self?: do [name = 'self]
		case [
			all [not thru name = 'exit	][comp-exit]
			all [not thru name = 'return][comp-return]
			all [not thru self?			][comp-self original]
			all [
				not final
				not local?
				name = 'make
				word? pc/1
				any-function? pc/1
			][
				if pc/1 = 'routine! [throw-error "MAKE routine! is not supported"]
				defer: fetch-functions skip pc -2		;-- extract functions definitions
				pc: back pc
				comp-word/final
				if defer [								;-- make op! func ... post-processing
					repend op-actions [
						defer
						name: to word! next next form first find/last skip tail output -10 get-word!
					]
					all [
						entry: find functions name
						1 < length? obj-stack
						append entry/2 select-obj either path? :obj-stack [safe-eval-object-path obj-stack][none]	;-- append context name if method
					]
				]
			]
			all [
				not literal
				not local?
				any [
					all [
						alter: get-prefix-func original
						entry: find functions alter
						name: alter
					]
					all [
						rebol-gctx = binding-of original
						entry: find functions name
					]
				]
			][
				;-- select-ssa may remap `name` to an alias target (e.g. `time-it: :dt`
				;-- => `time-it` -> `dt`) whose `functions` entry was removed by a later
				;-- redefinition (`dt:` set-word). Keep the existing entry in that case,
				;-- since the alias retained an equivalent spec.
				if all [alter: select-ssa name name: alter][
					if new: find functions alter [entry: new]
				]
			
				either ctx: any [
					obj-func-call? original
					pick entry/2 5
				][
					comp-call/with name entry/2 name ctx
				][
					comp-call name entry/2
				]
			]
			any [
				find globals name
				find-contexts name
				; Get-word of ops/natives (e.g. :< or :+) is literal mode, so the
				; function-call branch above is skipped. Still treat known functions
				; as defined so get-word/get can load the value (function-test fun-ref-4).
				find functions name
			][
				unless find/case symbols name [add-symbol name]
				do emit-word
			]
			'else [
				either job/red-strict-check? [
					pc: back pc
					throw-error ["undefined word" pc/1]
				][
					add-symbol to word! first back pc
					do emit-word
				]
			]
		]
	]
	
	search-expr-end: func [pos [block! paren!]][
		if infix? next pos [pos: search-expr-end skip pos 2]
		pos
	]
	
	make-func-prefix: func [name [word!]][
		load rejoin [									;@@ cache results locally
			head remove back tail form functions/:name/1 "s/"
			name #"*"
		]
	]
	
	check-infix-operators: func [
		root? [logic!]
		/local name op pos end ops spec substitute cnt paths single?
	][
		if infix? pc [return false]						;-- infix op already processed,
														;-- or used in prefix mode.
		if infix? next pc [
			substitute: [
				if paths < length? paths-stack [
					emit [stack/push pos +]
					emit cnt
					insert-lf -4
					cnt: cnt + 1
				]
			]
			cnt: 0
			pos: pc
			end: search-expr-end pos					;-- recursive search of expression end
			
			ops: make block! 1
			pos: end									;-- start from end of expression
			until [
				op: pos/-1			
				name: any [select op-actions op op]
				insert ops name							;-- remember ops in left-to-right order
				emit-open-frame op
				pos: skip pos -2						;-- process next previous op
				pos = pc								;-- until we reach the beginning of expression
			]
			paths: length? paths-stack
			comp-expression/no-infix					;-- fetch first left operand
			do substitute
			pc: next pc

			forall ops [
				paths: length? paths-stack
				single?: path? pc/1
				comp-expression/no-infix				;-- fetch right operand
				if single? [do substitute]
				
				name: ops/1
				spec: functions/:name
				switch/default spec/1 [
					function! [
						emit decorate-func name
						insert-lf either spec/5 [emit spec/5 -2][-1]
					]
					routine!  [emit-routine name spec/3]
				][
					emit make-func-prefix name
					insert-lf either spec/1 = 'native! [emit 'yes -2][-1] ;-- request run-time type-checking
				]
				
				emit-close-frame
				unless tail? next ops [pc: next pc]		;-- jump over op word unless last operand
			]
			return true									;-- infix expression processed
		]
		false											;-- not an infix expression
	]
	
	prepare-typesets: func [name [word!] spec [block!] /local list cnt arg expr][
		list: insert make block! 10 [0 0x0]				;-- insert fake debug header info
		cnt: 0
		
		parse spec [
			any [
				set arg [word! | lit-word! | get-word!] (
					append list compose [
						(emit-type-checking/native arg spec)
						(cnt)
						stack/arguments
					]
					new-line back tail list off
					insert-lf either cnt > 0 [
						expr: to paren! compose [stack/arguments + (cnt)]
						expr: insert expr [0 0x0]		;-- insert fake debug header info				
						change/only back tail list expr
						-5
					][-3]
					cnt: cnt + 1
				)
				| refinement! (cnt: cnt + 1)
				| skip
			]
		]
		unless empty? list [
			list: insert list [0 0x0]
			list: reduce ['if 'check? list]
			repend native-ts [name list]
		]
	]
		
	process-typecheck-directive: func [spec [word! block!] /local name res pos refs][
		name: either block? spec [spec/1][spec]
		if pos: select [								;-- words protected from macro replacement
			-unless-	unless
			-forever-	forever
			-does-		does
			-prin-		prin
			-positive?-	positive?
			-negative?-	negative?
			-max-		max
			-min-		min
			-zero?-     zero?
		] name [
			name: pos
		]
		res: select native-ts name
		
		if all [res block? spec][
			refs: functions/:name/4
			spec: next spec
			parse res/3 [								;-- rewrite checks for optional args
				some [
					pos: 'type-check-alt (
						if tail? spec [throw-error ["missing values in #typecheck block:" spec]]
						pos/1: 'type-check-opt
						pos/2: pick spec select refs to refinement! next form pos/2
						remove at pos 8
						new-line pos yes
					) 2 skip
					| skip
				]
			]
		]
		res
	]
	
	process-get-directive: func [
		spec code [block!] /local obj fpath ctx blk idx
	][
		switch/default type?/word spec [
			path! [
				unless parse spec [some word!][
					throw-error ["invalid #get argument:" spec]
				]
				set [obj fpath] object-access? spec
				ctx: second obj: find-obj obj
				unless idx: get-word-index/with last spec ctx [return none]
				remove/part code 2
				blk: [red/word/get-in (decorate-exec-ctx ctx) (idx)]
				insert code compose blk
			]
			word! [
				remove/part code 2
				insert code compose [red/word/get (decorate-exec-ctx decorate-symbol spec)]
			]
		][throw-error ["invalid #get argument:" spec]]
	]
	
	process-in-directive: func [
		path word code [block!] /local obj fpath ctx blk idx
	][
		if any [not path? path not any-word? :word][
			throw-error ["invalid #in argument:" mold path mold :word]
		]
		append path word
		set [obj fpath] object-access? path
		ctx: second obj: find-obj obj
		unless idx: get-word-index/with word ctx [return none]
		remove/part code 3
		blk: [red/object/get-word (decorate-exec-ctx ctx) (idx)]
		insert code compose blk
	]
	
	process-call-directive: func [
		body [block!] global?
		/local name spec cmd types type arg path ctx offset
	][
		name: body/1
		switch/default type?/word name [
			word! [name: to word! clean-lf-flag name]
			path! [set [path name ctx] obj-func-path? body/1]
		][
			throw-error ["invalid function name in #call:" mold body]
		]
		if any [
			not spec: select functions name
			not spec/1 = 'function!
		][
			throw-error ["invalid #call function name:" name]
		]
		either global? [
			emit 'red/stack/mark-func
			emit decorate-exec-ctx decorate-symbol name
			emit get-func-ctx name none
			insert-lf -3
		][
			emit-open-frame name
		]
		types: spec/3
		body: next body
		
		loop spec/2 [									;-- process arguments
			type: none
			types: find/tail types word!
			if block? types/1 [
				either 1 = length? types/1 [
					type: types/1/1
				][
					arg: body/1
					if word? :arg [arg: attempt [get arg]]
					type: none
					foreach value types/1 [
						if value = type?/word :arg [type: value break]
					]
				]
				if find [any-type! object!] type [type: none]
			]
			offset: either type [
				cmd: to path! reduce [to word! form get type 'push]
				if global? [insert cmd pick [exec red] type = 'event!] ;@@ ad-hoc treatment of event!...
				-1
			][
				cmd: [red/stack/push as cell!]
				-3
			]
			emit cmd
			insert-lf offset
			case [
				none? body/1 [
					throw-error ["missing argument(s) in #call body"]
				]
				body/1 = 'as [
					emit copy/part body 3
					body: skip body 3
				]
				body/1 = 'none [
					body: next body
				]
				'else [
					emit body/1
					body: next body
				]
			]
		]
		
		types: next types								;-- process refinements
		while [not tail? types][
			switch type?/word types/1 [
				refinement! [
					if types/1 = /local [break]
					emit 'red/logic/push 
					emit to word! form to logic! all [
						path? path
						find path to word! types/1
					]
					insert-lf -2
				]
				word! [
					emit 'red/none/push
					insert-lf -1
				]
				set-word! [break]
			]
			types: next types
		]
		
		name: decorate-func name						;-- function call
		if global? [name: decorate-exec-ctx name]
		emit name
		insert-lf either ctx [emit decorate-exec-ctx ctx -2][-1]
		
		either global? [
			emit 'red/stack/unwind-last
			insert-lf -1
			emit 'red/stack/reset
		][
			emit-close-frame
			emit 'stack/reset
		]
		insert-lf -1
	]
	
	comp-include: func [pc [block!] /only /local file saved version mark script-file saved-script-path saved-include-stk][
		unless file? file: pc/2 [
			throw-error ["#include requires a file argument:" pc/2]
		]
		if only [saved-include-stk: copy include-stk]
		append include-stk script-path
		saved-script-path: script-path

		file: resolve-include-file file
		script-path: first split-path file

		unless any [booting? exists? file][
			throw-error ["include file not found:" pc/2]
		]
		either find included-list file [
			script-path: take/last include-stk
			remove/part pc 2
			if only [script-path: saved-script-path]
		][
			script-file: file
			if all [slash <> first file	script-path][
				script-file: clean-path join script-path pc/2
			]
			append script-stk script-file
			emit reduce [						;-- force a newline at head
				#script script-file
			]
			saved: script-name
			unless only [insert skip pc 2 #pop-path]
			src: load-source/header file
			src: compiler-preprocessor/expand src job
			change/part pc next src 2			;@@ Header skipped, should be processed
			script-name: saved
			append included-list file
			if only [
				script-path: saved-script-path
				include-stk: saved-include-stk
			]
			unless any [only empty? expr-stack][comp-expression]
		]
	]

	comp-directive: has [mark value][
		if pc/1 = include-directive [
			comp-include pc
			return true
		]
		if pc/1 = get-definition-directive [
			either value: select extracts/definitions pc/2 [
				change/only/part pc value 2
				comp-expression						;-- continue expression fetching
			][
				pc: next pc
			]
			return true
		]
		switch pc/1 [
			#pop-path [
				take/last script-stk
				script-path: take/last include-stk
				pc: next pc
				true
			]
			#system [
				unless block? pc/2 [
					throw-error "#system requires a block argument"
				]
				process-include-paths pc/2
				process-calls pc/2
				preprocess-strings pc/2					;-- encode strings for Red/System
				emit reduce [							;-- force a newline at head
					#script script-name
				]
				mark: tail output
				emit pc/2
				new-line mark on
				emit reduce [							;-- force a newline at head
					#script script-name
				]
				pc: skip pc 2
				true
			]
			#system-global [
				unless block? pc/2 [
					throw-error "#system-global requires a block argument"
				]
				process-include-paths pc/2
				preprocess-strings pc/2					;-- encode strings for Red/System
				unless sys-global/1 = 'Red/System [
					append sys-global copy/deep [Red/System []]
				]
				append sys-global pc/2
				repend sys-global [						;-- force a newline at head
					#script script-name
				]
				pc: skip pc 2
				true
			]
			#register-intrinsics [						;-- internal boot-level directive
				if booting? [
					pc: next pc
					make-keywords						;-- register intrinsics functions
				]
				booting?
			]
		]
	]
	
	comp-substitute-expression: has [paths mark][
		paths: length? paths-stack
		mark: tail output
		
		comp-expression
		
		if all [
			paths < length? paths-stack
			not find mark [stack/push pos]
		][
			emit [stack/push pos + 0]
			insert-lf -4
		]
		mark: none
	]
	
	comp-expression: func [/no-infix /root /close-path /local out paths][
		root: to logic! root 
		if any [root close-path][out: tail output]
		paths: length? paths-stack
		
		unless no-infix [
			if check-infix-operators root [
				if all [root 'stack/reset <> last output][
					emit-stack-reset					;-- clear stack from last root expression result
				]
				exit
			]

		]
		if tail? pc [
			pc: any [find/reverse pc current-call back pc]
			throw-error "missing argument"
		]
		
		switch/default type?/word pc/1 [
			issue!		[unless comp-directive [comp-literal]]
			;-- active datatypes with specific literal form
			set-word!	[comp-set-word]
			word!		[comp-word]
			get-word!	[comp-word/literal]
			paren!		[comp-paren root]
			set-path!	[comp-path/set? root]
			get-path!	[comp-path root]
			path! 		[comp-path root]
		][
			comp-literal
		]
		if root [
			either tail? pc	[
				unless find/only [stack/reset stack/unwind] last output [
					emit-dyn-check
				]
			][
				if 'stack/reset <> last output [
					emit-stack-reset					;-- clear stack from last root expression result
				]
			]
		]
		if any [root close-path][
			if paths < length? paths-stack [
				;emit-dynamic-path out
				if tail? pc [emit-dyn-check]
			]
		]
	]
	
	comp-paren: func [root? [logic!]][
		emit-open-frame 'paren
		comp-next-block root?
		emit-close-frame
	]
	
	comp-next-block: func [root? [logic!] /with blk /local saved pos][
		saved: pc
		pc: any [blk pc/1]
		
		comp-block
		
		unless root? [
			case [
				'stack/reset = last output [remove back tail output]
				all [
					comment-marker = pick tail output -2
					'stack/reset = pick tail output -3
				][
					remove skip tail output -3
				]
			]
		]
		pc: next saved
	]
	
	comp-chunked-block: has [list mark saved][
		list: make block! 10
		saved: pc
		pc: pc/1										;-- dive in nested code
		mark: tail output
		
		comp-block/with [
			mold mark									;-- black magic, fixes #509, R2 internal memory corruption
			append/only list copy mark
			clear mark
		]
		
		pc: next saved
		list
	]
	
	comp-sub-block: func [origin [word!] /with body /local mark saved][
		unless any [with block? pc/1][
			throw-error [
				"expected a block for" uppercase form origin
				"instead of" mold type? pc/1 "value"
			]
		]
		
		mark: tail output
		saved: pc
		pc: any [body pc/1]								;-- dive in nested code
		comp-block
		pc: next saved									;-- step over block in source code				

		convert-to-block mark
		head insert last output [
			stack/reset
		]
	]
	
	comp-block: func [
		/with body [block!]
		/no-root
		/local expr size
	][
		if tail? pc [
			emit 'unset/push
			insert-lf -1
			exit
		]
		while [not tail? pc][
			expr: pc
			either no-root [comp-expression][comp-expression/root]
			
			if all [verbose > 3 positive? size: offset? expr pc][probe copy/part expr size]
			if verbose > 0 [emit-src-comment expr]
			
			if with [do body]
		]
	]
	
	store-header: func [spec [block!] /local saved][
		unless empty? spec [
			saved: pc
			pc: compose/only [system/script/header: construct/with (spec) system/standard/header]
			comp-block
			pc: saved
		]
	]
	
	register-object: func [obj [word! path!] name /store /local pos prev entry o][
		if pos: any [
			all [path? obj object? o: safe-eval-object-path head insert copy obj 'objects find-object o]
			all [not path? obj find-object/by-name obj]
		][
			;if prev: find get-obj-base name name [prev/1: none] ;-- unbind word with previous object

			insert entry: tail objects copy/part pos 6
			entry/1: to word! name			;@@ set-path! case
			if store [
				obj: entry/2
				either set-path? name [
					do reduce [to set-path! join-obj-stack to path! name obj] ;-- set object in shadow tree
				][
					unless tail? next obj-stack [		;-- set object in shadow tree (if sub-object)
						do reduce [to set-path! join-obj-stack name obj]
					]
				]
			]
		]
	]
	
	register-user-type: func [name [any-word! set-path!] spec [block!] /store /local found? types pos prev entry obj][
		found?: no
		types: spec
		
		forall types [
			if #"!" <> last mold types/1 [				;-- enforce trailing ! convention
				throw-error ["invalid type specified:" mold spec]
			]
			if pos: find/skip objects types/1 6 [
				if found? [throw-error ["unsupported multiple object type spec:" mold spec]]
				if prev: find get-obj-base name name [prev/1: none] ;-- unbind word with previous object

				insert entry: tail objects copy/part pos 6
				entry/1: to word! name			;@@ set-path! case
				types/1: 'object!
				
				if store [
					obj: entry/2
					either set-path? name [
						do reduce [to set-path! join-obj-stack to path! name obj] ;-- set object in shadow tree
					][
						unless tail? next obj-stack [		;-- set object in shadow tree (if sub-object)
							do reduce [to set-path! join-obj-stack name obj]
						]
					]
				]
				found?: yes
			]
		]
	]
	
	preprocess-types: func [name spec [block!] /local pos][
		parse spec [
			any [pos: word! block! (register-user-type pos/1 pos/2) | skip]
		]
	]
	
	comp-bodies: has [pos][
		obj-stack: to path! 'func-objs
		pos: tail objects
		
		foreach [name spec body func-symbols locals-nb stack ssa ctx obj?] bodies [
			locals-stack: stack
			ssa-names: ssa
			ctx-stack: ctx
			container-obj?: obj?
			func-objs: tail objects
			depth: max-depth
			preprocess-types name spec

			comp-func-body name spec body copy func-symbols locals-nb ;-- copy avoids function symbols corruption by decoration
		]
		clear pos
		clear locals-stack
		clear ssa-names
		func-objs: none
	]
	
	comp-init: does [
		compiler-redbin-emitter/init
		add-symbol 'datatype!
		add-global 'datatype!
		foreach [name specs] functions [
			add-symbol name
			add-global name
		]

		;-- Create datatype! datatype and word
		emit compose [
			stack/mark-native ~set
			word/push (decorate-symbol 'datatype!)
			datatype/push TYPE_DATATYPE
			word/set
			stack/unwind
			stack/reset
		]
	]
	
	comp-finish: does [
		compiler-redbin-emitter/finish pick [[compress] []] to logic! all [
			job/redbin-compress?
			compiler-crush/available?
		]
	]
	
	comp-source: func [code [block!] /local user main saved mods][
		output: make block! 10000
		comp-init
		
		pc: next compiler-preprocessor/expand/clean load-source/hidden %compiler/bootstrap-boot.red job
		unless job/red-help? [clear-docstrings pc]
		booting?: yes
		comp-block
		append output boot-extras
		booting?: no
		
		mods: tail output
		append output [#user-code]
		foreach module needed [
			saved: if script-path [copy script-path]
			saved-main: if main-path [copy main-path]
			saved-include-stk: copy include-stk
			saved-script-stk: copy script-stk
			script-path: first split-path module
			pc: next compiler-preprocessor/expand load-source/hidden module job
			unless job/red-help? [clear-docstrings pc]
			comp-block
			script-path: saved
			main-path: saved-main
			include-stk: saved-include-stk
			script-stk: saved-script-stk
		]

		store-header code/1
		pc: code										;-- compile user code
		user: tail output
		comp-block
		append output [#user-code]
		
		main: output
		output: make block! 1000
		
		comp-bodies										;-- compile deferred functions
		comp-finish
		;libRedRT/save-extras
		
		reduce [user mods main]
	]
	
	comp-as-lib: func [code [block!] /local user main mark defs pos ext-ctx slots][
		out: copy/deep [
			Red/System [
				type:   'dll
				origin: 'Red
			]
			
			***-root-size: <root-size>
			with red [
				exec: context [
					<declarations>
					<script>
				]
			]
		]
		
		set [user mark main] comp-source code

		defs: make block! 10'000
		foreach [type cast][
			block	red-block!
			string	red-string!
			context node-handle!
			typeset	red-typeset!
			][
				foreach name lit-vars/:type [
					either type = 'context [
						repend defs [to set-word! name 'declare cast to set-word! name 0]
						new-line skip tail defs -5 on
					][
						repend defs [to set-word! name 'as cast 0]
						new-line skip tail defs -4 on
					]
				]
		]
		foreach [name spec] symbols [
			repend defs [to set-word! spec/1 'as 'red-word! 0]
			new-line skip tail defs -4 on
		]
		
		append defs [
			obj: as red-object! 0
			------------| "Declarations"
		]
		append defs declarations
		pos: tail defs
		append defs [
			------------| "Functions"
		]
		append defs output
;		if verbose = 2 [probe pos]
		
		script: make block! 10'000
		append script [
			------------| "Symbols"
		]
		append script sym-table
		append script [
			------------| "Literals"
		]
		append script literals
		append script [
			red/boot?: no
			red/collector/active?: yes
			------------| "Main program"
		]
		append script main
;		if find [1 2] verbose [probe user]
		
		unless empty? sys-global [
			process-calls/global sys-global				;-- lazy #call processing
		]
		slots: compiler-redbin-emitter/index + 3000 + root-slots
		if job/dev-mode? [slots: slots + 100'000]		;-- Cannot know how many slots will be needed by the app
		change/only find out <root-size> slots
		
		pos: third last out
		change find pos <script> script
		remove pos: find pos <declarations>
		insert pos defs
		
		output: out	
		if verbose > 2 [?? output]
	]
	
	comp-as-exe: func [code [block!] /local out user mods main defs][
		out: copy/deep either job/dev-mode? [[
			Red/System [origin: 'Red]

			<imports>
			***-root-size: <root-size>

			with red [
				stk-bottom: system/stack/top			;-- reset stk-bottom set by libRedRT to allow GC to mark all pointers on stack
				root-base: redbin/boot-load system/boot-data yes
				exec: context <script>
			]
		]][[
			Red/System [origin: 'Red]

			***-root-size: <root-size>
			red/init
			
			with red [
				exec: context <script>
			]
		]]
		
		if all [job/dev-mode? not job/libRedRT?][
			replace out <imports> libRedRT/get-include-file job
		]
		set [user mods main] comp-source code
		
		;-- assemble all parts together in right order
		script: make block! 100'000
		
		if job/dev-mode? [append script [red/boot?: yes]] ;-- boot mode was reset by libRedRT
		
		append script [
			------------| "Symbols"
		]
		append script sym-table
		append script [
			------------| "Literals"
		]
		append script literals
		append script [
			------------| "Declarations"
		]
		append script declarations
		pos: tail script
		
		append script [
			red/boot?: no
			------------| "Functions"
		]
		append script output
		if verbose = 2 [probe pos]
		
		unless job/dev-mode? [append script [red/collector/active?: yes]]
		append script [
			------------| "Main program"
		]
		append script main
		if find [1 2] verbose [probe user]
		
		unless empty? sys-global [
			process-calls/global sys-global				;-- lazy #call processing
		]

		change/only find out <root-size> compiler-redbin-emitter/index + 3000 + root-slots
		change/only find last out <script> script		;-- inject compilation result in template
		output: out
		if verbose > 2 [?? output]
	]
	
	clear-docstrings: func [script [block!] /local clean rule pos][
		clean: [any [pos: string! (remove pos) | skip]]
		
		parse script rule: [
			some [
				['action! | 'native!] into [into clean]
				| ['func | 'function | 'routine] into clean
				| pos: [block! | paren!] :pos into rule
				| skip
			]
		]
	]
	
	load-source: func [file [file! block!] /hidden /header /local src][
		either file? file [
			unless hidden [script-name: file]
			src: lexer/process/file read/binary file file
			if all [
				(length? src) >= 4
				src/1 = 'REBOL
				block? src/2
				src/3 = 'Red
				block? src/4
			][src: skip src 2]						;-- canonical dual-host source
			unless all [src src/1 = 'Red block? src/2][
				throw-error ["invalid Red source header:" file]
			]
			src: next src
		][
			unless hidden [script-name: 'in-memory]
			src: file
		]
		src
	]
	
	process-currencies: func [header [block!] /local spec c][
		if block? spec: select header quote Currencies: [
			foreach c spec [
				if any [not word? c 3 <> length? form c][
					throw-error ["invalid header currencies field:" spec]
				]
				append boot-extras compose [
					block/rs-append 
						as red-block! #get system/locale/currencies/list
						as red-value! word/load (uppercase mold c)
				]
			]
			currencies: copy spec
		]
	]
	
	process-config: func [header [block!] /local spec][
		if spec: select header quote config: [
			do bind spec job
			if job/command-line [do bind job/command-line job]		;-- ensures cmd-line options have priority
		]
		if all [job/type = 'dll job/OS <> 'Windows][job/PIC?: yes]	;-- ensure PIC mode is enabled
	]
	
	process-needs: func [header [block!] src [block!] /local list file mods][
		either all [
			list: select header first [Needs:]
			find [word! lit-word! block!] type?/word list	;-- do not process other types
		][
			unless block? list [list: reduce [list]]
			forall list [if error? try [list/1: to-word list/1][throw-error ["invalid module name:" list/1]]]
			
			job/modules: list
			mods: make block! 2
			
			foreach mod list [
				file: find standard-modules mod
				unless file [
					throw-error ["module not found:" mod]
				]
				all [
					any [file/3 = 'all find file/3 job/OS]
					not find needed file/2
					append needed file/2
				]
			]
		][
			job/modules: make block! 0
		]
		if all [
			job/OS = 'Windows
			job/sub-system = 'GUI
			not find job/modules 'View
		][
			throw-error "Windows target requires View module (`Needs: View` in the header)"
		]
	]
	
	process-fields: func [header [block!] src [block!]][
		process-needs header src
		process-currencies header
	]
	
	; Re-apply expression field inits. Stage0 can compile large context field
	; expressions incorrectly (none), which breaks #get-definition matching and
	; forces full make action!/native! emission instead of redbin natives.
	ensure-host-fields: does [
		include-directive: to issue! "include"
		get-definition-directive: to issue! "get-definition"
		return-def: to-set-word 'return
		actions-prefix: to path! 'actions
		natives-prefix: to path! 'natives
		unless path? :obj-stack [obj-stack: to path! 'objects]
		unless object? :lexer [lexer: compiler-lexer]
		unless object? :extracts [extracts: compiler-extractor]
		unless object? :redbin [redbin: compiler-redbin-emitter]
		unless object? :preprocessor [preprocessor: compiler-preprocessor]
		unless object? :bindings [bindings: compiler-bindings]
		unless block? :lit-vars [
			lit-vars: reduce [
				'block make hash! 1000
				'string make hash! 1000
				'context make hash! 1000
				'typeset make hash! 100
			]
		]
		; binding-of 'rebol may be none in pure Red host; keep a stable sentinel.
		unless object? :rebol-gctx [
			rebol-gctx: any [binding-of 'rebol binding-of 'system none]
		]
	]

	clean-up: does [
		ensure-host-fields
		bindings/reset
		clear include-stk
		clear included-list
		clear script-stk
		clear needed
		clear symbols
		clear aliases
		clear globals
		clear sys-global
		clear contexts
		clear ctx-stack
		clear objects
		obj-stack: to path! 'objects					;-- reset it to original value
		clear frame-stack
		clear paths-stack
		clear locals-stack
		clear output
		clear sym-table
		clear literals
		clear declarations
		clear boot-extras
		clear bodies
		clear actions
		clear op-actions
		clear keywords
		clear skip functions 2							;-- keep MAKE definition
		clear lit-vars/block
		clear lit-vars/string
		clear lit-vars/context
		clear lit-vars/typeset
		clear types-cache
		clear shadow-funcs
		clear native-ts
		s-counter: 0
		depth:	   0
		max-depth: 0
		root-slots:	  0
		compiler-redbin-emitter/index: 0									;-- required here by libRedRT
		container-obj?:
		script-path:
		script-file:
		main-path: 
		currencies: none
	]

	compile: func [
		file [file! block!]								;-- source file or block of code
		opts [object!]
		/local time src resources defs
	][
		verbose: opts/verbosity
		job: opts
		clean-up
		main-path: first split-path any [all [block? file system/options/path] file]
		resources: make block! 8

		time: now/time/precise
		src: load-source file
			job/red-pass?: yes
			process-config src/1
			src: compiler-preprocessor/expand/clean src job
			if job/show = 'expanded [probe next src]	;-- show postprocessed source file
			process-fields src/1 next src
			extracts/init job
			if job/libRedRT? [libRedRT/init]
			if file? file [system-dialect/collect-resources src/1 resources file]
			
			if all [job/dev-mode? not job/libRedRT?][
				defs: libRedRT/get-definitions
				append clear functions defs/1
				;compiler-redbin-emitter/index:	defs/2
				globals:		defs/3
				objects:		compose/deep bind objects: defs/4 red
				contexts:		defs/5
				actions:		defs/6
				op-actions:		defs/7
				foreach w defs/8 [add-symbol w]
				append literals defs/9
				s-counter:		defs/10
				needed: 		exclude needed defs/11	;-- exclude already compiled modules
				shadow-funcs:	defs/12
				bindings/rebuild-shadows shadow-funcs
				make-keywords
			]
			print [
				"...GUI backend      :" either find job/modules 'View [job/GUI-engine][#"-"] nl
				"...Modules          :" either empty? job/modules [#"-"][mold/only job/modules]
			]
			either job/type = 'dll [comp-as-lib src][comp-as-exe src]
		time: now/time/precise - time
		reduce [output time compiler-redbin-emitter/buffer resources]
	]

]

compiler-frontend: red
compiler-redbin-emitter/frontend: red
compiler-redbin-emitter/front-encode-date: :red/encode-date
compiler-redbin-emitter/front-encode-UTC-time: :red/encode-UTC-time
compiler-redbin-emitter/front-to-nibbles: :red/to-nibbles
compiler-redbin-emitter/front-to-currency-code: :red/to-currency-code
compiler-redbin-emitter/front-get-RS-type-ID: :red/get-RS-type-ID
compiler-redbin-emitter/front-local-word?: :red/local-word?
compiler-redbin-emitter/front-get-word-index: :red/get-word-index
compiler-redbin-emitter/front-find-binding: :red/find-binding
