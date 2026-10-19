# Windows: GitHub Desktop updates the live addon

The source repository contains `docs`, `tools`, and an **inner** `RCPArsenal` addon. WoW needs `AddOns\RCPArsenal\RCPArsenal.toc`. Cloning the whole repository into AddOns adds extra levels. Keep the checkout outside WoW and use the one-time link setup below. Afterward, Desktop pulls update the actual addon without copying.

## Fix the existing nested clone once

1. Close WoW. In GitHub Desktop select **Jimfro22/RCPArsenal**, then **Fetch origin** and **Pull origin** if offered. Choose **Repository → Show in Explorer**. This is the checkout to move: it contains `docs`, `tools`, `Setup-Windows.cmd`, and the inner addon folder.
2. **Cut and paste that whole checkout** to a normal local folder outside WoW, such as `%USERPROFILE%\GitHub\RCPArsenal`. Use an unused destination; do not merge folders or move only the inner addon. In Desktop, choose **Locate** for the moved repository. Alternatively use **File → Add local repository** and select that same moved checkout. No re-clone or deletion is required.
3. In the moved checkout, double-click **Setup-Windows.cmd**. Select the actual **Interface\AddOns** directory for Retail. Battle.net → WoW → gear → **Show in Explorer** can locate the installation. Select AddOns itself, not Interface and not one of the nested Arsenal folders. Custom game folder names are supported; the helper checks the selected folder and `Wow.exe`, without inventing a standard installation path.
4. Review the displayed **source**, **live addon**, and any **backup** paths. If `AddOns\RCPArsenal` already exists as a normal folder, type **BACKUP** to move the entire old folder—including nested files—into the displayed `Interface\RCPArsenal-InstallBackups\...` location. Enter cancels unchanged. The helper then creates and verifies a directory junction to the inner addon. It never deletes or overwrites existing files. A different existing link is left alone.

The owner reported the TOC at `C:\Program Files (x86)\World of Warcraft_retail_\Interface\AddOns\RCPArsenal\RCPArsenal\RCPArsenal`. This confirms excess nesting, but does not establish which ancestor is the Git root. Use Desktop's Show in Explorer in step 1; do not guess which folder to cut. The reported game-root spelling is preserved here exactly.

After success, `AddOns\RCPArsenal\RCPArsenal.toc` opens the file in the source checkout. Start WoW, enable **RCP Arsenal**, and use **`/rcp`**. Preserve `WTF` and SavedVariables; the setup never accesses them.

## Every update afterward

In Desktop use **Fetch origin**, then **Pull origin** when offered. Fetch alone only checks for updates. The junction exposes the pulled files directly to WoW. Use `/reload` for ordinary Lua changes; fully restart WoW for the first install or new addon/media files. Keep the checkout at its chosen location.

## If setup stops

- **Checkout still inside AddOns:** complete the whole-checkout move and Desktop Locate first. The helper does not relocate your Git repository automatically.
- **Access denied under Program Files:** existing data is preserved; a moved old folder is restored if the link could not be created and the destination is still free. Retry the same launcher with **Run as administrator** only if Windows requires it. No ACL or machine-wide policy changes are made.
- **OneDrive:** a local folder outside sync is simplest. If using OneDrive, choose **Always keep on this device** for the entire checkout. The source must be available when WoW reads it.
- **Wrong game folder/network drive:** select the real Retail AddOns directory on a local NTFS drive. Existing directory links in ancestor paths and foreign links at the destination are refused instead of being retargeted.
- **PowerShell policy blocked:** the launcher requests RemoteSigned for this process only. It does not change machine/user policy or bypass organizational policy. Keep the error and ask for help; do not disable protections.

Advanced preview, from built-in **Windows PowerShell 5.1** in the checkout (substitute the path you actually selected). The helper deliberately uses that same runtime as the launcher; PowerShell 7 is refused before changes:

```powershell
.\tools\Link-WindowsAddon.ps1 -AddOnsPath 'C:\your actual WoW folder\Interface\AddOns' -WhatIf
```

Preview changes nothing. Running setup again verifies an already-correct junction and makes no changes. `-BackupExisting` is an explicit command-line alternative to typing BACKUP; it still preserves the existing folder and never retargets another link.

For an immediate one-time game test, the named [0.15.2 release ZIP](https://github.com/Jimfro22/RCPArsenal/releases/tag/v0.15.2-alpha.1) is also available. It is a snapshot, so it does not provide Desktop updates; the linked-checkout route above solves that ongoing workflow. GitHub's automatic source ZIP is not the addon installer.

The helper uses PowerShell's [directory junction support](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item?view=powershell-5.1); Desktop can [add an existing local checkout](https://docs.github.com/en/desktop/adding-and-cloning-repositories/adding-a-repository-from-your-local-computer-to-github-desktop). Automated disposable-folder checks are separate from installation on the owner's Windows PC and from native WoW validation. No new addon release/version is needed for this repository-only helper.
