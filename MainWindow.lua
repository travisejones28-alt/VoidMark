local SM = LibStub:GetLibrary("LibSharedMedia-3.0")
local Events = LibStub("AceEvent-3.0")
local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local _

--++ TALIAA: VOIDMARK COMBAT CLICK FIX BUILD ++--
Spy.VoidMarkCombatClickBuild = "2026-08-23-v1-fast-row"

--++ Local FrameFlash functions derived from Blizzard code ++--
local SpyFrameFlashManager = CreateFrame("FRAME");
local SPYFADEFRAMES = {};
local SPYFLASHFRAMES = {};
local SpyFrameFlashTimers = {};
local SpyFrameFlashTimerRefCount = {};

-- Fucntion to see if a frame is fading
function SpyFrameIsFading(frame)
	for index, value in pairs(SPYFADEFRAMES) do
		if ( value == frame ) then
			return 1;
		end
	end
	return nil;
end

-- Function to stop flashing --
local function SpyFrameFlashStop(frame)
    tDeleteItem(SPYFLASHFRAMES, frame);
    frame:SetAlpha(1.0);
    frame.flashTimer = nil;
    if (frame.syncId) then
        SpyFrameFlashTimerRefCount[frame.syncId] = SpyFrameFlashTimerRefCount[frame.syncId]-1;
        if (SpyFrameFlashTimerRefCount[frame.syncId] == 0) then
            SpyFrameFlashTimers[frame.syncId] = nil;
            SpyFrameFlashTimerRefCount[frame.syncId] = nil;
        end
        frame.syncId = nil;
    end
    if ( frame.showWhenDone ) then
        frame:Show();
    else
        frame:Hide();
    end
end

-- Call every frame to update flashing frames  --
local function SpyFrameFlash_OnUpdate(self, elapsed)
    local frame;
    local index = #SPYFLASHFRAMES;
     
    -- Update timers for all synced frames
    for syncId, timer in pairs(SpyFrameFlashTimers) do
        SpyFrameFlashTimers[syncId] = timer + elapsed;
    end
     
    while SPYFLASHFRAMES[index] do
        frame = SPYFLASHFRAMES[index];
        frame.flashTimer = frame.flashTimer + elapsed;
        if ( (frame.flashTimer > frame.flashDuration) and frame.flashDuration ~= -1 ) then
            SpyFrameFlashStop(frame);
        else
            local flashTime = frame.flashTimer;
            local alpha;
            if (frame.syncId) then
                flashTime = SpyFrameFlashTimers[frame.syncId];
            end
            flashTime = flashTime%(frame.fadeInTime+frame.fadeOutTime+(frame.flashInHoldTime or 0)+(frame.flashOutHoldTime or 0));
            if (flashTime < frame.fadeInTime) then
                alpha = flashTime/frame.fadeInTime;
            elseif (flashTime < frame.fadeInTime+(frame.flashInHoldTime or 0)) then
                alpha = 1;
            elseif (flashTime < frame.fadeInTime+(frame.flashInHoldTime or 0)+frame.fadeOutTime) then
                alpha = 1 - ((flashTime - frame.fadeInTime - (frame.flashInHoldTime or 0))/frame.fadeOutTime);
            else
                alpha = 0;
            end
            frame:SetAlpha(alpha);
            frame:Show();
        end
        -- Loop in reverse so that removing frames is safe
        index = index - 1;
    end
    if ( #SPYFLASHFRAMES == 0 ) then
        self:SetScript("OnUpdate", nil);
    end
end

-- Function to start a frame flashing
local function SpyFrameFlash(frame, fadeInTime, fadeOutTime, flashDuration, showWhenDone, flashInHoldTime, flashOutHoldTime, syncId)
    if ( frame ) then
        local index = 1;
        -- If frame is already set to flash then return
        while SPYFLASHFRAMES[index] do		
            if ( SPYFLASHFRAMES[index] == frame ) then
                return;
            end
            index = index + 1;
        end
        if (syncId) then
            frame.syncId = syncId;
            if (SpyFrameFlashTimers[syncId] == nil) then
                SpyFrameFlashTimers[syncId] = 0;
                SpyFrameFlashTimerRefCount[syncId] = 0;
            end
            SpyFrameFlashTimerRefCount[syncId] = SpyFrameFlashTimerRefCount[syncId]+1;
        else
            frame.syncId = nil;
        end
        -- Time it takes to fade in a flashing frame
        frame.fadeInTime = fadeInTime;
        -- Time it takes to fade out a flashing frame
        frame.fadeOutTime = fadeOutTime;
        -- How long to keep the frame flashing
        frame.flashDuration = flashDuration;
        -- Show the flashing frame when the fadeOutTime has passed
        frame.showWhenDone = showWhenDone;
        -- Internal timer
        frame.flashTimer = 0;
        -- How long to hold the faded in state
        frame.flashInHoldTime = flashInHoldTime;
        -- How long to hold the faded out state
        frame.flashOutHoldTime = flashOutHoldTime;
         
        tinsert(SPYFLASHFRAMES, frame);		
         
       SpyFrameFlashManager:SetScript("OnUpdate", SpyFrameFlash_OnUpdate);
    end
end

function Spy:SetFontSize(string, size)
	local Font, Height, Flags = string:GetFont()
	string:SetFont(Font, size, Flags)
end

function Spy:CreateMapNote(num)
	-- Removed: VoidMark does not create map/minimap pins.
	return
end

function Spy:CreateRow(num)
	local rowmin = 1
	if num < rowmin or Spy.MainWindow.Rows[num] then
		return
	end

	local row = CreateFrame("Button", "Spy_MainWindow_Bar"..num, Spy.MainWindow, "SecureActionButtonTemplate")
	row:SetPoint("TOPLEFT", Spy.MainWindow, "TOPLEFT", 2, -34 - (Spy.db.profile.MainWindow.RowHeight + Spy.db.profile.MainWindow.RowSpacing) * (num - 1))
	row:SetHeight(Spy.db.profile.MainWindow.RowHeight)
	row:SetWidth(Spy.MainWindow:GetWidth() - 4)

	Spy:SetupBar(row)
	Spy.MainWindow.Rows[num] = row
	Spy.MainWindow.Rows[num]:Hide()
	row.id = num

	-- VoidMark combat click assist: pre-create a VISUAL-only flash layer while
	-- secure frames are writable. During combat we only show/hide/recolor this
	-- texture; we never reassign the row's protected target attributes.
	row.VoidMarkCombatFlash = row:CreateTexture(nil, "OVERLAY")
	row.VoidMarkCombatFlash:SetAllPoints(row)
	row.VoidMarkCombatFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
	row.VoidMarkCombatFlash:SetVertexColor(0.72, 0.32, 1.00, 0.28)
	row.VoidMarkCombatFlash:SetBlendMode("ADD")
	row.VoidMarkCombatFlash:Hide()

	-- TaliaaSpy: secure targeting is configured OUTSIDE combat.
	-- We never change secure attributes from the click handler.
	row:RegisterForClicks(
		"LeftButtonDown",
		"LeftButtonUp",
		"RightButtonDown",
		"RightButtonUp"
	)
	row:SetAttribute("type1", "macro")
	row:SetAttribute("macro", nil)
	row:SetAttribute("macrotext1", "/targetexact nil")
	row:SetAttribute("macrotext", "/targetexact nil")

	row:SetScript("OnEnter", function(self)
		Spy:ShowTooltip(self, true)
	end)
	row:SetScript("OnLeave", function(self)
		Spy:ShowTooltip(self, false)
	end)
	-- Use PreClick, not OnClick. SecureActionButtonTemplate performs
	-- its protected target action as part of the secure click path.
	-- Replacing OnClick can prevent that secure action from firing.
	row:SetScript("PreClick", function(self, button)
		Spy:ButtonClicked(self, button)
	end)
end

function Spy:SetupBar(row)
	row.StatusBar = CreateFrame("StatusBar", nil, row)
	row.StatusBar:SetAllPoints(row)

	local BarTexture
	if not BarTexture then
		BarTexture = Spy.db.profile.BarTexture
	end

	if not BarTexture then
		BarTexture = SM:Fetch("statusbar", "flat")
	else
		BarTexture = SM:Fetch("statusbar", BarTexture)
	end
	row.StatusBar:SetStatusBarTexture(BarTexture)
	row.StatusBar:SetStatusBarColor(.5, .5, .5, 0.8)
	row.StatusBar:SetMinMaxValues(0, 100)
	row.StatusBar:SetValue(100)
	row.StatusBar:Show()

	row.LeftText = row.StatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.LeftText:SetPoint("LEFT", row.StatusBar, "LEFT", 2, 0)
	row.LeftText:SetJustifyH("LEFT")
	row.LeftText:SetHeight(Spy.db.profile.MainWindow.TextHeight)
	row.LeftText:SetTextColor(1, 1, 1, 1)
	Spy:SetFontSize(row.LeftText, math.max(Spy.db.profile.MainWindow.RowHeight * 0.75, Spy.db.profile.MainWindow.RowHeight - 3) * 1.20)
	Spy:AddFontString(row.LeftText)

	row.RightText = row.StatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.RightText:SetPoint("RIGHT", row.StatusBar, "RIGHT", -2, 0)	
	row.RightText:SetJustifyH("RIGHT")
	row.RightText:SetTextColor(1, 1, 1, 1)
	Spy:SetFontSize(row.RightText, math.max(Spy.db.profile.MainWindow.RowHeight * 0.65, Spy.db.profile.MainWindow.RowHeight - 12) * 1.20)		
	Spy:AddFontString(row.RightText)

	Spy.Colors:RegisterFont("Bar", "Bar Text", row.LeftText)
	Spy.Colors:RegisterFont("Bar", "Bar Text", row.RightText)
end

function Spy:UpdateBarTextures()
	for k, v in pairs(Spy.MainWindow.Rows) do
		v.StatusBar:SetStatusBarTexture(SM:Fetch(SM.MediaType.STATUSBAR, Spy.db.profile.BarTexture))
	end
	if Spy.db.profile.Font then
		Spy:SetFont(Spy.db.profile.Font)
	end
end

function Spy:SetBarTextures(handle)
	local Texture = SM:Fetch(SM.MediaType.STATUSBAR,handle)
	Spy.db.profile.BarTexture=handle
	for k, v in pairs(Spy.MainWindow.Rows) do
		v.StatusBar:SetStatusBarTexture(Texture)
	end
end

local info = {}
function Spy_CreateBarDropdown(self, level)
	if not level then return end
	for k in pairs(info) do info[k] = nil end
	if self and self.relativeTo.LeftText then
		local player = self.relativeTo.Name or Spy.ButtonName[self.relativeTo.id] or self.relativeTo.LeftText:GetText()
		if level == 1 then
			info.isTitle = 1
			info.text = player
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()

			if Spy.db.profile.CurrentList == 1 or Spy.db.profile.CurrentList == 2 then
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = true
				info.disabled = nil
				info.text = L["AnnounceDropDownMenu"]
				info.value = { ["Key"] = L["AnnounceDropDownMenu"] }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end

			if not SpyPerCharDB.KOSData[player] then
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["AddToKOSList"]
				info.func = function() Spy:ToggleKOSPlayer(true, player) end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			else
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = true
				info.disabled = nil
				info.text = L["KOSReasonDropDownMenu"]
				info.value = { ["Key"] = L["KOSReasonDropDownMenu"] }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["RemoveFromKOSList"]
				info.func = function() Spy:ToggleKOSPlayer(false, player) end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end
			if not SpyPerCharDB.IgnoreData[player] then
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["AddToIgnoreList"]
				info.func = function() Spy:ToggleIgnorePlayer(true, player) end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			else
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["RemoveFromIgnoreList"]
				info.func = function() Spy:ToggleIgnorePlayer(false, player) end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end

			if Spy.db.profile.CurrentList == 1 then
				info.isTitle = nil
				info.notCheckable = true
				info.disabled = nil
				info.text = L["Clear"]
				info.func = function() Spy:RemovePlayerFromList(player) end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end
		elseif level == 2 then
			local key = UIDROPDOWNMENU_MENU_VALUE["Key"]
			info = UIDropDownMenu_CreateInfo()

			if key == L["AnnounceDropDownMenu"] and (Spy.db.profile.CurrentList == 1 or Spy.db.profile.CurrentList == 2) then
				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["PartyDropDownMenu"]
				info.func = function() Spy:AnnouncePlayer(player, "PARTY") end
				info.value = { ["Key"] = key; ["Subkey"] = 1; }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["RaidDropDownMenu"]
				info.func = function() Spy:AnnouncePlayer(player, "RAID") end
				info.value = { ["Key"] = key; ["Subkey"] = 2; }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["GuildDropDownMenu"]
				info.func = function() Spy:AnnouncePlayer(player, "GUILD") end
				info.value = { ["Key"] = key; ["Subkey"] = 3; }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["LocalDefenseDropDownMenu"]
				info.func = function() Spy:AnnouncePlayer(player, "LOCAL") end
				info.value = { ["Key"] = key; ["Subkey"] = 4; }
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end

			if key == L["KOSReasonDropDownMenu"] then
				for i = 1, Spy_KOSReasonListLength do
					local reason = Spy_KOSReasonList[i]
					info.isTitle = nil
					info.notCheckable = true
					info.hasArrow = true
					info.disabled = nil
					info.text = reason.title
					info.value = { ["Key"] = key; ["Subkey"] = reason.title; ["Index"] = i; }
					info.arg1 = self.relativeTo.name
					UIDropDownMenu_AddButton(info, level)
				end

				info.isTitle = nil
				info.notCheckable = true
				info.hasArrow = false
				info.disabled = nil
				info.text = L["KOSReasonClear"]
				info.func = function()
					Spy:SetKOSReason(player, nil)
					CloseDropDownMenus(1)
				end
				info.value = nil
				info.arg1 = self.relativeTo.name
				UIDropDownMenu_AddButton(info, level)
			end
		elseif level == 3 then
			local key = UIDROPDOWNMENU_MENU_VALUE["Key"]
			local subkey = UIDROPDOWNMENU_MENU_VALUE["Subkey"]
			local index = UIDROPDOWNMENU_MENU_VALUE["Index"]
			local playerData = SpyPerCharDB.PlayerData[player]
			if key == L["KOSReasonDropDownMenu"] then
				for v, reason in pairs(Spy_KOSReasonList[index].content) do
					info.isTitle = nil
					info.notCheckable = false
					info.hasArrow = false
					info.disabled = nil
					info.text = reason
					info.func = function()
						Spy:SetKOSReason(player, reason)
						CloseDropDownMenus(1)
					end
					info.checked = nil
					if playerData and playerData.reason and playerData.reason[reason] == true then
						info.checked = true
					end
					info.value = { ["Key"] = subkey; ["Subkey"] = index; }
					info.arg1 = self.relativeTo.name
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end
end

function Spy:BarDropDownOpen(myframe)
	Spy_BarDropDownMenu = CreateFrame("Frame", "Spy_BarDropDownMenu", myframe)
	Spy_BarDropDownMenu.displayMode = "MENU"
	Spy_BarDropDownMenu.initialize	= Spy_CreateBarDropdown

	local leftPos = myframe:GetLeft()
	local rightPos = myframe:GetRight()
	local side
	local oside
	if not rightPos then
		rightPos = 0
	end
	if not leftPos then
		leftPos = 0
	end

	local rightDist = GetScreenWidth() - rightPos

	if leftPos and rightDist < leftPos then
		side = "TOPLEFT"
		oside = "TOPRIGHT"
	else
		side = "TOPRIGHT"
		oside = "TOPLEFT"
	end
	UIDropDownMenu_SetAnchor(Spy_BarDropDownMenu, 0, 0, oside, myframe, side)
end

function Spy:SetupMainWindowButtons()
	for k, v in pairs(Spy.db.profile.MainWindow.Buttons) do
		if v then
			Spy.MainWindow[k]:Show()
			Spy.MainWindow[k]:SetWidth(16)
		else
			Spy.MainWindow[k]:SetWidth(1)
			Spy.MainWindow[k]:Hide()
		end
	end
end

function Spy:CreateMainWindow()
	if not Spy.MainWindow then
		Spy.MainWindow = Spy:CreateFrame("Spy_MainWindow", L["Nearby"], 34, 200,
		function()
			Spy.db.profile.MainWindowVis = true
		end,
		function()
			Spy.db.profile.MainWindowVis = false
		end)

		Spy:UpdateMainWindow()
	
		local theFrame = Spy.MainWindow
		theFrame:SetResizable(true)
--		theFrame:SetMinResize(90, 34)
--		theFrame:SetMaxResize(300, 264)
		theFrame:SetResizeBounds(90, 34, 300, 264)
		theFrame:SetScript("OnSizeChanged",
		function(self)
			if (self.isResizing) then
				Spy:ResizeMainWindow()
			end
		end)
		theFrame:SetMovable(true)
        theFrame:EnableMouseWheel(true)	
		theFrame:SetScript("OnMouseWheel", function(self, delta)
			Spy:MainWindowScroll(delta)
		end)
		theFrame.TitleClick = CreateFrame("FRAME", nil, theFrame)
		theFrame.TitleClick:SetAllPoints(theFrame.Title)
		theFrame.TitleClick:EnableMouse(true)
		theFrame.TitleClick:SetScript("OnMouseDown", function(self, button) 
			local parent = self:GetParent()
			-- Stage 1 Hotfix 2: this frame owns protected SecureActionButton rows.
			-- Moving the protected frame during combat is blocked by Blizzard's
			-- restricted execution environment, so do not attempt StartMoving here.
			if InCombatLockdown() then
				return
			end
			if (((not parent.isLocked) or (parent.isLocked == 0)) and (button == "LeftButton")) then
				Spy:SetWindowTop(parent)
				parent:StartMoving();
				parent.isMoving = true;
			end
		end)
		theFrame.TitleClick:SetScript("OnMouseUp", function(self) 
			local parent = self:GetParent()
			if (parent.isMoving) then
				parent:StopMovingOrSizing();
				parent.isMoving = false;
				Spy:SaveMainWindowPosition()
			end
		end)
        theFrame.TitleClick:EnableMouseWheel(true)		
		theFrame.TitleClick:SetScript("OnMouseWheel", function(self, delta)
			if not IsAltKeyDown() then
				return
			end
			if delta > 0 then
				Spy:MainWindowPrevMode()
			else
				Spy:MainWindowNextMode()
			end
		end)


        -- Stage 1 Hotfix 2:
        -- Removed the SecureHandlerDragTemplate experiment. Restricted secure
        -- snippets do not expose StartMoving()/StopMovingOrSizing() for this
        -- protected window, which caused Blizzard_RestrictedAddOnEnvironment
        -- errors when dragging in combat. Combat-safe movement will be handled
        -- as part of the Stage 2 window architecture instead.

		if not Spy.db.profile.InvertSpy then
			theFrame.DragBottomRight = CreateFrame("Button", "SpyResizeGripRight", theFrame)
			theFrame.DragBottomRight:Show()
			theFrame.DragBottomRight:SetFrameLevel(theFrame:GetFrameLevel() + 10)
			theFrame.DragBottomRight:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-bottomright.tga")
			theFrame.DragBottomRight:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-bottomright.tga")
			theFrame.DragBottomRight:SetWidth(16)
			theFrame.DragBottomRight:SetHeight(16)
			theFrame.DragBottomRight:SetAlpha(0)
			theFrame.DragBottomRight:SetPoint("BOTTOMRIGHT", theFrame, "BOTTOMRIGHT", 0, 0)
			theFrame.DragBottomRight:EnableMouse(true)
			theFrame.DragBottomRight:SetScript("OnEnter", function(self)
				theFrame.DragBottomRight:SetAlpha(1)
			end)
			theFrame.DragBottomRight:SetScript("OnMouseDown", function(self, button)
				if (((not self:GetParent().isLocked) or (self:GetParent().isLocked == 0)) and (button == "LeftButton")) then 
					self:GetParent().isResizing = true;
					self:GetParent():StartSizing("BOTTOMRIGHT") 
				end
			end)
			theFrame.DragBottomRight:SetScript("OnMouseUp", function(self, button)
				if self:GetParent().isResizing == true then
					self:GetParent():StopMovingOrSizing();
					Spy:SaveMainWindowPosition();
					Spy:RefreshCurrentList();
					self:GetParent().isResizing = false;
				end
			end)
			theFrame.DragBottomRight:SetScript("OnLeave", function(self)
				theFrame.DragBottomRight:SetAlpha(0)
			end)
		
			theFrame.DragBottomLeft = CreateFrame("Button", "SpyResizeGripLeft", theFrame)
			theFrame.DragBottomLeft:Show()
			theFrame.DragBottomLeft:SetFrameLevel(theFrame:GetFrameLevel() + 10)
			theFrame.DragBottomLeft:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-bottomleft.tga")
			theFrame.DragBottomLeft:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-bottomleft.tga")
			theFrame.DragBottomLeft:SetWidth(16)
			theFrame.DragBottomLeft:SetHeight(16)
			theFrame.DragBottomLeft:SetAlpha(0)		
			theFrame.DragBottomLeft:SetPoint("BOTTOMLEFT", theFrame, "BOTTOMLEFT", 0, 0)
			theFrame.DragBottomLeft:EnableMouse(true)
			theFrame.DragBottomLeft:SetScript("OnEnter", function(self)
				theFrame.DragBottomLeft:SetAlpha(1)
			end)
			theFrame.DragBottomLeft:SetScript("OnMouseDown", function(self, button)
				if (((not self:GetParent().isLocked) or (self:GetParent().isLocked == 0)) and (button == "LeftButton")) then
					self:GetParent().isResizing = true;
					self:GetParent():StartSizing("BOTTOMLEFT")
				end
			end)
			theFrame.DragBottomLeft:SetScript("OnMouseUp", function(self, button)
				if self:GetParent().isResizing == true then
					self:GetParent():StopMovingOrSizing();
					Spy:SaveMainWindowPosition();
					Spy:RefreshCurrentList();
					self:GetParent().isResizing = false;
				end
			end)
			theFrame.DragBottomLeft:SetScript("OnLeave", function(self)
				theFrame.DragBottomLeft:SetAlpha(0)
			end)
		else
			theFrame.DragTopRight = CreateFrame("Button", "SpyResizeGripRight", theFrame)
			theFrame.DragTopRight:Show()
			theFrame.DragTopRight:SetFrameLevel(theFrame:GetFrameLevel() + 10)
			theFrame.DragTopRight:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-topright.tga")
			theFrame.DragTopRight:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-topright.tga")
			theFrame.DragTopRight:SetWidth(16)
			theFrame.DragTopRight:SetHeight(16)
			theFrame.DragTopRight:SetAlpha(0)
			theFrame.DragTopRight:SetPoint("TOPRIGHT", theFrame, "TOPRIGHT", 0, -32)
			theFrame.DragTopRight:EnableMouse(true)
			theFrame.DragTopRight:SetScript("OnEnter", function(self)
				theFrame.DragTopRight:SetAlpha(1)
			end)
			theFrame.DragTopRight:SetScript("OnMouseDown", function(self, button)
				if (((not self:GetParent().isLocked) or (self:GetParent().isLocked == 0)) and (button == "LeftButton")) then
					self:GetParent().isResizing = true;
					self:GetParent():StartSizing("TOPRIGHT")
				end
			end)
			theFrame.DragTopRight:SetScript("OnMouseUp", function(self, button)
				if self:GetParent().isResizing == true then
					self:GetParent():StopMovingOrSizing();
					Spy:SaveMainWindowPosition();
					Spy:RefreshCurrentList();
					self:GetParent().isResizing = false;
				end
			end)
			theFrame.DragTopRight:SetScript("OnLeave", function(self)
				theFrame.DragTopRight:SetAlpha(0)
			end)
		
			theFrame.DragTopLeft = CreateFrame("Button", "SpyResizeGripLeft", theFrame)
			theFrame.DragTopLeft:Show()
			theFrame.DragTopLeft:SetFrameLevel(theFrame:GetFrameLevel() + 10)
			theFrame.DragTopLeft:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-topleft.tga")
			theFrame.DragTopLeft:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\resize-topleft.tga")
			theFrame.DragTopLeft:SetWidth(16)
			theFrame.DragTopLeft:SetHeight(16)
			theFrame.DragTopLeft:SetAlpha(0)		
			theFrame.DragTopLeft:SetPoint("TOPLEFT", theFrame, "TOPLEFT", 0, -32)
			theFrame.DragTopLeft:EnableMouse(true)
			theFrame.DragTopLeft:SetScript("OnEnter", function(self)
				theFrame.DragTopLeft:SetAlpha(1)
			end)		
			theFrame.DragTopLeft:SetScript("OnMouseDown", function(self, button)
				if (((not self:GetParent().isLocked) or (self:GetParent().isLocked == 0)) and (button == "LeftButton")) then
					self:GetParent().isResizing = true;
					self:GetParent():StartSizing("TOPLEFT")
				end
			end)
			theFrame.DragTopLeft:SetScript("OnMouseUp", function(self, button)
				if self:GetParent().isResizing == true then
					self:GetParent():StopMovingOrSizing();
					Spy:SaveMainWindowPosition();
					Spy:RefreshCurrentList();
					self:GetParent().isResizing = false;
				end
			end)
			theFrame.DragTopLeft:SetScript("OnLeave", function(self)
				theFrame.DragTopLeft:SetAlpha(0)
			end)
		end

		theFrame.RightButton = CreateFrame("Button", nil, theFrame)
		theFrame.RightButton:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\button-right.tga")
		theFrame.RightButton:SetPushedTexture("Interface\\AddOns\\VoidMark\\Textures\\button-right.tga")
		theFrame.RightButton:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\button-highlight.tga")
		theFrame.RightButton:SetWidth(16)
		theFrame.RightButton:SetHeight(16)
		if not Spy.db.profile.InvertSpy then 		
			theFrame.RightButton:SetPoint("TOPRIGHT", theFrame, "TOPRIGHT", -23, -14.5)
		else
			theFrame.RightButton:SetPoint("BOTTOMRIGHT", theFrame, "BOTTOMRIGHT", -23, -16.5)
		end		
		theFrame.RightButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["Left/Right"], 1, 0.82, 0, 1)
			GameTooltip:AddLine(L["Left/RightDescription"],0,0,0,1)
			GameTooltip:Show()
		end)
		theFrame.RightButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		theFrame.RightButton:SetScript("OnClick", function()
			Spy:MainWindowNextMode()
		end)
		theFrame.RightButton:SetFrameLevel(theFrame.RightButton:GetFrameLevel() + 1)

		theFrame.LeftButton = CreateFrame("Button", nil, theFrame)
		theFrame.LeftButton:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\button-left.tga")
		theFrame.LeftButton:SetPushedTexture("Interface\\AddOns\\VoidMark\\Textures\\button-left.tga")
		theFrame.LeftButton:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\button-highlight.tga")
		theFrame.LeftButton:SetWidth(16)
		theFrame.LeftButton:SetHeight(16)
		theFrame.LeftButton:SetPoint("RIGHT", theFrame.RightButton, "LEFT", 0, 0)
		theFrame.LeftButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["Left/Right"], 1, 0.82, 0, 1)
			GameTooltip:AddLine(L["Left/RightDescription"],0,0,0,1)
			GameTooltip:Show()
		end)
		theFrame.LeftButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		theFrame.LeftButton:SetScript("OnClick", function()
			Spy:MainWindowPrevMode()
		end)
		theFrame.LeftButton:SetFrameLevel(theFrame.LeftButton:GetFrameLevel() + 1)

		theFrame.ClearButton = CreateFrame("Button", nil, theFrame)
		theFrame.ClearButton:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\button-clear.tga")
		theFrame.ClearButton:SetPushedTexture("Interface\\AddOns\\VoidMark\\Textures\\button-clear.tga")
		theFrame.ClearButton:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\button-highlight.tga")
		theFrame.ClearButton:SetWidth(16)
		theFrame.ClearButton:SetHeight(16)
		theFrame.ClearButton:SetPoint("RIGHT", theFrame.LeftButton,"LEFT", 0, 0)
		theFrame.ClearButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["Clear"], 1, 0.82, 0, 1)
			GameTooltip:AddLine(L["ClearDescription"],0,0,0,1)
			GameTooltip:Show()
		end)
		theFrame.ClearButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		theFrame.ClearButton:SetScript("OnClick", function()
			Spy:ClearList()
		end)
		theFrame.ClearButton:SetFrameLevel(theFrame.ClearButton:GetFrameLevel() + 1)
		
		theFrame.StatsButton = CreateFrame("Button", nil, theFrame)
		theFrame.StatsButton:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\button-file.tga")
		theFrame.StatsButton:SetPushedTexture("Interface\\AddOns\\VoidMark\\Textures\\button-file.tga")
		theFrame.StatsButton:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\button-highlight.tga")
		theFrame.StatsButton:SetWidth(12)
		theFrame.StatsButton:SetHeight(12)
		theFrame.StatsButton:SetPoint("RIGHT", theFrame.ClearButton,"LEFT", -4, 0)
		theFrame.StatsButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["Statistics"], 1, 0.82, 0, 1)
			GameTooltip:AddLine(L["StatsDescription"],0,0,0,1)
			GameTooltip:Show()
		end)
		theFrame.StatsButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		theFrame.StatsButton:SetScript("OnClick", function()
			SpyStats:Toggle()
		end)
		theFrame.StatsButton:SetFrameLevel(theFrame.StatsButton:GetFrameLevel() + 1)
		
		theFrame.CountFrame = CreateFrame("Frame", "CountFrame", theFrame)
		theFrame.CountFrame:SetPoint("RIGHT", theFrame.StatsButton,"LEFT", -4, 0)
		theFrame.CountFrame:SetHeight(Spy.db.profile.MainWindow.RowHeight)
		theFrame.CountFrame.Text = CountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		theFrame.CountFrame.Text:SetPoint("RIGHT", theFrame.StatsButton,"LEFT", -4, 0)
--		theFrame.CountFrame.Text:SetFont("GameFontNormal", Spy.db.profile.MainWindow.RowHeight * 0.85, "OUTLINE")
		theFrame.CountFrame.Text:SetFont("Fonts\\FRIZQT__.TTF", Spy.db.profile.MainWindow.RowHeight * 0.85, "OUTLINE")
		theFrame.CountFrame.Text:SetJustifyH("RIGHT")
		theFrame.CountFrame.Text:SetJustifyV("MIDDLE")
		theFrame.CountFrame.Text:SetTextColor(1, 1, 1, 1)
		theFrame.CountFrame.Text:SetText("|cFF0070DE0|r")
		theFrame.CountFrame.Text:SetScale(1)
	
		theFrame.CountButton = CreateFrame("Button", nil, theFrame)
		theFrame.CountButton:SetNormalTexture("Interface\\AddOns\\VoidMark\\Textures\\button-crosshairs.tga")
		theFrame.CountButton:SetPushedTexture("Interface\\AddOns\\VoidMark\\Textures\\button-crosshairs.tga")
		theFrame.CountButton:SetHighlightTexture("Interface\\AddOns\\VoidMark\\Textures\\button-highlight.tga")
		theFrame.CountButton:SetWidth(12)
		theFrame.CountButton:SetHeight(12)
		theFrame.CountButton:SetAlpha(.0)		
		theFrame.CountButton:SetPoint("RIGHT", theFrame.StatsButton,"LEFT", -4, 0)
		theFrame.CountButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["NearbyCount"], 1, 0.82, 0, 1)
			GameTooltip:AddLine(L["NearbyCountDescription"],0,0,0,1)
			GameTooltip:Show()
		end)
		theFrame.CountButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		theFrame.CountButton:SetFrameLevel(theFrame.CountButton:GetFrameLevel() + 1)
		
		Spy.MainWindow.Rows = {}
		Spy.MainWindow.CurRows = 0

		for i = 1, Spy.db.profile.ResizeSpyLimit do
			Spy:CreateRow(i)
		end

		Spy:RestoreMainWindowPosition(Spy.db.profile.MainWindow.Position.x, Spy.db.profile.MainWindow.Position.y, Spy.db.profile.MainWindow.Position.w, 34)
		Spy:SetupMainWindowButtons()
		Spy:ResizeMainWindow()
		Spy:ScheduleRepeatingTimer("ManageExpirations", 10, true)
		Spy:InitOrder()

	end

	if Spy.EnsureCombatSightingsFrame then
		Spy:EnsureCombatSightingsFrame()
	end

	if not Spy.AlertWindow then
		Spy.AlertWindow = CreateFrame("Frame", "Spy_AlertWindow", UIParent, "BackdropTemplate")
		Spy.AlertWindow:ClearAllPoints()
--		Spy.AlertWindow:SetPoint("TOP", UIParent, "TOP", 0, -140)
		Spy.AlertWindow:SetClampedToScreen(true)
		Spy:UpdateAlertWindow()
		Spy.AlertWindow:SetHeight(42)
		Spy.AlertWindow:SetBackdrop({
--			bgFile = "Interface\\AddOns\\VoidMark\\Textures\\alert-background.tga", tile = true, tileSize = 8,
--			edgeFile = "Interface\\AddOns\\VoidMark\\Textures\\alert-industrial.tga", edgeSize = 8,
--			insets = { left = 8, right = 8, top = 8, bottom = 8 },
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 8,edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		Spy.Colors:RegisterBackground("Alert", "Background", Spy.AlertWindow)

		Spy.AlertWindow.Icon = CreateFrame("Frame", nil, Spy.AlertWindow, "BackdropTemplate")
		Spy.AlertWindow.Icon:ClearAllPoints()
		Spy.AlertWindow.Icon:SetPoint("TOPLEFT", Spy.AlertWindow, "TOPLEFT", 6, -5)
		Spy.AlertWindow.Icon:SetWidth(32)
		Spy.AlertWindow.Icon:SetHeight(32)

		Spy.AlertWindow.Title = Spy.AlertWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		Spy.AlertWindow.Title:SetPoint("TOPLEFT", Spy.AlertWindow, "TOPLEFT", 42, -3)
--		Spy.AlertWindow.Title:SetJustifyH("LEFT")
		Spy.AlertWindow.Title:SetHeight(Spy.db.profile.MainWindow.TextHeight)
		Spy:AddFontString(Spy.AlertWindow.Title)

		Spy.AlertWindow.Name = Spy.AlertWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		Spy.AlertWindow.Name:SetPoint("TOPLEFT", Spy.AlertWindow, "TOPLEFT", 42, -15)
--		Spy.AlertWindow.Name:SetJustifyH("LEFT")
		Spy.AlertWindow.Name:SetHeight(Spy.db.profile.MainWindow.TextHeight)
		Spy:AddFontString(Spy.AlertWindow.Name)
		Spy:SetFontSize(Spy.AlertWindow.Name, Spy.db.profile.AlertWindow.NameSize)

		Spy.AlertWindow.Location = Spy.AlertWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		Spy.AlertWindow.Location:SetPoint("TOPLEFT", Spy.AlertWindow, "TOPLEFT", 42, -26)
--		Spy.AlertWindow.Location:SetJustifyH("LEFT")
		Spy.AlertWindow.Location:SetHeight(Spy.db.profile.MainWindow.TextHeight)
		Spy:AddFontString(Spy.AlertWindow.Location)
		Spy:SetFontSize(Spy.AlertWindow.Location, Spy.db.profile.AlertWindow.LocationSize)

		Spy.AlertWindow:Hide()
	end

	Spy:SetCurrentList(1)
	if not Spy.db.profile.Enabled or not Spy.db.profile.MainWindowVis then
		Spy.MainWindow:Hide()
	end
end

function Spy:SetBar(num, name, desc, value, colorgroup, colorclass, tooltipData, opacity)
	local rowmin = 1

	if num < rowmin or not Spy.MainWindow.Rows[num] then
		return
	end

	local Row = Spy.MainWindow.Rows[num]
	Row.StatusBar:SetValue(value)

	-- TALIAA SPY PRIORITY MARKERS
	-- KOS takes priority: skull.
	-- HIGH threat (but not KOS): star.
	-- Row.Name remains the real player name so secure click-targeting is unaffected.
	-- VoidMark compact rows never show the realm suffix. Keep the full
	-- Name-Realm value in Row.Name/secure attributes for targeting and data.
	local bareName = tostring(name):match("^([^%-]+)") or tostring(name)
	local displayName = bareName
	local isKOS = false
	local isHighThreat = false

	if SpyPerCharDB and SpyPerCharDB.KOSData and SpyPerCharDB.KOSData[name] then
		isKOS = true
	end

	local markerPlayerData = SpyPerCharDB
		and SpyPerCharDB.PlayerData
		and SpyPerCharDB.PlayerData[name]

	if markerPlayerData and markerPlayerData.kos == 1 then
		isKOS = true
	end

	if Spy.CalculateThreatScore then
		local _, markerThreatLevel = Spy:CalculateThreatScore(name)
		if markerThreatLevel == "HIGH" then
			isHighThreat = true
		end
	end

	if isKOS then
		displayName = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:16:16:0:0|t " .. bareName
	elseif isHighThreat then
		displayName = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16:16:0:0|t " .. bareName
	end

	Row.LeftText:SetText(displayName)

	-- TALIAA SPY THREAT DISPLAY
	-- UNKNOWN threat is intentionally blank in the compact VoidMark row.
	local threatDisplay = ""
	if Spy.CalculateThreatScore then
		local score, level = Spy:CalculateThreatScore(name)
		if level == "HIGH" then
			threatDisplay = "|cffff3333[HIGH]|r"
		elseif level == "LOW" then
			threatDisplay = "|cff33ff33[LOW]|r"
		elseif level == "EVEN" then
			threatDisplay = "|cffffff00[EVEN]|r"
		end
	end

	if desc and desc ~= "" then
		if threatDisplay ~= "" then
			-- VoidMark order: Name | Level Class | Threat
			Row.RightText:SetText(desc .. " " .. threatDisplay)
		else
			Row.RightText:SetText(desc)
		end
	else
		Row.RightText:SetText(threatDisplay)
	end

	Row.Name = name
	Row.TooltipData = tooltipData

	-- Pre-load the target macro while secure attributes are writable.
	-- During combat, leave the last secure value untouched.
	if not InCombatLockdown() then
		Row:SetAttribute("macro", nil)
		Row:SetAttribute("macrotext1", "/targetexact " .. name)
		Row:SetAttribute("macrotext", "/targetexact " .. name)
	end

	Row.LeftText:SetWidth(Row:GetWidth() - Row.RightText:GetStringWidth() - 4)

	if colorgroup and colorclass and type(colorclass) == "string" then
		Spy.Colors:UnregisterItem(Row.StatusBar)
		local Multi = { r = 1, b = 1, g = 1, a = opacity }
		Spy.Colors:RegisterTexture(colorgroup, colorclass, Row.StatusBar, Multi)
	end

	Row.LeftText:SetTextColor(Spy.db.profile.Colors.Bar["Bar Text"].r, Spy.db.profile.Colors.Bar["Bar Text"].g, Spy.db.profile.Colors.Bar["Bar Text"].b, opacity)
	Row.RightText:SetTextColor(Spy.db.profile.Colors.Bar["Bar Text"].r, Spy.db.profile.Colors.Bar["Bar Text"].g, Spy.db.profile.Colors.Bar["Bar Text"].b, opacity)
end

function Spy:AutomaticallyResize()
	local detected = Spy.ListAmountDisplayed
	if detected > Spy.db.profile.ResizeSpyLimit then detected = Spy.db.profile.ResizeSpyLimit end
	local height = 35 + (detected * (Spy.db.profile.MainWindow.RowHeight + Spy.db.profile.MainWindow.RowSpacing))
	Spy.MainWindow.CurRows = detected
	if not Spy.db.profile.InvertSpy then
		if not InCombatLockdown() then 
			Spy:RestoreMainWindowPosition(Spy.MainWindow:GetLeft(), Spy.MainWindow:GetTop(), Spy.MainWindow:GetWidth(), height)
		end
	else
		if not InCombatLockdown() then 
			Spy:RestoreMainWindowPosition(Spy.MainWindow:GetLeft(), Spy.MainWindow:GetBottom(), Spy.MainWindow:GetWidth(), height)
		end
	end	
end

function Spy:ManageBarsDisplayed()
	local detected = Spy.ListAmountDisplayed
	local bars = math.floor((Spy.MainWindow:GetHeight() - 34) / (Spy.db.profile.MainWindow.RowHeight + Spy.db.profile.MainWindow.RowSpacing))
	if bars > detected then
		bars = detected
	end
	if bars > Spy.db.profile.ResizeSpyLimit then
		bars = Spy.db.profile.ResizeSpyLimit
	end	
	Spy.MainWindow.CurRows = bars

	if not InCombatLockdown() then
		for i,row in pairs(Spy.MainWindow.Rows) do	
			if i <= Spy.MainWindow.CurRows then
				row:Show()
			else
				row:Hide()
			end
		end
	end
end

function Spy:ResizeMainWindow()
	if Spy.MainWindow.Rows[0] then
		Spy.MainWindow.Rows[0]:Hide()
	end

	local CurWidth = Spy.MainWindow:GetWidth() - 4
	Spy.MainWindow.Title:SetWidth(CurWidth - 75)
	for i,row in pairs(Spy.MainWindow.Rows) do
		row:SetWidth(CurWidth)	
	end

	Spy:ManageBarsDisplayed()
end

function Spy:SetCurrentList(mode)
	if not mode or mode > #Spy.ListTypes then
		mode = 1
	end
	Spy.db.profile.CurrentList = mode
	Spy:ManageExpirations()

	local data = Spy.ListTypes[mode]
	Spy.MainWindow.Title:SetText(data[1])

	Spy:RefreshCurrentList()
end

function Spy:MainWindowNextMode()
	local mode = Spy.db.profile.CurrentList + 1
	if mode > table.maxn(Spy.ListTypes) then
		mode = 1
	end
	Spy:SetCurrentList(mode)
end

function Spy:MainWindowPrevMode()
	local mode = Spy.db.profile.CurrentList - 1
	if mode == 0 then
		mode = table.maxn(Spy.ListTypes)
	end
	Spy:SetCurrentList(mode)
end

function Spy:MainWindowScroll(delta)
--  Work in progress to scroll the MainWindow
--	DEFAULT_CHAT_FRAME:AddMessage(delta)
	if delta > 0 then
--		Code for scrolling up
	else
--		Code for scrolling down
	end
end

function Spy:SaveMainWindowPosition()
	Spy.db.profile.MainWindow.Position.x = Spy.MainWindow:GetLeft()
	if not Spy.db.profile.InvertSpy then 
		Spy.db.profile.MainWindow.Position.y = Spy.MainWindow:GetTop()
    else 
		Spy.db.profile.MainWindow.Position.y = Spy.MainWindow:GetBottom()
    end
	Spy.db.profile.MainWindow.Position.w = Spy.MainWindow:GetWidth()
	Spy.db.profile.MainWindow.Position.h = Spy.MainWindow:GetHeight()
	local h = Spy.MainWindow:GetHeight()
end

function Spy:RestoreMainWindowPosition(x, y, width, height)
	Spy.MainWindow:ClearAllPoints()
	if not Spy.db.profile.InvertSpy then 	
		Spy.MainWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else		
		Spy.MainWindow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)	
	end
	Spy.MainWindow:SetWidth(width)
	for i,row in pairs(Spy.MainWindow.Rows) do
		row:SetWidth(width -4) 
	end
	Spy.MainWindow:SetHeight(height)
end


-- VoidMark fast-combat sightings ------------------------------------------------
--
-- The old implementation opened a separate COMBAT SIGHTINGS panel containing
-- non-clickable names. That was slow for WPvP and visually implied that those
-- names could be targeted. Secure target buttons cannot be rebound once combat
-- lockdown has started, so the safest/fastest behavior is:
--   1) if the enemy already owns a frozen secure Nearby row, flash THAT row;
--      it remains immediately clickable because its target macro was preloaded;
--   2) if the enemy is genuinely new during combat, show a short non-blocking
--      notice only. At PLAYER_REGEN_ENABLED the normal RefreshCurrentList() path
--      promotes the enemy into a clickable secure row.
--
-- We intentionally keep this logic visual-only during combat.

function Spy:EnsureCombatSightingsFrame()
    -- Compatibility no-op. Older builds may still call this during window init.
    -- Never recreate the large non-clickable combat panel.
    if Spy.CombatSightingsFrame then
        Spy.CombatSightingsFrame:Hide()
    end
    return nil
end

local function VoidMarkSamePlayer(a, b)
    if not a or not b then return false end
    if a == b then return true end
    -- Fallback for old rows that may have been assigned without a realm suffix.
    local aa = tostring(a):match("^([^%-]+)") or tostring(a)
    local bb = tostring(b):match("^([^%-]+)") or tostring(b)
    return aa == bb
end

local function VoidMarkFindFrozenRow(player)
    local main = Spy.MainWindow
    if not main or not main.Rows then return nil end

    for i, row in pairs(main.Rows) do
        if type(i) == "number" and i >= 1 and row then
            local assigned = (Spy.ButtonName and Spy.ButtonName[i]) or row.Name
            if VoidMarkSamePlayer(assigned, player) then
                return row, i, assigned
            end
        end
    end
    return nil
end

local function VoidMarkFlashFrozenRow(row, isKOS)
    if not row or not row:IsShown() then return false end

    local flash = row.VoidMarkCombatFlash
    if not flash then
        -- Normally pre-created by CreateRow(). This fallback is only for a row
        -- created by an older build before this file was installed; avoid trying
        -- to construct regions during lockdown.
        return false
    end

    row._VoidMarkCombatFlashToken = (row._VoidMarkCombatFlashToken or 0) + 1
    local token = row._VoidMarkCombatFlashToken

    if isKOS then
        flash:SetVertexColor(1.00, 0.12, 0.18, 0.34)
    else
        flash:SetVertexColor(0.72, 0.32, 1.00, 0.30)
    end
    flash:Show()

    C_Timer.After(1.6, function()
        if row and row._VoidMarkCombatFlashToken == token and row.VoidMarkCombatFlash then
            row.VoidMarkCombatFlash:Hide()
        end
    end)
    return true
end

local function VoidMarkCombatNotice(player, playerData, isKOS)
    Spy._VoidMarkCombatNoticeAt = Spy._VoidMarkCombatNoticeAt or {}
    local now = GetTime()
    local last = Spy._VoidMarkCombatNoticeAt[player] or 0
    if (now - last) < 2.5 then return end
    Spy._VoidMarkCombatNoticeAt[player] = now

    local bare = tostring(player):match("^([^%-]+)") or tostring(player)
    local detail = ""
    if playerData and playerData.level then
        detail = detail .. " L" .. tostring(playerData.level)
    end
    if playerData and playerData.class then
        detail = detail .. " " .. tostring(playerData.class)
    end

    local prefix = isKOS and "KOS: " or "NEW: "
    local r, g, b = 0.78, 0.45, 1.00
    if isKOS then r, g, b = 1.00, 0.20, 0.24 end

    -- This is deliberately NOT a fake row. A brand-new combat detection cannot
    -- be made a secure click target until combat ends.
    UIErrorsFrame:AddMessage(prefix .. bare .. detail .. "  •  row after combat", r, g, b, 1.0)
end

function Spy:QueueCombatSighting(player, source)
    if not player or player == "" or not InCombatLockdown() then return end

    Spy.CombatSightings = Spy.CombatSightings or {}
    local playerData = SpyPerCharDB and SpyPerCharDB.PlayerData and SpyPerCharDB.PlayerData[player]
    local isKOS = (SpyPerCharDB and SpyPerCharDB.KOSData and SpyPerCharDB.KOSData[player]) and true or false

    Spy.CombatSightings[player] = {
        player = player,
        seenAt = time(),
        source = source,
        kos = isKOS,
        level = playerData and playerData.level or nil,
        class = playerData and playerData.class or nil,
    }

    -- Best case: this player was already in a secure row when combat began.
    -- Flash the actual clickable row instead of drawing a second non-clickable row.
    local row = VoidMarkFindFrozenRow(player)
    if row and VoidMarkFlashFrozenRow(row, isKOS) then
        return
    end

    -- Brand-new combat-only detection: no protected target can legally be bound
    -- now. Keep the center-screen flag, but also queue it in a slim bar attached
    -- to VoidMark so it "hits the bar" immediately and then promotes to a normal
    -- clickable row after combat ends.
    Spy:UpdateCombatQueueBar()
    VoidMarkCombatNotice(player, playerData, isKOS)
end

function Spy:ClearCombatSightings()
    Spy.CombatSightings = {}
    Spy._VoidMarkCombatNoticeAt = {}

    if Spy.MainWindow and Spy.MainWindow.CombatQueueBar then
        Spy.MainWindow.CombatQueueBar:Hide()
    end

    -- Compatibility cleanup if a frame from an older build happened to exist.
    if Spy.CombatSightingsFrame then
        for _, row in ipairs(Spy.CombatSightingsFrame.Rows or {}) do
            if row.Hide then row:Hide() end
        end
        Spy.CombatSightingsFrame:Hide()
    end

    -- Clear any transient visual flashes. This does not alter secure attributes.
    if Spy.MainWindow and Spy.MainWindow.Rows then
        for _, row in pairs(Spy.MainWindow.Rows) do
            if row and row.VoidMarkCombatFlash then
                row.VoidMarkCombatFlash:Hide()
            end
        end
    end
end

function Spy:EnsureCombatQueueBar()
    if not Spy.MainWindow then return nil end
    local f = Spy.MainWindow.CombatQueueBar
    if not f then
        f = CreateFrame("Frame", nil, Spy.MainWindow, "BackdropTemplate")
        Spy.MainWindow.CombatQueueBar = f
        f:SetPoint("TOPLEFT", Spy.MainWindow, "TOPLEFT", 2, -54)
        f:SetPoint("TOPRIGHT", Spy.MainWindow, "TOPRIGHT", -2, -54)
        f:SetHeight(math.max(18, Spy.db.profile.MainWindow.RowHeight or 18))
        f:SetFrameLevel(Spy.MainWindow:GetFrameLevel() + 70)
        f:SetBackdrop({ bgFile = "Interface\Tooltips\UI-Tooltip-Background" })
        f:SetBackdropColor(0.10, 0.02, 0.16, 0.94)
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetSize(14, 14)
        f.Icon:SetPoint("LEFT", f, "LEFT", 4, 0)
        f.Icon:SetTexture("Interface\TargetingFrame\UI-RaidTargetingIcon_8")
        f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 4, 0)
        f.Text:SetPoint("RIGHT", f, "RIGHT", -4, 0)
        f.Text:SetJustifyH("LEFT")
        f.Text:SetTextColor(0.86, 0.66, 1.0, 1)
        f:EnableMouse(false)
        f:Hide()
    end
    return f
end

function Spy:UpdateCombatQueueBar()
    local f = Spy:EnsureCombatQueueBar()
    if not f then return end

    local sightings = Spy.CombatSightings or {}
    local newest = nil
    local count = 0
    for _, data in pairs(sightings) do
        count = count + 1
        if not newest or (data.seenAt or 0) > (newest.seenAt or 0) then
            newest = data
        end
    end

    if not newest then
        f:Hide()
        return
    end

    local player = tostring(newest.player or "")
    local bare = player:match("^([^%-]+)") or player
    local detail = ""
    if newest.level then detail = detail .. " L" .. tostring(newest.level) end
    if newest.class then detail = detail .. " " .. tostring(newest.class) end
    local more = ""
    if count > 1 then more = "  +" .. tostring(count - 1) end

    if newest.kos then
        f:SetBackdropColor(0.23, 0.02, 0.05, 0.95)
        f.Text:SetTextColor(1.0, 0.36, 0.40, 1)
        f.Text:SetText("KOS QUEUED • " .. bare .. detail .. more)
    else
        f:SetBackdropColor(0.10, 0.02, 0.16, 0.94)
        f.Text:SetTextColor(0.86, 0.66, 1.0, 1)
        f.Text:SetText("QUEUED • " .. bare .. detail .. more)
    end
    f:Show()
end

function Spy:ShowCombatStealthNotice(player, kind)
    if not Spy.MainWindow then return end
    local f = Spy.MainWindow.CombatStealthNotice
    if not f then
        f = CreateFrame("Frame", nil, Spy.MainWindow, "BackdropTemplate")
        Spy.MainWindow.CombatStealthNotice = f
        f:SetPoint("TOPLEFT", Spy.MainWindow, "TOPLEFT", 2, -34)
        f:SetPoint("TOPRIGHT", Spy.MainWindow, "TOPRIGHT", -2, -34)
        f:SetHeight(math.max(18, Spy.db.profile.MainWindow.RowHeight or 18))
        f:SetFrameLevel(Spy.MainWindow:GetFrameLevel() + 80)
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
        f:SetBackdropColor(0.18, 0.03, 0.28, 0.96)
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetSize(16, 16)
        f.Icon:SetPoint("LEFT", f, "LEFT", 3, 0)
        f.Icon:SetTexture("Interface\\Icons\\Ability_Stealth")
        f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 4, 0)
        f.Text:SetPoint("RIGHT", f, "RIGHT", -4, 0)
        f.Text:SetJustifyH("LEFT")
        f.Text:SetTextColor(0.78, 0.42, 1.0, 1)
        f:EnableMouse(false)
        f:Hide()
    end

    Spy._combatStealthNoticeToken = (Spy._combatStealthNoticeToken or 0) + 1
    local token = Spy._combatStealthNoticeToken
    f.Text:SetText(string.format("%s DETECTED: %s", string.upper(kind or "STEALTH"), tostring(player)))
    f:Show()
    C_Timer.After(8, function()
        if Spy._combatStealthNoticeToken == token and f then f:Hide() end
    end)
end

function Spy:SaveAlertWindowPosition()
	Spy.db.profile.AlertWindow.Position.x = Spy.AlertWindow:GetLeft()
	Spy.db.profile.AlertWindow.Position.y = Spy.AlertWindow:GetTop()
end

function Spy:RestoreAlertWindowPosition(x, y)
	Spy.AlertWindow:ClearAllPoints()
	Spy.AlertWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function Spy:UpdateMainWindow()
	if Spy.InInstance then
		Spy.MainWindow:SetAlpha(Spy.db.profile.MainWindow.AlphaBG)
	else	
		Spy.MainWindow:SetAlpha(Spy.db.profile.MainWindow.Alpha)
	end	
end

function Spy:UpdateAlertWindow()
	if Spy.db.profile.DisplayWarnings == "Moveable" then
		Spy.AlertWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", Spy.db.profile.AlertWindow.Position.x, Spy.db.profile.AlertWindow.Position.y)
		Spy.AlertWindow:SetMovable(true)
		Spy.AlertWindow:EnableMouse(true)
		Spy.AlertWindow:SetScript("OnMouseDown", function(self, button) 
			Spy.AlertWindow:StartMoving();
			Spy.AlertWindow.isMoving = true;
		end)
		Spy.AlertWindow:SetScript("OnMouseUp", function(self) 
			if (Spy.AlertWindow.isMoving) then
				Spy.AlertWindow:StopMovingOrSizing();
				Spy.AlertWindow.isMoving = false;
				Spy:SaveAlertWindowPosition()
			end
		end)
	else
		Spy.AlertWindow:ClearAllPoints()	
		Spy.AlertWindow:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end		
end	

function Spy:ShowTooltip(self, show, id)
	if show then
		local unit = self.unit
		local name = Spy.ButtonName[self.id] or unit.name
		if name and name ~= "" then
			local titleText = Spy.db.profile.Colors.Tooltip["Title Text"]

			-- TALIAA SPY TOOLTIP POSITION
			-- Use ONE anchor only. The old code was leaving both a TOP and
			-- BOTTOM anchor on GameTooltip, which stretched the black tooltip
			-- frame vertically down the screen.
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:ClearAllPoints()
			GameTooltip:SetPoint("TOPRIGHT", Spy.MainWindow, "TOPLEFT", -8, 0)
			GameTooltip:ClearLines()
			GameTooltip:AddLine(string.gsub(name, "%-", " - "), titleText.r, titleText.g, titleText.b)

			local playerData = SpyPerCharDB.PlayerData[name]
			if playerData then
				local detailsText = Spy.db.profile.Colors.Tooltip["Details Text"]
				if playerData.guild and playerData.guild ~= "" then
					GameTooltip:AddLine(playerData.guild, detailsText.r, detailsText.g, detailsText.b)
				end

				local details = ""
				if playerData.level then details = L["Level"].." "..playerData.level.." " end
				if playerData.race then details = details..playerData.race.." " end
				if playerData.class then details = details..L[playerData.class] end
				if details ~= "" then
					GameTooltip:AddLine(details..L["Player"], detailsText.r, detailsText.g, detailsText.b)
				end

				-- TALIAA SPY THREAT INTELLIGENCE
				if Spy.CalculateThreatScore then
					local score, level = Spy:CalculateThreatScore(name)
					local threat = playerData.threatData
					local wins = 0
					local losses = 0
					local completed = 0
					local winRate = 0
					local avgFight = 0
					local avgLoss = 0
					local damageDone = 0
					local damageTaken = 0
					local disengaged = 0
					local interrupted = 0
					local lastResult = nil

					if threat then
						wins = threat.wins or 0
						losses = threat.losses or 0
						completed = wins + losses
						if completed > 0 then
							winRate = (wins / completed) * 100
						end
						if (threat.fights or 0) > 0 then
							avgFight = (threat.totalCombatTime or 0) / threat.fights
						end
						if losses > 0 then
							avgLoss = (threat.totalLossTime or 0) / losses
						end
						damageDone = threat.damageDone or 0
						damageTaken = threat.damageTaken or 0
						disengaged = threat.disengaged or 0
						interrupted = threat.interrupted or 0
						lastResult = threat.lastResult
					end

					local r, g, b = 0.67, 0.67, 0.67
					if level == "HIGH" then
						r, g, b = 1, 0, 0
					elseif level == "HIGH" then
						r, g, b = 1, 0.5, 0
					elseif level == "EVEN" then
						r, g, b = 1, 1, 0
					elseif level == "LOW" then
						r, g, b = 0, 1, 0
					elseif level == "LOW" then
						r, g, b = 0.4, 1, 0.4
					end

					GameTooltip:AddLine(" ")
					GameTooltip:AddDoubleLine(
						"Threat",
						level,
						1, 1, 1,
						r, g, b
					)
					if completed > 0 then
						GameTooltip:AddDoubleLine(
							"Threat Record",
							wins .. "W - " .. losses .. "L (" .. math.floor(winRate + 0.5) .. "% wins)",
							1, 1, 1,
							0.85, 0.85, 0.85
						)
					end

					-- Old Spy W/L is lifetime history and is separate from the
					-- newer fight-based threat record above.
					local lifetimeWins = tonumber(playerData.wins) or 0
					local lifetimeLosses = tonumber(playerData.loses) or 0
					if TaliaaGankRepository and TaliaaGankRepository.GetHistoricalStats then
						local repoWins, repoLosses = TaliaaGankRepository:GetHistoricalStats(name, playerData.guid)
						lifetimeWins = math.max(lifetimeWins, tonumber(repoWins) or 0)
						lifetimeLosses = math.max(lifetimeLosses, tonumber(repoLosses) or 0)
					end
					if lifetimeWins > 0 or lifetimeLosses > 0 then
						GameTooltip:AddDoubleLine(
							"Lifetime Record",
							lifetimeWins .. " kills - " .. lifetimeLosses .. " deaths",
							1, 1, 1,
							0.78, 0.58, 1.0
						)
					end

					-- Keep the hover tooltip compact. Detailed fight duration, damage,
					-- disengage/interruption stats are intentionally omitted here.
					if threat and completed > 0 and lastResult then
						GameTooltip:AddDoubleLine(
							"Last Result",
							tostring(lastResult),
							1, 1, 1,
							0.85, 0.85, 0.85
						)
					end
				end


				if SpyPerCharDB.KOSData[name] then
					local reasonText = Spy.db.profile.Colors.Tooltip["Reason Text"]
					GameTooltip:AddLine(L["KOSReason"], reasonText.r, reasonText.g, reasonText.b)
					if playerData.reason and Spy.db.profile.DisplayKOSReason then
						for reason in pairs(playerData.reason) do
							if reason == L["KOSReasonOther"] then
								GameTooltip:AddLine(L["KOSReasonIndent"]..playerData.reason[reason], reasonText.r, reasonText.g, reasonText.b)
							else
								GameTooltip:AddLine(L["KOSReasonIndent"]..reason, reasonText.r, reasonText.g, reasonText.b)
							end
						end
					end
				end

				if Spy.db.profile.DisplayLastSeen then
					local locationText = Spy.db.profile.Colors.Tooltip["Location Text"]
					if playerData.time then
						local lastSeen = L["LastSeen"]
						local minutes = math.floor((time() - playerData.time) / 60)
						local hours = math.floor(minutes / 60)
						if minutes <= 0 then
							lastSeen = lastSeen.." "..L["LessThanOneMinuteAgo"]
						elseif minutes > 0 and minutes < 60 then
							lastSeen = lastSeen.." "..minutes.." "..L["MinutesAgo"]
						elseif hours > 0 and hours < 24 then
							lastSeen = lastSeen.." "..hours.." "..L["HoursAgo"]
						else
							local days = math.floor(hours / 24)
							lastSeen = lastSeen.." "..days.." "..L["DaysAgo"]
						end
						GameTooltip:AddLine(lastSeen, locationText.r, locationText.g, locationText.b)
					end
					GameTooltip:AddLine(Spy:GetPlayerLocation(playerData), locationText.r, locationText.g, locationText.b)
				end
			end

			GameTooltip:Show()
		end
	else
		GameTooltip:Hide()
	end
end

function Spy:ShowMapTooltip(icon, show)
	-- Removed with legacy map/minimap support.
	return
end

function Spy:ShowAlert(type, name, source, location)
	if not SpyFrameIsFading(Spy.AlertWindow) then
		Spy.AlertType = nil
	end

	if type == "kos" then
		Spy.Colors:RegisterBorder("Alert", "KOS Border", Spy.AlertWindow)
		Spy.AlertWindow.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Ability_Creature_Cursed_02" })
		Spy.Colors:RegisterBorder("Alert", "Background", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterBackground("Alert", "Icon", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterFont("Alert", "KOS Text", Spy.AlertWindow.Title)
		Spy.AlertWindow.Title:SetText(L["AlertKOSTitle"])
		Spy.Colors:RegisterFont("Alert", "Name Text", Spy.AlertWindow.Name)
		Spy.AlertWindow.Name:SetText(name)
		Spy.Colors:RegisterFont("Alert", "KOS Text", Spy.AlertWindow.Location)
		Spy.AlertWindow.Location:SetText(location)
		Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		if (Spy.AlertWindow.Title:GetStringWidth() < Spy.AlertWindow.Name:GetStringWidth()) then
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Name:GetStringWidth() + 52)
		else
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		end

		SpyFrameFlashStop(Spy.AlertWindow)
		SpyFrameFlash(Spy.AlertWindow, 0, 1, 4, false, 3, 0)
		Spy.AlertType = type
	elseif type == "kosguild" and Spy.AlertType ~= "kos" then
		Spy.Colors:RegisterBorder("Alert", "KOS Guild Border", Spy.AlertWindow)
		Spy.AlertWindow.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Spell_Holy_PrayerofSpirit" })
		Spy.Colors:RegisterBorder("Alert", "Background", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterBackground("Alert", "Icon", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterFont("Alert", "KOS Guild Text", Spy.AlertWindow.Title)
		Spy.AlertWindow.Title:SetText(L["AlertKOSGuildTitle"])
		Spy.Colors:RegisterFont("Alert", "Name Text", Spy.AlertWindow.Name)
		Spy.AlertWindow.Name:SetText(name)
		Spy.AlertWindow.Location:SetText("")
		Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		if (Spy.AlertWindow.Title:GetStringWidth() < Spy.AlertWindow.Name:GetStringWidth()) then
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Name:GetStringWidth() + 52)
		else
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		end

		SpyFrameFlashStop(Spy.AlertWindow)
		SpyFrameFlash(Spy.AlertWindow, 0, 1, 4, false, 3, 0)
		Spy.AlertType = type
	elseif type == "stealth" and Spy.AlertType ~= "kos" and Spy.AlertType ~= "kosguild" then
		Spy.Colors:RegisterBorder("Alert", "Stealth Border", Spy.AlertWindow)
		Spy.AlertWindow.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Ability_Stealth" })
		Spy.Colors:RegisterBorder("Alert", "Background", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterBackground("Alert", "Icon", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterFont("Alert", "Stealth Text", Spy.AlertWindow.Title)
		Spy.AlertWindow.Title:SetText(L["AlertStealthTitle"])
		Spy.Colors:RegisterFont("Alert", "Name Text", Spy.AlertWindow.Name)
		Spy.AlertWindow.Name:SetText(name)
		Spy.AlertWindow.Location:SetText("")
		Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		if (Spy.AlertWindow.Title:GetStringWidth() < Spy.AlertWindow.Name:GetStringWidth()) then
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Name:GetStringWidth() + 52)
		else
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		end

		SpyFrameFlashStop(Spy.AlertWindow)
		SpyFrameFlash(Spy.AlertWindow, 0, 1, 5, false, 4, 0)
		Spy.AlertType = type
	elseif type == "prowl" and Spy.AlertType ~= "kos" and Spy.AlertType ~= "kosguild" then
		Spy.Colors:RegisterBorder("Alert", "Stealth Border", Spy.AlertWindow)
		Spy.AlertWindow.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Ability_Ambush" })
		Spy.Colors:RegisterBorder("Alert", "Background", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterBackground("Alert", "Icon", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterFont("Alert", "Stealth Text", Spy.AlertWindow.Title)
		Spy.AlertWindow.Title:SetText(L["AlertStealthTitle"])
		Spy.Colors:RegisterFont("Alert", "Name Text", Spy.AlertWindow.Name)
		Spy.AlertWindow.Name:SetText(name)
		Spy.AlertWindow.Location:SetText("")
		Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		if (Spy.AlertWindow.Title:GetStringWidth() < Spy.AlertWindow.Name:GetStringWidth()) then
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Name:GetStringWidth() + 52)
		else
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		end

		SpyFrameFlashStop(Spy.AlertWindow)
		SpyFrameFlash(Spy.AlertWindow, 0, 1, 5, false, 4, 0)
		Spy.AlertType = type
	elseif (type == "kosaway" or type == "kosguildaway") and Spy.AlertType ~= "kos" and Spy.AlertType ~= "kosguild" and Spy.AlertType ~= "stealth" then
		local realmSeparator = strfind(source, "-")
		if realmSeparator and realmSeparator > 1 then
			source = string.gsub(strsub(source, 1, realmSeparator - 1), " ", "")
		end
		Spy.Colors:RegisterBorder("Alert", "Away Border", Spy.AlertWindow)
		Spy.AlertWindow.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Ability_Hunter_SniperShot" })
		Spy.Colors:RegisterBorder("Alert", "Background", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterBackground("Alert", "Icon", Spy.AlertWindow.Icon)
		Spy.Colors:RegisterFont("Alert", "Away Text", Spy.AlertWindow.Title)
		Spy.AlertWindow.Title:SetText(L["AlertTitle_"..type]..source.."!")
		Spy.Colors:RegisterFont("Alert", "Name Text", Spy.AlertWindow.Name)
		Spy.AlertWindow.Name:SetText(name)
		Spy.Colors:RegisterFont("Alert", "Location Text", Spy.AlertWindow.Location)
		Spy.AlertWindow.Location:SetText(location)
		if (Spy.AlertWindow.Title:GetStringWidth() < Spy.AlertWindow.Location:GetStringWidth()) then
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Location:GetStringWidth() + 52)
		else
			Spy.AlertWindow:SetWidth(Spy.AlertWindow.Title:GetStringWidth() + 52)
		end

		SpyFrameFlashStop(Spy.AlertWindow)
		SpyFrameFlash(Spy.AlertWindow, 0, 1, 4, false, 3, 0)
		Spy.AlertType = type
	end
	Spy.AlertWindow.Name:SetWidth(Spy.AlertWindow:GetWidth() - 52)
	Spy.AlertWindow.Location:SetWidth(Spy.AlertWindow:GetWidth() - 52)
end

function Spy:BarsChanged()  
	for k, v in pairs(Spy.MainWindow.Rows) do
		v:SetHeight(Spy.db.profile.MainWindow.RowHeight)
		v:SetPoint("TOPLEFT", Spy.MainWindow, "TOPLEFT", 2, -34 - (Spy.db.profile.MainWindow.RowHeight + Spy.db.profile.MainWindow.RowSpacing) * (k - 1))			
		Spy:SetFontSize(v.LeftText, math.max(Spy.db.profile.MainWindow.RowHeight * 0.75, Spy.db.profile.MainWindow.RowHeight - 3) * 1.20)
		Spy:SetFontSize(v.RightText, math.max(Spy.db.profile.MainWindow.RowHeight * 0.65, Spy.db.profile.MainWindow.RowHeight - 12) * 1.20)
	end
	Spy:ResizeMainWindow()
end

function Spy:CreateKoSButton()
	if not Spy.KoSButton then
		Spy.KoSButton = CreateFrame("Button", "Spy_KoSButton", TargetFrame)
		Spy.KoSButton:Hide()
		Spy.KoSButton:SetWidth(22) 
		Spy.KoSButton:SetHeight(22)
		Spy.KoSButton:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 141, 44)
		Spy.KoSButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		Spy.KoSButton.Background = Spy.KoSButton:CreateTexture("KoSButtonBackground", "BACKGROUND")
		Spy.KoSButton.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
		Spy.KoSButton.Background:SetWidth(12)
		Spy.KoSButton.Background:SetHeight(12)
		Spy.KoSButton.Background:SetPoint("CENTER")
		Spy.KoSButton.Background:SetVertexColor(0, 0, 0, 0.7)
		Spy.KoSButton.Icon = Spy.KoSButton:CreateTexture("KoSButtonIcon", "ARTWORK")
		Spy.KoSButton.Icon:SetWidth(14)
		Spy.KoSButton.Icon:SetHeight(14)
		Spy.KoSButton.Icon:SetPoint("CENTER", 2, -1)
		Spy.KoSButton.Border = Spy.KoSButton:CreateTexture("KoSButtonBorder", "OVERLAY")
		Spy.KoSButton.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		Spy.KoSButton.Border:SetWidth(44)
		Spy.KoSButton.Border:SetHeight(44)
		Spy.KoSButton.Border:SetPoint("CENTER", 11, -12)
		RaiseFrameLevel(Spy.KoSButton)

		Spy.KoSButton:SetScript("OnMouseDown", function(self, button)
			if (UnitIsEnemy("player","target") and UnitIsPlayer("target")) then
				local name = GetUnitName("target", true)
				if button == "LeftButton" then
					if SpyPerCharDB.KOSData[name] then
						Spy:ToggleKOSPlayer(false, name)
					else
						Spy:ToggleKOSPlayer(true, name)
					end
				elseif button == "RightButton" then	
					Spy:SetKOSReason(name, L["KOSReasonOther"], other)
				end
			end
		end)
	end
end

--hooksecurefunc("TargetFrame_Update", function()
hooksecurefunc(TargetFrame, "Update", function()
	if Spy.db.profile.ShowKoSButton then
		if (UnitIsEnemy("player","target") and UnitIsPlayer("target")) then
			local name = GetUnitName("target", true)	
			if SpyPerCharDB.KOSData[name] then
				Spy.KoSButton.Icon:SetTexture("Interface\\AddOns\\VoidMark\\Textures\\button-on.tga")
			else	
				Spy.KoSButton.Icon:SetTexture("Interface\\AddOns\\VoidMark\\Textures\\button-off.tga")
			end
			Spy.KoSButton:Show()
		else
			Spy.KoSButton:Hide()
		end
	end	
end)