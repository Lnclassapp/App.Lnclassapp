# ADR-0127 : Au niveau pr, les tests système se choisissent par la carte de ce qu'ils exécutent
<!-- index
titre: Carte des tests système au niveau pr
statut: Accepté
problematique: Le niveau pr de `bin/ci-quiet` (ADR-0107) ne jouait que les tests système modifiés ou nommés d'après la route d'une vue changée : les PR médailles et la feuille de style de #492 ont cassé six tests système sans les jouer. La sélection suit désormais une carte fichier → tests tracée par la couverture, une feuille de style par ses classes, une locale par son dossier, dans un budget de 240 s.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-10 |
| **Chantier** | [`docs/chantiers/ci-scope-tests-systeme`](../../chantiers/ci-scope-tests-systeme/memo.md) |
| **Remplace** | la sélection de `bin/system-changed` décrite à l'ADR-0107 §4 (« les tests système que `bin/system-changed` choisit ») |
| **Amende** | [ADR-0107](./0107-la-preuve-d-une-pr-suit-ce-qu-elle-touche.md) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0107 fait prouver chaque PR par son périmètre ; pour les tests système, ce périmètre était celui de `bin/system-changed` : un test système modifié, un test qui visite la route **nommée** d'après une vue ou un contrôleur changé (`app/views/classroom/student_homes` → `student_home_path`), et deux parcours transverses quand un fichier commun change.

Ce nom ne dit pas ce qu'un test exécute. Du 6 au 9 novembre 2026 :

- les PR médailles (#529, #530, #531, #534) ont changé des queries, des vues, une entité et des locales ; quatre tests système qui rendent ces écrans sous d'autres noms (`direction_home`, `departed_students`, `remediation_handed_in` par #530, `session_result` par #529) et un cinquième cassé par B-046 (#524, `teacher_first_path_desktop`) sont restés rouges sur `Develop` jusqu'au train de #465 (réparés par #535) ;
- #492 n'a changé que deux feuilles de style et trois vues : `sheet_cards_test.rb:60` (« Commencer » décalé à 390 px) a cassé sans être joué (réparé par #495).

Trois trous de la règle d'avant : une query, une entité ou un helper n'ont pas de route ; une route d'espace de noms (`school_admin_departed_students_path`) ne se reconnaît pas par le nom de la ressource ; une feuille de style ne choisit que les deux parcours transverses.

## 2. Moteurs de décision

1. ADR-0107 moteur 1 : ne prouver dans une PR que ce qu'elle peut casser — **tout** ce qu'elle peut casser à l'écran.
2. ADR-0107 moteur 5 : aucune tâche au-delà de 5 minutes ; la suite complète reste au train.
3. Repli prudent : un fichier que la sélection ne sait pas suivre ne choisit jamais moins qu'avant.
4. Mesurable sur l'historique : rejouer une PR passée doit dire ce qu'elle aurait joué.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Carte statique : routes → contrôleurs → vues rendues → constantes appelées | Toujours à jour, sans exécution | Une query appelée par un use case, un partial rendu par un helper, un `render` dynamique : chaque indirection est une règle à écrire, et chaque règle oubliée est un trou silencieux |
| B — **Carte tracée par la couverture des tests système, repli sur les noms** ✅ | Dit ce que chaque test exécute vraiment, indirections comprises ; se retrace en 7 min (4 cœurs) | Vieillit entre deux tracés ; ne voit ni le CSS ni les locales (suivis par leurs noms) |
| C — Toute la suite système au niveau pr | Rien ne passe | 15 à 25 min en local : contraire à l'ADR-0107 |
| D — Tracer la carte à chaque train sur GitHub | Toujours fraîche | Ajoute la couverture aux six parts système, déjà à ≈ 167 s chacune sous un plafond de 300 s : non mesuré, laissé à trancher |

## 4. Décision

> **Au niveau pr, `bin/system-changed` joue les tests système modifiés, et les tests que la carte `script/ci/system_map.yml` dit avoir exécuté un fichier changé, dans un budget de 240 s de durée enregistrée. Ce que la carte ne connaît pas garde la règle d'avant.**

| Fichier changé | Comment il choisit ses tests |
|---|---|
| Ruby d'`app/`, `lib/`, `config/`, vue, partial | La carte : les fichiers de tests système qui ont exécuté au moins une de ses lignes, ou rendu ce template |
| Feuille de style (`app/assets/stylesheets/`) | Les classes des règles que le diff touche (des deux côtés) ; une ligne hors de toute règle de classe (`@import`, variable) compte toutes les classes du fichier. Chaque classe → les vues, helpers et contrôleurs Stimulus qui l'écrivent → la carte |
| Contrôleur Stimulus | Son identifiant (`catalog/revision_more` → `catalog--revision-more`) → les vues et helpers qui l'attachent → la carte |
| Locale `config/locales/<dossier>/<ressource>.fr.yml` | Les vues, le contrôleur et le helper de `<dossier>/<ressource>` dans la carte, et les tests système qui lisent ses clés (`I18n.t("<dossier>.<ressource>.`) |
| Rien de cela (fichier nouveau, jamais exécuté) | La règle d'avant : la route nommée de sa ressource ; nommé « hors carte » par `--list` |
| Fichier commun (composant, shared, layout, helper, CSS, Stimulus) | En plus, `design_system` et `role_homes`, comme avant |

**Le budget.** Chaque fichier changé pèse 1, partagé entre les tests qu'il atteint : un fichier exécuté par un seul test lui donne 1, un layout exécuté par les 153 donne 1/153 à chacun ; une feuille de style partage son poids entre ses classes. Les tests modifiés jouent toujours ; les autres par poids décroissant, tant que la somme de leurs durées enregistrées (`script/ci/test_timings.yml`, secondes GitHub) tient dans **240 s** — 1 min 54 s d'horloge mesurées pour les 24 fichiers choisis sur #529 (2 processus, 4 cœurs). Les tests au-delà sont **nommés** (« laissés au train ») : le train les joue, comme avant.

**La carte.** `script/ci/record_system_map` joue toute la suite système avec `CI=true` (tout chargé avant le premier test) et la couverture de lignes démarrée avant l'application (`RUBYOPT=-rscript/ci/system_map_start.rb`) ; `script/ci/system_map_recorder.rb`, actif seulement sous `SYSTEM_MAP=<dossier>`, note pour chaque test les fichiers dont une ligne a tourné et les templates rendus (`render_*.action_view`). La carte se retrace à chaque promotion vers `Staging`, comme `test_timings.yml`.

## 5. Conséquences

### 🟢 Positives

- Rejouée sur l'historique (journal du chantier, §Mesure), la sélection choisit, sur la PR qui l'a cassé, chacun des tests système que la règle d'avant laissait passer.
- Une query, une entité, un helper ou une concern changés choisissent les tests qui les exécutent, quel que soit leur nom.
- `HEAD_REF=<sha> BASE=<sha> bin/system-changed --list` rejoue une PR passée ; `SYSTEM_SCOPE=former` montre ce qu'aurait choisi la règle d'avant.

### 🔴 Coûts consentis

- **Une PR qui touche un fichier très partagé** (layout, `ApplicationController`, entité des sessions) laisse au train les tests qu'elle touche le moins : le trou se rétrécit, il ne se ferme pas. C'est le prix du plafond de 5 minutes.
- **La carte vieillit** : un test qui se met à rendre un partial après le dernier tracé n'est pas choisi pour ce partial avant le tracé suivant. Un fichier absent garde la règle d'avant, jamais moins.
- `script/ci/system_map.yml` pèse ≈ 130 Ko (1 132 fichiers, une ligne chacun) et change à chaque tracé.
- Une classe CSS construite par interpolation (`"ps-#{kind}"`) n'est pas reconnue dans la vue qui l'écrit : le repli « toutes les classes du fichier » ne la rattrape que si la règle changée est hors classe.
- Les tests **unitaires** hors du miroir (FAQ `help_controller_test`, empreinte `standard_activity_test` de #534) restent hors de cette décision : `CiScope.tests_for` ne lit pas les locales ni les seeds par leur effet.

## 6. Notes d'implémentation

- `script/ci/system_scope.rb` (`SystemScope#select`, `#former`) ; `bin/system-changed` l'appelle, `bin/ci-quiet` aussi par lui, inchangé.
- `script/ci/record_system_map [dossier]` ; `script/ci/system_map_start.rb` ; `script/ci/system_map_recorder.rb`.
- Tests : `test/config/system_scope_test.rb`.

## 7. Comment vérifier que la décision est respectée

`bin/system-changed --list` sur une branche affiche les tests choisis, ceux laissés au train et les fichiers hors carte. La première ligne de `script/ci/system_map.yml` après l'en-tête (`commit:`) dit de quand date le tracé.
