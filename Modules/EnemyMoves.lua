-- VoidMark Enemy Moves
-- Native hostile PvP cooldown tracker.
VoidMarkEnemyMoves = VoidMarkEnemyMoves or {}
local EM = VoidMarkEnemyMoves

local VERSION = "1.0.1"
local MAX_ROWS = 8
local ROW_H, ROW_GAP = 20, 2
local HEADER_H, STATUS_H = 40, 22
local FRAME_W = 320

local C = {
    bg={0.018,0.010,0.026,0.97}, edge={0.48,0.16,0.72,0.95},
    purple={0.72,0.36,1,1}, dim={0.62,0.54,0.68,1}, white={0.94,0.94,0.97,1},
    red={0.95,0.20,0.24,1}, orange={1,0.58,0.12,1}, green={0.30,0.95,0.48,1},
    blue={0.26,0.62,1,1}, gray={0.58,0.58,0.62,1},
}

local SPELLS, CANON = {}, {}
local enemies, petOwner = {}, {}
local targetGUID, frame, options, ticker
local testMode, testGUID = false, "VOIDMARK-ENEMYMOVES-TEST"

local function Now() return GetTime() end
local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end
local function SetColor(fs,c) fs:SetTextColor(c[1],c[2],c[3],c[4] or 1) end
local function DB()
    SpyDB = SpyDB or {}
    SpyDB.VoidMarkEnemyMoves = type(SpyDB.VoidMarkEnemyMoves)=="table" and SpyDB.VoidMarkEnemyMoves or {}
    local db=SpyDB.VoidMarkEnemyMoves
    if db.enabled==nil then db.enabled=true end
    if db.scale==nil then db.scale=0.90 end
    if db.bgOpacity==nil then db.bgOpacity=0.90 end
    if db.frameOpacity==nil then db.frameOpacity=1.0 end
    return db
end
local function ShortTime(sec)
    if not sec or sec<=0 then return "0.0" end
    if sec>=60 then return string.format("%d:%02d",math.floor(sec/60),math.floor(sec%60)) end
    if sec<10 then return string.format("%.1f",sec) end
    return tostring(math.ceil(sec))
end

local function AddSpell(ids,key,name,cd,active,category,color,opts)
    opts=opts or {}
    local d={key=key,name=name,cd=cd or 0,active=active or 0,category=category or "utility",
        color=color or "purple",class=opts.class,pet=opts.pet and true or false,
        reset=opts.reset,priority=opts.priority or 50}
    CANON[key]=d
    for _,id in ipairs(ids) do SPELLS[id]=d end
end

-- Rogue
AddSpell({1766},"KICK","Kick",10,0,"control","orange",{class="ROGUE",priority=10})
AddSpell({408,8643},"KIDNEY_SHOT","Kidney Shot",20,0,"control","orange",{class="ROGUE",priority=11})
AddSpell({2094},"BLIND","Blind",210,0,"control","orange",{class="ROGUE",priority=12})
AddSpell({1776,1777,8629,11285,11286},"GOUGE","Gouge",10,0,"control","orange",{class="ROGUE",priority=13})
AddSpell({1856,1857},"VANISH","Vanish",210,0,"mobility","purple",{class="ROGUE",priority=20})
AddSpell({5277},"EVASION","Evasion",210,15,"defensive","red",{class="ROGUE",priority=3})
AddSpell({2983,8696,11305},"SPRINT","Sprint",210,15,"mobility","purple",{class="ROGUE",priority=21})
AddSpell({14185},"PREPARATION","Preparation",600,0,"utility","blue",{class="ROGUE",priority=30,reset={"KICK","KIDNEY_SHOT","GOUGE","VANISH","BLIND","SPRINT","EVASION"}})

-- Mage
AddSpell({2139},"COUNTERSPELL","Counterspell",30,0,"control","orange",{class="MAGE",priority=10})
AddSpell({11958},"ICE_BLOCK","Ice Block",300,10,"defensive","red",{class="MAGE",priority=1})
AddSpell({11426,13031,13032,13033},"ICE_BARRIER","Ice Barrier",30,0,"defensive","red",{class="MAGE",priority=2})
AddSpell({1953},"BLINK","Blink",15,0,"mobility","purple",{class="MAGE",priority=20})
AddSpell({122,865,6131,10230},"FROST_NOVA","Frost Nova",25,0,"control","orange",{class="MAGE",priority=11})
AddSpell({12472},"COLD_SNAP","Cold Snap",600,0,"utility","blue",{class="MAGE",priority=30,reset={"ICE_BLOCK","ICE_BARRIER","FROST_NOVA"}})
AddSpell({12043},"PRESENCE_OF_MIND","Presence of Mind",180,15,"offensive","blue",{class="MAGE",priority=40})
AddSpell({12042},"ARCANE_POWER","Arcane Power",180,15,"offensive","blue",{class="MAGE",priority=41})
AddSpell({11129},"COMBUSTION","Combustion",180,0,"offensive","blue",{class="MAGE",priority=42})

-- Warrior
AddSpell({6552,6554},"PUMMEL","Pummel",10,0,"control","orange",{class="WARRIOR",priority=10})
AddSpell({72,1671,1672},"SHIELD_BASH","Shield Bash",12,0,"control","orange",{class="WARRIOR",priority=11})
AddSpell({20252,20616,20617},"INTERCEPT","Intercept",10,0,"mobility","purple",{class="WARRIOR",priority=20})
AddSpell({5246},"INTIMIDATING_SHOUT","Intimidating Shout",180,0,"control","orange",{class="WARRIOR",priority=12})
AddSpell({18499},"BERSERKER_RAGE","Berserker Rage",30,0,"utility","gray",{class="WARRIOR",priority=31})
AddSpell({676},"DISARM","Disarm",60,0,"control","orange",{class="WARRIOR",priority=13})
AddSpell({20230},"RETALIATION","Retaliation",1800,15,"defensive","red",{class="WARRIOR",priority=2})
AddSpell({1719},"RECKLESSNESS","Recklessness",1800,15,"offensive","blue",{class="WARRIOR",priority=40})
AddSpell({871},"SHIELD_WALL","Shield Wall",1800,10,"defensive","red",{class="WARRIOR",priority=1})

-- Priest
AddSpell({15487},"SILENCE","Silence",45,0,"control","orange",{class="PRIEST",priority=10})
AddSpell({8122,8124,10888,10890},"PSYCHIC_SCREAM","Psychic Scream",26,0,"control","orange",{class="PRIEST",priority=11})
AddSpell({14751},"INNER_FOCUS","Inner Focus",180,0,"offensive","blue",{class="PRIEST",priority=40})
AddSpell({10060},"POWER_INFUSION","Power Infusion",180,15,"offensive","blue",{class="PRIEST",priority=41})

-- Warlock
AddSpell({6789,17925,17926},"DEATH_COIL","Death Coil",120,0,"control","orange",{class="WARLOCK",priority=10})
AddSpell({19244,19647},"SPELL_LOCK","Spell Lock",24,0,"control","orange",{class="WARLOCK",pet=true,priority=11})
AddSpell({6358},"SEDUCTION","Seduction",0,0,"control","orange",{class="WARLOCK",pet=true,priority=12})
AddSpell({6229,11739,11740},"SHADOW_WARD","Shadow Ward",30,30,"defensive","red",{class="WARLOCK",priority=3})
AddSpell({18708},"FEL_DOMINATION","Fel Domination",900,15,"utility","blue",{class="WARLOCK",priority=30})
AddSpell({7812,19438,19440,19441,19442,19443},"SACRIFICE","Sacrifice",30,30,"defensive","red",{class="WARLOCK",pet=true,priority=4})

-- Hunter
AddSpell({19503},"SCATTER_SHOT","Scatter Shot",30,0,"control","orange",{class="HUNTER",priority=10})
AddSpell({19577},"INTIMIDATION","Intimidation",60,0,"control","orange",{class="HUNTER",priority=11})
AddSpell({5384},"FEIGN_DEATH","Feign Death",30,0,"utility","gray",{class="HUNTER",priority=31})
AddSpell({19263},"DETERRENCE","Deterrence",300,10,"defensive","red",{class="HUNTER",priority=2})
AddSpell({19574},"BESTIAL_WRATH","Bestial Wrath",120,18,"offensive","blue",{class="HUNTER",priority=40})
AddSpell({3045},"RAPID_FIRE","Rapid Fire",300,15,"offensive","blue",{class="HUNTER",priority=41})

-- Druid
AddSpell({16979},"FERAL_CHARGE","Feral Charge",15,0,"control","orange",{class="DRUID",priority=10})
AddSpell({5211,6798,8983},"BASH","Bash",60,0,"control","orange",{class="DRUID",priority=11})
AddSpell({17116},"NATURES_SWIFTNESS_DRUID","Nature's Swiftness",180,15,"offensive","blue",{class="DRUID",priority=40})
AddSpell({29166},"INNERVATE","Innervate",360,20,"utility","blue",{class="DRUID",priority=31})
AddSpell({1850,9821},"DASH","Dash",300,15,"mobility","purple",{class="DRUID",priority=20})
AddSpell({22812},"BARKSKIN","Barkskin",60,15,"defensive","red",{class="DRUID",priority=3})

-- Paladin. Track both full bubble and lower-rank Divine Protection variants.
AddSpell({642,1020},"DIVINE_SHIELD","Divine Shield",300,12,"defensive","red",{class="PALADIN",priority=1})
AddSpell({498,5573},"DIVINE_PROTECTION","Divine Protection",300,8,"defensive","red",{class="PALADIN",priority=2})
AddSpell({1022,5599,10278},"BLESSING_PROTECTION","Blessing of Protection",180,10,"defensive","red",{class="PALADIN",priority=3})
AddSpell({853,5588,5589,10308},"HAMMER_JUSTICE","Hammer of Justice",30,0,"control","orange",{class="PALADIN",priority=10})
AddSpell({633,2800,10310},"LAY_ON_HANDS","Lay on Hands",3600,0,"defensive","red",{class="PALADIN",priority=4})
AddSpell({20216},"DIVINE_FAVOR","Divine Favor",120,20,"offensive","blue",{class="PALADIN",priority=40})

-- Shaman
AddSpell({8042,8044,8045,8046,10412,10413,10414},"EARTH_SHOCK","Earth Shock",6,0,"control","orange",{class="SHAMAN",priority=10})
AddSpell({16188},"NATURES_SWIFTNESS_SHAMAN","Nature's Swiftness",180,15,"offensive","blue",{class="SHAMAN",priority=40})
AddSpell({16166},"ELEMENTAL_MASTERY","Elemental Mastery",180,30,"offensive","blue",{class="SHAMAN",priority=41})
AddSpell({16190},"MANA_TIDE_TOTEM","Mana Tide Totem",300,12,"utility","blue",{class="SHAMAN",priority=31})
AddSpell({8177},"GROUNDING_TOTEM","Grounding Totem",15,45,"utility","gray",{class="SHAMAN",priority=32})

-- Engineering / items
AddSpell({23132},"SHADOW_REFLECTOR","Shadow Reflector",300,5,"defensive","red",{priority=4})

local TRINKET_NAMES={["Insignia of the Alliance"]=true,["Insignia of the Horde"]=true,["PvP Trinket"]=true}
local POTION_EFFECT_NAMES={
    -- PvP / control
    ["Free Action"]=true,
    ["Living Free Action"]=true,
    ["Invulnerability"]=true,
    ["Speed"]=true,
    ["Invisibility"]=true,
    ["Restoration"]=true,
    ["Restorative Potion"]=true,

    -- Defensive / resistance
    ["Greater Stoneshield"]=true,
    ["Stoneshield"]=true,
    ["Magic Resistance"]=true,
    ["Frost Protection"]=true,
    ["Fire Protection"]=true,
    ["Shadow Protection"]=true,
    ["Nature Protection"]=true,
    ["Arcane Protection"]=true,

    -- Rage / offensive potion effects
    ["Mighty Rage"]=true,
    ["Great Rage"]=true,
    ["Rage"]=true,
}

-- Known Classic item-effect spell IDs whose visible combat-log name does not
-- necessarily contain the word "Potion". These all consume the normal potion
-- cooldown when produced by the corresponding potion item.
local POTION_EFFECT_IDS={
    [6615]=true,  -- Free Action
    [24364]=true, -- Living Free Action
    [3169]=true,  -- Limited Invulnerability
    [2379]=true,  -- Swiftness / Speed
    [17540]=true, -- Greater Stoneshield

    -- Mana potion item effects (combat log name is usually "Restore Mana")
    [437]=true,   -- Lesser Mana Potion
    [438]=true,   -- Mana Potion
    [2023]=true,  -- Greater Mana Potion
    [17530]=true, -- Superior Mana Potion
    [17531]=true, -- Major Mana Potion
    [21395]=true, -- Major Combat Mana Potion / BG variant

    -- Healing potion item effects
    [439]=true,   -- Minor Healing Potion
    [440]=true,   -- Lesser Healing Potion
    [2024]=true,  -- Greater Healing Potion
    [4042]=true,  -- Superior Healing Potion
    [17534]=true, -- Major Healing Potion

    -- Protection potion absorb effects
    [7237]=true,[7239]=true,[17544]=true, -- Frost
    [7230]=true,[17543]=true,             -- Fire
    [7241]=true,[7242]=true,[17548]=true, -- Shadow
    [7254]=true,[17546]=true,             -- Nature
    [17549]=true,                         -- Arcane
}

local POTION_DEF={key="POTION",name="Potion",cd=120,active=0,category="utility",color="gray",priority=24}
CANON.POTION=POTION_DEF

local POTION_EVENTS={
    SPELL_CAST_SUCCESS=true,
    SPELL_AURA_APPLIED=true,
    SPELL_AURA_REFRESH=true,
    SPELL_HEAL=true,
    SPELL_ENERGIZE=true,
}

local function IsPotionUse(spellID,spellName,subevent)
    if not POTION_EVENTS[subevent] then return false end

    if POTION_EFFECT_IDS[spellID] then
        return true
    end

    if type(spellName)~="string" or spellName=="" then return false end
    if spellName:lower():find("potion",1,true) then
        return true
    end

    return POTION_EFFECT_NAMES[spellName] and true or false
end

local function GetEnemy(guid,name,class)
    if not guid then return nil end
    local e=enemies[guid]
    if not e then e={guid=guid,name=name or "Unknown",class=class,spells={},seen={}} enemies[guid]=e end
    if name and name~="" then e.name=name end
    if class and class~="" then e.class=class end
    return e
end
local function ClassFromGUID(guid)
    if not guid or not GetPlayerInfoByGUID then return nil end
    local _,class=GetPlayerInfoByGUID(guid)
    return class
end
local function LearnTargetPet()
    if UnitExists("target") and UnitIsPlayer("target") then
        local owner=UnitGUID("target")
        if owner and UnitExists("targetpet") then
            local pet=UnitGUID("targetpet")
            if pet then petOwner[pet]=owner end
        end
    end
end
local function StartCooldown(e,def,spellID)
    if not e or not def then return end
    local now=Now()
    local s=e.spells[def.key] or {}
    e.spells[def.key]=s
    s.key,s.name,s.usedAt=def.key,def.name,now
    s.cooldownEnd=now+(def.cd or 0)
    s.activeEnd=(def.active and def.active>0) and (now+def.active) or nil
    s.lastSpellID=spellID or s.lastSpellID
    e.seen[def.key]=true
end
local function ApplyReset(e,def)
    if not e or not def or not def.reset then return end
    for _,key in ipairs(def.reset) do
        local s=e.spells[key]
        if s then s.cooldownEnd=Now() s.activeEnd=nil end
    end
end
local function TrackSpell(ownerGUID,ownerName,ownerClass,spellID,spellName,event)
    local def=SPELLS[spellID]
    if not def and spellName and TRINKET_NAMES[spellName] then
        def={key="PVP_TRINKET",name="PvP Trinket",cd=300,active=0,category="utility",color="gray",priority=25}
    elseif IsPotionUse(spellID,spellName,event) then
        def=POTION_DEF
    end
    if not def then return false end
    local e=GetEnemy(ownerGUID,ownerName,ownerClass or def.class)
    if not e then return false end
    if def.reset and event=="SPELL_CAST_SUCCESS" then
        StartCooldown(e,def,spellID) ApplyReset(e,def) return true
    end
    -- Any recognized potion-use event consumes the shared potion slot.
    -- Mana/healing potions commonly appear as SPELL_ENERGIZE/SPELL_HEAL,
    -- while protection/FAP/LIP-style pots often appear as aura applications.
    if def.key=="POTION" and POTION_EVENTS[event] then
        StartCooldown(e,def,spellID)
        return true
    end
    if event=="SPELL_CAST_SUCCESS" then
        StartCooldown(e,def,spellID)
    elseif event=="SPELL_AURA_APPLIED" or event=="SPELL_AURA_REFRESH" then
        local s=e.spells[def.key]
        if not s then StartCooldown(e,def,spellID) s=e.spells[def.key] end
        if def.active and def.active>0 then s.activeEnd=Now()+def.active end
    elseif event=="SPELL_AURA_REMOVED" then
        local s=e.spells[def.key]
        if s then s.activeEnd=nil end
    end
    return true
end

local function ResizeForRows(n)
    if not frame then return end
    n=math.max(0,math.min(MAX_ROWS,tonumber(n) or 0))
    local rowBlock=n>0 and (n*ROW_H+math.max(0,n-1)*ROW_GAP+5) or 0
    frame:SetHeight(HEADER_H+STATUS_H+rowBlock+8)
end
local function ApplyAppearance()
    if not frame then return end
    local db=DB()
    frame:SetScale(Clamp(db.scale,0.50,1.50))
    frame:SetAlpha(Clamp(db.frameOpacity,0.35,1.0))
    frame:SetBackdropColor(C.bg[1],C.bg[2],C.bg[3],Clamp(db.bgOpacity,0.15,1.0))
end
local function SavePosition()
    local db=DB()
    local p,_,rp,x,y=frame:GetPoint(1)
    db.point,db.relPoint,db.x,db.y=p,rp,x,y
end
local function RestorePosition()
    if not frame then return end
    local db=DB()
    frame:ClearAllPoints()
    if db.point then frame:SetPoint(db.point,UIParent,db.relPoint or db.point,db.x or 0,db.y or 0)
    else frame:SetPoint("CENTER",UIParent,"CENTER",250,20) end
    ApplyAppearance()
end

local function BuildUI()
    if frame then return end
    frame=CreateFrame("Frame","VoidMarkEnemyMovesFrame",UIParent,"BackdropTemplate")
    frame:SetSize(FRAME_W,HEADER_H+STATUS_H+12)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
    frame:SetBackdropBorderColor(unpack(C.edge))
    frame:SetScript("OnDragStart",function(self) if not DB().locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() SavePosition() end)

    frame.Title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT",10,-7) frame.Title:SetText("ENEMY MOVES") SetColor(frame.Title,C.purple)
    frame.Version=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.Version:SetPoint("TOPRIGHT",-45,-8) frame.Version:SetText("v"..VERSION) SetColor(frame.Version,C.dim)

    frame.OptionsButton=CreateFrame("Button",nil,frame,"BackdropTemplate")
    frame.OptionsButton:SetSize(34,17) frame.OptionsButton:SetPoint("TOPRIGHT",-6,-5)
    frame.OptionsButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=6})
    frame.OptionsButton:SetBackdropColor(0.05,0.025,0.075,0.96) frame.OptionsButton:SetBackdropBorderColor(0.40,0.13,0.60,0.95)
    frame.OptionsButton.Text=frame.OptionsButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.OptionsButton.Text:SetAllPoints() frame.OptionsButton.Text:SetText("OPT") SetColor(frame.OptionsButton.Text,C.purple)

    frame.Target=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    frame.Target:SetPoint("TOPLEFT",frame.Title,"BOTTOMLEFT",0,-2) frame.Target:SetPoint("RIGHT",frame,"RIGHT",-8,0)
    frame.Target:SetJustifyH("LEFT") frame.Target:SetText("No hostile player targeted") SetColor(frame.Target,C.white)

    frame.StatusBG=frame:CreateTexture(nil,"ARTWORK")
    frame.StatusBG:SetPoint("TOPLEFT",6,-HEADER_H) frame.StatusBG:SetPoint("TOPRIGHT",-6,-HEADER_H)
    frame.StatusBG:SetHeight(STATUS_H) frame.StatusBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.StatusBG:SetVertexColor(0.12,0.04,0.16,0.9)
    frame.Status=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    frame.Status:SetPoint("CENTER",frame.StatusBG,"CENTER") frame.Status:SetText("WAITING") SetColor(frame.Status,C.dim)

    frame.Rows={}
    local rowsTop=HEADER_H+STATUS_H+5
    for i=1,MAX_ROWS do
        local row=CreateFrame("StatusBar",nil,frame)
        frame.Rows[i]=row
        row:SetPoint("TOPLEFT",7,-(rowsTop+(i-1)*(ROW_H+ROW_GAP))) row:SetPoint("TOPRIGHT",-7,-(rowsTop+(i-1)*(ROW_H+ROW_GAP)))
        row:SetHeight(ROW_H) row:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar") row:SetMinMaxValues(0,1)
        row.BG=row:CreateTexture(nil,"BACKGROUND") row.BG:SetAllPoints() row.BG:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.BG:SetVertexColor(0.035,0.025,0.045,0.94)
        row.Icon=row:CreateTexture(nil,"ARTWORK") row.Icon:SetSize(16,16) row.Icon:SetPoint("LEFT",2,0)
        row.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.Label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.Label:SetPoint("LEFT",row.Icon,"RIGHT",4,0) row.Label:SetPoint("RIGHT",row,"RIGHT",-54,0) row.Label:SetJustifyH("LEFT")
        row.Time=row:CreateFontString(nil,"OVERLAY","GameFontNormal") row.Time:SetPoint("RIGHT",-4,0) row.Time:SetWidth(46) row.Time:SetJustifyH("RIGHT")
        row:Hide()
    end

    frame.OptionsButton:SetScript("OnClick",function()
        EM:ToggleOptions()
    end)

    RestorePosition()
    frame:Hide()
end

local function CurrentEnemy()
    if testMode then return enemies[testGUID] end
    return targetGUID and enemies[targetGUID] or nil
end
local function Remaining(s,def,now)
    -- Enemy Moves answers "when can they use it again?".
    -- Keep ACTIVE as a separate state marker, but always display the recast
    -- cooldown rather than replacing it with the remaining buff duration.
    local active=s.activeEnd and s.activeEnd>now
    local cooldownRemain=math.max(0,(s.cooldownEnd or 0)-now)
    return cooldownRemain,active
end
local function BuildRows(e,now)
    local list={}
    if e then
        for key,s in pairs(e.spells or {}) do
            local def=CANON[key]
            if not def and key=="PVP_TRINKET" then def={key=key,name="PvP Trinket",cd=300,active=0,category="utility",color="gray",priority=25} end
            if def then
                local remain,active=Remaining(s,def,now)
                if remain>0 then list[#list+1]={state=s,def=def,remain=remain,active=active} end
            end
        end
    end
    table.sort(list,function(a,b)
        if a.active~=b.active then return a.active end
        if (a.def.priority or 50)~=(b.def.priority or 50) then return (a.def.priority or 50)<(b.def.priority or 50) end
        return a.remain<b.remain
    end)
    return list
end
local function ColorFor(def,active)
    if active and def.category=="defensive" then return C.red end
    return C[def.color] or C.purple
end
local function UpdateTarget()
    if testMode then return end
    targetGUID=nil
    if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player","target") then
        targetGUID=UnitGUID("target")
        local name,realm=UnitName("target")
        if realm and realm~="" then name=name.."-"..realm end
        local _,class=UnitClass("target")
        GetEnemy(targetGUID,name,class)
        LearnTargetPet()
    end
end

function EM:Refresh()
    BuildUI()
    local db=DB()
    if not db.enabled then frame:Hide() return end
    local e=CurrentEnemy()
    if not e then frame:Hide() return end

    local cc=RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    if cc then frame.Target:SetText(string.format("%s  •  |cff%02x%02x%02x%s|r",e.name or "Unknown",cc.r*255,cc.g*255,cc.b*255,e.class or ""))
    else frame.Target:SetText((e.name or "Unknown").."  •  "..tostring(e.class or "")) end

    local list=BuildRows(e,Now())
    if #list==0 then
        frame.Status:SetText("ALL TRACKED MOVES READY") SetColor(frame.Status,C.green) frame.StatusBG:SetVertexColor(0.03,0.20,0.08,0.95)
    elseif list[1].active then
        frame.Status:SetText("ACTIVE: "..list[1].def.name)
        local c=list[1].def.category=="defensive" and C.red or C.orange
        SetColor(frame.Status,c) frame.StatusBG:SetVertexColor(c[1]*0.25,c[2]*0.25,c[3]*0.25,0.95)
    else
        frame.Status:SetText(string.format("TRACKING %d COOLDOWN%s",#list,#list==1 and "" or "S"))
        SetColor(frame.Status,C.purple) frame.StatusBG:SetVertexColor(0.12,0.04,0.16,0.92)
    end

    ResizeForRows(math.min(#list,MAX_ROWS))
    for i,row in ipairs(frame.Rows) do
        local item=list[i]
        if item then
            local def,s=item.def,item.state
            local c=ColorFor(def,item.active)
            local total=item.active and math.max(def.active or 1,1) or math.max(def.cd or 1,1)
            row:SetMinMaxValues(0,total) row:SetValue(math.min(total,item.remain)) row:SetStatusBarColor(c[1],c[2],c[3],0.72)
            if s.lastSpellID and GetSpellTexture then
                local tex=GetSpellTexture(s.lastSpellID)
                if tex then row.Icon:SetTexture(tex) else row.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
            elseif def.key=="POTION" then row.Icon:SetTexture("Interface\\Icons\\INV_Potion_54")
            else row.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
            row.Label:SetText(def.name..(item.active and " |cffff4d5dACTIVE|r" or ""))
            row.Time:SetText(ShortTime(item.remain)) SetColor(row.Time,item.active and C.red or c)
            row:Show()
        else row:Hide() end
    end
    frame:Show()
end

local function EnsureOptions()
    if options then return options end
    options=CreateFrame("Frame","VoidMarkEnemyMovesOptions",UIParent,"BackdropTemplate")
    options:SetSize(270,205) options:SetPoint("CENTER") options:SetFrameStrata("DIALOG") options:SetMovable(true) options:EnableMouse(true)
    options:RegisterForDrag("LeftButton") options:SetScript("OnDragStart",options.StartMoving) options:SetScript("OnDragStop",options.StopMovingOrSizing)
    options:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
    options:SetBackdropColor(0.018,0.010,0.026,0.98) options:SetBackdropBorderColor(0.48,0.16,0.72,0.95)
    local title=options:CreateFontString(nil,"OVERLAY","GameFontNormalLarge") title:SetPoint("TOPLEFT",10,-9) title:SetText("ENEMY MOVES OPTIONS") SetColor(title,C.purple)
    local close=CreateFrame("Button",nil,options,"UIPanelCloseButton") close:SetPoint("TOPRIGHT",-3,-3)

    local enabled=CreateFrame("CheckButton",nil,options,"UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT",12,-42) enabled.Text=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    enabled.Text:SetPoint("LEFT",enabled,"RIGHT",3,0) enabled.Text:SetText("Enable Enemy Moves")
    enabled:SetScript("OnClick",function(self) DB().enabled=self:GetChecked() and true or false EM:Refresh() end)
    options.Enabled=enabled

    local lock=CreateFrame("CheckButton",nil,options,"UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT",12,-69) lock.Text=options:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    lock.Text:SetPoint("LEFT",lock,"RIGHT",3,0) lock.Text:SetText("Lock position")
    lock:SetScript("OnClick",function(self) DB().locked=self:GetChecked() and true or false end)
    options.Lock=lock

    local function Slider(name,label,minv,maxv,step,y,onchange)
        local s=CreateFrame("Slider",name,options,"OptionsSliderTemplate")
        s:SetPoint("TOPLEFT",22,y) s:SetWidth(220) s:SetMinMaxValues(minv,maxv) s:SetValueStep(step) s:SetObeyStepOnDrag(true)
        local fs=_G[name.."Text"]
        if fs then fs:SetText(label) end
        s:SetScript("OnValueChanged",onchange)
        return s
    end
    options.Scale=Slider("VoidMarkEnemyMovesScale","Scale",0.50,1.50,0.05,-105,function(_,v) DB().scale=v ApplyAppearance() end)
    options.Opacity=Slider("VoidMarkEnemyMovesOpacity","Overall opacity",0.35,1.0,0.05,-150,function(_,v) DB().frameOpacity=v ApplyAppearance() end)
    options:SetScript("OnShow",function()
        local db=DB()
        options.Enabled:SetChecked(db.enabled) options.Lock:SetChecked(db.locked)
        options.Scale:SetValue(db.scale) options.Opacity:SetValue(db.frameOpacity)
    end)
    options:Hide()
    return options
end

function EM:Toggle()
    BuildUI()
    local db=DB()
    if frame:IsShown() then
        db.enabled=false
        frame:Hide()
    else
        db.enabled=true
        UpdateTarget()
        EM:Refresh()
    end
end
function EM:ToggleOptions()
    local f=EnsureOptions()
    if f:IsShown() then f:Hide() else f:Show() end
end
function EM:SetEnabled(v) DB().enabled=v and true or false EM:Refresh() end

local function IsHostilePlayer(flags)
    if not flags or not bit or not bit.band then return false end
    return bit.band(flags,COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400)~=0
       and bit.band(flags,COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040)~=0
end

local eventFrame=CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_TARGET_CHANGED" then testMode=false UpdateTarget() EM:Refresh() return end
    if event=="PLAYER_ENTERING_WORLD" then BuildUI() UpdateTarget() EM:Refresh() return end

    local _,subevent,_,sourceGUID,sourceName,sourceFlags,_,destGUID,destName,_,_,spellID,spellName=CombatLogGetCurrentEventInfo()
    if subevent~="SPELL_CAST_SUCCESS"
        and subevent~="SPELL_AURA_APPLIED"
        and subevent~="SPELL_AURA_REFRESH"
        and subevent~="SPELL_AURA_REMOVED"
        and subevent~="SPELL_HEAL"
        and subevent~="SPELL_ENERGIZE" then
        return
    end
    if not sourceGUID then return end

    local ownerGUID,ownerName,ownerClass
    if IsHostilePlayer(sourceFlags) then
        ownerGUID,ownerName,ownerClass=sourceGUID,sourceName,ClassFromGUID(sourceGUID)
    elseif petOwner[sourceGUID] then
        ownerGUID=petOwner[sourceGUID]
        local e=enemies[ownerGUID]
        ownerName=e and e.name
        ownerClass=e and e.class
    elseif targetGUID and sourceGUID==targetGUID then
        ownerGUID=sourceGUID
        local n,r=UnitName("target")
        if n and r and r~="" then n=n.."-"..r end
        ownerName=n or sourceName
        ownerClass=select(2,UnitClass("target")) or ClassFromGUID(sourceGUID)
    else
        return
    end

    local def=SPELLS[spellID]
    if def and def.pet and not petOwner[sourceGUID] and not IsHostilePlayer(sourceFlags) then return end
    local tracked=TrackSpell(ownerGUID,ownerName,ownerClass,spellID,spellName,subevent)
    if DB().debug and tracked then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffb45cff[EnemyMoves]|r %s used %s (%s)",ownerName or "?",spellName or "?",tostring(spellID)))
    elseif DB().debug and IsHostilePlayer(sourceFlags)
        and (subevent=="SPELL_HEAL" or subevent=="SPELL_ENERGIZE")
        and sourceGUID==destGUID then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffb45cff[EnemyMoves RAW]|r %s %s (%s)",subevent,spellName or "?",tostring(spellID)))
    end
    if ownerGUID==targetGUID or testMode then EM:Refresh() end
end)

ticker=C_Timer.NewTicker(0.10,function()
    if frame and frame:IsShown() then EM:Refresh() end
    LearnTargetPet()
end)

local function TestStart()
    BuildUI()
    testMode=true
    local e=GetEnemy(testGUID,"Cartach","ROGUE")
    e.spells={}
    e.seen={}
    local function fake(key,remain,id)
        local d=CANON[key]
        local s={key=key,name=d.name,usedAt=Now()-2,cooldownEnd=Now()+remain,lastSpellID=id}
        e.spells[key]=s
        e.seen[key]=true
    end
    fake("BLIND",282,2094)
    fake("VANISH",197,1856)
    fake("KIDNEY_SHOT",14,408)
    fake("KICK",7.2,1766)
    fake("EVASION",171,5277)
    fake("SPRINT",46,2983)
    fake("POTION",83,nil)
    EM:Refresh()
end

SLASH_VOIDMARKENEMYMOVES1="/emoves"
SLASH_VOIDMARKENEMYMOVES2="/enemymoves"
SlashCmdList.VOIDMARKENEMYMOVES=function(msg)
    msg=string.lower(strtrim(msg or ""))
    if msg=="test" then TestStart()
    elseif msg=="options" or msg=="opt" then EM:ToggleOptions()
    elseif msg=="show" then
        DB().enabled=true
        UpdateTarget()
        EM:Refresh()
    elseif msg=="hide" then
        DB().enabled=false
        if frame then frame:Hide() end
    elseif msg=="lock" then DB().locked=true
    elseif msg=="unlock" then DB().locked=false
    elseif msg=="debug" then
        DB().debug=not DB().debug
        DEFAULT_CHAT_FRAME:AddMessage("|cffb45cff[EnemyMoves]|r debug "..(DB().debug and "ON" or "OFF"))
    elseif msg=="reset" then
        local db=DB()
        db.point=nil
        db.relPoint=nil
        db.x=nil
        db.y=nil
        if frame then RestorePosition() frame:Show() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffb45cffEnemy Moves|r: /emoves test | show | hide | options | lock | unlock | debug | reset")
    end
end
