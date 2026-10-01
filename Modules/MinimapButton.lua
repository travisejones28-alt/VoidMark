-- VoidMark native minimap button
-- Lightweight, dependency-free launcher. Position and visibility are account-wide.
local addonName = ...
VoidMarkMinimap = VoidMarkMinimap or {}
local MM = VoidMarkMinimap

local RADIUS = 80

local function DB()
    SpyDB = SpyDB or {}
    SpyDB.VoidMarkMinimap = type(SpyDB.VoidMarkMinimap) == "table" and SpyDB.VoidMarkMinimap or {}
    local db = SpyDB.VoidMarkMinimap
    if db.show == nil then db.show = true end
    if type(db.angle) ~= "number" then db.angle = 225 end
    return db
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

function MM:UpdatePosition()
    if not self.button or not Minimap then return end
    local angle = math.rad(DB().angle or 225)
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

function MM:SetShown(show)
    local db = DB()
    db.show = show and true or false
    if self.button then
        if db.show then self.button:Show() else self.button:Hide() end
    end
end

function MM:ToggleMain()
    if not Spy or not Spy.MainWindow then return end
    if InCombatLockdown and InCombatLockdown() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("VoidMark: window toggle unavailable during combat.", 0.75, 0.45, 1.0, 1.0)
        end
        return
    end
    if Spy.MainWindow:IsShown() then Spy.MainWindow:Hide() else Spy.MainWindow:Show() end
end

function MM:OpenSettings(button)
    local vm = Spy and Spy.VoidMark
    if vm and vm.OpenGearMenu then
        vm:OpenGearMenu(button)
    elseif Spy and Spy.ShowConfig then
        Spy:ShowConfig()
    end
end

function -- SavedVariables are guaranteed ready at ADDON_LOADED.  Do not initialize
-- SpyDB during file execution; doing so could race the client's SavedVariables
-- restore on some Classic builds.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loaded)
    if loaded ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    MM:Create()
end)
    if self.button or not Minimap then return end

    local b = CreateFrame("Button", "VoidMarkMinimapButton", Minimap, "BackdropTemplate")
    self.button = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    b:SetBackdropColor(0.025, 0.010, 0.040, 0.96)
    b:SetBackdropBorderColor(0.58, 0.20, 0.86, 1)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
    b.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    b.icon:SetVertexColor(0.78, 0.48, 1.0, 1)

    b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.highlight:SetAllPoints(b)
    b.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.highlight:SetBlendMode("ADD")

    b:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then MM:OpenSettings(self) else MM:ToggleMain() end
    end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local scale = UIParent:GetEffectiveScale()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            if not mx or not my or not cx or not cy or not scale or scale == 0 then return end
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(Atan2(cy - my, cx - mx))
            DB().angle = angle
            MM:UpdatePosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.78, 0.38, 1.0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("VoidMark", 0.78, 0.45, 1.0)
        GameTooltip:AddLine("Left-click: Show / hide VoidMark", 0.88, 0.88, 0.92)
        GameTooltip:AddLine("Right-click: Settings / tools", 0.88, 0.88, 0.92)
        GameTooltip:AddLine("Drag: Move around minimap", 0.62, 0.56, 0.68)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.58, 0.20, 0.86, 1)
        GameTooltip:Hide()
    end)

    self:UpdatePosition()
    if DB().show then b:Show() else b:Hide() end
end

-- Add the visibility switch to VoidMark's existing General options without
-- adding another settings window or library.
if Spy and Spy.options and Spy.options.args and Spy.options.args.General and Spy.options.args.General.args then
    Spy.options.args.General.args.VoidMarkMinimapButton = {
        name = "Show Minimap Button",
        desc = "Show the VoidMark launcher beside the minimap.",
        type = "toggle",
        order = 10,
        width = "full",
        get = function() return DB().show end,
        set = function(_, value) MM:SetShown(value) end,
    }
end

MM:Create()
