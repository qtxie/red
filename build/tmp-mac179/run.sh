#!/bin/bash
# Run one directory of cross-compiled unit binaries on the Mac and total the
# assertions. Usage: run.sh DIR LABEL
# There is no `timeout` on this box, so each run gets a watchdog instead.
DIR=${1:-.}
LABEL=${2:-suite}
cd "$DIR" || exit 1
chmod +x * 2>/dev/null
pass=0; fail=0; failed=""
for f in *; do
	case "$f" in
		*.log|*.out|*.red|*.reds|*.txt) continue ;;
	esac
	[ -f "$f" ] || continue
	( "./$f" > "$f.out" 2>&1 & pid=$!
	  ( sleep 90; kill -9 $pid 2>/dev/null ) & wd=$!
	  wait $pid; code=$?
	  kill -9 $wd 2>/dev/null
	  exit $code )
	code=$?
	line=$(grep -iE "Number of Assertions Failed|assertions: .* failed:" "$f.out" | tail -1)
	n=$(echo "$line" | grep -oE "[0-9]+" | tail -1)
	if [ "$code" = "0" ] && [ "$n" = "0" ]; then
		pass=$((pass+1))
	else
		fail=$((fail+1)); failed="$failed $f(exit=$code,$n)"
	fi
	echo "$f exit=$code |$line"
done
echo "$LABEL: $pass pass, $fail fail $failed"
