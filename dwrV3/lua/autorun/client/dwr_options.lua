
local function dwrClientSettings(Panel)
    Panel:NumSlider("Reverb volume", "cl_dwr_volume", 0, 100)
    Panel:NumSlider("Sound speed", "cl_dwr_soundspeed", 0, 100000)
    Panel:NumSlider("Sound Occlusion rays", "cl_dwr_occlusion_rays", 4, 64, 0)
    Panel:NumSlider("Reflections per sound occlusion ray", "cl_dwr_occlusion_rays_reflections", 0, 4, 0)
    Panel:NumSlider("Total maximum ray distance", "cl_dwr_occlusion_rays_max_distance", 0, 100000, 0)

    Panel:CheckBox("Disable sound speed delay", "cl_dwr_disable_soundspeed", true, false)
    Panel:CheckBox("Disable indoors reverb", "cl_dwr_disable_indoors_reverb", true, false)
    Panel:CheckBox("Disable outdoors reverb", "cl_dwr_disable_outdoors_reverb", true, false)
    Panel:CheckBox("Disable all reverb", "cl_dwr_disable_reverb", true, false)
    Panel:CheckBox("Process every(almost) sound", "cl_dwr_process_everything", true, false)
    Panel:CheckBox("Disable bullet cracks", "cl_dwr_disable_bulletcracks", true, false)
end

hook.Add("PopulateToolMenu", "dwr_clientsettings", function() 
    spawnmenu.AddToolMenuOption("Options", "DWR V3", "DWRClientSettings", "Client Settings", "", "", dwrClientSettings, {} )
end)