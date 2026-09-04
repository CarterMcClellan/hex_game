extends Control
const R = preload("res://Rules.gd")
const B = preload("res://Battle.gd")

const PAPER = Color("f8f2e4")
const INK = Color("203b40")
const GOLD = Color("b58a43")
const MUTE = Color("7c8478")
const LINE = Color("dcd2ba")
const TEAL = Color("286c72")
const RED = Color("ad5451")
const GREEN = Color("648365")

var title_font = preload("res://assets/Title.ttf")
var body_font = preload("res://assets/Body.ttf")
var elements = preload("res://assets/elements.png")
var characters = preload("res://assets/characters.png")
var enemies_art = preload("res://assets/enemies.png")
var dragon_art = preload("res://assets/dragon.png")
var map_art = preload("res://assets/overworld.png")
var clearing_art = preload("res://assets/battle-clearing.png")
var scenery = TextureRect.new()
var river_material = ShaderMaterial.new()
const BOARD_RADIUS = 80.0
const BOARD_ORIGIN = Vector2(530,413)
const BOARD_SPACING = 145.4922678 # sqrt(3) * (radius + 4): uniform eight-pixel gaps.
const ENEMY_CENTER = Vector2(530,96)
const PLAYER_CENTER = Vector2(530,662)
const MAP_NODES = [Vector2(292,470),Vector2(494,340),Vector2(844,483),Vector2(1061,344),Vector2(1301,486)]
const SETTINGS_RECT = Rect2(510,165,420,570)
var map_walking = false
var map_walk_points = PackedVector2Array()
var map_walk_distance = 0.0
var map_walk_target = -1
var map_player_position = Vector2(110,503)
var map_token_positions = [Vector2(110,503),Vector2(410,383),Vector2(564,375),Vector2(967,408),Vector2(1198,436),Vector2(1360,490)]
var battle = null
var screen = "map"
var unlocked = 0
var class_id = ""
var campaign_deck = {}
var spell_filter = "all"
var book_scope = "deck"
var book_element = ""
var spell_page = 0
var book_page = 0
var hand_offset = 0
var card_indices = []
var modal = ""
var selected_card = -1
var preview_id = ""
var regions = []
var card_rects = []
var mouse = Vector2.ZERO
var press_mouse = Vector2.ZERO
var drag_source = ""
var drag_index = -1
var dragging = false
var elapsed = 0.0
var flash = 0.0
var flash_color = TEAL
var toast = ""
var toast_time = 0.0
var impact = ""
var enemy_board = []
var enemy_spell = ""
var animation_running = false
var fight_generation = 0
var sound_on = true
var audio = AudioStreamPlayer.new()
var sounds = {}
var test_mode = false
var screenshot_path = ""
var last_hover_id = ""
var save_file = "user://progress.cfg"
var music_on = true
var music = AudioStreamPlayer.new()
var music_track = ""
var music_tween: Tween
var slot_impacts = {}
var cast_fx = {}
var portrait_hit = ""
var hit_time = 0.0
var outcome_pending = false
var music_streams = {
	"map":preload("res://assets/music/trail.wav"),
	"battle":preload("res://assets/music/duel.wav"),
	"boss":preload("res://assets/music/spire.wav")
}

const TOKEN_REGIONS = {
	"F":Rect2(27,55,339,389), "A":Rect2(408,55,342,389),
	"E":Rect2(793,55,339,389), "W":Rect2(1174,55,337,389),
	"D":Rect2(205,530,340,390), "L":Rect2(593,531,341,389), "B":Rect2(979,531,340,389)
}
const PORTRAIT_REGIONS = {
	"goblin":Rect2(28,60,546,622), "bat":Rect2(604,76,571,607), "elf":Rect2(1202,70,545,617),
	"troll":Rect2(30,66,547,620), "necromancer":Rect2(606,68,565,620), "lich":Rect2(1203,67,542,620), "dragon":Rect2(0,0,1254,1254)
}

func _ready():
	set_process_input(true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The shader belongs to scenery alone; interactive tiles and HUD are drawn above it.
	scenery.show_behind_parent = true
	scenery.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.size = Vector2(1440,900)
	scenery.texture = map_art
	scenery.stretch_mode = TextureRect.STRETCH_SCALE
	river_material.shader = preload("res://River.gdshader")
	scenery.material = river_material
	add_child(scenery)
	add_child(audio)
	add_child(music)
	for stream in music_streams.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length()*stream.mix_rate)
	audio.volume_db = -14
	load_progress()
	map_player_position = map_token_positions[unlocked]
	if class_id == "": modal = "class"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
			test_mode = true
		if arg.begins_with("--battle="):
			test_mode = true
			start_fight(int(arg.trim_prefix("--battle=")))
	if not screenshot_path.is_empty(): capture_later()
	update_music()
	get_window().title = "The Hex Game"
	if not test_mode: get_window().mode = Window.MODE_MAXIMIZED

func capture_later():
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("Saved screenshot: "+screenshot_path)
	get_tree().quit()

func load_progress():
	var cfg = ConfigFile.new()
	if cfg.load(save_file) == OK:
		unlocked = clampi(int(cfg.get_value("run","unlocked",0)),0,5)
		sound_on = bool(cfg.get_value("settings","sound",true))
		music_on = bool(cfg.get_value("settings","music",true))
		# Legacy campaigns retain their progress as the original Water/Light class.
		class_id = str(cfg.get_value("run","class","tide"))
		if not R.classes().any(func(c): return c.id==class_id): class_id="tide"
		campaign_deck = R.class_data(class_id).deck.duplicate()
		if not cfg.has_section_key("run","class"): campaign_deck={"W":12,"L":8}
		var stored = cfg.get_value("run","deck",{})
		if stored is Dictionary and not stored.is_empty():
			var valid = true
			var total = 0
			for e in stored:
				if not R.NAMES.has(e) or not (stored[e] is int) or stored[e]<1 or stored[e]>25:
					valid = false
					break
				total += stored[e]
			if valid and total>=20 and total<=25: campaign_deck=stored.duplicate()

func save_progress():
	if test_mode: return
	var cfg = ConfigFile.new()
	cfg.set_value("run","unlocked",unlocked)
	cfg.set_value("run","class",class_id)
	cfg.set_value("run","deck",campaign_deck)
	cfg.set_value("settings","sound",sound_on)
	cfg.set_value("settings","music",music_on)
	var temporary = save_file+".tmp"
	if cfg.save(temporary)==OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_file))

func _process(delta):
	elapsed += delta
	river_material.set_shader_parameter("flow_time",elapsed)
	scenery.texture = clearing_art if screen == "battle" else map_art
	if modal == "": update_map_walk(delta)
	if modal != "":
		queue_redraw()
		return
	hit_time = maxf(0.0,hit_time-delta)
	for slot in slot_impacts.keys():
		slot_impacts[slot] += delta
		if slot_impacts[slot] > 0.65: slot_impacts.erase(slot)
	if not cast_fx.is_empty():
		cast_fx.time += delta
		if cast_fx.time > 1.0: cast_fx.clear()
	flash = maxf(0,flash-delta*1.6)
	toast_time = maxf(0,toast_time-delta)
	mouse = get_local_mouse_position()
	if drag_source != "" and mouse.distance_to(press_mouse) > 7: dragging = true
	queue_redraw()

func _draw():
	regions.clear()
	card_rects.clear()
	card_indices.clear()
	if screen == "battle" and battle != null: draw_battle()
	else: draw_map()
	if dragging: draw_drag()
	if toast_time > 0 and modal == "":
		var w = minf(800,body_font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+46)
		panel(Rect2(720-w/2,18,w,42),INK,INK,12)
		center_text(toast,Rect2(720-w/2,18,w,42),15,PAPER)
	if modal != "": draw_modal()

func text_at(value, pos, px=16, color=INK, serif=false):
	draw_string(title_font if serif else body_font,pos,str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func center_text(value,rect,px=16,color=INK,serif=false):
	var font = title_font if serif else body_font
	var measured = font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,px)
	text_at(value,Vector2(rect.position.x+(rect.size.x-measured.x)/2,rect.position.y+(rect.size.y+font.get_ascent(px)-font.get_descent(px))/2),px,color,serif)

func line(a,b,color=LINE,width=1.0): draw_line(a,b,color,width,true)

func panel(rect,fill=Color("fffcf4"),stroke=LINE,radius=12.0):
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style,rect)

func button(rect,label,id,primary=false,enabled=true):
	var hovering = rect.has_point(mouse) and modal == ""
	var fill = TEAL if primary else Color("fffbf0")
	if hovering and enabled: fill = Color("205b61") if primary else Color("efe5cd")
	if not enabled: fill = Color("e6e2d7")
	panel(rect,fill,TEAL if primary and enabled else LINE,8)
	center_text(label,rect,15,PAPER if primary and enabled else (INK if enabled else MUTE))
	regions.append({"rect":rect,"id":id,"enabled":enabled})

func hex_points(center,radius):
	var points = PackedVector2Array()
	for i in range(6): points.append(center+Vector2.from_angle(-PI/2+i*PI/3)*radius)
	return points

func outline_hex(center,radius,color,width=2.0):
	var points = hex_points(center,radius)
	points.append(points[0])
	draw_polyline(points,color,width,true)

func textured_hex(tex,region,center,radius,alpha=1.0):
	var points = hex_points(center,radius)
	var uv = PackedVector2Array()
	var width = sqrt(3)*radius
	for p in points:
		var local = Vector2((p.x-center.x+width/2)/width,(p.y-center.y+radius)/(radius*2))
		uv.append((region.position+local*region.size)/Vector2(tex.get_width(),tex.get_height()))
	draw_polygon(points,PackedColorArray([Color(1,1,1,alpha)]),uv,tex)

func token(element,center,radius,alpha=1.0):
	if not TOKEN_REGIONS.has(element):
		draw_colored_polygon(hex_points(center,radius),Color(0.85,0.79,0.63,alpha))
		center_text("?",Rect2(center-Vector2(radius,radius),Vector2(radius*2,radius*2)),int(radius),INK,true)
		return
	textured_hex(elements,TOKEN_REGIONS[element],center,radius,alpha)

func portrait(id,center,radius,alpha=1.0,mood=""):
	var original_center = center
	if mood == "hit": center += Vector2(sin(elapsed*75)*hit_time*18,0)
	if mood == "victorious": center.y -= abs(sin(elapsed*3))*3
	if mood == "defeated":
		alpha *= 0.38
		center.y += radius*0.08
	var source = dragon_art if id == "dragon" else (characters if id in ["bat","goblin","elf"] else enemies_art)
	draw_colored_polygon(hex_points(center+Vector2(0,5),radius+3),Color(0.22,0.20,0.13,0.10))
	textured_hex(source,PORTRAIT_REGIONS[id],center,radius,alpha)
	outline_hex(center,radius,INK,2)
	if mood == "defeated":
		draw_colored_polygon(hex_points(center,radius),Color(0.20,0.29,0.32,0.20))
		for i in range(3):
			var a = elapsed*1.3+i*TAU/3
			star(original_center+Vector2(cos(a)*radius*0.52,-radius*0.57+sin(a)*radius*0.13),radius*0.095,GOLD)
	if mood == "victorious":
		outline_hex(center,radius+6,Color(GOLD,0.6+sin(elapsed*3)*0.2),3)
		for i in range(6):
			var a = elapsed*0.35+i*TAU/6
			star(center+Vector2.from_angle(a)*(radius+13),3+sin(elapsed*3+i)*1.5,GOLD)

func star(p,radius,color):
	if radius < 1.0 or color.a <= 0.01: return
	var pts = PackedVector2Array()
	for i in range(8): pts.append(p+Vector2.from_angle(i*PI/4)* (radius if i%2 == 0 else radius*0.3))
	draw_colored_polygon(pts,color)

func tree(p,s):
	draw_rect(Rect2(p.x-3*s,p.y,6*s,26*s),Color("8d8161"))
	for i in range(3):
		var y = p.y-i*15*s
		draw_colored_polygon(PackedVector2Array([Vector2(p.x-23*s,y+10*s),Vector2(p.x,y-40*s),Vector2(p.x+23*s,y+10*s)]),Color("8b9875") if i%2==0 else Color("a2ac8c"))

func rock(p,s):
	var pts = PackedVector2Array([p+Vector2(-25,9)*s,p+Vector2(-18,-20)*s,p+Vector2(1,-35)*s,p+Vector2(21,-23)*s,p+Vector2(30,11)*s])
	draw_colored_polygon(pts,Color("bbb39d"))
	line(p+Vector2(1,-35)*s,p+Vector2(-2,9)*s,Color("a39c88"),2)

func draw_map():
	for i in range(5):
		var p = MAP_NODES[i]
		var e = R.encounters()[i]
		var current = i == unlocked
		var done = i < unlocked
		# Opaque backing keeps the painted route below the encounter tile, even on victory.
		draw_colored_polygon(hex_points(p,65),INK)
		portrait(e.portrait,p,61,1.0 if i <= unlocked else 0.78,"defeated" if done else "")
		outline_hex(p,65,GOLD if current or done else Color("938764"),3)
		if current: outline_hex(p,70,Color(GOLD,0.6+sin(elapsed*2)*0.2),2)
		var badge = p+Vector2(39,-51)
		draw_circle(badge,16,INK)
		draw_circle(badge,14,GREEN if done else PAPER)
		center_text("✓" if done else str(i+1),Rect2(badge-Vector2(15,15),Vector2(30,30)),17,PAPER if done else INK)
		var label_width = title_font.get_string_size(e.name,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x+24
		var label = Rect2(p.x-label_width/2,p.y+70,label_width,32)
		# A small paper wash gives the names contrast over the path and grass.
		panel(label,Color(0.97,0.94,0.85,0.90),Color.TRANSPARENT,9)
		center_text(e.name,label,25,INK,true)
		regions.append({"rect":Rect2(p-Vector2(69,69),Vector2(138,176)),"id":"fight:"+str(i),"enabled":current and not map_walking})
	portrait("elf",map_player_position,39)
	outline_hex(map_player_position,44,GOLD,3)
	# A completed tutorial stays on the map; Escape provides the restart action.

func begin_map_walk(index):
	if class_id == "":
		modal="class"
		return
	if map_walking or index != unlocked or index >= 5: return
	map_walk_points = PackedVector2Array([map_player_position])
	# The one river crossing follows the actual illustrated bridge.
	if index == 2:
		map_walk_points.append_array(PackedVector2Array([Vector2(639,392),Vector2(686,420),Vector2(724,448)]))
	map_walk_points.append(MAP_NODES[index])
	map_walk_distance = 0.0
	map_walk_target = index
	map_walking = true
	ping("click")

func update_map_walk(delta):
	if not map_walking or screen != "map": return
	map_walk_distance += delta*240.0
	var distance = map_walk_distance
	for i in range(1,map_walk_points.size()):
		var length = map_walk_points[i-1].distance_to(map_walk_points[i])
		if distance < length:
			map_player_position = map_walk_points[i-1].lerp(map_walk_points[i],distance/length)
			return
		distance -= length
	map_walking = false
	start_fight(map_walk_target)

func board_centers(origin=BOARD_ORIGIN,spacing=BOARD_SPACING):
	var result = [origin]
	for i in range(6): result.append(origin+Vector2.from_angle(-PI/3+i*PI/3)*spacing)
	return result

func hp_bar(actor,rect,who):
	panel(rect,INK,INK,9)
	var inner = rect.grow(-3)
	panel(inner,PAPER,PAPER,6)
	var track = inner.grow(-3)
	panel(track,Color("555e57"),Color.TRANSPARENT,4)
	var width = track.size.x*clampf(float(actor.hp)/actor.max_hp,0,1)
	if width > 0: panel(Rect2(track.position,Vector2(width,track.size.y)),RED if who == "enemy" else TEAL,Color.TRANSPARENT,4)
	center_text("%d / %d" % [actor.hp,actor.max_hp],rect,16,PAPER)

func cast_star(p,radius,lit):
	var pts = PackedVector2Array()
	for i in range(10): pts.append(p+Vector2.from_angle(-PI/2+i*PI/5)*(radius if i%2==0 else radius*0.44))
	draw_colored_polygon(pts,GOLD if lit else Color("59625e"))
	pts.append(pts[0])
	draw_polyline(pts,INK,1.3,true)
	if lit: star(p,radius*0.5,PAPER)

func actor_tile(id,center,actor,who,casts_left,capacity,mood):
	portrait(id,center,BOARD_RADIUS,1.0,mood)
	outline_hex(center,BOARD_RADIUS,INK,3)
	outline_hex(center,BOARD_RADIUS-4,GOLD if who=="player" else Color("947c59"),1.5)
	for i in range(capacity):
		cast_star(center+Vector2((i-(capacity-1)/2.0)*27,BOARD_RADIUS*0.68),13,i<casts_left)
	var width = sqrt(3)*BOARD_RADIUS+8
	hp_bar(actor,Rect2(center.x-width/2,center.y+BOARD_RADIUS+2,width,29),who)

func draw_battle():
	var foe = R.encounters()[battle.stage]
	var player_turn = battle.phase == "player"
	var points = board_centers()
	var ghost = preview_pattern()
	var ready = battle.ready_spell()
	var aura = spell_color(ready) if not ready.is_empty() else TEAL
	for i in range(7):
		var p = points[i]
		draw_colored_polygon(hex_points(p,BOARD_RADIUS),Color("fff9e9"))
		outline_hex(p,BOARD_RADIUS,GOLD if i==0 else Color("65734e"),3)
		var placed = battle.board[i] if player_turn else (enemy_board[i] if enemy_board.size()==7 else "")
		if placed != "":
			var age = maxf(0.0,slot_impacts.get(i,1.0))
			var scale_gem = 1.0
			var drop = 0.0
			if age < 0.32:
				var land = clampf(age/0.32,0.0,1.0)
				drop = -20.0*pow(1.0-land,3)
				scale_gem = 1.0+0.12*exp(-land*4)*cos(land*TAU*1.5)
			if not ready.is_empty(): outline_hex(p,BOARD_RADIUS-3,Color(aura,0.65+sin(elapsed*3)*0.12),3)
			if age < 0.55: outline_hex(p,BOARD_RADIUS-6+age*16,Color(R.COLORS[placed],maxf(0,0.5-age)),2)
			token(placed,p+Vector2(0,drop),53*scale_gem)
		elif ghost.size()==7 and ghost[i] != "" and player_turn:
			token(ghost[i],p,49,0.20)
		elif i == 0: star(p,7,Color("d5c7a9"))
		if player_turn and slot_at(mouse)==i and selected_card>=0: outline_hex(p,BOARD_RADIUS,TEAL,4)
		if flash>0: outline_hex(p,BOARD_RADIUS,Color(flash_color,flash*0.5),3)
	# A readable link between a spell's core and its ingredients.
	if not ready.is_empty() and battle.board[0]!="":
		for i in range(1,7):
			if battle.board[i]=="": continue
			var a = points[0].lerp(points[i],0.40)
			var z = points[0].lerp(points[i],0.60)
			line(a,z,Color(aura,0.8),2)
			star((a+z)/2,4,aura)
	var enemy_left = battle.enemy_casts if battle.phase=="enemy" else (foe.casts if player_turn else 0)
	actor_tile(foe.portrait,ENEMY_CENTER,battle.enemy,"enemy",enemy_left,foe.casts,"defeated" if battle.phase=="won" else ("hit" if portrait_hit=="enemy" and hit_time>0 else ""))
	actor_tile("elf",PLAYER_CENTER,battle.player,"player",battle.casts if player_turn else 0,2,"victorious" if battle.phase=="won" else ("defeated" if battle.phase=="lost" else ("hit" if portrait_hit=="player" and hit_time>0 else "")))
	draw_spell_panel()
	draw_class_mechanic()
	draw_hand()
	draw_cast_effect()

func learned_spells():
	if battle != null and screen == "battle": return battle.learned
	var result = []
	for s in R.player_spells(class_id,campaign_deck):
		if s.unlock <= mini(unlocked,4): result.append(s)
	return result

func preview_spell():
	var id = last_hover_id if last_hover_id != "" else preview_id
	for s in learned_spells():
		if s.id == id: return s
	return {}

func preview_pattern():
	if screen != "battle" or battle.phase != "player": return []
	var s = preview_spell()
	if s.is_empty(): return []
	var fit = R.best_fit(battle.board,s)
	return fit if not fit.is_empty() else s.pattern

func mini_pattern(pattern,origin,radius=8.0):
	var centers = board_centers(origin,sqrt(3)*(radius+1))
	for i in range(7):
		var element = pattern[i]
		draw_colored_polygon(hex_points(centers[i],radius),R.COLORS.get(element,Color("d5c6a8")) if element != "" else Color("f0eadb"))
		outline_hex(centers[i],radius,Color("c9c4b3"),0.7)
		if element == "*": center_text("•",Rect2(centers[i]-Vector2(radius,radius),Vector2(radius*2,radius*2)),12,INK)

func visible_spells():
	if battle==null: return []
	var cards=battle.available_cards()
	return battle.learned.filter(func(recipe):
		if spell_filter=="ready": return battle.cast_allowed(recipe) and R.can_make(cards,recipe)
		if spell_filter=="match": return not R.best_fit(battle.board,recipe).is_empty()
		if spell_filter=="weaves": return recipe.get("weave",false)
		return true)

func book_spells():
	var recipes=R.rune_catalog(class_id) if book_scope=="all" else R.player_spells(class_id,campaign_deck)
	if book_element!="": recipes=recipes.filter(func(recipe): return book_element in recipe.pattern)
	return recipes

func draw_spell_panel():
	panel(Rect2(1005,57,401,797),PAPER,INK,15)
	text_at("Known spells",Vector2(1031,106),35,INK,true)
	line(Vector2(1029,129),Vector2(1382,129),LINE,2)
	last_hover_id = ""
	var cards = battle.available_cards()
	var visible=visible_spells()
	var filters=[["all","All"],["ready","Ready"],["match","Match"],["weaves","Weaves"]]
	for i in range(filters.size()): button(Rect2(1027+i*89,134,83,27),filters[i][1],"filter:"+filters[i][0],spell_filter==filters[i][0])
	spell_page=clampi(spell_page,0,maxi(0,int((visible.size()-1)/9)))
	for i in range(mini(9,visible.size()-spell_page*9)):
		var s=visible[i+spell_page*9]
		var row=Rect2(1024,173+i*53,362,49)
		var exact=battle.ready_spell().get("id","")==s.id
		var available=R.can_make(cards,s) and battle.cast_allowed(s)
		var selected=preview_id==s.id or row.has_point(mouse)
		if row.has_point(mouse): last_hover_id=s.id
		if selected or exact: panel(row,Color("dbe7df"),GOLD if exact else Color.TRANSPARENT,8)
		mini_pattern(s.pattern,Vector2(1056,row.get_center().y),7.8)
		text_at(s.name,Vector2(1093,row.get_center().y-1),24,INK if available else MUTE,true)
		text_at(battle.spell_text(s),Vector2(1094,row.get_center().y+18),11,MUTE)
		panel(Rect2(1346,row.get_center().y-15,27,30),TEAL if available else Color("e4decd"),Color.TRANSPARENT,5)
		center_text(str(i+1),Rect2(1346,row.get_center().y-15,27,30),14,PAPER if available else MUTE)
		regions.append({"rect":row,"id":"recipe:"+s.id,"enabled":battle.phase=="player" and not animation_running})
	if visible.is_empty(): center_text("No matching spells",Rect2(1030,210,352,40),21,MUTE,true)
	button(Rect2(1030,664,42,30),"‹","spells_prev",false,spell_page>0)
	center_text("%d spells · %d / %d" % [visible.size(),spell_page+1,maxi(1,int(ceil(visible.size()/9.0)))],Rect2(1080,664,235,30),12,MUTE)
	button(Rect2(1340,664,42,30),"›","spells_next",false,(spell_page+1)*9<visible.size())

	line(Vector2(1029,704),Vector2(1382,704),LINE,2)
	battle_button(Rect2(1026,719,358,53),"Cast","Enter","cast",true,battle.cast_allowed(battle.ready_spell()) and not animation_running)
	battle_button(Rect2(1026,787,358,49),"End turn","E","end",false,battle.phase=="player" and not animation_running)

func battle_button(rect,label,key_name,id,primary,enabled):
	button(rect,"",id,primary,enabled)
	center_text(label,Rect2(rect.position,Vector2(rect.size.x-85,rect.size.y)),29,PAPER if primary and enabled else (INK if enabled else MUTE),true)
	var key_rect = Rect2(rect.end.x-78,rect.position.y+10,62,rect.size.y-20)
	panel(key_rect,Color("e9e2cf"),Color.TRANSPARENT,5)
	center_text(key_name,key_rect,14,INK if enabled else MUTE)

func hand_layout(count):
	# Draw effects can grow the hand; compress spacing rather than clipping off-screen.
	var width = minf(105.0,820.0/maxi(count,1)-8.0)
	var gap = 8.0
	var total = count*width+maxi(0,count-1)*gap
	return Vector3(530-total/2,width,gap)

func draw_hand():
	draw_piles()
	if battle.phase in ["won","lost"]: return
	var hand = battle.player.hand if battle.phase=="player" else ["","","","",""]
	hand_offset = clampi(hand_offset,0,maxi(0,hand.size()-8))
	var shown = mini(8,hand.size()-hand_offset)
	var layout = hand_layout(shown)
	for visible_index in range(shown):
		var i = visible_index+hand_offset
		var rect = Rect2(layout.x+visible_index*(layout.y+layout.z),785,layout.y,105)
		if battle.phase=="player" and (selected_card==i or rect.has_point(mouse)):
			rect.position.y -= 5
		if battle.phase=="player":
			card_rects.append(rect)
			card_indices.append(i)
		panel(rect,PAPER if battle.phase=="player" else TEAL,GOLD if selected_card==i else INK,7)
		if battle.phase!="player":
			star(rect.get_center(),12,GOLD)
			continue
		line(rect.position+Vector2(9,7),rect.position+Vector2(layout.y-9,7),R.COLORS[hand[i]],4)
		token(hand[i],rect.position+Vector2(layout.y/2,47),minf(34,layout.y*0.40))
		center_text(R.NAMES[hand[i]].to_upper(),Rect2(rect.position+Vector2(0,84),Vector2(layout.y,18)),11 if layout.y>=65 else 9,INK)

	if hand.size()>8:
		button(Rect2(52,813,42,44),"‹","hand_prev",false,hand_offset>0)
		button(Rect2(964,813,34,44),"›","hand_next",false,hand_offset+8<hand.size())

func draw_class_mechanic():
	var rect=Rect2(135,543,228,110)
	panel(rect,PAPER,LINE,10)
	var title=""
	var first=""
	var second=""
	if class_id=="tide":
		title="Tide  %d / 3" % battle.tide
		first="Water builds · Light spends"
		second="Light: +%d power / +%d draw" % [battle.tide*2,battle.tide]
	elif class_id=="pyro":
		title="Heat  %d / 6" % battle.heat
		first="Fire: +%d damage%s" % [battle.heat," · −2 HP" if battle.heat>=4 else ""]
		second="Air vents: +%d HP" % battle.heat
	else:
		title="Blood Price"
		first="Blood spends HP for power"
		second="Dark steals life on hit"
	text_at(title,rect.position+Vector2(15,30),25,INK,true)
	text_at(first,rect.position+Vector2(15,61),12,MUTE)
	text_at(second,rect.position+Vector2(15,86),12,RED if class_id=="pyro" and battle.heat>=4 else TEAL)

func draw_piles():
	for i in range(2):
		var rect=Rect2(135+i*92,670,80,73)
		panel(rect,PAPER,LINE,8)
		center_text("Draw" if i==0 else "Discard",Rect2(rect.position+Vector2(0,4),Vector2(80,23)),12,MUTE)
		center_text(str(battle.player.pile.size() if i==0 else battle.player.discard.size()),Rect2(rect.position+Vector2(0,28),Vector2(80,35)),26,INK,true)

func draw_drag():
	if battle == null or battle.phase != "player": return
	var e = ""
	if drag_source == "hand" and drag_index < battle.player.hand.size(): e = battle.player.hand[drag_index]
	elif drag_source == "board" and drag_index >= 0: e = battle.board[drag_index]
	if e != "": token(e,mouse,43,0.9)

func start_fight(index):
	spell_filter="all"
	if class_id == "":
		modal="class"
		return
	fight_generation += 1
	map_walking = false
	battle = B.new(index,-1,campaign_deck,class_id)
	spell_page=0
	hand_offset=0
	screen = "battle"
	modal = ""
	preview_id = ""
	last_hover_id = ""
	selected_card = -1
	animation_running = false
	enemy_board = []
	impact = ""
	slot_impacts.clear()
	cast_fx.clear()
	outcome_pending = false
	update_music()

func notify(message):
	toast = message
	toast_time = 4.5

func apply_event(event):
	if event.is_empty(): return
	flash = 1.0
	flash_color = cast_fx.color if not cast_fx.is_empty() else (RED if event.effect=="damage" else (GREEN if event.effect=="heal" else TEAL))
	if not cast_fx.is_empty():
		cast_fx.amount = event.amount
		cast_fx.hp_cost=event.get("hp_cost",0)
		cast_fx.healed=event.get("healed",0)
	impact = ("−%d" % event.amount) if event.effect=="damage" else ("+%d" % event.amount)
	portrait_hit = ("enemy" if event.who=="You" else "player") if event.effect=="damage" else ""
	hit_time = 0.4
	ping(event.effect)
	if battle.phase in ["won","lost"] and not outcome_pending:
		outcome_pending = true
		show_outcome_later(fight_generation)

func show_outcome_later(generation):
	await battle_delay(0.95,generation)
	if generation != fight_generation or screen != "battle": return
	modal = "victory" if battle.phase=="won" else "defeat"
	if modal == "victory": ping("win")
	update_music()

func cast_action():
	if battle == null or animation_running or modal != "": return
	var s = battle.ready_spell()
	if not battle.cast_allowed(s): return
	begin_cast_effect(s,true,battle.board.duplicate())
	var event = battle.cast_player()
	if event.is_empty(): return
	animation_running = true
	drag_source = ""
	dragging = false
	selected_card = -1
	preview_id = ""
	last_hover_id = ""
	apply_event(event)
	var generation = fight_generation
	await battle_delay(0.85,generation)
	if generation != fight_generation: return
	animation_running = false
	if battle.phase == "player" and not battle.has_playable_spell(): run_enemy_turn()

func run_enemy_turn():
	if animation_running or battle == null or not battle.end_player_turn(): return
	animation_running = true
	drag_source = ""
	dragging = false
	selected_card = -1
	preview_id = ""
	var generation = fight_generation
	impact = ""
	enemy_spell = "Gathering elements…"
	await battle_delay(0.45,generation)
	if generation != fight_generation: return
	while battle.phase=="enemy" and battle.enemy_casts>0:
		var s = battle.plan_enemy()
		if s.is_empty(): break
		enemy_board = battle.enemy_layout(s)
		enemy_spell = s.name
		for i in range(7):
			if enemy_board[i] != "": slot_impacts[i] = -i*0.025
		ping("place")
		await battle_delay(0.70,generation)
		if generation != fight_generation: return
		begin_cast_effect(s,false,enemy_board.duplicate())
		apply_event(battle.cast_enemy(s))
		await battle_delay(0.90,generation)
		if generation != fight_generation: return
		enemy_board = []
		if battle.phase=="lost": break
	if battle.phase=="enemy": battle.next_round()
	enemy_board = []
	enemy_spell = ""
	animation_running = false
	if battle.phase=="player":
		impact = ""
		ping("place")

func accept_victory(gem=""):
	if battle == null or battle.phase!="won" or battle.stage!=unlocked: return false
	if gem!="" and not R.encounters()[battle.stage].deck.has(gem): return false
	if gem!="": campaign_deck[gem]=int(campaign_deck.get(gem,0))+1
	unlocked = battle.stage+1
	save_progress()
	modal = ""
	screen = "map"
	update_music()
	map_player_position = map_token_positions[unlocked]
	return true

func choose_class(id):
	if not R.classes().any(func(c): return c.id==id): return
	fight_generation+=1
	class_id=id
	campaign_deck=R.class_data(id).deck.duplicate()
	unlocked=0
	battle=null
	map_walking=false
	animation_running=false
	map_player_position=map_token_positions[0]
	screen="map"
	modal=""
	save_progress()
	update_music()

func activate(id):
	if id == "settings":
		modal = "" if modal == "settings" else "settings"
		drag_source = ""
		dragging = false
		return
	if id == "music":
		music_on = not music_on
		update_music()
		save_progress()
		return
	if id == "sound":
		sound_on = not sound_on
		if not sound_on: audio.stop()
		save_progress()
		return
	if id == "help": modal = "help"
	elif id == "book": modal = "book"
	elif id == "close": modal = ""
	elif id == "reset": modal = "reset"
	elif id == "confirm_reset": modal = "class"
	elif id.begins_with("class:"): choose_class(id.trim_prefix("class:"))
	elif id.begins_with("gem:"): accept_victory(id.trim_prefix("gem:"))
	elif id == "deck": modal="deck"
	elif id == "spells_prev": spell_page=maxi(0,spell_page-1)
	elif id == "spells_next": spell_page=mini(int((visible_spells().size()-1)/9),spell_page+1)
	elif id.begins_with("filter:"):
		spell_filter=id.trim_prefix("filter:")
		spell_page=0
	elif id.begins_with("book_scope:"):
		book_scope=id.trim_prefix("book_scope:")
		book_page=0
	elif id.begins_with("book_element:"):
		var element=id.trim_prefix("book_element:")
		book_element="" if book_element==element else element
		book_page=0
	elif id == "book_prev": book_page=maxi(0,book_page-1)
	elif id == "book_next": book_page+=1
	elif id == "hand_prev": hand_offset=maxi(0,hand_offset-8)
	elif id == "hand_next": hand_offset=mini(maxi(0,battle.player.hand.size()-8),hand_offset+8)
	elif id == "map":
		map_player_position = map_token_positions[unlocked]
		map_walking = false
		fight_generation += 1
		screen = "map"
		modal = ""
		animation_running = false
		update_music()
	elif id.begins_with("fight:"): begin_map_walk(int(id.trim_prefix("fight:")))
	elif id == "cast": cast_action()
	elif id == "clear":
		battle.clear_board()
		selected_card = -1
	elif id == "end": run_enemy_turn()
	elif id.begins_with("recipe:"):
		fill_spell(id.trim_prefix("recipe:"))
		return
	elif id == "arrange":
		fill_spell(preview_id)
		return
	elif id == "reward": accept_victory()
	elif id == "retry": start_fight(battle.stage)
	ping("click")

func slot_at(pos):
	var centers = board_centers()
	for i in range(7):
		if Geometry2D.is_point_in_polygon(pos,hex_points(centers[i],BOARD_RADIUS)): return i
	return -1

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if modal in ["victory","defeat"] or (modal=="class" and class_id==""): return
			modal = "" if modal != "" else "settings"
			drag_source = ""
			dragging = false
			return
		if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and modal in ["victory","defeat"]:
			if modal=="defeat": activate("retry")
			return
		if modal != "": return
		if event.keycode==KEY_H: modal = "help"
		if event.keycode==KEY_B: modal = "book"
		if screen=="map" and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and unlocked<5:
			begin_map_walk(unlocked)
			return
		if screen=="battle" and battle.phase=="player" and not animation_running:
			if event.keycode in [KEY_UP,KEY_DOWN]:
				var index = -1
				for i in range(battle.learned.size()):
					if battle.learned[i].id == preview_id: index = i
				index = posmod(index+(1 if event.keycode==KEY_DOWN else -1),battle.learned.size())
				fill_spell(battle.learned[index].id)
			if event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]: cast_action()
			if event.keycode==KEY_E: run_enemy_turn()
			if event.keycode in [KEY_BACKSPACE,KEY_DELETE]: activate("clear")
			if event.keycode==KEY_A: activate("arrange")
			if event.keycode>=KEY_1 and event.keycode<=KEY_9:
				var i = event.keycode-KEY_1
				var visible=visible_spells()
				if i+spell_page*9 < visible.size(): fill_spell(visible[i+spell_page*9].id)
	if not event is InputEventMouseButton: return
	var pos = make_input_local(event).position
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if screen=="battle" and modal=="" and battle.phase=="player" and not animation_running:
			var slot = slot_at(pos)
			if slot>=0: battle.take_back(slot)
			selected_card = -1
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if event.pressed:
		for region in regions.duplicate():
			if region.rect.has_point(pos) and region.enabled:
				activate(region.id)
				return
		if modal == "settings":
			if not SETTINGS_RECT.has_point(pos): modal = ""
			return
		if modal != "" or screen != "battle" or battle.phase != "player" or battle.casts<=0 or animation_running: return
		press_mouse = pos
		dragging = false
		for i in range(card_rects.size()):
			if card_rects[i].has_point(pos):
				drag_source = "hand"
				drag_index = card_indices[i]
				selected_card = card_indices[i]
				return
		var slot = slot_at(pos)
		if slot>=0:
			if selected_card >= 0:
				if battle.place(selected_card,slot): land_gem(slot)
				selected_card = -1
			elif battle.board[slot] != "":
				drag_source = "board"
				drag_index = slot
	else:
		if modal != "" or screen != "battle" or battle.phase != "player":
			drag_source = ""
			return
		var slot = slot_at(pos)
		if drag_source == "hand" and dragging and slot>=0:
			if battle.place(drag_index,slot): land_gem(slot)
			selected_card = -1
		elif drag_source == "board":
			if dragging and slot>=0:
				battle.swap_slots(drag_index,slot)
				land_gem(slot)
			else: battle.take_back(drag_index)
			ping("place")
		drag_source = ""
		drag_index = -1
		dragging = false

func missing_gems(s):
	var need={}
	for e in s.pattern:
		if e!="" and e!="*": need[e]=need.get(e,0)+1
	var names=[]
	for e in need:
		var missing=need[e]-campaign_deck.get(e,0)
		if missing>0: names.append(R.NAMES[e]+" ×"+str(missing))
	return "Need "+", ".join(names)

func spellbook_effect(s):
	var label=R.effect_text(s)
	if s.get("school","")!="": label=R.NAMES[s.school]+" · "+label
	if s.get("hp_cost",0)>0: label+=" · −%d HP" % s.hp_cost
	if s.get("leech",0)>0: label+=" · Steal "+("all" if s.leech==1.0 else "half")
	return label

func draw_modal():
	regions.clear()
	draw_rect(Rect2(0,0,1440,900),Color(0.08,0.16,0.17,0.72))
	if modal == "class":
		panel(Rect2(144,140,1152,615),PAPER,GOLD,18)
		center_text("Choose your class",Rect2(220,164,1000,62),46,INK,true)
		for i in range(3):
			var c=R.classes()[i]
			var rect=Rect2(177+i*369,262,348,440)
			panel(rect,Color("fffaf0"),LINE,12)
			token(c.elements[0],rect.position+Vector2(122,103),52)
			token(c.elements[1],rect.position+Vector2(226,103),52)
			center_text(c.name,Rect2(rect.position+Vector2(10,178),Vector2(328,48)),34,INK,true)
			center_text(c.role,Rect2(rect.position+Vector2(10,222),Vector2(328,28)),14,TEAL)
			center_text(str(c.deck[c.elements[0]])+" "+R.NAMES[c.elements[0]]+"  ·  "+str(c.deck[c.elements[1]])+" "+R.NAMES[c.elements[1]]+"  ·  "+str(c.hp)+" HP",Rect2(rect.position+Vector2(10,254),Vector2(328,26)),14,MUTE)
			for n in range(3): center_text(c.lines[n],Rect2(rect.position+Vector2(10,286+n*21),Vector2(328,23)),12,INK)
			button(Rect2(rect.position+Vector2(31,357),Vector2(286,49)),"Choose "+c.name,"class:"+c.id,true)
	elif modal == "settings":
		panel(SETTINGS_RECT,PAPER,GOLD,16)
		center_text("Settings",Rect2(540,180,360,52),37,INK,true)
		button(Rect2(540,245,360,43),"Music  ·  "+("On" if music_on else "Off"),"music")
		button(Rect2(540,297,360,43),"Sound effects  ·  "+("On" if sound_on else "Off"),"sound")
		button(Rect2(540,349,360,43),"Your deck","deck")
		button(Rect2(540,401,360,43),"Spellbook","book")
		button(Rect2(540,453,360,43),"How to play","help")
		button(Rect2(540,505,360,43),"Return to map" if screen=="battle" else "Begin a new journey","map" if screen=="battle" else "reset")
		button(Rect2(540,557,360,43),"Done     Esc","close",true)
		center_text("Unused cards stay in your hand.",Rect2(537,621,366,26),13,MUTE)
		center_text("Reshuffle only when the draw pile is empty.",Rect2(537,653,366,26),12,MUTE)
	elif modal == "deck":
		panel(Rect2(230,205,980,480),PAPER,GOLD,18)
		center_text(R.class_data(class_id).name+" · Deck",Rect2(260,226,920,60),40,INK,true)
		var index=0
		var total=0
		for e in R.NAMES:
			if not campaign_deck.has(e): continue
			var x=720+(index-(campaign_deck.size()-1)/2.0)*125
			token(e,Vector2(x,383),45)
			center_text(str(campaign_deck[e])+" "+R.NAMES[e],Rect2(x-60,450,120,28),16,INK)
			total+=campaign_deck[e]
			index+=1
		center_text(str(total)+" gems · Draw five each turn",Rect2(310,516,820,30),18,MUTE)
		button(Rect2(570,595,300,47),"Back","close",true)
	elif modal == "book":
		panel(Rect2(160,84,1120,744),PAPER,GOLD,18)
		text_at(R.class_data(class_id).name+" spellbook",Vector2(270,137),42,INK,true)
		button(Rect2(184,164,112,28),"My deck","book_scope:deck",book_scope=="deck")
		button(Rect2(306,164,112,28),"All runes","book_scope:all",book_scope=="all")
		var element_index=0
		for e in R.NAMES:
			button(Rect2(438+element_index*113,164,103,28),R.NAMES[e],"book_element:"+e,book_element==e)
			element_index+=1
		var all_spells=book_spells()
		var level = battle.stage if screen=="battle" and battle != null else mini(unlocked,4)
		book_page=clampi(book_page,0,int((all_spells.size()-1)/9))
		for i in range(mini(9,all_spells.size()-book_page*9)):
			var s = all_spells[i+book_page*9]
			var rect = Rect2(184+(i%3)*363,216+int(i/3)*177,347,159)
			var in_deck=R.can_make(R.deck_cards(campaign_deck),s)
			var learned=s.unlock<=level and in_deck
			panel(rect,Color("fffaf0") if learned else Color("e9e4d8"),LINE,10)
			mini_pattern(s.pattern,rect.position+Vector2(50,55),12)
			text_at(s.name,rect.position+Vector2(93,32),24,INK if learned else MUTE,true)
			text_at(spellbook_effect(s),rect.position+Vector2(93,55),12,GOLD if learned else MUTE)
			if not learned:
				text_at("After fight "+str(s.unlock) if s.unlock>level else missing_gems(s),rect.position+Vector2(20,113),11,MUTE)
			if learned:
				var desc = s.detail
				if desc.length()>34:
					var cut = desc.rfind(" ",33)
					text_at(desc.substr(0,cut),rect.position+Vector2(20,113),11,MUTE)
					text_at(desc.substr(cut+1),rect.position+Vector2(20,133),11,MUTE)
				else: text_at(desc,rect.position+Vector2(20,113),11,MUTE)
		center_text("%d patterns · %d / %d" % [all_spells.size(),book_page+1,maxi(1,int(ceil(all_spells.size()/9.0)))],Rect2(400,761,400,43),14,MUTE)
		if all_spells.size()>9:
			button(Rect2(190,761,75,43),"‹","book_prev",false,book_page>0)
			button(Rect2(280,761,75,43),"›","book_next",false,(book_page+1)*9<all_spells.size())
		button(Rect2(983,761,182,43),"Back to the journey","close",true)
	elif modal == "help":
		panel(Rect2(358,123,724,649),PAPER,GOLD,18)
		text_at("A little guide to spellcraft",Vector2(400,186),43,INK,true)
		var rows = [
			["1", "Draw five. Keep what you do not cast.", "Only spent gems go to the discard pile."],
			["2", "Choose a spell. Watch the gems settle.", "Click its row or press 1–9. Enter casts. You can also drag cards."],
			["3", "Work through your deck.", "Only an empty draw pile triggers a discard reshuffle."],
			["4", "Mix attacks, healing, and fresh cards.", "Pulse spends both casts. Drawing first can build a stronger finish."],
			["5", "Choose your rewards.", "After each victory, add one enemy gem or skip it."]
		]
		for i in range(rows.size()):
			var y = 229+i*83
			draw_circle(Vector2(420,y+9),18,TEAL)
			center_text(rows[i][0],Rect2(402,y-9,36,36),17,PAPER)
			text_at(rows[i][1],Vector2(456,y+7),25,INK,true)
			text_at(rows[i][2],Vector2(456,y+34),12,MUTE)
		text_at("1–9 fill spell · ENTER cast · E end turn · BACKSPACE clear",Vector2(401,682),12,MUTE)
		button(Rect2(830,706,204,42),"Let's play","close",true)
	elif modal == "victory":
		panel(Rect2(290,130,860,650),PAPER,GOLD,18)
		center_text(R.encounters()[battle.stage].name+" defeated",Rect2(340,160,760,61),44,INK,true)
		center_text("Add one gem to your deck?",Rect2(340,237,760,38),28,INK,true)
		var choices=R.encounters()[battle.stage].deck.keys()
		for i in range(choices.size()):
			var e=choices[i]
			var x=720+(i-(choices.size()-1)/2.0)*230
			var rect=Rect2(x-105,307,210,285)
			panel(rect,Color("fffaf0"),LINE,12)
			token(e,Vector2(x,382),48)
			center_text(R.NAMES[e],Rect2(x-98,443,196,32),27,INK,true)
			var new_patterns=R.reward_spells(class_id,campaign_deck,e,mini(4,battle.stage+1))
			center_text("+%d new patterns" % new_patterns.size(),Rect2(x-100,475,200,23),13,TEAL)
			var examples=new_patterns.filter(func(recipe): return recipe.get("weave",false))
			for n in range(mini(2,examples.size())): center_text(examples[n].name,Rect2(x-100,499+n*17,200,19),11,MUTE)
			if new_patterns.is_empty(): center_text("More copies for your patterns",Rect2(x-100,499,200,24),11,MUTE)
			button(Rect2(x-87,536,174,39),"Add "+R.NAMES[e],"gem:"+e,true)
		if battle.stage<4:
			for learned in R.player_spells(class_id):
				if learned.id==R.encounters()[battle.stage].reward:
					center_text("New pattern: "+learned.name,Rect2(350,621,740,29),20,INK,true)
		else: center_text("The tutorial is complete.",Rect2(350,621,740,29),20,INK,true)
		button(Rect2(530,693,380,48),"Skip gem & continue","reward")
	elif modal == "defeat":
		panel(Rect2(410,215,620,440),PAPER,RED,18)
		portrait(R.encounters()[battle.stage].portrait,Vector2(720,310),65)
		center_text("The circle falls quiet",Rect2(450,410,540,54),40,INK,true)
		center_text("Your class and deck are safe.",Rect2(450,485,540,32),18,MUTE)
		button(Rect2(530,566,380,48),"Try again","retry",true)
	elif modal == "reset":
		panel(Rect2(430,300,580,290),PAPER,GOLD,18)
		center_text("Begin again?",Rect2(465,338,510,57),44,INK,true)
		center_text("Choose a class for a fresh campaign and starting deck.",Rect2(465,410,510,31),14,MUTE)
		button(Rect2(475,489,221,49),"Keep this journey","close")
		button(Rect2(718,489,247,49),"Start fresh","confirm_reset",true)

func ping(kind):
	if not sound_on or test_mode: return
	if not sounds.has(kind):
		var freq = {"click":420.0,"place":560.0,"damage":150.0,"heal":740.0,"draw":620.0,"win":880.0}.get(kind,420.0)
		var duration = 0.15 if kind=="place" else (0.7 if kind=="win" else (0.06 if kind=="click" else 0.32))
		var sample_rate = 22050
		var data = PackedByteArray()
		for i in range(int(duration*sample_rate)):
			var t = float(i)/sample_rate
			var envelope = sin(PI*t/duration)*exp(-t*12)
			var wave = sin(TAU*freq*t)+0.24*sin(TAU*freq*2*t)
			if kind=="place":
				wave = sin(TAU*(110*t+1.7*(1-exp(-t*32))))*exp(-t*15)+0.32*sin(TAU*1120*t)*exp(-t*60)
				envelope = minf(t/0.003,1.0)*minf((duration-t)/0.025,1.0)
			elif kind=="win":
				var notes = [587.33,739.99,880.0,1174.66]
				wave = sin(TAU*notes[mini(3,int(t/0.12))]*t)+0.25*sin(TAU*587.33*t)
				envelope = minf(t/0.012,1.0)*minf((duration-t)/0.15,1.0)*0.55
			var value = int(clampf(wave*envelope,-1,1)*10000)
			data.append(value & 255)
			data.append((value >> 8) & 255)
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = sample_rate
		stream.data = data
		sounds[kind] = stream
	audio.stream = sounds[kind]
	audio.play()

func spell_color(s):
	if s.is_empty(): return TEAL
	if s.effect == "heal": return Color("77b78e")
	if s.effect == "draw": return Color("929cdd")
	for element in s.pattern:
		if R.COLORS.has(element): return R.COLORS[element]
	return GOLD

func land_gem(slot):
	slot_impacts[slot] = 0.0
	ping("place")

func fill_spell(id):
	if battle == null or animation_running or battle.phase != "player": return
	preview_id = id
	drag_source = ""
	dragging = false
	last_hover_id = ""
	selected_card = -1
	for s in battle.learned:
		if s.id != id: continue
		var visible=visible_spells()
		if not visible.has(s):
			spell_filter="all"
			visible=visible_spells()
		spell_page=int(visible.find(s)/9)
		hand_offset=0
		if battle.arrange(s):
			for i in range(7):
				if battle.board[i] != "": slot_impacts[i] = -i*0.025
			ping("place")
		elif not battle.cast_allowed(s):
			notify(battle.cast_block_reason(s))
		else: notify("Not enough elements yet.")
		return

func begin_cast_effect(s,from_player,pattern):
	cast_fx = {"time":0.0,"effect":s.effect,"color":spell_color(s),"player":from_player,"pattern":pattern,"amount":s.amount}

func draw_cast_effect():
	if cast_fx.is_empty(): return
	var t = cast_fx.time
	var c = cast_fx.color
	var origin = BOARD_ORIGIN
	var target = ENEMY_CENTER if cast_fx.player else PLAYER_CENTER
	if cast_fx.effect == "heal": target = PLAYER_CENTER if cast_fx.player else ENEMY_CENTER
	if cast_fx.effect == "draw": target = Vector2(530,833)
	var centers = board_centers()
	# The laid pattern contracts into one spell before travelling to its target.
	if t < 0.26:
		var k = t/0.26
		for i in range(7):
			if cast_fx.pattern[i] == "": continue
			var p = centers[i].lerp(origin,k*k)
			outline_hex(p,73*(1-k*0.8),Color(c,1-k),3)
			star(p,10*(1-k),Color(c,1-k))
	if cast_fx.effect == "damage":
		var u = clampf((t-0.12)/0.43,0,1)
		var tip = origin.lerp(target,u)+Vector2(0,-sin(u*PI)*78)
		if t < 0.56:
			for i in range(10):
				var trail = maxf(0,u-i*0.024)
				var pos = origin.lerp(target,trail)+Vector2(0,-sin(trail*PI)*78)
				draw_circle(pos,18-i*1.4,Color(c,0.36-i*0.028))
			star(tip,18,Color("fff5c6"))
		if t > 0.45:
			var burst = (t-0.45)/0.55
			for i in range(12):
				var p = target+Vector2.from_angle(i*TAU/12)*(12+burst*85)
				star(p,7*(1-burst),Color(c,1-burst))
	elif cast_fx.effect == "heal":
		for i in range(9):
			var angle = i*TAU/9+t*2.5
			var p = target+Vector2(cos(angle)*55,sin(angle)*24-45*t)
			star(p,6,Color(c,sin(t*PI)))
		for i in range(3): draw_arc(target,30+t*45+i*8,0,TAU,48,Color(c,(1-t)*0.4),2,true)
	else:
		for i in range(mini(5,cast_fx.amount)):
			var u = clampf((t-i*0.06)/0.62,0,1)
			var p = origin.lerp(target+Vector2((i-2)*65,0),u)+Vector2(sin(u*PI)*55,0)
			var rect = Rect2(p-Vector2(16,24),Vector2(32,48))
			panel(rect,Color(c,0.8*(1-u)),Color(c,1-u),5)
			star(p,8,Color(PAPER,1-u))
	if t > 0.48:
		if cast_fx.player and (cast_fx.get("healed",0)>0 or cast_fx.get("hp_cost",0)>0):
			var secondary="+%d HP" % cast_fx.healed if cast_fx.get("healed",0)>0 else "−%d HP" % cast_fx.hp_cost
			center_text(secondary,Rect2(PLAYER_CENTER+Vector2(80,-30-(t-0.48)*40),Vector2(140,36)),23,Color(GREEN if cast_fx.get("healed",0)>0 else RED,(1-t)*1.9),true)
		var label = ("−" if cast_fx.effect=="damage" else "+")+str(cast_fx.amount)
		center_text(label,Rect2(target+Vector2(-55,-25-(t-0.48)*52),Vector2(110,50)),35,Color(c,(1-t)*1.9),true)

func update_music():
	if test_mode: return
	var desired = "map" if screen=="map" or modal=="victory" else ("boss" if battle != null and battle.stage==4 else "battle")
	if not music_on:
		if music_tween: music_tween.kill()
		music.stop()
		music_track = ""
		return
	if music_track == desired and music.playing: return
	music_track = desired
	if music_tween: music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music,"volume_db",-50.0,0.3)
	music_tween.tween_callback(func():
		music.stream = music_streams[desired]
		music.play())
	music_tween.tween_property(music,"volume_db",-19.0 if desired=="map" else -21.0,0.65)


func battle_delay(seconds,generation):
	var remaining = seconds
	while remaining>0 and generation==fight_generation:
		await get_tree().process_frame
		if modal == "": remaining -= get_process_delta_time()
