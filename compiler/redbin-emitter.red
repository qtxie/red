Red [
	Title:   "Redbin format encoder for Red compiler"
	Author:  "Nenad Rakocevic"
	File: 	 %compiler/redbin-emitter.red
	Tabs:	 4
	Rights:  "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

compiler-redbin-emitter: context [
	frontend: none
	; Standalone date helpers (same reason as money: avoid relying on front-* rebinding).
	front-encode-UTC-time: func [time [time! none!] zone [time! none!]][
		to float! either time [either zone [time - zone][time]][0.0]
	]
	front-encode-date: func [value [date!] /with zone /local date][
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
	; Standalone money helpers: Stage1 object-field rebinding of front-* can leave
	; the empty stubs in place, so keep real implementations here.
	front-to-currency-code: func [code [string!] /local pos extra][
		code: to word! code
		case [
			pos: find compiler-extractor/currencies code [index? pos]
			all [
				object? frontend
				extra: in frontend 'currencies
				block? get extra
				pos: find get extra code
			][(index? pos) + length? compiler-extractor/currencies]
			code = '... [0]
			'else [
				print ["*** Syntax Error: unknown money! currency" code]
				0
			]
		]
	]
	front-to-nibbles: func [
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
				front-to-currency-code code
				front-to-nibbles digits
			]
		]
		out: make binary! 11
		foreach [high low] src [
			append out add
				shift/left (to integer! high - #"0") 4
				to integer! low - #"0"
		]
		out
	]
	front-get-RS-type-ID: func [name [word! datatype!] /word /local type spelling][
		; Standalone implementation so Stage1 works even if frontend binding fails.
		spelling: either datatype? name [form name][
			head remove back tail form name
		]
		replace/all spelling #"-" #"_"
		type: to word! uppercase head insert spelling "TYPE_"
		either word [type][
			any [
				select compiler-extractor/definitions type
				0
			]
		]
	]
	front-local-word?: func [name [word!]][false]
	front-get-word-index: func [name [word!] /with context [word!]][none]
	front-find-binding: func [word [any-word!]][none]

	header:		make binary! 10'000
	buffer:		make binary! 200'000
	sym-string:	make binary! 10'000
	sym-offsets: make block!  1'000						;-- byte offset of each symbol in sym-string
	symbols:	make hash! 	 1'000						;-- symbol spellings
	contexts:	make hash!	 1'000						;-- [name [symbols] index ...]
	index:		0
	last-index:	-1								;-- last emit-block/context return (Stage1-safe)
	word-index:	-1								;-- last emit-word/root return (Stage1-safe)
	string-index:	-1							;-- last emit-string/root return (Stage1-safe)
	typeset-index:	-1							;-- last emit-typeset/root return (Stage1-safe)
	pending-with-ctx: none						;-- Stage1-safe substitute for /with
	pending-sub?: no							;-- Stage1-safe substitute for /sub
	pending-root?: no							;-- Stage1-safe substitute for /root
	pending-set?: no							;-- Stage1-safe substitute for /set?
	pending-action?: no						;-- Stage1-safe substitute for /action
	
	stats:		make block! 100
	profile?:	no
	debug?:		no
	
	chars: 		make block!  10'000
	decoded: 	make binary! 10'000
	nl?:		no

	CP_MODIFIER: 64										;-- compact tag space (see runtime/redbin.reds)
	CP_INT0:	 128									;-- 80h-BFh integer! immediates 0-63
	CP_NL:		 192									;-- C0h new-line marker
	CP_TRUE:	 194									;-- C2h
	CP_FALSE:	 195									;-- C3h
	CP_GSET:	 196									;-- C4h global-set word marker

	profile: func [blk /local pos][
		foreach item blk [
			unless pos: find/skip stats type? :item 2 [
				repend stats [type? :item 0]
				pos: skip tail stats -2
			]
			pos/2: pos/2 + 1

		]
	]
	
	get-index: does [index - 1]
	get-definition-directive: to issue! "get-definition"
	
	preprocess-directives: func [blk][
		forall blk [
			if blk/1 = get-definition-directive [		;-- temporary directive
				value: select compiler-extractor/definitions blk/2
				change/only/part blk value 2
			]
		]
	]
	
	decode-UTF8: func [str [string! file! url! tag! email!] /local text upper cp unit new][
		text: to string! str
		upper: 0
		clear chars
		foreach cp text [
			cp: to integer! cp
			append chars cp
			upper: max upper cp
		]
		if upper < 128 [								;-- shortcut for ASCII strings
			clear chars
			return reduce [text 1]
		]
		new: clear decoded
		
		unit: either upper < 65536 [
			foreach cp chars [append new int-to-bin/to-bin16 cp]
			2
		][
			foreach cp chars [append new int-to-bin/to-bin32 cp]
			4
		]
		clear chars
		reduce [new unit]
	]
	
	to-varint: func [n [number!] /local out g done?][	;-- LEB128, 32-bit unsigned in decimal domain
		if n < 0 [n: 4294967296.0 + n]
		out: make binary! 5
		until [
			g: to integer! n // 128
			n: (n - (n // 128)) / 128
			done?: zero? n
			append out g + pick [0 128] done?
			done?
		]
		out
	]

	emit-byte: func [b [integer!]][append buffer b]
	
	emit-varint: func [n [number!]][append buffer to-varint n]

	emit-svarint: func [n [number!]][					;-- zigzag-mapped signed varint
		emit-varint either n < 0 [-2.0 * n - 1][2.0 * n]
	]
	
	emit-tag: func [type [word!] /mod /local b][
		if nl? [emit-byte CP_NL nl?: no]
		b: select compiler-extractor/definitions type
		if mod [b: b or CP_MODIFIER]
		emit-byte b
	]
	
	emit-u32-le: func [n [integer!]][append buffer int-to-bin/to-bin32 n]

	emit-float64-le: func [f [float! issue!]][
		append buffer either issue? f [ieee-754/to-binary64/rev f][reverse to binary! f]
	]
	
	same-float?: func [a [float!] b [float!]][
		(to binary! a) = (to binary! b)
	]
	
	emit-float32-le: func [f [float! issue!]][
		append buffer ieee-754/to-binary32/rev f
	]

	emit-unset: does [emit-tag 'TYPE_UNSET]

	emit-none: does [emit-tag 'TYPE_NONE]
	
	emit-datatype: func [type [datatype! word! integer!] /local name][
		either integer? type [
			emit-tag 'TYPE_DATATYPE
			emit-varint type
		][
			unless word? type [type: to word! mold type]
			emit-tag 'TYPE_DATATYPE
			emit-varint select compiler-extractor/definitions type
		]
	]
	
	emit-logic: func [value [logic!]][
		if nl? [emit-byte CP_NL nl?: no]
		emit-byte either value [CP_TRUE][CP_FALSE]
	]
	
	emit-float: func [value [float!] /with type /local i][
		either all [
			value >= -2147483000.0
			value <= 2147483000.0
			same-float? value to float! i: to integer! value	;-- exact whole number (also rejects -0.0)
		][
			emit-tag/mod any [type 'TYPE_FLOAT]			;-- whole-number short form
			emit-svarint i
		][
			emit-tag any [type 'TYPE_FLOAT]
			emit-float64-le value
		]
	]
	
	emit-fp-special: func [value [float! issue!]][
		emit-tag 'TYPE_FLOAT
		emit-float64-le either float? value [value][to float! form value]
	]

	emit-percent: func [value [percent! issue!] /local d k text][
		d: either percent? value [to float! value][
			text: form value
			to float! append copy/part text back tail text "e-2"	;-- (#5753)
		]
		k: 0
		either all [
			d >= -21474836.0
			d <= 21474836.0
			same-float? d ((to float! k: to integer! d * 100.0) / 100.0)	;-- exact round-trip only
		][
			emit-tag/mod 'TYPE_PERCENT					;-- hundredths short form
			emit-svarint k
		][
			emit-tag 'TYPE_PERCENT
			emit-float64-le d
		]
	]
	
	emit-time: func [value [time!] /local f i][
		f: to float! value
		either all [
			f >= -2147483000.0
			f <= 2147483000.0
			same-float? f to float! i: to integer! f	;-- exact whole seconds only
		][
			emit-tag/mod 'TYPE_TIME
			emit-svarint i
		][
			emit-tag 'TYPE_TIME
			emit-float64-le f
		]
	]
	
	emit-date: func [value [date!] /with zone][
		either value/time [
			emit-tag/mod 'TYPE_DATE
			emit-u32-le front-encode-date/with value zone
			emit-float64-le front-encode-UTC-time value/time any [zone value/zone]
		][
			emit-tag 'TYPE_DATE
			emit-u32-le front-encode-date/with value zone
		]
	]

	emit-char: func [value [integer!]][
		emit-tag 'TYPE_CHAR
		emit-varint value
	]
	
	emit-integer: func [value [integer!]][
		either all [value >= 0 value <= 63][
			if nl? [emit-byte CP_NL nl?: no]
			emit-byte CP_INT0 + value					;-- integer! immediate
		][
			emit-tag 'TYPE_INTEGER
			emit-svarint value
		]
	]

	emit-pair: func [value [pair!]][
		emit-tag 'TYPE_PAIR
		emit-svarint value/x
		emit-svarint value/y
	]
	
	emit-point: func [list [block!]][
		emit-tag select [2 TYPE_POINT2D 3 TYPE_POINT3D] length? list
		forall list [emit-float32-le either integer? list/1 [to float! list/1][list/1]]
	]

	emit-tuple: func [value [tuple! issue!] /local bin size][
		bin: either tuple? value [to binary! value][debase/base next form value 16]
		size: length? bin
		either size = 3 [
			emit-tag 'TYPE_TUPLE
		][
			emit-tag/mod 'TYPE_TUPLE
			emit-byte size
		]
		append buffer bin
	]
	
	emit-money: func [value [money! issue!] /local data][
		if money? value [
			data: front-to-nibbles value
			either data/1 [emit-tag/mod 'TYPE_MONEY][emit-tag 'TYPE_MONEY]
			append buffer data/2
			append buffer data/3
			exit
		]
		value: to string! next form value
		either value/4 = #"-" [
			emit-tag/mod 'TYPE_MONEY					;-- negative amount
		][
			emit-tag 'TYPE_MONEY
		]
		append buffer either value/1 = #"." [0][front-to-currency-code copy/part value 3]
		append buffer front-to-nibbles copy/part skip value 4 22		;-- nibbles array
	]
	
	emit-native: func [id [word!] spec [block!] /action /local native-id][
		if pending-action? [action: yes]
		native-id: select compiler-extractor/definitions id
		unless integer? native-id [
			print ["*** Compiler Internal Error: missing generated native ID:" id]
			halt
		]
		emit-tag pick [TYPE_ACTION TYPE_NATIVE] to logic! action
		emit-varint native-id
		pending-sub?: yes
		emit-block spec
		pending-sub?: no
	]
	
	emit-typeset: func [v1 [integer!] v2 [integer!] v3 [integer!] /root /local bin][
		;-- Typeset bits use network bit order within each 32-bit group.
		bin: rejoin [to-binary v1 to-binary v2 to-binary v3]
		while [all [not empty? bin zero? last bin]][clear back tail bin]		;-- trim trailing zero bytes
		emit-tag 'TYPE_TYPESET
		emit-byte length? bin
		append buffer bin
		
		if root [
			if debug? [print [index ": typeset"]]
			index: index + 1
			typeset-index: index - 1
		]
		index - 1
	]
	
	emit-string: func [str [any-string! binary! ref! issue!] /root /local type unit][
		type: either any [issue? str ref? str] ['TYPE_REF][	;-- internal encoding or native ref!
			select [
				string! TYPE_STRING
				file!	TYPE_FILE
				tag!	TYPE_TAG
				url!	TYPE_URL
				email!	TYPE_EMAIL
				binary! TYPE_BINARY
			] type?/word str
		]
		
		emit-tag type
		either type = 'TYPE_BINARY [						;-- binary payloads use a plain byte length
			emit-varint length? str
			append buffer str
		][													;-- any-string!: raw UCS-1/2/4, unit packed into length
			str: to string! str								;-- head is always zero (v1 boot payload)
			set [str unit] decode-UTF8 str
			emit-varint (length? str) / unit * 4 + select [1 0 2 1 4 2] unit
			append buffer str
		]

		if root [
			if debug? [print [index ": string :" copy/part str 40]]
			index: index + 1
			string-index: index - 1
		]
		index - 1
	]
	
	emit-issue: func [value [issue!]][
		emit-tag 'TYPE_ISSUE
		emit-symbol form value
	]
	
	emit-symbol: func [symbol /local pos s spelling][
		spelling: form symbol
		unless pos: find/case symbols spelling [
			s: tail sym-string
			append sym-offsets -1 + index? s			;-- byte offset of this symbol in sym-string
			append sym-string to binary! spelling
			append sym-string 0
			append symbols spelling
			pos: back tail symbols
		]
		emit-varint (index? pos) - 1					;-- emit index of symbol
	]
	
	emit-word: func [
		word ctx [word! none!] ctx-idx [integer! none!] /root /set?
		/local type entry pos ctx-field idx
	][
		if pending-root? [root: yes]
		if pending-set? [set?: yes]
		type: select [
			word!		TYPE_WORD
			set-word!	TYPE_SET_WORD
			get-word!	TYPE_GET_WORD
			refinement! TYPE_REFINEMENT
			lit-word!	TYPE_LIT_WORD
		] type?/word :word
		
		ctx-field: -1
		idx: -1
		if all [ctx entry: find contexts ctx][
			ctx-field: entry/3
			if pos: find entry/2 to word! word [
				idx: (index? pos) - 1
			]
		]
		; Prefer caller-provided field index (from emit-block /with lookup).
		if all [integer? ctx-idx ctx-idx >= 0][idx: ctx-idx]
		; If we have a context and field index, encode as context-bound even when
		; the word was not found by name lookup (Stage1 binding gaps).
		if all [ctx-field = -1 ctx integer? idx idx >= 0][
			if entry: find contexts ctx [ctx-field: entry/3]
		]

		if set? [emit-byte CP_GSET]						;-- global-set: value record follows
		either any [ctx-field = -1 none? idx idx < 0] [
			emit-tag type								;-- canonical form: global binding
			emit-symbol word
		][
			emit-tag/mod type
			emit-symbol word
			emit-varint ctx-field						;-- context record index among roots
			emit-svarint idx
		]
		if root [
			if debug? [print [index ": word :" mold word]]
			unless set? [index: index + 1]
			word-index: index - 1
		]
		index - 1
	]
	
	emit-block: func [
		blk [any-block! path! lit-path! get-path! set-path!] /with main-ctx [word!] /sub
		/local type item binding ctx idx emit? multi-line? ofs
	][
		; Merge refinement args with Stage1-safe pending fields (refinements on
		; object method paths can be dropped by the native compiler).
		unless with [
			if word? pending-with-ctx [
				with: yes
				main-ctx: pending-with-ctx
			]
		]
		if pending-sub? [sub: yes]
		if profile? [profile blk]
		
		type: case [
			get-path? :blk ['get-path]
			blk/1 = #!map! [
				remove blk
				'map
			]
			blk/1 = #!point! [
				emit-point next blk
				unless sub [index: index + 1]
				last-index: index - 1
				return last-index
			]
			blk/1 = #!date! [
				emit-date/with blk/2 blk/3
				unless sub [index: index + 1]
				last-index: index - 1
				return last-index
			]
			'else [type?/word :blk]
		]
		type: select [
			block!		TYPE_BLOCK
			paren!		TYPE_PAREN
			path!		TYPE_PATH
			lit-path!	TYPE_LIT_PATH
			set-path!	TYPE_SET_PATH
			get-path!	TYPE_GET_PATH
			get-path	TYPE_GET_PATH
			map			TYPE_MAP
		] type
		
		preprocess-directives blk
		ofs: (index? blk) - 1
		either any [type = 'TYPE_MAP zero? ofs][emit-tag type][
			emit-tag/mod type							;-- non-zero head
			emit-varint ofs
		]
		emit-varint length? blk
		if all [not sub debug?][
			print [index ": block" length? blk #":" trim/lines copy/part mold/flat blk 60]
		]
		nl?: no
		multi-line?: any [block? blk paren? blk]

		forall blk [
			if multi-line? [nl?: new-line? blk]
			item: blk/1
			either any-block? :item [
				either with [
					pending-with-ctx: main-ctx
					pending-sub?: yes
					emit-block :item
					pending-sub?: no
					pending-with-ctx: none
				][
					pending-sub?: yes
					emit-block :item
					pending-sub?: no
				]
			][
				emit?: case [
					issue? :item [emit-issue item no]
					any-word? :item [
						ctx: main-ctx
						idx: none
						value: :item
						; Prefer the /with object/function context word list. Do not rely
						; only on local-word? (function locals) or bind?/find-binding, which
						; have failed under compiled Stage1 for object field blocks.
						if all [with word? main-ctx][
							if entry: find contexts main-ctx [
								if pos: find entry/2 to word! :item [
									idx: (index? pos) - 1
								]
							]
						]
						if none? idx [
							either all [with front-local-word? to word! :item][
								idx: front-get-word-index/with to word! :item main-ctx
							][
								if binding: front-find-binding :item [
									set [ctx idx] binding
								]
							]
						]
						yes
					]
					'else [yes]
				]
				
				if emit? [
					switch type?/word get/any 'item [
						word!
						set-word!
						lit-word!
						refinement!
						get-word! [emit-word :item ctx idx]
						file!
						url!
						tag!
						email!
						string!
						binary!   [emit-string item]
						integer!  [emit-integer item]
						float!	  [emit-float item]
						percent!  [emit-percent item]
						char!	  [emit-char to integer! item]
						pair!	  [emit-pair item]
						tuple!    [emit-tuple item]
						money!    [emit-money item]
						ref!      [emit-string item]
						point2D!  [emit-point reduce [item/x item/y]]
						point3D!  [emit-point reduce [item/x item/y item/z]]
						map!      [
							either with [
								pending-with-ctx: main-ctx
								pending-sub?: yes
								emit-block insert copy to block! item #!map!
								pending-sub?: no
								pending-with-ctx: none
							][
								pending-sub?: yes
								emit-block insert copy to block! item #!map!
								pending-sub?: no
							]
						]
						datatype! [emit-datatype front-get-RS-type-ID/word item]
						logic!	  [emit-logic item]
						time!	  [emit-time item]
						date!	  [emit-date item]
						none! 	  [emit-none]
						unset! 	  [emit-unset]
					]
				]
			]
		]
		nl?: no
		if type = 'TYPE_MAP [insert blk #!map!]
		unless sub [index: index + 1]
		last-index: index - 1							;-- Stage1 reads this field if return is lost
		last-index										;-- return the block index
	]
	
	emit-context: func [
		name [word!] spec [block!] stack? [logic!] self? [logic!] type [word!] /root
		/local flags
	][
		if pending-root? [root: yes]
		repend contexts [name copy spec index]			;-- COPY to avoid late word decorations
		flags: select [function 1 object 2] type
		if stack? [flags: flags or 4]
		if self?  [flags: flags or 8]
		
		emit-tag 'TYPE_CONTEXT
		emit-byte flags
		emit-varint length? spec
		foreach word spec [emit-symbol word]
		if root [
			if debug? [print [index ": context :" trim/lines copy/part mold/flat spec 50 "," stack? "," self?]]
			index: index + 1
		]
		last-index: index - 1
		last-index
	]
	
	init: does [
		clear header
		clear buffer
		clear sym-string
		clear sym-offsets
		clear symbols
		clear contexts
		index: 0
		last-index: -1
		word-index: -1
		string-index: -1
		typeset-index: -1
		pending-with-ctx: none
		pending-sub?: no
		pending-root?: no
		pending-set?: no
		pending-action?: no
	]
	
	finish: func [spec [block!] /local flags compressed][
		flags: #{05}									;-- compact + symbol table
		
		repend header [
			to-varint index - 1							;-- number of root records
			to-varint length? buffer					;-- size of records in bytes
			to-varint length? symbols
			to-varint length? sym-string
		]
		foreach ofs sym-offsets [append header int-to-bin/to-bin32 ofs]	;-- per-symbol offsets (4-byte LE), read in place
		append header sym-string
		insert buffer header
		
		if all [find spec 'compress 128 < length? buffer][
			compressed: compiler-crush/compress buffer
			if binary? compressed [
				flags: flags or #{02}
				clear buffer
				append buffer compressed
			]
		]
		
		clear header
		repend header [
			"REDBIN"
			#{01}										;-- version: 1
			flags										;-- flags: compact + symbols [+ options]
		]
		insert buffer header
	]
]
