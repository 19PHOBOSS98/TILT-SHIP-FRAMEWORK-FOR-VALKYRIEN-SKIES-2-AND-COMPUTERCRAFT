local utilities = require "lib.utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local quaternion = require "lib.quaternions"
local list_manager = require "lib.list_manager"

local mod = math.fmod
local max = math.max

local getPlayerHeadOrientation = player_spatial_utilities.getPlayerHeadOrientation
local quadraticSolver = utilities.quadraticSolver
local IndexedListScroller = list_manager.IndexedListScroller

local pvc = player_spatial_utilities.PlayerVelocityCalculator()

targeting_utilities = {}

function targeting_utilities.getTargetAimPos(target_g_pos,target_g_vel,gun_g_pos,gun_g_vel,bullet_vel_sqr)--TargetingUtilities
	local target_relative_pos = target_g_pos:sub(gun_g_pos)
	local target_relative_vel = target_g_vel:sub(gun_g_vel)
	local a = (target_relative_vel:dot(target_relative_vel))-(bullet_vel_sqr)
	local b = 2 * (target_relative_pos:dot(target_relative_vel))
	local c = target_relative_pos:dot(target_relative_pos)

	local d,t1,t2 = quadraticSolver(a,b,c)
	local t = nil
	local target_global_aim_pos = target_g_pos
	
	if (d>=0) then
		t = (((t1*t2)>0) and (t1>0)) and min(t1,t2) or max(t1,t2)
		target_global_aim_pos = target_g_pos:add(target_g_vel:mul(t))
	end
	return target_global_aim_pos
end


function targeting_utilities.RadarSystems(radar_arguments)
	return{
		
		playerTargeting = radar_arguments.player_radar_component:PlayerTargeting(radar_arguments),
		shipTargeting = radar_arguments.ship_radar_component:ShipTargeting(radar_arguments),
		
		targeted_players_undetected = false,
		targeted_ships_undetected = false,
		
		updateTargetingTables = function(self)
			self.playerTargeting:updateTargets()
			self.shipTargeting:updateTargetList()
			--self.onboardEntityRadar:updateTargetList() --not implemented yet
		end,
		
		getRadarTarget = function(self,trg_mode,args)
			case =
				{
				["PLAYER"] = function (is_auto_aim)
								local player = self.playerTargeting:getTarget(is_auto_aim)
								
								if (player and next(player) ~= nil) then
									self.targeted_players_undetected = false
									local current_player_position = vector.new(	player.x,
																				player.y+player.eyeHeight,
																				player.z)
									
									return {orientation=getPlayerHeadOrientation(player),
											position=current_player_position,
											velocity=pvc:getPlayerVelocity(current_player_position)}
								end								
								self.targeted_players_undetected = true
								return nil
							end,
				["SHIP"] = function (is_auto_aim)
								local ship = self.shipTargeting:getTarget(is_auto_aim)
								if (ship) then
									self.targeted_ships_undetected = false
									local target_rot = ship.rotation
									return {orientation=quaternion.new(target_rot.w,target_rot.x,target_rot.y,target_rot.z),
											position=ship.position,
											velocity=ship.velocity}
								end
								self.targeted_ships_undetected = true
								return nil
							end,
				["ENTITY"] = function (arguments)
								return nil
							end,
				 default = function (arguments)
							print("getRadarTarget: default case executed")   
							return nil
						end,
				}
				if case[trg_mode] then
					return case[trg_mode](args)
				else
					return case["default"](args)
				end
		end,
		scrollUpShipTargets = function(self)
			self.shipTargeting.listScroller:scrollUp()
		end,
		scrollDownShipTargets = function(self)
			self.shipTargeting.listScroller:scrollDown()
		end,
		scrollUpPlayerTargets = function(self)
			self.playerTargeting.listScroller:scrollUp()
		end,
		scrollDownPlayerTargets = function(self)
			self.playerTargeting.listScroller:scrollDown()
		end,
		setDesignatedMaster = function(self,is_player,designation)
			if (is_player) then
				self.playerTargeting:setDesignation(designation)
			else
				self.shipTargeting:setDesignation(designation)
			end
		end,
		getDesignatedMaster = function(self,is_player)
			if (is_player) then
				return self.playerTargeting:getDesignation()
			else
				return self.shipTargeting:getDesignation()
			end
		end,
		addToWhitelist = function(self,is_player,designation)
			if (is_player) then
				self.playerTargeting:addToWhitelist(designation)
			else
				self.shipTargeting:addToWhitelist(designation)
			end
		end,
		removeFromWhitelist = function(self,is_player,designation)
			if (is_player) then
				self.playerTargeting:removeFromWhitelist(designation)
			else
				self.shipTargeting:removeFromWhitelist(designation)
			end
		end,
		setWhitelist = function(self,is_playerWhiteList,list)
			if (is_playerWhiteList) then
				self.playerTargeting:setWhitelist(list)
			else
				self.shipTargeting:setWhitelist(list)
			end
		end
	}
end

function targeting_utilities.TargetSpatialAttributes()
	return{
		target_spatial = {	orientation = quaternion.new(1,0,0,0), 
							position = vector.new(0,0,0), 
							velocity = vector.new(0,0,0)},
		
		updateTargetSpatials = function(self,trg)--TargetingUtilities
			if (trg) then
				local so = trg.orientation
				local sp = trg.position
				local sv = trg.velocity

				self.target_spatial.orientation = quaternion.new(so[1],so[2],so[3],so[4])
				self.target_spatial.position = vector.new(sp.x,sp.y,sp.z)
				self.target_spatial.velocity = vector.new(sv.x,sv.y,sv.z)
			end
		end
	}
end



function targeting_utilities.TargetingSystem(
	external_targeting_system_channel,
	targeting_mode,
	auto_aim_active,
	use_external_radar,
	radarSystems)
	return{
		external_targeting_system_channel = external_targeting_system_channel,
		
		targeting_mode = targeting_mode,
		
		auto_aim_active = auto_aim_active,
		
		use_external_radar = use_external_radar,
		
		current_target = targeting_utilities.TargetSpatialAttributes(),
		
		radarSystems = radarSystems,
		
		TARGET_MODE = {"PLAYER","SHIP","ENTITY"},
		
		listenToExternalRadar = function(self)
			if (self.use_external_radar) then
				local _, _, senderChannel, _, message, _ = os.pullEvent("modem_message")
				if (senderChannel == external_targeting_system_channel) then
					if (message.trg) then
						self.current_target:updateTargetSpatials(message.trg)
					end
				end
			end
		end,
		
		getTargetSpatials = function(self)
			if (not self.use_external_radar) then
				local spatial_attributes = self.radarSystems:getRadarTarget(self.targeting_mode,self.auto_aim_active)
				if(spatial_attributes == nil and self.targeting_mode == self.TARGET_MODE[2]) then
					self.targeting_mode = self.TARGET_MODE[1]
					spatial_attributes = self.radarSystems:getRadarTarget(self.targeting_mode,self.auto_aim_active)
				end
				
				self.current_target:updateTargetSpatials(spatial_attributes)
			end
			return self.current_target.target_spatial
		end,
		
		setAutoAimActive = function(self,lock_true,mode)
			if (lock_true) then
				self.auto_aim_active = true
			else
				self.auto_aim_active = mode
			end
		end,
		
		getAutoAimActive = function(self)
			return self.auto_aim_active
		end,
		
		useExternalRadar = function(self,mode)
			self.use_external_radar = mode
		end,
		
		isUsingExternalRadar = function(self)
			return self.use_external_radar
		end,
		
		setTargetMode = function(self,mode)
			self.targeting_mode = mode
		end,
		getTargetMode = function(self)
			return self.targeting_mode
		end
		
		
	}
end

return targeting_utilities

	--[[
	local radar_arguments={	ship_radar_component,
							ship_reader_component,
							player_radar_component,
							designated_ship_id,
							designated_player_name,
							ship_id_whitelist,
							player_name_whitelist,
							player_radar_box_size,
							ship_radar_range}
	local radars = targeting_utilities.RadarSystems(radar_arguments)
	local aimTargeting = targeting_utilities.TargetingSystem(EXTERNAL_AIM_TARGETING_CHANNEL,aim_targeting_mode,auto_aim,true,false,radars)
	local orbitTargeting = targeting_utilities.TargetingSystem(EXTERNAL_ORBIT_TARGETING_CHANNEL,orbit_targeting_mode,auto_aim,false,false,radars)

	function updateTargetingSystem()
		while run_firmware do
			aimTargeting.updateTarget()
			orbitTargeting.updateTarget()
			os.sleep(0.05)
		end
	end
	
	
	aimTargeting.current_target.target_spatial
	]]--