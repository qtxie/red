Red/System [
	Title: "Hybrid compiler diagnostic semantic verifier"
	File:  %wire-diagnostics.reds
]

#include %wire-string-table.reds

wire-diagnostic-result!: alias struct! [
	error           [integer!]
	container-error [integer!]
	string-error    [integer!]
	error-offset    [integer!]
	error-section   [integer!]
]

wire-diagnostics!: alias struct! [
	status          [integer!]
	records         [byte-ptr!]
	record-count    [integer!]
	record-size     [integer!]
	records-offset  [integer!]
	records-ordinal [integer!]
]

wire-diagnostic-reader: context [
	allowed-record-flags:
		WIRE_DIAGNOSTIC_FLAG_FILE
		or WIRE_DIAGNOSTIC_FLAG_SOURCE
		or WIRE_DIAGNOSTIC_FLAG_FUNCTION
		or WIRE_DIAGNOSTIC_FLAG_INSTRUCTION

	set-error: func [
		result [wire-diagnostic-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	set-container-error: func [
		result [wire-diagnostic-result!]
		container [wire-container-result!]
		code [integer!]
		return: [integer!]
	][
		result/container-error: code
		set-error result WIRE_DIAGNOSTIC_ERROR_INVALID_CONTAINER
			container/error-offset container/error-section
	]

	section-flags-offset: func [
		section [wire-section-slice!]
		return: [integer!]
	][
		WIRE_HEADER_SIZE
			+ (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
				+ WIRE_DIRECTORY_FLAGS_OFFSET)
	]

	valid-status-phase?: func [
		status phase [integer!]
		return: [logic!]
	][
		if status = WIRE_STATUS_INVALID_ARGUMENTS [
			return phase = WIRE_DIAGNOSTIC_PHASE_BRIDGE
		]
		if status = WIRE_STATUS_INVALID_CONFIGURATION [
			return phase = WIRE_DIAGNOSTIC_PHASE_CONFIGURATION
		]
		if status = WIRE_STATUS_INVALID_RSIR [
			return any [
				phase = WIRE_DIAGNOSTIC_PHASE_DECODE
				phase = WIRE_DIAGNOSTIC_PHASE_VERIFY
			]
		]
		if status = WIRE_STATUS_UNSUPPORTED_TARGET [
			return any [
				phase = WIRE_DIAGNOSTIC_PHASE_CONFIGURATION
				phase = WIRE_DIAGNOSTIC_PHASE_DECODE
				phase = WIRE_DIAGNOSTIC_PHASE_VERIFY
				phase = WIRE_DIAGNOSTIC_PHASE_SELECT
				phase = WIRE_DIAGNOSTIC_PHASE_ENCODE
			]
		]
		if status = WIRE_STATUS_CODEGEN_FAILURE [
			return any [
				phase = WIRE_DIAGNOSTIC_PHASE_OPTIMIZE
				phase = WIRE_DIAGNOSTIC_PHASE_SELECT
				phase = WIRE_DIAGNOSTIC_PHASE_ALLOCATE
				phase = WIRE_DIAGNOSTIC_PHASE_ENCODE
			]
		]
		if status = WIRE_STATUS_INVALID_ARTIFACT [
			return phase = WIRE_DIAGNOSTIC_PHASE_ARTIFACT
		]
		false
	]

	verify: func [
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-diagnostic-result!]
		strings [wire-string-table!]
		view [wire-diagnostics!]
		return: [integer!]
		/local container [wire-container-result!]
			string-result [wire-string-table-result!]
			verified-strings [wire-string-table!]
			diagnostics [wire-section-slice!]
			message [wire-string-slice!]
			status-code record-index record-offset value primary-status severity phase
			message-string file line column function-symbol instruction flags target [integer!]
			has-file? has-source? has-function? has-instruction? [logic!]
	][
		if null? result [return WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_DIAGNOSTIC_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [size < 0 null? data null? strings null? view][
			return set-error result WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS 0 0
		]
		if expected-magic <> WIRE_MAGIC_RSDG [
			return set-error result WIRE_DIAGNOSTIC_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container: declare wire-container-result!
		status-code: wire-container-reader/verify
			data size expected-magic container
		if status-code <> WIRE_CONTAINER_ERROR_SUCCESS [
			return set-container-error result container status-code
		]

		string-result: declare wire-string-table-result!
		verified-strings: declare wire-string-table!
		status-code: wire-string-table-reader/verify
			data size expected-magic string-result verified-strings
		if status-code <> WIRE_STRING_TABLE_ERROR_SUCCESS [
			result/container-error: string-result/container-error
			result/string-error: status-code
			return set-error result WIRE_DIAGNOSTIC_ERROR_INVALID_STRINGS
				string-result/error-offset string-result/error-section
		]

		diagnostics: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSDG_SECTION_DIAGNOSTICS diagnostics
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_DIAGNOSTIC_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		if diagnostics/flags <> 0 [
			return set-error result
				WIRE_DIAGNOSTIC_ERROR_BAD_DIAGNOSTIC_SECTION_FLAGS
				section-flags-offset diagnostics diagnostics/ordinal
		]

		; Validate every signed scalar before interpreting any diagnostic record.
		record-index: 0
		while [record-index < diagnostics/record-count][
			record-offset: record-index * WIRE_RSDG_DIAGNOSTIC_SIZE
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET
					diagnostics/ordinal
			]
			value: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
			if value < 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
					diagnostics/ordinal
			]
			record-index: record-index + 1
		]

		target: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_OFFSET
		primary-status: wire-container-reader/read-i31 diagnostics/data
			WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET
		record-index: 0
		while [record-index < diagnostics/record-count][
			record-offset: record-index * WIRE_RSDG_DIAGNOSTIC_SIZE
			status-code: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET)
			severity: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET)
			phase: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET)
			message-string: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
			file: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET)
			line: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET)
			column: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET)
			function-symbol: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET)
			instruction: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET)
			flags: wire-container-reader/read-i31 diagnostics/data
				(record-offset + WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)

			if any [
				status-code < WIRE_STATUS_INVALID_ARGUMENTS
				status-code > WIRE_STATUS_INVALID_ARTIFACT
			][
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_STATUS
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET
					diagnostics/ordinal
			]
			if status-code <> primary-status [
				return set-error result WIRE_DIAGNOSTIC_ERROR_INCONSISTENT_STATUS
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET
					diagnostics/ordinal
			]
			if any [
				severity < WIRE_DIAGNOSTIC_SEVERITY_NOTE
				severity > WIRE_DIAGNOSTIC_SEVERITY_FATAL
			][
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_SEVERITY
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET
					diagnostics/ordinal
			]
			if all [
				record-index = 0
				severity <> WIRE_DIAGNOSTIC_SEVERITY_ERROR
				severity <> WIRE_DIAGNOSTIC_SEVERITY_FATAL
			][
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_PRIMARY_SEVERITY
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET
					diagnostics/ordinal
			]
			if any [
				phase < WIRE_DIAGNOSTIC_PHASE_BRIDGE
				phase > WIRE_DIAGNOSTIC_PHASE_ARTIFACT
			][
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_PHASE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET
					diagnostics/ordinal
			]
			unless valid-status-phase? status-code phase [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_STATUS_PHASE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET
					diagnostics/ordinal
			]
			message: declare wire-string-slice!
			unless wire-string-table-reader/get-slice
				verified-strings message-string message
			[
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_MESSAGE_STRING
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET
					diagnostics/ordinal
			]
			if message/size = 0 [
				return set-error result WIRE_DIAGNOSTIC_ERROR_EMPTY_MESSAGE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET
					diagnostics/ordinal
			]
			unless (flags and allowed-record-flags) = flags [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_FLAGS
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
					diagnostics/ordinal
			]

			has-file?: (flags and WIRE_DIAGNOSTIC_FLAG_FILE) <> 0
			has-source?: (flags and WIRE_DIAGNOSTIC_FLAG_SOURCE) <> 0
			has-function?: (flags and WIRE_DIAGNOSTIC_FLAG_FUNCTION) <> 0
			has-instruction?: (flags and WIRE_DIAGNOSTIC_FLAG_INSTRUCTION) <> 0

			if all [has-source? not has-file?][
				return set-error result WIRE_DIAGNOSTIC_ERROR_SOURCE_WITHOUT_FILE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
					diagnostics/ordinal
			]
			if all [has-instruction? not has-function?][
				return set-error result
					WIRE_DIAGNOSTIC_ERROR_INSTRUCTION_WITHOUT_FUNCTION
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
					diagnostics/ordinal
			]
			if has-file? <> (file <> 0) [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_FILE_ID
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET
					diagnostics/ordinal
			]
			if has-source? <> (line <> 0) [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_LINE
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET
					diagnostics/ordinal
			]
			if has-source? <> (column <> 0) [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_COLUMN
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET
					diagnostics/ordinal
			]
			if has-function? <> (function-symbol <> 0) [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_FUNCTION_ID
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET
					diagnostics/ordinal
			]
			if has-instruction? <> (instruction <> 0) [
				return set-error result WIRE_DIAGNOSTIC_ERROR_BAD_INSTRUCTION_ID
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET
					diagnostics/ordinal
			]
			if all [flags <> 0 target = WIRE_TARGET_NONE][
				return set-error result WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET
					(diagnostics/offset + record-offset)
						+ WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
					diagnostics/ordinal
			]
			record-index: record-index + 1
		]

		strings/records: verified-strings/records
		strings/record-count: verified-strings/record-count
		strings/record-size: verified-strings/record-size
		strings/records-offset: verified-strings/records-offset
		strings/records-ordinal: verified-strings/records-ordinal
		strings/data: verified-strings/data
		strings/data-size: verified-strings/data-size
		strings/data-offset: verified-strings/data-offset
		strings/data-ordinal: verified-strings/data-ordinal

		view/status: primary-status
		view/records: diagnostics/data
		view/record-count: diagnostics/record-count
		view/record-size: diagnostics/record-size
		view/records-offset: diagnostics/offset
		view/records-ordinal: diagnostics/ordinal
		WIRE_DIAGNOSTIC_ERROR_SUCCESS
	]
]
