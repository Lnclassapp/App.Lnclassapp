# Journal — Barème des classes modifiable par l'équipe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | ADR-0058 et UDR-0045 (« plus haut + 2 ») ; 0057 et 0044 laissés libres | Deux chantiers parallèles pouvaient prendre le numéro suivant | Oui — noté dans l'ADR et l'UDR |
| 2026-09-28 | Une ligne par (type, niveau, série nulle au premier cycle) ; ligne absente = 0, « Non défini », comptée sautée (D1 du memo) | Plus de règle cachée « par série » ; l'oubli se voit à l'écran et au rapport | Oui — ADR-0058 §4 |
| 2026-09-28 | La reprise est une migration de données autonome (constante de l'ancien barème recopiée, `INSERT … SELECT … ON CONFLICT DO NOTHING`), appelée aussi par les seeds et par `seed_referential` | Une migration ne dépend pas du code applicatif ; seeds et tests obtiennent exactement le barème de la production | Oui — ADR-0058 §4 |
| 2026-09-28 | Clés étrangères `RESTRICT`, lignes effacées par `TaxonomyRepository#delete_level/#delete_series` | `test/db/schema_constraints_test.rb` refuse toute cascade hors de la liste fermée de l'ADR-0036 — premier choix (`CASCADE`) rouge | Oui — ADR-0058 §4 |
| 2026-09-28 | Un niveau du second cycle sans série est compté sauté **quel que soit son code** | Conséquence du barème par identifiant ; le test du job a rougi (5 niveaux créés à la volée par la fabrique `create_classroom`, comptés pour 3 lycées) | Oui — ADR-0058 §4 et coûts |
| 2026-09-28 | Badge de l'écran Niveaux : « Hors barème » (aucun nombre positif, au premier cycle ou pour un couple lié) | La constante `GENERATED_SLUGS` disparaît avec l'ancien barème | Oui — amendement UDR-0032 |
| 2026-09-28 | Demande du porteur en cours de chantier : génération et barème dans un menu « Classes » à droite de l'import, sur l'écran Établissements | — | Oui — amendements UDR-0043, UDR-0045, UDR-0036 ; BC-11 au PRD |
| 2026-09-28 | Déclencheur libellé « Classes » + chevron (`ui_dropdown trigger:`), pas un ⋮ | UDR-0042 réserve le ⋮ aux actions sur un objet ; celles-ci portent sur toute la liste | Oui — amendement UDR-0043 |
| 2026-09-28 | **D1 décidé par le porteur** : remplissage automatique d'un couple lié (2nde/1ère/autre 6/3 ; Tle C 2/1, D 6/3, A1 3/2, A2 2/2, autre 6/3) et d'un niveau du premier cycle au code connu (4/2, 10/4) ; autre niveau du premier cycle « Non défini » ; jamais d'écrasement ; délier garde les lignes ; audit `source: auto` | Demande explicite du porteur | Oui — amendement ADR-0058, UDR-0045 |
| 2026-09-28 | Remplissage porté par `Entities::Classroom::ClassroomPlanDefaults.fill` (ports reçus en argument), appelé par `LinkLevelSeries` et `CreateLevel` | Un module sous `use_cases/` serait pris pour un use case sans policy par `test/architecture/use_case_policies_test.rb` | Non |
| 2026-09-28 | Merge de `Develop` (#46 finitions, #47 cycles en radio) : génération dans le menu « Classes » avec le toast d'information « déjà en cours » et la redirection vers le rapport de #46 ; amendements UDR-0032/0036/0043 des deux côtés gardés | — | Non |
| 2026-09-28 | Menu « Classes » tenu à droite de l'import dès `sm` par un bloc local `#schools-header-actions` (`sm:shrink-0 sm:flex-nowrap`), sans toucher `ui_page_header` ; au téléphone, le bloc passe à la ligne (import puis menu dessous) | Demande du porteur ; `ui_page_header` partagé par tous les écrans | Non — amendement UDR-0043 |
| 2026-09-28 | **D2 à D5 décidées par le porteur** telles que proposées : mixtes au barème privé, 0 à 30 par ligne, une modale par ligne, pas d'historique à l'écran (journal d'audit) | Confirmation du porteur | Oui — ADR-0058, UDR-0045 |
| 2026-09-28 | Le composant `_dropdown` n'est pas modifié (le déclencheur libellé garde son style « pilule » d'avatar) | Le chantier parallèle `finitions-generation-menu` touche les menus ⋮ ; éviter un conflit sur un composant partagé | Non |

## Ce qui a dérapé

- TDD : premier lancement des tests écrits avant le code → `NameError` au chargement (`Ports::Classroom::ClassroomPlanRepositoryPort`, puis `Entities::Classroom::ClassroomPlan`) ; après le port et les migrations, rouge sur chaque constante et chaque méthode absente ; puis vert.
- `bin/rails db:migrate` (PostgreSQL 16 local) réécrit toutes les contraintes `CHECK` de `db/schema.rb` : le fichier a été remis à l'état de `Develop` puis complété à la main (version, table, deux clés étrangères).
- `0 AND 30` en base, `max: 30` dans le champ : le navigateur refuse 31 avant l'envoi ; le test système du 422 désactive la validation du navigateur (`noValidate`) pour prouver la réponse du serveur.
- Le DTO refusait « 30 » entouré d'espaces (`only_integer` lit la valeur brute) : les nombres sont désormais épurés à la lecture.
- Les tests système de bout en bout (`boucle_pedagogique`, `imports_end_to_end`) partaient d'un référentiel créé sans barème : 0 classe au lieu de 6 et 9. C'est le comportement voulu (D1) : la boucle pédagogique renseigne maintenant Tle D à l'écran du barème avant l'import, les imports de bout en bout reprennent le barème comme au déploiement.
- Un `dropdb` sans mot de passe a attendu une saisie et bloqué une série de tests système pendant 10 minutes ; tué, base supprimée par `psql`.
- Une entrée `stash@{0}` (branche `feature/cycles-en-radio`) existe dans le dépôt partagé : elle n'est pas de ce chantier, elle n'a pas été touchée.

## Mesures (`env PERF=1 COVERAGE=0 PARALLEL_WORKERS=1 bin/rails test test/performance/classroom test/performance/school`, local, PostgreSQL 16, deux passes chacune)

| Cas | `Develop` (avant) | `feature/bareme-classes` (après) |
|---|---|---|
| Génération, 500 établissements, mix du plan (18 091 classes) | 4,7 s · 3,7 s | 3,7 s · 4,4 s |
| Génération, 500 lycées publics (38 500 classes) | 9,3 s · 7,2 s | 8,0 s · 9,0 s |
| Import, 500 établissements, mix (18 091 classes) | 3,6 s · 3,6 s | 3,7 s · 3,7 s |
| Import, 500 lycées publics (38 500 classes) | 7,9 s · 7,9 s | 8,0 s · 8,3 s |

Écarts dans le bruit de la machine : une seule lecture du barème par exécution, aucune requête de plus par lot. Seuil du test inchangé : 60 s pour 500 établissements.

## Ce qu'on a appris sur la codebase

- Les fichiers de `test/support` sont chargés par `test_helper` : un double qui inclut un port inexistant casse **tout** le lancement, pas seulement son test.
- `ui_modal` sans `trigger:` + `ui_dropdown_item dialog:` suffit pour déplacer une confirmation existante dans un menu, sans toucher son contenu ni ses identifiants.
- `test/infrastructure/orm/models_test.rb` compte les modèles `Orm::` : toute nouvelle table l'incrémente.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Le déclencheur libellé d'`ui_dropdown` a le style « pilule » de l'avatar, pas celui d'un bouton secondaire | Composant partagé, chantier parallèle sur les menus | — |
| Aucun écran d'historique des changements du barème (journal d'audit seulement) | Hors périmètre (D5) | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0058 ; amendements ADR-0030, ADR-0056 |
| **UDR produits** | UDR-0045 ; amendements UDR-0018, UDR-0032, UDR-0036, UDR-0043 |
