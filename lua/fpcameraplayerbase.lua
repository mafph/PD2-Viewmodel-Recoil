if _G.IS_VR then 
	return
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
	local yaw = self._nssu_recoil_h_accumulated or 0
	local pitch = self._nssu_recoil_v_accumulated or 0

	local eye_rot = self:eye_rotation()
	local scalar = ViewmodelRecoil.RECOIL_DIR_SCALAR
	return Rotation(eye_rot:yaw() + yaw*scalar,eye_rot:pitch() + pitch*scalar,eye_rot:roll())
end

Hooks:PreHook(FPCameraPlayerBase, "recoil_kick", "nssu_pre_kick", function(self)
	self._nssu_v0 = self._recoil_kick.accumulated or 0
	self._nssu_h0 = self._recoil_kick.h.accumulated or 0
end)

Hooks:PostHook(FPCameraPlayerBase, "recoil_kick", "nssu_post_kick", function(self)
	if not ViewmodelRecoil:IsViewmodelRecoilEnabled() then return end

	local st = self._parent_movement_ext._current_state
	if ViewmodelRecoil:IsSteelsightCameraRecoilEnabled() and (st:in_steelsight() or st:is_second_sight_on()) then
		return
	end

	local dv = (self._recoil_kick.accumulated or 0) - self._nssu_v0
	local dh = (self._recoil_kick.h.accumulated or 0) - self._nssu_h0

	self._recoil_kick.accumulated = self._nssu_v0
	self._recoil_kick.h.accumulated = self._nssu_h0

	self._nssu_recoil_v_accumulated = math.clamp((self._nssu_recoil_v_accumulated or 0) + dv, -25, 25)
	self._nssu_recoil_h_accumulated = (self._nssu_recoil_h_accumulated or 0) + dh
	self._nssu_recoil_wait_t = ViewmodelRecoil.RECOIL_WAIT_DELAY
end)

-- Static Recoil: camera stays up
Hooks:PostHook(FPCameraPlayerBase, "stop_shooting", "nssu_post_stop", function(self)
	if ViewmodelRecoil:IsStaticRecoilEnabled() then
		self._recoil_kick.to_reduce = 0
		self._recoil_kick.h.to_reduce = 0
		self._recoil_wait = nil
	end
end)

-- directly calculate Viewmodel-Recoil into rotation 
Hooks:PreHook(FPCameraPlayerBase, "set_rotation", "nssu_vm_rot", function(self, rot)
	if not ViewmodelRecoil:IsViewmodelRecoilEnabled() then return end
	if managers.player:current_state() == "bipod" then return end

	local st = self._parent_movement_ext and self._parent_movement_ext._current_state
	if not st or st:in_steelsight() or st:is_second_sight_on() then return end

	local h = self._nssu_recoil_h_accumulated or 0
	local v = self._nssu_recoil_v_accumulated or 0
	if h == 0 and v == 0 then return end

	mrotation.multiply(rot, Rotation(h, v, 0))
end)