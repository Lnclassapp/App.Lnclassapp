# Journal — Une remédiation compte comme exercice fait

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | L'index garde son nom `index_exercise_sessions_handed_in` : construit sous un nom provisoire, ancien retiré, puis renommé, tout en `CONCURRENTLY` | Les ADR 0067 et 0072 et le PRD de `fonctions-espace-eleve` le citent par son nom ; les pages ne sont jamais sans index | Note du 2026-10-04 de l'ADR-0067 |
| 2026-10-04 | Sur la copie de mesure, 14 698 sessions deviennent des remédiations avant la mesure « avant » | Le jeu n'en contient aucune : mesurer sans remédiation ne mesure que la reconstruction de l'index | Non (protocole, [plan](plan.md#protocole)) |
| 2026-10-04 | « Anciens élèves » ajouté à `script/perf/measure_screens.rb` (`admin_departed_students`) | Écran touché par le correctif, budgeté par l'ADR-0067 (« direction »), absent du script | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Le brief annonçait des remédiations dans la base de mesure** (`app_lnclassapp_perf_rapports_lot_c`) : il n'y en a aucune. `script/perf/dataset.rb` sème 86 944 lacunes en attente mais toutes ses sessions en `standard`, ce qu'ADR-0043 rend impossible. Découvert à la copie, avant toute mesure ; corrigé sur la copie seulement.
- **Première mesure « avant » interrompue** : avec `PERF_ONLY=admin`, « Anciens élèves » (8,7 s par requête × 33) faisait durer chaque exécution plus de 5 minutes. Mesure relancée en deux temps : les trois écrans du protocole (3 × 30), puis « Anciens élèves » seul (`PERF_RUNS=5`).
- **`db:drop` en développement supprime aussi la base de test** du worktree : elle a été rechargée ensuite par `RAILS_ENV=test bin/rails db:drop db:create db:schema:load`, comme prévu.
- **`db/schema.rb` bruité** : sous PostgreSQL 16, `db:migrate` réécrit toutes les contraintes `ANY (ARRAY[…])`, même depuis une base migrée de zéro. Seules la version et la ligne de l'index sont gardées, prises telles quelles dans le dump (même parade que `import-drenas` et `inscription-direction`).
- **Bruit de mesure** : sur cette machine partagée, l'écran témoin non touché varie de +13 % en p95 entre deux séries. L'écart de « Travail des élèves » (+17 ms p50) n'est donc pas lisible à l'écran ; il a été isolé par un A/B alterné de la seule requête des totaux (+2 ms p50).
- **Pas de reproduction à la main dans le navigateur** : la reproduction passe par un test de contrôleur sur la vraie page (rouge, puis vert). Le rejeu dans l'application revient au challenger.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Pourquoi aucun test n'avait vu le bug** : les tests des deux queries affirmaient le contraire (« B's remediation at 100 » écartée de DS-09 ; une remédiation rattachée à une assignation qui « ne compte pas » dans `DepartedStudentsQueryTest`). Ils transcrivaient l'ADR-0065 §4 et l'ADR-0072 §4.4, écrits avant que `StartExerciseSession#new_session` n'ouvre une remédiation sur **tout** exercice d'une fiche à lacune en attente, rattachée à l'assignation. Aucun test ne jouait le scénario réel : X raté, puis Y assigné fait pendant la lacune.
- `index_exercise_sessions_handed_in` sert aussi `DepartedStudentsQuery#totals` (*Index Only Scan* puis filtre sur l'élève), et `Queries::Classroom::AssignmentFollowUpQuery` sur `Develop` (qui filtre encore `kind = 'standard'` : sa condition implique celle du nouvel index, il reste servi). `grep kind app/infrastructure` ne montre aucun autre lecteur.
- Le coût de « Travail des élèves » n'est pas dans la lecture des sessions (≈ 9 ms en *Index Only Scan*) mais dans l'agrégat et le tri des ≈ 23 000 couples élève × devoir de l'établissement, et dans la jointure `users` (22 792 boucles) pour exclure les comptes anonymisés.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| « Anciens élèves » de la direction : **8,7 s** p50 au volume de l'ADR-0067, dans la requête de la liste (`JOIN LATERAL` de la dernière classe sur tous les élèves, `NOT EXISTS` de présence), pas dans les totaux | Hors périmètre (requête que ce chantier ne touche pas) ; l'écran n'était pas dans `measure_screens.rb` | `optimize` à ouvrir — **priorité haute** |
| « Travail des élèves » hors budget : 230 ms p95 **avant** ce chantier (budget 100 ms, que l'ADR-0067 donnait tenu) ; SQL ≈ 100 ms | Antérieur au correctif, qui n'y ajoute que ≈ 2 ms | `optimize` à ouvrir (agrégat élève × devoir, jointure `users`), à remesurer sur machine peu chargée |
| « Enseignants » de la direction : 441 Ko de HTML (budget 150 Ko), 122 ms p95 | Écran non touché | `optimize` à ouvrir |
| `script/perf/dataset.rb` ne sème aucune session de remédiation | Hors périmètre ; la copie de mesure a été corrigée à la main (requête dans [plan § Protocole](plan.md#protocole)) | À reprendre dans le prochain chantier qui touche le jeu de mesure |
| Glossaire, « Rendu en retard » : « (standard, rattachée à l'assignation) » | Définition côté enseignant, corrigée par `rapports-exercices` | `rapports-exercices` |
| Conflit attendu à la fusion avec `feature/rapports-exercices` : les deux branches ajoutent un complément en fin d'ADR-0072 (bis, puis ter) | Les deux chantiers sont ouverts en parallèle depuis `Develop` | Résolution à la fusion : garder les deux, dans l'ordre |

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Rapport du challenger

Rejeu empirique du memo dans l'application (2026-10-04), en navigateur (Chrome sans tête), sans relire le code : `test/system/school_admin/remediation_handed_in_test.rb`. Le parcours de l'élève et la lecture de la direction passent par l'interface ; le reste de la classe est posé par les fabriques.

| Étape | Résultat | Preuve |
|---|---|---|
| 1. Données du memo : 3ème B (classe principale, active), X et Y de la même fiche, assignés | OK | Fabriques ; 4 camarades rendent X à 60 % (la moyenne de classe ne s'affiche qu'à partir de 5 élèves ayant rendu) |
| 2. L'élève, dans l'interface : X raté, puis Y démarré, puis réussi | OK | « Commencer l'exercice », puis les questions une à une. X : 1 / 3, soit 33 %, session `standard` rattachée à l'assignation de X, puis lacune `pending` dont la source est cette session. Y démarre en `remediation`, `knowledge_gap_id` = cette lacune, rattachée à l'assignation de Y (lu en base). Y : 2 / 2, soit 100 % |
| 3. La direction : « Travail des élèves », puis 3ème B | OK | Ligne 3ème B : 6 élèves, 2 devoirs, **50 %** (6 / 12), **62 %** ((33 + 100 + 4 × 60) / 6 = 62,2). Page de la classe : tuiles 2 · 50 % · 62 % ; Aya **2 / 2**, **67 %** ((33 + 100) / 2 = 66,5) |
| 4a. Remédiation commencée, non terminée | OK | Moussa (lacune sur la fiche, Y démarré en remédiation sur l'assignation) : 0 / 2, « — » ; il ne change pas le taux (7 / 12 donnerait 58 %) |
| 4b. Élève d'une autre classe | OK | Koffi (3ème A) : sa remédiation à 100 % sur l'assignation de Y de **sa** classe donne la ligne 3ème A (1, 1, 100 %, « — ») ; une session parasite qu'il porte sur l'assignation de la 3ème B ne bouge pas la 3ème B et son nom n'y apparaît pas |
| 5. Rouge sur le code d'avant | OK | Condition `exercise_sessions.kind = 'standard'` remise à la main dans `HANDED_IN`, puis le fichier restauré par `git checkout` : échec ligne 71, `Expected: ["6", "2", "50 %", "62 %"]`, `Actual: ["6", "2", "42 %", "55 %"]` (5 / 12, 273 / 5). La partie élève passe, seule la lecture de la direction casse : le bug du memo, pour la bonne raison |
| 6. Budget système | OK | 9,3 s enregistrées (`script/ci/test_timings.yml`, bannière Puma retirée du log), entre 8,6 et 9,4 s sur 4 exécutions ; `COVERAGE=0 bin/rails test test/guards` : 25 runs, 0 échec |

**Écart avec le memo, voulu** : le memo joue X à 25 % (4 questions) et Y à 80 % (5 questions). Ces 9 questions faisaient peser le test entre 10,4 et 10,9 s, au-delà du budget de 10 s. Avec 3 et 2 questions (33 % et 100 %), le scénario reste le même : X raté sous 50 %, lacune, Y en remédiation, réussi.

**Défauts trouvés** : aucun dans le correctif. Deux observations, sans correction de code applicatif :

- Le score d'une session est **tronqué**, pas arrondi : 1 / 3 donne 33, et 2 / 3 donne **66** (attendu 67 au premier jet). Les moyennes de la direction arrondissent au demi supérieur (66,5 donne 67 ; 52,5 donne 53 dans le test de contrôleur). C'est antérieur au chantier et hors périmètre. À confirmer avec le porteur : la troncature est-elle voulue ?
- Ce journal contient **deux sections « Dette laissée derrière »**. La seconde est le gabarit vide : elle est à retirer à la clôture.

**Non rejoué en navigateur** : « Anciens élèves » (`DepartedStudentsQuery`). Le memo le cite dans le symptôme, mais l'étape 4 de sa reproduction ne passe que par « Travail des élèves ». Il reste couvert par `DepartedStudentsQueryTest`.

La porte « Bug reproduit à la main dans l'application » n'avait pas été franchie avant le correctif (voir *Ce qui a dérapé*). Elle l'est maintenant après coup, par ce rejeu rouge sur le code d'avant.

## Clôture

| | |
|---|---|
| **Livré le** | — (commité le 2026-10-04 : `7b428c07` index, `813b3b90` correctif ; non poussé) |
| **PR** | |
| **ADR produits** | aucun ; compléments datés de 0065 §4, 0072 (ter), note de 0067 (levier 1) |
| **UDR produits** | |
