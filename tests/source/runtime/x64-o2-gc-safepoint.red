Red [
	Title: "Red x86-64 O2 GC safepoint root test"
	File:  %x64-o2-gc-safepoint.red
]

#system [
	force-gc-token: func [
		return: [integer!]
	][
		stack/mark-native ~recycle
		natives/recycle* true -1 -1
		stack/unwind
		1
	]

	consume-live-series: func [
		values [red-block!]
		text [red-string!]
		token [integer!]
		return: [integer!]
	][
		(block/rs-length? values) + (string/rs-length? text) + token - 1
	]
]

; A routine body is emitted as Red/System. Keep the managed series live in
; its argument slots across a helper that performs a real collection, then
; read the relocated cells.
gc-live-series-length: routine [
	values [block!]
	text [string!]
	return: [integer!]
][
	consume-live-series values text force-gc-token
]

values: make block! 6000
repeat index 6000 [append values index]
text: make string! 1500
append/dup text "x" 1500

unless 7500 = gc-live-series-length values text [quit/return 1]
unless values/6000 = 6000 [quit/return 1]
unless text/1500 = #"x" [quit/return 1]

print "X64-O2-GC-SAFEPOINT-OK"
