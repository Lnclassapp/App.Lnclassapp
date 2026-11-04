# PRD — Chaque feuille dans une case, lue avant de commencer

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Sur la page d'une leçon, les feuilles « Prépare interros » et « Prépare devoirs » sont empilées et déjà prêtes à remplir ; dans « Ma classe », les devoirs reçus aussi. Chaque feuille devient une case. La case ouvre le sujet complet, en lecture, comme un vrai sujet ; en bas, « Commencer » (ou « Continuer ») ouvre la feuille à remplir d'aujourd'hui.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir les cases et sa progression, lire le sujet, commencer ou continuer, rendre un devoir reçu | ouvrir la feuille d'une leçon qu'il ne peut pas lire ou le devoir d'une autre classe |
| Visiteur (non connecté) | comme l'élève sur une leçon publique ; ses réponses restent dans son navigateur | « Ma classe » |
| Teacher | voir les cases, lire le sujet avec ses bascules d'envoi et le bandeau d'envoi | commencer ou remplir une feuille (redirigé vers la lecture) |
| Team | voir les cases et le sujet, brouillons compris | commencer ou remplir une feuille |
| Parent, SchoolStaff | rien de neuf | — |

Aucune policy nouvelle : chaque page reprend celle de sa page hôte (`ReadPublishedPolicy`, `ReadClassroomPolicy`, devoirs reçus de l'élève connecté).

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre la leçon Thalès : sous « Prépare interros », 4 cases (3 notions, « Toute la leçon ») ; sous « Prépare devoirs », 4 cases. Chacune dit son numéro, son titre, son nombre d'exercices et « x / n exercice(s) réussi(s) » (singulier à 0 et 1).
2. Il touche « Prépare devoirs n°2 » : la page montre le sujet complet, champs désactivés, sans bouton dans les exercices ; en bas, « Commencer Prépare devoirs ».
3. Il touche « Commencer » : la feuille à remplir s'ouvre, comme aujourd'hui.
4. Il vérifie l'exercice 1 : la page de résultat s'affiche ; « Retour » le ramène à la feuille remplie, sur l'exercice 1.
5. De retour sur la leçon, la case dit « 1 / 4 exercice réussi » ; rouverte, son bouton dit « Continuer Prépare devoirs ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Leçon sans exercice | l'état vide d'aujourd'hui, aucune case |
| Leçon sans sujet | pas de section « Prépare devoirs » |
| Adresse d'une feuille inconnue ou retirée | retour à la page hôte, message « Cette feuille n'existe plus. » |
| Enseignant sur la page à remplir | redirigé vers la lecture |
| Enseignant sur la page de lecture | ses bascules d'envoi et le bandeau, pas de « Commencer » |
| Devoir reçu | case dans « Ma classe » ; lecture, puis « Commencer », feuille avec « Rendre à l'enseignant » ; le résultat ramène à cette feuille |
| Devoir d'une autre classe ou d'un autre élève | « Cette feuille n'existe plus. », retour à « Ma classe » |
| Leçon non publiée, élève | refus actuel de la leçon (introuvable) |

## 4. Critères d'acceptation

```gherkin
Scénario: la leçon montre une case par feuille
  Étant donné la leçon Thalès publiée avec 3 notions, des exercices « Toute la leçon » et 4 sujets
  Quand un élève ouvre la leçon
  Alors il voit 4 cases sous « Prépare interros » et 4 cases sous « Prépare devoirs »
  Et aucun champ de réponse ni bouton « Vérifier ma réponse » n'est sur la page

Scénario: la case mène au sujet complet en lecture
  Quand l'élève ouvre la case « Prépare devoirs n°2 »
  Alors la page montre tous les exercices et toutes les questions du sujet 2
  Et les champs de réponse sont désactivés
  Et aucun bouton « Vérifier ma réponse » ni « Indice » n'est affiché
  Et un lien « Commencer Prépare devoirs » mène à la feuille à remplir

Scénario: commencer ouvre la feuille à remplir
  Quand l'élève suit « Commencer Prépare devoirs »
  Alors la feuille du sujet 2 s'affiche avec ses champs actifs et « Vérifier ma réponse »

Scénario: le résultat ramène à la feuille remplie
  Étant donné l'élève sur la feuille à remplir du sujet 2
  Quand il vérifie l'exercice 1
  Alors le lien retour de la page de résultat mène à la feuille à remplir du sujet 2, à l'exercice 1

Scénario: une feuille commencée dit « Continuer » et montre le progrès
  Étant donné un élève qui a réussi 1 exercice du sujet 2 (« Continuer » dès une copie terminée, réussie ou non)
  Quand il ouvre la leçon
  Alors la case du sujet 2 dit « 1 / 4 exercice réussi »
  Et la page de lecture du sujet 2 propose « Continuer Prépare devoirs »

Scénario: l'enseignant lit le sujet avec ses bascules, sans commencer
  Étant donné un enseignant d'une classe de 3ème
  Quand il ouvre la case « Prépare interros n°1 » depuis la page de la leçon dans sa classe
  Alors il voit la feuille avec ses bascules d'envoi à cette classe
  Et aucun lien « Commencer »
  Et la page à remplir le redirige vers la lecture

Scénario: un devoir reçu se lit avant de se rendre
  Étant donné un élève qui a reçu un devoir de 3 exercices
  Quand il ouvre « Ma classe »
  Alors il voit une case « Prépare devoirs » pour ce devoir, avec « À rendre le <date> »
  Et la case mène au sujet en lecture, puis « Commencer » à la feuille avec « Rendre à l'enseignant »

Scénario: une feuille inconnue renvoie à sa page hôte
  Quand l'élève ouvre l'adresse de la feuille « sujet-9 » de la leçon Thalès
  Alors il est renvoyé sur la leçon avec le message « Cette feuille n'existe plus. »

Scénario: le devoir d'une autre classe reste fermé
  Étant donné un devoir envoyé à une autre classe
  Quand l'élève ouvre son adresse
  Alors il est renvoyé sur « Ma classe » avec le message « Cette feuille n'existe plus. »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien de nouveau |
| Infrastructure | requêtes existantes des feuilles (leçon et devoirs reçus) : choisir une feuille par son ancre ; rien d'autre |
| Delivery | trois pages de feuille (leçon, classe de l'enseignant, « Ma classe »), chacune en lecture et à remplir (sauf la classe) ; la vérification transmet l'ancre de la feuille à la page de résultat |
| UI | la case, la feuille en lecture, le bouton « Commencer / Continuer », le retour de la page de résultat |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni use case, ni dépendance ; trois pages de lecture sur les requêtes et les policies existantes.
- UDR-XXXX-feuilles-en-cases-lues-avant-de-commencer — la case, la page de lecture, la page à remplir, les adresses ; amende l'UDR-0149 §3.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Hauteur de la page de Thalès à 390 px (feuilles comprises) | à mesurer | moins de la moitié | |
