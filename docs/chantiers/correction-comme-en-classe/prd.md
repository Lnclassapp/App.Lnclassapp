# PRD — Corriger une copie comme en classe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Après sa copie rendue, l'élève voit sa note et son verdict question par question, mais jamais la bonne réponse, ni une
appréciation qui lui dise quoi revoir. Et la feuille ne sait pas poser les questions d'un vrai devoir de 3e : liste de mots,
unité, document, réponse rédigée, travail sur le cahier, points ([memo](memo.md)).

Le porteur a décidé le 2026-10-28 (D1 à D8 du memo) :

- le bouton devient « Vérifier ma copie », et la correction complète s'affiche tout de suite ;
- une appréciation de professeur ;
- la meilleure note compte, avec une pause de « Recommencer » ;
- aucune durée ;
- l'interrogation et le devoir sont deux exercices séparés ;
- les réponses rédigées ne comptent pas dans la note ;
- un seul bouton par exercice.

Les propositions marquées **(à confirmer)** répondent aux questions ouvertes du memo ; le porteur les tranche à la relecture.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student (auteur de la copie) | Répondre à tous les types de questions ; vérifier sa copie une fois. Après vérification : lire sa réponse, la bonne réponse, l'explication ou le corrigé type de chaque question, l'appréciation, la phrase d'encouragement, et cocher la grille de vérification. Recommencer, sauf pendant la pause | Voir une bonne réponse ou un corrigé type avant d'avoir vérifié sa copie, ni dans une copie abandonnée. Changer ses réponses après vérification. Se noter lui-même. Lire la copie d'un autre élève. Démarrer une copie pendant la pause, d'où qu'il parte |
| Teacher (enseigne à l'élève) | Lire le résultat de l'élève : bonnes réponses (déjà le cas), appréciation, et le texte de ses réponses rédigées | Lire la phrase d'encouragement. Noter une réponse rédigée (hors périmètre). Recommencer à la place de l'élève |
| Team | Comme l'enseignant ; écrire et importer des exercices avec les nouveaux types, les points, l'unité, la grille et les documents | Modifier les questions d'un exercice qui a déjà des copies (inchangé : elles sont verrouillées) |
| SchoolAdmin | Rien de nouveau | — |
| Parent | Ce rôle n'existe pas dans l'application | — |

Règles d'autorisation :

- **Lire un résultat** : `ReadSessionPolicy`, inchangée.
- **Voir les bonnes réponses et les corrigés types dans un résultat** : une nouvelle `RevealCorrectionPolicy`. L'équipe et
  l'enseignant les voient comme aujourd'hui ; l'élève auteur les voit seulement sur une copie vérifiée. `RevealAnswersPolicy`
  reste celle de la feuille, où l'élève ne voit jamais les bonnes réponses.
- **Démarrer une copie** : `StartSessionPolicy`, inchangée, puis la pause, vérifiée par `StartExerciseSession`.

## 3. Parcours utilisateur

### Chemin nominal

1. Dans la leçon, l'élève ouvre l'exercice « Devoir ». La feuille affiche le sujet, avec son document et son tableau, puis les
   questions numérotées. Chaque question affiche ses points quand l'exercice n'est pas tout à 1 point : « (2 points) ».
   Aucune durée n'apparaît.
2. Il répond, selon le type :
   - **QCM, vrai ou faux** : comme aujourd'hui ;
   - **choix dans une liste** : une liste déroulante, à la place du trou dans la phrase, ou sous la question s'il n'y a pas de
     trou ;
   - **association** : comme aujourd'hui ;
   - **ordre, texte à trous** : comme aujourd'hui ;
   - **réponse chiffrée** : un champ, suivi de son unité (« cm ») ;
   - **réponse rédigée** : une zone de texte, avec un début de phrase en exemple quand l'exercice en donne un ;
   - **travail sur le cahier** : la consigne seule, sans champ, avec « À faire sur ton cahier ».
3. En bas de la feuille, un seul bouton : **« Vérifier ma copie »**. Juste au-dessus, une phrase dit qu'après la vérification,
   on ne peut plus changer ses réponses (texte fixé par l'UDR).
4. La page du résultat s'ouvre aussitôt. En titre, l'**appréciation**, selon la note sur 20 affichée :
   - « Très bien » dès 16/20 ;
   - « Bien » dès 12 ;
   - « Assez bien » dès 10 ;
   - « À retravailler » en dessous.

   Sous le titre :
   - la phrase d'encouragement tirée au hasard (inchangée) ;
   - la note, avec les points corrigés automatiquement, par exemple « 14/20 · 8 points sur 11 corrigés automatiquement » ;
   - si l'exercice a des réponses rédigées ou du travail sur le cahier : « 9 points à comparer au corrigé » ;
   - **ce qu'il faut revoir** :
     - pour un exercice de notion, la notion et les questions en cause : « À revoir : « Calculer une longueur »,
       questions 2 et 4 » ;
     - pour un exercice de toute la leçon, les questions en cause et un renvoi à la leçon : « À revoir dans la leçon :
       questions 2 et 4 ».

   Une question est **en cause** quand elle est corrigée automatiquement et fausse ou sans réponse. Une réponse rédigée et un
   travail sur le cahier ne sont jamais en cause.
5. Dans la correction, pour chaque question :

   **Question corrigée automatiquement**
   - le verdict : « Juste », « Faux » ou « Sans réponse » ;
   - la réponse de l'élève ;
   - la bonne réponse, selon le type : proposition correcte, réponses acceptées, valeur attendue avec son unité, bon ordre ou
     bonnes paires ;
   - l'explication.

   **Réponse rédigée**
   - la mention « À comparer au corrigé » ;
   - le texte de l'élève, tel qu'il l'a écrit ;
   - le corrigé type ;
   - la grille de vérification, que l'élève coche à l'écran.

   **Travail sur le cahier**
   - la mention « À comparer au corrigé » ;
   - le corrigé type.
6. L'élève clique sur « Refaire l'exercice » : une nouvelle copie s'ouvre. La meilleure note continue de compter partout.
7. Après sa 3e copie vérifiée d'affilée, la page du résultat ne propose plus « Refaire l'exercice ». Elle dit « Tu pourras
   recommencer à 21 h 14. ». La page de l'exercice dit la même chose, à la place de son bouton.

**La note.** Chaque question a des points, 1 par défaut. Seules comptent les questions corrigées automatiquement :

```
score (%) = points des questions justes × 100 / points de toutes les questions corrigées automatiquement   (arrondi vers le bas)
note sur 20 = Grading.grade_on_20(score)                                                                     (inchangé)
```

Un exercice dont toutes les questions valent 1 point garde exactement sa note d'aujourd'hui. La maîtrise, le badge, les
lacunes et la note vue par l'enseignant se lisent sur ce score, sans autre changement. Le total des points de l'exercice n'a
pas à faire 20 : la note se ramène sur 20 **(à confirmer)**.

**La pause.** « D'affilée » : moins de 30 minutes entre la fin d'une copie vérifiée et la fin de la suivante. La pause dure
30 minutes après la fin de la 3e copie de la série ; ensuite, une nouvelle série de 3 copies est possible. Règle exacte : on
prend les 3 dernières copies vérifiées de l'élève sur cet exercice, toutes sortes confondues. Il est en pause si :
- elles sont 3 ;
- moins de 30 minutes séparent la fin de la 1re de la fin de la 2e, et la fin de la 2e de la fin de la 3e ;
- moins de 30 minutes se sont écoulées depuis la fin de la 3e.

Les copies abandonnées ne comptent pas.

**Interrogation et Devoir** sont deux exercices de toute la leçon, parmi les 4 qu'exige l'import. Proposition : Interrogation
au type fixation, Devoir au type évaluation, sans type nouveau ; aucune règle d'import sur leur nombre ne change **(à
confirmer)**.

### Les nouveaux éléments d'une question

| Élément | Types concernés | Règle |
|---|---|---|
| **Points** | tous | De 0,5 à 20, par demi-point. 1 par défaut, pour tout exercice existant ou importé sans points |
| **Unité** | réponse chiffrée | Facultative, 10 caractères au plus (« cm », « m », « km/h »). Une réponse tapée avec cette unité à la fin (« 4,8 cm ») est lue sans elle |
| **Choix dans une liste** | type nouveau | De 2 à 10 propositions, une seule correcte. Le trou `___` est facultatif ; s'il est là, il n'y en a qu'un, et la liste prend sa place dans la phrase. Juste si la proposition choisie est la correcte |
| **Réponse rédigée** | type nouveau | Un corrigé type obligatoire (le champ « explication » de la question). Un début de phrase facultatif, 150 caractères au plus, affiché en exemple dans la zone vide et jamais envoyé comme réponse. La réponse de l'élève : 2 000 caractères au plus. Jamais notée |
| **Grille de vérification** | réponse rédigée | Facultative, 8 critères au plus, 150 caractères chacun. Cochée à l'écran après vérification, **sans être enregistrée (à confirmer)** |
| **Travail sur le cahier** | type nouveau | Aucun champ. Un corrigé type obligatoire, en texte ; l'image du corrigé viendra plus tard **(à confirmer)**. Jamais noté |
| **Document et tableau dans le sujet** | exercice | Le sujet peut contenir un document titré (« Document · Voir de près et de loin ») et un tableau de données. Le format suit les blocs des fiches de révision (contenu-en-blocs) ; l'ADR le fixe |

Un exercice doit avoir **au moins une question corrigée automatiquement** pour être publié **(à confirmer)**.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Question corrigée automatiquement laissée vide | « Sans réponse », pas de réponse de l'élève ; la bonne réponse et l'explication s'affichent ; la question est en cause |
| Réponse rédigée laissée vide | La copie part quand même. « À comparer au corrigé », la mention « Tu n'as rien écrit », le corrigé type. La note n'en dépend pas |
| Copie entièrement vide | 0/20, « À retravailler », toutes les questions corrigées automatiquement en cause |
| Toutes les questions automatiques justes, réponses rédigées vides | 20/20, « Très bien », rien à revoir ; « 9 points à comparer au corrigé » reste affiché |
| Copie sans faute | « Très bien », rien à revoir, pas de « Refaire l'exercice » (inchangé) |
| Réponse chiffrée tapée avec une autre unité (« 48 mm » pour « cm ») | Lue comme mal formée, comme tout texte aujourd'hui dans une réponse chiffrée |
| Réponse rédigée de plus de 2 000 caractères | La zone n'en accepte pas plus ; le serveur refuse la copie, avec le message de champ trop long |
| Réponse rédigée contenant du HTML ou un script | Affichée telle quelle, en texte, à l'élève comme à l'enseignant |
| Sans JavaScript | La liste déroulante, l'association (déjà une liste de choix sans JavaScript), la zone de texte et l'envoi marchent. La grille se coche sans JavaScript (cases à cocher simples) |
| Copie abandonnée | Jamais corrigée, aucune bonne réponse ni corrigé type montrés ; hors du compte de la pause |
| Copie en cours | La feuille ne montre aucune bonne réponse ni corrigé type (inchangé) |
| Exercice assigné par l'enseignant | Même parcours. La copie de devoir compte dans la pause. La note du devoir reste la meilleure |
| Exercice de toute la leçon | L'appréciation nomme les questions en cause et renvoie à la leçon (`#toute-la-lecon`), jamais une notion |
| Copie de remédiation | Même correction ; elle compte dans la pause ; la lacune s'ouvre ou se referme comme aujourd'hui |
| Exercice ancien (tout à 1 point, sans unité, sans nouveau type) | Feuille, note et correction identiques à aujourd'hui, à la correction complète, à l'appréciation et au nom du bouton près |
| Leçon réimportée entre deux copies | Le réimport crée un nouvel exercice en brouillon ; l'ancienne copie garde sa correction ; la pause se compte par exercice |
| Import d'une question mal construite (choix dans une liste sans proposition correcte, deux trous, points à 0 ou 25, unité de 11 caractères, réponse rédigée sans corrigé, grille de 9 critères) | La leçon est refusée entière, l'erreur nomme la leçon et la question (comme aujourd'hui) |
| Import d'un exercice sans question corrigée automatiquement | Enregistré en brouillon, refusé à la publication **(à confirmer)** |
| Pendant la pause, l'élève demande une copie depuis l'accueil, l'historique ou un autre onglet | Aucune copie créée ; retour à la page de l'exercice avec « Tu as vérifié 3 copies d'affilée. Tu pourras recommencer à 21 h 14. » |
| L'enseignant ou l'équipe lit le résultat | Même appréciation, sans la phrase d'encouragement ; les bonnes réponses, les corrigés types et le texte rédigé de l'élève |
| Un autre élève ouvre l'adresse du résultat | 403 (inchangé) |

## 4. Critères d'acceptation

```gherkin
# CA-01 — Le bouton
Étant donné un élève sur la feuille d'un exercice
Alors il voit un seul bouton, « Vérifier ma copie », en bas de la feuille
Et la page ne contient ni « Rendre ma copie », ni « Vérifier les réponses courtes », ni une durée

# CA-02 — La correction complète après vérification
Étant donné un élève qui a vérifié sa copie d'un exercice à choix
Quand il ouvre son résultat
Alors chaque question montre son choix, la proposition correcte et l'explication

# CA-03 — La bonne réponse de chaque type corrigé automatiquement
Étant donné une copie vérifiée avec un texte à trous, une réponse chiffrée en cm, un ordre, une association et un choix dans une liste
Quand l'élève ouvre son résultat
Alors il voit les réponses acceptées, la valeur attendue suivie de « cm », le bon ordre, les bonnes paires et la proposition correcte

# CA-04 — Question laissée vide
Étant donné une copie vérifiée avec la question 2 sans réponse
Alors la question 2 porte « Sans réponse », avec sa bonne réponse et son explication

# CA-05 — Jamais avant la vérification
Étant donné un élève qui a une copie en cours d'un exercice avec une réponse rédigée
Quand il ouvre sa feuille
Alors aucune bonne réponse ni aucun corrigé type n'apparaît dans la page

# CA-06 — Jamais sur une copie abandonnée
Étant donné une copie abandonnée
Quand son élève demande l'adresse de son résultat
Alors aucune correction n'est rendue

# CA-07 — La règle de révélation
Étant donné RevealCorrectionPolicy
Alors elle accepte l'équipe, l'enseignant qui lit l'exercice et l'élève auteur d'une copie vérifiée
Et elle refuse l'élève auteur d'une copie en cours ou abandonnée, et tout autre élève

# CA-08 — Les seuils de l'appréciation, sur la note affichée
Étant donné des copies notées 20, 16, 15, 12, 11, 10, 9 et 0 sur 20
Alors leurs appréciations sont « Très bien », « Très bien », « Bien », « Bien », « Assez bien », « Assez bien », « À retravailler », « À retravailler »
Et un score de 79 %, affiché 16/20, donne « Très bien »

# CA-09 — Ce qu'il faut revoir, exercice de notion
Étant donné une copie d'un exercice de la notion « Calculer une longueur », fausse aux questions 2 et 4
Alors l'élève lit « À revoir : « Calculer une longueur », questions 2 et 4 »

# CA-10 — Ce qu'il faut revoir, exercice de toute la leçon
Étant donné une copie d'un exercice de toute la leçon, fausse à la question 3
Alors l'élève lit « À revoir dans la leçon : question 3 » avec un lien vers « Toute la leçon »
Et aucune notion n'est nommée

# CA-11 — Rien à revoir
Étant donné une copie sans faute
Alors l'élève lit « Très bien » et aucune ligne « À revoir »

# CA-12 — Le titre remplace « Félicitations ! » et « Courage ! »
Étant donné une copie notée 13/20
Alors le titre est « Bien », sans « Félicitations ! » ni « Courage ! », suivi d'une phrase d'encouragement

# CA-13 — L'enseignant lit la même appréciation et le texte rédigé
Étant donné une copie notée 9/20, fausse aux questions 1 et 3, avec une réponse rédigée « Non, car <b>AM/AB</b> »
Quand son enseignant ouvre le résultat
Alors il lit « À retravailler », les questions 1 et 3, et le texte « Non, car <b>AM/AB</b> » en clair
Et aucune phrase d'encouragement

# CA-14 — Les points dans la note
Étant donné un exercice : question 1 à 1 point, question 2 à 2 points, question 3 à 3 points, toutes corrigées automatiquement
Quand l'élève vérifie une copie juste aux questions 1 et 3 seulement
Alors son score est 66 % et sa note 13/20

# CA-15 — Les réponses rédigées hors de la note
Étant donné un exercice de 11 points corrigés automatiquement et une réponse rédigée de 4 points
Quand l'élève vérifie une copie juste à 8 points sur 11, avec la réponse rédigée vide
Alors il lit « 14/20 · 8 points sur 11 corrigés automatiquement » et « 4 points à comparer au corrigé »

# CA-16 — Un exercice ancien garde sa note
Étant donné un exercice existant, sans points ni nouveau type, et une copie juste à 7 questions sur 10
Alors son score reste 70 % et sa note 14/20

# CA-17 — Les points affichés sur la feuille
Étant donné une question à 2 points dans un exercice qui n'est pas tout à 1 point
Alors la feuille affiche « (2 points) » à côté de la question
Et un exercice tout à 1 point n'affiche aucun point

# CA-18 — Choix dans une liste, dans la phrase
Étant donné la question « Les points A, M et B doivent être ___. » avec les propositions parallèles, alignés, proportionnelles
Alors la feuille montre une liste déroulante à la place du trou, sans réponse choisie au départ
Et choisir « alignés » donne « Juste », choisir « parallèles » donne « Faux », ne rien choisir donne « Sans réponse »

# CA-19 — Choix dans une liste, sans trou
Étant donné la question « On sait que (MN) // (BC) et on cherche une longueur. » sans trou
Alors la liste déroulante s'affiche sous la question

# CA-20 — L'unité
Étant donné une réponse chiffrée attendue 4,8 avec l'unité « cm »
Alors la feuille affiche « cm » après le champ
Et « 4,8 », « 4.8 » et « 4,8 cm » sont justes

# CA-21 — La réponse rédigée
Étant donné une réponse rédigée avec le début de phrase « Non, car… » et 2 points
Alors la feuille montre une zone de texte vide avec « Non, car… » en exemple
Et après vérification, le résultat montre le texte de l'élève, « À comparer au corrigé » et le corrigé type
Et la question n'entre ni dans la note ni dans « À revoir »

# CA-22 — La réponse rédigée trop longue
Quand une copie arrive avec une réponse rédigée de 2 001 caractères
Alors elle est refusée, rien n'est enregistré, et l'élève retrouve sa feuille avec le message du champ

# CA-23 — La grille de vérification
Étant donné une réponse rédigée avec 5 critères
Alors après vérification, le résultat montre les 5 critères en cases à cocher, toutes vides
Et cocher une case ne change pas la note

# CA-24 — Le travail sur le cahier
Étant donné une question « Sur ton cahier, trace la construction » de 2 points
Alors la feuille montre la consigne et « À faire sur ton cahier », sans champ
Et après vérification, le résultat montre « À comparer au corrigé » et le corrigé type

# CA-25 — Le document et le tableau du sujet
Étant donné un exercice dont le sujet contient le document « Voir de près et de loin » et un tableau de 2 lignes et 4 colonnes
Alors la feuille et le résultat les affichent, le tableau lisible à 390 px sans déborder de la page

# CA-26 — L'import des nouveaux éléments
Étant donné un fichier d'import avec un choix dans une liste, une réponse chiffrée avec unité, une réponse rédigée avec grille, un travail sur le cahier, des points et un sujet avec document et tableau
Alors la leçon s'importe en brouillon, avec chaque élément à sa place

# CA-27 — L'import refuse une question mal construite
Étant donné un fichier d'import avec un choix dans une liste sans proposition correcte
Alors la leçon est refusée entière, et l'erreur nomme la leçon et la question
# (un test par règle du tableau « Les nouveaux éléments d'une question »)

# CA-28 — Un exercice sans question corrigée automatiquement
Étant donné un exercice qui n'a que des réponses rédigées
Alors il ne peut pas être publié

# CA-29 — La pause après 3 copies d'affilée
Étant donné un élève qui a vérifié 3 copies du même exercice à 10 h 00, 10 h 10 et 10 h 20
Quand il demande une nouvelle copie à 10 h 49
Alors aucune copie n'est créée
Et il revient sur la page de l'exercice avec « Tu pourras recommencer à 10 h 50. »

# CA-30 — La fin de la pause
Étant donné les mêmes 3 copies
Quand il demande une nouvelle copie à 10 h 50
Alors une copie s'ouvre

# CA-31 — Pas d'affilée, pas de pause
Étant donné 3 copies vérifiées à 10 h 00, 10 h 40 et 10 h 50
Quand l'élève demande une nouvelle copie à 10 h 55
Alors une copie s'ouvre

# CA-32 — Les copies abandonnées ne comptent pas
Étant donné 2 copies vérifiées à 10 h 00 et 10 h 10, puis une copie abandonnée à 10 h 15
Quand l'élève demande une nouvelle copie à 10 h 16
Alors une copie s'ouvre

# CA-33 — Toutes les sortes de copies comptent, exercice par exercice
Étant donné une copie libre, une de devoir et une de remédiation du même exercice, vérifiées à 10 minutes d'intervalle
Alors l'élève est en pause sur cet exercice
Et il peut démarrer un autre exercice

# CA-34 — La pause se voit sur le résultat et sur l'exercice
Étant donné un élève en pause jusqu'à 10 h 50
Quand il ouvre le résultat de sa 3e copie, puis la page de l'exercice
Alors aucune des deux ne propose « Refaire l'exercice »
Et chacune dit « Tu pourras recommencer à 10 h 50. »

# CA-35 — La meilleure note compte toujours
Étant donné un élève qui vérifie une copie de devoir à 8/20, puis une à 19/20
Quand son enseignant ouvre le suivi du devoir
Alors il lit 19/20 (règle inchangée)
```

CA-16 et CA-35 sont les tests de non-régression : ni les points ni la pause ne changent la note d'un exercice existant ni la
règle de la meilleure note.

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `QuestionKinds::Select` (choix dans une liste), `QuestionKinds::Written` (réponse rédigée), `QuestionKinds::Notebook` (travail sur le cahier), dans `Question::KINDS` ; `Question` gagne `points`, `unit`, `starter`, `criteria` et `auto_graded?` ; `Grading` calcule le score en points ; `Entities::Assessment::Appreciation` ; `Entities::Assessment::RestartPause` ; `Policies::Assessment::RevealCorrectionPolicy` ; `StartExerciseSession` refuse pendant la pause ; `SubmitExerciseCopy` accepte une réponse rédigée vide et la borne à 2 000 caractères ; `Exercise#publishable?` exige une question corrigée automatiquement ; port `ExerciseSessionRepositoryPort#recent_completions` |
| Infrastructure | Migration : sur les questions, `points` (décimal, 1 par défaut), `unit`, `starter`, `criteria` ; sur les réponses aux questions, un texte long pour la réponse rédigée. Le sujet en blocs (document, tableau), selon l'ADR. Repositories et `ImportCourseTree` (schéma `lnclass.course-tree.v2` : clés `points`, `unit`, `starter`, `criteria`, types `select`, `written`, `notebook`). `ExerciseSessionRepository#recent_completions` (index `student_id, completed_at` existant) |
| Delivery | `ExerciseSessionsController#create` (pause), `ExerciseCopiesController` (réponse rédigée), `SessionResultsController#show` (révélation, appréciation, points, pause), `ExercisesController#show` (pause). Aucune route nouvelle |
| UI | Feuille : `exercise_sessions/kinds/_select`, `_written`, `_notebook`, unité dans `_numeric`, points, sujet en blocs, bouton « Vérifier ma copie ». Résultat : `session_results/show`, `kinds/_select_review`, `_written_review`, `_notebook_review`, grille. Locales `exercise_sessions.fr.yml`, `session_results.fr.yml`, `exercises.fr.yml` ; écran de l'équipe pour les nouveaux champs |

Le découpage en lots revient au plan (phase 3). Un découpage probable : le socle (points, note en points, pause, appréciation,
policy) ; la correction complète et le bouton ; puis un lot par famille de types (choix dans une liste et unité ; réponse
rédigée, grille et cahier ; sujet en blocs), chacun avec son import.

## 6. Décisions rattachées

À écrire après la relecture du porteur, numérotées par `script/docs/build_index --number` :

- **ADR** : la révélation après vérification (nouvelle policy) ; la note en points sur les seules questions corrigées
  automatiquement ; la pause (méthode de port) ; les trois types nouveaux et leur forme d'import ; le sujet en blocs. **Menace
  écrite d'abord** pour la réponse rédigée (texte libre affiché à l'enseignant) et pour l'import des nouvelles clés.
- **UDR** : la feuille (liste déroulante, unité, zone rédigée, cahier, points, document, tableau, bouton et sa phrase
  d'avertissement) et la page du résultat (titre, points, « À revoir », correction complète, corrigé type, grille, pause).
  Elle remplace UDR-0023 sur « jamais les bonnes réponses à l'élève » et UDR-0138 sur le nom du bouton.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes de la page du résultat (élève) | à mesurer au socle | + 1 au plus (fins de copies) | |
| Requêtes de la feuille | à mesurer au socle | inchangé | |
| Note d'un exercice existant | — | identique avant et après (CA-16) | |
