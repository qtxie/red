Red [
	Title: "Self-hosted Red compiler bootstrap"
	File:  %red-bootstrap-windows.red
	Config: [show: 'X86-64-only]
]

; Bootstrap and focused target wrappers select one backend at preprocess time.
#either config/show = 'X86-64-Hybrid-only [
	#include %system/compiler-windows-hybrid-bootstrap.red
][
	#either config/show = 'X86-64-ELF-only [
		#include %system/compiler.red
	][
		#include %system/compiler-windows-bootstrap.red
	]
]

#include %compiler/bootstrap-driver.red
