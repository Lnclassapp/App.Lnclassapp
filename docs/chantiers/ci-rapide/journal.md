# Journal — La CI GitHub dure près de 10 minutes

## Mesure après

**Méthode** : identique à la mesure avant ([memo](memo.md#mesure-avant)) : runners GitHub `ubuntu-latest` (2 vCPU), horodatages de l'API et lignes « passed in » de `bin/ci`. Horloge = création du run → dernière mise à jour.

### Horloge d'un run de PR

| Run | Configuration | Horloge | Verdict |
|---|---|---:|---|
| [151](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36398103132) essai 1 | 6 parts système, 3 perf, seeds dans le job unitaire | 2 min 24 | vert |
| 151 essai 2 (relance, même SHA) | idem | 2 min 38 | vert |
| 151 essai 3 (relance, même SHA) | idem | 2 min 36 | rouge : test système instable, voir « Ce qui a dérapé » |
| [157](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36402450175) | configuration finale (seeds avec `perf:1/3`) | 2 min 36 | vert |
| **Médiane** | | **2 min 36 (156 s)** | |

**Avant : 9 min 28 (568 s). Après : 2 min 36 (156 s). Gain : ÷ 3,6.**

PR qui ne touche que la documentation ([run 161](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36405300326), PR jetable #58) : **18 s**, `ci` vert, aucun job de vérification lancé (÷ 31).

### Par étape (run 157, configuration finale)

| Poste | Avant (un job, en série) | Après (job qui le porte, en parallèle) | Job après (démarrage → fin) |
|---|---:|---:|---|
| File d'attente + `changes` | 4 s | 7 s puis 4 s d'attente des jobs | `changes` : 4 s |
| Conteneur PostgreSQL | 23 s | 13 à 26 s, **dans chaque** job de tests | — |
| `apt-get install libpq-dev` | 7 s | **0 s** (déjà dans l'image) | — |
| Checkout + Ruby + Node | 15 s | 13 à 16 s par job | — |
| Setup | 10,4 s | 10 à 13 s par job ; 3 à 4 s sans base (`--skip-db`) | — |
| Gardes + Rubocop | 8,1 s | ≈ 15 s d'étapes (cache Rubocop) | `checks (lint)` : 36 s |
| Audits + Brakeman + budget d'assets | 12,9 s | ≈ 20 s | `checks (security,assets)` : 38 s |
| **Tests unitaires (couverture 100 %)** | 69,8 s | 64 à 75 s (inchangé : même suite, même runner) | **`tests (unit)` : 138 s, chemin critique** |
| **Tests système** | 259,4 s | 6 parts de 52 à 87 s d'étape | `tests (system:k/6)` : 98 à 128 s |
| Seeds | 2,5 s | ≈ 3 s | dans `tests (perf:1/3,seeds)` |
| **Perf d'import** | 137,3 s | 3 parts de 55 à 79 s d'étape | `tests (perf:k/3)` : 97 à 119 s |
| Job final `ci` | — | 3 s (+ 3 s d'attente d'un runner) | `ci` : 3 s |
| **Horloge** | **568 s** | **156 s** | |

Le chemin critique n'est plus une somme mais un maximum : `changes` (7 s) → `tests (unit)` (138 s) → `ci` (6 s). Dans le job unitaire, 64 s seulement sont des tests ; le reste est le plancher d'un job (conteneur, checkout, Ruby, Node, Setup, compilation des assets, démarrage de Rails).

### Suite unitaire (`bin/rails test`), demande du porteur

| Mesure | Avant | Après | Comment |
|---|---:|---:|---|
| GitHub, étape « Tests: Rails » | 69,8 s (médiane de 5) | 64 à 75 s (4 runs, 2 workers) | inchangée : aucun levier retenu, voir ci-dessous |
| GitHub, 4 workers au lieu de 2 | — | 76 s / 60 s (2 runs) | levier H, annulé |
| Local, poste partagé à 4 cœurs | 3 min 03 (dans `bin/ci`, charge 20 à 30) | 1 min 53 (dans `bin/ci`, charge 45) | non comparable : la charge du poste varie d'un facteur 2 |
| Couverture | 100 % lignes, 100 % branches | 100 % lignes, 100 % branches | SimpleCov, suite complète, workers fusionnés |

Profil des 1 898 tests sur GitHub (2 runs, `-v`) : 123 s de temps cumulé sur 2 workers, médiane ≈ 0,06 s par test. Les plus lents :

| Durée | Test | Cause | Levier possible |
|---:|---|---|---|
| 3,5 s | `ProductionConfigurationTest` hosts | démarre l'application en production dans un processus enfant (`EnvironmentProbe`) | aucun sans perdre la preuve « sur un vrai démarrage de production » |
| 3,2 s | `ProductionConfigurationTest` sans variable d'hôte | idem, second démarrage (environnement différent, obligatoire) | idem |
| 3,0 s | `StorageTest` bucket Railway | idem, troisième démarrage | fusionner avec la sonde de production : ≈ 1,5 s d'horloge |
| 2,0 s × 3 | `ProductionConfigurationTest` (santé, `/up`), `StorageTest` sans bucket | idem | idem |
| 1,8 s | `DevelopmentConfigurationTest` | démarrage en développement | aucun |
| 0,77 s | `Assessment::DoubleSubmissionTest` | `sleep 0,5` volontaire : tient un verrou pour prouver la concurrence | aucun sans affaiblir la preuve |
| 0,72 s | `UseCases::Catalog::ImportCourseTreeTest` fichier mixte | import réel d'un arbre | aucun |
| 0,69 s | `Classroom::JoinCapacityTest` | `sleep 0,5` volontaire, verrou | aucun |
| 0,69 s × 2 | `PortContractsTest` | charge tous les ports et adaptateurs | aucun |
| < 0,62 s | les 1 888 autres | — | — |

Vérifications demandées : `BCrypt` est au coût minimal en test (`ActiveModel::SecurePassword.min_cost = true`, empreintes `$2a$04$`) ; aucun `sleep` inutile (les deux pauses de 0,5 s sont la preuve d'un verrou concurrent) ; aucun job n'est joué en ligne hors des tests qui le demandent ; les tests de perf sont hors de la suite (`PERF=1`) et tournent dans leurs propres jobs ; `parallelize(workers: :number_of_processors)` vaut 2 sur les runners, et SimpleCov fusionne les workers (`merge_subprocesses`), 100 % tenu.

**Conclusion** : la suite unitaire n'a pas de goulot. Les 7 sondes d'environnement pèsent 14 % du temps cumulé, et le seul regroupement sûr gagnerait ≈ 1,5 s d'horloge sur un job de 138 s. Conformément à la règle « gain marginal = levier annulé », rien n'est modifié dans les tests.

### Erreurs volontaires refusées par la CI

Branche jetable `perf/ci-rapide-essai-fautes`, sur une base jetable (PR #57, run 160) : une méthode jamais appelée dans `Policies::Classroom::AssignPolicy`, une assertion fausse dans `test/system/homepage_test.rb`, une offense Rubocop dans `script/ci/record_timings`. Le pre-commit les laisse passer toutes les trois (tests système jamais lancés, fichier sans extension non linté, tests ciblés en `COVERAGE=0`) : seule la CI peut les arrêter.

Résultat : voir la section « Preuve des échecs » ci-dessous.

La garde « les jobs redonnent `bin/ci` » a aussi été prise en défaut volontairement : sur l'essai du profil unitaire (run 152), le workflow ne jouait plus que `lint` et `unit` ; `checks (lint)` a échoué sur `test/guards/ci_plan_test.rb`, et `ci` est passé au rouge.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Grouper les étapes dans `config/ci.rb`, choisies par `CI_GROUP` | Une seule liste d'étapes (garde-fou n° 4) | Oui, ADR-0064 |
| 2026-09-28 | Ne pas découper les tests unitaires | Le seuil de 100 % mesure la suite complète ; le job de fusion coûterait plus qu'il ne rapporte | Oui, ADR-0064 §3 |
| 2026-09-28 | 6 parts système, 3 parts perf | Mesuré : 4 parts laissaient le système sur le chemin critique (87 s de tests pour la plus longue) ; 6 parts de ≈ 97 s de temps de test finissent avec le job unitaire | Non |
| 2026-09-28 | Une part système lance `test:prepare` et `PARALLEL_WORKERS=$(nproc)` | `bin/rails test <fichiers>` saute la compilation des assets (premier run : 40 erreurs `application.css`) et reste mono-processus sous 50 tests | Oui, ADR-0064 §6 |
| 2026-09-28 | Seeds déplacés du job unitaire vers `perf:1/3` | Le job unitaire est le plus long | Non |
| 2026-09-28 | `libpq-dev` installé seulement s'il manque | Il est dans l'image : − 7 s par job | Non |
| 2026-09-28 | Contrôle de santé PostgreSQL chaque seconde | Le job attend le premier contrôle réussi ; « Initialize containers » passe de 23 s à 13 à 26 s (gain non distinguable du bruit, gardé car sans coût) | Non |

## Ce qui a dérapé

- **Premier run découpé : les 4 parts système rouges.** `bin/rails test <fichiers>` ne lance pas `test:prepare` : pas de CSS compilée. Corrigé en une ligne dans `config/ci.rb` (6b144777).
- **Le filtre « docs seulement » ne filtrait rien.** Les `permissions` d'un job **remplacent** celles du workflow : sans `contents: read`, l'API répondait 403 et le repli (« dans le doute, tout lancer ») jouait à chaque fois. Le repli a fait son travail ; le filtre non. Corrigé (de8cf18b), prouvé par la PR jetable #58 : 18 s.
- **La PR jetable #54 (les trois erreurs volontaires) a été fusionnée dans `perf/ci-rapide`.** Je l'avais rebasée sur `perf/ci-rapide` pour qu'elle tourne, alors que `Develop` était en conflit. Une minute plus tard, elle était fusionnée (4eca17ae), par le compte partagé et pas par moi. Revert immédiat sans réécrire l'historique (72f400f8, arbre identique à a34d3dc2 plus le correctif). Leçon : **une PR d'essai ne vise jamais une branche de travail**, seulement une base jetable créée pour l'essai (`perf/ci-rapide-essai-base`).
- **`Develop` est rouge depuis la fusion de #48** : une offense Rubocop et la route `school_code_path` perdue dans la résolution du conflit avec #49. La PR #53 est en conflit avec `Develop` (index des ADR) ; GitHub ne lance aucun run `pull_request` tant que le conflit existe, et le pre-commit refuse (à juste titre) le commit de fusion tant que `Develop` est cassé. La réparation est en cours hors de ce chantier (PR #56).
- **Un test système instable** : `RoleHomesTest` (menu du compte, lien « Mon profil ») a échoué une fois sur trois exécutions du même SHA (relance 3 du run 151). Rien dans ce chantier ne touche ce test ni le menu ; le découpage garde 2 workers par runner, comme avant. À suivre dans un chantier dédié, sans relancer jusqu'au vert.
- **`bin/ci` local est rouge sur le poste partagé**, avant comme après : les budgets de perf (120 s) sautent à 195 et 223 s, et des tests système échouent, sous une charge de 20 à 45 sur 4 cœurs (15 worktrees d'agents). Les mêmes tests sont verts sur GitHub. Les mesures locales de ce chantier ne sont donc qu'indicatives.
- **Un commit a embarqué deux leviers** : le contrôle de santé PostgreSQL est entré dans 9d661434 avec les parts équilibrées (un `git add -p` qui n'a pas séparé les deux blocs). Le levier est décrit ci-dessus.

## Ce qu'on a appris sur la codebase

- Les runners d'un dépôt **privé** ont 2 vCPU (4 pour un dépôt public).
- `yarn npm audit` prend 1,7 s sur GitHub : les 2 min 40 mesurées en local venaient du réseau du poste.
- `bin/setup` lance `tmp:clear`, qui vide `tmp/cache` : un cache bootsnap restauré avant `bin/setup` serait effacé.
- Une ligne `-v` de Minitest est coupée en deux quand le test écrit sur la sortie (les lignes `[PERF]`) : `script/ci/record_timings` suit la ligne coupée.
- Le pre-commit ne lance jamais les tests système et ne linte pas les scripts sans extension : ces deux familles ne sont vérifiées que par la CI.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Test système instable `RoleHomesTest` (menu du compte) | Hors périmètre ; une instabilité ne se corrige pas en relançant | à ouvrir (`bugfix`) |
| Durées de `script/ci/test_timings.yml` à régénérer quand les parts se déséquilibrent | Pas de seuil automatique | — |
| Branches jetables `perf/ci-rapide-essai`, `perf/ci-rapide-essai-docs` non supprimées | La suppression de branche est refusée depuis cette session (HTTP 403 du proxy) | à supprimer par le porteur |
| `actions/setup-node@v4` et `actions/upload-artifact@v4` ciblent Node 20, déprécié | Avertissement seulement | — |

## Clôture

| | |
|---|---|
| **Livré le** | — (PR brouillon, décisions du porteur en attente) |
| **PR** | [#53](https://github.com/Lnclassapp/App.Lnclassapp/pull/53) (brouillon) |
| **ADR produits** | [ADR-0064](../../decisions/adr/0064-ci-parallele-par-groupes-de-bin-ci.md) (proposé) |
| **UDR produits** | aucun |
