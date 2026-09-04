extends RefCounted
## Pure spell geometry and encounter data. Slot 0 is the core, 1..6 clockwise.

static var weave_cache={}

const NAMES = {"W":"Water", "L":"Light", "D":"Dark", "B":"Blood", "E":"Earth", "F":"Fire", "A":"Air"}
const COLORS = {"W":Color("218da2"), "L":Color("d8a332"), "D":Color("77628e"), "B":Color("a4424a"), "E":Color("778748"), "F":Color("da632f"), "A":Color("79b9c7")}

static func spell(id, title, effect, amount, slots, unlock=0, detail="", cost=1):
	var pattern = ["", "", "", "", "", "", ""]
	for i in slots: pattern[i] = slots[i]
	return {"id":id, "name":title, "effect":effect, "amount":amount, "pattern":pattern, "unlock":unlock, "detail":detail, "cost":cost}

static func player_spells(class_id="tide", owned_elements=[]):
	var result = [
		spell("pulse", "Pulse", "damage", 4, {0:"*"}, 0, "Any core. Uses BOTH casts as a fallback.", 2),
		spell("twin", "Twin Tide", "damage", 5, {0:"W",1:"W"}, 0, "Water core + an outer Water."),
		spell("mend", "Mend", "heal", 5, {0:"L",1:"L"}, 0, "Light core + an outer Light."),
		spell("scry", "Scry", "draw", 3, {0:"W",1:"L"}, 0, "Water core + Light. Draw, then cast again."),
		spell("shard", "Sunshard", "damage", 4, {0:"L",1:"W"}, 0, "Light core + Water. Reverse Scry to strike."),
		spell("bolt", "Tidal Bolt", "damage", 9, {0:"W",1:"W",2:"L"}, 1, "Water core. Outer Water and Light touch."),
		spell("ward", "Tidal Ward", "heal", 8, {0:"L",6:"W",3:"W"}, 2, "Light core between opposite Waters."),
		spell("study", "Deep Study", "draw", 5, {0:"W",6:"W",3:"L"}, 3, "Water core. Outer Water and Light oppose."),
		spell("dawn", "Dawnfall", "damage", 18, {0:"L",1:"W",2:"L",3:"W",4:"W"}, 4, "Light core + a Water, Light, Water, Water arc.")
	]

	for recipe in result:
		recipe.school=recipe.pattern[0] if recipe.id!="pulse" else ""
	if class_id=="pyro":
		result=[
			spell("pulse","Pulse","damage",4,{0:"*"},0,"Any core. Both casts.",2),
			attune(spell("twin","Kindle","damage",4,{0:"F",1:"F"},0,"Fire core and outer Fire. Build Heat."),"F"),
			attune(spell("mend","Cooling Breath","heal",3,{0:"A",1:"A"},0,"Air pair. Vent Heat into healing."),"A"),
			attune(spell("scry","Bellows","draw",3,{0:"A",1:"F"},0,"Air core and Fire. Vent, draw, strike."),"A"),
			attune(spell("shard","Firebrand","damage",6,{1:"F",2:"A"},0,"Touching Fire and Air. Empty core."),"F"),
			attune(spell("bolt","Flame Lance","damage",9,{0:"F",1:"F",4:"A"},1,"Fire core between opposite Fire/Air."),"F"),
			attune(spell("ward","Backdraft","damage",7,{0:"A",1:"F",2:"F"},2,"Air core, touching Fires. Vent and hit."),"A"),
			attune(spell("study","Stoke","draw",4,{1:"A",3:"A",5:"F"},3,"Three spaced outer gems. Build Heat."),"F"),
			attune(spell("dawn","Wildfire","damage",15,{0:"F",1:"F",2:"F",3:"A"},4,"Fire core under a Fire/Fire/Air arc."),"F")
		]
	elif class_id=="night":
		result=[
			spell("pulse","Pulse","damage",4,{0:"*"},0,"Any core. Both casts. No life steal.",2),
			attune(spell("twin","Siphon","damage",4,{0:"D",1:"D"},0,"Dark pair. Steal half the damage."),"D"),
			attune(spell("mend","Blood Offering","damage",8,{0:"B",1:"B"},0,"Blood pair. Pay 3 HP for power."),"B",3),
			attune(spell("scry","Forbidden Pact","draw",4,{0:"B",1:"D"},0,"Blood core and Dark. Pay 3 HP to draw."),"B",3),
			attune(spell("shard","Night Fang","damage",4,{1:"D",4:"B"},0,"Opposite Dark/Blood. Empty core."),"D"),
			attune(spell("bolt","Heartseeker","damage",12,{0:"B",1:"D",3:"B"},1,"Blood core with a gap between outers."),"B",4),
			attune(spell("ward","Soul Feast","damage",7,{0:"D",1:"B",4:"B"},2,"Dark core between Bloods. Steal all."),"D",0,1.0),
			attune(spell("study","Grave Bargain","draw",6,{1:"B",3:"D",5:"B"},3,"Three spaced outer gems. Pay 5 HP."),"B",5),
			attune(spell("dawn","Eclipse","damage",16,{0:"D",1:"D",3:"B",5:"D"},4,"Dark core and three spaced outers."),"D")
		]
	var c=class_data(class_id)
	var counts=owned_elements.duplicate() if owned_elements is Dictionary and not owned_elements.is_empty() else c.deck.duplicate()
	if owned_elements is Array:
		for e in owned_elements:
			if not counts.has(e): counts[e]=1
	var cards=deck_cards(counts)
	for e in NAMES:
		if counts.has(e) and e not in c.elements: result.append(gem_spell(e))
	for recipe in weave_spells(class_id):
		if can_make(cards,recipe): result.append(recipe)
	return result

static func deck_cards(composition):
	var cards=[]
	for e in composition:
		for i in range(composition[e]): cards.append(e)
	return cards

static func rune_catalog(class_id):
	var all={}
	for e in NAMES: all[e]=7
	return player_spells(class_id,all)

static func reward_spells(class_id,composition,element,level):
	var before={}
	for recipe in player_spells(class_id,composition):
		if recipe.unlock<=level: before[recipe.id]=true
	var after=composition.duplicate()
	after[element]=after.get(element,0)+1
	var unlocked=[]
	for recipe in player_spells(class_id,after):
		if recipe.unlock<=level and not before.has(recipe.id): unlocked.append(recipe)
	return unlocked

static func weave_spells(class_id):
	if weave_cache.has(class_id): return weave_cache[class_id]
	# Every pair has a two-gem crescent and two distinct three-gem patterns.
	var pairs=[
		["W","L",["Dewlight","heal",4],["Prism Current","damage",8],["Mirrorwell","draw",4]],
		["W","D",["Blackwater","damage",6],["Drowned Memory","draw",4],["Undertow","damage",9]],
		["W","B",["Red Tide","damage",7],["Bloodspring","heal",6],["Crimson Current","damage",10]],
		["W","E",["Living Spring","heal",5],["Riverstone","damage",9],["Rootwater","draw",4]],
		["W","F",["Steam Burst","damage",7],["Scalding Veil","draw",4],["Boiling Point","damage",10]],
		["W","A",["Miststep","draw",3],["Cloudbreak","damage",8],["Raincall","heal",6]],
		["L","D",["Eclipse Spark","damage",6],["Twilight Pact","draw",4],["Duskfire","damage",9]],
		["L","B",["Martyr's Light","heal",5],["Sanguine Dawn","damage",9],["Vital Oath","heal",7]],
		["L","E",["Sunroot","heal",5],["Amber Lance","damage",9],["Sanctuary","heal",7]],
		["L","F",["Solar Flare","damage",7],["Cleansing Flame","heal",6],["Sunforge","damage",10]],
		["L","A",["Guiding Wind","draw",3],["Aurora","heal",6],["Prism Gust","damage",9]],
		["D","B",["Blood Hex","damage",6],["Grave Thirst","damage",8],["Scarlet Pact","draw",4]],
		["D","E",["Grave Root","damage",6],["Buried Memory","draw",4],["Obsidian Fang","damage",10]],
		["D","F",["Witchfire","damage",7],["Ashen Secrets","draw",4],["Hellbrand","damage",10]],
		["D","A",["Nightwind","draw",3],["Hollow Gale","damage",9],["Ravenflight","draw",4]],
		["B","E",["Briar Blood","damage",7],["Heartwood","heal",6],["Thorn Pact","damage",10]],
		["B","F",["Bloodfire","damage",8],["Crimson Ember","damage",10],["Phoenix Blood","heal",7]],
		["B","A",["Quickblood","draw",3],["Razorwind","damage",9],["Second Heart","heal",7]],
		["E","F",["Magma Shard","damage",7],["Obsidian Skin","heal",6],["Volcanic Spear","damage",11]],
		["E","A",["Dust Devil","damage",6],["Stone Echo","draw",4],["Mountain Breath","heal",7]],
		["F","A",["Firewhirl","damage",7],["Furnace Gale","damage",10],["Cinderflight","draw",4]]
	]
	var result=[]
	for row in pairs:
		var a=row[0]
		var b=row[1]
		var layouts=[{1:a,3:b},{0:a,1:b,3:a},{0:b,1:a,2:b}]
		var hints=["Outer crescent. Leave one hex between.","Core and two outers, one hex apart.","Core and two touching outer gems."]
		for i in range(3):
			var data=row[i+2]
			var recipe=spell("weave_"+a+b+str(i),data[0],data[1],data[2],layouts[i],0,hints[i])
			result.append(weave_attunement(recipe,class_id,b if i==2 else a))
	# One of each element forms a core with two opposite outer gems.
	var triples=[
		["WLD","Dusk Covenant","damage",10],["WLB","Mercy Tide","heal",8],["WLE","Sacred Grove","heal",9],
		["WLF","Dawnsteam","damage",11],["WLA","Rainbow Current","draw",5],
		["WDB","Drowned Heart","damage",11],["WDE","Sunken Crypt","damage",10],["WDF","Ghost Steam","damage",12],["WDA","Mist of Secrets","draw",5],
		["WBE","Living Marsh","heal",8],["WBF","Crimson Boil","damage",12],["WBA","Heartbeat Rain","heal",8],
		["WEF","Geyser","damage",12],["WEA","Monsoon","draw",5],["WFA","Stormfront","damage",11],
		["LDB","Twilight Heart","heal",8],["LDE","Forgotten Shrine","draw",5],["LDF","Ghost Lantern","damage",12],["LDA","Aurora Veil","draw",5],
		["LBE","Tree of Life","heal",9],["LBF","Phoenix Oath","heal",9],["LBA","Wings of Mercy","heal",8],
		["LEF","Sunstone","damage",12],["LEA","Sky Sanctuary","heal",9],["LFA","Solar Storm","damage",12],
		["DBE","Gravebloom","damage",11],["DBF","Hellheart","damage",13],["DBA","Raven Covenant","draw",5],
		["DEF","Ashen Tomb","damage",12],["DEA","Dust of Ages","draw",5],["DFA","Witchstorm","damage",12],
		["BEF","Molten Heart","damage",13],["BEA","Wildheart","heal",8],["BFA","Crimson Tempest","damage",12],
		["EFA","Volcanic Storm","damage",13]
	]
	for row in triples:
		var code=row[0]
		var recipe=spell("weave_"+code,row[1],row[2],row[3],{0:code[0],1:code[1],4:code[2]},0,"Three elements. Outer gems opposite.")
		result.append(weave_attunement(recipe,class_id,code[0]))
	weave_cache[class_id]=result
	return result

static func weave_attunement(recipe,class_id,preferred):
	var native=class_data(class_id).elements
	var school=preferred
	if school not in native:
		for e in native:
			if e in recipe.pattern:
				school=e
				break
	var price=2 if class_id=="night" and school=="B" and recipe.effect in ["damage","draw"] else 0
	recipe=attune(recipe,school,price)
	if class_id!="night": recipe.erase("leech")
	recipe.weave=true
	return recipe

static func attune(recipe,school,hp_cost=0,leech=0.5):
	recipe.school=school
	recipe.hp_cost=hp_cost
	if school=="D": recipe.leech=leech
	return recipe

static func classes():
	return [
		{"id":"tide","name":"Tidecaller","elements":["W","L"],"deck":{"W":9,"L":11},"hp":30,"role":"Patient combination caster","trait":"Ebb & Flow","lines":["Water builds Tide, up to 3.","Light spends Tide to boost its spell.","Each Tide: +2 power or +1 draw."]},
		{"id":"pyro","name":"Pyromancer","elements":["F","A"],"deck":{"F":14,"A":6},"hp":28,"role":"A volatile damage engine","trait":"Heat","lines":["Fire gains +1 Heat and hits harder.","At 4+ Heat, Fire costs 2 HP.","Air vents Heat into healing."]},
		{"id":"night","name":"Nightbinder","elements":["D","B"],"deck":{"D":8,"B":12},"hp":22,"role":"Life is a resource","trait":"Blood Price","lines":["Blood spends HP for stronger spells.","Dark attacks steal half their damage.","Soul Feast steals all of its damage."]}
	]

static func class_data(id):
	for c in classes():
		if c.id == id: return c
	return classes()[0]

static func gem_spell(e):
	var data = {"W":["Ripple","damage",3],"L":["Gleam","heal",3],"F":["Ember","damage",4],"A":["Breeze","draw",2],"E":["Root","heal",3],"D":["Hex","damage",4],"B":["Blood Bloom","heal",4]}[e]
	return spell("gem_"+e,data[0],data[1],data[2],{1:e},0,"One captured "+NAMES[e]+" gem on an outer hex. Empty core.")


static func encounters():
	return [
		{"name":"Bat", "hp":18, "deck":{"D":12,"B":8}, "casts":1, "portrait":"bat", "place":"THE HOLLOW", "flavor":"A flutter in the dusk. Your first spell awaits.", "intent":"Small attacks · one cast", "lesson":"A small beginning", "reward":"bolt"},
		{"name":"Goblin", "hp":28, "deck":{"E":12,"D":8}, "casts":1, "portrait":"goblin", "place":"MOSSWOOD", "flavor":"A crooked grin, and a pocket full of stones.", "intent":"Stronger patterns · one cast", "lesson":"Find the stronger pattern", "reward":"ward"},
		{"name":"Troll", "hp":42, "deck":{"E":16,"B":4}, "casts":1, "portrait":"troll", "place":"THE OLD CROSSING", "flavor":"Heavy hands. Stubborn roots. Pick your moment.", "intent":"Heavy hits · can regenerate once", "lesson":"Know when to recover", "reward":"study"},
		{"name":"Necromancer", "hp":52, "deck":{"D":12,"B":8}, "casts":2, "portrait":"necromancer", "place":"QUIET GRAVES", "flavor":"An old scholar with a dangerous second thought.", "intent":"Draws and combines · two casts", "lesson":"Make your two casts count", "reward":"dawn"},
		{"name":"Dragon", "hp":66, "deck":{"F":10,"E":6,"A":4}, "casts":2, "portrait":"dragon", "place":"THE EMBER DEN", "flavor":"Every pattern you have learned leads here.", "intent":"Three elements · two casts", "lesson":"Bring the whole spellbook", "reward":""}
	]

static func enemy_spells(stage):
	var base = [spell("epulse", "Ember" if stage==4 else "Dark Pulse", "damage", 2, {0:"*"})]
	match stage:
		0:
			base.append(spell("bite", "Night Bite", "damage", 4, {0:"D",1:"B"}))
			base.append(spell("sip", "Blood Sip", "heal", 2, {0:"B",1:"B"}))
		1:
			base.append(spell("stone", "Stone Throw", "damage", 6, {0:"E",1:"E"}))
			base.append(spell("ambush", "Shadow Stone", "damage", 7, {0:"E",1:"E",2:"D"}))
		2:
			base.append(spell("slam", "Stone Slam", "damage", 7, {0:"E",1:"E"}))
			base.append(spell("crush", "Earthbreaker", "damage", 8, {0:"E",1:"E",2:"E"}))
			base.append(spell("regrow", "Regrowth", "heal", 6, {0:"B",1:"E",4:"E"}))
		3:
			base.append(spell("grave", "Grave Bolt", "damage", 4, {0:"D",1:"D"}))
			base.append(spell("lance", "Grave Lance", "damage", 6, {0:"D",1:"D",2:"B"}))
			base.append(spell("bloodmend", "Blood Mend", "heal", 6, {0:"B",1:"B"}))
			base.append(spell("forbidden", "Forbidden Study", "draw", 2, {0:"D",1:"B"}))
		4:
			base.append(spell("flame", "Fire Breath", "damage", 4, {0:"F",1:"A"}))
			base.append(spell("fang", "Molten Fang", "damage", 7, {0:"F",1:"F",2:"E"}))
			base.append(spell("scales", "Renewed Scales", "heal", 6, {0:"E",1:"F",4:"F"}))
			base.append(spell("wings", "Wingbeat", "draw", 3, {0:"A",1:"F",4:"E"}))
			base.append(spell("inferno", "Inferno", "damage", 12, {0:"F",1:"F",2:"E",3:"A",4:"A"}))
	return base

static func variants(pattern):
	var result = []
	for sign_value in [1,-1]:
		for rotation in range(6):
			var v = [pattern[0],"","","","","",""]
			for i in range(6): v[1+posmod(i*sign_value+rotation,6)] = pattern[i+1]
			if not result.has(v): result.append(v)
	return result

static func occupied(pattern):
	var n = 0
	for e in pattern:
		if e != "": n += 1
	return n

static func compatible(board, pattern, exact=false):
	for i in range(7):
		if board[i] == "":
			if exact and pattern[i] != "": return false
		elif pattern[i] == "" or (pattern[i] != "*" and board[i] != pattern[i]): return false
	return true

static func matches(board, s):
	for v in variants(s.pattern):
		if compatible(board,v,true): return true
	return false

static func best_fit(board, s):
	for v in variants(s.pattern):
		if compatible(board,v): return v
	return []

static func indices_for(hand, pattern):
	var used = []
	for e in pattern:
		if e == "" or e == "*": continue
		var found = -1
		for i in range(hand.size()):
			if hand[i] == e and not used.has(i):
				found = i
				break
		if found < 0: return []
		used.append(found)
	for e in pattern:
		if e != "*": continue
		var found = -1
		for i in range(hand.size()):
			if not used.has(i):
				found = i
				break
		if found < 0: return []
		used.append(found)
	return used

static func can_make(hand, s):
	return indices_for(hand,s.pattern).size() == occupied(s.pattern)

static func materialize(hand, pattern):
	var p = pattern.duplicate()
	var indices = indices_for(hand,pattern)
	if indices.size() != occupied(pattern): return []
	var exact = []
	for i in range(hand.size()): exact.append(i)
	for e in pattern:
		if e == "" or e == "*": continue
		for i in exact.duplicate():
			if hand[i] == e:
				exact.erase(i)
				break
	for i in range(7):
		if p[i] == "*": p[i] = hand[exact.pop_front()]
	return p

static func effect_text(s):
	match s.effect:
		"damage": return "Deal %d damage" % s.amount
		"heal": return "Restore %d HP" % s.amount
		_: return "Draw %d cards" % s.amount

static func cost(s):
	return int(s.get("cost",1))
