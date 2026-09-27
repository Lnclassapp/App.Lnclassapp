# Inventaire du contexte borné `assessment`

> ⚠️ **Constat structurant à lire en premier** : le parcours élève réel (question par question) passe par `SubmitQuestionAttempt`, qui **n'appelle jamais** la détection ni la résolution des lacunes. `CompleteExerciseSession` — le seul use case qui pilote le cycle ADR-0018 — n'est appelé que par la simulation d'élèves démo, elle-même déclenchée par un job (`SimulateClassroomExerciseJob`) **jamais mis en file**. Conséquence : **toute la feature Remédiation / Lacunes est morte en production**, alors que le code, la table et les écrans existent.

---

### Consulter le catalogue d'exercices
- **Acteur** : tout utilisateur connecté (élève, prof, team)
- **Parcours** : `GET /essentials/:essential_id/exercises` → `Assessment::ExercisesController#index` → grille de cartes d'exercices. Si l'utilisateur est un élève, ses badges sont chargés et affichés sur chaque carte.
- **Règles métier** :
  - L'`essential_id` de l'URL est **ignoré** : la page liste **tous** les exercices de la plateforme (`Orm::Exercise.all`), pas ceux du chapitre.
  - Le flag `published` n'est **pas** filtré : les exercices non publiés sont visibles de tous.
  - Tri : `created_at ASC` (scope global `ordered`).
  - Un badge est indexé par `exercise_id` ; un élève a au plus 1 badge par exercice.
- **Données** : `exercises`, `essentials`, `teams`, `questions`, `exercise_badges`
- **État** : ⚠️ fonctionne mais le filtrage par chapitre et par publication est absent
- **À refaire différemment** : l'index doit être scopé au chapitre parent et aux exercices publiés.

---

### Consulter le détail d'un exercice
- **Acteur** : tout utilisateur connecté
- **Parcours** : `GET /exercises/:id` (slug) → titre, description, liste des questions numérotées avec leur type, puis barre d'action « Meilleur score » + bouton Commencer/Reprendre. Un menu team permet Modifier/Supprimer.
- **Règles métier** :
  - Les **bonnes réponses sont révélées** aux rôles `team` et `teacher` (jamais à l'élève).
  - Pour un élève : `best_session` = meilleure session `completed` triée par `percentage DESC` ; `current_session` = dernière session `started` ; `badge` = badge de l'élève sur cet exercice.
  - S'il existe une session `started`, le bouton devient « Reprendre l'exercice » (reprise exacte, pas de nouvelle session).
  - Libellés de type : `true_false` → « Vrai / Faux », `single_choice` → « Choix unique », `multiple_correct_2` → « 2 bonnes réponses », `multiple_correct_3` → « 3 bonnes réponses ».
- **Données** : `exercises`, `questions`, `answers`, `exercise_sessions`, `exercise_badges`
- **État** : ⚠️ la vue appelle `@exercise.exam_subjects` quand l'exercice n'a pas de chapitre → `NoMethodError` (association inexistante)
- **À refaire différemment** : rendre `essential_id` obligatoire pour supprimer cette branche morte.

---

### Créer / modifier un exercice
- **Acteur** : rôle `team` exclusivement (`authorize_team!`)
- **Parcours** : `GET /essentials/:essential_id/exercises/new` → formulaire (titre, description, case « Publier », bloc questions imbriqué) → `POST` → redirection vers la fiche du chapitre.
- **Règles métier** :
  - Seul champ obligatoire : `title`.
  - Champs acceptés par le contrôleur : `title`, `description`, `published`, `essential_id`, `import_data`. **`questions_attributes` n'est pas dans la liste blanche.**
  - Le repository `save_exercise` n'écrit que title, description, exercise_type, slug, team_id, essential_id, published. **Les questions ne sont jamais persistées par ce chemin.**
  - L'exercice est rattaché au chapitre (par slug) et à `current_team.id`.
- **Données** : `exercises`
- **État** : ❌ cassé — le template rend `Entities::Question.new` et `Entities::Answer.new` (constantes inexistantes, les entités sont sous `Entities::Assessment::`) → `NameError` à l'affichage du formulaire. Même si le formulaire s'affichait, les questions ne seraient pas enregistrées. De plus `create.turbo_stream.erb` rend le partial `exercise` avec `@exercise` non assigné dans la branche succès.
- **À refaire différemment** : un exercice sans question n'a aucune valeur — la création doit être atomique (exercice + questions + réponses) et validée par les règles de l'entité `Question`.

---

### Supprimer un exercice
- **Acteur** : rôle `team`
- **Parcours** : bouton « Supprimer » (confirmation Turbo) → `DELETE /exercises/:id` → redirection vers la fiche du chapitre.
- **Règles métier** :
  - Suppression **physique** (`record.destroy`), en cascade sur `questions` → `answers`, `exercise_sessions` → `question_attempts`, `exercise_badges`, `classroom_assignments`. **Toute la production des élèves est détruite.**
  - Le contrôleur recharge le chapitre deux fois (use case + fallback) pour construire l'URL de retour.
- **Données** : `exercises` et toutes ses tables filles
- **État** : ✅ fonctionne
- **À refaire différemment** : soft delete ou refus de suppression dès qu'une session existe.

---

### Importer des exercices (content engine)
- **Acteur** : rôle `team`
- **Parcours** : `POST /essentials/:essential_id/exercises/import_content_engine` avec un fichier JSON → message « N exercices importés (content engine). »
- **Règles métier** : fichier obligatoire, sinon alerte « Veuillez sélectionner un fichier JSON. » Le service reçoit le contenu brut, le chapitre et `current_team`.
- **Données** : `exercises` (+ `import_data` jsonb), `questions`, `answers`
- **État** : ❌ cassé — `Exercises::ContentEngineImportService` n'existe nulle part dans le code → `NameError`.
- **À refaire différemment** : c'est **le seul moyen théorique de créer des questions**. Dans le nouveau projet, le format d'import doit être spécifié et testé en priorité.

---

### Démarrer une session d'exercice
- **Acteur** : élève (`authorize_student!`)
- **Parcours** : `POST /exercises/:exercise_id/exercise_sessions` (bouton « Commencer ») → création de session → redirection `GET /exercise_sessions/:id`.
- **Règles métier** :
  - **Toutes les sessions `started` de cet élève sur cet exercice sont basculées en `abandoned`** avant création (`update_all`, sans callback). Les sessions `completed` sont conservées → l'historique des tentatives est préservé.
  - Nouvelle session : `status = "started"`, `started_at = Time.current`, `percentage = 0`, `score = 0`.
  - Un `slug` aléatoire `SecureRandom.base58(21)` est généré à la création mais **les URLs utilisent l'`id` numérique**, pas le slug.
  - **Aucune vérification que l'exercice est assigné à la classe de l'élève** (commentaire explicite dans le code : « On pourrait ajouter une vérification »).
  - En cas d'échec de sauvegarde : « Impossible de démarrer la session ».
- **Données** : `exercise_sessions`
- **État** : ✅ fonctionne
- **À refaire différemment** : exposer le slug dans l'URL et vérifier le droit d'accès à l'exercice.

---

### Répondre aux questions d'un exercice (cœur du moteur)
- **Acteur** : élève propriétaire de la session
- **Parcours** : `GET /exercise_sessions/:id` affiche **une** question à la fois dans un Turbo Frame + barre de progression → l'élève valide → `PATCH /exercise_sessions/:id` → le frame est remplacé par la carte de feedback (correct/incorrect, bonnes réponses en vert, explication) → bouton « Question suivante → » ou « Voir les résultats → ».
- **Règles métier** :
  - **Question suivante** = première question de l'exercice non encore tentée, triée par `position ASC`. Si aucune ne reste → redirection vers la page de résultat.
  - **Ordre des propositions aléatoire** à chaque affichage (`answers.shuffle`).
  - Widget selon le type : `single_choice` / `true_false` → radio (`answers[qid]`) ; `multiple_correct_2` / `multiple_correct_3` → cases à cocher (`answers[qid][]`), avec le tag « Plusieurs choix possibles ».
  - Session introuvable → « Session introuvable ». Session déjà `completed` → refus « Session terminée ».
  - Réponse vide → refus « Veuillez sélectionner au moins une réponse. » (la question est re-rendue, statut 422 en HTML).
  - **Correction** (`QuestionAttempt#evaluate!`), sur les **ids** des réponses correctes converties en chaînes :
    - réponse vide ou aucune bonne réponse définie → `false`
    - réponse multiple (Array) → correcte ssi l'ensemble normalisé (`to_s.strip.downcase`, trié) est **strictement égal** à l'ensemble attendu ; **pas de crédit partiel**
    - réponse simple → correcte ssi elle appartient à l'ensemble attendu normalisé
  - **Progression** pendant la session : `percentage = round(nb_tentatives / total_questions × 100)` — c'est un **pourcentage d'avancement**, pas un score. Il est réutilisé tel quel par la barre de progression. `score = nb de tentatives correctes`.
  - **Clôture automatique** dès que `nb_tentatives >= total_questions` : `status = "completed"`, `completed_at = now`, puis **recalcul** : `score = nb_correctes`, `percentage = round(nb_correctes / total_questions × 100)`. Si `total_questions == 0`, le score vaut 0.
  - `total_questions` = `@session.exercise.questions.count` (recompté à chaque requête HTTP).
  - Un `QuestionAttempt` est unique par (session, question) — `find_or_initialize_by` → réponse idempotente.
  - Après clôture, attribution du badge (voir feature suivante).
  - Messages d'encouragement tirés au hasard dans `config/locales/gamification.fr.yml` (`gamification.correct` / `gamification.incorrect`).
  - La barre de progression du Turbo Stream recalcule `nb_tentatives / nb_questions × 100` indépendamment de `session.percentage`.
- **Données** : `exercise_sessions`, `question_attempts` (`provided_answer`, `is_correct`), `questions`, `answers`
- **État** : ⚠️ partiellement cassé
  - Les colonnes `question_attempts.attempted_answer_ids` et `answer_data` **ne sont jamais écrites** (le repository n'écrit que `provided_answer` et `is_correct`). Or les vues `_feedback_card` et `result` s'en servent pour surligner **ce que l'élève a choisi** → **la sélection de l'élève n'est jamais mise en évidence**, seules les bonnes réponses sont vertes.
  - `SubmitQuestionAttempt` ne déclenche **ni** `DetectKnowledgeGaps` **ni** `ResolveKnowledgeGaps` → aucune lacune n'est créée ni résolue dans le parcours réel.
  - `exercise_sessions.badge_level` n'est jamais renseigné.
  - `finish.turbo_stream.erb` existe sans action `finish` correspondante → 💀 code mort.
- **À refaire différemment** : persister les ids des réponses choisies ; un seul use case de clôture, partagé par le parcours réel et la simulation.

---

### Attribution d'un badge
- **Acteur** : système, à la clôture d'une session
- **Parcours** : automatique → badge affiché sur la page de résultat, sur la carte de l'exercice et sur la fiche de l'exercice.
- **Règles métier** (valeurs exactes) :
  - `determine_level(percentage)` : `>= 100` → **gold** · `>= 80` → **silver** · `>= 50` → **bronze** · `< 50` → **aucun badge**. Retourne `nil` si la valeur n'est pas numérique.
  - > ⚠️ L'ADR-0008 documente « ≥ 80 % pour l'Or ». Le code dit 100 %. Le code fait foi.
  - Poids : `bronze = 1`, `silver = 2`, `gold = 3`.
  - `upgrade_if_better` : le badge n'est remplacé que si le nouveau poids est **strictement supérieur** à l'existant. Un élève ne perd jamais son meilleur badge en repassant l'exercice.
  - > ⚠️ L'ADR-0008 documente `>=`. Le code utilise `>`.
  - **Unicité stricte** : index unique `(student_id, exercise_id)` → 1 seul badge par élève et par exercice, mis à jour en place (`find_or_initialize_by`), `earned_at` écrasé à chaque upgrade.
  - Le niveau est stocké en **enum entier** : `bronze = 0`, `silver = 1`, `gold = 2`.
  - Chaque badge reçoit un `slug` `SecureRandom.base58(21)` unique, jamais utilisé dans une URL.
  - Un niveau « **diamond** » est affiché par plusieurs vues (`_exercise_badge`, `_exercise_card`, `student_detail`, `exam_subjects/show`) mais **n'existe dans aucune règle ni dans l'enum** → 💀 branche morte.
  - Libellés UI : bronze → « Bronze » 🥉, silver → « Argent » 🥈, gold → « Or » 🥇, aucun → « Non acquis » 🔒.
- **Données** : `exercise_badges`
- **État** : ✅ fonctionne côté données · ⚠️ la page de résultat lit `@session.badge_level` (jamais écrit) → **le badge n'est jamais affiché sur l'écran de résultat**, on voit le placeholder « :( » même à 100 %.

---

### Voir le résultat d'une session
- **Acteur** : élève propriétaire
- **Parcours** : `GET /exercise_sessions/:id/result` → badge, « Félicitations ! » ou « Courage ! », score en %, boutons de retour, puis le détail question par question (réponses colorées + explications).
- **Règles métier** :
  - Titre : « Félicitations ! » si `percentage >= 50`, sinon « Courage ! ».
  - **Confettis** déclenchés côté client si `percentage >= 50` (animation de 3 secondes).
  - Bouton « Recommencer » affiché uniquement si `percentage < 100`.
  - Tentatives listées dans l'ordre `questions.position ASC`.
  - Accès : `@session.student_id == current_student.id`, sinon redirection racine avec « Acces interdit. »
- **Données** : `exercise_sessions`, `question_attempts`, `questions`, `answers`, `exercise_badges`
- **État** : ⚠️ badge jamais affiché (cf. ci-dessus) ; sélection de l'élève jamais surlignée (`attempted_answer_ids` vide)

---

### Recommencer un exercice
- **Acteur** : élève
- **Parcours** : bouton « Recommencer » sur la page de résultat → `POST /exercises/:exercise_id/exercise_sessions` → nouvelle session vierge.
- **Règles métier** : aucune limite de tentatives. Chaque session complétée est conservée (utilisée pour « meilleur score » et le compteur de tentatives du rapport prof).
- **Données** : `exercise_sessions`
- **État** : ✅ fonctionne

---

### Détecter une lacune après un échec
- **Acteur** : système
- **Parcours** : déclenché à la clôture d'une session par `CompleteExerciseSession`.
- **Règles métier** :
  - Déclenchée si `percentage < 50` (échec). Si la session est réussie, retour en succès avec 0 lacune.
  - Aucune lacune si l'exercice n'a **pas** d'`essential_id` (succès silencieux, 0 lacune).
  - Exercice introuvable → « Exercice introuvable ». Identifiants élève/exercice manquants → « Identifiants étudiant et exercice requis ».
  - Granularité = la **notion essentielle** (`essential_id`), pas l'exercice.
  - S'il existe déjà une lacune `pending` sur (élève, notion) : `failed_attempts_count += 1` et `exercise_session_id` mis à jour vers la dernière session. Sinon création avec `status = "pending"`, `failed_attempts_count = 1`.
  - Clé primaire : nanoid Base58 (string), générée par `has_nanoid(:id)` (ADR-0017).
- **Données** : `knowledge_gaps`, `exercises.essential_id`
- **État** : 💀 jamais atteint dans le parcours réel (uniquement via la simulation démo, elle-même jamais déclenchée)

---

### Résoudre une lacune après une réussite
- **Acteur** : système
- **Parcours** : déclenché à la clôture d'une session par `CompleteExerciseSession`.
- **Règles métier** :
  - Déclenchée si `percentage >= 50`.
  - Cherche la lacune `pending` sur (élève, notion de l'exercice). Aucune → succès silencieux (0 lacune résolue).
  - Notion introuvable pour l'exercice → « Notion essentielle introuvable pour cet exercice ». Élève manquant → « Identifiant élève manquant ».
  - Transition : `remediated` si la session provient du flux de remédiation (`is_remediation: true`), sinon `self_corrected`. Dans les deux cas `resolved_at = now`.
  - Une lacune résolue ne redevient jamais `pending` automatiquement — `reopen!` existe sur l'entité (repasse en `pending`, efface `resolved_at`, incrémente `failed_attempts_count`) mais **n'est appelé nulle part** (💀).
  - Statuts : `pending`, `self_corrected`, `remediated`.
- **Données** : `knowledge_gaps`
- **État** : 💀 jamais atteint dans le parcours réel

---

### Lancer une session de remédiation (élève)
- **Acteur** : élève
- **Parcours** : bouton orange « 🎯 Remédiation » sur la carte d'exercice (contexte classe) → `POST /remediation_sessions` avec `essential_id` → génération just-in-time → redirection vers la session d'exercice.
- **Règles métier** :
  - Une lacune **`pending`** sur (élève, notion) est obligatoire ; sinon « Aucune lacune active (pending) trouvée pour cet élève et cette notion. » Si la lacune est résolue → « La lacune ciblée est déjà résolue (statut: X). »
  - La lacune peut être fournie directement (entité), par `gap_id`, ou déduite de (`student_id`, `essential_id`) ; `essential_id` peut lui-même être déduit d'un `exercise_id`.
  - Choix de l'exercice de rattrapage : **premier exercice de la notion dont `published != false`**, à défaut le premier tout court. Aucun critère pédagogique (difficulté, exercice non déjà échoué…). Aucun exercice → « Aucun exercice disponible pour cette notion essentielle. »
  - `force_new: true` par défaut → les sessions `started` en cours sur cet exercice sont abandonnées et une nouvelle session est créée. Avec `force_new: false`, une session active existante serait réutilisée.
  - Aucune donnée ne marque la session comme « de remédiation » en base : le flag `is_remediation` n'existe qu'en mémoire, le temps d'un appel.
  - Accès réservé au rôle `student` (`current_user&.student?`), sinon « Accès non autorisé ».
- **Données** : `knowledge_gaps`, `exercises`, `exercise_sessions`
- **État** : ❌ cassé sur deux points indépendants :
  1. Le contrôleur et la carte passent **`current_user.id`** (id utilisateur) là où est attendu un **`student_id`** (id de profil élève). Les lacunes étant stockées avec `student_id`, la recherche échoue quasi systématiquement → **le bouton n'apparaît jamais** et, s'il apparaissait, la génération échouerait.
  2. Même une session de remédiation lancée avec succès se terminerait via `SubmitQuestionAttempt`, qui ne résout aucune lacune → la lacune resterait éternellement `pending`.
- **À refaire différemment** : persister le caractère « remédiation » sur la session (colonne dédiée) au lieu d'un paramètre volatil.

---

### Suivre les remédiations de sa classe (enseignant)
- **Acteur** : enseignant
- **Parcours** : pastille « 🔴 N en difficulté / 🟢 N résolus » sur la carte d'exercice → `GET /teachers/classroom_exercises/:slug/remediation?classroom_id=X` (Turbo Frame `exercise_report_<exercise_id>`) → panneau à 3 colonnes : **En difficulté** (`pending`), **Auto-corrigés** (`self_corrected`), **Remédiation réussie** (`remediated`), chacune listant les noms d'élèves. Lien « Fermer » (`?close=true`).
- **Règles métier** :
  - Périmètre = élèves de la classe (`classroom_students`) × notion essentielle de l'exercice.
  - Lacunes triées par `created_at DESC`, groupées par statut.
  - Compteur « résolus » = `remediated + self_corrected`.
  - La pastille n'apparaît que si `pending > 0` **ou** `résolus > 0`.
  - Si l'exercice n'a pas de notion ou la classe aucun élève → compteurs à 0, liste vide, « Aucune donnée de remédiation pour cette classe. »
- **Données** : `knowledge_gaps`, `classroom_students`, `exercises.essential_id`, `students`
- **État** : ❌ cassé — `set_classroom_exercise` appelle `Orm::ClassroomExercise.find_by(...)`, **classe inexistante** → `NameError` sur les 3 actions du contrôleur (`show`, `report`, `remediation`). De toute façon la table `knowledge_gaps` reste vide faute de détection.

---

### Assigner un exercice à une classe
- **Acteur** : enseignant
- **Parcours** : bouton « Assigner » sur la carte d'exercice (page chapitre d'une classe) → `POST /classrooms/:classroom_id/exercises` avec `exercise_id` → le bouton devient « Assigné » (vert).
- **Règles métier** :
  - Autorisation par `Policies::ClassroomAccessPolicy` : l'enseignant doit être rattaché à la classe, sinon redirection racine « Accès non autorisé à cette classe. »
  - Assignation **polymorphe** (ADR-0007) dans `classroom_assignments` : `resource_type = "Orm::Exercise"` (le domaine manipule `"Exercise"`, le repository préfixe), `resource_id = exercise.id`, `assigned_by_id`, `status = "added"`.
  - Index unique `(classroom_id, resource_type, resource_id)` → une seule assignation par couple.
  - Si une assignation **active** (non `archived`) existe déjà : succès idempotent, message « Exercice déjà assigné. »
  - Une assignation `archived` re-sauvegardée repasse en `added` (réactivation).
  - Statuts autorisés : `added`, `active`, `validated`, `archived`. Défaut SQL de la colonne : `active`.
- **Données** : `classroom_assignments`
- **État** : ❌ cassé — la réponse `format.turbo_stream` n'a **aucun template** (`app/views/assessment/classroom_exercises/` n'existe pas) → `ActionView::MissingTemplate`. En amont, la page qui porte le bouton est elle-même cassée (voir ci-dessous).

---

### Retirer un exercice d'une classe
- **Acteur** : enseignant
- **Parcours** : clic sur le bouton vert « Assigné » → `DELETE /classrooms/:classroom_id/exercises/:id` → message « Exercice retiré de la classe. »
- **Règles métier** : **soft delete** (ADR-0016) — `status` passe à `"archived"`, la ligne est conservée. Les sessions et badges déjà produits ne sont pas touchés.
- **Données** : `classroom_assignments`
- **État** : ❌ cassé — même absence de template `turbo_stream` que pour l'assignation.

---

### Voir la page « chapitre d'une classe » (point d'entrée de l'assignation)
- **Acteur** : enseignant
- **Parcours** : `GET /teachers/classrooms/:id/essentials/:essential_id` → liste des exercices du chapitre avec l'état d'assignation (Assigner / Assigné), le lien « Résultats » et la pastille de remédiation.
- **Règles métier** : les exercices du chapitre sont chargés avec leurs questions et réponses, triés `created_at ASC` ; l'état d'assignation est indexé par exercice.
- **Données** : `essentials`, `exercises`, `classroom_assignments`
- **État** : ❌ cassé — `@classroom.classroom_exercises.where(exercise_id: ...).index_by(&:exercise_id)` : la table `classroom_assignments` **n'a pas de colonne `exercise_id`** (c'est `resource_id`) → erreur SQL. Idem ligne 40 du même contrôleur pour l'accueil de la classe, et pour `classroom_essentials.index_by(&:essential_id)`.

---

### Rapport de classe — synthèse (enseignant)
- **Acteur** : enseignant
- **Parcours** : `GET /teachers/classroom_exercises/:slug?classroom_id=X` → 4 KPI (Élèves, Ont complété, Score moyen, Tentatives) + distribution des badges + tableau par élève.
- **Règles métier** :
  - Seules les sessions **`completed`** sont comptées, triées `completed_at DESC`.
  - `total_students` = effectif de la classe.
  - `completed_count` = élèves ayant au moins une session complétée.
  - `completion_rate` = `round(completed_count / total_students × 100)` ; 0 si classe vide.
  - `average_score` = moyenne des `percentage` de **toutes** les sessions complétées (pas seulement des meilleures) ; 0 si aucune.
  - `total_attempts` = nombre total de sessions complétées.
  - Par élève : `best_score` = max des `percentage`, `attempts` = nombre de sessions, `badge`.
  - **Cache** `Rails.cache` 1 heure, clé `classroom_report_stats:<classroom_id>:<exercise_id>` — **jamais invalidée** à la complétion d'une session.
  - Résolution de la classe si `classroom_id` absent : la classe de l'enseignant ayant des sessions sur cet exercice s'il n'y en a qu'une, sinon la **première classe** de l'enseignant (arbitraire).
  - Distribution des badges affichée sur 3 paliers : Bronze / Argent / Or.
- **Données** : `classrooms`, `classroom_students`, `students`, `exercise_sessions`, `exercise_badges`
- **État** : ❌ cassé par le `Orm::ClassroomExercise` de `set_classroom_exercise`
- **À refaire différemment** : rendre `classroom_id` obligatoire, et invalider le cache à la clôture de session.

---

### Rapport de classe — détaillé (enseignant)
- **Acteur** : enseignant
- **Parcours** : lien « Résultats » sur la carte d'exercice → Turbo Frame `GET /teachers/classroom_exercises/:slug/report?classroom_id=X` → synthèse, alerte révision, tableau question par question, tableau élève par élève. Lien « Fermer » (`?close=true`).
- **Règles métier** (seuils exacts) :
  - **Statistiques par question** (questions triées par `id`, numérotées à partir de 1) : `correct`, `incorrect = tentées − correctes`, `not_attempted = effectif_classe − tentées`, `success_rate = round(correct / effectif_classe × 100)` — **le dénominateur est l'effectif de la classe, pas le nombre de répondants**.
  - Étiquette de maîtrise par question : `>= 70` → **Maîtrisé** · `>= 50` → **À surveiller** · sinon → **À réviser**.
  - « Alerte révision » : liste les questions dont `success_rate < 50`.
  - **Par élève** : `best_pct` = meilleur `percentage` parmi les sessions complétées ; **`score_on_20 = round(best_pct / 5)`** ; `attempts` = nombre de sessions ; `failed_indexes` = numéros des questions ratées **dans la meilleure session**, triés.
  - **Synthèse** : `total` = effectif ; `completed` = nombre d'élèves ayant au moins une session complétée ; `mastered_pct = round(nb_élèves_ayant_au_moins_une_session_à_70 %_ou_plus / effectif × 100)` — **seuil de maîtrise = 70 %** ; `needs_support` = nombre d'élèves dont `best_pct < 50`.
  - Cache 1 h, clé `classroom_report_detailed:<classroom_id>:<exercise_id>`, jamais invalidée.
- **Données** : `classrooms`, `students`, `exercise_sessions`, `question_attempts`, `questions`, `exercise_badges`
- **État** : ❌ cassé par le même `Orm::ClassroomExercise`
- **À refaire différemment** : trois seuils différents cohabitent sans être nommés (50 = réussite/badge bronze, 70 = maîtrise, 80/100 = badges). À expliciter en constantes métier uniques.

---

### Consulter le détail d'un élève (enseignant)
- **Acteur** : enseignant
- **Parcours** : `GET /teachers/classrooms/:classroom_id/students/:public_id` → historique des sessions complétées de l'élève, triées par `completed_at DESC`, avec badge par session.
- **Règles métier** : l'élève est identifié par le `public_id` de son **user** et doit appartenir à la classe (sinon 404 via `find_by!`).
- **Données** : `classrooms`, `classroom_students`, `students`, `users.public_id`, `exercise_sessions`, `exercise_badges`
- **État** : ⚠️ la vue lit `session.badge_level`, colonne jamais renseignée → la pastille de badge n'apparaît jamais. Deux copies de la vue existent (`app/views/teachers/classrooms/student_detail.html.erb` et `app/views/classroom/teachers/classrooms/student_detail.html.erb`) — une des deux est morte.

---

### Compteurs de badges de la classe sur la carte d'exercice
- **Acteur** : enseignant
- **Parcours** : pied de la carte d'exercice en contexte classe → pastilles « N Argent », « N Or ».
- **Règles métier** : `ExerciseBadgeQuery` compte les badges des élèves de la classe (`classroom_students`) pour cet exercice, groupés par niveau. Renvoie `{}` si la classe n'a pas d'élève. Si aucun badge : « Aucun badge obtenu ».
- **Données** : `exercise_badges`, `classroom_students`
- **État** : ⚠️ la vue n'affiche que **Argent, Or et « Diamant »** — **Bronze est silencieusement omis** et Diamant n'existe pas. Les badges bronze sont donc invisibles pour l'enseignant.

---

### Simulation d'élèves de démonstration (ADR-0019)
- **Acteur** : système (job asynchrone)
- **Parcours prévu** : à l'assignation d'un exercice → `SimulateClassroomExerciseJob.perform_later(classroom_id, exercise_id)` → pour chaque élève `is_demo` de la classe, une session complète est jouée.
- **Règles métier** :
  - Cible : élèves de la classe dont le **user** a `is_demo = true`.
  - Exercice introuvable → « Exercice introuvable ». Exercice sans question → « Exercice sans questions ».
  - **Remediation boost** : si l'élève a une lacune `pending` sur la notion de l'exercice, **100 % de bonnes réponses**. Sinon **70 % de probabilité** de répondre juste par question (`rand < 0.7`).
  - Réponse fausse simulée = chaîne littérale `"mauvaise_reponse"`. Réponse juste = id de la première bonne réponse (ou `"1"` à défaut).
  - Toutes les questions **sauf la dernière** passent par `SubmitQuestionAttempt` avec `total_questions = nb_questions + 1` (astuce pour empêcher la clôture prématurée), puis `CompleteExerciseSession` clôt la session avec la payload complète et réévalue tout.
  - **Durée simulée** : `completed_at = now`, `started_at = completed_at − rand(5..20) minutes`, sauvegardés dans une seconde passe.
  - `is_remediation` passé à la clôture = présence d'une lacune `pending` → l'élève démo boosté fait passer sa lacune en `remediated`.
- **Données** : `students`, `users.is_demo`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps`
- **État** : 💀 code mort — `SimulateClassroomExerciseJob` **n'est mis en file nulle part** dans le code. Les use cases `GenerateDemoStudents` et `PurgeDemoStudents` annoncés par l'ADR-0019 n'existent pas dans `app/domain/use_cases/`.

---

### Sujets d'examen (élève / enseignant / team)
- **Acteurs** : élève, enseignant, team
- **Parcours prévus** : `/students/examens`, `/students/training-examens`, `/students/subject-examens`, `/students/examens/:id` (+ `POST /students/examens/:id/retry`), `/teachers/examens…`, `/teams/examens` (+ `import_json`, `destroy`), assignation d'un sujet à une classe (`/teachers/classroom_exam_assignments`), validation d'assignation.
- **Règles métier lisibles dans le code et les vues** :
  - Deux catégories : `training` et `lnclass_special` (paramètre `exam_type`). L'index redirige vers la route dédiée quand `exam_type` est fourni.
  - Filtrage élève par `level_id` de l'élève, puis par matière (`material_id`) et catégorie (`science` / `literature`).
  - Répartition des matières : littéraires si le nom matche `/Français|Histoire|Géographie|Philo/i` ou `category == "literature"` ; scientifiques si `/Math|Physique|Chimie|SVT|PC\b/i` ou `category == "science"`.
  - Séparation « sujets traités » / « sujets non traités » (`treated_subjects` / `untreated_subjects`).
  - **Paywall** : un élève dont le profil est `unpaid?` voit la vue `paywall` au lieu du sujet.
  - Import JSON (team) : accepte un objet ou un tableau ; un sujet dont le `title` existe déjà est **ignoré** (compteur `skipped`). Attributs importés : `title`, `exam_category`, `exam_type`, etc.
  - Assignation : un enseignant ne peut assigner un sujet que si `exam_subject.level_id == classroom.level_id` **et** (le sujet n'a pas de séries **ou** la série de la classe figure dans celles du sujet). Le sujet doit relever de la matière de l'enseignant (`material_id`).
  - Validation d'assignation : passage du statut à `validated`, sous réserve de `ClassroomAccessPolicy` ; sinon « Assignation introuvable. » ou « Non autorisé. »
  - `retry` : redirige vers le sujet avec « Vous pouvez maintenant refaire ce sujet. » (aucune donnée n'est réinitialisée).
- **Données** : aucune — **la table `exam_subjects` n'existe pas**
- **État** : ❌ **entièrement non fonctionnel** — il n'existe **ni table `exam_subjects`**, **ni modèle `Orm::ExamSubject`**. `Repositories::Assessment::ExamRepository` est un **stub** qui renvoie `[]` / `nil` / `true`. Concrètement : les index affichent une liste vide, `show` redirige toujours vers « Sujet introuvable », `retry` plante (`nil.slug`), l'import plante, `ExamCatalogQuery` plante (`Orm::ExamSubject` inexistant) — donc `/students/examens` échoue dès le chargement du catalogue.
- **À refaire différemment** : c'est une feature **à spécifier de zéro** ; seules l'entité `Entities::ExamSubject` et les vues (assez complètes) subsistent comme cahier des charges.

---

### Accueil élève — exercices de ma classe
- **Acteur** : élève
- **Parcours** : `GET /students` → matières de la classe, exercices assignés à la classe avec progression (sessions, badges, meilleurs scores, nombre de tentatives), messages récents, 10 dernières activités.
- **Règles métier** :
  - L'élève doit avoir un `classroom_id`, sinon redirection vers la complétion de profil.
  - `best_scores` = `max(percentage)` par exercice sur les sessions `completed`.
  - `sessions_count` = nombre de sessions `completed` par exercice.
  - `activities` = 10 dernières sessions complétées triées par `completed_at DESC`.
  - Les exercices de la classe sont triés `created_at DESC`.
- **Données** : `classroom_assignments`, `exercises`, `essentials`, `exercise_sessions`, `exercise_badges`, `messages`
- **État** : ❌ cassé — `StudentFeedQuery#get_classroom_exercises` appelle `Orm::ClassroomExercise` (inexistant) → **la page d'accueil de tout élève rattaché à une classe plante**. Même problème pour l'accueil enseignant via `Orm::ClassroomEssential` dans `TeachersFeedQuery#get_recent_essentials_in_classrooms`.

---

### Progression de l'élève sur la fiche d'un chapitre
- **Acteur** : élève
- **Parcours** : `GET /essentials/:id` → les exercices du chapitre affichent le badge et la session de l'élève.
- **Règles métier** : mêmes calculs que l'accueil (`get_student_progress`) mais restreints aux exercices du chapitre.
- **Données** : `exercise_sessions`, `exercise_badges`
- **État** : ✅ fonctionne (ce chemin n'appelle pas `Orm::ClassroomExercise`)

---

## 1. Tables du contexte, colonnes et index

### `exercises`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `title` | string | **not null** |
| `description` | text | |
| `essential_id` | bigint | nullable, FK `essentials` (counter cache `exercises_count`) |
| `team_id` | bigint | nullable, FK `teams` |
| `exercise_type` | integer | enum `fixation: 0`, `evaluation: 1` |
| `questions_count` | integer | def. `0`, not null — counter cache des questions |
| `published` | boolean | def. `false` |
| `slug` | string | |
| `source_exam` | string | |
| `recurrence_rate` | integer | |
| `import_data` | jsonb | def. `{}` |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `essential_id` · `team_id` · `slug` (**non unique**) · `import_data` (GIN)

### `questions`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `exercise_id` | bigint | **not null**, FK, counter cache |
| `content` | text | **not null** |
| `explanation` | text | affichée après la réponse |
| `position` | integer | **nullable** — pilote l'ordre des questions |
| `question_type` | integer | def. `0`, not null — `true_false: 0`, `single_choice: 1`, `multiple_correct_2: 2`, `multiple_correct_3: 3` |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `exercise_id`

### `answers`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `question_id` | bigint | **not null**, FK |
| `content` | string | **not null** |
| `is_correct` | boolean | def. `false`, **not null** |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `question_id`

### `exercise_sessions`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `student_id` | bigint | **not null**, FK `students` |
| `exercise_id` | bigint | **not null**, FK |
| `status` | string | def. `"started"` — `started` / `completed` / `abandoned` |
| `percentage` | integer | def. `0` — avancement puis score |
| `score` | **float** | def. `0.0` — nombre de bonnes réponses |
| `badge_level` | string | **jamais écrite par le code** |
| `started_at` | datetime | |
| `completed_at` | datetime | |
| `slug` | string | `SecureRandom.base58(21)` à la création |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `exercise_id` · `student_id` · `slug` (**unique**)

### `question_attempts`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `exercise_session_id` | bigint | **not null**, FK |
| `question_id` | bigint | **not null**, FK |
| `provided_answer` | text | contient l'id (ou les ids) de réponse choisie |
| `is_correct` | boolean | def. `false` |
| `attempted_answer_ids` | integer[] | def. `[]` — **jamais écrite**, pourtant lue par 2 vues |
| `answer_data` | jsonb | def. `{}` — **jamais écrite ni lue** |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `exercise_session_id` · `question_id` — **pas d'index unique sur `(exercise_session_id, question_id)`** alors que l'unicité est présupposée par le code (`find_or_initialize_by`)

### `exercise_badges`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `student_id` | bigint | **not null**, FK |
| `exercise_id` | bigint | **not null**, FK |
| `level` | integer | **not null** — enum `bronze: 0`, `silver: 1`, `gold: 2` |
| `earned_at` | datetime | |
| `slug` | string | `SecureRandom.base58(21)` |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `student_id` · `exercise_id` · **`(student_id, exercise_id)` UNIQUE** · `slug` UNIQUE

### `knowledge_gaps`
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | **string** | PK nanoid Base58 (`has_nanoid`) |
| `student_id` | bigint | **not null**, FK |
| `essential_id` | bigint | **not null**, FK |
| `exercise_session_id` | bigint | nullable, FK (`dependent: :nullify`) |
| `status` | string | def. `"pending"`, **not null** — `pending` / `self_corrected` / `remediated` |
| `failed_attempts_count` | integer | def. `1`, **not null**, validé `>= 1` (ORM) / `>= 0` (entité) |
| `resolved_at` | datetime | |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `student_id` · `essential_id` · `exercise_session_id` · `status` · `(student_id, essential_id)` · `(student_id, status)` · `(student_id, essential_id, status)` — **aucun n'est unique**, alors que « une seule lacune `pending` par (élève, notion) » est une invariante du code

### `classroom_assignments` (partagée avec le contexte `classroom`, porte les exercices assignés)
| Colonne | Type | Contraintes / valeurs |
|---|---|---|
| `id` | bigint | PK |
| `classroom_id` | bigint | **not null**, FK |
| `resource_type` | string | **not null** — vaut `"Orm::Exercise"` pour un exercice |
| `resource_id` | bigint | **not null** |
| `assigned_by_id` | bigint | nullable — association vers `Orm::User` |
| `status` | string | def. `"active"`, **not null** — `added` / `active` / `validated` / `archived` |
| `created_at` / `updated_at` | datetime | not null |

**Index** : `(classroom_id, resource_type, resource_id)` **UNIQUE** · `classroom_id` · `(resource_type, resource_id)`

> **Tables manquantes** : `exam_subjects` (et ses tables de liaison matière / série / exercices) n'existe pas, alors que tout un pan de code, de routes et d'écrans en dépend.
>
> **Classes ORM appelées mais inexistantes** : `Orm::ClassroomExercise`, `Orm::ClassroomEssential`, `Orm::ExamSubject`.

---

## 2. Règles métier implicites ou non écrites, à rendre explicites

1. **Seuil de réussite = 50 %** (`ExerciseSession#success?`). Il pilote à la fois le badge bronze, la détection de lacune, la résolution de lacune, les confettis, le libellé « Félicitations / Courage » et le compteur `needs_support` du rapport. Jamais nommé ni centralisé.
2. **Seuil de maîtrise = 70 %**, utilisé uniquement dans le rapport détaillé (`mastered_pct` et l'étiquette « Maîtrisé »), sans rapport avec les paliers de badge.
3. **Barème sur 20 = `percentage / 5`**, arrondi. Jamais écrit en base, recalculé dans une seule vue.
4. **Un badge par élève et par exercice, monotone croissant** : le badge ne peut que monter, jamais descendre, et il n'est pas historisé — impossible de savoir qu'un bronze a été obtenu avant un or, ni quand.
5. **Une seule lacune `pending` par (élève, notion)** — invariante applicative sans contrainte SQL, donc exposée aux écritures concurrentes.
6. **La granularité pédagogique de la lacune est la notion essentielle, pas l'exercice** : réussir **n'importe quel** exercice de la notion résout la lacune, même un exercice plus facile que celui qui l'avait créée.
7. **La remédiation choisit le premier exercice publié de la notion**, sans exclure celui qui vient d'être échoué : l'élève peut être renvoyé sur l'exercice raté.
8. **`exercise_sessions.percentage` a deux significations** dans le cycle de vie : avancement (`nb_réponses / nb_questions`) tant que la session est `started`, score (`nb_correctes / nb_questions`) une fois `completed`. La barre de progression et le rapport lisent la même colonne.
9. **Pas de crédit partiel** sur les questions à réponses multiples : la sélection doit être exactement l'ensemble des bonnes réponses.
10. **Ordre des propositions aléatoire à chaque affichage**, mais ordre des questions déterministe (`position ASC`) — et `position` est nullable, donc l'ordre n'est pas garanti.
11. **Aucune limite de tentatives, aucune durée maximale, aucune expiration de session.** Une session `started` peut rester ouverte indéfiniment ; elle n'est fermée (en `abandoned`) que si l'élève relance l'exercice.
12. **Aucun contrôle d'accès pédagogique** : n'importe quel élève connecté peut démarrer n'importe quel exercice, publié ou non, assigné à sa classe ou non.
13. **La suppression d'un exercice détruit tout l'historique** des élèves (sessions, tentatives, badges) par cascade `dependent: :destroy`.
14. **Retirer un exercice d'une classe est réversible** (soft delete, statut `archived`), mais une ré-assignation réactive la ligne d'origine et conserve donc la date de création initiale.
15. **`assigned_by_id` reçoit un id de profil enseignant** (`current_teacher.id`) alors que l'association pointe vers `Orm::User` — incohérence de référence.
16. **Les rapports enseignant sont mis en cache 1 h sans invalidation** : après qu'un élève termine un exercice, l'enseignant voit des chiffres périmés jusqu'à une heure.
17. **`success_rate` par question se calcule sur l'effectif de la classe**, pas sur le nombre de répondants : une question à laquelle personne n'a répondu affiche 0 % (« À réviser ») et non « non évaluée ».
18. **Le contrat de `evaluate!` est ambigu** : `SubmitQuestionAttempt` compare des **ids** de réponses, `CompleteExerciseSession` accepte ids **ou** contenus textuels. Deux définitions de « bonne réponse » coexistent dans le même moteur.
19. **La comparaison est insensible à la casse et aux espaces** (`to_s.strip.downcase`) — sans effet sur des ids, mais déterminant si un jour on compare des contenus.
20. **La durée estimée d'un exercice** (`ceil(nb_questions × 1,5)` minutes, minimum 1) est codée dans l'entité `Exercise#estimated_duration` mais affichée nulle part (💀).
21. **Les validations structurelles des questions ne sont jamais exécutées** : `true_false` = exactement 2 choix / 1 correcte ; `single_choice` = ≥ 2 choix / exactement 1 correcte ; `multiple_correct_2` = ≥ 3 choix / exactement 2 correctes ; `multiple_correct_3` = ≥ 4 choix / exactement 3 correctes. Ces règles vivent dans `Entities::Assessment::Question`, mais aucun chemin de persistance ne les traverse.
22. **« Diamond » est un quatrième palier de badge fantôme**, présent dans 4 vues, absent de toute règle et de l'enum.
23. **Le `slug` des sessions et des badges est généré mais jamais utilisé dans une URL** : les identifiants numériques séquentiels sont exposés.
24. **Un exercice peut exister sans chapitre (`essential_id` nullable)** — dans ce cas il ne peut jamais produire de lacune, et plusieurs vues plantent en cherchant un sujet d'examen de repli.

---

## 3. Ce que je n'ai pas pu déterminer

1. **Le format du JSON d'import des exercices** (`import_content_engine`) : le service `Exercises::ContentEngineImportService` n'existe pas dans le dépôt. La colonne `exercises.import_data` (jsonb, indexée GIN) suggère qu'on y stocke la charge brute, mais aucun exemple n'est présent. **C'est le seul chemin de création de questions** — à récupérer auprès de l'équipe ou dans l'historique git.
2. **Le modèle de données des sujets d'examen** : `Entities::ExamSubject` et les vues donnent des indices (`title`, `exam_category`, `exam_type`, `material_id`, `level_id`, `series`, `exercises`, `published`, `slug`) mais ni table, ni ORM, ni migration ne permettent de reconstituer le schéma exact ni la relation `exam_subjects ↔ exercises`.
3. **À quel moment `SimulateClassroomExerciseJob` était censé être déclenché** : l'ADR-0019 dit « lorsqu'un exercice est assigné », mais aucun appel ne subsiste dans `CreateClassroomExercise` ni dans les contrôleurs.
4. **Les use cases `GenerateDemoStudents` et `PurgeDemoStudents`** décrits par l'ADR-0019 : absents du dépôt. Impossible de savoir comment les élèves démo sont créés aujourd'hui (probablement dans le `ClassroomRepository` via `insert_all!`, côté contexte `classroom`).
5. **La signification de `exercises.recurrence_rate`** : colonne présente, lue nulle part. `exercises.source_exam` n'apparaît que dans un fil d'Ariane enseignant.
6. **L'utilité de `question_attempts.answer_data` (jsonb)** : jamais écrite ni lue, aucune trace de son intention.
7. **Si la production tourne réellement avec ce code** : plusieurs chemins très fréquentés (accueil élève, page chapitre d'une classe, rapports enseignant, assignation d'exercice) lèvent des `NameError` ou des erreurs SQL au premier appel. Soit la branche courante `docs/process-v2` a régressé par rapport à ce qui est déployé, soit ces écrans ne sont plus utilisés. Je n'ai pas exécuté l'application pour trancher.
8. **Le rôle exact du paramètre `close=true`** sur les actions `report` et `remediation` : il rend le même template sans charger les données, ce qui produit un panneau vide plutôt qu'un frame refermé. Le comportement attendu côté UX n'est pas documenté.

---

## 4. Fichiers clés (chemins absolus)

| Sujet | Fichier |
|---|---|
| Cycle de vie et calcul de score d'une session | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/assessment/exercise_session.rb` |
| Règle de correction d'une réponse | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/assessment/question_attempt.rb` |
| Barème et upgrade des badges | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/assessment/exercise_badge.rb` |
| Validations structurelles des questions | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/assessment/question.rb` |
| Cycle de vie des lacunes | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/knowledge_gap.rb` |
| Parcours élève réel (question par question) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/submit_question_attempt.rb` |
| Clôture + cycle ADR-0018 (inutilisé en prod) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/complete_exercise_session.rb` |
| Détection des lacunes | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/detect_knowledge_gaps.rb` |
| Résolution des lacunes | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/resolve_knowledge_gaps.rb` |
| Remédiation just-in-time | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/generate_remediation_session.rb` |
| Simulation élèves démo | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/assessment/simulate_demo_student_session.rb` |
| Seuils des rapports enseignant | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/queries/classroom_report_query.rb` |
| Persistance sessions / tentatives / badges | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/repositories/assessment/exercise_execution_repository.rb` |
| Persistance et agrégats des lacunes | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/repositories/assessment/knowledge_gap_repository.rb` |
| Stub des sujets d'examen | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/repositories/assessment/exam_repository.rb` |
| Écran de passage d'exercice | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/assessment/exercise_sessions/` |
| Carte d'exercice (élève + prof) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/components/_exercise_card.html.erb` |
| Rapports enseignant | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/teachers/classroom_exercises/` |
