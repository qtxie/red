Red [
	Title: "Hybrid compiler RSIR constant and global-initializer verifier"
	File:  %wire-constant-initializer.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-symbol-linkage [do %wire-symbol-linkage.red]

compiler-wire-constant-initializer: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	symbol-verifier: compiler-wire-symbol-linkage

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	constant-fields: reduce [
		'type        schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
		'kind        schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
		'flags       schema/WIRE_RSIR_CONSTANT_FLAGS_OFFSET
		'data-offset schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		'data-size   schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		'first-part  schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET
		'part-count  schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET
		'auxiliary   schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET
	]

	part-fields: reduce [
		'parent-constant       schema/WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET
		'byte-offset           schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET
		'type                  schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET
		'kind                  schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET
		'child-constant        schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET
		'target-symbol         schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET
		'raw-addend-data-offset
			schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET
		'flags                 schema/WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET
	]

	binding-fields: reduce [
		'symbol   schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET
		'constant schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET
	]

	make-view: does [
		make object! [
			constants-offset: 0
			constant-count: 0
			constant-record-size: schema/WIRE_RSIR_CONSTANT_SIZE
			constants-ordinal: 0
			constant-data-offset: 0
			constant-data-size: 0
			constant-data-owned-size: 0
			constant-data-ordinal: 0
			parts-offset: 0
			part-count: 0
			part-record-size: schema/WIRE_RSIR_CONSTANT_PART_SIZE
			parts-ordinal: 0
			bindings-offset: 0
			binding-count: 0
			binding-record-size: schema/WIRE_RSIR_CONSTANT_BINDING_SIZE
			bindings-ordinal: 0
			global-count: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			type-layout-error: schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
			function-signature-error: schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
			module-lifecycle-error: schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
			symbol-linkage-error: schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			types: none
			functions: none
			modules: none
			symbols: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	constant-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/constants-offset schema/WIRE_RSIR_CONSTANT_SIZE id field
	]

	part-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/parts-offset schema/WIRE_RSIR_CONSTANT_PART_SIZE id field
	]

	binding-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/bindings-offset
			schema/WIRE_RSIR_CONSTANT_BINDING_SIZE id field
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		record-value data types/types-offset schema/WIRE_RSIR_TYPE_SIZE id field
	]

	field-value: func [data [binary!] types [object!] id field [integer!]][
		record-value data types/fields-offset schema/WIRE_RSIR_FIELD_SIZE id field
	]

	symbol-value: func [data [binary!] symbols [object!] id field [integer!]][
		record-value data symbols/symbols-offset schema/WIRE_RSIR_SYMBOL_SIZE id field
	]

	global-value: func [data [binary!] symbols [object!] id field [integer!]][
		record-value data symbols/globals-offset schema/WIRE_RSIR_GLOBAL_SIZE id field
	]

	valid-type?: func [types [object!] id [integer!]][
		all [id > 0 id <= types/type-count]
	]

	pointer-like-kind?: func [kind [integer!]][
		any [
			kind = schema/WIRE_TYPE_KIND_POINTER
			kind = schema/WIRE_TYPE_KIND_FUNCTION
		]
	]

	all-zero?: func [data [binary!] offset size [integer!] /local finish bad][
		finish: container/checked-add offset size
		if none? finish [return false]
		bad: container/first-nonzero data offset finish
		none? bad
	]

	first-nonzero-offset: func [data [binary!] offset size [integer!] /local finish][
		finish: container/checked-add offset size
		if none? finish [return offset]
		container/first-nonzero data offset finish
	]

	first-bad-logic-byte: func [data [binary!] offset [integer!] /local index value][
		value: to integer! pick data (offset + 1)
		if not find [0 1] value [return offset]
		index: 1
		while [index < 4][
			if (to integer! pick data (offset + index + 1)) <> 0 [return offset + index]
			index: index + 1
		]
		none
	]

	first-bad-c-string-byte: func [
		data [binary!] offset size [integer!]
		/local index
	][
		if size <= 0 [return offset]
		index: 0
		while [index < (size - 1)][
			if (to integer! pick data (offset + index + 1)) = 0 [return offset + index]
			index: index + 1
		]
		if (to integer! pick data (offset + size)) <> 0 [return offset + size - 1]
		none
	]

	first-bad-relative-addend-byte: func [
		data [binary!] offset [integer!]
		/local expected index
	][
		expected: either (to integer! pick data (offset + 4)) > 127 [255][0]
		index: 4
		while [index < 8][
			if (to integer! pick data (offset + index + 1)) <> expected [
				return offset + index
			]
			index: index + 1
		]
		none
	]

	first-bad-absolute-addend-byte: func [data [binary!] offset [integer!]][
		either all-zero? data offset 8 [offset][none]
	]

	inherit-symbol-errors: func [result symbol-result [object!]][
		result/header: symbol-result/header
		result/container-error: symbol-result/container-error
		result/string-error: symbol-result/string-error
		result/file-source-error: symbol-result/file-source-error
		result/data-layout-error: symbol-result/data-layout-error
		result/type-layout-error: symbol-result/type-layout-error
		result/function-signature-error: symbol-result/function-signature-error
		result/module-lifecycle-error: symbol-result/module-lifecycle-error
		result/symbol-linkage-error: symbol-result/error
	]

	map-symbol-error: func [code [integer!]][
		case [
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_STRINGS [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_STRINGS
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FILE_SOURCE [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FILE_SOURCE
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_DATA_LAYOUT [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_DATA_LAYOUT
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_TYPE_LAYOUT [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_TYPE_LAYOUT
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FUNCTION_SIGNATURE [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FUNCTION_SIGNATURE
			]
			code = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_MODULE_LIFECYCLE [
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_MODULE_LIFECYCLE
			]
			true [schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_SYMBOL_LINKAGE]
		]
	]

	verify: func [
		data
		/local result symbol-result container-result constants constant-data parts
			bindings target-fragments view record-index record-base field-name field-offset value
			constant-id constant-type constant-kind flags data-offset data-size
			first-part owned-part-count auxiliary part-cursor data-cursor finish
			type-kind type-size type-alignment type-flags detail-id expected-size
			part-id part-base parent byte-offset part-type part-kind child target
			addend-offset part-size part-alignment bad-offset previous-end
			field-count first-field expected-field selected-field field-type
			field-byte-offset binding-id binding-base binding-symbol binding-constant
			previous-symbol symbol-id symbol-kind symbol-type binding-cursor
			global-id global-base initializer alignment storage-class direct-data-base
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS 0 0
		]

		symbol-result: symbol-verifier/verify data
		inherit-symbol-errors result symbol-result
		unless symbol-result/valid? [
			return reject result (map-symbol-error symbol-result/error)
				symbol-result/error-offset symbol-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		constants: container/find-section container-result schema/WIRE_RSIR_SECTION_CONSTANTS
		constant-data:
			container/find-section container-result schema/WIRE_RSIR_SECTION_CONSTANT_DATA
		parts: container/find-section container-result schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
		bindings:
			container/find-section container-result schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		target-fragments:
			container/find-section container-result schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS
		if any [
			none? constants none? constant-data none? parts none? bindings
			none? target-fragments
		][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		foreach [section expected code] reduce [
			constants 0 schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_SECTION_FLAGS
			constant-data 0
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_SECTION_FLAGS
			parts 0 schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_SECTION_FLAGS
			bindings expected-index-flags
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_BINDING_SECTION_FLAGS
		][
			if (select section 'flags) <> expected [
				return reject result code (section-flags-offset section)
					(select section 'ordinal)
			]
		]

		view: make-view
		view/constants-offset: select constants 'payload-offset
		view/constant-count: select constants 'record-count
		view/constant-record-size: select constants 'record-size
		view/constants-ordinal: select constants 'ordinal
		view/constant-data-offset: select constant-data 'payload-offset
		view/constant-data-size: select constant-data 'payload-size
		view/constant-data-ordinal: select constant-data 'ordinal
		view/parts-offset: select parts 'payload-offset
		view/part-count: select parts 'record-count
		view/part-record-size: select parts 'record-size
		view/parts-ordinal: select parts 'ordinal
		view/bindings-offset: select bindings 'payload-offset
		view/binding-count: select bindings 'record-count
		view/binding-record-size: select bindings 'record-size
		view/bindings-ordinal: select bindings 'ordinal
		view/global-count: symbol-result/view/global-count

		foreach [count base size section-ordinal fields] reduce [
			view/constant-count view/constants-offset schema/WIRE_RSIR_CONSTANT_SIZE
				view/constants-ordinal constant-fields
			view/part-count view/parts-offset schema/WIRE_RSIR_CONSTANT_PART_SIZE
				view/parts-ordinal part-fields
			view/binding-count view/bindings-offset schema/WIRE_RSIR_CONSTANT_BINDING_SIZE
				view/bindings-ordinal binding-fields
		][
			record-index: 0
			while [record-index < count][
				record-base: record-offset base record-index size
				foreach [field-name field-offset] fields [
					value: container/read-i31 data (record-base + field-offset)
					if none? value [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_SCALAR_RANGE
							(record-base + field-offset) section-ordinal
					]
				]
				record-index: record-index + 1
			]
		]

		part-cursor: 1
		data-cursor: 0
		constant-id: 1
		while [constant-id <= view/constant-count][
			record-base: record-offset view/constants-offset (constant-id - 1)
				schema/WIRE_RSIR_CONSTANT_SIZE
			constant-type: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
			if any [
				not valid-type? symbol-result/types constant-type
				(type-value data symbol-result/types constant-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
					= schema/WIRE_TYPE_KIND_VOID
			][
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_TYPE
					(record-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
					view/constants-ordinal
			]
			constant-kind: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
			unless all [
				constant-kind >= schema/WIRE_CONSTANT_KIND_ZERO
				constant-kind <= schema/WIRE_CONSTANT_KIND_ADDRESS
			][
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_KIND
					(record-base + schema/WIRE_RSIR_CONSTANT_KIND_OFFSET)
					view/constants-ordinal
			]
			flags: constant-value data view constant-id schema/WIRE_RSIR_CONSTANT_FLAGS_OFFSET
			if flags <> schema/WIRE_CONSTANT_FLAG_NONE [
				return reject result
					schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_CONSTANT_FLAGS
					(record-base + schema/WIRE_RSIR_CONSTANT_FLAGS_OFFSET)
					view/constants-ordinal
			]

			data-offset: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
			data-size: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
			first-part: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET
			owned-part-count: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET
			auxiliary: constant-value data view constant-id
				schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET
			either owned-part-count = 0 [
				if first-part <> 0 [
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
						view/constants-ordinal
				]
			][
				if first-part <> part-cursor [
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
						view/constants-ordinal
				]
				finish: container/checked-add first-part (owned-part-count - 1)
				if any [none? finish finish > view/part-count][
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
						view/constants-ordinal
				]
			]

			type-kind: type-value data symbol-result/types constant-type
				schema/WIRE_RSIR_TYPE_KIND_OFFSET
			type-size: type-value data symbol-result/types constant-type
				schema/WIRE_RSIR_TYPE_SIZE_OFFSET
			type-flags: type-value data symbol-result/types constant-type
				schema/WIRE_RSIR_TYPE_FLAGS_OFFSET

			case [
				constant-kind = schema/WIRE_CONSTANT_KIND_ZERO [
					unless all [
						data-offset = 0 data-size = 0 owned-part-count = 0 auxiliary = 0
					][
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ZERO_SHAPE
							(record-base + schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							view/constants-ordinal
					]
				]
				constant-kind = schema/WIRE_CONSTANT_KIND_SCALAR [
					unless find reduce [
						schema/WIRE_TYPE_KIND_LOGIC schema/WIRE_TYPE_KIND_INTEGER
						schema/WIRE_TYPE_KIND_FLOAT
					] type-kind [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_TYPE
							(record-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							view/constants-ordinal
					]
					if data-size <> type-size [
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_DATA_SIZE
							(record-base + schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
							view/constants-ordinal
					]
					unless all [owned-part-count = 0 auxiliary = 0][
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_SHAPE
							(record-base + schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
							view/constants-ordinal
					]
				]
				constant-kind = schema/WIRE_CONSTANT_KIND_STORAGE [
					if type-kind <> schema/WIRE_TYPE_KIND_POINTER [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_TYPE
							(record-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							view/constants-ordinal
					]
					if auxiliary <= 0 [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_COUNT
							(record-base + schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							view/constants-ordinal
					]
					detail-id: type-value data symbol-result/types constant-type
						schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
					expected-size: container/checked-multiply auxiliary
						(type-value data symbol-result/types detail-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET)
					if none? expected-size [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_COUNT
							(record-base + schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							view/constants-ordinal
					]
					if data-size <> expected-size [
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_DATA_SIZE
							(record-base + schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
							view/constants-ordinal
					]
					if all [
						type-flags = schema/WIRE_TYPE_FLAG_C_STRING
						owned-part-count <> 0
					][
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_PART_COUNT
							(record-base + schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
							view/constants-ordinal
					]
				]
				constant-kind = schema/WIRE_CONSTANT_KIND_AGGREGATE [
					unless find reduce [
						schema/WIRE_TYPE_KIND_STRUCT schema/WIRE_TYPE_KIND_UNION
					] type-kind [
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_TYPE
							(record-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							view/constants-ordinal
					]
					field-count: type-value data symbol-result/types constant-type
						schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
					expected-size: either type-kind = schema/WIRE_TYPE_KIND_STRUCT [
						field-count
					][1]
					if owned-part-count <> expected-size [
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_PART_COUNT
							(record-base + schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
							view/constants-ordinal
					]
					if all [type-kind = schema/WIRE_TYPE_KIND_STRUCT auxiliary <> 0][
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
							(record-base + schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							view/constants-ordinal
					]
					if any [data-offset <> 0 data-size <> 0][
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
							(record-base + schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							view/constants-ordinal
					]
				]
				constant-kind = schema/WIRE_CONSTANT_KIND_ADDRESS [
					unless pointer-like-kind? type-kind [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TYPE
							(record-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							view/constants-ordinal
					]
					unless all [
						data-offset = 0 data-size = 0 owned-part-count = 1 auxiliary = 0
					][
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_SHAPE
							(record-base + schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							view/constants-ordinal
					]
				]
				true [assert false "unreachable constant kind"]
			]

			if find reduce [
				schema/WIRE_CONSTANT_KIND_SCALAR schema/WIRE_CONSTANT_KIND_STORAGE
			] constant-kind [
				if data-offset <> data-cursor [
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_OFFSET
						(record-base + schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
						view/constants-ordinal
				]
				finish: container/checked-add data-offset data-size
				if any [none? finish finish > view/constant-data-size][
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_RANGE
						(record-base + schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
						view/constants-ordinal
				]
				direct-data-base: view/constant-data-offset + data-offset
				if all [
					constant-kind = schema/WIRE_CONSTANT_KIND_SCALAR
					type-kind = schema/WIRE_TYPE_KIND_LOGIC
					bad-offset: first-bad-logic-byte data direct-data-base
				][
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_LOGIC_ENCODING
						bad-offset view/constant-data-ordinal
				]
				if all [
					constant-kind = schema/WIRE_CONSTANT_KIND_STORAGE
					type-flags = schema/WIRE_TYPE_FLAG_C_STRING
					bad-offset: first-bad-c-string-byte data direct-data-base data-size
				][
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_C_STRING_ENCODING
						bad-offset view/constant-data-ordinal
				]
				data-cursor: finish
			]

			previous-end: 0
			part-id: first-part
			while [owned-part-count > 0][
				part-base: record-offset view/parts-offset (part-id - 1)
					schema/WIRE_RSIR_CONSTANT_PART_SIZE
				parent: part-value data view part-id
					schema/WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET
				if parent <> constant-id [
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_PARENT
						(part-base + schema/WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET)
						view/parts-ordinal
				]
				part-type: part-value data view part-id schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET
				if any [
					not valid-type? symbol-result/types part-type
					(type-value data symbol-result/types part-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
						= schema/WIRE_TYPE_KIND_VOID
				][
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_TYPE
						(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
						view/parts-ordinal
				]
				part-kind: part-value data view part-id schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET
				unless all [
					part-kind >= schema/WIRE_CONSTANT_PART_KIND_VALUE
					part-kind <= schema/WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS
				][
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_KIND
						(part-base + schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET)
						view/parts-ordinal
				]
				byte-offset: part-value data view part-id
					schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET
				part-size: type-value data symbol-result/types part-type
					schema/WIRE_RSIR_TYPE_SIZE_OFFSET
				part-alignment: type-value data symbol-result/types part-type
					schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET

				case [
					constant-kind = schema/WIRE_CONSTANT_KIND_STORAGE [
						finish: container/checked-add byte-offset part-size
						if any [
							none? finish finish > data-size
							part-alignment <= 0
							not zero? (byte-offset // part-alignment)
						][
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								view/parts-ordinal
						]
						if byte-offset < previous-end [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_OVERLAP
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								view/parts-ordinal
						]
						previous-end: finish
					]
					constant-kind = schema/WIRE_CONSTANT_KIND_AGGREGATE [
						first-field: type-value data symbol-result/types constant-type
							schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
						either type-kind = schema/WIRE_TYPE_KIND_STRUCT [
							expected-field: first-field + (part-id - first-part)
						][
							selected-field: auxiliary
							finish: first-field + field-count - 1
							if any [selected-field < first-field selected-field > finish][
								return reject result
									schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_UNION_FIELD
									(record-base + schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
									view/constants-ordinal
							]
							expected-field: selected-field
						]
						field-byte-offset: field-value data symbol-result/types expected-field
							schema/WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET
						if byte-offset <> field-byte-offset [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								view/parts-ordinal
						]
						field-type: field-value data symbol-result/types expected-field
							schema/WIRE_RSIR_FIELD_TYPE_OFFSET
						if part-type <> field-type [
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								view/parts-ordinal
						]
					]
					constant-kind = schema/WIRE_CONSTANT_KIND_ADDRESS [
						if byte-offset <> 0 [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								view/parts-ordinal
						]
						if part-type <> constant-type [
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								view/parts-ordinal
						]
					]
					true [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
							(part-base + schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
							view/parts-ordinal
					]
				]

				child: part-value data view part-id
					schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET
				target: part-value data view part-id
					schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET
				addend-offset: part-value data view part-id
					schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET
				if (part-value data view part-id schema/WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET)
					<> schema/WIRE_CONSTANT_PART_FLAG_NONE
				[
					return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_FLAGS
						(part-base + schema/WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET)
						view/parts-ordinal
				]

				case [
					part-kind = schema/WIRE_CONSTANT_PART_KIND_VALUE [
						if constant-kind = schema/WIRE_CONSTANT_KIND_ADDRESS [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET)
								view/parts-ordinal
						]
						if any [child <= 0 child > view/constant-count][
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CHILD_CONSTANT
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
						if child >= constant-id [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_ORDER
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
						if (constant-value data view child schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							<> part-type
						[
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								view/parts-ordinal
						]
						if any [target <> 0 addend-offset <> 0][
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								view/parts-ordinal
						]
					]
					part-kind = schema/WIRE_CONSTANT_PART_KIND_SYMBOL_ADDRESS [
						if any [target <= 0 target > symbol-result/view/symbol-count][
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								view/parts-ordinal
						]
						symbol-kind: symbol-value data symbol-result/view target
							schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
						unless find reduce [
							schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL
							schema/WIRE_SYMBOL_KIND_CONSTANT
						] symbol-kind [
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL_KIND
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								view/parts-ordinal
						]
						either symbol-kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
							unless all [
								(type-value data symbol-result/types part-type
									schema/WIRE_RSIR_TYPE_KIND_OFFSET)
									= schema/WIRE_TYPE_KIND_FUNCTION
								(type-value data symbol-result/types part-type
									schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
									= (symbol-value data symbol-result/view target
										schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
							][
								return reject result
									schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
									(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
									view/parts-ordinal
							]
						][
							unless all [
								(type-value data symbol-result/types part-type
									schema/WIRE_RSIR_TYPE_KIND_OFFSET)
									= schema/WIRE_TYPE_KIND_POINTER
								(type-value data symbol-result/types part-type
									schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
									= (symbol-value data symbol-result/view target
										schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
							][
								return reject result
									schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
									(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
									view/parts-ordinal
							]
						]
						if child <> 0 [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
					]
					part-kind = schema/WIRE_CONSTANT_PART_KIND_CONSTANT_ADDRESS [
						if any [child <= 0 child > view/constant-count][
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CHILD_CONSTANT
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
						if child >= constant-id [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_ORDER
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
						unless all [
							(constant-value data view child schema/WIRE_RSIR_CONSTANT_KIND_OFFSET)
								= schema/WIRE_CONSTANT_KIND_STORAGE
							(constant-value data view child schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
								= part-type
						][
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								view/parts-ordinal
						]
						if target <> 0 [
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								view/parts-ordinal
						]
					]
					part-kind = schema/WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS [
						unless pointer-like-kind? (type-value data symbol-result/types part-type
							schema/WIRE_RSIR_TYPE_KIND_OFFSET) [
							return reject result
								schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								view/parts-ordinal
						]
						if any [child <> 0 target <> 0][
							return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								view/parts-ordinal
						]
					]
					true [assert false "unreachable constant part kind"]
				]

				if part-kind <> schema/WIRE_CONSTANT_PART_KIND_VALUE [
					if addend-offset <> data-cursor [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_OFFSET
							(part-base
								+ schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET)
							view/parts-ordinal
					]
					finish: container/checked-add addend-offset 8
					if any [none? finish finish > view/constant-data-size][
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_RANGE
							(part-base
								+ schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET)
							view/parts-ordinal
					]
					direct-data-base: view/constant-data-offset + addend-offset
					bad-offset: either
						part-kind = schema/WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS
					[
						first-bad-absolute-addend-byte data direct-data-base
					][
						first-bad-relative-addend-byte data direct-data-base
					]
					if bad-offset [
						return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_ENCODING
							bad-offset view/constant-data-ordinal
					]
					data-cursor: finish
				]

				if constant-kind = schema/WIRE_CONSTANT_KIND_STORAGE [
					bad-offset: first-nonzero-offset data
						(view/constant-data-offset + data-offset + byte-offset) part-size
					if bad-offset [
						return reject result
							schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_PLACEHOLDER
							bad-offset view/constant-data-ordinal
					]
				]

				part-id: part-id + 1
				part-cursor: part-cursor + 1
				owned-part-count: owned-part-count - 1
			]
			constant-id: constant-id + 1
		]

		if part-cursor <> (view/part-count + 1) [
			return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_PART_COVERAGE
				(view/parts-offset + ((part-cursor - 1) * schema/WIRE_RSIR_CONSTANT_PART_SIZE))
				view/parts-ordinal
		]
		view/constant-data-owned-size: data-cursor
		if all [
			(select target-fragments 'record-count) = 0
			data-cursor <> view/constant-data-size
		][
			return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_COVERAGE
				(view/constant-data-offset + data-cursor) view/constant-data-ordinal
		]

		previous-symbol: 0
		binding-id: 1
		while [binding-id <= view/binding-count][
			binding-base: record-offset view/bindings-offset (binding-id - 1)
				schema/WIRE_RSIR_CONSTANT_BINDING_SIZE
			binding-symbol: binding-value data view binding-id
				schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET
			if any [binding-symbol <= 0 binding-symbol > symbol-result/view/symbol-count][
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					view/bindings-ordinal
			]
			if (symbol-value data symbol-result/view binding-symbol
				schema/WIRE_RSIR_SYMBOL_KIND_OFFSET) <> schema/WIRE_SYMBOL_KIND_CONSTANT
			[
				return reject result
					schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL_KIND
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					view/bindings-ordinal
			]
			binding-constant: binding-value data view binding-id
				schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET
			if any [binding-constant <= 0 binding-constant > view/constant-count][
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_CONSTANT
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET)
					view/bindings-ordinal
			]
			if (constant-value data view binding-constant schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
				<> (symbol-value data symbol-result/view binding-symbol
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
			[
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_TYPE_MISMATCH
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET)
					view/bindings-ordinal
			]
			if binding-symbol < previous-symbol [
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_ORDER
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					view/bindings-ordinal
			]
			if binding-symbol = previous-symbol [
				return reject result
					schema/WIRE_CONSTANT_INITIALIZER_ERROR_DUPLICATE_BINDING_SYMBOL
					(binding-base + schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					view/bindings-ordinal
			]
			previous-symbol: binding-symbol
			binding-id: binding-id + 1
		]

		binding-cursor: 1
		symbol-id: 1
		while [symbol-id <= symbol-result/view/symbol-count][
			symbol-kind: symbol-value data symbol-result/view symbol-id
				schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			if symbol-kind = schema/WIRE_SYMBOL_KIND_CONSTANT [
				if any [
					binding-cursor > view/binding-count
					(binding-value data view binding-cursor
						schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET) <> symbol-id
				][
					return reject result
						schema/WIRE_CONSTANT_INITIALIZER_ERROR_MISSING_CONSTANT_BINDING
						(record-offset symbol-result/view/symbols-offset (symbol-id - 1)
							schema/WIRE_RSIR_SYMBOL_SIZE
							+ schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
						symbol-result/view/symbols-ordinal
				]
				binding-cursor: binding-cursor + 1
			]
			symbol-id: symbol-id + 1
		]

		global-id: 1
		while [global-id <= symbol-result/view/global-count][
			global-base: record-offset symbol-result/view/globals-offset (global-id - 1)
				schema/WIRE_RSIR_GLOBAL_SIZE
			initializer: global-value data symbol-result/view global-id
				schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET
			if initializer > view/constant-count [
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_INITIALIZER
					(global-base + schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET)
					symbol-result/view/globals-ordinal
			]
			if all [
				initializer > 0
				(constant-value data view initializer schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET)
					<> (global-value data symbol-result/view global-id
						schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET)
			][
				return reject result
					schema/WIRE_CONSTANT_INITIALIZER_ERROR_GLOBAL_INITIALIZER_TYPE_MISMATCH
					(global-base + schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET)
					symbol-result/view/globals-ordinal
			]
			constant-type: global-value data symbol-result/view global-id
				schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET
			type-alignment: type-value data symbol-result/types constant-type
				schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			alignment: global-value data symbol-result/view global-id
				schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET
			if all [
				alignment <> 0
				any [
					not container/power-of-two? alignment
					alignment < type-alignment
					alignment > select symbol-result/layout 'max-aggregate-alignment
				]
			][
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_ALIGNMENT
					(global-base + schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET)
					symbol-result/view/globals-ordinal
			]
			storage-class: global-value data symbol-result/view global-id
				schema/WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET
			if storage-class <> schema/WIRE_GLOBAL_STORAGE_CLASS_MUTABLE [
				return reject result
					schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_STORAGE_CLASS
					(global-base + schema/WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET)
					symbol-result/view/globals-ordinal
			]
			if (global-value data symbol-result/view global-id schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET)
				<> schema/WIRE_GLOBAL_FLAG_NONE
			[
				return reject result schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_GLOBAL_FLAGS
					(global-base + schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET)
					symbol-result/view/globals-ordinal
			]
			global-id: global-id + 1
		]

		result/strings: symbol-result/strings
		result/files: symbol-result/files
		result/layout: symbol-result/layout
		result/types: symbol-result/types
		result/functions: symbol-result/functions
		result/modules: symbol-result/modules
		result/symbols: symbol-result/view
		result/view: view
		result/valid?: true
		result
	]
]
