#!/usr/bin/env python3

import argparse
import json
import platform
import resource
import subprocess
import sys
import time


class BenchmarkError(RuntimeError):
    pass


def decode_output(value):
    return value.decode("utf-8", errors="replace")


def run_program(program, arguments, timeout_seconds, stage):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started = time.perf_counter_ns()
    try:
        result = subprocess.run(
            [program["Path"]] + arguments,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds if timeout_seconds > 0 else None,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise BenchmarkError(
            "{} {} timed out after {} seconds".format(
                program["Optimization"], stage, timeout_seconds
            )
        ) from error
    elapsed = (time.perf_counter_ns() - started) / 1_000_000_000.0
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_seconds = (
        after.ru_utime
        + after.ru_stime
        - before.ru_utime
        - before.ru_stime
    )
    return {
        "ExitCode": result.returncode,
        "WallSeconds": elapsed,
        "CpuSeconds": cpu_seconds,
        "PeakWorkingSetBytes": None,
        "StdoutBytes": result.stdout,
        "StderrBytes": result.stderr,
    }


def assert_behavior(program, stage, measurement, request, expected):
    optimization = program["Optimization"]
    expected_exit_code = request["ExpectedExitCode"]
    if measurement["ExitCode"] != expected_exit_code:
        raise BenchmarkError(
            "{} {} exited with {}, expected {}".format(
                optimization,
                stage,
                measurement["ExitCode"],
                expected_exit_code,
            )
        )
    if expected is None:
        return
    if measurement["StdoutBytes"] != expected["StdoutBytes"]:
        raise BenchmarkError(
            "{} {} produced different stdout from {}".format(
                optimization, stage, expected["Optimization"]
            )
        )
    if measurement["StderrBytes"] != expected["StderrBytes"]:
        raise BenchmarkError(
            "{} {} produced different stderr from {}".format(
                optimization, stage, expected["Optimization"]
            )
        )


def run_benchmark(request):
    programs = request["Programs"]
    arguments = request["ProgramArguments"]
    timeout_seconds = request["ProgramTimeoutSeconds"]
    expected = None
    verification = []

    for program in programs:
        measurement = run_program(program, arguments, timeout_seconds, "verification")
        assert_behavior(program, "verification", measurement, request, expected)
        if expected is None:
            expected = {
                "Optimization": program["Optimization"],
                "StdoutBytes": measurement["StdoutBytes"],
                "StderrBytes": measurement["StderrBytes"],
            }
        verification.append(
            {
                "Optimization": program["Optimization"],
                "ExitCode": measurement["ExitCode"],
                "Stdout": decode_output(measurement["StdoutBytes"]),
                "Stderr": decode_output(measurement["StderrBytes"]),
            }
        )

    for warmup in range(1, request["Warmups"] + 1):
        for program in programs:
            stage = "warmup {}".format(warmup)
            measurement = run_program(program, arguments, timeout_seconds, stage)
            assert_behavior(program, stage, measurement, request, expected)

    samples = []
    for run in range(1, request["Runs"] + 1):
        offset = (run - 1) % len(programs)
        for position in range(len(programs)):
            program = programs[(offset + position) % len(programs)]
            stage = "sample {}".format(run)
            measurement = run_program(program, arguments, timeout_seconds, stage)
            assert_behavior(program, stage, measurement, request, expected)
            samples.append(
                {
                    "Run": run,
                    "Position": position + 1,
                    "Optimization": program["Optimization"],
                    "WallSeconds": measurement["WallSeconds"],
                    "CpuSeconds": measurement["CpuSeconds"],
                    "PeakWorkingSetBytes": measurement["PeakWorkingSetBytes"],
                }
            )

    return {
        "Runtime": {
            "Kind": "WSL",
            "Platform": platform.platform(),
            "Python": platform.python_version(),
        },
        "Verification": verification,
        "Samples": samples,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", required=True)
    arguments = parser.parse_args()
    try:
        with open(arguments.request, "r", encoding="utf-8") as request_file:
            request = json.load(request_file)
        if not request.get("Programs"):
            raise BenchmarkError("at least one program is required")
        json.dump(run_benchmark(request), sys.stdout, separators=(",", ":"))
        sys.stdout.write("\n")
        return 0
    except (BenchmarkError, OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
