print("[DWRV3] Client loaded.")

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob

    if temp.HitPos == pos and tr.HitSky then
    	return true
    end

    return false
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
	local distance = pos1:Distance(pos2) * 0.01905 -- meters l0l
	-- tweak this number later plz
	if distance > 50 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammoType)
	print("[DWR] ammoType to be formatted: " .. ammoType)
	if table.HasValue(dwr_supportedAmmoTypes, ammoType) then
		return ammoType
	else
		return "Other"
	end
end

local function getEntriesStartingWith(pattern, array)
	local tempArray = {}
	for _, path in ipairs(array) do
		if string.StartWith(path, pattern) then
			table.insert(tempArray, path)
		end
	end
	return tempArray
end

local function playReverb(reverbSoundFile, positionState, distanceState, distance, dataSrc, customVolumeMultiplier)
	if GetConVar("sv_dwr_disable_reverb"):GetBool() == true then return end
	local earpos = LocalPlayer():GetViewEntity():GetPos()

	local volume = 1
	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = 100
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/Dsp_presets

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = dataSrc,
        filter = LocalPlayer(),
        mask = MASK_NPCWORLDSTATIC
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(dataSrc:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
    	if distance > 1000 then
			dsp = 30 -- lowpass
		end
		volume = volume * 0.5
	end

	if distanceState == "close" then
		local distance = earpos:Distance(dataSrc) * 0.01905 -- in meters
		local distanceMultiplier = math.Clamp(500/distance^2, 0, 1)
		volume = volume * distanceMultiplier
		print("[DWR] Distance (Meters): " .. distance)
	end

	local delayBySoundSpeed = 0
	if GetConVar("sv_dwr_disable_soundspeed"):GetBool() == false then
		delayBySoundSpeed = dataSrc:Distance(earpos) * 0.01905 / GetConVar("sv_dwr_soundspeed"):GetInt()
	end

	timer.Simple(delayBySoundSpeed, function()
		EmitSound(reverbSoundFile, LocalPlayer():EyePos(), -2, CHAN_STATIC, volume * (GetConVar("sv_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
		EmitSound(reverbSoundFile, LocalPlayer():EyePos(), -2, CHAN_STATIC, volume * (GetConVar("sv_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
		print("[DWR] delayBySoundSpeed: " .. delayBySoundSpeed)
		print("[DWR] reverbSoundFile: " .. reverbSoundFile)
		print("[DWR] volume: " .. volume)
		print("[DWR] soundLevel: " .. soundLevel)
		print("[DWR] soundFlags: " .. soundFlags)
		print("[DWR] pitch: " .. pitch)
		print("[DWR] dsp: " .. dsp)
		print("--------------------------------------------")
	end)
end

net.Receive("dwr_EntityFireBullets_networked", function(len)
	local earpos = LocalPlayer():GetViewEntity():GetPos()
	-- hook data
	local entity = net.ReadEntity()
	local weapon = net.ReadEntity()
	local dataSrc = net.ReadVector()
	local dataAmmoType = net.ReadString()
	local distance = dataSrc:Distance(earpos)

	print("[DWR] dwr_EntityFireBullets_networked received")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(dataSrc)

	if GetConVar("sv_dwr_disable_indoors_reverb"):GetBool() == true && positionState == "indoors" then return end
	if GetConVar("sv_dwr_disable_outdoors_reverb"):GetBool() == true && positionState == "outdoors" then return end

	local distanceState = getDistanceState(dataSrc, earpos)
	local ammoType = formatAmmoType(dataAmmoType)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, distance, dataSrc, customVolumeMultiplier)
end)

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	local earpos = LocalPlayer():GetViewEntity():GetPos()

	if not string.find(data.SoundName, "explo") then return end
	print("[DWR] EntityEmitSound (Explosion)")

	-- looking for reverb soundfiles to uses
	local positionState = getPositionState(data.Pos)
	local distanceState = getDistanceState(data.Pos, earpos)
	local ammoType = "Explosions"
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]
	local distance = data.Pos:Distance(earpos)

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, distance, customVolumeMultiplier)
end)