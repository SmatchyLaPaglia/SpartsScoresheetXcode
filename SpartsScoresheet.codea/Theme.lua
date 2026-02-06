-- =========================
-- THEME (all colors here)
-- =========================
Theme = {
  -- Base
  bgApp            = color(0, 0, 0, 255),         -- whole screen behind tables (used by your scene)
  boxBg            = color(25, 25, 25, 255),      -- inner rounded container (if you draw one)
  gridLine         = color(32, 32, 32, 255),      -- cell borders
  cellBg           = color(255, 255, 255, 255),   -- default cell bg (left side inputs)
  cellBgPressed    = color(232, 240, 254, 255),   -- tap highlight for inputs
  textPrimary      = color(240, 240, 240, 255),   -- default header/label text on dark
  textSecondary    = color(180, 180, 180, 255),   -- secondary labels on dark
  textOnLight      = color(0, 0, 0, 255),         -- text on white cells
  textDisabled     = color(140, 140, 140, 255),   -- "--" dim color
  textAccentBlue   = color(60, 160, 255, 255),    -- left-side numbers (bids/took)
  
  -- Left header band
  leftHeaderBg     = color(55, 55, 55, 255),      -- dark header slab
  leftHeaderText   = color(255, 140, 0, 255),     -- orange label (TEAMS / SPADES / HEARTS)
  
  -- Name stripes (alternating fill for the 4 name rows)
  nameStripeLight  = color(238, 238, 238, 255),   -- light gray
  nameStripeDark   = color(220, 235, 225, 255),   -- very light green tint (like screenshot)
  
  -- Right mini headers (small headers above per-column)
  rightMiniHeaderBg  = color(55, 55, 55, 255),
  rightMiniHeaderTxt = color(255, 140, 0, 255),
  
  -- Right numeric column blocks (per-column backgrounds)
  rightSpadesScoreBg = color(0, 132, 141, 255),   -- teal (SPADES SCORE)
  
  rightHeartsScoreBg = color(0, 146, 145, 255),   -- green-teal (HEARTS SCORE)
  
  rightHandScoreBg   = color(0, 116, 128, 255),   -- darker teal (HAND SCORE)
  
  rightAllBagsBg     = color(0, 100, 190, 255),   -- blue (ALL BAGS)
  
  rightSpadesTotalBg = color(0, 110, 190, 255),  -- magenta/pink (SPADES TOTAL)
  
  rightHeartsTotalBg = color(0, 80, 190, 255), -- light violet (HEARTS TOTAL)
  rightGameTotalBg   = color(160, 40, 120, 255),  -- purple/magenta (GAME TOTAL)
  rightNumberTxt     = color(255, 255, 255, 255), -- white numbers
  
  -- Checkbox fill
  checkboxTick       = color(0, 0, 0, 255),
  checkboxBox        = color(0, 0, 0, 255),
}

