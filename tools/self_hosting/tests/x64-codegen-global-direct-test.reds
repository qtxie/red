Red/System [
	Title: "x64 codegen direct scalar global access test"
]

#include %../../../system/codegen/x64-codegen.reds

put: func [data [byte-ptr!] offset value [integer!]][
	x64-encoder/write-i32 (data + offset) value
]

ir: allocate 225
image: allocate 4096
if any [null? ir null? image][quit 1]

; header: one scalar global, one function, seven instructions
put ir 0 1
put ir 4 0
put ir 8 0
put ir 12 0
put ir 16 1
put ir 20 7
put ir 24 1
put ir 28 0
put ir 32 0

; global g: integer!
put ir 36 0
put ir 40 1
put ir 44 -6
put ir 48 0
put ir 52 0
put ir 56 1

; entry function returns integer!, with no parameters or locals
put ir 60 0
put ir 64 1
put ir 68 -6
put ir 72 0
put ir 76 0
put ir 80 0
put ir 84 0
put ir 88 0
put ir 92 7

; scalar initializer for g
put ir 96 1
put ir 100 0
put ir 104 0
put ir 108 0

; literal 7, direct global SET, then direct global LOAD and RETURN
put ir 112 1
put ir 116 -6
put ir 120 7
put ir 124 0
put ir 128 3
put ir 132 2
put ir 136 1
put ir 140 0
put ir 144 5
put ir 148 0
put ir 152 0
put ir 156 0
put ir 160 12
put ir 164 0
put ir 168 0
put ir 172 0
put ir 176 3
put ir 180 2
put ir 184 1
put ir 188 0
put ir 192 4
put ir 196 0
put ir 200 0
put ir 204 0
put ir 208 11
put ir 212 -6
put ir 216 0
put ir 220 0

ir/225: as byte! 67h

size: x64-codegen/generate ir 225 image 4096 0
if size <= 0 [
	print ["FAIL: direct global codegen status=" size lf]
	quit 1
]

header: as codegen-header! image
fn: as codegen-function! (image + x64-codegen/IMAGE_HEADER_SIZE)
global: as codegen-global! (image + x64-codegen/IMAGE_HEADER_SIZE
	+ x64-codegen/IMAGE_FUNCTION_SIZE)
code: image + header/code-offset + fn/code-offset

has-load?: false
has-store?: false
has-address?: false
at: code
index: 1
while [index <= (fn/code-size - 2)][
	if all [at/1 = as byte! 8Bh at/2 = as byte! 05h][
		has-load?: true
	]
	if all [at/1 = as byte! 89h at/2 = as byte! 05h][
		has-store?: true
	]
	if all [at/1 = as byte! 48h at/2 = as byte! 8Dh
		at/3 = as byte! 05h][
		has-address?: true
	]
	at: at + 1
	index: index + 1
]

ok?: all [
	header/reference-count = 2
	global/reference-count = 2
	fn/code-size = 38
	has-load?
	has-store?
	not has-address?
]

either ok? [
	print ["PASS: direct scalar global load/store codegen" lf]
	free ir
	free image
	quit 0
][
	print ["FAIL: direct scalar global access was not emitted"
		" refs=" header/reference-count
		" global-refs=" global/reference-count
		" load=" has-load? " store=" has-store?
		" address=" has-address? " code-size=" fn/code-size lf]
	free ir
	free image
	quit 1
]
