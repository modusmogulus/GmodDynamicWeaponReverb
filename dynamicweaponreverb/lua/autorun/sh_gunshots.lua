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


function DynamicReverb(entity, data)

    if data.Distance < 100 then return end

    local weapon = NULL
    local reverb_range = 1
    if entity:IsPlayer() then
        weapon = entity:GetActiveWeapon()
    else
        weapon = entity
    end

    function DetermineSpace()
        
        local singletrace = Vector(1, 8, 1)
        local recordedtraces = {}
        local recordedtraces_indoors = {}
        local tracehymmi
        local roomheight

        for i=1,reflections,1 do 
            singletrace:Rotate( Angle(math.sin(i) * reflections, math.cos(i) * reflections, math.tan(i) * reflections ) ) -- i suck at math so idk if this is correct but it works!
            --singletrace:Rotate( Angle(math.random(0, 360), math.random(0, 360), math.random(0, 360) ) )

            tracehymmi = util.TraceLine({ -- Tracing a line to floor
                start = entity:EyePos(),
                endpos = entity:EyePos() + singletrace * -10000,
                mask = MASK_OPAQUE
            })

            recordedtraces[i] = entity:EyePos():Distance(tracehymmi.HitPos)

            
            if entity:EyePos():Distance(tracehymmi.HitPos) < 600 then recordedtraces_indoors[i] = 1
            else recordedtraces_indoors[i] = 0 end

            --ParticleEffect("gf2_rocket_large_explosion_01", tracehymmi.HitPos, Angle( 0, 0, 0 ))
            --local vPoint = tracehymmi.HitPos
            --local effectdata = EffectData()
            --effectdata:SetOrigin( vPoint )
            --util.Effect( "Impact", effectdata )
            --debugoverlay.Line(entity:EyePos(), tracehymmi.HitPos, 1.0)
            
        end

            local tracedown = util.TraceLine( {  --Tracing a line to floor
            start = entity:EyePos() +  Vector(0, 0, 1) * 1,
            endpos = entity:EyePos() + Vector(0, 0, 1) * -10000,
            mask = MASK_OPAQUE
        } )

        local traceup = util.TraceLine( {  --Tracing a line from floor to ceiling to measure room height
            start = tracedown.HitPos, --Trace start offset to prevent trace hitting player
            endpos = tracedown.HitPos + Vector(0, 0, 1) * 10000,
            mask = MASK_OPAQUE
        } )
        
        roomheight = traceup.HitPos:Distance(tracedown.HitPos, traceup.Entity)
        
        if roomheight < 1000 && traceup.HitSky == false then
            indoorpercentage = math.Clamp(math.average(recordedtraces_indoors) + 0.2, 0.0, 1.0) --higher chance of player being indoors if there is a ceiling above player
        else
            indoorpercentage = math.average(recordedtraces_indoors)
        end

        extensivity = math.Clamp(math.average(recordedtraces) / 9000 - 1000, 0.0, 1.0) 
        
        
        print(indoorpercentage * 100)
        print(extensivity)
        print(currentspace)

        if indoorpercentage < 0.95 then currentspace = "city" end
        if indoorpercentage > 0.95 then currentspace = "room" end
        if indoorpercentage < 0.4 or extensivity > 7000 then currentspace = "field" end

    
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

    function ReverbTheGunshot(soundtable, ammotype, desiredspace, excludespace, volumemultiplier, sidechain) -- common ammotypes include: "SMG1", "Pistol", "Buckshot", "357". leave desiredspace blank if space doesn't matter and excludespace blank to not exclude anything
        
        if ammotype == data.AmmoType or has_value(supported_ammunitions, ammotype) == false then
            if desiredspace == currentspace or desiredspace == "" then
                if excludespace == "" or currentspace != excludespace then

                    net.Start("dynrev_playSoundAtClient")
                    
                        net.WriteFloat(volumemultiplier)
                        net.WriteTable(soundtable)
                        net.WriteEntity(entity)
                        net.WriteBool(sidechain)

                    net.Broadcast()
                end
            end
        end
        
    end





    if SERVER then

        DetermineSpace()

        ReverbTheGunshot(hptailscity,     "SMG1",   "city",        "room", 1.0, false)
        ReverbTheGunshot(hptails,         "SMG1",   "field",       "room", 1.0, false)
        ReverbTheGunshot(hptailsroom,     "SMG1",   "room",        "city", indoorpercentage * 1.2, false)

        ReverbTheGunshot(hptailscity,     "AR2",    "city",        "room", 1.0, false)
        ReverbTheGunshot(hptails,         "AR2",    "field",       "room", 1.0, false)
        ReverbTheGunshot(aptailsroom,     "AR2",    "room",        "city", indoorpercentage * 1.2, false)

        ReverbTheGunshot(lptailscity,    "Pistol",  "city",        "room", 1.0, false)
        ReverbTheGunshot(lptails,        "Pistol",  "field",       "room", 1.0, false)
        ReverbTheGunshot(lptailsroom,    "Pistol",  "room",        "city", indoorpercentage * 1.2, false)

        if has_value(supported_ammunitions, data.AmmoType) == false then
            ReverbTheGunshot(hptailscity,    "",  "city",        "room", 1.0, false)
            ReverbTheGunshot(hptails,        "",  "field",       "room", 1.0, false)
            ReverbTheGunshot(lptailsroom,    "",  "room",        "city", indoorpercentage * 1.2, false)
        end

        ReverbTheGunshot(lptailscity,    "357",     "city",       "room", 1.0, false)
        ReverbTheGunshot(lptails,        "357",     "field",      "room", 1.0, true)
        ReverbTheGunshot(lptailsroom,    "357",     "room",       "city", indoorpercentage * 1.2, false)


        --print(data.AmmoType)


    end
end

timer.Simple(0.1, function()
    hook.Add("EntityFireBullets", "Teams_DynamicReverbs", DynamicReverb)
end)

