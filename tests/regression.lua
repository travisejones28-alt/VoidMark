-- Run from repository root: luatex --luaonly tests/regression.lua
local M=dofile('tests/wow_mock.lua')
local function loadModule(path,namespace) M.load(path,namespace) end
local function eq(a,b,label) assert(a==b,label..': expected '..tostring(b)..', got '..tostring(a)) end
local function findHandler(upvalue)
 for _,f in ipairs(M.frames) do
  if f.scripts.OnEvent then
   for i=1,80 do local n=debug.getupvalue(f.scripts.OnEvent,i);if n==upvalue then return f end end
  end
 end
 error('Missing handler '..upvalue)
end
SpyDB={};SpyPerCharDB={PlayerData={},KOSData={}}
Spy={db={profile={}},NearbyList={},ActiveList={},RealmName='Whitemane',FactionName='Horde',CharacterName='Taliaa'}
loadModule('GankRepository.lua');loadModule('GankTracker.lua')
local GT=TaliaaGankTracker
local effects=0
VoidMarkKillEffects={OnKill=function() effects=effects+1 end,StopActiveSound=function() end}
M.units.target={name='Hunter',guid='Player-1-HUNTER',class='HUNTER',feign=true}
eq(GT:IsKnownHunter('Hunter','Player-1-HUNTER'),true,'Hunter method')
local before=GT.currentStreak or 0
GT:RecordKill('Hunter','Player-1-HUNTER',false)
eq(GT.currentStreak or 0,before,'Feign streak')
eq(TaliaaGankRepository:GetHistoricalCount('Hunter','Player-1-HUNTER'),0,'Feign history')
M.units.target.feign=false
GT:ConfirmHunterRealDeath('Player-1-HUNTER','Hunter')
GT:RecordKill('Hunter','Player-1-HUNTER',false)
eq(GT.currentStreak,before+1,'real Hunter streak');eq(effects,1,'real Hunter immediate effect')
eq(TaliaaGankRepository:GetHistoricalCount('Hunter','Player-1-HUNTER'),1,'real Hunter history')
GT:RecordKill('Hunter','Player-1-HUNTER',false)
eq(GT.currentStreak,before+1,'duplicate streak');eq(effects,1,'duplicate sound')
M.now=1;GT:RecordKill('First','Player-1-FIRST',false)
eq(GT.currentStreak,before+2,'first kill before six seconds');M.now=200
local sap=findHandler('SAP_COMM_PREFIX');local sounds=M.sounds
local function sapMessage(channel,sender) sap.scripts.OnEvent(sap,'CHAT_MSG_ADDON','VMSAP','SAPPED|Friend',channel,sender) end
sapMessage('PARTY','Taliaa-Whitemane');sapMessage('WHISPER','Friend-Whitemane');eq(M.sounds,sounds,'sap self/channel')
sapMessage('PARTY','Friend-Whitemane');sapMessage('PARTY','Friend-Whitemane');eq(M.sounds,sounds+1,'sap throttle')
print('PASS: Hunter classification, persistent dedupe, startup credit and sap alerts')
-- Execute the UI callbacks whose late locals previously resolved as globals.
local setView=M.upvalue(GT.Frame.RecordsViewButton.scripts.OnClick,'SetHuntViewMode')
local updateDisplay=M.upvalue(setView,'UpdateDisplay')
local buildRecords=M.upvalue(updateDisplay,'BuildRecordStats')
local weeklyReset=M.upvalue(buildRecords,'WeeklyResetStart')
local firstStats=buildRecords()
local oldEpoch=M.epoch
M.epoch=weeklyReset(M.epoch)+7*86400+1
local nextStats=buildRecords()
assert(nextStats~=firstStats,'weekly reset must invalidate records cache without a new kill')
M.epoch=oldEpoch
GT.Frame.RecordsViewButton.scripts.OnClick()
eq(M.upvalue(updateDisplay,'lastLabel').text,'PERSONAL RECORD','records heading')
GT.Frame.TodayViewButton.scripts.OnClick()
eq(M.upvalue(updateDisplay,'lastLabel').text,'LAST MARK','today heading')
local syncButton
for _,f in ipairs(M.frames) do if f.Label and f.Label.text=='SYNC NOW' then syncButton=f end end
assert(syncButton)
local updateRepo=M.upvalue(syncButton.scripts.OnClick,'UpdateRepoStatus')
local originalStatus=TaliaaGankRepository.GetSyncStatus
TaliaaGankRepository.GetSyncStatus=function() return {syncing=true} end
updateRepo();eq(syncButton.Label.text,'SYNCING...','sync heading');eq(syncButton.enabled,false,'sync disabled while busy')
TaliaaGankRepository.GetSyncStatus=function() return {syncing=false} end
updateRepo();eq(syncButton.Label.text,'SYNC NOW','sync idle heading');eq(syncButton.enabled,true,'sync enabled after completion')
TaliaaGankRepository.GetSyncStatus=originalStatus
print('PASS: record heading, weekly cache boundary and sync-button state')


loadModule('Modules/EnemyMoves.lua')
local em=findHandler('TrackSpell');local track=M.upvalue(em.scripts.OnEvent,'TrackSpell');local getEnemy=M.upvalue(track,'GetEnemy')
local guid='Player-1-PALADIN';track(guid,'Pally','PALADIN',642,'Divine Shield','SPELL_CAST_SUCCESS')
local e=getEnemy(guid)
eq(e.spells.DIVINE_SHIELD.activeDuration,10,'rank 1 duration');eq(e.spells.DIVINE_PROTECTION.cooldownEnd,M.now+60,'shared lockout')
local expires=e.spells.DIVINE_SHIELD.cooldownEnd;M.now=M.now+0.2
em.scripts.OnEvent(em,'CHAT_MSG_ADDON','VMEM1',guid..'~Pally~PALADIN~642~SPELL_CAST_SUCCESS','PARTY','Friend-Whitemane')
eq(e.spells.DIVINE_SHIELD.cooldownEnd,expires,'peer duplicate')
em.scripts.OnEvent(em,'CHAT_MSG_ADDON','VMEM1',guid..'~Pally~PALADIN~1020~SPELL_CAST_SUCCESS','PARTY','Taliaa-Whitemane')
eq(e.spells.DIVINE_SHIELD.activeDuration,10,'own echo')
local unpack=table.unpack or unpack
CombatLogGetCurrentEventInfo=function() return unpack({[2]='SPELL_AURA_REMOVED',[8]=guid,[9]='Pally',[12]=642,[13]='Divine Shield'},1,13) end
em.scripts.OnEvent(em,'COMBAT_LOG_EVENT_UNFILTERED')
eq(e.spells.DIVINE_SHIELD.activeEnd,nil,'casterless removal');eq(e.spells.DIVINE_SHIELD.cooldownEnd,expires,'removal preserves cooldown')
M.now=M.now+1;track(guid,'Pally','PALADIN',1020,'Divine Shield','SPELL_CAST_SUCCESS');eq(e.spells.DIVINE_SHIELD.activeDuration,12,'rank 2 duration')
local mage='Player-1-MAGE';track(mage,'Mage','MAGE',11426,'Ice Barrier','SPELL_CAST_SUCCESS')
local me=getEnemy(mage);me.spells.ICE_BARRIER.activeEnd=M.now+45
track(mage,'Mage','MAGE',12472,'Cold Snap','SPELL_CAST_SUCCESS')
eq(me.spells.ICE_BARRIER.cooldownEnd,M.now,'Cold Snap cooldown');eq(me.spells.ICE_BARRIER.activeEnd,M.now+45,'Cold Snap aura')
eq(track('Player-1-PRIEST','Priest','PRIEST',976,'Shadow Protection','SPELL_AURA_APPLIED'),false,'Priest buff potion collision')
eq(track('Player-1-PRIEST','Priest','PRIEST',17548,'Shadow Protection','SPELL_AURA_APPLIED'),true,'real protection potion')
print('PASS: bubble ranks, lockouts, party sync, aura removal, Cold Snap and potions')

GetSpellInfo=function(id) return 'Spell '..id,'rank',123 end
local sentinel={};_G._=sentinel;loadModule('Modules/DamageRecords.lua')
local dr=findHandler('SaveRecord')
CombatLogGetCurrentEventInfo=function() return unpack({[2]='SPELL_DAMAGE',[4]=UnitGUID('player'),[8]='Player-1-ENEMY',[9]='Enemy',[12]=1,[13]='Spell',[15]=200,[21]=true},1,21) end
local function hit() dr.scripts.OnEvent(dr,'COMBAT_LOG_EVENT_UNFILTERED') end
hit();eq(_G._,sentinel,'global underscore');eq(SpyDB.VoidMarkDamageRecords.characters['Taliaa-Whitemane'].overall.amount,200,'first character')
M.units.player.name='Other';M.units.player.guid='Player-1-OTHER';hit()
eq(SpyDB.VoidMarkDamageRecords.characters['Other-Whitemane'].overall.amount,200,'second character')
eq(SpyDB.VoidMarkDamageRecords.characters['Taliaa-Whitemane'].overall.character,'Taliaa','first character retained')
M.units.player.name='Taliaa';M.units.player.guid='Player-1-SELF'
print('PASS: damage-record character isolation and global hygiene')

local A={active={},db={settings={retention=900}},char={timers={}}}
A.Now=function() return M.now end;A.Epoch=function() return M.epoch end;A.Save=function() end
local removed=0
A.OnVoidMarkTimerRemoved=function(self,r) assert(not self.active[r.guid]);removed=removed+1 end
loadModule('RunBack/Timers.lua',A)
for i=1,65 do A.active[tostring(i)]={guid=tostring(i),diedAt=M.epoch-i,readyAt=M.now+100} end
A:PruneTimers();eq(removed,1,'capacity hook');M.now=M.now+161;A:PruneTimers();eq(removed,65,'expiry hooks');eq(next(A.active),nil,'timers expired')
A.char.timers={restore={name='Restored',diedAt=M.epoch-30,calc={seconds=10},savedAt=M.epoch-5,readyRemaining=-10}}
A.RenderRows=function() end;A:RestoreTimers();eq(A.active.restore.readyAt,M.now-15,'reload linger')
-- Clear checks require the removal hook to observe the active record, because
-- ClearTimers deliberately calls all hooks before replacing the active table.
A.OnVoidMarkTimerRemoved=nil;A:ClearTimers()
local B={db={settings={assist=30}},metrics={ignored=0},involved={},seen={},units={}}
B.Finite=function(_,n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
B.Now=A.Now;B.Epoch=A.Epoch;B.IsOutdoor=function() return true end
B.CaptureLocation=function() return nil,{},false end;B.ScheduleCleanup=function() end
B.Safe=function(_,fn,...) if fn then return fn(...) end end
GetNetStats=function() return 0,0,0,0 end
loadModule('RunBack/CombatLog.lua',B)
local scheduled=0;B.CreateTimer=function() scheduled=scheduled+1 end
local hunter='Player-1-HUNTER2';M.units.target={name='Hunter2',guid=hunter,class='HUNTER',feign=true};B.involved[hunter]=M.now
B:CombatEvent(0,'UNIT_DIED',false,nil,nil,nil,nil,hunter,'Hunter2',0x440,nil,0,false)
M.advance(1);eq(scheduled,0,'Feign runback')
M.units.target.feign=false;GT:ConfirmHunterRealDeath(hunter,'Hunter2')
B:CombatEvent(0,'PARTY_KILL',false,UnitGUID('player'),'Taliaa',0x101,nil,hunter,'Hunter2',0x440,nil,0,false,nil,nil,false)
M.advance(1);eq(scheduled,1,'real Hunter runback')
print('PASS: runback capacity, expiry, reload and Hunter death classification')

local mounted=true;IsMounted=function() return mounted end
loadModule('Modules/RideOrDie.lua');local TRD=TaliaasRideOrDie
TRD.db={enabled=true,sets={Riding={[1]='riding'},PvP={[1]='pvp'},Holy={[1]='holy'}},ridingSetName='Riding',defaultGroundSet='PvP'}
TRD.RefreshUI=function() end;local equipped={};TRD.EquipSet=function(_,name) equipped[#equipped+1]=name;return true end
TRD:CheckMountState(true);TRD.db.enabled=false;M.advance(0.3);eq(#equipped,0,'disabled delayed swap')
TRD.db.enabled=true;TRD.db.pendingGroundSet='Holy';mounted=false;TRD.scripts.OnEvent(TRD,'PLAYER_REGEN_ENABLED');eq(equipped[1],'Holy','queued manual ground set')
print('PASS: gear auto-toggle and queued manual selection')
local combatCleanup,enemyCleanup
for _,ticker in ipairs(M.tickers) do
 for i=1,40 do
  local name,fn=debug.getupvalue(ticker.fn,i)
  if name=='PruneTransientCombatState' then combatCleanup=fn end
  if name=='PruneTrackingCaches' then enemyCleanup=fn end
 end
end
assert(combatCleanup and enemyCleanup)
local oldNow=M.now
GT.recentKillEvents.stale=oldNow-31
GT.recentKillEvents.fresh=oldNow
local historyCount=select(1,TaliaaGankRepository:GetStats())
combatCleanup(oldNow)
eq(GT.recentKillEvents.stale,nil,'stale kill cache removed');eq(GT.recentKillEvents.fresh,oldNow,'fresh dedupe retained')
eq(select(1,TaliaaGankRepository:GetStats()),historyCount,'persistent history retained')
local stale=getEnemy('Player-1-STALE','Stale','MAGE');stale.lastSeen=oldNow-3601
local enemies=M.upvalue(getEnemy,'enemies');enemyCleanup(oldNow)
eq(enemies['Player-1-STALE'],nil,'stale cooldown cache removed')
print('PASS: transient cache expiry preserves dedupe window and permanent history')


-- Custom KOS text uses the Other slot rather than an accidental boolean key.
local locale=setmetatable({},{__index=function(_,key) return key end})
LibStub=function() return {GetLocale=function() return locale end} end
loadModule('List.lua')
SpyPerCharDB.IgnoreData=SpyPerCharDB.IgnoreData or {}
Spy.RefreshCurrentList=function() end
Spy:ToggleKOSPlayer(true,'NewKOS')
eq(SpyPerCharDB.PlayerData.NewKOS.kos,1,'unknown KOS initialized')
local popup={playerName='NewKOS',editBox={GetText=function() return 'Custom reason' end}}
StaticPopupDialogs.Spy_SetKOSReasonOther.OnAccept(popup)
eq(SpyPerCharDB.PlayerData.NewKOS.reason.KOSReasonOther,'Custom reason','custom KOS reason')
Spy:ToggleKOSPlayer(false,'NewKOS')
eq(SpyPerCharDB.PlayerData.NewKOS.kos,nil,'KOS removed')
eq(SpyPerCharDB.PlayerData.NewKOS.reason,nil,'KOS reason removed')
print('PASS: KOS initialization, custom text and removal')

local lib={GetLocale=function() return locale end}
LibStub=setmetatable({GetLibrary=function() return lib end},{__call=function() return lib end})
hooksecurefunc=function() end
loadModule('MainWindow.lua')
Spy.MainWindow=CreateFrame('Frame');Spy.MainWindow.Rows={}
Spy.db.profile.MainWindow={RowHeight=20,RowSpacing=1}
Spy.SetupBar=function() end
local actions=0;Spy.ButtonClicked=function() actions=actions+1 end
Spy:CreateRow(1)
local row=Spy.MainWindow.Rows[1]
row.scripts.PreClick(row,'RightButton',true);eq(actions,0,'press does not open menu')
row.scripts.PreClick(row,'RightButton',false);eq(actions,1,'release opens menu once')
row.scripts.PreClick(row,'LeftButton',true);row.scripts.PreClick(row,'LeftButton',false);eq(actions,2,'modifier action once per click')
print('PASS: row menu/modifier actions execute once per physical click')
print('All regression checks passed; live WoW combat and secure UI validation still required.')

