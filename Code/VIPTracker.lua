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
	["meteor"]              = T{987234920005, "Died from a meteor impact"},
	["lighting strike"]     = T{987234920006, "Died from being struck by lighting"},
	["fuel explosion"]      = T{987234920007, "Died from a fuel explosion"},
	["low health"]          = T{987234920008, "Died from low health"},
	["Old age"]             = T{987234920009, "Died from old age"},
	["could not reach dome"]= T{987234920010, "Died from their spacesuit running out of Oxygen"},
	["could not find dome"] = T{987234920010, "Died from their spacesuit running out of Oxygen"},
	["suicide"]             = T{987234920011, "Died from suicide (low sanity)"},
	["rogue drone"]         = T{987234920012, "Died from being killed by a rogue machine"},

	["StatusEffect_Suffocating"]         = T{987234920013, "Died from suffocation"},
	["StatusEffect_Suffocating_Outside"] = T{987234920013, "Died from suffocation"},

	["StatusEffect_Dehydrated"] = T{987234920014, "Died from dehydration"},
	["StatusEffect_Freezing"]   = T{987234920015, "Died from hypothermia"},
	["StatusEffect_Starving"]   = T{987234920016, "Died from starvation"},

	["StoryBit"]     = T{987234920017, "Died from extenuating circumstances"},
	["DustSickness"] = T{987234920018, "Died from dust sickness"},

	-- used if no reason was given...maybe someone murdered them... ;)
	["unknown"] = T{987234920019, "Died from mysterious circumstances"},
}

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

local function FixupDeathReasons()
	local VIPTracker = VIPTracker
	for i=1,#VIPTracker.DeceasedList do
		local colonist = VIPTracker.DeceasedList[i]
		colonist.vip_died_reason = GetDeathReason(colonist)
	end
end

local function SetupSaveData()
	GuruTraitBlacklist[VIPTraitId] = true
	if not VIPTracker then
		VIPTracker = {
			ColonistsHaveArrived = UICity and UICity.labels.Colonist and #UICity.labels.Colonist > 0 or false,
			DeceasedList = { name = "Deceased VIPs" },
			Version = VIPTrackerMod.current_version
		}
	elseif VIPTracker.Version == nil or VIPTracker.Version < 8 then
		-- fixup death reasons based on changes from initial release
		DelayedCall(1000, FixupDeathReasons)
	end

	VIPTracker.Version = VIPTrackerMod.current_version
end

local function GetDeathReason(colonist)
	local reason = colonist.dying_reason
	return (reason and VIPDeathReasons[reason] ~= nil and VIPDeathReasons[reason])
		or reason and DeathReasons[reason]
		or VIPDeathReasons["unknown"]
end

local function VIPDeathNotification(colonist)
	local NotificationId = "VIPTracker_VIPDeathNotice"
	local existingIndex = table.find(g_ActiveOnScreenNotifications, 1, NotificationId)
	local cycle_objs = { colonist }
	if existingIndex then
		table.append(cycle_objs, g_ActiveOnScreenNotifications[existingIndex][3].cycle_objs)
	end

	CreateRealTimeThread(
		function()
			AddCustomOnScreenNotification(
				NotificationId,
				T{987234920003, "<Count> <Plural> died: <Name>"},
				T{987234920004, "<Reason>"},
				DeathNotificationIcon,
				function(cur_obj, params, res)
					local dlg = Dialogs.OnScreenNotificationsDlg
					if dlg then
						local popup = table.find_value(dlg.idNotifications, "notification_id", NotificationId)
						if popup then
							popup.idTitle:SetText(T{987234920003, "<Count> <Plural> died: <Name>",
								Count = params.Count,
								Plural = params.Plural,
								Name = cur_obj.name
							})
							popup.idText:SetText(T{987234920004, "<Reason>", Reason = cur_obj.vip_died_reason})
						end
					end
				end,
				{
					Count = #cycle_objs,
					Plural = #cycle_objs > 1 and T{987234920028, "VIPs"} or T{987234920001,"VIP"},
					Name = colonist.name,
					Reason = colonist.vip_died_reason,
					expiration = 75000,
					priority = "Important",
					game_time = true,
					cycle_objs = cycle_objs
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

function OnMsg.ColonistArrived()
	local VIPTracker = VIPTracker
	if not VIPTracker.ColonistsHaveArrived then
		VIPTracker.ColonistsHaveArrived = true
	end
end

function OnMsg.ColonistDied(colonist, reason)
	if colonist.traits[VIPTraitId] then
		colonist.vip_died_sol = UICity.day
		colonist.vip_died_reason = T{987234920004, "<Reason>", Reason = GetDeathReason(colonist)}
		table.insert(VIPTracker.DeceasedList, 1, colonist)
		VIPDeathNotification(colonist, reason)
	end
end

function OnMsg.CityStart()
	SetupSaveData()
end

function OnMsg.LoadGame()
	SetupSaveData()
end
