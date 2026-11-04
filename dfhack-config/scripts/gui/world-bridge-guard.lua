-- Experimental input guard. Only use with the disposable automatic test.
local gui=require('gui')
local guard=require('world-bridge.mission-guard')
local access=require('world-bridge.accessibility-adapter')
local automatic=require('world-bridge.automatic-experiment')
local adapter=require('world-bridge.df-adapter')
BridgeGuard=defclass(BridgeGuard,gui.ZScreen)
BridgeGuard.ATTRS{focus_path='world-bridge-guard',defocusable=false,pass_mouse_clicks=true}
local function filter()
    local s=dfhack.gui.getDFViewscreen(true)
    if s and s._type==df.viewscreen_worldst then
        guard.filter(s,access.is_extended,df.army_controller_goal_type.SITE_INVASION,
            df.world_new_mission_type.OKAY,df.world_new_mission_type.INACCESSIBLE,
            df.world_view_mode_type.NEW_MISSION)
    end
end
local function lock_extended_actions()
    local s=dfhack.gui.getDFViewscreen(true)
    if s and s._type==df.viewscreen_worldst then
        -- Before removing accessibility, invalidate the cached buttons for
        -- the currently selected bridge-only site, including raid.
        guard.filter(s,access.is_extended,nil,df.world_new_mission_type.OKAY,
            df.world_new_mission_type.INACCESSIBLE,df.world_view_mode_type.NEW_MISSION)
    end
end
function BridgeGuard:suspend()
    lock_extended_actions()
    local ok,env=pcall(adapter.environment)
    local stopped,err=pcall(automatic.stop,ok and env or nil)
    if not stopped then error(err) end
    if not ok and dfhack.isMapLoaded() then error(env) end
end
function BridgeGuard:onInput(keys)
    local ok,err=pcall(function()
        if dfhack.gui.getCurViewscreen(true)~=self._native then
            self:suspend()
            self:sendInputToParent(keys)
            return
        end
        -- Capture assignments and ensure the overlay is protected before
        -- native input, then capture any change caused by that input.
        automatic.update(adapter.environment())
        filter()
        self:sendInputToParent(keys)
        automatic.update(adapter.environment())
        local s=dfhack.gui.getDFViewscreen(true)
        if not s or s._type~=df.viewscreen_worldst then self:dismiss() else filter() end
    end)
    if not ok then
        self.failed=true
        df.global.pause_state=true
        dfhack.printerr('World Bridge input guard paused: '..tostring(err))
        self:dismiss()
    end
    return true
end
function BridgeGuard:onDismiss()
    local ok,err=pcall(self.suspend,self)
    if not ok then
        self.failed=true
        if dfhack.isMapLoaded() then df.global.pause_state=true end
        dfhack.printerr('World Bridge guard cleanup paused: '..tostring(err))
    end
end
function BridgeGuard:dismiss()
    BridgeGuard.super.dismiss(self)
    -- ZScreen restores its original pause state during dismissal. Preserve a
    -- failure pause even when the world map was opened while unpaused.
    if self.failed and dfhack.isMapLoaded() then df.global.pause_state=true end
end
function BridgeGuard:render(dc)
    filter();self:renderParent()
end
view=BridgeGuard():show()
