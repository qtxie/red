Red/System [
	Title: "x64 codegen static global layout test"
]

#include %../../../system/codegen/x64-codegen.reds

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

put-global: func [
	data [byte-ptr!]
	offset name name-size type flags first count [integer!]
][
	put data offset name
	put data (offset + 4) name-size
	put data (offset + 8) type
	put data (offset + 12) flags
	put data (offset + 16) first
	put data (offset + 20) count
]

ir: allocate 320
image: allocate 1024
if any [null? ir null? image][quit 1]

put ir 0 1
put ir 4 0
put ir 8 2
put ir 12 0
put ir 16 1
put ir 20 1
put ir 24 4
put ir 28 0

put ir 32 -6
put ir 36 -7
put ir 40 0
put ir 44 0
put ir 48 0

put ir 52 -2
put ir 56 0
put ir 60 0
put ir 64 0
put ir 68 2

put ir 72 -5
put ir 76 0
put ir 80 -5
put ir 84 0

put-global ir 88 0 1 2 0 0 1
put-global ir 112 1 1 2 0 1 1
put-global ir 136 0 0 -7 0 0 0
put-global ir 160 0 0 -7 0 0 0

put ir 184 2
put ir 188 2
put ir 192 0
put ir 196 0
put ir 200 0
put ir 204 0
put ir 208 0
put ir 212 0
put ir 216 1

put ir 220 2
put ir 224 2
put ir 228 3
put ir 232 1
put ir 236 2
put ir 240 2
put ir 244 4
put ir 248 1

put ir 252 11
put ir 256 0
put ir 260 0
put ir 264 0

ir/269: as byte! 61h
ir/270: as byte! 62h
ir/271: as byte! 66h
ir/272: as byte! 6Eh

size: x64-codegen/generate ir 272 image 1024 1
if size <= 0 [
	print ["FAIL: static global layout RSIR status=" size lf]
	quit 1
]

header: as codegen-header! image
first: as codegen-global! (image + x64-codegen/IMAGE_HEADER_SIZE
	+ x64-codegen/IMAGE_FUNCTION_SIZE)
second: first + 1
first-payload: second + 1
second-payload: first-payload + 1

ok?: all [
	header/data-size = 48
	first/data-offset = 16
	first/data-size = 8
	first-payload/data-offset = 24
	first-payload/data-size = 8
	second/data-offset = 32
	second/data-size = 8
	second-payload/data-offset = 40
	second-payload/data-size = 8
]

free ir
free image
either ok? [
	print ["PASS: x64 codegen validates typed static address casts and payload layout" lf]
	quit 0
][
	print ["FAIL: static global payload layout is not contiguous" lf]
	quit 1
]
