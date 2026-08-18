Red/System [
	Title: "x64 codegen logic cast test"
]

#include %../../../system/codegen/x64-codegen.reds

#import [
	"kernel32.dll" stdcall [
		VirtualAlloc: "VirtualAlloc" [
			address [byte-ptr!]
			size [integer!]
			allocation [integer!]
			protection [integer!]
			return: [byte-ptr!]
		]
		VirtualFree: "VirtualFree" [
			address [byte-ptr!]
			size [integer!]
			free-type [integer!]
			return: [logic!]
		]
	]
]

entry!: alias function! [return: [integer!]]

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

ir: allocate 128
image: allocate 1024
if any [null? ir null? image][
	print ["FAIL: could not allocate test buffers" lf]
	quit 1
]

put ir 0 1
put ir 4 0
put ir 8 0
put ir 12 0
put ir 16 1
put ir 20 3
put ir 24 0
put ir 28 0
put ir 32 0

put ir 36 0
put ir 40 2
put ir 44 -11
put ir 48 0
put ir 52 0
put ir 56 0
put ir 60 0
put ir 64 0
put ir 68 3

put-instruction ir 72 1 -15 255 0
put-instruction ir 88 8 -11 0 0
put-instruction ir 104 11 -11 0 0
ir/121: as byte! 66h
ir/122: as byte! 6Eh

size: x64-codegen/generate ir 122 image 1024 1
if size <= 0 [
	print ["FAIL: logic cast RSIR status=" size lf]
	quit 1
]

header: as codegen-header! image
fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
code: VirtualAlloc (as byte-ptr! 0) 4096 3000h 40h
if null? code [
	print ["FAIL: could not allocate executable memory" lf]
	quit 1
]
copy-memory code (image + header/code-offset) header/code-size
call: as entry! (code + fn/code-offset)
result: call
VirtualFree code 0 8000h
free ir
free image

either result = 1 [
	print ["PASS: x64 codegen normalizes logic casts" lf]
	quit 0
][
	print ["FAIL: logic cast returned " result lf]
	quit 1
]
