Red/System [Title: "system loader fixture"]

#define VALUE 10
#define ADD(left right) [left + right]
#include %child.reds
#if OS = 'Windows [platform: VALUE]
#either debug? = yes [debug-value: 1] [debug-value: 0]
#switch OS [Windows [switch-value: 1] #default [switch-value: 2]]
#case [debug? = yes [case-value: 1] true [case-value: 2]]
wide-value: 18446744073709551615
macro-value: ADD(2 3)
nested: [VALUE]
