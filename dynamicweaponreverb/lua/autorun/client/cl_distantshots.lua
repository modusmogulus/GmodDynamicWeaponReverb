
local distancedsp = 0

net.Receive( "dynrev_playSoundAtClient", function( len, ply )
    local localear = LocalPlayer():GetViewEntity()
    volumemultiplier = net.ReadFloat()
    soundtable = net.ReadTable()
    shooter = net.ReadEntity()
    sidechain = net.ReadBool() -- nothing fancy, not a real sidechaining effect. just forces the one instance thing
    desiredspace = net.ReadString()

    --timespeed = 331 * 1.905 / 1 -- sound speed in air converted from m/s to gmod units
    --timespeeddelay = (shooter:GetPos():Distance(localear:GetPos()) * 1.905 / 100) / timespeed
    timespeeddelay = 0 -- doesnt sound very right

    randompitch = math.random(90, 110)

    if sidechain == true then
        for i,v in ipairs(soundtable) do
            LocalPlayer():StopSound(v)
        end
    end

    timer.Simple(timespeeddelay, function() --time speed delay
        print(tostring(shooter))
        print("modified:", volumemultiplier)
    
        firesound = soundtable[math.random(#soundtable)]

        local trace_to_shooter = util.TraceLine( {
            start = LocalPlayer():EyePos(),
            endpos = shooter:GetPos() + Vector(0,0,32),
            filter = LocalPlayer()
        })
        // this is a super hack and i hate it but it works lol
        if (trace_to_shooter.Entity == shooter and string.find(firesound, "indoor")) or shooter == LocalPlayer() then
            EmitSound(Sound(firesound), shooter:GetPos(), 1, CHAN_STATIC, 1 * volumemultiplier, 130, 0, randompitch )
            shooter:EmitSound("tails/dynrev_expfar.wav", 140, math.random(140, 100),0.4*volumemultiplier, CHAN_STATIC)
            shooter:EmitSound(foliage[math.random(#foliage)], 50, math.random(80, 100),0.5*volumemultiplier, CHAN_STATIC)
        else
            local themostepicmultiplierever = volumemultiplier * 0.5 * 500/shooter:GetPos():Distance(localear:GetPos())
            EmitSound(Sound(firesound), shooter:GetPos(), 1, CHAN_STATIC, 1 * themostepicmultiplierever, 130, 0, randompitch )
            shooter:EmitSound("tails/dynrev_expfar.wav", 140, math.random(140, 100),0.4*themostepicmultiplierever, CHAN_STATIC)
            shooter:EmitSound(foliage[math.random(#foliage)], 50, math.random(80, 100),0.5*themostepicmultiplierever, CHAN_STATIC)    
        end
    end)
end )



net.Receive( "dynrev_BulletCrack", function( len, ply )
    --LocalPlayer():SetDSP(35)
    --EmitSound( Sound( bulletcracks[math.random(#bulletcracks)] ), LocalPlayer():GetPos(), 1, CHAN_STATIC, 1, 75, 0, math.random(75, 100) )
    print("cracking client")
    surface.PlaySound(bulletcracks[math.random(#bulletcracks)])
    --surface.PlaySound("tails/dynrev_muffler2.wav")
end )