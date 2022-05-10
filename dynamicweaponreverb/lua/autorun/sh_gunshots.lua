local currentspace = "city"
local reflections = 8

local reflectionstation = nil -- for keeping a reference to the audio object, so it doesn't get garbage collected which will stop the sound
local extensivity
local indoorpercentage
local indoorthreshold = 500
local supported_ammunitions = {"SMG1", "Pistol", "357", "Buckshot", "AR2"}
--

print("Reverb initialized...")


hptails = {
    "tails/dynrev_a_highpower_field1.wav", "tails/dynrev_a_highpower_field2.wav", 
    "tails/dynrev_a_highpower_field3.wav"
    --"distaudio/crazy_balloon.wav"
}

aptailsroom = {
    "distaudio/yt_gunshot_indoors1.wav", "distaudio/yt_gunshot_indoors1.wav"
}

bstails = {
    "tails/dynrev_buckshot_city1.wav", "tails/dynrev_buckshot_city2.wav"
}

bstailsroom = {
    "distaudio/yt_gunshot_indoors1.wav", "distaudio/yt_gunshot_indoors1.wav"
}

hptailscity = {
    "tails/dynrev_highpower_city3.wav"
}

lptails = {
    "tails/dynrev_lowpower_field1.wav", "tails/dynrev_lowpower_field2.wav"
    --"fprec/fp_winter_41khz.wav", "fprec/fp_winter_41khz_2.wav", "fprec/fp_winter_41khz_3.wav"
}

lptailscity = {
    "tails/dynrev_highpower_city2.wav", "tails/dynrev_highpower_city1.wav"
}

lptailsroom = {
    --"tails/dynrev_lowpower_indoors1.wav", "tails/dynrev_lowpower_indoors2.wav",
    --"tails/dynrev_lowpower_indoors3.wav", "tails/dynrev_lowpower_indoors4.wav",
    "tails/dynrev_lowpower_indoors2.wav", "tails/dynrev_lowpower_indoors6.wav"
}

hptailsroom = {
    --"tails/dynrev_lowpower_indoors1.wav", "tails/dynrev_lowpower_indoors2.wav",
    --"tails/dynrev_lowpower_indoors3.wav", "tails/dynrev_lowpower_indoors4.wav",
    "tails/dynrev_lowpower_indoors3.wav", "tails/dynrev_lowpower_indoors2.wav"
}

foliage = {
    "tails/dynrev_foliage1.wav", "tails/dynrev_foliage3.wav", "tails/dynrev_foliage3.wav",
}

bulletcracks = {
    "tails/dynrev_bulletcrack_center.wav", "tails/dynrev_bulletcrack_left1.wav", "tails/dynrev_bulletcrack_left2.wav",
    "tails/dynrev_bulletcrack_right1.wav", "tails/dynrev_bulletcrack_right2.wav"
}

function has_value(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return true end
    end
    return false
end

function string.startswith(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function math.average(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
        sum = sum + v
    end
    return sum / #t
end

local function createUpwardsTrace(ply, offset)
    local pos = ply:GetShootPos()
    local tr = util.TraceLine({start=pos + offset, endpos=pos + Vector(offset.x, offset.y, 100000000), filter=ply})
    local temp = util.TraceLine({start=tr.StartPos, endpos=ply:GetPos() + ply:OBBCenter()})
    tr.traceableToPlayer = (temp.Entity == ply)
    return tr
end

local function getOutdoorsState(ply)
    local tr_1 = createUpwardsTrace(ply, Vector(0,0,0))
    local tr_2 = createUpwardsTrace(ply, Vector(120,0,0))
    local tr_3 = createUpwardsTrace(ply, Vector(0,120,0))
    local tr_4 = createUpwardsTrace(ply, Vector(-120,0,0))
    local tr_5 = createUpwardsTrace(ply, Vector(0,-120,0))

    massive_hitsky = ((tr_1.HitSky and tr_1.traceableToPlayer) or
                 (tr_2.HitSky and tr_2.traceableToPlayer) or
                 (tr_3.HitSky and tr_3.traceableToPlayer) or
                 (tr_4.HitSky and tr_4.traceableToPlayer) or
                 (tr_5.HitSky and tr_5.traceableToPlayer))
    return massive_hitsky -- true means we're outdoors, false means we're indoors
end

function correct_src(weapon, source)
    -- I swear to fucking god if someone changes this in ArcCW again...
    local owner = weapon:GetOwner()

    if owner:IsNPC() then return owner:GetShootPos() end

    local dir    = owner:EyeAngles()
    local offset = Vector(0, 0, 0)

    if weapon:GetOwner():Crouching() then
        offset = weapon:GetBuff_Override("Override_BarrelOffsetCrouch") or weapon.BarrelOffsetCrouch or offset
    end

    if weapon:GetState() == ArcCW.STATE_SIGHTS then
        offset = LerpVector(weapon:GetSightDelta(), offset, weapon:GetBuff_Override("Override_BarrelOffsetSighted", weapon.BarrelOffsetSighted) or offset)
    else
        offset = LerpVector(1 - weapon:GetSightDelta(), offset, weapon:GetBuff_Override("Override_BarrelOffsetHip", weapon.BarrelOffsetHip) or offset)
    end

    source = source - dir:Right()   * offset[1]
    source = source - dir:Forward() * offset[2]
    source = source - dir:Up()      * offset[3]

    return source
end


function DynamicReverb(entity, data)
    if data.Distance < 100 then return end
    print("____________________")
    local weapon = NULL
    local reverb_range = 1

    if not entity:IsPlayer() and not entity:IsNPC() then
        weapon = entity
        entity = weapon:GetOwner()
    end

    if entity:IsPlayer() or entity:IsNPC() then 
        weapon = entity:GetActiveWeapon()
    end

    function DetermineSpace()
        local singletrace = Vector(1, 8, 1) * 100000000
        local recordedtraces = {}
        local recordedtraces_indoors = {}
        local tracehymmi
        local roomheight
        local degrees = 360/reflections

        for i=1,reflections,1 do 
            singletrace:Rotate(Angle(0,degrees))
            tracehymmi = util.TraceLine({ -- Tracing a line to floor
                start = entity:GetShootPos(),
                endpos = entity:GetShootPos() + singletrace,
                filter = entity
            })
            recordedtraces[i] = entity:EyePos():Distance(tracehymmi.HitPos)
            if entity:GetShootPos():Distance(tracehymmi.HitPos) < 600 then recordedtraces_indoors[i] = 1
            else recordedtraces_indoors[i] = 0 end
            debugoverlay.Line(tracehymmi.StartPos, tracehymmi.HitPos, 5, Color(255, 0, 0, 255), true)      
        end
        
        if getOutdoorsState(entity) == false then
            indoorpercentage = math.Clamp(math.average(recordedtraces_indoors) + 0.3, 0.0, 1.0) --higher chance of player being indoors if there is a ceiling above player
        else
            indoorpercentage = math.Clamp(math.average(recordedtraces_indoors), 0.0, 1.0)
        end

        extensivity = math.average(recordedtraces) / 9000 - 1000 
        if indoorpercentage < 0.85 then currentspace = "city" end
        if indoorpercentage > 0.85 then currentspace = "room" end
        if indoorpercentage < 0.85 and extensivity > 7000 then currentspace = "field" end
    end
    
    function Bulletcrack(entity)
        local trcrack = util.TraceHull( {
            start = entity:EyePos(),
            endpos = entity:EyePos() + ( weapon:GetOwner():GetAimVector() * 1000000),
            filter = entity,
            mins = Vector( 1, 1, 1 ) * -30,
            maxs = Vector( 1, 1, 1 ) * 2000,
            mask = MASK_SHOT_HULL
        } )

        --debugoverlay.SweptBox(entity:EyePos(), entity:EyePos(), Vector( -100, -100, -100 ), Vector( 10000, 100, 100), entity:GetAimVector():Angle(), 1, Color(255,155,0))

        if trcrack.Entity.IsPlayer == true then
            print("crack")
            net.Start("dynrev_BulletCrack")
            net.Send(trcrack.Entity)
        end
    end
    
    --if weapon:GetOwner():GetAimVector() != nil then
    --    Bulletcrack(entity)
    --end

    -- common ammotypes include: "SMG1", "Pistol", "Buckshot", "357". leave desiredspace blank if space doesn't matter and excludespace blank to not exclude anything
    function ReverbTheGunshot(soundtable, ammotype, desiredspace, excludespace, volumemultiplier, sidechain)
        print(data.AmmoType)
        if ammotype == data.AmmoType or has_value(supported_ammunitions, ammotype) == false then
            if desiredspace == currentspace or desiredspace == "" then
                if excludespace == "" or currentspace != excludespace then
                    local weapon_owner = weapon:GetOwner()
                    local weapon_class = weapon:GetClass()
                    if weapon_owner != nil and weapon_owner:IsPlayer() and data.Attacker == weapon_owner then
                        entity_pos = weapon:GetOwner():GetPos()
                        if string.find(weapon_class, "arccw") then
                            if data.Distance == 20000 then
                                print("221: invalid")
                                return 
                            end
                            shoot_pos = correct_src(weapon, data.Src)
                        else
                            shoot_pos = data.Src
                        end

                        if Vector(entity_pos.x, entity_pos.y, 0) != Vector(shoot_pos.x, shoot_pos.y, 0) or data.Distance < 100 then
                            print("230: invalid")
                            return
                        end
                    end

                    if string.startswith(weapon_class, "arccw_") and data.Distance != 20000 and weapon:GetBuff_Override("Silencer") then
                        volumemultiplier = volumemultiplier * 0.6
                    elseif string.startswith(weapon_class, "tfa_") and weapon:GetSilenced() then
                        volumemultiplier = volumemultiplier * 0.6
                    elseif string.startswith(weapon_class, "mg_") or weapon_class == mg_valpha then
                        for name, attachments in pairs(weapon.Customization) do
                            if name != "Muzzle" then continue end
                            local attachment = weapon.Customization[name][weapon.Customization[name].m_Index]
                            if string.find(attachment.Key, "silence") then
                                volumemultiplier = volumemultiplier * 0.6
                            end
                        end
                    elseif string.startswith(weapon_class, "cw_") then
                        for k, v in pairs(weapon.ActiveAttachments) do
                            if v == false then continue end
                            local att = CustomizableWeaponry.registeredAttachmentsSKey[k]
                            if att.isSuppressor then
                                volumemultiplier = volumemultiplier * 0.6
                            end
                        end
                    end

                    if desiredspace == "field" or desiredspace == "city" then
                        volumemultiplier = volumemultiplier * 0.6
                    end 

                    print("volumemultiplier:", volumemultiplier)
                    print("soundtable:", soundtable)
                    print("entity:", entity)
                    print("sidechain:", sidechain)   
                    print("desiredspace:", desiredspace)
                    print("indoorpercentage:", indoorpercentage)
                        

                    net.Start("dynrev_playSoundAtClient")
                        net.WriteFloat(volumemultiplier)
                        net.WriteTable(soundtable)
                        net.WriteEntity(entity)
                        net.WriteBool(sidechain)
                        net.WriteString(desiredspace)
                    net.Broadcast()
                end
            end
        end
    end

    if SERVER then
        DetermineSpace()
        // this needs to be redone. like, wtf is this?
        ReverbTheGunshot(hptailscity,     "SMG1",   "city",        "room", 1.0, false)
        ReverbTheGunshot(hptails,         "SMG1",   "field",       "room", 1.0, false)
        ReverbTheGunshot(hptailsroom,     "SMG1",   "room",        "city", math.min(indoorpercentage * 1.2, 1), false)

        ReverbTheGunshot(hptailscity,     "AR2",    "city",        "room", 1.0, false)
        ReverbTheGunshot(hptails,         "AR2",    "field",       "room", 1.0, false)
        ReverbTheGunshot(aptailsroom,     "AR2",    "room",        "city", math.min(indoorpercentage * 1.2, 1), false)

        ReverbTheGunshot(lptailscity,    "Pistol",  "city",        "room", 1.0, false)
        ReverbTheGunshot(lptails,        "Pistol",  "field",       "room", 1.0, false)
        ReverbTheGunshot(lptailsroom,    "Pistol",  "room",        "city", math.min(indoorpercentage * 1.2, 1), false)

        if has_value(supported_ammunitions, data.AmmoType) == false then
            ReverbTheGunshot(hptailscity,    "",  "city",        "room", 1.0, false)
            ReverbTheGunshot(hptails,        "",  "field",       "room", 1.0, false)
            ReverbTheGunshot(lptailsroom,    "",  "room",        "city", math.min(indoorpercentage * 1.2, 1), false)
        end

        ReverbTheGunshot(lptailscity,    "357",     "city",       "room", 1.0, false)
        ReverbTheGunshot(lptails,        "357",     "field",      "room", 1.0, true)
        ReverbTheGunshot(lptailsroom,    "357",     "room",       "city", math.min(indoorpercentage * 1.2, 1), false)

        ReverbTheGunshot(hptailscity,    "Buckshot",     "city",       "room", 1.0, false)
        ReverbTheGunshot(hptails,        "Buckshot",     "field",      "room", 1.0, true)
        ReverbTheGunshot(aptailsroom,    "Buckshot",     "room",       "city", math.min(indoorpercentage * 1.2, 1), false)
        --print(data.AmmoType)
    end
    print("____________________")
end

timer.Simple(0.1, function()
    hook.Add("EntityFireBullets", "Teams_DynamicReverbs", DynamicReverb)
end)

