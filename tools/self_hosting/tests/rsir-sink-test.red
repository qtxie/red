Red [
	Title: "Hybrid compiler minimal RSIR semantic sink tests"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/wire-schema.red
#include %../../../compiler/wire-writer.red
#include %../../../compiler/rsir-producer.red
#include %../../../compiler/rsir-sink.red

schema: compiler-wire-schema
sink: compiler-rsir-sink

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

state: sink/new
	none
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert sink/add-function state 'fn [] [] "sink rejected its supported function"
artifact: sink/finish state
assert binary? artifact "sink did not produce RSIR"
assert (length? artifact) = 1396 "sink output size changed"
assert (checksum artifact 'SHA256) =
	#{8353248CDBC69D83181C09D2668C4DF1879503004D23C890B079953F2EEA8DBE}
	"sink output bytes changed"
assert none? sink/last-error "sink retained an error after success"
assert none? sink/finish state "sink allowed a second finish"
assert sink/last-error/code = sink/ERROR-STATE "sink reported the wrong second-finish error"

state: sink/new none schema/WIRE_MODULE_KIND_USER schema/WIRE_IMAGE_KIND_EXECUTABLE
assert sink/add-function state 'first [] [] "sink rejected the first function"
assert not sink/add-function state 'second [] [] "sink accepted a second function"
assert sink/last-error/code = sink/ERROR-FUNCTION-COUNT
	"sink reported the wrong duplicate-function error"

state: sink/new none schema/WIRE_MODULE_KIND_USER schema/WIRE_IMAGE_KIND_EXECUTABLE
assert not sink/add-function state 'typed [return: [integer!]] []
	"sink accepted a typed function"
assert sink/last-error/code = sink/ERROR-UNSUPPORTED
	"sink reported the wrong typed-function error"

state: sink/new none schema/WIRE_MODULE_KIND_USER schema/WIRE_IMAGE_KIND_EXECUTABLE
assert not sink/add-function state 'body [] [1]
	"sink accepted a nonempty function body"
assert sink/last-error/code = sink/ERROR-UNSUPPORTED
	"sink reported the wrong nonempty-body error"

state: sink/new none schema/WIRE_MODULE_KIND_USER schema/WIRE_IMAGE_KIND_EXECUTABLE
assert none? sink/finish state "sink finished a module without a function"
assert sink/last-error/code = sink/ERROR-FUNCTION-COUNT
	"sink reported the wrong missing-function error"

state: sink/new/limit
	none
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
	1395
assert sink/add-function state 'fn [] [] "bounded sink rejected its function"
assert none? sink/finish state "bounded sink ignored the output limit"
assert sink/last-error/code = sink/ERROR-PRODUCER
	"bounded sink did not propagate its producer failure"

print "PASS: minimal RSIR semantic sink"
