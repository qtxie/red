#!/bin/bash
# Cross-compile the macOS slices of both suites with 179, plus the Darwin
# toolchain itself, so the Mac can run them natively.
cd /e/temp3/red
C=./build/self-hosting/merge-red64/hybrid-compiler179.exe
OUT=build/tmp-mac179

echo "=== darwin toolchain at 179 ==="
$C -r -t Darwin-ARM64 -o build/red-toolchain/darwin-arm64/red-toolchain-179 \
	red-toolchain-darwin-hybrid.red 2>&1 | grep -viE "type casting from" | tail -2

mkdir -p $OUT/rs $OUT/red

RS="alias-test array-test atomic-test byte-test c-string-test case-test cast-test
conditional-test enum-test exceptions-test exit-test fixed-int-test
float-pointer-test float-test float32-test function-test get-pointer-test
infix-test int64-test integer-test length-test lib-test logic-test
math-mixed-test modulo-test namespace-test not-test null-test overflow-test
pointer-test protect-test push-pop-test queue-test return-test
subroutine-test switch-test system-test union-test use-test vararg-test"

RED="logic-test integer-test float-test char-test series-test append-test
path-test object-test map-test function-test loop-test parse-test make-test
convert-test mold-test load-test lexer-test evaluation-test binding-test
type-test routine-test recycle-test comparison-test"

p=0; f=0; failed=""
for u in $RS; do
  if $C -r -t Darwin-ARM64 -o $OUT/rs/$u system/tests/source/units/$u.reds \
	  > $OUT/rs/$u.compile.log 2>&1 && [ -f $OUT/rs/$u ]; then
	p=$((p+1))
  else
	f=$((f+1)); failed="$failed rs/$u"
  fi
done
echo "RS compiled: $p pass, $f fail $failed"

p=0; f=0; failed=""
for u in $RED; do
  if $C -r -t Darwin-ARM64 -o $OUT/red/$u tests/source/units/$u.red \
	  > $OUT/red/$u.compile.log 2>&1 && [ -f $OUT/red/$u ]; then
	p=$((p+1)); echo "OK   $u"
  else
	f=$((f+1)); failed="$failed red/$u"; echo "FAIL $u"
  fi
done
echo "RED compiled: $p pass, $f fail $failed"
