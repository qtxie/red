Red [
	Title: "Red/System emitter state and chunk management"
	File:  %compiler/system-emitter.red
]

compiler-system-emitter: context [
	code-buf: make binary! 100000
	data-buf: make binary! 100000
	rodata-buf: make binary! 100000
	bits-buf: make binary! 10000
	symbols: make hash! 1000
	stack: make block! 40
	exits: make block! 1
	breaks: make block! 1
	cont-next: make block! 1
	cont-back: make block! 1
	overflow-jumps: make block! 1
	verbose: 0

	target: none
	compiler: none
	libc-init?: none
	rodata?: false
	extension-flag: -2147483648
	pointer: none
	anonymous-id: 0

	chunks: context [
		queue: make block! 10

		empty: does [copy/deep [#{} []]]

		start: has [start][
			repend/only queue [
				start: tail code-buf
				make block! 10
			]
			index? start
		]

		stop: has [entry chunk][
			entry: last queue
			remove back tail queue
			chunk: reduce [copy entry/1 entry/2 index? entry/1]
			clear entry/1
			chunk
		]

		make-boolean: func [/opt operation [word!]][
			start
			reduce [target/emit-boolean-switch operation stop]
		]

		join: func [left [block!] right [block!] /local byte-count reference][
			byte-count: length? left/1
			foreach reference right/2 [reference/1: reference/1 + byte-count]
			append left/1 right/1
			append left/2 right/2
			left
		]
	]

	connect: func [compiler-service [object!] target-service [object!]][
		compiler: compiler-service
		target: target-service
		target/connect compiler self
		self
	]

	reset: does [
		clear code-buf
		clear data-buf
		clear rodata-buf
		clear bits-buf
		clear symbols
		clear stack
		clear exits
		clear breaks
		clear cont-next
		clear cont-back
		clear overflow-jumps
		clear chunks/queue
		libc-init?: none
		rodata?: false
		anonymous-id: 0
		self
	]

	tail-ptr: does [index? tail code-buf]

	active-buf: does [either rodata? [rodata-buf][data-buf]]

	tag-ref: func [position [integer!]][
		either rodata? [negate position][position]
	]

	pad-data-buf: func [size [integer!] /local buffer over][
		buffer: active-buf
		unless zero? over: (length? buffer) // size [
			insert/dup tail buffer null (size - over)
		]
		buffer
	]

	make-name: does [
		anonymous-id: anonymous-id + 1
		to word! rejoin ["no-name-" anonymous-id]
	]

	merge: func [chunk [block!]][
		append code-buf chunk/1
		unless empty? chunks/queue [append second last chunks/queue chunk/2]
		code-buf
	]

	branch: func [
		chunk [block!]
		/over
		/back
		/on condition [word! block! logic!]
		/adjust offset [integer!]
		/parity use-parity? [none! logic!]
		/local size reference
	][
		case [
			over [
				size: target/emit-branch chunk/1 condition offset use-parity?
				foreach reference chunk/2 [reference/1: reference/1 + size]
				size
			]
			back [target/emit-branch/back? chunk/1 condition offset use-parity?]
			true [none]
		]
	]

	set-signed-state: func [expression][
		if all [block? expression 3 <= length? expression][
			target/set-width expression/2
		]
	]

	add-symbol: func [
		name [word! tag!]
		pointer [integer!]
		/with references [block! word! none!]
		/local spec
	][
		spec: reduce [
			name
			reduce [
				pick [constant global] rodata?
				pointer
				make block! 1
				any [references '-]
			]
		]
		append symbols new-line spec true
		spec
	]

	store-scalar: func [
		value
		type [word!]
		/packed
		/local size alignment pointer hex bytes number
	][
		if logic? :value [
			value: either value [1][0]
			type: 'integer!
		]
		if char? :value [value: to integer! value]
		size: compiler-system-layout/size-of? type
		unless size [compiler-system-types/throw-error reduce ["unsupported scalar type:" type]]
		case [
			(compiler-system-types/integer-type? type) [
				alignment: case [
					find [int64! uint64!] type [8]
					find [integer! int32! uint32!] type [
						either packed [size][target/default-align]
					]
					true [size]
				]
				pad-data-buf alignment
				pointer: tail active-buf
				hex: compiler-system-types/int-literal-hex value type
				bytes: debase/base hex 16
				if target/little-endian? [reverse bytes]
				append pointer bytes
			]
			find [float! float64! float32!] type [
				alignment: either type = 'float32! [target/default-align][8]
				pad-data-buf alignment
				pointer: tail active-buf
				number: either integer? :value [to float! value][value]
				unless any [float? :number issue? :number][number: 0.0]
				bytes: either type = 'float32! [
					either target/little-endian? [
						ieee-754/to-binary32/rev number
					][ieee-754/to-binary32 number]
				][
					either target/little-endian? [
						ieee-754/to-binary64/rev number
					][ieee-754/to-binary64 number]
				]
				append pointer bytes
			]
			type = 'c-string! [
				either string? :value [
					pointer: tail active-buf
					append pointer to binary! value
					append pointer null
				][
					pad-data-buf target/ptr-size
					pointer: tail active-buf
					store-scalar value either target/ptr-size = 8 ['uint64!]['integer!]
				]
			]
			find [pointer! function! subroutine! array! struct! union!] type [
				pad-data-buf target/ptr-size
				pointer: tail active-buf
				store-scalar value either target/ptr-size = 8 ['uint64!]['integer!]
			]
			true [compiler-system-types/throw-error reduce ["unsupported scalar type:" type]]
		]
		index? pointer
	]

	false-slots: func [count [integer!] /local output][
		output: make block! count
		loop count [append output false]
		output
	]

	merge-pointer-slots: func [
		destination [block!]
		byte-offset [integer!]
		source [block!]
		/local base index slot
	][
		base: 1 + to integer! (byte-offset / target/stack-width)
		index: 0
		foreach pointer? source [
			index: index + 1
			if pointer? [
				slot: base + index - 1
				if slot <= length? destination [poke destination slot true]
			]
		]
		destination
	]

	aggregate-pointer-slots: func [
		kind [word!]
		spec [block!]
		/local size output offset member-slots
	][
		size: either kind = 'union! [
			compiler-system-layout/union-size? spec
		][
			compiler-system-layout/member-offset? spec none
		]
		output: false-slots max 1 to integer! round/ceiling (size / target/stack-width)
		either kind = 'union! [
			offset: compiler-system-layout/union-payload-offset? spec
			foreach [name type] (compiler-system-types/union-members spec) [
				member-slots: pointer-slots type
				merge-pointer-slots output offset member-slots
			]
		][
			foreach [name type] spec [
				offset: compiler-system-layout/member-offset? spec name
				member-slots: pointer-slots type
				merge-pointer-slots output offset member-slots
			]
		]
		output
	]

	pointer-slots: func [
		type [block!]
		/local resolved base size count by-value?
	][
		resolved: compiler-system-types/resolve-aliased/silent type
		unless resolved [
			compiler-system-types/throw-error reduce ["unknown pointer-bitmap type:" mold type]
		]
		base: resolved/1
		by-value?: to logic! all [
			find [struct! union!] base
			'value = last resolved
		]
		case [
			find [pointer! c-string! function! subroutine! array!] base [copy [true]]
			find [struct! union!] base [
				either by-value? [
					aggregate-pointer-slots base resolved/2
				][
					copy [true]
				]
			]
			true [
				size: compiler-system-layout/size-of? resolved
				unless size [
					compiler-system-types/throw-error reduce ["unknown pointer-bitmap type:" mold type]
				]
				count: max 1 to integer! round/ceiling (size / target/stack-width)
				false-slots count
			]
		]
	]

	encode-slot-bits: func [
		slots [block!]
		flags [integer!]
		/local output position count bits index
	][
		output: make block! max 1 to integer! round/ceiling ((length? slots) / 31)
		position: head slots
		while [not tail? position][
			count: min 31 length? position
			bits: 0
			repeat index count [
				if pick position index [bits: bits or shift/left 1 index - 1]
			]
			position: skip position count
			if not tail? position [bits: bits or extension-flag]
			append output bits
		]
		if empty? output [append output 0]
		output/1: output/1 or flags
		output
	]

	compact-slot-bits: func [words [block!] /local mask][
		mask: complement extension-flag
		while [all [
			(length? words) > 1
			zero? ((last words) and mask)
		]][
			remove back tail words
		]
		poke words length? words (last words) and mask
		words
	]

	encode-ptr-bitmap: func [
		spec [block!]
		/metadata function-spec [block!]
		/local position item type arguments locals destination attributes flags
			argument-words local-words result
	][
		arguments: make block! 16
		locals: make block! 16
		destination: arguments
		position: head spec
		attributes: none
		if all [not tail? position block? position/1][
			attributes: position/1
			position: next position
		]
		while [not tail? position][
			item: position/1
			case [
				refinement? item [
					if (to word! item) = 'local [destination: locals]
					position: next position
				]
				set-word? item [
					position: either tail? next position [next position][skip position 2]
				]
				word? item [
					if tail? next position [
						compiler-system-types/throw-error reduce ["missing type for stack slot:" item]
					]
					type: position/2
					unless block? type [
						compiler-system-types/throw-error reduce ["invalid stack slot type for" item ":" mold type]
					]
					append destination pointer-slots type
					position: skip position 2
				]
				true [position: next position]
			]
		]
		flags: 0
		if attributes [
			case [
				find attributes 'variadic [flags: 1073741824]
				find attributes 'typed [flags: 536870912]
				true [none]
			]
		]
		argument-words: encode-slot-bits arguments flags
		local-words: encode-slot-bits locals 0
		unless target/stack-bitmap-counts? [
			compact-slot-bits argument-words
			compact-slot-bits local-words
		]
		result: make block! (length? argument-words) + (length? local-words) + 3
		if target/stack-bitmap-counts? [
			repend result [length? arguments length? locals]
		]
		append result argument-words
		append result '-
		append result local-words
		result
	]

	store-ptr-bitmap: func [list [block!] /local offset value bytes][
		offset: to integer! ((length? bits-buf) / 4)
		foreach value list [
			unless value = '- [
				bytes: int-to-bin/to-bin32 value
				unless target/little-endian? [reverse bytes]
				append bits-buf bytes
			]
		]
		offset
	]
]
