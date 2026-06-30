#!/usr/bin/env python3
import argparse
import datetime as dt
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd, cwd=None):
    p = subprocess.run(cmd, cwd=cwd, text=True)
    if p.returncode != 0:
        raise SystemExit(p.returncode)


def which(name: str):
    return shutil.which(name)


def find_first_info_plist(project_root: Path) -> Path | None:
    candidates = []
    for p in project_root.rglob("Info.plist"):
        s = str(p)
        if "/DerivedData/" in s or "/Pods/" in s or "/Carthage/" in s:
            continue
        candidates.append(p)
    return candidates[0] if candidates else None


def read_bundle_versions(info_plist: Path):
    with info_plist.open("rb") as f:
        d = plistlib.load(f)
    ver = str(d.get("CFBundleShortVersionString", "0.0.0"))
    build = str(d.get("CFBundleVersion", "0"))
    return ver, build


def safe_name(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", s).strip("-")


def zip_dir(src_dir: Path, out_zip: Path):
    if out_zip.exists():
        out_zip.unlink()
    base = str(out_zip).removesuffix(".zip")
    shutil.make_archive(base, "zip", root_dir=str(src_dir.parent), base_dir=str(src_dir.name))
    return out_zip


def optimize_assets(asset_root: Path):
    pngquant = which("pngquant")
    jpegoptim = which("jpegoptim")

    pngs = list(asset_root.rglob("*.png"))
    jpgs = list(asset_root.rglob("*.jpg")) + list(asset_root.rglob("*.jpeg"))

    if not pngquant and not jpegoptim:
        print("asset optimize: skipped (pngquant/jpegoptim not found)", file=sys.stderr)
        return

    if pngquant:
        for p in pngs:
            run([pngquant, "--force", "--ext", ".png", "--quality", "60-85", str(p)])
        print(f"asset optimize: pngquant optimized {len(pngs)} png files")

    if jpegoptim:
        for p in jpgs:
            run([jpegoptim, "--strip-all", "--max=85", str(p)])
        print(f"asset optimize: jpegoptim optimized {len(jpgs)} jpg/jpeg files")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", help="path to .xcodeproj", default=None)
    ap.add_argument("--workspace", help="path to .xcworkspace", default=None)
    ap.add_argument("--scheme", required=True)
    ap.add_argument("--configuration", default="Release")
    ap.add_argument("--sdk", default=None, help="iphoneos / iphonesimulator (optional)")
    ap.add_argument("--archive", action="store_true", help="build archive (.xcarchive)")
    ap.add_argument("--export-options", default=None, help="ExportOptions.plist path (needed for ipa export)")
    ap.add_argument("--output", default="build_out")
    ap.add_argument("--info-plist", default=None, help="Info.plist path for versioning (optional)")
    ap.add_argument("--rename", action="store_true", help="rename artifacts with version/build/timestamp")
    ap.add_argument("--zip", action="store_true", help="zip the exported folder/app if no ipa available")
    ap.add_argument("--optimize-assets", action="store_true", help="optimize assets in-place (requires pngquant/jpegoptim)")
    ap.add_argument("--assets-dir", default=None, help="asset root dir to optimize (optional)")
    args = ap.parse_args()

    if not args.project and not args.workspace:
        raise SystemExit("require --project or --workspace")

    root = Path.cwd()
    out_dir = (root / args.output).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.optimize_assets:
        if not args.assets_dir:
            raise SystemExit("--optimize-assets requires --assets-dir")
        optimize_assets(Path(args.assets_dir).resolve())

    info_plist = Path(args.info_plist).resolve() if args.info_plist else find_first_info_plist(root)
    ver, build = ("0.0.0", "0")
    if info_plist and info_plist.exists():
        ver, build = read_bundle_versions(info_plist)

    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    tag = safe_name(f"{args.scheme}_v{ver}_b{build}_{ts}")

    build_base = [
        "xcodebuild",
        "-scheme",
        args.scheme,
        "-configuration",
        args.configuration,
    ]
    if args.workspace:
        build_base += ["-workspace", args.workspace]
    else:
        build_base += ["-project", args.project]

    if args.sdk:
        build_base += ["-sdk", args.sdk]

    artifacts = []

    if args.archive:
        archive_path = out_dir / f"{tag}.xcarchive"
        cmd = build_base + ["-archivePath", str(archive_path), "archive"]
        run(cmd)
        artifacts.append(archive_path)

        if args.export_options:
            export_dir = out_dir / f"{tag}_export"
            export_dir.mkdir(parents=True, exist_ok=True)
            cmd = [
                "xcodebuild",
                "-exportArchive",
                "-archivePath",
                str(archive_path),
                "-exportPath",
                str(export_dir),
                "-exportOptionsPlist",
                str(Path(args.export_options).resolve()),
            ]
            run(cmd)
            artifacts.append(export_dir)

            ipa = next(export_dir.glob("*.ipa"), None)
            if ipa:
                if args.rename:
                    dst = out_dir / f"{tag}.ipa"
                    if dst.exists():
                        dst.unlink()
                    ipa.replace(dst)
                    artifacts.append(dst)
                else:
                    artifacts.append(ipa)
    else:
        build_dir = out_dir / f"{tag}_build"
        cmd = build_base + ["-derivedDataPath", str(build_dir), "build"]
        run(cmd)
        artifacts.append(build_dir)

    if args.zip:
        for a in list(artifacts):
            if a.is_dir():
                z = out_dir / f"{a.name}.zip"
                zip_dir(a, z)
                artifacts.append(z)

    print("artifacts:")
    for a in artifacts:
        print(f"- {a}")


if __name__ == "__main__":
    main()