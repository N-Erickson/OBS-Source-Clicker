-- OBS Studio Lua Script - Simple Auto-Click with Sleep

obs = obslua

-- Configuration
local browser_source_name = "DowntownCamera"
local target_scene_name = "Modern1 Radar"
local current_scene = ""

function script_description()
    return "Clicks browser source when switching to target scene (no timers)"
end

function sleep(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do
        -- busy wait
    end
end

function click_source()
    local source = obs.obs_get_source_by_name(browser_source_name)
    if source then
        local width = obs.obs_source_get_width(source)
        local height = obs.obs_source_get_height(source)
        
        local event = obs.obs_mouse_event()
        event.modifiers = 0
        event.x = width / 2
        event.y = height / 2
        
        print("[AutoClick] Clicking at: " .. event.x .. ", " .. event.y)
        
        -- First click
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, true, 1)
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, false, 0)
        
        -- Wait 500ms
        sleep(0.5)
        
        -- Second click
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, true, 1)
        obs.obs_source_send_mouse_click(source, event, obs.MOUSE_LEFT, false, 0)
        
        obs.obs_source_release(source)
        print("[AutoClick] Double-click complete")
    end
end

function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        local scene = obs.obs_frontend_get_current_scene()
        if scene then
            local name = obs.obs_source_get_name(scene)
            obs.obs_source_release(scene)
            
            -- Only act when switching TO the target scene
            if name == target_scene_name and current_scene ~= target_scene_name then
                print("[AutoClick] Switched to target scene")
                current_scene = name
                
                -- Wait 5 seconds
                sleep(5)
                
                -- Do the clicks
                click_source()
            else
                current_scene = name
            end
        end
    end
end

function test_click(pressed)
    if pressed then
        click_source()
    end
end

function script_properties()
    local props = obs.obs_properties_create()
    
    obs.obs_properties_add_text(props, "scene", "Target Scene", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "source", "Browser Source", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_button(props, "test", "Test Click", test_click)
    
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "scene", "Modern1 Radar")
    obs.obs_data_set_default_string(settings, "source", "DowntownCamera")
end

function script_update(settings)
    target_scene_name = obs.obs_data_get_string(settings, "scene")
    browser_source_name = obs.obs_data_get_string(settings, "source")
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event)
end
