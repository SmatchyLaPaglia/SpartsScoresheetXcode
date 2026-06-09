-- ScoreLedger.lua
-- Maintains a list of compleuted hands and a "live" hand (from UI).
-- Recomputes running totals and writes them back into teams[*].

ScoreLedger = class()

function ScoreLedger:init(rules, teams)
  self.rules = rules or ScoreRules
  self.teams = teams
  self.hands = {}   -- array of { team1 = {...}, team2 = {...} }
end

-- Returns snapshots[handIndex][teamIndex] = { spadesScore, heartsScore, handBags, spadesTotal, heartsTotal, allBags, gameTotal }
function ScoreLedger:computeSnapshotsForTables(tables)
  local R = self.rules or ScoreRules
  
  local snapshots = {}
  
  -- running state per team
  local run = {
    [1] = { spadesTotal=0, spadesReady=true, heartsTotal=0, heartsReady=false, allBags=0 },
    [2] = { spadesTotal=0, spadesReady=true, heartsTotal=0, heartsReady=false, allBags=0 },
  }
  
  for hi = 1, #tables do
    local teams = tables[hi].teams
    
    -- Normalize moon effects for THIS hand (this is the “rules layer” decision point)
    R.syncHeartsMoon(teams)
    
    local queenAssigned = R.queenIsAssigned(teams)
    
    snapshots[hi] = {}
    
    for ti = 1, 2 do
      local team = teams[ti]
      local rs = run[ti]
      
      local s = R.spadesHand(team)
      local h = R.heartsHand(team)
      
      -- HAND readiness
      local spadesHandReady = (s.handScore ~= nil)
      local heartsHandReady = queenAssigned and (team.hearts ~= nil) and (h.handScore ~= nil)
      
      -- Hand scores that the UI is allowed to show
      local spadesScore = spadesHandReady and s.handScore or nil
      local heartsScore = heartsHandReady and h.handScore or nil
      local handBags    = spadesHandReady and (s.handBags or 0) or nil
      
      -- Totals: spades can accumulate independently
      if spadesHandReady then
        rs.spadesTotal = (rs.spadesTotal or 0) + spadesScore
        rs.allBags     = (rs.allBags or 0) + (handBags or 0)
        
        local newAllBags, penalty = R.applySandbagPenalty(rs.allBags, 10, 100)
        rs.allBags = newAllBags
        rs.spadesTotal = rs.spadesTotal - (penalty or 0)
      end
      
      -- Totals: hearts must be a continuous chain (hand must be ready, AND previous heartsTotal must exist)
      if heartsScore ~= nil then
        if rs.heartsReady == false and hi == 1 then
          rs.heartsReady = true
        end
        if rs.heartsReady == true then
          rs.heartsTotal = (rs.heartsTotal or 0) + heartsScore
        end
      end
      
      -- If hearts never became “ready chain”, keep it nil for display
      local heartsTotalOut = rs.heartsReady and rs.heartsTotal or nil
      
      -- Game total only when BOTH totals exist
      local gameTotalOut = (heartsTotalOut ~= nil)
      and (rs.spadesTotal - heartsTotalOut)
      or nil
      
      snapshots[hi][ti] = {
        spadesScore = spadesScore,
        heartsScore = heartsScore,
        handBags    = handBags,
        
        spadesTotal = rs.spadesTotal,
        heartsTotal = heartsTotalOut,
        allBags     = rs.allBags,
        
        gameTotal   = gameTotalOut
      }
    end
  end
  
  return snapshots
end

