Red/System [
	Title: "x64 codegen shared library export metadata test"
]

#include %../../../system/codegen/x64-codegen.reds

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

put-instruction: func [
	data [byte-ptr!]
	offset op a b c [integer!]
][
	put data offset op
	put data (offset + 4) a
	put data (offset + 8) b
	put data (offset + 12) c
]

ir: allocate 193
image: allocate 1024
if any [null? ir null? image][quit 1]

; Shared library with one integer global and one ordinary exported callback.
put ir 0 4
put ir 4 0
put ir 8 0
put ir 12 0
put ir 16 1
put ir 20 2
put ir 24 1
put ir 28 0
put ir 32 2

put ir 36 0
put ir 40 5
put ir 44 -5
put ir 48 0
put ir 52 0
put ir 56 1

put ir 60 5
put ir 64 6
put ir 68 -5
put ir 72 66
put ir 76 0
put ir 80 0
put ir 84 0
put ir 88 0
put ir 92 2

put ir 96 1
put ir 100 11
put ir 104 9
put ir 108 -1
put ir 112 20
put ir 116 5

put ir 120 1
put ir 124 42
put ir 128 0
put ir 132 0

put-instruction ir 136 1 -5 42 0
put-instruction ir 152 11 -5 0 0

copy-memory (ir + 168) (as byte-ptr! "valueansweranswer-v1value") 25

put ir 100 -1
if (x64-codegen/generate ir 193 image 1024 1) <> x64-codegen/INVALID_IR [
	print ["FAIL: x64 codegen accepted a negative export name offset" lf]
	free ir
	free image
	quit 1
]
put ir 100 11

size: x64-codegen/generate ir 193 image 1024 1
if size <= 0 [
	print ["FAIL: shared library export RSIR status=" size lf]
	quit 1
]

header: as codegen-header! image
global: as codegen-global! (image + x64-codegen/IMAGE_HEADER_SIZE
	+ x64-codegen/IMAGE_FUNCTION_SIZE)
first: as codegen-export! (image + x64-codegen/IMAGE_HEADER_SIZE
	+ x64-codegen/IMAGE_FUNCTION_SIZE + x64-codegen/IMAGE_GLOBAL_SIZE)
second: first + 1
names: image + x64-codegen/IMAGE_HEADER_SIZE + x64-codegen/IMAGE_FUNCTION_SIZE
	+ x64-codegen/IMAGE_GLOBAL_SIZE + (2 * x64-codegen/IMAGE_EXPORT_SIZE)
data-at: header/code-offset + header/code-size
remainder: data-at // 4
if remainder <> 0 [data-at: data-at + 4 - remainder]
data-at: data-at + header/rodata-size
remainder: data-at // 4
if remainder <> 0 [data-at: data-at + 4 - remainder]
value-at: as int-ptr! (image + data-at + global/data-offset)
first-name: names + first/name
second-name: names + second/name

ok?: all [
	header/module-kind = 4
	header/entry-function = 0
	header/export-count = 2
	header/import-count = 0
	global/data-offset = 16
	value-at/value = 42
	first/symbol = 1
	first/name-size = 9
	second/symbol = -1
	second/name-size = 5
	first-name/1 = as byte! 61h
	second-name/1 = as byte! 76h
]

free ir
free image
either ok? [
	print ["PASS: x64 codegen preserves direct shared library exports" lf]
	quit 0
][
	print ["FAIL: shared library export metadata changed" lf]
	quit 1
]
