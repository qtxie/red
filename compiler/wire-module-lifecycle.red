Red [
	Title: "Hybrid compiler module lifecycle verifier"
	File:  %wire-module-lifecycle.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-file-source [do %wire-file-source.red]

compiler-wire-module-lifecycle: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	metadata-verifier: compiler-wire-file-source

	make-view: does [
		make object! [
			module-count: 0
			modules-offset: 0
			modules-ordinal: 0
			module-record-size: 0
			reference-count: 0
			image-kind: 0
			glue-module: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
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

	module-section-kind: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSIR [schema/WIRE_RSIR_SECTION_MODULE]
			magic = schema/WIRE_MAGIC_RSCG [schema/WIRE_RSCG_SECTION_MODULES]
			true [none]
		]
	]

	reference-section-kind: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSIR [schema/WIRE_RSIR_SECTION_FUNCTIONS]
			magic = schema/WIRE_MAGIC_RSCG [schema/WIRE_RSCG_SECTION_SYMBOLS]
			true [none]
		]
	]

	module-record-offset: func [view [object!] index [integer!]][
		view/modules-offset + (index * view/module-record-size)
	]

	module-value: func [
		data [binary!]
		view [object!]
		id field-offset [integer!]
	][
		container/read-i31 data
			((module-record-offset view (id - 1)) + field-offset)
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

	verify: func [
		data expected-magic
		/local result module-kind reference-kind container-result metadata-result
			modules references view module-count reference-count record-index
			record-offset field-offset value module-id name-string kind
			image-kind initializer finalizer entry source-location flags reserved
			string-size first-image glue-module symbol-id symbol-offset origin
			module-reference reference-offset name-offset kind-offset image-offset
			initializer-offset finalizer-offset entry-offset
	][
		result: make-result
		unless all [binary? data integer? expected-magic][
			return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS 0 0
		]
		module-kind: module-section-kind expected-magic
		reference-kind: reference-section-kind expected-magic
		if any [none? module-kind none? reference-kind][
			return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]
		either expected-magic = schema/WIRE_MAGIC_RSIR [
			name-offset: schema/WIRE_RSIR_MODULE_NAME_STRING_OFFSET
			kind-offset: schema/WIRE_RSIR_MODULE_KIND_OFFSET
			image-offset: schema/WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET
			initializer-offset: schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET
			finalizer-offset: schema/WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET
			entry-offset: schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET
		][
			name-offset: schema/WIRE_RSCG_MODULE_NAME_STRING_OFFSET
			kind-offset: schema/WIRE_RSCG_MODULE_KIND_OFFSET
			image-offset: schema/WIRE_RSCG_MODULE_IMAGE_KIND_OFFSET
			initializer-offset: schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
			finalizer-offset: schema/WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET
			entry-offset: schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
		]

		container-result: container/verify/expect data expected-magic
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		metadata-result: metadata-verifier/verify data expected-magic
		unless metadata-result/valid? [
			result/container-error: metadata-result/container-error
			result/string-error: metadata-result/string-error
			result/file-source-error: metadata-result/error
			case [
				metadata-result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
						metadata-result/error-offset metadata-result/error-section
				]
				metadata-result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS
						metadata-result/error-offset metadata-result/error-section
				]
				true [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE
						metadata-result/error-offset metadata-result/error-section
				]
			]
		]

		modules: container/find-section container-result module-kind
		references: container/find-section container-result reference-kind
		if any [none? modules none? references][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]
		if (select modules 'flags) <> 0 [
			return reject result
				schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_SECTION_FLAGS
				((select modules 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select modules 'ordinal)
		]

		view: make-view
		view/module-count: module-count: select modules 'record-count
		view/modules-offset: select modules 'payload-offset
		view/modules-ordinal: select modules 'ordinal
		view/module-record-size: select modules 'record-size
		view/reference-count: reference-count: select references 'record-count

		; Decode all module scalars before following any reference.
		record-index: 0
		while [record-index < module-count][
			record-offset: module-record-offset view record-index
			field-offset: 0
			while [field-offset < view/module-record-size][
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_SCALAR_RANGE
						(record-offset + field-offset) view/modules-ordinal
				]
				field-offset: field-offset + 4
			]
			record-index: record-index + 1
		]

		; RSCG symbol ownership is consumed here, so decode that scalar before use.
		if expected-magic = schema/WIRE_MAGIC_RSCG [
			symbol-id: 1
			while [symbol-id <= reference-count][
				symbol-offset: (select references 'payload-offset)
					+ ((symbol-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				origin: container/read-i31 data
					(symbol-offset + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
				if none? origin [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_SCALAR_RANGE
						(symbol-offset + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						(select references 'ordinal)
				]
				symbol-id: symbol-id + 1
			]
		]

		first-image: 0
		glue-module: 0
		module-id: 1
		while [module-id <= module-count][
			record-offset: module-record-offset view (module-id - 1)
			name-string: module-value data view module-id name-offset
			kind: module-value data view module-id kind-offset
			image-kind: module-value data view module-id image-offset
			initializer: module-value data view module-id initializer-offset
			finalizer: module-value data view module-id finalizer-offset
			entry: module-value data view module-id entry-offset
			either expected-magic = schema/WIRE_MAGIC_RSIR [
				source-location: module-value data view module-id
					schema/WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET
				flags: module-value data view module-id schema/WIRE_RSIR_MODULE_FLAGS_OFFSET
				reserved: 0
			][
				source-location: 0
				flags: module-value data view module-id schema/WIRE_RSCG_MODULE_FLAGS_OFFSET
				reserved: module-value data view module-id
					schema/WIRE_RSCG_MODULE_RESERVED_OFFSET
			]

			if any [name-string < 0 name-string > metadata-result/strings/record-count][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_NAME_ID
					(record-offset + name-offset) view/modules-ordinal
			]
			if name-string > 0 [
				string-size: string-size-for-id data metadata-result/strings name-string
				if zero? string-size [
					return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_EMPTY_NAME
						(record-offset + name-offset) view/modules-ordinal
				]
			]
			unless all [
				kind >= schema/WIRE_MODULE_KIND_RUNTIME
				kind <= schema/WIRE_MODULE_KIND_GLUE
			][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_KIND
					(record-offset + kind-offset) view/modules-ordinal
			]
			unless any [
				image-kind = schema/WIRE_IMAGE_KIND_EXECUTABLE
				image-kind = schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
			][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_IMAGE_KIND
					(record-offset + image-offset) view/modules-ordinal
			]
			if any [initializer < 0 initializer > reference-count][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_INITIALIZER_ID
					(record-offset + initializer-offset) view/modules-ordinal
			]
			if any [finalizer < 0 finalizer > reference-count][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_FINALIZER_ID
					(record-offset + finalizer-offset) view/modules-ordinal
			]
			if any [entry < 0 entry > reference-count][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_ENTRY_ID
					(record-offset + entry-offset) view/modules-ordinal
			]
			if all [
				expected-magic = schema/WIRE_MAGIC_RSIR
				any [
					source-location < 0
					source-location > metadata-result/view/source-count
				]
			][
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_SOURCE_LOCATION
					(record-offset + schema/WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET)
					view/modules-ordinal
			]
			if flags <> 0 [
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_FLAGS
					(record-offset + either expected-magic = schema/WIRE_MAGIC_RSIR [
						schema/WIRE_RSIR_MODULE_FLAGS_OFFSET
					][schema/WIRE_RSCG_MODULE_FLAGS_OFFSET])
					view/modules-ordinal
			]
			if reserved <> 0 [
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_RESERVED
					(record-offset + schema/WIRE_RSCG_MODULE_RESERVED_OFFSET)
					view/modules-ordinal
			]

			if first-image = 0 [first-image: image-kind]
			if image-kind <> first-image [
				return reject result schema/WIRE_MODULE_LIFECYCLE_ERROR_IMAGE_KIND_MISMATCH
					(record-offset + image-offset) view/modules-ordinal
			]
			either kind = schema/WIRE_MODULE_KIND_GLUE [
				if glue-module <> 0 [
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_MULTIPLE_GLUE_MODULES
						(record-offset + kind-offset)
						view/modules-ordinal
				]
				glue-module: module-id
				if initializer <> 0 [
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + initializer-offset)
						view/modules-ordinal
				]
				if finalizer <> 0 [
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + finalizer-offset)
						view/modules-ordinal
				]
				if entry = 0 [
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + entry-offset)
						view/modules-ordinal
				]
			][
				if entry <> 0 [
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + entry-offset)
						view/modules-ordinal
				]
			]
			module-id: module-id + 1
		]

		if expected-magic = schema/WIRE_MAGIC_RSCG [
			symbol-id: 1
			while [symbol-id <= reference-count][
				symbol-offset: (select references 'payload-offset)
					+ ((symbol-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				origin: container/read-i31 data
					(symbol-offset + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
				if any [origin <= 0 origin > module-count][
					return reject result
						schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_SYMBOL_ORIGIN_MODULE
						(symbol-offset + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						(select references 'ordinal)
				]
				symbol-id: symbol-id + 1
			]

			module-id: 1
			while [module-id <= module-count][
				record-offset: module-record-offset view (module-id - 1)
				foreach reference-offset reduce [
					schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
					schema/WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET
					schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
				][
					module-reference: container/read-i31 data
						(record-offset + reference-offset)
					if module-reference <> 0 [
						symbol-offset: (select references 'payload-offset)
							+ ((module-reference - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
						origin: container/read-i31 data
							(symbol-offset + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						if origin <> module-id [
							return reject result
								schema/WIRE_MODULE_LIFECYCLE_ERROR_LIFECYCLE_SYMBOL_OWNER
								(record-offset + reference-offset) view/modules-ordinal
						]
					]
				]
				module-id: module-id + 1
			]
		]

		view/image-kind: first-image
		view/glue-module: glue-module
		result/strings: metadata-result/strings
		result/files: metadata-result/view
		result/view: view
		result/valid?: true
		result
	]
]
