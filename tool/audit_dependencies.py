#!/usr/bin/env python3
"""Query OSV using package names/versions only; no source or credentials sent.

Usage: python3 tool/audit_dependencies.py [--android-report /tmp/dependencies.txt]
An unavailable service is a failed audit, never a clean result. This does not
cover embedded native libraries, Apple pods, or unpublished advisories.
"""
import argparse
import json
from pathlib import Path
import re
import sys
from urllib.request import Request, urlopen


def packages(lock, native_report=None):
    found = set()
    for match in re.finditer(r"^  ([\w]+):\n(.*?)(?=^  [\w]+:|\Z)", lock, re.M | re.S):
        name, block = match.groups()
        version = re.search(r'^    version: "([^"]+)"', block, re.M)
        if "source: hosted" in block and version:
            found.add(("Pub", name, version.group(1)))
    if not found:
        raise ValueError("No hosted packages found in pubspec.lock")
    if native_report is not None:
        native = set()
        for line in native_report.splitlines():
            if "FAILED" in line:
                raise ValueError("Android dependency resolution failed")
            match = re.search(r"[+\\]--- ([\w.-]+):([\w.-]+)(?::(\{[^}]+\}|[^\s]+))?(?: -> ([^\s]+))?", line)
            if not match:
                continue
            group, name, version, selected = match.groups()
            if selected:
                if ":" in selected:
                    group, name, version = selected.split(":", 2)
                else:
                    version = selected
            if version is None or not re.fullmatch(r"\d[\w.+-]*", version):
                raise ValueError("Unresolved Android version constraint")
            native.add(("Maven", f"{group}:{name}", version))
        if not native:
            raise ValueError("No resolved Android packages found")
        found.update(native)
    return sorted(found)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        inventory = packages(
            (root / "pubspec.lock").read_text(),
            args.android_report.read_text() if args.android_report else None,
        )
        findings = []
        for offset in range(0, len(inventory), 100):
            batch = inventory[offset:offset + 100]
            payload = {"queries": [
                {"package": {"ecosystem": ecosystem, "name": name}, "version": version}
                for ecosystem, name, version in batch
            ]}
            request = Request("https://api.osv.dev/v1/querybatch",
                              data=json.dumps(payload).encode(),
                              headers={"Content-Type": "application/json"})
            with urlopen(request, timeout=30) as response:
                results = json.load(response)["results"]
            if len(results) != len(batch):
                raise ValueError("Incomplete OSV response")
            for package, result in zip(batch, results):
                ids = [v["id"] for v in result.get("vulns", [])]
                if ids:
                    findings.append({"package": package, "advisories": ids})
        print(json.dumps({"packages_checked": len(inventory), "findings": findings}, indent=2))
        return 1 if findings else 0
    except Exception as error:
        # Do not dump response bodies or request data into CI logs.
        print(f"Dependency audit unavailable: {type(error).__name__}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
