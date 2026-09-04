extends SceneTree
const R = preload("res://Rules.gd")
const B = preload("res://Battle.gd")
var checks = 0
var failed = false

func _initialize(): call_deferred("run")

func verify(condition,message):
	checks += 1
	if not condition:
		failed = true
		push_error("FAILED: "+message)

func damage_plan(hand,spells,casts):
	var best = {"score":0,"spell":{}}
	if casts<=0: return best
	for s in spells:
		if s.effect!="damage" or R.cost(s)>casts or not R.can_make(hand,s): continue
		var left = hand.duplicate()
		var used = R.indices_for(left,s.pattern)
		used.sort()
		used.reverse()
		for i in used: left.remove_at(i)
		var score = s.amount+damage_plan(left,spells,casts-R.cost(s)).score
		if score>best.score: best = {"score":score,"spell":s}
	return best

func clone_battle(b):
	var copy=B.new(b.stage,0,{},b.archetype)
	copy.player=b.player.duplicate(true)
	copy.enemy=b.enemy.duplicate(true)
	copy.board=b.board.duplicate()
	copy.casts=b.casts
	copy.tide=b.tide
	copy.heat=b.heat
	copy.learned=b.learned
	return copy

func search_turn(b,depth=2):
	var best={"score":-100.0,"spell":{}}
	for recipe in b.learned:
		if not b.cast_allowed(recipe) or not R.can_make(b.available_cards(),recipe): continue
		var sim=clone_battle(b)
		if not sim.arrange(recipe): continue
		var event=sim.cast_player()
		var damage=b.enemy.hp-sim.enemy.hp
		var recovery=sim.player.hp-b.player.hp
		var urgency=1.5 if b.player.hp<16 else (0.7 if b.player.hp<28 else 0.35)
		var score=damage+recovery*urgency+(sim.tide-b.tide)*0.8+(sim.heat-b.heat)*0.35
		if event.effect=="draw": score+=event.amount*0.2
		if sim.phase=="won": score+=1000
		elif depth>1 and sim.casts>0:
			var next=search_turn(sim,depth-1)
			if not next.spell.is_empty(): score+=next.score
		if score>best.score: best={"score":score,"spell":recipe}
	return best

func bot_choice(b):
	return search_turn(b).spell

func run():
	var spells = R.player_spells()
	var bolt = spells[5]
	var ward = spells[6]
	var study = spells[7]
	verify(R.variants(bolt.pattern).size()==12,"adjacent asymmetric spell has 12 orientations")
	verify(R.variants(ward.pattern).size()==3,"opposite identical waters have three orientations")
	verify(R.variants(study.pattern).size()==6,"opposite distinct elements have six orientations")
	for s in spells:
		for v in R.variants(s.pattern):
			var actual = v.duplicate()
			for i in range(7):
				if actual[i]=="*": actual[i]="W"
			verify(R.matches(actual,s),"every rotation/reflection matches "+s.id)
	verify(not R.matches(bolt.pattern,ward),"same counts do not imply same spell")
	verify(not R.matches(study.pattern,bolt),"opposite and adjacent have distinct results")
	var extra = bolt.pattern.duplicate()
	extra[4]="W"
	verify(not R.matches(extra,bolt),"extra occupied cells invalidate exact recipe")
	var b = B.new(0,42)
	verify(b.player.hand.size()==5,"draw exactly five on first turn")
	verify(b.learned.size()==8,"starter library")
	verify(not b.cast_allowed(spells[2]),"healing at full HP cannot waste a cast")
	var lethal_small=R.spell("test_lethal","Quick Finish","damage",5,{0:"W",1:"L"})
	var complex_heal=R.spell("test_complex","Grand Recovery","heal",1,{0:"W",1:"W",2:"L",3:"L"})
	var unavailable=R.spell("test_missing","Missing Blood","damage",99,{0:"B"})
	b.learned=[complex_heal,lethal_small,unavailable]
	b.player.hand=["W","W","L","L"]
	b.player.hp-=1
	b.enemy.hp=4
	var castable=b.castable_spells()
	verify(castable.size()==2 and castable[0].id=="test_lethal","castable list hides unavailable spells and puts a finishing blow first")
	b.enemy.hp=10
	castable=b.castable_spells()
	verify(castable[0].id=="test_complex" and R.occupied(castable[0].pattern)>R.occupied(castable[1].pattern),"nonlethal spells sort from most to fewest runes")
	b=B.new(0,42)
	var original = b.player.hand.duplicate()
	verify(b.place(0,0),"place from hand")
	verify(b.conserved(b.player,true)==20,"placement conserves deck")
	verify(b.place(0,0),"occupied-slot replacement returns old card")
	b.swap_slots(0,1)
	verify(b.conserved(b.player,true)==20,"swap conserves deck")
	b.clear_board()
	verify(b.player.hand.size()==5,"clear returns all placements")
	verify(not b.arrange(bolt),"cannot arrange unlearned spell")
	verify(b.place(0,0),"place a pulse")
	var event = b.cast_player()
	verify(event.amount==4 and b.casts==0 and b.enemy.hp==14,"cast spends budget and damages")
	verify(b.conserved(b.player,true)==20,"cast conserves deck")
	verify(b.cast_player().is_empty(),"no repeat cast on empty board")
	b.player.hp=b.player.max_hp-1
	var heal = b.resolve(spells[2],b.player,b.enemy,"You")
	verify(heal.amount==1 and b.player.hp==b.player.max_hp,"healing caps at maximum")
	verify(not b.cast_allowed(spells[3]),"draw spell cannot waste last cast")
	var old_casts=b.casts
	b.casts=0
	verify(not b.arrange(spells[0]),"arrange cannot bypass exhausted cast budget")
	b.casts=old_casts
	b.end_player_turn()
	verify(not b.place(0,0),"player cannot place during enemy turn")
	var es = b.plan_enemy()
	verify(not es.is_empty() and R.can_make(b.enemy.hand,es),"enemy uses actual cards")
	b.cast_enemy(es)
	verify(b.conserved(b.enemy)==20,"enemy casts conserve its deck")
	b.next_round()
	verify(b.player.hand.size()==9 and b.round_number==2,"next round retains four and draws five")
	for i in range(15):
		b.player.hp=b.player.max_hp
		b.enemy.hp=999
		b.end_player_turn()
		b.next_round()
		verify(b.conserved(b.player,true)==20 and b.conserved(b.enemy)==20,"recycling conserves decks")
	b = B.new(4,42)
	verify(b.learned.size()==12,"all rewards unlocked at Dragon")
	b.enemy.hp=1
	b.place(0,0)
	b.cast_player()
	verify(b.phase=="won" and b.enemy.hp==0,"lethal damage stops battle")
	verify(not b.end_player_turn(),"won fight cannot start enemy turn")
	var combo = B.new(4,90)
	combo.player.hand=["W","W","W","L","L"]
	combo.player.pile=[]
	combo.player.discard=[]
	verify(combo.arrange(bolt),"Tidal Bolt autofills")
	combo.cast_player()
	verify(not combo.cast_allowed(spells[0]) and not combo.arrange(spells[0]),"Pulse cannot follow another cast")
	verify(combo.arrange(spells[4]),"Sunshard uses Water-Light leftovers")
	verify(combo.cast_player().amount==6 and combo.casts==0,"mixed-element followup resolves")
	combo = B.new(4,100)
	combo.player.hand=["W","W","W","L","L"]
	verify(combo.arrange(spells[3]),"Scry fills from real hand")
	verify(combo.cast_player().amount==3 and combo.player.hand.size()==6,"Scry gains an ingredient for a larger finisher")
	verify(not combo.arrange(spells[3]),"cannot autofill a draw spell on last cast")
	var before_cards=combo.available_cards().duplicate()
	combo.player.hand=["L","L"]
	combo.clear_board()
	verify(not combo.arrange(bolt) and combo.player.hand==["L","L"],"unavailable autofill never consumes cards")
	combo.player.hand=before_cards
	# A draw must exhaust the original pile before recycling spent cards.
	var cycle=B.new(0,7)
	cycle.player.hand=["W","L"]
	cycle.player.pile=["E","F"]
	cycle.player.discard=["D","B"]
	verify(cycle.draw_cards(cycle.player,1)==1 and cycle.player.hand==["W","L","F"] and cycle.player.discard.size()==2 and cycle.player.reshuffles==0,"draw leaves discard untouched while original pile remains")
	verify(cycle.draw_cards(cycle.player,2)==2 and cycle.player.hand[3]=="E" and cycle.player.reshuffles==1 and cycle.player.discard.is_empty(),"draw crossing exhaustion takes last original card before one reshuffle")
	verify(cycle.draw_cards(cycle.player,5)==1 and cycle.player.hand.size()==6 and cycle.player.reshuffles==1,"empty draw and discard stop drawing without recycling hand")
	var retain=B.new(0,20)
	var kept=retain.player.hand.duplicate()
	retain.place(0,2)
	retain.end_player_turn()
	verify(retain.player.hand.size()==5 and retain.player.discard.is_empty(),"uncast board gems return to retained hand")
	retain.next_round()
	verify(retain.player.hand.size()==10 and retain.player.pile.size()==10 and retain.player.reshuffles==0,"five additional cards each turn without premature reshuffle")
	for e in kept: verify(retain.player.hand.has(e),"unused ingredients remain in hand")
	for c in R.classes():
		var class_battle=B.new(4,2,c.deck,c.id)
		verify(class_battle.conserved(class_battle.player,true)==20 and class_battle.learned.size()==12,"class owns a full deck and nine evolving recipes")
		for recipe in class_battle.learned:
			for other in class_battle.learned:
				if other.id!=recipe.id: verify(not R.matches(recipe.pattern,other),"class spell patterns never collide")
			verify(R.can_make(class_battle.available_cards()+class_battle.player.pile,recipe),"every class recipe can be made from its starting deck")
		var deck=c.deck.duplicate()
		for e in R.NAMES:
			if e not in c.elements:
				deck[e]=1
				var captured=B.new(4,5,deck,c.id)
				captured.player.hp=20
				captured.player.hand=[e]
				var recipe=R.gem_spell(e)
				verify(captured.arrange(recipe) and captured.ready_spell().id==recipe.id,"captured gem autofill selects its own spell")
				verify(not R.matches(captured.board,captured.learned[0]),"captured outer-gem pattern does not conflict with Pulse core")
				captured.clear_board()
				verify(captured.arrange(captured.learned[0]) and captured.ready_spell().id=="pulse","Pulse autofill stays Pulse with a captured gem")
	# Each class owns actual mechanics and distinct geometry, not remapped recipes.
	var tide_b=B.new(4,10)
	tide_b.player.hand=["W","W","L","W"]
	verify(tide_b.arrange(tide_b.learned[1]),"Tide builds with Water")
	tide_b.cast_player()
	verify(tide_b.tide==1,"Water stores one Tide")
	verify(tide_b.arrange(tide_b.learned[4]) and tide_b.spell_preview(tide_b.learned[4]).amount==6,"Light previews stored Tide bonus")
	verify(tide_b.cast_player().amount==6 and tide_b.tide==0,"Light consumes Tide exactly once")
	tide_b.tide=3
	tide_b.casts=2
	tide_b.player.hand=["W","W"]
	tide_b.arrange(tide_b.learned[1])
	tide_b.cast_player()
	verify(tide_b.tide==3,"Tide cap prevents unbounded hoarding")
	var fire=B.new(4,11,{},"pyro")
	verify(fire.player.max_hp==28 and fire.conserved(fire.player)==20,"Pyromancer has fragile HP and a Fire-heavy deck")
	fire.heat=4
	fire.player.hand=["F","F","A","A"]
	fire.arrange(fire.learned[1])
	var hot=fire.cast_player()
	verify(hot.amount==8 and hot.hp_cost==2 and fire.player.hp==26 and fire.heat==5,"hot Fire gains damage, spends HP, builds Heat")
	fire.arrange(fire.learned[2])
	var cool=fire.cast_player()
	verify(cool.amount==2 and fire.player.hp==28 and fire.heat==0,"Air vents Heat and caps healing at max HP")
	fire.casts=2
	fire.heat=6
	fire.player.hp=2
	fire.player.hand=["F","F"]
	verify(not fire.arrange(fire.learned[1]) and fire.player.hand.size()==2,"overheat cannot pay lethal HP cost or consume gems")
	fire.player.hp=3
	verify(fire.arrange(fire.learned[1]),"overheat allowed when one HP remains")
	fire.cast_player()
	verify(fire.player.hp==1 and fire.heat==6,"overheat and Heat cap are enforced")
	var night=B.new(4,12,{},"night")
	verify(night.player.max_hp==22,"Nightbinder starts fragile, with blood-heavy deck")
	night.player.hand=["B","B","D","D"]
	night.arrange(night.learned[2])
	verify(night.cast_player().amount==8 and night.player.hp==19,"Blood Offering spends health for attack power")
	night.arrange(night.learned[1])
	var drain=night.cast_player()
	verify(drain.healed==2 and night.player.hp==21,"Dark siphons actual damage back as HP")
	night.casts=2
	night.player.hp=3
	night.player.hand=["B","D"]
	verify(not night.arrange(night.learned[3]),"blood drawing cannot kill its caster")
	night.player.hp=20
	night.enemy.hp=1
	night.player.hand=["D","D"]
	night.arrange(night.learned[1])
	drain=night.cast_player()
	verify(drain.amount==1 and drain.healed==1 and night.phase=="won","lethal life steal only heals from actual damage")
	for cid in ["pyro","night"]:
		var distinct=0
		var remap=R.class_data(cid).elements
		var book=R.player_spells(cid)
		for i in range(9):
			var normalized=book[i].pattern.duplicate()
			for j in range(7):
				if normalized[j]==remap[0]: normalized[j]="W"
				elif normalized[j]==remap[1]: normalized[j]="L"
			if not R.matches(normalized,spells[i]): distinct+=1
		verify(distinct>=5,"each new class has at least five genuinely different patterns")
	# All 98 weaves are distinct, castable, and recognized after rotations.
	for c in R.classes():
		var catalog=R.rune_catalog(c.id)
		verify(R.weave_spells(c.id).size()==98 and catalog.size()==112,"large catalog contains 98 weaves and 14 class/rune patterns")
		for i in range(catalog.size()):
			for j in range(i+1,catalog.size()):
				verify(not R.matches(catalog[i].pattern,catalog[j]),"no two catalog recipes collide under rotation/reflection")
		for recipe in R.weave_spells(c.id):
			var composition=c.deck.duplicate()
			for e in R.NAMES: composition[e]=maxi(composition.get(e,0),3)
			var trial=B.new(4,20,composition,c.id)
			trial.player.hp=20
			trial.player.hand=R.deck_cards(composition)
			trial.player.pile=[]
			var before=trial.conserved(trial.player,true)
			verify(trial.arrange(recipe) and trial.ready_spell().id==recipe.id,"every weave autofills its exact recipe")
			for variant in R.variants(recipe.pattern): verify(R.matches(variant,recipe),"weave rotations preserve identity")
			verify(not trial.cast_player().is_empty() and trial.conserved(trial.player,true)==before,"all weave effects resolve and conserve gems")
		for e in R.NAMES:
			if e in c.elements: continue
			var new_recipes=R.reward_spells(c.id,c.deck,e,1)
			var mixed=new_recipes.filter(func(recipe): return recipe.get("weave",false))
			verify(mixed.size()>=5,"one captured gem immediately enables at least five mixed patterns")
			for native in c.elements:
				verify(mixed.any(func(recipe): return e in recipe.pattern and native in recipe.pattern),"reward combines with BOTH starting elements")
			var added=c.deck.duplicate()
			added[e]=1
			for recipe in new_recipes: verify(R.can_make(R.deck_cards(added),recipe),"reward previews only patterns the actual deck can build")
	var dark_deck={"W":12,"L":8,"D":1}
	var first_dark=R.player_spells("tide",dark_deck)
	verify(first_dark.any(func(recipe): return recipe.id=="weave_WD0") and first_dark.any(func(recipe): return recipe.id=="weave_LD0") and first_dark.any(func(recipe): return recipe.id=="weave_WLD"),"Dark combines with Water, Light and both together")
	verify(not first_dark.any(func(recipe): return recipe.id=="weave_WD2"),"two-Dark recipe waits until deck owns two Dark")
	verify(R.reward_spells("tide",dark_deck,"D",1).any(func(recipe): return recipe.id=="weave_WD2"),"second captured copy unlocks advanced patterns")
	var woven=B.new(4,30,dark_deck,"tide")
	woven.player.hand=["W","D","L","D"]
	woven.arrange(R.weave_spells("tide").filter(func(recipe): return recipe.id=="weave_WD0")[0])
	woven.cast_player()
	verify(woven.tide==1,"captured Dark/Water weave builds Tide")
	woven.arrange(R.weave_spells("tide").filter(func(recipe): return recipe.id=="weave_LD0")[0])
	verify(woven.cast_player().amount==8 and woven.tide==0,"Dark/Light weave spends Tide")
	woven.casts=2
	woven.tide=2
	woven.player.hand=["L","L","W"]
	woven.arrange(R.weave_spells("tide").filter(func(recipe): return recipe.id=="weave_WL2")[0])
	verify(woven.cast_player().amount==6 and woven.tide==0,"Light draw weave spends Tide for extra cards")
	var hot_deck={"F":14,"A":6,"E":1}
	var hot_weave=B.new(4,30,hot_deck,"pyro")
	hot_weave.player.hand=["E","F"]
	hot_weave.heat=3
	hot_weave.arrange(R.weave_spells("pyro").filter(func(recipe): return recipe.id=="weave_EF0")[0])
	verify(hot_weave.cast_player().amount==10 and hot_weave.heat==4,"Earth/Fire weave gains Heat damage and builds Heat")
	var shadow_deck={"D":10,"B":10,"W":1}
	var shadow_weave=B.new(4,30,shadow_deck,"night")
	shadow_weave.player.hp=shadow_weave.player.max_hp-10
	shadow_weave.player.hand=["D","W"]
	shadow_weave.arrange(R.weave_spells("night").filter(func(recipe): return recipe.id=="weave_WD0")[0])
	verify(shadow_weave.cast_player().healed==3,"Dark/Water weave inherits Nightbinder life steal")
	# Run three complete campaigns with growing decks, including optional rewards.
	for c in R.classes():
		var campaign_wins=0
		for seed_value in range(12):
			var deck=c.deck.duplicate()
			for stage in range(5):
				var sim=B.new(stage,seed_value+700,deck,c.id)
				var total=0
				for count in deck.values(): total+=count
				while sim.phase not in ["won","lost"] and sim.round_number<40:
					while sim.casts>0 and sim.phase=="player":
						var action=bot_choice(sim)
						if action.is_empty(): break
						verify(sim.arrange(action) and sim.ready_spell().id==action.id,"class campaign autofill selects intended spell")
						verify(not sim.cast_player().is_empty(),"class campaign spell resolves")
						verify(sim.conserved(sim.player,true)==total,"growing deck conserves all cards")
					if sim.phase=="won": break
					sim.end_player_turn()
					while sim.phase=="enemy" and sim.enemy_casts>0:
						var action=sim.plan_enemy()
						if action.is_empty(): break
						sim.cast_enemy(action)
					if sim.phase=="enemy": sim.next_round()
				verify(sim.round_number<40,"class campaign battle finishes")
				if sim.phase!="won": break
				if stage==4: campaign_wins+=1
				if seed_value%2==0:
					var choices=R.encounters()[stage].deck.keys()
					var gem=choices[seed_value%choices.size()]
					deck[gem]=deck.get(gem,0)+1
		print("CAMPAIGN %s: %d/12 complete" % [c.name,campaign_wins])
	for stage in range(5):
		var wins=0
		var turns=0
		var health=0
		for seed_value in range(25):
			var sim=B.new(stage,seed_value+1234)
			while sim.phase not in ["won","lost"] and sim.round_number<40:
				while sim.casts>0 and sim.phase=="player":
					var action=bot_choice(sim)
					if action.is_empty(): break
					verify(sim.arrange(action),"bot can arrange chosen legal action")
					verify(not sim.cast_player().is_empty(),"bot action resolves")
					verify(sim.conserved(sim.player,true)==20,"simulation player card conservation")
				if sim.phase=="won": break
				sim.end_player_turn()
				while sim.phase=="enemy" and sim.enemy_casts>0:
					var action=sim.plan_enemy()
					if action.is_empty(): break
					verify(R.matches(sim.enemy_layout(action),action),"enemy layout is a valid pattern")
					verify(not sim.cast_enemy(action).is_empty(),"enemy action resolves")
					verify(sim.conserved(sim.enemy)==20,"simulation enemy card conservation")
				if sim.phase=="enemy": sim.next_round()
			verify(sim.round_number<40,"fight cannot stall indefinitely")
			if sim.phase=="won":
				wins+=1
				health+=sim.player.hp
			turns+=sim.round_number
		print("BALANCE %s: %d/25 wins, %.2f turns, %.1f remaining HP on wins" % [R.encounters()[stage].name,wins,float(turns)/25,float(health)/maxi(1,wins)])
	print("CHECKS: %d — %s" % [checks,"FAIL" if failed else "PASS"])
	quit(1 if failed else 0)
