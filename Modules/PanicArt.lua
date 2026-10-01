local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ROOT = "Interface\\AddOns\\VoidMark\\Media\\Panic\\"

local STYLE_SPEC = {
    skull = {
        texture = ROOT .. "panic_voidskull.tga",
        frameW = 100, frameH = 126,
        x = 0, y = -18, width = 52, size = 13,
    },
    diamond = {
        texture = ROOT .. "panic_diamond.tga",
        frameW = 96, frameH = 96,
        x = 0, y = -8, width = 58, size = 13,
    },
    ring = {
        texture = ROOT .. "panic_ring.tga",
        frameW = 96, frameH = 96,
        x = 0, y = -2, width = 58, size = 13,
    },
    banner = {
        texture = ROOT .. "panic_banner.tga",
        frameW = 214, frameH = 72,
        x = 39, y = 0, width = 132, size = 13,
    },
}

local TICK = 0.15
local elapsedSinceUpdate = 0
local lastStyle, lastCount, lastText = nil, nil, nil

local function CurrentStyle()
    local style = (SpyDB and SpyDB.VoidMarkPanicStyle) or "skull"
    if not STYLE_SPEC[style] then style = "skull" end
    return style
end

local function ThreatCount()
    local GT = TaliaaGankTracker
    if GT and GT.GetRecentEnemyCount then
        local ok, count = pcall(GT.GetRecentEnemyCount, GT, 30)
        if ok then return tonumber(count) or 0 end
    end
    return 0
end

local function ThreatColor(count)
    if count >= 6 then
        return 1.00, 0.94, 0.92
    elseif count >= 3 then
        return 1.00, 0.82, 0.82
    elseif count >= 1 then
        return 1.00, 0.58, 0.68
    else
        return 0.82, 0.60, 0.96
    end
end

local function GetObjects()
    local GT = TaliaaGankTracker
    local pf = GT and GT.PanicFrame
    local b = pf and pf.Button
    local label = b and b.Label
    if not label then return nil end
    return GT, pf, b, label
end

local function EnsureArt(button)
    if button.PanicArt then return end

    button.PanicArt = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    button.PanicArt:SetAllPoints(button)

    button.PanicPulse = button:CreateTexture(nil, "ARTWORK", nil, -1)
    button.PanicPulse:SetAllPoints(button)
    button.PanicPulse:SetBlendMode("ADD")
    button.PanicPulse:SetAlpha(0)

    if button.Icon then button.Icon:Hide() end
    if button.Accent then button.Accent:Hide() end
end

local function ApplyStyle(force)
    local _, pf, button, label = GetObjects()
    if not label then return end
    EnsureArt(button)

    local style = CurrentStyle()
    local spec = STYLE_SPEC[style]
    if not force and lastStyle == style then return end
    lastStyle = style

    pf:SetSize(spec.frameW, spec.frameH)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 0)
    button:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", 0, 0)

    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)

    button.PanicArt:SetTexture(spec.texture)
    button.PanicArt:SetAllPoints(button)
    button.PanicPulse:SetTexture(spec.texture)
    button.PanicPulse:SetAllPoints(button)

    if button.Icon then button.Icon:Hide() end
    if button.Accent then button.Accent:Hide() end

    label:ClearAllPoints()
    label:SetPoint("CENTER", button, "CENTER", spec.x, spec.y)
    label:SetWidth(spec.width)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    label:SetFont(FONT, spec.size, "OUTLINE")
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 1)
end

local function UpdateDisplay(force)
    local _, _, button, label = GetObjects()
    if not label then return end

    ApplyStyle(force)
    local style = lastStyle or CurrentStyle()
    local count = ThreatCount()

    local text
    if style == "banner" then
        text = string.format("PANIC   %d THREAT%s", count, count == 1 and "" or "S")
    else
        text = string.format("PANIC\n%d", count)
    end

    if force or count ~= lastCount or text ~= lastText then
        label:SetText(text)
        lastCount = count
        lastText = text
    end

    local r, g, b = ThreatColor(count)
    label:SetTextColor(r, g, b, 1)

    if button.PanicPulse then
        button.PanicPulse:SetVertexColor(r, g, b, 1)
        local alpha = 0.08
        if count >= 6 then
            alpha = 0.28
        elseif count >= 3 then
            alpha = 0.20
        elseif count >= 1 then
            alpha = 0.12
        end
        button.PanicPulse:SetAlpha(alpha)
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function()
    C_Timer.After(0.5, function() UpdateDisplay(true) end)
end)
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < TICK then return end
    elapsedSinceUpdate = 0

    local _, pf = GetObjects()
    if not pf or not pf:IsShown() then return end
    UpdateDisplay(false)
end)
