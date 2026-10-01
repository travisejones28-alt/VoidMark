-- VoidMark Damage Records
-- Lightweight highest-hit tracker. Keeps one record per ability; no hit history.
VoidMarkDamageRecords = VoidMarkDamageRecords or {}
local DR = VoidMarkDamageRecords

local function DB()
    SpyDB = SpyDB or {}
    SpyDB.VoidMarkDamageRecords = SpyDB.VoidMarkDamageRecords or {
        version = 1,
        partyAnnounce = true,
        records = {},
    }
    local db = SpyDB.VoidMarkDamageRecords
    if db.partyAnnounce == nil then db.partyAnnounce = true end
    db.records = db.records or {}
    return db
end

local function PlayerGUID()
    return UnitGUID and UnitGUID("player") or nil
end

local function TargetType(guid)
    if type(guid) == "string" and guid:match("^Player%-") then return "Player" end
    return "Mob"
end

local function Location()
    local zone = GetZoneText and GetZoneText() or "Unknown"
    local sub = GetSubZoneText and GetSubZoneText() or ""
    return zone, sub
end

local function SpellInfoSafe(spellID, fallback)
    local name, _, icon
    if GetSpellInfo and spellID then
        name, _, icon = GetSpellInfo(spellID)
    end
    return name or fallback or "Unknown", icon
end

local function RecordKey(kind, spellID, spellName)
    if kind == "SWING" then return "SWING" end
    if spellID then return "SPELL:" .. tostring(spellID) end
    return tostring(kind or "DAMAGE") .. ":" .. tostring(spellName or "Unknown")
end

local function AbilityLabel(record)
    if not record then return "Unknown" end
    if record.kind == "SWING" then return "Melee" end
    return tostring(record.spellName or "Unknown")
end

local function IconTag(record)
    local icon = record and tonumber(record.icon)
    if not icon then return "" end
    return "|T" .. tostring(icon) .. ":16:16:0:0|t "
end

local function ShortTarget(name)
    name = tostring(name or "Unknown")
    return name:match("^([^-]+)") or name
end

local function SelfNotice(record)
    local prefix = record.critical and "NEW HIGH CRIT!" or "NEW HIGH HIT!"
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cffb86cff[VoidMark]|r |cffffd34e" .. prefix .. "|r "
        .. IconTag(record) .. AbilityLabel(record)
        .. " |cffffffff" .. tostring(record.amount) .. "|r"
        .. " vs |cffffffff" .. ShortTarget(record.targetName) .. "|r"
    )
end

local function PartyNotice(record)
    local db = DB()
    if not db.partyAnnounce then return end
    local channel
    if IsInRaid and IsInRaid() then channel = "RAID"
    elseif IsInGroup and IsInGroup() then channel = "PARTY"
    else return end

    local prefix = record.critical and "NEW HIGH CRIT!" or "NEW HIGH HIT!"
    local message = prefix .. " " .. AbilityLabel(record) .. " - "
        .. tostring(record.amount) .. " vs " .. ShortTarget(record.targetName)
    SendChatMessage(message, channel)
end

local banner
local function ShowBanner(record)
    if not UIParent then return end
    if not banner then
        banner = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        banner:SetSize(440, 72)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -170)
        banner:SetFrameStrata("DIALOG")
        banner:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
        })
        banner:SetBackdropColor(0.04, 0.02, 0.07, 0.94)
        banner:SetBackdropBorderColor(0.66, 0.28, 0.90, 1)
        banner.Icon = banner:CreateTexture(nil, "ARTWORK")
        banner.Icon:SetSize(42, 42)
        banner.Icon:SetPoint("LEFT", banner, "LEFT", 14, 0)
        banner.Title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        banner.Title:SetPoint("TOPLEFT", banner.Icon, "TOPRIGHT", 12, -1)
        banner.Value = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        banner.Value:SetPoint("TOPLEFT", banner.Title, "BOTTOMLEFT", 0, -7)
        banner:Hide()
    end
    if record.icon then
        banner.Icon:SetTexture(record.icon)
        banner.Icon:Show()
    else
        banner.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    banner.Title:SetText(record.critical and "NEW HIGH CRIT" or "NEW HIGH HIT")
    banner.Value:SetText(AbilityLabel(record) .. "  •  " .. tostring(record.amount)
        .. "  →  " .. ShortTarget(record.targetName))
    banner:Show()
    local token = (banner._token or 0) + 1
    banner._token = token
    if C_Timer and C_Timer.After then
        C_Timer.After(3.0, function()
            if banner and banner._token == token then banner:Hide() end
        end)
    end
end

local function SaveRecord(kind, spellID, spellName, amount, critical, destGUID, destName)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local db = DB()
    local key = RecordKey(kind, spellID, spellName)
    local old = db.records[key]
    if old and (tonumber(old.amount) or 0) >= amount then return end

    local zone, sub = Location()
    local resolvedName, icon = SpellInfoSafe(spellID, spellName)
    if kind == "SWING" then
        resolvedName = "Melee"
        icon = "Interface\\Icons\\INV_Sword_04"
    end

    local record = {
        key = key,
        kind = kind,
        spellID = tonumber(spellID),
        spellName = resolvedName,
        icon = icon,
        amount = amount,
        critical = critical and true or false,
        targetName = tostring(destName or "Unknown"),
        targetGUID = tostring(destGUID or ""),
        targetType = TargetType(destGUID),
        time = GetServerTime and GetServerTime() or time(),
        zone = zone,
        subZone = sub,
        character = tostring(UnitName("player") or "?"),
        realm = tostring(GetRealmName and GetRealmName() or "?"),
    }
    db.records[key] = record
    db.overall = db.overall or nil
    if not db.overall or (tonumber(db.overall.amount) or 0) < amount then
        db.overall = record
    end

    SelfNotice(record)
    ShowBanner(record)
    PartyNotice(record)
    if DR.Refresh then DR:Refresh() end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DB()
        return
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or not CombatLogGetCurrentEventInfo then return end

    local info = { CombatLogGetCurrentEventInfo() }
    local subevent = info[2]
    local sourceGUID = info[4]
    if sourceGUID ~= PlayerGUID() then return end

    if subevent == "SWING_DAMAGE" then
        SaveRecord("SWING", nil, "Melee", info[12], info[18], info[8], info[9])
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE"
        or subevent == "RANGE_DAMAGE" then
        SaveRecord("SPELL", info[12], info[13], info[15], info[21], info[8], info[9])
    end
end)

local frame
local selectedKey = "__OVERALL"

local function SortedRecords()
    local out = {}
    for key, record in pairs(DB().records) do
        if type(record) == "table" then
            out[#out + 1] = { key = key, record = record }
        end
    end
    table.sort(out, function(a, b)
        return (tonumber(a.record.amount) or 0) > (tonumber(b.record.amount) or 0)
    end)
    return out
end

local function SelectedRecord()
    local db = DB()
    if selectedKey == "__OVERALL" then return db.overall end
    return db.records[selectedKey]
end

function DR:Refresh()
    if not frame then return end
    local db = DB()
    local r = SelectedRecord()
    frame.PartyButton.Text:SetText(db.partyAnnounce and "PARTY ANNOUNCE: ON" or "PARTY ANNOUNCE: OFF")
    if not r then
        frame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        frame.Ability:SetText("No damage records yet")
        frame.Amount:SetText("—")
        frame.Meta:SetText("Your first outgoing damage event will create a record.")
        frame.Location:SetText("")
        return
    end
    frame.Icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    frame.Ability:SetText(AbilityLabel(r))
    frame.Amount:SetText(tostring(r.amount) .. (r.critical and "  CRIT" or "  HIT"))
    local when = tonumber(r.time) and date("%b %d, %Y  %I:%M %p", tonumber(r.time)) or "?"
    frame.Meta:SetText(ShortTarget(r.targetName) .. "  •  " .. tostring(r.targetType or "?") .. "  •  " .. when)
    local loc = tostring(r.zone or "Unknown")
    if r.subZone and r.subZone ~= "" and r.subZone ~= r.zone then loc = loc .. " - " .. r.subZone end
    frame.Location:SetText(loc .. "  •  " .. tostring(r.character or "?"))
end

local function BuildUI()
    if frame then return end
    frame = CreateFrame("Frame", "VoidMarkDamageRecordsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(470, 235)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    frame:SetBackdropColor(0.035, 0.02, 0.055, 0.98)
    frame:SetBackdropBorderColor(0.48, 0.20, 0.68, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -13)
    title:SetText("VOIDMARK — DAMAGE RECORDS")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    frame.Dropdown = CreateFrame("Frame", "VoidMarkDamageRecordsDropdown", frame, "UIDropDownMenuTemplate")
    frame.Dropdown:SetPoint("TOPLEFT", 2, -40)
    UIDropDownMenu_SetWidth(frame.Dropdown, 260)
    UIDropDownMenu_Initialize(frame.Dropdown, function(_, level)
        if level ~= 1 then return end
        local function Add(label, key, icon)
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.value = key
            info.icon = icon
            info.checked = selectedKey == key
            info.func = function()
                selectedKey = key
                UIDropDownMenu_SetSelectedValue(frame.Dropdown, key)
                UIDropDownMenu_SetText(frame.Dropdown, label)
                DR:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
        Add("Highest Damage Ever", "__OVERALL")
        for _, item in ipairs(SortedRecords()) do
            Add(AbilityLabel(item.record) .. "  —  " .. tostring(item.record.amount), item.key, item.record.icon)
        end
    end)
    UIDropDownMenu_SetSelectedValue(frame.Dropdown, selectedKey)
    UIDropDownMenu_SetText(frame.Dropdown, "Highest Damage Ever")

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetSize(44, 44)
    frame.Icon:SetPoint("TOPLEFT", 20, -92)

    frame.Ability = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.Ability:SetPoint("TOPLEFT", frame.Icon, "TOPRIGHT", 12, -1)

    frame.Amount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Amount:SetPoint("TOPLEFT", frame.Ability, "BOTTOMLEFT", 0, -5)

    frame.Meta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Meta:SetPoint("TOPLEFT", 20, -148)
    frame.Meta:SetPoint("RIGHT", -20, 0)
    frame.Meta:SetJustifyH("LEFT")

    frame.Location = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Location:SetPoint("TOPLEFT", frame.Meta, "BOTTOMLEFT", 0, -7)
    frame.Location:SetPoint("RIGHT", -20, 0)
    frame.Location:SetJustifyH("LEFT")

    frame.PartyButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.PartyButton:SetSize(180, 24)
    frame.PartyButton:SetPoint("BOTTOMLEFT", 18, 13)
    frame.PartyButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 6,
    })
    frame.PartyButton:SetBackdropColor(0.08, 0.035, 0.12, 1)
    frame.PartyButton:SetBackdropBorderColor(0.48, 0.20, 0.68, 1)
    frame.PartyButton.Text = frame.PartyButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.PartyButton.Text:SetAllPoints()
    frame.PartyButton:SetScript("OnClick", function()
        local db = DB()
        db.partyAnnounce = not db.partyAnnounce
        DR:Refresh()
    end)

    frame:Hide()
    DR:Refresh()
end

function DR:Toggle()
    BuildUI()
    if frame:IsShown() then
        frame:Hide()
    else
        DR:Refresh()
        frame:Show()
    end
end
