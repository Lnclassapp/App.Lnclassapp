# Journal — Le niveau pr joue les tests système qui exécutent le code touché

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-10 | Carte tracée par la couverture (option B), pas carte statique | Les tests cassés passaient par une query, une concern, une entité : aucune règle de nommage ne les voit, la couverture si | ADR-0127 |
| 2026-11-10 | Budget de 240 s de durée enregistrée, poids 1/n par fichier, les tests modifiés toujours joués | Tenir la tâche sous 5 min (ADR-0107 moteur 5) ; un layout touché ne doit pas rejouer la suite | oui |
| 2026-11-10 | Le test nommé d'après l'écran changé pèse 1 de plus | Sans lui, `session_result_test` partait au train sur #529 (1/18 de `session_results/show`, derrière des tests touchés par plus de fichiers) | oui |
| 2026-11-10 | Carte en positions (`files: "0 3 17"`) | En YAML plat, 984 Ko et 20 000 lignes ; en positions, 130 Ko et une ligne par fichier | non |
| 2026-11-10 | `SYSTEM_SCOPE=former` garde la sélection d'avant | Pour rejouer l'historique et pour le test de reproduction | non |

## À trancher

- [ ] 2026-11-10 · ci-scope-tests-systeme · Qui retrace la carte `script/ci/system_map.yml` — appliqué : à la main à chaque promotion, `script/ci/record_system_map` (7 min, 4 cœurs), noté dans `docs/workflows/README.md` ; autres : une tâche GitHub qui trace la carte au train (couverture ajoutée à six parts déjà à ≈ 167 s sous un plafond de 300 s, non mesuré), une garde qui refuse une carte de plus de N jours ; recommandé : mesurer le surcoût sur une part GitHub avant de l'automatiser.
- [ ] 2026-11-10 · ci-scope-tests-systeme · Budget du niveau pr à 240 s enregistrées — appliqué : 240 s (1 min 54 s d'horloge pour les 24 fichiers choisis sur #529, 2 processus, 4 cœurs) ; autres : 300 s (attrape plus sur une PR large, risque sur un poste lent) ; recommandé : 240 s, relevé après un mois de rejeu si des tests « laissés au train » cassent.

## Ce qui a dérapé

- Premier rejeu : un fichier hors carte sans route renvoyait `nil` (`share.each` sur nil) ; corrigé avant le test d'historique, et testé (« a file nothing reaches selects nothing and is named »).
- `script/docs/build_index --number` numérote toutes les décisions en attente de la branche : sur `Develop`, 3 ADR et 9 UDR d'autres chantiers sont encore en `XXXX-` ; numéroté seul l'ADR du chantier (les autres mis de côté le temps de la commande).
- Le rejeu du worktree a d'abord échoué : `config/database.yml` suffixe la base de test par le nom du dossier (`app_lnclassapp_test_wt`), à créer avant.
- Premier format de carte trop lourd (984 Ko) : passé en positions.

## Ce qu'on a appris sur la codebase

**Rapport root cause.**

1. Chaîne : `bin/ci-quiet` niveau `pr` → étape « Tests: System (bin/system-changed) » → `bin/system-changed` → sélection par `resource_of` + `visiting` (`bin/system-changed:33-43` sur `cca607f`) → `bin/rails test <fichiers>`.
2. Cause : `bin/system-changed:40` (`visiting`) choisit un test système par le nom du helper de route de la ressource d'une vue ou d'un contrôleur changé. Trois trous :
   - une query, une entité, une concern, un helper n'ont pas de route : `direction_home_query.rb` (#530), `reads_own_level.rb` (#524) ne choisissent rien ;
   - le motif `(?<![\w.])departed_students?_path` refuse une route d'espace de noms (`school_admin_departed_students_path`, précédé de `_`) ;
   - une feuille de style ne choisit que `COMMON` (`bin/system-changed:13,50`).
3. Trou de test : aucun test ne couvrait `bin/system-changed` (pas de `test/bin/system_changed_test.rb`, pas de cas dans `ci_scope_test.rb`) ; l'ADR-0107 §5 consentait « une régression hors du périmètre se découvre au train » sans mesurer ce périmètre.

En une phrase sans le symptôme : la sélection devinait l'usage d'un fichier par son nom au lieu de lire ce que chaque test exécute.

**Qui a cassé quoi** (rejeu de chaque test sur la tête de `Develop` après chaque fusion, worktree, 2026-11-10) :

| Test système | Vert sur | Rouge dès | PR fautive |
|---|---|---|---|
| `catalog/sheet_cards_test.rb` | `44a6831^` | `44a6831` | #492 |
| `classroom/teacher_first_path_desktop_test.rb` | `f8a8a11` | `8e00053` | #524 (B-046) |
| `school_admin/departed_students_test.rb` | `c98cd00` | `2890e95` | #530 |
| `school_admin/direction_home_test.rb` | `c98cd00` | `2890e95` | #530 |
| `school_admin/remediation_handed_in_test.rb` | `c98cd00` | `2890e95` | #530 |
| `assessment/session_result_test.rb` | `b666f29` | `bde159c` | #529 |

**Mesure** — `HEAD_REF=<tête PR> BASE=<Develop avant> bin/system-changed --list`, avec et sans `SYSTEM_SCOPE=former` ; carte tracée sur `cca607f` (biais : la carte est postérieure aux PR ; les fichiers changés existent tous encore).

| PR | Avant : fichiers, s enregistrées | Le test cassé, avant | Après : fichiers, s | Le test cassé, après |
|---|---|---|---|---|
| #492 | 15 · 151 s | `sheet_cards` ❌ | 26 · 240 s | ✅ |
| #524 | 39 · 432 s | `teacher_first_path_desktop` ❌ | 19 · 240 s | ✅ |
| #530 | 22 · 299 s | `departed_students`, `direction_home`, `remediation_handed_in` ❌ ❌ ❌ | 23 · 240 s | ✅ ✅ ✅ |
| #529 | 34 · 374 s | `session_result` ❌ | 24 · 240 s | ✅ |
| #528 | 5 · 46 s | — | 20 · 240 s | — |
| #531 | 2 · 15 s | — | 30 · 236 s | — |
| #534 | 1 · 7 s | — | 19 · 142 s | — |
| #532 | 0 · 0 s | — | 26 · 219 s | — |

6 tests cassés sur 6 attrapés par la PR fautive, contre 0 sur 6 avant. La sélection d'avant dépassait déjà 240 s sur 3 PR sur 8 (432 s pour #524) sans rien attraper ; la nouvelle ne dépasse jamais 240 s.

**Test de reproduction** : `test/config/system_scope_test.rb`, joué avec `SystemScope#select` remplacé par la règle d'avant (`#former`) : 8 échecs sur 9, chacun « Expected [design_system, role_homes] to include … » ou sélection vide ; vert avec la carte.

- Les tests système tournent dans le même processus que le serveur Puma de Capybara : la couverture de lignes et `render_*.action_view` voient le code de l'application, fabriques comprises.
- Avec `CI=true`, tout est chargé avant le premier test : une ligne comptée pendant un test est une ligne exécutée, pas un fichier chargé. La couverture doit démarrer avant Bundler (`RUBYOPT`), sinon l'eager load lui échappe.
- `test/system/catalog/lesson_capture_test.rb` ne s'exécute pas hors de sa tâche : il n'est pas dans la carte (153 fichiers sur 154).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Tests unitaires hors miroir (FAQ `help_controller_test`, empreinte `standard_activity_test`, cassés par #534) | `CiScope.tests_for` ne suit ni une locale vers son contrôleur, ni une entité vers les seeds | à ouvrir : la même carte, tracée sur la suite unitaire |
| Retracé automatique de la carte | Surcoût non mesuré sur les parts GitHub | À trancher ci-dessus |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0127 |
| **UDR produits** | — |
