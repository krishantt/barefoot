#!/usr/bin/env python3
"""Generate an AltStore PAL source.json from a built .app.

    python3 scripts/make_altstore_source.py build/Build/Products/Release-iphoneos/Barefoot.app \
        --adp-url https://example.com/barefoot/adp

AltStore checks appPermissions against the installed IPA and refuses to install
on any mismatch, so entitlements and usage strings are read from the build
itself rather than typed by hand.
"""
import argparse
import datetime
import json
import pathlib
import plistlib
import subprocess
import sys

# AltStore ignores these; get-task-allow is a debug artefact absent from a
# distribution build.
IGNORED = {
    "application-identifier",
    "com.apple.developer.team-identifier",
    "get-task-allow",
}

REPO = "https://raw.githubusercontent.com/krishantt/barefoot/main"


def read_plist(path):
    with open(path, "rb") as f:
        return plistlib.load(f)


def entitlements(app):
    out = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        capture_output=True,
    ).stdout
    return plistlib.loads(out) if out.strip() else {}


def adp_size(adp_dir):
    variants = sorted(pathlib.Path(adp_dir).glob("**/variant/*.ipa"))
    if not variants:
        return None
    return min(v.stat().st_size for v in variants)


def build(app, adp_url, size, marketing_id):
    info = read_plist(app / "Info.plist")
    ents = [k for k in entitlements(app) if k not in IGNORED]
    privacy = {k: v for k, v in info.items() if k.endswith("UsageDescription")}

    return {
        "name": "Barefoot",
        "subtitle": "Ad-free weight sync for Chipsea/OKOK Bluetooth scales",
        "description": (
            "Reads your Bluetooth scale's weight and saves it to Apple Health. "
            "No account, no ads, no analytics, no network access."
        ),
        "iconURL": f"{REPO}/Barefoot/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "website": "https://github.com/krishantt/barefoot",
        "tintColor": "#15917F",
        "nsfw": False,
        "featuredApps": [info["CFBundleIdentifier"]],
        "apps": [
            {
                "name": "Barefoot",
                "bundleIdentifier": info["CFBundleIdentifier"],
                "marketplaceID": marketing_id,
                "developerName": "Krishant Timilsina",
                "subtitle": "No ads, no account, just your weight in Health.",
                "localizedDescription": (
                    "Barefoot listens for scales that broadcast their weight "
                    "(Chipsea / OKOK chipset) and writes the settled reading to "
                    "Apple Health.\n\nNo account, no advertising, no analytics, "
                    "no network access."
                ),
                "iconURL": f"{REPO}/Barefoot/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
                "tintColor": "#15917F",
                "category": "utilities",
                "screenshots": [
                    f"{REPO}/docs/screenshots/reading.png",
                    f"{REPO}/docs/screenshots/saved.png",
                ],
                "versions": [
                    {
                        "version": info["CFBundleShortVersionString"],
                        "buildVersion": info["CFBundleVersion"],
                        "date": datetime.date.today().isoformat(),
                        "localizedDescription": "First release.",
                        "downloadURL": adp_url,
                        "size": size,
                        "minOSVersion": info["MinimumOSVersion"],
                    }
                ],
                "appPermissions": {"entitlements": ents, "privacy": privacy},
            }
        ],
        "news": [],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("app", type=pathlib.Path, help="path to the built .app")
    ap.add_argument("--adp-url", required=True,
                    help="public URL of the ADP root or its manifest.json")
    ap.add_argument("--adp-dir", help="downloaded ADP, to read the size from")
    ap.add_argument("--size", type=int, help="override size in bytes")
    ap.add_argument("--marketing-id", default="",
                    help="app's Apple ID from App Store Connect (marketplaceID)")
    ap.add_argument("--out", type=pathlib.Path, default=pathlib.Path("altstore/source.json"))
    args = ap.parse_args()

    if not (args.app / "Info.plist").exists():
        sys.exit(f"no Info.plist in {args.app}")

    size = args.size or (adp_size(args.adp_dir) if args.adp_dir else None)
    if not size:
        sys.exit("need --size or --adp-dir to know the download size")
    if not args.marketing_id:
        sys.exit("--marketing-id is required for PAL (App Store Connect -> App Information)")

    source = build(args.app, args.adp_url, size, args.marketing_id)

    app = source["apps"][0]
    missing = [k for k in ("bundleIdentifier", "marketplaceID", "versions")
               if not app.get(k)]
    assert not missing, f"incomplete app entry: {missing}"
    assert app["appPermissions"]["entitlements"], "entitlements must be declared"
    assert app["appPermissions"]["privacy"], "privacy strings must be declared"

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(source, indent=2) + "\n")
    print(f"wrote {args.out}")
    print(f"  {app['bundleIdentifier']} {app['versions'][0]['version']} "
          f"({app['versions'][0]['buildVersion']}), {size} bytes")
    print(f"  entitlements: {', '.join(app['appPermissions']['entitlements'])}")
    print(f"  privacy: {', '.join(app['appPermissions']['privacy'])}")


if __name__ == "__main__":
    main()
