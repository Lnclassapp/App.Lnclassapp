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

Le rôle est la colonne `users.role`, une `string` fermée par une contrainte `CHECK` ([ADR-0038](../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md), [ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md)) :

```ruby
add_check_constraint :users, "role IN ('student','teacher','school_admin','team')", name: "users_role_values"
```

Un compte `team` porte en plus un **sous-rôle** `team_role` : `admin`, `content` ou `field` ([ADR-0038](../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md)). Le rôle `parent` n'existe pas. L'ancien dépôt déclare encore un `enum` entier avec `parent: 3` (`app/infrastructure/orm/user.rb`) : ne le reproduis pas.

| Terme | Définition | Où c'est dans le code |
|---|---|---|
| **User** | Compte de connexion. Identifié par son **contact** (numéro de téléphone à 10 chiffres, normalisé, [ADR-0050](../decisions/adr/0050-authentification-et-session.md)), pas par un email. Porte le rôle, le `public_id`, `last_name` et `first_name` ([ADR-0037](../decisions/adr/0037-nom-et-prenoms-en-deux-champs.md)). Code secret à 4 chiffres (« code secret » dans l'interface, `pin` dans le code) via `has_secure_password` ([ADR-0025](../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md)). Toute personne est référencée par `users.id` ([ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md)). | `Orm::User`, `Entities::Identity::User` |
| **Profile** | Le modèle de rôle rattaché à un `User`. `Orm::User#profile` renvoie `student`, `teacher`, `team` ou `school_staff` selon le rôle. | `Orm::User#profile` |
| **Student** | Élève. Rattaché à ses classes via `ClassroomStudent`, avec **une seule classe principale active**, et une seule classe active jusqu'à la V3 ([ADR-0040](../decisions/adr/0040-classe-principale-unique-de-l-eleve.md)). Porte ses sessions, badges et lacunes. | `Orm::Student`, `Entities::Student` |
| **Teacher** | Enseignant. Rattaché à **une** école principale en V1 (`TeacherSchool`), il y déclare lui-même ses classes (`TeacherClassroom`) ; il ne crée pas de classe ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)). | `Orm::Teacher`, `Entities::Teacher` |
| **Team** | Membre de l'équipe Lnclass : administrateur de la plateforme et producteur de contenu. Créé **uniquement par invitation**, avec un `team_role` et un second facteur TOTP obligatoire ([ADR-0038](../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md), [ADR-0031](../decisions/adr/0031-second-facteur-totp-pour-l-equipe.md)). Il administre la taxonomie, les DRENA, les écoles et les classes ; le contenu appartient à la plateforme, son auteur n'est qu'une trace ([ADR-0035](../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md)). | `Orm::Team`, `Entities::Team` |
| **SchoolStaff** | **Personnel de direction d'un établissement.** Table de liaison `User` ⇄ `School`, avec une **fonction** (`position`). Rattaché **par invitation** seulement, à une seule école, avec un second facteur TOTP ([ADR-0044](../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md)). C'est le profil du rôle `school_admin`. | `Orm::SchoolStaff`, `Entities::SchoolStaff`, `Entities::Identity::SchoolStaff` |
| **school_admin** | La **valeur du rôle** sur `User` qui désigne un membre de la direction d'un établissement. Dans l'ancien dépôt, ses écrans vivent dans `app/controllers/schoolstaff/` (espace de travail : classes, élèves, enseignants, profil, réglages) et `app/controllers/school_admins/registrations_controller.rb` (inscription). | `app/controllers/schoolstaff/`, `app/controllers/school_admins/` |
| **Position** | **Fonction** d'un membre de la direction, dans une liste fermée : `principal` (Proviseur), `censor` (Censeur), `educator` (Éducateur), `secretary` (Secrétaire). Un seul proviseur actif par école. Remplace les `SchoolRole` libres de l'ancien dépôt ([ADR-0044](../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md)). | `school_staffs.position` |

> ⚠️ **Deux noms pour le même espace.** Le dossier de contrôleurs s'écrit `schoolstaff/` (sans underscore) tandis que l'inscription est dans `school_admins/`. Le modèle, lui, est `SchoolStaff`. C'est une incohérence de nommage réelle : ne la propage pas, mais ne la corrige pas non plus au milieu d'un autre chantier.

---

## 2. Organisation scolaire

Hiérarchie : **DRENA → School → Classroom → Student**.

| Terme | Définition | Code |
|---|---|---|
| **Drena** | Direction Régionale de l'Éducation Nationale et de l'Alphabétisation. Le plus haut niveau administratif : regroupe des établissements. Contexte `school`, créée par l'équipe dès la V1, jamais seedée en production ([ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md), [ADR-0034](../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md)). | `Orm::Drena`, `Entities::Drena` |
| **School** | Établissement scolaire. Appartient à une DRENA. Créé par l'équipe, à l'écran ou par import JSON ([ADR-0039](../decisions/adr/0039-format-d-import-du-contenu.md)). Statuts (`status`) : `draft`, `active`, `inactive`. Types (`school_type`) : `public`, `private`, `mixed` (Public, Privé, Mixte ; un établissement mixte suit le barème de classes du privé). Cycle (`cycle`) : `first` (collège) ou `both`. Ses classes par défaut sont générées à sa création ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)). | `Orm::School`, `Entities::School` |
| **Code d'établissement** (`school_code`) | Code de 6 caractères (lettres sans I ni O, chiffres de 2 à 9), affiché `K7M-4QZ`, unique par établissement. L'enseignant le saisit à l'inscription, ou ouvre le lien `/e/<code>` : c'est lui qui désigne son établissement. Transmis et régénéré par l'équipe depuis la fiche de l'établissement ; distinct du code d'adhésion d'une classe (5 caractères) ([ADR-0057](../decisions/adr/0057-code-d-etablissement.md)). | `Entities::School::SchoolCode` |
| **Classroom** | Classe : un groupe d'élèves dans une école, à un **niveau** et éventuellement dans une **série**, pour une **année scolaire** (`school_year`). Statut `active` ou `archived` ; code d'adhésion révocable et régénérable ; plafond `max_students` ([ADR-0041](../decisions/adr/0041-vie-d-une-classe-annee-scolaire-et-code.md)). Créée par l'équipe en V1, par la direction ensuite ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)). C'est l'unité de diffusion du contenu et des messages. | `Orm::Classroom`, `Entities::Classroom` |
| **Level** | Niveau académique : `6ème`… `3ème`, `2nde`, `1ère`, `Tle`. Nom unique en base. Créé par l'équipe dans l'interface ([ADR-0034](../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md)). | `Orm::Level`, `Entities::Catalog::Level` |
| **Series** | Série de spécialisation du second cycle : A1, C, D… Optionnelle sur une classe et sur un cours. | `Orm::Series`, `Entities::Catalog::Series` |
| **LevelSeries** | Table de jonction Level ⇄ Series : quelles séries existent à quel niveau. | `Orm::LevelSeries` |
| **ClassroomStudent** | Appartenance d'un élève à une classe. Porte le drapeau **`primary`** : un index partiel garantit **une seule** classe principale active par élève ([ADR-0040](../decisions/adr/0040-classe-principale-unique-de-l-eleve.md)). Porte aussi `joined_at`. | `Orm::ClassroomStudent` |
| **TeacherClassroom** | Intervention d'un enseignant dans une classe, déclarée par l'enseignant lui-même dans son école ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)). C'est cette table que les policies du contexte `classroom` interrogent ([ADR-0028](../decisions/adr/0028-policies-de-domaine-par-use-case.md)). | `Orm::TeacherClassroom` |
| **TeacherSchool** | Rattachement d'un enseignant à un établissement, avec un drapeau **`primary`**. Une seule ligne en V1, garantie par index partiel ; d'autres écoles à partir de la V3, sans migration ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)). | `Orm::TeacherSchool` |

Contexte `school` (DRENA, écoles, direction) et `classroom` (classes, adhésions, enseignement, assignations) : [ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md), qui remplace l'[ADR-0023](../decisions/adr/0023-modelisation-de-l-organisation-scolaire.md).

---

## 3. Contenu pédagogique

Hiérarchie : **Material → Course → Essential → Exercise → Question → Answer**.

| Terme | Définition | Code |
|---|---|---|
| **Material** | **Matière scolaire** : Mathématiques, Physique-Chimie, SVT… Attention au faux ami : `Material` ne veut pas dire « support » ni « ressource ». Porte un `shortname` et une `category` **obligatoire** (`literature`, `science`, `other`), qui fixe sa couleur. Créée par l'équipe ([ADR-0034](../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md)). | `Orm::Material`, `Entities::Catalog::Material` |
| **Course** | **Cours** : unité d'enseignement couvrant un chapitre. Appartient à une matière, un niveau et éventuellement une série. | `Orm::Course`, `Entities::Catalog::Course` |
| **Essential** | **Fiche essentielle** : le résumé des notions clés d'un cours. Appartient à un `Course`, porte les exercices et les lacunes. C'est l'unité de granularité de la remédiation. Ne jamais écrire `Lesson` ni `Sheet`. À l'écran : « Fiche essentielle » / « Fiches essentielles », jamais « Habileté » ni « Notions clés » ([UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md)). | `Orm::Essential`, `Entities::Catalog::Essential` |
| **Exercise** | **Série de questions** rattachée à un `Essential` (`essential_id` obligatoire, [ADR-0054](../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md)). Cycle de vie `draft` / `published` / `archived`, comme le cours et la fiche ([ADR-0035](../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md)). Exposé par `public_id`, pas par slug ([ADR-0029](../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md)). | `Orm::Exercise`, `Entities::Assessment::Exercise` |
| **Question** | Item d'évaluation d'un exercice (QCM, vrai/faux…). | `Orm::Question`, `Entities::Assessment::Question` |
| **Answer** | Réponse **possible** proposée pour une question, correcte ou non. À ne pas confondre avec `QuestionAttempt`, qui est la réponse **donnée** par un élève. | `Orm::Answer`, `Entities::Assessment::Answer` |

Modélisation métier : [ADR-0022](../decisions/adr/0022-modelisation-hexagonale-du-catalogue-pedagogique.md), avec le contrat de l'[ADR-0026](../decisions/adr/0026-contrat-result-entites-et-dto.md) et le cycle de vie de l'[ADR-0035](../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md). Les imports en masse suivent l'[ADR-0039](../decisions/adr/0039-format-d-import-du-contenu.md). `ExamSubject` (sujet d'examen) est retiré du plan : ne le déclare nulle part.

---

## 4. Évaluation et gamification

Le cœur métier de la plateforme — [ADR-0054](../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md) (moteur), [ADR-0033](../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (badges et seuils) et [ADR-0043](../decisions/adr/0043-remediation-declenchee-par-la-cloture.md) (remédiation). Le parcours complet est tracé fichier par fichier dans [`architecture.md` §2](architecture.md#2-un-parcours-tracé-de-bout-en-bout).

| Terme | Définition |
|---|---|
| **ExerciseSession** | **Agrégat principal de l'évaluation.** Une réalisation d'un exercice par un élève. États `started` / `completed` / `abandoned` ; une seule session `started` par élève et exercice. `progress_percent` mesure l'avancement, `score_percent` n'est posé qu'à la clôture ([ADR-0033](../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)). `kind` vaut `standard` ou `remediation` ([ADR-0043](../decisions/adr/0043-remediation-declenchee-par-la-cloture.md)). Seul `Assessment::CloseExerciseSession` passe une session à `completed` et décide du score, du badge et de la lacune ([ADR-0054](../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md)). « Recommencer » abandonne la session ouverte. |
| **QuestionAttempt** | Réponse **donnée** par l'élève à une question lors d'une session : **une seule par question et par session, immuable**. Stocke les propositions choisies dans `selected_answer_ids` (`bigint[]`) et le verdict `correct`, calculé par identifiants ([ADR-0054](../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md)). |
| **ExerciseBadge** | Récompense décernée à la clôture d'une session. Quatre paliers : `bronze` (≥ 50 %, `PASS_THRESHOLD`), `silver` (≥ 70 %, `MASTERY_THRESHOLD`), `gold` (≥ 80 %, `GOLD_THRESHOLD`), `diamond` (100 %, `PERFECT_THRESHOLD`, le sans-faute). Un badge par élève et par exercice, qui ne monte que vers un palier **strictement** supérieur. Les seuils vivent dans `Entities::Assessment::Grading` ([ADR-0033](../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)). |
| **KnowledgeGap** | **Lacune de connaissance** constatée chez un élève sur un `Essential` donné. États : `pending`, `remediated`, `self_corrected` ; **une seule lacune `pending`** par élève et par fiche (index partiel). Ouverte et résolue par la seule clôture d'une session ; la session de remédiation est générée au clic (*just-in-time*). Clé `bigint`, comme toutes les tables ([ADR-0043](../decisions/adr/0043-remediation-declenchee-par-la-cloture.md), [ADR-0029](../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md)). `Entities::Assessment::KnowledgeGap` |

Termes UI à ne pas mélanger : « session » (une session d'exercice) n'est pas la « session » de connexion, qu'on n'écrit jamais à l'écran (« Connexion », « Se déconnecter »). En français d'interface, on dit **« tentative »** pour `QuestionAttempt` et **« session »** (ou « session d'exercice ») pour `ExerciseSession` : un compteur de sessions ne s'intitule jamais « Tentatives ». Une réponse **possible** (`Answer`) s'appelle **« proposition »**. Les badges s'affichent « Bronze », « Argent », « Or » et « Diamant » (le sans-faute). Référence : [UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md).

---

## 5. Sécurité et assignation

| Terme | Définition |
|---|---|
| **Policy** | Règle d'autorisation pure, **une par use case**, appelée avant toute écriture : `Policies::<Contexte>::<Nom>Policy#call(actor:, **faits)` renvoie un `Shared::Result`, refus en `:forbidden` (ou `:not_found` pour une lecture). L'acteur est un `Entities::Identity::Actor` ; `nil` pour un visiteur anonyme ([ADR-0028](../decisions/adr/0028-policies-de-domaine-par-use-case.md)). Dans l'ancien dépôt, `ClassroomAccessPolicy` était la seule policy. |
| **ClassroomAssignment** | **Entité polymorphique unique** représentant l'affectation d'une ressource pédagogique à une classe. Seul l'**exercice** s'assigne depuis le 2026-10-02 (`Exercise` ; cours et fiches ne s'assignent plus, [ADR-0072](../decisions/adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md)). Porte son **échéance** (`due_on`). **Deux statuts** : `active` et `archived` ; une réassignation crée une nouvelle ligne, et une session d'exercice est rattachée à son assignation. `assigned_by_id` référence `users` ([ADR-0048](../decisions/adr/0048-statuts-d-assignation-active-et-archived.md)). `Entities::Classroom::ClassroomAssignment` |
| **Jours de séance** (`ClassroomSessionDay`) | Jours de la semaine (lundi à samedi) où un enseignant voit une classe, déclarés par lui pour chaque classe qu'il enseigne ; aucune heure. Aucune ligne = « non renseignés » ([ADR-0072](../decisions/adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md)). | `classroom_session_days`, `Entities::Classroom::SessionDays` |
| **Échéance** (date limite) | Date pour laquelle un exercice assigné est à faire : le prochain jour de séance de l'auteur, strictement après la date de l'assignation, calculée et figée à l'assignation ; absente sans jours de séance. À l'écran : « À rendre demain », « Pour jeu. 8 oct. ». | `classroom_assignments.due_on` |
| **Rendu en retard** | Exercice dont la première session terminée (standard ou de remédiation, rattachée à l'assignation : [ADR-0079](../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) §4.1) date d'après l'échéance. Lu, jamais stocké ; rien ne se ferme après l'échéance. Pour l'élève : « En retard » tant qu'il ne l'a pas terminé après l'échéance. | `Queries::Classroom::AssignmentFollowUpQuery` |

Une seule table `classroom_assignments` remplace les anciennes `classroom_courses` / `classroom_essentials` / `classroom_exercises`. Les associations `Orm::Classroom#classroom_courses`, `#classroom_essentials` et `#classroom_exercises` existent encore, mais ce sont des **scopes sur `ClassroomAssignment`**, pas des modèles distincts.

> ⚠️ `Orm::ClassroomExercise` (la **classe**) n'existe pas et est pourtant appelée dans `app/infrastructure/queries/student_feed_query.rb` et `app/controllers/teachers/classroom_exercises_controller.rb`. Ces chemins lèvent `NameError`. Bug latent connu, cf. [`architecture.md` §7](architecture.md#7-écarts-connus-entre-cette-architecture-et-le-code).

---

## 6. Communication

| Terme | Définition |
|---|---|
| **Message** | Annonce diffusée par l'équipe (nationale ou pour une école) ou par une direction (pour son école). **`audience`** : `all`, `students`, `teachers`, `school_admins` ; pas d'audience `teams`, l'équipe voit tout. **`status`** : `draft`, `scheduled`, `published`, `archived` ; un job publie les annonces programmées. L'audience est filtrée à la lecture, y compris par l'URL ([ADR-0045](../decisions/adr/0045-annonces-publication-programmee-et-audience.md)). `Entities::Communication::Message` |
| **Article** | Texte public du **blog** (`/blog`), écrit par l'équipe Administration et Contenu, lisible sans compte, partageable et indexé. Texte riche illustré, adressé par un **slug figé** (`/blog/:slug`) ; cycle des contenus `draft` → `published` → `archived` → `published` (`ContentStatus`), « remettre en ligne » garde la date d'origine ; un archivé répond 410 ; jamais supprimé. Signé « L'équipe Lnclass » ou du nom de son auteur. Compteur de lectures brut, sans dédoublonnage, vu de l'équipe seule ([ADR-0074](../decisions/adr/0074-blog-public-articles-images-et-referencement.md)). `Entities::Communication::Article` |
| **Image d'article** | Couverture ou image du texte d'un article : JPEG, PNG ou WebP fixe, 1 Mo et 1600 px de côté au plus, sans métadonnées, 10 dans le texte au plus. Son **texte de remplacement** (jamais « alt » à l'écran) est exigé pour publier. Servie par Lnclass à `/blog/images/:public_id`. `Entities::Communication::ArticleImage` |
| ❌ **Article ≠ annonce** | Un **article** est public, sans audience ni établissement, ni programmation, adressé par slug. Une **annonce** (`Message`) est connectée, ciblée par audience et établissement, en texte simple, programmable, adressée par `public_id`. Deux tables, deux jeux de use cases ; aucun ne lit l'autre. À l'écran, jamais « post » ni « billet ». |

---

## 7. Identifiants — `public_id`, `slug`

### `public_id`

Identifiant public exposé dans les URLs, à la place de l'ID séquentiel : `SecureRandom.base58(14)`, **sans préfixe**, index unique et un nouvel essai en cas de collision. Aucune route n'expose `:id`. Les clés internes restent en `bigint` ([ADR-0029](../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md)).

L'ancien dépôt préfixait le `public_id` de `User` par rôle (`team_`, `tch_`, `stdt_`, `prnt_`, `sadm_`) : ce préfixe révélait le rôle et disparaît.

### ❌ Ce n'est plus un nanoid — et la macro porte un nom trompeur (ancien dépôt)

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

Identifiant lisible dérivé d'un nom, **réservé au catalogue et au blog** : niveaux, séries, matières, cours, fiches essentielles et articles du blog (adresse publique `/blog/:slug`, [ADR-0074](../decisions/adr/0074-blog-public-articles-images-et-referencement.md)). Dérivé par `parameterize`, suffixé `-2`, `-3`… en cas de collision, puis **figé à la création** : renommer ne casse aucun lien. `friendly_id` n'est pas repris ([ADR-0029](../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md)). Un compte n'a jamais de slug ([ADR-0037](../decisions/adr/0037-nom-et-prenoms-en-deux-champs.md)) ; une session ou un badge prend un `public_id`.

L'ancien dépôt mêle `friendly_id` (y compris sur `Orm::User`) et des slugs aléatoires de 21 caractères sur les sessions et les badges : ne les reproduis pas.

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

**À l'écran** ([UDR-0007](../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md)) :

| N'affiche pas | Affiche |
|---|---|
| « Habileté », « Habiletés », « Notion(s) clé(s) », « Essentiel » | « Fiche essentielle » |
| « Quiz », « Test », « Flashcard » | « Exercice » |
| « Tentatives » pour compter des sessions | « Sessions » |
| « Conforme au programme » | rien : aucun label de conformité ([ADR-0053](../decisions/adr/0053-validation-collaborative-requalifiee.md)) |

---

## 9. Où aller ensuite

| Tu veux | Ouvre |
|---|---|
| Voir ces concepts traverser les couches | [`architecture.md`](architecture.md) |
| Le nommage des fichiers et namespaces | [`conventions.md`](conventions.md) |
| Pourquoi un modèle est comme ça | [`../decisions/adr/`](../decisions/adr/) |
| Le vocabulaire d'interface | [`../decisions/udr/`](../decisions/udr/) |
