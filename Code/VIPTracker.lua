-- All save-game variables are stored within the "VIPTracker" variable.
GlobalVar("VIPTracker", false)

local ModId = "Dawnmist_VIPTracker"
local VIPTraitId = "VIPTrackerTrait"
local VIPDeadId = "VIPTrackerDead"
local mod_dir = CurrentModPath

local ColonistActiveVIPIcon = mod_dir.."UI/AllGold.png"
local ColonistInactiveVIPIcon = mod_dir.."UI/AllGrey.png"
local DeathNotificationIcon = mod_dir.."UI/VIPDeathNotificationIcon.png"

-- Non-saved global
VIPTrackerMod = {
	current_version = Mods[ModId].version,
	Functions = {},
}

-- To update, @see SurvivingMars/Lua/_GameConst.lua
local VIPDeathReasons = 
{
	["meteor"]              = T{987234920005, "a meteor impact"},
	["lighting strike"]     = T{987234920006, "being struck by lighting"},
	["fuel explosion"]      = T{987234920007, "a fuel explosion"},
	["low health"]          = T{987234920008, "low health"},
	["Old age"]             = T{987234920009, "old age"},
	["could not reach dome"]= T{987234920010, "their spacesuit running out of Oxygen"},
	["could not find dome"] = T{987234920010, "their spacesuit running out of Oxygen"},
	["suicide"]             = T{987234920011, "suicide (low sanity)"},
	["rogue drone"]         = T{987234920012, "being killed by a rogue machine"},

	["StatusEffect_Suffocating"]         = T{987234920013, "suffocation"},
	["StatusEffect_Suffocating_Outside"] = T{987234920013, "suffocation"},

	["StatusEffect_Dehydrated"] = T{987234920014, "dehydration"},
	["StatusEffect_Freezing"]   = T{987234920015, "hypothermia"},
	["StatusEffect_Starving"]   = T{987234920016, "starvation"},

	["StoryBit"]     = T{987234920017, "extenuating circumstances"},
	["DustSickness"] = T{987234920018, "dust sickness"},

	-- used if no reason was given...maybe someone murdered them... ;)
	["unknown"] = T{987234920019, "mysterious circumstances"},
}

-- Allow other mods to register additional death reasons.
-- "reason" => the value stored in colonist.dying_reason
-- "reason_msg" => translated string to display with "<colonist.name> has died from <reason_msg>".
-- if not specified, reason itself will be displayed by default.
-- This function should be used inside the VIPTrackerModLoaded message handler.
VIPTrackerMod.Functions.AddDeathReason = function(reason, reason_msg)
	if not VIPDeathReasons[reason] and reason and reason_msg then
		VIPDeathReasons[reason] = reason_msg
	end
end

local origUpdateUICommandCenterRow = UpdateUICommandCenterRow
function UpdateUICommandCenterRow(self, context, row_type)
	if row_type == "deadVIP" then
		self.diedSol:SetText(context.vip_died_sol)
		self.ageAtDeath:SetText(context.age)
		self.deathReason:SetText(context.vip_died_reason)
		self.idSpecialization:SetImage(context.pin_specialization_icon)
	end
	origUpdateUICommandCenterRow(self, context, row_type)
end

local function SetupSaveData()
	GuruTraitBlacklist[VIPTraitId] = true
	if not VIPTracker then
		VIPTracker = {
			ColonistsHaveArrived = UICity and UICity.labels.Colonist and #UICity.labels.Colonist > 0 or false,
			DeceasedList = { name = "Deceased VIPs" }
		}
	end
end

local function GetDeathReason(colonist)
	local reason = colonist.dying_reason
	return (reason and VIPDeathReasons[reason] ~= nil and VIPDeathReasons[reason])
		or reason or VIPDeathReasons["unknown"]
end

local function VIPDeathNotification(colonist)
	local Reason = GetDeathReason(colonist)
	CreateRealTimeThread(
		function()
			AddCustomOnScreenNotification(
				"VIPTracker_VIPDeathNotice",
				T{987234920003, "VIP <Name> died!"},
				T{987234920004, "Died from <Reason>"},
				DeathNotificationIcon,
				nil,
				{
					DeadColonist = colonist,
					Name = colonist.name,
					Reason = Reason,
					expiration = 75000,
					priority = "Important",
					cycle_objs = { colonist } 
				}
			)
		end
	)
end

local function IsLiving(colonist)
	local isDying = Colonist.IsDying(colonist)
	return IsValid(colonist) and not isDying and isDying ~= nil
end

local function ToggleVIP(colonist)
	if IsValid(colonist) then
		if not colonist.traits[VIPTraitId] then
			colonist:AddTrait(VIPTraitId)
		else
			colonist:RemoveTrait(VIPTraitId)
		end
	end
end

local function UpdateColonistInfopanel(dialog, colonist)
	if not IsLiving(colonist) then
		dialog:SetVisible(false)
	else
		dialog:SetVisible(true)
		if colonist.traits[VIPTraitId] then
			dialog:SetIcon(ColonistActiveVIPIcon)
			dialog:SetRolloverText(T{987234920021, --[[XTemplate ipColonist RolloverText]] "<Name> is a VIP. Click to remove VIP status.", Name = colonist.name })
		else
			dialog:SetIcon(ColonistInactiveVIPIcon)
			dialog:SetRolloverText(T{987234920020, --[[XTemplate ipColonist RolloverText]] "Add <Name> to the VIP list.", Name = colonist.name })
		end
	end
end

local function CreateVIPTrait()
	local PlaceObj = PlaceObj
	local TraitPresets = TraitPresets

	-- Trait to use to track VIPs
	if not TraitPresets[VIPTraitId] then
		TraitPresets[VIPTraitId] = PlaceObj('TraitPreset', {
			auto = false,
			display_name = T{987234920001, --[[TraitPreset VIP display_name]] "VIP"},
			description = T{987234920002, --[[TraitPreset VIP description]] "VIP colonists are being tracked by VIP Tracker."},
			dome_filter_only = true,
			group = "other",
			id = VIPTraitId,
			rare = false,
			show_in_traits_ui = true,
			hidden_on_start = true,
		})
	end
end

local function AddVIPToggleButton()
	local XT = XTemplates.ipColonist[1] or empty_table
	local VIPControlButtonID = "VIPTrackerButton"
	local VIPControlButtonVer = "v1.0"

	if not XT.VIPControlButton then
		XT.VIPControlButton = true
		XT[#XT + 1] = PlaceObj('XTemplateTemplate', {
			'Version', VIPControlButtonVer,
			'UniqueID', VIPControlButtonID,
			'Id', VIPControlButtonID,
			'__context_of_kind', "Colonist",
			'__condition', function(parent, context) return IsLiving(context) end,
			'__template', "InfopanelButton",
			'RolloverTitle', T{987234920001, --[[XTemplate ipColonist RolloverTitle]] "VIP"},
			'RolloverText', T{987234920020, --[[XTemplate ipColonist RolloverText]] "Add <Name> to the VIP list."},
			'OnContextUpdate', function (self, context) UpdateColonistInfopanel(self, context) end,
			'OnPress', function (self, gamepad)
				ToggleVIP(self.context)
				UpdateColonistInfopanel(self, self.context)
			end,
		})
	end
end

local function AddVIPDeadCategory()
	local XTemplates = XTemplates
	local PlaceObj = PlaceObj
	local Presets = Presets

	if not Presets.ColonyControlCenterCategory.Default[VIPDeadId] then
		Presets.ColonyControlCenterCategory.Default[VIPDeadId] = PlaceObj('ColonyControlCenterCategory', {
			SortKey = 90000,
			display_name = T{987234920022, "Deceased VIPs"},
			group = "Default",
			id = VIPDeadId,
			template_name = "VIPDeadOverview",
			title = T{987234920023, "DECEASED VIPS"},
		})
	end

	local CCC = XTemplates.ColonyControlCenter[1]
	for i=1, #CCC do
		if CCC[i].Id == "idContent" then
			local idContent = CCC[i]
			local modeNum
			local mode = PlaceObj('XTemplateMode', {
				'mode', VIPDeadId,
			}, {
				PlaceObj('XTemplateTemplate', {
					'__template', "VIPDeadOverview"
				})
			})
			for m = 1, #idContent do
				if idContent[m].mode == VIPDeadId then
					modeNum = m
					break
				end
			end
			if modeNum ~= nil then
				idContent[modeNum] = mode
			else
				table.insert(idContent, mode)
			end
		end
	end
end

-- OnMsg functions
function OnMsg.ClassesPostprocess()
	CreateVIPTrait()
	AddVIPToggleButton()
	AddVIPDeadCategory()
end

function OnMsg.ModsReloaded()
	Msg("VIPTrackerModLoaded", VIPTrackerMod.current_version)
end

function OnMsg.ColonistArrived()
	local VIPTracker = VIPTracker
	if not VIPTracker.ColonistsHaveArrived then
		VIPTracker.ColonistsHaveArrived = true
	end
end

function OnMsg.ColonistDied(colonist, reason)
	if colonist.traits[VIPTraitId] then
		VIPDeathNotification(colonist, reason)
		colonist.vip_died_sol = UICity.day
		colonist.vip_died_reason = T{987234920004, "Died from <Reason>", Reason = GetDeathReason(colonist)}
		table.insert(VIPTracker.DeceasedList, colonist)
	end
end

function OnMsg.CityStart()
	SetupSaveData()
end

function OnMsg.LoadGame()
	SetupSaveData()
end
