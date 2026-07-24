Red [
	Title: "Red/System source locations and diagnostics"
	File:  %compiler/system-diagnostics.red
]

compiler-system-diagnostics: context [
	cache-source: none
	cache-marker: none
	cache-index: 0
	cache-line: 1
	last-error: none

	reset: does [
		cache-source: none
		cache-marker: none
		cache-index: 0
		cache-line: 1
		last-error: none
		self
	]

	metadata-of: func [position [block! paren!] /local root metadata][
		root: head position
		case [
			integer? root/1 [root]
			block? root/1 [
				metadata: root/1
				all [not empty? metadata integer? metadata/1 metadata]
			]
			true [none]
		]
	]

	visible-index-of: func [position [block! paren!] /local metadata][
		metadata: metadata-of position
		(index? position) - either same? metadata head position [metadata/1][1]
	]

	line-of: func [position [block! paren!] /local metadata index marker cursor previous][
		metadata: metadata-of position
		unless metadata [return 1]
		index: visible-index-of position
		either all [
			same? metadata cache-source
			cache-marker
			index >= cache-index
		][
			cursor: cache-marker
			previous: cache-line
		][
			cache-source: metadata
			cache-marker: none
			cache-index: 0
			cache-line: 1
			cursor: next metadata
			previous: 1
		]
		while [not tail? cursor][
			marker: cursor/1
			unless pair? marker [break]
			if marker/2 = index [
				cache-marker: cursor
				cache-index: marker/2
				cache-line: marker/1
				return marker/1
			]
			if marker/2 > index [return previous]
			cache-marker: cursor
			cache-index: marker/2
			cache-line: previous: marker/1
			cursor: next cursor
		]
		previous
	]

	location: func [
		position [block! paren!]
		file [file! string! none!]
		/local record
	][
		record: make object! [
			file: none
			line: 1
			index: 0
		]
		record/file: file
		record/line: line-of position
		record/index: visible-index-of position
		record
	]

	error-at: func [
		message [word! string!]
		position [block! paren! none!]
		file [file! string! none!]
		/at-function function-name [word! none!]
		/local record
	][
		record: make object! [
			message: none
			file: none
			line: none
			function-name: none
			near: none
		]
		record/message: either word? message [form message][message]
		record/file: file
		record/function-name: either at-function [function-name][none]
		if position [
			record/line: line-of position
			record/near: copy/part position min 8 length? position
		]
		last-error: record
		record
	]
]
