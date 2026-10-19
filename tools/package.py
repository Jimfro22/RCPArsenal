#!/usr/bin/env python3
"""Validate and package RCPArsenal with Python's standard library only."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "RCPArsenal"
BASELINE = ROOT / "provenance" / "baseline-0.14.1.json"
ALLOWED_SUFFIXES = {".lua", ".toc", ".xml", ".tga", ".blp", ".png", ".md", ".txt"}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], text=True, stderr=subprocess.DEVNULL
    ).strip()


def collect(check_baseline):
    payload = {}
    for path in sorted(ADDON.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Symlinks are not package inputs: {path}")
        if path.is_dir():
            continue
        name = path.relative_to(ROOT).as_posix()
        if any(part.startswith(".") for part in path.relative_to(ADDON).parts):
            raise ValueError(f"Hidden file in addon payload: {name}")
        if path.suffix.lower() not in ALLOWED_SUFFIXES:
            raise ValueError(f"Unreviewed file type in addon payload: {name}")
        payload[name] = path.read_bytes()

    toc = payload["RCPArsenal/RCPArsenal.toc"].decode("utf-8-sig")
    meta = dict(re.findall(r"^##\s*([^:]+):\s*(.+)$", toc, re.MULTILINE))
    version = meta.get("Version", "").strip()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", version):
        raise ValueError("TOC Version must be a nonempty filename-safe version")
    core = payload["RCPArsenal/Core.lua"].decode("utf-8")
    core_version = re.search(r'RA\.VERSION\s*=\s*"([^"]+)"', core)
    if not core_version or core_version.group(1) != version:
        raise ValueError("TOC and Core.lua versions must match")
    if meta.get("SavedVariables", "").strip() != "RaidArsenalDB":
        raise ValueError("SavedVariables compatibility changed; review before packaging")
    load_order = []
    for line in toc.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name = "RCPArsenal/" + line.replace("\\", "/")
        if name not in payload:
            raise ValueError(f"Missing TOC load entry: {name}")
        load_order.append(line)
    if not load_order or load_order[0] != "Core.lua":
        raise ValueError("Core.lua must remain the first TOC load entry")
    files = {name: sha256(data) for name, data in payload.items()}
    baseline = json.loads(BASELINE.read_text())
    unchanged = files == baseline["files"]
    if check_baseline and not unchanged:
        changed = sorted(set(files) ^ set(baseline["files"]))
        changed += [n for n in files.keys() & baseline["files"].keys()
                    if files[n] != baseline["files"][n]]
        raise ValueError("Baseline payload differs: " + ", ".join(sorted(changed)))
    return payload, files, meta, load_order, unchanged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-baseline", action="store_true",
                        help="Require all addon bytes to match the original ZIP")
    parser.add_argument("--output-dir", type=Path,
                        help="Write a ZIP, checksum, and build manifest here")
    parser.add_argument("--label", default="local",
                        help="Filename label only; does not change the addon version")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.label):
        parser.error("--label must be filename-safe")
    payload, files, meta, load_order, unchanged = collect(args.check_baseline)
    print(f"Validated {len(files)} payload files; {len(load_order)} TOC entries; "
          f"version {meta['Version']}; original baseline match: {unchanged}.")
    if args.output_dir is None:
        return
    output = args.output_dir.resolve()
    if output == ADDON or ADDON in output.parents:
        raise ValueError("Output must be outside the addon directory")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"RCPArsenal-{meta['Version']}-{args.label}.zip"
    # Fixed timestamp, ordering, permissions, and uncompressed storage produce
    # identical bytes across platforms without a zlib version dependency.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as z:
        for name, data in payload.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 18, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            z.writestr(info, data)
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None or set(z.namelist()) != set(payload):
            raise ValueError("Packaged ZIP failed CRC or layout validation")
        if any(z.read(name) != data for name, data in payload.items()):
            raise ValueError("Packaged ZIP bytes differ from source")
    digest = sha256(archive.read_bytes())
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    manifest = {
        "addon": "RCPArsenal", "addon_version": meta["Version"],
        "toc_interface": meta.get("Interface"), "package_label": args.label,
        "git_commit": git("rev-parse", "HEAD"),
        "git_worktree_dirty": bool(git("status", "--porcelain", "--untracked-files=normal")),
        "original_baseline_match": unchanged, "zip": archive.name,
        "zip_sha256": digest, "toc_load_order": load_order, "files": files,
        "verification_scope": "Static manifest and payload validation; no Lua syntax or WoW runtime test",
    }
    archive.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    print(f"Built {archive}\nSHA-256 {digest}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"Package validation failed: {error}", file=sys.stderr)
        sys.exit(1)
