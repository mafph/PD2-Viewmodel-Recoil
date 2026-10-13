_G.ViewmodelRecoil = {}

ViewmodelRecoil._mod_path = ModPath
ViewmodelRecoil._default_localization_path = ViewmodelRecoil._mod_path .. "l10n/en.json"
ViewmodelRecoil._menu_path = ViewmodelRecoil._mod_path .. "menu/options.json"
ViewmodelRecoil._settings_path = SavePath .. "viewmodelrecoil_settings.json"
ViewmodelRecoil.default_settings = {
	viewmodel_recoil_enabled = true, -- if true, moves viewmodel instead of camera
	steelsight_camera_recoil_enabled = true, -- if true, uses game's default camera-moving behavior for steelsights specifically. if false, instead offsets the weapon aim, but without moving the viewmodel (while ADS)
	static_recoil_enabled = false -- if true, disables auto-centering recoil behavior.
}
ViewmodelRecoil.settings = table.deep_map_copy(ViewmodelRecoil.default_settings)
ViewmodelRecoil.RECOIL_WAIT_DELAY = 0.15
ViewmodelRecoil.RECOIL_DIR_SCALAR = 0.2



-- ======== Getters

function ViewmodelRecoil:IsViewmodelRecoilEnabled()
	return self.settings.viewmodel_recoil_enabled
end

function ViewmodelRecoil:IsSteelsightCameraRecoilEnabled()
	return self.settings.steelsight_camera_recoil_enabled
end

function ViewmodelRecoil:IsStaticRecoilEnabled()
	return self.settings.static_recoil_enabled
end


-- ======== I/O

function ViewmodelRecoil:Load()
	local file = io.open(self._settings_path, "r")
	if file then
		for k, v in pairs(json.decode(file:read("*all"))) do
			self.settings[k] = v
		end
	end
end

function ViewmodelRecoil:Save()
	local file = io.open(self._settings_path,"w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

Hooks:Add("LocalizationManagerPostInit","LocalizationManagerPostInit_nssu",function(loc_manager)
	if not BeardLib then
		loc_manager:load_localization_file(ViewmodelRecoil._default_localization_path)
	end
end)

-- ======== Menu Generation

Hooks:Add("MenuManagerInitialize","MenuManagerInitialize_nssu",function(menu_manager)
	MenuCallbackHandler.callback_viewmodelrecoil_recoil_enabled = function(this,item)
		ViewmodelRecoil.settings.viewmodel_recoil_enabled = item:value() == "on"
		ViewmodelRecoil:Save()
	end
	MenuCallbackHandler.callback_viewmodelrecoil_steelsightrecoil_enabled = function(this,item)
		ViewmodelRecoil.settings.steelsight_camera_recoil_enabled = item:value() == "on"
		ViewmodelRecoil:Save()
	end
	MenuCallbackHandler.callback_viewmodelrecoil_staticrecoil_enabled = function(this,item)
		ViewmodelRecoil.settings.static_recoil_enabled = item:value() == "on"
		ViewmodelRecoil:Save()
	end
	
	ViewmodelRecoil:Load()
	MenuHelper:LoadFromJsonFile(ViewmodelRecoil._menu_path, ViewmodelRecoil, ViewmodelRecoil.settings)
end)
