Red/System [
	Title: "Windows x64 encoder for the hybrid compiler"
	File:  %x64-encoder.reds
]

x64-encoder: context [
	VOID:        0
	I32_LITERAL: 1
	I32_CALL:    2
	I32_PARAM:   3
	I32_CALL_ARG_LITERAL: 4
	I32_CALL_ARG_PARAM:   5

	VOID_SIZE:       17
	VOID_ENTRY_SIZE: 31
	I32_SIZE:         22
	I32_ENTRY_SIZE:   34
	CALL_SIZE:        22
	CALL_ENTRY_SIZE:  36
	PARAM_SIZE:       19
	CALL_ARG_LITERAL_SIZE:       27
	CALL_ARG_LITERAL_ENTRY_SIZE: 41
	CALL_ARG_PARAM_SIZE:         22
	FRAME_SIZE:      32
	BITMAP_OFFSET:    9
	VOID_EXIT_REF:   23
	I32_EXIT_REF:    26
	CALL_EXIT_REF:   28
	CALL_NEXT:       20
	CALL_ARG_LITERAL_EXIT_REF: 33
	CALL_ARG_LITERAL_NEXT:     25

	write-i32: func [at [byte-ptr!] value [integer!]][
		at/1: as byte! value
		at/2: as byte! (value >>> 8)
		at/3: as byte! (value >>> 16)
		at/4: as byte! (value >>> 24)
	]

	encode: func [
		code [byte-ptr!]
		capacity [integer!]
		entry? [logic!]
		shape [integer!]
		value argument bitmap-word [integer!]
		return: [integer!]
		/local size [integer!] at [byte-ptr!]
	][
		if null? code [return -1]
		size: case [
			all [entry? shape = VOID] [VOID_ENTRY_SIZE]
			all [entry? shape = I32_LITERAL] [I32_ENTRY_SIZE]
			all [entry? shape = I32_CALL] [CALL_ENTRY_SIZE]
			all [entry? shape = I32_CALL_ARG_LITERAL] [CALL_ARG_LITERAL_ENTRY_SIZE]
			all [not entry? shape = VOID] [VOID_SIZE]
			all [not entry? shape = I32_LITERAL] [I32_SIZE]
			all [not entry? shape = I32_CALL] [CALL_SIZE]
			all [not entry? shape = I32_PARAM] [PARAM_SIZE]
			all [not entry? shape = I32_CALL_ARG_LITERAL] [CALL_ARG_LITERAL_SIZE]
			all [not entry? shape = I32_CALL_ARG_PARAM] [CALL_ARG_PARAM_SIZE]
			true [return -1]
		]
		if capacity < size [return -1]

		at: code
		at/1: as byte! 55h                             ; push rbp
		at/2: as byte! 48h
		at/3: as byte! 89h
		at/4: as byte! E5h                             ; mov rbp, rsp
		at/5: as byte! 6Ah
		at/6: as byte! 00h                             ; catch ID
		at/7: as byte! 6Ah
		at/8: as byte! 00h                             ; catch resume
		at/9: as byte! 68h                             ; push bitmap word offset
		write-i32 (at + 9) bitmap-word
		at/14: as byte! 6Ah
		at/15: as byte! 00h                            ; parent frame
		at: at + 15

		case [
			shape = I32_LITERAL [
				at/1: as byte! either entry? [B9h][B8h] ; mov ecx/eax, imm32
				write-i32 (at + 1) value
				at: at + 5
			]
			shape = I32_CALL [
				at/1: as byte! E8h                       ; call rel32
				write-i32 (at + 1) value
				at: at + 5
				if entry? [
					at/1: as byte! 89h
					at/2: as byte! C1h                   ; mov ecx, eax
					at: at + 2
				]
			]
			shape = I32_PARAM [
				at/1: as byte! 89h
				at/2: as byte! C8h                       ; mov eax, ecx
				at: at + 2
			]
			shape = I32_CALL_ARG_LITERAL [
				at/1: as byte! B9h                       ; mov ecx, imm32
				write-i32 (at + 1) argument
				at/6: as byte! E8h                       ; call rel32
				write-i32 (at + 6) value
				at: at + 10
				if entry? [
					at/1: as byte! 89h
					at/2: as byte! C1h                   ; mov ecx, eax
					at: at + 2
				]
			]
			shape = I32_CALL_ARG_PARAM [
				at/1: as byte! E8h                       ; RCX already holds argument
				write-i32 (at + 1) value
				at: at + 5
			]
			true []
		]
		if all [entry? shape = VOID] [
			at/1: as byte! 31h
			at/2: as byte! C9h                           ; xor ecx, ecx
			at: at + 2
		]
		if entry? [
			at/1: as byte! 48h
			at/2: as byte! 83h
			at/3: as byte! ECh
			at/4: as byte! 20h                           ; Win64 shadow space
			at/5: as byte! FFh
			at/6: as byte! 15h                           ; call [rip + rel32]
			write-i32 (at + 6) 0
			at/11: as byte! 31h
			at/12: as byte! C0h                          ; unreachable fallback
			at: at + 12
		]
		at/1: as byte! C9h                             ; leave
		at/2: as byte! C3h                             ; ret
		size
	]
]
