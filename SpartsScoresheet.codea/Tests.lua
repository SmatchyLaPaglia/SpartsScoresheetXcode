-- ScoreRulesTests.lua
-- Minimal unit tests for ScoreRules (no UI, pure functions)

T = {}

-- --- tiny assertion helpers -----------------------------------------------

local function fail(msg) error(msg, 2) end

local function expectEq(actual, expected, label)
  if actual ~= expected then
    fail(string.format("FAILED: %s (expected %s, got %s)", label, tostring(expected), tostring(actual)))
  end
end

local function expectTrue(cond, label)
  if not cond then fail("FAILED: " .. label .. " (expected true)") end
end

local function expectFalse(cond, label)
  if cond then fail("FAILED: " .. label .. " (expected false)") end
end

-- --- fixtures --------------------------------------------------------------

local function newTeam()
  return {
    players = { {bid=0,took=0}, {bid=0,took=0} }, -- spades irrelevant here
    hearts = 0, queensSpades = false, moonShot = false,
    _oppMoonBonus = 0
  }
end

local function newTeams()
  return { newTeam(), newTeam() }
end

local function heartsScore(team)
  local h = ScoreRules.heartsHand(team)
  return h.handScore, h
end

-- --- tests ----------------------------------------------------------------
-- 1) setting moon sets other teams hearts to 0
function T.test_moon_sets_other_hearts_to_0()
  local teams = newTeams()
  teams[2].hearts = 7 -- prefill to prove it gets cleared
  teams[1].moonShot = true
  ScoreRules.syncHeartsMoon(teams)
  expectEq(teams[2].hearts, 0, "other team hearts forced to 0")
end

-- 2) setting moon clears queen from other team
function T.test_moon_clears_other_queen()
  local teams = newTeams()
  teams[2].queensSpades = true
  teams[1].moonShot = true
  ScoreRules.syncHeartsMoon(teams)
  expectFalse(teams[2].queensSpades, "other team queen cleared")
end

-- 3) setting moon sets team’s hearts to 13 and queen to true
function T.test_moon_sets_team_hearts_13_and_queen_true()
  local teams = newTeams()
  teams[1].moonShot = true
  ScoreRules.syncHeartsMoon(teams)
  expectEq(teams[1].hearts, 13, "moon team hearts forced to 13")
  expectTrue(teams[1].queensSpades, "moon team queen forced true")
end

-- 4) setting moon sets team’s hearts score to 0
function T.test_moon_sets_team_hearts_score_0()
  local teams = newTeams()
  teams[1].moonShot = true
  ScoreRules.syncHeartsMoon(teams)
  local s1 = heartsScore(teams[1])
  expectEq(s1, 0, "moon team hearts score == 0")
end

-- 5) setting moon sets other team’s hearts score to 104
function T.test_moon_sets_other_hearts_score_104()
  local teams = newTeams()
  teams[1].moonShot = true
  ScoreRules.syncHeartsMoon(teams)
  local s2 = heartsScore(teams[2])
  expectEq(s2, 104, "other team gets +104 when opponent moons")
end

-- 6) taking queen plus 13 cards but no moon sets hearts score to 104
function T.test_queen_plus_13_no_moon_scores_104()
  local teams = newTeams()
  teams[1].hearts = 13
  teams[1].queensSpades = true
  teams[1].moonShot = false
  ScoreRules.syncHeartsMoon(teams)
  local s1 = heartsScore(teams[1])
  expectEq(s1, 104, "13 hearts + queen, no moon => 104")
end

-- --- runner ----------------------------------------------------------------

function T.run()
  local list = {
    {"moon_sets_other_hearts_to_0",                 T.test_moon_sets_other_hearts_to_0},
    {"moon_clears_other_queen",                     T.test_moon_clears_other_queen},
    {"moon_sets_team_hearts_13_and_queen_true",     T.test_moon_sets_team_hearts_13_and_queen_true},
    {"moon_sets_team_hearts_score_0",               T.test_moon_sets_team_hearts_score_0},
    {"moon_sets_other_hearts_score_104",            T.test_moon_sets_other_hearts_score_104},
    {"queen_plus_13_no_moon_scores_104",            T.test_queen_plus_13_no_moon_scores_104},       
    {"ledger_moon_normalizes_input_teams",        T.test_ledger_moon_normalizes_input_teams},
    {"ledger_moon_produces_correct_hearts_scores", T.test_ledger_moon_produces_correct_hearts_scores},
  }
  local ok, failed = 0, 0
  for _,pair in ipairs(list) do
    local name, fn = pair[1], pair[2]
    local status, err = pcall(fn)
    if status then
      ok = ok + 1
      print("✔︎ PASS:", name)
    else
      failed = failed + 1
      print("✘ FAIL:", name, "\n   ", err)
    end
  end
  print(string.format("\nRESULT: %d passed, %d failed", ok, failed))
end

local function newBlankTeams()
  local function team()
    return {
      players = { {bid=nil, took=nil}, {bid=nil, took=nil} },
      hearts=nil, queensSpades=false, moonShot=false,
      _oppMoonBonus=0,
      spadesScore=nil, heartsScore=nil, handBags=nil,
      spadesTotal=0, heartsTotal=0, allBags=0, gameTotal=0
    }
  end
  return { team(), team() }
end

local function setTeam1SpadesComplete(teams, b1,b2,t1,t2)
  local p1 = teams[1].players[1]
  local p2 = teams[1].players[2]
  p1.bid, p2.bid = b1, b2
  p1.took, p2.took = t1, t2
end

local function dumpLedger(label, ledger)
  local snap = ledger:recompute()
  local t1 = snap.team[1]
  local t2 = snap.team[2]
  print("----", label, "----")
  print("T1 spadesScore:", t1.spadesScore, "heartsScore:", t1.heartsScore, "handScore:", t1.handScore)
  print("T1 spadesTotal:", t1.spadesTotal, "heartsTotal:", t1.heartsTotal, "allBags:", t1.allBags, "gameTotal:", t1.gameTotal)
  print("T2 spadesScore:", t2.spadesScore, "heartsScore:", t2.heartsScore, "handScore:", t2.handScore)
  print("T2 spadesTotal:", t2.spadesTotal, "heartsTotal:", t2.heartsTotal, "allBags:", t2.allBags, "gameTotal:", t2.gameTotal)
end

function runLedgerOrderBugProbe()
  local ledger = ScoreLedger(ScoreRules, nil)
  
  -- HAND 1 (live)
  local hand1 = newBlankTeams()
  hand1[1].queensSpades = true  -- mimic your “queen assigned somewhere” requirement
  setTeam1SpadesComplete(hand1, 1,1,2,2) -- team1 bid=2 took=4 => +20, bags=2
  ledger.teams = hand1
  
  dumpLedger("step 1: hand1 spades only", ledger)
  
  -- STEP 2: "make new hand" => hand1 becomes completed snapshot, hand2 becomes live
  ledger.hands = {}
  ledger:finalizeHandFromTeams(hand1)
  
  local hand2 = newBlankTeams()
  hand2[1].queensSpades = true
  setTeam1SpadesComplete(hand2, 1,1,2,2)
  ledger.teams = hand2
  
  dumpLedger("step 2: hand2 spades only, hand1 snapped", ledger)
  
  -- STEP 3: go back and set hearts on hand1
  hand1[1].hearts = 5 -- any non-nil
  -- IMPORTANT: simulate “editing a completed hand” by re-snapping it
  ledger.hands = {}
  ledger:finalizeHandFromTeams(hand1)
  
  dumpLedger("step 3: hand1 hearts set AFTER hand2 created", ledger)
  
  -- Optional: also set hearts on live hand2 and see if it ever becomes ready
  hand2[1].hearts = 3
  dumpLedger("step 4: hand2 hearts set too", ledger)
end

local function newTable(teams)
  return { teams = teams }
end

function T.test_ledger_moon_normalizes_input_teams()
  local ledger = ScoreLedger(ScoreRules, nil)
  local hand1 = newTeams()
  
  hand1[1].moonShot = true
  hand1[2].hearts = 7
  hand1[2].queensSpades = true
  
  ledger:computeSnapshotsForTables({ newTable(hand1) })
  
  -- ledger calls ScoreRules.syncHeartsMoon(teams), which mutates hand1 in-place
  expectEq(hand1[1].hearts, 13, "moon team hearts forced to 13 by ledger")
  expectTrue(hand1[1].queensSpades, "moon team queen forced true by ledger")
  
  expectEq(hand1[2].hearts, 0, "other team hearts forced to 0 by ledger")
  expectFalse(hand1[2].queensSpades, "other team queen cleared by ledger")
  expectFalse(hand1[2].moonShot, "other team moon cleared by ledger")
  expectEq(hand1[2]._oppMoonBonus or 0, 104, "other team gets +104 opp bonus by ledger")
end

function T.test_ledger_moon_produces_correct_hearts_scores()
  local ledger = ScoreLedger(ScoreRules, nil)
  local hand1 = newTeams()
  hand1[1].moonShot = true
  
  local snaps = ledger:computeSnapshotsForTables({ newTable(hand1) })
  
  -- After normalization:
  -- moon team hearts score = 13*4 + 52 - 104 = 0
  -- other team hearts score = 0 + 0 + 0 + 104 = 104
  expectEq(snaps[1][1].heartsScore, 0, "ledger snap heartsScore (moon team) = 0")
  expectEq(snaps[1][2].heartsScore, 104, "ledger snap heartsScore (other team) = 104")
end