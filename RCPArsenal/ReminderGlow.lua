local _, RA = ...
local Glow = {}
RA.ReminderGlow = Glow

-- Independently authored native renderer. All inputs are ordinary appearance
-- constants. The caller owns a separate opaque-health alpha ancestor; this
-- module never reads or writes its alpha, visibility, health or interaction.
-- Only an owned OnHide cleanup hook; no OnUpdate, timers, animation-progress
-- queries or animation callbacks.
local ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
function Glow:GetExtent(settings,size)
    if settings.style=="BUTTON" then return size*0.2 end
    if settings.style=="PIXEL" then return (settings.pixelLength+settings.pixelThickness)/2 end
    if settings.style=="AUTOCAST" then return 3.5*settings.autocastSize/100 end
    return 4
end
local function Group(texture)
    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    return group
end
local function Animation(group, kind, order)
    local animation = group:CreateAnimation(kind)
    animation:SetOrder(order)
    return animation
end
local function Texture(owner)
    local texture = owner:CreateTexture(nil, "OVERLAY")
    texture:Hide()
    return texture
end

function Glow:Create(parent)
    local visual = CreateFrame("Frame", nil, parent)
    visual:SetAllPoints(parent); visual:EnableMouse(false); visual:Hide()
    local controller = {frame=visual, nodes={}, edges={}, active=false}

    function controller:Stop()
        if self.active then
            for _, node in ipairs(self.nodes) do node.group:Stop() end
            if self.button then self.button.group:Stop() end
        end
        self.active = false
        self.frame:Hide()
    end

    local function Edge(self, index, a, b, x, y, xx, yy, alpha, color)
        local texture = self.edges[index]
        if not texture then texture=Texture(visual); self.edges[index]=texture end
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT",visual,a,x,y); texture:SetPoint("BOTTOMRIGHT",visual,b,xx,yy)
        texture:SetColorTexture(color[1],color[2],color[3],alpha); texture:Show()
    end
    local function Steady(self, color)
        Edge(self,1,"TOPLEFT","TOPRIGHT",-4,4,4,0,0.18,color)
        Edge(self,2,"BOTTOMLEFT","BOTTOMRIGHT",-4,0,4,-4,0.18,color)
        Edge(self,3,"TOPLEFT","BOTTOMLEFT",-4,0,0,0,0.18,color)
        Edge(self,4,"TOPRIGHT","BOTTOMRIGHT",0,0,4,0,0.18,color)
        Edge(self,5,"TOPLEFT","TOPRIGHT",0,0,0,-2,0.94,color)
        Edge(self,6,"BOTTOMLEFT","BOTTOMRIGHT",0,2,0,0,0.94,color)
        Edge(self,7,"TOPLEFT","BOTTOMLEFT",0,0,2,0,0.94,color)
        Edge(self,8,"TOPRIGHT","BOTTOMRIGHT",-2,0,0,0,0.94,color)
    end
    local function Node(self, index)
        local node = self.nodes[index]
        if node then return node end
        node = {texture=Texture(visual), translations={}, rotations={}}
        node.group = Group(node.texture)
        for side=1,4 do node.translations[side]=Animation(node.group,"Translation",side) end
        self.nodes[index]=node
        return node
    end
    local function Square(node, span, duration, rotate)
        local offsets = {{span,0},{0,span},{-span,0},{0,-span}}
        for side, offset in ipairs(offsets) do
            local move = node.translations[side]
            move:SetOffset(offset[1],offset[2]); move:SetDuration(duration)
            -- A native 90-degree turn at each corner, concurrent with the last
            -- millisecond of the side. Translation/rotation reset on repeat.
            local turn = node.rotations[side]
            if rotate and not turn then turn=Animation(node.group,"Rotation",side); node.rotations[side]=turn end
            if turn then
                turn:SetDegrees(rotate and 90 or 0); turn:SetOrigin("CENTER",0,0)
                turn:SetStartDelay(duration-0.001); turn:SetDuration(0.001)
            end
        end
    end
    local function Moving(self, settings, size)
        local pixel = settings.style == "PIXEL"
        local count = pixel and settings.pixelLines or settings.autocastGroups*4
        for index=1,count do
            local node = Node(self,index)
            local tier = pixel and 1 or math.floor((index-1)/settings.autocastGroups)+1
            local thickness = pixel and settings.pixelThickness or 2
            local span = size-thickness
            local width = pixel and settings.pixelLength or (8-tier)*settings.autocastSize/100
            node.texture:ClearAllPoints()
            node.texture:SetPoint("CENTER",visual,"BOTTOMLEFT",thickness/2,thickness/2)
            node.texture:SetSize(width,pixel and thickness or width)
            if pixel then
                node.texture:SetVertexColor(1,1,1,1)
                node.texture:SetColorTexture(settings.color[1],settings.color[2],settings.color[3],1)
            else
                node.texture:SetTexture("Interface\\Cooldown\\star4")
                node.texture:SetVertexColor(settings.color[1],settings.color[2],settings.color[3],1)
            end
            node.texture:SetBlendMode(pixel and "BLEND" or "ADD")
            local duration = pixel and 1 or 2*tier
            Square(node,span,duration,pixel)
            node.group:SetAnimationSpeedMultiplier(pixel and settings.pixelSpeed or settings.autocastSpeed)
            node.offset = 4*duration*((index-1)%(pixel and count or settings.autocastGroups))/(pixel and count or settings.autocastGroups)
            node.texture:Show()
        end
        self.count=count
    end
    local function Button(self, settings, size)
        if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(ATLAS) then error("Proc atlas unavailable") end
        if not self.button then
            local texture = Texture(visual)
            local group = Group(texture)
            local flip = Animation(group,"FlipBook",1)
            flip:SetDuration(1); flip:SetFlipBookRows(6); flip:SetFlipBookColumns(5); flip:SetFlipBookFrames(30)
            flip:SetFlipBookFrameWidth(0); flip:SetFlipBookFrameHeight(0)
            self.button={texture=texture,group=group}
        end
        self.button.texture:SetAtlas(ATLAS)
        self.button.texture:SetDesaturated(true)
        self.button.texture:SetVertexColor(settings.color[1],settings.color[2],settings.color[3],1)
        self.button.texture:SetPoint("CENTER",visual,"CENTER",0,0)
        self.button.texture:SetSize(size*1.4,size*1.4)
        self.button.texture:Show()
        self.button.group:SetAnimationSpeedMultiplier(settings.buttonSpeed)
    end
    function controller:Configure(settings, size)
        -- Called only by a public refresh/edit/sample action, never health.
        local signature = table.concat({settings.style,unpack(settings.color)},":")
        for _,key in ipairs({"pixelLines","pixelSpeed","pixelLength","pixelThickness","buttonSpeed","autocastGroups","autocastSpeed","autocastSize"}) do signature=signature..":"..settings[key] end
        signature=signature..":"..size
        if signature == self.signature then return end
        self:Stop()
        for _,texture in ipairs(self.edges) do texture:Hide() end
        for _,node in ipairs(self.nodes) do node.texture:Hide() end
        if self.button then self.button.texture:Hide() end
        -- Prepare a bounded steady fallback before health hooks can Start.
        Steady(self,settings.color)
        if settings.style~="STEADY" then for _,texture in ipairs(self.edges) do texture:Hide() end end
        self.count=0; self.style=settings.style
        local ok=pcall(function()
            if settings.style=="PIXEL" or settings.style=="AUTOCAST" then Moving(self,settings,size)
            elseif settings.style=="BUTTON" then Button(self,settings,size)
            else Steady(self,settings.color) end
        end)
        if not ok then
            for _,node in ipairs(self.nodes) do node.texture:Hide() end
            if self.button then self.button.texture:Hide() end
            self.style="STEADY"; self.count=0
            Steady(self,settings.color)
        end
        self.signature=signature
    end
    function controller:Start()
        if self.active or not self.signature then return end
        -- Mark active before any native Play so even a partial failure cleans up.
        self.active=true
        local ok=pcall(function()
            if self.style=="BUTTON" then self.button.group:Play()
            else for index=1,self.count do local node=self.nodes[index]; node.group:Play(false,node.offset) end end
        end)
        if not ok then
            self:Stop()
            for _,node in ipairs(self.nodes) do node.texture:Hide() end
            if self.button then self.button.texture:Hide() end
            self.style="STEADY"; self.count=0
            for _,texture in ipairs(self.edges) do texture:Show() end
            self.active=true
        end
        self.frame:Show()
    end
    visual:SetScript("OnHide",function() controller:Stop() end)
    return controller
end
