Red [
	Title: "Red compiler version"
	File:  %compiler/version.red
]

compiler-version: 0.6.6
; Stage1 cannot encode date! literals, so the macro emits stable source spelling.
compiler-build-date: load #do keep [
	mold (apply func [/local text epoch days seconds][
		text: get-env "SOURCE_DATE_EPOCH"
		either text [
			epoch: attempt [to float! text]
			unless all [
				float? epoch
				epoch >= 0.0
				epoch = round/down epoch
			][
				do make error! "SOURCE_DATE_EPOCH must be a non-negative integer"
			]
			days: to integer! (epoch / 86400.0)
			seconds: to integer! (epoch - (days * 86400.0))
			(1-Jan-1970 + days) + (to time! seconds)
		][now/utc]
	] [])
]
