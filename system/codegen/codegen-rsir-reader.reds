Red/System [
	Title: "Hybrid compiler structural RSIR reader"
	File:  %codegen-rsir-reader.reds
]

; The reader deliberately validates only the architecture-neutral table
; topology. Type semantics and ABI restrictions belong to each code generator.
rsir-view!: alias struct! [
	header            [rsir-header!]
	types             [byte-ptr!]
	members           [byte-ptr!]
	imports           [byte-ptr!]
	globals           [byte-ptr!]
	functions         [byte-ptr!]
	exports           [byte-ptr!]
	parameters        [byte-ptr!]
	initializers      [byte-ptr!]
	switches          [byte-ptr!]
	instructions      [byte-ptr!]
	strings           [byte-ptr!]
	member-count      [integer!]
	parameter-count   [integer!]
	initializer-count [integer!]
	strings-size      [integer!]
]

rsir-reader-state!: alias struct! [
	cursor    [byte-ptr!]
	remaining [integer!]
]

codegen-rsir-reader: context [
	RSIR_HEADER_SIZE:      36
	RSIR_TYPE_SIZE:        20
	RSIR_MEMBER_SIZE:       8
	RSIR_IMPORT_SIZE:      32
	RSIR_GLOBAL_SIZE:      24
	RSIR_FUNCTION_SIZE:    36
	RSIR_EXPORT_SIZE:      12
	RSIR_PARAMETER_SIZE:    8
	RSIR_INITIALIZER_SIZE: 16
	RSIR_SWITCH_SIZE:      12
	RSIR_INSTRUCTION_SIZE: 16

	INVALID_IR: -1

	claim: func [
		state [rsir-reader-state!]
		count row-size [integer!]
		return: [byte-ptr!]
		/local table [byte-ptr!] bytes [integer!]
	][
		if any [count < 0 row-size <= 0 count > (state/remaining / row-size)][
			return null
		]
		bytes: count * row-size
		table: state/cursor
		state/cursor: table + bytes
		state/remaining: state/remaining - bytes
		table
	]

	span?: func [offset length total [integer!] return: [logic!]][
		all [
			offset >= 0
			length >= 0
			length <= total
			offset <= (total - length)
		]
	]

	open: func [
		data [byte-ptr!]
		size [integer!]
		view [rsir-view!]
		return: [integer!]
		/local state [rsir-reader-state! value]
			header [rsir-header!]
			type [rsir-type!]
			imported [rsir-import!]
			global [rsir-global!]
			fn [rsir-function!]
			exported [rsir-export!]
			initializer [rsir-initializer!]
			id member-count parameter-count initializer-count
			instruction-count next-count [integer!]
	][
		if any [
			null? data
			null? as byte-ptr! view
			size < RSIR_HEADER_SIZE
		][return INVALID_IR]
		header: as rsir-header! data
		if any [
			header/type-count < 0
			header/import-count < 0
			header/function-count <= 0
			header/instruction-count <= 0
			header/global-count < 0
			header/switch-count < 0
			header/export-count < 0
			header/module-kind < 1
			header/module-kind > 4
			all [header/module-kind = 4 header/export-count = 0]
			all [header/module-kind <> 4 header/export-count <> 0]
			all [header/module-kind = 3 any [
				header/entry-function <= 0
				header/entry-function > header/function-count
			]]
			all [header/module-kind <> 3 header/entry-function <> 0]
		][return INVALID_IR]

		state/cursor: data + RSIR_HEADER_SIZE
		state/remaining: size - RSIR_HEADER_SIZE
		view/header: header
		view/types: claim state header/type-count RSIR_TYPE_SIZE
		if null? view/types [return INVALID_IR]
		member-count: 0
		id: 1
		while [id <= header/type-count][
			type: as rsir-type! (view/types + ((id - 1) * RSIR_TYPE_SIZE))
			if any [type/member-count < 0 type/first-member <> member-count][
				return INVALID_IR
			]
			if type/kind <> -7 [
				if member-count > (2147483647 - type/member-count)[return INVALID_IR]
				member-count: member-count + type/member-count
			]
			id: id + 1
		]
		view/members: claim state member-count RSIR_MEMBER_SIZE
		if null? view/members [return INVALID_IR]

		view/imports: claim state header/import-count RSIR_IMPORT_SIZE
		if null? view/imports [return INVALID_IR]
		parameter-count: 0
		id: 1
		while [id <= header/import-count][
			imported: as rsir-import! (view/imports + ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				imported/first-parameter <> parameter-count
				imported/parameter-count < 0
				parameter-count > (2147483647 - imported/parameter-count)
			][return INVALID_IR]
			parameter-count: parameter-count + imported/parameter-count
			id: id + 1
		]

		view/globals: claim state header/global-count RSIR_GLOBAL_SIZE
		if null? view/globals [return INVALID_IR]
		initializer-count: 0
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			if any [
				global/first-initializer < 0
				global/initializer-count < 0
				all [global/initializer-count = 0 global/first-initializer <> 0]
				all [global/initializer-count > 0
					global/first-initializer <> initializer-count]
				initializer-count > (2147483647 - global/initializer-count)
			][return INVALID_IR]
			initializer-count: initializer-count + global/initializer-count
			id: id + 1
		]

		view/functions: claim state header/function-count RSIR_FUNCTION_SIZE
		if null? view/functions [return INVALID_IR]
		instruction-count: 0
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			if any [
				fn/first-parameter <> parameter-count
				fn/parameter-count < 0
				fn/local-count < 0
				fn/instruction-count <= 0
				parameter-count > (2147483647 - fn/parameter-count)
			][return INVALID_IR]
			next-count: parameter-count + fn/parameter-count
			if any [
				fn/first-local <> next-count
				next-count > (2147483647 - fn/local-count)
				instruction-count > (2147483647 - fn/instruction-count)
			][return INVALID_IR]
			parameter-count: next-count + fn/local-count
			instruction-count: instruction-count + fn/instruction-count
			id: id + 1
		]
		if instruction-count <> header/instruction-count [return INVALID_IR]

		view/exports: claim state header/export-count RSIR_EXPORT_SIZE
		if null? view/exports [return INVALID_IR]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				exported/symbol = 0
				all [exported/symbol > 0 exported/symbol > header/function-count]
				all [exported/symbol < 0
					exported/symbol < (0 - header/global-count)]
			][return INVALID_IR]
			id: id + 1
		]

		view/parameters: claim state parameter-count RSIR_PARAMETER_SIZE
		if null? view/parameters [return INVALID_IR]
		view/initializers: claim state initializer-count RSIR_INITIALIZER_SIZE
		if null? view/initializers [return INVALID_IR]
		view/switches: claim state header/switch-count RSIR_SWITCH_SIZE
		if null? view/switches [return INVALID_IR]
		view/instructions: claim state header/instruction-count RSIR_INSTRUCTION_SIZE
		if null? view/instructions [return INVALID_IR]
		view/strings: state/cursor
		view/strings-size: state/remaining

		id: 1
		while [id <= header/import-count][
			imported: as rsir-import! (view/imports + ((id - 1) * RSIR_IMPORT_SIZE))
			unless all [
				imported/library-size > 0
				span? imported/library imported/library-size view/strings-size
				imported/external-size > 0
				span? imported/external imported/external-size view/strings-size
			][return INVALID_IR]
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			unless span? global/name global/name-size view/strings-size [return INVALID_IR]
			if global/initializer-count > 0 [
				initializer: as rsir-initializer! (view/initializers
					+ (global/first-initializer * RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = 3
					not span? initializer/a initializer/b view/strings-size
				][return INVALID_IR]
			]
			id: id + 1
		]
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			unless all [
				fn/name-size > 0
				span? fn/name fn/name-size view/strings-size
			][return INVALID_IR]
			id: id + 1
		]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			unless all [
				exported/name-size > 0
				span? exported/name exported/name-size view/strings-size
			][return INVALID_IR]
			id: id + 1
		]

		view/member-count: member-count
		view/parameter-count: parameter-count
		view/initializer-count: initializer-count
		0
	]
]
