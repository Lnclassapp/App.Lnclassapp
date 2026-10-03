# Memo — Ne jouer que les tests système que les fichiers touchés concernent (carte de couverture)

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | cadrage — mesure avant prise, **grill à tenir avec le porteur** (questions ci-dessous, une à la fois) |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `perf/selection-par-carte-de-couverture` |
| **Programme** | — |

> Ouvert sur décision du porteur le 2026-10-03 (chantier [`ci-quota`](../ci-quota/memo.md), décision 2), à partir de son hypothèse du 2026-10-02 : « si `Develop` a tous les tests couverts à 100 %, n'est-il pas logique de tester uniquement les tests des fichiers concernés ? ». Décision cadre : [ADR-0069 §9](../../decisions/adr/0069-ci-en-un-job-sur-les-pr-et-promotions-par-preuve.md#9-amendement-des-2026-10-02-et-2026-10-03--dix-minutes-par-feature-sur-nimporte-quel-runner), point 5.

---

## Le problème

Chaque run qui rejoue la suite joue **les 338 tests système, quelle que soit l'étendue du changement** : une PR qui touche un contrôleur du contexte `school` rejoue les parcours de `catalog`, `identity`, `teams`, les pages publiques et le design system. Les tests système font 70 % du temps d'un run (7 min 04 sur les 8 min 52 de `bin/ci` au run 472) et la suite grandit : 299 → 338 tests le 2026-10-02.

`Develop` est couvert à 100 % lignes et branches (ADR-0024) : la couverture sait quels fichiers chaque test exerce. Cette carte n'est aujourd'hui lue que pour le seuil, jamais pour choisir quoi jouer.

Les deux leviers déjà pris (ADR-0069 §9 : deux jobs côte à côte, budget de croissance de 15 s par chantier) tiennent le plafond de dix minutes sur le runner du run 472, sans marge sur un runner 1,5× plus lent, et ne font que **contenir** la croissance. La sélection est le seul levier dont le coût suit la taille du changement, pas la taille de la suite.

## Pour qui

- Les agents et l'équipe qui attendent le verdict d'une PR : l'horloge d'un run, et le quota (une PR tirée au sort, une PR non prouvée, une PR Dependabot).
- La session cloud qui joue `bin/ci` avant de publier sa preuve (`script/ci/prove`, ADR-0069 §8) : ≈ 12 minutes par preuve sur le conteneur à 2 CPU (unitaires 86 s, système 424 s, performance 233 s, mesure locale du 2026-10-02).

## Pourquoi maintenant

L'exigence du porteur du 2026-10-02 est **dix minutes d'horloge au plus par feature**. Le run 472 les tient à 9 min 27 sans marge ; le job `system` seul fera ≈ 7 min 30 sur le même runner et ≈ 11 min sur un runner lent. Le budget de croissance empêche d'aggraver, pas de redescendre. La prochaine étape de l'algorithme (accélérer) passe par ici, ou par un découpage du groupe `system` en deux parts, qui double les jobs sans réduire le travail.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---:|---|---|
| Tests système joués par un run qui rejoue la suite | 338 tests dans 82 fichiers, run [472](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/37079379025) (PR #148, 4 fichiers touchés, aucun dans `app/`) | 338, soit 100 % | *à fixer au grill* (hypothèse : ≤ 25 % pour la PR médiane) | lignes `-v` du job `system` |
| Horloge du job `system` | run 472, runner GitHub 2 vCPU | 7 min 04 (5 min 55 au run 407, même suite, autre runner) | *à fixer au grill* (hypothèse : < 3 min pour la PR médiane) | horodatages des étapes |
| Durée enregistrée de la suite système | `script/ci/test_timings.yml`, run 472 | 812,8 s | — | somme des fichiers `test/system/` |
| `bin/ci` d'une session cloud avant `script/ci/prove` | conteneur 2 CPU, 2026-10-02 | ≈ 12 min (système 424 s) | *à fixer au grill* | `bin/ci` |
| Fichiers touchés par une PR de chantier | *à mesurer sur les 20 dernières PR vers `Develop`* | | | API GitHub `pulls/<n>/files` |

Protocole reproductible : pour un run donné, compter les lignes `… = 1.23 s = .` du job `system` ; lire les horodatages des étapes (`list_workflow_jobs`) ; `script/ci/billed_minutes <run>`.

## Hors périmètre

- **Les runs complets exigés par l'ADR-0069 §8** : PR tirée au sort (1 sur 5), promotion vers `Staging`, release vers `main`. Ils restent complets : c'est eux qui rattrapent un test que la sélection aurait laissé de côté. *(À confirmer au grill, question 1.)*
- **Les tests unitaires** : 1 min 18 avec la couverture, et le seuil de 100 % se mesure sur la suite complète (ADR-0024, `docs/guide/configuration.md` §4.1). Pas de sélection sur eux dans ce chantier.
- **Aucun test supprimé, désactivé ni affaibli.** La sélection choisit quoi jouer dans un run donné ; la suite entière reste jouée aux runs complets.
- **Aucun écran ne change.**

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Une PR qui ne touche aucun fichier de la carte (`docs/`, `.md`) : déjà verte sans rien jouer (ADR-0069 §4.4).
- Une PR qui touche un fichier **hors carte** : vue ERB, contrôleur Stimulus, CSS, locale, fixture, migration, `schema.rb`, `Gemfile.lock`, `config/`. SimpleCov ne voit que le Ruby chargé ; une vue rendue est exercée mais pas tracée ligne à ligne, le JS ne l'est jamais. Règle à décider : tout fichier hors carte déclenche la suite complète.
- Un test système qui exerce un fichier **par un chemin que la carte n'a pas vu** (chargement paresseux, job joué en arrière-plan, helper) : faux vert possible, rattrapé par le run complet suivant (§8).
- Une carte **périmée** : produite sur `Develop` à la promotion précédente, lue par une PR dont la base a avancé. Un fichier nouveau n'a pas d'entrée : règle à décider (suite complète pour tout fichier inconnu de la carte).
- Un run dont la carte est **illisible** (artefact expiré, API en erreur) : la suite complète tourne (tout doute répond « tout jouer », comme pour la preuve d'arbre).

## Questions encore ouvertes

Le grill, à tenir avec le porteur, **une question à la fois** (cycle optimisation, phase 1) :

1. **Où s'applique la sélection ?** (a) Une PR vers `Develop` ni prouvée ni tirée (humain sans session, Dependabot) ; (b) la session cloud avant `script/ci/prove`, ce qui amende le §8 (« la session joue `bin/ci` en entier ») ; (c) le hook pre-commit, qui ne joue aujourd'hui aucun test système. Et jamais aux runs complets du §8 ?
2. **Qu'est-ce qu'un fichier « concerné » ?** Les fichiers Ruby de `app/` et `lib/` par la carte ; tout fichier hors carte (vue, JS, CSS, locale, fixture, migration, config, dépendances) force la suite complète ?
3. **D'où vient la carte, et à quel grain ?** SimpleCov donne fichier → lignes pour toute la suite, pas par test : il faut relever `Coverage` autour de chaque test système (≈ 30 % de temps en plus sur ce run, mesuré sur les unitaires). Produite par le run complet de la promotion vers `Staging` et publiée en artefact `coverage-map-<arbre>`, ou versionnée dans `script/ci/` comme `test_timings.yml` ?
4. **Quel faux vert acceptez-vous ?** Le filet est le run complet du §8 (1 PR sur 5, chaque promotion). Un test écarté à tort se voit à la promotion, pas à la fusion dans `Develop`.
5. **Quelle cible chiffrée ?** Pour la PR médiane (nombre de fichiers touchés à mesurer sur les 20 dernières PR) : horloge du job `system` < 3 min ? Part de tests joués ≤ 25 % ?
6. **Hors périmètre confirmé ?** La liste ci-dessus, sans ajout ni retrait.
