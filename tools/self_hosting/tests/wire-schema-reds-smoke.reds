Red/System [
	Title: "Generated compiler wire constants smoke test"
]

#include %../../../system/codegen/wire-reader.reds

status: 0
if WIRE_VERSION_MAJOR <> 1 [status: 1]
if WIRE_MAGIC_RSIR <> 1380537170 [status: 2]
if WIRE_HEADER_SIZE <> 64 [status: 3]
if WIRE_DIRECTORY_SIZE <> 32 [status: 4]
if WIRE_SCHEMA_FINGERPRINT <> 363884945 [status: 5]
if WIRE_RSIR_REQUIRED_SECTION_COUNT <> 30 [status: 6]
if WIRE_RSCG_REQUIRED_SECTION_COUNT <> 16 [status: 7]
if WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_REQUIRED <> 0 [status: 8]
if (wire-container-reader/checked-add 64 32) <> 96 [status: 9]
if (wire-container-reader/checked-multiply 4 32) <> 128 [status: 10]
if (wire-container-reader/checked-multiply 7FFFFFFFh 2) <> -1 [status: 11]
if WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA <> 6 [status: 12]
if WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA <> 12 [status: 13]
if WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE <> 22 [status: 14]
if WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET <> 23 [status: 15]
if WIRE_DIAGNOSTIC_FLAG_INSTRUCTION <> 8 [status: 16]
if WIRE_TYPE_KIND_UNION <> 8 [status: 17]
if WIRE_TYPE_FLAG_C_STRING <> 4 [status: 18]
if WIRE_TYPE_LAYOUT_ERROR_NONZERO_RESERVED <> 26 [status: 19]
if WIRE_RSIR_TYPE_SIZE <> 40 [status: 20]
if WIRE_RSIR_TYPE_RESERVED_0_OFFSET <> 16 [status: 21]
if WIRE_RSIR_TYPE_DETAIL_ID_OFFSET <> 20 [status: 22]
if WIRE_RSIR_TYPE_RESERVED_1_OFFSET <> 24 [status: 23]
if WIRE_RSCG_SECTION_MODULES_CARDINALITY <> WIRE_SECTION_CARDINALITY_NONEMPTY [status: 24]
if WIRE_MODULE_KIND_GLUE <> 4 [status: 25]
if WIRE_IMAGE_KIND_DYNAMIC_LIBRARY <> 2 [status: 26]
if WIRE_MODULE_LIFECYCLE_ERROR_LIFECYCLE_SYMBOL_OWNER <> 22 [status: 27]
if WIRE_DEBUG_TYPE_CODE_AGGREGATE <> 100 [status: 28]
if WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_COVERAGE <> 54 [status: 29]
if WIRE_OPCODE_SET_UNION_VARIANT <> 58 [status: 30]
if WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_VARIANT <> 27 [status: 31]

either status = 0 [
	print ["PASS: Red/System compiler wire schema" lf]
][
	print ["FAIL: Red/System compiler wire schema " status lf]
]
quit status
