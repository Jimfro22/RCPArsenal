local _,RA=...
local UI,T=RA.DeathRecapUI,RA.Theme
local dialog
local function Number(value)
    if type(issecretvalue)~="function"then return nil end
    local ok,secret=pcall(issecretvalue,value)
    if ok and secret==false and type(value)=="number"and value==value and math.abs(value)~=math.huge then return value end
end
local function Text(parent,value,size,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    RA:ApplyFont(f,size,"REGULAR",false);f:SetJustifyH("LEFT");f:SetTextColor(unpack(T.Colors.text))
    T.SetPoint(f,"TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);RA:SetVisualText(f,value);return f
end
local function Scroll(value)
    value=Number(value);if not value then return end
    local maximum=math.max(0,dialog.bodyHeight-dialog.visibleHeight)
    dialog.offset=math.max(0,math.min(maximum,value));dialog.scroll:SetVerticalScroll(dialog.offset)
end
local function Button(text,x,fn)
    local b=CreateFrame("Button",nil,dialog);T.SetSize(b,120,28);T.SetPoint(b,"BOTTOMLEFT",dialog,"BOTTOMLEFT",x,16)
    T:ApplyRounded(b,T.Colors.surfaceRaised,6,"base");b.label=Text(b,text,11,10,-8,100);b:SetScript("OnClick",fn);return b
end
function UI:ShowDebugText(text)
    if type(issecretvalue)~="function"then return false,"Trust check unavailable"end
    local ok,secret=pcall(issecretvalue,text)
    if not ok or secret~=false or type(text)~="string"or #text>RA.DeathRecapDebug.LIMITS.text
        or text:find("|")or text:find("[%z\1-\8\11-\31\127]")then return false,"Debug text unavailable"end
    if not dialog then
        dialog=CreateFrame("Frame","RCPArsenalDeathRecapDebug",UIParent)
        T.SetSize(dialog,760,480);T.SetPoint(dialog,"CENTER",UIParent,"CENTER",0,0)
        dialog:SetFrameStrata("DIALOG");dialog:SetClampedToScreen(true);dialog:EnableMouse(true)
        T:ApplyRounded(dialog,T.Colors.canvasDeep,8,"base")
        Text(dialog,"Death Log diagnostics",18,20,-18,710)
        Text(dialog,"Read-only snapshot. Select all, then Ctrl+C to copy.",11,20,-47,710)
        dialog.scroll=CreateFrame("ScrollFrame",nil,dialog);T.SetSize(dialog.scroll,720,348)
        T.SetPoint(dialog.scroll,"TOPLEFT",dialog,"TOPLEFT",20,-74);dialog.scroll:SetClipsChildren(true)
        dialog.visibleHeight=348;dialog.scroll:EnableMouseWheel(true)
        dialog.scroll:SetScript("OnMouseWheel",function(_,delta)delta=Number(delta);if delta then Scroll((dialog.offset or 0)-delta*42)end end)
        dialog.box=CreateFrame("EditBox",nil,dialog.scroll);T.SetSize(dialog.box,700,348)
        dialog.box:SetMultiLine(true);dialog.box:SetAutoFocus(false);dialog.box:SetMaxLetters(65535)
        dialog.box:SetTextInsets(8,8,8,8);dialog.box:SetJustifyV("TOP");RA:ApplyFont(dialog.box,11,"REGULAR",false)
        dialog.scroll:SetScrollChild(dialog.box);dialog.box:EnableMouse(true)
        dialog.measure=Text(dialog,"",11,0,0,684);dialog.measure:SetWordWrap(true);dialog.measure:SetNonSpaceWrap(true);dialog.measure:SetMaxLines(0);dialog.measure:Hide()
        dialog.box:SetScript("OnTextChanged",function(self)
            if dialog.payload and self:GetText()~=dialog.payload then self:SetText(dialog.payload);self:HighlightText()end
        end)
        dialog.box:SetScript("OnCursorChanged",function(_,_,y,_,height)
            y=Number(y);height=Number(height);if not y then return end
            local top=math.max(0,-y);local offset=dialog.offset or 0
            if top<offset then Scroll(top)elseif top+(height or 16)>offset+dialog.visibleHeight then Scroll(top+(height or 16)-dialog.visibleHeight)end
        end)
        dialog.box:SetScript("OnEscapePressed",function()dialog:Hide()end)
        dialog:SetScript("OnHide",function()dialog.box:ClearFocus()end)
        dialog.select=Button("SELECT ALL",20,function()dialog.box:SetFocus();dialog.box:HighlightText()end)
        dialog.close=Button("CLOSE",620,function()dialog:Hide()end)
        if type(UISpecialFrames)=="table"then table.insert(UISpecialFrames,"RCPArsenalDeathRecapDebug")end
    end
    dialog.payload=text;dialog.measure:SetHeight(0);RA:SetVisualText(dialog.measure,text)
    local measured=Number(dialog.measure:GetStringHeight())
    local _,lines=text:gsub("\n","")
    dialog.bodyHeight=math.max(dialog.visibleHeight,measured and measured+24 or(lines+1)*16+24)
    dialog.box:SetHeight(dialog.bodyHeight);dialog.box:SetText(text);dialog.box:ClearFocus();Scroll(0)
    local width,height=Number(UIParent:GetWidth()),Number(UIParent:GetHeight())
    if width and height and width>40 and height>80 then dialog:SetScale(math.min(1,(width-40)/760,(height-80)/480))end
    dialog:Show();return true
end
