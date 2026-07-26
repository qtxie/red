import sys
import textwrap
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.self_hosting import selfhost


class InventoryTests(unittest.TestCase):
    def test_classification_and_api_scan(self):
        path = Path("encapper/compiler.r")
        text = "REBOL []\ndo-cache %compiler.cache\n"

        self.assertEqual(
            selfhost._classify(path, text),
            "compiler-frontend",
        )
        self.assertEqual(selfhost._scan_api_usage(text), ["do-cache"])

    def test_text_normalization_is_stable(self):
        value = "a\r\n<ROOT>\r\n...compilation time : 42 ms\r\n"
        normalized = selfhost._normalize_text(
            value,
            {"<ROOT>": "<ROOT>"},
        )
        self.assertEqual(normalized, "a\n<ROOT>\n...compilation time : <DURATION>\n")

    def test_pe_normalization_changes_only_timestamp_and_checksum(self):
        left = bytearray(256)
        left[:2] = b"MZ"
        left[60:64] = (128).to_bytes(4, "little")
        left[128:132] = b"PE\0\0"
        left[136:140] = (10).to_bytes(4, "little")
        left[216:220] = (20).to_bytes(4, "little")
        right = bytearray(left)
        right[136:140] = (11).to_bytes(4, "little")
        right[216:220] = (21).to_bytes(4, "little")

        left_normalized, fields = selfhost._normalize_pe(bytes(left))
        right_normalized, _ = selfhost._normalize_pe(bytes(right))

        self.assertEqual(fields, ["pe.coff_timestamp", "pe.checksum"])
        self.assertEqual(left_normalized, right_normalized)

    def test_manifest_audit_rejects_rebol_in_direct_closure(self):
        errors = selfhost._manifest_errors(
            {
                "sources": [],
                "target_registry": {},
                "entrypoint_rebol_dependencies": {
                    "red-selfhost.red": ["legacy/compiler.r"]
                },
            }
        )
        self.assertEqual(
            errors,
            ["direct Red entrypoint has Rebol dependencies: legacy/compiler.r"],
        )

    def test_target_parser_keeps_nested_options_and_defaults_cpu(self):
        targets = selfhost._parse_target_blocks(
            "One [\n\tOS: 'Linux\n\tPIC?: yes\n\tPIE?: no\n\tlegacy: [stat32]\n]\n"
        )
        self.assertEqual(
            targets,
            [
                (
                    "One",
                    [
                        ("OS", "Linux"),
                        ("PIC?", "#(true)"),
                        ("PIE?", "#(false)"),
                        ("legacy", "[stat32]"),
                    ],
                )
            ],
        )


class DifferentialTests(unittest.TestCase):
    def _make_fake_compiler(self, directory: Path, suffix: str = "") -> Path:
        script = directory / ("fake_compiler" + suffix + ".py")
        script.write_text(
            textwrap.dedent(
                """
                from pathlib import Path
                import sys

                source = Path(sys.argv[1])
                output = Path(sys.argv[2])
                output.write_bytes(source.read_bytes().upper())
                print(f"compiled {source} -> {output}")
                """
            ),
            encoding="utf-8",
        )
        return script

    def test_identical_commands_compare_cleanly_and_preserve_artifacts(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "input.reds"
            source.write_text("Red/System []\nprint 1\n", encoding="utf-8")
            compiler = self._make_fake_compiler(directory)
            command = [sys.executable, str(compiler), "{source}", "{output}.bin"]
            report = selfhost.run_differential(
                {
                    "left": {"command": command},
                    "right": {"command": command},
                    "cases": [{"id": "basic", "source": source.name}],
                },
                directory,
                directory / "runs",
            )

            self.assertEqual(report["differences"], [])
            case = report["cases"][0]
            self.assertEqual(case["left"]["status"], "success")
            self.assertEqual(case["right"]["status"], "success")
            self.assertTrue((directory / "runs/basic/left/output.bin").is_file())
            self.assertTrue((directory / "runs/basic/right/output.bin").is_file())

    def test_artifact_difference_is_reported(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "input.reds"
            source.write_text("hello\n", encoding="utf-8")
            left_compiler = self._make_fake_compiler(directory, "_left")
            right_compiler = directory / "fake_compiler_right.py"
            right_compiler.write_text(
                textwrap.dedent(
                    """
                    from pathlib import Path
                    import sys

                    source = Path(sys.argv[1])
                    output = Path(sys.argv[2])
                    output.write_bytes(source.read_bytes() + b"!")
                    print(f"compiled {source} -> {output}")
                    """
                ),
                encoding="utf-8",
            )
            report = selfhost.run_differential(
                {
                    "left": {
                        "command": [sys.executable, str(left_compiler), "{source}", "{output}.bin"]
                    },
                    "right": {
                        "command": [sys.executable, str(right_compiler), "{source}", "{output}.bin"]
                    },
                    "cases": [{"id": "different", "source": source.name}],
                },
                directory,
                directory / "runs",
            )

            self.assertEqual(report["differences"], [{"id": "different", "fields": ["artifacts"]}])

    def test_stdout_can_be_ignored_without_ignoring_artifacts(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "input.reds"
            source.write_text("hello\n", encoding="utf-8")
            left_compiler = self._make_fake_compiler(directory, "_left")
            right_compiler = self._make_fake_compiler(directory, "_right")
            right_text = right_compiler.read_text(encoding="utf-8")
            right_compiler.write_text(
                right_text.replace("compiled {source}", "translated {source}"),
                encoding="utf-8",
            )
            report = selfhost.run_differential(
                {
                    "compare": {"stdout": False},
                    "left": {
                        "command": [
                            sys.executable,
                            str(left_compiler),
                            "{source}",
                            "{output}.bin",
                        ]
                    },
                    "right": {
                        "command": [
                            sys.executable,
                            str(right_compiler),
                            "{source}",
                            "{output}.bin",
                        ]
                    },
                    "cases": [{"id": "quiet", "source": source.name}],
                },
                directory,
                directory / "runs",
            )

            self.assertEqual(report["differences"], [])
            for side in ("left", "right"):
                self.assertEqual(
                    [item["path"] for item in report["cases"][0][side]["artifacts"]],
                    ["output.bin"],
                )


if __name__ == "__main__":
    unittest.main()
