# PRD — Refonte de la page de la leçon : fiche de révision, « Prépare interros » et exercices sur feuille

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La page d'une leçon cache la fiche à l'identique des maquettes derrière un bouton et disperse ses exercices sur 3 à 5 pages de notion : l'enseignant passe par quatre écrans pour assigner, l'élève lit le même contenu deux fois et répond une question à la fois, sans sujet commun. La page devient deux sections, la **fiche de révision** (150 mots, puis « Voir plus ») et **« Prépare interros »** (un exercice par notion, puis quatre sur la leçon complète, chacun assignable). Chaque exercice se présente comme une feuille : un sujet, puis une **copie à rendre** sur le téléphone. Voir le [memo](memo.md), Q1 à Q12.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Lire la page d'une leçon de son niveau (fiche de révision, « Prépare interros ») ; ouvrir un exercice publié, remplir sa copie, la rendre, la refaire ; voir sa note, sa correction et « Notion à revoir » | Assigner ; voir la correction d'une copie avant de l'avoir rendue ; rendre la copie d'un autre élève ; ouvrir une leçon hors de son niveau |
| Teacher | Lire la page d'une leçon ; voir le sujet et les questions d'un exercice ; assigner un exercice de « Prépare interros » à une classe qu'il enseigne ; lire les copies de ses classes (première copie, meilleure note) et les notions à revoir | Assigner un exercice d'entraînement de la fiche de révision ; assigner à une classe qu'il n'enseigne pas ; rendre une copie |
| Team | Tout lire, avec le statut de publication ; importer une leçon (fiche, notions, exercices) ; publier la leçon et son contenu | Créer ou modifier une notion ou un exercice depuis l'écran (tout passe par l'import, Q9) |
| SchoolStaff | — (ne lit pas les leçons, inchangé) | Tout ce qui précède |
| Parent | — (n'existe pas) | — |

Règles d'autorisation, toutes existantes et inchangées :

- lecture élève : `Policies::Catalog::ReadOwnLevelPolicy` ;
- lecture enseignant et équipe : `Policies::Catalog::ReadPublishedPolicy` ;
- assignation : `Policies::Classroom::AssignPolicy` ;
- suivi d'une assignation : `Policies::Classroom::FollowAssignmentPolicy` ;
- ouvrir une copie : `Policies::Assessment::StartSessionPolicy` ;
- rendre une copie : `Policies::Assessment::SubmitAttemptPolicy` (l'élève propriétaire, copie ouverte) ;
- lire une copie : `Policies::Assessment::ReadSessionPolicy` ;
- voir les corrections : `Policies::Assessment::RevealAnswersPolicy` ;
- import et publication : `Policies::Catalog::ManageContentPolicy`.

## 3. Parcours utilisateur

### Chemin nominal — élève

1. Il ouvre la leçon « Propriétés de Thalès dans un triangle » depuis « Cours » ou son accueil.
2. La page montre le titre de la leçon, puis **Fiche de révision** : les premiers blocs de la fiche jusqu'à dépasser 150 mots, puis « Voir plus ». « Voir plus » déplie la fiche entière sur place, figure interactive et exercices d'entraînement compris ; « Voir moins » la replie.
3. Sous la fiche, **Prépare interros** liste d'abord les exercices de notion (un par notion, dans l'ordre des notions, la notion en intertitre), puis les quatre exercices « Toute la leçon ». Chaque ligne donne le titre, l'étiquette Fixation ou Évaluation, le nombre de questions et son état pour lui : « À rendre jeudi », « 14/20 », « À revoir ».
4. Il ouvre un exercice. La page montre **le sujet** : l'énoncé, puis les questions numérotées avec leurs propositions, comme sur une feuille ; puis « Faire l'exercice ».
5. « Faire l'exercice » ouvre **sa copie** : le sujet repliable en haut, toutes les questions dessous, chacune avec sa saisie (choix, nombre, texte à trous, associer, ordonner), et un compteur « 4/6 répondues ».
6. Il répond dans l'ordre qu'il veut et peut changer ses réponses. Elles restent gardées sur son téléphone s'il recharge la page ou perd le réseau.
7. « Rendre ma copie ». S'il reste des questions sans réponse, une confirmation lui dit combien et qu'elles compteront fausses.
8. La page de résultat montre la note sur 20, le badge et la correction question par question. Si l'exercice porte sur une notion et que la note est sous le seuil, « Notion à revoir » s'ouvre, et un lien ramène à cet exercice dans « Prépare interros ».

### Chemin nominal — enseignant

1. Il ouvre la même leçon : même fiche de révision, puis « Prépare interros ».
2. Sous chaque exercice, une ligne par classe qu'il enseigne à ce niveau porte « Assigner ». Le premier « Assigner » de la page est plein, les suivants sont secondaires, comme sur la page actuelle des notions.
3. Il assigne « Calculer une longueur » à la 3ème 1 ; l'échéance est la prochaine séance (règle existante, ADR-0072).
4. Depuis sa classe, il lit les copies rendues (première copie, meilleure note) et les notions à revoir ; chaque notion à revoir mène à l'exercice de cette notion dans « Prépare interros ».

### Chemin nominal — équipe

1. Elle importe un fichier « leçon complète » au nouveau format : la leçon, ses notions et leur texte, les exercices de notion, puis les exercices de toute la leçon, chacun avec son sujet et ses questions.
2. Le rapport d'import dit ce qui est importé. Un fichier qui n'a pas exactement un exercice par notion et quatre exercices de toute la leçon est refusé entier, avec la raison.
3. Elle publie la leçon : la fiche, les notions et les exercices sont publiés en cascade (règle existante).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Leçon sans fiche cahier | La fiche de révision est le texte de présentation de la leçon, puis le texte de chaque notion sous son titre en intertitre ; même règle « 150 mots, Voir plus » |
| Leçon sans fiche cahier ni texte | Section « Fiche de révision » : « La fiche de révision arrive bientôt. » |
| Fiche de révision de 150 mots ou moins | Affichée entière, sans « Voir plus » |
| JavaScript coupé | Fiche entière, sans « Voir plus » ; la copie s'envoie par un formulaire classique ; le brouillon n'est pas gardé |
| Leçon sans exercice (les 215 leçons jusqu'au réimport) | « Prépare interros » : « Les exercices arrivent bientôt. » ; aucun « Assigner » |
| Enseignant sans classe du niveau | Aucun « Assigner » ; la phrase existante « Aucune classe de %{level} » sous la section |
| Rendre avec des questions vides | Confirmation « 2 questions sans réponse compteront fausses. » ; « Rendre quand même » ou « Continuer ma copie » |
| Double envoi (double clic, deux onglets) | Une seule copie notée ; le second envoi mène au résultat existant |
| Réponse illisible (nombre mal écrit, proposition étrangère à la question) | 422 : la copie se réaffiche avec ses réponses et un message sous la question en cause ; rien n'est noté |
| Copie d'un autre élève | 403, sans rien révéler de l'exercice |
| Exercice archivé pendant qu'une copie est ouverte | Rendu refusé avec « Cet exercice a été retiré. » ; le brouillon local est effacé |
| Exercice de toute la leçon raté | Note et correction ; aucune « Notion à revoir » |
| Ancienne adresse d'une notion | Redirection 301 vers la page de la leçon, ancrée sur cette notion dans « Prépare interros » |
| Ancienne adresse de la fiche | Redirection 301 vers la page de la leçon, ancrée sur la fiche de révision |
| Ancienne page de notion d'une classe (enseignant) | Redirection 301 vers la page de la leçon dans sa classe, ancrée sur la notion dans « Prépare interros » |
| Import au format précédent (v1) | La leçon et ses notions sont importées ; ses exercices sont ignorés et le rapport le dit |

## 4. Critères d'acceptation

```gherkin
# --- Page de la leçon : fiche de révision ---

Scénario: CA-01 La fiche de révision s'affiche dans la page de la leçon, coupée après 150 mots
  Étant donné une leçon publiée avec une fiche cahier de 600 mots
  Quand un élève de son niveau ouvre la page de la leçon
  Alors il voit la section « Fiche de révision » avant la section « Prépare interros »
  Et la partie visible compte au moins 150 mots et s'arrête à la fin d'un bloc
  Et un bouton « Voir plus » déplie la fiche entière sans nouvelle requête

Scénario: CA-02 Sans JavaScript, la fiche de révision se lit en entier
  Étant donné la même leçon
  Quand la page est rendue sans JavaScript
  Alors tout le texte de la fiche est présent dans le HTML, sans attribut hidden
  Et le bouton « Voir plus » est absent ou masqué

Scénario: CA-03 Une leçon sans fiche cahier montre le texte de ses notions
  Étant donné une leçon publiée sans fiche cahier, avec 3 notions rédigées
  Quand un enseignant ouvre la page de la leçon
  Alors la fiche de révision montre le titre de chaque notion en intertitre suivi de son texte, dans l'ordre des notions
  Et aucun lien de la page ne mène à une adresse de notion

Scénario: CA-04 Fiche courte, fiche vide
  Étant donné une leçon dont la fiche de révision compte 120 mots
  Alors la fiche est entière et sans « Voir plus »
  Étant donné une leçon sans fiche cahier ni texte
  Alors la section affiche « La fiche de révision arrive bientôt. »

Scénario: CA-05 Vocabulaire
  Quand un élève, un enseignant ou l'équipe ouvre la page d'une leçon
  Alors les deux sections s'intitulent « Fiche de révision » et « Prépare interros »
  Et aucun titre de section ni bouton de la page ne dit « Fiche de cours », « Révisions de la leçon » ou « Fiche à revoir »

# --- Prépare interros ---

Scénario: CA-06 L'ordre des exercices de la leçon
  Étant donné une leçon de 4 notions avec un exercice par notion et 4 exercices de toute la leçon, tous publiés
  Quand un élève ouvre la page de la leçon
  Alors « Prépare interros » liste 8 exercices : ceux des notions 1 à 4 dans l'ordre des notions, puis les 4 exercices « Toute la leçon »
  Et chaque ligne affiche son titre, l'étiquette « Fixation » ou « Évaluation » et son nombre de questions

Scénario: CA-07 L'enseignant assigne depuis la page de la leçon
  Étant donné un enseignant de la 3ème 1 avec des jours de séance
  Quand il ouvre la page de la leçon et clique « Assigner » sur la ligne 3ème 1 de l'exercice de la notion 2
  Alors une assignation active existe pour cette classe et cet exercice, avec l'échéance de la prochaine séance
  Et la ligne affiche l'état assigné sans recharger la page

Scénario: CA-08 Un enseignant ne peut pas assigner à une classe qu'il n'enseigne pas
  Étant donné un enseignant qui n'enseigne pas la 3ème 2
  Quand il envoie une assignation de l'exercice à la 3ème 2
  Alors la réponse est 403 et aucune assignation n'est créée

Scénario: CA-09 Les exercices d'entraînement de la fiche de révision ne s'assignent pas
  Quand un enseignant ouvre la page d'une leçon dont la fiche contient des exercices d'entraînement
  Alors aucun bouton « Assigner » n'apparaît dans la section « Fiche de révision »

Scénario: CA-10 Leçon sans exercice
  Étant donné une leçon publiée sans exercice
  Quand un enseignant ouvre la page de la leçon
  Alors « Prépare interros » affiche « Les exercices arrivent bientôt. »
  Et aucun bouton « Assigner » n'est affiché

Scénario: CA-11 L'état de l'élève sur chaque exercice
  Étant donné un élève à qui l'exercice de la notion 1 est assigné pour jeudi
  Et qui a rendu l'exercice de la notion 2 avec 14/20
  Et qui a une notion à revoir sur la notion 3
  Quand il ouvre la page de la leçon
  Alors la ligne de la notion 1 affiche « À rendre jeudi »
  Et la ligne de la notion 2 affiche « 14/20 »
  Et la ligne de la notion 3 affiche « À revoir »

Scénario: CA-12 Les anciennes adresses mènent à la page de la leçon
  Quand on ouvre l'adresse d'une notion de la leçon
  Alors la réponse est une redirection 301 vers la page de la leçon, ancrée sur cette notion dans « Prépare interros »
  Quand on ouvre l'adresse « fiche » de la leçon
  Alors la réponse est une redirection 301 vers la page de la leçon, ancrée sur la fiche de révision
  Quand un enseignant ouvre l'adresse d'une notion dans sa classe
  Alors la réponse est une redirection 301 vers la page de la leçon dans sa classe

# --- Exercice sur feuille et copie à rendre ---

Scénario: CA-13 Le sujet d'un exercice se lit comme une feuille
  Étant donné un exercice publié avec un sujet et 5 questions
  Quand un élève ouvre l'exercice
  Alors il voit le sujet puis les 5 questions numérotées de 1 à 5, avec leurs propositions
  Et aucune bonne réponse n'est présente dans le HTML

Scénario: CA-14 La copie présente toutes les questions sur une page
  Quand l'élève clique « Faire l'exercice »
  Alors une copie est ouverte pour lui
  Et la page de la copie montre le sujet et les 5 questions, chacune avec sa saisie
  Et aucune bonne réponse ni aucune correction n'est présente dans le HTML

Scénario: CA-15 Rendre la copie note toutes les réponses d'un coup
  Étant donné une copie ouverte de 5 questions
  Quand l'élève répond juste à 4 questions, faux à 1, puis clique « Rendre ma copie »
  Alors la copie est close avec la note 16/20
  Et 5 réponses sont enregistrées, une par question
  Et la page de résultat montre la correction des 5 questions

Scénario: CA-16 Une question sans réponse compte faux
  Étant donné une copie ouverte de 5 questions
  Quand l'élève rend sa copie avec 3 réponses justes et 2 questions vides
  Alors la copie est close avec la note 12/20
  Et les 2 questions vides sont marquées « Sans réponse » dans la correction

Scénario: CA-17 Une copie ne se rend qu'une fois
  Étant donné une copie déjà rendue
  Quand la même copie est envoyée une seconde fois
  Alors aucune nouvelle réponse n'est enregistrée
  Et l'élève est redirigé vers le résultat existant

Scénario: CA-18 Réponse illisible
  Quand l'élève rend une copie dont une réponse numérique vaut « douze »
  Alors la réponse est 422
  Et la copie se réaffiche avec ses réponses et un message sous la question en cause
  Et la copie n'est pas close

Scénario: CA-19 Pas de copie pour autrui
  Étant donné la copie ouverte d'un autre élève
  Quand un élève tente de la rendre
  Alors la réponse est 403 et rien n'est enregistré

Scénario: CA-20 Le brouillon survit à un rechargement
  Étant donné une copie ouverte où l'élève a répondu à 3 questions sans rendre
  Quand il recharge la page
  Alors ses 3 réponses sont toujours saisies
  Et après « Rendre ma copie », le brouillon est effacé du navigateur

Scénario: CA-21 Notion à revoir après un exercice de notion raté
  Étant donné l'exercice de la notion 3
  Quand l'élève rend sa copie avec une note sous le seuil de réussite
  Alors une notion à revoir est ouverte sur la notion 3
  Et le résultat affiche « Notion à revoir » avec un lien vers cet exercice dans « Prépare interros »

Scénario: CA-22 Pas de notion à revoir pour un exercice de toute la leçon
  Étant donné un exercice « Toute la leçon »
  Quand l'élève rend sa copie avec 0/20
  Alors aucune notion à revoir n'est ouverte

Scénario: CA-23 L'ancien écran « une question à la fois » n'existe plus
  Quand on envoie une réponse à une seule question d'une copie
  Alors la route n'existe plus (404)
  Et ouvrir l'exercice du jour ou l'exercice proposé par « Notion à revoir » ouvre une copie

# --- Enseignant : lecture des copies ---

Scénario: CA-24 L'enseignant lit les copies de sa classe
  Étant donné l'exercice de la notion 2 assigné à la 3ème 1
  Et un élève qui l'a rendu deux fois, 8/20 puis 15/20
  Quand l'enseignant ouvre le suivi de cette assignation
  Alors il lit pour cet élève la première copie 8/20 et la meilleure note 15/20

Scénario: CA-25 Les notions à revoir de la classe mènent à l'exercice
  Étant donné un élève de la 3ème 1 avec une notion à revoir sur la notion 3
  Quand l'enseignant ouvre sa classe
  Alors la ligne « à revoir » nomme la notion 3 par son titre
  Et son lien mène à la page de la leçon dans la classe, ancrée sur la notion 3 dans « Prépare interros »

# --- Import ---

Scénario: CA-26 Import d'une leçon complète au nouveau format
  Étant donné un fichier de leçon au nouveau format avec 4 notions, 4 exercices de notion et 4 exercices de toute la leçon, chacun avec un sujet
  Quand l'équipe l'importe
  Alors la leçon, ses 4 notions et ses 8 exercices sont créés en brouillon
  Et chaque exercice de notion est rattaché à sa notion
  Et chaque exercice de toute la leçon n'est rattaché à aucune notion

Scénario: CA-27 Import refusé si la règle des exercices n'est pas tenue
  Étant donné un fichier au nouveau format dont la notion 2 n'a pas d'exercice
  Quand l'équipe l'importe
  Alors rien n'est importé
  Et le rapport nomme la leçon, la notion 2 et la raison « un exercice par notion »
  Étant donné un fichier au nouveau format avec 3 exercices de toute la leçon
  Alors rien n'est importé et le rapport dit « quatre exercices de toute la leçon »

Scénario: CA-28 Import au format précédent
  Étant donné un fichier de leçon au format v1 avec des exercices par notion
  Quand l'équipe l'importe
  Alors la leçon et ses notions sont créées
  Et aucun exercice n'est créé
  Et le rapport contient l'avertissement « exercices ignorés : format v1 »

Scénario: CA-29 L'équipe n'a plus d'écran d'édition de notion ni d'exercice
  Quand un membre de l'équipe ouvre la page d'une leçon
  Alors le menu de la leçon ne propose ni « Nouvelle notion », ni « Nouvel exercice »
  Et les adresses de création et d'édition d'une notion ou d'un exercice répondent 404

Scénario: CA-30 Les exercices existants sont archivés
  Étant donné des exercices créés avant le chantier
  Quand la migration du chantier est jouée
  Alors ils sont tous archivés
  Et aucun n'apparaît dans « Prépare interros »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::Exercise` : `course_id` (obligatoire), `essential_id` (facultatif), `statement` (le sujet), `lesson_wide?`. Use case `UseCases::Assessment::SubmitExerciseCopy`, qui remplace `SubmitQuestionAttempt` : vérifie toutes les réponses, les enregistre et clôt la copie dans une transaction, idempotent. `CloseExerciseSession` : pas de lacune sans notion. `ImportCourseTree` : format v2 et règle « 1 par notion + 4 sur la leçon ». `Dtos::Assessment::CopyInput`. Ports complétés au Lot 0 : `ExerciseRepositoryPort` (exercices d'une leçon) et `ExerciseSessionRepositoryPort` (enregistrer les réponses d'une copie). |
| Infrastructure | Migration : `exercises.course_id` (rempli depuis la notion, puis non nul), `essential_id` nullable, `description` renommée `statement`, index d'ordre par leçon, archivage de tous les exercices existants (Q11). Schéma `config/schemas/lnclass.course-tree.v2.json`. Queries : `Queries::Catalog::CourseDetailQuery` (fiche de révision et exercices de la leçon), `Queries::Assessment::SessionPlayQuery` (la copie entière), `Queries::Classroom::ClassroomCourseQuery`, `Queries::Assessment::ClassroomGapsQuery`. |
| Delivery | `Catalog::CoursesController#show` (fiche, « Prépare interros », cibles d'assignation) ; redirections dans `Catalog::EssentialsController#show`, `Catalog::CourseSheetsController#show`, `Classroom::ClassroomEssentialsController#show` ; `Assessment::ExerciseCopiesController#create` remplace `Assessment::QuestionAttemptsController` ; retrait des écrans de création et d'édition de `Teams::EssentialsController` et `Teams::ExercisesController`. |
| UI | `catalog/courses/show` et ses partials `_revision_sheet`, `_prepare_interros`, `_exercise_row` ; le cahier de `catalog/course_sheets/` rendu dans la page ; `assessment/exercises/show` (le sujet) ; `assessment/exercise_sessions/show` (la copie) et `kinds/*` avec un préfixe de champ par question ; `assessment/session_results/*`. Stimulus : `catalog--revision-more` (Voir plus, Voir moins) et `assessment--copy` (brouillon local, compteur, confirmation). |

## 6. Décisions rattachées

- [ADR-0113](../../decisions/adr/0113-exercice-de-lecon-avec-sujet-et-notion-sans-page.md) — un exercice appartient à la leçon et, s'il est de notion, à une notion ; il a un sujet ; la notion reste une donnée sans page ; format d'import v2 ; archivage des anciens exercices ; lecture de la leçon. Amende ADR-0035 et ADR-0090.
- [ADR-0112](../../decisions/adr/0112-copie-a-rendre.md) — un exercice se fait en une copie rendue d'un coup, brouillon dans le navigateur ; l'envoi question par question est retiré. Amende ADR-0054.
- [UDR-0139](../../decisions/udr/0139-page-de-la-lecon-fiche-de-revision-et-prepare-interros.md) — la page de la leçon, ses deux sections, « Voir plus », le vocabulaire. Amende UDR-0130 et UDR-0137 §4.
- [UDR-0138](../../decisions/udr/0138-exercice-sur-feuille-et-copie-a-rendre.md) — le sujet, la copie, le rendu, le résultat. Remplace l'UDR-0087 §3.2 et §3.4 (mode concentré, une question à la fois).

Aucune nouvelle dépendance : « Voir plus » est un contrôleur Stimulus maison, pas `@stimulus-components/read-more` (raison dans l'UDR de la page de la leçon, §2).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Écrans pour assigner un exercice depuis « Cours » (enseignant) | 4 (catalogue, leçon, notion, assigner) | 2 (catalogue, leçon) | |
| Requêtes HTTP pour faire un exercice de 6 questions (élève) | 8 (ouvrir, 6 réponses, résultat) | 3 (ouvrir, rendre, résultat) | |
| Pages à ouvrir pour lire une leçon de 4 notions | 5 (leçon, 4 notions) ou 2 (leçon, fiche) | 1 | |
