viewer.mode = FULLSCREEN

function setup()
  videoPlayer = CodeaAVPlayer()
end

function draw()
  background(30)
  fill(255)
  fontSize(22)
  textAlign(CENTER)
  
  text("Tap SHOWTIME to play video", WIDTH/2, HEIGHT/2 + 40)
  
  -- fake SPARTS logo text for demo
  fontSize(60)
  text("SHOWTIME", WIDTH/2, HEIGHT/2 - 20)
end

function touched(t)
  if t.state == BEGAN then
    -- replace with your real hit test later
    videoPlayer:showAndAutoplayMOV(asset.OverheadWaves)
    return true
  end
end