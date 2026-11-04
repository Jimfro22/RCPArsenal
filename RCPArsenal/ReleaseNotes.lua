local _, RA = ...

-- Shared by the manual settings log and tools/export_release_notes.lua.
-- Notes describe shipped behavior; native acceptance lives in docs/VALIDATION.md.
RA.ReleaseNotes = {
    {
        version = "0.15.3-alpha.64", title = "Initialize named recap capture",
        groups = {{label = "Fixed", items = {
            "Enabling Death Log while alive and out of combat now checks its named-recap baseline without waiting for a meter update.",
            "Unreadable startup checks can recover at existing alive boundaries; old or unresolved death records remain excluded.",
            "New saved debug reports retain the recap baseline source and failure reason for diagnosis after reload.",
        }}},
    },
    {
        version = "0.15.3-alpha.63", title = "Keep delayed incoming events",
        groups = {{label = "Fixed", items = {
            "Protected events delivered just after death now remain inspectable under Received after death.",
            "Delayed events keep their delivery times and stay separate from the eight-second chart, named hits and chat totals.",
            "Facts distinguish public and protected amounts instead of reporting zero events when native widgets show them.",
        }}},
    },
    {
        version = "0.15.3-alpha.62", title = "Protected incoming events in Death Log",
        groups = {{label = "Added", items = {
            "Death Log's eight-second view can draw protected dungeon/raid damage and healing through native bars.",
            "Each bar is one event. Hover and scroll to inspect exact amounts without guessing spell names.",
            "Protected events remain available for five deaths this login. Reload retains named hits and public facts, with a note when live amounts have cleared.",
            "Chat keeps its named-hit summary and omits a healing total when protected events prevent a complete calculation.",
        }}},
    },
    {
        version = "0.15.3-alpha.61", title = "Keep the display test recording",
        groups = {{label = "Fixed", items = {
            "The manual protected-number test stays armed when combat starts instead of canceling itself.",
            "External window hides preserve the capture. Reopen with /rcp recapdebug display; CLOSE still cancels an active test.",
            "COPY STATUS includes the last event and window hides to diagnose a failed test without another fight.",
        }}},
    },
    {
        version = "0.15.3-alpha.60", title = "Test protected incoming numbers",
        groups = {{label = "Added", items = {
            "A manual display test passes protected incoming amounts directly to Blizzard's bars and text.",
            "Use /rcp recapdebug display start before combat. After death, screenshot the test and COPY STATUS before reload.",
            "The test is off by default, retains eight seconds in memory, and stops after one death or two minutes.",
        }}},
    },
    {
        version = "0.15.3-alpha.59", title = "Save native recap comparisons",
        groups = {{label = "Added", items = {
            "A manual recap-source test saves Blizzard's own recap at death and again one second later.",
            "Both comparison snapshots survive reload with the saved death. No Blizzard window is needed.",
        }}},
    },
    {
        version = "0.15.3-alpha.58", title = "Compact Death Log sharing",
        groups = {{label = "Changed", items = {
            "Post to chat shares up to six named hits from the final six seconds, from either view.",
            "Reports summarize recorded damage, absorbs, overkill, healing and confirmed available abilities.",
        }}},
    },
    {
        version = "0.15.3-alpha.57", title = "Consolidation and testing",
        groups = {
            {label = "Added", items = {
                "What's new beneath the settings logo. Open it whenever you want to read recent changes.",
            }},
            {label = "Changed", items = {
                "One current test checklist separates finished work, confirmed results, and remaining checks.",
            }},
        },
    },
    {
        version = "0.15.3-alpha.56", title = "Death Log spacing",
        groups = {{label = "Fixed", items = {
            "Fight time sits above the eight-second chart, clear of the final healing amount.",
        }}},
    },
    {
        version = "0.15.3-alpha.55", title = "Named hits and spell replacements",
        groups = {{label = "Fixed", items = {
            "Named hits displays every supplied hit within eight seconds, including earlier small hits.",
            "New deaths use your learned spell replacement instead of also showing its base ability.",
        }}},
    },
    {
        version = "0.15.3-alpha.54", title = "Boss ability details",
        groups = {{label = "Added", items = {
            "Click a mapped boss ability to open its Dungeon Journal entry outside combat.",
        }}},
    },
    {
        version = "0.15.3-alpha.53", title = "Quick access and optional performance reports",
        groups = {
            {label = "Added", items = {
                "Type /recap to open your saved Death Log.",
                "Optional performance reports in General. Recording starts off and shows an indicator when on.",
            }},
            {label = "Fixed", items = {
                "Death Summary can return after reloading while dead, unless you already dismissed it.",
            }},
            {label = "Changed", items = {
                "The Quick Bar announces missing classes as MISSING RAID BUFFS: followed by the class list.",
            }},
        },
    },
}
