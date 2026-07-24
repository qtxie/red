Red [
	Title: "Red/System source normalization"
	File:  %compiler/system-source.red
]

; Red integer! is intentionally 32-bit. TRANSCODE therefore returns float! for
; larger decimal spellings and rejects hexadecimal spellings wider than eight
; digits. Preserve those exact source tokens as issue! values for the compiler;
; every other token remains owned by TRANSCODE.
compiler-system-source: context [
	original: make binary! 0
	normalized: make binary! 0
	values: none
	tokens: make block! 0
	rewrites: make block! 16
	last-error: none
	source-file: none

	digit: charset "0123456789"
	hex-digit: charset "0123456789ABCDEF"

	make-normalization-error: func [message token /local record][
		record: make object! [
			message: none
			file: none
			line: none
			column: none
			token: none
		]
		record/message: message
		record/file: source-file
		if object? token [
			record/line: token/line
			record/column: token/column
			record/token: token/raw
		]
		last-error: record
		none
	]

	make-rewrite: func [token replacement [string!] /local record][
		record: make object! [
			start: 0
			end: 0
			line: 0
			column: 0
			original: none
			replacement: none
		]
		record/start: token/start
		record/end: token/end
		record/line: token/line
		record/column: token/column
		record/original: copy token/raw
		record/replacement: replacement
		record
	]

	decimal-spelling?: func [text [string!]][
		parse/case text [
			opt ["+" | "-"]
			some [digit | "'"]
			end
		]
	]

	hex-spelling?: func [text [string!] /local digits][
		if (length? text) < 3 [return false]
		unless (last text) = #"h" [return false]
		digits: copy/part text (length? text) - 1
		all [
			parse/case digits [some hex-digit end]
			(length? digits) > 8
		]
	]

	greater-digits?: func [left [string!] right [string!]][
		any [
			(length? left) > (length? right)
			all [(length? left) = (length? right) left > right]
		]
	]

	decimal-replacement: func [text [string!] token /local digits negative? kind][
		digits: replace/all copy text "'" ""
		negative?: all [not empty? digits digits/1 = #"-"]
		if all [not empty? digits find "+-" digits/1][remove digits]
		while [all [(length? digits) > 1 digits/1 = #"0"]][remove digits]
		if empty? digits [digits: "0"]
		if either negative? [
			greater-digits? digits "9223372036854775808"
		][
			greater-digits? digits "18446744073709551615"
		][
			make-normalization-error "64-bit decimal literal is out of range" token
			return none
		]
		kind: either any [
			negative?
			not greater-digits? digits "9223372036854775807"
		]["i64"]["u64"]
		rejoin ["#" kind "-" either negative? ["n"][""] digits]
	]

	hex-replacement: func [text [string!] token /local digits][
		digits: copy/part text (length? text) - 1
		if (length? digits) > 16 [
			make-normalization-error "64-bit hexadecimal literal is out of range" token
			return none
		]
		rejoin ["#u64h-" digits]
	]

	replacement-for: func [token /local text][
		unless all [object? token binary? token/raw][return none]
		text: to string! token/raw
		case [
			decimal-spelling? text [decimal-replacement text token]
			hex-spelling? text [hex-replacement text token]
			true [none]
		]
	]

	error-token: does [
		foreach token reverse copy compiler-lexer/tokens [
			if token/kind = 'error [return token]
		]
		none
	]

	rewrite-token: func [buffer [binary!] token replacement [string!] /local width][
		width: token/end - token/start
		change/part at buffer token/start to binary! replacement width
		append/only rewrites make-rewrite token replacement
	]

	operator-word-rewrites: func [
		buffer [binary!]
		token-list [block!]
		/local output position left right suffix marker-text marker span original
	][
		output: make block! 8
		position: token-list
		while [not tail? next position][
			left: position/1
			right: position/2
			suffix: all [binary? right/raw to string! right/raw]
			if all [
				left/kind = 'value
				left/type = 'word!
				binary? left/raw
				right/kind = 'value
				find [word! set-word!] right/type
				left/end = right/start
				find ["<" "<:"] suffix
			][
				original: rejoin [to string! left/raw "<"]
				marker-text: rejoin [
					"__red_system_word_"
					enbase/base to binary! original 16
				]
				marker: copy marker-text
				either right/type = 'set-word! [
					append marker ":"
				][none]
				span: make left [
					end: right/end
					raw: copy/part at buffer left/start right/end - left/start
				]
				append/only output reduce [span marker]
				position: next position
			]
			position: next position
		]
		output
	]

	decode-buffer: func [buffer [binary!] /local result][
		result: either source-file [
			compiler-lexer/process/file buffer source-file
		][
			compiler-lexer/process buffer
		]
		tokens: copy compiler-lexer/tokens
		result
	]

	joined-less-than?: func [buffer [binary!] /local position previous][
		position: buffer
		while [position: find position #{3C}][
			unless head? position [
				previous: position/-1
				if any [
					all [previous >= 48 previous <= 57]
					all [previous >= 65 previous <= 90]
					all [previous >= 97 previous <= 122]
					find [33 45 61 62 63 95] previous
				][return true]
			]
			position: next position
		]
		false
	]

	wide-decimal-values?: func [values [series!] /local item][
		foreach item values [
			case [
				float? :item [
					if any [item > 2147483647.0 item < -2147483648.0][return true]
				]
				any-block? :item [if wide-decimal-values? item [return true]]
			]
		]
		false
	]

	process: func [
		input [binary! string!]
		/file file-name [file! string! none!]
		/local decoded token replacement attempts candidates pair operator-candidates candidate
	][
		original: either binary? input [copy input][to binary! input]
		normalized: copy original
		source-file: either file [file-name][none]
		values: none
		tokens: make block! 0
		rewrites: make block! 16
		last-error: none
		attempts: 0

		; Most sources need no spelling bridge. Avoid tens of thousands of trace
		; callbacks unless raw token spans are required for a rewrite.
		set/any 'decoded try [transcode normalized]
		if all [
			not error? :decoded
			not joined-less-than? normalized
			not wide-decimal-values? decoded
		][
			values: decoded
			return values
		]

		; TRANSCODE reports the exact prescan span for an otherwise-invalid
		; wide hexadecimal token. Rewrite one error at a time and retry.
		forever [
			decoded: decode-buffer normalized
			unless compiler-lexer/last-error [break]
			token: error-token
			replacement: either token [replacement-for token][none]
			if any [none? replacement last-error] [
				unless last-error [last-error: compiler-lexer/last-error]
				return none
			]
			rewrite-token normalized token replacement
			attempts: attempts + 1
			if attempts > 256 [
				make-normalization-error "too many Red/System numeric rewrites" token
				return none
			]
		]

		; Successful TRANSCODE calls expose out-of-range decimal spellings as
		; float!. Use their raw spans to retain all 64 bits.
		candidates: make block! 16
		foreach token tokens [
			if all [
				token/kind = 'value
				token/type = 'float!
				binary? token/raw
				decimal-spelling? to string! token/raw
			][
				replacement: replacement-for token
				if last-error [return none]
				append/only candidates reduce [token replacement]
			]
		]
		foreach pair reverse candidates [
			rewrite-token normalized pair/1 pair/2
		]
		if not empty? candidates [
			decoded: decode-buffer normalized
			if compiler-lexer/last-error [
				last-error: compiler-lexer/last-error
				return none
			]
			tokens: copy compiler-lexer/tokens
		]

		; Red/System allows '<' in words, while Red treats it as an operator
		; delimiter. Preserve transcode as the scanner and only bridge adjacent
		; word/< token pairs whose source spans contain no whitespace.
		operator-candidates: operator-word-rewrites normalized tokens
		if not empty? operator-candidates [
			foreach candidate reverse copy operator-candidates [
				rewrite-token normalized candidate/1 candidate/2
			]
			decoded: decode-buffer normalized
			if compiler-lexer/last-error [
				last-error: compiler-lexer/last-error
				return none
			]
			tokens: copy compiler-lexer/tokens
		]
		values: decoded
		values
	]
]
