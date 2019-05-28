local storage = minetest.get_mod_storage()

local death_timer = {}
local players
local player_objs = {}
local loops = {}

local initial_timeout = tonumber(minetest.settings:get("death_timer.initial_timeout")) or 8
local timeout = tonumber(minetest.settings:get("death_timer.timeout")) or 1
local timeout_reduce_loop = tonumber(minetest.settings:get("death_timer.timeout_reduce_loop")) or 3600
local timeout_reduce_rate = tonumber(minetest.settings:get("death_timer.timeout_reduce_rate")) or 1
local cloaking_mod = minetest.global_exists("cloaking")

players = minetest.deserialize(storage:get_string("players"))

if not players then
	players = {}
	storage:set_string("players", minetest.serialize(players))
end

function death_timer.create_deathholder(player, name)
	local obj = player_objs[name]
	if player and obj then
		local pos = player:get_pos()
		player:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		obj:set_pos(pos)
		player_objs[name] = obj
	elseif player and not obj then
		local pos = player:get_pos()
		obj = minetest.add_entity(pos, "death_timer:death")
		player:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		obj:set_pos(pos)
		player_objs[name] = obj
	end
end

minetest.register_on_joinplayer(function(player)
	minetest.after(2, function(name)
		local p = players[name]
		if p and p.time and p.time > 1 then
			local player = minetest.get_player_by_name(name)
			
			if not player then
				return
			end

			if not cloaking_mod then
				if not players[name].properties then
					players[name].properties = player:get_properties()
				end
		
				player:set_properties({
					visual_size    = {x = 0, y = 0},
					["selectionbox"] = {0, 0, 0, 0, 0, 0},
				})
			else
				cloaking.hide_player(name)
			end

			death_timer.create_deathholder(player, name)

			death_timer.create_loop(name)
		end
	end, player:get_player_name())
end)

minetest.register_entity("death_timer:death", {
	is_visible = false,
	on_activate = function(self, staticdata)

	end
})

function death_timer.reduce_loop()
	for k, v in pairs(players) do
		if players[k].longtime > 0 then
			players[k].longtime = players[k].longtime - timeout_reduce_rate
			if players[k].longtime < 0 then
				minetest.after(0, function(k) players[k] = nil end, k)
			end
		else
			minetest.after(0, function(k) players[k] = nil end, k)
		end
	end

	minetest.after(1, function() storage:set_string("players", minetest.serialize(players)) end)
	
	minetest.after(timeout_reduce_loop, death_timer.reduce_loop)
end

function death_timer.create_loop(name)
	if not loops[name] then
		loops[name] = true
		death_timer.loop(name)
	end
end

function death_timer.loop(name)
	local p = players[name]
	p.time = p.time - 1
	if p.time < 1 then
		local formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button_exit[4,3;3,0.5;death_button;Play" .."]"

		minetest.show_formspec(name, "death_timer:death_screen", formspec)

		local obj = player_objs[name]
		if obj then
			obj:set_detach()
			obj:remove()
			obj = nil
			player_objs[name] = obj
		end

		if p.interact then
			local privs = minetest.get_player_privs(name)
			privs.interact = p.interact
			p.interact = nil
			minetest.set_player_privs(name, privs)
		end

		if not cloaking_mod then
			if p.properties then
				local player = minetest.get_player_by_name(name)
				
				if player then
					player:set_properties(p.properties)
				end

				p.properties = nil
			end
		else
			cloaking.unhide_player(name)
		end

		p.time = nil

		players[name] = p

		loops[name] = nil

		storage:set_string("players", minetest.serialize(players))
	else
		local formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
			"label[4.85,1.35;Wait" ..
			"]button[4,3;3,0.5;death_button;" .. p.time .."]"
		minetest.show_formspec(name, "death_timer:death_screen", formspec)
		minetest.after(1, death_timer.loop, name)
	end
end

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()

	if player_objs[name] then
		player_objs[name]:set_detach()
		player_objs[name]:remove()
		player_objs[name] = nil
	end
end)

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	local privs = minetest.get_player_privs(name)

	if not players[name] then
		players[name] = {}
		players[name].longtime = initial_timeout
		players[name].time = initial_timeout
	else
		players[name].time = players[name].longtime + timeout
		players[name].longtime = players[name].time
	end

	players[name].interact = privs.interact
	
	if not cloaking_mod then
		if not players[name].properties then
			players[name].properties = player:get_properties()
		end

		player:set_properties({
			visual_size    = {x = 0, y = 0},
			["selectionbox"] = {0, 0, 0, 0, 0, 0},
		})
	else
		cloaking.hide_player(player)
	end

	privs.interact = false

	minetest.set_player_privs(name, privs)

	storage:set_string("players", minetest.serialize(players))
end)

minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()

	minetest.after(0, function(name)
		local player = minetest.get_player_by_name(name)
		death_timer.create_deathholder(player, name)
	end, name)

	local formspec

	if players[name] and players[name].time then
		formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button[4,3;3,0.5;death_button;" .. players[name].time .."]"
	else
		formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button_exit[4,3;3,0.5;death_button;Play" .."]"
	end

	minetest.after(1, minetest.show_formspec, name, "death_timer:death_screen", formspec)
	minetest.after(2, death_timer.create_loop, name)
end)

minetest.after(timeout_reduce_loop, death_timer.reduce_loop)
