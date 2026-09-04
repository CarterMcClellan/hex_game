"""Original, deterministic 16-bar fantasy miniatures. No downloaded samples."""
from pathlib import Path
import numpy as np
import wave
RATE=22050
OUT=Path(__file__).resolve().parents[1]/'assets/music'; OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(17)

def compose(name,bpm,boss=False,quiet=False):
    beat=60/bpm
    length=64*beat
    n=int(length*RATE)
    mix=np.zeros((n,2),np.float64)
    def add(midi,start,duration,amp,voice='pluck',pan=0):
        count=int(duration*RATE)
        t=np.arange(count)/RATE
        f=440*2**((midi-69)/12)
        if voice=='pluck':
            y=(np.sin(2*np.pi*f*t)+.32*np.sin(2*np.pi*f*2*t)+.13*np.sin(2*np.pi*f*3*t))*np.exp(-t*5)
            env=np.minimum(t/.006,1)*np.minimum((duration-t)/.05,1)
        elif voice=='flute':
            phase=2*np.pi*f*t+.009*np.sin(2*np.pi*5*t)
            y=np.sin(phase)+.13*np.sin(phase*2)+.055*np.sin(phase*3)
            env=np.minimum(t/.07,1)*np.minimum((duration-t)/.12,1)*.7
        elif voice=='strings':
            y=sum(np.sin(2*np.pi*(f*k+.4)*t)/k**1.6 for k in range(1,5))
            env=np.minimum(t/.28,1)*np.minimum((duration-t)/.4,1)*.46
        elif voice=='bell':
            y=np.sin(2*np.pi*f*t)*np.exp(-t*3)+.3*np.sin(2*np.pi*f*2.76*t)*np.exp(-t*7)
            env=np.minimum(t/.004,1)*np.minimum((duration-t)/.04,1)
        elif voice=='bass':
            y=np.sin(2*np.pi*f*t)+.16*np.sin(2*np.pi*f*2*t)
            env=np.minimum(t/.012,1)*np.minimum((duration-t)/.09,1)*np.exp(-t*1.8)
        elif voice=='drum':
            y=np.sin(2*np.pi*(63*t+2.8*(1-np.exp(-t*35))))*np.exp(-t*17)+rng.normal(0,.11,count)*np.exp(-t*45)
            env=np.minimum(t/.002,1)
        else:
            y=rng.normal(0,.18,count)*np.exp(-t*55)
            env=np.minimum(t/.002,1)
        y=y*env*amp
        idx=(int(start*RATE)+np.arange(count))%n
        mix[idx,0]+=y*np.sqrt((1-pan)/2)
        mix[idx,1]+=y*np.sqrt((1+pan)/2)
    # D minor, C, B-flat, A: a warm folk cadence. Boss varies to G minor/E diminished.
    chords=[(50,57,62,65),(48,55,60,64),(46,53,58,62),(45,52,57,61)]
    if boss: chords=[(50,57,62,65),(43,55,58,62),(40,52,58,62),(45,52,57,61)]
    themes=[
        [74,77,81,79,77,74,72,74],
        [76,79,84,81,79,76,74,72],
        [74,77,82,81,77,74,70,74],
        [73,76,81,79,76,73,69,73],
    ]
    for bar in range(16):
        chord=chords[(bar//2)%4]
        base=bar*4*beat
        for j,note in enumerate(chord[1:]): add(note,base,4*beat+.35,.11 if quiet else .15,'strings',(j-1)*.35)
        for b in [0,2]: add(chord[0]-12,base+b*beat,1.4*beat,.27,'bass')
        for tick in range(8):
            note=chord[1+([0,1,2,1,0,2,1,2][tick])]+(12 if quiet else 0)
            add(note,base+tick*.5*beat,.8,.16 if quiet else .23,'pluck',-.3 if tick%2 else .3)
        melody=themes[(bar//2)%4]
        for b in range(4):
            note=melody[(bar%2)*4+b]
            if bar>=8 and b==3: note+=12 if not boss else -12
            add(note,base+b*beat,.84*beat,.19 if quiet else .16,'flute',.1)
        if bar%2==0: add(melody[0]+12,base,1.3,.11,'bell',-.4)
        if not quiet:
            for b in [0,2]: add(0,base+b*beat,.24,.30 if boss else .22,'drum')
            for b in [1,3]: add(0,base+b*beat,.15,.15,'noise',.3)
        elif bar%2: add(0,base+3*beat,.1,.08,'noise',.3)
    # Circular room echoes preserve the loop seam and add a small acoustic space.
    dry=mix.copy()
    for delay,level in [(0.093,.12),(0.173,.09),(0.279,.05)]:
        mix+=np.roll(dry[:,::-1],int(delay*RATE),axis=0)*level
    peak=np.max(np.abs(mix)); mix*=.79/max(peak,1e-6)
    data=(mix*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data.tobytes())
    print(name,round(length,2),'seconds, peak',round(float(np.max(np.abs(data)))/32767,3))
compose('trail',96,quiet=True)
compose('duel',120)
compose('spire',120,boss=True)
