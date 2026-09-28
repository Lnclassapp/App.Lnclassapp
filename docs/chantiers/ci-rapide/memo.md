# Memo — La CI GitHub dure près de 10 minutes

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `perf/ci-rapide` |

---

## Le problème

Demande du porteur (2026-09-28) : « la durée de l'exécution du CI sur GitHub commence à augmenter. Trouve une optimisation pour diviser la durée par 10. »

Un run de CI est **un seul job** qui lance `bin/ci`, et `bin/ci` enchaîne en série les étapes de `config/ci.rb`. La suite compte 1 856 à 1 905 tests unitaires, 147 tests système Chrome et 7 tests de performance d'import. Chaque PR attend donc la somme de toutes les étapes, alors qu'elles sont presque toutes indépendantes.

## Pour qui

L'équipe et les agents qui ouvrent des PR vers `Develop` : le 2026-09-28 au matin, 145 runs en 4 jours, souvent 3 PR en attente en même temps.

## Pourquoi maintenant

Chaque PR attend 9 à 10 minutes son verdict, et chaque fusion dans `Develop` relance la même durée. La suite grossit à chaque chantier.

## Mesure avant

**Volume** : `Develop` et les PR #47 à #50 du 2026-09-28 (1 853 à 1 905 tests unitaires, 143 à 147 tests système, 7 tests de perf). **Machine** : runner GitHub `ubuntu-latest` d'un dépôt **privé**, soit **2 vCPU** (le log affiche « Running 1856 tests in parallel using 2 processes » : `parallelize(workers: :number_of_processors)` s'adapte déjà au runner). **Méthode** : horodatages des étapes du job (API GitHub `list_workflow_jobs`) et lignes « ✅ … passed in » de `bin/ci` dans les logs (`get_job_logs`). **5 runs, médiane retenue.**

Runs mesurés : [36393233097](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36393233097) (push Develop, #47), [36392735882](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36392735882) (PR #50), [36392029133](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36392029133) (PR #49), [36391989866](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36391989866) (PR #48), [36388663027](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36388663027) (PR #46).

| Poste | #47 | #50 | #49 | #48 | #46 | **Médiane** | Part |
|---|---:|---:|---:|---:|---:|---:|---:|
| File d'attente (création → démarrage du job) | 3 s | 5 s | 3 s | 4 s | 4 s | **4 s** | 1 % |
| Conteneur PostgreSQL (« Initialize containers ») | 23 s | 23 s | 26 s | 25 s | 23 s | **23 s** | 4 % |
| `apt-get install libpq-dev` | 7 s | 7 s | 9 s | 6 s | 6 s | **7 s** | 1 % |
| Checkout + Ruby (cache bundler) + Node | 12 s | 15 s | 15 s | 22 s | 14 s | **15 s** | 3 % |
| `bin/ci` · Setup (bundle check, yarn install 2 s, db:prepare 6 s) | 10,4 s | 9,6 s | 9,8 s | 10,5 s | 11,3 s | **10,4 s** | 2 % |
| · Gardes (pureté, HITL) | 0,4 s | 0,5 s | 0,3 s | 0,4 s | 0,5 s | **0,4 s** | 0 % |
| · Rubocop (sans cache) | 7,2 s | 7,8 s | 5,8 s | 7,7 s | 7,8 s | **7,7 s** | 1 % |
| · bundler-audit | 1,7 s | 1,5 s | 1,4 s | 2,5 s | 1,3 s | **1,5 s** | 0 % |
| · `yarn npm audit` | 1,6 s | 1,7 s | 1,4 s | 1,7 s | 1,7 s | **1,7 s** | 0 % |
| · Brakeman | 7,0 s | 8,0 s | 6,1 s | 8,6 s | 8,1 s | **8,0 s** | 1 % |
| · **Tests unitaires + couverture 100 %** | 61,7 s | 69,8 s | 57,6 s | 70,0 s | 72,6 s | **69,8 s** | 12 % |
| · **Tests système Chrome** (2 processus) | 241,5 s | 264,7 s | 230,1 s | 259,4 s | 262,4 s | **259,4 s** | 46 % |
| · Seeds | 2,2 s | 2,5 s | 1,9 s | 2,5 s | 2,6 s | **2,5 s** | 0 % |
| · **Perf d'import** (1 processus) | 132,1 s | 140,0 s | 102,2 s | 137,3 s | 142,0 s | **137,3 s** | 24 % |
| · Budget d'assets | 1,5 s | 1,7 s | 1,4 s | 1,7 s | 1,8 s | **1,7 s** | 0 % |
| `bin/ci` au total | 7 min 47 | 8 min 28 | 6 min 58 | 8 min 22 | 8 min 32 | **8 min 22** | |
| Artefacts + arrêt | 5 s | 6 s | 5 s | 7 s | 6 s | **6 s** | 1 % |
| **Horloge du run** (création → fin) | 8 min 42 | 9 min 28 | 7 min 59 | 9 min 32 | 9 min 28 | **9 min 28 (568 s)** | 100 % |

Ce que le tableau dit :

1. **Trois étapes font 82 % du run** : les tests système (46 %), la perf d'import (24 %), les tests unitaires (12 %). Tout le reste, installation comprise, tient en 1 min 40.
2. **L'installation n'est pas le problème** : 48 s avant `bin/ci`, dont 23 s pour démarrer le conteneur PostgreSQL. Le cache bundler est déjà en place ; `yarn install` prend 2 s.
3. **`yarn npm audit` ne coûte que 1,7 s sur GitHub** (les 2 min 40 mesurées en local venaient du réseau du poste, [`ci-audit-yarn-local`](../ci-audit-yarn-local/memo.md)).
4. **Les runners ont 2 vCPU, pas 4** : dépôt privé. Monter `PARALLEL_WORKERS` au-delà de 2 dans un runner ne peut rien gagner sur le CPU.
5. **Le plancher d'un job est d'environ une minute** : file d'attente, conteneur, checkout, Ruby, Node, Setup, démarrage de Rails. Aucun découpage ne descend un job sous ce plancher.

## Cible et écart avec « ÷ 10 »

| Métrique | Avant | ÷ 10 demandé | Cible atteignable sans compromis | Comment mesurée |
|---|---:|---:|---:|---|
| Horloge d'un run de PR qui touche du code | 9 min 28 | 57 s | **≈ 2 min 30 (÷ 3,5 à ÷ 4)** | création → fin du run, médiane de 3 runs |
| Horloge d'une PR qui ne touche que `docs/` ou des `.md` | 9 min 28 | 57 s | **< 30 s (÷ 20)** | idem |

**÷ 10 n'est pas atteignable sur les runners GitHub standard sans affaiblir le filet de sécurité.** 57 s est **sous le plancher d'un seul job** (≈ 60 s sans aucun test) : même un run qui ne jouerait qu'un test ne tiendrait pas dans la cible. Les moyens d'aller plus loin sont des décisions du porteur, présentées dans [`plan.md`](plan.md#décisions-à-soumettre-au-porteur), et **aucune n'est activée par défaut**.

## Hors périmètre

- Le contenu des tests : aucun test n'est supprimé, désactivé ni affaibli. Le seuil de couverture reste 100 % lignes et branches sur la suite complète (ADR-0024).
- Le test de mutation (ADR-0024 §4) : il n'existe pas encore dans `bin/ci`.
- Les runners plus gros, payants ou auto-hébergés : c'est une décision de budget, soumise au porteur.
- La lenteur de `bin/ci` en local : elle dépend de la charge du poste partagé, pas de la CI.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Découper aussi les tests unitaires et fusionner la couverture dans un job final ? | Les tests unitaires durent 70 s. Deux parts de 35 s plus un job de fusion (checkout, Ruby, `SimpleCov.collate` : ≈ 30 s de plancher) finissent **plus tard** qu'un seul job de 70 s, qui n'est de toute façon pas le plus long. | Levier écarté par la mesure : un seul job unitaire, le seuil de 100 % s'y applique à la suite complète, exactement comme aujourd'hui. |
| `PARALLEL_WORKERS=4` sur des runners à 4 vCPU ? | Les runners d'un dépôt privé ont 2 vCPU ; `number_of_processors` vaut déjà 2. | Aucun changement. |
| Mettre en cache `yarn`/`node_modules`, bootsnap, les assets compilés ? | `yarn install` : 2 s. `bin/setup` vide `tmp/cache` (`tmp:clear`) : un cache bootsnap serait effacé avant usage. Les assets se compilent en moins de 2 s. | Écartés : rien à gagner. Seul le cache Rubocop (`tmp/rubocop`, non effacé) est ajouté. |
| Filtrer les chemins au niveau du workflow (`paths-ignore`) ? | Un workflow ignoré ne rapporte **aucun** statut : une vérification requise resterait « en attente » pour toujours. | Un job `changes` décide, et le job final `ci` réussit quand seuls des documents ont changé. |
| Le statut requis s'appelle-t-il « ci » ? | La protection des branches est impossible sur ce dépôt (privé, offre gratuite, API en 403, [journal d'amorçage §5](../amorcage-depot/journal.md)). Le jour où elle sera posée, la commande prévue exige le contexte `ci`. | Le job final garde le nom `ci`. |
| Plus de jobs, plus de minutes facturées ? | Oui : chaque job est facturé à la minute entamée, avec son propre plancher. 145 runs en 4 jours. | Chiffré dans le journal ; le nombre de parts est un réglage du porteur. |

## Cas limites identifiés

- Une faute de frappe dans `CI_GROUP` ne doit pas donner un job vert qui n'a rien lancé : `bin/ci` échoue sur un groupe ou une part inconnus.
- Un fichier de test système nouveau, absent des durées enregistrées, doit quand même tourner : il pèse la médiane et tombe dans une part.
- Un groupe ajouté à `config/ci.rb` et oublié dans le workflow : la garde `test/guards/ci_plan_test.rb` le refuse.
- Un run annulé par un push plus récent ne doit pas passer pour vert : le job `ci` n'accepte que `success`, ou `skipped` quand seuls des documents ont changé.

## Questions encore ouvertes

- Voir [`plan.md` — Décisions à soumettre au porteur](plan.md#décisions-à-soumettre-au-porteur).

<!-- ESSAI JETABLE ci-rapide : PR documentation seule -->
