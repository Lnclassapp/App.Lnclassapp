# Plan d'exécution — La CI épuise le quota de minutes GitHub Actions

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Cycle optimisation** : un lot = un levier = un chiffre. `Done quand` est toujours chiffré, mesuré avec [`script/ci/billed_minutes`](../../../script/ci/billed_minutes). Les lots sont rangés par gain/risque décroissant. **Le chantier s'arrête dès que les cibles du [memo](memo.md#écart-avec-la-demande) sont atteintes** ; un lot devenu inutile se ferme, il ne se joue pas « par principe ».
>
> Pas de PRD : en cycle optimisation, le memo (grill, questions 1 à 6) et l'[ADR-0068](../../decisions/adr/0068-ci-sur-runner-auto-heberge-et-promotions-par-preuve.md) font foi.

## Graphe

```
Lot 0 — SOCLE : runner installé sur la machine du porteur, bench qui distingue GitHub et auto-hébergé
  ↓
  ├─► Lot A — Levier 1 : la matrice sur le runner auto-hébergé (PR de chantier, push Develop)  ┐
  ├─► Lot C — Bouton de secours sur GitHub (un seul job)                                       ├─ en parallèle
  └─► Lot D — Relance des runs annulés, jusqu'à 48 h                                           ┘
        ↓ (Lot A)
      Lot B — Levier 2 : preuve d'arbre pour les promotions
        ↓ (Lot B, même fichier)
      Lot E — Levier 3 : horloge < 3 min sur la machine (instances, découpage) — fermé si A l'atteint déjà
```

Tous les lots qui modifient `.github/workflows/ci.yml` (A, B, E) sont **en série** : ils partagent ce fichier et la garde `test/guards/ci_plan_test.rb`.

---

## Lot 0 — Socle : le runner existe, le bench sait le compter

- **Couche**       : outillage (hors `app/`)
- **Fichiers**     : `script/ci/runner/install` *(bash, lancé une fois avec `sudo` par le porteur, idempotent : utilisateur `github-runner` sans `sudo` ni accès au `$HOME` du porteur, groupe `docker`, paquets `libpq-dev` · Google Chrome · `gh` · `jq`, runner GitHub Actions téléchargé et vérifié, enregistré avec les étiquettes `self-hosted, linux, lnclass`, service systemd)*
                     `script/ci/runner/check` *(vérifie qu'un job peut tourner : Docker accessible, Chrome, service actif, runner en ligne)*
                     `script/ci/billed_minutes` *(ne compte que les jobs des runners GitHub : `runner_group_name == "GitHub Actions"`)*
                     `docs/guide/runner-auto-heberge.md` *(procédure : jeton d'enregistrement, installation, vérification, mise à jour, désinstallation)*
                     `docs/guide/README.md` *(fichier partagé : lien vers la procédure)*
- **Dépend de**    : —
- **Test associé** : `script/ci/runner/check` sort en 0 sur la machine du porteur ; `script/ci/billed_minutes` sur les runs 36410838383 et 36409044736 redonne 27 et 29 minutes.
- **Done quand**   : le runner `lnclass` apparaît **« Idle »** dans *Settings → Actions → Runners* de l'organisation, `script/ci/runner/check` est vert, et le bench redonne les valeurs *avant* du memo (27 et 29 minutes).

> ⚠️ **Action du porteur** : ce lot ne se termine pas sans lui. Il génère le jeton d'enregistrement (*Settings → Actions → Runners → New runner*) et lance `sudo script/ci/runner/install` sur sa machine. Le jeton n'est jamais écrit dans le dépôt.

---

## Lot A — Levier 1 : la matrice sur le runner auto-hébergé

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` *(`changes`, `checks`, `tests` et `ci` sur `[ self-hosted, linux, lnclass ]` pour une PR de base `Develop` et un push sur `Develop` ; PostgreSQL publié sur un port choisi par Docker, `DATABASE_URL` passé à `bin/ci` ; `ci` publie l'artefact `ci-tree-<arbre>`, 30 jours)*
                     `.github/actions/setup/action.yml` *(`libpq-dev` : ne plus tenter `sudo apt-get` sur le runner auto-hébergé, échouer clairement s'il manque)*
                     `test/guards/ci_plan_test.rb` *(nouvelle garde : aucun job sur `ubuntu-latest` hors `proof` et `ci`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/guards/ci_plan_test.rb` (groupe `lint`) ; bench `script/ci/billed_minutes` sur 3 runs.
- **Done quand**   : **3 runs de PR de chantier** qui touchent du code coûtent **0 minute facturée** chacun (27 à 29 avant), la suite complète y est verte avec la couverture 100 %, et leur horloge est notée (médiane, valeur de départ du Lot E). Deux PR poussées ensemble ne se disputent pas le port 5432.

---

## Lot B — Levier 2 : une promotion prouve que son arbre a été testé

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` *(job `proof` sur `ubuntu-latest` pour une PR de base `Staging` ou `main` et un push sur `Staging` ou `main` : cherche l'artefact `ci-tree-<arbre de github.sha>` ; les jobs de vérification ne tournent, sur le runner auto-hébergé, que si la preuve manque ; `ci` sur GitHub quand la preuve suffit)*
                     `script/ci/tested_tree` *(lit l'arbre, interroge l'API des artefacts, écrit `tested=true|false`)*
                     `test/guards/ci_plan_test.rb`
                     `test/config/ci_tested_tree_test.rb`
- **Dépend de**    : Lot A *(même fichier de workflow, et les artefacts `ci-tree-…` qu'il publie)*
- **Test associé** : `test/config/ci_tested_tree_test.rb` (arbre testé → `true` ; arbre inconnu, artefact expiré, réponse d'API illisible → `false`, jamais une erreur avalée) ; bench sur 3 runs de promotion.
- **Done quand**   : **3 runs de promotion** (PR `Develop` → `Staging`, push `Staging`, PR `Staging` → `main`) coûtent **≤ 2 minutes facturées** chacun (27 à 29 avant) ; une promotion dont l'arbre n'a jamais été testé lance la suite sur le runner auto-hébergé et ne passe au vert qu'après elle.

---

## Lot C — Bouton de secours sur GitHub

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci-github.yml` *(déclencheur `workflow_dispatch` seul ; **un** job nommé `ci` sur `ubuntu-latest` qui lance `bin/ci` complet et publie `ci-tree-<arbre>`)*
- **Dépend de**    : Lot 0
- **Test associé** : un clic sur *Run workflow* depuis une branche de PR ; `script/ci/billed_minutes` sur ce run.
- **Done quand**   : le clic pose un statut `ci` vert sur le commit, pour **≈ 9 minutes facturées** (8,5 en médiane avant l'ADR-0064). *Une seule exécution mesurée : chacune coûte du quota. Écart assumé à la règle des 3 exécutions, car ce lot n'est pas un levier mais un secours.*

---

## Lot D — Relance des runs annulés, jusqu'à 48 h

- **Couche**       : outillage (machine du porteur)
- **Fichiers**     : `script/ci/runner/rerun_expired` *(Ruby : liste les runs `ci.yml` annulés depuis < 48 h, garde ceux dont la PR est ouverte et la tête inchangée, les relance avec `gh run rerun`)*
                     `script/ci/runner/install_rerun` *(service et minuterie systemd sous `github-runner` : au démarrage, puis toutes les 15 minutes ; jeton limité au dépôt, droit `actions: write`)*
                     `test/config/ci_rerun_expired_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/config/ci_rerun_expired_test.rb` (réponse d'API figée : relancé si annulé depuis < 48 h, PR ouverte, tête inchangée ; ignoré sinon ; jamais deux relances du même run).
- **Done quand**   : sur la machine, un run annulé depuis moins de 48 h (simulé par une annulation manuelle) est relancé **en moins de 15 minutes** après le démarrage du service ; un run de plus de 48 h, ou dont la PR a reçu un nouveau commit, ne l'est pas.

---

## Lot E — Levier 3 : l'horloge sous 3 minutes sur la machine

- **Couche**       : CI + machine
- **Fichiers**     : `.github/workflows/ci.yml` *(matrice de la machine : nombre de parts système et perf)*
                     `script/ci/test_timings.yml` *(durées régénérées depuis les logs du runner, par `script/ci/record_timings`)*
                     `script/ci/runner/install` *(nombre d'instances du runner, option)*
- **Dépend de**    : Lot B *(même fichier de workflow)* ; Lot 0 *(même script d'installation)*
- **Test associé** : `test/guards/ci_plan_test.rb` ; bench sur 3 runs de PR de chantier.
- **Done quand**   : l'horloge médiane de **3 runs de PR de chantier** qui touchent du code est **< 3 min**. **Lot fermé sans rien changer** si le Lot A l'a déjà atteint.

---

## Contrat d'exécution (cycle optimisation)

1. **Le bench est versionné** : `script/ci/billed_minutes` (Lot 0) produit la valeur *avant* (27 et 29 minutes) et chaque valeur *après*.
2. **Non-régression fonctionnelle** : la suite complète est verte, couverture 100 % lignes et branches, **avant** le premier levier (dernier run vert : [36410838383](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36410838383)) et après chacun. Aucun test n'est touché.
3. **Un seul levier par lot**, bench relancé, chiffre noté dans le [journal](journal.md).
4. **Gain nul ou marginal → le pas est annulé.** Un changement de workflow sans gain mesuré se retire.

## Le chantier ne se clôt pas sans mesure après

Le tableau *Écart avec la demande* du [memo](memo.md#écart-avec-la-demande) reçoit une colonne **Après** : **même méthode** (`script/ci/billed_minutes`, horodatages des jobs), **même nature de run** (PR de chantier qui touche du code ; promotion), **au moins 3 exécutions, médiane retenue**, suite toujours verte. **Sans chiffre après, la PR est rejetée.**

## Dispatch

```
Vague 1 : Lot 0                     → 1 agent + le porteur (jeton, sudo sur sa machine)
Vague 2 : Lot A ‖ Lot C ‖ Lot D     → 3 agents, worktrees isolés
Vague 3 : Lot B (après A)           → 1 agent
Vague 4 : Lot E (après B)           → 1 agent, ou fermé si A tient déjà < 3 min
```

Branches de lot : `perf/ci-quota-lot-<x>`, créées depuis `perf/ci-quota` une fois le Lot 0 fusionné dedans. Chemins absolus ; un agent ne touche **aucun** fichier hors de son champ `Fichiers`. Une seule PR du chantier vers `Develop`.

**Amorçage** : la PR de ce chantier est la première à tourner sur le runner auto-hébergé. Une PR joue le workflow de sa propre branche : elle se teste donc elle-même sur la machine du porteur, sans attendre la remise à zéro du quota.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `script/ci/runner/install` | Lot 0 *(puis Lot E, en série)* |
| `script/ci/runner/check` | Lot 0 |
| `script/ci/billed_minutes` | Lot 0 |
| `docs/guide/runner-auto-heberge.md` | Lot 0 |
| `docs/guide/README.md` | Lot 0 |
| `.github/workflows/ci.yml` | Lot A → Lot B → Lot E *(en série, jamais en parallèle)* |
| `test/guards/ci_plan_test.rb` | Lot A → Lot B *(en série)* |
| `.github/actions/setup/action.yml` | Lot A |
| `script/ci/tested_tree` | Lot B |
| `test/config/ci_tested_tree_test.rb` | Lot B |
| `.github/workflows/ci-github.yml` | Lot C |
| `script/ci/runner/rerun_expired` | Lot D |
| `script/ci/runner/install_rerun` | Lot D |
| `test/config/ci_rerun_expired_test.rb` | Lot D |
| `script/ci/test_timings.yml` | Lot E |

Lots parallèles de la vague 2 (A, C, D) : aucun fichier en commun.

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [x] ADR écrit si un contrat change (callbacks contournés, dénormalisation, cache, port modifié) — [ADR-0068](../../decisions/adr/0068-ci-sur-runner-auto-heberge-et-promotions-par-preuve.md)
- [ ] Bench versionné, produisant la valeur avant
- [ ] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [ ] Un lot = un levier = un chiffre
- [ ] Chaque levier sans gain mesuré a été **annulé**, pas conservé
- [ ] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [ ] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi — c'est la partie la plus réutilisable

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce cycle d'optimisation, il **relance lui-même le bench** (`script/ci/billed_minutes` sur des runs qu'il déclenche : une PR de chantier, une promotion) et doit obtenir le gain annoncé, sinon la PR ne passe pas. Chemin d'erreur à rejouer : une promotion dont l'arbre n'a jamais été testé ne doit **pas** être verte sans que la suite ait tourné.
