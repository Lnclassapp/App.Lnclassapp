# Memo — Bronze pour tout exercice traité

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
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

- Aucune vue ni libellé ne change (c'est le rôle des chantiers d'écrans).
- Pas de migration ni de rattrapage : seules les nouvelles clôtures donnent Bronze sous 48 % (porteur).
- Seuil de remédiation (75 %) inchangé.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les sessions déjà clôturées sous 48 % reçoivent-elles Bronze ? | Non : seulement les nouvelles clôtures (porteur) | Aucune migration ni rattrapage ; les écrans gèrent l'absence de médaille ancienne par « Pas encore » |

## Cas limites identifiés

- Exercice commencé mais abandonné, ou rendu à 0 % : traité ou non ?
- Moyenne de classe côté élève (`class_badge_for`) sous 48 %.

## Questions encore ouvertes

1. Une copie clôturée à 0 % ou laissée vide donne-t-elle Bronze ?
