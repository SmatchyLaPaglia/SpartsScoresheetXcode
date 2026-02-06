-- LifecycleObserver.lua
-- Codea app lifecycle observer with Lua callbacks

LifecycleObserver = class()

function LifecycleObserver:init()
  self.onEnterBackground   = nil
  self.onWillEnterForeground = nil
  self.onDidBecomeActive   = nil
  self.onWillResignActive  = nil
  self.onWillTerminate    = nil
  
  self:_install()
end

function LifecycleObserver:_install()
  -- Define ObjC class once
  if not _G._LifecycleHandler then
    _LifecycleHandler = objc.class("LifecycleHandler")
    
    function _LifecycleHandler:didEnterBackground_(note)
      if self._lua and self._lua.onEnterBackground then
        self._lua.onEnterBackground()
      end
    end
    
    function _LifecycleHandler:willEnterForeground_(note)
      if self._lua and self._lua.onWillEnterForeground then
        self._lua.onWillEnterForeground()
      end
    end
    
    function _LifecycleHandler:didBecomeActive_(note)
      if self._lua and self._lua.onDidBecomeActive then
        self._lua.onDidBecomeActive()
      end
    end
    
    function _LifecycleHandler:willResignActive_(note)
      if self._lua and self._lua.onWillResignActive then
        self._lua.onWillResignActive()
      end
    end
    
    function _LifecycleHandler:willTerminate_(note)
      if self._lua and self._lua.onWillTerminate then
        self._lua.onWillTerminate()
      end
    end
  end
  
  -- Strong references (CRITICAL)
  self._handler = _LifecycleHandler()
  self._handler._lua = self
  
  local nc = objc.NSNotificationCenter.defaultCenter
  
  nc:addObserver_selector_name_object_(
  self._handler,
  objc.selector("didEnterBackground:"),
  "UIApplicationDidEnterBackgroundNotification",
  nil
  )
  
  nc:addObserver_selector_name_object_(
  self._handler,
  objc.selector("willEnterForeground:"),
  "UIApplicationWillEnterForegroundNotification",
  nil
  )
  
  nc:addObserver_selector_name_object_(
  self._handler,
  objc.selector("didBecomeActive:"),
  "UIApplicationDidBecomeActiveNotification",
  nil
  )
  
  nc:addObserver_selector_name_object_(
  self._handler,
  objc.selector("willResignActive:"),
  "UIApplicationWillResignActiveNotification",
  nil
  )
  
  nc:addObserver_selector_name_object_(
  self._handler,
  objc.selector("willTerminate:"),
  "UIApplicationWillTerminateNotification",
  nil
  )
end