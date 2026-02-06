-- ScoreRules.lua
-- Scoring rules for Sparts

ScoreRules = {}

----------------------------------------------------------------
-- SPADES (2v2)
-- - Team bid = sum of player bids.
-- - Determine "took_for_bid" = tricks by only the players who bid > 0.
-- - If took_for_bid >= teamBid: handScore = +10 * teamBid
--     Bags for this hand:
--       + (took_for_bid - teamBid)   -- normal overtricks
--       + (tricks taken by any nil-bid players)  -- nil tricks count as bags
-- - If took_for_bid < teamBid: handScore = -10 * teamBid; handBags = 0
-- - Bags are tracked cumulatively; every 10 => -100 and carry remainder.
----------------------------------------------------------------
function ScoreRules.spadesHand(team)
  if not ScoreRules.spadesReady(team) then
    return {
      bid        = nil,
      tookTotal  = nil,
      tookForBid = nil,
      nilTricks  = nil,
      over       = nil,
      handBags   = nil,
      handScore  = nil,      -- NO SCORE SET
    }
  end
  
  local p1, p2 = team.players[1], team.players[2]
  local b1, b2 = p1.bid, p2.bid
  local t1, t2 = p1.took, p2.took
  
  local teamBid = b1 + b2
  
  local took_for_bid =
  ((b1 > 0) and t1 or 0) +
  ((b2 > 0) and t2 or 0)
  
  local nil_tricks =
  ((b1 == 0) and t1 or 0) +
  ((b2 == 0) and t2 or 0)
  
  local made          = (took_for_bid >= teamBid)
  local baseHandScore = made and (10 * teamBid) or (-10 * teamBid)
  
  local nilBonus = 0
  if b1 == 0 then nilBonus = nilBonus + ((t1 == 0) and 100 or -100) end
  if b2 == 0 then nilBonus = nilBonus + ((t2 == 0) and 100 or -100) end
  
  -- Overtricks only exist when the (non-nil) bidders make their bid.
  local over = made and math.max(0, took_for_bid - teamBid) or 0
  
  -- Hand bags always include any nil-bidder tricks,
  -- plus normal overtricks if the bid was made.
  local handBags = nil_tricks + over
  
  return {
    bid        = teamBid,
    tookTotal  = t1 + t2,
    tookForBid = took_for_bid,
    nilTricks  = nil_tricks,
    over       = over,
    handBags   = handBags,
    handScore  = baseHandScore + nilBonus
  }
end

-- Apply sandbag penalty to a running bag count.
-- Returns (remainingBags, penaltyPointsApplied)
function ScoreRules.applySandbagPenalty(allBags, per, penalty)
  per     = per or 10
  penalty = penalty or 100
  local knocks = math.floor(allBags / per)
  return (allBags % per), knocks * penalty
end

----------------------------------------------------------------
-- HEARTS (team-level)
-- - Each heart = +4
-- - Queen of spades = +52
-- - Moon shot = -104
----------------------------------------------------------------
function ScoreRules.heartsHand(team)
  if not ScoreRules.heartsReady(team) then
    return {
      hearts    = nil,
      qs        = nil,
      moon      = nil,
      handScore = nil,   -- NO SCORE SET
    }
  end
  
  local heartsPts = (team.hearts or 0) * 4
  local qsPts     = team.queensSpades and 52   or 0
  local moonPts   = team.moonShot     and -104 or 0
  local oppMoon   = team._oppMoonBonus or 0
  local score     = heartsPts + qsPts + moonPts + oppMoon
  
  return {
    hearts    = heartsPts,
    qs        = team.queensSpades and 1 or 0,
    moon      = team.moonShot and 1 or 0,
    handScore = score
  }
end

----------------------------------------------------------------
-- HEARTS COUPLING / MOON NORMALIZATION
-- Enforces the "one team moons" rule across both teams.
-- - Moon team: hearts=13, queen=checked
-- - Other team: hearts=0, queen=unchecked, moon=unchecked
-- - Other team also receives +104 for the hand (set via _oppMoonBonus)
----------------------------------------------------------------

function ScoreRules.queenIsAssigned(teams)
  local t1, t2 = teams[1], teams[2]
  if not t1 or not t2 then return false end
  return (t1.queensSpades == true) or (t2.queensSpades == true)
  or (t1.moonShot == true)     or (t2.moonShot == true)
end

function ScoreRules.heartsTotalDisplayReady(teams, teamIndex)
  return (teams and teams[teamIndex] and teams[teamIndex].hearts ~= nil)
  and ScoreRules.queenIsAssigned(teams)
end

function ScoreRules.syncHeartsMoon(teams)
  local t1, t2 = teams[1], teams[2]
  -- clear per-hand transient bonuses
  t1._oppMoonBonus, t2._oppMoonBonus = 0, 0
  
  local t1Moon = (t1.moonShot == true)
  local t2Moon = (t2.moonShot == true)
  
  -- If both somehow toggled on, prefer team 1 (arbitrary but stable)
  if t1Moon then
    -- Team 1 moons
    t1.hearts        = 13
    t1.queensSpades  = true
    -- Force team 2 state
    t2.hearts        = 0
    t2.moonShot      = false
    t2.queensSpades  = false
    -- +104 goes to the *other* team
    t2._oppMoonBonus = 104
  elseif t2Moon then
    -- Team 2 moons
    t2.hearts        = 13
    t2.queensSpades  = true
    -- Force team 1 state
    t1.hearts        = 0
    t1.moonShot      = false
    t1.queensSpades  = false
    -- +104 goes to the *other* team
    t1._oppMoonBonus = 104
  end
end

-- Add at top-level:
function ScoreRules.spadesReady(team)
  local p1, p2 = team.players[1], team.players[2]
  -- Ready only when BOTH bids and BOTH tooks are explicitly set (non-nil)
  return (p1 and p2)
  and (p1.bid  ~= nil) and (p2.bid  ~= nil)
  and (p1.took ~= nil) and (p2.took ~= nil)
end

function ScoreRules.heartsReady(team)
  -- Ready if any hearts/queen/moon has been explicitly set, or if the opponent
  -- has mooned (which gives this team +104 via _oppMoonBonus).
  return (team.moonShot == true)
  or (team.hearts ~= nil)
  or (team.queensSpades == true)
  or ((team._oppMoonBonus or 0) ~= 0)
end