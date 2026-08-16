Red/System [
	Title: "Windows x64 primitive encoder for the hybrid compiler"
	File:  %x64-encoder.reds
]

x64-encoder: context [
	RAX: 0
	RCX: 1
	RDX: 2
	RBX: 3
	RSP: 4
	RBP: 5
	RSI: 6
	RDI: 7
	R8:  8
	R9:  9
	XMM0: 0
	XMM1: 1

	BASE_FRAME_SIZE: 32
	BITMAP_OFFSET: 9

	fits-i8?: func [value [integer!] return: [logic!]][
		all [value >= -128 value <= 127]
	]

	write-i32: func [at [byte-ptr!] value [integer!]][
		at/1: as byte! value
		at/2: as byte! (value >>> 8)
		at/3: as byte! (value >>> 16)
		at/4: as byte! (value >>> 24)
	]

	write-i64: func [at [byte-ptr!] low high [integer!]][
		write-i32 at low
		write-i32 (at + 4) high
	]

	room?: func [code [byte-ptr!] capacity size [integer!] return: [logic!]][
		any [null? code capacity >= size]
	]

	rex: func [wide? [logic!] reg rm [integer!] return: [integer!]
		/local value [integer!]
	][
		value: 40h
		if wide? [value: value + 8]
		if reg >= 8 [value: value + 4]
		if rm >= 8 [value: value + 1]
		value
	]

	modrm: func [mode reg rm [integer!] return: [integer!]][
		((mode << 6) or ((reg and 7) << 3)) or (rm and 7)
	]

	prolog: func [
		code [byte-ptr!]
		capacity bitmap [integer!]
		return: [integer!]
		/local at [byte-ptr!]
	][
		unless room? code capacity 15 [return -1]
		if null? code [return 15]
		at: code
		at/1: as byte! 55h                         ; push rbp
		at/2: as byte! 48h
		at/3: as byte! 89h
		at/4: as byte! E5h                         ; mov rbp, rsp
		at/5: as byte! 6Ah
		at/6: as byte! 00h                         ; catch ID
		at/7: as byte! 6Ah
		at/8: as byte! 00h                         ; catch resume
		at/9: as byte! 68h                         ; pointer bitmap word
		write-i32 (at + 9) bitmap
		at/14: as byte! 6Ah
		at/15: as byte! 00h                        ; parent frame
		15
	]

	allocate-frame: func [
		code [byte-ptr!]
		capacity size [integer!]
		return: [integer!]
		/local count [integer!] at [byte-ptr!]
	][
		if size = 0 [return 0]
		if size < 0 [return -1]
		count: either size <= 127 [4][7]
		unless room? code capacity count [return -1]
		if null? code [return count]
		at: code
		at/1: as byte! 48h
		either count = 4 [
			at/2: as byte! 83h
			at/3: as byte! ECh
			at/4: as byte! size
		][
			at/2: as byte! 81h
			at/3: as byte! ECh
			write-i32 (at + 3) size
		]
		count
	]

	move-immediate: func [
		code [byte-ptr!]
		capacity target width low high [integer!]
		return: [integer!]
		/local size [integer!] at [byte-ptr!]
	][
		unless all [target >= 0 target <= 15 any [width = 4 width = 8]][
			return -1
		]
		size: either width = 8 [either target >= 8 [11][10]][
			either target >= 8 [6][5]
		]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if target >= 8 [
			at/1: as byte! either width = 8 [49h][41h]
			at: at + 1
		]
		if all [width = 8 target < 8][
			at/1: as byte! 48h
			at: at + 1
		]
		at/1: as byte! (B8h + (target and 7))
		either width = 8 [write-i64 (at + 1) low high][write-i32 (at + 1) low]
		size
	]

	move-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) source target
		size: either prefix = 40h [2][3]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! 89h
		at/2: as byte! modrm 3 source target
		size
	]

	binary-register: func [
		code [byte-ptr!]
		capacity opcode target source width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			any [width = 4 width = 8]
			any [
				opcode = 01h opcode = 09h opcode = 21h
				opcode = 29h opcode = 31h opcode = 39h
			]
		][return -1]
		prefix: rex (width = 8) source target
		size: either prefix = 40h [2][3]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! opcode
		at/2: as byte! modrm 3 source target
		size
	]

	multiply-register: func [
		code [byte-ptr!]
		capacity target source width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) target source
		size: either prefix = 40h [3][4]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! AFh
		at/3: as byte! modrm 3 target source
		size
	]

	multiply-immediate: func [
		code [byte-ptr!]
		capacity target source value width [integer!]
		return: [integer!]
		/local prefix immediate-size size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) target source
		immediate-size: either fits-i8? value [1][4]
		size: 2 + immediate-size
		if prefix <> 40h [size: size + 1]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! either immediate-size = 1 [6Bh][69h]
		at/2: as byte! modrm 3 target source
		either immediate-size = 1 [at/3: as byte! value][write-i32 (at + 2) value]
		size
	]

	shift-register: func [
		code [byte-ptr!]
		capacity target mode width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15
			any [mode = 4 mode = 5 mode = 7]
			any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) mode target
		size: either prefix = 40h [2][3]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! D3h
		at/2: as byte! modrm 3 mode target
		size
	]

	shift-immediate: func [
		code [byte-ptr!]
		capacity target mode count width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15
			any [mode = 4 mode = 5 mode = 7]
			count >= 0 count <= 63
			any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) mode target
		size: either prefix = 40h [3][4]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! C1h
		at/2: as byte! modrm 3 mode target
		at/3: as byte! count
		size
	]

	not-register: func [
		code [byte-ptr!]
		capacity target width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) 2 target
		size: either prefix = 40h [2][3]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! F7h
		at/2: as byte! modrm 3 2 target
		size
	]

	condition-result: func [
		code [byte-ptr!]
		capacity condition [integer!]
		return: [integer!]
	][
		unless all [condition >= 0 condition <= 15 room? code capacity 6][return -1]
		if not null? code [
			code/1: as byte! 0Fh
			code/2: as byte! (90h + condition)
			code/3: as byte! C0h
			code/4: as byte! 0Fh
			code/5: as byte! B6h
			code/6: as byte! C0h
		]
		6
	]

	test-register: func [
		code [byte-ptr!]
		capacity target width [integer!]
		return: [integer!]
		/local prefix size [integer!] at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15 any [width = 4 width = 8]
		][return -1]
		prefix: rex (width = 8) target target
		size: either prefix = 40h [2][3]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		at/1: as byte! 85h
		at/2: as byte! modrm 3 target target
		size
	]

	jump-relative: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
	][
		unless room? code capacity 5 [return -1]
		if not null? code [
			code/1: as byte! E9h
			write-i32 (code + 1) displacement
		]
		5
	]

	jump-condition: func [
		code [byte-ptr!]
		capacity condition displacement [integer!]
		return: [integer!]
	][
		unless all [condition >= 0 condition <= 15 room? code capacity 6][return -1]
		if not null? code [
			code/1: as byte! 0Fh
			code/2: as byte! (80h + condition)
			write-i32 (code + 2) displacement
		]
		6
	]

	trap: func [
		code [byte-ptr!]
		capacity [integer!]
		return: [integer!]
	][
		unless room? code capacity 2 [return -1]
		if not null? code [
			code/1: as byte! 0Fh
			code/2: as byte! 0Bh
		]
		2
	]

	divide-register: func [
		code [byte-ptr!]
		capacity width signed [integer!]
		return: [integer!]
		/local size [integer!]
	][
		unless all [any [width = 4 width = 8] any [signed = 0 signed = 1]][return -1]
		size: either signed = 1 [either width = 8 [5][3]][either width = 8 [5][4]]
		unless room? code capacity size [return -1]
		if null? code [return size]
		case [
			all [signed = 1 width = 4][
				code/1: as byte! 99h
				code/2: as byte! F7h
				code/3: as byte! F9h
			]
			all [signed = 1 width = 8][
				code/1: as byte! 48h
				code/2: as byte! 99h
				code/3: as byte! 48h
				code/4: as byte! F7h
				code/5: as byte! F9h
			]
			all [signed = 0 width = 4][
				code/1: as byte! 31h
				code/2: as byte! D2h
				code/3: as byte! F7h
				code/4: as byte! F1h
			]
			true [
				code/1: as byte! 31h
				code/2: as byte! D2h
				code/3: as byte! 48h
				code/4: as byte! F7h
				code/5: as byte! F1h
			]
		]
		size
	]

	sign-extend-register: func [
		code [byte-ptr!]
		capacity target [integer!]
		return: [integer!]
	][
		unless all [target >= 0 target <= 15 room? code capacity 3][return -1]
		if not null? code [
			code/1: as byte! rex true target target
			code/2: as byte! 63h
			code/3: as byte! modrm 3 target target
		]
		3
	]

	frame-load: func [
		code [byte-ptr!]
		capacity target displacement width signed [integer!]
		return: [integer!]
		/local prefix opcode-size displacement-size size mode [integer!]
			at [byte-ptr!]
	][
		unless all [
			target >= 0 target <= 15
			any [width = 1 width = 2 width = 4 width = 8]
			any [signed = 0 signed = 1]
		][return -1]
		displacement-size: either fits-i8? displacement [1][4]
		mode: either displacement-size = 1 [1][2]
		opcode-size: either width <= 2 [2][1]
		prefix: rex (width = 8) target RBP
		size: opcode-size + 1 + displacement-size
		if prefix <> 40h [size: size + 1]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if prefix <> 40h [at/1: as byte! prefix at: at + 1]
		case [
			width = 1 [
				at/1: as byte! 0Fh
				at/2: as byte! either signed = 1 [BEh][B6h]
				at: at + 2
			]
			width = 2 [
				at/1: as byte! 0Fh
				at/2: as byte! either signed = 1 [BFh][B7h]
				at: at + 2
			]
			true [at/1: as byte! 8Bh at: at + 1]
		]
		at/1: as byte! modrm mode target RBP
		at: at + 1
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	frame-store: func [
		code [byte-ptr!]
		capacity source displacement width [integer!]
		return: [integer!]
		/local prefix-size prefix displacement-size size mode [integer!]
			at [byte-ptr!]
	][
		unless all [
			source >= 0 source <= 15
			any [width = 1 width = 2 width = 4 width = 8]
		][return -1]
		displacement-size: either fits-i8? displacement [1][4]
		mode: either displacement-size = 1 [1][2]
		prefix: rex (width = 8) source RBP
		prefix-size: 0
		if width = 2 [prefix-size: prefix-size + 1]
		if any [prefix <> 40h all [width = 1 source >= 4]][
			prefix-size: prefix-size + 1
		]
		size: prefix-size + 1 + 1 + displacement-size
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if width = 2 [at/1: as byte! 66h at: at + 1]
		if any [prefix <> 40h all [width = 1 source >= 4]][
			at/1: as byte! prefix
			at: at + 1
		]
		at/1: as byte! either width = 1 [88h][89h]
		at/2: as byte! modrm mode source RBP
		at: at + 2
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	xmm-prefix: func [width [integer!] return: [integer!]][
		either width = 4 [F3h][either width = 8 [F2h][0]]
	]

	xmm-frame-load: func [
		code [byte-ptr!]
		capacity target displacement width [integer!]
		return: [integer!]
		/local prefix rex-byte displacement-size size mode [integer!]
			at [byte-ptr!]
	][
		prefix: xmm-prefix width
		unless all [target >= 0 target <= 15 prefix <> 0][return -1]
		displacement-size: either fits-i8? displacement [1][4]
		mode: either displacement-size = 1 [1][2]
		rex-byte: rex false target RBP
		size: 4 + displacement-size
		if rex-byte <> 40h [size: size + 1]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 10h
		at/3: as byte! modrm mode target RBP
		at: at + 3
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	xmm-frame-store: func [
		code [byte-ptr!]
		capacity source displacement width [integer!]
		return: [integer!]
		/local prefix rex-byte displacement-size size mode [integer!]
			at [byte-ptr!]
	][
		prefix: xmm-prefix width
		unless all [source >= 0 source <= 15 prefix <> 0][return -1]
		displacement-size: either fits-i8? displacement [1][4]
		mode: either displacement-size = 1 [1][2]
		rex-byte: rex false source RBP
		size: 4 + displacement-size
		if rex-byte <> 40h [size: size + 1]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 11h
		at/3: as byte! modrm mode source RBP
		at: at + 3
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	xmm-load-indirect: func [
		code [byte-ptr!]
		capacity target address width [integer!]
		return: [integer!]
		/local prefix rex-byte size low [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix width
		low: address and 7
		unless all [
			target >= 0 target <= 15 address >= 0 address <= 15
			prefix <> 0 low <> 4 low <> 5
		][return -1]
		rex-byte: rex false target address
		size: either rex-byte = 40h [4][5]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 10h
		at/3: as byte! modrm 0 target address
		size
	]

	xmm-store-indirect: func [
		code [byte-ptr!]
		capacity address source width [integer!]
		return: [integer!]
		/local prefix rex-byte size low [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix width
		low: address and 7
		unless all [
			address >= 0 address <= 15 source >= 0 source <= 15
			prefix <> 0 low <> 4 low <> 5
		][return -1]
		rex-byte: rex false source address
		size: either rex-byte = 40h [4][5]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 11h
		at/3: as byte! modrm 0 source address
		size
	]

	xmm-binary: func [
		code [byte-ptr!]
		capacity opcode target source width [integer!]
		return: [integer!]
		/local prefix rex-byte size [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix width
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15 prefix <> 0
			any [opcode = 58h opcode = 5Ch opcode = 59h opcode = 5Eh]
		][return -1]
		rex-byte: rex false target source
		size: either rex-byte = 40h [4][5]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! opcode
		at/3: as byte! modrm 3 target source
		size
	]

	xmm-compare: func [
		code [byte-ptr!]
		capacity left right width [integer!]
		return: [integer!]
		/local rex-byte size [integer!] at [byte-ptr!]
	][
		unless all [
			left >= 0 left <= 15 right >= 0 right <= 15
			any [width = 4 width = 8]
		][return -1]
		rex-byte: rex false left right
		size: 3
		if width = 8 [size: size + 1]
		if rex-byte <> 40h [size: size + 1]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if width = 8 [at/1: as byte! 66h at: at + 1]
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 2Eh
		at/3: as byte! modrm 3 left right
		size
	]

	xmm-convert: func [
		code [byte-ptr!]
		capacity target source source-width target-width [integer!]
		return: [integer!]
		/local prefix rex-byte size [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix source-width
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			prefix <> 0 source-width <> target-width
			any [target-width = 4 target-width = 8]
		][return -1]
		rex-byte: rex false target source
		size: either rex-byte = 40h [4][5]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at: at + 1
		if rex-byte <> 40h [at/1: as byte! rex-byte at: at + 1]
		at/1: as byte! 0Fh
		at/2: as byte! 5Ah
		at/3: as byte! modrm 3 target source
		size
	]

	integer-to-xmm: func [
		code [byte-ptr!]
		capacity target source source-width target-width [integer!]
		return: [integer!]
		/local prefix rex-byte size [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix target-width
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			prefix <> 0 any [source-width = 4 source-width = 8]
		][return -1]
		rex-byte: rex (source-width = 8) target source
		size: 5
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at/2: as byte! rex-byte
		at/3: as byte! 0Fh
		at/4: as byte! 2Ah
		at/5: as byte! modrm 3 target source
		size
	]

	xmm-to-integer: func [
		code [byte-ptr!]
		capacity target source source-width target-width [integer!]
		return: [integer!]
		/local prefix rex-byte size [integer!] at [byte-ptr!]
	][
		prefix: xmm-prefix source-width
		unless all [
			target >= 0 target <= 15 source >= 0 source <= 15
			prefix <> 0 any [target-width = 4 target-width = 8]
		][return -1]
		rex-byte: rex (target-width = 8) target source
		size: 5
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! prefix
		at/2: as byte! rex-byte
		at/3: as byte! 0Fh
		at/4: as byte! 2Ch
		at/5: as byte! modrm 3 target source
		size
	]

	float-condition-result: func [
		code [byte-ptr!]
		capacity condition parity [integer!]
		return: [integer!]
	][
		unless all [
			condition >= 0 condition <= 15
			any [parity = 0 parity = 1 parity = 2]
		][return -1]
		if parity = 0 [return condition-result code capacity condition]
		unless room? code capacity 11 [return -1]
		if not null? code [
			code/1: as byte! 0Fh
			code/2: as byte! (90h + condition)
			code/3: as byte! C0h
			code/4: as byte! 0Fh
			code/5: as byte! either parity = 1 [9Bh][9Ah]
			code/6: as byte! C2h
			code/7: as byte! either parity = 1 [20h][08h]
			code/8: as byte! D0h
			code/9: as byte! 0Fh
			code/10: as byte! B6h
			code/11: as byte! C0h
		]
		11
	]

	frame-address: func [
		code [byte-ptr!]
		capacity target displacement [integer!]
		return: [integer!]
		/local displacement-size size mode [integer!] at [byte-ptr!]
	][
		unless all [target >= 0 target <= 15][return -1]
		displacement-size: either fits-i8? displacement [1][4]
		mode: either displacement-size = 1 [1][2]
		size: 3 + displacement-size
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! rex true target RBP
		at/2: as byte! 8Dh
		at/3: as byte! modrm mode target RBP
		at: at + 3
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	rip-address: func [
		code [byte-ptr!]
		capacity target displacement [integer!]
		return: [integer!]
	][
		unless all [target >= 0 target <= 15 room? code capacity 7][return -1]
		if not null? code [
			code/1: as byte! rex true target RBP
			code/2: as byte! 8Dh
			code/3: as byte! modrm 0 target RBP
			write-i32 (code + 3) displacement
		]
		7
	]

	rip-load: func [
		code [byte-ptr!]
		capacity target displacement [integer!]
		return: [integer!]
	][
		unless all [target >= 0 target <= 15 room? code capacity 7][return -1]
		if not null? code [
			code/1: as byte! rex true target RBP
			code/2: as byte! 8Bh
			code/3: as byte! modrm 0 target RBP
			write-i32 (code + 3) displacement
		]
		7
	]

	load-indirect: func [
		code [byte-ptr!]
		capacity width signed [integer!]
		return: [integer!]
		/local size [integer!]
	][
		unless all [
			any [width = 1 width = 2 width = 4 width = 8]
			any [signed = 0 signed = 1]
		][return -1]
		size: case [width <= 2 [3] width = 4 [2] true [3]]
		unless room? code capacity size [return -1]
		if null? code [return size]
		case [
			width = 1 [
				code/1: as byte! 0Fh
				code/2: as byte! either signed = 1 [BEh][B6h]
				code/3: as byte! 00h
			]
			width = 2 [
				code/1: as byte! 0Fh
				code/2: as byte! either signed = 1 [BFh][B7h]
				code/3: as byte! 00h
			]
			width = 4 [code/1: as byte! 8Bh code/2: as byte! 00h]
			true [
				code/1: as byte! 48h
				code/2: as byte! 8Bh
				code/3: as byte! 00h
			]
		]
		size
	]

	store-indirect: func [
		code [byte-ptr!]
		capacity width [integer!]
		return: [integer!]
		/local size [integer!]
	][
		size: case [
			width = 1 [2]
			width = 2 [3]
			width = 4 [2]
			width = 8 [3]
			true [return -1]
		]
		unless room? code capacity size [return -1]
		if null? code [return size]
		case [
			width = 1 [code/1: as byte! 88h code/2: as byte! 02h]
			width = 2 [
				code/1: as byte! 66h
				code/2: as byte! 89h
				code/3: as byte! 02h
			]
			width = 4 [code/1: as byte! 89h code/2: as byte! 02h]
			true [
				code/1: as byte! 48h
				code/2: as byte! 89h
				code/3: as byte! 02h
			]
		]
		size
	]

	add-immediate: func [
		code [byte-ptr!]
		capacity target value [integer!]
		return: [integer!]
		/local size [integer!] at [byte-ptr!]
	][
		if any [target < 0 target > 15][return -1]
		if value = 0 [return 0]
		size: either fits-i8? value [4][7]
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		at/1: as byte! rex true 0 target
		at: at + 1
		either size = 4 [
			at/1: as byte! 83h
			at/2: as byte! modrm 3 0 target
			at/3: as byte! value
		][
			at/1: as byte! 81h
			at/2: as byte! modrm 3 0 target
			write-i32 (at + 2) value
		]
		size
	]

	; RCX is the source address and RDX is the destination address. The
	; operation advances both and uses RAX and R8 as volatile scratch.
	copy-chunk: func [
		code [byte-ptr!]
		capacity width [integer!]
		advance? [logic!]
		return: [integer!]
		/local at [byte-ptr!] encoded written [integer!]
	][
		written: 0
		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: move-register at (capacity - written) RAX RCX 8
		if encoded < 0 [return -1]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: load-indirect at (capacity - written) width 0
		if encoded < 0 [return -1]
		written: written + encoded

		at: as byte-ptr! 0
		if not null? code [at: code + written]
		encoded: store-indirect at (capacity - written) width
		if encoded < 0 [return -1]
		written: written + encoded

		if advance? [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: add-immediate at (capacity - written) RCX width
			if encoded < 0 [return -1]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: add-immediate at (capacity - written) RDX width
			if encoded < 0 [return -1]
			written: written + encoded
		]
		written
	]

	copy-indirect: func [
		code [byte-ptr!]
		capacity size [integer!]
		return: [integer!]
		/local at [byte-ptr!]
			encoded written remaining chunks width loop-start [integer!]
	][
		if size <= 0 [return -1]
		written: 0
		remaining: size
		chunks: remaining / 8

		either chunks >= 4 [
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: move-immediate at (capacity - written) R8 4 chunks 0
			if encoded < 0 [return -1]
			written: written + encoded
			loop-start: written

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: copy-chunk at (capacity - written) 8 true
			if encoded < 0 [return -1]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: add-immediate at (capacity - written) R8 -1
			if encoded < 0 [return -1]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: test-register at (capacity - written) R8 8
			if encoded < 0 [return -1]
			written: written + encoded

			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: jump-condition at (capacity - written) 5
				(loop-start - (written + 6))
			if encoded < 0 [return -1]
			written: written + encoded
			remaining: remaining - (chunks * 8)
		][
			while [remaining >= 8][
				at: as byte-ptr! 0
				if not null? code [at: code + written]
				encoded: copy-chunk at (capacity - written) 8 (remaining > 8)
				if encoded < 0 [return -1]
				written: written + encoded
				remaining: remaining - 8
			]
		]

		while [remaining > 0][
			width: case [
				remaining >= 4 [4]
				remaining >= 2 [2]
				true [1]
			]
			at: as byte-ptr! 0
			if not null? code [at: code + written]
			encoded: copy-chunk at (capacity - written) width (remaining > width)
			if encoded < 0 [return -1]
			written: written + encoded
			remaining: remaining - width
		]
		written
	]

	outgoing-store: func [
		code [byte-ptr!]
		capacity displacement width [integer!]
		return: [integer!]
		/local displacement-size size [integer!] at [byte-ptr!]
	][
		unless any [width = 4 width = 8][return -1]
		displacement-size: either all [displacement >= 0 displacement <= 127][1][4]
		size: either width = 8 [4][3]
		size: size + displacement-size
		unless room? code capacity size [return -1]
		if null? code [return size]
		at: code
		if width = 8 [at/1: as byte! 48h at: at + 1]
		at/1: as byte! 89h
		at/2: as byte! either displacement-size = 1 [44h][84h]
		at/3: as byte! 24h
		at: at + 3
		either displacement-size = 1 [at/1: as byte! displacement][
			write-i32 at displacement
		]
		size
	]

	call-relative: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
	][
		unless room? code capacity 5 [return -1]
		if not null? code [
			code/1: as byte! E8h
			write-i32 (code + 1) displacement
		]
		5
	]

	call-import: func [
		code [byte-ptr!]
		capacity displacement [integer!]
		return: [integer!]
	][
		unless room? code capacity 6 [return -1]
		if not null? code [
			code/1: as byte! FFh
			code/2: as byte! 15h
			write-i32 (code + 2) displacement
		]
		6
	]

	stack-top: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		unless room? code capacity 3 [return -1]
		if not null? code [
			code/1: as byte! 48h
			code/2: as byte! 89h
			code/3: as byte! E0h
		]
		3
	]

	sign-extend-eax: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		unless room? code capacity 3 [return -1]
		if not null? code [
			code/1: as byte! 48h
			code/2: as byte! 63h
			code/3: as byte! C0h                     ; movsxd rax, eax
		]
		3
	]

	clear-register: func [
		code [byte-ptr!]
		capacity target [integer!]
		return: [integer!]
		/local size [integer!]
	][
		unless all [target >= 0 target <= 15][return -1]
		size: either target >= 8 [3][2]
		unless room? code capacity size [return -1]
		if null? code [return size]
		either target >= 8 [
			code/1: as byte! 45h
			code/2: as byte! 31h
			code/3: as byte! modrm 3 target target
		][
			code/1: as byte! 31h
			code/2: as byte! modrm 3 target target
		]
		size
	]

	leave-return: func [code [byte-ptr!] capacity [integer!] return: [integer!]][
		unless room? code capacity 2 [return -1]
		if not null? code [code/1: as byte! C9h code/2: as byte! C3h]
		2
	]
]
