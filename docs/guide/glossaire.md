# Glossaire — le langage omniprésent

> Un concept = **un seul mot**, dans le code, dans la base, dans l'UI, dans les chantiers et dans les ADR.
> Ce fichier remplace `CONTEXT.md` et [`../archives/STANDARD/glossary.md`](../archives/STANDARD/glossary.md) (v1, gelée et partiellement fausse).
> Le découpage en contextes bornés est dans [`architecture.md` §5](architecture.md#5-les-six-contextes-bornés), les règles de nommage dans [`conventions.md`](conventions.md).

---

## Les trois règles

**1. Code en anglais, UI en français.** `Entities::Catalog::Course` dans le code, « Cours » à l'écran via `t(".key")`. Locale par défaut `:fr` (`config/application.rb`). Les traductions des modèles de domaine sont dans `config/locales/fr.yml`, sous `activemodel.models.entities/…`.

**2. Un concept = un seul mot. Pas de synonymes.** Si le mot est `Essential`, on n'écrit jamais `Lesson`, `Sheet` ni `Fiche` dans le code. Un synonyme introduit dans une PR coûte des heures de lecture à tous les suivants — humains comme agents.

**3. Un terme absent de ce glossaire ne s'invente pas.** Tu le proposes à l'équipe, tu l'ajoutes ici, puis tu l'utilises. Un terme métier employé dans le code et absent d'ici est un bug de documentation.

---

## 1. Acteurs

Le rôle est un `enum` sur `Orm::User` (`app/infrastructure/orm/user.rb` l. 40) :

```ruby
enum :role, { team: 0, teacher: 1, student: 2, parent: 3, school_admin: 4 }
```

| Terme | Définition | Où c'est dans le code |
|---|---|---|
| **User** | Compte de connexion. Identifié par son **contact** (numéro de téléphone), pas par un email. Porte le rôle et le `public_id`. Mot de passe via `has_secure_password` ([ADR-0002](../decisions/adr/0002-authentification-native-contact-telephonique-sans-devise.md)). | `Orm::User`, `Entities::Identity::User` |
| **Profile** | Le modèle de rôle rattaché à un `User`. `Orm::User#profile` renvoie `student`, `teacher`, `team` ou `school_staff` selon le rôle. | `Orm::User#profile` |
| **Student** | Élève. Rattaché à une ou **plusieurs** classes via `ClassroomStudent` ([ADR-0003](../decisions/adr/0003-multi-appartenance-et-denormalisation-eleves.md)). Porte ses sessions, badges et lacunes. | `Orm::Student`, `Entities::Student` |
| **Teacher** | Enseignant. Rattaché à plusieurs classes (`TeacherClassroom`) et plusieurs établissements (`TeacherSchool`), et à une matière ([ADR-0004](../decisions/adr/0004-autorisation-multi-etablissements-enseignants.md)). | `Orm::Teacher`, `Entities::Teacher` |
| **Team** | Membre de l'équipe Lnclass : administrateur de la plateforme et producteur de contenu. C'est lui qui possède DRENA, niveaux, matières, écoles, exercices et messages. | `Orm::Team`, `Entities::Team` |
| **SchoolStaff** | **Personnel administratif d'un établissement.** Table de liaison `User` ⇄ `School` ⇄ `SchoolRole`. Unicité : un utilisateur ne peut être membre du staff d'une école qu'une fois. C'est le profil du rôle `school_admin`. | `Orm::SchoolStaff`, `Entities::SchoolStaff`, `Entities::Identity::SchoolStaff` |
| **school_admin** | La **valeur du rôle** sur `User` qui désigne un membre du staff d'établissement. Préfixe de `public_id` : `sadm_`. Ses écrans vivent dans `app/controllers/schoolstaff/` (espace de travail : classes, élèves, enseignants, profil, réglages) et `app/controllers/school_admins/registrations_controller.rb` (inscription). | `app/controllers/schoolstaff/`, `app/controllers/school_admins/` |
| **SchoolRole** | Rôle **dynamique** défini par un établissement pour son personnel (Proviseur, Éducateur, Censeur…). C'est une ligne en base, pas un `enum` : chaque école crée les siens. | `Orm::SchoolRole`, `Entities::SchoolRole` |
| **Parent** | Tuteur légal suivant la progression d'un élève. ⚠️ Le rôle existe dans l'`enum` (préfixe `prnt_`), **mais il n'y a ni table `parents`, ni `Orm::Parent`, ni entité.** `User#profile` renvoie `nil` pour ce rôle. Concept déclaré, non implémenté. | — |

> ⚠️ **Deux noms pour le même espace.** Le dossier de contrôleurs s'écrit `schoolstaff/` (sans underscore) tandis que l'inscription est dans `school_admins/`. Le modèle, lui, est `SchoolStaff`. C'est une incohérence de nommage réelle : ne la propage pas, mais ne la corrige pas non plus au milieu d'un autre chantier.

---

## 2. Organisation scolaire

Hiérarchie : **DRENA → School → Classroom → Student**.

| Terme | Définition | Code |
|---|---|---|
| **Drena** | Direction Régionale de l'Éducation Nationale et de l'Alphabétisation. Le plus haut niveau administratif : regroupe des établissements. | `Orm::Drena`, `Entities::Drena` |
| **School** | Établissement scolaire. Appartient à une DRENA. Statuts (`schoolstatus`) : `draft`, `active`, `inactive`. Types (`schooltype`) : `privée`, `public`, `mixte`. | `Orm::School`, `Entities::School` |
| **Classroom** | Classe : un groupe d'élèves dans une école, à un **niveau** et éventuellement dans une **série**. C'est l'unité de diffusion du contenu et des messages. | `Orm::Classroom`, `Entities::Classroom` |
| **Level** | Niveau académique : 6ème, 3ème, Terminale… Nom unique en base. | `Orm::Level`, `Entities::Catalog::Level` |
| **Series** | Série de spécialisation du second cycle : A1, C, D… Optionnelle sur une classe et sur un cours. | `Orm::Series`, `Entities::Catalog::Series` |
| **LevelSeries** | Table de jonction Level ⇄ Series : quelles séries existent à quel niveau. | `Orm::LevelSeries` |
| **ClassroomStudent** | Appartenance d'un élève à une classe. Porte le drapeau **`primary`** : un élève peut appartenir à plusieurs classes, une seule est sa classe principale ([ADR-0003](../decisions/adr/0003-multi-appartenance-et-denormalisation-eleves.md)). Porte aussi `joined_at`. | `Orm::ClassroomStudent` |
| **TeacherClassroom** | Intervention d'un enseignant dans une classe. C'est cette table que `ClassroomAccessPolicy` interroge pour autoriser. | `Orm::TeacherClassroom` |
| **TeacherSchool** | Rattachement d'un enseignant à un établissement. Un enseignant peut en avoir plusieurs ([ADR-0004](../decisions/adr/0004-autorisation-multi-etablissements-enseignants.md)). | `Orm::TeacherSchool` |

Modélisation tranchée par l'[ADR-0023](../decisions/adr/0023-modelisation-de-l-organisation-scolaire.md) *(ex-ADR-0015, renuméroté — les en-têtes HITL du code citent encore l'ancien numéro)*.

---

## 3. Contenu pédagogique

Hiérarchie : **Material → Course → Essential → Exercise → Question → Answer**.

| Terme | Définition | Code |
|---|---|---|
| **Material** | **Matière scolaire** : Mathématiques, Physique-Chimie, SVT… Attention au faux ami : `Material` ne veut pas dire « support » ni « ressource ». Porte un `shortname` et une `category`. | `Orm::Material`, `Entities::Catalog::Material` |
| **Course** | **Cours** : unité d'enseignement couvrant un chapitre. Appartient à une matière, un niveau et éventuellement une série. | `Orm::Course`, `Entities::Catalog::Course` |
| **Essential** | **Fiche essentielle** : le résumé des notions clés d'un cours. Appartient à un `Course`, porte les exercices et les lacunes. C'est l'unité de granularité de la remédiation. Ne jamais écrire `Lesson` ni `Sheet`. À l'écran : « Fiche essentielle » / « Fiches essentielles », jamais « Habileté » ni « Notions clés » ([UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md), proposée). | `Orm::Essential`, `Entities::Catalog::Essential` |
| **Exercise** | **Série de questions** rattachée à un `Essential`. Porte `exercise_type`, `published`, `questions_count`, `recurrence_rate` et `source_exam`. | `Orm::Exercise`, `Entities::Assessment::Exercise` |
| **Question** | Item d'évaluation d'un exercice (QCM, vrai/faux…). | `Orm::Question`, `Entities::Assessment::Question` |
| **Answer** | Réponse **possible** proposée pour une question, correcte ou non. À ne pas confondre avec `QuestionAttempt`, qui est la réponse **donnée** par un élève. | `Orm::Answer`, `Entities::Assessment::Answer` |
| **ExamSubject** | **Sujet d'examen** : annale officielle (BAC, BEPC) ou composition blanche. Attributs : `exam_category`, `exam_type`, `year`. ⚠️ L'entité existe (`app/domain/entities/exam_subject.rb`) et le type est accepté par `ClassroomAssignment`, **mais il n'y a ni table `exam_subjects` ni `Orm::ExamSubject`.** Concept modélisé côté domaine, non persisté. | `Entities::ExamSubject` |

Modélisation tranchée par l'[ADR-0022](../decisions/adr/0022-modelisation-hexagonale-du-catalogue-pedagogique.md) *(ex-ADR-0014, renuméroté)*. Les imports en masse suivent l'[ADR-0020](../decisions/adr/0020-optimisations-bulk-insert-donnees-catalogue.md).

---

## 4. Évaluation et gamification

Le cœur métier de la plateforme — [ADR-0008](../decisions/adr/0008-moteur-evaluation-et-gamification.md) et [ADR-0018](../decisions/adr/0018-remediation-just-in-time-et-historique-lacunes.md). Le parcours complet est tracé fichier par fichier dans [`architecture.md` §2](architecture.md#2-un-parcours-tracé-de-bout-en-bout).

| Terme | Définition |
|---|---|
| **ExerciseSession** | **Agrégat principal de l'évaluation.** Une tentative de réalisation d'un exercice par un élève. Porte les états `started` / `completed` / `abandoned`, le `score`, le `percentage`, et les règles de correction (`start!`, `submit_attempt!`, `calculate_score`, `success?` = `percentage >= 50`). Démarrer une nouvelle session marque les précédentes `abandoned`. `app/domain/entities/assessment/exercise_session.rb` |
| **QuestionAttempt** | Réponse **donnée** par l'élève à une question lors d'une session. Stocke la donnée brute dans `answer_data` (jsonb) et le verdict. `app/domain/entities/assessment/question_attempt.rb` |
| **ExerciseBadge** | Récompense décernée à la complétion d'un exercice. Trois paliers, définis dans `LEVELS` : `bronze` (≥ 50 %), `silver` (≥ 80 %), `gold` (100 %). La règle vit dans `ExerciseBadge.determine_level`, **pas dans le contrôleur**. Un badge existant n'est remplacé que s'il est amélioré (`upgrade_if_better`). `app/domain/entities/assessment/exercise_badge.rb` |
| **KnowledgeGap** | **Lacune de connaissance** constatée chez un élève sur un `Essential` donné. États : `pending`, `remediated`, `self_corrected`. Compte les échecs cumulés (`failed_attempts_count`) et pilote la remédiation *Just-In-Time* : la plateforme repropose la notion au bon moment plutôt qu'à la fin. Clé primaire de type `String`. `app/domain/entities/knowledge_gap.rb` |

Termes UI à ne pas mélanger : « session » (une session d'exercice) n'est pas la « session » de connexion, qu'on n'écrit jamais à l'écran (« Connexion », « Se déconnecter »). En français d'interface, on dit **« tentative »** pour `QuestionAttempt` et **« session »** (ou « session d'exercice ») pour `ExerciseSession` : un compteur de sessions ne s'intitule jamais « Tentatives ». Une réponse **possible** (`Answer`) s'appelle **« proposition »**. Les badges s'affichent « Bronze », « Argent », « Or » — « Diamant » n'existe pas. Référence : [UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (proposée).

---

## 5. Sécurité et assignation

| Terme | Définition |
|---|---|
| **ClassroomAccessPolicy** | Règle de domaine centralisée qui détermine si un **Teacher** a le droit d'agir sur une **Classroom**. Elle reçoit un `classroom_repo` par injection et répond à `authorized?(teacher_id:, classroom_id:)` en vérifiant l'intervention effective (`teacher_classrooms`). Elle est **dans le domaine**, jamais dans le contrôleur — c'est la seule policy du dépôt. `app/domain/policies/classroom_access_policy.rb`, [ADR-0004](../decisions/adr/0004-autorisation-multi-etablissements-enseignants.md) |
| **ClassroomAssignment** | **Entité polymorphique unique** représentant l'affectation d'une ressource pédagogique à une classe. `resource_type` accepte `Course`, `Essential`, `Exercise` et `ExamSubject`. Statuts : `added`, `active`, `validated`, `archived` — l'archivage remplace la suppression, l'historique est conservé ([ADR-0016](../decisions/adr/0016-conservation-historique-assignations.md)). Porte `assigned_by`. `Orm::ClassroomAssignment`, `Entities::ClassroomAssignment`, [ADR-0007](../decisions/adr/0007-hierarchie-pedagogique-et-assignations-polymorphes.md) |

Une seule table `classroom_assignments` remplace les anciennes `classroom_courses` / `classroom_essentials` / `classroom_exercises`. Les associations `Orm::Classroom#classroom_courses`, `#classroom_essentials` et `#classroom_exercises` existent encore, mais ce sont des **scopes sur `ClassroomAssignment`**, pas des modèles distincts.

> ⚠️ `Orm::ClassroomExercise` (la **classe**) n'existe pas et est pourtant appelée dans `app/infrastructure/queries/student_feed_query.rb` et `app/controllers/teachers/classroom_exercises_controller.rb`. Ces chemins lèvent `NameError`. Bug latent connu, cf. [`architecture.md` §7](architecture.md#7-écarts-connus-entre-cette-architecture-et-le-code).

---

## 6. Communication

| Terme | Définition |
|---|---|
| **Message** | Annonce diffusée par l'équipe Lnclass. Deux `enum` : **`audience`** (`all`, `students`, `teachers`, `teams`) et **`message_status`** (`draft`, `scheduled`, `published`, `archived`). Porte un `published_at` et un `slug` unique. `Orm::Message`, `Entities::Message` |

---

## 7. Identifiants — `public_id`, `slug`

### `public_id`

Identifiant public exposé dans les URLs et les échanges API, à la place de l'ID séquentiel. Sur `User` il est **préfixé par rôle** :

| Rôle | Préfixe |
|---|---|
| `team` | `team_` |
| `teacher` | `tch_` |
| `student` | `stdt_` |
| `parent` | `prnt_` |
| `school_admin` | `sadm_` |

`Orm::User#to_param` renvoie le `public_id` : les routes utilisateur l'utilisent automatiquement.

### ❌ Ce n'est plus un nanoid — et la macro porte un nom trompeur

La v1 du glossaire dit « `public_id` (nanoid) ». **C'est faux depuis l'[ADR-0017](../decisions/adr/0017-remplacement-nanoid-par-secure-random.md) (2026-08-21)** : la gem `nanoid` et le concern `PublicIdGenerator` ont été supprimés au profit de `SecureRandom.base58`, natif.

Voici exactement ce qui se passe dans le code. La macro **a gardé son ancien nom `has_nanoid`** tout en changeant d'implémentation — `app/models/application_record.rb` :

```ruby
def self.has_nanoid(field = :public_id)
  before_create do
    self.send("#{field}=", SecureRandom.base58(14)) if self.send(field).blank?
  end
end
```

Autrement dit : **le nom dit « nanoid », le code fait `SecureRandom.base58(14)`.** Pas de gem, pas de boucle de ré-essai, un simple `before_create`. L'alphabet base58 exclut les caractères ambigus (`0`/`O`, `1`/`I`/`l`), comme le faisait nanoid — d'où l'équivalence fonctionnelle et le nom conservé.

Où la macro est appelée : `Orm::Level`, `Orm::Series`, `Orm::Material`, `Orm::School`, `Orm::Drena`, `Orm::Classroom` (sur `public_id`), et `Orm::KnowledgeGap` (sur `:id`, d'où sa clé primaire `String`). `Orm::User` n'utilise pas la macro : il a son propre `before_create` pour gérer le préfixe de rôle.

> ⚠️ Les commentaires et en-têtes HITL de beaucoup de fichiers (`app/domain/entities/user.rb`, `school.rb`, `drena.rb`, `level.rb`, `series.rb`, `knowledge_gap.rb`, `app/infrastructure/orm/knowledge_gap.rb`…) décrivent encore ces identifiants comme des « nanoid ». C'est un vestige lexical, pas une dépendance : **il n'y a plus de nanoid dans le projet.** Ne t'en sers pas comme preuve. Renommer `has_nanoid` demanderait un chantier à part.

### `slug`

Identifiant lisible dérivé d'un nom, pour les URLs. Deux mécanismes coexistent :

- **`friendly_id`** — `app/models/concerns/sluggable.rb` (`friendly_id :name, use: :slugged`) et `Orm::User` (`friendly_id :fullname`). Table `friendly_id_slugs`, config dans `config/initializers/friendly_id.rb`.
- **Slug aléatoire** — `Orm::ExerciseSession` et `Orm::ExerciseBadge` génèrent `SecureRandom.base58(21)` quand le slug est vide : il n'y a pas de nom à sluguer, seulement un besoin d'URL non devinable.

---

## 8. Mots à ne jamais employer

| N'écris pas | Écris |
|---|---|
| `Lesson`, `Sheet`, `Fiche` | `Essential` |
| `Subject`, `Matiere`, `Discipline` | `Material` (matière) |
| `Quiz`, `Test` | `Exercise` |
| `Attempt` tout court | `QuestionAttempt` ou `ExerciseSession`, selon la granularité |
| `Admin` tout court | `Team` (équipe Lnclass) ou `SchoolStaff` / `school_admin` (établissement) — ce ne sont pas les mêmes gens |
| `Grade`, `Class` | `Level` (niveau) et `Classroom` (classe) |
| `ClassroomCourse`, `ClassroomEssential`, `ClassroomExercise` | `ClassroomAssignment` |
| `presenter`, `validator` | Ces couches n'existent pas — voir [`architecture.md` §1](architecture.md#1-les-quatre-couches-et-le-sens-des-dépendances) |

**À l'écran** ([UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md), proposée) :

| N'affiche pas | Affiche |
|---|---|
| « Habileté », « Habiletés », « Notion(s) clé(s) », « Essentiel » | « Fiche essentielle » |
| « Quiz », « Test », « Flashcard » | « Exercice » |
| « Tentatives » pour compter des sessions | « Sessions » |
| « Diamant » | « Bronze », « Argent », « Or » |
| « Conforme au programme » | rien : aucun label de conformité ([ADR-0053](../decisions/adr/0053-validation-collaborative-requalifiee.md), proposé) |

---

## 9. Où aller ensuite

| Tu veux | Ouvre |
|---|---|
| Voir ces concepts traverser les couches | [`architecture.md`](architecture.md) |
| Le nommage des fichiers et namespaces | [`conventions.md`](conventions.md) |
| Pourquoi un modèle est comme ça | [`../decisions/adr/`](../decisions/adr/) |
| Le vocabulaire d'interface | [`../decisions/udr/`](../decisions/udr/) |
