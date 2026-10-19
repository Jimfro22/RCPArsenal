# RCP Arsenal engineering checkout

This is the editable source checkout for the Morning Brew raid hub. The addon under `RCPArsenal/` is the unchanged 0.14.1-alpha handoff. New hub functionality has not been implemented.

The first commit imports all 49 original files. `provenance/baseline-0.14.1.json` records the original archive checksum and every payload file hash. The original archives and extracted handoff remain outside this checkout and unchanged.

## Validate and build

Python 3 and Git are the only local packaging requirements. From this directory:

```sh
python3 tools/package.py --check-baseline
python3 tools/package.py --check-baseline --output-dir dist --label baseline.1
```

For a future modified build, omit `--check-baseline`. Keep the TOC and `RA.VERSION` versions in sync. A package label changes only the filename; it does not change the version seen in game. The ZIP includes exactly one `RCPArsenal/` root, addon code, assets, and inherited docs. Engineering tools and planning documents are outside the game payload. Each ZIP has a SHA-256 sidecar and a manifest containing file hashes and Git revision. ZIP entries use stable ordering, timestamps, and uncompressed storage for reproducible bytes across platforms.

These checks validate versions, manifest references, source identity, and ZIP contents. They do not parse Lua or simulate WoW. No Lua/luac runtime is installed in this environment, and no game testing has been performed.

## Delivery documents

- [Delivery plan](docs/DELIVERY_PLAN.md)
- [Windows smoke test](docs/WINDOWS_SMOKE_TEST.md)
- [Draft validation workflow](docs/ci/validate-package.yml.example)

The draft workflow is inactive and creates workflow artifacts only when installed in a future remote repo. GitHub release publishing and CurseForge setup remain follow-up work. No remote is configured. The addon source has no supplied project license; the owner must choose its publication license. Do not copy Northern Sky code or package external addons into Arsenal.

Use the current Lua source for actual controls; inherited addon docs contain older click descriptions. Preserve the existing Obsidian Ember theme, artwork, local overlay positions, SavedVariables name, static-in-combat capability model, and role → class → spec → movement split priority.
