Red [
	Title:   "Red/System compiler source loader"
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2024 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

compiler-system-loader: context [
	verbose: 	  0
	include-list: make hash! 20
	macros:		  make map! 100
	definitions:  make hash! 100
	keywords-list: make block! 0
	job:          none
	last-error:   none
	root-path:    none

	connect-compiler-state: func [
		compiler-definitions [block! hash!]
		compiler-keywords [block!]
	][
		definitions: compiler-definitions
		keywords-list: compiler-keywords
	]

	hex-chars: 	  charset "0123456789ABCDEF"
	ws-chars: 	  charset " ^M^-"
	ws-all:		  union ws-chars charset "^/"
	hex-delim: 	  charset "[]()/"
	non-cbracket: complement charset "}^/"

	scripts-stk:  make block! 10
	current-script: none
	line: none

	throw-error: func [err [string! block!] /local record][
		record: make object! [
			message: none
			file: none
			line: none
		]
		record/message: form either block? err [reduce err][err]
		record/file: current-script
		record/line: line
		last-error: record
		throw/name record 'system-loader-error
	]

	init: does [
		root-path: copy system/options/path
		clear include-list
		clear macros
		clear scripts-stk
		clear definitions
		last-error: none
		current-script: line: none
	]

	relative-path?: func [file [file!]][
		not find "/~" first file
	]

	resolve-file: func [file [file!] /local base spelling][
		spelling: to string! file
		unless any [
			all [not empty? spelling spelling/1 = #"/"]
			all [(length? spelling) >= 2 spelling/2 = #":"]
		][
			base: either file? current-script [first split-path current-script][root-path]
			file: to file! rejoin [base file]
		]
		clean-path/only file
	]

	included?: func [file [file!] /local key][
		key: to string! clean-path file
		if system/platform = 'Windows [lowercase key]
		either find include-list key [true][
			append include-list key
			false
		]
	]

	check-macro-parameters: func [args [paren!]][
		unless parse args [some word!][
			throw-error ["only words can be used as macro parameters:" mold args]
		]
		unless empty? intersect to block! args keywords-list [
			throw-error ["keywords cannot be used as macro parameters:" mold args]
		]
	]

	check-marker: func [src [binary! string!] /local pos][
		unless parse/case src [any ws-all "Red/System" any ws-all #"[" to end][
			throw-error "not a Red/System source program"
		]
	]

	check-condition: func [type [word!] payload [block!]][
		case [
			type = 'switch [
				any [
					select payload/2 job/(payload/1)
					select payload/2 #default
				]
			]
			payload/2 = 'contains [
				do bind/copy 
					compose/deep [all [(payload/1) find (payload/1) (payload/3)]]
					job
			]
			'else [do bind/copy payload job]
		]
	]
	
	copy-deep: func [s [series!]][
		s: copy/deep :s
		forall s [
			case [
				find [path! set-path! lit-path!] type?/word s/1 [
					s/1: copy/deep s/1
				]
				any [block? s/1 paren? s/1][
					s/1: copy-deep s/1
				]
			]
		]
		:s
	]

	inject: func [
		args [block!]
		macro [block! paren!]
		s [block! paren!]
		e [block! paren!]
		/local rule pos i type value path nested
	][
		unless equal? length? args length? s/2 [
			throw-error ["invalid macro arguments count in:" mold s/2]
		]	
	 	macro: copy-deep :macro
		parse :macro rule: [
			while [
				pos: set path [path! | get-path! | set-path!] (
					forall path [
						if i: find args path/1 [
							value: pick s/2 index? :i
							change/part :path :value 1
						]
					]
				)
				| pos: [
					word! 		(type: word!) 
					| set-word! (type: set-word!)
					| get-word! (type: get-word!)
				] (
					if i: find args to word! pos/1 [
						value: pick s/2 index? :i
						change/only pos either type = word! [
							value						;-- word! => pass-thru value
						][
							all [
								path: find [path! get-path! set-path!] type?/word :value
								type: find [word! get-word! set-word!] to word! type
								type: get pick head path index? type
							]
							to type :value				;-- get/set => convert value
						]
					]
				)
				| nested: [block! | paren!] :nested into rule
				| skip
			]
		]
		either paren? :macro [
			change/part/only s :macro e
		][
			change/part s :macro e
		]
	]

	expand-definition: func [
		position [series!]
		/local definition args value end
	][
		unless definition: select macros position/1 [return next position]
		args: definition/2
		value: definition/3
		if block? args [
			unless all [not tail? next position paren? position/2][
				position/1: definition/1
				return next position
			]
			end: skip position 2
			inject args value position end
			return position
		]
		end: next position
		either block? value [
			change/part position copy-deep value end
		][
			change/part position :value end
		]
		position
	]

	expand-string: func [src [string! binary!] /local lf-count ws i prev ins?][
		if verbose > 0 [print "running string preprocessor..."]

		line: 1										;-- lines counter
		lf-count: [lf s: (
			if prev <> i: index? s [				;-- workaround to avoid writing more complex rules
				prev: i
				line: line + 1
				if ins? [s: insert s rejoin [" #L " line " "]]
			]
		)] 
		ws:	[ws-chars | (ins?: yes) lf-count]
		braces: ["{" any [(ins?: no) lf-count | non-cbracket] "}"]

		parse/case src [							;-- insert line number
			any [
				#";" to lf
				| {#"^^} skip thru {"}
				| {"} thru {"}
				| "{" any [(ins?: no) lf-count | braces | non-cbracket] "}"
				| (ins?: yes) lf-count
				| skip
			]
		]
	]

	expand-block: func [
		src [block!]
		/own
		/local blk macro-rule name value args s e opr then-block else-block cases body p
			saved stack header mark idx prev enum-value enum-name enum-names line-rule
			definition recurse condition nested
	][
		#process off
		if verbose > 0 [print "running block preprocessor..."]
		stack: append/only clear [] make block! 100
		append stack/1 1							;-- insert root header starting size
		line: 1

		store-line: [			
			header: last stack				
			idx: index? s
			mark: to pair! reduce [line idx]
			either all [
				prev: pick tail header -1
				pair? prev
				prev/2 = idx 						;-- test if previous marker is at the same series position
			][
				change back tail header mark		;-- replace last marker by a more accurate one
			][			
				append header mark					;-- append line marker to header
			]
		]
		line-rule: [
			s: #L set line integer! e: (
				s: remove/part s 2
				new-line s yes
				do store-line
			) :s
		]
		definition: [
			s: word! (s: expand-definition s) :s
		]
		recurse: [
			saved: reduce [s e]
			parse/case value macro-rule: [
				some [
					definition
					| nested: [block! | paren!] :nested into macro-rule
					| p: [path! | get-path! | set-path!] :p into [some [definition | skip]]
					| skip
				]								;-- resolve macros recursively
			]
			set [s e] saved
		]
		condition: [
			opt 'not ['find block! skip | ['any | 'all] block!]
			| set name word! set opr skip set value any-type!
		]
		
		parse/case src blk: [
			s: (do store-line)
			while [
				definition							;-- resolve definitions in a single pass
				| s: #define set name word! (args: none) [
					set args paren! set value [block! | paren!]
					| set value skip
				  ] e: (
				  ;probe "define......................"
				  	if paren? args [check-macro-parameters args]
					if verbose > 0 [print [mold name #":" mold value]]
					if find definitions name [
						print ["*** Warning:" name "macro in R/S is redefined"]
					]
					if any [block? value paren? value][do recurse]
					unless select macros name [
						append definitions name
						args: either paren? args [to block! args][none]
						put macros name reduce [name args :value]
					]
					remove/part s e
				) :s
				| s: #enum word! set value skip e: (
					either block? value [
						saved: reduce [s e]
						parse value [
							any [
								any line-rule [
									[word! | some [set-word! any line-rule][integer! | word!]]
									| skip
								]
							]
						]
						set [s e] saved
					][
						throw-error ["invalid enumeration (block required!):" mold value]
					]
					s: e
				) :s
				| s: #include set name file! e: (
					name: resolve-file name
					either included? name [
						s: remove/part s e			;-- already included, drop it
					][
						if verbose > 0 [print ["...including file:" mold name]]
						value: process-source name none true true
						e: change/part s skip value 2 e	;-- skip Red/System header
						
						insert e reduce [
							#pop-path 0
							#script last scripts-stk	;-- put back the parent origin
						]
						insert s reduce [				;-- mark code origin
							#script name
						]
						append scripts-stk name
						current-script: name
					]
				) :s
				| s: #if condition set then-block block! e: (
					either check-condition 'if copy/part next s back e [
						change/part s then-block e
					][
						remove/part s e
					]
				) :s
				| s: #either condition set then-block block! set else-block block! e: (
					either check-condition 'either copy/part next s skip e -2 [
						change/part s then-block e
					][
						change/part s else-block e
					]
				) :s
				| s: #switch set name word! set cases block! e: (
					either body: check-condition 'switch reduce [name cases][
						change/part s body e
					][
						remove/part s e
					]
				) :s
				| s: #case set cases block! e: (
					either body: select reduce bind cases job true [
						change/part s body e
					][
						remove/part s e
					]
				) :s
				| s: #pop-path set value integer! e: (
					take/last scripts-stk
					current-script: any [last scripts-stk current-script]
					s: remove/part s 2
				) :s
				| line-rule
				| s: issue! (
					value: to string! s/1
					if value/1 = #"'" [
						value: to integer! debase/base next value 16
						either value > 255 [
							throw-error ["unsupported literal byte:" next s/1]
						][
							s/1: to char! value
						]
					]
				)
				| p: [path! | get-path! | set-path!] :p into [some [definition | skip]] ;-- process macros in paths
				
				| s: (if any [block? s/1 paren? s/1][append/only stack copy [1]])
				  p: [block! | paren!] :p into blk
				  s: (
					if any [block? s/-1 paren? s/-1][
						header: last stack
						change header length? header	;-- update header size
						s/-1: insert copy s/-1 header		;-- insert hidden header
						remove back tail stack
					]
				  )
				| skip
			]
		]
		#process on
		change stack/1 length? stack/1				;-- update root header size	
		insert src stack/1						;-- return source with hidden root header
	]

	process-source: func [
		input [file! string! binary! block!]
		name [file! none!]
		short? [logic!]
		sub? [logic!]
		/local src path source-name err
	][
		path: none
		source-name: any [name 'in-memory]
		if file? input [
			path: resolve-file input
			source-name: path
			if error? set/any 'err try [src: read/binary path][
				throw-error ["file access error:" mold path]
			]
			check-marker src
		]
		if verbose > 0 [print ["processing" mold source-name]]
		unless short? [
			current-script: source-name
			append clear scripts-stk current-script
		]
		src: any [src input]
		unless block? src [
			expand-string src
			src: either file? source-name [
				compiler-system-source/process/file src source-name
			][
				compiler-system-source/process src
			]
			if compiler-system-source/last-error [
				throw-error [
					"syntax error during TRANSCODE phase:"
					mold compiler-system-source/last-error
				]
			]
		]
		unless short? [src: expand-block src]
		src
	]

	process: func [
		input [file! string! binary! block!]
		/sub
		/with name [file!]
		/short
		/own
		/local result
	][
		unless sub [current-script: none]
		result: catch/name [
			process-source input either with [name][none] to logic! short to logic! sub
		] 'system-loader-error
		either same? result last-error [none][result]
	]
]
