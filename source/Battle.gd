extends RefCounted
const R = preload("res://Rules.gd")

var rng = RandomNumberGenerator.new()
var stage = 0
var archetype = "tide"
var tide = 0
var heat = 0
var player = {}
var enemy = {}
var board = ["","","","","","",""]
var phase = "player"
var casts = 2
var enemy_casts = 0
var round_number = 1
var healed_enemy = false
var learned = []
var last_event = {}
var history = []
var stats = {"damage":0,"healed":0,"drawn":0,"casts":0}

func _init(fight=0, seed_value=-1, composition={}, class_id="tide"):
	archetype=class_id
	stage = clampi(fight,0,4)
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	var encounter = R.encounters()[stage]
	player = make_actor(R.class_data(class_id).hp,composition if not composition.is_empty() else R.class_data(class_id).deck)
	enemy = make_actor(encounter.hp,encounter.deck)
	for s in R.player_spells(class_id,composition):
		if s.unlock <= stage: learned.append(s)
	draw_cards(player,5)

func make_actor(hp, composition):
	var actor = {"hp":hp,"max_hp":hp,"pile":[],"discard":[],"hand":[],"reshuffles":0}
	for e in composition:
		for i in range(composition[e]): actor.pile.append(e)
	shuffle(actor.pile)
	return actor

func shuffle(cards):
	for i in range(cards.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func draw_cards(actor,n):
	var drawn = 0
	for i in range(n):
		if actor.pile.is_empty():
			if actor.discard.is_empty(): break
			actor.reshuffles += 1
			actor.pile = actor.discard.duplicate()
			actor.discard.clear()
			shuffle(actor.pile)
		actor.hand.append(actor.pile.pop_back())
		drawn += 1
	return drawn

func place(card,slot):
	if phase != "player" or casts <= 0 or card < 0 or card >= player.hand.size() or slot < 0 or slot > 6: return false
	var e = player.hand[card]
	player.hand.remove_at(card)
	if board[slot] != "": player.hand.append(board[slot])
	board[slot] = e
	return true

func take_back(slot):
	if phase != "player" or slot < 0 or slot > 6 or board[slot] == "": return false
	player.hand.append(board[slot])
	board[slot] = ""
	return true

func swap_slots(a,b):
	if phase != "player" or a < 0 or b < 0 or a > 6 or b > 6: return
	var temp = board[a]
	board[a] = board[b]
	board[b] = temp

func clear_board():
	if phase != "player": return
	for i in range(7): take_back(i)

func ready_spell():
	if phase != "player" or casts <= 0: return {}
	for s in learned:
		if s.id != "pulse" and R.matches(board,s): return s
	for s in learned:
		if s.id == "pulse" and R.matches(board,s): return s
	return {}

func spell_preview(s):
	var result={"amount":s.amount,"hp_cost":int(s.get("hp_cost",0)),"heal":0}
	var school=s.get("school","")
	if archetype=="tide" and school=="L": result.amount+=tide*(1 if s.effect=="draw" else 2)
	if archetype=="pyro":
		if school=="F":
			if s.effect=="damage": result.amount+=heat
			if heat>=4: result.hp_cost+=2
		elif school=="A":
			if s.effect=="heal": result.amount+=heat
			else: result.heal=heat
	if archetype=="night" and school=="D" and s.effect=="damage":
		result.heal=int(ceil(mini(result.amount,enemy.hp)*s.get("leech",0.5)))
	return result

func spell_text(s):
	var p=spell_preview(s)
	var label=(str(p.amount)+" damage" if s.effect=="damage" else (str(p.amount)+" healing" if s.effect=="heal" else "Draw "+str(p.amount)))
	if s.get("school","")!="": label=R.NAMES[s.school]+" · "+label
	if p.hp_cost>0: label+=" · −"+str(p.hp_cost)+" HP"
	if p.heal>0: label+=" · +"+str(p.heal)+" HP"
	if R.cost(s)==2: label+=" · 2 casts"
	return label

func cast_block_reason(s):
	if s.is_empty(): return "Arrange a spell first."
	if phase!="player": return "Wait for your turn."
	if casts<R.cost(s): return "Not enough casts left."
	if player.hp<=spell_preview(s).hp_cost: return "Not enough HP to pay this spell's cost."
	if s.effect=="draw" and casts<=R.cost(s): return "Draw before your last cast."
	if s.effect=="heal" and player.hp>=player.max_hp: return "You are already at full health."
	return ""

func cast_allowed(s):
	return cast_block_reason(s)==""

func available_cards():
	var cards = player.hand.duplicate()
	for e in board:
		if e != "": cards.append(e)
	return cards

func is_lethal_spell(s):
	return s.effect == "damage" and spell_preview(s).amount >= enemy.hp

func castable_spells():
	var cards = available_cards()
	var choices = learned.filter(func(s): return cast_allowed(s) and R.can_make(cards,s))
	choices.sort_custom(func(a,b):
		var a_lethal = is_lethal_spell(a)
		var b_lethal = is_lethal_spell(b)
		if a_lethal != b_lethal: return a_lethal
		var a_complexity = R.occupied(a.pattern)
		var b_complexity = R.occupied(b.pattern)
		if a_complexity != b_complexity: return a_complexity > b_complexity
		var a_power = spell_preview(a).amount
		var b_power = spell_preview(b).amount
		if a_power != b_power: return a_power > b_power
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return choices

func has_playable_spell():
	return not castable_spells().is_empty()

func cast_player():
	var s = ready_spell()
	if not cast_allowed(s): return {}
	for e in board:
		if e != "": player.discard.append(e)
	board = ["","","","","","",""]
	casts -= R.cost(s)
	stats.casts += 1
	var event = resolve(s,player,enemy,"You")
	if s.effect == "damage": stats.damage += event.amount
	elif s.effect == "heal": stats.healed += event.amount
	else: stats.drawn += event.amount
	stats.healed+=event.healed
	if enemy.hp <= 0: phase = "won"
	return event

func arrange(s):
	if not cast_allowed(s): return false
	var all_cards = available_cards()
	if not learned.has(s) or not R.can_make(all_cards,s): return false
	clear_board()
	var p = R.materialize(player.hand,s.pattern)
	for i in range(7):
		if p[i] != "": place(player.hand.find(p[i]),i)
	return true

func resolve(s,caster,target,who):
	var p=spell_preview(s) if who=="You" else {"amount":s.amount,"hp_cost":0,"heal":0}
	caster.hp-=p.hp_cost
	var amount=p.amount
	match s.effect:
		"damage":
			amount=mini(amount,target.hp)
			target.hp=maxi(0,target.hp-amount)
		"heal":
			amount=mini(amount,caster.max_hp-caster.hp)
			caster.hp+=amount
		"draw": amount=draw_cards(caster,amount)
	var restored=mini(p.heal,caster.max_hp-caster.hp)
	caster.hp+=restored
	if who=="You":
		var school=s.get("school","")
		if archetype=="tide":
			if school=="W": tide=mini(3,tide+1)
			elif school=="L": tide=0
		elif archetype=="pyro":
			if school=="F": heat=mini(6,heat+1)
			elif school=="A": heat=0
	last_event={"who":who,"spell":s.name,"effect":s.effect,"amount":amount,"hp_cost":p.hp_cost,"healed":restored}
	history.append(last_event.duplicate())
	return last_event

func end_player_turn():
	if phase != "player": return false
	clear_board()
	phase = "enemy"
	enemy_casts = R.encounters()[stage].casts
	draw_cards(enemy,5)
	return true

func plan_enemy():
	if phase != "enemy" or enemy_casts <= 0: return {}
	var choices = []
	var best_damage = 0
	for s in R.enemy_spells(stage):
		if not R.can_make(enemy.hand,s): continue
		if s.effect == "draw" and enemy_casts <= 1: continue
		if s.effect == "heal" and (healed_enemy or enemy.hp > enemy.max_hp/2): continue
		choices.append(s)
		if s.effect == "damage": best_damage = maxi(best_damage,s.amount)
	var best = {}
	var best_score = -100.0
	for s in choices:
		var score = 0.0
		if s.effect == "damage":
			score = float(s.amount) - R.occupied(s.pattern)*0.03
			if s.amount >= player.hp: score += 1000
		elif s.effect == "heal":
			score = float(mini(s.amount,enemy.max_hp-enemy.hp))*1.65
			if enemy.hp <= 10: score += 2
		else:
			score = 1.0
			if round_number % 3 == 0 and best_damage < 8: score = best_damage+0.5
		if score > best_score:
			best_score = score
			best = s
	return best

func enemy_layout(s):
	return R.materialize(enemy.hand,s.pattern)

func cast_enemy(s):
	if phase != "enemy" or enemy_casts <= 0 or not R.enemy_spells(stage).has(s) or not R.can_make(enemy.hand,s): return {}
	if s.effect == "draw" and enemy_casts <= 1: return {}
	if s.effect == "heal" and healed_enemy: return {}
	var indices = R.indices_for(enemy.hand,s.pattern)
	indices.sort()
	indices.reverse()
	for i in indices:
		enemy.discard.append(enemy.hand[i])
		enemy.hand.remove_at(i)
	enemy_casts -= 1
	if s.effect == "heal": healed_enemy = true
	var event = resolve(s,enemy,player,R.encounters()[stage].name)
	if player.hp <= 0: phase = "lost"
	return event

func next_round():
	if phase != "enemy": return
	enemy_casts = 0
	round_number += 1
	casts = 2
	phase = "player"
	draw_cards(player,5)

func conserved(actor, include_board=false):
	return actor.pile.size()+actor.discard.size()+actor.hand.size()+(R.occupied(board) if include_board else 0)
