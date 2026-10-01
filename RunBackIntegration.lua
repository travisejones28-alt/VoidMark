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

local function ResolveSpyName(raw)
    if not raw or raw == "" then return nil end
    if SpyPerCharDB and SpyPerCharDB.PlayerData and SpyPerCharDB.PlayerData[raw] then return raw end
    if Spy.NearbyList and Spy.NearbyList[raw] then return raw end

    local rawLower=Lower(raw)
    local rawBase=Lower(BaseName(raw))
    local exactBase=nil
    local matches=0
    local function scan(tbl)
        if type(tbl)~="table" then return end
        for key in pairs(tbl) do
            if Lower(key)==rawLower then return key,true end
            if Lower(BaseName(key))==rawBase then exactBase=key; matches=matches+1 end
        end
    end
    local key,found=scan(Spy.NearbyList); if found then return key end
    key,found=scan(SpyPerCharDB and SpyPerCharDB.PlayerData); if found then return key end
    if matches==1 then return exactBase end
    return raw
end

local function MapRecord(r)
    if not r or not r.name then return end
    local key=ResolveSpyName(r.voidMarkName or r.name)
    r.voidMarkName=key
    Spy.RunBackPinned[key]=r.guid
    RB.byVoidMarkName[Lower(key)]=r.guid
    RB.byVoidMarkName[Lower(BaseName(key))]=r.guid
    return key
end

function Spy:IsRunBackPinned(name)
    if not name then return false end
    local guid=Spy.RunBackPinned[name]
    if guid and RB.active and RB.active[guid] then return true end
    local g=RB.byVoidMarkName[Lower(name)] or RB.byVoidMarkName[Lower(BaseName(name))]
    return g and RB.active and RB.active[g] ~= nil or false
end

function Spy:GetRunBackRecord(name)
    if not name or not RB.active then return nil end
    local guid=Spy.RunBackPinned[name] or RB.byVoidMarkName[Lower(name)] or RB.byVoidMarkName[Lower(BaseName(name))]
    local r=guid and RB.active[guid] or nil
    if r then return r end
    -- Defensive fallback for pre-integration restored timers.
    local base=Lower(BaseName(name))
    for _,record in pairs(RB.active) do
        if Lower(BaseName(record.voidMarkName or record.name))==base then
            MapRecord(record)
            return record
        end
    end
end

local function Clock(seconds)
    local t=math.max(0,math.floor(seconds or 0))
    return string.format("%d:%02d",math.floor(t/60),t%60)
end

function Spy:GetRunBackDisplay(name)
    local r=self:GetRunBackRecord(name)
    if not r or type(r.readyAt)~="number" then return nil end
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
    local name=r.voidMarkName or ResolveSpyName(r.name)
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
    local name=r.voidMarkName or ResolveSpyName(r.name)
    if not name then return end
    Spy.RunBackPinned[name]=nil
    RB.byVoidMarkName[Lower(name)]=nil
    RB.byVoidMarkName[Lower(BaseName(name))]=nil

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
