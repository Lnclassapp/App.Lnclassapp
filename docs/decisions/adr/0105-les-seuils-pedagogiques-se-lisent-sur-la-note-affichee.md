# ADR-0105 : Les seuils pédagogiques se lisent sur la note affichée sur 20, partout, par un seul endroit : `Grading.reaches?`
<!-- index
titre: Les seuils pédagogiques se lisent sur la note affichée sur 20, partout
statut: Accepté — *amende 0033 §4 et 0101 §4.5*
problematique: Badges, maîtrise, « à revoir » et réussite de la classe comparaient le pourcentage brut à un seuil, alors que l'élève lit une note sur 20 : à 68 % il lit 14/20 en vert et reçoit « Fragile ». `Grading.reaches?(score, seuil)` compare les notes sur 20 ; le Diamant reste le sans-faute.
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-19, porteur : « Oui, partout ») |
| **Date** | 2026-10-19 |
| **Chantier** | [`docs/chantiers/note-sur-20-partout`](../../chantiers/note-sur-20-partout/memo.md) |
| **Remplace** | — |
| **Amende** | [ADR-0033](./0033-bareme-des-badges-et-seuils-pedagogiques.md) §4 (la lecture des seuils) · [ADR-0101](./0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.5 (dernière phrase) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'élève lit une note sur 20, arrondie une seule fois par `Grading.grade_on_20` (`(score_percent / 5.0).round`, ADR-0033 §4). Pourtant, hors des lacunes, les règles comparaient encore le **pourcentage brut** à un seuil : Bronze `>= 50`, Argent et « Acquis » `>= 70`, Or `>= 80`, « à revoir » `< 50`, élève « en réussite » `>= 50`. À 68 %, l'écran affichait **14/20 en vert** et, à côté, « Fragile » et un badge Bronze.

Le 2026-10-19, le porteur a décidé que la note affichée fait foi pour les lacunes (ADR-0101 §4.5, PR 256), puis répondu « Oui, partout » pour le reste.

## 2. Moteurs de décision

1. L'écran ne se contredit pas : une même note donne la même réponse partout.
2. L'arrondi vit à **un seul endroit** (`grade_on_20`) et aucune règle ne le recopie.
3. Les seuils gardent leur valeur et leur nom (ADR-0033) ; seule la façon de les lire change.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Garder le pourcentage brut hors des lacunes | Aucune ligne à changer | L'écran se contredit à 48 %, 68 %, 78 % |
| B — Ramener la note affichée au pourcentage (afficher 68 % partout) | Cohérent aussi | Contraire à la décision UDR-0023 : l'élève lit des notes sur 20 |
| C — **Toute règle compare `grade_on_20(score)` à `grade_on_20(seuil)`, par `Grading.reaches?`** | Une règle, un arrondi, l'écran cohérent | Les seuils effectifs bougent de quelques points (voir §4) |

## 4. Décision

> **Un score atteint un seuil quand sa note sur 20 atteint celle du seuil. La comparaison se fait dans `Entities::Assessment::Grading.reaches?(score_percent, threshold)` et nulle part ailleurs ; l'arrondi reste dans `grade_on_20`.**

```ruby
def self.reaches?(score_percent, threshold) = grade_on_20(score_percent) >= grade_on_20(threshold)
```

### 4.1 Effet sur les seuils

| Seuil | Note du seuil | Atteint dès | Avant |
|---|---|---|---|
| `PASS_THRESHOLD` (50) : Bronze, « Fragile », élève en réussite, lacune | 10/20 | 48 % | 50 % |
| `MASTERY_THRESHOLD` (70) : Argent, « Acquis », « stable » | 14/20 | 68 % | 70 % |
| `REMEDIATION_THRESHOLD` (75) : lacune levée | 15/20 | 73 % | 73 % depuis la PR 256 |
| `GOLD_THRESHOLD` (80) : Or | 16/20 | 78 % | 80 % |

Le seuil de `PERFECT_THRESHOLD` (100) n'est pas dans ce tableau : voir §4.3.

### 4.2 Règles alignées

`Grading.badge_for` (Bronze, Argent, Or), `Grading.mastery_for`, `GapDecision`, `Comprehension.trend_for` (stable ou stagne), `Comprehension.to_revisit?` (une question n'est « à revoir » que sous 10/20, 48 % est donc lu 10/20 et n'est plus à revoir), et le comptage des élèves en réussite de `ClassroomEssentialQuery`. Les vues qui recopiaient `grade_on_20(score) >= grade_on_20(MASTERY_THRESHOLD)` ou un `>= 14` appellent `reaches?`.

### 4.3 Le Diamant reste le sans-faute

`score_percent` est une division entière arrondie vers le bas : il ne vaut 100 que si **toutes** les réponses sont justes (ADR-0033). Lu sur 20, 98 % s'afficherait 20/20 et donnerait un « sans-faute » faux (possible dès 50 questions). Le Diamant est un fait, pas un seuil : `Grading.perfect?(score)` (`score >= PERFECT_THRESHOLD`) le dit, et `badge_for` ne passe par `reaches?` que pour Bronze, Argent et Or. Le bouton « Recommencer » de la page de résultat, qui disparaît au sans-faute, suit la même règle.

### 4.4 Ce qui n'est pas une décision et ne bouge pas

- Les **moyennes** (moyenne de classe, « Réussite moyenne » de l'équipe, travail des élèves) : des statistiques, aucun score n'y est comparé à un seuil. Arrondir chaque note avant de moyenner changerait la moyenne sans rien décider.
- `Comprehension::PROGRESS_MARGIN` : un écart entre deux scores, pas un seuil.
- Le **taux de rendu** de la direction (`WorkSignal`, vert dès 70 %) : un taux de devoirs rendus, aucune note derrière.
- La note affichée et son arrondi : inchangés.

### 4.5 Textes

Les textes qui citaient un seuil en pourcentage (infobulles « Badge » et « Maîtrise », FAQ) se lisent sur 20 et se calculent depuis `Grading`, jamais en dur (UDR-0128).

## 5. Conséquences

### 🟢 Positives

- Une note donne la même réponse partout : couleur, badge, maîtrise, aide.
- Un seul endroit compare un score à un seuil ; ajouter une règle ne rouvre pas la question de l'arrondi.
- Aucune migration, aucune route.

### 🔴 Coûts consentis

- Les seuils effectifs baissent de 1 à 2 points (§4.1) : un élève à 48 % obtient Bronze, un exercice à 48 % de bonnes réponses n'est plus « à revoir ».
- **Les badges déjà décernés ne sont pas recalculés.** Un badge s'écrit à la clôture et ne descend jamais (ADR-0033) ; un élève dont la meilleure session valait 48 %, 68 % ou 78 % garde le palier d'avant jusqu'à sa prochaine session. Si le porteur veut un rattrapage, c'est un chantier de données à part.
- Le Diamant ne suit pas la règle : 98 % et 99 % s'affichent 20/20 sans Diamant. C'est voulu (§4.3), mais ça se verra sur un exercice de 50 questions ou plus.

## 6. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/grading_test.rb` : `reaches?` aux bornes des quatre seuils ; `badge_for` à 47, 48, 67, 68, 77, 78, 99, 100 ; `mastery_for` à 47, 48, 67, 68 ; `perfect?` à 98, 99, 100.
- `test/domain/entities/assessment/gap_decision_test.rb`, `comprehension_test.rb`, `test/infrastructure/queries/classroom/classroom_essential_query_test.rb` : les mêmes bornes.
- `git grep -nE "score[a-z_]* *(>=|<) *[A-Za-z:]*_?THRESHOLD|(>=|<) *(Entities::Assessment::)?Grading::[A-Z_]*THRESHOLD" app` ne trouve que `Grading.perfect?`.

## 7. Remplace, complète, amende

- **Amende** l'ADR-0033 §4 : les seuils 50, 70, 80 se lisent sur la note affichée ; le Diamant reste le sans-faute.
- **Amende** l'ADR-0101 §4.5 : sa dernière phrase (« Les autres seuils […] restent sur le pourcentage brut ») est remplacée par le présent ADR. Le reste du §4.5 est inchangé.
- **S'appuie sur** l'ADR-0043 (seuil de remédiation 75), UDR-0023 (la note sur 20).
