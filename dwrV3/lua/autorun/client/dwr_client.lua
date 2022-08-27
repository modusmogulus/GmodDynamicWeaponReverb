print("[DWRV3] Client loaded.")

local UNITS_TO_METERS = 0.01905 -- multiply by this value and voila

-- start of functions
local function readVectorUncompressed()
	local tempVec = Vector(0,0,0)
	tempVec.x = net.ReadFloat()
	tempVec.y = net.ReadFloat()
	tempVec.z = net.ReadFloat()
	return tempVec
end

local function traceableToSky(pos, offset)
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), mask=MASK_NPCWORLDSTATIC})
	local temp = util.TraceLine({start=tr.StartPos, endpos=pos, mask=MASK_NPCWORLDSTATIC}) -- doing this because sometimes the trace can go oob and even rarely there are cases where i cant see if it spawned oob

    if temp.HitPos == pos and not temp.StartSolid and tr.HitSky then
    	return true
    end

    return false
end

local function getEarPos()
	local lp = LocalPlayer()
	local viewEntityPos = lp:GetViewEntity():GetPos()

	if viewEntityPos != lp:GetPos() then return viewEntityPos end

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
	if distance > 115 then 
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
        mask = MASK_NPCWORLDSTATIC
    })

    totalDistance = traceToOffset.HitPos:Distance(traceToOffset.StartPos)

    lastTrace = traceToOffset

	for i=1,bounceLimit,1 do
	    local bounceTrace = util.TraceLine( {
	        start = lastTrace.HitPos,
	        endpos = lastTrace.HitPos + reflectVector(lastTrace.HitPos, lastTrace.Normal) * 1000000000,
	        mask = MASK_NPCWORLDSTATIC
	    })
	    if bounceTrace.StartSolid or bounceTrace.AllSolid then break end

	    totalDistance = totalDistance + bounceTrace.HitPos:Distance(bounceTrace.StartPos)
	    lastTrace = bounceTrace
	end

    local traceLastTraceToPos = util.TraceLine( {
        start = lastTrace.HitPos,
        endpos = pos,
        mask = MASK_NPCWORLDSTATIC
    })

    totalDistance = totalDistance + traceLastTraceToPos.HitPos:Distance(traceLastTraceToPos.StartPos)

    if totalDistance > maxdistance then return false end

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

	return percentageOfFailedTraces
end

local function calculateDelay(pos1, pos2, speed)
	if speed == 0 then return 0 end
	return pos1:Distance(pos2) / speed
end

local function playReverb(src, ammotype, isSuppressed)
	if GetConVar("cl_dwr_disable_reverb"):GetBool() == true then return end
		
	local earpos = getEarPos()
	local volume = 1
	local positionState = getPositionState(src)
	if GetConVar("cl_dwr_disable_indoors_reverb"):GetBool() == true && positionState == "indoors" then return end
	if GetConVar("cl_dwr_disable_outdoors_reverb"):GetBool() == true && positionState == "outdoors" then return end
	local distanceState = getDistanceState(src, earpos)
	ammotype = formatAmmoType(ammotype)
	local reverbOptions = getEntriesStartingWith("dwr" .. "/" .. ammotype .. "/" .. positionState .. "/" .. distanceState .. "/", dwr_reverbFiles)
	local reverbSoundFile = reverbOptions[math.random(#reverbOptions)]

	if isSuppressed then volume = 0.3 end

	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = math.random(94, 107)
	local dsp = 0 -- https://developer.valvesoftware.com/wiki/DSP
	local distance = earpos:Distance(src) * UNITS_TO_METERS -- in meters

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = src,
        mask = MASK_VISIBLE
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(src:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
	    local occlusionPercentage = getOcclusionPercent(earpos, src)
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
	
	local soundspeed = GetConVar("cl_dwr_soundspeed"):GetFloat()

	if GetConVar("cl_dwr_disable_soundspeed"):GetInt() == 1 then soundspeed = 0 end

	timer.Simple(calculateDelay(src, earpos, soundspeed), function()
		EmitSound(reverbSoundFile, earpos, -2, CHAN_AUTO, volume * (GetConVar("cl_dwr_volume"):GetFloat() / 100), soundLevel, soundFlags, pitch, dsp)
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

local function playBulletCrack(src, dir, vel, spread, ammotype)
	if GetConVar("cl_dwr_disable_bulletcracks"):GetInt() == 1 then return end
	ammotype = formatAmmoType(ammotype)
	local earpos = getEarPos()
    local distanceState = getDistanceState(src, earpos)
    local volume = 1
    local dsp = 0
	local soundLevel = 0 -- sound plays everywhere
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local pitch = math.random(94, 107)

    local trajectory = util.TraceLine( {
        start = src,
        endpos = src + calculateSpread(dir, spread) * 10000000,
        mask = MASK_VISIBLE
    })

    distance, point, distanceToPointOnLine = util.DistanceToLine(trajectory.StartPos, trajectory.HitPos, earpos)
    if distance * UNITS_TO_METERS > 10 then return end -- I've read somewhere that you can hear bullet cracks even from 100 meters away. But for the scale sake I'll keep it lower.

    local traceToSrc = util.TraceLine( {
        start = earpos,
        endpos = point,
        mask = MASK_VISIBLE
    })

    -- i hate floats
    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(point:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

    if not direct then
    	dsp = 30
	end

	local crackOptions = getEntriesStartingWith("dwr/" .. "bulletcracks/" .. distanceState .. "/", dwr_reverbFiles)
	local crackhead = crackOptions[math.random(#crackOptions)]

	--if distanceState == "distant" then
	--	dsp = 30
	--end

	timer.Simple(calculateDelay(trajectory.StartPos, trajectory.HitPos, vel:Length()), function()
		EmitSound(crackhead, point, -2, CHAN_AUTO, volume * (GetConVar("cl_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp)
		--if distanceState == "distant" then EmitSound(crackhead, point, -2, CHAN_USER_BASE, volume * (GetConVar("cl_dwr_volume"):GetInt() / 100), soundLevel, soundFlags, pitch, dsp) end
	end)
end

local function getSuppressed(weapon, weaponClass)
    if string.StartWith(weaponClass, "arccw_") and weapon:GetBuff_Override("Silencer") then return true
    elseif string.StartWith(weaponClass, "tfa_") and weapon:GetSilenced() then return true
    elseif string.StartWith(weaponClass, "mg_") or weaponClass == mg_valpha then
        if weapon.Customization != nil then
            for name, attachments in pairs(weapon.Customization) do
                if name != "Muzzle" then continue end
                local attachment = weapon.Customization[name][weapon.Customization[name].m_Index]
                if string.find(attachment.Key, "silence") then
                    return true
                end
            end
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
        mask = MASK_NPCWORLDSTATIC
    })

    -- i hate floats

    local x1,y1,z1 = math.floor(traceToSrc.HitPos:Unpack())
    local x2,y2,z2 = math.floor(src:Unpack())
    local direct = (Vector(x1,y1,z1) == Vector(x2,y2,z2)) 

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
	local ignore = (net.ReadEntity() == LocalPlayer())
	if not game.SinglePlayer() and ignore then return end

	if not ignore then
		playBulletCrack(src, dir, vel, spread, ammotype)
	end
	
	playReverb(src, ammotype, isSuppressed)
end)

net.Receive("dwr_EntityEmitSound_networked", function(len)
	if GetConVar("cl_dwr_process_everything"):GetInt() != 1 then return end
	local data = net.ReadTable()
	data = processSound(data, true)
	if data.Entity == NULL then return end
	data.Entity:EmitSound(data.SoundName, data.SoundLevel, data.Pitch, data.Volume, CHAN_STATIC, data.Flags, data.DSP)
	--hook.Run("EntityEmitSound", data)
end)

if not game.SinglePlayer() then
	hook.Add("EntityFireBullets", "dwr_firebullets_client", function(attacker, data)
		local earpos = getEarPos()
	    local entity = NULL
	    local weapon = NULL
	    local weaponIsWeird = false
	    local isSuprressed = false
	    local ammotype = "none"

	    if attacker:IsPlayer() or attacker:IsNPC() then
	        entity = attacker
	        weapon = entity:GetActiveWeapon()
	    else
	        weapon = attacker
	        entity = weapon:GetOwner()
	        if entity == NULL then 
	            entity = attacker
	            weaponIsWeird = true
	        end
	    end

		if entity == NULL or entity != LocalPlayer() then return end

	    if not weaponIsWeird then -- should solve all of the issues caused by external bullet sources (such as the turret mod)
	        local weaponClass = weapon:GetClass()
	        local entityShootPos = entity:GetShootPos()

	        if entity.dwr_shotThisTick == nil then entity.dwr_shotThisTick = false end
	        if entity.dwr_shotThisTick then return end
	        entity.dwr_shotThisTick = true
	        timer.Simple(0, function() entity.dwr_shotThisTick = false end) -- the most universal fix for fuckin penetration and ricochet
	    
	        if #data.AmmoType > 2 then ammotype = data.AmmoType else ammotype = weapon.Primary.Ammo end

	        if data.Distance < 100 then return end

	        if string.StartWith(weaponClass, "arccw_") then
	            if data.Distance == 20000 then
	                return
	            end
	            if GetConVar("arccw_bullet_enable"):GetInt() == 1 and data.Spread == Vector(0, 0, 0) then
	                return
	            end
	        end

	        isSuppressed = getSuppressed(weapon, weaponClass)
	    end

		playReverb(data.Src, ammotype, isSuppressed)
	end)

	hook.Add("Think", "dwr_detectarccwphys", function()
		if ArcCW == nil then return end
	    if ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)] == nil then return end
	    local latestPhysBullet = ArcCW.PhysBullets[table.Count(ArcCW.PhysBullets)]
	    if latestPhysBullet["dwr_detected"] then return end
	    if latestPhysBullet["Attacker"] == Entity(0) then return end
	    if LocalPlayer() != latestPhysBullet["Attacker"] then return end


	    local weapon = latestPhysBullet["Weapon"]
	    local weaponClass = weapon:GetClass()

	    local isSuppressed = getSuppressed(weapon, weaponClass)
	    local pos = latestPhysBullet["Pos"]
	    local ammotype = weapon.Primary.Ammo

	    playReverb(pos, ammotype, isSuppressed)
	    latestPhysBullet["dwr_detected"] = true
	end)

	hook.Add("Think", "dwr_detecttfaphys", function()
    	if TFA == nil then return end

	    local latestPhysBullet = TFA.Ballistics.Bullets["bullet_registry"][table.Count(TFA.Ballistics.Bullets["bullet_registry"])]
	    if latestPhysBullet == nil then return end
	    if latestPhysBullet["dwr_detected"] then return end
	    if latestPhysBullet["owner"] != LocalPlayer() then return end

	    local weapon = latestPhysBullet["inflictor"]
	    local weaponClass = weapon:GetClass()

	    local isSuppressed = getSuppressed(weapon, weaponClass)
	    local pos = latestPhysBullet["bul"]["Src"]
	    local ammotype = weapon.Primary.Ammo


	    playReverb(pos, ammotype, isSuppressed)
	    latestPhysBullet["dwr_detected"] = true
	end)
end

local function explosionProcess(data)
	if not string.find(data.SoundName, "explo") or string.find(data.SoundName, "dwr") or not string.StartWith(data.SoundName, "^") then return end
	playReverb(data.Pos, "explosions", false)
end

hook.Add("EntityEmitSound", "dwr_EntityEmitSound", function(data)
	if data.Pos == nil or not data.Pos then return end
	explosionProcess(data)

	if GetConVar("cl_dwr_process_everything"):GetInt() == 1 then
		data = processSound(data, false)
		return true
	end
end)

-- end of main