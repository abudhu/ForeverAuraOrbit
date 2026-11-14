-- API-boundary simulator. This is not a replacement for in-client testing.
Frames, Combat, Secure, Forms, Messages = {}, false, false, {
    {465, "Devotion Aura", 101, true},
    {7294, "Retribution Aura", 102, false},
    {19746, "Concentration Aura", 103, false},
}, {}
local methods = {}
local function guarded(self)
    assert(not (Combat and self.protected and not Secure), "Insecure protected mutation during combat: " .. (self.name or "unnamed"))
end
local function run(self, code, ...)
    if not code then return end
    local old = Secure
    Secure = true
    local f = assert(loadstring('return function(self, newstate, name, value) '..code..' end'))()
    local ok, err = pcall(f, self, ...)
    Secure = old
    assert(ok,err)
end
function methods:Fire(script,...)
    local a = ({OnEnter='_onenter', OnLeave='_onleave',OnShow='_onshow',OnHide='_onhide'})[script]
    if a then run(self,self.attrs[a]) end
    if self.scripts[script] then self.scripts[script](self,...) end
    if self.hooks[script] then self.hooks[script](self,...) end
end
function methods:SetSize(w,h) guarded(self); self.w,self.h=w,h end
function methods:GetWidth() return self.w or 60 end
function methods:GetHeight() return self.h or 60 end
function methods:SetPoint(...)
    guarded(self)
    local args={...}
    local relative=args[2]
    assert(not (self.protected and type(relative)=='table' and
        (relative.kind=='Texture' or relative.kind=='FontString')),
        'Action[SetPoint] failed because[Cannot anchor protected frames to regions]')
    self.point=args
end
function methods:ClearAllPoints() guarded(self); self.point=nil end
function methods:SetAllPoints() guarded(self) end
function methods:SetFrameStrata(s) guarded(self); self.strata=s end
function methods:SetFrameLevel(n) guarded(self); self.level=n end
function methods:GetFrameLevel() return self.level or 5 end
function methods:GetParent() return self.parent end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter()
    if self.cx and self.cy then return self.cx,self.cy end
    local p=self.point
    if p and type(p[2])=='table' then
        assert(p[1]=='CENTER' and p[3]=='CENTER', 'Fixture supports only centered anchors')
        local rx,ry=p[2]:GetCenter()
        local relativeScale=p[2]:GetEffectiveScale()
        local scale=self:GetEffectiveScale()
        return rx*relativeScale/scale+(p[4] or 0),ry*relativeScale/scale+(p[5] or 0)
    end
    return 100,100
end
function methods:GetRect()
    local x,y=self:GetCenter()
    local w,h=self:GetWidth(),self:GetHeight()
    return x-w/2,y-h/2,w,h
end
PointerX,PointerY=0,0
function SetPointer(x,y) PointerX,PointerY=x,y end
function methods:IsUnderMouse()
    if not self:IsVisible() then return false end
    local l,b,w,h=self:GetRect()
    local scale=self:GetEffectiveScale()
    local x,y=PointerX/scale,PointerY/scale
    return x>=l and x<=l+w and y>=b and y<=b+h
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:Show() guarded(self); local was=self.shown; self.shown=true; if not was then self:Fire('OnShow') end end
function methods:Hide() guarded(self); local was=self.shown; self.shown=false; if was then self:Fire('OnHide') end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetAlpha(a) guarded(self); self.alpha=a end
function methods:GetAlpha() return self.alpha or 1 end
function methods:EnableMouse(v) guarded(self); self.mouse=v end
function methods:EnableMouseMotion(v) guarded(self); self.motion=v end
function methods:EnableMouseClicks(v) guarded(self); self.clicks=v end
function methods:SetPropagateMouseClicks(v) guarded(self); self.propagate=v end
function methods:RegisterForClicks(...) guarded(self); self.clickRegistration={...} end
function methods:SetAttribute(k,v) guarded(self); self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetFrameRef(k,v) guarded(self); self.refs[k]=v end
function methods:GetFrameRef(k) return self.refs[k] end
function methods:SetScript(k,v) guarded(self); self.scripts[k]=v end
function methods:HookScript(k,v) guarded(self); self.hooks[k]=v end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:RegisterUnitEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:RegisterAutoHide(t) assert(Secure); self.autoHide=t; self.autoFrames={}; self.autoPoints={} end
function methods:AddToAutoHide(f)
    assert(Secure)
    self.autoFrames[#self.autoFrames+1]=f
    self.autoPoints[#self.autoFrames]=f.point and {unpack(f.point)} or {}
end
function methods:UnregisterAutoHide() assert(Secure); self.autoHide=nil end
function methods:SetTexture(t) self.texture=t end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexColor(...) self.vertex={...} end
function methods:SetTexCoord(...) self.texcoord={...} end
function methods:SetBlendMode() end
function methods:SetDrawLayer() end
function methods:SetMask() end
function methods:AddMaskTexture() end
function methods:SetText(t) self.text=t end
function methods:SetCooldown(s,d) self.cooldown={s,d} end
function methods:SetDrawEdge() end
function methods:SetHideCountdownNumbers() end
function methods:SetOwner() end
function methods:SetSpellByID(id) self.spell=id end
function methods:AddLine() end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({kind=kind,name=name,parent=parent,template=template or '',attrs={},refs={},scripts={},hooks={},events={},shown=true,
        protected=(template and template:find('Secure') ~= nil) or (parent and parent.protected) or false}, {__index=methods})
    Frames[#Frames+1]=f
    if name then _G[name]=f end
    return f
end
function methods:CreateTexture() return CreateFrame('Texture',nil,nil) end
function methods:CreateMaskTexture() return CreateFrame('Texture',nil,nil) end
function methods:CreateFontString() return CreateFrame('FontString',nil,nil) end
-- Record animation API calls without reimplementing selection logic.
local animationMethods = {}
function animationMethods:SetFromAlpha(v) self.fromAlpha=v end
function animationMethods:SetToAlpha(v) self.toAlpha=v end
function animationMethods:SetDuration(v) self.duration=v end
local groupMethods = {}
function groupMethods:CreateAnimation(kind)
    local a=setmetatable({kind=kind},{__index=animationMethods})
    self.animations[#self.animations+1]=a
    return a
end
function groupMethods:Play() self.playing=true; self.playCount=(self.playCount or 0)+1 end
function groupMethods:Stop() self.playing=false end
function groupMethods:IsPlaying() return self.playing==true end
function methods:CreateAnimationGroup()
    assert(self.kind=='Texture', 'Selection animation must be cosmetic, not on protected buttons')
    return setmetatable({owner=self,animations={}},{__index=groupMethods})
end
function UnitClass() return 'Paladin',ClassTag or 'PALADIN' end
function InCombatLockdown() return Combat end
function GetNumShapeshiftForms() return #Forms end
function GetShapeshiftFormInfo(i) local f=Forms[i]; return f[3],f[4],true,f[1] end
C_Spell={
    GetSpellInfo=function(id) for _,v in ipairs(Forms) do if v[1]==id then return {name=v[2],iconID=v[3]} end end end,
    GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true} end,
}
function IsSpellKnown(id) return C_Spell.GetSpellInfo(id) ~= nil end
function RegisterStateDriver(f,state,condition) guarded(f); f.driver={state,condition} end
function SetCombat(v)
    Combat=v
    for _,f in ipairs(Frames) do if f.driver then run(f,f.attrs['_onstate-'..f.driver[1]],v and '1' or '0') end end
    FireEvent(v and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED')
end
function FireEvent(event,...)
    local list={unpack(Frames)}
    for _,f in ipairs(list) do if f.events[event] then f:Fire('OnEvent',event,...) end end
end
C_Timer={After=function(_,f) f() end}
function GetTime() return 100 end
SlashCmdList={}
UIParent=CreateFrame('Frame','UIParent')
PlayerFrame=CreateFrame('Frame','PlayerFrame',UIParent,'SecureUnitButtonTemplate')
PlayerLevelText=CreateFrame('FontString','PlayerLevelText',PlayerFrame)
PlayerLevelText.cx,PlayerLevelText.cy=113,73
PlayerLevelText.w,PlayerLevelText.h=18,14
local portrait=CreateFrame('Texture',nil,PlayerFrame)
local ring=CreateFrame('Texture',nil,PlayerFrame)
ring.w,ring.h=22,22; ring.cx,ring.cy=113,73
PlayerFrame.PlayerFrameContainer={PlayerPortrait=portrait}
PlayerFrame.PlayerFrameContent={PlayerFrameContentMain={LevelBackgroundCircle=ring}}
GameTooltip=CreateFrame('Frame','GameTooltip',UIParent)
DEFAULT_CHAT_FRAME={AddMessage=function(_,t) Messages[#Messages+1]=t end}
