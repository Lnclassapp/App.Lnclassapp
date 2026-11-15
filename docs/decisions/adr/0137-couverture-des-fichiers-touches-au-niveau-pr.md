# ADR-0137 : La couverture des fichiers touchés se voit au niveau pr, en avertissement
<!-- index
titre: Couverture des fichiers touchés au niveau pr
statut: Accepté
problematique: Le seuil de couverture de branches (ADR-0024) n'est contrôlé qu'au train ; une PR vers Develop ne voit jamais ses branches non jouées, qui arrêtent ensuite la promotion.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-15 |
| **Chantier** | [`docs/chantiers/couverture-branches-visible`](../../chantiers/couverture-branches-visible/memo.md) |
| **Remplace** | — |
| **Remplacé par** | — |
| **Amende** | [ADR-0107](0107-la-preuve-d-une-pr-suit-ce-qu-elle-touche.md) (niveau pr) ; ne change pas le seuil de l'[ADR-0024](0024-couverture-de-tests-a-100-pourcent.md) |

---

## 1. Contexte et problématique

Le train #631 a arrêté la PR #627 : 100 % des lignes mais 6917 / 6919 branches. La preuve `bin/ci-quiet` niveau `pr` de la PR était verte, car ses tests unitaires jouent sous `COVERAGE=0`.

## 2. Moteurs de décision

1. Voir l'écart avant la fusion dans `Develop`.
2. Aucune tâche de CI ne dépasse 5 minutes ; le niveau `pr` reste court (ADR-0107).
3. La suite complète et le seuil global ne tournent qu'une fois par train.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Suite complète avec mesure au niveau `pr` | Le seuil exact | Déplace la suite complète dans la PR (ADR-0107) |
| B — Tâche GitHub sur les PR vers `Develop` | Visible sur la PR | Pas de CI GitHub vers `Develop` (ADR-0069) |
| C — **Mesurer les tests déjà joués au niveau `pr`, lire les seuls fichiers touchés, avertir** ✅ | ≈ 5,5 s de plus, aucun test de plus, a nommé les deux branches du train #631 | Faux positifs possibles (une branche jouée hors du périmètre) |
| D — Même mesure, mais bloquante | Aucun écart ne passe | Bloque sur des faux positifs (1 sur 3 sur la PR #627) |

## 4. Décision

> **Au niveau `pr`, les tests unitaires du périmètre jouent avec la mesure de couverture (`COVERAGE_PART=pr`, sans seuil). `script/ci/coverage_touched` nomme, pour les seuls fichiers `app/` et `lib/` touchés, les lignes et branches qu'aucun de ces tests ne joue. `bin/ci-quiet` l'affiche : un avertissement, jamais un blocage. Le seuil de 100 % reste contrôlé sur la suite complète, une fois par train.**

## 5. Conséquences

### 🟢 Positives

- Sur la PR #627 avant correction, les deux branches du train #631 sont nommées (lignes 163 et 185 de `courses_controller.rb`).
- Surcoût mesuré : ≈ 5,5 s sur une étape unitaire de 56 fichiers de test (23,7 s → 29,4 s).

### 🔴 Coûts consentis

- Un sous-ensemble de la suite ne peut que sous-estimer la couverture : un avertissement peut viser une branche jouée par un test hors du périmètre (1 sur 3 sur la PR #627). Aucun blocage pour cette raison.
- Un fichier touché sans test dans le périmètre n'est pas mesuré (l'étape ne joue pas) ; le train reste le filet.

## 6. Notes d'implémentation

- `script/ci/coverage_touched(.rb)` ; câblage dans `bin/ci-quiet` (niveau `pr`) ; tests : `test/config/coverage_touched_test.rb`.
- L'avertissement est gardé dans `tmp/ci-coverage-touched.txt` sous l'empreinte du code et redit tant qu'elle ne change pas.

## 7. Comment vérifier que la décision est respectée

`bin/ci-quiet` sur une PR qui touche un fichier `app/` ou `lib/` dont une branche n'est pas jouée affiche `⚠️  Branch coverage: …` avec le fichier et la ligne.
