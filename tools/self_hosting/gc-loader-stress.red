Red [
	Title: "Stage1 loader GC stress test"
	File:  %gc-loader-stress.red
]

#include %../../compiler/lexer.red
#include %../../compiler/system-source.red

fail: func [phase [string!] iteration [integer!] value][
	print ["FAIL" phase "iteration" iteration "type" either value? 'value [type? :value]["unset"]]
	quit/return 1
]

source-file: %system/tests/source/units/arm64-call-args-smoke.reds
source: read/binary source-file
expected-length: none
iterations: 2000
max-pins: max-pinned-bytes: 0

sample-pins: does [
	pins: system/state/GC/pinned-frames
	bytes: system/state/GC/pinned-bytes
	if pins > max-pins [max-pins: pins]
	if bytes > max-pinned-bytes [max-pinned-bytes: bytes]
]

recycle/on

repeat iteration iterations [
	normalized: copy source
	set/any 'decoded try [transcode normalized]
	recycle
	sample-pins
	unless value? 'decoded [
		print ["FAIL try/transcode iteration" iteration "value unset"]
		quit/return 1
	]
	unless block? :decoded [
		fail "try/transcode" iteration :decoded
	]
	either none? expected-length [
		expected-length: length? decoded
	][
		unless expected-length = length? decoded [
			fail "try/transcode length" iteration decoded
		]
	]
	if zero? iteration % 100 [print ["try/transcode" iteration]]
]

repeat iteration iterations [
	set/any 'decoded try [compiler-system-source/process/file source source-file]
	unless value? 'decoded [
		print ["FAIL system-source/process iteration" iteration "value unset"]
		quit/return 1
	]
	unless block? :decoded [
		fail "system-source/process" iteration :decoded
	]
	recycle
	sample-pins
	unless block? decoded [
		fail "system-source/process after recycle" iteration decoded
	]
	if zero? iteration % 100 [print ["system-source/process" iteration]]
]

print [
	"PASS loader GC stress:" iterations * 2 "forced collections; max conservative pins:"
	max-pins "frames /" max-pinned-bytes "bytes"
]
quit/return 0
