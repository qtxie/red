Red/System [Title: "Counted stack bitmap records"]

#include %../../../codegen/stack-bitmap.reds

check: func [condition [logic!]][
	unless condition [print ["stack bitmap check failed" lf] quit 1]
]

record: as int-ptr! allocate 32
check (stack-bitmap/words 0) = 1
check (stack-bitmap/words 31) = 1
check (stack-bitmap/words 32) = 2
check (stack-bitmap/words 62) = 2
check (stack-bitmap/words 63) = 3
check (stack-bitmap/record-size 0) = 16
check (stack-bitmap/record-size 31) = 16
check (stack-bitmap/record-size 32) = 20
check (stack-bitmap/record-size 63) = 24

stack-bitmap/initialize record 0
check record/1 = 0
check record/2 = 0
check record/3 = 0
check record/4 = 0
check not stack-bitmap/mark record 0

stack-bitmap/initialize record 3
check stack-bitmap/mark record 0
check stack-bitmap/mark record 2
check record/4 = 5
check not stack-bitmap/mark record 3
check not stack-bitmap/mark record -1
check record/4 = 5

stack-bitmap/initialize record 63
check record/1 = 0
check record/2 = 63
check record/3 = 0
check record/4 = 80000000h
check record/5 = 80000000h
check record/6 = 0
check stack-bitmap/mark record 30
check stack-bitmap/mark record 31
check stack-bitmap/mark record 61
check stack-bitmap/mark record 62
check record/4 = C0000000h
check record/5 = C0000001h
check record/6 = 1
check not stack-bitmap/mark record 63
free as byte-ptr! record
#if target = 'ARM64 [
	check-catch-bitmap: func [
		/local frame slot [ptr-ptr!] before [integer!]
	][
		frame: as ptr-ptr! system/stack/frame
		slot: frame - 5
		before: as integer! slot/value
		check before > 0
		catch 1 [
			check (as integer! slot/value) = before
			catch 2 [
				check (as integer! slot/value) = before
				throw 2
			]
			check (as integer! slot/value) = before
			throw 1
		]
		check (as integer! slot/value) = before
	]
	check-catch-bitmap
]
print ["stack bitmap records: PASS" lf]
