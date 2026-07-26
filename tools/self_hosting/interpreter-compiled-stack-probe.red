Red [
	Title: "Interpreter to compiled function stack probe"
]

probe: context [
	step: func [n [integer!]][
		if zero? n [return 1]
		1 + do compose [probe/step (n - 1)]
	]
]

repeat run 200 [
	result: probe/step 100
	if result <> 101 [
		print ["FAIL: expected 101, got" result]
		quit/return 1
	]
]

print "PASS: interpreter/compiled stack remained balanced"
