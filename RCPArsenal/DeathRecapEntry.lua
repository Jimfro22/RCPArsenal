local _, RA = ...
local Entry = {}
RA.DeathRecapEntry = Entry
local R, UI, T = RA.DeathRecap, RA.DeathRecapUI, RA.Theme
local C = T.Colors
local button, token, anchor, layoutHost, placement, shownPage
local previewPage
local CARD_MIN, CARD_MAX, CARD_HEIGHT = 160, 280, 56
local ICON_SIZE, ICON_GAP, ITEM_GAP = 22, 4, 10
local binding, pulsing, hovered = 0, false, false
local hooks, subscriptions = {}, {}
local hookDemand, previewCombat

local function Public(value)
    if type(issecretvalue) ~= "function" then return nil end
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret == false then return value end
end
local function Read(object, key)
    local ok, value = pcall(function() return object[key] end)
    if ok then return Public(value) end
end
local function Call(object, method, ...)
    local fn = Read(object, method)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return Public(value) end
end
local function Global(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Public(value) end
end
local function Number(value)
    value = Public(value)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
end
-- A display-only projection of the frozen checks. Never refresh availability here.
function Entry:GetAvailableRows(page)
    local rows, sample = {}, page and page.lastAlive
    rows.hadCheck = type(sample) == "table"
    if not rows.hadCheck then return rows end
    local seen = {}
    local function Add(row, kind, detail)
        local id = row.spellID or row.itemID
        if not Number(id) or id <= 0 or id ~= math.floor(id) or seen[(kind or "spell")..id] then return end
        seen[(kind or "spell")..id] = true
        rows[#rows+1] = {spellID=not kind and id or nil, itemID=kind and id or nil,
            name=kind == "stone" and "Healthstone" or kind == "potion" and "Healing potion" or row.name or "Defensive",
            category=row.category, kind=kind, icon=row.icon, detail=detail,
            checkedAt=Number(R:GetRecordedCheckTime(row)),remainingUses=Number(row.remainingUses),physicalCount=Number(row.physicalCount)}
    end
    for index, row in ipairs(sample.spells or {}) do
        if index > R.LIMITS.spells then break end
        local state, detail = R:ClassifyRecordedCheck(row, sample.coverageEndedAt, false)
        if row.known == true and state == true and R:GetRecordedUseRole(row)~="utility"then Add(row, nil, detail) end
    end
    local supplies = {}
    for index, row in ipairs(sample.supplies or {}) do
        if index > 32 then break end
        supplies[#supplies+1] = row
    end
    for _, family in ipairs(R:GetSupplyFamilies({lastAlive={supplies=supplies,coverageEndedAt=sample.coverageEndedAt}})) do
        for _, member in ipairs(family.members) do
            local uses=Number(member.row.remainingUses)
            if member.state == true and(family.kind~="stone"or uses and uses>0)then Add(member.row, family.kind, member.detail); break end
        end
    end
    local function Rank(row) return row.kind == "stone" and 2 or row.kind == "potion" and 3 or row.category == "major" and 0 or 1 end
    table.sort(rows, function(a,b)
        local ar,br=Rank(a),Rank(b)
        return ar ~= br and ar < br or ar == br and (a.spellID or a.itemID) < (b.spellID or b.itemID)
    end)
    return rows
end
local function Mutable(frame)
    local ok, method = pcall(function() return frame.CanChangeProtectedState end)
    if not ok or type(issecretvalue) ~= "function" then return false end
    local checked, secret = pcall(issecretvalue, method)
    if not checked or secret ~= false then return false end
    if method == nil then return true end -- Older surfaces may omit this accessor.
    if type(method) ~= "function" then return false end
    local called, allowed = pcall(method, frame)
    return called and Public(allowed) == true
end
local function Accessible(frame)
    frame = Public(frame)
    if type(frame) ~= "table" and type(frame) ~= "userdata" then return nil end
    if Call(frame, "IsForbidden") ~= false then return nil end
    return frame
end
local function Visible(frame)
    return Accessible(frame) and Call(frame, "IsShown") == true and Call(frame, "IsVisible") == true
end
local function Host()
    local frame = Global(StaticPopup_FindVisible, "DEATH")
    if Visible(frame) and Read(frame, "which") == "DEATH" then return frame end
end
local function Enabled()
    local state = R:GetState()
    return state and state.enabled == true
end
local function SubscriptionDemand()
    local demanded=Enabled()or previewPage~=nil
    for _, subscription in ipairs(subscriptions)do subscription:SetEnabled(demanded)end
    if previewCombat then previewCombat:SetEnabled(previewPage~=nil)end
end
local function OwnDeath()
    return Global(UnitIsDeadOrGhost, "player") == true and Global(UnitIsGhost, "player") == false
end
local function Current()
    if not token or not Enabled() or not OwnDeath() or button and not Mutable(button) then return false end
    local page = R:GetPage()
    return page == token.page and page.id == token.id and page.captureGeneration == token.generation
end
local function HideTooltip()
    if not button or not GameTooltip then return end
    local owner = Call(GameTooltip, "GetOwner")
    if owner == button or owner and Read(owner, "entryOwner") == button then pcall(GameTooltip.Hide, GameTooltip) end
end
local function StopGlow()
    if not button then return end
    if pulsing then button.pulse:Stop(); pulsing = false end
    button.glow:SetAlpha(.10)
    button.glow:Hide()
end
local function Hide(clearPlacement)
    binding = binding + 1
    anchor = nil
    if clearPlacement then layoutHost, placement = nil, nil end
    hovered = false
    if button then
        StopGlow(); HideTooltip()
        button:SetScript("OnClick", nil)
        for _, icon in ipairs(button.icons or {}) do icon:SetScript("OnClick", nil); icon:Hide(); icon.row=nil; icon.overflow=nil end
        button.boundRows=nil
        button:Hide()
    end
end
local function Clear()
    token, shownPage, previewPage = nil, nil, nil
    SubscriptionDemand()
    Hide(true)
end
local function Paint()
    if not button then return end
    T:SetRoundedColor(button, hovered and C.surfaceHover or C.surfaceRaised, "base")
    T:SetRoundedColor(button, {C.magenta[1], C.magenta[2], C.magenta[3], hovered and .80 or .45}, "border")
    T:SetRoundedColor(button.glow, {C.magenta[1], C.magenta[2], C.magenta[3], 1}, "border")
end
local function Attention()
    if not button or not button:IsVisible() or previewPage or not token or token.viewed or hovered then StopGlow(); return end
    button.glow:Show()
    if not pulsing then button.glow:SetAlpha(.10); button.pulse:Play(); pulsing = true end
end
local function ValidHover()
    return button and button:IsVisible()and(previewPage~=nil and Mutable(button)and Global(InCombatLockdown)==false or not previewPage and Current()and anchor==Host())
end
local function Age(row, page)
    local died, checked = Number(page and page.diedAt), Number(row.checkedAt)
    if not died or not checked or checked > died then return "Check time not recorded" end
    return string.format("Checked %.1fs before death notice", died-checked)
end
local function TooltipIcon(self)
    if not self:IsVisible() or not ValidHover() then Hide(true); return end
    hovered=true; Paint(); Attention()
    if not GameTooltip then return end
    local page=previewPage or token.page
    GameTooltip:SetOwner(self,"ANCHOR_TOP")
    GameTooltip:SetText(self.row.name)
    GameTooltip:AddLine("Available when checked",1,1,1)
    GameTooltip:AddLine(Age(self.row,page),.7,.7,.75,true)
    if self.row.kind=="stone"and self.row.remainingUses then GameTooltip:AddLine("Uses remaining when checked: "..self.row.remainingUses,.7,.7,.75,true)end
    if self.row.detail then GameTooltip:AddLine(self.row.detail,.7,.7,.75,true) end
    GameTooltip:AddLine(previewPage and "Preview · click to open the sample log" or "Click to open Death Log",.7,.7,.75,true)
    GameTooltip:Show()
end
local function Populate(rows)
    HideTooltip()
    for _, icon in ipairs(button.icons) do icon:Hide(); icon.row=nil; icon.overflow=nil; icon:SetScript("OnClick",nil) end
    RA:SetVisualText(button.label,previewPage and "Death Log · Preview" or "Death Log")
    button.previewClose:SetShown(previewPage~=nil);button.chevron:SetShown(previewPage==nil)
    local items=0;for _,row in ipairs(rows)do if row.kind then items=items+1 end end
    local total=#rows*ICON_SIZE+math.max(0,#rows-1)*ICON_GAP+(items>0 and #rows>items and ITEM_GAP-ICON_GAP or 0)
    local titleWidth=Number(Call(button.label,"GetUnboundedStringWidth"))or Number(Call(button.label,"GetStringWidth"))or 0
    local headerWidth=36+titleWidth+(previewPage and 34 or 24)
    local width=math.min(CARD_MAX,math.max(CARD_MIN,math.ceil((total+16)/4)*4,math.ceil(headerWidth/4)*4))
    local lines,line={{width=0}}
    line=lines[1]
    for index,row in ipairs(rows)do
        local startsItems=row.kind and(index==1 or not rows[index-1].kind)
        local gap=#line>0 and(startsItems and ITEM_GAP or ICON_GAP)or 0
        local needed=startsItems and(items*ICON_SIZE+math.max(0,items-1)*ICON_GAP)or ICON_SIZE
        if #line>0 and line.width+gap+needed>width-16 then line={width=0};lines[#lines+1]=line;gap=0 end
        line[#line+1]={row=row,x=line.width+gap};line.width=line.width+gap+ICON_SIZE
    end
    T.SetSize(button,width,#rows==0 and 32 or CARD_HEIGHT+(#lines-1)*(ICON_SIZE+ICON_GAP))
    button.label:SetWidth(width-36-(previewPage and 34 or 24))
    local headerY=#rows==0 and 7 or 6
    button.logo:ClearAllPoints();T.SetPoint(button.logo,"TOPLEFT",button,"TOPLEFT",10,-headerY)
    button.label:ClearAllPoints();T.SetPoint(button.label,"TOPLEFT",button,"TOPLEFT",36,-headerY)
    button.chevron:ClearAllPoints();T.SetPoint(button.chevron,"TOPRIGHT",button,"TOPRIGHT",-8,-headerY)
    button.previewClose:ClearAllPoints();T.SetPoint(button.previewClose,"TOPRIGHT",button,"TOPRIGHT",-6,-headerY+1)
    local index=0
    for lineIndex,strip in ipairs(lines)do for _,item in ipairs(strip)do
        index=index+1
        local icon=button.icons[index]
        if not icon then
            icon=CreateFrame("Button",nil,button);button.icons[index]=icon;icon.entryOwner=button
            icon:RegisterForClicks("LeftButtonUp");T.SetSize(icon,ICON_SIZE,ICON_SIZE)
            icon.texture=icon:CreateTexture(nil,"ARTWORK");icon.texture:SetAllPoints(icon);icon.texture:SetTexCoord(.08,.92,.08,.92)
            icon:SetScript("OnEnter",TooltipIcon)
            icon:SetScript("OnLeave",function()hovered=false;HideTooltip();Paint();Attention()end)
        end
        icon.row=item.row
        icon:ClearAllPoints();T.SetPoint(icon,"TOPLEFT",button,"TOPLEFT",(width-strip.width)/2+item.x,-28-(lineIndex-1)*(ICON_SIZE+ICON_GAP))
        if item.row.spellID then RA:RegisterSpellIcon(icon.texture,item.row.spellID)
        else RA:RegisterVisualTexture(icon.texture,item.row.icon or(item.row.kind=="stone"and"Interface\\Icons\\INV_Stone_04"or"Interface\\Icons\\INV_Potion_51"),T.Assets.White) end
        icon.texture:SetVertexColor(1,1,1);icon.texture:SetDesaturated(false);icon:Show()
    end end
end
local function EnsureButton()
    if button and button.entryConfigured then return true end
    if not button then button = CreateFrame("Button", "RCPArsenalDeathRecapEntry", UIParent); button:Hide() end
    if not Mutable(button) then return false end
    button:SetFrameStrata("DIALOG"); button:SetFrameLevel(100); button:RegisterForClicks("LeftButtonUp")
    T.SetSize(button, CARD_MIN, CARD_HEIGHT)
    T:ApplyRounded(button, C.surfaceRaised, 6, "base")
    T:ApplyRounded(button, {C.magenta[1], C.magenta[2], C.magenta[3], .45}, 6, "border", "OVERLAY")
    button.logo = button:CreateTexture(nil, "ARTWORK")
    T.SetSize(button.logo, 18, 18); T.SetPoint(button.logo, "TOPLEFT", button, "TOPLEFT", 10, -6)
    button.logo:SetVertexColor(1, 1, 1)
    T:RegisterAssetTexture(button.logo, T.Assets.HeaderLogo, nil, "LINEAR")
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    RA:ApplyFont(button.label, 13, "BOLD", false)
    button.label:SetWordWrap(false);button.label:SetMaxLines(1)
    button.label:SetTextColor(unpack(C.text)); button.label:SetJustifyH("LEFT")
    T.SetSize(button.label, CARD_MIN-60, 18); T.SetPoint(button.label, "TOPLEFT", button, "TOPLEFT", 36, -6)
    RA:SetVisualText(button.label, "Death Log")
    button.chevron=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");RA:ApplyFont(button.chevron,16,"REGULAR",false)
    button.chevron:SetTextColor(unpack(C.muted));T.SetSize(button.chevron,8,18);T.SetPoint(button.chevron,"TOPRIGHT",button,"TOPRIGHT",-8,-6);RA:SetVisualText(button.chevron,"›")
    button.icons={}
    button.previewClose=CreateFrame("Button",nil,button);T.SetSize(button.previewClose,20,20);T.SetPoint(button.previewClose,"TOPRIGHT",button,"TOPRIGHT",-6,-6)
    button.previewClose.label=button.previewClose:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");button.previewClose.label:SetAllPoints(button.previewClose);RA:ApplyFont(button.previewClose.label,14,"REGULAR",false);RA:SetVisualText(button.previewClose.label,"×")
    button.previewClose:SetScript("OnClick",function()Entry:HidePreview()end);button.previewClose:Hide()
    button.glow = CreateFrame("Frame", nil, button)
    button.glow:EnableMouse(false)
    T.SetPoint(button.glow, "TOPLEFT", button, "TOPLEFT", -2, 2)
    T.SetPoint(button.glow, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    T:ApplyRounded(button.glow, {C.magenta[1], C.magenta[2], C.magenta[3], 1}, 6, "border", "OVERLAY")
    button.glow:SetAlpha(.10); button.glow:Hide()
    button.pulse = button.glow:CreateAnimationGroup(); button.pulse:SetLooping("REPEAT")
    for order, values in ipairs({{.10, .22}, {.22, .10}}) do
        local animation = button.pulse:CreateAnimation("Alpha")
        animation:SetOrder(order); animation:SetDuration(1.4)
        animation:SetFromAlpha(values[1]); animation:SetToAlpha(values[2]); animation:SetSmoothing("IN_OUT")
    end
    button:SetScript("OnHide", function() StopGlow(); HideTooltip(); hovered = false end)
    button:SetScript("OnEnter", function(self)
        if not ValidHover() then Hide(true); return end
        hovered = true; Paint(); Attention()
        local text = previewPage and "Preview · open the sample Death Log." or "Open your captured log."
        local page = previewPage or token.page
        local rows=button.boundRows
        if not previewPage and rows and #rows==0 then text=text.." "..(rows.hadCheck and"No availability confirmed."or"Availability was not recorded.")end
        if not previewPage and not page.native then
            text = text .. (R:GetDiagnostics().fetchPending and " Hit details are loading." or " Hit details are unavailable.")
        end
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(text);GameTooltip:AddLine("Shown icons were available when checked. Other checks may be missing or uncertain.",.7,.7,.75,true); GameTooltip:Show() end
    end)
    button:SetScript("OnLeave", function() hovered = false; HideTooltip(); Paint(); Attention() end)
    button:SetScript("OnMouseDown", function() T:SetRoundedColor(button, C.surfacePressed, "base") end)
    button:SetScript("OnMouseUp", Paint)
    button.entryConfigured = true
    return true
end
local function Bounds(frame)
    if not Accessible(frame) then return nil end
    local scale = Number(Call(frame, "GetEffectiveScale"))
    local left, right = Number(Call(frame, "GetLeft")), Number(Call(frame, "GetRight"))
    local top, bottom = Number(Call(frame, "GetTop")), Number(Call(frame, "GetBottom"))
    if not scale or scale <= 0 or not left or not right or not top or not bottom or right <= left or top <= bottom then return nil end
    return {left=left*scale, right=right*scale, top=top*scale, bottom=bottom*scale}
end
local function Place(host)
    if not Mutable(button) then return false end
    local bounds, screen = Bounds(host), Bounds(UIParent)
    local scale = Number(Call(UIParent, "GetEffectiveScale"))
    if not bounds or not screen or not scale or scale <= 0 then return false end
    local w, h, gap, clearance = button:GetWidth()*scale, button:GetHeight()*scale, 8*scale, 10*scale
    local middle = (bounds.left + bounds.right)/2
    local function Fits(left, right, bottom, top)
        return left >= screen.left+clearance and right <= screen.right-clearance
            and bottom >= screen.bottom+clearance and top <= screen.top-clearance
    end
    local above=Fits(middle-w/2,middle+w/2,bounds.top+gap,bounds.top+gap+h)
    if not above and not Fits(middle-w/2,middle+w/2,bounds.bottom-gap-h,bounds.bottom-gap)then return false end
    button:ClearAllPoints()
    if above then T.SetPoint(button,"BOTTOM",host,"TOP",0,8)else T.SetPoint(button,"TOP",host,"BOTTOM",0,-8)end
    layoutHost, placement = host, above and "above"or"below"
    return true
end
local function RefreshNow()
    if previewPage then
        if Global(InCombatLockdown)~=false or button and not Mutable(button)then previewPage=nil;SubscriptionDemand();Hide(true);return end
        if Call(UI,"IsShown")~=false or not EnsureButton() then Hide(true); return end
        if button.boundRows~=previewPage.available then Populate(previewPage.available);button.boundRows=previewPage.available end
        button:ClearAllPoints();T.SetPoint(button,"CENTER",UIParent,"CENTER",0,80)
        anchor=nil;binding=binding+1
        local expectedPage,expectedBinding=previewPage,binding
        local function Open(self)
            if previewPage~=expectedPage or binding~=expectedBinding or not button:IsVisible() or not Mutable(button)or Global(InCombatLockdown)~=false
                or self and self~=button and not self:IsVisible() then return end
            previewPage=nil;SubscriptionDemand();Hide(true);UI:Preview()
        end
        button:SetScript("OnClick",Open)
        for _,icon in ipairs(button.icons)do if icon:IsShown()then icon:SetScript("OnClick",Open)end end
        Paint();button:Show();StopGlow();return
    end
    if not hooks.StaticPopup_Show or not hooks.StaticPopup_OnShow or not hooks.StaticPopup_OnHide then Hide(true); return end
    if not Current() then Hide(true); return end
    local host = Host()
    if not host then Hide(true); return end
    if Call(UI, "IsShown") ~= false then Hide(false); return end
    if not EnsureButton() then Hide(true); return end
    if button.boundRows~=token.available then Populate(token.available);button.boundRows=token.available end
    if not Place(host) then Hide(true); return end
    anchor = host; binding = binding + 1
    local clickBinding, clickToken = binding, token
    local function Open(self)
        if clickBinding ~= binding or clickToken ~= token or anchor ~= host or not Current()
            or Host() ~= host or Call(UI, "IsShown") ~= false or self and self~=button and not self:IsVisible() then return end
        if UI:ShowLast() == true and token == clickToken then token.viewed = true end
        Entry:Refresh()
    end
    button:SetScript("OnClick",Open)
    for _,icon in ipairs(button.icons)do if icon:IsShown()then icon:SetScript("OnClick",Open)end end
    Paint(); button:Show(); Attention()
end
function Entry:Refresh()
    local ok = pcall(RefreshNow)
    if not ok then pcall(Hide, true) end
end
function Entry:HidePreview()
    previewPage=nil;SubscriptionDemand();Hide(true);self:Refresh()
end
function Entry:Preview()
    if Global(InCombatLockdown)~=false then return false end
    if previewPage then self:HidePreview();return true end
    Hide(true)
    previewPage={diedAt=100,lastAlive={spells={
        {spellID=45438,name="Ice Block",known=true,category="major",cooldown="inactive",chargeQuery="not_applicable",cooldownAt=99},
        {spellID=55342,name="Mirror Image",known=true,category="minor",role="defensive",defensiveTalentSpellID=1309497,cooldown="inactive",chargeQuery="not_applicable",cooldownAt=98.4},
    },supplies={
        {kind="stone",itemID=5512,physicalCount=1,remainingUses=1,cooldown="inactive",cooldownAt=99},
        {kind="potion",itemID=241304,physicalCount=1,cooldown="inactive",cooldownAt=99},
    }}}
    previewPage.available=self:GetAvailableRows(previewPage)
    SubscriptionDemand()
    if Call(UI,"IsShown")==true then UI:Hide()end
    self:Refresh();return button and button:IsShown()or false
end
previewCombat=RA:RegisterOptionalEvent("PLAYER_REGEN_DISABLED",function()
    if previewPage then Entry:HidePreview()end
end)
local function InstallHooks()
    if type(hooksecurefunc) ~= "function" then return end
    local callbacks = {
        StaticPopup_Show = function(which)
            if token and Public(which) == "DEATH" then Entry:Refresh() end
        end,
        StaticPopup_OnShow = function(dialog)
            dialog = Accessible(dialog)
            if token and dialog and (Read(dialog, "which") == "DEATH" or dialog == anchor) then Entry:Refresh() end
        end,
        StaticPopup_OnHide = function(dialog)
            dialog = Public(dialog)
            if dialog and (dialog == anchor or dialog == layoutHost) then Hide(true) end
        end,
    }
    for name, callback in pairs(callbacks) do
        if not hooks[name] and type(_G[name]) == "function" then
            local ok = pcall(hooksecurefunc, name, function(...) pcall(callback, ...) end)
            if ok then hooks[name] = true end
        end
    end
    if hookDemand and hooks.StaticPopup_Show and hooks.StaticPopup_OnShow and hooks.StaticPopup_OnHide then hookDemand:SetEnabled(false) end
end
local function Settings()
    local enabled = Enabled()
    SubscriptionDemand()
    if not enabled then Clear() end
    InstallHooks(); Entry:Refresh()
end
for _, event in ipairs({"PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT"}) do
    subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent(event, function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            local debug = RA.DeathRecapDebug
            if debug and type(debug.StopCooldownCapture) == "function" then pcall(debug.StopCooldownCapture, debug, "world-transition") end
        end
        Clear()
    end)
end
for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
    subscriptions[#subscriptions+1] = RA:RegisterOptionalEvent(event, function() Entry:Refresh() end)
end
hookDemand = RA:RegisterOptionalEvent("ADDON_LOADED", InstallHooks)
RA:RegisterInitializer(function() hookDemand:SetEnabled(true); Settings() end)
RA:RegisterCallback("DEATH_RECAP_CHANGED", function(kind)
    if kind == "death" then
        previewPage=nil
        local page = R:GetPage()
        if Enabled() and OwnDeath() and type(page) == "table" and Number(page.id) and Number(page.captureGeneration) then
            if not token or token.page ~= page or token.generation ~= page.captureGeneration then
                Hide(true)
                token = {page=page, id=page.id, generation=page.captureGeneration,
                    available=Entry:GetAvailableRows(page),viewed=shownPage == page and Call(UI, "IsShown") == true}
            end
        else Clear() end
    elseif kind == "life" or kind == "reset" or kind == "unavailable" then Clear()
    elseif kind == "settings" then Settings(); return end
    Entry:Refresh()
end)
RA:RegisterCallback("DEATH_RECAP_VISIBILITY", function(shown, page)
    local visible = Call(UI, "IsShown") == true
    shownPage = shown == true and visible and page or nil
    if shown == true and visible and Current() and page == token.page then token.viewed = true end
    Entry:Refresh()
end)
RA:RegisterCallback("PROFILE_RESET", function() Clear(); Settings() end)
RA:RegisterCallback("PROFILE_IMPORTED", function() Clear(); Settings() end)
RA:RegisterCallback("ACCENT_THEME_CHANGED", function() Paint() end)
