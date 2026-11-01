# RCP Arsenal engineering checkout

This is the editable source checkout for RCP Arsenal. Current source is **0.15.3-alpha.35**. The optional radial now has a graphite segmented ring, theme-accent selection and one caption below its text-free hub. Place next always uses instant cursor placement. The optional hold/swipe/release wheel has a separate key that starts unbound; its center release cancels. Existing Place next/Clear bindings and alpha.25 Raid Groups improvements are retained. See [separate marker controls and native checks](docs/MARKER_CENTER_RELEASE.md) and [Raid Groups matching](docs/RAID_GROUPS.md).

Optional personal Death Recap is default OFF; alpha.35 simplifies the popup header and health row, with compact shield absorption labels. Complete reports, explicit paced chat posting and stable group focus remain available. The Missing dock action posts the displayed missing provider coverage to Raid chat. Recording and defensive auditing remain unchanged. See [test flow, evidence limits and workload bounds](docs/DEATH_RECAP.md).
The alpha.18 [marker center-release behavior](docs/MARKER_CENTER_RELEASE.md), [General and Personal Tools settings](docs/SETTINGS_CLEANUP.md), alpha.16 [glow visibility repair](docs/GLOW_VISIBILITY.md), [adjustable glow](docs/ADJUSTABLE_GLOW.md), [marker cancellation and native targeting](docs/RADIAL_CANCELLATION.md), [Rogue provider coverage](docs/ROGUE_PROVIDER_COVERAGE.md) and [ready-item audio](docs/READY_CONSUMABLE_AUDIO.md) remain intact. Profile schema stays 19. Native WoW visual and protected-input acceptance remains separate from offline source verification.

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
- [Raid Groups planner and Windows checks](docs/RAID_GROUPS.md)
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
