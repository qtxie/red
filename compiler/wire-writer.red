Red [
	Title: "Hybrid compiler Red wire container writer"
	File:  %wire-writer.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'int-to-bin [do %int-to-bin.red]

; This writer owns only container layout.  Semantic table ordering and flags
; remain the responsibility of the producer that supplies each section.
compiler-wire-writer: context [
	schema: compiler-wire-schema
	ERROR-SUCCESS: 0
	ERROR-ARGUMENTS: 1
	ERROR-MAGIC: 2
	ERROR-STATE: 3
	ERROR-SECTION: 4
	ERROR-FLAGS: 5
	ERROR-RECORD-SIZE: 6
	ERROR-LIMIT: 7
	ERROR-FINISH: 8
	MAX-SCALAR: 2147483647

	profile-for: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSCF [schema/profiles/RSCF]
			magic = schema/WIRE_MAGIC_RSIR [schema/profiles/RSIR]
			magic = schema/WIRE_MAGIC_RSCG [schema/profiles/RSCG]
			magic = schema/WIRE_MAGIC_RSDG [schema/profiles/RSDG]
			true [none]
		]
	]

	wire-scalar?: func [value [integer!]][
		all [value >= 0 value <= MAX-SCALAR]
	]

	align-size: func [size alignment [integer!] /local remainder][
		if any [size < 0 alignment <= 0][return none]
		remainder: size // alignment
		either zero? remainder [size][size + alignment - remainder]
	]

	write-u16-at: func [data [binary!] offset value [integer!]][
		change/part at data (offset + 1) int-to-bin/to-bin16 value 2
	]

	write-u32-at: func [data [binary!] offset value [integer!]][
		change/part at data (offset + 1) int-to-bin/to-bin32 value 4
	]

	set-error: func [writer [object!] code [integer!]][
		writer/error: code
		code
	]

	new: func [
		magic target abi endian pointer-size section-count limit capacity [integer!]
		/local writer profile required known directory-size directory-end
	][
		writer: make object! [
			output: make binary! 0
			magic: 0
			limit: 0
			section-count: 0
			section-index: 0
			last-kind: 0
			section-kind: 0
			section-flags: 0
			section-record-size: 0
			section-alignment: 0
			section-start: -1
			section-open?: false
			finished?: false
			error: ERROR-SUCCESS
		]
		writer/magic: magic
		writer/limit: limit
		writer/section-count: section-count
		profile: profile-for magic
		if none? profile [set-error writer ERROR-MAGIC return writer]
		required: profile/required-count
		known: profile/known-count
		if any [
			not wire-scalar? magic
			not wire-scalar? target
			not wire-scalar? abi
			not wire-scalar? endian
			not wire-scalar? pointer-size
			not wire-scalar? section-count
			section-count < required
			section-count > known
			limit <= 0
			capacity < 0
			capacity > limit
		][set-error writer ERROR-ARGUMENTS return writer]
		directory-size: section-count * schema/WIRE_DIRECTORY_SIZE
		directory-end: schema/WIRE_HEADER_SIZE + directory-size
		if capacity < directory-end [set-error writer ERROR-ARGUMENTS return writer]
		writer/output: make binary! capacity
		if directory-end > limit [set-error writer ERROR-LIMIT return writer]
		append/dup writer/output 0 directory-end
		write-u32-at writer/output schema/WIRE_HEADER_MAGIC_OFFSET magic
		write-u16-at writer/output schema/WIRE_HEADER_VERSION_MAJOR_OFFSET
			schema/WIRE_VERSION_MAJOR
		write-u16-at writer/output schema/WIRE_HEADER_VERSION_MINOR_OFFSET
			schema/WIRE_VERSION_MINOR
		write-u32-at writer/output schema/WIRE_HEADER_HEADER_SIZE_OFFSET
			schema/WIRE_HEADER_SIZE
		write-u32-at writer/output schema/WIRE_HEADER_CONTAINER_FLAGS_OFFSET 0
		write-u32-at writer/output schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 0
		write-u32-at writer/output schema/WIRE_HEADER_SECTION_COUNT_OFFSET section-count
		write-u32-at writer/output schema/WIRE_HEADER_DIRECTORY_OFFSET_OFFSET
			schema/WIRE_HEADER_SIZE
		write-u32-at writer/output schema/WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET
			schema/WIRE_DIRECTORY_SIZE
		write-u32-at writer/output schema/WIRE_HEADER_TARGET_OFFSET target
		write-u32-at writer/output schema/WIRE_HEADER_ABI_OFFSET abi
		write-u32-at writer/output schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET endian
		write-u32-at writer/output schema/WIRE_HEADER_POINTER_SIZE_OFFSET pointer-size
		write-u32-at writer/output schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
		write-u32-at writer/output schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 0
		write-u32-at writer/output schema/WIRE_HEADER_PRODUCER_BUILD_OFFSET 1
		write-u32-at writer/output schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET
			schema/WIRE_SCHEMA_FINGERPRINT
		writer
	]

	ensure-space: func [writer [object!] count [integer!]][
		if any [count < 0 (length? writer/output) > (MAX-SCALAR - count)][
			return set-error writer ERROR-LIMIT
		]
		if (length? writer/output) + count > writer/limit [
			return set-error writer ERROR-LIMIT
		]
		ERROR-SUCCESS
	]

	start-section: func [
		writer [object!] kind flags [integer!]
		/local profile expected-kind record-size alignment
	][
		if any [none? writer writer/error <> ERROR-SUCCESS][
			return either none? writer [ERROR-ARGUMENTS][writer/error]
		]
		profile: profile-for writer/magic
		if any [
			writer/finished?
			writer/section-open?
			writer/section-index >= writer/section-count
			kind <= writer/last-kind
			kind <= 0
			kind > profile/known-count
			flags < 0
			flags > (schema/WIRE_SECTION_FLAG_OPTIONAL
				+ schema/WIRE_SECTION_FLAG_SORTED
				+ schema/WIRE_SECTION_FLAG_DEDUPLICATED)
		][return set-error writer ERROR-SECTION]
		either writer/section-index < profile/required-count [
			expected-kind: writer/section-index + 1
			if kind <> expected-kind [return set-error writer ERROR-SECTION]
			if (flags and schema/WIRE_SECTION_FLAG_OPTIONAL) <> 0 [
				return set-error writer ERROR-FLAGS
			]
		][
			if (flags and schema/WIRE_SECTION_FLAG_OPTIONAL) = 0 [
				return set-error writer ERROR-FLAGS
			]
		]
		record-size: pick profile/record-sizes kind
		alignment: pick profile/alignments kind
		if any [record-size <= 0 alignment <= 0][
			return set-error writer ERROR-SECTION
		]
		writer/section-kind: kind
		writer/section-flags: flags
		writer/section-record-size: record-size
		writer/section-alignment: alignment
		writer/section-start: -1
		writer/section-open?: true
		ERROR-SUCCESS
	]

	ensure-section-start: func [writer [object!] /local aligned padding status][
		if any [none? writer not writer/section-open?][return ERROR-STATE]
		if writer/section-start >= 0 [return ERROR-SUCCESS]
		aligned: align-size length? writer/output writer/section-alignment
		if none? aligned [return set-error writer ERROR-SECTION]
		padding: aligned - length? writer/output
		status: ensure-space writer padding
		if status <> ERROR-SUCCESS [return status]
		if padding > 0 [append/dup writer/output 0 padding]
		writer/section-start: length? writer/output
		ERROR-SUCCESS
	]

	bytes: func [writer [object!] data [binary!] /local status][
		if any [none? writer none? data][return ERROR-ARGUMENTS]
		if writer/error <> ERROR-SUCCESS [return writer/error]
		if not writer/section-open? [return set-error writer ERROR-STATE]
		if empty? data [return ERROR-SUCCESS]
		status: ensure-section-start writer
		if status <> ERROR-SUCCESS [return status]
		status: ensure-space writer length? data
		if status <> ERROR-SUCCESS [return status]
		append writer/output data
		ERROR-SUCCESS
	]

	u32: func [writer [object!] value [integer!] /local status][
		status: bytes writer int-to-bin/to-bin32 value
		status
	]

	words: func [writer [object!] values [block!] /local value status][
		if any [none? writer none? values][return ERROR-ARGUMENTS]
		foreach value values [
			unless integer? :value [return set-error writer ERROR-ARGUMENTS]
			status: u32 writer value
			if status <> ERROR-SUCCESS [return status]
		]
		ERROR-SUCCESS
	]

	end-section: func [writer [object!] /local payload-size payload-offset count entry status][
		if any [none? writer writer/error <> ERROR-SUCCESS][
			return either none? writer [ERROR-ARGUMENTS][writer/error]
		]
		if any [writer/finished? not writer/section-open?][
			return set-error writer ERROR-STATE
		]
		either writer/section-start < 0 [
			payload-offset: 0
			payload-size: 0
			count: 0
		][
			payload-offset: writer/section-start
			payload-size: (length? writer/output) - payload-offset
			if (payload-size // writer/section-record-size) <> 0 [
				return set-error writer ERROR-RECORD-SIZE
			]
			count: payload-size / writer/section-record-size
		]
		entry: schema/WIRE_HEADER_SIZE
			+ (writer/section-index * schema/WIRE_DIRECTORY_SIZE)
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_KIND_OFFSET)
			writer/section-kind
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
			writer/section-flags
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET)
			payload-offset
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET)
			payload-size
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET)
			count
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_RECORD_SIZE_OFFSET)
			writer/section-record-size
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET)
			writer/section-alignment
		write-u32-at writer/output (entry + schema/WIRE_DIRECTORY_RESERVED_OFFSET) 0
		writer/last-kind: writer/section-kind
		writer/section-index: writer/section-index + 1
		writer/section-open?: false
		writer/section-start: -1
		ERROR-SUCCESS
	]

	empty-section: func [writer [object!] kind flags [integer!] /local status][
		status: start-section writer kind flags
		if status <> ERROR-SUCCESS [return status]
		end-section writer
	]

	finish: func [writer [object!] /local status][
		if any [none? writer writer/error <> ERROR-SUCCESS][
			return either none? writer [ERROR-ARGUMENTS][writer/error]
		]
		if any [writer/finished? writer/section-open?]
			[return set-error writer ERROR-STATE]
		if writer/section-index <> writer/section-count [
			return set-error writer ERROR-FINISH
		]
		status: ensure-space writer 0
		if status <> ERROR-SUCCESS [return status]
		write-u32-at writer/output schema/WIRE_HEADER_TOTAL_SIZE_OFFSET
			length? writer/output
		writer/finished?: true
		ERROR-SUCCESS
	]
]
