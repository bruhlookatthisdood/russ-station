/**
 * This is the proc that handles the order of an item_attack.
 *
 * The order of procs called is:
 * * [/atom/proc/tool_act] on the target. If it returns TOOL_ACT_TOOLTYPE_SUCCESS or TOOL_ACT_SIGNAL_BLOCKING, the chain will be stopped.
 * * [/obj/item/proc/pre_attack] on src. If this returns TRUE, the chain will be stopped.
 * * [/atom/proc/attackby] on the target. If it returns TRUE, the chain will be stopped.
 * * [/obj/item/proc/afterattack]. The return value does not matter.
 */
/obj/item/proc/melee_attack_chain(mob/user, atom/target, params)
	var/is_right_clicking = LAZYACCESS(params2list(params), RIGHT_CLICK)

	if(tool_behaviour && (target.tool_act(user, src, tool_behaviour, is_right_clicking) & TOOL_ACT_MELEE_CHAIN_BLOCKING))
		return TRUE

	var/pre_attack_result
	if (is_right_clicking)
		switch (pre_attack_secondary(target, user, params))
			if (SECONDARY_ATTACK_CALL_NORMAL)
				pre_attack_result = pre_attack(target, user, params)
			if (SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
				return TRUE
			if (SECONDARY_ATTACK_CONTINUE_CHAIN)
				// Normal behavior
			else
				CRASH("pre_attack_secondary must return an SECONDARY_ATTACK_* define, please consult code/__DEFINES/combat.dm")
	else
		pre_attack_result = pre_attack(target, user, params)

	if(pre_attack_result)
		return TRUE

	var/attackby_result

	if (is_right_clicking)
		switch (target.attackby_secondary(src, user, params))
			if (SECONDARY_ATTACK_CALL_NORMAL)
				attackby_result = target.attackby(src, user, params)
			if (SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
				return TRUE
			if (SECONDARY_ATTACK_CONTINUE_CHAIN)
				// Normal behavior
			else
				CRASH("attackby_secondary must return an SECONDARY_ATTACK_* define, please consult code/__DEFINES/combat.dm")
	else
		attackby_result = target.attackby(src, user, params)

	if (attackby_result)
		return TRUE

	if(QDELETED(src) || QDELETED(target))
		attack_qdeleted(target, user, TRUE, params)
		return TRUE

	if (is_right_clicking)
		var/after_attack_secondary_result = afterattack_secondary(target, user, TRUE, params)

		// There's no chain left to continue at this point, so CANCEL_ATTACK_CHAIN and CONTINUE_CHAIN are functionally the same.
		if (after_attack_secondary_result == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN || after_attack_secondary_result == SECONDARY_ATTACK_CONTINUE_CHAIN)
			return TRUE

	var/afterattack_result = afterattack(target, user, TRUE, params)

	if (!(afterattack_result & AFTERATTACK_PROCESSED_ITEM) && isitem(target))
		if (isnull(user.get_inactive_held_item()))
			SStutorials.suggest_tutorial(user, /datum/tutorial/switch_hands, params2list(params))
		else
			SStutorials.suggest_tutorial(user, /datum/tutorial/drop, params2list(params))

	return afterattack_result & TRUE //this is really stupid but its needed because afterattack can return TRUE | FLAGS.

/// Called when the item is in the active hand, and clicked; alternately, there is an 'activate held object' verb or you can hit pagedown.
/obj/item/proc/attack_self(mob/user, modifiers)
	if(SEND_SIGNAL(src, COMSIG_ITEM_ATTACK_SELF, user) & COMPONENT_CANCEL_ATTACK_CHAIN)
		return TRUE
	interact(user)

/// Called when the item is in the active hand, and right-clicked. Intended for alternate or opposite functions, such as lowering reagent transfer amount. At the moment, there is no verb or hotkey.
/obj/item/proc/attack_self_secondary(mob/user, modifiers)
	if(SEND_SIGNAL(src, COMSIG_ITEM_ATTACK_SELF_SECONDARY, user) & COMPONENT_CANCEL_ATTACK_CHAIN)
		return TRUE

/**
 * Called on the item before it hits something
 *
 * Arguments:
 * * atom/A - The atom about to be hit
 * * mob/living/user - The mob doing the htting
 * * params - click params such as alt/shift etc
 *
 * See: [/obj/item/proc/melee_attack_chain]
 */
/obj/item/proc/pre_attack(atom/A, mob/living/user, params) //do stuff before attackby!
	if(SEND_SIGNAL(src, COMSIG_ITEM_PRE_ATTACK, A, user, params) & COMPONENT_CANCEL_ATTACK_CHAIN)
		return TRUE
	return FALSE //return TRUE to avoid calling attackby after this proc does stuff

/**
 * Called on the item before it hits something, when right clicking.
 *
 * Arguments:
 * * atom/target - The atom about to be hit
 * * mob/living/user - The mob doing the htting
 * * params - click params such as alt/shift etc
 *
 * See: [/obj/item/proc/melee_attack_chain]
 */
/obj/item/proc/pre_attack_secondary(atom/target, mob/living/user, params)
	var/signal_result = SEND_SIGNAL(src, COMSIG_ITEM_PRE_ATTACK_SECONDARY, target, user, params)

	if(signal_result & COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	if(signal_result & COMPONENT_SECONDARY_CONTINUE_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	return SECONDARY_ATTACK_CALL_NORMAL

/**
 * Called on an object being hit by an item
 *
 * Arguments:
 * * obj/item/attacking_item - The item hitting this atom
 * * mob/user - The wielder of this item
 * * params - click params such as alt/shift etc
 *
 * See: [/obj/item/proc/melee_attack_chain]
 */
/atom/proc/attackby(obj/item/attacking_item, mob/user, params)
	if(SEND_SIGNAL(src, COMSIG_PARENT_ATTACKBY, attacking_item, user, params) & COMPONENT_NO_AFTERATTACK)
		return TRUE
	return FALSE

/**
 * Called on an object being right-clicked on by an item
 *
 * Arguments:
 * * obj/item/weapon - The item hitting this atom
 * * mob/user - The wielder of this item
 * * params - click params such as alt/shift etc
 *
 * See: [/obj/item/proc/melee_attack_chain]
 */
/atom/proc/attackby_secondary(obj/item/weapon, mob/user, params)
	var/signal_result = SEND_SIGNAL(src, COMSIG_PARENT_ATTACKBY_SECONDARY, weapon, user, params)

	if(signal_result & COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	if(signal_result & COMPONENT_SECONDARY_CONTINUE_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	return SECONDARY_ATTACK_CALL_NORMAL

/obj/attackby(obj/item/attacking_item, mob/user, params)
	return ..() || ((obj_flags & CAN_BE_HIT) && attacking_item.attack_atom(src, user, params))

/mob/living/attackby(obj/item/attacking_item, mob/living/user, params)
	if(..())
		return TRUE
	user.changeNext_move(attacking_item.attack_speed)
	return attacking_item.attack(src, user, params)

/mob/living/attackby_secondary(obj/item/weapon, mob/living/user, params)
	var/result = weapon.attack_secondary(src, user, params)

	// Normal attackby updates click cooldown, so we have to make up for it
	if (result != SECONDARY_ATTACK_CALL_NORMAL)
		if(weapon.secondary_attack_speed)
			user.changeNext_move(weapon.secondary_attack_speed)
		else
			user.changeNext_move(weapon.attack_speed)

	return result

/**
 * Called from [/mob/living/proc/attackby]
 *
 * Arguments:
 * * mob/living/target_mob - The mob being hit by this item
 * * mob/living/user - The mob hitting with this item
 * * params - Click params of this attack
 */
/obj/item/proc/attack(mob/living/target_mob, mob/living/user, params)
	var/signal_return = SEND_SIGNAL(src, COMSIG_ITEM_ATTACK, target_mob, user, params)
	if(signal_return & COMPONENT_CANCEL_ATTACK_CHAIN)
		return TRUE
	if(signal_return & COMPONENT_SKIP_ATTACK)
		return

	SEND_SIGNAL(user, COMSIG_MOB_ITEM_ATTACK, target_mob, user, params)

	if(item_flags & NOBLUDGEON)
		return

	if(damtype != STAMINA && force && HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("You don't want to harm other living beings!"))
		return

	if(!force && !HAS_TRAIT(src, TRAIT_CUSTOM_TAP_SOUND))
		playsound(loc, 'sound/weapons/tap.ogg', get_clamped_volume(), TRUE, -1)
	else if(hitsound)
		playsound(loc, hitsound, get_clamped_volume(), TRUE, extrarange = stealthy_audio ? SILENCED_SOUND_EXTRARANGE : -1, falloff_distance = 0)

	target_mob.lastattacker = user.real_name
	target_mob.lastattackerckey = user.ckey

	if(force && target_mob == user && user.client)
		user.client.give_award(/datum/award/achievement/misc/selfouch, user)

	user.do_attack_animation(target_mob)
	target_mob.attacked_by(src, user)

	log_combat(user, target_mob, "attacked", src.name, "(COMBAT MODE: [uppertext(user.combat_mode)]) (DAMTYPE: [uppertext(damtype)])")
	add_fingerprint(user)

	//HONK - start
	if(smelted_material)
		smelted_material.expose_mob(target_mob, TOUCH, 30)
	//HONK - end

/// The equivalent of [/obj/item/proc/attack] but for alternate attacks, AKA right clicking
/obj/item/proc/attack_secondary(mob/living/victim, mob/living/user, params)
	var/signal_result = SEND_SIGNAL(src, COMSIG_ITEM_ATTACK_SECONDARY, victim, user, params)

	if(signal_result & COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	if(signal_result & COMPONENT_SECONDARY_CONTINUE_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	return SECONDARY_ATTACK_CALL_NORMAL

/// The equivalent of the standard version of [/obj/item/proc/attack] but for non mob targets.
/obj/item/proc/attack_atom(atom/attacked_atom, mob/living/user, params)
	if(SEND_SIGNAL(src, COMSIG_ITEM_ATTACK_OBJ, attacked_atom, user) & COMPONENT_CANCEL_ATTACK_CHAIN)
		return
	if(item_flags & NOBLUDGEON)
		return
	user.changeNext_move(attack_speed)
	user.do_attack_animation(attacked_atom)
	attacked_atom.attacked_by(src, user)

/// Called from [/obj/item/proc/attack_atom] and [/obj/item/proc/attack] if the attack succeeds
/atom/proc/attacked_by(obj/item/attacking_item, mob/living/user)
	if(!uses_integrity)
		CRASH("attacked_by() was called on an object that doesnt use integrity!")

	if(!attacking_item.force)
		return

	var/damage = take_damage(attacking_item.force, attacking_item.damtype, MELEE, 1)
	//only witnesses close by and the victim see a hit message.
	user.visible_message(span_danger("[user] hits [src] with [attacking_item][damage ? "." : ", without leaving a mark!"]"), \
		span_danger("You hit [src] with [attacking_item][damage ? "." : ", without leaving a mark!"]"), null, COMBAT_MESSAGE_RANGE)
	log_combat(user, src, "attacked", attacking_item)

/area/attacked_by(obj/item/attacking_item, mob/living/user)
	CRASH("areas are NOT supposed to have attacked_by() called on them!")

/mob/living/attacked_by(obj/item/attacking_item, mob/living/user)
	send_item_attack_message(attacking_item, user)
	if(!attacking_item.force)
		return FALSE
	var/damage = attacking_item.force
	if(mob_biotypes & MOB_ROBOTIC)
		damage *= attacking_item.demolition_mod
	apply_damage(damage, attacking_item.damtype, attacking_item = attacking_item)
	if(attacking_item.damtype == BRUTE && prob(33))
		attacking_item.add_mob_blood(src)
		var/turf/location = get_turf(src)
		add_splatter_floor(location)
		if(get_dist(user, src) <= 1) //people with TK won't get smeared with blood
			user.add_mob_blood(src)
	return TRUE //successful attack

/mob/living/simple_animal/attacked_by(obj/item/I, mob/living/user)
	if(!attack_threshold_check(I.force, I.damtype, MELEE, FALSE))
		playsound(loc, 'sound/weapons/tap.ogg', I.get_clamped_volume(), TRUE, -1)
	else
		return ..()

/mob/living/basic/attacked_by(obj/item/I, mob/living/user)
	if(!attack_threshold_check(I.force, I.damtype, MELEE, FALSE))
		playsound(loc, 'sound/weapons/tap.ogg', I.get_clamped_volume(), TRUE, -1)
	else
		return ..()

/**
 * Last proc in the [/obj/item/proc/melee_attack_chain].
 * Returns a bitfield containing AFTERATTACK_PROCESSED_ITEM if the user is likely intending to use this item on another item.
 * Some consumers currently return TRUE to mean "processed". These are not consistent and should be taken with a grain of salt.
 *
 * Arguments:
 * * atom/target - The thing that was hit
 * * mob/user - The mob doing the hitting
 * * proximity_flag - is 1 if this afterattack was called on something adjacent, in your square, or on your person.
 * * click_parameters - is the params string from byond [/atom/proc/Click] code, see that documentation.
 */
/obj/item/proc/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = NONE
	. |= SEND_SIGNAL(src, COMSIG_ITEM_AFTERATTACK, target, user, proximity_flag, click_parameters)
	SEND_SIGNAL(user, COMSIG_MOB_ITEM_AFTERATTACK, target, src, proximity_flag, click_parameters)
	SEND_SIGNAL(target, COMSIG_ATOM_AFTER_ATTACKEDBY, src, user, proximity_flag, click_parameters)
	return .

/**
 * Called at the end of the attack chain if the user right-clicked.
 *
 * Arguments:
 * * atom/target - The thing that was hit
 * * mob/user - The mob doing the hitting
 * * proximity_flag - is 1 if this afterattack was called on something adjacent, in your square, or on your person.
 * * click_parameters - is the params string from byond [/atom/proc/Click] code, see that documentation.
 */
/obj/item/proc/afterattack_secondary(atom/target, mob/user, proximity_flag, click_parameters)
	var/signal_result = SEND_SIGNAL(src, COMSIG_ITEM_AFTERATTACK_SECONDARY, target, user, proximity_flag, click_parameters)
	SEND_SIGNAL(user, COMSIG_MOB_ITEM_AFTERATTACK_SECONDARY, target, src, proximity_flag, click_parameters)

	if(signal_result & COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	if(signal_result & COMPONENT_SECONDARY_CONTINUE_ATTACK_CHAIN)
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	return SECONDARY_ATTACK_CALL_NORMAL

/// Called if the target gets deleted by our attack
/obj/item/proc/attack_qdeleted(atom/target, mob/user, proximity_flag, click_parameters)
	SEND_SIGNAL(src, COMSIG_ITEM_ATTACK_QDELETED, target, user, proximity_flag, click_parameters)
	SEND_SIGNAL(user, COMSIG_MOB_ITEM_ATTACK_QDELETED, target, user, proximity_flag, click_parameters)

/obj/item/proc/get_clamped_volume()
	if(w_class)
		if(force)
			return clamp((force + w_class) * 4, 30, 100)// Add the item's force to its weight class and multiply by 4, then clamp the value between 30 and 100
		else
			return clamp(w_class * 6, 10, 100) // Multiply the item's weight class by 6, then clamp the value between 10 and 100

/mob/living/proc/send_item_attack_message(obj/item/I, mob/living/user, hit_area, obj/item/bodypart/hit_bodypart)
	if(!I.force && !length(I.attack_verb_simple) && !length(I.attack_verb_continuous))
		return
	var/message_verb_continuous = length(I.attack_verb_continuous) ? "[pick(I.attack_verb_continuous)]" : "attacks"
	var/message_verb_simple = length(I.attack_verb_simple) ? "[pick(I.attack_verb_simple)]" : "attack"
	var/message_hit_area = ""
	if(hit_area)
		message_hit_area = " in the [hit_area]"
	var/attack_message_spectator = "[src] [message_verb_continuous][message_hit_area] with [I]!"
	var/attack_message_victim = "Something [message_verb_continuous] you[message_hit_area] with [I]!"
	var/attack_message_attacker = "You [message_verb_simple] [src][message_hit_area] with [I]!"
	if(user in viewers(src, null))
		attack_message_spectator = "[user] [message_verb_continuous] [src][message_hit_area] with [I]!"
		attack_message_victim = "[user] [message_verb_continuous] you[message_hit_area] with [I]!"
	if(user == src)
		attack_message_victim = "You [message_verb_simple] yourself[message_hit_area] with [I]."
	visible_message(span_danger("[attack_message_spectator]"),\
		span_userdanger("[attack_message_victim]"), null, COMBAT_MESSAGE_RANGE, user)
	if(is_blind())
		to_chat(src, span_danger("Someone hits you[message_hit_area]!"))
	to_chat(user, span_danger("[attack_message_attacker]"))
	return 1
