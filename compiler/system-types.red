Red [
	Title: "Red/System compiler type service"
	File:  %compiler/system-types.red
]

compiler-system-types: context [
	last-error: none
	aliases: make hash! 40
	enumerations: make hash! 40

	none-type: [none]
	number-types: [byte! int8! uint8! int16! uint16! integer! int32! uint32! int64! uint64!]
	float-types: [float! float32! float64!]
	integer-types: [byte! int8! uint8! int16! uint16! integer! int32! uint32! int64! uint64!]
	signed-integers: [int8! int16! integer! int32! int64!]
	unsigned-integers: [byte! uint8! uint16! uint32! uint64!]
	int64-types: [int64! uint64!]
	base-types: [
		int8! byte! uint8! int16! uint16! int32! integer! uint32!
		int64! uint64! float32! float64! float! logic! pointer! c-string!
		struct! union! function! subroutine! array!
	]
	type-sets: [number! any-number! bit-set! poly! any-type! any-pointer!]

	reset: does [
		clear aliases
		clear enumerations
		last-error: none
		self
	]

	throw-error: func [message /local record][
		record: make object! [message: none]
		record/message: form either block? message [reduce message][message]
		last-error: record
		throw/name record 'system-type-error
	]

	base-type?: func [value][
		if block? value [value: value/1]
		to logic! find base-types value
	]

	canonical-type: func [type [block!]][
		either type/1 = 'int32! [copy [integer!]][type]
	]

	integer-type?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return false]
		if block? type [type: type/1]
		to logic! find integer-types type
	]

	int32-type?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return false]
		if block? type [type: type/1]
		to logic! find [integer! int32!] type
	]

	integer-width?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return none]
		if block? type [type: type/1]
		select [
			byte! 1 uint8! 1 int8! 1
			uint16! 2 int16! 2
			integer! 4 int32! 4 uint32! 4
			int64! 8 uint64! 8
		] type
	]

	signed-integer?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return false]
		if block? type [type: type/1]
		to logic! find signed-integers type
	]

	unsigned-integer?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return false]
		if block? type [type: type/1]
		to logic! find unsigned-integers type
	]

	int64?: func [type [block! word! integer! none!]][
		if any [none? type integer? type][return false]
		if block? type [type: type/1]
		to logic! find int64-types type
	]

	any-float?: func [type [block!]][
		to logic! find float-types type/1
	]

	same-type?: func [left [block!] right [block!]][
		(canonical-type left) = canonical-type right
	]

	none-type?: func [type [block! none!]][
		any [none? type all [block? type none? type/1]]
	]

	lossless-integer-cast?: func [
		from [block!]
		to [block!]
		/local from-width to-width from-signed? to-signed?
	][
		from: canonical-type from
		to: canonical-type to
		if from = to [return true]
		unless all [integer-type? from integer-type? to][return false]
		from-width: integer-width? from
		to-width: integer-width? to
		from-signed?: signed-integer? from
		to-signed?: signed-integer? to
		any [
			all [from-signed? to-signed? from-width < to-width]
			all [not from-signed? not to-signed? from-width < to-width]
			all [not from-signed? to-signed? from-width < to-width]
			all [from/1 = 'byte! to/1 = 'integer!]
		]
	]

	register-alias: func [name [word!] type [block!]][
		if find aliases name [throw-error ["duplicate type alias:" name]]
		repend aliases [name copy/deep type]
		type
	]

	find-aliased: func [name [word!] /position /local entry][
		entry: find aliases name
		either position [entry][all [entry entry/2]]
	]

	resolve-aliased: func [type [block!] /silent /local name seen alias][
		type: canonical-type type
		seen: copy []
		while [all [block? type word? type/1 not base-type? type/1]][
			name: type/1
			if find seen name [
				either silent [return none][throw-error ["cyclic type alias:" name]]
			]
			append seen name
			alias: find-aliased name
			unless alias [
				either silent [return none][throw-error ["unknown type:" name]]
			]
			type: alias
		]
		type
	]

	union-spec?: func [spec [block!]][
		all [not empty? spec find [union-marker variant-marker] spec/1]
	]

	tagged-union?: func [spec [block!]][
		all [not empty? spec spec/1 = 'variant-marker]
	]

	union-members: func [spec [block!]][
		either union-spec? spec [skip spec 2][spec]
	]

	union-tag-type?: func [spec [block!]][
		either tagged-union? spec [spec/2][none]
	]

	union-variant-id?: func [spec [block!] name [word!] /local id][
		id: 1
		foreach [variant type] union-members spec [
			if variant = name [return id]
			id: id + 1
		]
		none
	]

	union-variant-type?: func [spec [block!] name [word!]][
		select union-members spec name
	]

	tagged-union-type?: func [type [block!] /local resolved][
		resolved: resolve-aliased type
		all [resolved/1 = 'union! tagged-union? resolved/2 resolved]
	]

	inline-struct?: func [spec [block!] /local position][
		if odd? length? spec [return false]
		position: head spec
		while [not tail? position][
			unless all [word? position/1 block? position/2][return false]
			position: skip position 2
		]
		not empty? spec
	]

	normalize-member-type: func [payload [block!] /local type][
		type: copy/deep payload
		case [
			all [not empty? type word? type/1 any [base-type? type/1 find aliases type/1]][type]
			inline-struct? type [reduce ['struct! type 'value]]
			true [throw-error ["invalid union member type:" mold payload]]
		]
	]

	normalize-union-spec: func [
		spec [block!]
		/local output tagged? members count tag-type seen type
	][
		spec: copy/deep spec
		tagged?: all [block? spec/1 spec/1/1 = 'variant]
		members: either tagged? [next spec][spec]
		if odd? length? members [throw-error "union members must be name/type pairs"]
		count: 0
		seen: copy []
		output: make block! length? members
		foreach [name payload] members [
			unless word? name [throw-error ["invalid union member name:" mold name]]
			if find seen name [throw-error ["duplicate union member:" name]]
			append seen name
			unless block? payload [throw-error ["invalid union member type:" mold payload]]
			type: normalize-member-type payload
			repend output [name type]
			count: count + 1
		]
		either tagged? [
			tag-type: case [
				count <= 255 [[uint8!]]
				count <= 65535 [[uint16!]]
				true [[uint32!]]
			]
			insert output reduce ['variant-marker tag-type]
		][
			insert output reduce ['union-marker none]
		]
		output
	]

	greater-digits?: func [left [string!] right [string!]][
		any [
			(length? left) > (length? right)
			all [(length? left) = (length? right) left > right]
		]
	]

	hex4: func [number [integer!] /local hex][
		hex: to string! to-hex number
		copy/part skip hex 4 4
	]

	decimal64-to-hex: func [
		digits [string!]
		negative? [logic!]
		/local limbs carry value digit index output part
	][
		limbs: copy [0 0 0 0]
		foreach character digits [
			digit: (to integer! character) - (to integer! #"0")
			carry: digit
			repeat index 4 [
				value: (limbs/:index * 10) + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
			if carry <> 0 [throw-error ["64-bit integer literal overflow:" digits]]
		]
		if negative? [
			repeat index 4 [limbs/:index: 65535 - limbs/:index]
			carry: 1
			repeat index 4 [
				value: limbs/:index + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
		]
		output: hex4 limbs/4
		part: hex4 limbs/3
		append output part
		part: hex4 limbs/2
		append output part
		part: hex4 limbs/1
		append output part
		output
	]

	int64-literal-info: func [value /local spelling kind payload negative? digits type][
		unless issue? value [return none]
		spelling: to string! value
		case [
			find/match spelling "i64-" [kind: 'i64 payload: skip spelling 4]
			find/match spelling "u64-" [kind: 'u64 payload: skip spelling 4]
			find/match spelling "u64h-" [kind: 'u64h payload: skip spelling 5]
			true [return none]
		]
		switch kind [
			i64 [
				negative?: to logic! all [not empty? payload payload/1 = #"n"]
				if negative? [payload: next payload]
				digits: copy payload
				if greater-digits? digits either negative? ["9223372036854775808"]["9223372036854775807"] [
					throw-error ["int64! literal out of range:" mold value]
				]
				reduce ['int64! decimal64-to-hex digits negative?]
			]
			u64 [
				digits: copy payload
				if greater-digits? digits "18446744073709551615" [
					throw-error ["uint64! literal out of range:" mold value]
				]
				type: either greater-digits? digits "9223372036854775807" ['uint64!]['int64!]
				reduce [type decimal64-to-hex digits false]
			]
			u64h [
				payload: uppercase copy payload
				if 16 < length? payload [throw-error ["uint64! literal out of range:" mold value]]
				insert/dup payload #"0" (16 - length? payload)
				type: either payload > "7FFFFFFFFFFFFFFF" ['uint64!]['int64!]
				reduce [type payload]
			]
		]
	]

	int64-literal?: func [value][to logic! int64-literal-info value]
	last-value?: func [value][all [tag? value value = <last>]]

	int64-hex: func [value type [word!] /local info hex negative?][
		case [
			info: int64-literal-info value [info/2]
			integer? value [
				negative?: negative? value
				if all [type = 'uint64! negative?][
					throw-error ["negative integer literal cannot initialize uint64!:" value]
				]
				hex: decimal64-to-hex form absolute value negative?
				hex
			]
			last-value? value ["0000000000000000"]
			true [throw-error ["invalid 64-bit integer literal:" mold value]]
		]
	]

	int-literal-hex: func [value type [word!] /local width info hex range minimum maximum][
		type: first canonical-type reduce [type]
		width: integer-width? type
		if width = 8 [return int64-hex value type]
		case [
			info: int64-literal-info value [
				hex: info/2
				if all [type <> 'uint32! copy/part hex 8 <> "00000000"] [
					throw-error ["integer literal out of range for" type ":" mold value]
				]
				copy skip hex 16 - (width * 2)
			]
			integer? value [
				unless find [integer! uint32!] type [
					range: select [
						int8! [-128 127] byte! [0 255] uint8! [0 255]
						int16! [-32768 32767] uint16! [0 65535]
					] type
					minimum: range/1
					maximum: range/2
					if any [value < minimum value > maximum][
						throw-error ["integer literal out of range for" type ":" value]
					]
				]
				hex: to string! to-hex value
				copy skip hex 8 - (width * 2)
			]
			last-value? value [copy/part "00000000" width * 2]
			true [throw-error ["invalid integer literal:" mold value]]
		]
	]
]
