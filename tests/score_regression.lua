-- Run from repository root: luatex --luaonly tests/score_regression.lua
local M = dofile('tests/wow_mock.lua')
local function eq(a, b, label)
    assert(a == b, label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a))
end

SpyDB = {}
SpyPerCharDB = { PlayerData = {}, KOSData = {} }
Spy = { db = { profile = {} }, NearbyList = {}, ActiveList = {},
    RealmName = 'Whitemane', FactionName = 'Horde', CharacterName = 'Taliaa' }
M.load('GankRepository.lua')
M.load('GankTracker.lua')
M.load('VoidMarkUI.lua')
local Repo, GT = TaliaaGankRepository, TaliaaGankTracker
local history = SpyDB.TaliaaGankGlobal.Whitemane.GankHistory
local guid = 'Player-1-SCORED'

for i = 1, 6 do
    M.epoch = M.epoch + 10
    Repo:RecordKill('Scored', guid, {})
end
SpyPerCharDB.PlayerData.Scored = { wins = 2, loses = 1, class = 'PRIEST', level = 60 }
Spy.MainWindow = CreateFrame('Frame')
local row = CreateFrame('Button')
row.StatusBar = CreateFrame('StatusBar')
row.LeftText, row.RightText = row:CreateFontString(), row:CreateFontString()
Spy.MainWindow.Rows = { row }

Spy.VoidMark:StyleRow(1, 'Scored', '', 1)
eq(row.VoidMarkRecordText:GetText(), '|cffb9a3c96-1|r', 'detected row uses all six previous kills')
eq(SpyPerCharDB.PlayerData.Scored.guid, nil, 'read does not assign an unobserved GUID')
eq(SpyPerCharDB.PlayerData.Scored.wins, 2, 'read leaves legacy presentation cache untouched')
local eventsBefore = history.eventCount

M.combat = true
M.now, M.epoch = M.now + 10, M.epoch + 10
GT:RecordKill('Scored', guid, false)
Spy.VoidMark:StyleRow(1, 'Scored', '', 1)
eq(row.VoidMarkRecordText:GetText(), '|cffb9a3c97-1|r', 'one real kill advances row to seven')
eq(history.eventCount, eventsBefore + 1, 'one real kill adds one event')
local streak = GT.currentStreak
GT:RecordKill('Scored', guid, false)
eq(history.eventCount, eventsBefore + 1, 'duplicate combat events leave history unchanged')
eq(GT.currentStreak, streak, 'duplicate combat events leave streak unchanged')
print('PASS: stale 2-1 row reconciles before kill, then advances once to 7-1')

local function addKills(name, victimGUID, count)
    for _ = 1, count do
        M.now, M.epoch = M.now + 10, M.epoch + 10
        Repo:RecordKill(name, victimGUID, {})
    end
end
M.combat = false
addKills('Realmplayer-Whitemane', 'Player-1-REALM', 3)
eq(Repo:GetHistoricalStats('Realmplayer'), 3, 'bare sighting resolves qualified ledger name')
eq(Repo:GetHistoricalStats('REALMPLAYER-Whitemane'), 3, 'case variant resolves history')
eq(Repo:GetHistoricalStats('Realmplayer-OtherRealm'), 0, 'qualified identity cannot borrow another realm')
addKills('Twin-Whitemane', 'Player-1-TWIN1', 1)
addKills('Twin-Thunderfury', 'Player-1-TWIN2', 2)
eq(Repo:GetHistoricalStats('Twin'), 0, 'ambiguous bare name cannot borrow either GUID')
eq(Repo:GetHistoricalStats('Twin-Whitemane'), 1, 'first qualified twin')
eq(Repo:GetHistoricalStats('Twin-Thunderfury'), 2, 'second qualified twin')
eq(Repo:GetHistoricalStats('Twin', 'Player-1-TWIN2'), 2, 'observed GUID resolves ambiguity')
addKills('Accénted', 'Player-1-ACCENT', 2)
eq(Repo:GetHistoricalStats('ACCÉNTED'), 2, 'accent-preserving case lookup')
eq(Repo:GetHistoricalStats('Accented'), 2, 'unique recovered accent alias')
addKills('Accented', 'Player-1-ASCII', 1)
eq(Repo:GetHistoricalStats('Accented'), 1, 'exact name takes priority over folded alias')
eq(Repo:GetHistoricalStats('Accènted'), 0, 'ambiguous accent fold cannot combine players')
print('PASS: realm, case, GUID and conservative accent identity matching')

-- Imported lifetime totals can exceed their timestamped event rows. Both the
-- initial sighting and the next kill must include those older missing kills.
local archiveGUID = 'Player-1-ARCHIVE'
addKills('Archivéd-Whitemane', archiveGUID, 3)
SpyDB.VoidMarkLegacyPlayers = { ['Archivéd-Whitemane'] = { wins = 6, loses = 1 } }
SpyPerCharDB.PlayerData.Archived = { wins = 2, loses = 1 }
eq(Repo:GetHistoricalStats('Archived'), 6, 'sighting includes archived lifetime total')
M.combat = true
M.now, M.epoch = M.now + 10, M.epoch + 10
local total, added = Repo:RecordKill('Archivéd-Whitemane', archiveGUID, {})
eq(added, true, 'new archived victim death')
eq(total, 7, 'kill includes old archived kills before increment')
eq(Repo:GetHistoricalStats('Archived'), 7, 'sighting immediately sees archived total plus new kill')
M.combat = false
eq(Repo:GetHistoricalCount('Archivéd-Whitemane', archiveGUID), 7, 'deep recovery agrees with immediate score')
eq(Repo:GetHistoricalStats('Archived'), 7, 'score remains stable after recovery')
print('PASS: archived lifetime gaps remain stable through kill and recovery')

-- A name-only import and its GUID row are separate timestamped contributions,
-- while old lifetime floors are missing kills rather than another full total.
addKills('Split', nil, 2)
addKills('Split', 'Player-1-SPLIT', 2)
eq(Repo:GetHistoricalStats('Split'), 4, 'name-to-GUID migration retains older events once')
local mergeGap = M.upvalue(M.upvalue(Repo.GetHistoricalCount, 'HistoricalCountWithFloor'), 'MergeLegacyGap')
mergeGap(history, 'Split', 'Player-1-SPLIT', 3, true)
eq(Repo:GetHistoricalStats('Split'), 7, 'GUID-bound gap is visible before next encounter')
mergeGap(history, 'FloorOnly-Whitemane', 'Player-1-FLOOR', 5, true)
eq(Repo:GetHistoricalStats('FloorOnly'), 5, 'floor-only imported identity resolves without a kill')
Repo:RebuildIndexes()
eq(Repo:GetHistoricalStats('Scored'), 7, 'reload/rebuild retains reconciled score')
eq(Repo:GetHistoricalStats('Archived'), 7, 'reload/rebuild retains archived gap')
eq(Repo:GetHistoricalStats('Split'), 7, 'reload/rebuild does not double-count old events')
eq(Repo:GetHistoricalStats('FloorOnly'), 5, 'reload/rebuild retains floor-only identity')
print('PASS: legacy rows, floor-only imports and rebuilt indexes preserve totals')

-- Warm all name/legacy indexes, then forbid full database walks while in combat.
-- Exercise the actual renderer repeatedly and the actual write path afterward.
Repo:GetHistoricalStats('Scored')
local nativePairs = pairs
pairs = function(t)
    assert(t ~= history.victims and t ~= history.legacyFloors
        and t ~= history.legacyUnresolved and t ~= SpyPerCharDB.PlayerData
        and t ~= SpyDB.VoidMarkLegacyPlayers, 'combat path walked a full score database')
    return nativePairs(t)
end
M.combat = true
SpyPerCharDB.PlayerData.Scored.guid = nil
for _ = 1, 100 do Spy.VoidMark:StyleRow(1, 'Scored', '', 1) end
eq(row.VoidMarkRecordText:GetText(), '|cffb9a3c97-1|r', 'combat sightings remain correct without cached GUID')
local countBefore = history.eventCount
M.now, M.epoch = M.now + 10, M.epoch + 10
eq(Repo:RecordKill('Scored', guid, {}), 8, 'combat write stays indexed')
eq(history.eventCount, countBefore + 1, 'combat write still appends once')
eq(Repo:GetHistoricalStats('Scored'), 8, 'combat score sees newly appended event')
pairs = nativePairs
M.combat = false
print('PASS: repeated combat rendering and kill writes avoid full database scans')
