-- Run from the repository root: lua tools/export_release_notes.lua [--check]
local RA = {}
assert(loadfile('RCPArsenal/ReleaseNotes.lua'))('RCPArsenal', RA)
local lines = {'# Recent RCP Arsenal updates', '',
    '<!-- Generated from RCPArsenal/ReleaseNotes.lua; edit that source, then run tools/export_release_notes.lua. -->', ''}
for _, entry in ipairs(RA.ReleaseNotes) do
    lines[#lines + 1] = '## ' .. entry.version .. ' — ' .. entry.title
    lines[#lines + 1] = ''
    for _, group in ipairs(entry.groups) do
        lines[#lines + 1] = '### ' .. group.label
        lines[#lines + 1] = ''
        for _, note in ipairs(group.items) do lines[#lines + 1] = '- ' .. note end
        lines[#lines + 1] = ''
    end
end
local path, content = 'docs/RECENT_UPDATES.md', table.concat(lines, '\n')
if arg[1] == '--check' then
    local file = assert(io.open(path, 'rb')); local existing = file:read('*a'); file:close()
    assert(existing == content, 'Recent updates differ from the in-game notes; regenerate ' .. path)
else
    local file = assert(io.open(path, 'wb')); file:write(content); file:close()
end
