# Plan d'exécution — Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot P — PROMPT PAR MATIÈRE (docs, séquentiel)
  ↓
  ├─► Lot FR — 10 leçons de Français (docs) ──► commit direct sur Develop, fichiers envoyés au porteur
  ↓
Lot 0 — SOCLE DES FIGURES (séquentiel) : 6 sortes + courbe, listes fermées, cohérence, liste blanche, prompt des figures
  ↓
  ├─► Lot A  frise          ┐
  ├─► Lot B  carte + fonds  │
  ├─► Lot C  schéma fléché  │
  ├─► Lot D  tracé optique  ├─ en parallèle (rendu)
  ├─► Lot E  planches       │
  ├─► Lot F  molécule       │
  └─► Lot G  courbe         ┘
  ↓  (les lots de rédaction ne dépendent que du Lot 0 : ils valident par le domaine)
  ├─► Lot SVT ┐
  ├─► Lot PC  ├─ en parallèle (rédaction, un sous-agent par leçon, 6 au plus par lot)
  ├─► Lot HG  │
  └─► Lot EDHC┘
  ↓
Lot Z — CLÔTURE : test « 10 leçons par matière », structure complète des modules, README des contenus
```

Livraison (grill, « matière par matière ») : le Français part seul, dès le Lot FR, en commit de documentation sur `Develop` ; il ne contient aucune sorte nouvelle et s'importe avec le code déjà en production. Le reste part dans **la PR unique du chantier**, puis un train jusqu'en production ; les 40 fichiers sont envoyés au porteur quand les figures y sont.

---

## Lot P — Le prompt de rédaction pour toutes les matières

- **Couche**       : contenus (documentation)
- **Fichiers**     : `docs/contenus/prompt-redaction.md`
                     `docs/contenus/prompt-redaction-lot.md`
- **Dépend de**    : —
- **Test associé** : `test/script/contenus/valider_test.rb` (inchangé, doit rester vert : le prompt ne change aucune règle de format)
- **Done quand**   : le prompt dit, pour chacune des 5 matières, ce que deviennent « La méthode » et « Un exemple corrigé », la forme des 4 problèmes (type interrogation, devoir, BEPC), la règle « la moitié des questions au moins corrigées automatiquement » (FR, HG, EDHC), le corrigé modèle et le barème des questions rédigées, la fidélité à la progression nationale, les textes originaux ou du domaine public (Français), la neutralité et les sources des sujets sensibles (HG) ; et `prompt-redaction-lot.md` prend une matière en entrée au lieu des seules mathématiques

---

## Lot FR — Les 10 leçons de Français de 3ème

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/francais/*.json` (10 fichiers v3 ; les 3 fichiers v1 du même intitulé sont remplacés)
- **Dépend de**    : Lot P
- **Test associé** : `ruby script/contenus/valider.rb` sur chaque fichier ; part corrigée automatiquement vérifiée par une commande ponctuelle (l'avertissement permanent arrive au Lot 0)
- **Done quand**   : les 10 intitulés exacts de la progression ont leur fichier ; le script sort sans erreur ni avertissement ; la relecture IA indépendante est faite ; ≥ 50 % de questions corrigées automatiquement par leçon ; aucune figure ; un fichier importé en brouillon sur `Develop` affiche sa fiche de révision

---

## Lot 0 — Socle des figures

- **Couche**       : domaine (contrats) + UI (liste blanche) + contenus (script, prompt)
- **Fichiers**     : `app/domain/entities/catalog/figure_kinds.rb`
                     `app/domain/entities/catalog/figure_catalogs.rb` *(nouveau : planches → parties, fonds → aires et lieux)*
                     `app/domain/entities/catalog/figure.rb`
                     `app/javascript/controllers/figure_controller.js` *(KINDS, RANGE_PARAMS)*
                     `script/contenus/valider.rb` *(require du catalogue ; avertissement « moins de la moitié des questions corrigées automatiquement »)*
                     `docs/contenus/prompt-redaction.md` *(section des 6 sortes nouvelles et de la courbe : formes, listes fermées)*
                     `test/domain/entities/catalog/figure_test.rb`
                     `test/domain/entities/catalog/figure_catalogs_test.rb`
                     `test/script/contenus/parite_import_test.rb`
                     `test/script/contenus/valider_test.rb`
                     `test/javascript/figures_structure_test.rb`
- **Dépend de**    : Lot P (même fichier `prompt-redaction.md`, en séquence)
- **Test associé** : `test/domain/entities/catalog/figure_test.rb` (une figure bien formée par sorte ; chaque incohérence de l'ADR §4.2 → `figure_invalid`) · `test/script/contenus/parite_import_test.rb` (mêmes raisons et chemins import ↔ script)
- **Done quand**   : un fichier portant une figure de chaque sorte nouvelle, bien formée, passe l'import en brouillon sur l'environnement local et `valider.rb` ; chaque incohérence est refusée des deux côtés au même chemin ; le contrôleur liste les 11 sortes. **Les contrats sont gelés** : un lot qui a besoin de changer une forme, une borne ou une liste fermée s'arrête et le Lot 0 rouvre

---

## Lot A — Frise chronologique

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/timeline.js`
                     `test/system/catalog/figure_timeline_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_timeline_test.rb`
- **Done quand**   : dans une fiche de révision, une frise (périodes, événements en quinconce, unité « jour » et « année ») est `ready`, ses curseurs `start`/`end` la zooment, aucun libellé ne se chevauche à 390 px

## Lot B — Carte et fonds de carte

- **Couche**       : UI + contenus (script de fabrication)
- **Fichiers**     : `app/javascript/lib/figures/map.js`
                     `app/javascript/lib/figures/maps/cote_d_ivoire.js` · `maps/africa.js` · `maps/world.js`
                     `script/contenus/fonds_de_carte.rb`
                     `test/javascript/map_bases_parity_test.rb`
                     `test/system/catalog/figure_map_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/javascript/map_bases_parity_test.rb` (identifiants du domaine = identifiants des fonds ; ≤ 150 Ko par fond) · `test/system/catalog/figure_map_test.rb`
- **Done quand**   : une carte de chacun des 3 fonds est `ready` avec aires catégorisées (teinte + motif), lieux, flux et légende ; un lieu inconnu côté navigateur → `error`, description visible

## Lot C — Schéma fléché

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/diagram.js`
                     `test/system/catalog/figure_diagram_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_diagram_test.rb`
- **Done quand**   : un schéma `flow`, un `tree` et un `cycle` sont `ready`, mise en page calculée sans chevauchement à 390 px, libellés d'arêtes lisibles

## Lot D — Tracé optique

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/optics.js`
                     `test/system/catalog/figure_optics_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_optics_test.rb`
- **Done quand**   : une lentille convergente puis divergente est `ready` ; déplacer le curseur de la distance de l'objet change OA' et γ affichés et les annonce ; le mode œil montre myopie, hypermétropie et leur correction

## Lot E — Planches légendées

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/plate.js`
                     `app/javascript/lib/figures/plates/*.js` *(un module de dessin par planche, 11 planches de l'ADR §4.2)*
                     `test/javascript/plates_parity_test.rb`
                     `test/system/catalog/figure_plate_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/javascript/plates_parity_test.rb` (planches et parties du domaine = celles des modules) · `test/system/catalog/figure_plate_test.rb`
- **Done quand**   : les 11 planches sont `ready` en `names` et en `numbers`, parties surlignées, traits de rappel sans chevauchement ; une planche inconnue → `error`, description visible ; captures envoyées au porteur pour relecture par un enseignant

## Lot F — Molécule

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/molecule.js`
                     `test/system/catalog/figure_molecule_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_molecule_test.rb`
- **Done quand**   : un alcane en formule développée, semi-développée et brute est `ready` ; le curseur `carbons` met à jour la chaîne et le nom (méthane à décane) et l'annonce ; une molécule `custom` (eau, dioxygène) se dessine

## Lot G — Courbe

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/stat_chart.js`
                     `test/system/catalog/figure_line_chart_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_line_chart_test.rb`
- **Done quand**   : un `stat_chart` `line` est `ready` (points reliés, étiquettes d'abscisse, valeurs) ; les graphiques `bars`, `histogram`, `pie` existants restent inchangés (`test/system/catalog/figure_kinds_test.rb` vert)

---

## Lots SVT, PC, HG, EDHC — Les 10 leçons de chaque matière

Quatre lots de même forme, un par matière (`<matiere>` = `svt`, `physique-chimie`, `histoire-geographie`, `edhc`).

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/<matiere>/*.json` (10 fichiers v3 ; les fichiers v1 du même intitulé sont remplacés, les autres v1 de 3ème retirés)
- **Dépend de**    : Lot 0 (les figures se valident par le domaine ; leur dessin est vérifié par le challenger une fois les lots A à G fusionnés)
- **Test associé** : `ruby script/contenus/valider.rb` sur chaque fichier
- **Done quand**   : les 10 intitulés exacts de la progression ont leur fichier ; le script sort sans erreur ni avertissement ; la relecture IA indépendante (calculs en PC, faits et dates en HG et EDHC, exactitude scientifique en SVT) est faite ; les figures sont celles de l'inventaire de l'ADR §4.1

---

## Lot Z — Clôture

- **Couche**       : tests + contenus
- **Fichiers**     : `test/script/contenus/lecons_3eme_test.rb` *(nouveau : chaque matière a ses 10 leçons v3, intitulés exacts de la progression, toutes valides)*
                     `test/system/catalog/figure_kinds_test.rb` *(une figure de chaque sorte dans une même fiche)*
                     `docs/contenus/README.md`
- **Dépend de**    : tous les lots
- **Test associé** : `test/script/contenus/lecons_3eme_test.rb`
- **Done quand**   : une fiche portant une figure de chacune des 11 sortes s'affiche, toutes `ready`, à 390 px et sur ordinateur (captures envoyées) ; le README des contenus liste les 50 leçons

---

## Dispatch

```
Vague 1 : Lot P                                   → 1 agent (orchestrateur)
Vague 2 : Lot FR ‖ Lot 0                          → 2 agents (FR : 6 sous-agents de rédaction au plus ; 0 : executant-lot)
Vague 3 : Lots A ‖ B ‖ C ‖ D ‖ E ‖ F ‖ G           → 7 agents executant-lot, worktrees isolés
Vague 4 : Lots SVT ‖ PC ‖ HG ‖ EDHC               → 4 agents, 6 sous-agents de rédaction au plus chacun
Vague 5 : Lot Z, revues, challenger, PR, train    → orchestrateur
```

Le Lot FR et le Lot 0 ne partagent aucun fichier ; FR part en commit direct sur `Develop`, la branche de chantier s'y rebase avant le Lot 0. La vague 4 peut démarrer pendant la vague 3 si la charge le permet : elle ne touche aucun fichier des lots A à G.

Worktrees : `git worktree add ../lnclass-contenus-3e-autres-matieres-lot-<x> -b feature/contenus-3e-autres-matieres-lot-<x> feature/contenus-3e-autres-matieres`, une fois le Lot 0 fusionné dans la branche de chantier.

---

## Vérification de collision

> Deux lots parallèles ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `docs/contenus/prompt-redaction.md` | Lot P, puis Lot 0 (en séquence, jamais en parallèle) |
| `docs/contenus/prompt-redaction-lot.md` | Lot P |
| `app/domain/entities/catalog/figure_kinds.rb` · `figure_catalogs.rb` · `figure.rb` | Lot 0 |
| `app/javascript/controllers/figure_controller.js` | Lot 0 |
| `script/contenus/valider.rb` | Lot 0 |
| `test/javascript/figures_structure_test.rb` | Lot 0 |
| `app/javascript/lib/figures/stat_chart.js` | Lot G |
| `app/javascript/lib/figures/maps/` · `script/contenus/fonds_de_carte.rb` | Lot B |
| `app/javascript/lib/figures/plates/` | Lot E |
| `test/system/catalog/figure_kinds_test.rb` | Lot Z |
| `docs/contenus/README.md` | Lot Z |
| `docs/contenus/lecons-traitees/3eme/<matiere>/` | le lot de la matière |

Contrôle mécanique (`awk … | sort | uniq -d`) : vide hors `prompt-redaction.md`, séquentiel par construction.

---

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

## Rattachement des critères du PRD §4

| Critère | Lot |
|---|---|
| Chaque sorte nouvelle bien formée est acceptée | Lot 0 |
| Une incohérence est refusée des deux côtés | Lot 0 |
| Listes fermées identiques domaine ↔ navigateur | Lots B, E |
| Chaque sorte se dessine dans la fiche | Lots A à G, Lot Z |
| Un curseur redessine la figure | Lot D (et A, F) |
| Un identifiant inconnu côté navigateur ne dessine rien | Lots B, E |
| Modules sûrs et légers | Lot 0 (structure), Lot B (poids) |
| Chaque leçon livrée passe le contrôle | Lots FR, SVT, PC, HG, EDHC |
| Les leçons suivent la progression nationale | Lot Z |
| La moitié des questions au moins corrigée automatiquement | Lot 0 (avertissement), lots de rédaction |

Aucun critère orphelin.

## Challenger empirique — non négociable

Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.

Ici : il importe en brouillon une leçon de chaque matière, ouvre chaque fiche de révision à 390 px et sur ordinateur, vérifie que chaque figure est `ready` et lisible, fait varier un curseur ; puis il importe un fichier dont une carte cite un lieu inconnu et constate le refus `figure_invalid`.
