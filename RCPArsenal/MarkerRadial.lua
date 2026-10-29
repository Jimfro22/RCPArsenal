local _, RA = ...
local Radial = {}
RA.MarkerRadial = Radial

local cycle, wheel, root, center, preview
local bindingSnapshot
local status = "Optional wheel is off. Place next stays instant."
local DEADZONE, RADIUS, SIZE, VISUAL_LIMIT = 28.01, 92, 282, 10
local originX, originY, originScale, visualAge
local originLeft, originBottom, originWidth, originHeight
local hadSelection

-- This action belongs only to WheelBinding. The primary cycle never calls it.
local ROUTE_RELEASE = [[
    local key = self:GetAttribute("rcp-wheel-key")
    if key then
        for mask = 0, 7 do
            local chord = key
            if mask % 2 == 1 then chord = "SHIFT-" .. chord end
            if math.floor(mask / 2) % 2 == 1 then chord = "CTRL-" .. chord end
            if mask >= 4 then chord = "ALT-" .. chord end
            self:SetBindingClick(true, chord, self:GetName(), "LeftButton")
        end
    end
]]
local RESET = [[
    local reason = ...
    local drain = reason ~= "release" and reason ~= "force"
        and (self:GetAttribute("rcp-wheel-held") or self:GetAttribute("rcp-wheel-cancelled"))
    self:SetAttribute("rcp-wheel-held", nil)
    self:SetAttribute("rcp-wheel-cancelled", drain and true or nil)
    self:SetAttribute("macrotext", nil)
    self:ClearBindings()
    if drain then self:RunAttribute("rcp-wheel-release-routes") end
    self:GetFrameRef("root"):Hide()
    self:CallMethod("RCPWheelEndPreview")
]]
local CLICK = [[
    if self:GetAttribute("rcp-wheel-cancelled") then
        if not down then self:RunAttribute("rcp-wheel-reset", "release") end
        return false
    end
    if not self:GetAttribute("enabled") or self:GetAttribute("rcp-input-suppressed")
        or self:GetAttribute("state-rcp-wheel-context") == "blocked" then return false end
    local root = self:GetFrameRef("root")
    if down then
        if self:GetAttribute("rcp-wheel-held") then return false end
        local x,y = root:GetMousePosition()
        local left,bottom,width,height = root:GetRect()
        local scale = root:GetEffectiveScale()
        if not x or not y or not left or not bottom or not width or not height or not scale or scale <= 0 then return false end
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("rcp-wheel-held", true)
        self:SetAttribute("rcp-origin-x", x)
        self:SetAttribute("rcp-origin-y", y)
        self:SetAttribute("rcp-origin-left", left)
        self:SetAttribute("rcp-origin-bottom", bottom)
        self:SetAttribute("rcp-origin-width", width)
        self:SetAttribute("rcp-origin-height", height)
        self:SetAttribute("rcp-origin-scale", scale)
        local center = self:GetFrameRef("center")
        center:ClearAllPoints()
        center:SetPoint("CENTER", root, "BOTTOMLEFT", x*width, y*height)
        self:RunAttribute("rcp-wheel-release-routes")
        for mask = 0, 7 do
            local prefix = ""
            if mask % 2 == 1 then prefix = "SHIFT-" .. prefix end
            if math.floor(mask / 2) % 2 == 1 then prefix = "CTRL-" .. prefix end
            if mask >= 4 then prefix = "ALT-" .. prefix end
            self:SetBindingClick(true, prefix .. "ESCAPE", "RCPArsenalWorldMarkerCancel", "LeftButton")
            self:SetBindingClick(true, prefix .. "BUTTON2", "RCPArsenalWorldMarkerCancel", "LeftButton")
        end
        root:Show()
        self:CallMethod("RCPWheelBeginPreview", left+x*width, bottom+y*height, scale, left, bottom, width, height)
        return false
    end
    if not self:GetAttribute("rcp-wheel-held") then return false end
    local x,y = root:GetMousePosition()
    local left,bottom,width,height = root:GetRect()
    local marker
    if x and y and left == self:GetAttribute("rcp-origin-left") and bottom == self:GetAttribute("rcp-origin-bottom")
        and width == self:GetAttribute("rcp-origin-width") and height == self:GetAttribute("rcp-origin-height")
        and root:GetEffectiveScale() == self:GetAttribute("rcp-origin-scale") then
        local dx = (x-self:GetAttribute("rcp-origin-x"))*width
        local dy = (y-self:GetAttribute("rcp-origin-y"))*height
        local radius = self:GetAttribute("rcp-wheel-deadzone")
        if dx*dx+dy*dy > radius*radius then
            marker = (math.floor((math.atan2(dx,dy)+math.pi/8)/(math.pi/4)) % 8)+1
        end
    end
    self:RunAttribute("rcp-wheel-reset", "release")
    if not marker then return false end
    local cycle = self:GetFrameRef("cycle")
    local macro = "/wm " .. marker
    self:SetAttribute("macrotext", macro)
    cycle:SetAttribute("rcp-issued-" .. marker, true)
    cycle:SetAttribute("rcp-pending-marker", marker)
    cycle:CallMethod("RCPMarkerTrace", "wheel", marker, 0, macro)
]]
local CANCEL = [[
    if down then
        local wheel = self:GetFrameRef("wheel")
        if wheel:GetAttribute("rcp-wheel-held") then wheel:RunAttribute("rcp-wheel-reset") end
    end
    return false
]]
local HIDE = [[
    if control:GetAttribute("rcp-wheel-held") then control:RunAttribute("rcp-wheel-reset") end
]]
local CONTEXT = [[
    if name == "state-rcp-wheel-context" and value == "blocked" then self:RunAttribute("rcp-wheel-reset") end
]]
local function Text(region,value)
    if RA.SetVisualText then RA:SetVisualText(region,value) else region:SetText(value) end
end
local function Label(parent,size)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    if RA.ApplyFont then RA:ApplyFont(label,size,"REGULAR",true) end
    return label
end
local fallbackColors={canvasDeep={.021,.022,.046,1},surface={.065,.070,.120,1},
    surfaceHover={.108,.105,.175,1},text={.965,.955,.985,1},textSoft={.790,.765,.835,1},
    lineStrong={.870,.765,.950,1}}
local function Color(name)
    return RA.Theme and RA.Theme.Colors[name] or fallbackColors[name]
end
local function Tint(texture,color,alpha)
    texture:SetVertexColor(color[1],color[2],color[3],alpha or color[4] or 1)
end
local function ArtSize(region,width,height)
    if RA.Theme and RA.Theme.SetSize then RA.Theme.SetSize(region,width,height)else region:SetSize(width,height)end
end
local function ArtPoint(region,...)
    if RA.Theme and RA.Theme.SetPoint then RA.Theme.SetPoint(region,...)else region:SetPoint(...)end
end
local function Mask(parent,name,angle,layer,sublevel,size)
    local texture=parent:CreateTexture(nil,layer,nil,sublevel)
    ArtSize(texture,size or SIZE,size or SIZE);ArtPoint(texture,"CENTER",parent,"CENTER",0,0)
    local path=(RA.Theme and RA.Theme.MediaPath or "Interface\\AddOns\\RCPArsenal\\Media\\")..name
    if RA.SetVisualTexture then RA:SetVisualTexture(texture,path)else texture:SetTexture(path)end
    -- Inverse clockwise rotation in image UV space (UL, LL, UR, LR). This
    -- preserves the 282-unit art scale and the north/east/south/west mapping.
    -- Padded transparent edges remain clear when UVs extend beyond the image.
    local c,s=math.cos(angle or 0),math.sin(angle or 0)
    texture:SetTexCoord(.5-(c+s)/2,.5+(s-c)/2,.5+(s-c)/2,.5+(s+c)/2,
        .5+(c-s)/2,.5-(s+c)/2,.5+(c+s)/2,.5+(c-s)/2)
    return texture
end
local function RefreshAccent()
    if not center then return end
    local accent=RA.Theme and RA.Theme:GetAccentEnd() or Color("text")
    for _,slot in ipairs(center.slots)do Tint(slot.edge,accent,1)end
end
local function Selection(selected,returned)
    for id,slot in ipairs(center.slots)do
        local alpha=selected==id and 1 or 0
        slot.icon:SetAlpha(selected and selected~=id and .72 or 1)
        slot.highlight:SetAlpha(alpha);slot.edge:SetAlpha(alpha);slot.chevron:SetAlpha(alpha)
        for _,corner in ipairs(slot.corners)do corner:SetAlpha(alpha)end
    end
    center.hubBorder:SetAlpha(returned and .95 or .52)
end
local function RecoveryCue()
    if not center then return end
    preview:SetScript("OnUpdate",nil)
    Selection(nil,false)
    Text(center.caption,"Preview paused · wheel armed · Esc cancels")
end
local function UpdatePreview(_,elapsed)
    visualAge=visualAge+elapsed
    if visualAge>=VISUAL_LIMIT then RecoveryCue();return end
    local left,bottom,width,height=root:GetRect()
    if left~=originLeft or bottom~=originBottom or width~=originWidth or height~=originHeight or root:GetEffectiveScale()~=originScale then
        RecoveryCue();return
    end
    local x,y=GetCursorPosition()
    local px,py=x/originScale,y/originScale
    local outside=px<left or py<bottom or px>left+width or py>bottom+height
    local dx,dy=px-originX,py-originY
    local selected
    if not outside and dx*dx+dy*dy>DEADZONE*DEADZONE then
        selected=(math.floor((math.atan2(dx,dy)+math.pi/8)/(math.pi/4))%8)+1
    end
    if selected then hadSelection=true end
    Selection(selected,not selected and (hadSelection or outside))
    Text(center.caption,selected and RA.WorldMarkers.Definitions[selected].name.." · release to aim; click ground"
        or (hadSelection or outside) and "Release, Esc or right-click to cancel" or "Swipe to choose · center cancels")
end
local function Create()
    wheel=CreateFrame("Button","RCPArsenalWorldMarkerWheel",UIParent,"SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    wheel:SetSize(1,1);wheel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,0);wheel:EnableMouse(false)
    wheel:RegisterForClicks("AnyDown","AnyUp");wheel:SetAttribute("useOnKeyDown",false)
    wheel:SetAttribute("type","macro");wheel:SetAttribute("rcp-wheel-deadzone",DEADZONE)
    wheel:SetFrameRef("cycle",cycle);cycle:SetFrameRef("rcp-wheel",wheel)
    root=CreateFrame("Button","RCPArsenalWorldMarkerRadial",UIParent,"SecureHandlerBaseTemplate")
    root:SetAllPoints(UIParent);root:SetFrameStrata("FULLSCREEN_DIALOG");root:EnableMouse(true)
    root:RegisterForClicks("RightButtonDown","RightButtonUp")
    local passthrough={"LeftButton","MiddleButton"}
    for button=4,31 do passthrough[#passthrough+1]="Button"..button end
    root:SetPassThroughButtons(unpack(passthrough));root:SetFrameRef("wheel",wheel)
    SecureHandlerWrapScript(root,"OnClick",wheel,CANCEL);root:Hide()
    SecureHandlerWrapScript(root,"OnHide",wheel,HIDE)
    center=CreateFrame("Frame",nil,root,"SecureHandlerBaseTemplate")
    center:SetSize(SIZE,SIZE);center:EnableMouse(false)
    wheel:SetFrameRef("root",root);wheel:SetFrameRef("center",center)
    -- Non-clickable artwork. Clockwise from twelve o'clock: world-marker IDs
    -- 1 square, 2 triangle, 3 diamond, 4 cross, 5 star, 6 circle, 7 moon, 8 skull.
    center.cancelRegion=CreateFrame("Frame",nil,center)
    center.cancelRegion:SetSize(DEADZONE*2,DEADZONE*2);center.cancelRegion:SetPoint("CENTER");center.cancelRegion:EnableMouse(false)
    center.hub=Mask(center.cancelRegion,"RadialHub",0,"BACKGROUND",0,DEADZONE*2);Tint(center.hub,Color("canvasDeep"),.94)
    center.hubBorder=Mask(center.cancelRegion,"RadialHubBorder",0,"BORDER",0,DEADZONE*2);Tint(center.hubBorder,Color("textSoft"),1)
    center.origin=Mask(center.cancelRegion,"RadialHub",0,"ARTWORK",0,2);Tint(center.origin,Color("textSoft"),.6)
    center.slots={}
    for id,definition in ipairs(RA.WorldMarkers.Definitions)do
        local slot=CreateFrame("Frame",nil,center);slot:SetSize(42,42);slot:EnableMouse(false)
        local angle=(id-1)*math.pi/4
        slot:SetPoint("CENTER",center,"CENTER",math.sin(angle)*RADIUS,math.cos(angle)*RADIUS)
        slot.backing=Mask(center,"RadialSector",angle,"BACKGROUND",0);Tint(slot.backing,Color("surface"),.94)
        slot.highlight=Mask(center,"RadialSelection",angle,"BACKGROUND",1);Tint(slot.highlight,Color("surfaceHover"),1)
        slot.edge=Mask(center,"RadialSelectionEdge",angle,"BACKGROUND",2)
        slot.chevron=Mask(center,"RadialChevron",angle,"ARTWORK",0,32);Tint(slot.chevron,Color("text"),1)
        slot.chevron:ClearAllPoints()
        ArtPoint(slot.chevron,"CENTER",center,"CENTER",math.sin(angle)*43.893,math.cos(angle)*43.893)
        slot.corners={}
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do
            for _,vertical in ipairs({false,true})do
                local corner=slot:CreateTexture(nil,"OVERLAY")
                ArtSize(corner,vertical and 1.5 or 6,vertical and 6 or 1.5)
                ArtPoint(corner,"CENTER",slot,"CENTER",x*(vertical and 21 or 18.75),y*(vertical and 18.75 or 21))
                local color=Color("text");corner:SetColorTexture(color[1],color[2],color[3],1)
                slot.corners[#slot.corners+1]=corner
            end
        end end
        slot.icon=slot:CreateTexture(nil,"ARTWORK");slot.icon:SetSize(30,30);slot.icon:SetPoint("CENTER")
        local texture="Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..definition.icon
        if RA.SetVisualTexture then RA:SetVisualTexture(slot.icon,texture)else slot.icon:SetTexture(texture)end
        center.slots[id]=slot
    end
    center.caption=Label(center,12);ArtSize(center.caption,264,16)
    ArtPoint(center.caption,"BOTTOM",center,"BOTTOM",0,2)
    center.caption:SetJustifyH("CENTER");center.caption:SetWordWrap(false)
    local color=Color("text");center.caption:SetTextColor(color[1],color[2],color[3],1)
    RefreshAccent();Selection(nil,false)
    preview=CreateFrame("Frame",nil,UIParent) -- presentation only; no protected changes
    wheel.RCPWheelBeginPreview=function(_,x,y,scale,left,bottom,width,height)
        originX,originY,originScale,visualAge=x,y,scale,0
        originLeft,originBottom,originWidth,originHeight=left,bottom,width,height
        hadSelection=false
        UpdatePreview(nil,0);preview:SetScript("OnUpdate",UpdatePreview)
    end
    wheel.RCPWheelEndPreview=function()preview:SetScript("OnUpdate",nil)end
    local cancel=CreateFrame("Button","RCPArsenalWorldMarkerCancel",UIParent,"SecureHandlerBaseTemplate")
    cancel:SetSize(1,1);cancel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,0);cancel:EnableMouse(false)
    cancel:RegisterForClicks("AnyDown","AnyUp");cancel:SetFrameRef("wheel",wheel)
    SecureHandlerWrapScript(cancel,"OnClick",wheel,CANCEL)
    wheel:SetAttribute("rcp-wheel-release-routes",ROUTE_RELEASE);wheel:SetAttribute("rcp-wheel-reset",RESET)
    SecureHandlerWrapScript(wheel,"OnClick",wheel,CLICK)
    SecureHandlerWrapScript(wheel,"OnAttributeChanged",wheel,CONTEXT)
end
local function BindingValue(value)
    if type(issecretvalue)~="function" then return false end
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret~=false then return false end
    if value==nil or type(value)=="string" then return value end
    return false
end
local function BaseKey(value)
    if value==nil then return nil end
    if type(value)~="string" or value=="" or #value>96 or value:find("[%z\r\n]")then return false end
    local key=value:upper();local before
    repeat before=key;key=key:gsub("^ALT%-",""):gsub("^CTRL%-",""):gsub("^SHIFT%-","")until before==key
    if key=="LEFTBUTTON"then key="BUTTON1"elseif key=="RIGHTBUTTON"then key="BUTTON2"elseif key=="MIDDLEBUTTON"then key="BUTTON3"end
    if key=="" or key:find("WHEEL",1,true)or key=="BUTTON1"or key=="BUTTON2"or key=="ESCAPE"then return false end
    return key
end
local function ReadBindings()
    local values={}
    for _,action in ipairs({RA.WorldMarkers.WheelBinding,RA.WorldMarkers.PlaceBinding,RA.WorldMarkers.ClearBinding})do
        local ok,first,second,extra=pcall(GetBindingKey,action)
        if not ok or BindingValue(extra)~=nil then values[#values+1]={false,false}
        else values[#values+1]={BindingValue(first),BindingValue(second)}end
    end
    return values
end
function Radial:NeedsBindingRefresh()
    local values=ReadBindings()
    if not bindingSnapshot then return true end
    for i=1,3 do for j=1,2 do if values[i][j]~=bindingSnapshot[i][j]then return true end end end
    return false
end
function Radial:Cancel()
    if InCombatLockdown()then return false end
    if wheel then SecureHandlerExecute(wheel,[[self:RunAttribute("rcp-wheel-reset","force")]])end
    return true
end
function Radial:SetInputSuppressed(value)
    if not InCombatLockdown()and wheel then wheel:SetAttribute("rcp-input-suppressed",value==true)end
end
function Radial:IsEnabled()return wheel and wheel:GetAttribute("enabled")==true or false end
function Radial:Configure(action,enabled)
    if InCombatLockdown()then return false end
    cycle=action;self:Cancel();bindingSnapshot=ReadBindings()
    local first,second=BaseKey(bindingSnapshot[1][1]),BaseKey(bindingSnapshot[1][2])
    local key=first or second
    local readable=true
    for i=1,3 do for j=1,2 do if bindingSnapshot[i][j]==false then readable=false end end end
    if not enabled then status="Optional wheel is off. Place next stays instant."
    elseif not readable then enabled=false;status="Wheel unavailable: binding keys unreadable. Place next stays instant."
    elseif first==false or second==false then enabled=false;status="Wheel needs a keyboard key or side button with a real release."
    elseif not key then enabled=false;status="Optional wheel unbound. Place next stays instant."
    elseif first and second and first~=second then enabled=false;status="Use one physical wheel key; modifier aliases of that key are supported."
    else
        for i=2,3 do for j=1,2 do
            if BaseKey(bindingSnapshot[i][j])==key then enabled=false;status="Wheel needs a different physical key from Place next and Clear."end
        end end
        if enabled then status="Hold the separate wheel key, swipe, release to aim, then click ground. Center release cancels."end
    end
    if enabled and not wheel then Create()end
    if wheel then
        wheel:SetAttribute("enabled",enabled==true);wheel:SetAttribute("rcp-wheel-key",enabled and key or nil)
        wheel:SetAttribute("rcp-input-suppressed",cycle:GetAttribute("rcp-input-suppressed"))
        if enabled then RegisterStateDriver(wheel,"rcp-wheel-context","[petbattle] blocked; [vehicleui] blocked; ready")
        else UnregisterStateDriver(wheel,"rcp-wheel-context");wheel:SetAttribute("state-rcp-wheel-context",nil)end
    end
    return enabled==true
end
function Radial:GetStatusText()return status end
local function RefreshEditorGuard()
    local editor=RA.MarkerBindings
    RA.WorldMarkers:SetInputSuppressed(editor and(editor:GetPending()~=nil or editor:GetHeldKey()~=nil)or false,"editor")
end
RA:RegisterCallback("MARKER_BINDINGS_CHANGED",RefreshEditorGuard)
RA:RegisterCallback("ACCENT_THEME_CHANGED",RefreshAccent)
RA:RegisterEvent("PLAYER_LEAVING_WORLD",function()if not Radial:Cancel()then RecoveryCue()end end)
RA:RegisterEvent("PLAYER_ENTERING_WORLD",function()if not Radial:Cancel()then RecoveryCue()end end)
