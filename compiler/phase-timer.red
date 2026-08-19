Red [
	Title: "Red compiler phase timing"
	File:  %phase-timer.red
]

phase-timer: context [
	active?: false
	started: make map! 16
	records: make block! 48
	gc-records: make map! 16

	reset: does [
		clear started
		clear records
		clear gc-records
	]

	begin: func [name [word! string!] /local stack][
		if active? [
			stack: select started name
			either block? stack [
				repend stack [now/precise/utc system/state/GC/series-cycles]
			][
				put started name reduce [now/precise/utc system/state/GC/series-cycles]
			]
		]
	]

	finish: func [
		name [word! string!]
		/local stack start-time start-cycle end-time end-cycle duration record cycles
	][
		unless active? [return none]
		unless all [stack: select started name not empty? stack][
			make error! rejoin ["phase was not started: " mold name]
		]
		end-time: now/precise/utc
		end-cycle: system/state/GC/series-cycles
		start-cycle: take/last stack
		start-time: take/last stack
		duration: difference end-time start-time
		record: find/skip records name 3
		unless record [
			repend records [name 0 0:0:0]
			record: skip tail records -3
		]
		record/2: record/2 + 1
		record/3: record/3 + duration
		cycles: end-cycle - start-cycle
		unless zero? cycles [
			put gc-records name cycles + any [select gc-records name 0]
		]
		duration
	]

	balanced?: does [
		foreach [name stack] started [
			unless empty? stack [return no]
		]
		yes
	]

	snapshot: does [copy/deep records]
	gc-cycles: func [name [word! string!]][any [select gc-records name 0]]

	report: does [
		foreach [name count duration] records [
			print [
				"...profile phase   :" name
				"count:" count
				"time:" duration
				"gc-cycles:" gc-cycles name
			]
		]
	]
]
