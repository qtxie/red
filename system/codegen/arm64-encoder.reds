Red/System [
	Title: "Apple AArch64 primitive encoder for the hybrid compiler"
	File:  %arm64-encoder.reds
]

arm64-encoder: context [
	X0:   0
	X1:   1
	X2:   2
	X3:   3
	X4:   4
	X5:   5
	X6:   6
	X7:   7
	X8:   8
	X9:   9
	X10: 10
	X11: 11
	X12: 12
	X13: 13
	X14: 14
	X15: 15
	X16: 16
	X17: 17
	X18: 18
	X19: 19
	X20: 20
	X21: 21
	X22: 22
	X23: 23
	X24: 24
	X25: 25
	X26: 26
	X27: 27
	X28: 28
	FP:  29
	LR:  30
	SP:  31
	ZR:  31

	EQ:  0
	NE:  1
	CS:  2
	CC:  3
	MI:  4
	PL:  5
	VS:  6
	VC:  7
	HI:  8
	LS:  9
	GE: 10
	LT: 11
	GT: 12
	LE: 13

	OP_ADD: 1
	OP_SUB: 2
	OP_AND: 3
	OP_OR:  4
	OP_XOR: 5

	SHIFT_LEFT:     1
	SHIFT_RIGHT:    2
	SHIFT_ARITHMETIC: 3

	valid-register?: func [register [integer!] return: [logic!]][
		all [register >= 0 register <= 30]
	]

	valid-base?: func [register [integer!] return: [logic!]][
		all [register >= 0 register <= 31]
	]

	valid-width?: func [width [integer!] return: [logic!]][
		any [width = 4 width = 8]
	]

	room?: func [code [byte-ptr!] capacity size [integer!] return: [logic!]][
		any [null? code capacity >= size]
	]

	write-i32: func [at [byte-ptr!] value [integer!]][
		at/1: as byte! value
		at/2: as byte! (value >>> 8)
		at/3: as byte! (value >>> 16)
		at/4: as byte! (value >>> 24)
	]

	instruction: func [
		code [byte-ptr!]
		capacity value [integer!]
		return: [integer!]
	][
		unless room? code capacity 4 [return -1]
		if not null? code [write-i32 code value]
		4
	]

	halfword: func [low high index [integer!] return: [integer!]][
		case [
			index = 0 [low and FFFFh]
			index = 1 [(low >>> 16) and FFFFh]
			index = 2 [high and FFFFh]
			true [(high >>> 16) and FFFFh]
		]
	]

	move-immediate: func [
		code [byte-ptr!]
		capacity target width low high [integer!]
		return: [integer!]
		/local count i value zero-count ones-count base-index base-value
			written opcode encoded [integer!] invert? [logic!] at [byte-ptr!]
	][
		unless all [valid-register? target valid-width? width][return -1]
		count: either width = 8 [4][2]
		zero-count: 0
		ones-count: 0
		i: 0
		while [i < count][
			value: halfword low high i
			if value = 0 [zero-count: zero-count + 1]
			if value = FFFFh [ones-count: ones-count + 1]
			i: i + 1
		]
		invert?: ones-count > zero-count
		base-index: -1
		i: 0
		while [i < count][
			value: halfword low high i
			if all [
				base-index = -1
				either invert? [value <> FFFFh][value <> 0]
			][base-index: i]
			i: i + 1
		]
		if base-index = -1 [base-index: 0]
		written: 4
		i: 0
		while [i < count][
			value: halfword low high i
			if all [
				i <> base-index
				either invert? [value <> FFFFh][value <> 0]
			][written: written + 4]
			i: i + 1
		]
		unless room? code capacity written [return -1]
		if null? code [return written]

		base-value: halfword low high base-index
		if invert? [base-value: (base-value xor FFFFh) and FFFFh]
		opcode: case [
			all [invert? width = 8][92800000h]
			invert? [12800000h]
			width = 8 [D2800000h]
			true [52800000h]
		]
		encoded: (opcode or (base-index * 2097152))
		encoded: encoded or (base-value * 32)
		write-i32 code (encoded or target)

		written: 4
		i: 0
		while [i < count][
			value: halfword low high i
			if all [
				i <> base-index
				either invert? [value <> FFFFh][value <> 0]
			][
				opcode: either width = 8 [F2800000h][72800000h]
				encoded: (opcode or (i * 2097152))
				encoded: encoded or (value * 32)
				at: code + written
				write-i32 at (encoded or target)
				written: written + 4
			]
			i: i + 1
		]
		written
	]

	move-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-base? target valid-base? source valid-width? width][return -1]
		if target = source [return 0]
		either any [target = SP source = SP][
			opcode: either width = 8 [91000000h][11000000h]
			opcode: opcode or (source * 32)
		][
			opcode: either width = 8 [AA0003E0h][2A0003E0h]
			opcode: opcode or (source * 65536)
		]
		instruction code capacity (opcode or target)
	]

	move-not-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? target valid-register? source valid-width? width][return -1]
		opcode: either width = 8 [AA2003E0h][2A2003E0h]
		opcode: opcode or (source * 65536)
		instruction code capacity (opcode or target)
	]

	negate-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? target valid-register? source valid-width? width][return -1]
		opcode: either width = 8 [CB0003E0h][4B0003E0h]
		opcode: opcode or (source * 65536)
		instruction code capacity (opcode or target)
	]

	alu-register: func [
		code [byte-ptr!]
		capacity operation target left right width [integer!]
		set-flags? [logic!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right
			valid-width? width
			operation >= OP_ADD operation <= OP_XOR
		][return -1]
		if all [set-flags? operation >= OP_OR][return -1]
		opcode: case [
			operation = OP_ADD [
				case [
					all [set-flags? width = 8][AB000000h]
					set-flags? [2B000000h]
					width = 8 [8B000000h]
					true [0B000000h]
				]
			]
			operation = OP_SUB [
				case [
					all [set-flags? width = 8][EB000000h]
					set-flags? [6B000000h]
					width = 8 [CB000000h]
					true [4B000000h]
				]
			]
			operation = OP_AND [
				case [
					all [set-flags? width = 8][EA000000h]
					set-flags? [6A000000h]
					width = 8 [8A000000h]
					true [0A000000h]
				]
			]
			operation = OP_OR [either width = 8 [AA000000h][2A000000h]]
			true [either width = 8 [CA000000h][4A000000h]]
		]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	logical-immediate-fields: func [
		low high width [integer!]
		fields [int-ptr!]
		return: [logic!]
		/local bits element-size element-mask ones rotation base pattern shift
			base-low base-high candidate-low candidate-high rotated-by imms n [integer!]
	][
		bits: width * 8
		element-size: 2
		while [element-size <= bits][
			ones: 1
			while [ones < element-size][
				rotation: 0
				while [rotation < element-size][
					either element-size <= 32 [
						element-mask: either element-size = 32 [-1][
							(1 << element-size) - 1
						]
						base: (1 << ones) - 1
						pattern: either rotation = 0 [base][
							((base >>> rotation) or
								(base << (element-size - rotation))) and element-mask
						]
						candidate-low: pattern
						shift: element-size
						while [shift < 32][
							candidate-low: candidate-low or (pattern << shift)
							shift: shift + element-size
						]
						candidate-high: candidate-low
					][
						case [
							ones < 32 [
								base-low: (1 << ones) - 1
								base-high: 0
							]
							ones = 32 [
								base-low: -1
								base-high: 0
							]
							true [
								base-low: -1
								base-high: (1 << (ones - 32)) - 1
							]
						]
						case [
							rotation = 0 [
								candidate-low: base-low
								candidate-high: base-high
							]
							rotation < 32 [
								candidate-low: (base-low >>> rotation) or
									(base-high << (32 - rotation))
								candidate-high: (base-high >>> rotation) or
									(base-low << (32 - rotation))
							]
							rotation = 32 [
								candidate-low: base-high
								candidate-high: base-low
							]
							true [
								rotated-by: rotation - 32
								candidate-low: (base-high >>> rotated-by) or
									(base-low << (32 - rotated-by))
								candidate-high: (base-low >>> rotated-by) or
									(base-high << (32 - rotated-by))
							]
						]
					]
					if all [
						candidate-low = low
						any [width = 4 candidate-high = high]
					][
						imms: ((0 - (element-size * 2)) and 63) or (ones - 1)
						n: either element-size = 64 [1][0]
						fields/1: (n * 4194304) or (rotation * 65536)
						fields/1: fields/1 or (imms * 1024)
						return true
					]
					rotation: rotation + 1
				]
				ones: ones + 1
			]
			element-size: element-size * 2
		]
		false
	]

	logical-immediate: func [
		code [byte-ptr!]
		capacity operation target source width low high [integer!]
		return: [integer!]
		/local fields opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? source valid-width? width
			operation >= OP_AND operation <= OP_XOR
		][return -1]
		fields: 0
		unless logical-immediate-fields low high width :fields [return -1]
		opcode: case [
			all [operation = OP_AND width = 8][92000000h]
			operation = OP_AND [12000000h]
			all [operation = OP_OR width = 8][B2000000h]
			operation = OP_OR [32000000h]
			all [operation = OP_XOR width = 8][D2000000h]
			true [52000000h]
		]
		opcode: opcode or fields
		opcode: opcode or (source * 32)
		instruction code capacity (opcode or target)
	]

	add-register: func [
		code [byte-ptr!]
		capacity target left right width [integer!]
		return: [integer!]
	][
		alu-register code capacity OP_ADD target left right width false
	]

	subtract-register: func [
		code [byte-ptr!]
		capacity target left right width [integer!]
		return: [integer!]
	][
		alu-register code capacity OP_SUB target left right width false
	]

	extend-register: func [
		code [byte-ptr!]
		capacity target source source-width signed [integer!]
		return: [integer!]
		/local opcode imms [integer!]
	][
		unless all [
			valid-register? target
			valid-register? source
			any [source-width = 1 source-width = 2 source-width = 4 source-width = 8]
			any [signed = 0 signed = 1]
		][return -1]
		if source-width = 8 [return move-register code capacity target source 8]
		imms: (source-width * 8) - 1
		opcode: either signed = 1 [93400000h][D3400000h]
		opcode: opcode or (imms * 1024)
		opcode: opcode or (source * 32)
		instruction code capacity (opcode or target)
	]

	add-extended-register: func [
		code [byte-ptr!]
		capacity operation target base index source-width signed shift [integer!]
		return: [integer!]
		/local option opcode [integer!]
	][
		unless all [
			any [operation = OP_ADD operation = OP_SUB]
			valid-register? target
			valid-base? base
			valid-register? index
			any [source-width = 1 source-width = 2 source-width = 4 source-width = 8]
			any [signed = 0 signed = 1]
			shift >= 0 shift <= 4
		][return -1]
		option: case [
			source-width = 1 [0]
			source-width = 2 [1]
			source-width = 4 [2]
			true [3]
		]
		if signed = 1 [option: option + 4]
		opcode: either operation = OP_ADD [8B200000h][CB200000h]
		opcode: opcode or (index * 65536)
		opcode: opcode or (option * 8192)
		opcode: opcode or (shift * 1024)
		opcode: opcode or (base * 32)
		instruction code capacity (opcode or target)
	]

	compare-register: func [
		code [byte-ptr!]
		capacity left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? left valid-register? right valid-width? width][return -1]
		opcode: either width = 8 [EB00001Fh][6B00001Fh]
		opcode: opcode or (right * 65536)
		instruction code capacity (opcode or (left * 32))
	]

	encode-add-immediate: func [
		operation target source value width [integer!]
		set-flags? [logic!]
		return: [integer!]
		/local opcode shift [integer!]
	][
		unless all [
			valid-base? target valid-base? source valid-width? width
			any [operation = OP_ADD operation = OP_SUB]
			value >= 0
		][return -1]
		shift: 0
		if value > 4095 [
			unless all [(value and 4095) = 0 (value >>> 12) <= 4095][return -1]
			value: value >>> 12
			shift: 00400000h
		]
		opcode: case [
			all [operation = OP_ADD set-flags? width = 8][B1000000h]
			all [operation = OP_ADD set-flags?][31000000h]
			all [operation = OP_ADD width = 8][91000000h]
			operation = OP_ADD [11000000h]
			all [set-flags? width = 8][F1000000h]
			set-flags? [71000000h]
			width = 8 [D1000000h]
			true [51000000h]
		]
		opcode: opcode or shift
		opcode: opcode or (value * 1024)
		opcode: opcode or (source * 32)
		opcode or target
	]

	add-immediate: func [
		code [byte-ptr!]
		capacity target source value width [integer!]
		return: [integer!]
		/local operation encoded [integer!]
	][
		operation: OP_ADD
		if value < 0 [
			operation: OP_SUB
			if value = 80000000h [return -1]
			value: 0 - value
		]
		encoded: encode-add-immediate operation target source value width false
		if encoded = -1 [return -1]
		instruction code capacity encoded
	]

	compare-immediate: func [
		code [byte-ptr!]
		capacity source value width [integer!]
		return: [integer!]
		/local encoded [integer!]
	][
		encoded: encode-add-immediate OP_SUB ZR source value width true
		if encoded = -1 [return -1]
		instruction code capacity encoded
	]

	multiply-register: func [
		code [byte-ptr!]
		capacity target left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right valid-width? width
		][return -1]
		opcode: either width = 8 [9B007C00h][1B007C00h]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	divide-register: func [
		code [byte-ptr!]
		capacity target left right width signed [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right valid-width? width
			any [signed = 0 signed = 1]
		][return -1]
		opcode: case [
			all [signed = 1 width = 8][9AC00C00h]
			signed = 1 [1AC00C00h]
			width = 8 [9AC00800h]
			true [1AC00800h]
		]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	multiply-subtract: func [
		code [byte-ptr!]
		capacity target left right minuend width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right
			valid-register? minuend valid-width? width
		][return -1]
		opcode: either width = 8 [9B008000h][1B008000h]
		opcode: opcode or (right * 65536)
		opcode: opcode or (minuend * 1024)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	shift-register: func [
		code [byte-ptr!]
		capacity mode target value count width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			mode >= SHIFT_LEFT mode <= SHIFT_ARITHMETIC
			valid-register? target valid-register? value valid-register? count
			valid-width? width
		][return -1]
		opcode: case [
			all [mode = SHIFT_LEFT width = 8][9AC02000h]
			mode = SHIFT_LEFT [1AC02000h]
			all [mode = SHIFT_RIGHT width = 8][9AC02400h]
			mode = SHIFT_RIGHT [1AC02400h]
			width = 8 [9AC02800h]
			true [1AC02800h]
		]
		opcode: opcode or (count * 65536)
		opcode: opcode or (value * 32)
		instruction code capacity (opcode or target)
	]

	shift-immediate: func [
		code [byte-ptr!]
		capacity mode target source amount width [integer!]
		return: [integer!]
		/local bits immr imms opcode [integer!]
	][
		unless all [
			mode >= SHIFT_LEFT mode <= SHIFT_ARITHMETIC
			valid-register? target valid-register? source valid-width? width
		][return -1]
		bits: width * 8
		unless all [amount >= 0 amount < bits][return -1]
		case [
			mode = SHIFT_LEFT [
				immr: (bits - amount) and (bits - 1)
				imms: (bits - 1) - amount
				opcode: either width = 8 [D3400000h][53000000h]
			]
			mode = SHIFT_RIGHT [
				immr: amount
				imms: bits - 1
				opcode: either width = 8 [D3400000h][53000000h]
			]
			true [
				immr: amount
				imms: bits - 1
				opcode: either width = 8 [93400000h][13000000h]
			]
		]
		opcode: opcode or (immr * 65536)
		opcode: opcode or (imms * 1024)
		opcode: opcode or (source * 32)
		instruction code capacity (opcode or target)
	]

	condition-result: func [
		code [byte-ptr!]
		capacity target condition [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? target condition >= 0 condition <= 13][return -1]
		opcode: 1A9F07E0h or (((condition xor 1) and 15) * 4096)
		instruction code capacity (opcode or target)
	]

	branch-relative: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
		/local immediate [integer!]
	][
		unless all [
			(displacement and 3) = 0
			displacement >= -134217728 displacement <= 134217724
		][return -1]
		immediate: (displacement / 4) and 67108863
		instruction code capacity (14000000h or immediate)
	]

	call-relative: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
		/local immediate [integer!]
	][
		unless all [
			(displacement and 3) = 0
			displacement >= -134217728 displacement <= 134217724
		][return -1]
		immediate: (displacement / 4) and 67108863
		instruction code capacity (94000000h or immediate)
	]

	branch-condition: func [
		code [byte-ptr!]
		capacity condition displacement [integer!]
		return: [integer!]
		/local immediate opcode [integer!]
	][
		unless all [
			condition >= 0 condition <= 13
			(displacement and 3) = 0
			displacement >= -1048576 displacement <= 1048572
		][return -1]
		immediate: (displacement / 4) and 524287
		opcode: 54000000h or (immediate * 32)
		instruction code capacity (opcode or condition)
	]

	branch-zero: func [
		code [byte-ptr!]
		capacity register width displacement [integer!]
		nonzero? [logic!]
		return: [integer!]
		/local immediate opcode [integer!]
	][
		unless all [
			valid-register? register valid-width? width
			(displacement and 3) = 0
			displacement >= -1048576 displacement <= 1048572
		][return -1]
		immediate: (displacement / 4) and 524287
		opcode: case [
			all [nonzero? width = 8][B5000000h]
			nonzero? [35000000h]
			width = 8 [B4000000h]
			true [34000000h]
		]
		opcode: opcode or (immediate * 32)
		instruction code capacity (opcode or register)
	]

	call-register: func [
		code [byte-ptr!]
		capacity register [integer!]
		return: [integer!]
	][
		unless valid-register? register [return -1]
		instruction code capacity (D63F0000h or (register * 32))
	]

	jump-register: func [
		code [byte-ptr!]
		capacity register [integer!]
		return: [integer!]
	][
		unless valid-register? register [return -1]
		instruction code capacity (D61F0000h or (register * 32))
	]

	return-near: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		instruction code capacity D65F03C0h
	]

	trap: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		instruction code capacity D4200000h
	]

	page-address: func [
		code [byte-ptr!]
		capacity register [integer!]
		return: [integer!]
	][
		unless all [valid-register? register room? code capacity 8][return -1]
		if not null? code [
			write-i32 code (90000000h or register)
			write-i32 (code + 4) ((91000000h or (register * 32)) or register)
		]
		8
	]

	address-offset: func [
		code [byte-ptr!]
		capacity target base displacement scratch [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written magnitude operation opcode [integer!]
	][
		unless all [
			valid-register? target valid-base? base valid-register? scratch scratch <> base
		][return -1]
		if displacement = 0 [return move-register code capacity target base 8]
		operation: either displacement < 0 [OP_SUB][OP_ADD]
		magnitude: displacement
		if displacement < 0 [
			magnitude: either displacement = 80000000h [80000000h][0 - displacement]
		]
		encoded: encode-add-immediate operation target base magnitude 8 false
		if encoded <> -1 [return instruction code capacity encoded]
		written: move-immediate code capacity scratch 8 magnitude 0
		if written < 0 [return -1]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		opcode: either operation = OP_ADD [8B206000h][CB206000h]
		opcode: opcode or (scratch * 65536)
		opcode: opcode or (base * 32)
		encoded: instruction at (capacity - written) (opcode or target)
		if encoded < 0 [return -1]
		written + encoded
	]

	load-opcode: func [
		width signed result-width [integer!]
		scaled? [logic!]
		return: [integer!]
	][
		case [
			all [width = 1 signed = 1 result-width = 8 scaled?][39800000h]
			all [width = 1 signed = 1 scaled?][39C00000h]
			all [width = 1 signed = 1 result-width = 8][38800000h]
			all [width = 1 signed = 1][38C00000h]
			all [width = 1 scaled?][39400000h]
			width = 1 [38400000h]
			all [width = 2 signed = 1 result-width = 8 scaled?][79800000h]
			all [width = 2 signed = 1 scaled?][79C00000h]
			all [width = 2 signed = 1 result-width = 8][78800000h]
			all [width = 2 signed = 1][78C00000h]
			all [width = 2 scaled?][79400000h]
			width = 2 [78400000h]
			all [width = 4 signed = 1 result-width = 8 scaled?][B9800000h]
			all [width = 4 signed = 1 result-width = 8][B8800000h]
			all [width = 4 scaled?][B9400000h]
			width = 4 [B8400000h]
			all [width = 8 scaled?][F9400000h]
			true [F8400000h]
		]
	]

	store-opcode: func [width [integer!] scaled? [logic!] return: [integer!]][
		case [
			all [width = 1 scaled?][39000000h]
			width = 1 [38000000h]
			all [width = 2 scaled?][79000000h]
			width = 2 [78000000h]
			all [width = 4 scaled?][B9000000h]
			width = 4 [B8000000h]
			all [width = 8 scaled?][F9000000h]
			true [F8000000h]
		]
	]

	register-load: func [
		code [byte-ptr!]
		capacity target base displacement width signed result-width scratch [integer!]
		return: [integer!]
		/local at [byte-ptr!] opcode encoded written [integer!] scaled? [logic!]
	][
		unless all [
			valid-register? target valid-base? base valid-register? scratch scratch <> base
			any [width = 1 width = 2 width = 4 width = 8]
			any [result-width = 4 result-width = 8]
			any [signed = 0 signed = 1]
		][return -1]
		scaled?: all [
			displacement >= 0
			(displacement // width) = 0
			(displacement / width) <= 4095
		]
		if any [scaled? all [displacement >= -256 displacement <= 255]][
			opcode: load-opcode width signed result-width scaled?
			opcode: opcode or (base * 32)
			opcode: opcode or target
			opcode: either scaled? [
				opcode or ((displacement / width) * 1024)
			][opcode or ((displacement and 511) * 4096)]
			return instruction code capacity opcode
		]
		written: address-offset code capacity scratch base displacement scratch
		if written < 0 [return -1]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		opcode: (load-opcode width signed result-width false) or (scratch * 32)
		encoded: instruction at (capacity - written) (opcode or target)
		if encoded < 0 [return -1]
		written + encoded
	]

	register-store: func [
		code [byte-ptr!]
		capacity source base displacement width scratch [integer!]
		return: [integer!]
		/local at [byte-ptr!] opcode encoded written [integer!] scaled? [logic!]
	][
		unless all [
			valid-register? source valid-base? base valid-register? scratch
			scratch <> base scratch <> source
			any [width = 1 width = 2 width = 4 width = 8]
		][return -1]
		scaled?: all [
			displacement >= 0
			(displacement // width) = 0
			(displacement / width) <= 4095
		]
		if any [scaled? all [displacement >= -256 displacement <= 255]][
			opcode: store-opcode width scaled?
			opcode: opcode or (base * 32)
			opcode: opcode or source
			opcode: either scaled? [
				opcode or ((displacement / width) * 1024)
			][opcode or ((displacement and 511) * 4096)]
			return instruction code capacity opcode
		]
		written: address-offset code capacity scratch base displacement scratch
		if written < 0 [return -1]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		opcode: (store-opcode width false) or (scratch * 32)
		encoded: instruction at (capacity - written) (opcode or source)
		if encoded < 0 [return -1]
		written + encoded
	]

	frame-load: func [
		code [byte-ptr!]
		capacity target displacement width signed result-width [integer!]
		return: [integer!]
	][
		register-load code capacity target FP displacement width signed result-width X16
	]

	frame-store: func [
		code [byte-ptr!]
		capacity source displacement width [integer!]
		return: [integer!]
	][
		register-store code capacity source FP displacement width X16
	]

	pair-memory: func [
		code [byte-ptr!]
		capacity first second base displacement [integer!]
		load? [logic!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? first valid-register? second valid-base? base
			(displacement // 8) = 0 displacement >= -512 displacement <= 504
		][return -1]
		opcode: either load? [A9400000h][A9000000h]
		opcode: opcode or (((displacement / 8) and 127) * 32768)
		opcode: opcode or (second * 1024)
		opcode: opcode or (base * 32)
		instruction code capacity (opcode or first)
	]

	store-pair: func [
		code [byte-ptr!]
		capacity first second base displacement [integer!]
		return: [integer!]
	][
		pair-memory code capacity first second base displacement false
	]

	load-pair: func [
		code [byte-ptr!]
		capacity first second base displacement [integer!]
		return: [integer!]
	][
		pair-memory code capacity first second base displacement true
	]

	stack-subtract: func [
		code [byte-ptr!]
		capacity size [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		if size = 0 [return 0]
		unless all [size > 0 (size and 15) = 0][return -1]
		encoded: encode-add-immediate OP_SUB SP SP size 8 false
		if encoded <> -1 [return instruction code capacity encoded]
		written: move-immediate code capacity X16 8 size 0
		if written < 0 [return -1]
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: instruction at (capacity - written) CB3063FFh
		if encoded < 0 [return -1]
		written + encoded
	]

	frame-enter: func [
		code [byte-ptr!]
		capacity frame-size [integer!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		unless all [frame-size >= 0 (frame-size and 15) = 0][return -1]
		unless room? code capacity 8 [return -1]
		if not null? code [
			write-i32 code A9BF7BFDh
			write-i32 (code + 4) 910003FDh
		]
		written: 8
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: stack-subtract at (capacity - written) frame-size
		if encoded < 0 [return -1]
		written + encoded
	]

	frame-leave: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		unless room? code capacity 12 [return -1]
		if not null? code [
			write-i32 code 910003BFh
			write-i32 (code + 4) A8C17BFDh
			write-i32 (code + 8) D65F03C0h
		]
		12
	]

	float-move-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? target valid-register? source valid-width? width][return -1]
		if target = source [return 0]
		opcode: either width = 8 [1E604000h][1E204000h]
		opcode: opcode or (source * 32)
		instruction code capacity (opcode or target)
	]

	float-binary: func [
		code [byte-ptr!]
		capacity operation target left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			operation >= OP_ADD operation <= OP_SUB
			valid-register? target valid-register? left valid-register? right valid-width? width
		][return -1]
		opcode: case [
			all [operation = OP_ADD width = 8][1E602800h]
			operation = OP_ADD [1E202800h]
			width = 8 [1E603800h]
			true [1E203800h]
		]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	float-multiply: func [
		code [byte-ptr!]
		capacity target left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right valid-width? width
		][return -1]
		opcode: either width = 8 [1E600800h][1E200800h]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	float-divide: func [
		code [byte-ptr!]
		capacity target left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [
			valid-register? target valid-register? left valid-register? right valid-width? width
		][return -1]
		opcode: either width = 8 [1E601800h][1E201800h]
		opcode: opcode or (right * 65536)
		opcode: opcode or (left * 32)
		instruction code capacity (opcode or target)
	]

	float-compare: func [
		code [byte-ptr!]
		capacity left right width [integer!]
		return: [integer!]
		/local opcode [integer!]
	][
		unless all [valid-register? left valid-register? right valid-width? width][return -1]
		opcode: either width = 8 [1E602000h][1E202000h]
		opcode: opcode or (right * 65536)
		instruction code capacity (opcode or (left * 32))
	]
]
