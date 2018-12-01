-- All save-game variables are stored within the "VIPTracker" variable.
GlobalVar("VIPTracker", false)

local ModId = "Dawnmist_VIPTracker"
local VIPTraitId = "VIPTrackerTrait"
local VIPDeadId = "VIPTrackerDead"
local VIPActivityLogId = "VIPTrackerActivityLog"
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
		self.idButtonIcon:SetImage(context.pin_icon)
		return
	elseif row_type == "VIPActivityLog" then
		self.idButtonIcon:SetImage(context.pin_icon)
		self.idSpecialization:SetImage(context.pin_specialization_icon)
		self.name:SetText(context.name)
		self.sol:SetText(context.sol)
		self.log_msg:SetText(context.log_msg)
		return
	end
	origUpdateUICommandCenterRow(self, context, row_type)
end

local function FixupDeathReasons()
	local VIPTracker = VIPTracker
	for i=1,#VIPTracker.DepartedList do
		local colonist = VIPTracker.DepartedList[i]
		colonist.vip_died_reason = GetDeathReason(colonist)
	end
end

local function SetupSaveData()
	GuruTraitBlacklist[VIPTraitId] = true

	if not VIPTracker then
		VIPTracker = {
			ColonistsHaveArrived = UICity and UICity.labels.Colonist and #UICity.labels.Colonist > 0 or false,
			DepartedList = { name = "Departed VIPs" },
			ActivityLog = { name = "VIP Activity Log" },
			Version = VIPTrackerMod.current_version
		}
	elseif VIPTracker.Version == nil or VIPTracker.Version < 8 then
		-- fixup death reasons based on changes from initial release
		DelayedCall(1000, FixupDeathReasons)
	end

	-- Update list name for addition of colonists that returned to Earth, v9 => v10.
	if VIPTracker.DeceasedList ~= nil and VIPTracker.DepartedList == nil then
		VIPTracker.DepartedList = VIPTracker.DeceasedList
		VIPTracker.DeceasedList = nil
	end

	-- Create ActivityLog for pre-existing saves, v10 => v11.
	if VIPTracker.ActivityLog == nil then
		VIPTracker.ActivityLog = { name = "VIP Activity Log" }
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

local function VIPLeavingNotification(colonist)
	local NotificationId = "VIPTracker_VIPLeavingNotice"
	local existingIndex = table.find(g_ActiveOnScreenNotifications, 1, NotificationId)
	local cycle_objs = { colonist }
	if existingIndex then
		table.append(cycle_objs, g_ActiveOnScreenNotifications[existingIndex][3].cycle_objs)
	end

	CreateRealTimeThread(
		function()
			AddCustomOnScreenNotification(
				NotificationId,
				T{987234920030, "<Count> <Plural> leaving Mars"},
				T{987234920031, "<Name>"},
				DeathNotificationIcon,
				function(cur_obj, params, res)
					local dlg = Dialogs.OnScreenNotificationsDlg
					if dlg then
						local popup = table.find_value(dlg.idNotifications, "notification_id", NotificationId)
						if popup then
							popup.idText:SetText(T{987234920031, "<Name>",
								Name = cur_obj.name
							})
						end
					end
				end,
				{
					Count = #cycle_objs,
					Plural = #cycle_objs > 1 and T{987234920028, "VIPs"} or T{987234920001,"VIP"},
					Name = colonist.name,
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
	return IsValid(colonist) and not isDying and isDying ~= nil and not colonist.leaving
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
			display_name = T{987234920022, "Departed VIPs"},
			group = "Default",
			id = VIPDeadId,
			template_name = "VIPDeadOverview",
			title = T{987234920023, "DEPARTED VIPS"},
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

local function AddVIPActivityLogCategory()
	local XTemplates = XTemplates
	local PlaceObj = PlaceObj
	local Presets = Presets

	if not Presets.ColonyControlCenterCategory.Default[VIPActivityLogId] then
		Presets.ColonyControlCenterCategory.Default[VIPActivityLogId] = PlaceObj('ColonyControlCenterCategory', {
			SortKey = 89000,
			display_name = T{987234920053,"VIP Activity Log"},
			group = "Default",
			id = VIPActivityLogId,
			template_name = "VIPActivityOverview",
			title = T{987234920054, "VIP ACTIVITY LOG"},
		})
	end

	local CCC = XTemplates.ColonyControlCenter[1]
	for i=1, #CCC do
		if CCC[i].Id == "idContent" then
			local idContent = CCC[i]
			local modeNum
			local mode = PlaceObj('XTemplateMode', {
				'mode', VIPActivityLogId,
			}, {
				PlaceObj('XTemplateTemplate', {
					'__template', "VIPActivityOverview"
				})
			})
			for m = 1, #idContent do
				if idContent[m].mode == VIPActivityLogId then
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

local function AdjustActivityLogSelect()
	local XT = XTemplates.CommandCenterRow

	if XT == nil then
		return
	end

	for i=1,#XT[1] do
		local item = XT[1][i]
		if item ~= nil and item.name == "OnMouseButtonDoubleClick(self, pos, button)" then
			local origFunc = item.func
			item.func = function(self, pos, button)
				if self.context.id == VIPActivityLogId then
					if button == "L" then
						local colonist = self.context.colonist
						if colonist ~= nil and IsValid(colonist) and IsLiving(colonist) then
								ViewObjectMars(colonist)
								SelectObj(colonist)
								CloseCommandCenter()
								return "break"
						end
					end
				else
					return origFunc(self, pos, button)
				end
			end
			return
		end
	end
end

local function AddActivityLog(colonist, msg)
	table.insert(VIPTracker.ActivityLog, 1, {
			id = VIPActivityLogId,
			colonist = colonist,
			pin_icon = colonist.pin_icon,
			pin_specialization_icon = colonist.pin_specialization_icon,
			name = colonist.name,
			sol = UICity.day,
			log_msg = msg
		})
end

-- OnMsg functions
function OnMsg.ClassesPostprocess()
	CreateVIPTrait()
	AddVIPToggleButton()
	AddVIPActivityLogCategory()
	AddVIPDeadCategory()
	AdjustActivityLogSelect()
end

function OnMsg.ColonistArrived()
	local VIPTracker = VIPTracker
	if not VIPTracker.ColonistsHaveArrived then
		VIPTracker.ColonistsHaveArrived = true
	end
end

function OnMsg.ColonistChangeWorkplace(colonist, new_workplace, old_workplace)
	if colonist.traits[VIPTraitId] and IsLiving(colonist) then
		AddActivityLog(
			colonist,
			T{987234920032, "Changed job from <OldWorkplace> to <NewWorkplace>",
				OldWorkplace =
					old_workplace and old_workplace.display_name
					or T{987234920039, "unemployed"},
				NewWorkplace =
					new_workplace and new_workplace.display_name
					or T{987234920039, "unemployed"}
			}
	  );
	end
end

function OnMsg.SanityBreakdown(colonist)
	if colonist.traits[VIPTraitId] and IsLiving(colonist) then
		AddActivityLog(colonist, T{987234920034, "Suffered a Sanity breakdown"})
	end
end

-- Would prefer to use "OnMsg.NewSpecialist" directly, but it doesn't provide the colonist info.
local originalSetSpecialization = Colonist.SetSpecialization
function Colonist.SetSpecialization(self, specialist, init)
	if originalSetSpecialization ~= nil then
		originalSetSpecialization(self, specialist, init)
	end
	if self.traits[VIPTraitId]
		and IsLiving(colonist)
		and init == nil
		and specialist ~= nil
		and specialist ~= "none"
	then
		AddActivityLog(
			colonist,
			T{987234920035, "Graduated as a <Specialist>", Specialist = specialist}
		)
	end
end

function OnMsg.ColonistJoinsDome(colonist, dome)
	if colonist.traits[VIPTraitId] and IsLiving(colonist) then
		AddActivityLog(colonist, T{987234920036, "Moved to <Dome>", Dome = dome.name})
	end
end

function OnMsg.ColonistAddTrait(colonist, trait_id, init)
	if (colonist.traits[VIPTraitId] or trait_id == VIPTraitId)
		and IsLiving(colonist)
		and init == nil
	then
		local trait = TraitPresets[trait_id]
		if not trait then
			return
		end

		if trait_id == VIPTraitId or trait_id == "Renegade" then
			AddActivityLog(colonist, T{987234920057, "Became a <Trait>", Trait = trait.display_name})
		elseif trait.group == "Age Group" then
			AddActivityLog(colonist, T{987234920033, "Aged to <NewAge>", NewAge = trait.display_name})
		elseif trait.group == "Specialization" then
			AddActivityLog(colonist, T{987234920035, "Graduated as a <Specialist>", Specialist = trait.display_name})
		else
			AddActivityLog(colonist, T{987234920037, "Gained the <Trait> trait", Trait = trait.display_name})
		end
	end
end

function OnMsg.ColonistRemoveTrait(colonist, trait_id)
	if (colonist.traits[VIPTraitId] or trait_id == VIPTraitId) and IsLiving(colonist) then
		local trait = TraitPresets[trait_id]
		if not trait then
			return
		end

		if trait_id == VIPTraitId or trait_id == "Renegade" then
			AddActivityLog(colonist, T{987234920058, "Is no longer a <Trait>", Trait = trait.display_name})
		elseif trait.group ~= "Age Group" and trait.group ~= "Specialization" then
			AddActivityLog(
				colonist,
				T{987234920038, "Lost the <Trait> trait", Trait = trait.display_name}
			)
		end
	end
end

function OnMsg.ColonistStatusEffect(colonist, status_effect, bApply, now)
	if colonist.traits[VIPTraitId] and IsLiving(colonist) then
		if status_effect == "StatusEffect_Starving" then
			AddActivityLog(
				colonist,
				bApply and T{987234920040, "Suffering from starvation"}
				or T{987234920041, "Is no longer starving"}
			)
		elseif status_effect == "StatusEffect_Homeless" then
			AddActivityLog(
				colonist,
				bApply and T{987234920042, "Became homeless"}
				or T{987234920043, "Moved into the <Residence>",
					Residence = colonist:GetResidenceDisplayName()
				}
			)
		elseif status_effect == "StatusEffect_Earthsick" then
			AddActivityLog(
				colonist,
				bApply and T{987234920042, "Became Earthsick"}
				or T{987234920045, "Is no longer Earthsick"}
			)
		elseif status_effect == "StatusEffect_Suffocating" then
			AddActivityLog(
				colonist,
				bApply and T{987234920046, "Suffering from suffocation"}
				or T{987234920047, "Is no longer suffering from suffocation"}
			)
		elseif status_effect == "StatusEffect_Dehydrated" then
			AddActivityLog(
				colonist,
				bApply and T{987234920048,"Suffering from dehydration"}
				or T{987234920049, "Is no longer dehydrated"}
			)
		elseif status_effect == "StatusEffect_Freezing" then
			AddActivityLog(
				colonist,
				bApply and T{987234920050, "Suffering from freezing"}
				or T{987234920051, "Is no longer freezing"}
			)
		elseif status_effect == "StatusEffect_Irradiated" and bApply then
			AddActivityLog(colonist, T{987234920052, "Was Irradiated"})
		end
	end
end

function OnMsg.ColonistDied(colonist, reason)
	if colonist.traits[VIPTraitId] then
		colonist.vip_died_sol = UICity.day
		colonist.vip_died_reason = T{987234920004, "<Reason>", Reason = GetDeathReason(colonist)}
		table.insert(VIPTracker.DepartedList, 1, colonist)
		VIPDeathNotification(colonist, reason)
		AddActivityLog(colonist, colonist.vip_died_reason)
	end
end

function OnMsg.ColonistLeavingMars(colonist, rocket)
	if colonist.traits[VIPTraitId] then
		VIPLeavingNotification(colonist)
		colonist.vip_died_sol = UICity.day
		colonist.vip_died_reason = T{987234920029, "Abandoned Mars to return to Earth"}
		table.insert(VIPTracker.DepartedList, 1, colonist)
		AddActivityLog(colonist, colonist.vip_died_reason)
	end
end

function OnMsg.ColonistBorn(colonist, event)
	if colonist.traits[VIPTraitId] and event == "reborn" then
		AddActivityLog(colonist, T{987234920059, "Reborn through Project Phoenix"})
	end
end

function OnMsg.CityStart()
	SetupSaveData()
end

function OnMsg.LoadGame()
	SetupSaveData()
end
