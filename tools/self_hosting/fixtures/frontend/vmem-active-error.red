Red [
	Title: "Virtual memory active-error preservation probe"
]

vmem-preserves-active-error?: routine [
	return: [logic!]
	/local
		ptr [int-ptr!]
		allocation-preserved? [logic!]
		release-preserved? [logic!]
][
	system/thrown: RED_THROWN_ERROR
	ptr: allocate-virtual 1 no
	allocation-preserved?: system/thrown = RED_THROWN_ERROR

	system/thrown: RED_THROWN_ERROR
	free-virtual ptr
	release-preserved?: system/thrown = RED_THROWN_ERROR
	system/thrown: 0

	allocation-preserved? and release-preserved?
]

quit/return either vmem-preserves-active-error? [0][1]
