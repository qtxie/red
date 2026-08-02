Red [
	Title: "Linux ARM Red/System cross-suite builder"
	File:  %build-arm32-red-system-tests.red
	Config: [show: 'ARM-ELF-only]
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red
#include %arm-red-system-suite-builder.red

arm-suite-builder/run "RPi" system/options/args
