extends SceneTree
const R=preload("res://Rules.gd")
const B=preload("res://Battle.gd")
const A=preload("res://BalanceAgent.gd")
func _initialize(): call_deferred("run")
func run():
	var checks=0
	for cid in ["tide","pyro","night"]:
		for policy in ["planner","greedy","random"]:
			for seed_value in range(15):
				var b=B.new(seed_value%5,seed_value,{},cid)
				b.player.hp=maxi(1,b.player.hp-seed_value)
				var a=A.new()
				a.policy=policy
				a.rng.seed=700+seed_value
				var before=JSON.stringify(a.snapshot(b))
				var random_state=b.rng.state
				var chosen=a.choose(b)
				assert(before==JSON.stringify(a.snapshot(b)) and b.rng.state==random_state,"planning mutates real battle")
				checks+=1
				assert(chosen.is_empty() or (b.cast_allowed(chosen) and R.can_make(b.available_cards(),chosen)),"policy chose illegal spell")
				checks+=1
				b.player.pile.reverse()
				a.rng.seed=700+seed_value
				var alternate=a.choose(b)
				assert(chosen.get("id","")==alternate.get("id",""),"policy can see hidden draw order")
				checks+=1
	print("AGENT CHECKS: %d — PASS" % checks)
	quit()
