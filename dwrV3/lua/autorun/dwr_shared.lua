-- Automatically generated by update_precache_list.py
-- Please don't change anything here and instead refer to the script in question.
print("[DWRV3] Shared loaded.")

dwr_reverbFiles = {'dwr/357/indoors/close/1.wav', 'dwr/357/indoors/close/2.wav', 'dwr/357/indoors/distant/1.wav', 'dwr/357/indoors/distant/2.wav', 'dwr/357/outdoors/close/1.wav', 'dwr/357/outdoors/close/2.wav', 'dwr/357/outdoors/distant/1.wav', 'dwr/357/outdoors/distant/2.wav', 'dwr/AR2/indoors/close/1.wav', 'dwr/AR2/indoors/close/2.wav', 'dwr/AR2/indoors/distant/1.wav', 'dwr/AR2/indoors/distant/2.wav', 'dwr/AR2/outdoors/close/1.wav', 'dwr/AR2/outdoors/close/2.wav', 'dwr/AR2/outdoors/distant/1.wav', 'dwr/AR2/outdoors/distant/2.wav', 'dwr/Buckshot/indoors/close/1.wav', 'dwr/Buckshot/indoors/close/2.wav', 'dwr/Buckshot/indoors/distant/1.wav', 'dwr/Buckshot/indoors/distant/2.wav', 'dwr/Buckshot/outdoors/close/1.wav', 'dwr/Buckshot/outdoors/close/2.wav', 'dwr/Buckshot/outdoors/distant/1.wav', 'dwr/Buckshot/outdoors/distant/2.wav', 'dwr/Explosions/indoors/close/1.wav', 'dwr/Explosions/indoors/close/2.wav', 'dwr/Explosions/indoors/distant/1.wav', 'dwr/Explosions/indoors/distant/2.wav', 'dwr/Explosions/outdoors/close/1.wav', 'dwr/Explosions/outdoors/close/2.wav', 'dwr/Explosions/outdoors/distant/1.wav', 'dwr/Explosions/outdoors/distant/2.wav', 'dwr/Other/indoors/close/1.wav', 'dwr/Other/indoors/close/2.wav', 'dwr/Other/indoors/distant/1.wav', 'dwr/Other/indoors/distant/2.wav', 'dwr/Other/outdoors/close/1.wav', 'dwr/Other/outdoors/close/2.wav', 'dwr/Other/outdoors/distant/1.wav', 'dwr/Other/outdoors/distant/2.wav', 'dwr/Pistol/indoors/close/1.wav', 'dwr/Pistol/indoors/close/2.wav', 'dwr/Pistol/indoors/distant/1.wav', 'dwr/Pistol/indoors/distant/2.wav', 'dwr/Pistol/outdoors/close/1.wav', 'dwr/Pistol/outdoors/close/2.wav', 'dwr/Pistol/outdoors/distant/1.wav', 'dwr/Pistol/outdoors/distant/2.wav', 'dwr/SMG1/indoors/close/1.wav', 'dwr/SMG1/indoors/close/2.wav', 'dwr/SMG1/indoors/distant/1.wav', 'dwr/SMG1/indoors/distant/2.wav', 'dwr/SMG1/outdoors/close/1.wav', 'dwr/SMG1/outdoors/close/2.wav', 'dwr/SMG1/outdoors/distant/1.wav', 'dwr/SMG1/outdoors/distant/2.wav'}
dwr_successfullyCached = false

hook.Add("InitPostEntity", "dwr_precache", function()
	for _, snd in pairs(dwr_reverbFiles) do
		util.PrecacheSound(dwr_reverbFiles)
	end
	dwr_successfullyCached = true
end)