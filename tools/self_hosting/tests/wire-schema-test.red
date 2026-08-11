Red [
	Title: "Hybrid compiler wire schema tests"
]

do %../../../compiler/wire-schema-spec.red
do %../../../compiler/wire-schema-generator.red

assert: func [condition [logic!] message [string!]][
	unless condition [
		print ["FAIL:" message]
		quit/return 1
	]
]

generator: compiler-wire-schema-generator
assert generator/validate compiler-wire-schema-spec "schema validation failed"

expected-red: generator/render-red compiler-wire-schema-spec
expected-reds: generator/render-reds compiler-wire-schema-spec
assert expected-red = to string! read %../../../compiler/wire-schema.red
	"generated Red constants are stale"
assert expected-reds = to string! read %../../../system/codegen/wire-schema.reds
	"generated Red/System constants are stale"

do %../../../compiler/wire-schema.red
foreach [name value] generator/constants compiler-wire-schema-spec [
	field: in compiler-wire-schema name
	assert not none? field rejoin ["missing generated Red constant: " name]
	assert (get field) = value rejoin ["wrong generated Red constant: " name]
]

assert compiler-wire-schema/WIRE_HEADER_SIZE = 64 "wrong common header size"
assert compiler-wire-schema/WIRE_DIRECTORY_SIZE = 32 "wrong directory size"
assert compiler-wire-schema/WIRE_MAGIC_RSIR = 1380537170 "wrong RSIR magic encoding"
assert compiler-wire-schema/WIRE_SCHEMA_FINGERPRINT = generator/fingerprint compiler-wire-schema-spec
	"wrong schema fingerprint"

assert-rejected: func [bad [block!] message [string!] /constants /local error][
	error: try [either constants [generator/constants bad][generator/validate bad]]
	assert error? error message
]

bad: copy/deep compiler-wire-schema-spec
header: select select bad 'records 'HEADER
field: find select header 'fields 'TOTAL_SIZE
field/2: 63
assert-rejected bad "overlapping/out-of-bounds field was accepted"

bad: copy/deep compiler-wire-schema-spec
repend select bad 'enums ['TARGET copy []]
assert-rejected bad "duplicate enum group was accepted"

bad: copy/deep compiler-wire-schema-spec
header: select select bad 'records 'HEADER
fields: select header 'fields
fields/4: 'MAGIC
assert-rejected bad "duplicate record field was accepted"

bad: copy/deep compiler-wire-schema-spec
repend bad ['unexpected copy []]
assert-rejected bad "unknown top-level schema section was accepted"

bad: copy/deep compiler-wire-schema-spec
append select bad 'enums reduce [
	'HEADER reduce ['SIZE 99]
]
assert-rejected/constants bad "generated constant collision was accepted"

print [
	"PASS: compiler wire schema"
	compiler-wire-schema/WIRE_SCHEMA_FINGERPRINT
]
