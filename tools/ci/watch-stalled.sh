#!/usr/bin/env bash
# Give every process a suite starts a deadline, and say where the one that missed
# it was stuck.
#
# A harness that waits on a hung unit waits forever. On the ARM64 job one unit that
# never returned held the runner for the whole 90-minute budget, and everything the
# suite would still have reported after it was cancelled with it -- the log stopped
# at "compile ... -> ..." and said nothing more. `timeout` cannot bound that: it
# would kill the *suite*, which is the part that has to keep going. So this watches
# the suite's own children -- the unit or compiler it is blocked on -- and kills
# only that one, which turns a lost job into a failed unit.
#
# The report is the other half. A stalled process is otherwise invisible: "the log
# went quiet" does not say whether the compiler, the unit or the harness stopped, and
# it certainly does not say where. The thread list answers the shape of it -- every
# thread R means a spin, a thread S in futex means a join or a lock that will never
# be released -- and the backtrace answers the place, when the runner lets gdb
# attach at all.
#
#   watch-stalled.sh <seconds> -- <command...>
set -uo pipefail

limit=${1:-}
[[ ${limit:-} =~ ^[0-9]+$ ]] || { echo "usage: $0 <seconds> -- <command...>" >&2; exit 2; }
[[ ${2:-} == -- ]] || { echo "usage: $0 <seconds> -- <command...>" >&2; exit 2; }
shift 2

# What watching needs: a /proc to read, pgrep to walk the tree, and a `ps` that ages
# a process. A host without them gets a plain run, plus one line saying the deadline
# was never armed -- otherwise a job that hangs there looks like one that was watched
# and found innocent.
if [[ ! -d /proc || -z $(command -v pgrep) ]] || ! ps -o etimes= -p $$ >/dev/null 2>&1; then
	echo "watch-stalled: cannot inspect processes here; running unwrapped" >&2
	exec "$@"
fi

children() { pgrep -P "$1" 2>/dev/null || true; }

# Post-order, so a parent is printed after its children: the deepest process -- the
# one actually doing the work -- is the interesting one.
walk() {
	local pid
	for pid in $(children "$1"); do
		walk "$pid"
		printf '%s\n' "$pid"
	done
}

report() {
	local pid=$1 t trace
	echo "STALL: pid $pid has been alive past ${limit}s"
	ps -o pid,ppid,stat,etimes,time,args --no-headers -p "$pid" || true
	for t in /proc/$pid/task/*; do
		[[ -r $t/stat ]] || continue
		printf '  thread %-8s state=%-1s cpu=%ss wchan=%s\n' "${t##*/}" \
			"$(awk '{print $3}' "$t/stat")" \
			"$((($(awk '{print $14 + $15}' "$t/stat")) / 100))" \
			"$(cat "$t/wchan" 2>/dev/null)"
	done
	if command -v gdb >/dev/null; then
		trace=$(gdb -p "$pid" --batch --quiet -ex 'thread apply all bt 24' 2>&1)
		# An unprivileged runner cannot attach to a process it did not fork, and gdb
		# then spends four lines saying so. Say it in one, and keep the thread list
		# above as the evidence.
		if [[ $trace == *"Could not attach"* ]]; then
			echo "  no backtrace: gdb cannot ptrace a process it did not start"
		else
			printf '%s\n' "$trace" | head -300
		fi
	fi
}

# bash reaps a finished background job on its own, so both "gone" and "zombie" mean
# the process is over -- only a live state means there is still something to watch.
alive() {
	local state
	state=$(awk '{print $3}' "/proc/$1/stat" 2>/dev/null)
	[[ -n $state && $state != Z ]]
}

"$@" &
root=$!
killed=
victims=0
while alive "$root"; do
	sleep 5
	for pid in $(walk "$root"); do
		age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
		[[ -n $age && $age -ge $limit ]] || continue
		case " $killed " in *" $pid "*) continue ;; esac   # never report one pid twice
		report "$pid"
		killed="$killed $pid"
		victims=$((victims + 1))
		kill -9 "$pid" 2>/dev/null || true
	done
done
wait "$root"
status=$?
[ "$victims" = 0 ] || echo "STALL: $victims stalled process(es) killed; the suite went on"
exit "$status"
