Red [
	Title: "Large-source TRANSCODE/TRACE stress probe"
	File:  %transcode-trace-stress.red
]

#include %../../compiler/lexer.red

path-at: func [base [file!] relative [file!]][
	clean-path append copy base relative
]

root-dir: either exists? path-at system/options/path %system/tests/ [
	system/options/path
][
	path-at system/options/path %../../
]
source-file: path-at root-dir %system/tests/source/units/math-mixed-test.reds
source: read/binary source-file
mode: any [pick system/options/args 1 "lexer"]
iterations: to integer! any [pick system/options/args 2 "1"]
events: 0
retained: make block! 350000
records: make block! 70000
result: none
pending-start: pending-end: 0

trace-count: func [
	event [word!]
	input [binary! string!]
	type [word! datatype!]
	line [integer!]
	token
	return: [logic!]
][
	events: events + 1
	true
]

trace-retain: func [
	event [word!]
	input [binary! string!]
	type [word! datatype!]
	line [integer!]
	token
	return: [logic!]
][
	events: events + 1
	append retained event
	append retained type
	append retained line
	append/only retained :token
	true
]

trace-objects: func [
	event [word!]
	input [binary! string!]
	type [word! datatype!]
	line [integer!]
	token
	return: [logic!]
	/local record
][
	events: events + 1
	if find [load open close error] event [
		record: make object! [
			event: none
			type: none
			value: none
			line: 0
			start: 0
			end: 0
			raw: none
		]
		record/event: event
		record/type: type
		set/any in record 'value :token
		record/line: line
		append/only records record
	]
	true
]

trace-raw: func [
	event [word!]
	input [binary! string!]
	type [word! datatype!]
	line [integer!]
	token
	return: [logic!]
][
	events: events + 1
	if all [event = 'scan pair? token][
		pending-start: token/x
		pending-end: token/y
	]
	if all [event = 'load pending-start > 0 pending-end >= pending-start][
		append/only records copy/part at source pending-start pending-end - pending-start
	]
	true
]

repeat iteration iterations [
	events: 0
	clear retained
	clear records
	set/any 'result try [
		switch/default mode [
			"count" [transcode/trace source :trace-count]
			"retain" [transcode/trace source :trace-retain]
			"objects" [transcode/trace source :trace-objects]
			"raw" [transcode/trace source :trace-raw]
			"lexer" [compiler-lexer/process/file source source-file]
		][cause-error 'script 'invalid-arg reduce [mode]]
	]
	if any [error? :result all [mode = "lexer" compiler-lexer/last-error]][
		print [
			"FAIL" mode "iteration" iteration "events" events
			"retained" length? retained
		]
		print either error? :result [mold :result][mold compiler-lexer/last-error]
		quit/return 1
	]
	print [
		"PASS" mode "iteration" iteration "events" events
		"retained" length? retained
		"records" length? records
		"values" length? result
		either mode = "lexer" [rejoin ["tokens " length? compiler-lexer/tokens]][""]
	]
]

quit/return 0
