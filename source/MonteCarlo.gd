extends SceneTree
const R=preload("res://Rules.gd")
const B=preload("res://Battle.gd")
const Agent=preload("res://BalanceAgent.gd")
var options={"n":"100","seed":"0","policies":"planner","rewards":"skip,random","classes":"tide,pyro,night","out":"work/mc-pilot","hp":"","primary":""}
var agent=Agent.new()
var summaries={}
var usage={}
var rows

func _initialize(): call_deferred("run")
func track(key,won,turns,hp,spent,healed,drawn,casts):
	if not summaries.has(key): summaries[key]={"n":0,"wins":0,"turns":0,"hp":0,"spent":0,"healed":0,"drawn":0,"casts":0}
	var row=summaries[key]
	row.n+=1
	row.wins+=int(won)
	row.turns+=turns
	row.hp+=hp
	row.spent+=spent
	row.healed+=healed
	row.drawn+=drawn
	row.casts+=casts

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair=arg.trim_prefix("--").split("=",true,1)
			options[pair[0]]=pair[1]
	var destination=options.out
	DirAccess.make_dir_recursive_absolute(destination)
	rows=FileAccess.open(destination+"/battles.csv",FileAccess.WRITE)
	rows.store_line("class,policy,reward,seed,stage,win,turns,hp,max_hp,hp_spent,hp_restored,cards_drawn,casts,deck_size,timeout")
	var start=Time.get_ticks_msec()
	var n=int(options.n)
	var first_seed=int(options.seed)
	var cases=0
	for cid in options.classes.split(","):
		for policy in options.policies.split(","):
			for reward in options.rewards.split(","):
				agent.policy=policy
				var campaigns=0
				for index in range(n):
					var seed_value=first_seed+index
					var deck=R.class_data(cid).deck.duplicate()
					if options.primary!="":
						var elements=R.class_data(cid).elements
						deck={elements[0]:int(options.primary),elements[1]:20-int(options.primary)}
					var reward_rng=RandomNumberGenerator.new()
					reward_rng.seed=seed_value*7919+1987
					var complete=true
					for stage in range(5):
						var battle=B.new(stage,seed_value*104729+stage*15485863+401,deck,cid)
						if options.hp!="": battle.player.hp=int(options.hp); battle.player.max_hp=int(options.hp)
						agent.rng.seed=seed_value*65537+stage*1009+71
						var card_count=R.deck_cards(deck).size()
						var decisions=0
						while battle.phase not in ["won","lost"] and battle.round_number<=40:
							while battle.phase=="player" and battle.casts>0:
								var action=agent.choose(battle)
								if action.is_empty(): break
								assert(battle.arrange(action))
								assert(not battle.cast_player().is_empty())
								assert(battle.conserved(battle.player,true)==card_count)
								var key=cid+"|"+policy+"|"+reward+"|"+action.id
								if not usage.has(key): usage[key]={"name":action.name,"casts":0}
								usage[key].casts+=1
								decisions+=1
								assert(decisions<200)
							if battle.phase=="won": break
							battle.end_player_turn()
							while battle.phase=="enemy" and battle.enemy_casts>0:
								var action=battle.plan_enemy()
								if action.is_empty(): break
								assert(not battle.cast_enemy(action).is_empty())
								assert(battle.conserved(battle.enemy)==20)
							if battle.phase=="enemy": battle.next_round()
						var won=battle.phase=="won"
						complete=complete and won
						var spent=0
						for event in battle.history:
							if event.who=="You": spent+=event.get("hp_cost",0)
						track(cid+"|"+policy+"|"+reward+"|"+str(stage),won,battle.round_number,battle.player.hp,spent,battle.stats.healed,battle.stats.drawn,battle.stats.casts)
						rows.store_csv_line([cid,policy,reward,str(seed_value),str(stage),str(int(won)),str(battle.round_number),str(battle.player.hp),str(battle.player.max_hp),str(spent),str(battle.stats.healed),str(battle.stats.drawn),str(battle.stats.casts),str(card_count),str(int(battle.round_number>40))])
						cases+=1
						# Counterfactual later fights still run after losses, avoiding survivor bias.
						if reward=="random":
							var choices=R.encounters()[stage].deck.keys()
							var gem=choices[reward_rng.randi_range(0,choices.size()-1)]
							deck[gem]=deck.get(gem,0)+1
					if complete: campaigns+=1
					summaries[cid+"|"+policy+"|"+reward+"|campaign"]={"n":index+1,"wins":campaigns}
					if (index+1)%100==0: print("PROGRESS %s %s %s %d/%d: %d campaigns" % [cid,policy,reward,index+1,n,campaigns])
				print("RESULT %s %s %s: %d/%d complete" % [cid,policy,reward,campaigns,n])
	rows.close()
	var file=FileAccess.open(destination+"/summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"options":options,"cases":cases,"elapsed_seconds":(Time.get_ticks_msec()-start)/1000.0,"summaries":summaries,"usage":usage,"class_definitions":R.classes(),"encounters":R.encounters(),"policy_version":"hidden-order-invariant-v2"},"\t"))
	file.close()
	print("DONE: %d fights in %.1f seconds" % [cases,(Time.get_ticks_msec()-start)/1000.0])
	quit()
