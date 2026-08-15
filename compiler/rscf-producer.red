Red [
	Title: "Hybrid compiler Red-side RSCF producer"
	File:  %rscf-producer.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-writer [do %wire-writer.red]

; Translate the compiler job into the bounded native-codegen contract. This
; producer deliberately exposes only configuration the current backend honors.
compiler-rscf-producer: context [
	schema: compiler-wire-schema
	writer-api: compiler-wire-writer
	ERROR-SUCCESS: 0
	ERROR-ARGUMENTS: 1
	ERROR-TARGET: 2
	ERROR-OPTIMIZATION: 3
	ERROR-UNSUPPORTED: 4
	ERROR-LIMIT: 5
	ERROR-WRITER: 6
	DEFAULT-MAX-OUTPUT-BYTES: 16777216
	DEFAULT-MAX-DIAGNOSTIC-BYTES: 65536
	last-error: none

	set-error: func [
		code [integer!]
		message [string!]
		field [word! none!]
		value
		/local record
	][
		record: make object! [
			code: 0
			message: none
			field: none
			value: none
		]
		record/code: code
		record/message: message
		record/field: field
		set in record 'value :value
		last-error: record
		none
	]

	required-job?: func [job [object!] /local field][
		foreach field [OS format target ABI opt-level debug? PIC?][
			unless in job field [return false]
		]
		true
	]

	build: func [
		job [object!]
		/limits max-output-bytes max-diagnostic-bytes [integer!]
		/local OS format target ABI optimization debug? PIC? flags relocation-model
			debug-format writer status
	][
		last-error: none
		unless required-job? job [
			return set-error ERROR-ARGUMENTS
				"RSCF producer requires a complete compiler job"
				none none
		]
		OS: get in job 'OS
		format: get in job 'format
		target: get in job 'target
		ABI: get in job 'ABI
		unless all [
			OS = 'Windows
			format = 'PE
			target = 'X86-64
			ABI = 'win64
		][
			return set-error ERROR-TARGET
				"RSCF producer currently supports only Windows x64 PE with the Win64 ABI"
				'target target
		]

		optimization: get in job 'opt-level
		unless all [
			integer? optimization
			optimization >= schema/WIRE_OPTIMIZATION_LEVEL_O0
			optimization <= schema/WIRE_OPTIMIZATION_LEVEL_O1
		][
			return set-error ERROR-OPTIMIZATION
				"RSCF producer currently supports only O0 and O1"
				'opt-level optimization
		]

		debug?: get in job 'debug?
		PIC?: get in job 'PIC?
		unless all [logic? debug? logic? PIC?][
			return set-error ERROR-ARGUMENTS
				"RSCF producer requires logic debug and PIC options"
				none none
		]
		if any [debug? PIC?][
			return set-error ERROR-UNSUPPORTED
				"RSCF producer slice does not yet support debug or PIC codegen"
				either debug? ['debug?]['PIC?]
			true
		]

		max-output-bytes: any [max-output-bytes DEFAULT-MAX-OUTPUT-BYTES]
		max-diagnostic-bytes: any [
			max-diagnostic-bytes DEFAULT-MAX-DIAGNOSTIC-BYTES
		]
		if any [
			max-output-bytes < schema/WIRE_RSCG_MINIMUM_SIZE
			max-output-bytes > writer-api/MAX-SCALAR
		][
			return set-error ERROR-LIMIT
				"RSCF maximum output size is outside the protocol range"
				'max-output-bytes max-output-bytes
		]
		if any [
			max-diagnostic-bytes < 0
			max-diagnostic-bytes > writer-api/MAX-SCALAR
			all [
				max-diagnostic-bytes <> 0
				max-diagnostic-bytes < schema/WIRE_RSDG_MINIMUM_SIZE
			]
		][
			return set-error ERROR-LIMIT
				"RSCF maximum diagnostic size is outside the protocol range"
				'max-diagnostic-bytes max-diagnostic-bytes
		]

		flags: schema/WIRE_CONFIG_FLAG_DETERMINISTIC
		relocation-model: schema/WIRE_RELOCATION_MODEL_STATIC
		debug-format: schema/WIRE_DEBUG_FORMAT_NONE
		writer: writer-api/new
			schema/WIRE_MAGIC_RSCF
			schema/WIRE_TARGET_X86_64
			schema/WIRE_ABI_WIN64
			schema/WIRE_ENDIAN_LITTLE
			8
			schema/WIRE_RSCF_REQUIRED_SECTION_COUNT
			schema/WIRE_RSCF_MINIMUM_SIZE
			schema/WIRE_RSCF_MINIMUM_SIZE
		if writer/error <> writer-api/ERROR-SUCCESS [
			return set-error ERROR-WRITER
				"RSCF producer could not initialize its writer"
				none writer/error
		]
		status: writer-api/start-section writer schema/WIRE_RSCF_SECTION_CONFIG 0
		if status <> writer-api/ERROR-SUCCESS [
			return set-error ERROR-WRITER
				"RSCF producer could not start its config section"
				none status
		]
		status: writer-api/words writer reduce [
			optimization
			flags
			schema/WIRE_CODE_MODEL_SMALL
			relocation-model
			debug-format
			schema/WIRE_CPU_BASELINE_X86_64_BASE
			0 0
			max-output-bytes
			max-diagnostic-bytes
			1
			0
			0 0 0 0
		]
		if status <> writer-api/ERROR-SUCCESS [
			return set-error ERROR-WRITER
				"RSCF producer could not write its config record"
				none status
		]
		status: writer-api/end-section writer
		if status <> writer-api/ERROR-SUCCESS [
			return set-error ERROR-WRITER
				"RSCF producer could not finish its config section"
				none status
		]
		status: writer-api/finish writer
		if status <> writer-api/ERROR-SUCCESS [
			return set-error ERROR-WRITER
				"RSCF producer could not finish its message"
				none status
		]
		copy writer/output
	]
]
