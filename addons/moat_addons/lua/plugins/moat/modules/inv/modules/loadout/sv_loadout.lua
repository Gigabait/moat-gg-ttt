print("loadout loaded")

function table.removeFunctions(tbl)
    for k,v in pairs(tbl) do
        if isfunction(v) then
            tbl[k] = nil
        elseif istable(v) then
            table.removeFunctions(v)
        end
    end
end

FindMetaTable "Player".HasWeapon2 = FindMetaTable "Player".HasWeapon2 or FindMetaTable "Player".HasWeapon
-- crowbars and friends
FindMetaTable "Player".HasWeapon = function(ply, class)
    for i, w in pairs(ply:GetWeapons()) do
        if (w:GetClass() == class) then
            return true
        end
    end
    return ply:HasWeapon2(class)
end

util.AddNetworkString("MOAT_UPDATE_WEP")
util.AddNetworkString("MOAT_UPDATE_OTHER_WEP")
util.AddNetworkString("MOAT_NET_SPAWN")
util.AddNetworkString("MOAT_UPDATE_WEP_CACHE")
util.AddNetworkString("MOAT_UPDATE_OTHER_WEP_CACHE")

util.AddNetworkString("MOAT_UPDATE_WEP_PAINT")
util.AddNetworkString("MOAT_UPDATE_WEP_PAINT_LATE")

util.AddNetworkString("MOAT_UPDATE_PLANETARIES")
util.AddNetworkString("MOAT_UPDATE_PLANETARIES_LATE")

MOAT_LOADOUT = {}

-- We only need to know if the weapon is a unique or a tier, nothing else
local item_kind_codes = {
    ["tier"] = "1"
}

function MOAT_LOADOUT.ResetPowerupAbilities(ply)
    if (not IsValid(ply)) then return end
    
    ply:SetJumpPower(160)
    ply.JumpHeight = 160
	local max = 100
	if (max ~= 100) then
		D3A.Chat.SendToPlayer2(ply, 
		Color(255, 0, 255), "[Head's up!]", 
		Color(255, 255, 255), " Base health is ", 
		Color(0, 255, 0), tostring(max), 
		Color(255, 255, 255), " for ", 
		Color(0, 255, 255), "testing", 
		Color(255, 255, 255), "!")
	end

    ply:SetMaxHealth(max)
    ply.MaxHealth = max
    ply:SetHealth(max)

    ply.ExtraXP = 1
end

function MOAT_LOADOUT.GetLoadout(ply)
    local tbl = {}

    for i = 1, 5 do
        if (MOAT_INVS and MOAT_INVS[ply] and MOAT_INVS[ply]["l_slot" .. i]) then
            tbl[i] = table.Copy(MOAT_INVS[ply]["l_slot" .. i])
        else
            tbl[i] = nil
            continue
        end

        if (not tbl[i].c) then
            tbl[i] = {}
            continue
        else
            tbl[i].item = m_GetItemFromEnumWithFunctions(tbl[i].u)

            if (tbl[i].t) then
                tbl[i].Talents = {}

                for k, v in ipairs(tbl[i].t) do
                    tbl[i].Talents[k] = m_GetTalentFromEnumWithFunctions(v.e)
                end
            end

            if (tbl[i] and tbl[i].item and (tbl[i].item.Kind == "Other" or tbl[i].item.Kind == "Unique")) then
                if (tbl[i].item.WeaponClass) then
                    tbl[i].w = tbl[i].item.WeaponClass
                end    
            end
        end
    end

    return tbl[1], tbl[2], tbl[3], tbl[4], tbl[5]
end

function m_GetLoadout(ply)
    return MOAT_LOADOUT.GetLoadout(ply)
end

function MOAT_LOADOUT.GetCosmetics(ply)
    local tbl = {}

    for i = 6, 10 do
        tbl[i] = table.Copy(MOAT_INVS[ply]["l_slot" .. i]) or {}

        if (not tbl[i].c) then
            tbl[i] = {}
            continue
        else
            tbl[i].item = m_GetItemFromEnumWithFunctions(tbl[i].u)
        end
    end

    return tbl[6], tbl[7], tbl[8], tbl[9], tbl[10]
end

function MOAT_LOADOUT.SetPlayerModel(ply, item_tbl)
	if (item_tbl.item.CustomSpawn and item_tbl.item.OnPlayerSpawn) then
		item_tbl.item:OnPlayerSpawn(ply)
	else
		timer.Simple(1, function() if (IsValid(ply)) then ply:SetModel(item_tbl.item.Model) end end)
	end

    if (MOAT_INVS and MOAT_INVS[ply] and MOAT_INVS[ply]["l_slot10"] and MOAT_INVS[ply]["l_slot10"].p2 and MOAT_PAINT) then
        local col = MOAT_PAINT.Paints[MOAT_INVS[ply]["l_slot10"].p2][2]
        ply:SetColor(Color(col[1], col[2], col[3], 255))
        ply:SetPlayerColor(Vector(col[1]/255, col[2]/255, col[3]/255))
    end
end
/*
function MOAT_LOADOUT.SaveLoadedWeapons()
    loadout_weapon_indexes = {}
    loadout_cosmetic_indexes = {}
end
hook.Add("TTTBeginRound", "moat_SaveLoadedWeapons", MOAT_LOADOUT.SaveLoadedWeapons)
*/

function MOAT_LOADOUT.ApplyWeaponMods(wep, loadout_tbl, item)
    local itemtbl = table.Copy(loadout_tbl)

    if (wep.ItemName) then
        wep.PrintName = wep.ItemName
    end

    if (itemtbl.n) then
        wep.PrintName = "\"" .. itemtbl.n:Replace("''", "'") .. "\""
    elseif (item and item.Name and wep.PrintName and wep.ClassName and wep.PrintName == util.GetWeaponName(wep.ClassName)) then
        if (item.Kind and item.Kind == "tier") then
            wep.PrintName = string(item.Name, " ", wep.PrintName)
        else
            wep.PrintName = item.Name
        end
    end
    wep.ItemName = wep.PrintName
    wep:SetRealPrintName(wep.PrintName)

    if (itemtbl.s) then
        for s_idx, mult in pairs(itemtbl.s) do
            local mod = MODS.Settable[s_idx]
            if (not mod) then
                print("s_idx fail: ", s_idx)
                continue
            end

            if (not mod.valid(wep)) then
                print("mod invalid: " .. wep:GetClass() .. " s_idx: " .. s_idx)
                continue
            end
            
            local mult = mod.getmult(itemtbl.item.Stats, mult)

            mod.set(wep, mult)
        end
    end

    if (itemtbl.t) then
        wep.Talents = table.Copy(itemtbl.t)
        wep.level = itemtbl.s.l
        wep.exp = itemtbl.s.x
        m_ApplyTalentMods(wep, itemtbl)
    end

    for _, mod in pairs(MODS.Networked) do
        if (not mod.valid(wep)) then
            continue
        end

        mod.network(wep)
    end

    wep.ItemStats = itemtbl or {}

    return wep
end

function m_ApplyWeaponMods(wep, loadout_tbl, item)
    if (loadout_tbl.p3) then
        wep:SetSkinID(loadout_tbl.p3)
    end
    if (loadout_tbl.p2) then
        wep:SetPaintID(loadout_tbl.p2)
    elseif (loadout_tbl.p) then
        print(loadout_tbl.p, "TINT")
        wep:SetTintID(loadout_tbl.p)
    end

    return MOAT_LOADOUT.ApplyWeaponMods(wep, loadout_tbl, item)
end

function MOAT_LOADOUT.ApplyOtherModifications(tbl, loadout_tbl, item)
    local wep = tbl
    local itemtbl = table.Copy(loadout_tbl)

    if (wep.ItemName) then
        wep.PrintName = wep.ItemName
    end

    if (item and item.Name and wep.PrintName and wep.ClassName and wep.PrintName == util.GetWeaponName(wep.ClassName)) then
        if (item.Kind and item.Kind == "tier") then
            wep.PrintName = string(item.Name, " ", wep.PrintName)
        else
            wep.PrintName = item.Name
        end

        wep.ItemName = wep.PrintName
    end

    if (itemtbl and itemtbl.item and itemtbl.item.Stats and itemtbl.s and #itemtbl.s > 0) then
        wep.InventoryModifications = {}

        for i = 1, #itemtbl.s do
            wep.InventoryModifications[i] = itemtbl.item.Stats[i].min + ((itemtbl.item.Stats[i].max - itemtbl.item.Stats[i].min) * itemtbl.s[i])
        end
    end
end

loadout_weapon_indexes = {}
local loadout_other_indexes = {}
local loadout_cosmetic_indexes = {}
MOAT_MODEL_EDIT_POS = MOAT_MODEL_EDIT_POS or {}

function MOAT_LOADOUT.SaveLoadedWeapons()
    loadout_other_indexes = {}
    loadout_weapon_indexes = {}
    loadout_cosmetic_indexes = {}
end
hook.Add("TTTPrepareRound", "moat_SaveLoadedWeapons", MOAT_LOADOUT.SaveLoadedWeapons)


function MOAT_LOADOUT.HasCosmeticInLoadout(ply, id)
    local return_val = false
    local item_tbl = {}

    if (isnumber(id)) then
        for k, v in ipairs(loadout_cosmetic_indexes) do
            if (v[1] == ply:EntIndex() and v[2] == id) then
                return_val = true
                item_tbl = m_GetItemFromEnumWithFunctions(id)
                break
            end
        end
    else
        for k, v in ipairs(loadout_cosmetic_indexes) do
            local cosmetic_tbl = m_GetItemFromEnumWithFunctions(v[2])

            if (v[1] == ply:EntIndex() and cosmetic_tbl.Kind == id) then
                return_val = true
                item_tbl = cosmetic_tbl
                break
            end
        end
    end

    return return_val, item_tbl
end

--[[
hook.Add( "PlayerSetModel", "moat_SetPlayerModel", function( ply )

    local has_item, tbl = m_HasCosmeticInLoadout( ply, "Model" )

    if ( has_item ) then

        ply:SetModel( tbl.Model )

    end

end )]]
-- Hook wasn't doing it for whatever reason, so just overwrited default... (That above code)

MOAT_LOADOUT.UpdateWepCache = {}
MOAT_LOADOUT.UpdateOtherWepCache = {}

function MOAT_LOADOUT.GivePlayerLoadout(ply, pri_wep, sec_wep, melee_wep, powerup, tactical, is_reequip)
    if (hook.Run("MoatInventoryShouldGiveLoadout", ply)) then return end
    if (not IsValid(ply)) then return end

    local loadout_table = {
        ["Primary"] = pri_wep,
        ["Secondary"] = sec_wep,
        ["Melee"] = melee_wep,
        ["Power-Up"] = powerup,
        ["Other"] = tactical
    }

    if (not is_reequip) then
        MOAT_LOADOUT.ResetPowerupAbilities(ply)
        local l_ply = ply
        if (l_ply:IsBot()) then
            l_ply = player.GetHumans()[1] or l_ply
        end
        local cos_head, cos_mask, cos_body, cos_effect, cos_model = MOAT_LOADOUT.GetCosmetics(l_ply)

        local cosmetic_table = {
            ["Hat"] = cos_head,
            ["Mask"] = cos_mask,
            ["Body"] = cos_body,
            ["Effect"] = cos_effect,
            ["Model"] = cos_model
        }

        for k, v in pairs(cosmetic_table) do
            if k == "Effect" then
                if not v.item then continue end
                if tonumber(v.u) == 920 then
                    mg_tesla(ply)
                    continue
                end
            end
            if (v.c) then
                local paint = 0
                if (v.p) then paint = v.p end
                if (v.p2) then paint = v.p2 end

                table.insert(loadout_cosmetic_indexes, {ply:EntIndex(), v.u, paint})

                if (k == "Model") then
                    MOAT_LOADOUT.SetPlayerModel(ply, v)
                    continue
                end

                net.Start("MOAT_APPLY_MODELS")
                net.WriteUInt(ply:EntIndex(), 16)
                net.WriteUInt(v.u, 16)
                net.WriteUInt(paint, 32)

                if (MOAT_MODEL_EDIT_POS[ply] and MOAT_MODEL_EDIT_POS[ply][v.u]) then
                    net.WriteBool(true)
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][1])
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][2])
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][3])
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][4])
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][5])
                    net.WriteDouble(MOAT_MODEL_EDIT_POS[ply][v.u][6])
                else
                    net.WriteBool(false)
                end

                net.Broadcast()
            end
        end
    end

    for k, v in pairs(loadout_table) do
        if (k == "Power-Up") then
            if (v.c) then
                m_ApplyPowerUp(ply, v)
            end

            continue
        end

        if (k == "Other") then
            if (v.c) then
                local weapon_table = {}

                if (v.w) then
                    weapon_table = weapons.Get(v.w)
                else
                    continue
                end

                for k2, v2 in pairs(ply:GetWeapons()) do
                    if (v2.Kind == weapon_table.Kind) then
                        ply:StripWeapon(v2.ClassName)
                    end
                end

                local v3 = ply:Give(v.w)
                local wpn_tbl = v3:GetTable()
                local item_old = table.Copy(v.item)
                v.item = m_GetItemFromEnum(v.u)

                MOAT_LOADOUT.ApplyOtherModifications(wpn_tbl, v, v.item)

                net.Start("MOAT_UPDATE_OTHER_WEP")
                net.WriteUInt(v3:EntIndex(), 16)
                net.WriteString(wpn_tbl.ItemName or wpn_tbl.PrintName or "NAME_ERROR0")

                net.WriteTable(v)
                net.Send(ply)

                loadout_other_indexes[v3:EntIndex()] = {owner = ply:EntIndex(), info = v, name = wpn_tbl.ItemName or wpn_tbl.PrintName}

                v.item = item_old
                v3.c = v.c
            end

            continue
        end

        if (v.c) then
            local weapon_table = {}

            if (v.w) then
                weapon_table = weapons.Get(v.w)
            end

            for k2, v2 in pairs(ply:GetWeapons()) do
                if (v2.Kind == weapon_table.Kind) then
                    ply:StripWeapon(v2.ClassName)
                end
            end

            local v3 = ply:Give(v.w)
            local wpn_tbl = v3:GetTable()
            local item_old = table.Copy(v.item)
            v.item = m_GetItemFromEnum(v.u)

            m_ApplyWeaponMods(v3, v, v.item)
            local clipsize = wpn_tbl.Primary.ClipSize
            local defaultclip = wpn_tbl.Primary.DefaultClip
            local add_ammo = clipsize
            if (defaultclip > clipsize) then
                add_ammo = add_ammo + defaultclip - clipsize
                defaultclip = clipsize
            end
            v3:SetClip1(defaultclip)
            wpn_tbl.UniqueItemID = v.c
            wpn_tbl.PrimaryOwner = ply

            net.Start("MOAT_UPDATE_WEP")
            net.WriteUInt(v3:EntIndex(), 16)

            if (v.t) then
                v.Talents = {}

                for k5, v5 in ipairs(v.t) do
                    v.Talents[k5] = m_GetTalentFromEnum(v5.e)
                end
            end

            net.WriteTable(v or {})

            local sent = false
            if (v.item and v.item.Rarity == 9) then
                sent = true
                net.Broadcast()
            else
                net.Send(ply)
            end

            loadout_weapon_indexes[v3:EntIndex()] = {
                name = wpn_tbl.ItemName or wpn_tbl.PrintName,
                stats = {
                    wpn_tbl.Primary.Damage or 0,
                    wpn_tbl.Primary.Delay or 0,
                    wpn_tbl.Primary.ClipSize or 0,
                    wpn_tbl.Primary.Recoil or 0,
                    wpn_tbl.Primary.Cone or 0,
                    wpn_tbl.PushForce or 0,
                    wpn_tbl.Secondary.Delay or 0,
                    wpn_tbl.Primary.ConeX or 0,
                    wpn_tbl.Primary.ConeY or 0,
                },
                owner = ply:EntIndex(),
                info = v,
                net = sent
            }

            if (wpn_tbl.Primary.Ammo and wpn_tbl.Primary.ClipSize and ply:GetAmmoCount(wpn_tbl.Primary.Ammo) < wpn_tbl.Primary.ClipSize) then
                ply:GiveAmmo(add_ammo, wpn_tbl.Primary.Ammo, true)
            end

            v.item = item_old
        end
    end
end

function m_GivePlayerLoadout(ply, pri_wep, sec_wep, melee_wep, powerup, tactical, is_reequip)
    return MOAT_LOADOUT.GivePlayerLoadout(ply, pri_wep, sec_wep, melee_wep, powerup, tactical, is_reequip)
end

function MOAT_LOADOUT.GiveLoadout(ply)
    if (ply:IsSpec()) then return end
    if (GetRoundState() == ROUND_WAIT) then return end

    net.Start("MOAT_NET_SPAWN")
    net.Send(ply)

    local idx = ply:EntIndex()
    timer.Create("moat_CheckLoadoutSpawn" .. idx, 1, 0, function()
        if (not IsValid(ply)) then timer.Remove("moat_CheckLoadoutSpawn" .. idx) return end

        local l_ply = ply
        if (l_ply:IsBot()) then
            l_ply = player.GetHumans()[1] or l_ply
        end

        local pri_wep, sec_wep, melee_wep, powerup, tactical = m_GetLoadout(l_ply)

        if (pri_wep and sec_wep and melee_wep and powerup and tactical) then
            m_GivePlayerLoadout(ply, pri_wep, sec_wep, melee_wep, powerup, tactical)
            timer.Remove("moat_CheckLoadoutSpawn" .. idx)
        end
    end)
end
hook.Add("PlayerSpawn", "moat_GiveLoadout", MOAT_LOADOUT.GiveLoadout)

function MOAT_LOADOUT.LoadLoadedLoadouts(ply)
    /*if (table.Count(loadout_weapon_indexes) < 1) then return end

    for k, v in pairs(loadout_weapon_indexes) do
        if (not Entity(v[1]):IsValid()) then continue end
        if (not v[1]) then continue end
        local wpn_tbl = Entity(v[1]).Weapon
        local wpn_dmg = 0
        if (not wpn_tbl) then continue end

        if (wpn_tbl.Primary.Damage) then
            wpn_dmg = wpn_tbl.Primary.Damage
        end

        local wpn_delay = 0

        if (wpn_tbl.Primary.Delay) then
            wpn_delay = wpn_tbl.Primary.Delay
        end

        local wpn_clip = 0

        if (wpn_tbl.Primary.ClipSize) then
            wpn_clip = wpn_tbl.Primary.ClipSize
        end

        local wpn_recoil = 0

        if (wpn_tbl.Primary.Recoil) then
            wpn_recoil = wpn_tbl.Primary.Recoil
        end

        local wpn_cone = 0

        if (wpn_tbl.Primary.Cone) then
            wpn_cone = wpn_tbl.Primary.Cone
        end

        local wpn_force = 0

        if (wpn_tbl.PushForce) then
            wpn_force = wpn_tbl.PushForce
        end

        local wpn_delay2 = 0

        if (wpn_tbl.Secondary.Delay) then
            wpn_delay2 = wpn_tbl.Secondary.Delay
        end

        local wpn_ownerindex = 0

        if (wpn_tbl.PrimaryOwner) then
            wpn_ownerindex = wpn_tbl.PrimaryOwner:EntIndex()
        end

        net.Start("MOAT_UPDATE_WEP")
        net.WriteUInt(v[1], 16)
        net.WriteTable(v[2])
        net.Send(ply)
    end*/
end
hook.Add("PlayerInitialSpawn", "moat_LoadLoadedLoadouts", MOAT_LOADOUT.LoadLoadedLoadouts)


function MOAT_LOADOUT.LoadCosmeticLoadouts(ply)
    if (table.Count(loadout_cosmetic_indexes) < 1) then return end

    for k, v in pairs(loadout_cosmetic_indexes) do
        if (not Entity(v[1]):IsValid()) then continue end
        net.Start("MOAT_APPLY_MODELS")
        net.WriteDouble(v[1])
        net.WriteDouble(v[2])
        net.WriteUInt(v[3], 8)
        net.Send(ply)
    end
end
hook.Add("PlayerInitialSpawn", "moat_LoadCosmeticLoadouts", MOAT_LOADOUT.LoadCosmeticLoadouts)

--[[-------------------------------------------------------------------------
Custom Model Positioning
---------------------------------------------------------------------------]]

util.AddNetworkString("MOAT_UPDATE_MODEL_POS")
util.AddNetworkString("MOAT_UPDATE_MODEL_POS_SINGLE")

local clamp_table = {
	[1] = { -180, 180 },
	[2] = { -180, 180 },
	[3] = {  0.8, 1.2 },
	[4] = { -2.5, 2.5 },
	[5] = { -2.5, 2.5 },
	[6] = { -2.5, 2.5 }
}

function MOAT_LOADOUT.UpdateModelPos(_, ply)
	local item_id = net.ReadUInt(16)
	local pos_table = {}
	
	for i = 1, #clamp_table do
		pos_table[i] = math.Clamp(net.ReadDouble(), clamp_table[i][1], clamp_table[i][2])
	end

	if (not MOAT_MODEL_EDIT_POS[ply]) then
		MOAT_MODEL_EDIT_POS[ply] = {}
	end

	MOAT_MODEL_EDIT_POS[ply][item_id] = {
		pos_table[1],
		pos_table[2],
		pos_table[3],
		pos_table[4],
		pos_table[5],
		pos_table[6]
	}
end
net.Receive("MOAT_UPDATE_MODEL_POS", MOAT_LOADOUT.UpdateModelPos)


function MOAT_LOADOUT.UpdateModelPosSingle(_, ply)
	local item_id = net.ReadUInt(16)
	local slider_id = net.ReadUInt(8)
	if (slider_id > #clamp_table or slider_id == 0) then return end

	local item_pos = math.Clamp(net.ReadDouble(), clamp_table[slider_id][1], clamp_table[slider_id][2])

	if (not MOAT_MODEL_EDIT_POS[ply]) then
		MOAT_MODEL_EDIT_POS[ply] = {}
	end

	MOAT_MODEL_EDIT_POS[ply][item_id][slider_id] = item_pos
end
net.Receive("MOAT_UPDATE_MODEL_POS_SINGLE", MOAT_LOADOUT.UpdateModelPosSingle)

--[[-------------------------------------------------------------------------
Gamemode Fixes
---------------------------------------------------------------------------]]

hook.Add("PostGamemodeLoaded", "moat_OverwritePlayermodel", function()
    function GAMEMODE:PlayerSetModel(ply)
        local mdl = GAMEMODE.playermodel or "models/player/phoenix.mdl"
        local has_item, tbl = MOAT_LOADOUT.HasCosmeticInLoadout(ply, "Model")

        if (has_item) then
            mdl = tbl.Model
        end

        util.PrecacheModel(mdl)
        ply:SetModel(mdl)
        ply:SetColor(COLOR_WHITE)

        if (MOAT_INVS and MOAT_INVS[ply] and MOAT_INVS[ply]["l_slot10"] and MOAT_INVS[ply]["l_slot10"].p2 and MOAT_PAINT) then
            local col = MOAT_PAINT.Paints[MOAT_INVS[ply]["l_slot10"].p2][2]
            ply:SetColor(Color(col[1], col[2], col[3], 255))
            ply:SetPlayerColor(Vector(col[1]/255, col[2]/255, col[3]/255))
        end
    end

    function GAMEMODE:TTTPlayerSetColor(ply)
        local clr = COLOR_WHITE
        if (MOAT_INVS and MOAT_INVS[ply] and MOAT_INVS[ply]["l_slot10"] and MOAT_INVS[ply]["l_slot10"].p2 and MOAT_PAINT) then
            local col = MOAT_PAINT.Paints[MOAT_INVS[ply]["l_slot10"].p2][2]
            ply:SetColor(Color(col[1], col[2], col[3], 255))
            ply:SetPlayerColor(Vector(col[1]/255, col[2]/255, col[3]/255))
        else
            ply:SetPlayerColor(Vector(1, 1, 1))
        end
    end
end)

hook.Add("TTTPlayerColor", "moat_ResetPlayerColor", function() return Color(61, 87, 105) end) -- Set the default player color (paint for items coming soon)


--[[-------------------------------------------------------------------------
Loadout Networking
---------------------------------------------------------------------------]]
local function NetworkRegularWeapon(wep)
    local tbl = loadout_weapon_indexes[wep:EntIndex()]
    if (tbl.net) then return end
    if (GetRoundState() == ROUND_ACTIVE) then tbl.net = true end

    net.Start("MOAT_UPDATE_WEP")
    net.WriteUInt(wep:EntIndex(), 16)
    net.WriteTable(tbl.info or {})
    net.Broadcast()
end

local function NetworkOtherWeapon(wep)
    local tbl = loadout_other_indexes[wep:EntIndex()]
    if (GetRoundState() ~= ROUND_PREP and tbl.net) then return end
    if (GetRoundState() == ROUND_ACTIVE) then tbl.net = true end

    net.Start("MOAT_UPDATE_OTHER_WEP")
    net.WriteUInt(wep:EntIndex(), 16)
    net.WriteString(tbl.name or "NAME_ERROR3")
    net.WriteTable(tbl.info)
    net.Broadcast()
end

function NetworkWeaponStats(wep)
    if (not IsValid(wep)) then return end

    if (loadout_other_indexes[wep:EntIndex()]) then NetworkOtherWeapon(wep) end
    if (loadout_weapon_indexes[wep:EntIndex()]) then NetworkRegularWeapon(wep) end
end

hook.Add("PlayerDroppedWeapon", "moat_NetworkWeapons", function(pl, wep)
    NetworkWeaponStats(wep)
end)

hook.Add("PlayerDeath", "moat_NetworkWeapons", function(pl, inf, att)
    if (IsValid(inf) and inf:IsWeapon() and inf.ItemStats) then
        NetworkWeaponStats(inf)
        return
    end

    if (IsValid(att) and att:IsPlayer()) then
        local wep = att:GetActiveWeapon()
        if (IsValid(wep) and wep.ItemStats) then
            NetworkWeaponStats(wep)
        end
    end
end)
