Red [
	Title: "Frontend type layout and legacy emitter parity"
]

#include %../../../system/compiler-windows-bootstrap.red
#include %../../../compiler/system-types.red
#include %../../../compiler/system-target-model.red
#include %../../../compiler/system-layout.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check-equal: func [label [string!] expected actual][
	unless :expected = :actual [
		fail [
			label
			" expected=" mold :expected
			" actual=" mold :actual
		]
	]
]

check-target: func [name [word!] width [integer!] /local model][
	model: compiler-system-target-model/configure name
	unless object? model [fail compiler-system-target-model/last-error/message]
	check-equal rejoin [name " target"] name model/target
	check-equal rejoin [name " pointer width"] width model/ptr-size
	check-equal rejoin [name " stack width"] width model/stack-width
	check-equal rejoin [name " struct alignment"] width model/struct-align-size
]

check-target 'IA-32 4
check-target 'ARM 4
check-target 'X86-64 8
check-target 'ARM64 8

job: compiler-system-job/new 'Windows-X86-64
unless object? job [fail "could not create Windows x64 compiler job"]
system-dialect/job: job
system-dialect/compiler/job: job
emitter/init false job

model: compiler-system-target-model/configure job/target
unless object? model [fail compiler-system-target-model/last-error/message]
compiler-system-layout/connect/compiler model

check-equal "target identity" emitter/target/target model/target
check-equal "target endian" emitter/target/little-endian? model/little-endian?
check-equal "target pointer width" emitter/target/ptr-size model/ptr-size
check-equal "target stack width" emitter/target/stack-width model/stack-width
check-equal "target struct alignment" emitter/target/struct-align-size model/struct-align-size
check-equal "comparison operations" emitter/target/comparison-op model/comparison-op
check-equal "math operations" emitter/target/math-op model/math-op
check-equal "bitwise operations" emitter/target/bitwise-op model/bitwise-op
check-equal "datatype table" emitter/datatypes compiler-system-layout/datatypes
check-equal "datatype IDs" emitter/datatype-ID compiler-system-layout/datatype-ID

clear system-dialect/compiler/aliased-types
clear system-dialect/compiler/enumerations
repend system-dialect/compiler/aliased-types ['byte-alias! copy [uint8!]]
repend system-dialect/compiler/aliased-types ['wide-alias! copy [uint64!]]

pair-spec: [small [byte!] wide [uint64!]]
pair-type: reduce ['struct! pair-spec]
repend system-dialect/compiler/aliased-types ['pair! pair-type]
repend system-dialect/compiler/enumerations ['choice! 'choices 1]

foreach type [
	int8! byte! uint8! int16! uint16! int32! integer! uint32!
	int64! uint64! float32! float64! float! logic! pointer! c-string!
	struct! union! function! subroutine! array! byte-alias! wide-alias! choice!
][
	check-equal
		rejoin ["size-of " type]
		emitter/size-of? type
		compiler-system-layout/size-of? type
]

check-equal "base byte" true compiler-system-layout/base-type? [byte!]
check-equal "base alias" false compiler-system-layout/base-type? [byte-alias!]
check-equal "aliased byte alignment"
	emitter/type-align? [byte-alias!]
	compiler-system-layout/type-align? [byte-alias!]
check-equal "aliased wide alignment"
	emitter/type-align? [wide-alias!]
	compiler-system-layout/type-align? [wide-alias!]

plain-struct: [small [byte!] count [integer!] wide [uint64!]]
nested-struct: [
	nested [struct! [small [byte!] wide [uint64!]] value]
	tail [byte!]
]
plain-union: [union-marker none small [byte!] wide [uint64!]]
tagged-union: [variant-marker [uint8!] small [byte!] wide [uint64!]]

foreach name reduce ['small 'count 'wide none][
	check-equal
		rejoin ["plain struct member " mold name]
		emitter/member-offset? plain-struct name
		compiler-system-layout/member-offset? plain-struct name
]
foreach name reduce ['small 'wide none][
	check-equal
		rejoin ["plain union member " mold name]
		emitter/member-offset? plain-union name
		compiler-system-layout/member-offset? plain-union name
	check-equal
		rejoin ["tagged union member " mold name]
		emitter/member-offset? tagged-union name
		compiler-system-layout/member-offset? tagged-union name
]

foreach spec reduce [plain-struct nested-struct plain-union tagged-union pair-spec][
	check-equal
		"direct aggregate size"
		emitter/struct-size?/direct spec
		compiler-system-layout/struct-size?/direct spec
	check-equal
		"direct aggregate slots"
		emitter/struct-slots?/direct spec
		compiler-system-layout/struct-slots?/direct spec
]

pair-value: copy [pair! value]
return-spec: reduce [to set-word! 'return pair-value]
scalar-return-spec: reduce [to set-word! 'return copy [integer!]]
check-equal "aliased aggregate size"
	emitter/struct-size? pair-value
	compiler-system-layout/struct-size? pair-value
check-equal "aliased aggregate slots"
	emitter/struct-slots? pair-value
	compiler-system-layout/struct-slots? pair-value
check-equal "checked aggregate size"
	emitter/struct-size?/check return-spec
	compiler-system-layout/struct-size?/check return-spec
check-equal "checked aggregate slots"
	emitter/struct-slots?/check return-spec
	compiler-system-layout/struct-slots?/check return-spec
check-equal "checked scalar size"
	emitter/struct-size?/check scalar-return-spec
	compiler-system-layout/struct-size?/check scalar-return-spec
check-equal "checked scalar slots"
	emitter/struct-slots?/check scalar-return-spec
	compiler-system-layout/struct-slots?/check scalar-return-spec

check-equal "word get-size"
	emitter/get-size 'uint64! none
	compiler-system-layout/get-size 'uint64! none
check-equal "array get-size"
	emitter/get-size [array! 37] none
	compiler-system-layout/get-size [array! 37] none
check-equal "string get-size"
	emitter/get-size [c-string!] "abc"
	compiler-system-layout/get-size [c-string!] "abc"
check-equal "struct get-size"
	emitter/get-size reduce ['struct! plain-struct] none
	compiler-system-layout/get-size reduce ['struct! plain-struct] none
check-equal "union get-size"
	emitter/get-size reduce ['union! tagged-union] none
	compiler-system-layout/get-size reduce ['union! tagged-union] none

pointer-struct: [address [pointer! [integer!]] count [integer!]]
check-equal "pointer aggregate classification"
	emitter/type-has-pointer? reduce ['struct! pointer-struct 'value]
	compiler-system-layout/type-has-pointer? reduce ['struct! pointer-struct 'value]

print "PASS: frontend type layout matches legacy emitter on Windows x64"
