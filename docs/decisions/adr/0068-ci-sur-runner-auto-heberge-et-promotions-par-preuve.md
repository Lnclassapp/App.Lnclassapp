# ADR-0068 : La CI tourne sur un runner auto-hébergé ; une promotion prouve que son code a déjà été testé

| | |
|---|---|
| **Statut** | Proposé *(options tranchées par le porteur au grill du 2026-09-29 et du 2026-09-30)* |
| **Date** | 2026-09-30 |
| **Chantier** | `docs/chantiers/ci-quota` |
| **Remplace** | — *(amende l'[ADR-0064](./0064-ci-parallele-par-groupes-de-bin-ci.md) : §4 précision 6 et §5 « plus de minutes facturées »)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le dépôt est privé, sur l'offre gratuite d'une organisation GitHub : **2 000 minutes de runner par mois** (≈ 66 par jour), chaque job facturé à la minute entamée. L'[ADR-0064](./0064-ci-parallele-par-groupes-de-bin-ci.md) a découpé `bin/ci` en 14 jobs pour ramener l'horloge d'un run de 9 min 28 à 2 min 36. Il avait chiffré le prix, environ 2,5 fois plus de minutes, et laissé la surveillance du quota au porteur.

Le quota s'est épuisé le 2026-09-28 à 10 h 44 UTC. Depuis, aucun job ne démarre et les PR fusionnent sans verdict. La mesure du [memo](../../chantiers/ci-quota/memo.md#mesure-avant) donne l'ordre de grandeur :

- un run de PR qui touche du code coûte **27 à 29 minutes** (8,5 en un seul job avant l'ADR-0064) ;
- le 2026-09-29, **40 runs en 6 heures**, dont **60 % retestent du code déjà testé** : 18 pushes de fusion sur `Develop`, `Staging` et `main`, et 6 PR de promotion ;
- même en un seul job et sans les runs en double, la cadence dépasse le quota de moitié : la suite complète coûte 7 à 11 minutes sur un runner GitHub à 2 vCPU.

Aucun réglage des runners GitHub gratuits ne tient donc à la fois le quota et un verdict rapide.

## 2. Moteurs de décision

1. **La CI ne s'arrête plus pour une question de quota.**
2. **Le filet de sécurité ne faiblit pas** : mêmes étapes (`config/ci.rb`), même seuil de couverture (ADR-0024), mêmes tests système dans un vrai Chrome.
3. **Un verdict en moins de 3 minutes** sur une PR de chantier (demande du porteur).
4. **Une promotion coûte moins de 3 minutes facturées** (demande du porteur).
5. Le code d'une PR ne peut pas lire les fichiers personnels du porteur.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Revenir à un seul job GitHub | Divise le coût d'un run par 3,3 | 8,5 minutes par run × ≈ 40 runs par jour : le quota tient 6 jours. L'horloge remonte à 7-10 minutes |
| B — Moins de runs sur GitHub (plus de push sur les branches longues) | Supprime 45 % des runs | Le reste dépasse encore le quota. Utilisé quand même, sous forme de preuve (décision, point 3) |
| C — Payer les minutes au-delà du quota, ou des runners plus gros | Rien à administrer | Écarté par le porteur (hors périmètre) |
| D — Rendre le dépôt public (minutes gratuites) | Gratuit et illimité | Écarté par le porteur. Un dépôt public avec un runner auto-hébergé laisserait aussi n'importe qui exécuter du code sur la machine |
| E — Runner auto-hébergé sur la machine du porteur pour les PR de chantier, preuve d'arbre pour les promotions ✅ | Les minutes d'un runner auto-hébergé ne sont pas décomptées du quota. Une promotion ne reteste pas un contenu déjà testé | Retenue |

## 4. Décision

> **Nous faisons tourner les jobs de `bin/ci` sur un runner auto-hébergé, sur la machine du porteur (Ubuntu 22.04, Docker), sous un utilisateur Linux dédié. Une promotion (`Develop` → `Staging`, `Staging` → `main`) ne rejoue pas la suite : un job GitHub unique vérifie que l'arbre de fichiers du commit promu a déjà reçu un `ci` vert. Sinon, la suite part sur le runner auto-hébergé, jamais sur un runner GitHub.**

Précisions qui font partie de la décision :

1. **Où tourne quoi.**

   | Événement | Runner | Coût visé |
   |---|---|---|
   | PR de chantier (base `Develop`) | auto-hébergé | 0 minute facturée |
   | Push sur `Develop` (fusion d'une PR) | auto-hébergé : preuve d'arbre, sinon la suite | 0 minute facturée |
   | PR de promotion (base `Staging` ou `main`), push sur `Staging` ou `main` | GitHub : job de preuve, puis `ci` | ≤ 2 minutes facturées |
   | Preuve absente sur une promotion | auto-hébergé : la suite complète | 1 minute facturée (le job de preuve) |
   | Bouton « Run workflow » (secours manuel) | GitHub, **un seul job** `bin/ci` complet | ≈ 9 minutes par clic |

2. **La preuve est l'arbre, pas le commit.** `git rev-parse HEAD^{tree}` identifie le contenu exact testé. Il ignore les messages et les commits de fusion. Le job `ci` d'un run vert publie un artefact vide nommé `ci-tree-<arbre>`, conservé 30 jours. Le job de preuve cherche cet artefact par son nom (`GET /actions/artifacts?name=…`). Pour une PR, l'arbre est celui du commit de fusion que GitHub teste (`github.sha`), pas celui de la tête de branche.
3. **Le statut attendu garde le nom `ci`**, quel que soit le runner (ADR-0064 §4, précision 5). Le job `ci` tourne sur GitHub quand la preuve suffit, et sur le runner auto-hébergé sinon.
4. **Une PR qui ne touche que des documents** reste verte sans lancer de vérification (ADR-0064 §4, précision 6). Le job qui le décide tourne sur le runner auto-hébergé.
5. **Machine éteinte : la PR attend.** GitHub annule un job resté 24 heures en file ([docs GitHub](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)). Un service de la machine relance, à son démarrage puis à intervalle régulier, les runs annulés depuis **moins de 48 heures** dont la PR est ouverte et le commit inchangé. **Aucune bascule automatique** vers un runner GitHub.
6. **Isolation.** Le runner tourne en service systemd sous l'utilisateur `github-runner` : sans `sudo`, sans accès au dossier personnel du porteur, membre du groupe `docker` (nécessaire au conteneur PostgreSQL). Il sert **ce dépôt privé seulement**. Le service de relance utilise un jeton limité à ce dépôt, avec le seul droit `actions: write`.
7. **Plusieurs jobs sur une même machine.** Chaque job publie PostgreSQL sur un port de l'hôte choisi par Docker (`ports: [ "5432" ]`) et le passe à Rails par `PGPORT`, que lit `config/database.yml`. Deux jobs simultanés, ou le PostgreSQL de développement du porteur, ne se disputent jamais le port 5432. Le nombre d'instances du runner et le découpage des groupes sur la machine se fixent **à la mesure** (chantier, lot E).

## 5. Conséquences

### 🟢 Positives

- Les PR de chantier et `Develop` ne consomment plus de quota. Seules les promotions et le bouton de secours en consomment, soit ≈ 12 promotions × 2 minutes par jour chargé, sous les 66 minutes quotidiennes.
- La suite complète tourne toujours avant une fusion dans `Develop`, et `bin/ci` reste la seule liste d'étapes.
- Un runner gardé chaud (Ruby, gems, Chrome et image PostgreSQL déjà présents) démarre plus vite qu'un runner GitHub.

### 🔴 Coûts consentis

- **La CI dépend d'une seule machine.** Éteinte, elle fait attendre les PR ; en panne, plus de verdict sans clic sur le bouton de secours.
- **`Staging` et `main` ne sont plus retestés sur une machine propre.** Une différence d'environnement entre la machine du porteur et GitHub (Chrome, PostgreSQL, fuseau horaire) n'est plus rattrapée à la promotion. Le conteneur `postgres:17` reste identique, ce qui limite le risque.
- **Une machine à entretenir** : mises à jour d'Ubuntu, de Docker et de Chrome, et du runner lui-même (GitHub refuse un runner trop ancien).
- **Surface d'attaque** : le groupe `docker` équivaut à root pour qui le détourne exprès. Le risque est accepté parce que seul du code de l'équipe et de ses agents atteint ce dépôt privé.
- **Une preuve à faire confiance** : quelqu'un qui peut pousser sur le dépôt peut aussi publier un artefact `ci-tree-…` sans tester. C'est le même niveau de confiance que celui qui lui permet déjà de modifier le workflow.

## 6. Notes d'implémentation

| Fichier | Rôle |
|---|---|
| `.github/workflows/ci.yml` | Job `proof` (preuve d'arbre), puis `changes`, `checks`, `tests` sur `[ self-hosted, linux, lnclass ]`, puis `ci` qui publie `ci-tree-<arbre>` |
| `script/ci/tested_tree` | La preuve : arbre de `GITHUB_SHA` par l'API, artefact cherché par son nom ; tout doute répond `false` |
| `.github/workflows/ci-github.yml` | Bouton de secours (`workflow_dispatch`) : un job `ci` sur GitHub, `bin/ci` complet |
| `script/ci/runner/install`, `check` | Installation et vérification du runner sur la machine ([guide](../../guide/runner-auto-heberge.md)) |
| `script/ci/runner/rerun_expired`, `install_rerun` | Relance des runs expirés, minuterie systemd |
| `config/database.yml` | `port: <%= ENV.fetch("PGPORT", 5432) %>` |
| `script/ci/billed_minutes` | Minutes facturées d'un run (les jobs auto-hébergés comptent 0) |

Le choix du runner, dans `ci.yml`, tient dans une expression. Une promotion va sur GitHub, tout le reste sur la machine :

```yaml
proof:
  runs-on: ${{ fromJSON(((github.event_name == 'pull_request' && (github.base_ref == 'Staging' || github.base_ref == 'main')) || (github.event_name == 'push' && (github.ref_name == 'Staging' || github.ref_name == 'main'))) && '["ubuntu-latest"]' || '["self-hosted", "linux", "lnclass"]') }}
```

Le job `ci` reprend cette expression, préfixée de `needs.proof.outputs.tested == 'true' &&` : il ne va sur GitHub que si la preuve suffit. Sinon il attend les jobs de la machine.

PostgreSQL sur un port choisi par Docker, transmis à Rails :

```yaml
services:
  postgres:
    image: postgres:17
    ports:
      - 5432
# …
- name: Run bin/ci (${{ matrix.group }})
  env:
    PGPORT: ${{ job.services.postgres.ports['5432'] }}
  run: bin/ci
```

`DATABASE_URL` a été écarté : `bin/setup` prépare la base de l'environnement `development`, qui l'aurait prise pour la base de test.

Seul un run qui a **joué** les vérifications publie la preuve de son arbre. Une PR qui ne touche que des documents est verte sans rien prouver.

## 7. Comment vérifier que la décision est respectée

- `script/ci/billed_minutes <run-id>` compte les minutes facturées d'un run. Une PR de chantier doit afficher 0, une promotion 2 au plus.
- La garde `test_only_the_proof_and_the_verdict_of_a_promotion_run_on_a_github_runner` de `test/guards/ci_plan_test.rb` (groupe `lint`) refuse un job de `ci.yml` qui ne tourne pas sur `[ self-hosted, linux, lnclass ]`, en dehors de `proof` et `ci`, et vérifie que ces deux-là ne vont sur GitHub que pour une promotion. Un nouveau job ne peut pas rouvrir la fuite de minutes sans casser la garde.
- `test/config/ci_tested_tree_test.rb` : un arbre inconnu, une preuve expirée ou une API en erreur répondent « non testé », jamais une erreur avalée.
- `test/config/ci_rerun_expired_test.rb` : seul un run expiré faute de runner, de moins de 48 h, dont la PR n'a pas bougé, est relancé, et une seule fois.
- La garde existante vérifie toujours que les jobs redonnent exactement la liste de `bin/ci`.
