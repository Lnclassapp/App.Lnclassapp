# PRD — Refaire ou continuer depuis la correction

## 1. Contexte

Voir [`memo.md`](memo.md). La page de correction d'une copie vérifiée depuis une feuille ramène l'élève à sa feuille : « Refaire l'exercice » la rouvre avec cet exercice vide, « Continuer les exercices » la rouvre à l'exercice qu'il lui reste à faire.

## 2. Acteurs et permissions

| Acteur | Ce qu'il voit | Ce qu'il peut faire |
|---|---|---|
| Student (propriétaire de la copie, venu d'une feuille) | « Refaire l'exercice », « Continuer les exercices » / « Reprendre le devoir », ou « Retour à la leçon » / « Retour à Ma classe » | Revenir à sa feuille |
| Teacher, Team | La correction, inchangée | — |
| Parent, SchoolStaff | Rien (inchangé) | — |

Autorisations inchangées : `ReadSessionPolicy` pour la correction ; la feuille à remplir garde ses propres refus.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur « Prépare devoirs n°1 » de Thalès, l'élève remplit l'exercice 1 et clique « Vérifier ma réponse ».
2. La correction s'ouvre. Il clique « Continuer les exercices ».
3. La feuille à remplir s'ouvre sur l'exercice 2. L'exercice 1 montre ses réponses, son statut et « Voir ma correction ».
4. Il remplit l'exercice 2, le vérifie, obtient 8/20 et clique « Refaire l'exercice ».
5. La feuille s'ouvre sur l'exercice 2, vide, avec « Vérifier ma réponse ».

### Chemins alternatifs et erreurs

- Dernier exercice non fait vérifié : la correction montre « Retour à la leçon » (lien vers la case de la feuille sur la leçon).
- Devoir de « Ma classe » : « Reprendre le devoir » ouvre le devoir à remplir sur l'exercice suivant non fait ; tout fait : « Retour à Ma classe ».
- Feuille introuvable : « Retour à la leçon » / « Retour à Ma classe ».
- Sans-faute ou pause : « Refaire » caché ou remplacé par l'heure de reprise (inchangé).
- `redo` qui ne désigne pas un exercice de la feuille : ignoré.

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Refaire ou continuer depuis la correction

  Scénario: Continuer va à l'exercice suivant non fait
    Étant donné une feuille de 3 exercices dont l'élève a vérifié le 1
    Quand il ouvre la correction du 1 venue de la feuille
    Alors il voit le lien « Continuer les exercices » vers la feuille à remplir, ancre de l'exercice 2

  Scénario: Continuer revient au premier non fait
    Étant donné une feuille de 3 exercices dont l'élève a vérifié le 2 et le 3, pas le 1
    Quand il ouvre la correction du 3
    Alors le lien « Continuer les exercices » vise l'ancre de l'exercice 1

  Scénario: Tout est fait
    Étant donné une feuille dont l'élève a vérifié tous les exercices
    Quand il ouvre la correction du dernier
    Alors il voit « Retour à la leçon » vers la leçon, ancre de la case de la feuille
    Et il ne voit pas « Continuer les exercices »

  Scénario: Devoir de Ma classe
    Étant donné un devoir de 2 exercices dont l'élève a vérifié le 1
    Quand il ouvre sa correction venue de « Ma classe »
    Alors « Reprendre le devoir » vise le devoir à remplir, ancre de l'exercice 2
    Et quand les 2 sont vérifiés, il voit « Retour à Ma classe »

  Scénario: Refaire ramène à la feuille avec l'exercice vide
    Étant donné un élève qui a obtenu 8/20 à l'exercice 2 d'une feuille
    Quand il clique « Refaire l'exercice » sur la correction
    Alors la feuille à remplir s'ouvre sur l'exercice 2
    Et ses champs sont vides et « Vérifier ma réponse » est visible
    Et l'exercice 1 garde ses réponses vérifiées

  Scénario: Une adresse trafiquée ne change rien
    Quand l'élève ouvre la feuille à remplir avec un exercice à refaire qui n'est pas sur la feuille
    Alors la feuille s'ouvre et aucun exercice n'est remis à blanc

  Scénario: Hors d'une feuille, rien ne change
    Quand l'élève ouvre une correction sans feuille
    Alors « Refaire l'exercice » reste le bouton de l'ancien lecteur et « Retour à la leçon » mène à la leçon
```

## 5. Modélisation préliminaire

- Infrastructure (lecture) : la feuille de la leçon et la feuille d'un devoir savent donner l'exercice à continuer après un exercice donné (suivant non fait, sinon premier non fait, sinon rien).
- Delivery : la page de correction lit la feuille de l'élève (requêtes existantes) quand elle vient d'une feuille ; la feuille à remplir accepte l'exercice à refaire, vérifié parmi les siens.
- UI : boutons de la correction ; la feuille remet à blanc l'exercice demandé, comme son propre « Refaire ».
- Aucun port, aucune table, aucune route nouvelle.

## 6. Décisions rattachées

- Pas d'ADR : aucune table, aucun port, aucun contrat de domaine.
- UDR-0153 (amende l'UDR-0138 §3.4 et l'UDR-0151 §3 pour les boutons de la correction).

## 7. Mesures

- Depuis la correction, l'élève atteint l'exercice suivant de sa feuille en 1 clic, sans défiler.
