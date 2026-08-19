Red [
	Title: "Compiler phase timer tests"
]

do %../../../compiler/phase-timer.red

assert: func [condition [logic!] message [string!]][
	unless condition [
		print ["FAIL:" message]
		quit/return 1
	]
]

phase-timer/reset
phase-timer/active?: yes
phase-timer/begin 'nested
phase-timer/begin 'nested
phase-timer/finish 'nested
phase-timer/finish 'nested

record: phase-timer/snapshot
assert phase-timer/balanced? "nested phase stack was not cleared"
assert (length? record) = 3 "unexpected snapshot shape"
assert record/1 = 'nested "unexpected phase name"
assert record/2 = 2 "nested phase count was not accumulated"
assert time? record/3 "phase duration is not a time value"
assert integer? phase-timer/gc-cycles 'nested "GC cycle count is not an integer"
assert not negative? phase-timer/gc-cycles 'nested "GC cycle count is negative"
assert zero? phase-timer/gc-cycles 'missing "missing phase has GC cycles"

before: system/state/GC/series-cycles
phase-timer/begin 'gc-cycle
recycle
phase-timer/finish 'gc-cycle
after: system/state/GC/series-cycles
assert after > before "explicit recycle did not run a GC cycle"
assert (after - before) = phase-timer/gc-cycles 'gc-cycle "GC cycle delta was not recorded"

print "PASS: compiler phase timer"
