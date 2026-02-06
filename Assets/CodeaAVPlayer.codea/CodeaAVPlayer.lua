-- CodeaAVPlayer.lua
-- Minimal AVPlayer wrapper for local .mov assets
-- Manual dismissal via native controls only

CodeaAVPlayer = class()

function CodeaAVPlayer:init()
  self._player = nil
  self._vc = nil
  self._controlsRevealed = false
end

function CodeaAVPlayer:showAndAutoplayMOV(videoAsset)
  if not videoAsset or not videoAsset.path then
    print("[MOVPlayer] invalid asset")
    return
  end
  
  -- NSURL from file path (CRITICAL: avoids crash)
  local url = objc.NSURL:fileURLWithPath_(videoAsset.path)
  print("url:", url)
  
  local AVPlayer = objc.AVPlayer
  local AVPlayerViewController = objc.AVPlayerViewController
  
  local player = AVPlayer:playerWithURL_(url)
  print("player:", player)
  
  local vc = AVPlayerViewController()
  vc.player = player
  
  -- retain
  self._player = player
  self._vc = vc
  
  print("presenting video VC")
  
  objc.viewer:presentViewController_animated_completion_(
  vc,
  true,
  function()
    print("video VC presented, autoplaying")
    player:play()
  end
  )
end