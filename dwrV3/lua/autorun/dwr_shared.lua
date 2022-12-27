print("[DWRV3] Shared loaded.")

dwr_supportedAmmoTypes = {'357', 'ar2', 'buckshot', 'pistol', 'smg1'} -- there's also "other" and "explosions" in the sound directory but we use them differently

hook.Add("InitPostEntity", "dwr_precache", function()
	for _, snd in pairs(dwr_reverbFiles) do
		util.PrecacheSound(snd)
	end
end)
