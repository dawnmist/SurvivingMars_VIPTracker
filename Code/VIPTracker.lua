-- All save-game variables are stored within the "VIPTracker" variable.
GlobalVar("VIPTracker", false)

local ModId = "Dawnmist_VIPTracker"
local VIPTraitId = "VIPTrackerTrait"
local VIPDepartedId = "VIPTrackerDead"
local VIPActivityLogId = "VIPTrackerActivityLog"
local mod_dir = CurrentModPath

local ColonistActiveVIPIcon = mod_dir.."UI/AllGold.png"
local ColonistInactiveVIPIcon = mod_dir.."UI/AllGrey.png"
local DeathNotificationIcon = mod_dir.."UI/VIPDeathNotificationIcon.png"

-- Compatibility with SkiRich's IA mod - better trait gain/loss messages.
local IAtraitParolee       = "Parolee"
local IAtraitFormerOfficer = "Former_Officer"

-- Non-saved global
VIPTrackerMod = {
	ActivityOverview = "VIPTrackerActivityOverview",
	ActivityOverviewRow = "VIPTrackerActivityOverviewRow",
	DepartedOverview = "VIPTrackerDepartedOverview",
	DepartedOverviewRow = "VIPTrackerDepartedOverviewRow",
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

	-- clean out oops during development
	-- for i=#(VIPTracker.ActivityLog or empty_table),1,-1 do
	-- 	local log = VIPTracker.ActivityLog[i]
	-- 	if IsValid(log.colonist) and not log.colonist.traits[VIPTraitId] then
	-- 		table.remove(VIPTracker.ActivityLog, i)
	-- 	end
	-- end

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

local function AddCccCategory(sort_key, id, template_name, display_name, title)
	local XTemplates = XTemplates
	local PlaceObj = PlaceObj
	local Presets = Presets
	local VIPTrackerMod = VIPTrackerMod

	if Presets.ColonyControlCenterCategory.Default[id] then
		return
	end

	Presets.ColonyControlCenterCategory.Default[id] = PlaceObj('ColonyControlCenterCategory', {
			SortKey = sort_key,
			id = id,
			template_name = template_name,
			display_name = display_name,
			title = title,
		})

	local CCC = XTemplates.ColonyControlCenter
	if CCC then
		local idContent
		for i, child in ipairs(CCC[1] or empty_table) do
			if IsKindOf(child, "XTemplateWindow") and child.Id == "idContent" then
				idContent = child
				break
			end
		end
		if idContent then
			local new_mode = PlaceObj('XTemplateMode', { 'mode', id, },
			{
				PlaceObj('XTemplateTemplate', { '__template', template_name })
			})
			table.insert(idContent, new_mode)
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
function OnMsg.ClassesBuilt()
	local VIPTrackerMod = VIPTrackerMod
	local ActivityOverview = VIPTrackerMod.ActivityOverview
	local DepartedOverview = VIPTrackerMod.DepartedOverview

	AddCccCategory(
		89000,
		VIPActivityLogId,
		ActivityOverview, 
		T{987234920053,"VIP Activity Log"},
		T{987234920054, "VIP ACTIVITY LOG"}
	)
	AddCccCategory(
		90000,
		VIPDepartedId,
		DepartedOverview,
		T{987234920022, "Departed VIPs"},
		T{987234920023, "DEPARTED VIPS"}
	)
	AdjustActivityLogSelect()
end

function OnMsg.ClassesPostprocess()
	CreateVIPTrait()
	AddVIPToggleButton()
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

function OnMsg.NewSpecialist(colonist)
	if colonist.traits[VIPTraitId]
		and IsLiving(colonist)
		and colonist.specialist ~= nil
		and colonist.specialist ~= "none"
	then
		AddActivityLog(
			colonist,
			T{987234920035, "Graduated as a <Specialist>", Specialist = colonist.specialist}
		)
	end
end

function OnMsg.ColonistLeavesDome(colonist, old_dome)
	if IsLiving(colonist) and colonist.traits[VIPTraitId] then
		CreateGameTimeThread(function(colonist, old_dome)
			while true do
				local ok, col2, new_dome = WaitMsg("ColonistJoinsDome", 30000)
				if not IsValid(colonist) or not IsLiving(colonist) then
					break
				elseif IsValid(col2) and IsLiving(col2) and colonist == col2 then
					local Dome1 = IsValid(old_dome) and old_dome.name or T{987234920061, "unknown dome"}
					local Dome2 = IsValid(new_dome) and new_dome.name or T{987234920061, "unknown dome"}
					AddActivityLog(
						colonist,
						T{987234920060, "Moved from <Dome1> to <Dome2>", Dome1 = Dome1, Dome2 = Dome2})
					break
				end
			end
		end, colonist, old_dome)
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

		if trait_id == VIPTraitId
			or trait_id == "Renegade"
			or trait_id == IAtraitFormerOfficer
			or trait_id == IAtraitParolee
		then
			AddActivityLog(colonist, T{987234920057, "Became a <Trait>", Trait = trait.display_name})
		elseif trait.group == "Age Group" then
			AddActivityLog(colonist, T{987234920033, "Aged to <NewAge>", NewAge = trait.display_name})
		elseif trait.group == "Specialization" then
			-- already handled in NewSpecialist
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

		if trait_id == VIPTraitId
			or trait_id == "Renegade"
			or trait_id == IAtraitFormerOfficer
			or trait_id == IAtraitParolee
		then
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
