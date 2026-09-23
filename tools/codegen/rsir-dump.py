#!/usr/bin/env python3
"""Read the structural RSIR a hybrid compile hands to the native code generator.

Every code generator failure prints a site id, a site name and the IR
coordinates of the instruction it rejected:

    *** codegen INVALID_IR site 236 (emit-control-operation/stack-kinds/depth#23)
        in x64-codegen.reds function=2541 instruction=1 op=11

`tools/codegen/sync-codegen-sites.py --locate 236` turns that into a source
line; this script turns the coordinates into the construct that was being
compiled. Both function and instruction ids are 1-based, so `function=2541`
is the row at index 2540 below. Dump the IR with `--dump-o2-ir <path>`:

    hybrid-compiler.exe -r -t MSDOS-X86-64 \
        --dump-o2-ir build/tmp/prog.ir -o build/tmp/prog.exe prog.red

usage:
    python tools/codegen/rsir-dump.py <file.ir>                 # header only
    python tools/codegen/rsir-dump.py <file.ir> 2540            # one function
    python tools/codegen/rsir-dump.py <file.ir> 2540:12         # first 12 ops
    python tools/codegen/rsir-dump.py <file.ir> /text-box       # find by name

The table order is the one `codegen-rsir-reader.reds` walks: types, members,
imports, globals, functions, exports, parameters, initializers, switches,
instructions, line records, file table, then the string blob. Note that the
parameter table starts with the *imports'* parameters, so a function's
first-parameter is never 0.
"""

import struct
import sys

OP = {
    1: 'LITERAL', 2: 'CONSTANT', 3: 'ADDRESS', 4: 'LOAD', 5: 'SET', 6: 'MEMBER',
    7: 'CALL', 8: 'CAST', 9: 'SIZE', 10: 'NATIVE', 11: 'RETURN', 12: 'DROP',
    13: 'DUPLICATE', 14: 'UNARY', 15: 'BINARY', 16: 'JUMP', 17: 'BRANCH',
    18: 'SWITCH', 19: 'FAIL', 20: 'REFERENCE', 21: 'INDEX', 22: 'TAG',
    23: 'OVERFLOW', 24: 'CATCH', 25: 'END_CATCH', 26: 'THROW', 27: 'ENTRY',
    28: 'SUB_CALL', 29: 'SUB_RETURN',
}

HEADER = ['module-kind', 'entry', 'type-count', 'import-count', 'function-count',
          'instruction-count', 'global-count', 'switch-count', 'export-count',
          'line-record-count', 'file-count']


class RSIR:
    def __init__(self, path):
        self.b = open(path, 'rb').read()
        b = self.b

        def i32(o):
            return struct.unpack_from('<i', b, o)[0]

        self.h = dict(zip(HEADER, [i32(4 * k) for k in range(len(HEADER))]))
        h = self.h

        members = 0
        for k in range(h['type-count']):
            kind, target, flags, first, count = struct.unpack_from('<5i', b, 44 + 20 * k)
            if kind != -7:
                members += count

        off = 44 + h['type-count'] * 20 + members * 8
        self.imports = off
        off += h['import-count'] * 32

        self.globals = off
        initializers = 0
        for k in range(h['global-count']):
            name, size, ty, flags, first, count = struct.unpack_from(
                '<6i', b, self.globals + 24 * k)
            initializers += count
        off += h['global-count'] * 24

        self.functions = off
        slots = 0
        for k in range(h['import-count']):
            lib, ls, ext, es, ty, flags, first, count = struct.unpack_from(
                '<8i', b, self.imports + 32 * k)
            slots += count

        self.starts = []
        instructions = 0
        for k in range(h['function-count']):
            (name, size, ret, flags, first, params,
             first_local, locals, count) = struct.unpack_from(
                '<9i', b, self.functions + 36 * k)
            assert first == slots, (k, first, slots)
            assert first_local == slots + params, (k, first_local, slots + params)
            self.starts.append(instructions)
            instructions += count
            slots += params + locals
        assert instructions == h['instruction-count'], (
            instructions, h['instruction-count'])
        off += h['function-count'] * 36

        self.exports = off
        off += h['export-count'] * 12
        self.parameters = off
        off += slots * 8
        self.initializers = off
        off += initializers * 16
        self.switches = off
        off += h['switch-count'] * 12
        self.instructions = off
        off += h['instruction-count'] * 16
        self.lines = off
        off += h['line-record-count'] * 16
        self.files = off
        off += h['file-count'] * 8
        self.strings = off

    def string(self, offset, size):
        return self.b[self.strings + offset:self.strings + offset + size].decode(
            'utf-8', 'replace')

    def meta(self, fid):
        (name, size, ret, flags, first, params,
         first_local, locals, count) = struct.unpack_from(
            '<9i', self.b, self.functions + 36 * fid)
        return dict(name=self.string(name, size), return_type=ret, flags=flags,
                    parameter_count=params, local_count=locals,
                    instruction_count=count)

    def name(self, fid):
        name, size = struct.unpack_from('<2i', self.b, self.functions + 36 * fid)
        return self.string(name, size)

    def instruction(self, index):
        return struct.unpack_from('<4i', self.b, self.instructions + 16 * index)

    def dump(self, fid, limit=40):
        f = self.meta(fid)
        print('--- fn %d (1-based %d) %r icnt=%d params=%d locals=%d ret=%d flags=%d'
              % (fid, fid + 1, f['name'], f['instruction_count'],
                 f['parameter_count'], f['local_count'], f['return_type'],
                 f['flags']))
        start = self.starts[fid]
        for j in range(min(limit, f['instruction_count'])):
            op, a, b, c = self.instruction(start + j)
            print('   %4d  %-11s a=%-8d b=%-8d c=%d' % (j + 1, OP.get(op, op), a, b, c))

    def find(self, substring):
        return [(k, self.name(k)) for k in range(self.h['function-count'])
                if substring in self.name(k)]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    ir = RSIR(sys.argv[1])
    print('header', ir.h)
    print('strings at', ir.strings, 'size', len(ir.b) - ir.strings)
    for arg in sys.argv[2:]:
        if arg.startswith('/'):
            for fid, name in ir.find(arg[1:]):
                print('  fn %d %s' % (fid, name))
        elif ':' in arg:
            fid, limit = arg.split(':')
            ir.dump(int(fid), int(limit))
        else:
            ir.dump(int(arg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
