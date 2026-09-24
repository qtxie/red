Red [
	Title:   "Red compiler target registry"
	File:    %system/target-registry.red
	Purpose: {
		The one place a compilation target is declared. Adding or changing a
		target means editing this file: there is no config.r behind it and no
		generator in front of it. `compiler-system-job/new` looks a target up
		here by name, the format in `system/formats/` reads the fields it
		needs, and `--list-targets` reports the names in the order below.
	}
]

;-------------------------------------------
;     Compilation Target Options
;-------------------------------------------
;;	OS:				'Windows | 'Linux | 'macOS
;;					| 'Syllable | 'FreeBSD
;;					| 'NetBSD | 'Android			;-- operating system name
;;	format:			'PE | 'ELF | 'Mach-O			;-- file format
;;	type:			'exe | 'dll | 'drv				;-- file type
;;	target:			'IA-32 | 'ARM | 'ARM64 | 'X86-64	;-- CPU or VM target
;;	cpu-version:	<decimal!>						;-- CPU version (default: 6.0)
;;	ABI:			none | word!					;-- optional ABI flags
;;	sub-system:		'GUI | 'console | 'driver		;-- Windows: 2, 3, 1 (see defs/sub-system)
;;	PIC?:			yes | no						;-- generate Position Independent Code
;;	PIE?:			yes | no						;-- generate Position Independent Executable
;;	base-address:	<integer!>						;-- base image memory address
;;	use-natives?:	yes | no						;-- native functions instead of C bindings
;;	dynamic-linker:	none | <string!>				;-- ELF dynamic linker ("interpreter")
;;	syscall:		'Linux | 'BSD					;-- syscalls calling convention
;;	stack-align-16?: yes | no						;-- yes => align stack to 16 bytes
;;	literal-pool?:	yes | no						;-- yes => store literals in pools
;;	debug?:			yes | no						;-- yes => emit debug information
;;	debug-safe?:	yes | no						;-- yes => avoid over-crashing on debug reports
;;	dev-mode?:		yes | no						;-- yes => link a prebuilt runtime
;;	red-store-bodies?: yes | no						;-- no => do not store function! bodies
;;	red-strict-check?: yes							;-- no => defer undefined word errors to run-time
;;	red-tracing?:	yes								;-- no => do not compile tracing code
;;	red-help?:		no								;-- yes => keep doc-strings from boot.red
;;	gui-console?:	no								;-- yes => redirect printing to the GUI console
;;	GUI-engine:		'native							;-- native | test | GTK | ...
;;	draw-engine:	none | 'GDI+					;-- none => the best one for the OS
;;	packager:		'Mach-APP						;-- wraps the output in a bundle
;;	legacy:			block! of words				;-- flags for OS legacy features
;;		- stat32									;-- use the older stat struct
;;		- no-touch									;-- no touch support
;;		- no-multi-monitor
;;-------------------------------------------
;; Values are Red literals: logic is #(true)/#(false), a word is bare, a string
;; is quoted, a block stays a block. `sub-system` is what picks the Windows PE
;; sub-system: 'console is
;; IMAGE_SUBSYSTEM_WINDOWS_CUI (3), 'GUI is IMAGE_SUBSYSTEM_WINDOWS_GUI (2) and
;; attaches no console window, 'driver is 1. Every target names its `target`
;; CPU class explicitly.
;;-------------------------------------------

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
	MSDOS-X86-64 [
		OS Windows
		format PE
		target X86-64
		type exe
		ABI win64
		sub-system console
		stack-align-16? #(true)
	]
	Windows-X86-64 [
		OS Windows
		format PE
		target X86-64
		type exe
		ABI win64
		sub-system GUI
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

;-- What the compiler can emit for, gathered from every target above: the CPUs
;-- a `target` may name, and the containers a `format` may name.
compiler-target-classes: [IA-32 ARM X86-64 ARM64]
compiler-formats: [PE ELF Mach-O]
compiler-object-formats: [COFF ELF-obj Mach-O-obj]
