extends RefCounted
## Simulation policy uses Battle.gd itself. It knows card counts, never draw order.
const R=preload("res://Rules.gd")
const B=preload("res://Battle.gd")
var rng=RandomNumberGenerator.new()
var sandbox=B.new()
var policy="planner"

func snapshot(b):
	return {"player":b.player.duplicate(true),"enemy":b.enemy.duplicate(true),"board":b.board.duplicate(),"phase":b.phase,"casts":b.casts,"tide":b.tide,"heat":b.heat,"archetype":b.archetype,"stage":b.stage,"learned":b.learned}

func restore(state):
	sandbox.player=state.player.duplicate(true)
	sandbox.enemy=state.enemy.duplicate(true)
	sandbox.board=state.board.duplicate()
	sandbox.phase=state.phase
	sandbox.casts=state.casts
	sandbox.tide=state.tide
	sandbox.heat=state.heat
	sandbox.archetype=state.archetype
	sandbox.stage=state.stage
	sandbox.learned=state.learned
	sandbox.history.clear()
	sandbox.stats={"damage":0,"healed":0,"drawn":0,"casts":0}

func legal(b):
	var cards=b.available_cards()
	return b.learned.filter(func(s): return b.cast_allowed(s) and R.can_make(cards,s))

func score(before,after):
	if after.enemy.hp==0: return 1000.0+after.player.hp*0.01
	var threat=[4,7,8,12,24][before.stage]
	var urgency=1.65 if before.player.hp<=threat+6 else (0.75 if before.player.hp<before.player.max_hp*0.65 else 0.35)
	return before.enemy.hp-after.enemy.hp+(after.player.hp-before.player.hp)*urgency+(after.tide-before.tide)*0.7+(after.heat-before.heat)*0.25+after.stats.drawn*0.20

func choose(b):
	var choices=legal(b)
	if choices.is_empty(): return {}
	if policy=="random": return choices[rng.randi_range(0,choices.size()-1)]
	var state=snapshot(b)
	var best={}
	var best_score=-INF
	for recipe in choices:
		var samples=3 if recipe.effect=="draw" and policy=="planner" else 1
		var total=0.0
		for sample_index in range(samples):
			restore(state)
			# Shuffle a copy of the unseen multiset. Never consult the true top card.
			sandbox.rng.seed=rng.randi()
			sandbox.player.pile.sort()
			sandbox.shuffle(sandbox.player.pile)
			assert(sandbox.arrange(recipe))
			sandbox.cast_player()
			var value=score(state,sandbox)
			if policy=="planner" and sandbox.phase=="player" and sandbox.casts>0:
				var midway=snapshot(sandbox)
				var drawn=sandbox.stats.drawn
				for second in legal(sandbox):
					restore(midway)
					sandbox.stats.drawn=drawn
					assert(sandbox.arrange(second))
					sandbox.cast_player()
					value=maxf(value,score(state,sandbox))
			total+=value
		var value=total/samples
		if value>best_score:
			best_score=value
			best=recipe
	return best
