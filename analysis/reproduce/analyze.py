from pathlib import Path
import sys,csv,json,math,statistics,hashlib,zipfile
from collections import defaultdict
out=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter
classes=['tide','pyro','night']; names={'tide':'Tidecaller','pyro':'Pyromancer','night':'Nightbinder'}
foes=['Bat','Goblin','Troll','Necromancer','Dragon']
colors={'tide':'#2a7c86','pyro':'#ce6b33','night':'#8b526c'}
paths=[out/f'{c}-{p}'/'summary.json' for c in classes for p in ['planner','sensitivity']]
assert all(p.exists() for p in paths),'Experiments are still running'
summaries=[json.loads(p.read_text()) for p in paths]
rows=[]; usage={}; campaign=defaultdict(lambda:True); cohort=defaultdict(list); bystage=defaultdict(list)
for p,d in zip(paths,summaries):
    assert d['policy_version']=='hidden-order-invariant-v2'
    usage.update(d['usage'])
    with (p.parent/'battles.csv').open() as f:
        for row in csv.DictReader(f):
            for key in ['seed','stage','win','turns','hp','max_hp','hp_spent','hp_restored','cards_drawn','casts','deck_size','timeout']: row[key]=int(row[key])
            assert not row['timeout'],row
            assert 0<=row['hp']<=row['max_hp']
            key=(row['class'],row['policy'],row['reward'])
            campaign[(*key,row['seed'])] &= bool(row['win'])
            cohort[key].append(row); bystage[(*key,row['stage'])].append(row); rows.append(row)
assert len(rows)==60000 and len(campaign)==12000
rates={}
for c in classes:
    for p in ['planner','greedy','random']:
        for reward in ['skip','random']:
            arr=[v for (cc,pp,rr,seed),v in campaign.items() if (cc,pp,rr)==(c,p,reward)]
            expected=1000 if p=='planner' else 500
            assert len(arr)==expected
            rates[c,p,reward]=(sum(arr),len(arr))
def wilson(w,n):
    z=1.959963984540054; p=w/n; den=1+z*z/n
    center=(p+z*z/(2*n))/den
    spread=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return max(0,center-spread),min(1,center+spread)
def ratecell(w,n):
    lo,hi=wilson(w,n)
    return f'{100*w/n:.1f}% ({100*lo:.1f}–{100*hi:.1f}%)'
def avg(c,key,p='planner',reward='random'):
    return statistics.mean(r[key] for r in cohort[c,p,reward])
metrics=[]
for c in classes:
    for p in ['planner','greedy','random']:
        for reward in ['skip','random']:
            w,n=rates[c,p,reward];lo,hi=wilson(w,n)
            metrics.append({'class':c,'policy':p,'reward':reward,'campaigns':n,'wins':w,'win_rate':w/n,'ci95_low':lo,'ci95_high':hi,'mean_turns_per_fight':avg(c,'turns',p,reward),'mean_hp_spent':avg(c,'hp_spent',p,reward),'mean_hp_restored':avg(c,'hp_restored',p,reward),'mean_hp_remaining':avg(c,'hp',p,reward)})
with (out/'win-rates.csv').open('w') as f:
    wr=csv.DictWriter(f,fieldnames=list(metrics[0]));wr.writeheader();wr.writerows(metrics)
with (out/'matchups.csv').open('w') as f:
    wr=csv.writer(f);wr.writerow(['class','policy','reward','enemy','wins','n','rate','ci95_low','ci95_high'])
    for key,rs in bystage.items():
        w=sum(r['win'] for r in rs);n=len(rs);lo,hi=wilson(w,n)
        wr.writerow([key[0],key[1],key[2],foes[key[3]],w,n,w/n,lo,hi])
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False,'axes.facecolor':'#fbf7ed','figure.facecolor':'#fbf7ed','text.color':'#244348','axes.labelcolor':'#244348','xtick.color':'#526463','ytick.color':'#526463','savefig.facecolor':'#fbf7ed'})
fig,axs=plt.subplots(1,2,figsize=(12,4.3),sharex=True)
for ax,reward,title in zip(axs,['random','skip'],['Take a random enemy gem','Skip every gem']):
    for i,c in enumerate(classes):
        w,n=rates[c,'planner',reward];p=w/n;lo,hi=wilson(w,n)
        ax.barh(i,p,color=colors[c],height=.54)
        ax.errorbar(p,i,xerr=[[p-lo],[hi-p]],fmt='none',ecolor='#233f44',capsize=4,lw=1.4)
        ax.text(p-.025 if p>.86 else p+.06,i,f'{p:.1%}',ha='right' if p>.86 else 'left',va='center',fontweight='bold',color='white' if p>.86 else '#244348')
    ax.set_yticks(range(3),[names[c] for c in classes]);ax.invert_yaxis();ax.set_xlim(0,1.08)
    ax.xaxis.set_major_formatter(PercentFormatter(1));ax.set_xticks([0,.25,.5,.75,1]);ax.set_title(title,loc='left',pad=18)
    ax.set_xlabel('Five-fight campaign win rate');ax.grid(axis='x',alpha=.13);ax.set_axisbelow(True)
fig.suptitle('Class balance · planner policy',x=.06,ha='left',fontsize=19,fontweight='bold')
fig.text(.06,.02,'1,000 fresh seeded campaigns per class and reward policy · bars show 95% Wilson intervals',fontsize=10)
fig.tight_layout(rect=[0,.07,1,.92]);fig.savefig(out/'campaign-win-rates.png',dpi=180);fig.savefig(out/'campaign-win-rates.svg');plt.close(fig)
heat=np.array([[sum(r['win'] for r in bystage[c,'planner','random',i])/1000 for i in range(5)] for c in classes])
fig,ax=plt.subplots(figsize=(11,3.5));im=ax.imshow(heat,vmin=.5,vmax=1,cmap='YlGnBu',aspect='auto')
for i in range(3):
    for j in range(5): ax.text(j,i,f'{heat[i,j]:.1%}',ha='center',va='center',color='white' if heat[i,j]>.8 else '#244348',fontsize=14,fontweight='bold')
ax.set_xticks(range(5),foes);ax.set_yticks(range(3),[names[c] for c in classes]);ax.set_title('Win rate by opponent · random gem rewards',loc='left',pad=20,fontsize=18,fontweight='bold')
fig.text(.1,.015,'1,000 fights in every cell · later fights also run after prior losses, avoiding survivor bias',fontsize=10)
fig.tight_layout(rect=[0,.08,1,1]);fig.savefig(out/'enemy-matchups.png',dpi=180);plt.close(fig)
# Paired seed reward effects, with a deterministic percentile bootstrap.
rng=np.random.default_rng(703)
effects={}
for c in classes:
    diffs=np.array([int(campaign[c,'planner','random',seed])-int(campaign[c,'planner','skip',seed]) for seed in range(10000,11000)])
    boot=np.mean(rng.choice(diffs,(10000,len(diffs)),replace=True),axis=1)
    effects[c]={'delta':float(diffs.mean()),'ci95_low':float(np.quantile(boot,.025)),'ci95_high':float(np.quantile(boot,.975))}
# Compact usage table preserves names, roles, counts, and concentration.
with (out/'spell-usage.csv').open('w') as f:
    wr=csv.writer(f);wr.writerow(['class','policy','reward','spell_id','spell_name','casts'])
    for key,val in sorted(usage.items()): wr.writerow(key.split('|')+[val['name'],val['casts']])
source=Path(__file__).resolve().parent
provenance={p:hashlib.sha256((source/p).read_bytes()).hexdigest() for p in ['Rules.gd','Battle.gd','BalanceAgent.gd','MonteCarlo.gd']}
(out/'source-sha256.json').write_text(json.dumps(provenance,indent=2)+'\n')
(out/'results.json').write_text(json.dumps({'battles':len(rows),'campaigns':len(campaign),'metrics':metrics,'paired_reward_effects':effects,'source_sha256':provenance},indent=2)+'\n')
text=['# The Hex Game — Monte Carlo balance report','', 'Version 0.7.0 · 60,000 holdout fights · 12,000 five-fight campaigns · 2026-09-03','', 'The final configuration was selected using separate exploratory seeds, then frozen before this holdout. Results measure simulated policies against the five tutorial enemies, not human win rates or player-versus-player balance.','', '## Main result','', 'The primary comparison uses the planner policy and takes one uniformly random eligible enemy gem after each victory. Each class has 1,000 seeded campaign samples. A campaign win means winning all five fights without a defeat or retry. HP and class resources reset at each fight, as in the game.','', '| Class | Starting deck | HP | Campaign wins | Win rate (95% interval) |','| --- | --- | ---: | ---: | --- |']
settings={'tide':('9 Water / 11 Light',30),'pyro':('14 Fire / 6 Air',28),'night':('8 Dark / 12 Blood',22)}
for c in classes:
    w,n=rates[c,'planner','random'];text.append(f'| {names[c]} | {settings[c][0]} | {settings[c][1]} | {w}/{n} | {ratecell(w,n)} |')
text+=['','![Campaign win rates](campaign-win-rates.png)','','## Strengths and costs','','| Class | Mean turns per fight | HP spent on spells | HP restored | HP remaining |','| --- | ---: | ---: | ---: | ---: |']
for c in classes: text.append(f"| {names[c]} | {avg(c,'turns'):.2f} | {avg(c,'hp_spent'):.2f} | {avg(c,'hp_restored'):.2f} | {avg(c,'hp'):.2f} |")
text+=['','Means include wins and losses, all five opponents, and random gem rewards. Restoration includes ordinary healing, life steal and venting; it is capped by missing HP. Remaining HP is zero on defeats.','', '- **Tidecaller:** the highest starting HP and more Light support a sustain-oriented plan. Water-to-Light sequencing converts preparation into damage, healing or extra draws. Its cost is slower finishing and fewer Water attack gems.', '- **Pyromancer:** Fire-heavy draws and Heat support immediate damage, but Air is limited and overheated casts spend HP. New elements can supply recovery and alternatives when the opening deck runs hot.', '- **Nightbinder:** powerful Blood spells and Dark life steal can finish quickly and recover while attacking. Its low HP and Blood-heavy draw distribution make paying for power dangerous, especially when Dark is unavailable.','', 'These are design roles; the tables quantify their realized performance under the tested policies.','', '## Opponent matchups','','![Opponent win rates](enemy-matchups.png)','','| Class | Bat | Goblin | Troll | Necromancer | Dragon |','| --- | ---: | ---: | ---: | ---: | ---: |']
for i,c in enumerate(classes): text.append('| '+names[c]+' | '+' | '.join(f'{v:.1%}' for v in heat[i])+' |')
text+=['','Every cell contains 1,000 fights. Later fights run even when an earlier one was lost, using the predetermined reward path. This produces unconditional matchup rates; it does not select only surviving campaigns. Campaign completion is the joint outcome across the same five fights.','', '## Reward sensitivity','','| Class | Skip gems | Take random gems | Paired change (95% bootstrap interval) |','| --- | ---: | ---: | --- |']
for c in classes:
    sw,sn=rates[c,'planner','skip'];rw,rn=rates[c,'planner','random'];e=effects[c]
    text.append(f"| {names[c]} | {sw/sn:.1%} | {rw/rn:.1%} | {e['delta']*100:+.1f} points ({e['ci95_low']*100:+.1f} to {e['ci95_high']*100:+.1f}) |")
text+=['','Random rewards are not optimized drafting. Enemy reward pools favor Dark, Blood and Earth before the Dragon. That gives the classes different opportunities to add new elements; Nightbinder starts with two of those elements already. Fire/Air rewards from the Dragon cannot affect an earlier fight.','', '## Policy sensitivity','','Each planner condition has 1,000 campaigns. Greedy and random conditions each have 500.','', '| Class | Planner, skip | Planner, take | Greedy, skip | Greedy, take | Random, skip | Random, take |','| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
for c in classes: text.append('| '+names[c]+' | '+' | '.join(f'{rates[c,p,r][0]/rates[c,p,r][1]:.1%}' for p in ['planner','greedy','random'] for r in ['skip','random'])+' |')
text+=['','- **Planner:** evaluates two casts within the current turn using the real battle engine. It scores damage, recovery and class resources. Draw spells use three hypothetical samples from the sorted unseen card multiset, not the true draw order. It does not search future enemy turns or know enemy hands.', '- **Greedy:** uses the same utility calculation but scores one cast at a time. It is not purely maximum damage and is not guaranteed to underperform the planner.', '- **Random:** chooses uniformly among legal spells, including Pulse. It never deliberately makes an invalid layout, so even this is not a model of an entirely new human player.','', '## Spell usage','','The catalog contains 98 shared weaves and 112 total possible patterns per class, including its class spells and simple runes. Each particular campaign only learns patterns supported by its actual gem counts and encounter progression.','', '| Class | Distinct spells used | Mixed-weave share of casts | Most cast spells |','| --- | ---: | ---: | --- |']
for c in classes:
    selected=[(k.split('|')[-1],v) for k,v in usage.items() if k.startswith(c+'|planner|random|')]
    selected.sort(key=lambda kv:kv[1]['casts'],reverse=True)
    total=sum(v['casts'] for k,v in selected); weave=sum(v['casts'] for k,v in selected if k.startswith('weave_'))
    top=', '.join(f"{v['name']} ({v['casts']/total:.0%})" for k,v in selected[:3])
    text.append(f'| {names[c]} | {len(selected)} | {weave/total:.1%} | {top} |')
text+=['','## What this suggests for the demo','','- Tidecaller is the forgiving planning class. Its sustain trades speed for safety; its near-ceiling planner win rate leaves little difficulty headroom for experienced players.', '- Pyromancer offers the fastest fights and the strongest measured benefit from gem rewards. Skipping upgrades is a substantial self-imposed challenge.', '- Nightbinder spends much more HP to cast and recovers through attacks. Its thinner starting health and poor random-policy performance make recovery sequencing an important tutorial lesson.', '- These classes intentionally do not have equal win rates. This experiment measures the current tutorial configuration; it does not establish that the classes are equally enjoyable or that every spell is balanced.', '', 'Full counts are in `spell-usage.csv`. Do not interpret usage as a causal measure of spell power: availability, deck composition and policy preferences all affect it.','', '## Validation and reproduction','','- 31,102 rules/regression checks, 125 rendered interface checks and 405 agent-isolation checks passed. Agent checks verify legal choices, no mutation of the real battle, and invariance to permutations of the hidden pile.', '- Every simulation checks player and enemy card conservation and stops at 40 rounds. There were no timeouts in the holdout.', '- Confidence intervals are 95% Wilson intervals. Reward effects use a paired bootstrap over 1,000 shared seed IDs with 10,000 resamples. Seed IDs are paired across classes and reward policies; do not treat every row as an independent campaign.', '- Holdout seeds are 10,000–10,999 for the planner and 10,000–10,499 for the other policies. Tuning seeds were 0–29, 200–299 and 400–499. No holdout result was used to retune this version.', '- All combat resolution comes from `Battle.gd`. The older rules-test bot is not used for these Monte Carlo results.', '- The standalone reproduction project matched all ten per-fight rows for a checked seed exactly.', '', 'From the analysis folder, reproduce one condition with Godot 4.6.3:', '', '```sh', 'godot --headless --path reproduce --script MonteCarlo.gd --log-file ./simulation.log -- --classes=tide --policies=planner --n=1000 --seed=10000 --out=/absolute/path/to/results', '```', '', 'To rerun all six conditions, run `python3 reproduce/run_all.py --godot /path/to/godot --out /absolute/path/to/results`. The bundled `reproduce/analyze.py` regenerates tables and figures; install its `requirements.txt` first, then run `python3 reproduce/analyze.py /absolute/path/to/results`.', '', 'Use `--policies=greedy,random --n=500` for the sensitivity run. The default reward conditions are `skip,random`. `experiment-plan.json` records the frozen configuration; `source-sha256.json` fingerprints the exact rules and simulator. Raw per-fight CSVs and summary JSONs are in the six class/policy folders.']
(out/'BALANCE-REPORT.md').write_text('\n'.join(text)+'\n')
print(json.dumps({'battles':len(rows),'campaigns':len(campaign),'primary':{c:rates[c,'planner','random'] for c in classes},'reward_effects':effects},indent=2))
