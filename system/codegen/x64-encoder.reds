Red/System [
	Title: "Hybrid compiler Windows x64 instruction encoder"
	File:  %x64-encoder.reds
]

#include %wire-arena.reds

wire-x64-encoder: context [
	ERROR_SUCCESS:   0
	ERROR_ARGUMENTS: 1

	EMPTY_VOID_FUNCTION_SIZE:        17
	EMPTY_VOID_ENTRY_FUNCTION_SIZE:  31
	EMPTY_VOID_BITMAP_PATCH_OFFSET:   9
	EMPTY_VOID_ENTRY_RELOCATION_OFFSET: 23
	EMPTY_VOID_FRAME_SIZE:           32

	emit-u8: func [
		arena [wire-arena!]
		value [integer!]
		return: [integer!]
		/local status offset [integer!] destination [byte-ptr!]
	][
		if any [null? arena value < 0 value > 255][return ERROR_ARGUMENTS]
		status: wire-arena/ensure arena 1
		if status <> wire-arena/ERROR_SUCCESS [return status]
		offset: arena/size
		destination: arena/data + offset
		destination/1: as byte! value
		arena/size: offset + 1
		ERROR_SUCCESS
	]

	emit-u32: func [
		arena [wire-arena!]
		value [integer!]
		return: [integer!]
		/local status offset [integer!] destination [byte-ptr!]
	][
		if null? arena [return ERROR_ARGUMENTS]
		status: wire-arena/ensure arena 4
		if status <> wire-arena/ERROR_SUCCESS [return status]
		offset: arena/size
		destination: arena/data + offset
		destination/1: as byte! value
		destination/2: as byte! (value >>> 8)
		destination/3: as byte! (value >>> 16)
		destination/4: as byte! (value >>> 24)
		arena/size: offset + 4
		ERROR_SUCCESS
	]

	encode-empty-void: func [
		arena [wire-arena!]
		entry? [logic!]
		return: [integer!]
		/local start status [integer!]
	][
		if null? arena [return ERROR_ARGUMENTS]
		start: arena/size
		status: emit-u8 arena 55h                 ; PUSH rbp
		if status = ERROR_SUCCESS [status: emit-u8 arena 48h]
		if status = ERROR_SUCCESS [status: emit-u8 arena 89h]
		if status = ERROR_SUCCESS [status: emit-u8 arena E5h] ; MOV rbp, rsp
		if status = ERROR_SUCCESS [status: emit-u8 arena 6Ah]
		if status = ERROR_SUCCESS [status: emit-u8 arena 00h] ; catch ID
		if status = ERROR_SUCCESS [status: emit-u8 arena 6Ah]
		if status = ERROR_SUCCESS [status: emit-u8 arena 00h] ; catch resume
		if status = ERROR_SUCCESS [status: emit-u8 arena 68h] ; PUSH imm32
		if status = ERROR_SUCCESS [status: emit-u32 arena 0]  ; bitmap patch
		if status = ERROR_SUCCESS [status: emit-u8 arena 6Ah]
		if status = ERROR_SUCCESS [status: emit-u8 arena 00h] ; parent frame
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 31h]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena C9h] ; XOR ecx, ecx
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 48h]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 83h]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena ECh]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 20h] ; shadow space
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena FFh]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 15h]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u32 arena 0] ; IAT relocation
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena 31h]
		if all [status = ERROR_SUCCESS entry?] [status: emit-u8 arena C0h] ; unreachable fallback
		if status = ERROR_SUCCESS [status: emit-u8 arena C9h] ; LEAVE
		if status = ERROR_SUCCESS [status: emit-u8 arena C3h] ; RET
		if status <> ERROR_SUCCESS [arena/size: start]
		status
	]

	encode-empty-void-function: func [
		arena [wire-arena!]
		return: [integer!]
	][
		encode-empty-void arena false
	]

	encode-empty-void-entry: func [
		arena [wire-arena!]
		return: [integer!]
	][
		encode-empty-void arena true
	]
]
