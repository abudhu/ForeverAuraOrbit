local _, ns = ...
local Core = {}
ns.Core = Core

-- The stance API is authoritative on Forever, including server-specific auras.
local families = {
    {465, 10290, 643, 10291, 1032, 10292, 10293}, -- Devotion
    {7294, 10298, 10299, 10300, 10301}, -- Retribution
    {19746}, -- Concentration
    {19876, 19895, 19896}, -- Shadow resistance
    {19888, 19897, 19898}, -- Frost resistance
    {19891, 19899, 19900}, -- Fire resistance
    {20218}, -- Sanctity (talent)
    {32223}, -- Only included if actually known; unavailable on current Forever.
}

function Core.Collect(forms, isKnown, getInfo)
    if #forms == 0 and isKnown and getInfo then
        for _, ranks in ipairs(families) do
            for i = #ranks, 1, -1 do
                local id = ranks[i]
                if isKnown(id) then
                    local info = getInfo(id)
                    if info then
                        forms[#forms + 1] = {spellID=id, name=info.name, icon=info.icon, active=false}
                        break
                    end
                end
            end
        end
    end
    local result, byName = {}, {}
    for _, form in ipairs(forms) do
        if form.spellID and form.name then
            local previous = byName[form.name]
            if previous then
                result[previous] = {
                    spellID=form.spellID, name=form.name, icon=form.icon, formIndex=form.formIndex,
                    active=form.active or result[previous].active,
                }
            else
                result[#result + 1] = form
                byName[form.name] = #result
            end
        end
    end
    return result
end

-- A clockwise arc leaves the health/mana bars to the right unobstructed.
-- Expand the radius for unusually large/custom aura lists instead of overlapping.
function Core.Position(index, count, radius, progress, startAngle, startRadius, endAngle)
    startAngle, startRadius = startAngle or -65, startRadius or 26
    local span = math.min(220, math.max(0, count - 1) * 40)
    if endAngle then span = math.min(span, math.max(0, startAngle - endAngle)) end
    local step = count > 1 and span / (count - 1) or 0
    if step > 0 then radius = math.max(radius, 30 / (2 * math.sin(math.rad(step / 2)))) end
    local p = math.max(0, math.min(1, progress))
    local eased = 1 - (1 - p)^3
    local angle = math.rad(startAngle - (index - 1) * step * eased)
    local r = startRadius + (radius - startRadius) * eased
    return r * math.cos(angle), r * math.sin(angle)
end

-- Fit a left/top arc outside the badge and before the bar's left edge.
-- Opening uses the fitted radius too, so visible icons never pass over the badge.
function Core.ArcLayout(count, baseRadius, badgeAngle, badgeRadius, badgeHalf, iconHalf, barLeft, gap)
    badgeAngle = (badgeAngle + 180) % 360 - 180
    local first = math.max(-170, math.min(-100, badgeAngle))
    local last = -280
    local radius = math.max(baseRadius, badgeRadius + badgeHalf + iconHalf + gap)
    local rightLimit = barLeft - iconHalf - gap
    for _ = 1, 16 do
        local span = math.min(220, math.max(0, count - 1) * 40, math.max(0, first - last))
        local step = count > 1 and span / (count - 1) or 0
        if step > 0 then radius = math.max(radius, 30 / (2 * math.sin(math.rad(step / 2)))) end
        if radius * math.cos(math.rad(last)) > rightLimit then
            local ratio = math.max(-0.999, math.min(1, rightLimit / radius))
            last = -360 + math.deg(math.acos(ratio)) + 0.01
        end
    end
    return radius, first, last
end
