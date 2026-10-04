-- VoidMark + Taliaa RunBack integration.
-- Keeps normal VoidMark detection behavior for living enemies, pins a dead
-- enemy through the corpse-run floor, then releases the pin 60 seconds after
-- RETURN POSSIBLE.  The far-right W/L record remains untouched.
local _, RB = ...

Spy.RunBackPinned = Spy.RunBackPinned or {}
RB.byVoidMarkName = RB.byVoidMarkName or {}

local function BaseName(name)
    return tostring(name or ""):match("^([^%-]+)") or tostring(name or "")
end

local function Lower(s) return string.lower(tostring(s or "")) end
local function KnownGUID(info)
    local guid=type(info)=="table" and info.guid
    return type(guid)=="string" and guid:sub(1,7)=="Player-" and guid or nil
end

local function ResolveSpyName(raw,guid)
    if not raw or raw=="" then return nil end
    local data=SpyPerCharDB and SpyPerCharDB.PlayerData or {}
    local exactGUID=KnownGUID(data[raw])
    if guid and exactGUID==guid then return raw end
    if raw:find("-",1,true) and (data[raw] or (Spy.NearbyList and Spy.NearbyList[raw])) and (not exactGUID or exactGUID==guid) then return raw end
    local keys={}
    for key in pairs(data) do keys[key]=true end
    for key in pairs(Spy.NearbyList or {}) do keys[key]=true end
    local exact,base,baseCount=nil,nil,0
    for key in pairs(keys) do
        local info=data[key]
        local known=KnownGUID(info)
        if guid and known==guid then return key end
        local compatible=not known or known==guid
        if compatible and Lower(key)==Lower(raw) then exact=key end
        if compatible and Lower(BaseName(key))==Lower(BaseName(raw)) then base=key; baseCount=baseCount+1 end
    end
    if exact then return exact end
    -- An explicit realm is part of identity. Never strip it to attach a timer
    -- to another realm. Unqualified names may match only one known identity.
    if not raw:find("-",1,true) and baseCount==1 then return base end
    return raw
end

local function MapRecord(r)
    if not r or not r.name then return end
    local key=ResolveSpyName(r.name,r.guid)
    r.voidMarkName=key
    Spy.RunBackPinned[key]=r.guid
    RB.byVoidMarkName[Lower(key)]=r.guid
    return key
end

function Spy:GetRunBackRecord(name)
    if not name or not RB.active then return nil end
    local data=SpyPerCharDB and SpyPerCharDB.PlayerData
    local info=data and data[name]
    local guid=KnownGUID(info)
    if guid then return RB.active[guid] end
    local full=Lower(name)
    local qualified=name:find("-",1,true)~=nil
    local found
    for _,r in pairs(RB.active) do
        local key=r.voidMarkName or r.name
        local matches=qualified and (Lower(key)==full or Lower(r.name)==full)
            or (not qualified and (Lower(BaseName(key))==full or Lower(BaseName(r.name))==full))
        if matches then
            if found and found.guid~=r.guid then return nil end
            found=r
        end
    end
    return found
end

function Spy:IsRunBackPinned(name)
    return self:GetRunBackRecord(name)~=nil
end

local function Clock(seconds)
    local t=math.max(0,math.floor(seconds or 0))
    return string.format("%d:%02d",math.floor(t/60),t%60)
end

function Spy:GetRunBackDisplay(name)
    local r=self:GetRunBackRecord(name)
    if not r or not RB:Finite(r.readyAt) then return nil end
    local now=RB:Now()
    local delta=r.readyAt-now
    if delta>0 then
        -- Yellow countdown until the earliest possible return floor.
        return {time=Clock(delta), ready=false, record=r}
    end
    -- Once return is possible, keep the exact same compact timer format but
    -- count upward in red.  No POS/REZ/ALIVE label is shown.
    return {time="+"..Clock(-delta), ready=true, record=r}
end

-- Fired exactly once when a pinned dead player is positively seen alive again.
-- Treat that as a fresh local detection for timestamps and play the same sound
-- family VoidMark normally uses: KOS alert for KOS, guild-KOS where applicable,
-- race alert when configured, otherwise the standard nearby ping.
function Spy:OnRunBackRezConfirmed(r, unit)
    if not r then return end
    local name=r.voidMarkName or ResolveSpyName(r.name,r.guid)
    if not name then return end

    local now=time()
    Spy.NearbyList=Spy.NearbyList or {}
    Spy.ActiveList=Spy.ActiveList or {}
    Spy.InactiveList=Spy.InactiveList or {}
    Spy.LastHourList=Spy.LastHourList or {}
    Spy.NearbyList[name]=now
    Spy.ActiveList[name]=now
    Spy.InactiveList[name]=nil
    Spy.LastHourList[name]=now

    if r._voidMarkRezSoundPlayed then return end
    r._voidMarkRezSoundPlayed=true

    if not (Spy.db and Spy.db.profile and Spy.db.profile.EnableSound) then return end
    local profile=Spy.db.profile
    local playerData=SpyPerCharDB and SpyPerCharDB.PlayerData and SpyPerCharDB.PlayerData[name]
    local isKOS=SpyPerCharDB and SpyPerCharDB.KOSData and SpyPerCharDB.KOSData[name]

    if isKOS and profile.WarnOnKOS then
        PlaySoundFile("Interface\\AddOns\\VoidMark\\Sounds\\detected-kos.mp3",profile.SoundChannel)
        return
    end
    if profile.WarnOnKOSGuild and playerData and playerData.guild and Spy.KOSGuild and Spy.KOSGuild[playerData.guild] then
        PlaySoundFile("Interface\\AddOns\\VoidMark\\Sounds\\detected-kosguild.mp3",profile.SoundChannel)
        return
    end
    if profile.OnlySoundKoS then return end
    if playerData and profile.WarnOnRace and playerData.race==profile.SelectWarnRace then
        PlaySoundFile("Interface\\AddOns\\VoidMark\\Sounds\\detected-race.mp3",profile.SoundChannel)
    else
        PlaySoundFile("Interface\\AddOns\\VoidMark\\Sounds\\detected-nearby.mp3",profile.SoundChannel)
    end
end

function RB:OnVoidMarkRezConfirmed(r,unit)
    Spy:OnRunBackRezConfirmed(r,unit)
    if not InCombatLockdown() and Spy.db and Spy.db.profile and Spy.db.profile.CurrentList==1 then
        Spy:RefreshCurrentList()
        if Spy.UpdateActiveCount then Spy:UpdateActiveCount() end
    end
end

function RB:OnVoidMarkTimerCreated(r, restored)
    local name=MapRecord(r)
    if not name then return end
    local now=time()
    Spy.NearbyList=Spy.NearbyList or {}
    Spy.ActiveList=Spy.ActiveList or {}
    Spy.InactiveList=Spy.InactiveList or {}
    Spy.LastHourList=Spy.LastHourList or {}

    -- If VoidMark already knew this enemy, preserve its real detection stamp.
    -- Otherwise add the combat-log victim so the pinned timer has a row.
    if not Spy.NearbyList[name] then Spy.NearbyList[name]=now end
    if not Spy.ActiveList[name] and not Spy.InactiveList[name] then Spy.InactiveList[name]=Spy.NearbyList[name] or now end
    Spy.LastHourList[name]=math.max(tonumber(Spy.LastHourList[name]) or 0,now)

    if not InCombatLockdown() and Spy.db and Spy.db.profile and Spy.db.profile.CurrentList==1 then
        Spy:RefreshCurrentList()
        if Spy.UpdateActiveCount then Spy:UpdateActiveCount() end
    end
end

function RB:OnVoidMarkTimerRemoved(r, reason)
    if not r then return end
    local name=r.voidMarkName or ResolveSpyName(r.name,r.guid)
    if not name then return end
    if Spy.RunBackPinned[name]==r.guid then Spy.RunBackPinned[name]=nil end
    if RB.byVoidMarkName[Lower(name)]==r.guid then RB.byVoidMarkName[Lower(name)]=nil end

    -- Another GUID may still own this exact row after a replacement.
    local owner=Spy:GetRunBackRecord(name)
    if owner and owner.guid~=r.guid then return end

    -- If the enemy has actually been detected again recently, hand the row back
    -- to normal VoidMark expiration. Otherwise remove the dead pinned row now.
    local now=time()
    local activeAt=Spy.ActiveList and tonumber(Spy.ActiveList[name])
    local recent=activeAt and (now-activeAt)<=((Spy.ActiveTimeout or 10)+1)
    if not recent then
        if Spy.ActiveList then Spy.ActiveList[name]=nil end
        if Spy.InactiveList then Spy.InactiveList[name]=nil end
        if Spy.NearbyList then Spy.NearbyList[name]=nil end
    end
    if not InCombatLockdown() and Spy.db and Spy.db.profile and Spy.db.profile.CurrentList==1 then
        Spy:RefreshCurrentList()
        if Spy.UpdateActiveCount then Spy:UpdateActiveCount() end
    end
end

-- Timers.lua calls RenderRows every second.  In the integrated build that tick
-- simply repaints the already-existing VoidMark rows; no second run-back window.
function RB:RenderRows()
    local frame=Spy.MainWindow
    if not frame or not frame:IsShown() then return end
    for i=1,(Spy.ListAmountDisplayed or 0) do
        local name=Spy.ButtonName and Spy.ButtonName[i]
        local vm=Spy.VoidMark
        if name and vm and vm.StyleRow then
            local opacity=1
            if Spy.db and Spy.db.profile and Spy.db.profile.CurrentList==1 and Spy.InactiveList and Spy.InactiveList[name] then opacity=.5 end
            vm:StyleRow(i,name,nil,opacity)
        end
    end
end

-- Expose the engine for debugging without making the standalone frame necessary.
_G.VoidMarkRunBack = RB
