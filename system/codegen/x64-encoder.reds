Red/System [
	Title: "Windows x64 encoder for the hybrid compiler"
	File:  %x64-encoder.reds
]

x64-encoder: context [
	NONE: 0
	PROLOG: 1
	SHADOW: 2
	I32_CALL: 3
	I32_CALL_LITERAL: 4
	I32_CALL_PARAM: 5
	I32_CALL_RAX: 6
	I32_IMPORT: 7
	I32_IMPORT_LITERAL: 8
	I32_IMPORT_PARAM: 9
	I32_IMPORT_RAX: 10
	I32_GLOBAL: 11
	I32_IMPORT_LOAD: 12
	SCALAR_IMPORT_STORE: 13
	RETURN_VOID: 14
	RETURN_RAX: 15
	RETURN_PARAM: 16
	RETURN_LITERAL: 17
	ENTRY_VOID: 18
	ENTRY_RAX: 19
	ENTRY_PARAM: 20
	ENTRY_LITERAL: 21

	SHADOW_FLAG: 256
	FORM_MASK: 255
	FRAME_SIZE: 32
	BITMAP_OFFSET: 9

	form-size: func [form [integer!] return: [integer!]][
		case [
			form = NONE [0]
			form = PROLOG [15]
			form = SHADOW [4]
			form = I32_CALL [5]
			form = I32_CALL_LITERAL [10]
			form = I32_CALL_PARAM [5]
			form = I32_CALL_RAX [7]
			form = I32_IMPORT [6]
			form = I32_IMPORT_LITERAL [11]
			form = I32_IMPORT_PARAM [6]
			form = I32_IMPORT_RAX [8]
			form = I32_GLOBAL [6]
			form = I32_IMPORT_LOAD [9]
			form = SCALAR_IMPORT_STORE [13]
			form = RETURN_VOID [2]
			form = RETURN_RAX [2]
			form = RETURN_PARAM [4]
			form = RETURN_LITERAL [7]
			form = ENTRY_VOID [12]
			form = ENTRY_RAX [12]
			form = ENTRY_PARAM [10]
			form = ENTRY_LITERAL [15]
			true [-1]
		]
	]

	reference-offset: func [form [integer!] return: [integer!]][
		case [
			form = I32_IMPORT [2]
			form = I32_IMPORT_LITERAL [7]
			form = I32_IMPORT_PARAM [2]
			form = I32_IMPORT_RAX [4]
			form = I32_GLOBAL [2]
			form = I32_IMPORT_LOAD [3]
			form = SCALAR_IMPORT_STORE [3]
			form = ENTRY_VOID [4]
			form = ENTRY_RAX [4]
			form = ENTRY_PARAM [2]
			form = ENTRY_LITERAL [7]
			true [-1]
		]
	]

	call-next: func [form [integer!] return: [integer!]][
		case [
			form = I32_CALL [5]
			form = I32_CALL_LITERAL [10]
			form = I32_CALL_PARAM [5]
			form = I32_CALL_RAX [7]
			true [-1]
		]
	]

	write-i32: func [at [byte-ptr!] value [integer!]][
		at/1: as byte! value
		at/2: as byte! (value >>> 8)
		at/3: as byte! (value >>> 16)
		at/4: as byte! (value >>> 24)
	]

	encode: func [
		code [byte-ptr!]
		capacity form value argument [integer!]
		return: [integer!]
		/local size [integer!] at [byte-ptr!]
	][
		if null? code [return -1]
		size: form-size form
		if any [size < 0 capacity < size][return -1]
		at: code

		case [
			form = PROLOG [
				at/1: as byte! 55h                         ; push rbp
				at/2: as byte! 48h
				at/3: as byte! 89h
				at/4: as byte! E5h                         ; mov rbp, rsp
				at/5: as byte! 6Ah
				at/6: as byte! 00h                         ; catch ID
				at/7: as byte! 6Ah
				at/8: as byte! 00h                         ; catch resume
				at/9: as byte! 68h                         ; bitmap word offset
				write-i32 (at + 9) argument
				at/14: as byte! 6Ah
				at/15: as byte! 00h                        ; parent frame
			]
			form = SHADOW [
				at/1: as byte! 48h
				at/2: as byte! 83h
				at/3: as byte! ECh
				at/4: as byte! 20h                         ; Win64 shadow space
			]
			form = I32_CALL [
				at/1: as byte! E8h
				write-i32 (at + 1) value
			]
			form = I32_CALL_LITERAL [
				at/1: as byte! B9h                         ; mov ecx, imm32
				write-i32 (at + 1) argument
				at/6: as byte! E8h
				write-i32 (at + 6) value
			]
			form = I32_CALL_PARAM [
				at/1: as byte! E8h                         ; RCX already holds argument
				write-i32 (at + 1) value
			]
			form = I32_CALL_RAX [
				at/1: as byte! 89h
				at/2: as byte! C1h                         ; mov ecx, eax
				at/3: as byte! E8h
				write-i32 (at + 3) value
			]
			form = I32_IMPORT [
				at/1: as byte! FFh
				at/2: as byte! 15h                         ; call [rip + rel32]
				write-i32 (at + 2) 0
			]
			form = I32_IMPORT_LITERAL [
				at/1: as byte! B9h
				write-i32 (at + 1) argument
				at/6: as byte! FFh
				at/7: as byte! 15h
				write-i32 (at + 7) 0
			]
			form = I32_IMPORT_PARAM [
				at/1: as byte! FFh
				at/2: as byte! 15h                         ; RCX already holds argument
				write-i32 (at + 2) 0
			]
			form = I32_IMPORT_RAX [
				at/1: as byte! 89h
				at/2: as byte! C1h                         ; mov ecx, eax
				at/3: as byte! FFh
				at/4: as byte! 15h
				write-i32 (at + 4) 0
			]
			form = I32_GLOBAL [
				at/1: as byte! 8Bh
				at/2: as byte! 05h                         ; mov eax, [rip + rel32]
				write-i32 (at + 2) 0
			]
			form = I32_IMPORT_LOAD [
				at/1: as byte! 48h
				at/2: as byte! 8Bh
				at/3: as byte! 05h                         ; mov rax, [rip + rel32]
				write-i32 (at + 3) 0
				at/8: as byte! 8Bh
				at/9: as byte! 00h                         ; mov eax, [rax]
			]
			form = SCALAR_IMPORT_STORE [
				at/1: as byte! 48h
				at/2: as byte! 8Bh
				at/3: as byte! 05h                         ; mov rax, [rip + rel32]
				write-i32 (at + 3) 0
				at/8: as byte! C7h
				at/9: as byte! 00h                         ; mov dword [rax], imm32
				write-i32 (at + 9) value
			]
			any [form = RETURN_VOID form = RETURN_RAX] []
			form = RETURN_PARAM [
				at/1: as byte! 89h
				at/2: as byte! C8h                         ; mov eax, ecx
				at: at + 2
			]
			form = RETURN_LITERAL [
				at/1: as byte! B8h                         ; mov eax, imm32
				write-i32 (at + 1) value
				at: at + 5
			]
			form = ENTRY_VOID [
				at/1: as byte! 31h
				at/2: as byte! C9h                         ; xor ecx, ecx
				at: at + 2
			]
			form = ENTRY_RAX [
				at/1: as byte! 89h
				at/2: as byte! C1h                         ; mov ecx, eax
				at: at + 2
			]
			form = ENTRY_PARAM []
			form = ENTRY_LITERAL [
				at/1: as byte! B9h                         ; mov ecx, imm32
				write-i32 (at + 1) value
				at: at + 5
			]
			true [return -1]
		]

		if form >= ENTRY_VOID [
			at/1: as byte! FFh
			at/2: as byte! 15h                           ; call [rip + rel32]
			write-i32 (at + 2) 0
			at/7: as byte! 31h
			at/8: as byte! C0h                           ; unreachable fallback
			at: at + 8
		]
		if form >= RETURN_VOID [
			at/1: as byte! C9h                           ; leave
			at/2: as byte! C3h                           ; ret
		]
		size
	]
]
