# Memo — Dettes du chantier « réorganisation équipe / enseignant »

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `Develop` (directement, comme le chantier d'origine, décision du porteur du 2026-10-03) |
| **Programme** | — |

---

## Le problème

Le journal de [`reorganisation-equipe-enseignant`](../reorganisation-equipe-enseignant/journal.md#dette-laissée-derrière) a laissé quatre écarts entre ce que disent les décisions et ce que fait l'application. Le porteur demande de les corriger tous les quatre (« Fix les 4 dettes », 2026-10-04). Chacun est un bug distinct, avec son symptôme, sa reproduction et son test rouge. Ils forment chacun un lot (voir [`plan.md`](plan.md)).

### Bug 1 — Le toast d'assignation finit par deux points

- **Symptôme** : l'enseignant lit « Les phases ajouté à Tle D 1, à rendre jeudi 8 oct.. ».
- **Attendu** : « … à rendre jeudi 8 oct. » ([UDR-0062](../../decisions/udr/0062-echeances.md) §3.4, mot pour mot).
- **Reproduction** :
  1. Enseignant de « Tle D 1 », dont les jours de séance sont connus.
  2. Il assigne un exercice le lundi 5 octobre 2026 ; l'échéance est le jeudi 8.
  3. Le toast affiche « oct.. ».
  - Reproduit le 2026-10-04 par `I18n.t("classroom.assignments.create.done_due", …)` : « Méiose ajouté à 6ème 1, à rendre jeudi 8 oct.. ».
  - Déjà observé dans l'application par le challenger du chantier d'origine.
  - Avec un mois sans abréviation, la phrase est juste : « jeudi 6 mai. ».
- **Portée** :
  - Depuis l'échéance des exercices (ADR-0072, 2026-10-01).
  - Tout enseignant qui assigne quand le mois de l'échéance est abrégé : janv., févr., avr., juil., sept., oct., nov., déc.
  - Seul le texte du toast est faux ; aucune donnée en base.

### Bug 2 — Le jeu de mesure des écrans lourds ne se sème plus

- **Symptôme** : `PERF=1 bin/rails test test/performance/school/heavy_screens_budget_test.rb` s'arrête sur `PG::CheckViolation` (`classroom_assignments_type_values`) avant toute mesure.
- **Attendu** : le jeu se sème et les budgets se mesurent ([ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md), test de budget, « avant chaque recette »).
- **Reproduction** : `PERF=1 COVERAGE=0 bin/rails test test/performance/school/heavy_screens_budget_test.rb`, sur la base de test, rejoué le 2026-10-04 : `ActiveRecord::CheckViolation … violates check constraint "classroom_assignments_type_values"`, ligne `Essential`, après 44 s.
- **Portée** :
  - Depuis la migration `20261003100000_restrict_classroom_assignments_to_exercises` (« seul l'exercice s'assigne », ADR-0072, 2026-10-03).
  - Aucun acteur touché : c'est un outil de mesure de l'équipe de développement.
  - Aucune donnée en base.

### Bug 3 — Les énoncés de démonstration s'affichent avec leurs balises

- **Symptôme** : en développement, l'exercice « Reconnaître la membrane » affiche « <p>La membrane plasmique délimite la cellule.</p> » tel quel, balises comprises.
- **Attendu** : un énoncé est du **texte brut**. Il se saisit dans une zone de texte ([UDR-0017](../../decisions/udr/0017-formulaire-exercice.md)) et s'affiche échappé, avec ses retours à la ligne (`whitespace-pre-line`, `_question_card`, `_questions_preview`, `_question_review`).
- **Reproduction** :
  1. `bin/rails db:prepare` en développement, sur une base neuve.
  2. Le compte enseignant `0500000001` (PIN 2468) ouvre l'exercice du cours « La cellule ».
  - Reproduit le 2026-10-04 : `Orm::Question.pluck(:content)` donne `["<p>La membrane plasmique délimite la cellule.</p>", "<p>Quel est son rôle principal ?</p>"]`.
- **Portée** :
  - Depuis le premier `db/seeds/development.rb`.
  - Seulement les bases de développement. Le jeu de mesure (`script/perf/dataset.rb`) a le même défaut : énoncés et explications en `<p>`.
  - **Données déjà écrites** : les bases de développement existantes gardent leurs deux énoncés, car les seeds sont idempotents par nom. C'est une dette assumée ; `bin/rails db:reset` les refait. Aucune base de production n'est concernée : ces seeds n'y tournent jamais (ADR-0034).

### Bug 4 — Sous filtre DRENA, en vue « Année scolaire », la somme des établissements peut différer des chiffres de la DRENA

- **Symptôme** : l'équipe filtre le pilotage sur une DRENA, en vue « Année scolaire ».
  - En haut de la page, les chiffres disent 422 élèves.
  - Le tableau « Par établissement » totalise 423, pendant au plus 5 minutes après un changement.
- **Attendu** : « la somme des établissements listés égale la ligne de la DRENA » ([UDR-0068](../../decisions/udr/0068-configuration-et-pilotage-par-etablissement.md) règle 8, critère RE-08).
- **Reproduction** :
  1. En vue « Année scolaire », sous filtre DRENA, ouvrir le pilotage.
  2. Inscrire un élève dans une classe d'un établissement de cette DRENA.
  3. Recharger : le tableau compte l'élève, les chiffres du haut non.
  - Constaté par le challenger du chantier d'origine (2026-10-04) et noté comme coût consenti dans l'amendement du 2026-10-03 de l'[ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md).
  - Le porteur demande de le corriger.
- **Portée** :
  - Depuis le pilotage par établissement (2026-10-03).
  - Les membres de l'équipe, seulement en vue « Année scolaire » et seulement sous un filtre DRENA.
  - Aucune donnée en base.

## Pour qui

| Bug | Acteur touché |
|---|---|
| 1 | L'enseignant (`Teacher`) au moment d'assigner |
| 2 | L'équipe de développement, avant une recette |
| 3 | Quiconque travaille sur une base de développement |
| 4 | L'équipe (`Team`) sur le pilotage filtré |

## Pourquoi maintenant

Les quatre ont été relevés au journal du chantier précédent. Le porteur les veut fermés avant d'ouvrir autre chose. Le bug 2 empêche aussi de mesurer le budget du pilotage, que le correctif du bug 4 doit tenir.

## Hors périmètre

- `ui_copy_button` sans option `full:` et l'entrée courante du menu « Plus » sans style propre : ce sont des finitions visuelles du journal d'origine, pas des bugs.
- Réenregistrer les durées de base du budget système depuis la CI.
- Réécrire les seeds de développement au-delà des énoncés : le contenu des cours et des fiches est du texte riche, son HTML est juste.
- Tout autre format de date des échéances : `due_short`, `due_long` et les badges sont justes.
- Le cache de la vue nationale « Année scolaire » : il reste. Aucun tableau d'établissements n'y est lu, il n'y a donc rien à aligner.

## Ce que le grill a révélé

Un memo de bug n'est pas grillé : il est reproduit (`docs/workflows/bugfix.md`, modulateur d'équipage). Les questions propres au cycle ont été posées sur le code.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document fixe le comportement attendu ? | 1 : UDR-0062 §3.4. 2 : ADR-0067 et le test de budget. 3 : UDR-0017 et les vues d'exercice. 4 : UDR-0068 règle 8 et RE-08 | Ce sont des bugs, aucun n'est une spec manquante |
| Le correctif exige-t-il une colonne, un port ou une règle métier nouvelle ? | Non pour les quatre | Bugfix, pas feature |
| Multi-appartenance (élève de plusieurs classes ou écoles) ? | Bug 4 : un élève n'est compté qu'une fois, par sa classe principale, dans les deux lectures (ADR-0040). Les bugs 1 à 3 n'en dépendent pas | Le test de reproduction du bug 4 garde un élève à deux classes |
| D'autres acteurs passent-ils par le même chemin ? | Bug 1 : l'équipe n'assigne pas. Bug 4 : seule l'équipe lit le pilotage | Rien de plus |
| Des données fausses en base ? | Bug 3 seulement, sur les bases de développement existantes | Dette assumée, `db:reset` (journal) |
| Bug 4 : mettre le tableau en cache, ou tout lire en direct ? | Deux entrées de cache, remplies à deux instants, ne s'alignent pas. Tout lire en direct sous filtre referait payer à la vue « année » le coût qui croît avec les sessions de l'année, et que le cache du 2026-09-29 évite : la sous-requête des élèves actifs parcourt toutes les sessions de la période, quel que soit le filtre | Une seule lecture : sous filtre DRENA, les lignes de **tous** les établissements de la DRENA sont calculées avec les chiffres, dans la même entrée de cache en vue « année » (en direct en 7 et 30 jours) ; la recherche et les pages se font sur ces lignes (amendement du 2026-10-04 de l'ADR-0062) |

## Cas limites identifiés

- Bug 1 : les mois sans point abréviatif (mars, mai, juin, août) gardent leur point final.
- Bug 4 :
  - La vue nationale « Année scolaire » garde son cache, inchangé ; seule l'entrée filtrée porte en plus les lignes d'établissements.
  - La recherche lit les noms en direct (même `TextSearch`) et ne garde que les établissements de l'instantané : un établissement créé depuis, ou un nom changé, apparaît à l'expiration. C'est le même retard de 5 minutes que les chiffres, sur la même page.
  - En passant de la vue nationale à une DRENA, la ligne de la DRENA et la page filtrée sont deux entrées, remplies à deux instants : elles peuvent différer pendant 5 minutes. Deux pages, accepté (amendement ADR-0062).
  - Une DRENA inconnue lit la vue nationale, comme avant, sans tableau d'établissements.
  - La forme des chiffres gardés change : `CACHE_VERSION` passe à 2, les anciennes entrées ne sont plus lues.

## Questions encore ouvertes

- Aucune.

## Portes de sortie (bugfix, une par lot dans `plan.md`)

Voir [`plan.md`](plan.md).
