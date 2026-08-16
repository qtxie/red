Red/System [
	Title: "Hybrid compiler Windows x64 primitive encoder tests"
]

#include %../../../system/codegen/x64-encoder.reds

failures: 0
code: allocate 128
if null? code [quit 1]

size: x64-encoder/prolog code 128 0
if size <> 15 [failures: failures + 1]
size: x64-encoder/allocate-frame (code + 15) 113 48
if size <> 4 [failures: failures + 1]
size: x64-encoder/move-immediate (code + 19) 109 x64-encoder/RAX 4 42 0
if size <> 5 [failures: failures + 1]
size: x64-encoder/frame-store (code + 24) 104 x64-encoder/RAX -40 4
if size <> 3 [failures: failures + 1]
size: x64-encoder/frame-load (code + 27) 101 x64-encoder/RCX -40 4 1
if size <> 3 [failures: failures + 1]
size: x64-encoder/call-relative (code + 30) 98 -35
if size <> 5 [failures: failures + 1]
size: x64-encoder/leave-return (code + 35) 93
if size <> 2 [failures: failures + 1]

expected: #{
	554889E56A006A0068000000006A00
	4883EC30
	B82A000000
	8945D8
	8B4DD8
	E8DDFFFFFF
	C9C3
}
if (compare-memory code (as byte-ptr! expected) 37) <> 0 [
	failures: failures + 1
]

if (x64-encoder/prolog null 0 0) <> 15 [failures: failures + 1]
if (x64-encoder/allocate-frame null 0 128) <> 7 [failures: failures + 1]
if (x64-encoder/move-immediate null 0 x64-encoder/R9 8 1 0) <> 11 [
	failures: failures + 1
]
if (x64-encoder/move-register code 128 x64-encoder/RDX x64-encoder/RCX 8) <> 3 [
	failures: failures + 1
]
if any [code/1 <> as byte! 48h code/2 <> as byte! 89h code/3 <> as byte! CAh][
	failures: failures + 1
]

offset: 0
size: x64-encoder/binary-register (code + offset) (128 - offset) 01h
	x64-encoder/RAX x64-encoder/RDX 4
if size <> 2 [failures: failures + 1]
offset: offset + size
size: x64-encoder/multiply-register (code + offset) (128 - offset)
	x64-encoder/RAX x64-encoder/RDX 8
if size <> 4 [failures: failures + 1]
offset: offset + size
size: x64-encoder/multiply-immediate (code + offset) (128 - offset)
	x64-encoder/RDX x64-encoder/RDX 4 8
if size <> 4 [failures: failures + 1]
offset: offset + size
size: x64-encoder/shift-register (code + offset) (128 - offset)
	x64-encoder/RAX 7 4
if size <> 2 [failures: failures + 1]
offset: offset + size
size: x64-encoder/shift-immediate (code + offset) (128 - offset)
	x64-encoder/RAX 7 31 4
if size <> 3 [failures: failures + 1]
offset: offset + size
size: x64-encoder/not-register (code + offset) (128 - offset) x64-encoder/RAX 4
if size <> 2 [failures: failures + 1]
offset: offset + size
size: x64-encoder/condition-result (code + offset) (128 - offset) 4
if size <> 6 [failures: failures + 1]
offset: offset + size
size: x64-encoder/test-register (code + offset) (128 - offset)
	x64-encoder/RAX 4
if size <> 2 [failures: failures + 1]
offset: offset + size
size: x64-encoder/jump-relative (code + offset) (128 - offset) -5
if size <> 5 [failures: failures + 1]
offset: offset + size
size: x64-encoder/jump-condition (code + offset) (128 - offset) 4 7
if size <> 6 [failures: failures + 1]
offset: offset + size
size: x64-encoder/divide-register (code + offset) (128 - offset) 4 1
if size <> 3 [failures: failures + 1]
offset: offset + size
size: x64-encoder/sign-extend-register (code + offset) (128 - offset)
	x64-encoder/RCX
if size <> 3 [failures: failures + 1]
offset: offset + size
operations: #{
	01D0
	480FAFC2
	486BD204
	D3F8
	C1F81F
	F7D0
	0F94C00FB6C0
	85C0
	E9FBFFFFFF
	0F8407000000
	99F7F9
	4863C9
}
if any [offset <> 42 (compare-memory code (as byte-ptr! operations) offset) <> 0][
	failures: failures + 1
]

size: x64-encoder/frame-address code 128 x64-encoder/RAX -40
if any [size <> 4 code/1 <> as byte! 48h code/2 <> as byte! 8Dh][
	failures: failures + 1
]
size: x64-encoder/rip-address code 128 x64-encoder/RAX 123
if any [size <> 7 code/1 <> as byte! 48h code/2 <> as byte! 8Dh code/3 <> as byte! 05h][
	failures: failures + 1
]
size: x64-encoder/rip-load code 128 x64-encoder/RDX -7
if any [size <> 7 code/1 <> as byte! 48h code/2 <> as byte! 8Bh code/3 <> as byte! 15h][
	failures: failures + 1
]

if (x64-encoder/load-indirect code 128 1 1) <> 3 [failures: failures + 1]
if (x64-encoder/store-indirect code 128 8) <> 3 [failures: failures + 1]
size: x64-encoder/add-immediate code 128 x64-encoder/RAX 127
if any [
	size <> 4 code/1 <> as byte! 48h code/2 <> as byte! 83h
	code/3 <> as byte! C0h code/4 <> as byte! 7Fh
][failures: failures + 1]
size: x64-encoder/add-immediate code 128 x64-encoder/RDX 128
if any [
	size <> 7 code/1 <> as byte! 48h code/2 <> as byte! 81h
	code/3 <> as byte! C2h code/4 <> as byte! 80h
	code/5 <> as byte! 00h code/6 <> as byte! 00h code/7 <> as byte! 00h
][failures: failures + 1]
size: x64-encoder/add-immediate code 128 x64-encoder/R9 -1
if any [
	size <> 4 code/1 <> as byte! 49h code/2 <> as byte! 83h
	code/3 <> as byte! C1h code/4 <> as byte! FFh
][failures: failures + 1]
if (x64-encoder/outgoing-store code 128 32 8) <> 5 [failures: failures + 1]
if (x64-encoder/call-import code 128 0) <> 6 [failures: failures + 1]
if (x64-encoder/stack-top code 128) <> 3 [failures: failures + 1]
if (x64-encoder/sign-extend-eax code 128) <> 3 [failures: failures + 1]
if (x64-encoder/clear-register code 128 x64-encoder/R9) <> 3 [failures: failures + 1]

if (x64-encoder/prolog code 14 0) <> -1 [failures: failures + 1]
if (x64-encoder/frame-load code 128 x64-encoder/RAX 0 3 0) <> -1 [
	failures: failures + 1
]
if (x64-encoder/store-indirect code 128 3) <> -1 [failures: failures + 1]
if (x64-encoder/binary-register code 128 02h 0 1 4) <> -1 [
	failures: failures + 1
]
if (x64-encoder/condition-result code 128 16) <> -1 [failures: failures + 1]
if (x64-encoder/test-register code 128 x64-encoder/RAX 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/jump-relative code 4 0) <> -1 [failures: failures + 1]
if (x64-encoder/jump-condition code 128 16 0) <> -1 [failures: failures + 1]

free code
either failures = 0 [
	print ["PASS: primitive Windows x64 encoder" lf]
][
	print ["FAIL: primitive x64 encoder failures=" failures lf]
]
quit failures
