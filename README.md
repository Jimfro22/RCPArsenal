# RCP Arsenal engineering checkout

This is the editable source checkout for RCP Arsenal. Current source is **0.15.3-alpha.8**. This small display polish stops unrelated inspection reports from repainting the Addons matrix and keeps its one-second age/status heartbeat cheap. Scan scheduling, the HUD and communication authorization are unchanged. Alpha.7's disabled-event/lazy-frame work and lossless ZIP compression remain intact. The [optimization contract](docs/OPTIMIZATION.md) records measured offline counters, reporting guarantees and native profiling still required. [Navigation, bindings and reminder behavior](docs/NAVIGATION_KEYBINDS.md) and the [reminder selection contract](docs/REMINDER_SELECTION.md) remain intact. Profile schema remains 19.

The first commit imports all 49 original files. `provenance/baseline-0.14.1.json` records the original archive checksum and every payload file hash. The original archives and extracted handoff remain outside this checkout and unchanged.

## Windows testing with GitHub Desktop

Keep the source checkout **outside WoW**. After the one-time setup, Desktop **Fetch origin → Pull origin** updates the live addon directly through a directory junction; no repeated folder copying is needed.

Follow [the four-step Windows setup](docs/WINDOWS_DESKTOP_SETUP.md), including the existing nested-clone fix. Run **Setup-Windows.cmd** from the checkout after moving it outside WoW. The helper asks for your actual Retail AddOns folder, preserves any existing folder only after an explicit backup choice, and links the inner `RCPArsenal` addon. Do not clone the repository into AddOns or flatten/rename the repository.

## Validate and build

Python 3.9 or newer and Git are the only local packaging requirements. From this directory:

```sh
python3 -m unittest discover -s tests -v
python3 tools/package.py --output-dir dist --label local
```

Use `--check-baseline` only when verifying the original baseline checkout; it correctly rejects this feature build. Keep the TOC and `RA.VERSION` versions in sync. A package label changes only the filename; it does not change the version seen in game. The ZIP includes exactly one `RCPArsenal/` root, addon code, assets, and inherited docs. Engineering tools and planning documents are outside the game payload. Each ZIP has a SHA-256 sidecar and a manifest containing file hashes and Git revision. ZIP entries use stable ordering, timestamps, permissions and lossless level-9 deflate. Repeat builds with the same compressor produce identical bytes; different zlib versions may produce different ZIP checksums, so CI records its actual checksum and extracted payload hashes.

Packaging checks validate versions, manifest references, and ZIP contents. CI also installs Lua 5.1, parses all addon modules, and runs every `tests/*.lua` harness for actual-module profile/hub/quiet lifecycle, captions/assets, the combined addon table, inspection cache, readiness protocol, personal tools, and marker logic. These checks do not simulate native glyph rendering, hardware dispatch, taint, terrain, or permissions. Owner testing of alpha.3 confirmed the installation and markers work, but expanded testing exposed blank captions and grouping problems; cold-start verification of this correction remains required.

## Delivery documents

- [Optimization and native profiling acceptance](docs/OPTIMIZATION.md)
- [Native rendering and feature grouping repair](docs/NATIVE_RENDERING_REPAIR.md)
- [Inspection cache Windows tests](docs/INSPECTION_CACHE_WINDOWS_TESTS.md)
- [Delivery plan](docs/DELIVERY_PLAN.md)
- [Northern Sky adapter contract](docs/NSRT_ADAPTER_CONTRACT.md)
- [Northern Sky Windows tests](docs/NSRT_WINDOWS_TESTS.md)
- [Hub Windows tests](docs/HUB_WINDOWS_TESTS.md)
- [World marker Windows tests](docs/WORLD_MARKER_TESTS.md)
- [Baseline Windows smoke test](docs/WINDOWS_SMOKE_TEST.md)
- [Alpha release process](docs/RELEASING.md)
- [Packaging validation workflow](.github/workflows/validate-package.yml)
- [Tagged alpha workflow](.github/workflows/release-alpha.yml)

The public source destination is [Jimfro22/RCPArsenal](https://github.com/Jimfro22/RCPArsenal). Validation produces test artifacts, and pushed alpha tags produce prereleases with an install ZIP, checksum, and Git/file provenance. CurseForge project 1753701 (`rcp-arsenal`) exists; alpha file 9252808 was submitted and was still processing/project approval pending at the last check. No automatic CurseForge uploads are configured. The addon source has no supplied project license. Publication does not add a license grant; an open-source license remains an owner policy choice. Do not copy Northern Sky code or package external addons into Arsenal.

Use the current Lua source for actual controls; inherited addon docs contain older click descriptions. Preserve the existing Obsidian Ember theme, artwork, local overlay positions, SavedVariables name, static-in-combat capability model, and role → class → spec → movement split priority.
