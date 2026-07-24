Red [
	Title: "Generated Red compiler target registry"
	File:  %target-registry.red
]

; Generated from system/config.r. Do not edit by hand.
target-registry-source-sha256: "b1c3aaaa325fda80ec38a8791125fbf06c983b70b11ce196707913643cc621df"
target-registry: [
	MSDOS [
		OS Windows
		format PE
		type exe
		sub-system console
		target IA-32
	]
	Windows [
		OS Windows
		format PE
		type exe
		sub-system GUI
		target IA-32
	]
	Windows7 [
		OS Windows
		format PE
		type exe
		sub-system GUI
		legacy [no-multi-monitor]
		target IA-32
	]
	WindowsXP [
		OS Windows
		format PE
		type exe
		sub-system GUI
		legacy [no-touch no-multi-monitor]
		draw-engine GDI+
		target IA-32
	]
	MSDOS-Old [
		OS Windows
		format PE
		type exe
		sub-system console
		cpu-version 1.0
		target IA-32
	]
	Windows-Old [
		OS Windows
		format PE
		type exe
		sub-system GUI
		cpu-version 1.0
		target IA-32
	]
	WinDLL [
		OS Windows
		format PE
		type DLL
		sub-system GUI
		red-store-bodies? #(false)
		target IA-32
	]
	Windows-X86-64 [
		OS Windows
		format PE
		target X86-64
		type exe
		ABI win64
		sub-system console
		stack-align-16? #(true)
	]
	Windows-X86-64-DLL [
		OS Windows
		format PE
		target X86-64
		type DLL
		ABI win64
		sub-system GUI
		stack-align-16? #(true)
		red-store-bodies? #(false)
	]
	WinDRV [
		OS Windows
		format PE
		type drv
		sub-system driver
		use-natives? #(true)
		red-store-bodies? #(false)
		target IA-32
	]
	Linux [
		OS Linux
		format ELF
		type exe
		dynamic-linker "/lib/ld-linux.so.2"
		stack-align-16? #(true)
		target IA-32
	]
	Linux-GTK [
		OS Linux
		format ELF
		type exe
		dynamic-linker "/lib/ld-linux.so.2"
		stack-align-16? #(true)
		sub-system GUI
		target IA-32
	]
	Linux-musl [
		OS Linux
		format ELF
		type exe
		dynamic-linker "/lib/ld-musl-i386.so.1"
		stack-align-16? #(true)
		target IA-32
	]
	Linux-Old [
		OS Linux
		format ELF
		type exe
		dynamic-linker "/lib/ld-linux.so.2"
		legacy [stat32]
		target IA-32
	]
	Linux-X86-64 [
		OS Linux
		format ELF
		target X86-64
		type exe
		ABI sysv
		PIC? #(true)
		PIE? #(true)
		stack-align-16? #(true)
		dynamic-linker "/lib64/ld-linux-x86-64.so.2"
	]
	Linux-X86-64-SO [
		OS Linux
		format ELF
		target X86-64
		type dll
		ABI sysv
		PIC? #(true)
		stack-align-16? #(true)
	]
	Linux-X86-64-NoPIE [
		OS Linux
		format ELF
		target X86-64
		type exe
		ABI sysv
		stack-align-16? #(true)
		dynamic-linker "/lib64/ld-linux-x86-64.so.2"
	]
	Linux-ARM64 [
		OS Linux
		format ELF
		target ARM64
		type exe
		ABI aapcs64
		cpu-version 8.0
		PIC? #(true)
		PIE? #(true)
		stack-align-16? #(true)
		dynamic-linker "/lib/ld-linux-aarch64.so.1"
	]
	Linux-ARM64-SO [
		OS Linux
		format ELF
		target ARM64
		type dll
		ABI aapcs64
		cpu-version 8.0
		PIC? #(true)
		stack-align-16? #(true)
	]
	Android [
		OS Android
		format ELF
		target ARM
		type exe
		dynamic-linker "/system/bin/linker"
		red-store-bodies? #(false)
		red-tracing? #(false)
	]
	Android-x86 [
		OS Android
		format ELF
		target IA-32
		type exe
		dynamic-linker "/system/bin/linker"
		red-store-bodies? #(false)
		red-tracing? #(false)
	]
	Linux-ARM [
		OS Linux
		format ELF
		target ARM
		ABI soft-float
		type exe
		cpu-version 5.0
		base-address 32768
		dynamic-linker "/lib/ld-linux.so.3"
	]
	RPi [
		OS Linux
		format ELF
		target ARM
		ABI hard-float
		type exe
		cpu-version 7.0
		base-address 32768
		dynamic-linker "/lib/ld-linux-armhf.so.3"
	]
	RPi-GTK [
		OS Linux
		format ELF
		target ARM
		ABI hard-float
		type exe
		cpu-version 7.0
		base-address 32768
		dynamic-linker "/lib/ld-linux-armhf.so.3"
		sub-system GUI
	]
	Pico [
		OS Linux
		format ELF
		target ARM
		ABI hard-float
		type exe
		cpu-version 7.0
		base-address 32768
		dynamic-linker "/lib/ld-uClibc.so.1"
	]
	Syllable [
		OS Syllable
		format ELF
		type exe
		base-address -2147483648
		target IA-32
	]
	FreeBSD [
		OS FreeBSD
		format ELF
		type exe
		dynamic-linker "/usr/libexec/ld-elf.so.1"
		syscall BSD
		target IA-32
	]
	NetBSD [
		OS NetBSD
		format ELF
		type exe
		dynamic-linker "/usr/libexec/ld.elf_so"
		syscall BSD
		target IA-32
		PIC? #(true)
	]
	Darwin [
		OS macOS
		format Mach-O
		type exe
		sub-system console
		syscall BSD
		stack-align-16? #(true)
		target IA-32
	]
	DarwinSO [
		OS macOS
		format Mach-O
		type dll
		sub-system console
		syscall BSD
		stack-align-16? #(true)
		PIC? #(true)
		target IA-32
	]
	Darwin-ARM64 [
		OS macOS
		format Mach-O
		target ARM64
		type exe
		sub-system console
		syscall BSD
		ABI apple-aarch64
		cpu-version 8.0
		PIC? #(true)
		PIE? #(true)
		stack-align-16? #(true)
	]
	Darwin-ARM64-SO [
		OS macOS
		format Mach-O
		target ARM64
		type dll
		sub-system console
		syscall BSD
		ABI apple-aarch64
		cpu-version 8.0
		PIC? #(true)
		stack-align-16? #(true)
	]
	macOS [
		OS macOS
		format Mach-O
		type exe
		sub-system GUI
		syscall BSD
		stack-align-16? #(true)
		packager Mach-APP
		dev-mode? #(false)
		target IA-32
	]
	macOS-ARM64 [
		OS macOS
		format Mach-O
		target ARM64
		type exe
		sub-system GUI
		syscall BSD
		ABI apple-aarch64
		cpu-version 8.0
		PIC? #(true)
		PIE? #(true)
		stack-align-16? #(true)
		packager Mach-APP
		dev-mode? #(false)
	]
]

compiler-target-classes: [IA-32 ARM X86-64 ARM64]
compiler-formats: [PE ELF Mach-O]
compiler-object-formats: [COFF ELF-obj Mach-O-obj]
