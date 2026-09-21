import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("codegen_sites", Path(__file__).with_name("sync-codegen-sites.py"))
sites = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = sites
spec.loader.exec_module(sites)


class SiteAuditTests(unittest.TestCase):
    def scan(self, body):
        scanner = sites.FileSites("arm64", Path("example.reds"))
        scanner.source = 'Red/System []\nf: func [][\n' + body + '\n]\n'
        return scanner

    def test_literals_and_comments_are_not_failures(self):
        scanner = self.scan('; return INVALID_IR\n"UNSUPPORTED ^"OUTPUT_FULL^""\n'
                            '{nested {INVALID_IR}} #{AABB} #"^""')
        self.assertEqual(scanner.problems(), ([], 0))

    def test_expression_cleanup_and_assignment_are_audited(self):
        scanner = self.scan('either ok? [0][INVALID_IR]\n'
                            'return release memory UNSUPPORTED\nstatus: OUTPUT_FULL')
        self.assertEqual(len(scanner.scan()[1]), 3)

    def test_multiple_sites_and_multiline_calls(self):
        scanner = self.scan('if a [return fail-invalid 1 "a"] if b [fail-invalid 2 "b"]\n'
                            'return release memory fail-code\n result 3 "c"\n'
                            'fail-output needed capacity 4 "d"')
        self.assertEqual(scanner.problems(), ([], 4))

    def test_duplicate_ids_and_names(self):
        scanner = self.scan('fail-invalid 1 "same"\nfail-unsupported 1 "same"')
        self.assertEqual(len(scanner.problems()[0]), 2)

    def test_write_preserves_existing_sites_and_is_idempotent(self):
        scanner = self.scan('fail-invalid 9 "original"\nfail-invalid 9 "original"\n'
                            'return release memory INVALID_IR\nfail-code result 0 "auto"')
        with tempfile.TemporaryDirectory() as directory:
            scanner.path = Path(directory) / "example.reds"
            scanner.annotate()
            annotated, bare = scanner.scan()
            self.assertEqual((annotated[0]["id"], annotated[0]["name"]), (9, "original"))
            self.assertEqual(len(annotated), 4)
            self.assertEqual(bare, [])
            self.assertEqual(scanner.problems(), ([], 4))
            self.assertEqual(scanner.annotate(), 0)

    def test_output_capacity_needs_explicit_sizes(self):
        scanner = self.scan('return OUTPUT_FULL')
        self.assertEqual(scanner.annotate(), 0)
        self.assertEqual(len(scanner.problems()[0]), 1)

    def test_missing_helper_arguments_fail_audit(self):
        self.assertEqual(len(self.scan('return fail-code result').problems()[0]), 1)


if __name__ == "__main__":
    unittest.main()
