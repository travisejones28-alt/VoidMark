-- Run from the repository root: luatex --luaonly tests/runback_regression.lua
-- Exercises the loaded engine/integration with real static assignment data.
local M=dofile('tests/wow_mock.lua')
local function load(path,A) return assert(loadfile(path))('VoidMark',A) end
local function eq(a,b,label) assert(a==b,label..': expected '..tostring(b)..', got '..tostring(a)) end
local function near(a,b,label) assert(math.abs(a-b)<1e-7,label..': '..tostring(a)..' vs '..tostring(b)) end
GetNetStats=function() return 0,0,0,0 end
UnitPosition=function(unit)
    local u=M.units[unit]; local p=u and u.pos
    if p then return p.x,p.y,p.z,p.map end
end
UnitIsGhost=function(unit) return M.units[unit] and M.units[unit].ghost==true or false end
UnitIsDeadOrGhost=function(unit) local u=M.units[unit]; return u and (u.dead==true or u.ghost==true) or false end
CheckInteractDistance=function() return false end
C_Map.GetAreaInfo=function() return nil end
C_Map.GetBestMapForUnit=function() return 1433 end
local data={}
load('RunBack/Data/Areas.lua',data); load('RunBack/Data/Graveyards.lua',data)
local function engine()
    M.timers={}; M.tickers={}; M.now=1000; M.epoch=1791010800; M.sounds=0; M.combat=false
    M.units={player={name='Taliaa',realm='Whitemane',guid='Player-1-SELF',class='PRIEST',faction='Horde',pos={x=0,y=0,z=0,map=0}}}
    Spy={db={profile={EnableSound=true,WarnOnKOS=true,CurrentList=1}},NearbyList={},ActiveList={},InactiveList={},LastHourList={},RunBackPinned={}}
    Spy.RefreshCurrentList=function() end; Spy.UpdateActiveCount=function() end
    SpyPerCharDB={PlayerData={},KOSData={}}
    TaliaaGankTracker=nil; TaliaaRunBackDB=nil; TaliaaRunBackCharDB=nil
    local A={Data={areas=data.Data.areas,maps=data.Data.maps,links=data.Data.links,graveyards=data.Data.graveyards}}
    load('RunBack/Data/Network.lua',A)
    for _,path in ipairs({'Core','Areas','Graveyards','Routing','Timers','CombatLog','UI','Diagnostics'}) do load('RunBack/'..path..'.lua',A) end
    load('RunBackIntegration.lua',A)
    A:InitDB(); A:BuildAreaIndex(); A:RefreshGroup()
    return A
end
local function record(A,guid,name,seconds)
    local r={guid=guid,name=name,diedAt=M.epoch,deathObservedAt=M.now,readyAt=M.now+seconds,calc={seconds=seconds},timingRevision=A.timingRevision}
    A.active[guid]=r; A:OnVoidMarkTimerCreated(r); return r
end

do
    local A=engine(); math.randomseed(20261004)
    for _=1,2000 do
        local p={x=math.random(-3000,3000),y=math.random(-3000,3000),map=0,uncertainty=math.random(0,400)}
        local g={id=1,map=0,x=math.random(-3000,3000),y=math.random(-3000,3000)}
        local other={id=2,map=0,x=math.random(-3000,3000),y=math.random(-3000,3000)}
        local angle=math.random()*2*math.pi; local radius=math.random()*p.uncertainty
        local corpse={x=p.x+radius*math.cos(angle),y=p.y+radius*math.sin(angle),map=0}
        local c=A:FloorFor(p,{candidates={g,other}},'Human','Alliance')
        assert(c.seconds<=math.max(0,A:Distance(corpse,g)-40)/8.75+1e-7,'geometry must remain an optimistic floor for valid inputs')
    end
    near(A:FloorFor(nil,{candidates={}},nil,'Alliance').seconds,0,'unlocated warning')
    near(A:FloorFor({x=0,y=0,map=0,uncertainty=0},{candidates={}},nil,'Alliance').seconds,0,'missing coverage warning')
    near(A:GhostSpeed('NightElf','Alliance'),10.5,'Wisp speed'); near(A:GhostSpeed(nil,'Horde'),8.75,'unknown Horde speed')
    print('PASS: 2000 valid-input geometric cases, ghost speeds and immediate fallbacks')
end

do
    local A=engine(); A.db.settings.routes=true
    local gy={id=90001,x=200,y=0,z=0,map=0,name='Synthetic graveyard'}
    A.ResolveGraveyard=function() return {predicted=gy,candidates={gy}} end
    M.units.party1={name='Friend',guid='Player-1-FRIEND',pos={x=200,y=0,map=0}}
    M.units.partypet1={name='Pet',guid='Pet-1-FRIEND',pos={x=400,y=0,map=0}}
    A:RefreshGroup()
    eq(A:RememberDamageEventEnvelope('Player-1-PET','SWING_DAMAGE',nil,nil,'Pet-1-FRIEND'),true,'party pet envelope')
    near(A.enemyBounds['Player-1-PET'].x,400,'party pet source anchor')
    eq(A:RememberDamageEventEnvelope('Player-1-UNKNOWN','SWING_DAMAGE',nil,nil,'Player-1-MISSING'),false,'unknown source cannot borrow observer coordinates')
    M.units.partypet1.pos=nil
    eq(A:RememberDamageEventEnvelope('Player-1-PET-MISSING','SWING_DAMAGE',nil,nil,'Pet-1-FRIEND'),false,'unlocated pet cannot borrow observer coordinates')
    local enemy='Player-1-GROUP'; A.seen[enemy]={race='Human',faction='Alliance'}
    A:CombatEvent(0,'SWING_DAMAGE',false,'Player-1-FRIEND','Friend',0x102,nil,enemy,'Enemy',0x440,nil,1)
    A:CombatEvent(0,'PARTY_KILL',false,'Player-1-FRIEND','Friend',0x102,nil,enemy,'Enemy',0x440,nil,0,false,nil,nil,false)
    M.advance(.01)
    local r=assert(A.active[enemy]); near(r.position.x,200,'actual party source anchor'); near(r.calc.seconds,0,'corpse near source graveyard')
    eq(next(A.Data.nodes),nil,'ordinary kill does not allocate network'); eq(#A.routeQueue,0,'ordinary kill does not queue routes even with diagnostic setting on')
    M.units.party1.guid='Player-1-REPLACED'
    eq(A:FindGroupSourceUnit('Player-1-FRIEND'),nil,'recycled group token rejected')
    M.advance(2.01)
    local p=A:CaptureLocation(enemy); eq(p.uncertainty,nil,'stale combat envelope unbounded')
    print('PASS: party/pet source locations, recycled tokens, stale envelopes and no automatic route work')
end

do
    local A=engine(); local g=A.Data.graveyards[3]
    local p={x=g.x,y=g.y,z=g.z,map=g.map,uncertainty=0}
    local unknown=A:ResolveGraveyard(p,40,'Alliance',false)
    local exact=A:ResolveGraveyard(p,40,'Alliance',true)
    near(A:FloorFor(p,unknown,'Human','Alliance').seconds,0,'enemy at Darkshire cannot inherit Westfall-only assignment')
    assert(A:FloorFor(p,exact,'Human','Alliance').seconds>0,'known area uses that area rather than unknown candidate union')
    local border={x=-10600,y=480,map=0,uncertainty=40}
    near(A:FloorFor(border,A:ResolveGraveyard(border,40,'Alliance',false),'Human','Alliance').seconds,
        A:FloorFor(border,A:ResolveGraveyard(border,10,'Alliance',false),'Human','Alliance').seconds,'unknown border warning independent of observer area')
    local distant={x=100000,y=100000,map=0,uncertainty=40}
    eq(#A:ResolveGraveyard(distant,40,'Alliance',false).candidates,0,'no continent-wide fallback outside local map coverage')
    local start=A:ResolveGraveyard(p,10,'Alliance',true)
    for _,v in ipairs(start.candidates) do assert(v.id~=629,'test graveyard excluded') end
    print('PASS: enemy-local candidates, exact-area selection, border consistency and missing coverage')
end

do
    local A=engine(); local r=record(A,'Player-1-REZ','Enemy',80)
    SpyPerCharDB.KOSData.Enemy=true
    local calls=0; local original=Spy.OnRunBackRezConfirmed
    Spy.OnRunBackRezConfirmed=function(self,...) calls=calls+1; return original(self,...) end
    M.units.target={name='Enemy',guid=r.guid,class='MAGE',faction='Alliance',dead=true,pos={x=100,y=0,map=0}}
    M.units.mouseover=M.units.target
    A:Observe('target'); eq(calls,0,'death-event grace')
    M.advance(1); A:Observe('target'); eq(calls,0,'dead unit cannot confirm resurrection')
    M.units.target.dead=false; M.units.target.feign=true; A:Observe('target'); eq(calls,0,'Feign is not live confirmation')
    M.units.target.feign=false
    local position=UnitPosition; UnitPosition=function(unit) assert(unit~='mouseover','mouseover must remain identity-only'); return position(unit) end
    A:Observe('mouseover'); eq(calls,0,'mouseover cannot confirm or query position'); UnitPosition=position
    eq(A.units[r.guid],'target','mouseover cannot replace a readable target token')
    A:Observe('target'); A:Observe('target'); A:CheckLiveTimers()
    eq(calls,1,'resurrection callback once'); eq(M.sounds,1,'KOS resurrection alert once'); near(r.readyAt,1080,'live observation cannot alter timer')
    A:Save(); A.active={}; A:RestoreTimers(); A:Observe('target'); eq(calls,1,'saved confirmation cannot replay alert')
    local steady=record(A,'Player-1-STEADY','Steady',80)
    M.units.nameplate1={name='Steady',guid=steady.guid,dead=true}
    A:Observe('nameplate1'); M.advance(1); M.units.nameplate1.dead=false; A:CheckLiveTimers()
    eq(steady.rezConfirmed,true,'same nameplate token across resurrection detected by existing tick')
    print('PASS: positive resurrection detection, Feign/mouseover gates, fixed timing and one-shot reload-safe alerts')
end

do
    local A=engine()
    local one=record(A,'Player-1-A','Duplicate-RealmA',100)
    local two=record(A,'Player-1-B','Duplicate-RealmB',200)
    eq(Spy:GetRunBackRecord('Duplicate-RealmA'),one,'exact realm A'); eq(Spy:GetRunBackRecord('Duplicate-RealmB'),two,'exact realm B')
    eq(Spy:GetRunBackRecord('Duplicate-RealmC'),nil,'unknown realm cannot alias known realm')
    eq(Spy:GetRunBackRecord('Duplicate'),nil,'ambiguous bare name'); eq(Spy:IsRunBackPinned('Duplicate'),false,'ambiguous bare pin')
    SpyPerCharDB.PlayerData.Duplicate={guid=one.guid}
    eq(Spy:GetRunBackRecord('Duplicate'),one,'GUID safely resolves bare Spy identity')
    SpyPerCharDB.PlayerData['Duplicate-RealmA']={guid=''}
    eq(Spy:GetRunBackRecord('Duplicate-RealmA'),one,'empty historical GUID cannot hide exact realm identity')
    A:ClearTimers(); eq(Spy.NearbyList['Duplicate-RealmA'],nil,'clear removes dead row'); eq(Spy.RunBackPinned['Duplicate-RealmA'],nil,'clear releases exact pin')
    print('PASS: full-realm identity, ambiguous name rejection and GUID resolution')
end

do
    local A=engine(); local r=record(A,'Player-1-CLOCK','Clock',100)
    local display=Spy:GetRunBackDisplay('Clock'); eq(display.time,'1:40','yellow countdown'); eq(display.ready,false,'not ready')
    M.advance(115); display=Spy:GetRunBackDisplay('Clock'); eq(display.time,'+0:15','red elapsed'); eq(display.ready,true,'ready')
    A:Save(); eq(A.char.timers[r.guid].readyRemaining,-15,'signed save'); M.advance(10); A.active={}; A:RestoreTimers()
    near(A.active[r.guid].readyAt,M.now-25,'signed reload')
    M.advance(34.99); A:PruneTimers(); assert(A.active[r.guid],'row held until 60 seconds after floor')
    M.advance(.01); A:PruneTimers(); eq(A.active[r.guid],nil,'exact 60-second expiry'); eq(Spy:IsRunBackPinned('Clock'),false,'pin released')
    local nan=0/0
    for _,value in ipairs({nan,math.huge,-math.huge}) do
        A.char.timers.bad={name='Bad',diedAt=M.epoch,calc={seconds=10},savedAt=M.epoch,readyRemaining=value}
        A:RestoreTimers(); eq(A.active.bad,nil,'invalid saved warning rejected')
    end
    A.char.timers.old={name='Legacy',diedAt=M.epoch-10,calc={seconds=100},savedAt=M.epoch,readyRemaining=90,
        position={x=0,y=0,map=0,uncertainty=15,source='recent combat envelope'},area=44,faction='Alliance'}
    A:RestoreTimers(); near(A.active.old.readyAt,M.now-10,'old unverified envelope migrates to immediate warning')
    A.char.timers.invalidpos={name='Invalid position',diedAt=M.epoch-10,calc={seconds=100},savedAt=M.epoch,readyRemaining=90,position=true,timingRevision=A.timingRevision}
    A:RestoreTimers(); near(A.active.invalidpos.readyAt,M.now-10,'malformed saved position cannot preserve positive floor')
    TaliaaRunBackDB.settings.retention=nan; A:InitDB(); eq(A.db.settings.retention,900,'invalid numeric setting repaired')
    print('PASS: compact clocks, signed reload, exact expiry, nonfinite rejection and older-timer migration')
end

do
    local A=engine(); A:InstallCommands()
    assert(pcall(SlashCmdList.TALIAARUNBACK,'resetpos'),'integrated resetpos cannot dereference missing standalone frame')
    local g=A.Data.graveyards[104]; local p={x=g.x+100,y=g.y,z=g.z+300,map=0,uncertainty=0}
    A.PlayerContext=function() return {position=p,area=44,zone=44,uiMap=1433,zoneName='Redridge Mountains'} end
    A.ShowReport=function(self,title,body) self.capturedReport=body end
    A:AnalyzePosition('horde'); assert(A.capturedReport:find('warning 7s'),'diagnostics use the same 2D floor as countdown')
    local enemy='Player-1-DUP'
    local function death()
        A:CombatEvent(0,'PARTY_KILL',false,UnitGUID('player'),'Taliaa',0x101,nil,enemy,'Duplicate',0x440,nil,0,false,nil,nil,false)
        M.advance(.01)
    end
    death(); local first=A.active[enemy]; M.advance(3); death(); eq(A.metrics.deaths,1,'delayed duplicate coalesced'); eq(A.active[enemy],first,'duplicate cannot restart countdown')
    print('PASS: integrated commands, consistent diagnostic geometry and six-second death deduplication')
end

do
    local A=engine(); local key=A:CalibrationKey(44,104,'Alliance'); local samples={}
    for i=1,5 do samples[i]={routeFactor=10,geoFactor=10,releaseDelay=15} end
    A.db.calibration.routes[key]={samples=samples}
    local seconds,note=A:ApplyRouteCalibration(100,50,44,104,'Alliance')
    near(seconds,100,'rejected factors cannot train release padding'); assert(note:find('NONE'),'invalid sample count cannot create HIGH confidence')
    samples[6]={routeFactor=1.5,geoFactor=1.2,releaseDelay=1,actualRun=150,corpseRangeConfirmed=true,actualStartGY=104,actualStartGYDistance=1}
    local c=A:GetRouteCalibration(44,104,'Alliance'); eq(c.n,1,'confidence counts accepted factors only')
    samples[7]={routeFactor=1.5,geoFactor=1.2,releaseDelay=1,actualRun=150,corpseRangeConfirmed=true,actualStartGY=3,actualStartGYDistance=1}
    eq(A:GetRouteCalibration(44,104,'Alliance').n,1,'wrong graveyard sample rejected')
    local function session(actualGY)
        return {deadAt=M.now-31,ghostAt=M.now-30,reclaimAt=M.now,corpseRangeConfirmed=true,ctx={zone=44},corpse={map=0,x=0,y=0},
            faction='Alliance',graveyard=104,calc={seconds=20},releaseDelay=1,actualStartGY=actualGY,actualStartGYDistance=0}
    end
    A.calibrationSession=session(3); A:FinishCalibration(); eq(#samples,7,'mismatched actual graveyard not saved')
    A.calibrationSession=session(104); A:FinishCalibration(); eq(#samples,8,'validated corpse run saved')
    A.calibrationSession=session(104); A.calibrationSession.reclaimAt=nil; A.calibrationSession.corpseRangeConfirmed=nil
    A:CalibrationEvent('PLAYER_UNGHOST'); eq(#samples,8,'non-corpse resurrection cannot train calibration')
    A.calibrationSession=session(104); A.calibrationSession.reclaimAt=nil; A.calibrationSession.corpseRangeConfirmed=nil
    M.units.player.ghost=true; A:CalibrationEvent('CORPSE_IN_RANGE'); eq(#samples,9,'client corpse-range event completes own run')
    print('PASS: accepted-only calibration confidence, matching graveyard and authoritative own corpse-range completion')
end

do
    local A=engine(); local gy=A.Data.graveyards[3]
    eq(#A.Data.nodes,0,'network starts unallocated'); assert(A:EnsureRouteData(),'explicit diagnostics load graph'); eq(#A.Data.nodes,47718,'complete graph loaded')
    local goal
    for _,n in ipairs(A.Data.nodes) do
        if n[3]==gy.map and n[4]==10 then
            local d=A:Distance({x=n[1],y=n[2],map=n[3]},gy)
            if d>300 and d<600 then goal={x=n[1],y=n[2],map=n[3],uncertainty=0}; break end
        end
    end
    assert(goal)
    local function routedRecord(guid)
        A:CreateTimer({guid=guid,name=guid,at=M.now,position=goal,context={area=10,zone=10},exactArea=true,faction='Alliance',race='Human'})
        local r=A.active[guid]; local ready=r.readyAt; A:RequestTimerRoute(r)
        eq(#A.routeQueue,1,'explicit route queued'); near(r.readyAt,ready,'queuing route never delays floor'); return r,ready
    end
    local expired=routedRecord('Player-1-EXPIRE'); expired.readyAt=M.now-60; A:PruneTimers(); eq(#A.routeQueue,0,'expiry cancels queued work')
    local capped=routedRecord('Player-1-CAP'); capped.diedAt=M.epoch-200
    for i=1,64 do record(A,'Player-1-CAP-'..i,'Cap'..i,100) end
    A:PruneTimers(); eq(A.active[capped.guid],nil,'old route owner removed at capacity'); eq(#A.routeQueue,0,'capacity cancels queued work')
    A:ClearTimers(); routedRecord('Player-1-CLEAR'); A:ClearTimers(); eq(#A.routeQueue,0,'clear cancels queued work')
    local replaced=routedRecord('Player-1-REPLACE')
    A:CreateTimer({guid=replaced.guid,name=replaced.name,position=goal,context={area=10,zone=10},exactArea=true,faction='Alliance',race='Human'})
    eq(#A.routeQueue,0,'replacement cancels prior job'); A:ClearTimers()
    local r,ready=routedRecord('Player-1-ROUTE')
    local ticks=0
    while r.routeRequested and ticks<10000 do M.advance(.021); ticks=ticks+1 end
    eq(r.routeRequested,nil,'route completes'); assert(r.routeStatus~='Queued','completion status retained'); near(r.readyAt,ready,'completed advisory route cannot move countdown')
    print('PASS: lazy graph, explicit routes, cancellation on expiry/capacity/clear/replacement and immutable countdown')
end
print('All focused runback regression checks passed. Live Era terrain, secure UI and combat validation still require the game client.')
