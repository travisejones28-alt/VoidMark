local _, A = ...
A.liveGY={}; A.linkCache={}

function A:Eligible(team,faction)
    return team==0 or not faction or faction=="Unknown" or (team==469 and faction=="Alliance") or (team==67 and faction=="Horde")
end

local function IsUsableGraveyard(g)
    if not g then return false end
    -- Classic-DB includes test/internal graveyards that are not valid player
    -- release points. Never let those drive a PvP corpse-run timer.
    local name=string.lower(tostring(g.name or ""))
    if name:find("gm client",1,true) or name:find("do not bug",1,true) or name:find("test",1,true) then
        return false
    end
    return true
end

function A:ResolveLinks(area,faction)
    local key=tostring(area)..":"..tostring(faction)
    if self.linkCache[key] then return self.linkCache[key][1],self.linkCache[key][2] end
    for _,id in ipairs(self:AreaChain(area)) do
        local out={}
        for _,link in ipairs(self.Data.links[id] or {}) do
            if self:Eligible(link[2],faction) then
                local gy=self.Data.graveyards[link[1]]
                if IsUsableGraveyard(gy) then out[#out+1]={gy=gy,team=link[2],area=id} end
            end
        end
        if #out>0 then
            self.linkCache[key]={out,id}
            return out,id
        end
    end
    return {},nil
end

function A:RefreshLiveGraveyards(ui)
    if not ui then return end
    local rows=self:Safe(C_DeathInfo and C_DeathInfo.GetGraveyardsForMap,ui)
    local out={}
    if type(rows)=="table" then
        for _,r in ipairs(rows) do
            local c,w
            if r.position then c,w=self:Safe(C_Map and C_Map.GetWorldPosFromMapPos,ui,r.position) end
            local x,y; if w then x,y=w:GetXY() end
            out[#out+1]={id=r.graveyardID,name=r.name,map=c,x=x,y=y,selectable=r.isGraveyardSelectable,poi=r.areaPoiID}
        end
    end
    self.liveGY[ui]=out
end

function A:ResolveGraveyard(p,area,faction,exactArea)
    -- Scarlet Monastery special case. Faol's Rest (GY 429) is the actual
    -- Alliance release graveyard for deaths around the monastery. Some static
    -- subarea assignments in the imported Classic-DB data can resolve to a
    -- farther Tirisfal graveyard first, producing obviously inflated timers.
    local faol=self.Data.graveyards and self.Data.graveyards[429]
    if faction=="Alliance" and p and faol and IsUsableGraveyard(faol) then
        local faolDistance=self:Distance(p,faol)
        if faolDistance and faolDistance<=1200 then
            return {
                predicted=faol,
                candidates={faol},
                assignmentArea=area,
                reason=string.format("Scarlet Monastery / eastern Tirisfal override: Faol's Rest is %.0f yd away",faolDistance),
                source="VoidMark verified Scarlet Monastery override",
                exactArea=exactArea,
                candidateScope="Scarlet Monastery / Faol's Rest vicinity",
            }
        end
    end

    local links,used=self:ResolveLinks(area,faction)
    local predicted,best

    -- The server prediction and the warning floor are both restricted to the
    -- first area in the observer's area->zone parent chain that actually has
    -- eligible graveyard assignments.  Enemy subzone is not exposed in Era,
    -- but widening this to every graveyard on the continent creates false
    -- zero-second timers whenever an unrelated graveyard happens to be near.
    -- A real PvP kill is therefore bounded to the death-vicinity zone/parent
    -- assignment instead of inventing continent-wide possibilities.
    local candidates={}
    for _,v in ipairs(links) do
        local g=v.gy
        candidates[#candidates+1]=g
        local d=self:Distance(p,g)
        if d then
            if self:Finite(p and p.z) and self:Finite(g.z) then
                d=(d*d+(p.z-g.z)^2)^.5
            end
            if not best or d<best or (d==best and g.id<predicted.id) then
                predicted,best=g,d
            end
        end
    end

    table.sort(candidates,function(a,b) return a.id<b.id end)

    local reason
    if used then
        reason=string.format("First eligible linked area %d (%s); %d eligible graveyard%s; nearest %s candidate",
            used,self:AreaName(used),#candidates,#candidates==1 and "" or "s",
            (p and self:Finite(p.z)) and "3D" or "2D (height unavailable)")
    else
        reason="No eligible graveyard assignment in the observer area/parent chain; no server prediction"
    end

    return {
        predicted=predicted,
        candidates=candidates,
        assignmentArea=used,
        reason=reason,
        source="CMaNGOS Classic-DB; Era assignment unverified",
        exactArea=exactArea,
        candidateScope=used and "death-vicinity area/parent assignment" or "none",
    }
end
