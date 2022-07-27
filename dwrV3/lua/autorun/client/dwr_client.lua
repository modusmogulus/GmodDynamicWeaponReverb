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
	if distance > 100 then 
		return "distant"
	else
		return "close"
	end
end

local function formatAmmoType(ammoType)
	if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] ammoType to be formatted: " .. ammoType) end
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

    if GetConVar("cl_dwr_debug"):GetInt() == 1 then
	    local color = Color(0,0,0)

	    if traceFromOffsetToPos.HitPos == pos then
	    	color = Color(0,255,0)
	    else
	    	color = Color(255,0,0)
	    end
	    debugoverlay.Line(traceToOffset.HitPos, traceToOffset.StartPos, 5, color, true)
	    debugoverlay.Line(traceFromOffsetToPos.HitPos, traceFromOffsetToPos.StartPos, 5, color, true)
	end

    return (traceFromOffsetToPos.HitPos == pos)
end

function boolToInt(value)
	-- oh come on lua, fuck you.
  	return value and 1 or 0
end

local function getOcclusionPercent(earpos, pos)
	local traceAmount = math.floor(GetConVar("cl_dwr_occlusion_rays"):GetInt()/4)
	local degrees = 360/traceAmount
	local savedTraces = {}
	local successfulTraces = 0

	for j=1, 4, 1 do
		local singletrace = Vector(100000000,0,0)
		local angle
		if j==1 then angle = Angle(degrees, 0)
		elseif j==2 then angle = Angle(degrees, degrees)
		elseif j==3 then angle = Angle(-degrees, degrees)
		elseif j==4 then angle = Angle(0, degrees) end
 		for i=1, traceAmount, 1 do
			singletrace:Rotate(angle)
			successfulTraces = successfulTraces + boolToInt(traceableToPos(earpos, pos, singletrace))
		end
	end

	successfulTraces = math.Clamp(successfulTraces, 0, traceAmount) -- why the FUCK does it go over the traceamount

	local failedTraces = traceAmount - successfulTraces
	local percentageOfFailedTraces = failedTraces / traceAmount

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

	if !isSuppressed then
		volume = 1
	else
		volume = 0.3
	end

	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = 100
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(dataSrc) * 0.01905 -- in meters

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

	if distanceState == "close" then
		local distanceMultiplier = math.Clamp(3000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	elseif distanceState == "distant" then
		local distanceMultiplier = math.Clamp(8000/distance^2, 0, 1)
		volume = volume * distanceMultiplier
	end


	timer.Simple(calculateSoundspeedDelay(dataSrc, earpos), function()
		EmitSound(reverbSoundFile, LocalPlayer():EyePos(), -2, CHAN_STATIC, volume * (GetConVar("cl_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
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
	if GetConVar("cl_dwr_debug"):GetInt() == 1 then print("[DWR] EntityEmitSound") end
	
	-- looking for reverb soundfiles to uses
	local positionState = getPositionState(data.Pos)
	local distanceState = getDistanceState(data.Pos, earpos)
	local ammoType = "Explosions"
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammoType .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]
	local isSuppressed = false

	playReverb(reverbSoundFile, positionState, distanceState, data.Pos, isSuppressed)
end


hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	explosionReverb(data)
end)