# PRD — Les exercices en cartes

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un exercice s'affiche en quatre lignes différentes selon l'écran, sans matière ici, sans type là, sans action écrite nulle part ([memo](memo.md)). Ce chantier donne à chaque exercice listé une seule carte — titre, matière (sa couleur), type, état, action — et fait de chaque question de l'écran d'un exercice une carte numérotée qui dit son format.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir ses exercices en cartes (Ma classe, page d'une leçon) ; voir les questions en cartes | Voir le nombre de bonnes propositions d'une question |
| Teacher | Voir les exercices d'une leçon et les assignations de sa classe en cartes, avec ses bascules d'assignation | — (rien de nouveau) |
| Team | Voir les exercices d'une leçon en cartes, avec leur statut | — |

Aucune règle d'autorisation nouvelle : les policies en place (`ReadPublishedPolicy`, `FollowAssignmentPolicy`, ADR-0091 §4.4 pour la solution) décident déjà de ce qui est rendu ; la carte ne fait que l'afficher.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Ma classe » : chaque exercice assigné est une carte (pastille de la matière, « Matière · Type », titre, échéance, « Commencer » ou « Reprendre »).
2. Il touche la carte : l'écran de l'exercice s'ouvre.
3. Chaque question y est une carte : numéro, format (« Relier », « Une seule réponse »…), énoncé, propositions.
4. Les exercices traités sont des cartes avec la meilleure note et « Voir ma copie ».
5. L'enseignant ouvre sa classe : chaque assignation est une carte (matière, type, échéance, progression, « Voir le suivi ») ; sur la page d'une leçon, ses bascules d'assignation restent sous chaque carte.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun exercice | Les états vides existants, inchangés |
| Assignation sans droit de suivi | Carte sans lien ni action |
| Exercice en retard | Échéance en ambre (« En retard · prévu … »), jamais de rouge |
| Note < 10/20 sur la page de la leçon | Note en encre, action « Refaire » |
| Matière sans illustration connue | Pastille neutre |

## 4. Critères d'acceptation

```gherkin
CA-1
Étant donné un élève à qui un exercice de SVT (fixation) est assigné, non commencé
Quand il ouvre « Ma classe »
Alors l'exercice est une carte qui montre son titre, « SVT · Fixation », son échéance et l'action « Commencer »
Et toute la carte mène à l'écran de l'exercice

CA-2
Étant donné un élève qui a commencé un exercice assigné
Quand il ouvre « Ma classe »
Alors la carte de cet exercice dit « Reprendre »

CA-3
Étant donné un élève qui a terminé un exercice à 16/20
Quand il ouvre « Ma classe »
Alors la carte traitée montre « 16/20 » en vert et l'action « Voir ma copie », qui mène au résultat

CA-4
Étant donné un élève sur la page d'une leçon
Quand un exercice a une note sous 10/20
Alors sa carte montre la note en encre et l'action « Refaire »
Et un exercice à revoir montre « À revoir » et l'action « Revoir »

CA-5
Étant donné un enseignant sur la page d'une leçon
Alors chaque exercice publié est une carte avec « Voir l'exercice »
Et ses bascules d'assignation restent utilisables sous la carte

CA-6
Étant donné un enseignant sur la page de sa classe avec une assignation suivie
Alors l'assignation est une carte avec la matière, le type, l'échéance, la progression et « Voir le suivi »
Et une assignation sans droit de suivi est une carte sans lien

CA-7
Étant donné l'équipe sur la page d'une leçon
Alors chaque carte montre le statut éditorial de l'exercice

CA-8
Étant donné un élève sur l'écran d'un exercice de 4 formats de questions
Alors chaque question est une carte numérotée qui dit son format
Et une question à 3 propositions correctes dit « Plusieurs réponses », jamais « 3 propositions correctes »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun changement |
| Infrastructure | `exercise_type` ajouté aux lignes de lecture de « Ma classe » (assignés, traités) et du suivi de classe |
| Delivery | aucun changement |
| UI | partial `assessment/exercises/_card`, helper qui construit la carte depuis chaque ligne, cartes de question dans l'écran de l'exercice |

## 6. Décisions rattachées

- ADR : aucun — ni port, ni table, ni contrat de domaine ; un champ de lecture ajouté à trois `Data` de queries.
- UDR-XXXX-exercices-et-questions-en-cartes — la carte d'exercice et la carte de question.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Rendus différents d'un exercice listé | 4 | 1 partial | |
