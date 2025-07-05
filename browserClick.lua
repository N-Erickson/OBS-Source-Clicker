-- OBS Studio Lua Script for Auto-Clicking Browser Source
-- Only active when specific scene is active
-- Save as autoclick-browser-source.lua
-- Tools → Scripts → Add this script

obs = obslua

-- Configuration
browser_source_name = "Downtown Camera"  -- Change this to your browser source name
target_scene_name = "Camera Scene"  -- Only active when this scene is active
click_delay = 5000  -- Delay before clicking (increased to 5 seconds)
refresh_interval = 5 * 60 * 1000  -- 5 minutes
click_positions = 3  -- Number of different positions to try

-- Global variables
local timer_refresh = nil
local is_active = false
local current_scene = nil

function script_description()
    return [[Auto-clicks play button in browser source when specific scene is active.
    
Only runs when the target scene is active and stops when switching to other scenes.]]
end

function script_properties()
    local props = obs.obs_properties_create()
    
    -- Source selector
    local source_prop = obs.obs_properties_add_list(props, "source_name", "Browser Source", 
                                                   obs.OBS_COMBO_TYPE_EDITABLE,
                                                   obs.OBS_COMBO_FORMAT_STRING)
    
    -- Scene selector
    local scene_prop = obs.obs_properties_add_list(props, "scene_name", "Target Scene", 
                                                  obs.OBS_COMBO_TYPE_EDITABLE,
                                                  obs.OBS_COMBO_FORMAT_STRING)
    
    -- Populate source list
    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_id(source)
            if source_id == "browser_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(source_prop, name, name)
            end
        end
        obs.source_list_release(sources)
    end
    
    -- Populate scene list
    local scenes = obs.obs_frontend_get_scenes()
    if scenes then
        for _, scene in ipairs(scenes) do
            local name = obs.obs_source_get_name(scene)
            obs.obs_property_list_add_string(scene_prop, name, name)
        end
        obs.source_list_release(scenes)
    end
    
    obs.obs_properties_add_int(props, "click_delay", "Initial Click Delay (ms)", 3000, 10000, 500)
    obs.obs_properties_add_int(props, "refresh_mins", "Refresh Interval (minutes)", 1, 60, 1)
    obs.obs_properties_add_bool(props, "debug_mode", "Debug Mode (print logs)")
    
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "source_name", browser_source_name)
    obs.obs_data_set_default_string(settings, "scene_name", target_scene_name)
    obs.obs_data_set_default_int(settings, "click_delay", 5000)
    obs.obs_data_set_default_int(settings, "refresh_mins", 5)
    obs.obs_data_set_default_bool(settings, "debug_mode", false)
end

function script_update(settings)
    browser_source_name = obs.obs_data_get_string(settings, "source_name")
    target_scene_name = obs.obs_data_get_string(settings, "scene_name")
    click_delay = obs.obs_data_get_int(settings, "click_delay")
    refresh_interval = obs.obs_data_get_int(settings, "refresh_mins") * 60 * 1000
    debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
end

function log(message)
    if debug_mode then
        print("[AutoClick] " .. message)
    end
end

function send_mouse_click(source, x_ratio, y_ratio)
    if source ~= nil then
        local width = obs.obs_source_get_width(source)
        local height = obs.obs_source_get_height(source)
        
        local event = obs.obs_mouse_event()
        event.modifiers = 0
        event.x = width * x_ratio
        event.y = height * y_ratio
        
        -- Send mouse down and up events
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, true, 1)
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, false, 0)
        
        log(string.format("Clicked at: %.0f, %.0f", event.x, event.y))
    end
end

function click_play_button()
    if not is_active then
        log("Not active, skipping click")
        return
    end
    
    local source = obs.obs_get_source_by_name(browser_source_name)
    if source ~= nil then
        log("Clicking play button on: " .. browser_source_name)
        
        -- Try multiple click positions with delays
        send_mouse_click(source, 0.5, 0.5)  -- Center
        
        obs.timer_add(function()
            if is_active then
                send_mouse_click(source, 0.5, 0.8)  -- Bottom center
            end
            obs.timer_remove(click_bottom)
        end, 500)
        
        obs.timer_add(function()
            if is_active then
                send_mouse_click(source, 0.5, 0.9)  -- Very bottom
            end
            obs.timer_remove(click_very_bottom)
        end, 1000)
        
        obs.obs_source_release(source)
    else
        log("Browser source not found: " .. browser_source_name)
    end
end

function refresh_browser_source()
    if not is_active then
        log("Not active, skipping refresh")
        return
    end
    
    local source = obs.obs_get_source_by_name(browser_source_name)
    if source ~= nil then
        local settings = obs.obs_source_get_settings(source)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
        
        log("Browser source refreshed")
        
        -- Click play button after refresh
        obs.timer_add(function()
            click_play_button()
            obs.timer_remove(click_after_refresh)
        end, click_delay)
    end
end

function start_automation()
    if is_active then
        return  -- Already active
    end
    
    is_active = true
    log("Starting automation for scene: " .. target_scene_name)
    
    -- Initial click after delay
    obs.timer_add(function()
        click_play_button()
        obs.timer_remove(initial_click)
    end, click_delay)
    
    -- Start refresh timer
    if timer_refresh ~= nil then
        obs.timer_remove(timer_refresh)
    end
    timer_refresh = obs.timer_add(refresh_browser_source, refresh_interval)
end

function stop_automation()
    if not is_active then
        return  -- Already stopped
    end
    
    is_active = false
    log("Stopping automation")
    
    -- Stop refresh timer
    if timer_refresh ~= nil then
        obs.timer_remove(timer_refresh)
        timer_refresh = nil
    end
end

function on_scene_change()
    local scene = obs.obs_frontend_get_current_scene()
    if scene ~= nil then
        local scene_name = obs.obs_source_get_name(scene)
        obs.obs_source_release(scene)
        
        if scene_name == target_scene_name then
            log("Target scene activated: " .. scene_name)
            start_automation()
        else
            log("Different scene activated: " .. scene_name)
            stop_automation()
        end
        
        current_scene = scene_name
    end
end

function script_load(settings)
    log("Script loaded")
    
    -- Connect to scene change events
    obs.obs_frontend_add_event_callback(function(event)
        if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
            on_scene_change()
        elseif event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
            -- Check initial scene
            on_scene_change()
        end
    end)
end

function script_unload()
    log("Script unloading")
    stop_automation()
end
