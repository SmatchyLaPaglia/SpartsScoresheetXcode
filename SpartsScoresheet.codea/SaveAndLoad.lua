function saveGameState()
  print("[SAVE] begin")
  
  -- timezone
  saveLocalData("isWest", sheets.tzBtn.isWest and 1 or 0)
  
  -- number of hands
  saveLocalData("handCount", #sheets.tables)

  -- first dealer (drives dealer rotation across hands)
  saveLocalData("firstDealer", sheets.firstDealer or 1)
  saveLocalData("secondDealer", sheets.secondDealer or 3)
  
  for hi, table in ipairs(sheets.tables) do
    for ti = 1, 2 do
      local team = table.teams[ti]
      
      saveLocalData("h"..hi.."t"..ti.."hearts", team.hearts ~= nil and team.hearts or -1)
      saveLocalData("h"..hi.."t"..ti.."qs", team.queensSpades and 1 or 0)
      saveLocalData("h"..hi.."t"..ti.."moon", team.moonShot and 1 or 0)
      
      for pi = 1, 2 do
        local p = team.players[pi]
        saveLocalData("h"..hi.."t"..ti.."p"..pi.."name", p.name or "")
        saveLocalData("h"..hi.."t"..ti.."p"..pi.."bid", p.bid or -1)
        saveLocalData("h"..hi.."t"..ti.."p"..pi.."took", p.took or -1)
      end
    end
  end
  
  print("[SAVE] done")
end

function loadGameState()
  print("[LOAD] begin")
  
  local handCount = readLocalData("handCount")
  if not handCount or handCount < 1 then
    print("[LOAD] nothing saved")
    return
  end
  
  -- timezone
  sheets.tzBtn.isWest = readLocalData("isWest", 0) == 1
  
  local tables = {}
  
  for hi = 1, handCount do
    local teams = {}
    
    for ti = 1, 2 do
      local players = {}
      
      for pi = 1, 2 do
        local name = readLocalData("h"..hi.."t"..ti.."p"..pi.."name", "")
        local bid  = readLocalData("h"..hi.."t"..ti.."p"..pi.."bid", -1)
        local took = readLocalData("h"..hi.."t"..ti.."p"..pi.."took", -1)
        
        players[pi] = {
          name = name,
          bid  = (bid  >= 0) and bid  or nil,
          took = (took >= 0) and took or nil
        }
      end
      
      local h = readLocalData("h"..hi.."t"..ti.."hearts", -1)
      teams[ti] = {
        players       = players,
        hearts = (h >= 0) and h or nil,
        queensSpades  = readLocalData("h"..hi.."t"..ti.."qs", 0) == 1,
        moonShot      = readLocalData("h"..hi.."t"..ti.."moon", 0) == 1,
        
        -- ledger will recompute these
        spadesTotal = 0,
        heartsTotal = 0,
        gameTotal   = 0,
        allBags     = 0
      }
    end
    
    tables[hi] = ScoreTable(teams)
  end
  
  sheets.tables = tables
  sheets.scrollY = 0
  sheets.ledger = nil   -- force recompute next draw

  -- The line below discards this `sheets` and builds a fresh one so that
  -- :init() re-wires everything (buttons, sensors, dealer tracking, and
  -- the 4 name UITextFields) against the loaded tables. That fresh :init()
  -- creates its own 4 UITextFields and attaches them to the host view —
  -- if we don't remove the outgoing instance's 4 fields first, they stay
  -- attached forever as an invisible, non-functional orphaned duplicate
  -- set sitting at hand 1's position (this only happens once, at the
  -- setup() -> loadGameState() handoff at launch, not per hand/table).
  if sheets._rawNameFields then
    for _, tf in ipairs(sheets._rawNameFields) do
      if tf then tf:removeFromSuperview_() end
    end
  end

  sheets = ScoreSheets(function() return tables[1].teams end)
  sheets.tables = tables

  if sheets._setFirstDealer then
    sheets:_setFirstDealer(readLocalData("firstDealer", 1))
  end
  if sheets._setSecondDealer then
    sheets:_setSecondDealer(readLocalData("secondDealer", -1))
  end

  -- Restore hand-1 player names from disk. init() seeds the name text fields
  -- with "Player N" placeholders and writes them into the model, which would
  -- otherwise clobber the just-loaded names on the first hand only.
  if sheets._nameData and sheets._rawNameFields and sheets.tables[1] then
    for i = 1, 4 do
      local nameData = sheets._nameData[i]
      if nameData then
        local ti = nameData.team
        local pi = nameData.player
        local savedName = readLocalData("h1t"..ti.."p"..pi.."name", "")
        if savedName and savedName ~= "" then
          local model = sheets.tables[1].teams[ti].players[pi]
          if model then model.name = savedName end
          local tf = sheets._rawNameFields[i]
          if tf then tf.text = savedName end
        end
      end
    end
  end

  devLog("[LOAD] done")
end
    
function clearSavedGameState()
  -- read before clearing
  clearLocalData()
  print("[SAVE] cleared persisted game state")
end