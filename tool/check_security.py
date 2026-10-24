#!/usr/bin/env python3
"""Local policy check; optionally inspect a generated merged manifest.

Usage: python3 tool/check_security.py [--manifest PATH] [--release]
This checks configuration, not runtime TLS or SDK behavior.
"""
import argparse
from pathlib import Path
import plistlib
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = "{http://schemas.android.com/apk/res/android}"
TOOLS = "{http://schemas.android.com/tools}"


def check(manifest, release=False):
    errors = []
    tree = ET.parse(manifest).getroot()
    app = tree.find("application")
    for attribute in ("usesCleartextTraffic", "allowBackup", "fullBackupContent"):
        if app is None or app.get(ANDROID + attribute) != "false":
            errors.append(f"Expected {attribute}=false")
    if app is None or app.get(ANDROID + "dataExtractionRules") != "@xml/data_extraction_rules":
        errors.append("Missing data extraction policy")
    for permission in tree.findall("uses-permission"):
        name = permission.get(ANDROID + "name", "")
        if name in {"android.permission.RECORD_AUDIO", "android.permission.READ_EXTERNAL_STORAGE",
                    "android.permission.WRITE_EXTERNAL_STORAGE"} and permission.get(TOOLS + "node") != "remove":
            errors.append(f"Unexpected permission: {name}")
    if release and app is not None:
        if app.get(ANDROID + "debuggable", "false") != "false":
            errors.append("Release is debuggable")
        values = [m.get(ANDROID + "value", "") for m in app.findall("meta-data")
                  if m.get(ANDROID + "name") == "com.google.android.gms.ads.APPLICATION_ID"]
        if len(values) != 1 or not values[0].startswith("ca-app-pub-") or "3940256099942544" in values[0]:
            errors.append("Release AdMob app ID is missing or a sample")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path,
                        default=ROOT / "android/app/src/main/AndroidManifest.xml")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    errors = check(args.manifest, args.release)
    ios_path = ROOT / "ios/Runner/Info.plist"
    with ios_path.open("rb") as stream:
        ios = plistlib.load(stream)
    keys = [element.text for element in ET.parse(ios_path).getroot().find("dict").findall("key")]
    if len(keys) != len(set(keys)):
        errors.append("Duplicate iOS plist keys")
    if ios.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads", False):
        errors.append("iOS ATS allows arbitrary loads")
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    for name in tracked:
        path = Path(name)
        if path.suffix in {".jks", ".keystore", ".p12", ".p8", ".symbols", ".mobileprovision"} or path.name == "key.properties":
            errors.append(f"Private release material is tracked: {name}")
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print("PASS: manifest policy, iOS plist/ATS, tracked signing/symbol files")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
