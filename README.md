# RCP Arsenal engineering checkout

This is the editable source checkout for the Morning Brew raid hub. The current feature alpha is **0.14.2-alpha.1**, adding an optional world/ground marker cycler under Quick Bar. It starts off and unbound. The broader hub redesign remains future work.

The first commit imports all 49 original files. `provenance/baseline-0.14.1.json` records the original archive checksum and every payload file hash. The original archives and extracted handoff remain outside this checkout and unchanged.

## Validate and build

Python 3.9 or newer and Git are the only local packaging requirements. From this directory:

```sh
python3 -m unittest discover -s tests -v
python3 tools/package.py --output-dir dist --label local
```

Use `--check-baseline` only when verifying the original baseline checkout; it correctly rejects this feature build. Keep the TOC and `RA.VERSION` versions in sync. A package label changes only the filename; it does not change the version seen in game. The ZIP includes exactly one `RCPArsenal/` root, addon code, assets, and inherited docs. Engineering tools and planning documents are outside the game payload. Each ZIP has a SHA-256 sidecar and a manifest containing file hashes and Git revision. ZIP entries use stable ordering, timestamps, and uncompressed storage for reproducible bytes across platforms.

Packaging checks validate versions, manifest references, and ZIP contents. CI also installs Lua 5.1, parses all addon modules, and runs `lua5.1 tests/world_markers.lua` for offline profile/sequence/secure-snippet logic. These checks do not simulate WoW native hardware dispatch, taint, terrain, or permissions. No game testing has been performed.

## Delivery documents

- [Delivery plan](docs/DELIVERY_PLAN.md)
- [World marker Windows tests](docs/WORLD_MARKER_TESTS.md)
- [Baseline Windows smoke test](docs/WINDOWS_SMOKE_TEST.md)
- [Alpha release process](docs/RELEASING.md)
- [Packaging validation workflow](.github/workflows/validate-package.yml)
- [Tagged alpha workflow](.github/workflows/release-alpha.yml)

The public source destination is [Jimfro22/RCPArsenal](https://github.com/Jimfro22/RCPArsenal). Validation produces test artifacts, and pushed alpha tags produce prereleases with an install ZIP, checksum, and Git/file provenance. CurseForge setup is separate; no CurseForge upload is activated. The addon source has no supplied project license. Publication does not add a license grant; an open-source license remains an owner policy choice. Do not copy Northern Sky code or package external addons into Arsenal.

Use the current Lua source for actual controls; inherited addon docs contain older click descriptions. Preserve the existing Obsidian Ember theme, artwork, local overlay positions, SavedVariables name, static-in-combat capability model, and role → class → spec → movement split priority.
