Red [
	Title: "Hybrid compiler minimal RSIR producer tests"
]

do %../../../compiler/wire-target-intrinsic.red
do %../../../compiler/wire-atomic.red
do %../../../compiler/wire-memory-aggregate.red
do %../../../compiler/rsir-producer.red

schema: compiler-wire-schema
producer: compiler-rsir-producer
container: compiler-wire-container

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

verify-rsir: func [name [string!] data [binary!] /local result][
	result: compiler-wire-target-intrinsic/verify data
	assert result/valid? [name " target verifier error=" result/error]
	result: compiler-wire-atomic/verify data
	assert result/valid? [name " atomic verifier error=" result/error]
	result: compiler-wire-memory-aggregate/verify data
	assert result/valid? [name " memory verifier error=" result/error]
]

anonymous: producer/build-empty-void-module
	none 'fn
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? anonymous "producer rejected its supported anonymous module"
assert none? producer/last-error "producer retained an error after success"
assert (length? anonymous) = 1396 "minimal producer output size changed"
verify-rsir "anonymous" anonymous
assert anonymous = producer/build-empty-void-module
	none "fn"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	"producer output is not deterministic across word/string names"

parsed: container/verify/expect anonymous schema/WIRE_MAGIC_RSIR
assert parsed/valid? "producer output failed common container verification"
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
symbol-section: container/find-section parsed schema/WIRE_RSIR_SECTION_SYMBOLS
assert (container/read-u32 anonymous (select module-section 'payload-offset)) = 0
	"anonymous module acquired a name ID"
assert (container/read-u32 anonymous (select symbol-section 'payload-offset)) = 2
	"function name did not receive the expected canonical ID"

named: producer/build-empty-void-module
	"z-module" "a-function"
	schema/WIRE_MODULE_KIND_SUPPORT
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? named "producer rejected a supported named module"
verify-rsir "named" named
parsed: container/verify/expect named schema/WIRE_MAGIC_RSIR
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
symbol-section: container/find-section parsed schema/WIRE_RSIR_SECTION_SYMBOLS
assert (container/read-u32 named (select module-section 'payload-offset)) = 3
	"named module string ID is not canonical"
assert (container/read-u32 named (select symbol-section 'payload-offset)) = 2
	"named function string ID is not canonical"

glue: producer/build-empty-void-module
	none "entry"
	schema/WIRE_MODULE_KIND_GLUE
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? glue "producer rejected a supported glue entry module"
verify-rsir "glue" glue
parsed: container/verify/expect glue schema/WIRE_MAGIC_RSIR
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
module-offset: select module-section 'payload-offset
assert all [
	(container/read-u32 glue
		(module-offset + schema/WIRE_RSIR_MODULE_KIND_OFFSET))
		= schema/WIRE_MODULE_KIND_GLUE
	(container/read-u32 glue
		(module-offset + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)) = 1
]["glue module did not retain its sole entry function"]

deduplicated: producer/build-empty-void-module
	"same" "same"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? deduplicated "producer rejected shared module/function spelling"
verify-rsir "deduplicated" deduplicated
parsed: container/verify/expect deduplicated schema/WIRE_MAGIC_RSIR
strings-section: container/find-section parsed schema/WIRE_RSIR_SECTION_STRINGS
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
symbol-section: container/find-section parsed schema/WIRE_RSIR_SECTION_SYMBOLS
assert (select strings-section 'record-count) = 2
	"producer did not deduplicate canonical strings"
assert all [
	(container/read-u32 deduplicated (select module-section 'payload-offset)) = 2
	(container/read-u32 deduplicated (select symbol-section 'payload-offset)) = 2
]["deduplicated names do not share one string ID"]

case-distinct: producer/build-empty-void-module
	"Z" "z"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? case-distinct "producer collapsed case-distinct names"
verify-rsir "case-distinct" case-distinct
parsed: container/verify/expect case-distinct schema/WIRE_MAGIC_RSIR
strings-section: container/find-section parsed schema/WIRE_RSIR_SECTION_STRINGS
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
symbol-section: container/find-section parsed schema/WIRE_RSIR_SECTION_SYMBOLS
assert (select strings-section 'record-count) = 3
	"producer deduplicated case-distinct UTF-8 strings"
assert all [
	(container/read-u32 case-distinct (select module-section 'payload-offset)) = 2
	(container/read-u32 case-distinct (select symbol-section 'payload-offset)) = 3
]["case-distinct names received noncanonical IDs"]

too-small: producer/build-empty-void-module/limit
	none "fn"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	1395
assert none? too-small "producer ignored its output limit"
assert producer/last-error/code = producer/ERROR-LIMIT
	"producer reported the wrong bounded-output error"

assert none? producer/build-empty-void-module
	none ""
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	"producer accepted an empty function name"
assert producer/last-error/code = producer/ERROR-NAME
	"producer reported the wrong empty-name error"

assert none? producer/build-empty-void-module
	"" "fn"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	"producer accepted an empty present module name"
assert producer/last-error/code = producer/ERROR-NAME
	"producer reported the wrong module-name error"

assert none? producer/build-empty-void-module
	none "bad^(00)name"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	"producer accepted an embedded NUL in a function name"
assert producer/last-error/code = producer/ERROR-NAME
	"producer reported the wrong embedded-NUL error"

assert none? producer/build-empty-void-module
	none "fn"
	schema/WIRE_MODULE_KIND_RUNTIME
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	"producer accepted a runtime module outside its slice"
assert producer/last-error/code = producer/ERROR-KIND
	"producer reported the wrong module-kind error"

assert none? producer/build-empty-void-module
	none "fn"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
	"producer accepted a dynamic library outside its slice"
assert producer/last-error/code = producer/ERROR-KIND
	"producer reported the wrong image-kind error"

print "PASS: minimal Red-side RSIR producer"
