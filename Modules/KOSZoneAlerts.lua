-- WHO-based KOS zone sightings. Not proximity tracking.
local prefix="VMKOS1"
local f=CreateFrame("Frame")
local alerts,shares={},{}
local db
local banner=CreateFrame("Frame",nil,UIParent)
banner:SetSize(460,65)
banner:SetPoint("TOP",0,-150)
banner:SetFrameStrata("HIGH")
local label=banner:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
label:SetAllPoints()
banner:Hide()
local token=0

local function Init()
    if not SpyDB then return end
    SpyDB.VoidMarkKOSWho=SpyDB.VoidMarkKOSWho or {}
    db=SpyDB.VoidMarkKOSWho
    if db.enabled==nil then db.enabled=true end
    if db.sound==nil then db.sound=true end
    if db.share==nil then db.share=true end
    if db.shareReasons==nil then db.shareReasons=false end
    if db.cooldown==nil then db.cooldown=180 end
end

local function Short(s) return tostring(s or ""):match("^([^%-]+)") or "" end
local function Clean(s,n) return tostring(s or ""):gsub("[%c]"," "):sub(1,n or 80) end

local function FindKOS(name)
    if not SpyPerCharDB or type(SpyPerCharDB.KOSData)~="table" then return nil end
    local target=Short(name):lower()
    if target=="" then return nil end
    for stored,added in pairs(SpyPerCharDB.KOSData) do
        if added and Short(stored):lower()==target then
            return SpyPerCharDB.PlayerData and SpyPerCharDB.PlayerData[stored] or {}
        end
    end
end

local function Reason(data)
    if type(data)~="table" or type(data.reason)~="table" then return "" end
    for why,extra in pairs(data.reason) do
        if extra and extra~=false then
            if type(extra)=="string" and extra~="" then return Clean(extra,80) end
            return Clean(why,80)
        end
    end
    return ""
end

local function Notify(owner,name,level,class,zone,reason)
    if not db or not db.enabled then return end
    local key=owner:lower()..":"..Short(name):lower()..":"..zone:lower()
    local now=GetTime()
    if alerts[key] and now-alerts[key]<(tonumber(db.cooldown) or 180) then return end
    alerts[key]=now
    local who=owner=="You" and "YOUR KOS" or (owner.."'s KOS")
    local msg="|cffff5555[VoidMark KOS]|r "..who..": "..Clean(name,65)
        .." Lv"..tostring(level or "?").." "..Clean(class,24).." in "..Clean(zone,70)
    if reason and reason~="" then msg=msg.." | Reason: "..Clean(reason,80) end
    DEFAULT_CHAT_FRAME:AddMessage(msg)
    token=token+1
    local current=token
    label:SetText("|cffff5555KOS DETECTED|r\n"..who..": "..Clean(name,48))
    banner:Show()
    C_Timer.After(5,function() if token==current then banner:Hide() end end)
    if db.sound and PlaySound then
        pcall(PlaySound,SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,"Master")
    end
end

local function SendMatch(name,level,class,zone,reason)
    if not db.share then return end
    local channel=IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then return end
    local key=Short(name):lower()..":"..zone:lower()
    local now=GetTime()
    if shares[key] and now-shares[key]<(tonumber(db.cooldown) or 180) then return end
    shares[key]=now
    local send=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(send)~="function" then return end
    pcall(send,prefix,table.concat({"K",Clean(name,65),tostring(level or ""),
        Clean(class,24),Clean(zone,70),db.shareReasons and Clean(reason,80) or ""},"\031"),channel)
end

local function ReceiveWho(name,level,class,zone)
    if not db then Init() end
    if not db or not db.enabled then return end
    name=Clean(name,65)
    zone=Clean(zone,70)
    if name=="" or zone=="" then return end
    local data=FindKOS(name)
    if not data then return end
    local reason=Reason(data)
    Notify("You",name,level,class,zone,reason)
    SendMatch(name,level,class,zone,reason)
end
_G.VoidMarkKOS_OnWhoResult=ReceiveWho

local function InOurGroup(sender)
    if not IsInGroup() then return false end
    local name=Short(sender):lower()
    if name==Short(UnitName("player")):lower() then return true end
    local raid=IsInRaid()
    local count=raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i=1,count do
        local member=UnitName((raid and "raid" or "party")..i)
        if member and Short(member):lower()==name then return true end
    end
    return false
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent",function(_,event,p,m,channel,sender)
    if event=="PLAYER_LOGIN" then
        Init()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(prefix)
        end
        return
    end
    if p~=prefix or (channel~="PARTY" and channel~="RAID")
        or type(m)~="string" or not InOurGroup(sender) then return end
    local fields={}
    for part in (m.."\031"):gmatch("(.-)\031") do
        fields[#fields+1]=part
        if #fields==6 then break end
    end
    if fields[1]=="W" then
        ReceiveWho(fields[3],tonumber(fields[4]),fields[5],fields[2])
    elseif fields[1]=="K" and fields[2] and fields[5] then
        -- Don't echo our own party-share message as a second alert.
        if Short(sender):lower()~=Short(UnitName("player")):lower() then
            Notify(Short(sender),fields[2],tonumber(fields[3]),fields[4],fields[5],fields[6])
        end
    end
end)

SLASH_VOIDMARKWHO1="/vmkos"
SlashCmdList.VOIDMARKWHO=function(msg)
    if not db then Init() end
    if not db then return end
    local cmd,value=tostring(msg or ""):lower():match("^(%S+)%s*(%S*)")
    if cmd=="on" or cmd=="off" then db.enabled=cmd=="on"
    elseif cmd=="share" then db.share=value=="on"
    elseif cmd=="reasons" then db.shareReasons=value=="on"
    elseif cmd=="sound" then db.sound=value=="on"
    elseif cmd=="cooldown" then db.cooldown=math.max(30,math.min(1800,tonumber(value) or 180))
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffb56cffVoidMark KOS WHO|r enabled="..tostring(db.enabled)
        .." sharing="..tostring(db.share).." reasons="..tostring(db.shareReasons)
        .." sound="..tostring(db.sound).." cooldown="..tostring(db.cooldown).."s")
end
