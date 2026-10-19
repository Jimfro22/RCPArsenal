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
ALLOWED_SUFFIXES = {".lua", ".toc", ".xml", ".tga", ".blp", ".png", ".md", ".txt", ".ogg"}


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

    # Only reviewed user-provided audio may enter an install ZIP. Hash validation
    # also rejects a missing/truncated/replaced sound without guessing native
    # file availability from a PlaySound return value.
    audio_manifest = json.loads((BASELINE.parent / "user-alert-audio/manifest.json").read_text())
    audio = {"RCPArsenal/Media/Audio/" + Path(entry["export"]).name: entry["sha256"] for entry in audio_manifest["files"]}
    for name in payload:
        if name.lower().endswith(".ogg") and name not in audio:
            raise ValueError(f"Unreviewed sound asset: {name}")
    for name, expected in audio.items():
        if name not in payload:
            raise ValueError(f"Missing reviewed sound asset: {name}")
        if sha256(payload[name]) != expected:
            raise ValueError(f"Sound asset hash differs: {name}")

    toc = payload["RCPArsenal/RCPArsenal.toc"].decode("utf-8-sig")
    meta = dict(re.findall(r"^##\s*([^:]+):\s*(.+)$", toc, re.MULTILINE))
    version = meta.get("Version", "").strip()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", version):
        raise ValueError("TOC Version must be a nonempty filename-safe version")
    core = payload["RCPArsenal/Core.lua"].decode("utf-8")
    core_version = re.search(r'RA\.VERSION\s*=\s*"([^"]+)"', core)
    if not core_version or core_version.group(1) != version:
        raise ValueError("TOC and Core.lua versions must match")
    revisions = dict(re.findall(r"RA\.(PROFILE_SCHEMA|CATALOG_VERSION)\s*=\s*(\d+)", core))
    meta["ProfileSchema"] = revisions["PROFILE_SCHEMA"]
    meta["CatalogVersion"] = revisions["CATALOG_VERSION"]
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
    parser.add_argument("--release-tag",
                        help="Require a clean tagged commit matching the addon version")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.label):
        parser.error("--label must be filename-safe")
    payload, files, meta, load_order, unchanged = collect(args.check_baseline)
    commit = git("rev-parse", "HEAD")
    dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
    if args.release_tag:
        base_tag = "v" + meta["Version"]
        baseline_suffix = args.release_tag.removeprefix(base_tag + "-")
        if args.release_tag == base_tag:
            args.label = "release"
        elif (args.release_tag.startswith(base_tag + "-")
              and re.fullmatch(r"baseline\.[1-9][0-9]*", baseline_suffix)):
            if not unchanged:
                raise ValueError("A baseline release must match every original addon byte")
            args.label = baseline_suffix
        else:
            raise ValueError("Release tag does not match the TOC/Core version")
        if dirty:
            raise ValueError("Release builds require a clean working tree")
        if git("rev-parse", f"refs/tags/{args.release_tag}^{{commit}}") != commit:
            raise ValueError("Release tag must point at the checked-out commit")
    print(f"Validated {len(files)} payload files; {len(load_order)} TOC entries; "
          f"version {meta['Version']}; original baseline match: {unchanged}.")
    if args.output_dir is None:
        return
    output = args.output_dir.resolve()
    if output == ADDON or ADDON in output.parents:
        raise ValueError("Output must be outside the addon directory")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"RCPArsenal-{meta['Version']}-{args.label}.zip"
    # Stable metadata and explicit lossless deflate. Supplying a ZipInfo to
    # writestr otherwise retains its default STORED method. Reproducible with
    # the same compressor; CI records the final cross-platform ZIP checksum.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in payload.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 18, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            z.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
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
        "profile_schema": int(meta["ProfileSchema"]), "catalog_version": int(meta["CatalogVersion"]),
        "git_commit": commit,
        "git_worktree_dirty": dirty,
        "release_tag": args.release_tag,
        "original_source_zip_sha256": json.loads(BASELINE.read_text())["original_source_zip_sha256"],
        "original_baseline_match": unchanged, "zip": archive.name,
        "zip_sha256": digest, "toc_load_order": load_order, "files": files,
        "verification_scope": "Package validation only; Lua checks are recorded separately in CI; no WoW runtime verification",
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
