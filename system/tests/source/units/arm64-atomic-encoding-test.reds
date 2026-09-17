Red/System [Title: "ARM64 LSE and exclusive atomic encodings"]

#include %../../../codegen/arm64-encoder.reds
#include %../../../../quick-test/quick-test.reds

~~~start-file~~~ "ARM64 atomic encodings"

buffer: allocate 32
words: as int-ptr! buffer

--test-- "LSE read-modify-write remains one instruction"
	--assert 4 = arm64-encoder/atomic-rmw buffer 32 arm64-encoder/OP_ADD 17 9 16
	--assert words/1 = B8F10209h
	--assert 4 = arm64-encoder/atomic-rmw buffer 32 arm64-encoder/OP_AND 17 9 16
	--assert words/1 = B8F11209h
	--assert 4 = arm64-encoder/atomic-rmw buffer 32 arm64-encoder/OP_XOR 17 9 16
	--assert words/1 = B8F12209h
	--assert 4 = arm64-encoder/atomic-rmw buffer 32 arm64-encoder/OP_OR 17 9 16
	--assert words/1 = B8F13209h

--test-- "LSE compare-and-exchange remains one instruction"
	--assert 4 = arm64-encoder/atomic-compare-exchange buffer 32 9 11 16
	--assert words/1 = 88E9FE0Bh

--test-- "Exclusive add retry loop"
	--assert 16 = arm64-encoder/atomic-rmw-exclusive buffer 32 arm64-encoder/OP_ADD 17 9 16 0 1
	--assert words/1 = 885FFE09h
	--assert words/2 = 0B110120h
	--assert words/3 = 8801FE00h
	--assert words/4 = 35FFFFA1h
	--assert 16 = arm64-encoder/atomic-rmw-exclusive null 0 arm64-encoder/OP_ADD 17 9 16 0 1
	--assert -1 = arm64-encoder/atomic-rmw-exclusive buffer 15 arm64-encoder/OP_ADD 17 9 16 0 1
	--assert -1 = arm64-encoder/atomic-rmw-exclusive buffer 32 arm64-encoder/OP_ADD 17 9 16 0 0

--test-- "Exclusive bitwise update preserves the LSE operand convention"
	--assert 16 = arm64-encoder/atomic-rmw-exclusive buffer 32 arm64-encoder/OP_AND 17 9 16 0 1
	--assert words/2 = 0A310120h
	--assert 16 = arm64-encoder/atomic-rmw-exclusive buffer 32 arm64-encoder/OP_XOR 17 9 16 0 1
	--assert words/2 = 4A110120h
	--assert 16 = arm64-encoder/atomic-rmw-exclusive buffer 32 arm64-encoder/OP_OR 17 9 16 0 1
	--assert words/2 = 2A110120h

--test-- "Exclusive compare-and-exchange retries stores and clears mismatches"
	--assert 32 = arm64-encoder/atomic-compare-exchange-exclusive buffer 32 9 11 16 10
	--assert words/1 = 885FFE0Ah
	--assert words/2 = 6B09015Fh
	--assert words/3 = 54000081h
	--assert words/4 = 880AFE0Bh
	--assert words/5 = 35FFFF8Ah
	--assert words/6 = 14000003h
	--assert words/7 = D5033F5Fh
	--assert words/8 = 2A0A03E9h
	--assert 32 = arm64-encoder/atomic-compare-exchange-exclusive null 0 9 11 16 10
	--assert -1 = arm64-encoder/atomic-compare-exchange-exclusive buffer 31 9 11 16 10
	--assert -1 = arm64-encoder/atomic-compare-exchange-exclusive buffer 32 9 11 16 9

free buffer
~~~end-file~~~
