# PRD — Le sujet se lit comme une vraie épreuve

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La page de lecture d'une feuille « Prépare interros » ou « Prépare devoirs » (UDR-0151) montre le sujet dans la mise en page du cahier à remplir. Le pilote veut qu'elle ressemble à une vraie épreuve, sur le modèle d'un BEPC blanc qu'il a fourni : cartouche, titre « ÉPREUVE DE … », exercices avec leurs points, affirmations en tableau, figure à côté de l'énoncé. La feuille à remplir ne change pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | lire le sujet en forme d'épreuve (leçon et « Ma classe »), puis « Commencer » / « Continuer » | voir l'indice ou la correction sur la page de lecture |
| Teacher | lire le sujet en forme d'épreuve, avec ses bascules d'envoi sous chaque exercice | commencer la feuille (inchangé) |
| Team | lire le sujet en forme d'épreuve, brouillons compris, avec la mention « Brouillon » | commencer la feuille (inchangé) |
| Parent, SchoolStaff | — (pas de page de feuille, inchangé) | — |

Autorisations inchangées : celles des pages de lecture de l'UDR-0151 (`ReadPublishedPolicy`, `ReadClassroomPolicy`, devoirs de la classe principale de l'élève).

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre la case « Prépare devoirs n°1 » de Thalès.
2. Il lit une épreuve : cartouche « PRÉPARE DEVOIRS N°1 · MATHÉMATIQUES » (leçon, classe, sujet x / n), titre « ÉPREUVE DE MATHÉMATIQUES », consigne « Cette épreuve comporte 2 exercices. », puis « Exercice 1 (6 points) » : énoncé avec la figure à côté, tableau V/F, tableau A/B/C/D des QCM, puis « f. … » en liste.
3. En bas, la mention « Sujet d'entraînement rédigé par Lnclass. Ce n'est pas un sujet officiel. », puis « Commencer Prépare devoirs ».
4. Il clique : la feuille à remplir s'ouvre, inchangée (« Notions mobilisées » compris).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Écran de 390 px | Les tableaux tiennent dans l'écran (texte qui passe à la ligne, taille réduite) ; une formule trop large défile dans sa cellule, jamais la page |
| Exercice sans question | Son énoncé seul, sans points ni tableau |
| Enseignant | La même épreuve, ses bascules sous chaque exercice, pas de « Commencer » |
| Feuille inconnue | Inchangé : 303 vers la page hôte, « Cette feuille n'existe plus. » |

## 4. Critères d'acceptation

```gherkin
Scénario: la page de lecture est une épreuve
  Étant donné un élève de 3ème et le sujet 1 de Thalès (2 exercices, 6 et 4 points)
  Quand il ouvre la case « Prépare devoirs n°1 »
  Alors il voit le cartouche « PRÉPARE DEVOIRS N°1 » et « MATHÉMATIQUES »
  Et le titre « ÉPREUVE DE MATHÉMATIQUES » et « Cette épreuve comporte 2 exercices. »
  Et « Exercice 1 (6 points) » puis « Exercice 2 (4 points) »
  Et la mention « Sujet d'entraînement rédigé par Lnclass. Ce n'est pas un sujet officiel. »
  Et ni champ, ni bouton de choix, ni « Vérifier ma réponse », ni indice, ni « Notions mobilisées »

Scénario: les QCM qui se suivent forment un tableau A/B/C
  Étant donné un exercice dont les questions b à e sont des QCM à 4 propositions
  Quand l'élève lit le sujet
  Alors un tableau a les colonnes « N° », « Affirmation », « A », « B », « C », « D »
  Et ses lignes sont « b » à « e », chaque proposition dans sa colonne
  Et un QCM à 2 bonnes réponses porte « Coche 2 réponses. » dans sa ligne

Scénario: les vrai ou faux qui se suivent forment un tableau V/F
  Étant donné un exercice dont la question a est un vrai ou faux
  Quand l'élève lit le sujet
  Alors un tableau a les colonnes « N° » et « Affirmation » avec la ligne « a »
  Et la consigne dit d'indiquer V si elle est vraie, F si elle est fausse

Scénario: les autres questions restent en liste
  Étant donné une question de calcul f
  Quand l'élève lit le sujet
  Alors elle s'écrit « f. » suivi de son énoncé, hors tableau

Scénario: un Prépare interros n'a pas « À retenir » en lecture
  Étant donné la notion 1 de Thalès et son « À retenir »
  Quand l'élève lit « Prépare interros n°1 »
  Alors la page n'a pas l'encadré « À retenir »
  Et la feuille à remplir l'a toujours

Scénario: les points d'un exercice sont la somme de ses questions
  Étant donné un exercice de questions à 1, 1 et 0,5 point
  Alors il s'intitule « Exercice 1 (2,5 points) »
  Et un exercice d'une question à 1 point s'intitule « (1 point) »

Scénario: l'enseignant lit la même épreuve avec ses bascules
  Étant donné l'enseignant de maths de la 3ème 1
  Quand il ouvre une feuille depuis sa classe
  Alors il voit l'épreuve et ses bascules d'envoi sous chaque exercice
  Et pas « Commencer »

Scénario: à 390 px, rien ne déborde
  Étant donné un écran de 390 px
  Quand l'élève lit le sujet 1 de Thalès
  Alors la page ne défile pas sur le côté
  Et chaque tableau tient dans la largeur de la feuille
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien |
| Infrastructure | les points de chaque question dans la lecture des feuilles (requête existante) |
| Delivery | rien (contrôleurs et routes inchangés) |
| UI | un partiel « épreuve » rendu par les trois pages de lecture ; feuille de style des feuilles ; libellés |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni dépendance, ni contrat nouveaux ; une colonne existante (les points des questions) entre dans une requête de lecture existante.
- UDR-0152 (amende l'UDR-0151 §3, page de lecture).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Défilement horizontal à 390 px sur les 8 feuilles de Thalès | 0 | 0 | |
