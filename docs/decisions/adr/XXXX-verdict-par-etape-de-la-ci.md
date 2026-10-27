# ADR-XXXX : Chaque étape de la CI locale garde son verdict, pour les seuls fichiers qu'elle lit
<!-- index
titre: Verdict par étape de la CI locale
statut: Accepté
problematique: `bin/ci-quiet` ne gardait qu'un verdict pour tout l'arbre : une ligne de JavaScript rejouait les 6 295 tests Rails et la perf des imports. Chaque étape garde désormais son verdict, sur l'empreinte de ses seules entrées, et la perf ne rejoue que ses tests changés.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-27 |
| **Chantier** | [`docs/chantiers/ci-rejeu-cible`](../../chantiers/ci-rejeu-cible/memo.md) |
| **Remplace** | — (complète [ADR-0107](0107-la-preuve-d-une-pr-suit-ce-qu-elle-touche.md) §4, le verdict par arbre) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

ADR-0107 garde un verdict vert par empreinte de **tout l'arbre** (sans son Markdown). Le 2026-10-27, une même PR (#316) a joué trois trains complets en local (≈ 50 min) : le deuxième pour une ligne de JavaScript, le troisième pour une ligne d'un test de perf. Chacun a rejoué les 6 295 tests Rails (3 min 46 s) et les 6 fichiers de perf (2 à 3 min), que ces lignes ne pouvaient pas changer. Le porteur a validé le 2026-10-27 qu'une étape déjà verte pour ses entrées ne se rejoue pas.

## 2. Moteurs de décision

1. Ne rejouer que ce qu'un changement peut casser, étape par étape.
2. **Fail-safe** : une étape dont on ne sait pas dire ce qu'elle lit dépend de tout l'arbre.
3. La couverture à 100 % reste mesurée sur la suite entière (ADR-0024).
4. Rien ne change sur GitHub : la promotion vers `Staging` rejoue tout (ADR-0107).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder le verdict par arbre | Simple, sans risque | Une ligne de JS coûte un train complet |
| B — Verdict par étape, entrées = liste de dossiers lus | Précis | Une liste oubliée fait sauter une étape qui aurait dû tourner |
| C — **Verdict par étape, entrées = l'arbre moins ce que l'étape ne lit pas** ✅ | Un dossier nouveau compte par défaut (fail-safe) ; les exclusions sont peu nombreuses et testées | Une exclusion fausse fait sauter l'étape : chacune est justifiée ci-dessous et tenue par `test/config/ci_scope_test.rb` |

## 4. Décision

> **`bin/ci-quiet` joue chaque étape pour elle-même et garde un verdict vert par étape, sous la clé : commande, environnement, empreinte des seules entrées de l'étape. Une étape déjà verte pour cette clé ne se rejoue pas ; la ligne de preuve dit combien d'étapes ont été jouées et combien étaient déjà vertes.**

Les entrées (`CiScope::INPUTS`, déclarées dans `config/ci.rb` par `inputs:`) :

| Étape | Entrées |
|---|---|
| Gardes | tout l'arbre |
| Style Ruby, Brakeman | l'arbre sans `app/javascript/`, `app/assets/` (Brakeman : ni `test/` ni `docs/`) |
| Audit des gems / Yarn | `Gemfile`, `Gemfile.lock`, configuration de l'audit / `package.json`, `yarn.lock` |
| Tests Rails | l'arbre sans `app/javascript/`, `app/assets/stylesheets/`, `test/system/`, `test/performance/` |
| Tests système | l'arbre sans les fichiers `*_test.rb` hors de `test/system/` (un processus ne charge que ses tests) |
| Seeds | l'arbre sans `app/javascript/`, `app/assets/stylesheets/`, `test/` |
| Perf des imports | `PERF_PATHS` sans `PERF_IGNORED` (ADR-0039) |
| Budget des assets | l'arbre sans `test/`, `db/`, `docs/`, `app/domain/`, `app/infrastructure/`, `app/jobs/` |

**Les tests Rails qui lisent le front.** 67 fichiers de tests unitaires lisent du CSS, du JavaScript ou leur build (jetons de design, bundle, sprites). Quand seul le front a bougé, ils sont rejoués seuls (`CiScope.front_readers` : un test qui nomme `javascript`, `stylesheet`, `tailwind`, `esbuild`, `builds`, `.css` ou `.js`, ou qui appelle une aide de `test/support/` qui le fait). La détection est large exprès.

**La perf ciblée.** Quand l'écart avec `origin/Develop` sur `PERF_PATHS` ne porte que sur des fichiers `test/performance/**/*_test.rb`, seuls les tests changés jouent ; tout autre écart les joue tous, comme avant. La condition qui distingue GitHub teste `GITHUB_ACTIONS`, plus `CI` : `bin/ci` pose `CI=true` sur toute machine (`ActiveSupport::ContinuousIntegration.run`), si bien que la perf n'était jamais sautée en local.

**Au niveau train aussi** : `bin/ci-quiet` ne délègue plus à `bin/ci`. Il joue les étapes de `config/ci.rb` une à une (Setup d'abord, seulement si une étape doit jouer), toutes, même après une rouge : chaque étape verte garde son verdict, et le run suivant ne rejoue que les rouges. Elles jouent avec `CI=true`, comme sous `bin/ci` : l'environnement de test charge alors tout le code (`eager_load`), ce que la couverture de la suite entière demande.

## 5. Conséquences

### 🟢 Positives

- Une ligne de JavaScript rejoue les tests système, le budget des assets et les tests unitaires qui lisent le front, plus les 6 295 tests Rails ni la perf.
- Une ligne d'un test de perf ne rejoue que ce test, et les gardes.
- Un train rouge corrigé ne rejoue que les étapes que la correction touche.

### 🔴 Coûts consentis

- Une exclusion fausse ferait sauter une étape qui aurait dû tourner. La promotion vers `Staging` rejoue tout sur GitHub (ADR-0107) : l'erreur ne passe pas `Staging`.
- L'audit des gems garde son verdict tant que `Gemfile.lock` ne bouge pas : une faille publiée depuis se voit au train GitHub, comme avec le verdict par arbre.
- Le verdict reste local (`tmp/ci-verdicts/steps/`). `rm -r tmp/ci-verdicts` oublie tout.

## 6. Notes d'implémentation

- `script/ci/scope.rb` : `Inputs`, `INPUTS`, `front_readers`, `step_key`, `Verdicts#step?` et `#record_step`.
- `script/ci/plan.rb` : `Step` porte `inputs` ; `bin/ci` et GitHub l'ignorent.
- `config/ci.rb` : `inputs:` sur chaque étape ; la condition shell de la perf.

## 7. Comment vérifier que la décision est respectée

`bin/ci-quiet --plan` marque « (déjà vert pour ses entrées) » chaque étape qui ne jouera pas. La ligne de preuve dit « N étape(s) jouée(s), M déjà verte(s) pour leurs entrées ».
