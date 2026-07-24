Red [
	Title: "Red compiler transcode adapter"
	File:  %compiler/lexer.red
]

; TRANSCODE is Red's supported UTF-8 scanner. Keeping this adapter in the
; compiler gives later phases a stable token/location contract without
; duplicating the language grammar or invoking LOAD.
compiler-lexer: context [
	source: make binary! 0
	source-file: none
	values: make block! 0
	tokens: make block! 256
	trace-data: make block! 1536
	line-starts: make block! 64
	last-error: none
	decoded: none
	token-prototype: object [
		kind: none
		type: none
		value: none
		line: 1
		column: 1
		start: 0
		end: 0
		raw: none
		newline?: false
	]

	pending-type: none
	pending-start: 0
	pending-end: 0
	pending-line: 1
	prescan-start: 0
	prescan-end: 0
	prescan-line: 1
	previous-line: 1

	make-token: func [
		kind [word!]
		type [word! datatype!]
		value
		token-line [integer!]
		start [integer!]
		finish [integer!]
		/local line-start record
	][
		line-start: any [pick line-starts token-line 1]
		record: make token-prototype []
		record/kind: kind
		record/type: either datatype? type [to word! type][type]
		set/any in record 'value :value
		record/line: token-line
		record/column: (start - line-start) + 1
		record/start: start
		record/end: finish
		record/raw: either all [start > 0 finish >= start][
			copy/part at source start finish - start
		][none]
		record/newline?: token-line > previous-line
		record
	]

	append-token: func [
		kind [word!]
		type [word! datatype!]
		value
		token-line [integer!]
		start [integer!]
		finish [integer!]
		/local record
	][
		record: make-token kind type :value token-line start finish
		append/only tokens record
		previous-line: token-line
		record
	]

	append-trace: func [
		kind [word!]
		type [word! datatype!]
		value
		token-line [integer!]
		start [integer!]
		finish [integer!]
	][
		append trace-data kind
		append trace-data type
		append/only trace-data :value
		append trace-data token-line
		append trace-data start
		append trace-data finish
	]

	structural-kind: func [event [word!] type [word! datatype!] /local name][
		name: either datatype? type [to word! type][type]
		to word! rejoin [event #"-" name]
	]

	trace-event: func [
		event [word!]
		input [binary! string!]
		type [word! datatype!]
		token-line [integer!]
		token
		return: [logic!]
		/local start finish
	][
		switch/default event [
			prescan [
				prescan-line: token-line
				either pair? token [
					prescan-start: token/x
					prescan-end: token/y
				][
					prescan-start: prescan-end: 0
				]
			]
			scan [
				pending-type: type
				pending-line: token-line
				either pair? token [
					pending-start: token/x
					pending-end: token/y
				][
					pending-start: pending-end: 0
				]
			]
			load [
				append-trace 'value pending-type :token pending-line pending-start pending-end
			]
			open [
				start: either pair? token [token/x][0]
				append-trace 'open type type token-line start start
			]
			close [
				start: either pair? token [token/y][0]
				finish: either zero? start [0][start + 1]
				append-trace 'close type type token-line start finish
			]
			error [
				append-trace 'error type :token prescan-line prescan-start prescan-end
			]
		][
			; PRESCAN is useful to TRANSCODE internally, but SCAN/LOAD and
			; OPEN/CLOSE contain the stable compiler-facing information.
		]
		true
	]

	materialize-tokens: func [
		/local position kind type value token-line start finish
	][
		position: trace-data
		while [not tail? position][
			kind: position/1
			type: position/2
			set/any 'value position/3
			token-line: position/4
			start: position/5
			finish: position/6
			if find [open close] kind [kind: structural-kind kind type]
			append-token kind type :value token-line start finish
			position: skip position 6
		]
	]

	index-lines: does [
		clear line-starts
		append line-starts 1
		repeat index length? source [
			if source/:index = 10 [append line-starts index + 1]
		]
	]

	reset: func [input [binary! string!] /file file-name [file! string! none!]][
		source: either binary? input [copy input][to binary! input]
		source-file: either file [file-name][none]
		; Do not clear buffers returned by an earlier call; compiler phases may
		; retain them while scanning an include or a diagnostic fragment.
		values: make block! 0
		tokens: make block! 256
		; Six values are retained per compiler-facing token. Reserve against the
		; input size so the trace callback does not need to grow this series.
		trace-data: make block! max 1536 ((length? source) * 2)
		last-error: none
		pending-type: none
		pending-start: pending-end: 0
		pending-line: previous-line: 1
		prescan-start: prescan-end: 0
		prescan-line: 1
		index-lines
	]

	decode: does [
		set/any 'decoded try [transcode/trace source :trace-event]
		materialize-tokens
		either error? :decoded [
			last-error: :decoded
			none
		][
			values: :decoded
		]
	]

	tokenize: func [
		input [binary! string!]
		/file file-name [file! string! none!]
	][
		either file [reset/file input file-name][reset input]
		decode
		tokens
	]

	process: func [
		input [binary! string!]
		/file file-name [file! string! none!]
	][
		either file [reset/file input file-name][reset input]
		decode
	]

	next-value: func [
		input [binary! string!]
		/local result
	][
		set/any 'result try [transcode/next input]
		either error? :result [
			last-error: :result
			none
		][
			result
		]
	]

	scan-type: func [input [binary! string!] /local result][
		set/any 'result try [transcode/scan input]
		either error? :result [
			last-error: :result
			none
		][
			result
		]
	]

	prescan-type: func [input [binary! string!] /local result][
		set/any 'result try [transcode/prescan input]
		either error? :result [
			last-error: :result
			none
		][
			result
		]
	]
]
