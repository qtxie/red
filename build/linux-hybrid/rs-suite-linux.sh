#!/bin/bash
# Linux x86-64 Red/System unit regression: cross-compile the same 40 units the
# Windows suite covers, then run them on a Linux host and compare their output
# against the Windows run logs. The host is either a remote box reached over
# ssh or the local WSL distribution, which has no sshd of its own.
cd /e/temp3/red
C=${1:-./build/self-hosting/merge-red64/hybrid-compiler93.exe}
TARGET=${2:-Linux-X86-64}
HOST=${3:-vps}
TAG=$(basename "$C" .exe)
# The two Linux targets share one generation, so the output directory carries
# the target too -- otherwise the second run overwrites the first one's logs.
OUT=build/linux-hybrid/rs-$TAG-$(echo "${TARGET#Linux-}" | tr 'A-Z' 'a-z')
REF=build/win-regression/rs-$TAG
mkdir -p $OUT
UNITS="alias-test array-test atomic-test byte-test c-string-test case-test cast-test conditional-test enum-test exceptions-test exit-test fixed-int-test float-pointer-test float-test float32-test function-test get-pointer-test infix-test int64-test integer-test length-test lib-test logic-test math-mixed-test modulo-test namespace-test not-test null-test overflow-test pointer-test protect-test push-pop-test queue-test return-test struct-x64-test subroutine-test switch-test system-test union-test use-test vararg-test"

# struct-x64-test dlopens a 64-bit structlib by its bare name, so the library
# goes to the host beside the units and the loader is pointed at that
# directory. The two targets need different builds of it.
LIBDIR=/tmp
LIBSRC=system/tests/source/units/libs/structlib.so
[ "${TARGET#Linux-}" = "ARM64" ] && LIBSRC=system/tests/source/units/libs/structlib-arm64.so

case "$HOST" in
  wsl)
    ship_one() { wsl.exe -- bash -c "cat > $2 && chmod +x $2" < "$1"; }
    runon()    { wsl.exe -- bash -c "LD_LIBRARY_PATH=$LIBDIR timeout 120 $1" 2>&1; }
    ;;
  *)
    ship_one() { scp -q "$1" $HOST:"$2" && ssh $HOST "chmod +x $2"; }
    runon()    { ssh $HOST "LD_LIBRARY_PATH=$LIBDIR timeout 120 $1" 2>&1; }
    ;;
esac

ship_one "$LIBSRC" "$LIBDIR/$(basename "$LIBSRC")" >/dev/null 2>&1

pass=0; fail=0; runpass=0; runfail=0; diffcount=0; noref=0; failed=""
for u in $UNITS; do
  if timeout 300 "$C" -r -t $TARGET -o "$OUT/$u" "system/tests/source/units/$u.reds" > "$OUT/$u.compile.log" 2>&1 && [ -f "$OUT/$u" ]; then
    pass=$((pass+1))
    if ship_one "$OUT/$u" "/tmp/rs-$u" >/dev/null 2>&1; then
      # Redirect straight into the log: $(...) would swallow the trailing
      # blank line the Windows run keeps, and the comparison below is
      # byte-exact. Carriage returns, if the transport adds any, go after.
      runon "/tmp/rs-$u" > "$OUT/$u.run.log" 2>&1; status=$?
      tr -d '\r' < "$OUT/$u.run.log" > "$OUT/$u.run.log.crlf" && mv "$OUT/$u.run.log.crlf" "$OUT/$u.run.log"
      if [ $status -eq 0 ]; then
        runpass=$((runpass+1))
        # The Windows console turns every LF into CRLF, so compare the output
        # with the carriage returns taken back out.
        if [ ! -f "$REF/$u.run.log" ]; then
          # Nothing to compare against, so say so instead of counting this as
          # a match -- `differed: 0` used to mean either "identical" or "no
          # reference was ever generated for this generation".
          noref=$((noref+1)); echo "NOREF $u"
        elif ! diff -q <(tr -d '\r' < "$REF/$u.run.log") "$OUT/$u.run.log" >/dev/null; then
          diffcount=$((diffcount+1)); echo "DIFF $u"
        else
          echo "OK   $u"
        fi
      else
        runfail=$((runfail+1)); failed="$failed $u(run:$status)"; echo "RUNFAIL $u"
      fi
    else
      runfail=$((runfail+1)); failed="$failed $u(ship)"; echo "SHIPFAIL $u"
    fi
  else
    fail=$((fail+1)); failed="$failed $u(compile)"; echo "FAIL $u"
  fi
done
echo "compiled: $pass pass, $fail fail"
echo "ran     : $runpass pass, $runfail fail"
echo "differed: $diffcount  noref: $noref"
[ -n "$failed" ] && echo "failed:$failed"
