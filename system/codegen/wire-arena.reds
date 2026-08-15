Red/System [
	Title: "Hybrid compiler bounded native arena"
	File:  %wire-arena.reds
]

wire-arena!: alias struct! [
	data     [byte-ptr!]
	size     [integer!]
	capacity [integer!]
	limit    [integer!]
	error    [integer!]
]

wire-arena: context [
	ERROR_SUCCESS:    0
	ERROR_ARGUMENTS:  1
	ERROR_OVERFLOW:   2
	ERROR_LIMIT:      3
	ERROR_ALLOCATION: 4

	max-scalar: 7FFFFFFFh
	default-capacity: 256

	reset: func [arena [wire-arena!]][
		if null? arena [exit]
		arena/data: null
		arena/size: 0
		arena/capacity: 0
		arena/limit: 0
		arena/error: ERROR_SUCCESS
	]

	fail: func [
		arena [wire-arena!]
		code [integer!]
		return: [integer!]
	][
		if arena <> null [arena/error: code]
		code
	]

	init: func [
		arena [wire-arena!]
		limit initial-capacity [integer!]
		return: [integer!]
		/local capacity [integer!] memory [byte-ptr!]
	][
		if null? arena [return ERROR_ARGUMENTS]
		reset arena
		if any [limit < 0 initial-capacity < 0 limit > max-scalar][
			return fail arena ERROR_ARGUMENTS
		]
		if initial-capacity > limit [
			return fail arena ERROR_LIMIT
		]
		arena/limit: limit
		capacity: initial-capacity
		if all [capacity = 0 limit > 0][
			capacity: either limit < default-capacity [limit][default-capacity]
		]
		if capacity = 0 [return ERROR_SUCCESS]
		memory: libC.malloc capacity
		if null? memory [return fail arena ERROR_ALLOCATION]
		arena/data: memory
		arena/capacity: capacity
		ERROR_SUCCESS
	]

	release: func [arena [wire-arena!]][
		if null? arena [exit]
		if arena/data <> null [libC.free arena/data]
		reset arena
	]

	checked-add: func [left right [integer!] return: [integer!]][
		if any [left < 0 right < 0 left > (max-scalar - right)][return -1]
		left + right
	]

	ensure: func [
		arena [wire-arena!]
		additional [integer!]
		return: [integer!]
		/local required capacity doubled [integer!] memory [byte-ptr!]
	][
		if null? arena [return ERROR_ARGUMENTS]
		if arena/error <> ERROR_SUCCESS [return arena/error]
		required: checked-add arena/size additional
		if required < 0 [return fail arena ERROR_OVERFLOW]
		if required > arena/limit [return fail arena ERROR_LIMIT]
		if required <= arena/capacity [return ERROR_SUCCESS]

		capacity: arena/capacity
		if capacity = 0 [
			capacity: either arena/limit < default-capacity [
				arena/limit
			][default-capacity]
		]
		while [capacity < required][
			either capacity > (arena/limit / 2) [
				capacity: arena/limit
			][
				doubled: capacity * 2
				if doubled <= capacity [
					return fail arena ERROR_OVERFLOW
				]
				capacity: doubled
			]
		]
		memory: either arena/data = null [
			libC.malloc capacity
		][
			libC.realloc arena/data capacity
		]
		if null? memory [return fail arena ERROR_ALLOCATION]
		arena/data: memory
		arena/capacity: capacity
		ERROR_SUCCESS
	]

	append: func [
		arena [wire-arena!]
		data [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local status [integer!] destination [byte-ptr!]
	][
		if any [null? arena count < 0 all [count > 0 null? data]][
			return fail arena ERROR_ARGUMENTS
		]
		status: ensure arena count
		if status <> ERROR_SUCCESS [return status]
		if count = 0 [return ERROR_SUCCESS]
		destination: arena/data + arena/size
		copy-memory destination data count
		arena/size: arena/size + count
		ERROR_SUCCESS
	]

	append-zero: func [
		arena [wire-arena!]
		count [integer!]
		return: [integer!]
		/local status [integer!] destination [byte-ptr!]
	][
		if any [null? arena count < 0][return fail arena ERROR_ARGUMENTS]
		status: ensure arena count
		if status <> ERROR_SUCCESS [return status]
		if count = 0 [return ERROR_SUCCESS]
		destination: arena/data + arena/size
		set-memory destination as byte! 0 count
		arena/size: arena/size + count
		ERROR_SUCCESS
	]

	align: func [
		arena [wire-arena!]
		alignment [integer!]
		return: [integer!]
		/local remainder padding [integer!]
	][
		if any [null? arena alignment <= 0 (alignment and (alignment - 1)) <> 0][
			return fail arena ERROR_ARGUMENTS
		]
		remainder: arena/size // alignment
		padding: either remainder = 0 [0][alignment - remainder]
		append-zero arena padding
	]
]
