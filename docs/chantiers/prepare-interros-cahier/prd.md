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
| Student | Répondre dans la feuille, « Vérifier ma réponse » (une copie), lire l'indice, « Refaire l'exercice », « Recommencer cette notion / ce sujet » | Vérifier pendant la pause de 3 copies ; vérifier un exercice non publié ou d'une notion non publiée |
| Teacher | Lire les feuilles sans champs de réponse ; « Assigner à <classe> » sous chaque exercice | Rendre une copie |
| Team | Lire les feuilles comme l'enseignant, brouillons compris, sans « Assigner » | Rendre une copie |
| Visiteur non connecté | Lire les feuilles d'une leçon publique | Vérifier : « Vérifier ma réponse » mène à la connexion |
| Parent, SchoolStaff | Rien de nouveau : la page ne change pas pour eux | — |

Règles appliquées, inchangées : `ReadPublishedPolicy` (lecture, ADR-0028), la policy de `StartExerciseSession`
(élève, exercice publié, pause ADR-0115), les policies d'assignation d'aujourd'hui.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre une leçon : sous « Prépare interros », une feuille par notion ; sous « Prépare devoirs », une feuille par sujet.
2. Il répond aux questions d'un exercice ; ses réponses restent dans son navigateur s'il recharge la page.
3. Il clique « Vérifier ma réponse » : la copie part, l'exercice se remplace sur place par sa version corrigée (« Réussi » ou
   « À revoir », « Ta note : x / 10 », « Mention : … », « x bonnes réponses sur n. », la correction question par question).
4. La progression de la feuille se met à jour (« 2 / 3 exercices réussis »).
5. Il clique « Refaire l'exercice » : l'exercice revient à blanc. « Recommencer cette notion / ce sujet » fait de même pour
   toute la feuille.
6. L'enseignant ouvre la même leçon : chaque exercice porte « Assigner à <classe> » ; un clic assigne sans recharger.

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
| Rechargement après une copie vérifiée | L'exercice s'affiche corrigé, d'après la dernière copie |

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
Et l'exercice affiche « À revoir », « Ta note : 8 / 10 », « Mention : Très bien », « 4 bonnes réponses sur 5. »
Et la correction de chaque question avec « Bonne réponse : » et « Explication : »
Et l'adresse de la page n'a pas changé

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

# CA-11 Téléphone
Étant donné un écran de 390 px de large
Alors aucune feuille ne dépasse de l'écran et chaque bouton fait au moins 44 px de haut
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::Exercise#hint` ; `Entities::Catalog::Subject` ; `Entities::Assessment::SheetGrade` (note sur 10, mention, détail) ; use case `UseCases::Assessment::CheckExerciseOnSheet` (compose `StartExerciseSession` et `SubmitExerciseCopy`) ; port `Ports::Catalog::ContentTreeWriterPort` étendu (sujets, indice) |
| Infrastructure | migrations `exercises.hint`, table `subjects`, `exercises.subject_id` ; `Orm::Subject` ; `Queries::Catalog::PrepareSheetsQuery` (remplace `PrepareInterrosQuery`) ; import `course_tree` (indice, sujets) |
| Delivery | `POST /exercises/:exercise_public_id/sheet_check` → `Assessment::SheetChecksController#create` (Turbo Stream) |
| UI | `catalog/courses/_prepare_sheets`, `catalog/courses/sheets/_sheet`, `_exercise`, `_result` ; `app/assets/stylesheets/prepare_sheet.css` ; Stimulus `prepare-sheet` (brouillon local, indice, refaire, recommencer) |

## 6. Décisions rattachées

- ADR-XXXX-sujets-de-devoir-et-verification-sur-la-feuille — sujet de devoir, indice, copie rendue depuis la feuille.
- UDR-XXXX-feuilles-prepare-interros-et-devoirs — les deux feuilles, à l'identique des maquettes.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de la page d'une leçon (élève, 4 notions × 3 exercices, 3 sujets × 4) | à mesurer au Lot 0 | ≤ avant + 3 | |
