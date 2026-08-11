Red/System [
	Title: "Generated compiler wire constants smoke test"
]

#include %../../../system/codegen/wire-reader.reds

status: 0
if WIRE_VERSION_MAJOR <> 1 [status: 1]
if WIRE_MAGIC_RSIR <> 1380537170 [status: 2]
if WIRE_HEADER_SIZE <> 64 [status: 3]
if WIRE_DIRECTORY_SIZE <> 32 [status: 4]
if WIRE_SCHEMA_FINGERPRINT <> 1338324974 [status: 5]
if WIRE_RSIR_REQUIRED_SECTION_COUNT <> 29 [status: 6]
if WIRE_RSCG_REQUIRED_SECTION_COUNT <> 15 [status: 7]
if WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_REQUIRED <> 0 [status: 8]
if (wire-container-reader/checked-add 64 32) <> 96 [status: 9]
if (wire-container-reader/checked-multiply 4 32) <> 128 [status: 10]
if (wire-container-reader/checked-multiply 7FFFFFFFh 2) <> -1 [status: 11]
if WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA <> 6 [status: 12]
if WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA <> 12 [status: 13]
if WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE <> 22 [status: 14]

either status = 0 [
	print ["PASS: Red/System compiler wire schema" lf]
][
	print ["FAIL: Red/System compiler wire schema " status lf]
]
quit status
