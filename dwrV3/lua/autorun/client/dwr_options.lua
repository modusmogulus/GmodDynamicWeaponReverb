
local function dwr_serversettings(Panel)
	Panel:AddControl("Header", {description = "Server Settings"})
    Panel:AddControl("Slider", {Label = "Global volume", min=0, max=100, Command = "sv_dwr_volume"})
    Panel:AddControl("CheckBox", {Label = "VR-Support/Disable distance checks when in VR", "sv_vr_disable_distance_checks"}) --for future, will be combined with vrmod.IsPlayerInVR( player )
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
