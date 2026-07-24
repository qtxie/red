Red [
	Title: "Compiler source parity inventory"
	File:  %source-parity.red
]

; Compiler ports are decoded by Red's native scanner. The comparison works on
; structured values and deliberately ignores formatting and host header names.
compiler-source-parity: context [
	last-error: none
	constructors: [func function has does context]

	decode: func [file [file!] /legacy /local source values][
		last-error: none
		source: read file
		if legacy [
			; REBOL's #[none] spelling is parsed as a map constructor by Red.
			replace/all source "#[none]" "none"
		]
		set/any 'values try [transcode source]
		either error? :values [
			last-error: :values
			none
		][values]
	]

	definition-body: func [
		values [block!]
		name [word! none!]
		/local position limit offset value
	][
		either name [
			position: head values
			while [not tail? position][
				if all [
					set-word? position/1
					(to word! position/1) = name
				][break]
				position: next position
			]
			if tail? position [return none]
			unless position [return none]
			limit: min 6 length? position
			repeat offset limit [
				value: pick position offset
				if block? value [return value]
			]
		][
			position: tail values
			while [not head? position][
				position: back position
				if block? position/1 [return position/1]
			]
		]
		none
	]

	method-names: func [body [block!] /local names position][
		names: make block! 128
		position: head body
		while [not tail? position][
			if all [
				set-word? position/1
				not tail? next position
				word? position/2
				find constructors position/2
			][
				append names to word! form position/1
			]
			if all [
				position/1 = 'do
				not tail? next position
				block? position/2
			][
				append names method-names position/2
			]
			position: next position
		]
		sort unique names
	]

	inventory: func [file [file!] name [word! none!] /legacy /local values body][
		values: either legacy [decode/legacy file][decode file]
		unless values [return none]
		body: either name = 'source-body [
			copy skip values 2
		][
			definition-body values name
		]
		unless body [return none]
		method-names body
	]

	contains-value?: func [value needle /local item][
		if equal? value needle [return true]
		if any [block? value paren? value][
			foreach item value [
				if contains-value? :item :needle [return true]
			]
		]
		false
	]

	payload-text: func [file [file!] /local values][
		values: decode file
		unless values [return none]
		mold/flat skip values 2
	]
]
