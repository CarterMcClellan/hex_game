extends SceneTree
const R = preload("res://Rules.gd")
const LogicTests = preload("res://Tests.gd")
var game
var checks = 0
var failed = false

func _initialize(): call_deferred("run")

func verify(ok,message):
	checks+=1
	if not ok:
		failed=true
		push_error("UI FAILED: "+message)

func key(code):
	var e=InputEventKey.new()
	e.keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	await process_frame
	e=e.duplicate()
	e.pressed=false
	Input.parse_input_event(e)
	await process_frame

func shortcut_spell(id):
	var visible=game.visible_spells()
	var index=-1
	for i in range(visible.size()):
		if visible[i].id==id: index=i
	verify(index>=0,"spell "+id+" is available for its shortcut")
	if index<0: return
	game.spell_page=int(index/game.spells_per_page())
	await key(KEY_1+index%game.spells_per_page())

func click_at(pos):
	for pressed in [true,false]:
		var e=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		e.position=root.get_stretch_transform()*game.get_global_transform_with_canvas()*pos
		e.global_position=e.position
		Input.parse_input_event(e)
		await process_frame

func capture(name):
	await process_frame
	await RenderingServer.frame_post_draw
	var destination=ProjectSettings.globalize_path("res://test-output")
	DirAccess.make_dir_recursive_absolute(destination)
	verify(root.get_texture().get_image().save_png(destination.path_join(name+".png"))==OK,"save screenshot "+name)

func drag_between(from,to):
	var e=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	e.position=root.get_stretch_transform()*game.get_global_transform_with_canvas()*from
	e.global_position=e.position
	Input.parse_input_event(e)
	await process_frame
	var motion=InputEventMouseMotion.new()
	motion.position=root.get_stretch_transform()*game.get_global_transform_with_canvas()*to
	motion.global_position=motion.position
	motion.relative=to-from
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	e=e.duplicate()
	e.pressed=false
	e.position=motion.position
	e.global_position=e.position
	Input.parse_input_event(e)
	await process_frame

func run():
	game=load("res://Main.tscn").instantiate()
	game.test_mode=true
	game.save_file="res://test-progress.cfg"
	var portrait_command="--portrait-command" in OS.get_cmdline_user_args()
	game.force_command_layout=portrait_command
	root.add_child(game)
	await process_frame
	if portrait_command:
		await capture("v8-browser-mobile-class")
		game.choose_class("tide")
		await process_frame
		await capture("v8-browser-mobile-map")
		game.start_fight(4)
		game.battle.player.hand=["W","W","W","L","L"]
		game.battle.enemy.hp=8
		await process_frame
		await capture("v8-browser-mobile")
		verify(game.command_is_portrait(),"portrait browser view selects the mobile layout")
		verify(game.card_rects.is_empty() and game.regions.any(func(region): return region.id.begins_with("recipe:") and region.rect.size.x>1000),"mobile battle uses full-width spell cards without a hand")
		print("MOBILE UI CHECKS: %d — %s" % [checks,"FAIL" if failed else "PASS"])
		quit(1 if failed else 0)
		return
	verify(game.class_id=="" and game.modal=="class","fresh campaign opens class picker before map")
	await key(KEY_ESCAPE)
	verify(game.modal=="class","fresh campaign cannot bypass class selection")
	await click_at(Vector2(351,644))
	verify(game.class_id=="tide" and game.modal=="","class button confirms starting deck")
	game.unlocked=0
	await process_frame
	await process_frame
	verify(game.screen=="map","game starts on map")
	await key(KEY_H)
	verify(game.modal=="help","H opens help")
	await capture("v7-help")
	await key(KEY_ESCAPE)
	await capture("v7-map-start")
	verify(not game.regions.any(func(r): return r.id=="settings"),"no visible settings button")
	await key(KEY_ESCAPE)
	verify(game.modal=="settings","Escape opens settings overlay")
	await capture("v7-settings")
	await key(KEY_ESCAPE)
	verify(game.modal=="","Escape closes settings")
	await click_at(game.MAP_NODES[0])
	verify(game.map_walking,"clicking encounter moves player along trail")
	await create_timer(1.3).timeout
	verify(game.screen=="battle" and game.battle.stage==0,"map tile starts encounter")
	game.battle.player.hand=["W","W","W","L","L"]
	game.toast_time=0
	var centers=game.board_centers()
	for i in range(1,7):
		verify(abs(centers[0].distance_to(centers[i])-game.BOARD_SPACING)<0.01,"all six slots equidistant from core")
		verify(game.slot_at(centers[i])==i,"aligned slot hitbox")
	for actor_center in [game.ENEMY_CENTER,game.PLAYER_CENTER]:
		for center in centers:
			verify(Geometry2D.intersect_polygons(game.hex_points(actor_center,game.BOARD_RADIUS),game.hex_points(center,game.BOARD_RADIUS)).is_empty(),"character hexes never overlap playable hexes")
	verify(game.slot_at(game.ENEMY_CENTER)==-1 and game.slot_at(game.PLAYER_CENTER)==-1,"portrait hexes are not playable slots")
	await process_frame
	# Click the actual Twin Tide row. No second Arrange action.
	await process_frame
	var twin_region=game.regions.filter(func(region): return region.id=="recipe:twin")[0]
	await click_at(twin_region.rect.get_center())
	verify(game.battle.ready_spell().id=="twin","click spell fills exact pattern immediately")
	verify(game.battle.player.hand.size()==3 and game.battle.enemy.hp==18,"autofill spends cards only on board, never casts")
	verify(game.slot_impacts.size()==2,"each placed gem has an impact animation")
	await create_timer(0.4).timeout
	await capture("v7-ready")
	await key(KEY_ENTER)
	verify(game.battle.enemy.hp==13 and game.battle.casts==1,"Enter casts selected recipe")
	verify(game.animation_running and game.cast_fx.effect=="damage","attack animation starts")
	await key(KEY_5)
	verify(game.battle.ready_spell().is_empty(),"inputs cannot place cards in middle of a cast")
	await key(KEY_ESCAPE)
	var paused_hp=game.battle.player.hp
	var paused_round=game.battle.round_number
	await create_timer(1.2).timeout
	verify(game.battle.player.hp==paused_hp and game.battle.round_number==paused_round and game.animation_running,"settings pauses battle timeline")
	await key(KEY_ESCAPE)
	await create_timer(0.25).timeout
	await capture("v7-attack")
	await create_timer(0.65).timeout
	var prior_board=game.battle.board.duplicate()
	verify(not game.visible_spells().any(func(recipe): return recipe.id=="pulse"),"Pulse disappears when the remaining cast budget cannot pay for it")
	game.fill_spell("pulse")
	verify(game.battle.board==prior_board and game.battle.ready_spell().is_empty(),"Pulse cannot be filled as a second cast")
	await shortcut_spell("shard")
	verify(game.battle.ready_spell().id=="shard","5 fills Sunshard from mixed leftovers")
	await key(KEY_ENTER)
	await create_timer(3.0).timeout
	verify(game.battle.phase=="player" and game.battle.round_number==2,"exhausted casts automatically advance enemy turn")
	verify(game.battle.history.any(func(ev): return ev.who=="Bat"),"enemy resolves an attack or recovery from its cards")
	await process_frame
	await drag_between(game.card_rects[0].get_center(),game.BOARD_ORIGIN)
	verify(game.battle.board[0]!="","manual drag onto core still works")
	var element=game.battle.board[0]
	await drag_between(game.BOARD_ORIGIN,game.board_centers()[1])
	verify(game.battle.board[0]=="" and game.battle.board[1]==element,"manual rearrangement still works")
	await key(KEY_BACKSPACE)
	verify(R.occupied(game.battle.board)==0,"Backspace returns placed cards")
	game.battle.player.hand=["W","W","W","L","L"]
	await shortcut_spell("scry")
	verify(game.battle.ready_spell().id=="scry","4 autofills Scry")
	await key(KEY_ENTER)
	verify(game.battle.player.hand.size()==6 and game.cast_fx.effect=="draw","draw animation accompanies net extra ingredient")
	await create_timer(0.36).timeout
	await capture("v7-draw")
	await create_timer(0.6).timeout
	game.battle.clear_board()
	game.battle.player.hand=["L","L","W"]
	game.battle.player.hp=game.battle.player.max_hp-10
	await shortcut_spell("mend")
	verify(game.battle.ready_spell().id=="mend","3 autofills healing pattern")
	await key(KEY_ENTER)
	verify(game.cast_fx.effect=="heal","healing animation is distinct")
	await create_timer(0.4).timeout
	await capture("v7-heal")
	# Start a fresh fight while delayed work exists; it must not affect the next fight.
	game.start_fight(4)
	await create_timer(1.0).timeout
	verify(game.battle.stage==4 and R.encounters()[4].name=="Dragon" and game.battle.round_number==1 and game.battle.phase=="player","old animation cannot advance new fight")
	game.battle.player.hand=["W","W","W","L","L"]
	await process_frame
	verify(game.regions.any(func(r): return r.id=="cast" and r.rect.position.x>1000),"Cast lives above End turn in spell sidebar")
	await shortcut_spell("dawn")
	verify(game.battle.ready_spell().id=="dawn","9 fills Dawnfall with all five gems")
	await create_timer(0.45).timeout
	await capture("v7-battle")
	await key(KEY_B)
	verify(game.modal=="book","B opens nine-spell book")
	await capture("v7-book")
	await key(KEY_ESCAPE)
	game.unlocked=4
	game.battle.enemy.hp=1
	await key(KEY_ENTER)
	verify(game.battle.phase=="won" and game.modal=="","lethal cast leaves time for impact and portrait reaction")
	await create_timer(0.55).timeout
	await capture("v7-finishing-blow")
	await create_timer(0.55).timeout
	verify(game.modal=="victory","reward appears after victory beat")
	await key(KEY_ESCAPE)
	verify(game.modal=="victory","Escape cannot skip reward")
	await capture("v7-victory")
	await key(KEY_ENTER)
	verify(game.modal=="victory" and game.unlocked==4,"Enter cannot silently skip gem choice")
	await click_at(Vector2(720,717))
	verify(game.unlocked==5 and game.screen=="map","victory completes map")
	await capture("v7-map")
	game.start_fight(1)
	game.battle.player.hp=1
	game.battle.end_player_turn()
	var s=game.battle.plan_enemy()
	game.apply_event(game.battle.cast_enemy(s))
	await create_timer(1.05).timeout
	verify(game.modal=="defeat","enemy lethal opens retry after impact")
	game.activate("retry")
	verify(game.battle.stage==1 and game.battle.player.hp==30 and game.battle.learned.size()==9,"retry restores HP and preserves spells")
	# Music uses separate player, stable loops, and a persisted switch.
	for stream in game.music_streams.values():
		verify(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_end>0,"soundtrack loops")
		verify(stream.get_length()>=32.0,"theme has a full musical phrase")
	game.save_file="res://test-progress.cfg"
	game.test_mode=false
	game.music_on=true
	game.update_music()
	await create_timer(1.1).timeout
	verify(game.music.playing and game.music_track=="battle","battle theme plays")
	game.start_fight(4)
	await create_timer(1.1).timeout
	verify(game.music.playing and game.music_track=="boss","Dragon switches to boss theme")
	game.activate("music")
	verify(not game.music.playing and not game.music_on,"music toggle stops playback")
	game.sound_on=false
	game.unlocked=3
	game.save_progress()
	game.unlocked=0
	game.sound_on=true
	game.music_on=true
	game.load_progress()
	verify(game.unlocked==3 and not game.sound_on and not game.music_on,"progress and both audio settings survive save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_file))
	game.test_mode=true
	# Class picker, reward choices and paging use the actual rendered controls.
	game.screen="map"
	game.activate("confirm_reset")
	await process_frame
	await capture("v7-class-picker")
	await click_at(Vector2(720,644))
	verify(game.class_id=="pyro" and game.campaign_deck=={"F":14,"A":6} and game.unlocked==0,"class click starts selected twenty-card campaign")
	game.start_fight(0)
	verify(game.battle.player.hand.all(func(e): return e in ["F","A"]),"selected class supplies combat hand")
	game.battle.phase="won"
	game.modal="victory"
	await process_frame
	await capture("v7-gem-reward")
	verify(not game.accept_victory("W") and game.unlocked==0,"reward rejects elements enemy does not own")
	await click_at(Vector2(605,555))
	verify(game.unlocked==1 and game.campaign_deck.get("D")==1,"reward button adds exactly one chosen enemy gem")
	verify(not game.accept_victory("D") and game.campaign_deck.D==1,"same victory cannot grant duplicate rewards")
	game.start_fight(1)
	verify(game.battle.learned.any(func(recipe): return recipe.id=="gem_D"),"captured foreign gem unlocks immediate spell")
	game.battle.phase="won"
	game.modal="victory"
	var before_deck=game.campaign_deck.duplicate()
	game.activate("reward")
	verify(game.unlocked==2 and game.campaign_deck==before_deck,"skip advances campaign without changing deck")
	game.campaign_deck["W"]=1
	game.campaign_deck["E"]=1
	game.start_fight(4)
	game.battle.player.hand=["F","A","F","A","F","A","F","A","D","W","E"]
	await process_frame
	verify(game.card_rects.size()==8,"large retained hand remains inside eight-card viewport")
	await click_at(Vector2(981,835))
	verify(game.hand_offset==3 and game.card_indices[0]==3,"hand paging tracks actual card indices")
	await drag_between(game.card_rects[7].get_center(),game.board_centers()[1])
	verify(game.battle.board[1]=="E","paged hand drag places correct hidden ingredient")
	game.battle.clear_board()
	await process_frame
	await capture("v7-large-hand")
	game.activate("spells_next")
	await process_frame
	verify(game.spell_page==1,"captured spells have a second page")
	var second_page_first=game.visible_spells()[game.spells_per_page()].id
	await key(KEY_1)
	verify(game.battle.ready_spell().id==second_page_first,"number keys fill the first sorted spell on the second page")
	await capture("v7-captured-spell")
	game.save_file="res://test-progress.cfg"
	game.test_mode=false
	game.unlocked=2
	game.save_progress()
	game.class_id="tide"
	game.campaign_deck={}
	game.load_progress()
	verify(game.class_id=="pyro" and game.campaign_deck=={"F":14,"A":6,"D":1,"W":1,"E":1} and game.unlocked==2,"class and growing deck persist across reload")
	var legacy=ConfigFile.new()
	legacy.set_value("run","unlocked",4)
	legacy.save(game.save_file)
	game.load_progress()
	verify(game.class_id=="tide" and game.campaign_deck=={"W":12,"L":8} and game.unlocked==4,"legacy campaigns keep progress and migrate to Tidecaller")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_file))
	game.test_mode=true
	game.choose_class("pyro")
	game.start_fight(4)
	game.battle.heat=4
	game.battle.player.hand=["F","F","A","A","F"]
	await shortcut_spell("twin")
	verify(game.battle.ready_spell().name=="Kindle" and game.battle.spell_text(game.battle.ready_spell()).contains("−2 HP"),"Fire UI previews overheat health cost")
	await capture("v7-pyro-hot")
	await key(KEY_ENTER)
	verify(game.battle.heat==5 and game.battle.player.hp==26 and game.cast_fx.hp_cost==2,"cast updates visible Heat and health cost effect")
	await create_timer(0.9).timeout
	await shortcut_spell("mend")
	await key(KEY_ENTER)
	verify(game.battle.heat==0 and game.battle.player.hp==28,"Air UI cast vents and heals")
	game.choose_class("night")
	game.start_fight(0)
	game.battle.player.hand=["B","B","D","D","B"]
	await shortcut_spell("mend")
	verify(game.battle.ready_spell().effect=="damage","Nightbinder third spell is blood attack rather than healing")
	await capture("v7-night-offering")
	await key(KEY_ENTER)
	verify(game.battle.player.hp==19 and game.battle.enemy.hp==10,"Blood price resolves in real UI")
	await create_timer(0.9).timeout
	await shortcut_spell("twin")
	await key(KEY_ENTER)
	verify(game.battle.player.hp==21 and game.cast_fx.healed==2,"Dark life steal is shown in casting effect")
	game.choose_class("tide")
	game.choose_class("tide")
	game.campaign_deck["D"]=1
	game.start_fight(1)
	game.battle.player.hand=["W","D","L","W","L"]
	await process_frame
	verify(game.visible_spells().all(func(recipe): return game.battle.cast_allowed(recipe) and R.can_make(game.battle.available_cards(),recipe)),"combat list contains only spells that can be cast now")
	for i in range(1,game.visible_spells().size()):
		var previous=game.visible_spells()[i-1]
		var current=game.visible_spells()[i]
		if not game.battle.is_lethal_spell(previous) and not game.battle.is_lethal_spell(current):
			verify(R.occupied(previous.pattern)>=R.occupied(current.pattern),"nonlethal castable spells descend by rune count")
	var enemy_hp=game.battle.enemy.hp
	game.battle.enemy.hp=4
	verify(not game.visible_spells().is_empty() and game.battle.is_lethal_spell(game.visible_spells()[0]),"a finishing blow rises to the top of the spell list")
	game.battle.enemy.hp=enemy_hp
	await process_frame
	verify(not game.card_rects.is_empty() and game.regions.any(func(region): return region.id=="cast" and region.rect.position.x>1000),"desktop battle keeps its board, hand, and spell sidebar")
	await capture("v7-castable-spells")
	game.fill_spell("weave_WD0")
	verify(game.battle.ready_spell().name=="Blackwater","captured Dark fills a mixed Water spell")
	await key(KEY_ENTER)
	verify(game.battle.tide==1,"mixed spell updates class resource through UI")
	await create_timer(0.9).timeout
	await process_frame
	var first_ready=game.visible_spells()[0].id
	await key(KEY_1)
	verify(game.battle.ready_spell().id==first_ready,"number shortcut follows the castable sorted list")
	game.battle.clear_board()
	game.battle.player.hand=["W","D","L"]
	game.battle.casts=2
	game.battle.place(1,3)
	await process_frame
	verify(game.visible_spells().any(func(recipe): return recipe.id=="weave_WD0"),"castable list includes ingredients already placed on the board")
	game.modal="book"
	game.activate("book_scope:all")
	game.activate("book_element:D")
	await process_frame
	verify(game.book_spells().size()>20 and game.book_spells().all(func(recipe): return "D" in recipe.pattern),"rune atlas filters the full catalog by element")
	await capture("v7-rune-atlas")
	game.modal="victory"
	game.battle.phase="won"
	await capture("v7-reward-combos")
	verify(R.reward_spells("tide",game.campaign_deck,"E",2).size()>5,"reward previews multiple new mixed patterns")
	game.modal=""
	game.choose_class("tide")
	# Walk each tutorial segment, including the bridge, and verify unlock gating.
	game.screen="map"
	game.modal=""
	for stage in range(5):
		game.unlocked=stage
		game.map_player_position=game.map_token_positions[stage]
		game.map_walking=false
		await process_frame
		await RenderingServer.frame_post_draw
		var available=game.regions.filter(func(r): return r.id.begins_with("fight:") and r.enabled)
		verify(available.size()==1 and available[0].id=="fight:"+str(stage),"only current tutorial enemy unlocks")
		await click_at(game.MAP_NODES[stage])
		verify(game.map_walk_target==stage and game.map_walking,"each encounter tile starts its route")
		if stage==2:
			verify(game.map_walk_points.size()==5,"Troll approach uses the bridge waypoints")
		var steps=0
		while game.map_walking and steps<100:
			game.update_map_walk(0.05)
			steps+=1
		verify(game.screen=="battle" and game.battle.stage==stage,"route enters matching fight")
		game.battle.phase="won"
		game.accept_victory()
		verify(game.unlocked==stage+1 and game.screen=="map","victory unlocks next tutorial encounter")
	game.unlocked=0
	game.map_player_position=game.map_token_positions[0]
	game.screen="map"
	game.modal=""
	game.map_walking=false
	await process_frame
	game.river_material.set_shader_parameter("flow_time",0.0)
	game.set_process(false)
	await capture("v7-river-a")
	game.river_material.set_shader_parameter("flow_time",2.5)
	await capture("v7-river-b")
	game.set_process(true)
	game.music.stop()
	game.music.stream=null
	await create_timer(0.2).timeout
	if game.music_tween: game.music_tween.kill()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("UI CHECKS: %d — %s" % [checks,"FAIL" if failed else "PASS"])
	quit(1 if failed else 0)
