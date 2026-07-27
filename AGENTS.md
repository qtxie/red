- compile Windows x64 Red/Red/System in release mode: `build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d -t Windows-X86-64 -o output_path_name input_file_path`
- compile in development mode: omit `-r` and keep the Stage1-built `libRedRT.dll` beside the output executable
- the Rebol Stage0 compiler is retired from normal work; do not invoke `red.r` through `rebcmdview.exe` unless the user explicitly requests a recovery or historical audit
- run/interpret Red script: `D:\EE\QTool\red-console.exe red-script-path.red` for quick testing without waiting a long time to compile it.
- Be careful when you using red-console.exe, sometime it does not exit properly and keep burning cpu
- dumpbin: C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\dumpbin.exe
- cdb: C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe

# Red/System Idiomatic Patterns - Key Insights

## Reference
https://static.red-lang.org/red-system-specs.html

## ⚠️ CRITICAL UNUSUAL FEATURES (Different from C-like languages!)

### NO OPERATOR PRECEDENCE!
- `1 + 2 * 3` = `(1 + 2) * 3` = 9, NOT `1 + (2 * 3)` = 7
- ALWAYS use parentheses for intended grouping: `a < b and (c > d)`
- Exception: infix functions have precedence over prefix calls

**Key Gotchas:**
- `case` requires a `true` catch-all or **runtime error** if no match
- `switch` values must be **literal** integer!/byte! (not expressions)
- Neither has fall-through between cases
- Both can return values if all branches return same type
- No `else` keyword, use `either`
- (expr)/index, array/(idx) are invalid

## Critical Language Semantics

### 1. Integer Type (Only Signed!)
- **Only one integer type**: `integer!` is 32-bit signed (-2147483648 to 2147483647)
- **NO unsigned integer types exist** in Red/System
- **Hexadecimal literals use SUFFIX 'h', NOT 0x prefix!**
  - Correct: `9E3779B1h` or `04D2h`
  - WRONG: `0x9E3779B1` (this syntax does NOT exist!)
- Hex letters MUST be uppercase
- Only 2, 4, or 8 hex characters allowed
- `9E3779B1h` = -1640531535 in signed representation

### 2. Pointer Arithmetic
- **Pointer + integer** scales by the pointed type size
  - `int-ptr! + 1` adds 4 bytes (sizeof integer)
  - `byte-ptr! + 1` adds 1 byte
- **Array indexing is 1-based** (not 0-based like C)
- Pointer/pointer arithmetic treats both as byte pointers

### 3. Struct Layout
- Members are **automatically padded for alignment**
- Padding is target-dependent (4-byte for IA-32)
- `size?` returns size including padding

### 4. Type Conversions
- `as` keyword for compatible type conversions
- Integer to byte! truncates values above 255
- No sign extension on truncation
