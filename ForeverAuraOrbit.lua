local addonName, ns = ...
local Core = ns.Core
local buttons, auras = {}, {}
local root, panel, trigger, animator
local radius, startAngle, startRadius = 48, -65, 26
local elapsed, pending = 0, false
local DURATION, SIZE = 0.24, 26
local ASSET = "Interface\\AddOns\\ForeverAuraOrbit\\Media\\Ring"

local function message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcf70Aura Orbit:|r " .. text)
end

local function spellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then
            local texture = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
            return {name=info.name, icon=texture or info.iconID or info.originalIconID}
        end
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        if name then return {name=name, icon=icon} end
    end
end

local function isKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown and Enum and Enum.SpellBookSpellBank then
        return C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player)
    end
    return IsSpellKnown and IsSpellKnown(id)
end

local function readAuras()
    local forms = {}
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        for i = 1, GetNumShapeshiftForms() do
            local icon, active, _, id = GetShapeshiftFormInfo(i)
            local info = id and spellInfo(id)
            if info then
                forms[#forms + 1] = {spellID=id, name=info.name, icon=info.icon or icon, active=active, formIndex=i}
            end
        end
    end
    return Core.Collect(forms, isKnown, spellInfo)
end

local function updateActive(suppressPulse)
    local activeNames = {}
    for _, aura in ipairs(readAuras()) do
        if aura.active then activeNames[aura.name] = true end
    end
    for i, aura in ipairs(auras) do
        local b = buttons[i]
        local isActive = activeNames[aura.name] == true
        local wasActive = b.isActive
        b.active:SetShown(isActive)
        b.isActive = isActive
        if wasActive == false and isActive and not suppressPulse and panel:IsShown() then
            -- Confirmed state change, not merely a click (which may fail to cast).
            b.pulseAnimation:Stop()
            b.pulseAnimation:Play()
        elseif wasActive and not isActive then
            b.pulseAnimation:Stop()
        end
        if b.cooldown then
            local start, duration
            if C_Spell and C_Spell.GetSpellCooldown then
                local info = C_Spell.GetSpellCooldown(aura.spellID)
                if info then start, duration = info.startTime, info.duration end
            elseif GetSpellCooldown then
                start, duration = GetSpellCooldown(aura.spellID)
            end
            if start and duration then b.cooldown:SetCooldown(start, duration) end
        end
    end
end

local function position(progress)
    for i = 1, #auras do
        local b = buttons[i]
        local x, y = Core.Position(i, #auras, radius, progress, startAngle, startRadius)
        b:ClearAllPoints()
        b:SetPoint("CENTER", panel, "CENTER", x, y)
        b:SetAlpha(math.min(1, progress * 3))
    end
end

local function animate(self, dt)
    -- Never move protected buttons from an insecure OnUpdate during combat.
    if InCombatLockdown() or not panel:IsShown() then
        self:SetScript("OnUpdate", nil)
        return
    end
    elapsed = math.min(DURATION, elapsed + dt)
    position(elapsed / DURATION)
    if elapsed >= DURATION then self:SetScript("OnUpdate", nil) end
end

local function newButton(index)
    local b = CreateFrame("Button", "ForeverAuraOrbitButton" .. index, panel, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "spell")
    b:SetAttribute("unit", "player")
    b:SetAttribute("useOnKeyDown", false)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
    b.icon, b.mask = icon, mask
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(SIZE + 6, SIZE + 6)
    border:SetTexture(ASSET)
    border:SetVertexColor(0.60, 0.54, 0.39)
    b.border = border
    local active = b:CreateTexture(nil, "OVERLAY", nil, 1)
    active:SetPoint("CENTER")
    active:SetSize(SIZE + 8, SIZE + 8)
    active:SetTexture(ASSET)
    active:SetVertexColor(1, 0.8, 0.25)
    active:Hide()
    b.active = active
    -- Only a Texture is animated; secure button geometry never changes here.
    local pulse = b:CreateTexture(nil, "OVERLAY", nil, 2)
    pulse:SetPoint("CENTER")
    pulse:SetSize(SIZE + 16, SIZE + 16)
    pulse:SetTexture(ASSET)
    pulse:SetVertexColor(1, 0.9, 0.45)
    pulse:SetBlendMode("ADD")
    pulse:SetAlpha(0)
    b.pulse = pulse
    b.pulseAnimation = pulse:CreateAnimationGroup()
    local fade = b.pulseAnimation:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.35)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    b.cooldown:SetDrawEdge(false)
    b.cooldown:SetHideCountdownNumbers(true)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(self:GetAttribute("spell"))
        GameTooltip:AddLine("Click to activate aura", 1, 0.82, 0.4)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function createFrames()
    root = CreateFrame("Frame", "ForeverAuraOrbitRoot", PlayerFrame, "SecureHandlerStateTemplate")
    root:SetSize(1, 1)
    root:SetFrameStrata("DIALOG")
    root:SetFrameLevel(PlayerFrame:GetFrameLevel() + 20)
    panel = CreateFrame("Frame", "ForeverAuraOrbitPanel", root, "SecureHandlerShowHideTemplate")
    panel:SetSize(1, 1)
    panel:Hide()
    trigger = CreateFrame("Frame", "ForeverAuraOrbitTrigger", root, "SecureHandlerEnterLeaveTemplate")
    trigger:EnableMouse(true)
    if trigger.EnableMouseClicks then trigger:EnableMouseClicks(false) end
    if trigger.SetPropagateMouseClicks then trigger:SetPropagateMouseClicks(true) end
    trigger:SetFrameRef("panel", panel)
    trigger:SetAttribute("_onenter", [[
        local panel = self:GetFrameRef("panel")
        if panel:GetAttribute("count") > 0 then panel:Show() end
    ]])
    panel:SetFrameRef("trigger", trigger)
    panel:SetAttribute("count", 0)
    root:SetFrameRef("panel", panel)
    root:SetAttribute("_onstate-combat", [[
        if newstate == "1" then
            local panel = self:GetFrameRef("panel")
            for i = 1, panel:GetAttribute("count") do
                local button = panel:GetFrameRef("button" .. i)
                button:ClearAllPoints()
                button:SetPoint("CENTER", panel, "CENTER", button:GetAttribute("final-x"), button:GetAttribute("final-y"))
                button:SetAlpha(1)
            end
        end
    ]])
    RegisterStateDriver(root, "combat", "[combat] 1; 0")
    panel:SetAttribute("_onshow", [[
        -- The hover driver snapshots rectangles: normalize before registering.
        for i = 1, self:GetAttribute("count") do
            local button = self:GetFrameRef("button" .. i)
            button:ClearAllPoints()
            button:SetPoint("CENTER", self, "CENTER", button:GetAttribute("final-x"), button:GetAttribute("final-y"))
            button:SetAlpha(1)
        end
        self:RegisterAutoHide(0.45)
        self:AddToAutoHide(self:GetFrameRef("trigger"))
        for i = 1, self:GetAttribute("count") do
            self:AddToAutoHide(self:GetFrameRef("button" .. i))
        end
    ]])
    -- Hook rather than replace the secure template's OnShow/OnHide scripts.
    animator = CreateFrame("Frame", "ForeverAuraOrbitAnimator", UIParent)
    panel:HookScript("OnShow", function()
        updateActive(true)
        if InCombatLockdown() then return end
        elapsed = 0
        position(0)
        animator:SetScript("OnUpdate", animate)
    end)
    panel:HookScript("OnHide", function()
        animator:SetScript("OnUpdate", nil)
        for _, b in ipairs(buttons) do b.pulseAnimation:Stop() end
        GameTooltip:Hide()
    end)
end

-- Protected frames cannot anchor directly to Texture/FontString regions.
-- Anchor to the owning Frame, with offsets measured at the region's center.
local function anchorToRegion(frame, region)
    local owner = region:GetParent()
    local rx, ry = region:GetCenter()
    local ox, oy = owner:GetCenter()
    if not rx or not ry or not ox or not oy then return false end
    local ownerScale = owner:GetEffectiveScale()
    local regionScale = region.GetEffectiveScale and region:GetEffectiveScale() or ownerScale
    local frameScale = frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", owner, "CENTER",
        (rx * regionScale - ox * ownerScale) / frameScale,
        (ry * regionScale - oy * ownerScale) / frameScale)
    return true
end

local function refresh()
    if InCombatLockdown() then pending = true; return end
    if not PlayerFrame then pending = true; return end
    if not root then createFrames() end
    panel:Hide()
    local main = PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    local portrait = PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContainer.PlayerPortrait or PlayerPortrait
    local level = (main and main.LevelBackgroundCircle) or PlayerLevelText
    if not portrait or not level then
        trigger:Hide()
        message("Could not find the default player portrait/level. Use /fao refresh after it loads.")
        return
    end
    if not anchorToRegion(root, portrait) or not anchorToRegion(trigger, level) then
        trigger:Hide()
        pending = true
        return
    end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", root, "CENTER")
    trigger:SetSize(math.max(22, level:GetWidth()), math.max(22, level:GetHeight()))
    radius = math.max(45, portrait:GetWidth() / 2 + SIZE / 2 + 5)
    local px, py = portrait:GetCenter()
    local lx, ly = level:GetCenter()
    if px and py and lx and ly then
        -- GetCenter coordinates are expressed in the region's effective scale.
        local portraitScaleOwner = portrait.GetEffectiveScale and portrait or portrait:GetParent()
        local levelScaleOwner = level.GetEffectiveScale and level or level:GetParent()
        local ps, ls = portraitScaleOwner:GetEffectiveScale(), levelScaleOwner:GetEffectiveScale()
        local dx, dy = (lx * ls - px * ps) / root:GetEffectiveScale(), (ly * ls - py * ps) / root:GetEffectiveScale()
        startAngle, startRadius = math.deg(math.atan2(dy, dx)), math.sqrt(dx * dx + dy * dy)
    end
    auras = readAuras()
    for i, aura in ipairs(auras) do
        if not buttons[i] then buttons[i] = newButton(i) end
        local b = buttons[i]
        b.icon:SetTexture(aura.icon)
        b:SetAttribute("spell", aura.spellID)
        b:SetAttribute("final-x", (Core.Position(i, #auras, radius, 1, startAngle, startRadius)))
        local _, y = Core.Position(i, #auras, radius, 1, startAngle, startRadius)
        b:SetAttribute("final-y", y)
        b:Show()
        panel:SetFrameRef("button" .. i, b)
    end
    for i = #auras + 1, #buttons do buttons[i]:Hide() end
    panel:SetAttribute("count", #auras)
    position(1)
    trigger:SetShown(#auras > 0)
    updateActive()
    pending = false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then return end
        for _, name in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_COOLDOWN", "UPDATE_SHAPESHIFT_USABLE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD"}) do
            self:RegisterEvent(name)
        end
        self:RegisterUnitEvent("UNIT_AURA", "player")
        refresh()
        message("Loaded. Hover your level badge for your auras. /fao for status.")
    elseif event == "UNIT_AURA" then
        if unit == "player" and panel then updateActive() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_COOLDOWN" or event == "UPDATE_SHAPESHIFT_USABLE" then
        if panel then updateActive() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then refresh() end
    else
        refresh()
    end
end)

SLASH_FOREVERAURAORBIT1 = "/fao"
SLASH_FOREVERAURAORBIT2 = "/auraorbit"
SlashCmdList.FOREVERAURAORBIT = function(text)
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then message("This addon is for paladins."); return end
    if text and text:lower():match("^refresh") then refresh(); return end
    message(#auras .. " known auras. Hover your level badge; click an icon to activate. /fao refresh rebuilds the menu outside combat.")
    for _, aura in ipairs(auras) do message(aura.name .. " (" .. aura.spellID .. ")") end
end
