# PRD — La note sur 20 décide partout

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier.

## 1. Contexte

Décision du porteur (2026-10-19, « Oui, partout ») : la note affichée sur 20, arrondie une seule fois par `Grading.grade_on_20`, décide de toute règle « réussi / acquis / à revoir », comme elle le fait déjà pour les lacunes (ADR-0101 §4.5). Inventaire dans le [memo](memo.md).

## 2. Acteurs et permissions

Aucun changement : pas de nouvelle action ni de permission. Élève et enseignant lisent les mêmes écrans ; seule la décision qui les alimente change.

## 3. Parcours utilisateur

Aucun parcours nouveau. Un score de 68 % : la note, la couleur, le badge Argent, la maîtrise « Acquis » et l'aide disent la même chose (14/20).

| Situation | Comportement attendu |
|---|---|
| Score de 48 % à la clôture | Note 10/20, badge Bronze, maîtrise « Fragile », aucune lacune ouverte |
| Score de 47 % | Note 9/20, aucun badge, « En difficulté », lacune ouverte |
| Infobulles et FAQ des badges et de la maîtrise | Seuils lus sur 20, jamais en pourcentage |

## 4. Critères d'acceptation

Chacun devient un test, aux bornes.

```gherkin
Règle générale
  Quand on compare un score à un seuil
  Alors Grading.reaches?(score, seuil) vaut grade_on_20(score) >= grade_on_20(seuil)
  Et reaches?(47, 50) est faux, reaches?(48, 50) est vrai
  Et reaches?(67, 70) est faux, reaches?(68, 70) est vrai
  Et reaches?(72, 75) est faux, reaches?(73, 75) est vrai
  Et reaches?(77, 80) est faux, reaches?(78, 80) est vrai

Badges
  Quand badge_for vaut 47 Alors aucun palier ; 48 et 67 Alors :bronze ; 68 et 77 Alors :silver
  Et 78 et 99 Alors :gold ; 100 Alors :diamond
  Et 98 % s'affiche 20/20 mais ne donne pas de Diamant : le Diamant reste le sans-faute (Grading.perfect?)

Maîtrise
  Quand mastery_for vaut 47 Alors :struggling ; 48 et 67 Alors :fragile ; 68 Alors :acquired

Compréhension
  Quand to_revisit?(47) Alors vrai ; to_revisit?(48) Alors faux ; to_revisit?(nil) Alors faux
  Et trend_for([67, 67]) vaut :stagnant ; trend_for([68, 68]) vaut :stable

Taux de réussite de la classe sur une fiche
  Étant donné des meilleurs scores de 47 % et de 48 % dans la classe
  Alors passed_students_count ne compte que celui de 48 %

Lacune (comportement inchangé)
  Quand 48 % et 49 % Alors rien (10/20) ; 47 % Alors ouvre ; 73 % et 74 % Alors lèvent ; 72 % Alors rien

Écrans
  Les infobulles « Badge » et « Maîtrise » et les réponses « badges » et « maîtrise » de la FAQ citent des notes sur 20
  calculées depuis Grading, sans aucun « % » de seuil.
  Aucune règle de app/ ne compare un score brut à un *_THRESHOLD, hors Diamant (le sans-faute).
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Grading.reaches?` et `Grading.perfect?` ; `badge_for`, `mastery_for`, `GapDecision`, `Comprehension` les utilisent |
| Infrastructure | `ClassroomEssentialQuery#success` utilise `reaches?` |
| Delivery | aucun |
| UI | cinq vues ramenées à `reaches?` ; `BadgesHelper#badges_tip` et `#mastery_tip` ; locales `shared.info_tips` et `communication.help` |

Aucune migration, aucune route.

## 6. Décisions rattachées

- ADR-0105 — Les seuils pédagogiques se lisent sur la note affichée (amende ADR-0033 §4 et ADR-0101 §4.5).
- UDR-0128 — Paliers et maîtrise lus sur 20 dans les infobulles et la FAQ.

## 7. Mesures

Sans objet.
