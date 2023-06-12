print("[DWR] Convar file loaded")

CreateConVar("cl_dwr_volume", "100", {FCVAR_ARCHIVE}, "Global volume multiplier", 0, 100)

--CreateConVar("cl_vr_disable_distance_checks", "0", {FCVAR_ARCHIVE}, "Disables... distance checks!", 0, 1)
CreateConVar("cl_dwr_disable_soundspeed", "1", {FCVAR_ARCHIVE}, "Disable delay caused by sound travel speed", 0, 1)

CreateConVar("cl_dwr_disable_indoors_reverb", "0", {FCVAR_ARCHIVE}, "Disable reverb if the source is indoors", 0, 1)

CreateConVar("cl_dwr_disable_outdoors_reverb", "0", {FCVAR_ARCHIVE}, "Disable reverb if the source is outdoors", 0, 1)

CreateConVar("cl_dwr_disable_reverb", "0", {FCVAR_ARCHIVE}, "Disable literally all the reverb", 0, 1)

CreateConVar("cl_dwr_soundspeed", "343", {FCVAR_ARCHIVE}, "Speed of sound (m/s)", 0, 100000)

CreateConVar("cl_dwr_occlusion_rays", "32", {FCVAR_ARCHIVE}, "Amount of traces ran from the player to the sound source in order to determine the effects")

CreateConVar("cl_dwr_occlusion_rays_reflections", "0", {FCVAR_ARCHIVE}, "Maximum amount of times rays can reflect (0 - disable reflections)")

CreateConVar("cl_dwr_occlusion_rays_max_distance", "100000", {FCVAR_ARCHIVE}, "Rays will be rejected if they're longer than this distance (in hammer units a.k.a inches)")

CreateConVar("cl_dwr_process_everything", "0", {FCVAR_ARCHIVE}, "Will do modifications to every sound emitted by entities. (sound occlusion, volume falloff)")

CreateConVar("cl_dwr_disable_bulletcracks", "0", {FCVAR_ARCHIVE}, "Bullet crackhead DISALBE")