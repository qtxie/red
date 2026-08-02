Red [
	Title: "Red/System namespace undecoration operator regression"
	File:  %undecorate-operator-test.red
	Config: [show: 'ARM64-ELF-only]
]

#include %../../system/compiler.red

foreach operator [> >= <> >> >>>][
	unless operator = system-dialect/compiler/undecorate operator [
		print ["FAIL undecorate changed" mold operator]
		quit/return 1
	]
]

internal: to word! "exec>f_extract-boot-args"
unless 'exec/f_extract-boot-args = system-dialect/compiler/undecorate internal [
	print ["FAIL undecorate did not restore internal path" mold internal]
	quit/return 1
]

print "PASS undecorate operators and internal paths"
quit/return 0
