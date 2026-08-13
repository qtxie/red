Red [
	Title: "Hybrid compiler RSIR type and aggregate-layout verifier"
	File:  %wire-type-layout.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-file-source [do %wire-file-source.red]
unless value? 'compiler-wire-data-layout [do %wire-data-layout.red]

compiler-wire-type-layout: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	file-source-verifier: compiler-wire-file-source
	data-layout-verifier: compiler-wire-data-layout

	type-fields: reduce [
		'kind          schema/WIRE_RSIR_TYPE_KIND_OFFSET
		'flags         schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
		'size          schema/WIRE_RSIR_TYPE_SIZE_OFFSET
		'alignment     schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
		'reserved-0    schema/WIRE_RSIR_TYPE_RESERVED_0_OFFSET
		'detail-id     schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
		'reserved-1    schema/WIRE_RSIR_TYPE_RESERVED_1_OFFSET
		'first-field   schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
		'field-count   schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
		'gc-kind       schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET
	]

	field-fields: reduce [
		'owner-type      schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
		'name-string     schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET
		'type            schema/WIRE_RSIR_FIELD_TYPE_OFFSET
		'byte-offset     schema/WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET
		'flags           schema/WIRE_RSIR_FIELD_FLAGS_OFFSET
		'ordinal         schema/WIRE_RSIR_FIELD_ORDINAL_OFFSET
		'source-location schema/WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET
		'reserved        schema/WIRE_RSIR_FIELD_RESERVED_OFFSET
	]

	make-view: does [
		make object! [
			type-count: 0
			types-offset: 0
			types-ordinal: 0
			type-record-size: schema/WIRE_RSIR_TYPE_SIZE
			field-count: 0
			fields-offset: 0
			fields-ordinal: 0
			field-record-size: schema/WIRE_RSIR_FIELD_SIZE
			signature-count: 0
			source-location-count: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			view: none
		]
	]

	reject: func [
		result [object!]
		code offset section [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	power-of-two?: func [value [integer!]][
		all [value > 0 zero? (value and (value - 1))]
	]

	align-offset?: func [offset alignment [integer!] /local remainder padding][
		if any [offset < 0 alignment <= 0][return none]
		remainder: offset // alignment
		if zero? remainder [return offset]
		padding: alignment - remainder
		container/checked-add offset padding
	]

	type-record-offset: func [view [object!] index [integer!]][
		view/types-offset + (index * schema/WIRE_RSIR_TYPE_SIZE)
	]

	field-record-offset: func [view [object!] index [integer!]][
		view/fields-offset + (index * schema/WIRE_RSIR_FIELD_SIZE)
	]

	type-value: func [data [binary!] view [object!] id field-offset [integer!]][
		container/read-i31 data
			((type-record-offset view (id - 1)) + field-offset)
	]

	field-value: func [data [binary!] view [object!] id field-offset [integer!]][
		container/read-i31 data
			((field-record-offset view (id - 1)) + field-offset)
	]

	string-size-for-id: func [
		data [binary!]
		table [object!]
		id [integer!]
		/local record-offset
	][
		if any [id <= 0 id > table/record-count][return none]
		record-offset: table/records-offset
			+ ((id - 1) * schema/WIRE_STRING_SIZE)
		container/read-i31 data (record-offset + schema/WIRE_STRING_SIZE_OFFSET)
	]

	aggregate-kind?: func [kind [integer!]][
		any [
			kind = schema/WIRE_TYPE_KIND_STRUCT
			kind = schema/WIRE_TYPE_KIND_UNION
		]
	]

	verify: func [
		data
		/local result container-result metadata-result data-result types fields signatures
			view type-count field-count signature-count record-index record-offset
			field-name field-offset value type-id kind flags size alignment reserved-0
			detail-id reserved-1 first-field owned-field-count gc-kind expected-flags
			expected-gc
			finish string-size source-count field-id owner-type field-type
			byte-offset ordinal source-location owner-kind owner-first owner-count
			child-kind cursor expected-offset child-size
			child-alignment max-alignment
			payload-size payload-offset tag-size expected-size
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_ARGUMENTS 0 0
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		metadata-result: file-source-verifier/verify data schema/WIRE_MAGIC_RSIR
		unless metadata-result/valid? [
			result/container-error: metadata-result/container-error
			result/string-error: metadata-result/string-error
			result/file-source-error: metadata-result/error
			case [
				metadata-result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
						metadata-result/error-offset metadata-result/error-section
				]
				metadata-result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS
						metadata-result/error-offset metadata-result/error-section
				]
				true [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE
						metadata-result/error-offset metadata-result/error-section
				]
			]
		]

		data-result: data-layout-verifier/verify data schema/WIRE_MAGIC_RSIR
		unless data-result/valid? [
			result/container-error: data-result/container-error
			result/data-layout-error: data-result/error
			if data-result/error = schema/WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
					data-result/error-offset data-result/error-section
			]
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT
				data-result/error-offset data-result/error-section
		]

		types: container/find-section container-result schema/WIRE_RSIR_SECTION_TYPES
		fields: container/find-section container-result schema/WIRE_RSIR_SECTION_FIELDS
		signatures:
			container/find-section container-result schema/WIRE_RSIR_SECTION_SIGNATURES
		if any [none? types none? fields none? signatures][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		if (select types 'flags) <> 0 [
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_SECTION_FLAGS
				((select types 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select types 'ordinal)
		]
		if (select fields 'flags) <> 0 [
			return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_SECTION_FLAGS
				((select fields 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select fields 'ordinal)
		]

		view: make-view
		view/type-count: type-count: select types 'record-count
		view/types-offset: select types 'payload-offset
		view/types-ordinal: select types 'ordinal
		view/type-record-size: select types 'record-size
		view/field-count: field-count: select fields 'record-count
		view/fields-offset: select fields 'payload-offset
		view/fields-ordinal: select fields 'ordinal
		view/field-record-size: select fields 'record-size
		view/signature-count: signature-count: select signatures 'record-count
		source-count: metadata-result/view/source-count
		view/source-location-count: source-count

		; Decode every signed scalar before applying semantic rules.
		record-index: 0
		while [record-index < type-count][
			record-offset: type-record-offset view record-index
			foreach [field-name field-offset] type-fields [
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE
						(record-offset + field-offset) view/types-ordinal
				]
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < field-count][
			record-offset: field-record-offset view record-index
			foreach [field-name field-offset] field-fields [
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE
						(record-offset + field-offset) view/fields-ordinal
				]
			]
			record-index: record-index + 1
		]

		; Establish kind and flag domains before following any type reference.
		type-id: 1
		while [type-id <= type-count][
			record-offset: type-record-offset view (type-id - 1)
			kind: type-value data view type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET
			unless all [
				kind >= schema/WIRE_TYPE_KIND_VOID
				kind <= schema/WIRE_TYPE_KIND_UNION
			][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_KIND
					(record-offset + schema/WIRE_RSIR_TYPE_KIND_OFFSET)
					view/types-ordinal
			]
			flags: type-value data view type-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
			expected-flags: case [
				kind = schema/WIRE_TYPE_KIND_INTEGER [
					either find reduce [
						0
						schema/WIRE_TYPE_FLAG_SIGNED
					] flags [flags][-1]
				]
				kind = schema/WIRE_TYPE_KIND_POINTER [
					either any [
						flags = 0
						flags = schema/WIRE_TYPE_FLAG_C_STRING
					][flags][-1]
				]
				kind = schema/WIRE_TYPE_KIND_UNION [
					either any [
						flags = 0
						flags = schema/WIRE_TYPE_FLAG_TAGGED
					][flags][-1]
				]
				true [either flags = 0 [0][-1]]
			]
			if expected-flags < 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FLAGS
					(record-offset + schema/WIRE_RSIR_TYPE_FLAGS_OFFSET)
					view/types-ordinal
			]
			type-id: type-id + 1
		]

		; Check each record's local representation shape.
		type-id: 1
		while [type-id <= type-count][
			record-offset: type-record-offset view (type-id - 1)
			kind: type-value data view type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET
			flags: type-value data view type-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
			size: type-value data view type-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET
			alignment: type-value data view type-id schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			reserved-0:
				type-value data view type-id schema/WIRE_RSIR_TYPE_RESERVED_0_OFFSET
			detail-id: type-value data view type-id schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
			reserved-1:
				type-value data view type-id schema/WIRE_RSIR_TYPE_RESERVED_1_OFFSET
			first-field:
				type-value data view type-id schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
			owned-field-count:
				type-value data view type-id schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
			gc-kind: type-value data view type-id schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET

			if reserved-0 <> 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
					(record-offset + schema/WIRE_RSIR_TYPE_RESERVED_0_OFFSET)
					view/types-ordinal
			]
			if reserved-1 <> 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
					(record-offset + schema/WIRE_RSIR_TYPE_RESERVED_1_OFFSET)
					view/types-ordinal
			]

			case [
				kind = schema/WIRE_TYPE_KIND_VOID [
					if size <> 0 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					if alignment <> 0 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				kind = schema/WIRE_TYPE_KIND_LOGIC [
					if size <> 4 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					if alignment <> 4 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				kind = schema/WIRE_TYPE_KIND_INTEGER [
					unless find [1 2 4 8] size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					if alignment <> size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				kind = schema/WIRE_TYPE_KIND_FLOAT [
					unless find [4 8] size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					if alignment <> size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				any [
					kind = schema/WIRE_TYPE_KIND_POINTER
					kind = schema/WIRE_TYPE_KIND_FUNCTION
				][
					if size <> 8 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					if alignment <> 8 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				aggregate-kind? kind [
					if size <= 0 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					unless all [alignment <= 8 power-of-two? alignment][
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
				]
				true []
			]

			either aggregate-kind? kind [
				if first-field <= 0 [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET)
						view/types-ordinal
				]
				if owned-field-count <= 0 [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET)
						view/types-ordinal
				]
				finish: container/checked-add first-field (owned-field-count - 1)
				if any [none? finish finish > field-count][
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET)
						view/types-ordinal
				]
			][
				if first-field <> 0 [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET)
						view/types-ordinal
				]
				if owned-field-count <> 0 [
					return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
						(record-offset + schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET)
						view/types-ordinal
				]
			]

			case [
				kind = schema/WIRE_TYPE_KIND_POINTER [
					if any [detail-id <= 0 detail-id > type-count][
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
					child-kind: type-value data view detail-id
						schema/WIRE_RSIR_TYPE_KIND_OFFSET
					if child-kind = schema/WIRE_TYPE_KIND_VOID [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
					if flags = schema/WIRE_TYPE_FLAG_C_STRING [
						if any [
							(type-value data view detail-id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
								<> schema/WIRE_TYPE_KIND_INTEGER
							(type-value data view detail-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET) <> 0
							(type-value data view detail-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) <> 1
						][
							return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
								(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
								view/types-ordinal
						]
					]
				]
				kind = schema/WIRE_TYPE_KIND_FUNCTION [
					if any [detail-id <= 0 detail-id > signature-count][
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
				]
				all [
					kind = schema/WIRE_TYPE_KIND_UNION
					flags = schema/WIRE_TYPE_FLAG_TAGGED
				][
					if any [detail-id <= 0 detail-id >= type-id][
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
					tag-size: case [
						owned-field-count <= 255 [1]
						owned-field-count <= 65535 [2]
						true [4]
					]
					if any [
						(type-value data view detail-id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
							<> schema/WIRE_TYPE_KIND_INTEGER
						(type-value data view detail-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET) <> 0
						(type-value data view detail-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							<> tag-size
					][
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
				]
				true [
					if detail-id <> 0 [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
							(record-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
							view/types-ordinal
					]
				]
			]

			expected-gc: case [
				kind = schema/WIRE_TYPE_KIND_POINTER [schema/WIRE_GC_KIND_POINTER]
				kind = schema/WIRE_TYPE_KIND_FUNCTION [schema/WIRE_GC_KIND_POINTER]
				kind = schema/WIRE_TYPE_KIND_INTEGER [
					either any [
						gc-kind = schema/WIRE_GC_KIND_NONE
						all [
							gc-kind = schema/WIRE_GC_KIND_HANDLE
							flags = schema/WIRE_TYPE_FLAG_SIGNED
							size = 4
						]
					][gc-kind][-1]
				]
				true [schema/WIRE_GC_KIND_NONE]
			]
			if expected-gc < 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_GC_KIND
					(record-offset + schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET)
					view/types-ordinal
			]
			if gc-kind <> expected-gc [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_GC_KIND
					(record-offset + schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET)
					view/types-ordinal
			]
			type-id: type-id + 1
		]

		; Verify field ownership in both directions and all field-local metadata.
		field-id: 1
		while [field-id <= field-count][
			record-offset: field-record-offset view (field-id - 1)
			owner-type:
				field-value data view field-id schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
			if any [owner-type <= 0 owner-type > type-count][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
					view/fields-ordinal
			]
			owner-kind:
				type-value data view owner-type schema/WIRE_RSIR_TYPE_KIND_OFFSET
			unless aggregate-kind? owner-kind [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
					view/fields-ordinal
			]
			owner-first:
				type-value data view owner-type schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
			owner-count:
				type-value data view owner-type schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
			finish: container/checked-add owner-first (owner-count - 1)
			unless all [field-id >= owner-first field-id <= finish][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
					(record-offset + schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
					view/fields-ordinal
			]

			name-string:
				field-value data view field-id schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET
			if any [name-string <= 0 name-string > metadata-result/strings/record-count][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_NAME_ID
					(record-offset + schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET)
					view/fields-ordinal
			]
			string-size: string-size-for-id data metadata-result/strings name-string
			if zero? string-size [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_EMPTY_FIELD_NAME
					(record-offset + schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET)
					view/fields-ordinal
			]

			field-type: field-value data view field-id schema/WIRE_RSIR_FIELD_TYPE_OFFSET
			if any [field-type <= 0 field-type > type-count][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
					(record-offset + schema/WIRE_RSIR_FIELD_TYPE_OFFSET)
					view/fields-ordinal
			]
			if (type-value data view field-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_VOID
			[
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
					(record-offset + schema/WIRE_RSIR_FIELD_TYPE_OFFSET)
					view/fields-ordinal
			]
			child-kind:
				type-value data view field-type schema/WIRE_RSIR_TYPE_KIND_OFFSET
			if all [aggregate-kind? child-kind field-type >= owner-type][
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_ORDER
					(record-offset + schema/WIRE_RSIR_FIELD_TYPE_OFFSET)
					view/fields-ordinal
			]
			if (field-value data view field-id schema/WIRE_RSIR_FIELD_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_FIELD_FLAGS
					(record-offset + schema/WIRE_RSIR_FIELD_FLAGS_OFFSET)
					view/fields-ordinal
			]
			ordinal: field-value data view field-id schema/WIRE_RSIR_FIELD_ORDINAL_OFFSET
			if ordinal <> (field-id - owner-first)[
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_ORDINAL
					(record-offset + schema/WIRE_RSIR_FIELD_ORDINAL_OFFSET)
					view/fields-ordinal
			]
			source-location:
				field-value data view field-id schema/WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SOURCE_LOCATION
					(record-offset + schema/WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET)
					view/fields-ordinal
			]
			if (field-value data view field-id schema/WIRE_RSIR_FIELD_RESERVED_OFFSET) <> 0 [
				return reject result schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_RESERVED
					(record-offset + schema/WIRE_RSIR_FIELD_RESERVED_OFFSET)
					view/fields-ordinal
			]
			field-id: field-id + 1
		]

		; Every aggregate range must point back to its owner.
		type-id: 1
		while [type-id <= type-count][
			kind: type-value data view type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET
			if aggregate-kind? kind [
				first-field:
					type-value data view type-id schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				owned-field-count:
					type-value data view type-id schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				finish: container/checked-add first-field (owned-field-count - 1)
				field-id: first-field
				while [field-id <= finish][
					owner-type: field-value data view field-id
						schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
					if owner-type <> type-id [
						record-offset: field-record-offset view (field-id - 1)
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
							(record-offset + schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
							view/fields-ordinal
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
			kind: type-value data view type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET
			if aggregate-kind? kind [
					record-offset: type-record-offset view (type-id - 1)
					flags: type-value data view type-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
					first-field: type-value data view type-id
						schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
					owned-field-count: type-value data view type-id
						schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
					finish: container/checked-add first-field (owned-field-count - 1)
					cursor: 0
					payload-size: 0
					max-alignment: 1
					field-id: first-field
					while [field-id <= finish][
						field-type: field-value data view field-id
							schema/WIRE_RSIR_FIELD_TYPE_OFFSET
						child-size: type-value data view field-type
							schema/WIRE_RSIR_TYPE_SIZE_OFFSET
						child-alignment: type-value data view field-type
							schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
						if child-alignment > max-alignment [
							max-alignment: child-alignment
						]
						expected-offset: either kind = schema/WIRE_TYPE_KIND_STRUCT [
							align-offset? cursor child-alignment
						][0]
						if none? expected-offset [
							return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
								(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
								view/types-ordinal
						]
						if kind = schema/WIRE_TYPE_KIND_STRUCT [
							cursor: container/checked-add expected-offset child-size
							if none? cursor [
								return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
									(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
									view/types-ordinal
							]
						]
						if child-size > payload-size [payload-size: child-size]
						field-id: field-id + 1
					]

					payload-offset: 0
					if all [
						kind = schema/WIRE_TYPE_KIND_UNION
						flags = schema/WIRE_TYPE_FLAG_TAGGED
					][
						detail-id: type-value data view type-id
							schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
						tag-size: type-value data view detail-id
							schema/WIRE_RSIR_TYPE_SIZE_OFFSET
						payload-offset: align-offset? tag-size max-alignment
					]

					cursor: 0
					field-id: first-field
					while [field-id <= finish][
						field-type: field-value data view field-id
							schema/WIRE_RSIR_FIELD_TYPE_OFFSET
						child-size: type-value data view field-type
							schema/WIRE_RSIR_TYPE_SIZE_OFFSET
						child-alignment: type-value data view field-type
							schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
						expected-offset: either kind = schema/WIRE_TYPE_KIND_STRUCT [
							align-offset? cursor child-alignment
						][payload-offset]
						byte-offset: field-value data view field-id
							schema/WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET
						if byte-offset <> expected-offset [
							field-offset: field-record-offset view (field-id - 1)
							return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OFFSET
								(field-offset + schema/WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET)
								view/fields-ordinal
						]
						if kind = schema/WIRE_TYPE_KIND_STRUCT [
							cursor: container/checked-add expected-offset child-size
						]
						field-id: field-id + 1
					]

					expected-size: either kind = schema/WIRE_TYPE_KIND_STRUCT [
						align-offset? cursor max-alignment
					][
						finish: container/checked-add payload-offset payload-size
						either none? finish [none][align-offset? finish max-alignment]
					]
					if none? expected-size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
					alignment: type-value data view type-id
						schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
					if alignment <> max-alignment [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
							(record-offset + schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET)
							view/types-ordinal
					]
					size: type-value data view type-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET
					if size <> expected-size [
						return reject result schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
							(record-offset + schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
							view/types-ordinal
					]
			]
			type-id: type-id + 1
		]

		result/strings: metadata-result/strings
		result/files: metadata-result/view
		result/layout: data-result/layout
		result/view: view
		result/valid?: true
		result
	]
]
