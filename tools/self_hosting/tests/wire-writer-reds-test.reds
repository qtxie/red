Red/System [
	Title: "Hybrid compiler native arena and container writer tests"
]

#include %../../../system/codegen/wire-writer.reds
#include %../../../system/codegen/wire-rscg-metadata.reds

append-word: func [
	writer [wire-container-writer!]
	value [integer!]
	return: [integer!]
][
	wire-container-writer/append-u32 writer value
]

build-empty-rscg: func [
	writer [wire-container-writer!]
	arena [wire-arena!]
	limit [integer!]
	return: [integer!]
	/local status flags [integer!]
][
	flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED
	status: wire-container-writer/begin writer arena limit 576 WIRE_MAGIC_RSCG
		WIRE_TARGET_X86_64 WIRE_ABI_WIN64 WIRE_ENDIAN_LITTLE 8 0 0 1
		WIRE_RSCG_REQUIRED_SECTION_COUNT
	if status <> 0 [return status]

	status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_DATA_LAYOUT 0
	if status <> 0 [return status]
	status: append-word writer 1
	if status = 0 [status: append-word writer 8]
	if status = 0 [status: append-word writer 8]
	if status = 0 [status: append-word writer 16]
	if status = 0 [status: append-word writer 8]
	if status = 0 [status: append-word writer 8]
	if status = 0 [status: append-word writer 8]
	if status = 0 [status: append-word writer 0]
	if status <> 0 [return status]
	status: wire-container-writer/end-section writer
	if status <> 0 [return status]

	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_STRINGS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_STRING_DATA 0
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_OUTPUT_SECTIONS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_OUTPUT_DATA 0
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_SYMBOLS
		WIRE_SECTION_FLAG_SORTED
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_RELOCATIONS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_IMPORTS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_EXPORTS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_FUNCTIONS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_FILES flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA 0
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_DEBUG_LINES
		WIRE_SECTION_FLAG_SORTED
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_DEBUG_PARAMETERS flags
	if status <> 0 [return status]
	status: wire-container-writer/empty-section writer WIRE_RSCG_SECTION_GC_FRAMES flags
	if status <> 0 [return status]

	status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_MODULES 0
	if status <> 0 [return status]
	status: append-word writer 0
	if status = 0 [status: append-word writer 2]
	if status = 0 [status: append-word writer 1]
	if status = 0 [status: append-word writer 0]
	if status = 0 [status: append-word writer 0]
	if status = 0 [status: append-word writer 0]
	if status = 0 [status: append-word writer 0]
	if status = 0 [status: append-word writer 0]
	if status <> 0 [return status]
	status: wire-container-writer/end-section writer
	if status <> 0 [return status]
	wire-container-writer/finish writer
]

failures: 0
arena: declare wire-arena!
wire-arena/reset arena

status: wire-arena/init arena 1024 4
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
status: wire-arena/append-zero arena 600
if any [status <> wire-arena/ERROR_SUCCESS arena/size <> 600 arena/capacity < 600][
	failures: failures + 1
]
status: wire-arena/align arena 64
if any [status <> wire-arena/ERROR_SUCCESS arena/size <> 640][
	failures: failures + 1
]
wire-arena/release arena

status: wire-arena/init arena 8 4
if status <> wire-arena/ERROR_SUCCESS [failures: failures + 1]
status: wire-arena/append-zero arena 9
if any [status <> wire-arena/ERROR_LIMIT arena/size <> 0][failures: failures + 1]
wire-arena/release arena

writer: declare wire-container-writer!
status: build-empty-rscg writer arena 640
if status <> wire-container-writer/ERROR_SUCCESS [
	print ["FAIL: writer status=" status " arena=" arena/error lf]
	failures: failures + 1
]
if arena/size <> WIRE_RSCG_MINIMUM_SIZE [
	print ["FAIL: RSCG size=" arena/size lf]
	failures: failures + 1
]

metadata-result: declare wire-rscg-metadata-result!
strings: declare wire-string-table!
files: declare wire-file-source!
layout: declare wire-data-layout!
modules: declare wire-module-lifecycle!
object-view: declare wire-rscg-object!
relocation-view: declare wire-rscg-relocation!
metadata-view: declare wire-rscg-metadata!
status: wire-rscg-metadata-reader/verify arena/data arena/size metadata-result
	strings files layout modules object-view relocation-view metadata-view
if status <> WIRE_RSCG_METADATA_ERROR_SUCCESS [
	print [
		"FAIL: generated RSCG rejected=" status
		" reloc=" metadata-result/relocation-error
		" object=" metadata-result/object-error
		" at=" metadata-result/error-offset ":" metadata-result/error-section lf
	]
	failures: failures + 1
]
wire-arena/release arena

status: build-empty-rscg writer arena 639
if any [
	status <> wire-container-writer/ERROR_ARENA
	arena/error <> wire-arena/ERROR_LIMIT
][failures: failures + 1]
wire-arena/release arena

status: wire-container-writer/begin writer arena 640 576 WIRE_MAGIC_RSCG
	WIRE_TARGET_X86_64 WIRE_ABI_WIN64 WIRE_ENDIAN_LITTLE 8 0 0 1
	WIRE_RSCG_REQUIRED_SECTION_COUNT
if status = 0 [
	status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_DATA_LAYOUT 0
]
if status = 0 [status: wire-container-writer/append-u32 writer 1]
if status = 0 [status: wire-container-writer/end-section writer]
if status <> wire-container-writer/ERROR_RECORD_SIZE [failures: failures + 1]
wire-arena/release arena

either failures = 0 [
	print ["PASS: Red/System bounded arena and deterministic wire writer" lf]
][
	print ["FAIL: Red/System wire writer failures=" failures lf]
]
quit failures
