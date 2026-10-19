# RCP Arsenal alpha delivery

The authorized public source destination is [Jimfro22/RCPArsenal](https://github.com/Jimfro22/RCPArsenal). Public source publication does not add an open-source license grant. CurseForge project creation and upload are managed separately; no CurseForge workflow is enabled.

## Validation

`.github/workflows/validate-package.yml` runs packaging safeguard tests, builds the correctly rooted addon ZIP, and saves a workflow artifact on pushes to main and pull requests. Its token has read-only contents permission. It receives no publishing secret. Python 3.9 or newer and Git are required locally.

```sh
python3 -m unittest discover -s tests -v
python3 tools/package.py --output-dir dist --label local
```

These validate the package, source manifest, and negative fixtures. They do not run the addon in WoW.

## Tagged alpha releases

`.github/workflows/release-alpha.yml` runs only for pushed `v*-alpha*` tags in the exact repository. It requires the tagged commit to be on main and have matching TOC/Core versions plus a notes file at `docs/releases/<tag>.md`. Actions are pinned to reviewed official revisions. No PR workflow can publish.

The release workflow checks the package tests, builds from a clean tagged checkout, then uses the job's built-in GitHub token to upload the installer, checksum, and provenance to a draft release. It publishes that draft as a prerelease only after uploads succeed. No separate personal token or external publisher is needed. A repeated attempt stops rather than replacing existing release assets; inspect the existing release before repairing a partial draft.

The first tag is `v0.14.1-alpha-baseline.1`. It requires byte-for-byte equality with the original addon and keeps the in-game version `0.14.1-alpha`. Later feature alphas must increment both actual version strings; use a tag exactly matching `v<addon-version>`, for example `v0.15.0-alpha.1` only when that version exists in source. Add accurate release notes before tagging.

After the main branch passes validation:

```sh
git tag v0.14.1-alpha-baseline.1 <reviewed-main-commit>
git push origin v0.14.1-alpha-baseline.1
```

For each release, verify the workflow conclusion, public prerelease status, asset names, downloaded ZIP hash and payload, and manifest commit. Download the named `RCPArsenal-...zip` install asset; GitHub's automatic source-code ZIP is not the installer. Give Windows testers the named asset and smoke-test instructions.

The initial alpha retains Interface 120100 and all inherited defaults and behavior. Packaging success is separate from client compatibility, Windows installation, and game acceptance. Keep those checks open until observed.
