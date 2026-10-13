if _G.IS_VR then 
	return
end

--[[
local orig_fire_pos = PlayerStandard.get_fire_weapon_position
function PlayerStandard:get_fire_weapon_position(...)
	local enabled
	
	if not enabled then 
		return orig_fire_pos(self,...)
	end
	
	if self:is_reticle_aim() then
		return self._ext_camera:position_with_shake()
	else
		return self._ext_camera:position()
	end
end
--]]

local dir = Vector3()

local orig_fire_dir = PlayerStandard.get_fire_weapon_direction
function PlayerStandard:get_fire_weapon_direction(...)
	if ViewmodelRecoil:IsViewmodelRecoilEnabled() then 
		if not (self:in_steelsight() and ViewmodelRecoil:IsSteelsightCameraRecoilEnabled()) then
			return self._camera_unit:base():get_nssu_weapon_fire_rot():y()
		end
	end
	return orig_fire_dir(self,...)
end