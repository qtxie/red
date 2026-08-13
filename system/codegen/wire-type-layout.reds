Red/System [
	Title: "Hybrid compiler RSIR type and aggregate-layout verifier"
	File:  %wire-type-layout.reds
]

#include %wire-file-source.reds
#include %wire-data-layout.reds

wire-type-layout-result!: alias struct! [
	error             [integer!]
	container-error   [integer!]
	string-error      [integer!]
	file-source-error [integer!]
	data-layout-error [integer!]
	error-offset      [integer!]
	error-section     [integer!]
]

wire-type-layout!: alias struct! [
	types                 [byte-ptr!]
	type-count            [integer!]
	type-record-size      [integer!]
	types-offset          [integer!]
	types-ordinal         [integer!]
	fields                [byte-ptr!]
	field-count           [integer!]
	field-record-size     [integer!]
	fields-offset         [integer!]
	fields-ordinal        [integer!]
	signature-count       [integer!]
	source-location-count [integer!]
]

wire-type-layout-reader: context [
	set-error: func [
		result [wire-type-layout-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	section-flags-offset: func [
		section [wire-section-slice!]
		return: [integer!]
	][
		WIRE_HEADER_SIZE
			+ (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
				+ WIRE_DIRECTORY_FLAGS_OFFSET)
	]

	aggregate-kind?: func [kind [integer!] return: [logic!]][
		any [
			kind = WIRE_TYPE_KIND_STRUCT
			kind = WIRE_TYPE_KIND_UNION
		]
	]

	valid-flags?: func [kind flags [integer!] return: [logic!]][
		case [
			kind = WIRE_TYPE_KIND_INTEGER [
				return any [
					flags = 0
					flags = WIRE_TYPE_FLAG_SIGNED
				]
			]
			kind = WIRE_TYPE_KIND_POINTER [
				return any [flags = 0 flags = WIRE_TYPE_FLAG_C_STRING]
			]
			kind = WIRE_TYPE_KIND_UNION [
				return any [flags = 0 flags = WIRE_TYPE_FLAG_TAGGED]
			]
			true [return flags = 0]
		]
	]

	align-offset: func [
		offset alignment [integer!]
		return: [integer!]
		/local remainder padding [integer!]
	][
		if any [offset < 0 alignment <= 0][return -1]
		remainder: offset // alignment
		if remainder = 0 [return offset]
		padding: alignment - remainder
		wire-container-reader/checked-add offset padding
	]

	first-bad-scalar: func [
		record [byte-ptr!]
		word-count [integer!]
		return: [integer!]
		/local index relative value [integer!]
	][
		index: 0
		while [index < word-count][
			relative: index * 4
			value: wire-container-reader/read-i31 record relative
			if value < 0 [return relative]
			index: index + 1
		]
		-1
	]

	type-record-offset: func [
		types [wire-section-slice!]
		id [integer!]
		return: [integer!]
	][
		types/offset + ((id - 1) * WIRE_RSIR_TYPE_SIZE)
	]

	field-record-offset: func [
		fields [wire-section-slice!]
		id [integer!]
		return: [integer!]
	][
		fields/offset + ((id - 1) * WIRE_RSIR_FIELD_SIZE)
	]

	type-value: func [
		types [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31
			types/data (((id - 1) * WIRE_RSIR_TYPE_SIZE) + field-offset)
	]

	field-value: func [
		fields [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31
			fields/data (((id - 1) * WIRE_RSIR_FIELD_SIZE) + field-offset)
	]

	nonempty-string?: func [
		strings [wire-string-table!]
		id [integer!]
		return: [logic!]
		/local slice [wire-string-slice!]
	][
		slice: declare wire-string-slice!
		all [
			wire-string-table-reader/get-slice strings id slice
			slice/size > 0
		]
	]

	copy-strings: func [
		destination source [wire-string-table!]
	][
		destination/records: source/records
		destination/record-count: source/record-count
		destination/record-size: source/record-size
		destination/records-offset: source/records-offset
		destination/records-ordinal: source/records-ordinal
		destination/data: source/data
		destination/data-size: source/data-size
		destination/data-offset: source/data-offset
		destination/data-ordinal: source/data-ordinal
	]

	copy-files: func [
		destination source [wire-file-source!]
	][
		destination/files: source/files
		destination/file-count: source/file-count
		destination/file-record-size: source/file-record-size
		destination/files-offset: source/files-offset
		destination/files-ordinal: source/files-ordinal
		destination/checksum-data: source/checksum-data
		destination/checksum-data-size: source/checksum-data-size
		destination/checksum-data-offset: source/checksum-data-offset
		destination/checksum-data-ordinal: source/checksum-data-ordinal
		destination/source-present: source/source-present
		destination/sources: source/sources
		destination/source-count: source/source-count
		destination/source-record-size: source/source-record-size
		destination/source-offset: source/source-offset
		destination/source-ordinal: source/source-ordinal
	]

	copy-layout: func [
		destination source [wire-data-layout!]
	][
		destination/address-unit: source/address-unit
		destination/pointer-size: source/pointer-size
		destination/pointer-alignment: source/pointer-alignment
		destination/stack-alignment: source/stack-alignment
		destination/max-scalar-alignment: source/max-scalar-alignment
		destination/max-aggregate-alignment: source/max-aggregate-alignment
		destination/integer-register-width: source/integer-register-width
		destination/flags: source/flags
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-type-layout-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		view [wire-type-layout!]
		return: [integer!]
		/local container-result [wire-container-result!]
			metadata-result [wire-file-source-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			data-result [wire-data-layout-result!]
			verified-layout [wire-data-layout!]
			types fields signatures [wire-section-slice!]
			type-record field-record [byte-ptr!]
			status bad-relative type-count field-count signature-count
			record-index type-id field-id record-offset kind flags type-size alignment
			reserved-0 detail-id reserved-1 first-field owned-field-count gc-kind
			expected-gc finish tag-size source-count owner-type owner-kind owner-first
			owner-count field-name field-type byte-offset ordinal source-location
			child-kind
			cursor expected-offset child-size child-alignment max-alignment payload-size
			payload-offset expected-size [integer!]
	][
		if null? result [return WIRE_TYPE_LAYOUT_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [
			size < 0
			null? data
			null? strings
			null? files
			null? layout
			null? view
		][
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_ARGUMENTS 0 0
		]

		container-result: declare wire-container-result!
		status: wire-container-reader/verify
			data size WIRE_MAGIC_RSIR container-result
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			result/container-error: status
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		metadata-result: declare wire-file-source-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		status: wire-file-source-reader/verify
			data size WIRE_MAGIC_RSIR metadata-result verified-strings verified-files
		if status <> WIRE_FILE_SOURCE_ERROR_SUCCESS [
			result/container-error: metadata-result/container-error
			result/string-error: metadata-result/string-error
			result/file-source-error: status
			case [
				status = WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
						metadata-result/error-offset metadata-result/error-section
				]
				status = WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS
						metadata-result/error-offset metadata-result/error-section
				]
				true [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE
						metadata-result/error-offset metadata-result/error-section
				]
			]
		]

		data-result: declare wire-data-layout-result!
		verified-layout: declare wire-data-layout!
		status: wire-data-layout-reader/verify
			data size WIRE_MAGIC_RSIR data-result verified-layout
		if status <> WIRE_DATA_LAYOUT_ERROR_SUCCESS [
			result/container-error: data-result/container-error
			result/data-layout-error: status
			if status = WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
					data-result/error-offset data-result/error-section
			]
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT
				data-result/error-offset data-result/error-section
		]

		types: declare wire-section-slice!
		fields: declare wire-section-slice!
		signatures: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_TYPES types
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_FIELDS fields
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_SIGNATURES signatures
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if types/flags <> 0 [
			return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_SECTION_FLAGS
				section-flags-offset types types/ordinal
		]
		if fields/flags <> 0 [
			return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_SECTION_FLAGS
				section-flags-offset fields fields/ordinal
		]

		type-count: types/record-count
		field-count: fields/record-count
		signature-count: signatures/record-count
		source-count: verified-files/source-count

		; Decode every signed scalar before applying semantic rules.
		record-index: 0
		while [record-index < type-count][
			type-record: types/data + (record-index * WIRE_RSIR_TYPE_SIZE)
			bad-relative: first-bad-scalar type-record 10
			if bad-relative >= 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE
					(types/offset + (record-index * WIRE_RSIR_TYPE_SIZE)) + bad-relative
					types/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < field-count][
			field-record: fields/data + (record-index * WIRE_RSIR_FIELD_SIZE)
			bad-relative: first-bad-scalar field-record 8
			if bad-relative >= 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE
					(fields/offset + (record-index * WIRE_RSIR_FIELD_SIZE)) + bad-relative
					fields/ordinal
			]
			record-index: record-index + 1
		]

		; Establish kind and flag domains before following type references.
		type-id: 1
		while [type-id <= type-count][
			record-offset: type-record-offset types type-id
			kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
			unless all [
				kind >= WIRE_TYPE_KIND_VOID
				kind <= WIRE_TYPE_KIND_UNION
			][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_KIND
					(record-offset + WIRE_RSIR_TYPE_KIND_OFFSET) types/ordinal
			]
			flags: type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET
			unless valid-flags? kind flags [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FLAGS
					(record-offset + WIRE_RSIR_TYPE_FLAGS_OFFSET) types/ordinal
			]
			type-id: type-id + 1
		]

		; Check every type record's local representation shape.
		type-id: 1
		while [type-id <= type-count][
			record-offset: type-record-offset types type-id
			kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
			flags: type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET
			type-size: type-value types type-id WIRE_RSIR_TYPE_SIZE_OFFSET
			alignment: type-value types type-id WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			reserved-0: type-value types type-id WIRE_RSIR_TYPE_RESERVED_0_OFFSET
			detail-id: type-value types type-id WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
			reserved-1: type-value types type-id WIRE_RSIR_TYPE_RESERVED_1_OFFSET
			first-field: type-value types type-id WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
			owned-field-count: type-value types type-id WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
			gc-kind: type-value types type-id WIRE_RSIR_TYPE_GC_KIND_OFFSET

			if reserved-0 <> 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
					(record-offset + WIRE_RSIR_TYPE_RESERVED_0_OFFSET) types/ordinal
			]
			if reserved-1 <> 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
					(record-offset + WIRE_RSIR_TYPE_RESERVED_1_OFFSET) types/ordinal
			]

			case [
				kind = WIRE_TYPE_KIND_VOID [
					if type-size <> 0 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					if alignment <> 0 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				kind = WIRE_TYPE_KIND_LOGIC [
					if type-size <> 4 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					if alignment <> 4 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				kind = WIRE_TYPE_KIND_INTEGER [
					unless any [
						type-size = 1
						type-size = 2
						type-size = 4
						type-size = 8
					][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					if alignment <> type-size [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				kind = WIRE_TYPE_KIND_FLOAT [
					unless any [type-size = 4 type-size = 8][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					if alignment <> type-size [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				any [kind = WIRE_TYPE_KIND_POINTER kind = WIRE_TYPE_KIND_FUNCTION][
					if type-size <> 8 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					if alignment <> 8 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				aggregate-kind? kind [
					if type-size <= 0 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					unless all [
						alignment <= 8
						wire-container-reader/power-of-two? alignment
					][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
				]
				true []
			]

			either aggregate-kind? kind [
				if first-field <= 0 [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET) types/ordinal
				]
				if owned-field-count <= 0 [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET) types/ordinal
				]
				finish: wire-container-reader/checked-add first-field (owned-field-count - 1)
				if any [finish < 0 finish > field-count][
					return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET) types/ordinal
				]
			][
				if first-field <> 0 [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET) types/ordinal
				]
				if owned-field-count <> 0 [
					return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET) types/ordinal
				]
			]

			case [
				kind = WIRE_TYPE_KIND_POINTER [
					if any [detail-id <= 0 detail-id > type-count][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
					child-kind: type-value types detail-id WIRE_RSIR_TYPE_KIND_OFFSET
					if child-kind = WIRE_TYPE_KIND_VOID [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
					if flags = WIRE_TYPE_FLAG_C_STRING [
						if any [
							(type-value types detail-id WIRE_RSIR_TYPE_KIND_OFFSET)
								<> WIRE_TYPE_KIND_INTEGER
							(type-value types detail-id WIRE_RSIR_TYPE_FLAGS_OFFSET) <> 0
							(type-value types detail-id WIRE_RSIR_TYPE_SIZE_OFFSET) <> 1
						][
							return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
								(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
						]
					]
				]
				kind = WIRE_TYPE_KIND_FUNCTION [
					if any [detail-id <= 0 detail-id > signature-count][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
				]
				all [
					kind = WIRE_TYPE_KIND_UNION
					flags = WIRE_TYPE_FLAG_TAGGED
				][
					if any [detail-id <= 0 detail-id >= type-id][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
					tag-size: case [
						owned-field-count <= 255 [1]
						owned-field-count <= 65535 [2]
						true [4]
					]
					if any [
						(type-value types detail-id WIRE_RSIR_TYPE_KIND_OFFSET)
							<> WIRE_TYPE_KIND_INTEGER
						(type-value types detail-id WIRE_RSIR_TYPE_FLAGS_OFFSET) <> 0
						(type-value types detail-id WIRE_RSIR_TYPE_SIZE_OFFSET) <> tag-size
					][
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
				]
				true [
					if detail-id <> 0 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) types/ordinal
					]
				]
			]

			expected-gc: case [
				kind = WIRE_TYPE_KIND_POINTER [WIRE_GC_KIND_POINTER]
				kind = WIRE_TYPE_KIND_FUNCTION [WIRE_GC_KIND_POINTER]
				kind = WIRE_TYPE_KIND_INTEGER [
					either any [
						gc-kind = WIRE_GC_KIND_NONE
						all [
							gc-kind = WIRE_GC_KIND_HANDLE
							flags = WIRE_TYPE_FLAG_SIGNED
							type-size = 4
						]
					][gc-kind][-1]
				]
				true [WIRE_GC_KIND_NONE]
			]
			if expected-gc < 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_GC_KIND
					(record-offset + WIRE_RSIR_TYPE_GC_KIND_OFFSET) types/ordinal
			]
			if gc-kind <> expected-gc [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_GC_KIND
					(record-offset + WIRE_RSIR_TYPE_GC_KIND_OFFSET) types/ordinal
			]
			type-id: type-id + 1
		]

		; Verify field-local metadata and ownership in both directions.
		field-id: 1
		while [field-id <= field-count][
			record-offset: field-record-offset fields field-id
			owner-type: field-value fields field-id WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
			if any [owner-type <= 0 owner-type > type-count][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET) fields/ordinal
			]
			owner-kind: type-value types owner-type WIRE_RSIR_TYPE_KIND_OFFSET
			unless aggregate-kind? owner-kind [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET) fields/ordinal
			]
			owner-first: type-value types owner-type WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
			owner-count: type-value types owner-type WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
			finish: wire-container-reader/checked-add owner-first (owner-count - 1)
			unless all [
				field-id >= owner-first
				field-id <= finish
			][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET) fields/ordinal
			]

			field-name: field-value fields field-id WIRE_RSIR_FIELD_NAME_STRING_OFFSET
			if any [field-name <= 0 field-name > verified-strings/record-count][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_NAME_ID
					(record-offset + WIRE_RSIR_FIELD_NAME_STRING_OFFSET) fields/ordinal
			]
			unless nonempty-string? verified-strings field-name [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_EMPTY_FIELD_NAME
					(record-offset + WIRE_RSIR_FIELD_NAME_STRING_OFFSET) fields/ordinal
			]

			field-type: field-value fields field-id WIRE_RSIR_FIELD_TYPE_OFFSET
			if any [field-type <= 0 field-type > type-count][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
					(record-offset + WIRE_RSIR_FIELD_TYPE_OFFSET) fields/ordinal
			]
			if (type-value types field-type WIRE_RSIR_TYPE_KIND_OFFSET)
				= WIRE_TYPE_KIND_VOID
			[
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
					(record-offset + WIRE_RSIR_FIELD_TYPE_OFFSET) fields/ordinal
			]
			child-kind: type-value types field-type WIRE_RSIR_TYPE_KIND_OFFSET
			if all [aggregate-kind? child-kind field-type >= owner-type][
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_ORDER
					(record-offset + WIRE_RSIR_FIELD_TYPE_OFFSET) fields/ordinal
			]
			if (field-value fields field-id WIRE_RSIR_FIELD_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_NONZERO_FIELD_FLAGS
					(record-offset + WIRE_RSIR_FIELD_FLAGS_OFFSET) fields/ordinal
			]
			ordinal: field-value fields field-id WIRE_RSIR_FIELD_ORDINAL_OFFSET
			if ordinal <> (field-id - owner-first)[
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_ORDINAL
					(record-offset + WIRE_RSIR_FIELD_ORDINAL_OFFSET) fields/ordinal
			]
			source-location:
				field-value fields field-id WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SOURCE_LOCATION
					(record-offset + WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET) fields/ordinal
			]
			if (field-value fields field-id WIRE_RSIR_FIELD_RESERVED_OFFSET) <> 0 [
				return set-error result WIRE_TYPE_LAYOUT_ERROR_NONZERO_RESERVED
					(record-offset + WIRE_RSIR_FIELD_RESERVED_OFFSET) fields/ordinal
			]
			field-id: field-id + 1
		]

		type-id: 1
		while [type-id <= type-count][
			kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
			if aggregate-kind? kind [
				first-field: type-value types type-id WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				owned-field-count:
					type-value types type-id WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				finish: wire-container-reader/checked-add
					first-field (owned-field-count - 1)
				field-id: first-field
				while [field-id <= finish][
					owner-type: field-value fields field-id
						WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
					if owner-type <> type-id [
						record-offset: field-record-offset fields field-id
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
							(record-offset + WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
							fields/ordinal
					]
					field-id: field-id + 1
				]
			]
			type-id: type-id + 1
		]

		; By-value aggregate dependencies use smaller type IDs, so natural
		; Windows x64 layouts can be recomputed in one forward pass.
		type-id: 1
		while [type-id <= type-count][
			kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
			if aggregate-kind? kind [
					record-offset: type-record-offset types type-id
					flags: type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET
					first-field:
						type-value types type-id WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
					owned-field-count:
						type-value types type-id WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
					finish: wire-container-reader/checked-add
						first-field (owned-field-count - 1)
					cursor: 0
					payload-size: 0
					max-alignment: 1
					field-id: first-field
					while [field-id <= finish][
						field-type: field-value fields field-id WIRE_RSIR_FIELD_TYPE_OFFSET
						child-size: type-value types field-type WIRE_RSIR_TYPE_SIZE_OFFSET
						child-alignment:
							type-value types field-type WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
						if child-alignment > max-alignment [
							max-alignment: child-alignment
						]
						expected-offset: either kind = WIRE_TYPE_KIND_STRUCT [
							align-offset cursor child-alignment
						][0]
						if expected-offset < 0 [
							return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
								(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
						]
						if kind = WIRE_TYPE_KIND_STRUCT [
							cursor: wire-container-reader/checked-add
								expected-offset child-size
							if cursor < 0 [
								return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
									(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET)
									types/ordinal
							]
						]
						if child-size > payload-size [payload-size: child-size]
						field-id: field-id + 1
					]

					payload-offset: 0
					if all [
						kind = WIRE_TYPE_KIND_UNION
						flags = WIRE_TYPE_FLAG_TAGGED
					][
						detail-id: type-value types type-id WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
						tag-size: type-value types detail-id WIRE_RSIR_TYPE_SIZE_OFFSET
						payload-offset: align-offset tag-size max-alignment
					]

					cursor: 0
					field-id: first-field
					while [field-id <= finish][
						field-type: field-value fields field-id WIRE_RSIR_FIELD_TYPE_OFFSET
						child-size: type-value types field-type WIRE_RSIR_TYPE_SIZE_OFFSET
						child-alignment:
							type-value types field-type WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
						expected-offset: either kind = WIRE_TYPE_KIND_STRUCT [
							align-offset cursor child-alignment
						][payload-offset]
						byte-offset: field-value fields field-id
							WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET
						if byte-offset <> expected-offset [
							record-offset: field-record-offset fields field-id
							return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OFFSET
								(record-offset + WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET)
								fields/ordinal
						]
						if kind = WIRE_TYPE_KIND_STRUCT [
							cursor: wire-container-reader/checked-add
								expected-offset child-size
						]
						field-id: field-id + 1
					]

					expected-size: either kind = WIRE_TYPE_KIND_STRUCT [
						align-offset cursor max-alignment
					][
						finish: wire-container-reader/checked-add payload-offset payload-size
						either finish < 0 [-1][align-offset finish max-alignment]
					]
					if expected-size < 0 [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
					alignment: type-value types type-id WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
					if alignment <> max-alignment [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) types/ordinal
					]
					type-size: type-value types type-id WIRE_RSIR_TYPE_SIZE_OFFSET
					if type-size <> expected-size [
						return set-error result WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + WIRE_RSIR_TYPE_SIZE_OFFSET) types/ordinal
					]
			]
			type-id: type-id + 1
		]

		copy-strings strings verified-strings
		copy-files files verified-files
		copy-layout layout verified-layout
		view/types: types/data
		view/type-count: type-count
		view/type-record-size: types/record-size
		view/types-offset: types/offset
		view/types-ordinal: types/ordinal
		view/fields: fields/data
		view/field-count: field-count
		view/field-record-size: fields/record-size
		view/fields-offset: fields/offset
		view/fields-ordinal: fields/ordinal
		view/signature-count: signature-count
		view/source-location-count: source-count
		WIRE_TYPE_LAYOUT_ERROR_SUCCESS
	]
]
