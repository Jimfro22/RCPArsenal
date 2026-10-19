# Typography and header-logo correction — 0.15.3-alpha.2

The owner rejected alpha.1’s thin, narrow font and jagged header mark in a native screenshot. This pass changes font initialization and one small-size header asset, retaining sizes, layout, caption recovery, all feature behavior and saved values.

## Font regression

The previous resolver used `CreateFont` but checked its `SetFont` result as if it were `FontString:SetFont`. `Font:SetFont` is a void native API. Requiring `true` rejected valid Expressway objects despite correct GetFont path/height and selected Arial Narrow for regular and bold roles. The offline mock incorrectly returned true and concealed the regression.

The corrected resolver first attaches the object to a dedicated hidden FontString, then loads it. Successful nonthrowing calls are verified through effective path and positive height; the void return is ignored. Invalid, mismatched and missing readback still falls back safely. The hidden parent is shared and probes are cached by size/weight. Live captions never probe optional paths; retained text, styling, drafts, late registration and bounded recovery remain. An instance whose effective face drifts from its cached selection is rebound on recovery.

The preference remains Expressway/Expressway Bold/ExtraBold from registered SharedMedia or the user’s licensed local files, then the native fallback. The registered `Expressway, Bold` alias is also recognized. No font file is copied or distributed. The owner’s supplied Interface sample identifies `Expressway.TTF` as Expressway Bold and `Expressway Bold.ttf` as Expressway ExtraBold; these are existing face files, not synthetic outline flags. Regular roles keep the base selection and bold roles prefer the heavier registered face. No font sizes were changed.

Primary native definitions: [Font API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua), [FontString API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua). Cold-bound-instance evidence: [native report and maintainer correction](https://github.com/Antrakt92/StatsPro/issues/6), consistent with [WeakAuras text initialization](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/RegionTypes/Text.lua).

## Exact-mark small-size export

Original `RCPLogo.tga` stays unchanged (SHA256 `9729123a843bd16ab41a500daf9fdabfcd329958e489bc7e9bc497af1d25a461`). It already has antialiasing, but its roughly two-source-pixel colored outline is about one third of a UI unit when reduced from256 to42. Merely selecting LINEAR did not satisfy native visual quality.

`tools/build_header_logo.py` deterministically derives `RCPLogoHeader.tga` at64×64. It preserves the original interior RP/check artwork by coverage downsampling, uses the original six hex vertices and sampled border colors, and hints that outline to1.25export pixels (about0.82units at the unchanged42-unit display size). Premultiplied prefiltering and transparent RGB extrusion avoid discarded thin-edge coverage and black sampling fringes. This is a dedicated optical export, not an upscale, font substitution, new symbol or palette. The builder uses only Python’s standard library and verifies the original source hash.

Only Config’s header uses the new asset. Its42-unit size and position remain; native layout rounding follows the final parent scale. Other logo/checkmark assets remain unchanged. Before/after output-size sampling previews support source review but do not simulate WoW’s full rendering path.

## Acceptance

After the approved GitHub update, Fetch origin → Pull origin in the existing Windows Desktop checkout, fully exit/restart WoW, and confirm `/run print(RCPArsenal.VERSION)` shows0.15.3-alpha.2. No reset or reinstall.

Cold-open the same page at the same UI scale. Compare brand/nav/card headings, buttons and body copy with the original substantial Expressway style. Check the same RP header outline and previous blank-caption controls, then reopen and check Quick Bar labels. Capture native results. Font and logo visual acceptance remains pending; source checks and sampling previews do not close it. CurseForge remains held for new explicit owner approval.
