return PlaceObj('ModDef', {
	'title', "VIP Tracker",
	'id', "Dawnmist_VIPTracker",
	'steam_id', "1574069378",
	'image', "Preview.png",
	'last_changes', [[Created a new category report "VIP Activity Log" that records a log of life changes (e.g. new traits, graduating university, getting older, moving domes, etc) for VIPs.]],
	'author', "Dawnmist",
	'version', 11,
	'lua_revision', 237920,
	'code', {
		"Code/VIPTracker.lua"
	},
	'saved', 1543635347,
	'TagInterface', true,
	'TagTools', true,
	'TagOther', true,
	'ignore_files', {
		"*Images/*",
		"*.git/*",
		"*.gitattributes",
		"*README.md",
		"*UI/ColonistIconTemplate.xcf"
	},
	'description', [[
[h1]VIP Tracker[/h1]

This mod is Gagarin compatible (both base game and with Space Race).

[i][b]New Feature: VIP Activity Log.[/b]
Keep a log of VIP colonists' life changes, such as moving to a new Dome, graduating University, getting older. Since this is data that wasn't being recorded previously, it will only show life changes that occur after the installation of this update.[/i]

This mod enables you to mark individual colonists as ones that you wish to track. These colonists are given a Quirk called "VIP" so that they can be listed in the Colony Command Center colonist filters. Double-clicking on a colonist in this colonist list will zoom you to where they are.

When a VIP dies, the mod keeps track of their age at death, the Sol they died, and what their cause of death was. A notification is popped up that allows you to zoom to the dead VIP.

When a VIP boards a rocket to return to Earth, the mod keeps track of their age at time of boarding and the Sol that they boarded the rocket. A notification is popped up that allows you to cycle through the names of VIPs that are leaving Mars.

Two new options are added to the Colony Command Center. The first option - "VIP Activity Log" - provides an ongoing record of changes in the lives of VIPs - items like moving to a new Dome, graduating University, getting older, etc. The second option - "Departed VIPs" - provides a record of the VIPs that have either died or returned to Earth.

[h1]Acknowledgements[/h1]

The original idea for this mod came from CheTranqui with the mod "Neighbourhood Watch". VIP Tracker is a complete rewrite of the ideas from "Neighbourhood Watch" made with CheTranqui's blessing.

Other people that helped with working out how to make parts of the mod work include ChoGGi and SkiRich, plus others in the Surviving Mars Modding Discord.

[h1]Source and Bug Reports[/h1]

VIP Tracker is hosted at Github at https://github.com/dawnmist/SurvivingMars_VIPTracker and bug reports can also be created at Github.
VIP Tracker has also been published to NexusMods at https://www.nexusmods.com/survivingmars/mods/99
	]]
})