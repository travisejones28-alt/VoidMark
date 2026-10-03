local _, A = ...

function A:CreateTimer(death)
    if not self.db or not self:IsOutdoor() then return end
    local p=death.position
    local ctx=death.context or {}
    local resolution=self:ResolveGraveyard(p,ctx.area,death.faction,death.exactArea)
    local calc=self:FloorFor(p,resolution,death.race,death.faction)
    if death.latency and death.latency>0 then
        calc.adjustment=calc.adjustment..string.format("; warn %.3f s earlier for measured world RTT",death.latency)
    end

    local predicted=resolution.predicted
    local warning=calc.floorGY and self.Data.graveyards[calc.floorGY] or nil
    local r={
        guid=death.guid,name=death.name or "Unknown",level=death.level,class=death.class,race=death.race,faction=death.faction or "Unknown",
        diedAt=death.epoch or self:Epoch(),readyAt=(death.at or self:Now())+calc.seconds,
        position=p,uiMap=ctx.uiMap,area=ctx.area,zone=ctx.zone,subzone=ctx.subzone,zoneName=ctx.zoneName,
        graveyard=predicted and predicted.id,graveyardName=predicted and predicted.name or "Unknown graveyard",
        warningGraveyard=warning and warning.id,warningGraveyardName=warning and warning.name or nil,
        selection=resolution.reason,assignmentSource=resolution.source,assignmentArea=resolution.assignmentArea,
        candidateScope=resolution.candidateScope,exactArea=death.exactArea,calc=calc,test=death.test,routeStatus="Not requested"
    }
    self.active[r.guid]=r
    self.metrics.deaths=self.metrics.deaths+1
    if self.OnVoidMarkTimerCreated then self:OnVoidMarkTimerCreated(r) end

    -- Route diagnostics are still advisory only.  They never move readyAt later.
    -- Use the same graveyard that actually drove the lower-bound countdown when
    -- available so the diagnostic route and the visible timer refer to one GY.
    local routeGY=warning or predicted
    if self.db.settings.routes and p and p.uncertainty~=nil and routeGY then
        r.routeStatus="Queued"
        self:RequestRoute(routeGY,p,function(distance,status)
            if A.active[r.guid]~=r then return end
            r.networkDistance=distance
            r.routeStatus=status
            -- Route ETA is advisory only. It estimates when a fast, direct
            -- corpse run is likely to reach the 40 yd reclaim radius. It can
            -- never postpone or replace the EARLIEST lower-bound warning.
            if distance and calc.speed and calc.speed>0 then
                -- RequestRoute already terminates at the 40 yd reclaim disk, so
                -- do not subtract the reclaim radius a second time here.
                local baseRouteSeconds=math.max(0,distance)/calc.speed
                local calibratedSeconds, calibrationNote = A:ApplyRouteCalibration(
                    baseRouteSeconds, calc.seconds, ctx.zone or ctx.area, routeGY.id, death.faction
                )
                r.baseRouteSeconds=baseRouteSeconds
                r.routeSeconds=calibratedSeconds or baseRouteSeconds
                r.calibrationNote=calibrationNote
                r.routeAt=(death.at or A:Now())+r.routeSeconds
            else
                r.routeSeconds=nil
                r.routeAt=nil
            end
            A:Save()
            if A.frame and A.frame:IsShown() then A:RenderRows() end
        end)
    elseif p and p.uncertainty==nil then
        r.routeStatus="Cannot route an unlocated enemy corpse"
    end

    self:PruneTimers()
    self:RenderRows()
    self:ArmTimer()
    self:Save()
end

function A:PruneTimers()
    local nowEpoch=self:Epoch(); local now=self:Now(); local list={}; local changed=false
    local linger=60 -- VoidMark integrated requirement: hold dead rows 60s after RETURN POSSIBLE
    for guid,r in pairs(self.active) do
        -- Keep the enemy visible after the earliest-return floor is reached.
        -- This is display-only; it never changes the calculated floor.
        if (type(r.readyAt)=="number" and now>=r.readyAt+linger) or nowEpoch-r.diedAt>self.db.settings.retention then
            self.active[guid]=nil
            if self.OnVoidMarkTimerRemoved then self:OnVoidMarkTimerRemoved(r, "expired") end
            changed=true
        else
            list[#list+1]=r
        end
    end
    table.sort(list,function(a,b) return a.diedAt>b.diedAt end)
    for i=65,#list do
        local r=list[i]
        self.active[r.guid]=nil
        if self.OnVoidMarkTimerRemoved then self:OnVoidMarkTimerRemoved(r, "capacity") end
        changed=true
    end
    if changed and self.char then self:Save() end
end

function A:RestoreTimers()
    local nowEpoch=self:Epoch(); local now=self:Now()
    for guid,r in pairs(self.char.timers) do
        if type(r)=="table" and type(r.diedAt)=="number" and type(r.calc)=="table" and type(r.name)=="string" and type(r.savedAt)=="number" then
            local elapsed=nowEpoch-r.savedAt
            local savedRemaining=type(r.readyRemaining)=="number" and r.readyRemaining or r.remaining
            if type(savedRemaining)=="number" and elapsed>=0 and nowEpoch-r.diedAt<self.db.settings.retention then
                r.guid=guid
                -- Do not clamp at zero: a negative value means the row is already
                -- in its post-RETURN-POSSIBLE linger window.
                r.readyAt=now+savedRemaining-elapsed
                if type(r.routeRemaining)=="number" then
                    r.routeAt=now+r.routeRemaining-elapsed
                elseif type(r.routeSeconds)=="number" and type(r.calc.seconds)=="number" then
                    -- Older saved rows did not persist routeRemaining. Rebuild
                    -- relative to the saved earliest timer when possible.
                    r.routeAt=r.readyAt+(r.routeSeconds-r.calc.seconds)
                end
                self.active[guid]=r
                if self.OnVoidMarkTimerCreated then self:OnVoidMarkTimerCreated(r, true) end
            end
        end
    end
    self:PruneTimers(); self:RenderRows(); self:ArmTimer()
end

function A:ArmTimer()
    if self.uiTimer then self.uiTimer:Cancel(); self.uiTimer=nil end
    if not next(self.active) then return end
    -- One ticker for the whole window avoids allocating a new timer every second.
    self.uiTimer=C_Timer.NewTicker(1,function()
        A:PruneTimers(); A:RenderRows()
        if not next(A.active) and A.uiTimer then
            A.uiTimer:Cancel(); A.uiTimer=nil
        end
    end)
end

local function clockText(seconds)
    local t=math.max(0,math.floor(seconds or 0))
    return string.format("%d:%02d",math.floor(t/60),t%60)
end

function A:RouteTimerLabel(r)
    if not r or not r.routeAt then return nil end
    local delta=r.routeAt-self:Now()
    if delta<=0 then return "NOW" end
    return clockText(delta)
end

function A:TimerLabel(r)
    local delta=r.readyAt-self:Now()
    if delta<=0 then
        local elapsed=math.floor(-delta)
        local route=self:RouteTimerLabel(r)
        if route and route~="NOW" then
            return string.format("EARLY +%d:%02d | ROUTE ~%s",math.floor(elapsed/60),elapsed%60,route)
        end
        return string.format("RETURN POSSIBLE +%d:%02d",math.floor(elapsed/60),elapsed%60)
    end
    local early=clockText(delta)
    local route=self:RouteTimerLabel(r)
    if route then return string.format("E %s | R ~%s",early,route) end
    return early
end

function A:ClearTimers()
    if self.OnVoidMarkTimerRemoved then
        for _,r in pairs(self.active) do self:OnVoidMarkTimerRemoved(r, "clear") end
    end
    self.active={}; self.char.timers={}; self:ArmTimer(); self:RenderRows()
end
