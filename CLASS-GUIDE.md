# Three ways to cast

## Tidecaller — Ebb & Flow

A keeper of moonlit estuaries: patient, restorative, and dangerous when the tide turns.

**30 HP · 9 Water + 11 Light.** Water class spells build one Tide, up to three. Tide stays between turns. A Light spell spends all stored Tide for +2 damage or healing per Tide, or +1 card per Tide for draw spells. You choose when to release it: spend early to survive, or bank it for a finisher. Tide resets each fight.

| Spell | Pattern | Base effect |
| --- | --- | --- |
| Pulse | Any gem in core | 4 damage; both casts; no Tide |
| Twin Tide | Water core + outer Water | 5 damage; build Tide |
| Mend | Light core + outer Light | Heal 5 + Tide bonus |
| Scry | Water core + outer Light | Draw 3; build Tide |
| Sunshard | Light core + outer Water | 4 damage + Tide bonus |
| Tidal Bolt | Water core + touching Water/Light | 9 damage; build Tide |
| Tidal Ward | Light core between opposite Waters | Heal 8 + Tide bonus |
| Deep Study | Water core between opposite Water/Light | Draw 5; build Tide |
| Dawnfall | Light core + Water/Light/Water/Water outer arc | 18 damage + Tide bonus |

**A typical decision:** Twin Tide builds one Tide, making Sunshard hit for 6. Or keep the Tide for later and build toward a 24-damage Dawnfall. Healing also spends the bank, so recovery competes with your strongest attack.

## Pyromancer — Heat

A reckless kiln-mage who treats flame as something to cultivate. Air can feed a pattern, but an Air-aligned spell opens the furnace and lets it cool.

**28 HP · 14 Fire + 6 Air.** Fire-aligned class spells gain one Heat, up to six. Fire attacks add current Heat to their damage before gaining the new point. At four or more Heat, any Fire-aligned class spell also costs 2 HP. Air-aligned spells vent all Heat and heal that much HP. Heat stays between turns and resets each fight.

The spell row identifies its alignment: a mixed pattern can be a Fire or an Air spell. Pulse and simple single-gem runes do not build or vent Heat.

| Spell | Pattern | Base effect |
| --- | --- | --- |
| Pulse | Any gem in core | 4 damage; both casts |
| Kindle · Fire | Fire core + outer Fire | 4 damage + Heat |
| Cooling Breath · Air | Air core + outer Air | Heal 3 + vented Heat |
| Bellows · Air | Air core + outer Fire | Draw 3; vent and heal |
| Firebrand · Fire | Touching outer Fire/Air; empty core | 6 damage + Heat |
| Flame Lance · Fire | Fire core between opposite Fire/Air | 9 damage + Heat |
| Backdraft · Air | Air core + touching outer Fires | 7 damage; vent and heal |
| Stoke · Fire | Three alternating outer Air/Air/Fire; empty core | Draw 4; build Heat |
| Wildfire · Fire | Fire core + Fire/Fire/Air outer arc | 15 damage + Heat |

**A typical decision:** At four Heat, Flame Lance hits for 13 but costs 2 HP and raises Heat to five. Backdraft then deals 7 and vents for 5 healing. Holding your rare Air cards lets you choose when to cool down. Wildfire costs only four gems, making it easier to unleash than Tidecaller's five-gem finisher.

## Nightbinder — Blood Price

A forbidden physician who bargains with their own heartbeat. Blood buys power; shadows bring borrowed life home.

**22 HP · 8 Dark + 12 Blood.** Blood-aligned class spells pay HP for efficient damage or drawing. Dark-aligned attacks restore half the damage actually dealt, rounded up. Soul Feast restores all of it. Costs must leave at least one HP; healing is capped at maximum HP, and overkill grants no extra life.

There is no ordinary healing spell in the starting class book. It recovers by attacking; earned weaves can add other recovery options. Blood costs are paid immediately, even when you defeat the enemy with that spell. Pulse and simple single-gem runes do not steal life.

| Spell | Pattern | Base effect |
| --- | --- | --- |
| Pulse | Any gem in core | 4 damage; both casts; no life steal |
| Siphon · Dark | Dark core + outer Dark | 4 damage; steal half |
| Blood Offering · Blood | Blood core + outer Blood | 8 damage; pay 3 HP |
| Forbidden Pact · Blood | Blood core + outer Dark | Draw 4; pay 3 HP |
| Night Fang · Dark | Opposite outer Dark/Blood; empty core | 4 damage; steal half |
| Heartseeker · Blood | Blood core + Dark/Blood separated by one outer slot | 12 damage; pay 4 HP |
| Soul Feast · Dark | Dark core between opposite Bloods | 7 damage; heal damage dealt |
| Grave Bargain · Blood | Alternating outer Blood/Dark/Blood; empty core | Draw 6; pay 5 HP |
| Eclipse · Dark | Dark core + alternating outer Dark/Blood/Dark | 16 damage; steal half |

**A typical decision:** Forbidden Pact trades 3 HP and two gems for four fresh cards. Use the second cast on Heartseeker for a dangerous burst, or Siphon/Soul Feast to recover. At low HP, a Blood-heavy hand can be unusable until a Dark pattern becomes available.

## Shared campaign rules

Each class begins with the first five patterns. Defeating Bat teaches the sixth; Goblin the seventh; Troll the eighth; Necromancer the ninth. Recipes rotate and reflect, but the core and relative spacing matter.

Draw five each turn; keep unused cards. Spent gems enter discard, which only reshuffles when the draw pile is empty. Two casts per turn; draw spells must leave a cast for follow-up. Pulse spends both casts.

After each victory, choose one enemy gem or skip. Captured gems now combine with your starting elements through 98 shared weaves (see `RUNE-ATLAS.md`). These mixed spells attune to a class element in their pattern when possible and trigger the corresponding class trait. Simple single-gem runes still work independently. Recipes appear only when your deck has the required copies; a second captured gem can unlock stronger patterns.

The spellbook's All runes view shows the full pool and missing ingredients. In combat, Ready filters castable spells, Match uses your current board, and Weaves shows combinations. Every class also begins with three shared weaves using its starting pair.

Each fight resets HP and class resources; your class and growing deck persist. Existing campaigns keep their selected class and exact gem counts. New starting compositions apply when you choose a class for a new journey.

## Measured balance

Version 0.7.0 starting decks and HP were tuned on exploratory seeds, then frozen for 60,000 holdout fights. See `analysis/BALANCE-REPORT.md` for class win rates, confidence intervals, opponent matchups, reward sensitivity and policy comparisons. Existing saved campaigns retain their exact gem counts; choose a new journey to use these starting decks.
