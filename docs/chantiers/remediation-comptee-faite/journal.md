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

## Clôture

| | |
|---|---|
| **Livré le** | — (commité le 2026-10-04 : `7b428c07` index, `813b3b90` correctif ; non poussé) |
| **PR** | |
| **ADR produits** | aucun ; compléments datés de 0065 §4, 0072 (ter), note de 0067 (levier 1) |
| **UDR produits** | |
