Red/System [Title: "x64 bitmap prologue encoding"]

#include %../../../codegen/x64-encoder.reds

buffer: allocate 32
encoded: x64-encoder/prolog buffer 32 01234567h 0
value: as int-ptr! (buffer + x64-encoder/BITMAP_OFFSET)
print ["bitmap-index=" value/value " prologue-bytes=" encoded lf]
assert encoded = 15
assert value/value = 01234567h
assert buffer/9 = as byte! 68h
encoded: x64-encoder/prolog buffer 32 0 0
assert value/value = 0
free buffer
print ["bitmap prologue encoding: PASS" lf]
