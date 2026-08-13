Red [
	Title: "Hybrid compiler diagnostic semantic verifier"
	File:  %wire-diagnostics.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-string-table [do %wire-string-table.red]

compiler-wire-diagnostics: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	string-verifier: compiler-wire-string-table

	allowed-record-flags:
		schema/WIRE_DIAGNOSTIC_FLAG_FILE
		+ schema/WIRE_DIAGNOSTIC_FLAG_SOURCE
		+ schema/WIRE_DIAGNOSTIC_FLAG_FUNCTION
		+ schema/WIRE_DIAGNOSTIC_FLAG_INSTRUCTION

	diagnostic-fields: reduce [
		'status             schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET
		'severity           schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET
		'phase              schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET
		'message-string     schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET
		'file               schema/WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET
		'line               schema/WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET
		'column             schema/WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET
		'function-symbol    schema/WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET
		'instruction        schema/WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET
		'flags              schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
	]

	make-view: does [
		make object! [
			status: 0
			record-count: 0
			records-offset: 0
			records-ordinal: 0
			record-size: schema/WIRE_RSDG_DIAGNOSTIC_SIZE
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_DIAGNOSTIC_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
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

	string-size-for-id: func [
		data [binary!]
		table [object!]
		id [integer!]
		/local record-offset
	][
		if any [id <= 0 id > table/record-count][return none]
		record-offset: table/records-offset
			+ ((id - 1) * schema/WIRE_STRING_SIZE)
		container/read-i31 data
			(record-offset + schema/WIRE_STRING_SIZE_OFFSET)
	]

	valid-status-phase?: func [status phase [integer!]][
		if status = schema/WIRE_STATUS_INVALID_ARGUMENTS [
			return phase = schema/WIRE_DIAGNOSTIC_PHASE_BRIDGE
		]
		if status = schema/WIRE_STATUS_INVALID_CONFIGURATION [
			return phase = schema/WIRE_DIAGNOSTIC_PHASE_CONFIGURATION
		]
		if status = schema/WIRE_STATUS_INVALID_RSIR [
			return any [
				phase = schema/WIRE_DIAGNOSTIC_PHASE_DECODE
				phase = schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
			]
		]
		if status = schema/WIRE_STATUS_UNSUPPORTED_TARGET [
			return any [
				phase = schema/WIRE_DIAGNOSTIC_PHASE_CONFIGURATION
				phase = schema/WIRE_DIAGNOSTIC_PHASE_DECODE
				phase = schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
				phase = schema/WIRE_DIAGNOSTIC_PHASE_SELECT
				phase = schema/WIRE_DIAGNOSTIC_PHASE_ENCODE
			]
		]
		if status = schema/WIRE_STATUS_CODEGEN_FAILURE [
			return any [
				phase = schema/WIRE_DIAGNOSTIC_PHASE_OPTIMIZE
				phase = schema/WIRE_DIAGNOSTIC_PHASE_SELECT
				phase = schema/WIRE_DIAGNOSTIC_PHASE_ALLOCATE
				phase = schema/WIRE_DIAGNOSTIC_PHASE_ENCODE
			]
		]
		if status = schema/WIRE_STATUS_INVALID_ARTIFACT [
			return phase = schema/WIRE_DIAGNOSTIC_PHASE_ARTIFACT
		]
		false
	]

	verify: func [
		data expected-magic
		/local result container-result string-result strings-table diagnostics-section
			record-count records-offset section-ordinal record-index record-offset
			field-name field-offset value status primary-status severity phase
			message-string file line column function-symbol instruction flags
			message-size has-file? has-source? has-function? has-instruction?
			target view
	][
		result: make-result
		unless all [binary? data integer? expected-magic][
			return reject result schema/WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS 0 0
		]
		if expected-magic <> schema/WIRE_MAGIC_RSDG [
			return reject result schema/WIRE_DIAGNOSTIC_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container-result: container/verify/expect data expected-magic
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_DIAGNOSTIC_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		string-result: string-verifier/verify data expected-magic
		unless string-result/valid? [
			result/container-error: string-result/container-error
			result/string-error: string-result/error
			return reject result schema/WIRE_DIAGNOSTIC_ERROR_INVALID_STRINGS
				string-result/error-offset string-result/error-section
		]
		strings-table: string-result/table

		diagnostics-section: container/find-section container-result
			schema/WIRE_RSDG_SECTION_DIAGNOSTICS
		if none? diagnostics-section [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_DIAGNOSTIC_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]
		section-ordinal: select diagnostics-section 'ordinal
		if (select diagnostics-section 'flags) <> 0 [
			return reject result
				schema/WIRE_DIAGNOSTIC_ERROR_BAD_DIAGNOSTIC_SECTION_FLAGS
				((select diagnostics-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				section-ordinal
		]

		record-count: select diagnostics-section 'record-count
		records-offset: select diagnostics-section 'payload-offset

		; Validate every signed scalar before interpreting any diagnostic record.
		record-index: 0
		while [record-index < record-count][
			record-offset: records-offset
				+ (record-index * schema/WIRE_RSDG_DIAGNOSTIC_SIZE)
			foreach [field-name field-offset] diagnostic-fields [
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
						(record-offset + field-offset) section-ordinal
				]
			]
			record-index: record-index + 1
		]

		target: select container-result/header 'target
		primary-status: container/read-i31 data
			(records-offset + schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
		record-index: 0
		while [record-index < record-count][
			record-offset: records-offset
				+ (record-index * schema/WIRE_RSDG_DIAGNOSTIC_SIZE)
			status: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
			severity: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET)
			phase: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET)
			message-string: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
			file: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET)
			line: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET)
			column: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET)
			function-symbol: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET)
			instruction: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET)
			flags: container/read-i31 data
				(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)

			if any [
				status < schema/WIRE_STATUS_INVALID_ARGUMENTS
				status > schema/WIRE_STATUS_INVALID_ARTIFACT
			][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_STATUS
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
					section-ordinal
			]
			if status <> primary-status [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_INCONSISTENT_STATUS
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
					section-ordinal
			]
			if any [
				severity < schema/WIRE_DIAGNOSTIC_SEVERITY_NOTE
				severity > schema/WIRE_DIAGNOSTIC_SEVERITY_FATAL
			][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_SEVERITY
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET)
					section-ordinal
			]
			if all [
				record-index = 0
				severity <> schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
				severity <> schema/WIRE_DIAGNOSTIC_SEVERITY_FATAL
			][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_PRIMARY_SEVERITY
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET)
					section-ordinal
			]
			if any [
				phase < schema/WIRE_DIAGNOSTIC_PHASE_BRIDGE
				phase > schema/WIRE_DIAGNOSTIC_PHASE_ARTIFACT
			][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_PHASE
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET)
					section-ordinal
			]
			unless valid-status-phase? status phase [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_STATUS_PHASE
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET)
					section-ordinal
			]
			message-size: string-size-for-id data strings-table message-string
			if none? message-size [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_MESSAGE_STRING
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
					section-ordinal
			]
			if zero? message-size [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_EMPTY_MESSAGE
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
					section-ordinal
			]
			unless (flags and allowed-record-flags) = flags [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_FLAGS
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
					section-ordinal
			]

			has-file?: (flags and schema/WIRE_DIAGNOSTIC_FLAG_FILE) <> 0
			has-source?: (flags and schema/WIRE_DIAGNOSTIC_FLAG_SOURCE) <> 0
			has-function?: (flags and schema/WIRE_DIAGNOSTIC_FLAG_FUNCTION) <> 0
			has-instruction?:
				(flags and schema/WIRE_DIAGNOSTIC_FLAG_INSTRUCTION) <> 0

			if all [has-source? not has-file?][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_SOURCE_WITHOUT_FILE
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
					section-ordinal
			]
			if all [has-instruction? not has-function?][
				return reject result
					schema/WIRE_DIAGNOSTIC_ERROR_INSTRUCTION_WITHOUT_FUNCTION
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
					section-ordinal
			]
			if has-file? <> (file <> 0) [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_FILE_ID
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET)
					section-ordinal
			]
			if has-source? <> (line <> 0) [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_LINE
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET)
					section-ordinal
			]
			if has-source? <> (column <> 0) [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_COLUMN
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET)
					section-ordinal
			]
			if has-function? <> (function-symbol <> 0) [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_FUNCTION_ID
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET)
					section-ordinal
			]
			if has-instruction? <> (instruction <> 0) [
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_BAD_INSTRUCTION_ID
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET)
					section-ordinal
			]
			if all [flags <> 0 target = schema/WIRE_TARGET_NONE][
				return reject result schema/WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET
					(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
					section-ordinal
			]
			record-index: record-index + 1
		]

		view: make-view
		view/status: primary-status
		view/record-count: record-count
		view/records-offset: records-offset
		view/records-ordinal: section-ordinal
		view/record-size: select diagnostics-section 'record-size
		result/strings: strings-table
		result/view: view
		result/valid?: true
		result
	]
]
