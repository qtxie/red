Red/System [
	Title: "Generated compiler wire constants smoke test"
]

#include %../../../system/codegen/wire-schema.reds

status: 0
if WIRE_VERSION_MAJOR <> 1 [status: 1]
if WIRE_MAGIC_RSIR <> 1380537170 [status: 2]
if WIRE_HEADER_SIZE <> 64 [status: 3]
if WIRE_DIRECTORY_SIZE <> 32 [status: 4]
if WIRE_SCHEMA_FINGERPRINT <> 195193392 [status: 5]

either status = 0 [
	print ["PASS: Red/System compiler wire schema" lf]
][
	print ["FAIL: Red/System compiler wire schema " status lf]
]
quit status
