local _, RA = ...

-- Ordinary local editor only. RaidGroups owns identity, validation and all game actions.
function RA:CreateRaidGroupsPane(parent, kit)
    local T, C = self.Theme, self.Theme.Colors
    local Point, Size = T.SetPoint, T.SetSize
    local ui = {active=false, selected=nil, dragging=nil, consumed=false, slots={}, tray={}, groups={}, modalRows={}}
    parent.raidGroupsUI = ui
    local function Core() return RA.RaidGroups end
    local function Literal(value) return type(value)=="string" and value:gsub("|","||") or "" end
    local function SetText(region, value) RA:SetVisualText(region, Literal(value)) end
    local function Text(owner, value, size, x, y, width, color)
        local label=kit.Font(owner,size or 10,color or C.textSoft,"REGULAR")
        label:SetWordWrap(true);T.SetWidth(label,width or 918);Point(label,"TOPLEFT",owner,"TOPLEFT",x,y)
        SetText(label,value);return label
    end
    local function Enabled(button, enabled) enabled=enabled==true;button:SetEnabled(enabled);button:SetAlpha(enabled and 1 or 0.45) end
    local function Call(method,...)
        local core=Core()
        if not core or type(core[method])~="function" then return false,"Raid Groups is unavailable." end
        local ok,a,b=pcall(core[method],core,...)
        if not ok then return false,"Unable to update the planner. Try From raid again." end
        return a,b
    end
    local function Busy() return ui.state and ui.state.apply and ui.state.apply.status=="waiting" end
    local function Uncertain()
        local applying=ui.state and ui.state.apply
        return applying and applying.unknownResult==true and applying.recovered~=true
    end
    local function Locked() return Busy() or Uncertain() end
    local function Tip(owner, entry, target)
        if not GameTooltip or not entry then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText(Literal(entry.fullName or entry.name or "Unknown player"))
        local member=entry.guid and ui.members and ui.members[entry.guid]
        local class=member and member.class
        if class then GameTooltip:AddLine(Literal(class),0.8,0.8,0.85) end
        local role=member and member.role
        GameTooltip:AddLine(role=="TANK" and "Tank" or role=="HEALER" and "Healer" or role=="DAMAGER" and "Damage" or "Role unknown",0.8,0.8,0.85)
        GameTooltip:AddLine("Current: "..(entry.liveGroup and ("Group "..entry.liveGroup) or entry.absentPlaceholder and "Not in current raid" or "Identity not verified"),0.8,0.8,0.85)
        GameTooltip:AddLine("Draft: "..(target and ("Group "..target) or "Unassigned"),0.8,0.8,0.85)
        if entry.matchedFullName then GameTooltip:AddLine("Realm alias matched: "..Literal(entry.matchedFullName),0.8,0.8,0.85,true) end
        if entry.absentPlaceholder then GameTooltip:AddLine("Absent placeholder. Kept in this layout; skipped by Apply.",0.8,0.8,0.85,true)
        elseif entry.unusedPlaceholder then GameTooltip:AddLine("Unused template card. Kept in the tray; skipped when all current players have targets.",0.8,0.8,0.85,true)
        elseif entry.identityReason then GameTooltip:AddLine(Literal(entry.identityReason),1,0.65,0.25,true)
        elseif entry.unresolved then GameTooltip:AddLine("Unresolved identity. Use Match to choose a current raider.",1,0.65,0.25,true)
        elseif entry.missing then GameTooltip:AddLine("Absent from this raid. Right-click for local options.",0.8,0.8,0.85,true)
        elseif member and member.online==false then GameTooltip:AddLine("Offline",0.8,0.8,0.85) end
        GameTooltip:AddLine("Slots plan groups; raid frames may sort players differently.",0.7,0.7,0.8,true)
        GameTooltip:Show()
    end
    local Refresh, Prepare, Edit, ShowLoad, ShowImport, ShowResolve, ShowRecovery
    local saveStatus,sortButton,sortMenu
    local nameBox, status, applyButton, cancelButton, reviewButton, fromButton, reconcileButton, loadButton, saveButton, importButton, trayTitle, trayScroll, trayChild
    local function Message(value) ui.message=value or "";if status then SetText(status,ui.message) end end
    local function ClearPointer()
        ui.dragging=nil;ui.hover=nil
        if GameTooltip then GameTooltip:Hide() end
    end
    local function HideModal()
        if ui.modal then ui.modal:Hide() end
        ui.modalMode=nil;ui.resolveID=nil
    end
    local function ClearSelection() ui.selected=nil;ClearPointer() end
    local function ReviewContext(state)
        local model=state and state.draft;local live=state and state.live
        return table.concat({tostring(model and model.revision),live and live.fingerprint or "",state and state.liveError or "",
            tostring(live and live.canApply),live and live.reason or ""},"\n")
    end
    Prepare=function()
        ui.preparing=true
        local preview,reason=Call("PrepareApply")
        ui.preparing=false
        ui.prepareFailed=not preview or preview==false
        ui.prepareReason=ui.prepareFailed and (reason or "Review the draft before applying.") or nil
        ui.prepareContext=ui.prepareFailed and ReviewContext(ui.state) or nil
        if ui.prepareFailed then ui.message=reason or "Review the draft before applying." end
        return preview,reason
    end
    Edit=function(method,...)
        if Locked() then Message(Uncertain() and "Review the current raid before editing this draft." or "Cancel Apply before editing the draft.");return false end
        local ok,reason=Call(method,...)
        if ok then
            ui.message=reason or "Local draft updated."
            if method~="SaveLayout" and method~="DeleteLayout" then Prepare() end
            if method=="ImportAndSaveNote" then nameBox:SetText(reason) end
            if method=="FromCurrentRaid" then nameBox:SetText("") end
        else ui.message=reason or "Draft unchanged." end
        ui.feedback=nil
        if not ok then ui.feedback=ui.message elseif method=="SaveLayout" then ui.feedback="Layout saved locally." end
        if ok and method=="ImportAndSaveNote" then ui.feedback="Imported and saved locally as "..reason.."." end
        if ok and method=="SortDraft" then ui.feedback=reason end
        Refresh();return ok,reason
    end
    local function Move(group,slot)
        local id=ui.dragging or ui.selected
        if not id then return end
        ClearPointer();ui.selected=nil
        Edit("Move",id,group,slot)
    end
    local function DropTarget()
        -- Drag focus can remain on the source. Hit-test our bounded visible
        -- targets first, only at drop; there is no cursor polling/OnUpdate.
        local function Over(target)
            local frame=target and (target.frame or target)
            if not frame or not frame:IsVisible() or type(MouseIsOver)~="function" then return false end
            local ok,over=pcall(MouseIsOver,frame);return ok and over==true
        end
        if Over(sortMenu) then return end
        for group=1,8 do for slot=1,5 do
            local target=ui.slots[group][slot];if Over(target) then return target end
        end end
        if Over(trayScroll) then for _,target in ipairs(ui.tray)do if Over(target) then return target end end end
        if Over(trayChild) and Over(trayScroll) then return ui.dropOwners[trayChild] end
        if ui.hover and Over(ui.hover) then return ui.hover end
        if type(MouseIsOver)=="function" then return end
        if type(GetMouseFoci)=="function" then
            local ok,focus=pcall(GetMouseFoci)
            if ok and type(focus)=="table" then for _,frame in ipairs(focus) do
                for _=1,6 do
                    if ui.dropOwners and ui.dropOwners[frame] and frame.entryID~=ui.dragging then return ui.dropOwners[frame] end
                    local good,nextFrame=pcall(function()return frame and frame:GetParent()end)
                    if not good or not nextFrame then break end;frame=nextFrame
                end
            end end
        end
        if ui.hover and ui.hover.entryID~=ui.dragging then return ui.hover end
    end
    local function PointerDown() ui.consumed=false end
    local function MakeSlot(owner,width,height)
        local button=kit.Button(owner,"",width,height,function()end)
        button.label:Hide()
        button.name=Text(button,"",10.5,9,-3,width-36,C.text);button.name:SetWordWrap(false)
        button.roleIcon=button:CreateTexture(nil,"OVERLAY");Size(button.roleIcon,13,13);Point(button.roleIcon,"TOPRIGHT",button,"TOPRIGHT",-5,-2);button.roleIcon:Hide()
        button.detail=Text(button,"",8.8,9,-16,width-18,C.textSoft);button.detail:SetWordWrap(false)
        button.match=kit.Button(button,"MATCH",48,20,function()
            if not Locked() and button.entryID then ClearPointer();ui.selected=nil;ShowResolve(button.entryID) end
        end)
        Point(button.match,"TOPRIGHT",button,"TOPRIGHT",-4,-4);button.match:Hide()
        button.classStrip=button:CreateTexture(nil,"OVERLAY");Size(button.classStrip,2,height-6);Point(button.classStrip,"TOPLEFT",button,"TOPLEFT",2,-3)
        button:RegisterForClicks("LeftButtonUp","RightButtonUp");button:RegisterForDrag("LeftButton")
        ui.dropOwners=ui.dropOwners or {};ui.dropOwners[button]=button
        button:SetScript("OnMouseDown",PointerDown)
        button:SetScript("OnEnter",function(self)
            ui.hover=self
            local entry=ui.state and ui.state.view and ui.state.view.entries[self.entryID]
            Tip(self,entry,self.group)
        end)
        button:SetScript("OnLeave",function(self)
            if ui.hover==self then ui.hover=nil end
            if GameTooltip then GameTooltip:Hide() end
        end)
        button:SetScript("OnDragStart",function(self)
            if not Locked() and self.entryID then
                ui.selected=self.entryID;ui.dragging=self.entryID;ui.consumed=true
                Message("Moving "..(ui.state.view.entries[self.entryID].fullName or "player")..". Drop on a slot.")
                Refresh()
            end
        end)
        button:SetScript("OnDragStop",function()
            local target=DropTarget()
            if ui.dragging and target then Move(target.group,target.slot) else ClearPointer();Message("Drag cancelled. Draft unchanged.");Refresh() end
            ui.consumed=true
        end)
        button:SetScript("OnClick",function(self,mouse)
            if ui.consumed or Locked() then return end
            if mouse=="RightButton" and self.entryID then
                local entry=ui.state.view.entries[self.entryID]
                if entry and (entry.missing or entry.unresolved) then ShowResolve(self.entryID) end
            elseif ui.selected then
                if ui.selected==self.entryID then ui.selected=nil;Refresh() else Move(self.group,self.slot) end
            elseif self.entryID then ui.selected=self.entryID;Message("Selected "..(ui.state.view.entries[self.entryID].fullName or "player")..". Click a slot or drag.");Refresh() end
        end)
        return button
    end
    kit.Heading(parent,"Raid Groups","Draft locally; Apply changes raid groups, not raid-frame order.")
    Text(parent,"Layout / boss name",9.5,0,-48,280)
    nameBox=CreateFrame("EditBox",nil,parent,"BackdropTemplate");Size(nameBox,280,32);Point(nameBox,"TOPLEFT",parent,"TOPLEFT",0,-62)
    kit.Backdrop(nameBox,C.input,C.line,6,false);RA:ApplyFont(nameBox,11,"REGULAR",false)
    nameBox:SetTextInsets(9,9,0,0);nameBox:SetAutoFocus(false);nameBox:SetMaxLetters(80)
    if nameBox.SetHyperlinksEnabled then nameBox:SetHyperlinksEnabled(false) end
    nameBox:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    nameBox:SetScript("OnTextChanged",function()if Refresh then Refresh() end end)
    saveStatus=Text(parent,"New layout",9.5,290,-48,178,C.textSoft);ui.saveStatus=saveStatus
    loadButton=kit.Button(parent,"LOAD",84,32,function()ShowLoad()end);Point(loadButton,"TOPLEFT",parent,"TOPLEFT",290,-62)
    saveButton=kit.Button(parent,"SAVE",84,32,function()Edit("SaveLayout",nameBox:GetText())end);Point(saveButton,"TOPLEFT",parent,"TOPLEFT",384,-62)
    fromButton=kit.Button(parent,"FROM RAID",130,32,function()
        if Uncertain() then ShowRecovery() else ClearSelection();HideModal();Edit("FromCurrentRaid") end
    end);Point(fromButton,"TOPLEFT",parent,"TOPLEFT",478,-62)
    reconcileButton=kit.Button(parent,"UPDATE RAID",120,32,function()ClearSelection();Edit("Reconcile")end)
    Point(reconcileButton,"TOPLEFT",parent,"TOPLEFT",618,-62)
    importButton=kit.Button(parent,"IMPORT WOWUTILS",170,32,function()ShowImport()end);Point(importButton,"TOPLEFT",parent,"TOPLEFT",748,-62)
    for group=1,8 do
        local card=CreateFrame("Frame",nil,parent,"BackdropTemplate");Size(card,228,188)
        Point(card,"TOPLEFT",parent,"TOPLEFT",((group-1)%4)*240,-110-math.floor((group-1)/4)*200)
        kit.Backdrop(card,C.surface,C.line,7,false)
        Text(card,"Group "..group,11,9,-7,120,C.text)
        card.count=Text(card,"",9.5,153,-8,66);card.count:SetJustifyH("RIGHT")
        ui.groups[group]=card;ui.slots[group]={}
        for slot=1,5 do
            local button=MakeSlot(card,212,28);button.group,button.slot=group,slot
            Point(button,"TOPLEFT",card,"TOPLEFT",8,-32-(slot-1)*30);ui.slots[group][slot]=button
        end
    end
    trayTitle=Text(parent,"Unassigned",10,0,-508,680)
    sortButton=kit.Button(parent,"SORT DRAFT",170,20,function()
        if Locked() then return end
        if sortMenu then sortMenu:SetShown(not sortMenu:IsShown()) end
    end);Point(sortButton,"TOPLEFT",parent,"TOPLEFT",748,-504);ui.sortButton=sortButton
    sortMenu=CreateFrame("Frame",nil,parent,"BackdropTemplate");Size(sortMenu,250,148);Point(sortMenu,"BOTTOMRIGHT",sortButton,"TOPRIGHT",0,4)
    sortMenu:SetFrameLevel(parent:GetFrameLevel()+30);sortMenu:EnableMouse(true);kit.Backdrop(sortMenu,C.surface,C.lineStrong,8,true)
    Text(sortMenu,"Draft only · Apply to change raid",9.5,10,-8,230)
    local sortOptions={{"Role sort","ROLE_SORT","Tank > Melee > Ranged > Healer; fills free slots from Group 1."},
        {"Split odd / even","SPLIT_ODD_EVEN","Balances known roles across odd/even groups, using the first 2, 4, 6 or 8 groups that fit."},
        {"Split adjacent groups","SPLIT_ADJACENT","Balances known roles across two adjacent group blocks, such as G1+2 / G3+4."}}
    for index,option in ipairs(sortOptions)do
        local mode,tip=option[2],option[3]
        local button=kit.Button(sortMenu,option[1],230,28,function()
            if Locked() then return end
            ClearSelection();local ok=Edit("SortDraft",mode);if ok then sortMenu:Hide() end
        end);Point(button,"TOPLEFT",sortMenu,"TOPLEFT",10,-30-(index-1)*34)
        button:HookScript("OnEnter",function(self)if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(tip);GameTooltip:AddLine("Absent/unresolved cards and tray stay put. Unknown current roles stop this local sort. No inspection.",0.8,0.8,0.85,true);GameTooltip:Show() end end)
        button:HookScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    end
    sortMenu:Hide();ui.sortMenu=sortMenu
    trayScroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    Point(trayScroll,"TOPLEFT",parent,"TOPLEFT",0,-528);Size(trayScroll,922,72)
    trayChild=CreateFrame("Frame",nil,trayScroll);Size(trayChild,918,72);trayScroll:SetScrollChild(trayChild)
    trayChild:EnableMouse(true);ui.dropOwners[trayChild]={frame=trayChild}
    trayChild:SetScript("OnEnter",function()ui.hover={frame=trayChild}end)
    trayChild:SetScript("OnLeave",function()if ui.hover and ui.hover.frame==trayChild then ui.hover=nil end end)
    trayChild:SetScript("OnMouseDown",PointerDown)
    trayChild:SetScript("OnMouseUp",function()if ui.selected and not ui.consumed then Move(nil,nil)end end)
    trayScroll:HookScript("OnVerticalScroll",function()ui.hover=nil;if GameTooltip then GameTooltip:Hide()end end)
    status=Text(parent,"",10,0,-610,590);status:SetHeight(48);ui.applyStatus=status
    cancelButton=kit.Button(parent,"CANCEL APPLY",128,34,function()Call("CancelApply");ClearSelection();Refresh()end)
    Point(cancelButton,"TOPLEFT",parent,"TOPLEFT",610,-610);cancelButton:Hide()
    reviewButton=kit.Button(parent,"REVIEW CHANGES",128,34,function()
        if Locked() then return end
        ClearSelection();ui.feedback=nil;Prepare();Refresh()
    end);Point(reviewButton,"TOPLEFT",parent,"TOPLEFT",610,-610)
    applyButton=kit.Button(parent,"APPLY TO RAID",200,34,function()
        if not ui.state or Locked() then return end
        local preview=ui.state.preview
        if not preview or preview.canApply~=true or (ui.state.draft and ui.state.draft.stale) then return end
        ui.feedback=nil
        local ok,reason=Call("Apply",preview.id)
        ui.message=reason or (ok and "Applying reviewed group changes." or "Apply stopped.")
        if not ok then ui.feedback=ui.message end
        Refresh()
    end,true)
    Point(applyButton,"TOPLEFT",parent,"TOPLEFT",750,-610)

    local function Modal(title)
        ClearPointer();sortMenu:Hide();nameBox:ClearFocus()
        if not ui.modal then
            local host=RA.ConfigFrame or parent
            ui.modal=CreateFrame("Frame",nil,host,"BackdropTemplate");ui.modal:SetAllPoints(host)
            ui.modal:SetFrameLevel(host:GetFrameLevel()+180);ui.modal:EnableMouse(true)
            kit.Backdrop(ui.modal,{0,0,0,0.72},C.line,8,false)
            ui.card=CreateFrame("Frame",nil,ui.modal,"BackdropTemplate");Size(ui.card,620,500);Point(ui.card,"CENTER",ui.modal,"CENTER",0,0)
            kit.Backdrop(ui.card,C.surface,C.lineStrong,12,true)
            ui.modalTitle=Text(ui.card,"",16,20,-18,580,C.text)
            ui.modalStatus=Text(ui.card,"",10,20,-448,430)
            local close=kit.Button(ui.card,"CLOSE",120,32,HideModal);Point(close,"BOTTOMRIGHT",ui.card,"BOTTOMRIGHT",-20,18)
            ui.modal:SetScript("OnKeyDown",function(self,key)
                if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput,self,key~="ESCAPE") end
                if key=="ESCAPE" then HideModal() end
            end)
            ui.modal:HookScript("OnHide",function()
                if ui.paste then ui.paste:ClearFocus() end
                ui.resolveID=nil;ui.modalMode=nil
                pcall(ui.modal.EnableKeyboard,ui.modal,false)
            end)
        end
        for _,row in ipairs(ui.modalRows)do row:Hide()end
        if ui.listScroll then ui.listScroll:Hide() end
        if ui.pasteScroll then ui.pasteScroll:Hide() end
        if ui.parseButton then ui.parseButton:Hide();ui.importConfirm:Hide() end
        if ui.removeEntry then ui.removeEntry:Hide() end
        if ui.recoverConfirm then ui.recoverConfirm:Hide() end
        SetText(ui.modalTitle,title);SetText(ui.modalStatus,"")
        ui.modal:Show();pcall(ui.modal.EnableKeyboard,ui.modal,true)
    end
    local function List(rows,onPick)
        if not ui.listScroll then
            ui.listScroll=CreateFrame("ScrollFrame",nil,ui.card,"UIPanelScrollFrameTemplate");Size(ui.listScroll,552,330);Point(ui.listScroll,"TOPLEFT",ui.card,"TOPLEFT",20,-60)
            ui.listChild=CreateFrame("Frame",nil,ui.listScroll);Size(ui.listChild,548,330);ui.listScroll:SetScrollChild(ui.listChild)
        end
        ui.listScroll:Show();ui.listScroll:SetVerticalScroll(0);ui.listChild:SetHeight(math.max(330,#rows*34))
        for index,item in ipairs(rows)do
            local button=ui.modalRows[index]
            if not button then
                button=kit.Button(ui.listChild,"",548,30,function()end);ui.modalRows[index]=button
                button:HookScript("OnEnter",function(self)
                    if GameTooltip and self.item then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(Literal(self.item.label));GameTooltip:Show() end
                end)
                button:HookScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
            end
            button:ClearAllPoints();Point(button,"TOPLEFT",ui.listChild,"TOPLEFT",0,-(index-1)*34)
            button.item=item;SetText(button.label,item.label);button:SetScript("OnClick",function()onPick(item)end);button:Show()
        end
    end
    ShowLoad=function()
        if Locked() then return end
        Modal("Load a local layout");ui.modalMode="load"
        local rows={}
        for _,row in ipairs((ui.state and ui.state.layouts)or{})do rows[#rows+1]={label=row.name,name=row.name}end
        SetText(ui.modalStatus,#rows==0 and "No saved layouts yet. Enter a name and Save." or "Loading replaces the local draft, including unsaved edits. No raid action.")
        List(rows,function(item)if Edit("LoadLayout",item.name)then nameBox:SetText(item.name);HideModal();ClearSelection();Refresh()end end)
    end
    ShowResolve=function(id)
        if Locked() then return end
        Modal("Match an absent or unresolved identity");ui.modalMode="resolve";ui.resolveID=id
        local rows={}
        for _,member in ipairs((ui.state.live and ui.state.live.members)or{})do rows[#rows+1]={label=member.fullName.." · Group "..member.group,guid=member.guid}end
        table.sort(rows,function(a,b)return a.label<b.label end)
        List(rows,function(item)if Edit("ResolveEntry",id,item.guid)then HideModal();ClearSelection();Refresh()end end)
        if not ui.removeEntry then ui.removeEntry=kit.Button(ui.card,"REMOVE ABSENT CARD",210,30,function()
            if ui.resolveID and Edit("RemoveEntry",ui.resolveID)then HideModal();ClearSelection();Refresh()end
        end);Point(ui.removeEntry,"BOTTOMLEFT",ui.card,"BOTTOMLEFT",20,66) end
        local entry=ui.state and ui.state.view and ui.state.view.entries[id]
        SetText(ui.removeEntry.label,entry and entry.absentPlaceholder and "REMOVE ABSENT CARD" or "REMOVE UNMATCHED CARD")
        ui.removeEntry:Show();SetText(ui.modalStatus,"Choose the exact current raider. This edits only the draft.")
    end
    ShowImport=function()
        if Locked() then return end
        Modal("Import WowUtils note");ui.modalMode="paste";ui.sections=nil;ui.parsedText=nil;ui.sectionIndex=nil
        if not ui.pasteScroll then
            ui.pasteScroll=CreateFrame("ScrollFrame",nil,ui.card,"UIPanelScrollFrameTemplate");Size(ui.pasteScroll,552,320);Point(ui.pasteScroll,"TOPLEFT",ui.card,"TOPLEFT",20,-60)
            ui.paste=CreateFrame("EditBox",nil,ui.pasteScroll);Size(ui.paste,548,320);ui.pasteScroll:SetScrollChild(ui.paste)
            RA:ApplyFont(ui.paste,10,"REGULAR",false);ui.paste:SetMultiLine(true);ui.paste:SetAutoFocus(false);ui.paste:SetMaxLetters(65536)
            if ui.paste.SetHyperlinksEnabled then ui.paste:SetHyperlinksEnabled(false) end
            ui.paste:SetScript("OnEscapePressed",HideModal)
            ui.paste:SetScript("OnTextChanged",function(self)
                ui.sections=nil;ui.parsedText=nil;ui.sectionIndex=nil;if ui.importConfirm then Enabled(ui.importConfirm,false) end
                local lines=0;for line in ((self:GetText()or"").."\n"):gmatch("(.-)\n")do lines=lines+math.max(1,math.ceil(#line/54))end
                self:SetHeight(math.max(320,math.min(16000,lines*14+28)))
            end)
            ui.paste:SetScript("OnCursorChanged",function(_,_,y,_,height)
                if type(y)~="number" then return end
                local top,current=math.max(0,-y),ui.pasteScroll:GetVerticalScroll()or 0
                if top<current then ui.pasteScroll:SetVerticalScroll(top)
                elseif top+(height or 14)>current+320 then ui.pasteScroll:SetVerticalScroll(top+(height or 14)-320)end
            end)
            ui.parseButton=kit.Button(ui.card,"READ SECTIONS",160,32,function()
                local text=ui.paste:GetText()
                local sections,reason=Call("ParseNote",text)
                if not sections then SetText(ui.modalStatus,reason or "Unsupported note.");return end
                ui.sections=sections;ui.parsedText=text;ui.sectionIndex=nil;ui.paste:ClearFocus();ui.pasteScroll:Hide();ui.parseButton:Hide()
                local rows={};for index,section in ipairs(sections)do if section.hasInvite then rows[#rows+1]={label=section.label..(section.difficulty and (" · "..section.difficulty)or""),index=index}end end
                List(rows,function(item)
                    if ui.modalMode~="paste" or ui.sections~=sections or ui.parsedText~=text or ui.paste:GetText()~=text then
                        Enabled(ui.importConfirm,false);SetText(ui.modalStatus,"Paste changed. Read sections again.");return
                    end
                    ui.sectionIndex=item.index
                    local name,reason=Call("GetImportName",text,item.index)
                    SetText(ui.modalStatus,name and ("Save as: "..name..". Local only; Apply changes the raid.")or reason)
                    Enabled(ui.importConfirm,name~=false and name~=nil)
                end)
                SetText(ui.modalStatus,"Choose a section, then Import & save locally.")
            end);Point(ui.parseButton,"BOTTOMLEFT",ui.card,"BOTTOMLEFT",20,64)
            ui.importConfirm=kit.Button(ui.card,"IMPORT & SAVE",180,32,function()
                local section=ui.sections and ui.sections[ui.sectionIndex]
                if ui.modalMode~="paste" or not section or ui.parsedText~=ui.paste:GetText() then
                    Enabled(ui.importConfirm,false);SetText(ui.modalStatus,"Paste changed. Read sections again.");return
                end
                local ok,reason=Edit("ImportAndSaveNote",ui.parsedText,ui.sectionIndex)
                if ok then
                    HideModal();ClearSelection();Refresh()
                else SetText(ui.modalStatus,reason or "Import was not saved. Draft unchanged.") end
            end);Point(ui.importConfirm,"BOTTOMLEFT",ui.card,"BOTTOMLEFT",190,64)
        end
        ui.pasteScroll:Show();ui.parseButton:Show();ui.importConfirm:Show();Enabled(ui.importConfirm,false)
        SetText(ui.modalStatus,"Read and select a section. Import & save creates a local layout; Apply changes the raid.");ui.paste:SetFocus()
    end
    ShowRecovery=function()
        if Busy() or not Uncertain() then return end
        local ok,reason=Call("RefreshRoster")
        Refresh()
        if not ok or not ui.state or not ui.state.live or ui.state.liveError then
            ui.feedback=reason or "Current raid data is unavailable.";Refresh();return
        end
        if not Uncertain() then ui.feedback="Submitted result observed. Review changes before another Apply.";Refresh();return end
        Modal("Review observed raid groups");ui.modalMode="recovery"
        ui.recoveryFingerprint=ui.state.live.fingerprint
        local groups={};for g=1,8 do groups[g]={}end
        for _,member in ipairs(ui.state.live.members or {})do
            if groups[member.group] then groups[member.group][#groups[member.group]+1]=member.fullName end
        end
        local rows={}
        for g=1,8 do
            table.sort(groups[g])
            if #groups[g]==0 then rows[#rows+1]={label="Group "..g.." · Empty"}
            else for _,fullName in ipairs(groups[g])do rows[#rows+1]={label="Group "..g.." · "..fullName}end end
        end
        List(rows,function()end)
        if not ui.recoverConfirm then
            ui.recoverConfirm=kit.Button(ui.card,"ACKNOWLEDGE GROUPS",210,32,function()
                if ui.modalMode~="recovery" then return end
                local recovered,detail=Call("RecoverStopped",ui.recoveryFingerprint)
                if not recovered then SetText(ui.modalStatus,detail or "Recovery is unavailable; raid data must be known.");return end
                ui.message="Observed groups acknowledged; draft retained. A prior move may still settle. Review again before Apply."
                ui.feedback=ui.message;ui.prepareFailed=false;HideModal();ClearSelection();Refresh()
            end);Point(ui.recoverConfirm,"BOTTOMLEFT",ui.card,"BOTTOMLEFT",20,64)
        end
        ui.recoverConfirm:Show();Enabled(ui.recoverConfirm,ui.state.apply.canRecover==true and type(ui.recoveryFingerprint)=="string")
        SetText(ui.modalStatus,"A prior move may still settle. Acknowledge these observed groups to unlock; your draft stays. Review again before Apply.")
    end
    local function Paint(button,id,target,entries)
        local entry=id and entries[id]
        button.entryID=entry and id or nil;button.roleIcon:Hide();button.match:Hide()
        if not entry then
            SetText(button.name,"Empty slot");SetText(button.detail,"");button.classStrip:Hide();button:SetAlpha(0.45);button:SetSelected(false);return
        end
        local member=entry.guid and ui.members[entry.guid]
        if member and (member.role=="TANK" or member.role=="HEALER") then
            button.roleIcon:SetAtlas(member.role=="TANK" and "UI-LFG-RoleIcon-Tank-Micro-GroupFinder" or "UI-LFG-RoleIcon-Healer-Micro-GroupFinder");button.roleIcon:Show()
        end
        local class=member and member.class or entry.class
        local color=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        button.classStrip:SetColorTexture(color and color.r or C.muted[1],color and color.g or C.muted[2],color and color.b or C.muted[3],1);button.classStrip:Show()
        local detail=class or ""
        if entry.absentPlaceholder then detail=entry.unresolved and "Absent · short name" or "Absent"
        elseif entry.unusedPlaceholder then detail="Unused template · skipped"
        elseif entry.identityReason then detail="Needs matching"
        elseif entry.unresolved then detail="Unresolved"
        elseif entry.missing then detail=(detail~="" and detail.." · " or "").."Absent"
        else
            if entry.liveGroup~=target then detail=detail..(detail~="" and " · " or "").."G"..tostring(entry.liveGroup).." > "..(target and ("G"..target) or "Unassigned") end
            if member and member.online==false then detail=detail..(detail~="" and " · " or "").."Offline" end
        end
        if ui.nameCounts[(entry.name or ""):lower()] and ui.nameCounts[(entry.name or ""):lower()]>1 then
            detail=(entry.realm or entry.fullName or "Unknown realm")..(detail~="" and " · "..detail or "")
        end
        local needsMatch=target~=nil and entry.identityReason~=nil and not entry.absentPlaceholder
        button.match:SetShown(needsMatch);Enabled(button.match,not Locked())
        if needsMatch then button.roleIcon:Hide() end
        button.name:SetWidth(button:GetWidth()-(needsMatch and 68 or 36))
        button.detail:SetWidth(button:GetWidth()-(needsMatch and 68 or 18))
        SetText(button.name,entry.name or entry.fullName);SetText(button.detail,detail)
        button:SetAlpha(entry.missing and 0.6 or member and member.online==false and 0.7 or 1)
        button:SetSelected(ui.selected==id)
    end
    Refresh=function()
        if not ui.active or not parent:IsVisible() then return end
        local state,reason=Call("GetState")
        if not state or state==false then Message(reason or "Raid Groups is unavailable.");Enabled(applyButton,false);return end
        ui.state=state;ui.members={};ui.nameCounts={}
        if ui.prepareFailed and ui.prepareContext~=ReviewContext(state) then ui.prepareFailed=false;ui.prepareReason=nil;ui.prepareContext=nil end
        for _,member in ipairs((state.live and state.live.members)or{})do ui.members[member.guid]=member end
        local view=state.view or {groups={},entries={},tray={}};local targets={};local changes,unassigned,absent,unmatched=0,0,0,0
        for _,entry in pairs(view.entries)do
            local short=(entry.name or ""):lower();ui.nameCounts[short]=(ui.nameCounts[short]or 0)+1
        end
        for group=1,8 do
            local present=0
            for slot=1,5 do
                local id=view.groups[group] and view.groups[group][slot]
                if id then targets[id]=group;local entry=view.entries[id];if entry and not entry.missing then present=present+1;if entry.liveGroup~=group then changes=changes+1 end end end
                Paint(ui.slots[group][slot],id,group,view.entries)
            end
            SetText(ui.groups[group].count,tostring(present).." / 5")
        end
        for index,id in ipairs(view.tray or {})do
            local button=ui.tray[index]
            if not button then button=MakeSlot(trayChild,222,28);ui.tray[index]=button end
            Point(button,"TOPLEFT",trayChild,"TOPLEFT",((index-1)%4)*232,-math.floor((index-1)/4)*32)
            Paint(button,id,nil,view.entries);button:Show()
            local entry=view.entries[id]
            if entry and entry.guid then unassigned=unassigned+1
            elseif entry and entry.absentPlaceholder then absent=absent+1 else unmatched=unmatched+1 end
        end
        for index=#(view.tray or {})+1,#ui.tray do ui.tray[index]:Hide()end
        local trayHeight=math.max(72,math.ceil(#(view.tray or {})/4)*32)
        trayChild:SetHeight(trayHeight)
        local current=trayScroll:GetVerticalScroll()or 0;if current>trayHeight-72 then trayScroll:SetVerticalScroll(math.max(0,trayHeight-72))end
        SetText(trayTitle,"Unassigned: "..unassigned.." present"..(absent>0 and (" · "..absent.." absent")or"")..(unmatched>0 and (" · "..unmatched.." unused")or"")..(ui.selected and " · Click a slot to move selected player"or""))
        local busy=Busy();local preview=state.preview
        for _,button in ipairs({loadButton,saveButton,importButton,reconcileButton,sortButton})do Enabled(button,not Locked())end
        if Locked() then sortMenu:Hide() end
        local savedName=state.layout and state.layout.savedName
        local typed=(nameBox:GetText()or""):match("^%s*(.-)%s*$")
        local saveAs=savedName and typed~=savedName
        local dirty=state.draft and (not savedName or saveAs or state.layout.contentDirty)
        ui.dirty=dirty==true;saveButton:SetSelected(ui.dirty)
        SetText(saveButton.label,saveAs and "SAVE AS" or "SAVE")
        SetText(saveStatus,not state.draft and "No layout" or not savedName and "New layout · unsaved" or dirty and "Unsaved changes" or "Saved")
        Enabled(fromButton,not busy);SetText(fromButton.label,Uncertain() and "REVIEW RAID" or "FROM RAID")
        Enabled(applyButton,not Locked() and preview and preview.canApply==true and (preview.operationCount or 0)>0 and not (state.draft and state.draft.stale))
        cancelButton:SetShown(busy);reviewButton:SetShown(not busy);Enabled(reviewButton,not Locked())
        local applying=state.apply or {}
        local message
        if busy then message="Applying "..tostring(applying.confirmed or 0).." / "..tostring(applying.total or 0).." confirmed."
        elseif Uncertain() then message=(applying.reason or "Apply stopped.").." Review raid to acknowledge current groups; a prior move may still settle."
        elseif state.liveError then message="Apply blocked: "..state.liveError
        elseif ui.prepareFailed then message="Apply blocked: "..(ui.prepareReason or "Review changes again.")
        elseif preview and preview.canApply~=true then message="Apply blocked: "..(preview.reason or "Review changes again.")
        elseif unassigned>0 then message="Apply blocked: "..unassigned.." present raiders need a target group."
        elseif state.draft and state.draft.stale then message="Raid changed. Review changes again before Apply."
        elseif not preview and applying.status=="stopped" then message=(applying.reason or "Apply stopped.").." Review changes before another Apply."
        elseif not preview and applying.status=="complete" then message=(applying.reason or "Group changes confirmed.").." Review changes before another Apply."
        elseif not preview then message="Review changes before Apply."
        elseif (preview.operationCount or 0)==0 then message="Raid already matches. No live group changes to apply."
        else message="Ready to move "..changes..(changes==1 and " player" or " players").." · "..tostring(preview.operationCount).." moves/swaps." end
        if preview and preview.canApply and not Locked() and #(preview.missing or {})>0 then message=message.." "..#preview.missing.." not in raid skipped." end
        if preview and preview.canApply and #(preview.unusedPlaceholders or {})>0 then message=message.." "..#preview.unusedPlaceholders.." unused template card(s) skipped." end
        if preview and preview.canApply and (preview.realmAliasCount or 0)>0 then message=message.." "..preview.realmAliasCount.." realm alias(es) matched to current raiders." end
        if preview and (preview.mergedTrayDuplicates or 0)>0 then message=message.." "..preview.mergedTrayDuplicates.." duplicate tray card(s) combined locally." end
        if preview and (preview.mergedRealmAliases or 0)>0 then message=message.." "..preview.mergedRealmAliases.." redundant tray alias(es) merged locally; Save to update this layout." end
        ui.applyReason=message
        if not busy then
            if ui.feedback then message=message.." · "..ui.feedback
            elseif ui.selected then message=message.." · "..(ui.message or "Card selected.") end
        end
        if applying.priorRequestMaySettle and not Uncertain() and not busy then message=message.." · A prior move may still settle." end
        SetText(status,message or "")
    end
    function ui:Show()
        if self.active then return end
        self.active=true;self.prepareFailed=false;self.prepareReason=nil;self.prepareContext=nil
        Call("SetVisible",true);Refresh()
        if self.state and not self.state.draft and self.state.live then Call("FromCurrentRaid") end
        Prepare();Refresh()
    end
    function ui:Hide()
        self.active=false;ClearSelection();HideModal();self.prepareFailed=false;self.prepareReason=nil;self.prepareContext=nil;self.feedback=nil
        nameBox:ClearFocus();sortMenu:Hide();Call("SetVisible",false)
    end
    parent:HookScript("OnShow",function()ui:Show()end)
    parent:HookScript("OnHide",function()ui:Hide()end)
    RA:RegisterCallback("RAID_GROUPS_CHANGED",function()
        if ui.active and parent:IsVisible() then
            if not ui.preparing then ui.feedback=nil end
            Refresh()
        end
    end)
    -- Constructor intentionally makes no core/getter/event-subscription call.
    return Refresh
end
