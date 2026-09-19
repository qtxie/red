Red [
	Title: "Standalone Darwin ARM64 hybrid Red toolchain"
	File:  %red-toolchain-darwin-hybrid.red
	Config: [show: 'X86-64-Hybrid-only]
]

#include %build/generated/red-toolchain-resources.generated.red

compiler-command: "red-toolchain"

;-- Same compiler closure as `red-toolchain-windows-hybrid.red`: the hybrid
;-- core is a cross-compiler, so the Windows-named include is not Windows-
;-- specific. What makes this the macOS toolchain is `-t Darwin-ARM64` at
;-- build time, which sets `config/OS` to 'macOS -- bootstrap-driver then
;-- reports Darwin-ARM64 as the host and defaults to it, and
;-- compiler-hybrid-common imports the chmod its executables need.
#include %system/compiler-windows-hybrid-bootstrap.red
#include %compiler/bootstrap-driver.red
