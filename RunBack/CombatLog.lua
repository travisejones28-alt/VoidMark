local _, A = ...
local band=bit.band
local PLAYER=COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE=COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local CONTROL=COMBATLOG_OBJECT_CONTROL_PLAYER or 0x100
local AFFILIATION=0x7 -- mine, party, raid; includes pets with player control
local damage={SWING_DAMAGE=true,RANGE_DAMAGE=true,SPELL_DAMAGE=true,SPELL_PERIODIC_DAMAGE=true,DAMAGE_SHIELD=true,DAMAGE_SPLIT=true}

function A:RefreshGroup()
    self.group={}
    for _,u in ipairs({"player","pet"}) do local id=UnitGUID(u); if id then self.group[id]=true end end
    for i=1,40 do
        local prefix=IsInRaid and IsInRaid() and "raid" or "party"
        if prefix=="party" and i>4 then break end
        for _,u in ipairs({prefix..i,prefix.."pet"..i}) do local id=UnitGUID(u); if id then self.group[id]=true end end
    end
end

function A:IsOurSource(guid,flags)
    return guid and ((self.group and self.group[guid]) or (flags and band(flags,AFFILIATION)~=0 and band(flags,CONTROL)~=0))
end

function A:IsEnemyPlayer(guid,flags)
    return type(guid)=="string" and guid:sub(1,7)=="Player-" and type(flags)=="number" and band(flags,PLAYER)~=0 and band(flags,HOSTILE)~=0
end

function A:Observe(unit)
    -- Mouseover/nameplate/target events can fire while Blizzard marks the unit
    -- token as protected.  Identity reads on those tokens can taint the UI even
    -- though this observer never performs a protected action.  Read every unit
    -- field through the RunBack safe wrapper and abandon the observation when
    -- the token is not safely readable.
    if not unit then return end
    local isPlayer=self:Safe(UnitIsPlayer,unit)
    if not isPlayer then return end

    local guid=self:Safe(UnitGUID,unit)
    if type(guid)~="string" or guid:sub(1,7)~="Player-" then return end

    local name,realm=self:Safe(UnitName,unit)
    if not name or name=="" then return end
    if realm and realm~="" then name=name.."-"..realm end

    local _,class=self:Safe(UnitClass,unit)
    local _,race=self:Safe(UnitRace,unit)
    local faction=self:Safe(UnitFactionGroup,unit)
    local level=self:Safe(UnitLevel,unit)

    self.seen[guid]={name=name,level=level,class=class,race=race,faction=faction,observed=self:Now()}
    self.units[guid]=unit

    -- The protected-action report we captured came specifically through the
    -- UPDATE_MOUSEOVER_UNIT path while range/location enrichment was running.
    -- Identity is useful, but a mouseover envelope is optional: direct damage,
    -- target and nameplate observations can supply a conservative envelope.
    -- Skip range APIs entirely for mouseover so this event cannot enter the
    -- restricted CheckInteractDistance/IsSpellInRange/UnitPosition chain.
    if unit ~= "mouseover" then
        self:Safe(function()
            self:RememberEnemyEnvelope(guid,unit,"unit observation")
        end)
    end

    self:ScheduleCleanup()
    -- Identity/range observations never alter an already-created death timer.
end

function A:ForgetUnit(unit)
    for guid,u in pairs(self.units) do if u==unit then self.units[guid]=nil end end
end

function A:CombatEvent(timestamp,event,hideCaster,sg,sn,sf,srf,dg,dn,df,drf,...)
    if not dg or (event~="UNIT_DIED" and event~="PARTY_KILL" and not damage[event]) then return end
    if not self:IsEnemyPlayer(dg,df) then return end
    local now=self:Now()

    if damage[event] then
        if self:IsOurSource(sg,sf) then
            self.involved[dg]=now
            -- Prefer a live target/nameplate envelope.  If the unit token has
            -- already vanished, direct damage itself supplies a deliberately
            -- loose combat-log range bound so a real kill does not collapse to
            -- immediate UNKNOWN/RETURN POSSIBLE.
            local captured=self:RememberEnemyEnvelopeByGUID(dg,"our damage event")
            if not captured and event~="SPELL_PERIODIC_DAMAGE" and event~="DAMAGE_SPLIT" then
                local spellID=(event=="SWING_DAMAGE") and nil or select(1,...)
                self:RememberDamageEventEnvelope(dg,event,spellID,"our direct damage event")
            end
            self:ScheduleCleanup()
        end
        return
    end

    local eligible=(event=="PARTY_KILL" and self:IsOurSource(sg,sf)) or (self.involved[dg] and now-self.involved[dg]<=self.db.settings.assist)
    if not eligible then self.metrics.ignored=self.metrics.ignored+1; return end
    self.lastDeath=self.lastDeath or {}
    if self.lastDeath[dg] and now-self.lastDeath[dg]<2 then return end
    if not self:IsOutdoor() then return end
    self.lastDeath[dg]=now; self.involved[dg]=nil
    local info=self.seen[dg] or {}
    local p,ctx,exact=self:CaptureLocation(dg)
    local faction=info.faction
    if not faction or faction=="Neutral" then
        local own=UnitFactionGroup("player"); faction=own=="Horde" and "Alliance" or own=="Alliance" and "Horde" or "Unknown"
    end
    local _,_,_,latency=self:Safe(GetNetStats)
    latency=self:Finite(latency) and math.max(0,latency/1000) or 0
    local death={guid=dg,name=dn or info.name,at=now-latency,latency=latency,epoch=self:Epoch(),position=p,context=ctx,exactArea=exact,
        faction=faction,race=info.race,class=info.class,level=info.level}
    -- The event handler does no graveyard search, pathfinding, or UI work.
    C_Timer.After(0,function() A:CreateTimer(death) end)
    self:ScheduleCleanup()
end

function A:ScheduleCleanup()
    if not self.cleanupPending then
        self.cleanupPending=true
        C_Timer.After(30,function()
            A.cleanupPending=false; local t=A:Now()
            for id,v in pairs(A.involved) do if t-v>30 then A.involved[id]=nil end end
            for id,v in pairs(A.lastDeath or {}) do if t-v>30 then A.lastDeath[id]=nil end end
            for id,v in pairs(A.seen) do if t-v.observed>300 then A.seen[id]=nil; A.units[id]=nil end end
            for id,v in pairs(A.enemyBounds or {}) do if t-(v.at or 0)>30 then A.enemyBounds[id]=nil end end
            -- Re-arm only while transient observation/combat state remains.
            -- This guarantees stale entries eventually expire without keeping a
            -- permanent background ticker alive.
            if next(A.involved) or next(A.lastDeath or {}) or next(A.seen) or next(A.enemyBounds or {}) then
                A:ScheduleCleanup()
            end
        end)
    end
end
