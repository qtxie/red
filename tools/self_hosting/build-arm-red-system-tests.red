Red [
	Title: "Linux ARM64 Red/System cross-suite builder"
	File:  %build-arm-red-system-tests.red
	Config: [show: 'ARM64-ELF-only]
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red
#include %arm-red-system-suite-builder.red

arm-suite-builder/run "Linux-ARM64" system/options/args
