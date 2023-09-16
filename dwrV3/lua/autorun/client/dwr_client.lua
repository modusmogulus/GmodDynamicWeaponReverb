print("[DWRV3] Client loaded.")

local UNITS_TO_METERS = 0.01905 -- multiply by this value and voila

local MASK_GLOBAL = CONTENTS_WINDOW + CONTENTS_SOLID + CONTENTS_AREAPORTAL + CONTENTS_MONSTERCLIP + CONTENTS_CURRENT_0

local previousAmmo = 0
local previousWep = NULL

local blacklist = {}
local serverBlacklist = {}

if not file.Read("dwr_weapon_blacklist.json") or #file.Read("dwr_weapon_blacklist.json") == 0 then
	print("[DWRV3] Created the blacklist file.")
	file.Write("dwr_weapon_blacklist.json", util.TableToJSON({}))
else
	print("[DWRV3] Loaded the blacklist file.")
	blacklist = util.JSONToTable(file.Read("dwr_weapon_blacklist.json"))
end
-- start of functions

local function applySettingsToDSP(ply, cmd, args) 
	print("snd_pitchquality 1;")  
	print("snd_disable_mixer_duck 0;")  
	print("snd_surround_speakers 1;")  
	print("dsp_enhance_stereo 1;")  
	print("dsp_slow_cpu 0;")  
	print("snd_spatialize_roundrobin 0;")  
	print("dsp_room 1;")  
	print("dsp_water 14;")  
	print("dsp_spatial 40;")  
	print("snd_defer_trace 0")
end

concommand.Add("cl_dwr_show_dsp_settings", applySettingsToDSP, nil, "Show the best dsp/sound settings for better experience")

concommand.Add("cl_dwr_weaponclass", function() 
	print(LocalPlayer():GetActiveWeapon():GetClass())
end)

local function changeBlacklist(action)
	local weapon = LocalPlayer():GetActiveWeapon()
	if not IsValid(weapon) then print("Weapon invalid. Blacklist not affected!") return end
	local weaponClass = weapon:GetClass()

	local JSONData = file.Read("dwr_weapon_blacklist.json")
	local converted = util.JSONToTable(JSONData) or {}

	if action == "remove" then 
		print("Removed " .. weaponClass .. " from the blacklist.") 
		converted[weaponClass] = nil
	end

	if action == "add" then
		print("Added " .. weaponClass .. " to the blacklist.")
		converted[weaponClass] = true
	end

	if action == "clear" then 
		print("Blacklist cleared.") 
		converted = {}
	end

	blacklist = converted
	file.Write("dwr_weapon_blacklist.json", util.TableToJSON(blacklist))
end

local function removeWeaponFromBlacklist(ply, cmd, args)
	changeBlacklist("remove")
end
concommand.Add("cl_dwr_blacklist_remove", removeWeaponFromBlacklist, nil, "Remove your current weapon from the blacklist.")

local function addWeaponToBlacklist(ply, cmd, args)
	changeBlacklist("add")
end
concommand.Add("cl_dwr_blacklist_add", addWeaponToBlacklist, nil, "Blacklist your current weapon from being affected by this mod.")

local function clearBlacklist(ply, cmd, args)
	changeBlacklist("clear")
end
concommand.Add("cl_dwr_blacklist_clear", clearBlacklist, nil, "Clear the blacklist from anything and everything.")

net.Receive("dwr_sync_blacklist", function(len) 
	serverBlacklist = net.ReadTable()
end)

local function equalVector(vector1, vector2)
	return vector1:IsEqualTol(vector2, 2)
end

local function readVectorUncompressed()
	local tempVec = Vector(0,0,0)
	tempVec.x = net.ReadFloat()
	tempVec.y = net.ReadFloat()
	tempVec.z = net.ReadFloat()
	return tempVec
end

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_GLOBAL})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_GLOBAL}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob

    if temp.HitPos == pos and not temp.StartSolid and tr.HitSky then
    	return true
    end

    return false
end

local function getEarPos()
	local lp = LocalPlayer()
	local viewEntityPos = lp:GetViewEntity():GetPos()

	if not equalVector(viewEntityPos, lp:GetPos()) then return viewEntityPos end

	return lp:EyePos()
end

local function getOutdoorsState(pos)
    local tr_1 = traceableToSky(pos, Vector(0,0,0))
    local tr_2 = traceableToSky(pos, Vector(120,0,0))
    local tr_3 = traceableToSky(pos, Vector(0,120,0))
    local tr_4 = traceableToSky(pos, Vector(-120,0,0))
    local tr_5 = traceableToSky(pos, Vector(0,-120,0))
    return (tr_1 or tr_2 or tr_3 or tr_4 or tr_5)
end

local function getPositionState(pos)
	local state = getOutdoorsState(pos)
	if state then
		return "outdoors"
	else
		return "indoors"
	end
end

local function getDistanceState(pos1, pos2)
	local distance = pos1:Distance(pos2) * UNITS_TO_METERS -- meters l0l
	-- tweak this number later plz
	if distance > 150 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammotype)
	ammotype = string.lower(ammotype)
	if table.HasValue(dwr_supportedAmmoTypes, ammotype) then
		return ammotype
	elseif ammotype == "explosions" then
		return "explosions"
	else
		return "other"
	end
end

local function getEntriesStartingWith(pattern, array)
	local tempArray = {}
	pattern = string.lower(pattern)
	for _, path in ipairs(array) do
		path = string.lower(path)
		if string.StartWith(path, pattern) then
			table.insert(tempArray, path)
		end
	end
	if table.IsEmpty(tempArray) then
		print("[DWR] WTF. Nothing found??? Here's debug info!!!", pattern, table.ToString(dwr_reverbFiles, "debug", false))
		return {"dwr/kleiner.wav"}
	end
	return tempArray
end

local function reflectVector(pVector, normal)
	local dn = 2 * pVector:Dot(normal)
	return pVector - normal * dn
end

local function traceableToPos(earpos, pos, offset)
	local bounceLimit = GetConVar("cl_dwr_occlusion_rays_reflections"):GetInt()
	local lastTrace = {}
	local maxdistance = GetConVar("cl_dwr_occlusion_rays_max_distance"):GetInt()
	local totalDistance = 0

	earpos = earpos + Vector(0,0,10) -- just in case
	pos = pos + Vector(0,0,10) -- just in case

    local traceToOffset = util.TraceLine( {
        start = earpos,
        endpos = earpos + offset,
        mask = MASK_GLOBAL
    })

    totalDistance = traceToOffset.HitPos:Distance(traceToOffset.StartPos)

    lastTrace = traceToOffset

	for i=1,bounceLimit,1 do
	    local bounceTrace = util.TraceLine( {
	        start = lastTrace.HitPos,
	        endpos = lastTrace.HitPos + reflectVector(lastTrace.HitPos, lastTrace.Normal) * 1000000000,
	        mask = MASK_GLOBAL
	    })
	    if bounceTrace.StartSolid or bounceTrace.AllSolid then break end

	    totalDistance = totalDistance + bounceTrace.HitPos:Distance(bounceTrace.StartPos)
	    lastTrace = bounceTrace
	end

    local traceLastTraceToPos = util.TraceLine( {
        start = lastTrace.HitPos,
        endpos = pos,
        mask = MASK_GLOBAL
    })

    totalDistance = totalDistance + traceLastTraceToPos.HitPos:Distance(traceLastTraceToPos.StartPos)

    if totalDistance > maxdistance then return false end

    return (traceLastTraceToPos.HitPos == pos)
end

local function boolToInt(value)
	-- oh come on lua, fuck you.
  	return value and 1 or 0
end

local function inverted_boolToInt(value)
	-- oh come on lua, fuck you.
  	return value and 0 or 1
end

local function getOcclusionPercent(earpos, pos)
	local traceAmount = math.floor(GetConVar("cl_dwr_occlusion_rays"):GetInt()/4)
	local degrees = 360/traceAmount
	local successfulTraces = 0
	local failedTraces = 0

	for j=1, 4, 1 do
		local singletrace = Vector(100000000,0,0)
		local angle
		if j==1 then angle = Angle(degrees, 0)
		elseif j==2 then angle = Angle(degrees, degrees)
		elseif j==3 then angle = Angle(-degrees, degrees)
		elseif j==4 then angle = Angle(0, degrees) end
 		for i=1, traceAmount, 1 do
			singletrace:Rotate(angle)
			local traceToPos = traceableToPos(earpos, pos, singletrace)
			successfulTraces = successfulTraces + boolToInt(traceToPos)
			failedTraces = failedTraces + inverted_boolToInt(traceToPos)
		end
	end

	local percentageOfFailedTraces = failedTraces / (traceAmount * 4)

	return percentageOfFailedTraces
end

local function calculateDelay(distance, speed)
	if speed == 0 then return 0 end
	return distance/speed
end

local function playReverb(src, ammotype, isSuppressed, weapon)
	if GetConVar("cl_dwr_disable_reverb"):GetBool() == true then return end

	if weapon.dwr_reverbDisable then return end
		
	local earpos = getEarPos()
	local volume = weapon.dwr_customVolume or 1

	local positionState = getPositionState(src)
	local earpos_positionState = getPositionState(earpos)
	if GetConVar("cl_dwr_disable_indoors_reverb"):GetBool() == true && positionState == "indoors" then return end
	if GetConVar("cl_dwr_disable_outdoors_reverb"):GetBool() == true && positionState == "outdoors" then return end
	local distanceState = getDistanceState(src, earpos)
	ammotype = weapon.dwr_customAmmoType or formatAmmoType(ammotype)
	if weapon.dwr_customIsSuppressed != nil then isSuppressed = weapon.dwr_customIsSuppressed end


	if isSuppressed then volume = volume * 0.25 end

	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = math.random(94, 107)
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(src) * UNITS_TO_METERS -- in meters

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = src,
        mask = MASK_GLOBAL
    })

    local direct = equalVector(traceToSrc.HitPos, src)

    local occlusionPercentage = 0
    if not direct then
	    occlusionPercentage = getOcclusionPercent(earpos, src)
	    if positionState != "outdoors" or earpos_positionState != "outdoors" then
    		if occlusionPercentage == 1 then dsp = 30 end -- lowpass
    	end
		volume = volume * (1-math.Clamp(occlusionPercentage-0.5, 0, 0.5))
	end

	if distanceState == "close" then
		local distanceMultiplier = math.Clamp(5000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	elseif distanceState == "distant" then
		local distanceMultiplier = math.Clamp(10000/distance^2, 0, 1)
		if positionState == "outdoors" then
			volume = volume * distanceMultiplier * 2
		else
			volume = volume * distanceMultiplier * 0.5
		end
	end
	
	local soundspeed = GetConVar("cl_dwr_soundspeed"):GetFloat()

	// I slept bad
	local reverbQueue = {}
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammotype .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]
	table.insert(reverbQueue, reverbSoundFile)

	if earpos_positionState == "outdoors" and positionState == "indoors" and occlusionPercentage < 1 then
		local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammotype .. "/" .. earpos_positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
		local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]
		table.insert(reverbQueue, reverbSoundFile)
	end

	if GetConVar("cl_dwr_disable_soundspeed"):GetInt() == 1 then soundspeed = 0 end

	timer.Simple(calculateDelay(distance, soundspeed), function()
		for _, path in ipairs(reverbQueue) do
			local mult = 1
			if #reverbQueue > 1 and string.find(path, "/indoors/") then
				mult = 0.75
			elseif #reverbQueue > 1 then
				mult = 1.75
			end
			EmitSound(path, earpos, -2, CHAN_AUTO, volume * (GetConVar("cl_dwr_volume"):GetFloat() / 100) / #reverbQueue * mult, soundLevel, soundFlags, pitch, dsp)
		end
	end)
end

-- shamelessly pasted from arccw because math is hard
function calculateSpread(dir, spread)
    local radius = math.Rand(0, 1)
    local theta = math.Rand(0, math.rad(360))
    local bulletang = dir:Angle()
    local forward, right, up = bulletang:Forward(), bulletang:Right(), bulletang:Up()
    local x = radius * math.sin(theta)
    local y = radius * math.cos(theta)

    return (dir + right * spread.x * x + up * spread.y * y)
end

local function playBulletCrack(src, dir, vel, spread, ammotype, weapon)
	if GetConVar("cl_dwr_disable_bulletcracks"):GetInt() == 1 then return end
	if weapon.dwr_cracksDisable then return end

	local earpos = getEarPos()
    local distanceState = getDistanceState(src, earpos)
    local volume = 1
    local dsp = 0
	local soundLevel = 140
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = math.random(94, 107)

    local trajectory = util.TraceLine( {
        start = src,
        endpos = src + calculateSpread(dir, spread) * 10000000,
        mask = MASK_GLOBAL
    })

    distance, point, distanceToPointOnLine = util.DistanceToLine(trajectory.StartPos, trajectory.HitPos, earpos)
    if distance * UNITS_TO_METERS > 10 then return end -- I've read somewhere that you can hear bullet cracks even from 100 meters away. But for the scale sake I'll keep it lower.

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = point,
        mask = MASK_GLOBAL
    })

    local direct = equalVector(traceToSrc.HitPos, point)

    if not direct then
    	dsp = 30
	end

	local crackOptions = getEntriesStartingWith("dwr/" .. "bulletcracks/" .. distanceState .. "/", dwr_reverbFiles)
	local crackhead = ")" .. crackOptions[math.random(#crackOptions)] // ")" adds spatial support... not like it matters because we dont have an entity at that position so it doesnt fucking work.

	timer.Simple(calculateDelay(trajectory.StartPos:Distance(trajectory.HitPos), vel:Length()), function()
		EmitSound(crackhead, point, -1, CHAN_AUTO, volume * (GetConVar("cl_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
	end)
end

local function getSuppressed(weapon, weaponClass)
    if string.StartWith(weaponClass, "arccw_") and weapon:GetBuff_Override("Silencer") then return true
    elseif string.StartWith(weaponClass, "tfa_") and weapon:GetSilenced() then return true
    elseif string.StartWith(weaponClass, "mg_") or weaponClass == mg_valpha then
    	if not weapon.GetAllAttachmentsInUse then return false end
        for slot, attachment in pairs(weapon:GetAllAttachmentsInUse()) do
            if string.find(attachment.ClassName, "silence") or string.find(attachment.ClassName, "suppress") then return true end
        end
    elseif string.StartWith(weaponClass, "cw_") then
        if weapon.ActiveAttachments != nil then
            for k, v in pairs(weapon.ActiveAttachments) do
                if v == false then continue end
                local att = CustomizableWeaponry.registeredAttachmentsSKey[k]
                if att.isSuppressor then
                    return true
                end
            end
        end
    end

    return false
end

local function processSound(data, isweapon)
	local earpos = getEarPos()
	local src = data.Pos
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(src) * UNITS_TO_METERS -- in meters
	local volume = data.Volume

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = src,
        mask = MASK_GLOBAL
    })

    if not traceToSrc then return data end

    local direct = equalVector(traceToSrc.HitPos, src)

    if not direct then
	    local occlusionPercentage = getOcclusionPercent(earpos, src)
    	if occlusionPercentage == 1 then dsp = 30 end -- lowpass
		volume = volume * (1-math.Clamp(occlusionPercentage-0.5, 0, 0.5))
	end

	if not isweapon then
		if distanceState == "close" then
			local distanceMultiplier = math.Clamp(5000/distance^2, 0, 1)
			volume = volume * distanceMultiplier
		elseif distanceState == "distant" then
			local distanceMultiplier = math.Clamp(9000/distance^2, 0, 1)
			volume = volume * distanceMultiplier
		end
	end

	data.Volume = volume
	data.DSP = dsp
	return data
end

-- end of functions

-- start of main
net.Receive("dwr_EntityFireBullets_networked", function(len)
	-- we receive this only when someone else shoots inorder to eliminate any possibility of accessing serverside-only functions from the client.
	local src = readVectorUncompressed()
	local dir = readVectorUncompressed()
	local vel = readVectorUncompressed()
	local spread = readVectorUncompressed()
	local ammotype = net.ReadString()
	local isSuppressed = net.ReadBool()
	local entity = net.ReadEntity()
	--local override = net.ReadTable()
	local ignore = (entity == LocalPlayer())

	local weapon = {}
	if entity.GetActiveWeapon then
		weapon = entity:GetActiveWeapon()
		if not IsValid(weapon) then return end
		if blacklist[weapon:GetClass()] or serverBlacklist[weapon:GetClass()] then return end
	end

	if not game.SinglePlayer() and ignore then return end

	if not ignore then
		playBulletCrack(src, dir, vel, spread, ammotype, weapon)
	end
	
	playReverb(src, ammotype, isSuppressed, weapon)
end)

net.Receive("dwr_EntityEmitSound_networked", function(len)
	local data = net.ReadTable()
	if not data then return end
	data = processSound(data, true)
	if data.Entity == NULL then return end
	if not game.SinglePlayer() and data.Entity == LocalPlayer() then return end
	data.Entity:EmitSound(data.SoundName, data.SoundLevel, data.Pitch, data.Volume, CHAN_STATIC, data.Flags, data.DSP)
end)

if not game.SinglePlayer() then
	local function onPrimaryAttack(attacker, weapon)
        local weaponClass = weapon:GetClass()
		if blacklist[weaponClass] or serverBlacklist[weaponClass] then return end
        if weaponClass == "mg_arrow" then return end -- mw2019 sweps crossbow

		local earpos = getEarPos()
	    local entity = attacker
        local isSuppressed = getSuppressed(weapon, weaponClass)
        local entityShootPos = entity:GetShootPos()

	    local ammotype_num = weapon:GetPrimaryAmmoType()
	    local ammotype = "unknown"
        if ammotype_num != -1 then
        	ammotype = game.GetAmmoName(ammotype_num) 
        end
        if (ammotype == "unknown" or #ammotype < 2) and weapon.Primary then
        	ammotype = weapon.Primary.Ammo
        end

		playReverb(entityShootPos, ammotype, isSuppressed, weapon)
	end

	hook.Add("Think", "dwr_detect_primary_attack", function(cmd)
		local ply = LocalPlayer()
		if not ply:Alive() then return end
		local wep = ply:GetActiveWeapon()
		if not wep then return end
		if not wep.Clip1 then return end
		local currentAmmo = wep:Clip1()
		if currentAmmo < previousAmmo and not (wep != previousWep) then
			onPrimaryAttack(ply, wep)
		end
		
		previousAmmo = currentAmmo
		previousWep = wep
	end)
end

local function explosionProcess(data)
	if not string.find(data.SoundName, "explo") or string.find(data.SoundName, "dwr") or not string.StartWith(data.SoundName, "^") then return end
	playReverb(data.Pos, "explosions", false, {})
end

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	if data.Pos == nil or not data.Pos then return end
	explosionProcess(data)

	if GetConVar("cl_dwr_process_everything"):GetInt() == 1 then
		local isweapon = false
		if string.find(data.SoundName, "weapon") then isweapon = true end
		data = processSound(data, isweapon)
		return true
	end
end)

-- end of main