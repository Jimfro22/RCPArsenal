# Rogue provider coverage — 0.15.3-alpha.12

Quick Bar's Missing provider classes panel now includes **Atrophic Poison** under **Debuffs**, using Rogue class presence and spell 381637 for the cast/icon. No damage percentage is encoded. An online Rogue in a tracked raid subgroup satisfies this provider row. Offline Rogues and Rogues only in ignored groups leave it missing. Class presence does not confirm talent selection or an active poison.

This is one entry in the existing local composition map. Roster, ignored-group and online behavior are unchanged. There is no aura, talent, combat-log or inspection tracking, new scan, protocol or encoded capability-catalog change. Profile schema and feature defaults remain unchanged. The composition notes also bring the existing Devotion Aura and Hunter's Mark table placement into line with the current map; their gameplay behavior is unchanged.

Actual-module checks exercise Rogue absence/presence, offline and ignored-group providers, mixed ignored/tracked providers, invalid subgroup, an unrelated class and out-of-raid behavior. They assert one existing roster pass and no aura/combat-log/talent/inspection work. The icon fixture constructs all eleven rows, checks panel bounds/label fit, starts with a cold Rogue icon fallback and one data request, then recovers all eleven icons through the existing bounded shared queue.

Update the existing Windows checkout with **Fetch origin → Pull origin**, then fully restart WoW. Keep the checkout/junction and saved settings. Enable Quick Bar and Missing provider classes if needed; check Atrophic Poison under Debuffs with no Rogue, then with an online Rogue in a tracked group. Check offline and ignored-group cases and the icon after a cold login. Native font/icon/render acceptance remains open. CurseForge remains held.

## Sharing displayed coverage (alpha.34)

Left-click the **Missing** Quick Bar dock box to submit its current absent-provider
classes to Raid chat. Hover still opens the inspection panel; the small count badge
still toggles inspection. The message groups the already rendered provider classes by Buffs and Debuffs,
without a new roster/inspection/aura query. It says missing providers, not missing
active buffs. An empty list, demo/layout preview, unavailable raid/chat permissions
or combat does not post. A two-second guard suppresses accidental double-clicks;
a failed ordinary-chat call is not retried. No timer or automatic broadcast is added.
