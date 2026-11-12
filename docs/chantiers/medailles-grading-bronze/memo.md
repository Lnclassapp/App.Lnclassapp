# Memo — Bronze pour tout exercice traité

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `feature/medailles-grading-bronze` |
| **Programme** | — (précède `medailles-eleve`, voir `medailles-vocabulaire/plan.md`) |

---

## Le problème

Le porteur a décidé que tout exercice traité donne au moins Bronze. Aujourd'hui, un score sous 48 % ne donne aucune médaille (`nil`), côté exercice comme côté classe. Les écrans futurs ne peuvent donc pas « lire la médaille » sans trou.

## Correspondance note / % → médaille (aujourd'hui, et cible)

Le palier se lit sur la note sur 20 arrondie (ADR-0106) : 48 % s'affiche 10/20 et atteint Bronze.

| Pourcentage | Note affichée | Médaille aujourd'hui | Médaille cible |
|---|---|---|---|
| 0 à 47 % | 0 à 9/20 | aucune | **Bronze** |
| 48 à 67 % | 10 à 13/20 | Bronze | Bronze |
| 68 à 77 % | 14 à 15/20 | Argent | Argent |
| 78 à 99 % | 16 à 20/20 | Or | Or |
| 100 % (sans faute) | 20/20 | Diamant | Diamant |

98 et 99 % s'affichent 20/20 mais restent Or : seul le sans-faute donne le Diamant.

## Pour qui

Élève (sa médaille d'exercice), enseignant et direction (répartition de la classe). Parent et équipe : aucun écran de médaille concerné ici.

## Pourquoi maintenant

Prérequis des chantiers d'écrans (`medailles-eleve` en premier) : sans cette règle, « Pas encore » apparaîtrait pour des exercices faits.

## Hors périmètre

- Aucun seuil de rendu : un élève peut toujours rendre sa copie comme aujourd'hui.
- Aucune vue ni libellé ne change (c'est le rôle des chantiers d'écrans).
- Pas de migration ni de rattrapage : seules les nouvelles clôtures donnent Bronze sous 48 % (porteur).
- Seuil de remédiation (75 %) inchangé.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les sessions déjà clôturées sous 48 % reçoivent-elles Bronze ? | Non : seulement les nouvelles clôtures (porteur) | Aucune migration ni rattrapage ; les écrans gèrent l'absence de médaille ancienne par « Pas encore » |
| Une copie à 0 % ou vide donne-t-elle Bronze ? | Bronze seulement si au moins une réponse donnée ; copie vide = « Pas encore » (porteur) | La règle lit les réponses, pas seulement le score |
| Faut-il exiger un minimum de réponses pour rendre ? | Non, on simplifie : pas de seuil de rendu (porteur) | Aucun changement de l'écran de la copie en cours ; seule la règle de médaille change |
| Médaille d'un élève dans une classe sous 48 % de moyenne ? | Bronze dès qu'un exercice a une réponse (porteur) | La règle de classe suit la règle par exercice, la moyenne ne bloque plus Bronze |
| Bronze sous 48 % affiche-t-il « Nouvelle médaille ! » et les confettis ? | Non : médaille décernée et affichée, sans fête sous 48 % (porteur) | Une petite UDR sur l'écran de résultat |
| Parent, direction, équipe, multi-classes ? | Aucun écran de médaille pour le parent ; la médaille appartient à l'élève et à l'exercice, pas à la classe : un élève dans deux classes garde une seule médaille par exercice (constat) | Aucun cas de doublon ; les lectures de classe suivent la règle de classe |

## Cas limites identifiés

- Exercice commencé mais abandonné, ou rendu à 0 % : traité ou non ?
- Moyenne de classe côté élève (`class_badge_for`) sous 48 %.

## Questions encore ouvertes

1. Conception : les écrans recalculent la médaille depuis le score, qui ignore si l'élève a répondu. La médaille de l'exercice se lit-elle dans la médaille enregistrée à la clôture (recommandé) ou se recalcule-t-elle depuis le score + le nombre de réponses ?
