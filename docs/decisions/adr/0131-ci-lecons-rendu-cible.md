# ADR-0131 : Le train rend les leçons changées, plus les 223
<!-- index
titre: Rendu ciblé des leçons au train
statut: Accepté
problematique: Rendre toutes les leçons v3 à chaque train coûte 98,7 min de machine et grandit avec chaque vague de leçons.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-12 |
| **Chantier** | `docs/chantiers/ci-lecons-rendu` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La tâche `lecons` du train rendait les 223 leçons v3 en 32 parts : 98,7 min de machine (run #541, `cf0483e70`), ≈ 20 s par leçon et ≈ 49 s d'installation par part. Environ 100 leçons de plus sont attendues : ≈ 46 parts. Ce que prouvait un train (ADR-0107 ; ADR standard-de-test §4 point 4) incluait donc « toutes les leçons se rendent ».

## 2. Moteurs de décision

- Minutes de machine par train, stables quand le corpus grandit.
- Aucun défaut détecté n'est retiré de la vérification.

## 3. Options envisagées

Rendre plus vite chaque leçon : gardé pour la suite. Rendu complet de nuit : écarté par le porteur (2026-11-12), remplacé par le rendu complet quand le train touche aux écrans. Retenu ici : rendre ce qui change (décision du porteur du 2026-11-12).

## 4. Décision

> **Au train vers Staging, la tâche `lecons` rend seulement les leçons v3 nouvelles ou modifiées de la PR (⌈N/8⌉ parts calculées par le job `plan`) ; s'il n'y en a aucune, ou si le diff est illisible (avec `::warning::`), 2 leçons témoins de `script/ci/lecons_temoins.txt`, en 1 part. `LECONS=tout` reste disponible à la main.**
>
> **Exception (lot B) : si la PR touche aux écrans (vues, JavaScript, assets, aides, catalogue qui les lit, dépendances front, test de rendu), `plan` passe `LECONS=tout` et la tâche rend toutes les leçons, ⌈nombre/8⌉ parts. Pas de rendu hebdomadaire.**

## 5. Conséquences

### 🟢 Positives

- Un train sans leçon changée coûte 1 part au lieu de 32 ; un train avec N leçons en coûte ⌈N/8⌉.

### 🔴 Coûts consentis

- Une PR qui ne touche pas aux écrans ne voit une régression sur une leçon ancienne que par les 2 témoins (formules, figures, tableaux, feuilles), pas par les 221 autres ; une PR qui les touche paie 23 parts.

## 6. Notes d'implémentation

`.github/workflows/ci.yml` (étape `changes` du job `plan`, job `lecons`) ; `LessonRendering::Selection.call` applique `LECONS_PART` à une liste nommée (`test/system/catalog/lesson_rendering_test.rb`).

## 7. Comment vérifier que la décision est respectée

`test/guards/ci_plan_test.rb` (matrice issue de `plan`, 5 min, un processus, expression des écrans et branche `lecons_files=tout`) et `Catalog::LessonSelectionTest` (découpage d'une liste nommée, témoins existants et v3).

## Amendement du 2026-11-12 — 8 leçons par part

Train #545 (`bd1d61bd`), rendu complet en 23 parts de 10 leçons : part la plus longue 283 s, médiane 239 s, pour un plafond de 300 s. Décision du porteur : 8 leçons au plus par part, ⌈N/8⌉ parts (≈ 230 s au pire).
