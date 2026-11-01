-- VoidMark Target Range (Classic Era)
-- Spell-based range bands: no enemy position/direction API is assumed.
local TR = CreateFrame("Frame", "VoidMarkTargetRangeEvents")
local panel, nameText, rangeText, hintText
local db
local elapsed = 0

local function Chat(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffbd78ffVoidMark Target:|r " .. s) end
end

local function SavePosition()
    if not panel or not db then return end
    local x, y = panel:GetCenter()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if x and y and w and h then
        db.x = x - w / 2
        db.y = y - h / 2
    end
end

local function InRange(spell)
    if not IsSpellInRange or not GetSpellInfo then return nil end
    local name = GetSpellInfo(spell)
    if not name then return nil end
    local ok, result = pcall(IsSpellInRange, name, "target")
    if ok and (result == 1 or result == 0) then return result == 1 end
    return nil
end

local function Update()
    if not panel or not db then return end
    if not db.enabled or not UnitExists("target") or not UnitCanAttack("player", "target")
        or UnitIsDead("target") then
        panel:Hide()
        return
    end
    panel:Show()
    nameText:SetText(UnitName("target") or "Enemy")
    -- The client does not provide a reliable heading to arbitrary enemy targets.
    -- Do not draw a misleading directional pointer.
    local melee = CheckInteractDistance and CheckInteractDistance("target", 3)
    local flay = InRange(15407)       -- Mind Flay rank 1; talent range may vary
    local pain = InRange(589)         -- Shadow Word: Pain rank 1; talent range may vary
    local text, color
    if melee then
        text, color = "Very close (~10 yd)", {0.30, 1.00, 0.52}
    elseif flay == true then
        text, color = "In Mind Flay range", {0.30, 1.00, 0.52}
    elseif pain == true then
        text, color = "In SW:P range", {1.00, 0.78, 0.25}
    elseif pain == false then
        text, color = "Outside SW:P range", {1.00, 0.29, 0.37}
    else
        text, color = "Range unavailable", {0.70, 0.64, 0.78}
    end
    rangeText:SetText(text)
    rangeText:SetTextColor(color[1], color[2], color[3])
end

local function Build()
    panel = CreateFrame("Frame", "VoidMarkTargetRangeFrame", UIParent)
    panel:SetSize(210, 76)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.025, 0.012, 0.045, 0.93)
    local border = panel:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetHeight(3)
    border:SetColorTexture(0.68, 0.28, 1.0, 1)
    nameText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOP", 0, -11)
    nameText:SetWidth(190)
    nameText:SetTextColor(0.85, 0.62, 1)
    rangeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    rangeText:SetPoint("TOP", nameText, "BOTTOM", 0, -6)
    rangeText:SetWidth(200)
    hintText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("BOTTOM", 0, 8)
    hintText:SetText("Drag to move  |  /vmrange")
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -145)
    panel:Hide()
end

TR:RegisterEvent("PLAYER_LOGIN")
TR:RegisterEvent("PLAYER_TARGET_CHANGED")
TR:RegisterEvent("PLAYER_ENTERING_WORLD")
TR:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        SpyDB = SpyDB or {}
        SpyDB.VoidMarkTargetRange = type(SpyDB.VoidMarkTargetRange) == "table" and SpyDB.VoidMarkTargetRange or {}
        db = SpyDB.VoidMarkTargetRange
        if db.enabled == nil then db.enabled = true end
        Build()
        SLASH_VOIDMARKTARGETRANGE1 = "/vmrange"
        SlashCmdList.VOIDMARKTARGETRANGE = function(msg)
            msg = (msg or ""):lower():match("^%s*(.-)%s*$")
            if msg == "on" then db.enabled = true
            elseif msg == "off" then db.enabled = false
            elseif msg == "reset" then
                db.x, db.y = 0, -145
                panel:ClearAllPoints()
                panel:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
            else db.enabled = not db.enabled end
            Update()
            Chat("Range display " .. (db.enabled and "ON" or "OFF") .. ". Commands: /vmrange on, off, reset.")
        end
    end
    Update()
end)
TR:SetScript("OnUpdate", function(self, dt)
    if not db or not db.enabled then return end
    elapsed = elapsed + dt
    if elapsed >= 0.25 then elapsed = 0; Update() end
end)
