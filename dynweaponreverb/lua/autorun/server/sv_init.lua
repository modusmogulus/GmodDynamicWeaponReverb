resource.AddFile("sound/distaudio/clapper2_near22khz.wav")
resource.AddFile("sound/distaudio/clapper2_veryveryfar.wav")
resource.AddFile("sound/distaudio/clapper2_superfar.wav")
resource.AddFile("sound/distaudio/clapper2_veryfar.wav")
resource.AddFile("sound/distaudio/clapper2_flat.wav")
resource.AddFile("sound/distaudio/explosion_far.wav")
resource.AddFile("sound/distaudio/guntail_oldfar.wav")

resource.AddFile("distaudio/clienttail_urban5.wav")
resource.AddFile("distaudio/clienttail_urban6.wav")

resource.AddFile("distaudio/hho_explosion_indoors9.wav")
resource.AddFile("distaudio/clienttail_roomlarge3.wav")
resource.AddFile("distaudio/underwater_shot10.wav")


resource.AddFile("distaudio/exp_lpg_4_44khz.wav")
resource.AddFile("distaudio/exp_lpg_6_44khz.wav")
resource.AddFile("distaudio/exp_lpg_8_44khz.wav")
resource.AddFile("distaudio/exp_lpg_10_44khz.wav")
resource.AddFile("distaudio/exp_lpg_11_44khz.wav")

--convars
CreateConVar( "za_enable_reverb", "1", true, false)
CreateConVar( "za_volume", 0.8, FCVAR_REPLICATED )

CreateConVar( "za_server_distance_shots", "1", true, false)
CreateConVar( "za_outdoors_tail", "1", true, false)
CreateConVar( "za_indoors_tail", "1", true, false)

CreateConVar( "za_oneinstance", "0", true, false)

util.AddNetworkString("playSoundToClient")
util.AddNetworkString("addIgnoreSWEP")
util.AddNetworkString("removeIgnoreSWEP")
util.AddNetworkString("setServerDynreverbVolumeSliderValue")


function printTable(tab) -- for debug
	--print("-------------table contains----------------")
	for i, v in ipairs(tab) do
		--print(tostring(v))
	end
	--print("-------------------------------------------")
end


function removekey(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            tab[index] = nil
        end
    end
end


function saveMuteData()
	local JSONData = util.TableToJSON(swepstoignoreND)
	file.Write("dynweaponreverbdata.json", JSONData)
end

function loadMuteData()
	local JSONData = file.Read("dynweaponreverbdata.json")
	sharedfile.swepstoignoreND = util.JSONToTable(JSONData)
	PrintTable(util.JSONToTable(JSONData))
end




net.Receive( "addIgnoreSWEP", function(len, pl)

	if(pl:IsAdmin() == true) then

		local receivedWeaponName = net.ReadString("addIgnoreSWEP") --read string can only be used once (otherwise empty) so it should be written into a variable
		table.insert(swepstoignoreND, receivedWeaponName)
		
		saveMuteData()

	end
end )

net.Receive( "removeIgnoreSWEP", function(len, pl)
	if(pl:IsAdmin() == true) then

		local receivedWeaponName = net.ReadString("addIgnoreSWEP")
		removekey(swepstoignoreND, receivedWeaponName)

		saveMuteData()

	end
end )



net.Receive( "setServerDynreverbVolumeSliderValue", function(len, pl)
	if(pl:IsAdmin() == true) then
		
		RunConsoleCommand("za_volume", tostring(net.ReadFloat("setServerDynreverbVolumeSliderValue")))
	end
end )

