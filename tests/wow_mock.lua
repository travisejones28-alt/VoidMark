-- Minimal WoW API harness. Rendering and secure execution require the game client.
local M={now=100,epoch=1791010800,frames={},timers={},tickers={},messages={},sounds=0,units={},combat=false}
local noop=function() end
local methods={}
local function frame(name)
 local f=setmetatable({scripts={},events={},shown=true,name=name},{__index=methods})
 M.frames[#M.frames+1]=f;if name then _G[name]=f end;return f
end
setmetatable(methods,{__index=function(_,key)
 if key:match('^Set') or key:match('^Register') or key:match('^Enable') or key:match('^Disable') or key:match('^Clear') or key:match('^Start') or key:match('^Stop') then return noop end
end})
function methods:SetScript(key,fn) self.scripts[key]=fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:HookScript(key,fn) local old=self.scripts[key];self.scripts[key]=function(...) if old then old(...) end;fn(...) end end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:UnregisterEvent(event) self.events[event]=nil end
function methods:CreateTexture() return frame() end
methods.CreateFontString=methods.CreateTexture
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text or '' end
function methods:GetWidth() return 300 end
function methods:GetHeight() return 250 end
function methods:GetLeft() return 0 end
function methods:GetRight() return 300 end
function methods:GetTop() return 250 end
function methods:GetBottom() return 0 end
function methods:GetPoint() return 'CENTER',UIParent,'CENTER',0,0 end
function methods:GetCenter() return 150,125 end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetStringWidth() return #(self.text or '')*6 end
function methods:GetFont() return 'font',12,'' end
function methods:GetAlpha() return 1 end
function methods:SetEnabled(value) self.enabled=value end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:GetRegions() return end
CreateFrame=function(_,name) return frame(name) end
UIParent=frame();Minimap=frame();GameTooltip=frame();UIErrorsFrame=frame()
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) M.messages[#M.messages+1]=msg end}
C_Timer={After=function(delay,fn) M.timers[#M.timers+1]={at=M.now+delay,fn=fn} end,
 NewTicker=function(delay,fn) local t={delay=delay,fn=fn,Cancel=function(self) self.cancelled=true end};M.tickers[#M.tickers+1]=t;return t end}
GetTime=function() return M.now end
GetServerTime=function() return M.epoch end
time=function(t) return t and os.time(t) or M.epoch end;date=os.date
UnitName=function(unit) local u=M.units[unit];return u and u.name,u and u.realm end
UnitFullName=UnitName
UnitGUID=function(unit) local u=M.units[unit];return u and u.guid end
UnitExists=function(unit) return M.units[unit]~=nil end
UnitIsPlayer=function(unit) local g=UnitGUID(unit);return g and g:sub(1,7)=='Player-' or false end
UnitIsUnit=function(a,b) return UnitGUID(a)~=nil and UnitGUID(a)==UnitGUID(b) end
UnitIsFeignDeath=function(unit) local u=M.units[unit];return u and u.feign==true or false end
UnitClass=function(unit) local u=M.units[unit];return u and u.class,u and u.class end
UnitRace=function() return 'Human','Human' end
UnitFactionGroup=function(unit) local u=M.units[unit];return u and u.faction or 'Horde' end
UnitLevel=function() return 60 end
UnitIsDeadOrGhost=function() return false end;UnitOnTaxi=function() return false end
UnitCreatureType=function() return 'Beast' end
UnitCanAttack=function() return true end
IsInGroup=function() return true end;IsInRaid=function() return false end
GetNumGroupMembers=function() return 2 end;GetNumSubgroupMembers=function() return 1 end
GetRealmName=function() return 'Whitemane' end
GetZoneText=function() return 'Redridge Mountains' end;GetRealZoneText=GetZoneText
GetSubZoneText=function() return 'Lakeshire' end
InCombatLockdown=function() return M.combat end
IsInInstance=function() return false,'none' end
GetPlayerInfoByGUID=function(guid) for _,u in pairs(M.units) do if u.guid==guid then return u.class,u.class end end end
GetGameTime=function() return 2,0 end
GetPVPSessionStats=function() return 0,0 end
GetPVPYesterdayStats=GetPVPSessionStats;GetPVPThisWeekStats=GetPVPSessionStats;GetPVPLastWeekStats=GetPVPSessionStats
GetPVPLifetimeStats=GetPVPSessionStats
PlaySound=function() M.sounds=M.sounds+1 end
PlaySoundFile=function() M.sounds=M.sounds+1;return true,M.sounds end
SendChatMessage=function(msg,channel) M.messages[#M.messages+1]=channel..':'..msg end
C_ChatInfo={RegisterAddonMessagePrefix=noop,SendAddonMessage=noop}
C_Map={GetBestMapForUnit=function() return 49 end}
SlashCmdList={};StaticPopupDialogs={};RAID_CLASS_COLORS={};SOUNDKIT={RAID_WARNING=1}
local function bitop(a,b,isOr)
 local result,place=0,1
 while a>0 or b>0 do
  local x,y=a%2,b%2
  if (isOr and (x==1 or y==1)) or (not isOr and x==1 and y==1) then result=result+place end
  a=math.floor(a/2);b=math.floor(b/2);place=place*2
 end
 return result
end
bit={band=function(a,b) return bitop(a,b,false) end,bor=function(a,b) return bitop(a,b,true) end}
M.units.player={name='Taliaa',realm='Whitemane',guid='Player-1-SELF',class='PRIEST',faction='Horde'}
function M.emit(event,...)
 for _,f in ipairs(M.frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
function M.advance(delta)
 M.now=M.now+delta;M.epoch=M.epoch+delta
 local work=M.timers;M.timers={}
 for _,timer in ipairs(work) do if timer.at<=M.now then timer.fn() else M.timers[#M.timers+1]=timer end end
end
function M.upvalue(fn,name)
 for i=1,100 do local key,value=debug.getupvalue(fn,i);if not key then break end;if key==name then return value end end
 error('Missing upvalue '..name)
end
function M.load(path,namespace) return assert(loadfile(path))('VoidMark',namespace or {}) end
return M
