Red [
	Title: "Standalone hybrid Red toolchain"
	File:  %red-toolchain-hybrid.red
	Config: [show: 'X86-64-Hybrid-only]
]

#include %build/generated/red-toolchain-resources.generated.red

compiler-command: "red-toolchain"

;-- One source, every target. The hybrid core is a cross-compiler, so what
;-- makes this the macOS or Linux toolchain is `-t Darwin-ARM64` /
;-- `-t Linux-X86-64` at build time: that sets `config/OS`, and
;-- bootstrap-driver then reports that target as the host and defaults to it.
;-- It used to be duplicated as %red-toolchain-darwin-hybrid.red, identical
;-- apart from this header.
#include %system/compiler-hybrid-bootstrap.red
#include %compiler/bootstrap-driver.red
