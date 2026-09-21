Red [Title: "Hybrid codegen bridge diagnostic contract"]

#include %../../../compiler/codegen-bridge.red

check: func [condition [logic!] message [string!]][
	unless condition [print ["FAIL:" message] quit/return 1]
]

ir: make binary! 98
append/dup ir #{00} 98
foreach [index value] [1 1 17 1 21 1 49 2 77 1 81 11 97 102 98 110][
	poke ir index value
]

artifact: make binary! 1
check 4 = codegen-module ir artifact 1 1 0 "short output must request growth"
check empty? artifact "failed generation must leave output empty"
required: codegen-required
check required > 1 "required capacity must be available through the bridge"
artifact: make binary! 4096
check 0 = codegen-module ir artifact 1 1 0 "retry must succeed"
check 0 = codegen-required "successful retry clears capacity diagnostic"
clear artifact
check 3 = codegen-module ir artifact 1 1 1 "unsupported optimization status"
check 1 = codegen-module ir artifact 99 1 0 "invalid architecture status"
check 2 = codegen-module copy/part ir 43 artifact 2 3 0 "invalid IR status"
check 0 = codegen-module ir artifact 2 3 0 "ARM64 recovery after failure"
print "PASS: codegen bridge diagnostics"
