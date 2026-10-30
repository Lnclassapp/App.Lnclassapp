# PRD — « Je m’entraîne » dans la fiche de révision

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La fiche de révision d'une leçon montre, pour chaque notion, ce qu'il faut retenir, la méthode, un exemple corrigé et le piège à éviter, mais l'élève ne s'y exerce pas. On ajoute à chaque notion une section « Je m'entraîne » placée après l'exemple corrigé. Elle porte un exercice d'entraînement propre à la fiche, distinct de l'exercice noté, que le serveur corrige sans rien enregistrer. Pour écrire ces exercices comme les maquettes, les questions de tous les exercices (fiche, interrogations, devoirs) gagnent plusieurs cases par question et un indice. Le contenu est livré pour une leçon pilote dans chacune des 6 matières de 3e.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Élève (Student) | Dans la fiche d'une leçon de son niveau : répondre à l'exercice d'entraînement de chaque notion, « Vérifier » autant de fois qu'il veut, ouvrir l'indice, puis voir la correction après un premier « Vérifier ». Dans une copie notée : ouvrir l'indice d'une question. | Voir une bonne réponse avant « Vérifier ». Laisser une trace de l'entraînement (copie, note, maîtrise, pause). Se voir assigner un exercice d'entraînement. |
| Enseignant (Teacher) | Faire l'exercice d'entraînement comme l'élève, sur une leçon publiée. Voir « Indice ouvert » sur chaque question concernée d'une copie de ses élèves. | Assigner un exercice d'entraînement, ou le voir hors de la fiche. |
| Équipe (Team) | Tout ce que fait l'enseignant, y compris sur une leçon en brouillon. Importer les exercices d'entraînement, les indices et les questions à plusieurs cases. | — |
| Visiteur non connecté | — | Voir la fiche. Il est renvoyé à la connexion, comme aujourd'hui. |

Règle d'autorisation : celle de la fiche, `Policies::Catalog::ReadPublishedPolicy`, plus le contrôle du niveau de l'élève (`ReadsOwnLevel`), appliquée **à chaque « Vérifier »**. Pour l'indice d'une copie : `Policies::Assessment::SubmitAttemptPolicy` (l'élève auteur d'une copie en cours).

## 3. Parcours utilisateur

### Chemin nominal — entraînement dans la fiche

1. L'élève ouvre la page d'une leçon pilote et déplie « Voir plus ».
2. Dans la notion 1, après « Un exemple corrigé », il lit « Je m'entraîne » : l'énoncé, puis les questions avec leurs cases.
3. Il ouvre l'indice de la question 1 et le lit.
4. Il remplit les cases (« AN (cm) = 4,8 », « MN (cm) = 3 ») et clique sur « Vérifier ».
5. Sans recharger la page, chaque case affiche « Juste », « À revoir » ou « À compléter », suivis d'un message global. Le bouton « Correction » apparaît.
6. Il ouvre « Correction » et lit la bonne réponse de chaque case et l'explication.
7. Il corrige MN et clique de nouveau sur « Vérifier » : tout est juste. Rien n'a été enregistré.

### Chemin nominal — indice et cases dans une copie notée

1. L'élève commence l'exercice noté d'une notion. Une question a deux cases et un indice.
2. Il ouvre l'indice : le serveur enregistre « indice ouvert » sur sa copie et lui montre le texte.
3. Il rend sa copie : il a juste une case sur deux à une question qui vaut 2 points, et cette question compte 1 point.
4. Sur sa page de résultat, comme sur la copie que lit l'enseignant, la question porte « Indice ouvert » et le verdict de chaque case.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Notion sans exercice d'entraînement | Pas de section « Je m'entraîne » : la fiche garde ses 4 blocs, sans titre ni message vide. |
| « Vérifier » avec toutes les cases vides | Chaque case affiche « À compléter », et « Correction » apparaît. |
| Réponse chiffrée « 4,8 », « 4.8 », « 4,8 cm » ou « 4,8cm » | Même verdict que dans une copie notée : c'est la même règle. |
| Réponse chiffrée illisible (« quatre ») | « À revoir » sur la case, sans erreur de page. |
| Exercice réimporté ou retiré entre l'affichage et « Vérifier » | Message « Cet exercice a changé : recharge la fiche. » dans la section ; aucun verdict ; réponse 409. |
| Leçon dépubliée, élève hors niveau, ou compte d'un autre niveau | 404 sur « Vérifier », comme la fiche. |
| Plus de 30 « Vérifier » en une minute par le même compte | Message « Trop d'essais d'un coup : attends une minute. » ; réponse 429 ; rien de corrigé. |
| Sans JavaScript | La fiche se lit. « Vérifier » ouvre une page qui montre la notion avec le verdict et la correction, et un lien « Retour à la fiche » vers `#notion-<slug>`. |
| Indice ouvert dix fois sur la même question d'une copie | Une seule mention « Indice ouvert ». |
| Indice demandé sur une copie déjà rendue, ou par un autre élève | 404 ; rien n'est enregistré. |
| Exercice noté existant, une case par question | Note inchangée au centième près. |
| La coupe « Voir plus » tombe dans la notion 1 | « Je m'entraîne » est soit entièrement visible, soit entièrement caché jusqu'à « Voir plus », jamais coupé. |

## 4. Critères d'acceptation

```gherkin
# CA-1 — la section et sa place
Étant donné une notion publiée avec un exercice d'entraînement
Quand un élève de son niveau ouvre la page de la leçon
Alors la section de la notion montre, dans l'ordre, « À retenir », « La méthode », « Un exemple corrigé », « Je m'entraîne », « Le piège à éviter »

# CA-2 — notion sans entraînement
Étant donné une notion publiée sans exercice d'entraînement
Quand un élève ouvre la page de la leçon
Alors la section de la notion n'a pas de bloc « Je m'entraîne »
Et elle garde ses quatre blocs

# CA-3 — aucune bonne réponse dans la page
Étant donné une notion avec un exercice d'entraînement dont une réponse chiffrée attendue est « 4,8 » et une proposition correcte « parallèles »
Quand un élève, un enseignant ou l'équipe ouvre la page de la leçon
Alors le HTML ne contient ni l'explication ni l'indication de la proposition correcte ni la valeur attendue

# CA-4 — vérifier sans rien enregistrer
Étant donné un élève sur la fiche d'une notion avec un exercice d'entraînement
Quand il envoie ses réponses avec « Vérifier »
Alors chaque case reçoit « Juste », « À revoir » ou « À compléter »
Et le bouton « Correction » apparaît avec la bonne réponse de chaque case et l'explication
Et aucune ligne n'est créée dans exercise_sessions, question_attempts ni aucune autre table

# CA-5 — même verdict que la copie notée
Étant donné une question chiffrée d'unité « cm » attendant 4,8 avec une tolérance de 0,01
Quand on juge « 4,8 », « 4.8 », « 4,8 cm », « 4,8cm », « 4,81 » et « 4,9 » dans la fiche et dans une copie notée
Alors les deux verdicts sont identiques pour chaque réponse

# CA-6 — accès refusé
Étant donné une leçon en brouillon, ou une leçon d'un autre niveau que celui de l'élève
Quand un élève ou un enseignant envoie « Vérifier » pour une de ses notions
Alors la réponse est 404 et aucun verdict n'est rendu
Et un visiteur non connecté est renvoyé à la connexion

# CA-7 — exercice changé
Étant donné un élève qui a ouvert la fiche
Et l'exercice d'entraînement de la notion réimporté avec d'autres questions
Quand il envoie « Vérifier » avec les anciennes questions
Alors la réponse est 409 avec « Cet exercice a changé : recharge la fiche. »

# CA-8 — envois en rafale
Étant donné un élève qui a déjà envoyé 30 « Vérifier » dans la minute
Quand il en envoie un 31e
Alors la réponse est 429 avec « Trop d'essais d'un coup : attends une minute. »

# CA-9 — sans JavaScript
Étant donné un navigateur sans JavaScript
Quand l'élève envoie « Vérifier »
Alors une page montre la notion, le verdict de chaque case, la correction et un lien vers la fiche à l'ancre de la notion

# CA-10 — la coupe
Étant donné une leçon dont la coupe des 150 mots tombe dans la notion 1, avant ou après l'exemple corrigé
Quand la fiche est repliée
Alors le bloc « Je m'entraîne » de la notion 1 porte la cible « rest » en entier, ou n'est pas replié du tout
Et il ne compte aucun mot dans la coupe

# CA-11 — plusieurs cases, points répartis
Étant donné une question chiffrée à 2 cases valant 2 points dans un exercice noté
Quand l'élève rend une copie juste sur la première case et fausse sur la seconde
Alors la question compte 1 point sur 2
Et la tentative de la question est marquée fausse
Et la page de résultat montre « Juste » sur la case 1 et « À revoir » sur la case 2

# CA-12 — aucune note ne change
Étant donné les exercices notés en base avant la migration
Quand on recalcule leur note à partir de leurs tentatives après la migration
Alors chaque note est identique

# CA-13 — import des cases
Étant donné un fichier de leçon dont une question « fill_blank » a 3 « ___ » et des réponses pour les cases 0, 1 et 2
Quand l'équipe l'importe
Alors l'import réussit
Et un fichier dont une case n'a aucune réponse acceptée est refusé, avec le chemin de la question et la raison

# CA-14 — indice dans une copie
Étant donné un élève avec une copie en cours dont la question 2 a un indice
Quand il ouvre l'indice deux fois puis rend sa copie
Alors il lit le texte de l'indice
Et sa note est celle qu'il aurait eue sans indice
Et sa page de résultat et la copie lue par l'enseignant montrent « Indice ouvert » sur la question 2 seulement

# CA-15 — indice refusé
Étant donné une copie déjà rendue, ou la copie d'un autre élève
Quand on demande l'indice d'une de ses questions
Alors la réponse est 404 et rien n'est enregistré

# CA-16 — indice dans la fiche
Étant donné une question d'entraînement avec un indice
Quand l'élève ouvre « Indice » dans la fiche
Alors le texte s'affiche sans requête au serveur et sans enregistrement

# CA-17 — rédigé et cahier dans la fiche
Étant donné une question d'entraînement de type « written » ou « notebook »
Quand l'élève clique sur « J'ai fini »
Alors le corrigé type s'affiche, sans verdict

# CA-18 — jamais assignable, jamais listé
Étant donné une leçon avec des exercices d'entraînement
Quand un enseignant ouvre « Prépare interros », l'assignation depuis le catalogue ou l'accueil
Alors aucun exercice d'entraînement n'y apparaît

# CA-19 — leçons pilotes
Étant donné les 6 leçons pilotes importées sur la recette
Quand on ouvre chacune
Alors chacune de leurs notions a une section « Je m'entraîne » qui se vérifie
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Catalog::NotionPractice` (énoncé et questions de l'entraînement d'une notion, ses règles de forme, son empreinte de version) ; `Entities::Catalog::NotionSheet` gagne `practice` ; `Entities::Assessment::Question` gagne `hint` et la notion de case (`blanks`, réponses rattachées à une case, `blank_results(response)`) ; les classes `QuestionKinds::Numeric`, `Select` et `FillBlank` jugent case par case ; `Entities::Assessment::Grading` somme des fractions de points ; `Entities::Catalog::RevisionPreview` gagne le bloc `PRACTICE` (0 mot). Use cases : `UseCases::Catalog::CheckPractice` (juge sans écrire), `UseCases::Assessment::OpenHint`. Port : `ExerciseSessionRepositoryPort#record_hint`. |
| Infrastructure | Migration : `answers.blank` (smallint, défaut 0), `question_attempts.blank_responses` (text[], défaut `{}`), `question_attempts.blank_results` (boolean[], défaut `{}`), `questions.hint` (varchar 500), `exercise_sessions.hinted_question_ids` (bigint[], défaut `{}`). L'entraînement vit dans `essentials.sheet` (jsonb, clé `practice`) : pas de table nouvelle. `RevisionSheetQuery` lit `practice` sans les réponses. Schéma `lnclass.course-tree.v3.json` : `notion.practice`, `question.hint`, `answer.blank`. |
| Delivery | `POST /courses/:course_slug/notions/:slug/practice_check` → `Catalog::PracticeChecksController#create` (rate limit 30/min par compte). `POST /exercise_sessions/:public_id/hints` → `Assessment::HintsController#create`. |
| UI | `catalog/revision_sheets/_practice` (section dans la fiche), `catalog/practice_checks/_result` et `show` (sans JS), partials de saisie par case partagés avec la copie, bouton d'indice dans `assessment/exercise_sessions/show`, verdict par case et « Indice ouvert » dans `assessment/session_results/_question_review`. Aucun contrôleur Stimulus nouveau. |

## 6. Décisions rattachées

- ADR-0119 — l'exercice d'entraînement vit dans la fiche de la notion et le serveur le corrige sans rien écrire.
- ADR-0120 — plusieurs cases par question, points répartis par case, indice dont l'ouverture est enregistrée sur la copie (amende ADR-0115).
- UDR-0147 — section « Je m'entraîne », cases, indice, verdicts (amende UDR-0141 §2 et §3.2, UDR-0139 §3.2 pour la coupe).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| JavaScript commun (gzip) | ≤ 61 Ko | inchangé, ≤ 61 Ko | |
| Réponse de « Vérifier » (p95, recette) | — | < 300 ms côté serveur | |
| Notes recalculées identiques (CA-12) | — | 100 % | |
