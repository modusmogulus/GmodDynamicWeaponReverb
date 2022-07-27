print("[DWR] Convar file loaded")

CreateConVar("cl_dwr_volume", "100", {FCVAR_ARCHIVE}, "Global volume multiplier", 0, 100)
CreateConVar("cl_vr_disable_distance_checks", "0", {FCVAR_ARCHIVE}, "Disables... distance checks!", 0, 1)
CreateConVar("cl_dwr_disable_soundspeed", "1", {FCVAR_ARCHIVE}, "Disable delay caused by sound travel speed", 0, 1)
CreateConVar("cl_dwr_disable_indoors_reverb", "0", {FCVAR_ARCHIVE}, "Disable reverb if the source is indoors", 0, 1)
CreateConVar("cl_dwr_disable_outdoors_reverb", "0", {FCVAR_ARCHIVE}, "Disable reverb if the source is outdoors", 0, 1)
CreateConVar("cl_dwr_disable_reverb", "0", {FCVAR_ARCHIVE}, "Disable literally all the reverb", 0, 1)
CreateConVar("cl_dwr_soundspeed", "343", {FCVAR_ARCHIVE}, "Speed of sound", 0, 1000) -- needs to be converted by this * 1.905, default is sound speed in air @20C
CreateConVar("cl_dwr_occlusion_rays", "32", {FCVAR_ARCHIVE}, "Amount of traces ran from the player to the sound source in order to determine the effects")
CreateConVar("cl_dwr_debug", "0", {FCVAR_ARCHIVE}, "deez bugs")

