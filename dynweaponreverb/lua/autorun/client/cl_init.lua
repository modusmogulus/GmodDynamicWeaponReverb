--basic tails
local tailnear = "distaudio/guntail_oldfar.wav"
local tailveryfar = "distaudio/clapper2_veryfar.wav"
local tailflat = "distaudio/explosion_far.wav"
local tailveryveryfar = "distaudio/clapper2_veryveryfar.wav"
local tailsuperfar = "distaudio/clapper2_superfar.wav"
local mediumtails = {"distaudio/clapper2_flat.wav", "distaudio/clapper2_medium.wav" }
local volume = 1.0
local volumeconvar = NULL
local localp = LocalPlayer()
CreateConVar( "za_volume", 1.0, FCVAR_REPLICATED)

--SETTINGS

hook.Add( "AddToolMenuCategories", "ReverbCategory", function()
    
    if ConVarExists( "za_volume" ) then
        print("convar za_volume exists")
        volumeconvar = GetConVar("za_volume")
        volume = volumeconvar:GetFloat()
    end
	spawnmenu.AddToolCategory( "Utilities", "DynamicWeaponReverb", "#Dynamic Weapon Reverb" )

end )

local function UnmuteCurrentWeapon()
    
    
    net.Start( "removeIgnoreSWEP" )
    if LocalPlayer():GetActiveWeapon():GetClass() != NULL then
        net.WriteString(tostring(localp:GetActiveWeapon():GetClass()))
        net.SendToServer()
    end
end


local function MuteCurrentWeapon()
    
    
    net.Start( "addIgnoreSWEP" )
    if LocalPlayer():GetActiveWeapon():GetClass() != NULL == true then
        net.WriteString(tostring(localp:GetActiveWeapon():GetClass()))
        net.SendToServer()
    end
end



hook.Add( "PopulateToolMenu", "DynreverbSettings", function()
	spawnmenu.AddToolMenuOption( "Utilities", "DynamicWeaponReverb", "menu_weapon_reverb", "#Weapon reverb world settings", "a", "a", function( panel )
		panel:ClearControls()
		panel:CheckBox( "Enable weapon reverb tails", "za_enable_reverb", true, false )
		panel:CheckBox( "Distance gunfire", "za_server_distance_shots", true, false )
		panel:CheckBox( "Enable outdoor reverb tails", "za_outdoors_tail", true, false )
		panel:CheckBox( "Enable indoors reverb tails", "za_indoors_tail", true, false )
		panel:CheckBox( "Only allow one instance of every weapon reverb tail (sounds worse but works better for some high firerate weapons)", "za_oneinstance", true, false )
        
        local volumeslider = panel:NumSlider( "Volume (wont affect distance gunfire)", "za_volume", 0.0, 1.0)
        
        volumeslider.OnValueChanged = function( panel, value )
            net.Start("setServerDynreverbVolumeSliderValue") --sending the volumeslider value to server so the server can set the volume convar
            net.WriteFloat(value)
            net.SendToServer()
        end
        
        panel:Help("Mute settings can't be saved yet but saving will be added in future")

        local ignorebutton = panel:Button( "Mute dynamic reverb for current weapon (experimental)" )
            
        ignorebutton.DoClick = function()
            if(localp:IsAdmin() == true) then
                MuteCurrentWeapon()
            end
        end

        local unignorebutton = panel:Button( "Unmute dynamic reverb for current weapon (experimental)" )

        unignorebutton.DoClick = function()
            if(localp:IsAdmin() == true) then
                UnmuteCurrentWeapon()    
            end
       
        end

	end )
end)



--   DISTANCE SOUND STUFF --


net.Receive( "playSoundToClient", function()
    
    local localear = LocalPlayer():GetViewEntity() --more like eyes but you cant hear with eyes can you
    local listenerdistance = localp:GetNWInt( 'listenerdistance', 0 )
    if (listenerdistance < 200) then
        localear:EmitSound(tailnear, 70, 100, 1, CHAN_STATIC )
        localear:EmitSound(tailflat, 70, 180, 0.2, CHAN_STATIC )
    end
    
    if (listenerdistance < 3000 && listenerdistance  > 200) then
        localear:EmitSound(mediumtails[ math.random( #mediumtails )], 70, 95, 0.1, CHAN_STATIC )
        localear:EmitSound(tailflat, 70, 130, 0.2, CHAN_STATIC )
    end

    if(listenerdistance < 8000 && listenerdistance  > 3000) then
        localear:EmitSound(tailveryfar, 70, 100, 1, CHAN_STATIC )
        localear:EmitSound(tailflat, 70, 110, 0.2, CHAN_STATIC )
    end

    if (listenerdistance > 8000 && listenerdistance  < 10000) then
        localear:EmitSound(tailveryveryfar, 70, 100, 0.3, CHAN_STATIC )
    end

    if (listenerdistance > 10000 && listenerdistance < 30000) then
        localear:EmitSound(tailveryveryfar, 70, 80, 0.2, CHAN_STATIC )
    end
end )