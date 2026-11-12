# Memo — Rendu des leçons en CI : moins de minutes de machine par train

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `perf/ci-lecons-rendu` |
| **Programme** | — |

---

## Le problème

La tâche `lecons` du train (`.github/workflows/ci.yml`, `test/system/catalog/lesson_rendering_test.rb`) importe, publie et lit chaque leçon v3 à 390 px et sur ordinateur, avec chacune de ses feuilles (lecture et « à remplir »). Le coût croît avec chaque leçon et chaque feuille :

- 06/11 : 60 leçons, 8 s par leçon ;
- 08/11 : 182 leçons, 19 s par leçon (deux exercices par notion, donc deux fois plus de feuilles) : passage de 12 à 24 parts ;
- 12/11 : 223 leçons, la part 17/24 dépasse les 5 min sur #541 : passage à 32 parts (#542).

Chaque nouvelle vague de leçons ajoute des parts, et donc des minutes de machine GitHub. Environ 50 s de chaque part sont de l'installation.

## Pour qui

Le porteur (minutes GitHub, durée du train) et toute session qui ouvre un train vers `Staging`.

## Pourquoi maintenant

L'étape 3 de #484 (1ère) ajoutera environ 100 leçons. Au rythme actuel, il faudrait environ 46 parts et 140 minutes de machine par train.

## Mesure avant

Run GitHub du train #541, tête `cf0483e70` (2026-11-12), tâche `lecons`, 32 parts, toutes vertes.

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Minutes de machine de la tâche `lecons` par train | 223 leçons v3, 32 parts | **98,7 min** (5 923 s) | ≤ 30 min | somme de `completed_at - started_at` des check runs `lecons *` du commit (API GitHub `commits/<sha>/check-runs`) |
| Durée de la part la plus longue (chemin critique) | idem | **213 s** (médiane 188 s, min 151 s) | ≤ 240 s, et stable quand on ajoute 100 leçons | idem, maximum |
| Rendu par leçon | part 1 de ce run : 7 leçons + 2 tests de garde | **157 s de tests, ≈ 20 s par leçon** (la première ≈ 57 s, démarrage de Chrome et de Puma compris) | ≤ 10 s | ligne `Finished in` du journal de la part, `-v` (durée par test) |
| Installation par part | idem | **≈ 49 s** (de la prise de la machine au premier test) | inchangée ou partagée | horodatages du journal : début → `Run options` |

Protocole reproductible : `gh api "repos/Lnclassapp/App.Lnclassapp/commits/<sha>/check-runs?per_page=100" --jq '[.check_runs[]|select(.name|startswith("lecons"))|((.completed_at|fromdate)-(.started_at|fromdate))]|{n:length,total:add,max:max}'`, sur la tête de la PR de train, au même nombre de leçons. Localement : `LECONS=<7 fichiers> bin/rails test test/system/catalog/lesson_rendering_test.rb -v`, 3 exécutions, médiane.

## Mesure après

Même protocole (`gh api …/check-runs`, somme et maximum des check runs `lecons *`).

| Train | Cas | Parts | Minutes de machine | Part la plus longue | Médiane |
|---|---|---|---|---|---|
| #541 (`cf0483e70`), avant | 223 leçons, 7 par part | 32 | 98,7 | 213 s | 188 s |
| #545 (`bd1d61bd`) | écrans touchés : rendu complet, 10 par part | 23 | 91,4 | **283 s** | 239 s |
| #549 (`665bb01b`) | écrans touchés : rendu complet, 8 par part | 28 | 100,1 | **269 s** | 211 s |

- Le rendu complet coûte presque autant qu'avant : le gain vient des trains sans écran touché (1 part de 2 témoins, ou ⌈N/8⌉ parts).
- 10 par part est trop près du plafond de 300 s : passage à 8 (décision du porteur).
- 8 par part : médiane en baisse, mais la part la plus longue reste à 269 s (installation variable d'une machine à l'autre). Repasser à 6 si une part dépasse 280 s.
- À relever : le premier train sans écran touché (attendu : 1 part, ≤ 3 min).

## Hors périmètre

- Les vues des leçons et des feuilles : aucun écran ne change.
- Les défauts détectés (largeur, `**`, figure absente, import refusé) : la liste ne rétrécit pas.
- Les autres tâches de CI (`unit`, `system`, `coverage`).
- Le format des leçons et le prompt de rédaction.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le générateur de leçons ne rend-il pas ce test inutile ? | Non : le générateur fixe la structure, l'import la valide ; seul le rendu voit l'écran de l'élève et les régressions des vues sur les leçons anciennes. | On garde le rendu ; on en baisse le coût ou la fréquence. |
| Où part le temps ? | ≈ 49 s d'installation par part (25 % du total) ; ≈ 20 s par leçon, dont des attentes `sleep 0.25` jusqu'à la stabilité des formules, polices et figures (`measure_sheet`), sur 2 pages × 2 largeurs par feuille. | Levier « attente » et levier « installation » à mesurer séparément. |

## Leviers candidats (ordonnés par gain/risque)

1. **Coût par leçon** : mesurer la part d'attente dans `measure_sheet` / `measure_page` et la réduire (attente sur événement plutôt que sondage, une seule visite par largeur si le rendu le permet). Aucune perte de couverture.
2. **Fréquence** : au train, rendre les leçons changées + un échantillon fixe couvrant chaque type de contenu ; le rendu complet tourne une fois par nuit sur `Develop` (tâche GitHub programmée), rouge = issue. Perte : une régression d'affichage hors échantillon est vue la nuit suivante, pas au train.
3. **Installation** : moins de parts une fois le levier 1 joué (moins d'installations).

## Questions encore ouvertes

- Le levier 2 change ce que prouve un train : décision du porteur (voir `## À trancher` du journal).
