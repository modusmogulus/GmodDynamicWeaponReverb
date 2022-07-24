print("[DWRV3] Client loaded.")

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC})

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
	local distance = pos1:Distance(pos2)
	-- tweak this number later plz
	if distance > 2500 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammoType)
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

local function playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
	local volume = 1
	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = 100
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/Dsp_presets

    local traceToSrc = util.TraceLine( {
        start = LocalPlayer():GetShootPos(),
        endpos = dataSrc,
        filter = LocalPlayer(),
        mask = MASK_NPCWORLDSTATIC
    })

    local direct = (traceToSrc.HitPos == dataSrc)

    if not direct then
    	if distanceState == "distant" then
			dsp = 30 -- lowpass
			volume = volume * 0.5
		else
			volume = volume * 0.8
		end
	end

	if distanceState == "close" then
		local distance = LocalPlayer():EyePos():Distance(dataSrc) * 0.01905 -- in meters
		local distanceMultiplier = 500/distance^2
		volume = math.Clamp(volume * distanceMultiplier, 0, 1)
		print(distance)
	end

	EmitSound(reverbSoundFile, LocalPlayer():EyePos(), -2, CHAN_STATIC, volume, soundLevel, soundFlags, pitch, dsp)
	EmitSound(reverbSoundFile, LocalPlayer():EyePos(), -2, CHAN_STATIC, volume, soundLevel, soundFlags, pitch, dsp)
	print("[DWR] reverbSoundFile: " .. reverbSoundFile)
	print("[DWR] volume: " .. volume)
	print("[DWR] soundLevel: " .. soundLevel)
	print("[DWR] soundFlags: " .. soundFlags)
	print("[DWR] pitch: " .. pitch)
	print("[DWR] dsp: " .. dsp)
	print("--------------------------------------------")
end

net.Receive("dwr_EntityFireBullets_networked", function(len)
	-- hook data
	local entity = net.ReadEntity()
	local weapon = net.ReadEntity()
	local dataSrc = net.ReadVector()
	local dataAmmoType = net.ReadString()

	print("[DWR] dwr_EntityFireBullets_networked received")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(dataSrc)
	local distanceState = getDistanceState(dataSrc, LocalPlayer():EyePos())
	local ammoType = formatAmmoType(dataAmmoType)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
end)

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	if not string.find(data.SoundName, "explo") then return end
	print("[DWR] EntityEmitSound")

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(data.Pos)
	local distanceState = getDistanceState(data.Pos, LocalPlayer():EyePos())
	local ammoType = "Explosions"
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, data.Pos, customVolumeMultiplier)
end)