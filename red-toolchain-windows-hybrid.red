Red [
	Title: "Standalone Windows x64 hybrid Red toolchain"
	File:  %red-toolchain-windows-hybrid.red
	Config: [show: 'X86-64-Hybrid-only]
]

#include %build/generated/red-toolchain-resources.generated.red

compiler-command: "red-toolchain"

#include %system/compiler-windows-hybrid-bootstrap.red
#include %compiler/bootstrap-driver.red
