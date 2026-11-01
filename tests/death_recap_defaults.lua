local f=assert(io.open('tests/setup_placement.lua'));local source=f:read('*a');f:close()
source=source:sub(1,assert(source:find('local h=Lifecycle();local RA=h.RA',1,true))-1)
source=source..[[
for _,saved in ipairs({{}, {autoOpen=true}, {autoOpen=false}, {autoOpen=true,manualEntryVersion=1}, {autoOpen=false,manualEntryVersion=1}})do
 local expected=saved.manualEntryVersion==1 and saved.autoOpen==true
 local h=Lifecycle({profile={schemaVersion=19,deathRecap=saved},setup={completed=true}})
 local R=h.RA.DeathRecap;local db=h.RA:GetDB().deathRecap
 check(db.manualEntryVersion==1 and R:GetState().autoOpen==expected,'Legacy/default migration did not match once-only policy')
 check(not db.enabled,'Auto-open migration enabled recording')
 R:SetOption('autoOpen',true);check(R:GetState().autoOpen and db.manualEntryVersion==1,'Explicit opt-in was not retained')
 local nextLife=Lifecycle({profile={schemaVersion=19,deathRecap={autoOpen=db.autoOpen,manualEntryVersion=db.manualEntryVersion}},setup={completed=true}})
 check(nextLife.RA.DeathRecap:GetState().autoOpen,'Subsequent load reset explicit opt-in')
 nextLife.RA.DeathRecap:SetOption('autoOpen',false);check(not nextLife.RA.DeathRecap:GetState().autoOpen,'Explicit OFF did not apply')
end
io.write('PASS: manual-entry defaults, one-time legacy migration, explicit preference and reload assertions\n')
]]
assert(loadstring(source,'death-recap-default-fixture'))()
