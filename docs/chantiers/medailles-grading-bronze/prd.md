# PRD — Bronze pour tout exercice traité

## 1. Contexte

Le porteur veut que tout exercice traité donne au moins Bronze (memo). Aujourd'hui un score sous 48 % ne donne aucune médaille. La médaille d'un exercice devient une valeur enregistrée à la clôture, lue telle quelle par les écrans.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Gagne et voit la médaille de ses exercices | Voir celle d'un autre élève |
| Teacher | Lit les médailles des élèves de ses classes (règles de classe inchangées) | Modifier une médaille |
| Parent, SchoolStaff, Team | Rien de nouveau | — |

Aucune policy ne change.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève rend une copie avec au moins une réponse donnée et un score sous 48 %.
2. La session est clôturée : la médaille Bronze est enregistrée pour cet exercice.
3. L'écran de résultat montre la médaille Bronze, sans « Nouvelle médaille ! » ni confettis.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Copie entièrement vide (aucune réponse) | Aucune médaille ; « Pas encore » |
| Score de 48 à 67 % | Bronze, avec « Nouvelle médaille ! » à la première obtention (inchangé) |
| Bronze déjà détenu, nouvelle copie sous 48 % | Rien ne change (une médaille ne descend jamais) |
| Sessions clôturées avant ce chantier, sous 48 % | Restent sans médaille ; aucun rattrapage |
| Élève dans deux classes | Une seule médaille par exercice |
| Moyenne d'un élève dans une classe sous 48 % avec au moins un exercice médaillé | Bronze |
| Aucun exercice médaillé dans la classe | « Pas encore » |

## 4. Critères d'acceptation

```gherkin
Scénario: Bronze sous 48 % avec au moins une réponse
  Étant donné un élève qui rend une copie à 20 % avec 2 réponses données
  Quand la session est clôturée
  Alors sa médaille de cet exercice est Bronze

Scénario: Copie entièrement vide
  Étant donné un élève qui rend une copie sans aucune réponse
  Quand la session est clôturée
  Alors aucune médaille n'est enregistrée
  Et l'écran de résultat affiche « Pas encore »

Scénario: Pas de fête sous 48 %
  Étant donné une première médaille Bronze obtenue à 20 %
  Quand l'élève ouvre le résultat
  Alors la médaille Bronze s'affiche
  Et ni « Nouvelle médaille ! » ni les confettis ne s'affichent

Scénario: La fête reste à partir de 48 %
  Étant donné une première médaille Bronze obtenue à 50 %
  Quand l'élève ouvre le résultat
  Alors « Nouvelle médaille ! » s'affiche

Scénario: Les paliers au-dessus de Bronze sont inchangés
  Étant donné des copies à 48, 68, 78 et 100 %
  Alors les médailles sont Bronze, Argent, Or, Diamant

Scénario: Les écrans lisent la médaille enregistrée
  Étant donné un élève avec une médaille Bronze enregistrée et un meilleur score de 20 %
  Quand l'enseignant ouvre le rapport de l'exercice, la fiche élève ou la liste de classe
  Alors Bronze s'affiche, jamais « Pas encore »

Scénario: Pas de rattrapage
  Étant donné une session clôturée avant ce chantier à 20 %
  Alors aucune médaille n'est ajoutée par la mise en production

Scénario: Médaille de classe
  Étant donné un élève dont la moyenne est de 30 % et qui a une médaille Bronze
  Alors sa médaille de classe est Bronze
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Grading.badge_for` inchangé pour le palier du score ; nouvelle règle « au moins Bronze si une réponse » dans la clôture ; `class_badge_for` reçoit le fait « a une médaille » |
| Infrastructure | Aucune migration. Les 6 requêtes qui recalculent depuis le score lisent `exercise_badges.level` |
| Delivery | Aucun contrôleur nouveau |
| UI | Résultat : Bronze sans fête sous 48 %, « Pas encore » sans médaille |

## 6. Décisions rattachées

- ADR-XXXX-medailles-lues-a-la-cloture
- UDR-XXXX-bronze-sans-fete-sous-48
- Pas de seuil de rendu (retiré du périmètre).

## 7. Mesures

Sans objet.
