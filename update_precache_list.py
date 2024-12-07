# run everytime you add a new sound

import os

def listFiles(root):
    allFiles = []; walk = [root]
    while walk:
        folder = walk.pop(0)+"/"; items = os.listdir(folder)
        for i in items: i=folder+i; (walk if os.path.isdir(i) else allFiles).append(i)
    for index, file in enumerate(allFiles):
    	allFiles[index] = file.replace("dwrV3/sound/", "").lower()
    return allFiles


stringArray = str(listFiles("dwrV3/sound/dwr"))
stringArray = stringArray.replace("[", "{").replace("]", "}")

precacheLua = "-- Automatically generated by update_precache_list.py\n"
precacheLua += "-- Please don't change anything here and instead refer to the script in question.\n"
precacheLua += f"dwr_reverbFiles = {stringArray}\n"

print(precacheLua)

with open("dwrV3\\lua\\autorun\\!dwr_precache.lua", "w+") as file:
	file.write(precacheLua)
