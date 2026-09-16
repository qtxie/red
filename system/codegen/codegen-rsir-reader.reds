Red/System [
	Title: "Hybrid compiler structural RSIR reader"
	File:  %codegen-rsir-reader.reds
]

#include %codegen-diag.reds

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
	lines             [byte-ptr!]
	file-table        [byte-ptr!]
	strings           [byte-ptr!]
	member-count      [integer!]
	parameter-count   [integer!]
	initializer-count [integer!]
	line-count        [integer!]
	file-count        [integer!]
	strings-size      [integer!]
]

rsir-reader-state!: alias struct! [
	cursor    [byte-ptr!]
	remaining [integer!]
]

codegen-rsir-reader: context [
	RSIR_HEADER_SIZE:      44
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
	RSIR_LINE_SIZE:        16
	RSIR_FILE_ENTRY_SIZE:   8

	INVALID_IR: -1

	fail-invalid: func [site [integer!] site-name [c-string!] return: [integer!]][
		codegen-diag/fail INVALID_IR codegen-diag/FILE_READER site site-name
	]

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
			record [rsir-line-record!]
			entry [rsir-file-entry!]
			id member-count parameter-count initializer-count
			instruction-count next-count previous-function previous-index [integer!]
	][
		if any [
			null? data
			null? as byte-ptr! view
			size < RSIR_HEADER_SIZE
		][return fail-invalid 1 "open/byte-ptr#1"]
		header: as rsir-header! data
		if any [
			header/type-count < 0
			header/import-count < 0
			header/function-count <= 0
			header/instruction-count <= 0
			header/global-count < 0
			header/switch-count < 0
			header/export-count < 0
			header/line-record-count < 0
			header/file-count < 0
			all [header/line-record-count > 0 header/file-count <= 0]
			header/module-kind < 1
			header/module-kind > 4
			all [header/module-kind = 4 header/export-count = 0]
			all [header/module-kind <> 4 header/export-count <> 0]
			all [header/module-kind = 3 any [
				header/entry-function <= 0
				header/entry-function > header/function-count
			]]
			all [header/module-kind <> 3 header/entry-function <> 0]
		][return fail-invalid 2 "open/header/module-kind#2"]

		state/cursor: data + RSIR_HEADER_SIZE
		state/remaining: size - RSIR_HEADER_SIZE
		view/header: header
		view/types: claim state header/type-count RSIR_TYPE_SIZE
		if null? view/types [return fail-invalid 3 "open/view/types#3"]
		member-count: 0
		id: 1
		while [id <= header/type-count][
			type: as rsir-type! (view/types + ((id - 1) * RSIR_TYPE_SIZE))
			if any [type/member-count < 0 type/first-member <> member-count][
				return fail-invalid 4 "open/member-count#4"
			]
			if type/kind <> -7 [
				if member-count > (2147483647 - type/member-count)[return fail-invalid 5 "open/member-count#5"]
				member-count: member-count + type/member-count
			]
			id: id + 1
		]
		view/members: claim state member-count RSIR_MEMBER_SIZE
		if null? view/members [return fail-invalid 6 "open/view/members#6"]

		view/imports: claim state header/import-count RSIR_IMPORT_SIZE
		if null? view/imports [return fail-invalid 7 "open/view/imports#7"]
		parameter-count: 0
		id: 1
		while [id <= header/import-count][
			imported: as rsir-import! (view/imports + ((id - 1) * RSIR_IMPORT_SIZE))
			if any [
				imported/first-parameter <> parameter-count
				imported/parameter-count < 0
				parameter-count > (2147483647 - imported/parameter-count)
			][return fail-invalid 8 "open/imported/parameter-count#8"]
			parameter-count: parameter-count + imported/parameter-count
			id: id + 1
		]

		view/globals: claim state header/global-count RSIR_GLOBAL_SIZE
		if null? view/globals [return fail-invalid 9 "open/view/globals#9"]
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
			][return fail-invalid 10 "open/global/initializer-count#10"]
			initializer-count: initializer-count + global/initializer-count
			id: id + 1
		]

		view/functions: claim state header/function-count RSIR_FUNCTION_SIZE
		if null? view/functions [return fail-invalid 11 "open/view/functions#11"]
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
			][return fail-invalid 12 "open/fn/parameter-count#12"]
			next-count: parameter-count + fn/parameter-count
			if any [
				fn/first-local <> next-count
				next-count > (2147483647 - fn/local-count)
				instruction-count > (2147483647 - fn/instruction-count)
			][return fail-invalid 13 "open/fn/instruction-count#13"]
			parameter-count: next-count + fn/local-count
			instruction-count: instruction-count + fn/instruction-count
			id: id + 1
		]
		if instruction-count <> header/instruction-count [return fail-invalid 14 "open/header/instruction-count#14"]

		view/exports: claim state header/export-count RSIR_EXPORT_SIZE
		if null? view/exports [return fail-invalid 15 "open/view/exports#15"]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			if any [
				exported/symbol = 0
				all [exported/symbol > 0 exported/symbol > header/function-count]
				all [exported/symbol < 0
					exported/symbol < (0 - header/global-count)]
			][return fail-invalid 16 "open/exported/symbol#16"]
			id: id + 1
		]

		view/parameters: claim state parameter-count RSIR_PARAMETER_SIZE
		if null? view/parameters [return fail-invalid 17 "open/view/parameters#17"]
		view/initializers: claim state initializer-count RSIR_INITIALIZER_SIZE
		if null? view/initializers [return fail-invalid 18 "open/view/initializers#18"]
		view/switches: claim state header/switch-count RSIR_SWITCH_SIZE
		if null? view/switches [return fail-invalid 19 "open/view/switches#19"]
		view/instructions: claim state header/instruction-count RSIR_INSTRUCTION_SIZE
		if null? view/instructions [return fail-invalid 20 "open/view/instructions#20"]
		view/lines: claim state header/line-record-count RSIR_LINE_SIZE
		if null? view/lines [return fail-invalid 40 "open/view/lines#40"]
		view/file-table: claim state header/file-count RSIR_FILE_ENTRY_SIZE
		if null? view/file-table [return fail-invalid 41 "open/view/file-table#41"]
		view/line-count: header/line-record-count
		view/file-count: header/file-count
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
			][return fail-invalid 21 "open/imported/external#21"]
			id: id + 1
		]
		id: 1
		while [id <= header/global-count][
			global: as rsir-global! (view/globals + ((id - 1) * RSIR_GLOBAL_SIZE))
			unless span? global/name global/name-size view/strings-size [return fail-invalid 22 "open/global/name#22"]
			if global/initializer-count > 0 [
				initializer: as rsir-initializer! (view/initializers
					+ (global/first-initializer * RSIR_INITIALIZER_SIZE))
				if all [
					initializer/kind = 3
					not span? initializer/a initializer/b view/strings-size
				][return fail-invalid 23 "open/initializer/a#23"]
			]
			id: id + 1
		]
		id: 1
		while [id <= header/function-count][
			fn: as rsir-function! (view/functions + ((id - 1) * RSIR_FUNCTION_SIZE))
			unless all [
				fn/name-size > 0
				span? fn/name fn/name-size view/strings-size
			][return fail-invalid 24 "open/fn/name#24"]
			id: id + 1
		]
		id: 1
		while [id <= header/export-count][
			exported: as rsir-export! (view/exports + ((id - 1) * RSIR_EXPORT_SIZE))
			unless all [
				exported/name-size > 0
				span? exported/name exported/name-size view/strings-size
			][return fail-invalid 25 "open/exported/name#25"]
			id: id + 1
		]

		view/member-count: member-count
		view/parameter-count: parameter-count
		view/initializer-count: initializer-count

		; Debug line records must ascend by (function-id, instruction-index) so
		; the code generator can mirror them without reordering.
		if view/line-count > 0 [
			previous-function: 0
			previous-index: 0
			id: 1
			while [id <= view/line-count][
				record: as rsir-line-record! (view/lines + ((id - 1) * RSIR_LINE_SIZE))
				if any [
					record/function-id <= 0
					record/function-id > header/function-count
					record/instruction-index <= 0
					record/line <= 0
					record/file-id <= 0
					record/file-id > view/file-count
				][return fail-invalid 42 "open/line-record/function-id#42"]
				if record/function-id = previous-function [
					if record/instruction-index <= previous-index [
						return fail-invalid 43 "open/line-record/instruction-index#43"
					]
				]
				if record/function-id < previous-function [
					return fail-invalid 44 "open/line-record/ordering#44"
				]
				either record/function-id = previous-function [
					previous-index: record/instruction-index
				][
					previous-function: record/function-id
					previous-index: record/instruction-index
				]
				id: id + 1
			]
			; Every instruction index must fall inside its function's stream.
			id: 1
			while [id <= view/line-count][
				record: as rsir-line-record! (view/lines + ((id - 1) * RSIR_LINE_SIZE))
				fn: as rsir-function! (view/functions
					+ ((record/function-id - 1) * RSIR_FUNCTION_SIZE))
				if record/instruction-index > fn/instruction-count [
					return fail-invalid 45 "open/line-record/instruction-index#45"
				]
				id: id + 1
			]
		]
		id: 1
		while [id <= view/file-count][
			entry: as rsir-file-entry! (view/file-table + ((id - 1) * RSIR_FILE_ENTRY_SIZE))
			unless all [
				entry/name-size > 0
				span? entry/name-offset entry/name-size view/strings-size
			][return fail-invalid 46 "open/file-entry/name#46"]
			id: id + 1
		]
		0
	]
]
