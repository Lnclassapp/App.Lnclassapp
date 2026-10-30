# PRD — « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Dans la page d'une leçon, « Prépare interros » est une liste de liens ; l'élève ne voit jamais une notion en entier et
l'application ne connaît pas de sujet de devoir. Les maquettes de Touré (« Prépare interros Thalès », « Prépare devoirs
Thalès », [`maquettes/`](maquettes/)) montrent une feuille de cahier par notion et par sujet, où l'élève répond, vérifie et
lit la correction sans quitter la page. **Leur design s'applique tel quel** ([memo](memo.md), règle du chantier).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Lire ses devoirs reçus en feuilles dans « Ma classe » ; répondre dans la feuille, « Vérifier ma réponse » (une copie), lire l'indice, « Refaire l'exercice », « Recommencer cette notion / ce sujet » | Vérifier pendant la pause de 3 copies ; vérifier un exercice non publié ou d'une notion non publiée |
| Teacher | Lire les feuilles sans champs de réponse ; « Assigner à <classe> » sous chaque exercice ; cocher des exercices de plusieurs leçons et les « Envoyer à <classe> » en un devoir | Rendre une copie ; envoyer à une classe qui n'est pas la sienne ou un exercice d'un autre niveau |
| Team | Lire les feuilles comme l'enseignant, brouillons compris, sans « Assigner » | Rendre une copie |
| Visiteur non connecté | Lire les feuilles d'une leçon publique | Vérifier : « Vérifier ma réponse » mène à la connexion |
| Parent, SchoolStaff | Rien de nouveau : la page ne change pas pour eux | — |

Règles appliquées, inchangées : `ReadPublishedPolicy` (lecture, ADR-0028), la policy de `StartExerciseSession`
(élève, exercice publié, pause ADR-0115), les policies d'assignation d'aujourd'hui.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre une leçon : sous « Prépare interros », une feuille par notion ; sous « Prépare devoirs », une feuille par sujet.
2. Il répond aux questions d'un exercice ; ses réponses restent dans son navigateur s'il recharge la page.
3. Il clique « Vérifier ma réponse » : la copie part et il arrive sur la page de résultat de sa copie, celle qui existe déjà
   (note sur 20, appréciation, correction question par question).
4. Il clique « Retour à la leçon » : il retrouve l'exercice sur la feuille (même ancre), marqué « Réussi » ou « À revoir »,
   avec « Voir ma correction » et « Refaire l'exercice », et la progression se met à jour (« 2 / 3 exercices réussis »).
5. Il clique « Refaire l'exercice » : l'exercice revient à blanc. « Recommencer cette notion / ce sujet » fait de même pour
   toute la feuille.
6. L'enseignant ouvre la même leçon : chaque exercice porte « Assigner à <classe> » ; un clic assigne sans recharger.
7. L'enseignant coche « Choisir » sous des exercices, dans une ou plusieurs leçons ; un bandeau compte sa sélection
   (« 4 exercices choisis ») ; « Envoyer à <classe> » crée le devoir.
8. L'élève ouvre « Ma classe » : chaque devoir reçu est une feuille, la plus récente en haut. Un devoir de 3 exercices ou
   plus a la forme « Prépare devoirs » (« Devoir n / N », « Notions mobilisées »), un devoir de 1 ou 2 la forme
   « Prépare interros ». Il y vérifie ses réponses comme dans la leçon.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Élève en pause (3 copies en 30 min) | « Vérifier » ne rend pas de copie ; la feuille dit « Tu as rendu 3 copies d'affilée. Tu pourras recommencer à HH h MM. » ; les réponses restent |
| Exercice archivé entre l'ouverture et « Vérifier » | Message « Cet exercice n'existe plus. » dans l'exercice ; le reste de la page ne bouge pas |
| Visiteur non connecté | « Vérifier ma réponse » mène à la connexion, retour sur l'ancre de l'exercice |
| Réseau coupé ou erreur serveur | Message « La copie n'est pas partie. Réessaie. » dans l'exercice ; les réponses restent |
| Exercice sans indice | Pas de bouton « Indice » |
| Notion sans « À retenir » | Pas d'encadré « À retenir » |
| Leçon sans sujet | Pas de section « Prépare devoirs » |
| Question d'un type absent de la maquette | Rendue dans le cadre de la feuille avec son interaction d'aujourd'hui |
| Rechargement après une copie vérifiée | L'exercice affiche son statut (« Réussi » ou « À revoir »), « Voir ma correction » et « Refaire l'exercice », d'après la dernière copie |
| Envoi avec un exercice déjà assigné à la classe | Les autres partent ; le bandeau nomme l'exercice refusé |
| Envoi vide, ou de plus de 10 exercices | Refusé : « Choisis entre 1 et 10 exercices. » |
| Élève sans devoir reçu | « Ma classe » garde son état vide d'aujourd'hui |

## 4. Critères d'acceptation

```gherkin
# CA-1 Feuille par notion
Étant donné une leçon publiée avec une notion « La propriété de Thalès » et 3 exercices publiés
Quand un élève ouvre la leçon
Alors il voit sous « Prépare interros » une feuille « PRÉPARE INTERROS » titrée « LA PROPRIÉTÉ DE THALÈS »
Et l'encadré « À retenir : » de la notion
Et les 3 exercices « Exercice 1 » à « Exercice 3 » avec leurs questions et leurs champs de réponse

# CA-2 Feuille par sujet
Étant donné une leçon avec un sujet « Sujet 1 · Calculer, démontrer, conclure » de 4 exercices
Quand un élève ouvre la leçon
Alors il voit sous « Prépare devoirs » une feuille « PRÉPARE DEVOIRS », « Sujet 1 / 1 »
Et l'encadré « Notions mobilisées : » du sujet

# CA-3 Vérifier sur place
Étant donné un élève connecté devant un exercice de 5 questions
Quand il répond juste à 4 questions et clique « Vérifier ma réponse »
Alors une copie terminée est enregistrée pour cet exercice
Et il arrive sur la page de résultat de sa copie, avec sa note sur 20 et sa correction, sans JavaScript non plus
Et « Retour à la leçon » le ramène à l'exercice sur la feuille
Et l'exercice y affiche « À revoir », « Voir ma correction » et « Refaire l'exercice », sans « Ta note » ni correction

# CA-4 Réussi et progression
Étant donné un élève qui répond juste à toutes les questions d'un exercice et vérifie
Alors l'exercice affiche « Réussi »
Et la feuille affiche « 1 / 3 exercice réussi »

# CA-5 Pause
Étant donné un élève qui a rendu 3 copies en moins de 30 minutes
Quand il clique « Vérifier ma réponse » sur un exercice
Alors aucune copie n'est enregistrée
Et l'exercice affiche « Tu pourras recommencer à » suivi de l'heure de reprise

# CA-6 Indice
Étant donné un exercice importé avec un indice
Quand l'élève clique « Indice »
Alors il lit « Indice : » et le texte importé
Et un exercice importé sans indice n'a pas de bouton « Indice »

# CA-7 Refaire et Recommencer
Étant donné un exercice vérifié
Quand l'élève clique « Refaire l'exercice »
Alors l'exercice revient à blanc avec « Vérifier ma réponse »
Et « Recommencer cette notion » remet à blanc tous les exercices de la feuille

# CA-8 Vue enseignant
Étant donné un enseignant d'une classe de 3e qui ouvre la leçon
Alors chaque exercice porte « Assigner à <classe> » et aucun champ de réponse ni « Vérifier ma réponse »
Quand il clique « Assigner à <classe> »
Alors l'exercice est assigné à la classe sans rechargement et le bouton devient « ✓ Assigné à <classe> »

# CA-9 Import
Étant donné un fichier d'import de leçon avec un indice sur un exercice et un sujet de 4 exercices
Quand l'équipe l'importe
Alors l'exercice porte son indice et le sujet existe avec ses notions mobilisées et ses 4 exercices dans l'ordre
Et un sujet dont un exercice a une notion est refusé avec une erreur nommant le sujet

# CA-10 Erreurs
Étant donné un exercice archivé après l'ouverture de la page
Quand l'élève clique « Vérifier ma réponse »
Alors l'exercice affiche « Cet exercice n'existe plus. » et ses réponses restent dans les champs

# CA-12 Composer un devoir
Étant donné un enseignant de la 3e 1 qui coche 2 exercices dans la leçon « Thalès » et 2 dans « Pythagore »
Quand il clique « Envoyer à 3e 1 »
Alors 4 assignations actives d'un même envoi existent pour la 3e 1, échéance au prochain jour de séance
Et sa sélection est vidée

# CA-13 Devoir reçu, forme « Prépare devoirs »
Étant donné un élève de la 3e 1 et l'envoi de 4 exercices
Quand il ouvre « Ma classe »
Alors il voit une feuille « PRÉPARE DEVOIRS » avec les 4 exercices et « Notions mobilisées : » qui nomme leurs notions
Et il vérifie un exercice sans quitter la page

# CA-14 Devoir reçu, forme « Prépare interros »
Étant donné l'envoi de 2 exercices de la même notion
Alors l'élève voit une feuille « PRÉPARE INTERROS » avec « À retenir : » de cette notion
Et un envoi de 2 exercices de notions différentes n'a pas d'encadré « À retenir »

# CA-15 Refus
Étant donné un exercice déjà assigné à la 3e 1
Quand l'enseignant l'envoie avec 2 autres exercices
Alors 2 assignations sont créées et le bandeau nomme l'exercice refusé
Et un enseignant d'une autre classe ne peut pas envoyer à la 3e 1

# CA-16 Devoir reçu : pas de correction avant de rendre
Étant donné un élève qui a reçu un devoir de 3 exercices
Alors chaque exercice porte « Rendre à l'enseignant » et ni « Vérifier ma réponse » ni note ni correction
Quand il clique « Rendre à l'enseignant » sur un exercice
Alors la copie est rattachée à l'assignation, l'enseignant la voit dans son suivi
Et il arrive sur la page de résultat de sa copie ; « Retour » le ramène à « Ma classe », où l'exercice affiche « Voir ma correction » et « Refaire l'exercice »
Quand il refait l'exercice
Alors le bouton est « Vérifier ma réponse », la nouvelle copie n'est pas rattachée au devoir
Et l'enseignant voit toujours la copie rendue

# CA-17 Pas de raccourci par la leçon
Étant donné un exercice assigné à l'élève et pas encore rendu
Quand il ouvre la leçon
Alors cet exercice n'a pas « Vérifier ma réponse » et affiche « Ce devoir est à rendre : ouvre-le dans Ma classe. »
Et un envoi direct de la vérification est refusé sans copie

# CA-11 Téléphone
Étant donné un écran de 390 px de large
Alors aucune feuille ne dépasse de l'écran et chaque bouton fait au moins 44 px de haut
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | use case `UseCases::Classroom::AssignExerciseBatch` (règles de `AssignResource`, une transaction) ; `Entities::Assessment::Exercise#hint` ; `Entities::Catalog::Subject` ; `Entities::Assessment::SheetGrade` (note sur 10, mention, détail) ; use case `UseCases::Assessment::CheckExerciseOnSheet` (compose `StartExerciseSession` et `SubmitExerciseCopy`) ; port `Ports::Catalog::ContentTreeWriterPort` étendu (sujets, indice) |
| Infrastructure | migration `classroom_assignments.batch_public_id` ; `Queries::Classroom::StudentAssignedSheetsQuery` ; migrations `exercises.hint`, table `subjects`, `exercises.subject_id` ; `Orm::Subject` ; `Queries::Catalog::PrepareSheetsQuery` (remplace `PrepareInterrosQuery`) ; import `course_tree` (indice, sujets) |
| Delivery | `POST /exercises/:exercise_public_id/sheet_check` → `Assessment::SheetChecksController#create` (Turbo Stream) ; `POST /classrooms/:classroom_public_id/assignment_batches` → `Classroom::AssignmentBatchesController#create` |
| UI | `catalog/courses/_prepare_sheets`, `catalog/courses/sheets/_sheet`, `_exercise`, `_result` ; `app/assets/stylesheets/prepare_sheet.css` ; Stimulus `prepare-sheet` (brouillon local, indice, refaire, recommencer) |

## 6. Décisions rattachées

- ADR-XXXX-sujets-de-devoir-et-verification-sur-la-feuille — sujet de devoir, indice, copie rendue depuis la feuille.
- UDR-XXXX-feuilles-prepare-interros-et-devoirs — les deux feuilles, à l'identique des maquettes.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de la page d'une leçon (élève, 4 notions × 3 exercices, 3 sujets × 4) | 36 (Lot 0, sans sujet) | ≤ 39 | 36 sans sujet, 37 avec sujets (Lot B) |
