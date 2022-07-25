
local function dwr_serversettings(Panel)

    if LocalPlayer():IsAdmin() == false then return end

    Panel:NumSlider("Addon volume", "sv_dwr_volume", 0, 100)
    Panel:NumSlider("Sound speed", "sv_dwr_soundspeed", 0, 1000)
    --Panel:CheckBox("Disable distance checks for VR", "sv_vr_disable_distance_checks", true, false)
    Panel:CheckBox("Disable soundspeed", "sv_dwr_disable_soundspeed", true, false)
    Panel:CheckBox("Disable indoors reverb", "sv_dwr_disable_indoors_reverb", true, false)
    Panel:CheckBox("Disable outdoors reverb", "sv_dwr_disable_outdoors_reverb", true, false)
    Panel:CheckBox("Disable all reverb", "sv_dwr_disable_reverb", true, false)
end

local function dwr_clientsettings(Panel)
	Panel:AddControl("Header", {description = "Client Settings"})
end

function init_settings()
	spawnmenu.AddToolMenuOption("Options", "DWR V3", "DWRServerSettings", "Server Settings", "", "", dwr_serversettings, {} )
    spawnmenu.AddToolMenuOption("Options", "DWR V3", "DWRClientSettings", "Client Settings", "", "", dwr_clientsettings, {} )
end
hook.Add("PopulateToolMenu", "dwr_serversettings", init_settings)
hook.Add("PopulateToolMenu", "dwr_clientsettings", init_settings)
