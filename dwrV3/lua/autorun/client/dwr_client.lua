print("[DWRV3] Client loaded.")

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob

    if temp.HitPos == pos and tr.HitSky then
    	return true
    end

    return false
end

local isSuppressed = false

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
	if distance > 115 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammoType)
	ammoType = string.lower(ammoType)
	if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] ammoType to be formatted: " .. ammoType) end
	if table.HasValue(dwr_supportedAmmoTypes, ammoType) then
		return ammoType
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
	local debugTraceArray = {}
	local maxdistance = GetConVar("cl_dwr_occlusion_rays_max_distance"):GetInt()
	local totalDistance = 0


	earpos = earpos + Vector(0,0,10) -- just in case
	pos = pos + Vector(0,0,10) -- just in case

    local traceToOffset = util.TraceLine( {
        start = earpos,
        endpos = earpos + offset,
        mask = MASK_NPCWORLDSTATIC
    })

    totalDistance = traceToOffset.HitPos:Distance(traceToOffset.StartPos)

    if GetConVar("cl_dwr_debug"):GetInt() == 1 then table.insert(debugTraceArray, traceToOffset) end

    lastTrace = traceToOffset

	for i=1,bounceLimit,1 do
	    local bounceTrace = util.TraceLine( {
	        start = lastTrace.HitPos,
	        endpos = lastTrace.HitPos + reflectVector(lastTrace.HitPos, lastTrace.Normal) * 1000000000,
	        mask = MASK_NPCWORLDSTATIC
	    })
	    if bounceTrace.StartSolid or bounceTrace.AllSolid then break end

	    totalDistance = totalDistance + bounceTrace.HitPos:Distance(bounceTrace.StartPos)
    	if GetConVar("cl_dwr_debug"):GetInt() == 1 then table.insert(debugTraceArray, bounceTrace) end
	    lastTrace = bounceTrace
	end

    local traceLastTraceToPos = util.TraceLine( {
        start = lastTrace.HitPos,
        endpos = pos,
        mask = MASK_NPCWORLDSTATIC
    })

    totalDistance = totalDistance + traceLastTraceToPos.HitPos:Distance(traceLastTraceToPos.StartPos)

    if totalDistance > maxdistance then return false end

    if GetConVar("cl_dwr_debug"):GetInt() == 1 then
		table.insert(debugTraceArray, traceLastTraceToPos)
		local color = Color(255, 255, 255)
		if traceLastTraceToPos.HitPos == pos then color = Color(0,255,0) else color = Color(255,0,0) end
		for _, trace in ipairs(debugTraceArray) do debugoverlay.Line(trace.HitPos, trace.StartPos, 5, color, true) end
	end

    return (traceLastTraceToPos.HitPos == pos)
end

function boolToInt(value)
	-- oh come on lua, fuck you.
  	return value and 1 or 0
end

function inverted_boolToInt(value)
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

	if GetConVar("cl_dwr_debug"):GetInt() == 1 then
	    print("[DWR] successfulTraces: ", successfulTraces)
	    print("[DWR] failedTraces: ", failedTraces)
	    print("[DWR] percentageOfFailedTraces: ", percentageOfFailedTraces)
	end

	return percentageOfFailedTraces
end

local function calculateSoundspeedDelay(pos1, pos2)
	if not GetConVar("cl_dwr_disable_soundspeed"):GetBool() then
		return pos1:Distance(pos2) * 0.01905 / GetConVar("cl_dwr_soundspeed"):GetInt()
	else
		return 0
	end
end

local function playReverb(reverbSoundFile, positionState, distanceState, dataSrc, isSuppressed)
	if GetConVar("cl_dwr_disable_reverb"):GetBool() == true then return end
	local localPlayer = LocalPlayer()
	local earpos = localPlayer:GetViewEntity():GetPos()
	local volume = 1

	if isSuppressed then volume = 0.3 end

	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = math.random(94, 107)
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(dataSrc) * 0.01905 -- in meters

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = dataSrc,
        mask = MASK_NPCWORLDSTATIC
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(dataSrc:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
	    local occlusionPercentage = getOcclusionPercent(earpos, dataSrc)
    	if occlusionPercentage == 1 then dsp = 30 end -- lowpass
		volume = volume * (1-math.Clamp(occlusionPercentage-0.5, 0, 0.5))
	end

	if distanceState == "close" then
		local distanceMultiplier = math.Clamp(5000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	elseif distanceState == "distant" then
		local distanceMultiplier = math.Clamp(9000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	end

	timer.Simple(calculateSoundspeedDelay(dataSrc, earpos), function()
		EmitSound(reverbSoundFile, localPlayer:EyePos(), -2, CHAN_STATIC, volume * (GetConVar("cl_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
		if GetConVar("cl_dwr_debug"):GetInt() == 1 then
			print("[DWR] Distance (Meters): " .. distance)
			print("[DWR] delayBySoundSpeed: " .. calculateSoundspeedDelay(dataSrc, earpos))
			print("[DWR] reverbSoundFile: " .. reverbSoundFile)
			print("[DWR] volume: " .. volume)
			print("[DWR] soundLevel: " .. soundLevel)
			print("[DWR] soundFlags: " .. soundFlags)
			print("[DWR] pitch: " .. pitch)
			print("[DWR] dsp: " .. dsp)
			print("[DWR] isSuprressed: " .. tostring(isSuppressed))
			print("--------------------------------------------")
		end
	end)
end

net.Receive("dwr_EntityFireBullets_networked", function(len)
	local earpos = LocalPlayer():GetViewEntity():GetPos()
	local dataSrc = net.ReadVector()
	local dataAmmoType = net.ReadString()
	local isSuppressed = net.ReadBool()

	if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] dwr_EntityFireBullets_networked received") end

	-- looking for reverb soundfiles to use
	local positionState = getPositionState(dataSrc)

	if GetConVar("cl_dwr_disable_indoors_reverb"):GetBool() == true && positionState == "indoors" then return end
	if GetConVar("cl_dwr_disable_outdoors_reverb"):GetBool() == true && positionState == "outdoors" then return end

	local distanceState = getDistanceState(dataSrc, earpos)
	local ammoType = formatAmmoType(dataAmmoType)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	playReverb(reverbSoundFile, positionState, distanceState, dataSrc, isSuppressed)
end)


function explosionReverb(data)
	local earpos = LocalPlayer():GetViewEntity():GetPos()

	if not string.find(data.SoundName, "explo") then return end
	if not string.StartWith(data.SoundName, "^") then return end

	if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] EntityEmitSound") end
	
	-- looking for reverb soundfiles to uses
	local positionState = getPositionState(data.Pos)
	local distanceState = getDistanceState(data.Pos, earpos)
	local ammoType = "explosions"
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]
	local isSuppressed = false

	playReverb(reverbSoundFile, positionState, distanceState, data.Pos, isSuppressed)
end

local function modifySound(reverbSoundFile, positionState, distanceState, data)
	if GetConVar("cl_dwr_disable_reverb"):GetBool() == true then return end
	local localPlayer = LocalPlayer()
	local earpos = localPlayer:GetViewEntity():GetPos()
	local volume = 1
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(data.Pos) * 0.01905 -- in meters

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = data.Pos,
        mask = MASK_NPCWORLDSTATIC
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(data.Pos:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
	    local occlusionPercentage = getOcclusionPercent(earpos, data.Pos)
    	if occlusionPercentage == 1 then dsp = 30 end -- lowpass
		volume = volume * (1-math.Clamp(occlusionPercentage-0.5, 0, 0.5))
	end

	if distanceState == "close" then
		local distanceMultiplier = math.Clamp(5000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	elseif distanceState == "distant" then
		local distanceMultiplier = math.Clamp(9000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	end

	data.Volume = data.Volume * volume
	data.DSP = dsp

	return data
end

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	explosionReverb(data)

	if GetConVar("cl_dwr_calculate_every_sound"):GetInt() == 1 then
		if string.find(data.SoundName, "dwr") or data.Pos == nil then return end

		if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] EntityEmitSound EVERYTHING :DD") end

		local earpos = LocalPlayer():GetViewEntity():GetPos()
		local positionState = getPositionState(data.Pos)
		local distanceState = getDistanceState(data.Pos, earpos)
		data = modifySound(data.SoundName, positionState, distanceState, data)
		
		return true
	end
end)