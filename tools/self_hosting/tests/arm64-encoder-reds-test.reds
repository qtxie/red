Red/System [
	Title: "Hybrid compiler Apple AArch64 primitive encoder tests"
]

#include %../../../system/codegen/arm64-encoder.reds

failures: 0
code: allocate 256
expected: as byte-ptr! 0
if null? code [quit 1]

check: func [size wanted [integer!] bytes [byte-ptr!]][
	if any [size <> wanted (compare-memory code bytes wanted) <> 0][
		failures: failures + 1
	]
]

size: arm64-encoder/move-immediate code 256 arm64-encoder/X11 8 12345678h 0
expected: #{0BCF8AD28B46A2F2}
check size 8 expected

size: arm64-encoder/move-immediate code 256 arm64-encoder/X12 8 -1 -1
expected: #{0C008092}
check size 4 expected

size: arm64-encoder/move-immediate code 256 arm64-encoder/X10 4 0 0
expected: #{0A008052}
check size 4 expected

size: arm64-encoder/move-register code 256 arm64-encoder/X9 arm64-encoder/X19 8
expected: #{E90313AA}
check size 4 expected

size: arm64-encoder/move-register code 256 arm64-encoder/X10 arm64-encoder/X20 4
expected: #{EA03142A}
check size 4 expected

size: arm64-encoder/add-register code 256 arm64-encoder/X13
	arm64-encoder/X19 arm64-encoder/X20 8
expected: #{6D02148B}
check size 4 expected

size: arm64-encoder/subtract-register code 256 arm64-encoder/X14
	arm64-encoder/X19 arm64-encoder/X20 8
expected: #{6E0214CB}
check size 4 expected

size: arm64-encoder/extend-register code 256 arm64-encoder/X17
	arm64-encoder/X17 4 1
expected: #{317E4093}
check size 4 expected

size: arm64-encoder/extend-register code 256 arm64-encoder/X9
	arm64-encoder/X10 1 0
expected: #{491D40D3}
check size 4 expected

size: arm64-encoder/add-extended-register code 256 arm64-encoder/OP_ADD
	arm64-encoder/X10 arm64-encoder/X10 arm64-encoder/X17 4 1 2
expected: #{4AC9318B}
check size 4 expected

size: arm64-encoder/add-extended-register code 256 arm64-encoder/OP_SUB
	arm64-encoder/X11 arm64-encoder/X12 arm64-encoder/X13 4 0 3
expected: #{8B4D2DCB}
check size 4 expected

size: arm64-encoder/alu-register code 256 arm64-encoder/OP_AND arm64-encoder/X9
	arm64-encoder/X19 arm64-encoder/X20 8 false
expected: #{6902148A}
check size 4 expected

size: arm64-encoder/alu-register code 256 arm64-encoder/OP_XOR arm64-encoder/X9
	arm64-encoder/X19 arm64-encoder/X20 8 false
expected: #{690214CA}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_AND
	arm64-encoder/X10 arm64-encoder/X19 4 1023 0
expected: #{6A260012}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_OR
	arm64-encoder/X11 arm64-encoder/X20 4 00FF00FFh 0
expected: #{8B9E0032}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_XOR
	arm64-encoder/X12 arm64-encoder/X21 4 80000000h -1
expected: #{AC020152}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_AND
	arm64-encoder/X13 arm64-encoder/X22 8 1023 0
expected: #{CD264092}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_OR
	arm64-encoder/X14 arm64-encoder/X23 8 00FF00FFh 00FF00FFh
expected: #{EE9E00B2}
check size 4 expected

size: arm64-encoder/logical-immediate code 256 arm64-encoder/OP_XOR
	arm64-encoder/X15 arm64-encoder/X24 8 0 80000000h
expected: #{0F0341D2}
check size 4 expected

size: arm64-encoder/add-immediate code 256 arm64-encoder/X9 arm64-encoder/X19 42 8
expected: #{69AA0091}
check size 4 expected

size: arm64-encoder/add-immediate code 256 arm64-encoder/X9 arm64-encoder/X19 -12288 8
expected: #{690E40D1}
check size 4 expected

size: arm64-encoder/multiply-register code 256 arm64-encoder/X9
	arm64-encoder/X19 arm64-encoder/X20 8
expected: #{697E149B}
check size 4 expected

size: arm64-encoder/divide-register code 256 arm64-encoder/X9
	arm64-encoder/X19 arm64-encoder/X20 4 1
expected: #{690ED41A}
check size 4 expected

size: arm64-encoder/divide-register code 256 arm64-encoder/X9
	arm64-encoder/X19 arm64-encoder/X20 8 0
expected: #{690AD49A}
check size 4 expected

size: arm64-encoder/multiply-subtract code 256 arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 arm64-encoder/X12 8
expected: #{49B10B9B}
check size 4 expected

size: arm64-encoder/shift-register code 256 arm64-encoder/SHIFT_LEFT
	arm64-encoder/X9 arm64-encoder/X19 arm64-encoder/X20 8
expected: #{6922D49A}
check size 4 expected

size: arm64-encoder/shift-immediate code 256 arm64-encoder/SHIFT_LEFT
	arm64-encoder/X9 arm64-encoder/X19 7 8
expected: #{69E279D3}
check size 4 expected

size: arm64-encoder/shift-immediate code 256 arm64-encoder/SHIFT_RIGHT
	arm64-encoder/X9 arm64-encoder/X19 7 4
expected: #{697E0753}
check size 4 expected

size: arm64-encoder/shift-immediate code 256 arm64-encoder/SHIFT_ARITHMETIC
	arm64-encoder/X9 arm64-encoder/X19 7 8
expected: #{69FE4793}
check size 4 expected

size: arm64-encoder/negate-register code 256 arm64-encoder/X9 arm64-encoder/X19 8
expected: #{E90313CB}
check size 4 expected

size: arm64-encoder/move-not-register code 256 arm64-encoder/X9 arm64-encoder/X19 4
expected: #{E903332A}
check size 4 expected

size: arm64-encoder/compare-register code 256 arm64-encoder/X19 arm64-encoder/X20 8
expected: #{7F0214EB}
check size 4 expected

size: arm64-encoder/compare-immediate code 256 arm64-encoder/X19 42 4
expected: #{7FAA0071}
check size 4 expected

size: arm64-encoder/condition-result code 256 arm64-encoder/X9 arm64-encoder/EQ
expected: #{E9179F1A}
check size 4 expected

size: arm64-encoder/conditional-negate code 256 arm64-encoder/X16
	arm64-encoder/X17 4 arm64-encoder/MI
expected: #{3056915A}
check size 4 expected

size: arm64-encoder/conditional-negate code 256 arm64-encoder/X9
	arm64-encoder/X10 8 arm64-encoder/PL
expected: #{49458ADA}
check size 4 expected

size: arm64-encoder/conditional-select code 256 arm64-encoder/X16
	arm64-encoder/X16 arm64-encoder/ZR 4 arm64-encoder/MI
expected: #{10429F1A}
check size 4 expected

size: arm64-encoder/conditional-select code 256 arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 8 arm64-encoder/PL
expected: #{49518B9A}
check size 4 expected

size: arm64-encoder/branch-zero code 256 arm64-encoder/X9 8 20 false
expected: #{A90000B4}
check size 4 expected

size: arm64-encoder/branch-zero code 256 arm64-encoder/X9 4 16 true
expected: #{89000035}
check size 4 expected

size: arm64-encoder/branch-condition code 256 arm64-encoder/EQ 12
expected: #{60000054}
check size 4 expected

size: arm64-encoder/branch-relative code 256 8
expected: #{02000014}
check size 4 expected

size: arm64-encoder/call-relative code 256 4
expected: #{01000094}
check size 4 expected

size: arm64-encoder/call-register code 256 arm64-encoder/X16
expected: #{00023FD6}
check size 4 expected

size: arm64-encoder/jump-register code 256 arm64-encoder/X17
expected: #{20021FD6}
check size 4 expected

size: arm64-encoder/page-address code 256 arm64-encoder/X16
expected: #{1000009010020091}
check size 8 expected

size: arm64-encoder/frame-load code 256 arm64-encoder/X9 -40 8 0 8
expected: #{A9835DF8}
check size 4 expected

size: arm64-encoder/frame-store code 256 arm64-encoder/X9 -44 4
expected: #{A9431DB8}
check size 4 expected

size: arm64-encoder/register-load code 256 arm64-encoder/X9 arm64-encoder/X19
	32760 8 0 8 arm64-encoder/X16
expected: #{69FE7FF9}
check size 4 expected

size: arm64-encoder/register-store code 256 arm64-encoder/X9 arm64-encoder/SP
	16380 4 arm64-encoder/X16
expected: #{E9FF3FB9}
check size 4 expected

size: arm64-encoder/register-load code 256 arm64-encoder/X9 arm64-encoder/X19
	-1 1 1 4 arm64-encoder/X16
expected: #{69F2DF38}
check size 4 expected

size: arm64-encoder/store-pair code 256 arm64-encoder/X19 arm64-encoder/X20
	arm64-encoder/FP -48
expected: #{B3533DA9}
check size 4 expected

size: arm64-encoder/load-pair code 256 arm64-encoder/X19 arm64-encoder/X20
	arm64-encoder/FP -48
expected: #{B3537DA9}
check size 4 expected

size: arm64-encoder/frame-enter code 256 32
expected: #{FD7BBFA9FD030091FF8300D1}
check size 12 expected

size: arm64-encoder/frame-leave code 256
expected: #{BF030091FD7BC1A8C0035FD6}
check size 12 expected

size: arm64-encoder/float-move-register code 256 arm64-encoder/X9 arm64-encoder/X10 8
expected: #{4941601E}
check size 4 expected

size: arm64-encoder/float-move-from-register code 256 arm64-encoder/X0
	arm64-encoder/X1 4
expected: #{2000271E}
check size 4 expected

size: arm64-encoder/float-move-to-register code 256 arm64-encoder/X2
	arm64-encoder/X3 4
expected: #{6200261E}
check size 4 expected

size: arm64-encoder/float-move-from-register code 256 arm64-encoder/X4
	arm64-encoder/X5 8
expected: #{A400679E}
check size 4 expected

size: arm64-encoder/float-move-to-register code 256 arm64-encoder/X6
	arm64-encoder/X7 8
expected: #{E600669E}
check size 4 expected

size: arm64-encoder/float-move-immediate code 256 arm64-encoder/X8 4
	3F800000h 0
expected: #{08102E1E}
check size 4 expected

size: arm64-encoder/float-move-immediate code 256 arm64-encoder/X9 8
	0 3FF00000h
expected: #{09106E1E}
check size 4 expected

size: arm64-encoder/float-convert code 256 arm64-encoder/X8 arm64-encoder/X9 8 4
expected: #{2841621E}
check size 4 expected

size: arm64-encoder/float-convert code 256 arm64-encoder/X10 arm64-encoder/X11 4 8
expected: #{6AC1221E}
check size 4 expected

size: arm64-encoder/integer-to-float code 256 arm64-encoder/X12
	arm64-encoder/X13 4 4 1
expected: #{AC01221E}
check size 4 expected

size: arm64-encoder/integer-to-float code 256 arm64-encoder/X14
	arm64-encoder/X15 8 8 0
expected: #{EE01639E}
check size 4 expected

size: arm64-encoder/float-to-integer code 256 arm64-encoder/X16
	arm64-encoder/X17 4 4 1
expected: #{3002381E}
check size 4 expected

size: arm64-encoder/float-to-integer code 256 arm64-encoder/X18
	arm64-encoder/X19 8 8 0
expected: #{7202799E}
check size 4 expected

size: arm64-encoder/float-register-load code 256 20 arm64-encoder/X21
	-4 4 arm64-encoder/X16
expected: #{B4C25FBC}
check size 4 expected

size: arm64-encoder/float-register-load code 256 24 arm64-encoder/X25
	12 4 arm64-encoder/X16
expected: #{380F40BD}
check size 4 expected

size: arm64-encoder/float-register-store code 256 26 arm64-encoder/X27
	24 8 arm64-encoder/X16
expected: #{7A0F00FD}
check size 4 expected

size: arm64-encoder/float-binary code 256 arm64-encoder/OP_ADD arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 8
expected: #{49296B1E}
check size 4 expected

size: arm64-encoder/float-binary code 256 arm64-encoder/OP_SUB arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 4
expected: #{49392B1E}
check size 4 expected

size: arm64-encoder/float-multiply code 256 arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 8
expected: #{49096B1E}
check size 4 expected

size: arm64-encoder/float-divide code 256 arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 4
expected: #{49192B1E}
check size 4 expected

size: arm64-encoder/float-compare code 256 arm64-encoder/X10 arm64-encoder/X11 8
expected: #{40216B1E}
check size 4 expected

if (arm64-encoder/move-immediate null 0 arm64-encoder/X11 8 12345678h 0) <> 8 [
	failures: failures + 1
]
if (arm64-encoder/move-immediate code 7 arm64-encoder/X11 8 12345678h 0) <> -1 [
	failures: failures + 1
]
if (arm64-encoder/branch-relative code 256 2) <> -1 [failures: failures + 1]
if (arm64-encoder/branch-condition code 256 arm64-encoder/EQ 1048576) <> -1 [
	failures: failures + 1
]
if (arm64-encoder/register-store code 256 arm64-encoder/X9 arm64-encoder/X19
	300000 8 arm64-encoder/X9) <> -1 [
	failures: failures + 1
]
if (arm64-encoder/alu-register code 256 arm64-encoder/OP_OR arm64-encoder/X9
	arm64-encoder/X10 arm64-encoder/X11 8 true) <> -1 [
	failures: failures + 1
]
if (arm64-encoder/logical-immediate code 256 arm64-encoder/OP_AND
	arm64-encoder/X9 arm64-encoder/X10 4 0 0) <> -1 [
	failures: failures + 1
]
if (arm64-encoder/logical-immediate code 256 arm64-encoder/OP_OR
	arm64-encoder/X9 arm64-encoder/X10 8 -1 -1) <> -1 [
	failures: failures + 1
]

free code
either failures = 0 [
	print ["PASS: primitive Apple AArch64 encoder" lf]
][
	print ["FAIL: primitive Apple AArch64 encoder failures=" failures lf]
]
quit failures
