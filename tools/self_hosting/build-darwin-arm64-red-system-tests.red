Red [
	Title: "Darwin ARM64 Red/System cross-suite builder"
	File:  %build-darwin-arm64-red-system-tests.red
	Config: [show: 'ARM64-Darwin-only]
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red
#include %arm-red-system-suite-builder.red

; The installed interpreter has a collector fault during large compiler jobs.
; Generated test runtimes still use their normal GC configuration.
recycle/off
arm-suite-builder/run "Darwin-ARM64" system/options/args
