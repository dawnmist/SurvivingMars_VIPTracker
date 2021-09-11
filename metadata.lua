return PlaceObj('ModDef', {
	'title', "VIP Tracker",
	'image', "Preview.png",
	'last_changes', "Below & Beyond compatibility update",
	'ignore_files', {
		"*Images/*",
		"*.git/*",
		"*.gitattributes",
		"*README.md",
		"*UI/ColonistIconTemplate.xcf",
	},
	'id', "Dawnmist_VIPTracker",
	'steam_id', "1574069378",
	'pops_desktop_uuid', "ba93d8c2-8fc8-45e0-bc19-5505c05c6014",
	'pops_any_uuid', "2059cfcb-6603-457a-b6f4-0952f821df06",
	'author', "Dawnmist",
	'version', 19,
	'lua_revision', 1007000,
	'saved_with_revision', 1007000,
	'code', {"Code/VIPTracker.lua", "Code/VIPTrackerTemplates.lua"},
	'saved', 1631257445,
	'TagInterface', true,
	'TagTools', true,
	'TagOther', true,
	'description', [[
[h1]VIP Tracker[/h1]

This mod is Below and Beyond compatible (both base game only, and any expansions up to B&B).

This mod enables you to mark individual colonists as ones that you wish to track. These colonists are given a Quirk called "VIP" so that they can be listed in the Colony Command Center colonist filters. Double-clicking on a colonist in this colonist list will zoom you to where they are.

VIP Tracker keeps a log of VIP colonists' life changes, recording events such as moving to a new Dome, graduating University, getting older, and changing job.

When a VIP dies, the mod keeps track of their age at death, the Sol they died, and what their cause of death was. A notification is popped up that allows you to zoom to the dead VIP.

When a VIP boards a rocket to return to Earth, the mod keeps track of their age at time of boarding and the Sol that they boarded the rocket. A notification is popped up that allows you to cycle through the names of VIPs that are leaving Mars.

Two new options are added to the Colony Command Center. The first option - "VIP Activity Log" - provides the ongoing record of events in the lives of VIPs. The second option - "Departed VIPs" - provides a record of the VIPs that have either died or returned to Earth.

[h1]Acknowledgements[/h1]

The original idea for this mod came from CheTranqui with the mod "Neighbourhood Watch". VIP Tracker is a complete rewrite of the ideas from "Neighbourhood Watch" made with CheTranqui's blessing.

Other people that helped with working out how to make parts of the mod work include ChoGGi and SkiRich, plus others in the Surviving Mars Modding Discord.

[h1]Source and Bug Reports[/h1]

VIP Tracker is hosted at Github at https://github.com/dawnmist/SurvivingMars_VIPTracker and bug reports can also be created at Github.
VIP Tracker has also been published to NexusMods at https://www.nexusmods.com/survivingmars/mods/99
And to Paradox Mods at https://mods.paradoxplaza.com/mods/667/Any
You can also leave me a message in the "#dawnmist's-mods" channel in the Surviving Mars Discord.
	]]
})