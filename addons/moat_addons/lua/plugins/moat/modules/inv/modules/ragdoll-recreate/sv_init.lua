hook.Add("OnEntityCreated", "Ragdoll Recreate", function(e)
    if (GetRoundState() ~= ROUND_ACTIVE or e:GetClass() ~= "prop_ragdoll") then
        return
    end

    e.PleaseRecreate = true
end)


hook.Add("EntityRemoved", "Ragdoll Recreate", function(e)
    if (not IsValid(e) or e:GetClass() ~= "prop_ragdoll" or e.IsSafeToRemove or not e.PleaseRecreate or GetGlobalStr("MOAT_MINIGAME_ACTIVE", false)) then
        return
    end

    if (e.trial and e.trial > 5) then
        print "Ragdoll Recreate tried 5 times for ragdoll, giving up!"
        return
    end

    -- recreate

    local rag = ents.Create "prop_ragdoll"

    rag:SetPos(e:GetPos())
    rag:SetModel(e:GetModel())
    rag:SetAngles(e:GetAngles())
    rag:SetColor(e:GetColor())
    rag.CheckThisShit = true
    rag:SetCustomCollisionCheck(true)
    rag:Spawn()
    rag:Activate()

    
    CORPSE.SetPlayerNick(rag, CORPSE.GetPlayerNick(e))
    CORPSE.SetFound(rag, CORPSE.GetFound(e))
    CORPSE.SetCredits(rag, CORPSE.GetCredits(e))

    -- nonsolid to players, but can be picked up and shot
    rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	_RagdollStorageCount = _RagdollStorageCount and _RagdollStorageCount + 1 or 1
	_RagdollStorage[_RagdollStorageCount] = rag

    timer.Simple(1, function()
        if IsValid(rag) then
            rag:CollisionRulesChanged()
        end
    end)

    for _, field in pairs { 
        "player_ragdoll", "sid", "uqid", "equipment", "was_role",
        "bomb_wire", "dmgtype", "dmgwep", "was_headshot", "time",
        "kills", "killer_sample", "scene", "trial"
    } do
        rag[field] = e[field]
    end

    rag.trial = (rag.trial or 0) + 1

    local num = rag:GetPhysicsObjectCount() - 1

    for i = 0, num do
        local bone = rag:GetPhysicsObjectNum(i)
        local old_bone = e:GetPhysicsObjectNum(i)
        if (IsValid(bone) and IsValid(old_bone)) then
            bone:SetPos(old_bone:GetPos())
            bone:SetAngles(old_bone:GetAngles())
        end
    end
end)