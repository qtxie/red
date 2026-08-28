Red/System [
	Title: "Hybrid compiler Windows x64 primitive encoder tests"
]

#include %../../../system/codegen/x64-encoder.reds

failures: 0
code: allocate 128
expected: as byte-ptr! 0
if null? code [quit 1]

size: x64-encoder/prolog code 128 0 0
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
if (compare-memory code expected 37) <> 0 [
	failures: failures + 1
]

if (x64-encoder/prolog null 0 0 0) <> 15 [failures: failures + 1]
if (x64-encoder/allocate-frame null 0 128) <> 7 [failures: failures + 1]
if (x64-encoder/move-immediate null 0 x64-encoder/R9 8 1 0) <> 6 [
	print ["compact zero immediate size failed" lf]
	failures: failures + 1
]
size: x64-encoder/move-immediate code 128 x64-encoder/R9 8 1 0
expected: #{41B901000000}
if any [size <> 6 (compare-memory code expected size) <> 0][
	print ["compact zero immediate failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/move-immediate code 128 x64-encoder/RAX 8 -1 -1
expected: #{48C7C0FFFFFFFF}
if any [size <> 7 (compare-memory code expected size) <> 0][
	print ["sign-extended immediate failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/move-immediate code 128 x64-encoder/R9 8 1 1
expected: #{49B90100000001000000}
if any [size <> 10 (compare-memory code expected size) <> 0][
	print ["full-width immediate failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/move-immediate-compact code 128 x64-encoder/R9 8 0 0
expected: #{4531C9}
if any [size <> 3 (compare-memory code expected size) <> 0][
	print ["zero materialization failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/move-immediate-compact code 128 x64-encoder/R9 8 1 0
expected: #{4531C941FFC1}
if any [size <> 6 (compare-memory code expected size) <> 0][
	print ["one materialization failed, size=" size lf]
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
size: x64-encoder/bit-scan-reverse (code + offset) (128 - offset)
	x64-encoder/RAX x64-encoder/RDX 4
if size <> 3 [failures: failures + 1]
offset: offset + size
size: x64-encoder/bit-scan-reverse (code + offset) (128 - offset)
	x64-encoder/R9 x64-encoder/R10 8
if size <> 4 [failures: failures + 1]
offset: offset + size
size: x64-encoder/unsigned-multiply-register (code + offset) (128 - offset)
	x64-encoder/RDX 8
if size <> 3 [failures: failures + 1]
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
size: x64-encoder/jump-relative-short (code + offset) (128 - offset) -2
expected: #{EBFE}
if any [size <> 2 (compare-memory (code + offset) expected size) <> 0][
	print ["short jump failed, size=" size lf]
	failures: failures + 1
]
offset: offset + size
size: x64-encoder/jump-condition-short (code + offset) (128 - offset) 5 7
expected: #{7507}
if any [size <> 2 (compare-memory (code + offset) expected size) <> 0][
	print ["short condition failed, size=" size lf]
	failures: failures + 1
]
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
	0FBDC2
	4D0FBDCA
	48F7E2
	486BD204
	D3F8
	C1F81F
	F7D0
	0F94C00FB6C0
	85C0
	E9FBFFFFFF
	0F8407000000
	EBFE
	7507
	99F7F9
	4863C9
}
if any [offset <> 56 (compare-memory code (as byte-ptr! operations) offset) <> 0][
	failures: failures + 1
]

size: x64-encoder/extend-narrow-register code 128 x64-encoder/RAX
	x64-encoder/RAX 1 1
expected: #{0FBEC0}
if any [size <> 3 (compare-memory code expected size) <> 0][
	print ["indirect load zero failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/extend-narrow-register code 128 x64-encoder/RDX
	x64-encoder/RAX 2 0
expected: #{0FB7D0}
if any [size <> 3 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/extend-narrow-register code 128 9 10 1 0
expected: #{450FB6CA}
if any [size <> 4 (compare-memory code expected size) <> 0][
	print ["indirect load disp8 failed, size=" size lf]
	failures: failures + 1
]
if (x64-encoder/extend-narrow-register code 128 x64-encoder/RAX
	x64-encoder/RAX 4 0) <> -1 [
	failures: failures + 1
]

size: x64-encoder/frame-address code 128 x64-encoder/RAX -40
if any [size <> 4 code/1 <> as byte! 48h code/2 <> as byte! 8Dh][
	failures: failures + 1
]
size: x64-encoder/stack-address code 128 x64-encoder/R9 0
if any [
	size <> 4 code/1 <> as byte! 4Ch code/2 <> as byte! 8Dh
	code/3 <> as byte! 0Ch code/4 <> as byte! 24h
][failures: failures + 1]
size: x64-encoder/stack-address code 128 x64-encoder/RDX 32
if any [
	size <> 5 code/1 <> as byte! 48h code/2 <> as byte! 8Dh
	code/3 <> as byte! 54h code/4 <> as byte! 24h code/5 <> as byte! 20h
][failures: failures + 1]
size: x64-encoder/stack-address code 128 x64-encoder/RAX 128
if any [
	size <> 8 code/1 <> as byte! 48h code/2 <> as byte! 8Dh
	code/3 <> as byte! 84h code/4 <> as byte! 24h code/5 <> as byte! 80h
	code/6 <> as byte! 00h code/7 <> as byte! 00h code/8 <> as byte! 00h
][failures: failures + 1]
size: x64-encoder/register-load code 128 x64-encoder/R9 x64-encoder/R10 24
expected: #{4D8B4A18}
if any [size <> 4 (compare-memory code expected size) <> 0][
	print ["indirect store zero failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/register-store code 128 x64-encoder/R9 x64-encoder/R10 24
expected: #{4D894A18}
if any [size <> 4 (compare-memory code expected size) <> 0][
	print ["indirect load disp8 new failed, size=" size lf]
	failures: failures + 1
]
size: x64-encoder/register-load code 128 x64-encoder/RAX x64-encoder/RSP 32
expected: #{488B442420}
if any [size <> 5 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-store code 128 x64-encoder/RAX x64-encoder/RSP 32
expected: #{4889442420}
if any [size <> 5 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-load-indirect code 128 x64-encoder/R9
	x64-encoder/R10 0 4 0
expected: #{458B0A}
if any [size <> 3 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-load-indirect code 128 x64-encoder/RAX
	x64-encoder/RBP 0 2 1
expected: #{0FBF4500}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-store-indirect code 128 x64-encoder/R13
	x64-encoder/R9 0 4
expected: #{45894D00}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-load-indirect code 128 x64-encoder/R9
	x64-encoder/R10 24 4 0
expected: #{458B4A18}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/register-store-indirect code 128 x64-encoder/R13
	x64-encoder/R9 12345678h 4
expected: #{45898D78563412}
if any [size <> 7 (compare-memory code expected size) <> 0][
	print ["indirect store disp32 failed, size=" size lf]
	failures: failures + 1
]
offset: 0
size: x64-encoder/atomic-binary (code + offset) (128 - offset) 01h
	x64-encoder/RDX x64-encoder/R10
if size <> 4 [failures: failures + 1]
offset: offset + size
size: x64-encoder/atomic-exchange-add (code + offset) (128 - offset)
	x64-encoder/RDX x64-encoder/RAX
if size <> 4 [failures: failures + 1]
offset: offset + size
size: x64-encoder/atomic-compare-exchange (code + offset) (128 - offset)
	x64-encoder/R13 x64-encoder/R11
if size <> 6 [failures: failures + 1]
offset: offset + size
size: x64-encoder/memory-fence (code + offset) (128 - offset)
if size <> 3 [failures: failures + 1]
offset: offset + size
size: x64-encoder/negate-register (code + offset) (128 - offset)
	x64-encoder/R9 4
if size <> 3 [failures: failures + 1]
offset: offset + size
expected: #{F0440112F00FC102F0450FB15D000FAEF041F7D9}
if any [offset <> 20 (compare-memory code expected offset) <> 0][
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

size: x64-encoder/rip-value-load code 128 x64-encoder/RAX 123 4 0
expected: #{8B057B000000}
if any [size <> 6 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/rip-value-load code 128 x64-encoder/R9 -7 8 1
expected: #{4C8B0DF9FFFFFF}
if any [size <> 7 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/rip-value-load code 128 x64-encoder/RAX 1 1 1
expected: #{0FBE0501000000}
if any [size <> 7 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/rip-value-load code 128 x64-encoder/RAX 1 2 0
expected: #{0FB70501000000}
if any [size <> 7 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/rip-value-store code 128 x64-encoder/RAX 123 4
expected: #{89057B000000}
if any [size <> 6 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/rip-value-store code 128 x64-encoder/R9 -7 8
expected: #{4C890DF9FFFFFF}
if any [size <> 7 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-rip-load code 128 x64-encoder/XMM0 123 8
expected: #{F20F10057B000000}
if any [size <> 8 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-rip-store code 128 9 -7 4
expected: #{F3440F110DF9FFFFFF}
if any [size <> 9 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if any [
	(x64-encoder/rip-value-load null 0 x64-encoder/RAX 0 3 0) <> -1
	(x64-encoder/rip-value-store null 0 x64-encoder/RAX 0 3) <> -1
	(x64-encoder/xmm-rip-load null 0 x64-encoder/XMM0 0 3) <> -1
	(x64-encoder/xmm-rip-store null 0 x64-encoder/XMM0 0 3) <> -1
][failures: failures + 1]

if (x64-encoder/load-indirect code 128 1 1) <> 3 [failures: failures + 1]
if (x64-encoder/store-indirect code 128 8) <> 3 [failures: failures + 1]
if (x64-encoder/copy-indirect code 128 1) <> 8 [failures: failures + 1]
if (x64-encoder/copy-indirect code 128 8) <> 9 [failures: failures + 1]
if (x64-encoder/copy-indirect code 128 12) <> 24 [failures: failures + 1]
if (x64-encoder/copy-indirect code 128 40) <> 36 [failures: failures + 1]
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
size: x64-encoder/and-immediate code 128 x64-encoder/RSP -16
expected: #{4883E4F0}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/compare-immediate code 128 x64-encoder/R8 4
expected: #{4183F804}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/outgoing-store code 128 32 8) <> 5 [failures: failures + 1]
size: x64-encoder/frame-immediate-store code 128 -64 12345678h 4
expected: #{C745C078563412}
if any [size <> 7 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/frame-immediate-store code 128 128 12345678h 4
expected: #{C7858000000078563412}
if any [size <> 10 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/frame-immediate-store code 128 -64 12345678h 8
expected: #{48C745C078563412}
if any [size <> 8 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/frame-immediate-store code 128 128 12345678h 8
expected: #{48C7858000000078563412}
if any [size <> 11 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/frame-immediate-store code 128 -64 0 2) <> -1 [failures: failures + 1]
size: x64-encoder/alu-immediate code 128 5 x64-encoder/RAX 5 4
expected: #{83E805}
if any [size <> 3 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/alu-immediate code 128 0 x64-encoder/RAX 7 8
expected: #{4883C007}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/alu-immediate code 128 7 x64-encoder/RAX 12345678h 4
expected: #{81F878563412}
if any [size <> 6 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/alu-immediate code 128 1 x64-encoder/RDX 1000 4
expected: #{81CAE8030000}
if any [size <> 6 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/alu-immediate code 128 8 x64-encoder/RAX 1 4) <> -1 [failures: failures + 1]
if (x64-encoder/alu-immediate code 128 0 x64-encoder/RAX 1 2) <> -1 [failures: failures + 1]
size: x64-encoder/outgoing-immediate-store code 128 32 12345678h
expected: #{C744242078563412}
if any [size <> 8 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/outgoing-immediate-store code 128 128 12345678h
expected: #{C784248000000078563412}
if any [size <> 11 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-outgoing-store code 128 x64-encoder/XMM0 32 4
expected: #{F30F11442420}
if any [size <> 6 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-outgoing-store code 128 9 128 8
expected: #{F2440F118C2480000000}
if any [size <> 10 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-load-register code 128 x64-encoder/XMM0
	x64-encoder/RAX 4
expected: #{660F6EC0}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-load-register code 128 9 10 8
expected: #{664D0F6ECA}
if any [size <> 5 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-store-register code 128 x64-encoder/RAX
	x64-encoder/XMM0 4
expected: #{660F7EC0}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-store-register code 128 10 9 8
expected: #{664D0F7ECA}
if any [size <> 5 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/xmm-load-register code 128 x64-encoder/XMM0
	x64-encoder/RAX 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/xmm-store-register code 3 x64-encoder/RAX
	x64-encoder/XMM0 4) <> -1 [
	failures: failures + 1
]
size: x64-encoder/xmm-move-register code 128 x64-encoder/XMM1
	x64-encoder/XMM0 4
expected: #{F30F10C8}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/xmm-move-register code 128 9 10 8
expected: #{F2450F10CA}
if any [size <> 5 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/xmm-move-register code 128 x64-encoder/XMM0
	x64-encoder/XMM1 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/call-import code 128 0) <> 6 [failures: failures + 1]
size: x64-encoder/call-register code 128 x64-encoder/RAX
if any [size <> 2 code/1 <> as byte! FFh code/2 <> as byte! D0h][
	failures: failures + 1
]
size: x64-encoder/call-register code 128 x64-encoder/R9
if any [
	size <> 3 code/1 <> as byte! 41h code/2 <> as byte! FFh
	code/3 <> as byte! D1h
][failures: failures + 1]
size: x64-encoder/push-register code 128 x64-encoder/RAX
if any [size <> 1 code/1 <> as byte! 50h][failures: failures + 1]
size: x64-encoder/push-register code 128 x64-encoder/R9
if any [
	size <> 2 code/1 <> as byte! 41h code/2 <> as byte! 51h
][failures: failures + 1]
size: x64-encoder/pop-register code 128 x64-encoder/RAX
if any [size <> 1 code/1 <> as byte! 58h][failures: failures + 1]
size: x64-encoder/pop-register code 128 x64-encoder/R9
if any [
	size <> 2 code/1 <> as byte! 41h code/2 <> as byte! 59h
][failures: failures + 1]
size: x64-encoder/push-flags code 128
if any [size <> 1 code/1 <> as byte! 9Ch][failures: failures + 1]
size: x64-encoder/pop-flags code 128
if any [size <> 1 code/1 <> as byte! 9Dh][failures: failures + 1]
size: x64-encoder/fxsave-stack code 128
expected: #{0FAE0424}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/fxrstor-stack code 128
expected: #{0FAE0C24}
if any [size <> 4 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/repeat-store-quad code 128
expected: #{F348AB}
if any [size <> 3 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/prolog code 128 0 -2
if any [size <> 15 code/6 <> as byte! FEh][failures: failures + 1]
if (x64-encoder/prolog code 128 0 -3) <> -1 [failures: failures + 1]
size: x64-encoder/throw-unwind code 128 false
expected: #{8B55F839C27303C9EBF64C8B5DF04D85DB7502415B41FFE3}
if any [size <> 24 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
size: x64-encoder/throw-unwind code 128 true
expected: #{C98B55F839C27303C9EBF64C8B5DF04D85DB7502415B41FFE3}
if any [size <> 25 (compare-memory code expected size) <> 0][
	failures: failures + 1
]
if (x64-encoder/throw-unwind null 0 false) <> 24 [failures: failures + 1]
if (x64-encoder/throw-unwind code 23 false) <> -1 [failures: failures + 1]
if (x64-encoder/throw-unwind code 24 true) <> -1 [failures: failures + 1]
if (x64-encoder/stack-top code 128) <> 3 [failures: failures + 1]
if (x64-encoder/sign-extend-eax code 128) <> 3 [failures: failures + 1]
if (x64-encoder/clear-register code 128 x64-encoder/R9) <> 3 [failures: failures + 1]

if (x64-encoder/prolog code 14 0 0) <> -1 [failures: failures + 1]
if (x64-encoder/frame-load code 128 x64-encoder/RAX 0 3 0) <> -1 [
	failures: failures + 1
]
if (x64-encoder/store-indirect code 128 3) <> -1 [failures: failures + 1]
if (x64-encoder/copy-indirect code 128 0) <> -1 [failures: failures + 1]
if (x64-encoder/stack-address code 128 x64-encoder/RAX -1) <> -1 [
	failures: failures + 1
]
if (x64-encoder/register-load code 3 x64-encoder/R9 x64-encoder/R10 24) <> -1 [
	failures: failures + 1
]
if (x64-encoder/register-store code 128 16 x64-encoder/RAX 0) <> -1 [
	failures: failures + 1
]
if (x64-encoder/register-load-indirect code 128 16 x64-encoder/RAX 0 4 0) <> -1 [
	failures: failures + 1
]
if (x64-encoder/register-store-indirect code 128 x64-encoder/RAX
	x64-encoder/RCX 0 3) <> -1 [failures: failures + 1]
if (x64-encoder/atomic-binary code 128 02h x64-encoder/RAX
	x64-encoder/RCX) <> -1 [failures: failures + 1]
if (x64-encoder/atomic-exchange-add code 128 16 x64-encoder/RAX) <> -1 [
	failures: failures + 1
]
if (x64-encoder/atomic-compare-exchange code 3 x64-encoder/RAX
	x64-encoder/RCX) <> -1 [failures: failures + 1]
if (x64-encoder/memory-fence code 2) <> -1 [failures: failures + 1]
if (x64-encoder/negate-register code 128 x64-encoder/RAX 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/and-immediate code 128 16 0) <> -1 [failures: failures + 1]
if (x64-encoder/compare-immediate code 3 x64-encoder/R8 4) <> -1 [
	failures: failures + 1
]
if (x64-encoder/outgoing-immediate-store code 128 -1 0) <> -1 [
	failures: failures + 1
]
if (x64-encoder/xmm-outgoing-store code 128 x64-encoder/XMM0 0 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/binary-register code 128 02h 0 1 4) <> -1 [
	failures: failures + 1
]
if (x64-encoder/unsigned-multiply-register code 128 x64-encoder/RAX 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/condition-result code 128 16) <> -1 [failures: failures + 1]
if (x64-encoder/test-register code 128 x64-encoder/RAX 2) <> -1 [
	failures: failures + 1
]
if (x64-encoder/jump-relative code 4 0) <> -1 [failures: failures + 1]
if (x64-encoder/jump-condition code 128 16 0) <> -1 [failures: failures + 1]
if (x64-encoder/call-register code 1 x64-encoder/RAX) <> -1 [
	failures: failures + 1
]
if (x64-encoder/call-register code 128 16) <> -1 [failures: failures + 1]
if (x64-encoder/push-register code 0 x64-encoder/RAX) <> -1 [
	failures: failures + 1
]
if (x64-encoder/push-register code 128 16) <> -1 [failures: failures + 1]
if (x64-encoder/pop-register code 0 x64-encoder/RAX) <> -1 [
	failures: failures + 1
]
if (x64-encoder/pop-register code 128 16) <> -1 [failures: failures + 1]
if (x64-encoder/push-flags code 0) <> -1 [failures: failures + 1]
if (x64-encoder/pop-flags code 0) <> -1 [failures: failures + 1]
if (x64-encoder/fxsave-stack code 3) <> -1 [failures: failures + 1]
if (x64-encoder/fxrstor-stack code 3) <> -1 [failures: failures + 1]
if (x64-encoder/repeat-store-quad code 2) <> -1 [failures: failures + 1]

free code
either failures = 0 [
	print ["PASS: primitive Windows x64 encoder" lf]
][
	print ["FAIL: primitive x64 encoder failures=" failures lf]
]
quit failures
