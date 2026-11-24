# Memo — Preuve de l'arbre pour une promotion de documents seuls

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-24 |
| **Branche** | `claude/pensive-mccarthy-k5ggd6` (branche imposée par la session) |
| **Programme** | — |

---

## Symptôme

La PR #692 (Develop → Staging) ne touche que `docs/contenus/`. Son « ci » est vert, mais après la fusion le déploiement de
Staging échoue : « Arbre sans ci vert (CI coupée, base déplacée entre le test et la fusion, ou preuve expirée après 30 jours).
Rien n'est envoyé au VPS. » (run 45403364756).

## Reproduction

1. PR vers Staging (ou main) qui ne modifie que `docs/` ou des `*.md` ; « plan » sort `code=false`.
2. Job `ci`, étape `verdict` : branche « documents seulement », `exit 0` sans `proof=true`.
3. L'étape « Publish the proof of the tested tree » est sautée : aucun artefact `ci-tree-<tree>`.
4. Push sur Staging → `deploiement.yml`, « Preuve de l'arbre » (`script/ci/tested_tree`) répond `tested=false` → « Refus sans preuve ».

Rejoué en test : `test/config/ci_documents_proof_test.rb` exécute le script `verdict` tel qu'il est écrit dans `ci.yml`.

## Portée

- Depuis la revue sécurité du 2026-11-24 (seule une PR vers Staging/main prouve un arbre) et l'exigence de preuve au déploiement (ADR-0144).
- Toute promotion de documents seuls, dont les leçons de `docs/contenus/` (qui se déploient). Aucune donnée corrompue.
- Contournement : relancer une promotion qui touche du code, ou `workflow_dispatch` impossible sans preuve.

## Source du comportement attendu

ADR-0069 (la preuve est l'arbre), ADR-0107 (une PR vers Staging/main prouve son arbre), ADR-0144 (le déploiement exige la preuve).

## Correction retenue

« code=false » ne signifiait **pas** « code identique à une base prouvée » : c'est seulement « le diff de la PR (API
`pulls/files`, comparé au merge-base) ne nomme que des documents ». Rien ne vérifiait que la base était prouvée.

Condition sûre, dans « plan » (`script/ci/documents_proof`) :

1. l'arbre testé (commit de fusion GitHub) ne diffère de son premier parent (la tête de Staging/main) que par des documents
   (`git diff --no-renames`, les deux noms d'un renommage comptent) ;
2. l'arbre de ce parent est prouvé par `script/ci/tested_tree`, sans preuve locale (artefact d'une PR vers Staging/main).

Alors `documents_proven=true` et le verdict publie `ci-tree-<tree>` (leçons v3 vertes si présentes). Sinon, ou au moindre
doute, `code=true` : la suite entière tourne et prouve l'arbre. La publication reste limitée aux PR vers Staging et main.

## Hors périmètre

- Le plafond de 3 000 fichiers de l'API `pulls/files` (le contrôle git ci-dessus le rend sans effet sur la preuve).
- Toute modification de `deploiement.yml` ou des règles de `tested_tree`.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit : verdict rejoué en shell (pas d'application à manipuler, le bug vit dans la CI)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (`journal.md`)
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (« Rien à rejouer : … documents seulement », sans `proof=true`)
- [x] Correctif appliqué dans la couche de la **cause** (`plan` et `verdict` de `ci.yml`)
- [x] Test au vert · tests des workflows au vert
- [x] Cas symétrique vérifié : du code exige toujours unit, coverage, system et lecons verts
- [x] Données déjà corrompues : aucune
- [ ] Challenger : la prochaine promotion de documents seuls vers Staging doit se déployer
- [x] Commit `fix(ci): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
