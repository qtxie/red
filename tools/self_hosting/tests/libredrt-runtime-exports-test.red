Red [
	Title: "libRedRT runtime export tests"
]

do %../../../compiler/host-compat.red
system/options/path: clean-path %../../../
do %system/utils/libRedRT.red

assert: func [condition [logic! none!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

job: context [
	OS: 'Windows
	GUI-engine: none
]

exports: libRedRT/runtime-exports job
export-name: func [spelling [string!] /local position][
	position: exports
	while [not tail? position][
		if (form position/1) = spelling [return position/2]
		position: skip position 2
	]
	none
]
assert zero? ((length? exports) // 2) "runtime exports are not symbol/name pairs"
assert (export-name "red/boot") = "red/boot" "red/boot export is missing"
assert (export-name "red/image/push") = "red/image/push"
	"Windows image exports are missing"
assert none? export-name "exec/gui/OS-alert"
	"headless runtime retained the GUI alert export"
assert (export-name "red/root") = "red/root" "runtime variable exports are missing"
assert (libRedRT/compiler-name first [red/stack/mark]) = (to word! "red>stack>mark")
	"runtime paths do not use the compiler namespace spelling"

spec: libRedRT/make-import-spec reduce [
	'value reduce [to word! "red>integer!"]
	/local 'temporary [integer!]
]
assert all [
	block? spec/1
	find spec/1 'red-internal
	none? find spec /local
	spec/3 = [integer!]
]["runtime import specs did not preserve types and the private ABI"]

print "PASS: libRedRT runtime exports"
