"""Rerun the frozen experiment with at most three Godot processes."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse,subprocess
parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args()
source=Path(__file__).resolve().parent
out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
def run(case):
    cid,mode=case
    destination=out/f'{cid}-{mode}';destination.mkdir(exist_ok=True)
    policy='planner' if mode=='planner' else 'greedy,random'
    n='1000' if mode=='planner' else '500'
    with (destination/'console.log').open('w') as log:
        subprocess.run([args.godot,'--headless','--path',str(source),'--script','MonteCarlo.gd','--log-file',str(destination/'godot.log'),'--',f'--classes={cid}',f'--policies={policy}',f'--n={n}','--seed=10000',f'--out={destination}'],stdout=log,stderr=subprocess.STDOUT,check=True)
    print(f'Finished {cid} {mode}',flush=True)
with ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(run,[(c,m) for c in ['tide','pyro','night'] for m in ['planner','sensitivity']]))
