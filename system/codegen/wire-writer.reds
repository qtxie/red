Red/System [
	Title: "Hybrid compiler deterministic wire container writer"
	File:  %wire-writer.reds
]

#include %wire-reader.reds
#include %wire-arena.reds

wire-container-writer!: alias struct! [
	arena              [wire-arena!]
	magic              [integer!]
	section-count      [integer!]
	section-index      [integer!]
	last-kind          [integer!]
	section-kind       [integer!]
	section-flags      [integer!]
	section-record-size [integer!]
	section-alignment  [integer!]
	section-start      [integer!]
	section-open       [integer!]
	finished           [integer!]
	error              [integer!]
]

wire-container-writer: context [
	ERROR_SUCCESS:       0
	ERROR_ARGUMENTS:     1
	ERROR_STATE:         2
	ERROR_SECTION:       3
	ERROR_RECORD_SIZE:   4
	ERROR_ARENA:         5

	set-error: func [
		writer [wire-container-writer!]
		code [integer!]
		return: [integer!]
	][
		if writer <> null [writer/error: code]
		code
	]

	write-le16: func [data [byte-ptr!] offset value [integer!]][
		data: data + offset
		data/1: as byte! value
		data/2: as byte! (value >>> 8)
	]

	write-le32: func [data [byte-ptr!] offset value [integer!]][
		data: data + offset
		data/1: as byte! value
		data/2: as byte! (value >>> 8)
		data/3: as byte! (value >>> 16)
		data/4: as byte! (value >>> 24)
	]

	begin: func [
		writer [wire-container-writer!]
		arena [wire-arena!]
		limit initial-capacity magic target abi endian pointer-size
		features-low features-high producer-build section-count [integer!]
		return: [integer!]
		/local directory-size directory-end status known required [integer!]
	][
		if any [null? writer null? arena][return ERROR_ARGUMENTS]
		writer/arena: arena
		writer/magic: magic
		writer/section-count: section-count
		writer/section-index: 0
		writer/last-kind: 0
		writer/section-kind: 0
		writer/section-flags: 0
		writer/section-record-size: 0
		writer/section-alignment: 0
		writer/section-start: -1
		writer/section-open: 0
		writer/finished: 0
		writer/error: ERROR_SUCCESS

		known: wire-container-reader/known-section-count magic
		required: wire-container-reader/required-section-count magic
		if any [
			known < 0
			section-count < required
			section-count > known
			limit < 0
			initial-capacity < 0
		][return set-error writer ERROR_ARGUMENTS]
		directory-size: wire-container-reader/checked-multiply
			section-count WIRE_DIRECTORY_SIZE
		if directory-size < 0 [return set-error writer ERROR_ARGUMENTS]
		directory-end: wire-container-reader/checked-add WIRE_HEADER_SIZE directory-size
		if directory-end < 0 [return set-error writer ERROR_ARGUMENTS]
		if initial-capacity < directory-end [initial-capacity: directory-end]
		status: wire-arena/init arena limit initial-capacity
		if status <> wire-arena/ERROR_SUCCESS [
			return set-error writer ERROR_ARENA
		]
		status: wire-arena/append-zero arena directory-end
		if status <> wire-arena/ERROR_SUCCESS [
			return set-error writer ERROR_ARENA
		]

		write-le32 arena/data WIRE_HEADER_MAGIC_OFFSET magic
		write-le16 arena/data WIRE_HEADER_VERSION_MAJOR_OFFSET WIRE_VERSION_MAJOR
		write-le16 arena/data WIRE_HEADER_VERSION_MINOR_OFFSET WIRE_VERSION_MINOR
		write-le32 arena/data WIRE_HEADER_HEADER_SIZE_OFFSET WIRE_HEADER_SIZE
		write-le32 arena/data WIRE_HEADER_CONTAINER_FLAGS_OFFSET 0
		write-le32 arena/data WIRE_HEADER_TOTAL_SIZE_OFFSET 0
		write-le32 arena/data WIRE_HEADER_SECTION_COUNT_OFFSET section-count
		write-le32 arena/data WIRE_HEADER_DIRECTORY_OFFSET_OFFSET WIRE_HEADER_SIZE
		write-le32 arena/data WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET WIRE_DIRECTORY_SIZE
		write-le32 arena/data WIRE_HEADER_TARGET_OFFSET target
		write-le32 arena/data WIRE_HEADER_ABI_OFFSET abi
		write-le32 arena/data WIRE_HEADER_TARGET_ENDIAN_OFFSET endian
		write-le32 arena/data WIRE_HEADER_POINTER_SIZE_OFFSET pointer-size
		write-le32 arena/data WIRE_HEADER_FEATURE_MASK_LOW_OFFSET features-low
		write-le32 arena/data WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET features-high
		write-le32 arena/data WIRE_HEADER_PRODUCER_BUILD_OFFSET producer-build
		write-le32 arena/data WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET WIRE_SCHEMA_FINGERPRINT
		ERROR_SUCCESS
	]

	start-section: func [
		writer [wire-container-writer!]
		kind flags [integer!]
		return: [integer!]
		/local record-size alignment [integer!]
	][
		if null? writer [return ERROR_ARGUMENTS]
		if writer/error <> ERROR_SUCCESS [return writer/error]
		if any [
			writer/finished <> 0
			writer/section-open <> 0
			writer/section-index >= writer/section-count
			kind <= writer/last-kind
		][return set-error writer ERROR_STATE]
		record-size: wire-container-reader/expected-record-size writer/magic kind
		alignment: wire-container-reader/expected-alignment writer/magic kind
		if any [record-size <= 0 alignment <= 0][
			return set-error writer ERROR_SECTION
		]
		writer/section-kind: kind
		writer/section-flags: flags
		writer/section-record-size: record-size
		writer/section-alignment: alignment
		writer/section-start: -1
		writer/section-open: 1
		ERROR_SUCCESS
	]

	ensure-section-start: func [
		writer [wire-container-writer!]
		return: [integer!]
		/local status [integer!]
	][
		if any [null? writer writer/section-open = 0][return ERROR_STATE]
		if writer/section-start >= 0 [return ERROR_SUCCESS]
		status: wire-arena/align writer/arena writer/section-alignment
		if status <> wire-arena/ERROR_SUCCESS [
			return set-error writer ERROR_ARENA
		]
		writer/section-start: writer/arena/size
		ERROR_SUCCESS
	]

	append-bytes: func [
		writer [wire-container-writer!]
		data [byte-ptr!]
		count [integer!]
		return: [integer!]
		/local status [integer!]
	][
		if any [null? writer count < 0 all [count > 0 null? data]][
			return set-error writer ERROR_ARGUMENTS
		]
		if writer/error <> ERROR_SUCCESS [return writer/error]
		if writer/section-open = 0 [return set-error writer ERROR_STATE]
		if count = 0 [return ERROR_SUCCESS]
		status: ensure-section-start writer
		if status <> ERROR_SUCCESS [return status]
		status: wire-arena/append writer/arena data count
		if status <> wire-arena/ERROR_SUCCESS [
			return set-error writer ERROR_ARENA
		]
		ERROR_SUCCESS
	]

	append-u32: func [
		writer [wire-container-writer!]
		value [integer!]
		return: [integer!]
		/local status offset [integer!]
	][
		if null? writer [return ERROR_ARGUMENTS]
		if writer/error <> ERROR_SUCCESS [return writer/error]
		if writer/section-open = 0 [return set-error writer ERROR_STATE]
		status: ensure-section-start writer
		if status <> ERROR_SUCCESS [return status]
		status: wire-arena/ensure writer/arena 4
		if status <> wire-arena/ERROR_SUCCESS [
			return set-error writer ERROR_ARENA
		]
		offset: writer/arena/size
		writer/arena/size: offset + 4
		write-le32 writer/arena/data offset value
		ERROR_SUCCESS
	]

	end-section: func [
		writer [wire-container-writer!]
		return: [integer!]
		/local payload-offset payload-size record-count entry [integer!]
	][
		if null? writer [return ERROR_ARGUMENTS]
		if writer/error <> ERROR_SUCCESS [return writer/error]
		if writer/section-open = 0 [return set-error writer ERROR_STATE]
		either writer/section-start < 0 [
			payload-offset: 0
			payload-size: 0
			record-count: 0
		][
			payload-offset: writer/section-start
			payload-size: writer/arena/size - payload-offset
			if (payload-size // writer/section-record-size) <> 0 [
				return set-error writer ERROR_RECORD_SIZE
			]
			record-count: payload-size / writer/section-record-size
		]
		entry: WIRE_HEADER_SIZE + (writer/section-index * WIRE_DIRECTORY_SIZE)
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_KIND_OFFSET)
			writer/section-kind
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_FLAGS_OFFSET)
			writer/section-flags
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET)
			payload-offset
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET)
			payload-size
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_RECORD_COUNT_OFFSET)
			record-count
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_RECORD_SIZE_OFFSET)
			writer/section-record-size
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_ALIGNMENT_OFFSET)
			writer/section-alignment
		write-le32 writer/arena/data (entry + WIRE_DIRECTORY_RESERVED_OFFSET) 0

		writer/last-kind: writer/section-kind
		writer/section-index: writer/section-index + 1
		writer/section-open: 0
		writer/section-start: -1
		ERROR_SUCCESS
	]

	empty-section: func [
		writer [wire-container-writer!]
		kind flags [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: start-section writer kind flags
		if status <> ERROR_SUCCESS [return status]
		end-section writer
	]

	finish: func [
		writer [wire-container-writer!]
		return: [integer!]
	][
		if null? writer [return ERROR_ARGUMENTS]
		if writer/error <> ERROR_SUCCESS [return writer/error]
		if any [
			writer/section-open <> 0
			writer/finished <> 0
			writer/section-index <> writer/section-count
		][return set-error writer ERROR_STATE]
		write-le32 writer/arena/data WIRE_HEADER_TOTAL_SIZE_OFFSET writer/arena/size
		writer/finished: 1
		ERROR_SUCCESS
	]
]
