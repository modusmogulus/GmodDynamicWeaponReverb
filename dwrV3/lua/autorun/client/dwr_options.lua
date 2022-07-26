
local function dwrClientSettings(Panel)
    Panel:NumSlider("Addon volume", "cl_dwr_volume", 0, 100)
    Panel:NumSlider("Sound speed", "cl_dwr_soundspeed", 0, 1000)
    --Panel:CheckBox("Disable distance checks for VR", "cl_vr_disable_distance_checks", true, false)
    Panel:CheckBox("Disable soundspeed", "cl_dwr_disable_soundspeed", true, false)
    Panel:CheckBox("Disable indoors reverb", "cl_dwr_disable_indoors_reverb", true, false)
    Panel:CheckBox("Disable outdoors reverb", "cl_dwr_disable_outdoors_reverb", true, false)
    Panel:CheckBox("Disable all reverb", "cl_dwr_disable_reverb", true, false)
end

hook.Add("PopulateToolMenu", "dwr_clientsettings", function() 
    spawnmenu.AddToolMenuOption("Options", "DWR V3", "DWRClientSettings", "Client Settings", "", "", dwrClientSettings, {} )
end)
