--@module = true
-- Plan on DF's native world map; planner clicks never reach native orders.
local gui=require('gui')
local widgets=require('gui.widgets')
local dialogs=require('gui.dialogs')
local adapter=require('world-bridge.df-adapter')
local service=require('world-bridge.service')
local store=require('world-bridge.store')
local runtime=require('world-bridge.runtime')
local materials=require('world-bridge.materials')
local coordinates=require('world-bridge.map-coordinates')
local native=require('world-bridge.native-map')
local removal=require('world-bridge.removal')
local env=adapter.environment()
local function key(x,y)return x..','..y end
local function show_error(message)dialogs.showMessage('World Bridge',tostring(message),COLOR_LIGHTRED)end
local function pan_to(screen,x,y)
    x,y=coordinates.clamp_center(df.global.gps.main_map_port,
        {width=env.world.world_width,height=env.world.world_height},x,y)
    screen.region_cent_x,screen.region_cent_y=x,y
end

WorldBridgeWindow=defclass(WorldBridgeWindow,widgets.Window)
WorldBridgeWindow.ATTRS{frame_title='World Bridge',frame={r=1,t=1,w=48,b=1},resizable=false,world_screen=DEFAULT_NIL}
function WorldBridgeWindow:init()
    self.existing={};self.preview_tiles={};self.message='Click a land tile on the world map to choose the first shore.'
    self:addviews{
        widgets.Label{frame={l=1,t=0},text=('%d blocks | %d days per water tile'):format(service.BLOCKS_PER_WATER_TILE,service.TICKS_PER_WATER_TILE/1200)},
        widgets.Label{frame={l=1,t=2},text='Projects in this world'},
        widgets.List{view_id='projects',frame={l=1,t=3,r=1,h=7},on_select=self:callback('showProject')},
        widgets.Label{view_id='project_detail',frame={l=1,t=11,r=1,h=7},text='Select a project to view it.'},
        widgets.WrappedLabel{view_id='preview',frame={l=1,t=19,r=1,h=5},auto_height=false,text_to_wrap=function()return self.message end},
        widgets.HotkeyLabel{frame={l=1,t=25},key='CUSTOM_CTRL_N',label='Create previewed project',on_activate=self:callback('createProject'),disabled=function()return not self.preview end},
        widgets.HotkeyLabel{frame={l=1,t=27},key='CUSTOM_CTRL_R',label='Clear shore selection',on_activate=self:callback('clearSelection')},
        widgets.HotkeyLabel{frame={l=1,t=29},key='CUSTOM_CTRL_D',label='Deliver blocks',on_activate=self:callback('deliverBlocks'),disabled=function()return not self:selectedFundingProject() end},
        widgets.HotkeyLabel{frame={l=1,t=31},key='CUSTOM_CTRL_B',label='Build local deck',on_activate=self:callback('buildLocalDeck'),disabled=function()return not self:selectedCompletedProject() end},
        widgets.HotkeyLabel{frame={l=1,t=33},key='CUSTOM_CTRL_C',label='Center on fortress',on_activate=self:callback('centerFortress')},
        widgets.HotkeyLabel{frame={l=1,t=35},key='CUSTOM_CTRL_F',label='Refresh project status',on_activate=self:callback('refreshProjects')},
        widgets.HotkeyLabel{frame={l=1,t=37},key='CUSTOM_CTRL_T',label=function()return 'Raid routing: '..(runtime.is_automatic_enabled() and 'on' or 'off') end,on_activate=self:callback('toggleRouting')},
        widgets.HotkeyLabel{frame={l=1,t=39},key='CUSTOM_CTRL_L',label=function()return 'Automatic local decks: '..(require('world-bridge.local-sync').enabled(env.persistent) and 'on' or 'off') end,on_activate=self:callback('toggleLocalDecks')},
        widgets.HotkeyLabel{frame={l=1,t=41},key='CUSTOM_CTRL_E',label=function()return 'Caravan access: '..(runtime.is_trade_enabled() and runtime.is_active() and 'on' or 'off') end,on_activate=self:callback('toggleTradeLinks')},
        widgets.HotkeyLabel{frame={l=1,t=43},key='CUSTOM_CTRL_X',label=function()
            local p=self:selectedOwnedProject()
            return p and p.state=='complete' and 'Remove bridge' or 'Cancel project'
        end,on_activate=self:callback('removeProject'),disabled=function()return not self:selectedOwnedProject() end},
        widgets.Label{frame={l=1,b=0},text='Esc: close planner'},
    }
    self:centerFortress();self:refreshProjects()
end
function WorldBridgeWindow:centerFortress()
    local s=df.world_site.find(env.site_id)
    if s then pan_to(self.world_screen,s.pos.x,s.pos.y) end
end
function WorldBridgeWindow:setMessage(message)
    self.message=message
    self.subviews.preview:updateLayout()
end
function WorldBridgeWindow:clearSelection()
    self.shore_a=nil;self.shore_b=nil;self.preview=nil;self.preview_tiles={};self:setMessage('Click a land tile to choose the first shore.')
end
function WorldBridgeWindow:selectShore(x,y)
    if env.classify(x,y)~='land' then self.preview=nil;self.preview_tiles={};self:setMessage('Choose a land tile on the shore.');return end
    if self.shore_a and not self.shore_b and self.shore_a.x==x and self.shore_a.y==y then return end
    if self.shore_b and self.shore_b.x==x and self.shore_b.y==y then return end
    if not self.shore_a or self.shore_b then self:clearSelection();self.shore_a={x=x,y=y};self:setMessage(('Shore A: %d,%d. Click land on the other side.'):format(x,y));return end
    self.shore_b={x=x,y=y}
    local ok,p,why=pcall(service.plan,env,self.shore_a,self.shore_b)
    if not ok then self:setMessage(tostring(p));self.preview=nil;return end
    if not p then self:setMessage(tostring(why));self.preview=nil;return end
    self.preview=p;self.preview_tiles={};for _,t in ipairs(p.path) do self.preview_tiles[key(t.x,t.y)]=true end
    self:setMessage(('Shore A: %d,%d | B: %d,%d\nWater tiles: %d\n%d blocks | %d game days\nCreate, then deliver blocks.'):format(self.shore_a.x,self.shore_a.y,x,y,#p.path-2,p.required_blocks,p.duration_ticks/1200))
end
function WorldBridgeWindow:createProject()
    if not self.preview then return end
    local a,b=self.shore_a,self.shore_b;local p=self.preview
    dialogs.showYesNoPrompt('Create world bridge',('%d blocks and %d game days are required.\nCreate this project? Blocks are delivered separately.'):format(p.required_blocks,p.duration_ticks/1200),COLOR_WHITE,function()
        local ok,new,why=pcall(service.create,env,a,b)
        if not ok or not new then show_error(ok and why or new);return end
        dfhack.run_script('world-bridge','enable');self:clearSelection();self:refreshProjects(new.id)
    end)
end
function WorldBridgeWindow:refreshProjects(selected_id)
    local choices={};self.existing={}
    for _,entry in ipairs(store.load(env.persistent).projects) do
        local p=entry.project
        choices[#choices+1]={text=('#%d %s %d/%d blocks'):format(p.id,p.state,p.supplied_blocks,p.required_blocks),data=entry}
        for i=2,#p.path-1 do local t=p.path[i];self.existing[key(t.x,t.y)]={x=t.x,y=t.y,state=p.state} end
    end
    self.subviews.projects:setChoices(choices)
    if selected_id then for i,c in ipairs(choices) do if c.data.project.id==selected_id then self.subviews.projects:setSelected(i);break end end end
    self:showProject()
end
function WorldBridgeWindow:showProject()
    local _,choice=self.subviews.projects:getSelected()
    if not choice then self.subviews.project_detail:setText('No projects yet.\nChoose two shores to begin.');return end
    local e=choice.data;local p=e.project;local a,b=p.path[1],p.path[#p.path]
    local text=('#%d: %s\nShore A: %d,%d\nShore B: %d,%d\nBlocks: %d/%d\nBuild time: %d days\nOwner: %s'):format(p.id,p.state,a.x,a.y,b.x,b.y,p.supplied_blocks,p.required_blocks,p.duration_ticks/1200,e.owner_site_id==env.site_id and 'this fortress' or ('site '..e.owner_site_id))
    self.subviews.project_detail:setText(text)
end
function WorldBridgeWindow:selectedFundingProject()
    local _,choice=self.subviews.projects:getSelected()
    if choice and choice.data.owner_site_id==env.site_id and choice.data.project.state=='funding' then return choice.data.project end
end
function WorldBridgeWindow:selectedCompletedProject()
    local _,choice=self.subviews.projects:getSelected()
    if choice and choice.data.project.state=='complete' then return choice.data.project end
end
function WorldBridgeWindow:selectedOwnedProject()
    local _,choice=self.subviews.projects:getSelected()
    if choice and choice.data.owner_site_id==env.site_id then return choice.data.project end
end
function WorldBridgeWindow:removeProject()
    local p=self:selectedOwnedProject()
    if not p then return end
    local ok,preview=pcall(removal.preview,env,p.id)
    if not ok then show_error(preview);return end
    p=preview.project
    local completed=p.state=='complete'
    dialogs.showYesNoPrompt(completed and 'Remove bridge' or 'Cancel project',removal.summary(preview),COLOR_WHITE,function()
        local removed,err=pcall(removal.run,env,p.id,p.state,p.supplied_blocks)
        if not removed then show_error(err);return end
        self:refreshProjects()
        self:clearSelection()
        self:setMessage(completed and 'Bridge removed. Its route can be planned again.' or 'Project canceled.')
    end)
end
function WorldBridgeWindow:buildLocalDeck()
    local p=self:selectedCompletedProject();if not p then return end
    local local_build=require('world-bridge.local-construction')
    local ok,preview=pcall(local_build.preview,env,p)
    if not ok then show_error(preview);return end
    if preview.empty then dialogs.showMessage('Local deck','This bridge does not cross the loaded fortress map.',COLOR_WHITE);return end
    if preview.existing then dialogs.showMessage('Local deck','The local deck is already present and verified.',COLOR_WHITE);return end
    local plan=preview.plan
    dialogs.showYesNoPrompt('Build local deck',('%d deck tiles and %d pillar tiles will be placed.\nDry shore approaches: %d (%d stair tiles).\n%d natural floor bases will be replaced.\nWater will be displaced in %d tiles; source flags are preserved.\nBuild this section of the completed bridge?'):format(#plan.deck,#plan.pillars,plan.approaches or 0,#(plan.stairs or {}),plan.replaced_floors,plan.displaced_water),COLOR_WHITE,function()
        local built,result=pcall(local_build.build,env,p,preview.entry.deck_z)
        if not built then show_error(result);return end
        dialogs.showMessage('Local deck','Construction committed. The game is paused.',COLOR_WHITE)
    end)
end
function WorldBridgeWindow:deliverBlocks()
    local p=self:selectedFundingProject();if not p then return end
    local remaining=p.required_blocks-p.supplied_blocks
    local available=#materials.select(env.delivery.items,env.delivery.block_type,remaining)
    dialogs.showInputPrompt('Deliver blocks',('Eligible ground blocks available: %d\nBlocks still required: %d\nHow many should be consumed?'):format(available,remaining),COLOR_WHITE,tostring(math.min(available,remaining)),function(text)
        local count=tonumber(text)
        if not count or count<1 or count~=math.floor(count) then show_error('Enter a positive whole number.');return end
        local ok,n,left=pcall(service.deliver,env,p.id,count)
        if not ok then show_error(n);return end
        self:refreshProjects(p.id)
        dialogs.showMessage('Blocks delivered',('%d blocks consumed. %d still required.'):format(n,left),COLOR_WHITE)
    end)
end
function WorldBridgeWindow:toggleRouting()
    dfhack.run_script('world-bridge','experiment-auto',runtime.is_automatic_enabled() and 'off' or 'on')
end
function WorldBridgeWindow:toggleLocalDecks()
    local sync=require('world-bridge.local-sync')
    dfhack.run_script('world-bridge','local-decks',sync.enabled(env.persistent) and 'off' or 'on')
end
function WorldBridgeWindow:toggleTradeLinks()
    dfhack.run_script('world-bridge','trade-access',runtime.is_trade_enabled() and runtime.is_active() and 'off' or 'on')
end

WorldBridgeScreen=defclass(WorldBridgeScreen,gui.ZScreen)
WorldBridgeScreen.ATTRS{focus_path='world-bridge',defocusable=false,pass_mouse_clicks=false,pass_movement_keys=false,force_pause=true,world_screen=DEFAULT_NIL}
function WorldBridgeScreen:init()
    self:addviews{
        WorldBridgeWindow{view_id='window',world_screen=self.world_screen},
        widgets.Panel{frame={l=1,t=1,r=50,h=6},frame_style=gui.FRAME_MEDIUM,frame_background=gui.CLEAR_PEN,no_force_pause_badge=true,
            subviews={widgets.Label{frame={l=1,t=0},text={
                'Click land on each shore to preview.',NEWLINE,
                'W/A/S/D, arrows or middle drag: pan',NEWLINE,
                'A/B: shores | +: preview | =: project',NEWLINE,
                'Create a project, then deliver blocks.',
            }}}},
    }
end
function WorldBridgeScreen:liveWorld()
    local s=dfhack.gui.getDFViewscreen(true)
    return dfhack.isMapLoaded() and df.global.plotinfo.site_id==env.site_id and
        s==self.world_screen and s._type==df.viewscreen_worldst and s.view_mode==df.world_view_mode_type.NORMAL
end
function WorldBridgeScreen:panTo(x,y)
    pan_to(self.world_screen,x,y)
end
function WorldBridgeScreen:worldAtMouse()
    if self:isMouseOver() then return end
    local g=df.global.gps;local port=g.main_map_port
    if not port or not port.flag.active then return end
    return coordinates.pick(port,{x=self.world_screen.region_cent_x,y=self.world_screen.region_cent_y},
        {width=env.world.world_width,height=env.world.world_height},g.precise_mouse_x,g.precise_mouse_y)
end
function WorldBridgeScreen:onInput(keys)
    if not self:liveWorld() then self:dismiss();return true end
    if keys.LEAVESCREEN or keys._MOUSE_R then self:dismiss();return true end
    local moves={CUSTOM_W={0,-4},CUSTOM_A={-4,0},CUSTOM_S={0,4},CUSTOM_D={4,0}}
    if not self.subviews.window:getMouseFramePos() then
        moves.CURSOR_UP={0,-4};moves.CURSOR_LEFT={-4,0};moves.CURSOR_DOWN={0,4};moves.CURSOR_RIGHT={4,0}
    end
    for k,d in pairs(moves) do if keys[k] then
        self.drag=nil;self:panTo(self.world_screen.region_cent_x+d[1],self.world_screen.region_cent_y+d[2]);return true
    end end
    if gui.Screen.onInput(self,keys) then return true end
    local x,y=self:worldAtMouse()
    if x and keys._MOUSE_L then self.subviews.window:selectShore(x,y)
    elseif x and keys._MOUSE_M then
        local g=df.global.gps
        self.drag={px=g.precise_mouse_x,py=g.precise_mouse_y,x=self.world_screen.region_cent_x,y=self.world_screen.region_cent_y}
    end
    return true
end
function WorldBridgeScreen:onIdle()
    WorldBridgeScreen.super.onIdle(self)
    if not self:liveWorld() then self:dismiss();return end
    if self.drag then
        local g,e=df.global.gps,df.global.enabler
        if e.mouse_mbut_down==0 or not e.mouse_focus or not self:hasFocus() then self.drag=nil
        else self:panTo(self.drag.x+math.floor((self.drag.px-g.precise_mouse_x)/16+.5),
            self.drag.y+math.floor((self.drag.py-g.precise_mouse_y)/16+.5)) end
    end
    native.without_mouse(function()self.world_screen:logic()end)
end
function WorldBridgeScreen:render(dc)
    if not self:liveWorld() then self:dismiss();return end
    native.without_mouse(function()self:renderParent()end)
    local g=df.global.gps;local port=g.main_map_port;local c=self.subviews.window
    if port and port.flag.active and g.tile_pixel_x>0 and g.tile_pixel_y>0 then
        local center={x=self.world_screen.region_cent_x,y=self.world_screen.region_cent_y}
        local function mark(x,y,ch,color)
            local px,py=coordinates.pixel(port,center,x,y)
            if px then dc:seek(math.floor(px/g.tile_pixel_x),math.floor(py/g.tile_pixel_y)):char(ch,{fg=color,keep_lower=true}) end
        end
        for _,t in pairs(c.existing) do mark(t.x,t.y,'=',t.state=='complete' and COLOR_LIGHTGREEN or COLOR_BROWN) end
        if c.preview then for _,t in ipairs(c.preview.path) do mark(t.x,t.y,'+',COLOR_YELLOW) end end
        if c.shore_a then mark(c.shore_a.x,c.shore_a.y,'A',COLOR_WHITE) end
        if c.shore_b then mark(c.shore_b.x,c.shore_b.y,'B',COLOR_WHITE) end
    end
    gui.Screen.render(self,dc)
end
function WorldBridgeScreen:onDismiss()view=nil end
if dfhack_flags.module then return end
if view and view:isActive() then view:raise();return end
launch_generation=(launch_generation or 0)+1
local generation=launch_generation
local screen=dfhack.gui.getDFViewscreen(true)
if screen and screen._type==df.viewscreen_dwarfmodest then
    if dfhack.gui.getCurViewscreen(true)~=screen then qerror('Close other DFHack windows before opening the bridge planner.') end
    gui.simulateInput(screen,'D_WORLD')
    screen=dfhack.gui.getDFViewscreen(true)
end
if not screen or screen._type~=df.viewscreen_worldst or screen.view_mode~=df.world_view_mode_type.NORMAL then
    qerror('Open the normal fortress world map, then run world-bridge.')
end
local top=dfhack.gui.getCurViewscreen(true)
local guard=dfhack.script_environment('gui/world-bridge-guard').view
if top~=screen and (not guard or top~=guard._native) then
    qerror('Close other DFHack windows before opening the bridge planner.')
end
local function show_when_ready()
    if generation~=launch_generation or not dfhack.isMapLoaded() or df.global.plotinfo.site_id~=env.site_id or
        dfhack.gui.getDFViewscreen(true)~=screen then return end
    -- Let the player read and close native help before covering the map.
    if df.global.game.main_interface.help.open then dfhack.timeout(1,'frames',show_when_ready);return end
    local current=dfhack.gui.getCurViewscreen(true)
    local live_guard=dfhack.script_environment('gui/world-bridge-guard').view
    if current~=screen and (not live_guard or current~=live_guard._native) then return end
    view=WorldBridgeScreen{world_screen=screen}:show()
end
show_when_ready()
