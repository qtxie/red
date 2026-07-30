Red [
	Title: "Red compiler preprocessor adapter"
	File:  %compiler/preprocessor.red
]

; EXPAND-DIRECTIVES is the canonical Red preprocessor. This adapter only
; supplies compiler configuration, source-relative path state, error capture,
; and restoration of process-global state.
;
; Host contract: the runtime preprocessor rewrites #include to DO when
; all [not Rebol system/state/interpreted?] is true. That is correct for
; user scripts, but wrong for the compiler frontend: #include must remain a
; directive so COMP-INCLUDE can load and compile the file.
;
; Include preservation is done by temporarily renaming #include issues, not by
; forcing the global Rebol word true. Forcing Rebol true makes expand use PARSE
; ANY instead of WHILE; on Red that exits early (#3771) and leaves later #if /
; #either / #do directives unexpanded. Residual runtime config/OS accesses in
; Stage1-built EXEs came from that bug.
compiler-preprocessor: context [
	last-error: none
	source-file: none
	include-name: "include"
	include-binary-name: "include-binary"
	include-marker-name: "compiler-include"
	include-binary-marker-name: "compiler-include-binary"

	make-issue: func [name [string!]][to issue! name]

	issue-named?: func [value name [string!]][
		all [issue? :value (form value) = name]
	]

	replace-named-issues: func [
		code [block! paren!]
		from-name [string!]
		to-name [string!]
		/local position value
	][
		position: head code
		while [not tail? position][
			value: position/1
			if any [block? :value paren? :value][
				replace-named-issues value from-name to-name
			]
			if issue-named? :value from-name [
				position/1: make-issue to-name
			]
			position: next position
		]
		code
	]

	protect-includes: func [code [block! paren!] restore? [logic!]][
		either restore? [
			replace-named-issues code include-marker-name include-name
			replace-named-issues code include-binary-marker-name include-binary-name
		][
			replace-named-issues code include-name include-marker-name
			replace-named-issues code include-binary-name include-binary-marker-name
		]
		code
	]

	restore-do-includes: func [
		code [block! paren!]
		/local position value path
	][
		; Host expand-directives rewrites #include %file -> do %file when not
		; Rebol/interpreted. Restore only those forms. Never convert intentional
		; DO of string! source (e.g. parse-test #3951: do "res: expand-...").
		position: head code
		while [not tail? position][
			value: position/1
			if any [block? :value paren? :value][restore-do-includes value]
			if all [
				word? :value
				(form value) = "do"
				not tail? next position
				file? position/2
			][
				path: position/2
				change/part position reduce [make-issue include-name path] 2
			]
			if all [
				path? :value
				(length? value) = 2
				(form value/1) = "read"
				(form value/2) = "binary"
				not tail? next position
				file? position/2
			][
				path: position/2
				change/part position reduce [make-issue include-binary-name path] 2
			]
			position: next position
		]
		code
	]

	set-global-rebol: func [value [logic!]][
		; Object-local assignment is not enough under compiled Red. Force the
		; word that expand-directives consults.
		set in system/words 'Rebol value
	]

	expand: func [
		code [block! paren!]
		job [object! none!]
		/clean
		/file file-name [file! string! none!]
		/local saved-config saved-path saved-rebol input result
	][
		last-error: none
		source-file: either file [file-name][none]
		saved-config: system/build/config
		saved-path: system/script/path
		saved-rebol: to logic! get in system/words 'Rebol
		system/build/config: job
		; Keep Rebol false on the Red host so expand uses PARSE WHILE (#3771).
		; #include is preserved via protect-includes markers, not via Rebol.
		set-global-rebol false
		if all [file file-name][
			system/script/path: first split-path to file! file-name
		]
		input: copy/deep code
		protect-includes input false
		set/any 'result try [
			either clean [
				expand-directives/clean/preserve-includes input
			][
				expand-directives/preserve-includes input
			]
		]
		set-global-rebol saved-rebol
		system/build/config: saved-config
		system/script/path: saved-path
		either error? :result [
			last-error: :result
			none
		][
			result: get/any 'result
			if any [block? :result paren? :result][
				protect-includes result true
			]
			:result
		]
	]
]
