if _G.IS_VR then 
	return
end

local bezier_values = {
	0,
	0,
	1,
	1
}

local mrot1 = Rotation()
local mrot2 = Rotation()
local mrot3 = Rotation()
local mrot4 = Rotation()
local mvec1 = Vector3()
local mvec2 = Vector3()
local mvec3 = Vector3()
local mvec4 = Vector3()

local orig_recoil_kick = FPCameraPlayerBase.recoil_kick
function FPCameraPlayerBase:recoil_kick(up, down, left, right,...)
	if ViewmodelRecoil:IsViewmodelRecoilEnabled()
		and not (
			ViewmodelRecoil:IsSteelsightCameraRecoilEnabled() and
			( self._parent_movement_ext._current_state:in_steelsight() or self._parent_movement_ext._current_state:is_second_sight_on() )
		)
	then
		
		local v = math.lerp(up, down, math.random())
		self._nssu_recoil_v_accumulated = math.clamp((self._nssu_recoil_v_accumulated or 0) + v,-25,25)

		local h = math.lerp(left, right, math.random())
		self._nssu_recoil_h_accumulated = (self._nssu_recoil_h_accumulated or 0) + h
		
		self._nssu_recoil_wait_t = ViewmodelRecoil.RECOIL_WAIT_DELAY
	else
		if ViewmodelRecoil:IsStaticRecoilEnabled() then
			
			local v = math.lerp(up, down, math.random())
			self._recoil_kick.accumulated = (self._recoil_kick.accumulated or 0) + v
			
			local h = math.lerp(left, right, math.random())
			self._recoil_kick.h.accumulated = (self._recoil_kick.h.accumulated or 0) + h
			
			return
		else
			return orig_recoil_kick(self,up,down,left,right,...)
		end
	end
end

Hooks:PostHook(FPCameraPlayerBase,"update","nssu_upd_fpcamera",function(self,unit,t,dt)
	self:update_nssu_recoil(t,dt)
end)

function FPCameraPlayerBase:update_nssu_recoil(t,dt)
	
	-- remove recoil entirely whilst in bipod state
	if managers.player:current_state() == "bipod" then
		self._nssu_recoil_h_accumulated = 0
		self._nssu_recoil_v_accumulated = 0
		return
	end
	
	-- delay before recoil decay
	if self._nssu_recoil_wait_t and self._nssu_recoil_wait_t > 0 then
		self._nssu_recoil_wait_t = self._nssu_recoil_wait_t - dt
		return
	end
	
	-- decay horizontal recoil
	if self._nssu_recoil_h_accumulated and self._nssu_recoil_h_accumulated ~= 0 then
		local sign = math.sign(self._nssu_recoil_h_accumulated)
		local decay = self._nssu_recoil_h_accumulated * (dt * 7)
		
		if math.abs(decay) > math.abs(self._nssu_recoil_h_accumulated) then 
			self._nssu_recoil_h_accumulated = 0
		else
			self._nssu_recoil_h_accumulated = self._nssu_recoil_h_accumulated - decay
		end
	end
	
	-- decay vertical recoil
	if self._nssu_recoil_v_accumulated and self._nssu_recoil_v_accumulated ~= 0 then
		local sign = math.sign(self._nssu_recoil_v_accumulated)
		local decay = self._nssu_recoil_v_accumulated * (dt * 7)
		
		
		if math.abs(decay) > math.abs(self._nssu_recoil_v_accumulated) then 
			self._nssu_recoil_v_accumulated = 0
		else
			self._nssu_recoil_v_accumulated = self._nssu_recoil_v_accumulated - decay
		end
	end
	
end

function FPCameraPlayerBase:get_nssu_weapon_fire_rot()
--[[
	local eye_rot = self:eye_rotation()
	local scalar = 0.2
	return Rotation(eye_rot:yaw() + (self._nssu_recoil_h_accumulated or 0)*scalar,eye_rot:pitch() + (self._nssu_recoil_v_accumulated or 0)*scalar,eye_rot:roll())
	--]]
	
--	return eye_rot * Rotation((self._nssu_recoil_h_accumulated or 0),-(self._nssu_recoil_v_accumulated or 0),0)
--	return Rotation((self._nssu_recoil_h_accumulated or 0),-(self._nssu_recoil_v_accumulated or 0),0)

	local yaw = self._nssu_recoil_h_accumulated or 0
	local pitch = self._nssu_recoil_v_accumulated or 0

	local eye_rot = self:eye_rotation()
	local scalar = ViewmodelRecoil.RECOIL_DIR_SCALAR
	return Rotation(eye_rot:yaw() + yaw*scalar,eye_rot:pitch() + pitch*scalar,eye_rot:roll())
end

local orig_update_rot = FPCameraPlayerBase._update_rot
function FPCameraPlayerBase:_update_rot(axis, unscaled_axis,...)
	if not ViewmodelRecoil:IsViewmodelRecoilEnabled() then
		return orig_update_rot(self,axis,unscaled_axis,...)
	end
	if self._animate_pitch then
		self:animate_pitch_upd()
	end

	local t = managers.player:player_timer():time()
	local dt = t - (self._last_rot_t or t)
	self._last_rot_t = t
	local data = self._camera_properties
	local new_head_pos = mvec2
	local new_shoulder_pos = mvec1
	local new_shoulder_rot = mrot1
	local new_head_rot = mrot2

	self._parent_unit:m_position(new_head_pos)

	if TacticalLean then
		local lean_lerp = TacticalLean:GetLeanLerp()
		local lean_distance = TacticalLean:GetLeanDistance()
		local lean_direction = TacticalLean:IsExitingLean() or TacticalLean:GetLeanDirection()
		if lean_direction then
			local lean_angle = TacticalLean:GetLeanAngle(lean_direction)
			local lean_fwd = self:eye_rotation():y()
			local lean_vec = lean_fwd:cross(Vector3(0, 0, 1)):normalized()
			new_head_pos = new_head_pos + (lean_distance * lean_lerp * math.sign(lean_angle) * lean_vec)
		end
		TacticalLean.previous_raycast_from = mvector3.copy(new_head_pos)
	end

	mvector3.add(new_head_pos, self._head_stance.translation)

	self._input.look = axis
	self._input.look_multiplier = self._parent_unit:base():controller():get_setup():get_connection("look"):get_multiplier()
	local stick_input_x, stick_input_y = self._look_function(axis, self._input.look_multiplier, dt, unscaled_axis)
	local look_polar_spin = data.spin - stick_input_x
	local look_polar_pitch = math.clamp(data.pitch + stick_input_y, -85, 85)
	local player_state = managers.player:current_state()

	if self._limits then
		if self._limits.spin then
			local d = (look_polar_spin - self._limits.spin.mid) / self._limits.spin.offset
			d = math.clamp(d, -1, 1)
			look_polar_spin = data.spin - math.lerp(stick_input_x, 0, math.abs(d))
		end

		if self._limits.pitch then
			local d = math.abs((look_polar_pitch - self._limits.pitch.mid) / self._limits.pitch.offset)
			d = math.clamp(d, -1, 1)
			look_polar_pitch = data.pitch + math.lerp(stick_input_y, 0, math.abs(d))
			look_polar_pitch = math.clamp(look_polar_pitch, -85, 85)
		end
	end

	if not self._limits or not self._limits.spin then
		look_polar_spin = look_polar_spin % 360
	end

	local look_polar = Polar(1, look_polar_pitch, look_polar_spin)
	local look_vec = look_polar:to_vector()
	local cam_offset_rot = mrot3

	mrotation.set_look_at(cam_offset_rot, look_vec, math.UP)

	if self._animate_pitch == nil then
		mrotation.set_zero(new_head_rot)
		mrotation.multiply(new_head_rot, self._head_stance.rotation)
		mrotation.multiply(new_head_rot, cam_offset_rot)

		data.pitch = look_polar_pitch
		data.spin = look_polar_spin
	end

	self._output_data.position = new_head_pos

	if self._p_exit then
		self._p_exit = false
		self._output_data.rotation = self._parent_unit:movement().fall_rotation

		mrotation.multiply(self._output_data.rotation, self._parent_unit:camera():rotation())

		data.spin = self._output_data.rotation:y():to_polar().spin
	else
		self._output_data.rotation = new_head_rot or self._output_data.rotation
	end

	if self._camera_properties.current_tilt ~= self._camera_properties.target_tilt then
		self._camera_properties.current_tilt = math.step(self._camera_properties.current_tilt, self._camera_properties.target_tilt, 150 * dt)
	end

	if self._camera_properties.current_tilt ~= 0 then
		self._output_data.rotation = Rotation(self._output_data.rotation:yaw(), self._output_data.rotation:pitch(), self._output_data.rotation:roll() + self._camera_properties.current_tilt)
	end

	mvector3.set(new_shoulder_pos, self._shoulder_stance.translation)
	mvector3.add(new_shoulder_pos, self._vel_overshot.translation)
	mvector3.rotate_with(new_shoulder_pos, self._output_data.rotation)
	mvector3.add(new_shoulder_pos, new_head_pos)
	mrotation.set_zero(new_shoulder_rot)
	mrotation.multiply(new_shoulder_rot, self._output_data.rotation)
	mrotation.multiply(new_shoulder_rot, self._shoulder_stance.rotation)
	mrotation.multiply(new_shoulder_rot, self._vel_overshot.rotation)
	
	
	--// VIEWMODEL RECOIL CHANGES BELOW
	local in_steelsight = self._parent_movement_ext._current_state:in_steelsight()
	local in_second_sight = self._parent_movement_ext._current_state:is_second_sight_on()
	if not (in_steelsight or in_second_sight) then
		mrotation.multiply(new_shoulder_rot,Rotation((self._nssu_recoil_h_accumulated or 0),(self._nssu_recoil_v_accumulated or 0),0))
	end
	--// CHANGES END

	if player_state == "driving" then
		self:_set_camera_position_in_vehicle()
	elseif player_state == "jerry1" or player_state == "jerry2" then
		mrotation.set_zero(cam_offset_rot)
		mrotation.multiply(cam_offset_rot, self._parent_unit:movement().fall_rotation)
		mrotation.multiply(cam_offset_rot, self._output_data.rotation)

		local shoulder_pos = mvec3
		local shoulder_rot = mrot4

		mrotation.set_zero(shoulder_rot)
		mrotation.multiply(shoulder_rot, cam_offset_rot)
		mrotation.multiply(shoulder_rot, self._shoulder_stance.rotation)
		mrotation.multiply(shoulder_rot, self._vel_overshot.rotation)
		mvector3.set(shoulder_pos, self._shoulder_stance.translation)
		mvector3.add(shoulder_pos, self._vel_overshot.translation)
		mvector3.rotate_with(shoulder_pos, cam_offset_rot)
		mvector3.add(shoulder_pos, self._parent_unit:position())
		self:set_position(shoulder_pos)
		self:set_rotation(shoulder_rot)
		self._parent_unit:camera():set_position(self._parent_unit:position())
		self._parent_unit:camera():set_rotation(cam_offset_rot)
	elseif player_state == "bipod" then
		local movement_state = self._parent_unit:movement():current_state()

		self:set_position(movement_state._shoulder_pos or new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(movement_state._camera_pos or self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	elseif player_state == "player_turret" then
		self:set_position(new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	else
		self:set_position(new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	end
end

local orig_stop_shooting = FPCameraPlayerBase.stop_shooting
function FPCameraPlayerBase:stop_shooting(wait,...)
	if ViewmodelRecoil:IsStaticRecoilEnabled() then
		self._recoil_kick.to_reduce = 0
		self._recoil_kick.h.to_reduce = 0
		self._recoil_wait = nil
	else
		return orig_stop_shooting(self,wait,...)
	end
end