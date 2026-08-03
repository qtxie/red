Red []

; The selected include must restore this file's directory before #system is
; processed, so the sibling Red/System include does not resolve under %sub/.
#switch config/OS [
	Windows [#include %sub/selected.red]
]

#system [
	#include %after.reds
]

print "include-origin-ok"
