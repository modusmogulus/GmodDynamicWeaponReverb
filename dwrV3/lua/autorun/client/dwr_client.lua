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

local function traceableToPos(earpos, pos, offset)
	offset = offset * 1000000000
	local localPlayer = LocalPlayer()
    local traceToOffset = util.TraceLine( {
        start = earpos,
        endpos = earpos + offset,
        filter = localPlayer,
        mask = MASK_NPCWORLDSTATIC
    })
    local traceFromOffsetToPos = util.TraceLine( {
        start = traceToOffset.HitPos,
        endpos = pos,
        filter = localPlayer,
        mask = MASK_NPCWORLDSTATIC
    })

    local color = Color(0,0,0)

    if traceFromOffsetToPos.HitPos == pos then
    	color = Color(0,255,0)
    else
    	color = Color(255,0,0)
    end

    debugoverlay.Line(traceToOffset.HitPos, traceToOffset.StartPos, 5, color, true)
    debugoverlay.Line(traceFromOffsetToPos.HitPos, traceFromOffsetToPos.StartPos, 5, color, true)

    return (traceFromOffsetToPos.HitPos == pos)
end

function boolToInt(value)
	-- oh come on lua, fuck you.
  	return value and 1 or 0
end

local function getOcclusionPercent(earpos, pos)
	local singletrace = Vector(1, 0, 0) * 100000000
	local traceAmount = 10
	local degrees = 360/traceAmount
	local savedTraces = {}
	local successfulTraces = 0

	for i=1, traceAmount, 1 do
		singletrace:Rotate(Angle(0,degrees))
		successfulTraces = successfulTraces + boolToInt(traceableToPos(earpos, pos, singletrace))
	end

	for i=1, traceAmount, 1 do
		singletrace:Rotate(Angle(degrees,0))
		successfulTraces = successfulTraces + boolToInt(traceableToPos(earpos, pos, singletrace))
	end

	local failedTraces = traceAmount - successfulTraces
	local percentageOfFailedTraces = failedTraces / traceAmount
    print("[DWR] successfulTraces: ", successfulTraces)
    print("[DWR] failedTraces: ", failedTraces)
    print("[DWR] percentageOfFailedTraces: ", percentageOfFailedTraces)
	return percentageOfFailedTraces
end

local function playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
	if GetConVar("sv_dwr_disable_reverb"):GetBool() == true then return end
	local localPlayer = LocalPlayer()
	local earpos = localPlayer:GetViewEntity():GetPos()

	local volume = 1
	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = 100
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/Dsp_presets
	local distance = dataSrc:Distance(earpos)

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = dataSrc,
        filter = localPlayer,
        mask = MASK_NPCWORLDSTATIC
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(dataSrc:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
	    local occlusionPercentage = getOcclusionPercent(earpos, dataSrc)
    	if occlusionPercentage == 1 then
			dsp = 30 -- lowpass
		end
		volume = volume * 0.5
	end

	local distance = earpos:Distance(dataSrc) * 0.01905 -- in meters
	local distanceMultiplier = math.Clamp(3000/distance^2, 0, 1)
	volume = volume * distanceMultiplier
	print("[DWR] Distance (Meters): " .. distance)

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
	-- we dont use any of these here. we only use them serverside
	--local entity = net.ReadEntity()
	--local weapon = net.ReadEntity()
	local dataSrc = net.ReadVector()
	local dataAmmoType = net.ReadString()

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

	playReverb(reverbSoundFile, positionState, distanceState, dataSrc, customVolumeMultiplier)
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

	local customVolumeMultiplier = 1

	playReverb(reverbSoundFile, positionState, distanceState, data.Pos, customVolumeMultiplier)
end)