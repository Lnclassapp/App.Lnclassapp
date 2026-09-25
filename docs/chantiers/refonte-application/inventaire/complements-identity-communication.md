# Compléments d'inventaire — `identity` + `communication`

> **Mission n° 1** du brief [`prompt-exploration.md`](../prompt-exploration.md) (partie 3).
> **Vérifie et complète** [`identity-communication.md`](identity-communication.md) — ne le remplace pas.
>
> | | |
> |---|---|
> | **Date** | 2026-09-22 |
> | **Commit inspecté** | `684ae16` (branche `Teamprocess`, identique à `Develop` : `git rev-list --count` = 0 dans les deux sens) |
> | **Branches non fusionnées lues** | `feature/ticket-4-auth` (6 commits hors `HEAD`), `feature/ticket-4-auth-dashboard` (7 commits hors `HEAD`) |
> | **Décisions confrontées** | ADR-0002, ADR-0005, ADR-0017, ADR-0021, ADR-0025 · UDR-0004 |
> | **Méthode** | lecture du code appelant, suivi des routes, des `before_action`, des clés de paramètres ; un seul appel à l'exécution, en lecture : `bin/rails runner` pour lire `model_name.param_key` de `Orm::User`, `Entities::User`, `Orm::Message` et vérifier l'absence de la colonne `users.email` |
>
> Légende des états : ✅ fonctionne · ⚠️ fonctionne avec réserves · ❌ cassé ou absent · 💀 code présent, jamais exécuté.
> Les chemins sont relatifs à la racine du dépôt ; `chemin:ligne` renvoie à `HEAD` sauf mention d'une branche.

---

## 1. Catalogue des features

### 1.1 Identity

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| ID-01 | S'inscrire comme élève (code de classe ou choix manuel de la classe) | Élève | ⚠️ | `users`, `students`, `classroom_students` | `GET /student-signup`, `POST /student-signup` | `inventaire/identity-communication.md#inscription-dun-élève-formulaire-public` |
| ID-02 | S'inscrire comme élève par le lien de classe `/c/<code>` | Élève | ⚠️ | `users`, `students`, `classroom_students` | `GET /c/:unique_code`, `POST /c/:unique_code` | `inventaire/identity-communication.md#inscription-dun-élève-via-lien-de-classe--prepa-` |
| ID-03 | S'inscrire comme enseignant | Enseignant | ⚠️ | `users`, `teachers`, `teacher_schools` | `GET /teacher-signup`, `POST /teacher-signup` | `inventaire/identity-communication.md#inscription-dun-enseignant` |
| ID-04 | S'inscrire comme membre de l'équipe Lnclass | N'importe qui | ❌ | `users`, `teams` | `GET /team-signup`, `POST /team-signup` | `inventaire/identity-communication.md#inscription-dun-membre-de-léquipe-lnclass` |
| ID-05 | S'inscrire comme administrateur d'établissement | N'importe qui | ❌ | `users`, `school_staffs`, `school_roles` | `GET /staff-signup`, `POST /staff-signup` | `inventaire/identity-communication.md#inscription-dun-administrateur-détablissement` |
| ID-06 | S'inscrire comme enseignant depuis la page d'acquisition « Prépa BAC », puis voir la ressource promise | Enseignant prospect (public) | ❌ | `users`, `teachers`, `teacher_schools` | `GET /teachers/prepa_acquisitions/new`, `POST /teachers/prepa_acquisitions`, `GET /teachers/prepa_acquisitions/download` | nouveau |
| ID-07 | Vérifier en direct un code de classe pendant l'inscription | Visiteur anonyme | ⚠️ | `classrooms`, `schools`, `levels`, `series` (lecture) | `GET /api/v1/classrooms/lookup` | nouveau |
| ID-08 | Charger les écoles d'une DRENA et les classes d'un niveau dans une école (listes en cascade) | Visiteur anonyme | ✅ | `schools`, `classrooms`, `series` (lecture) | `GET /api/v1/schools`, `GET /api/v1/classrooms` | nouveau (l'inventaire cite l'appel, pas la feature) |
| ID-09 | Rattacher un enseignant existant à son établissement | `school_admin` | ⚠️ | `teacher_schools` | `GET /schoolstaff/teachers/new`, `POST /schoolstaff/teachers` | `inventaire/identity-communication.md#rattachement-dun-enseignant-existant-à-un-second-établissement` |
| ID-10 | Rattacher un élève existant à une classe de l'établissement | `school_admin` | ⚠️ | `classroom_students` | `GET /schoolstaff/students/new`, `POST /schoolstaff/students` | `inventaire/identity-communication.md#rattachement-dun-élève-existant-à-une-classe-par-la-direction` |
| ID-11 | Lister les enseignants et les élèves de l'établissement | `school_admin` | ⚠️ | `teacher_schools`, `classroom_students`, `users` | `GET /schoolstaff/teachers`, `GET /schoolstaff/students` | `inventaire/identity-communication.md#consultation-des-élèves-et-enseignants-de-létablissement` |
| ID-12 | Se connecter avec son numéro et son code secret | Tous | ⚠️ | `users` | `GET /login`, `POST /login` | `inventaire/identity-communication.md#connexion` |
| ID-13 | Être dirigé vers son espace (après connexion, ou en arrivant sur `/` déjà connecté) | Tous | ⚠️ | `users`, `teacher_classrooms` | `GET /` | `inventaire/identity-communication.md#connexion` (table de redirection) |
| ID-14 | Se déconnecter | Tous | ⚠️ | — (session) | `DELETE /logout` | `inventaire/identity-communication.md#déconnexion` |
| ID-15 | Récupérer un code secret oublié | Tous | ❌ absent | — | — | `inventaire/identity-communication.md#mot-de-passe-oublié--réinitialisation` |
| ID-16 | Restreindre chaque espace à son rôle (gardes et helpers de rôle) | Système | ⚠️ | `users` | toutes | `inventaire/identity-communication.md#contexte-identity--autorisation` |
| ID-17 | Modifier son profil depuis `/profile` (nom, contact, genre, code secret) | Tous | ⚠️ | `users` | `GET /profile/edit`, `PATCH /profile`, `PUT /profile` | `inventaire/identity-communication.md#a-profileedit--patch-profile-profilescontroller` |
| ID-18 | Modifier une fiche utilisateur depuis `/users/<public_id>/edit` | `team` ou le titulaire | ❌ | `users` | `GET /users/:public_id/edit`, `PATCH /users/:public_id`, `PUT /users/:public_id` | `inventaire/identity-communication.md#b-userspublic_idedit--patch-userspublic_id-identityuserscontroller` |
| ID-19 | Consulter et modifier son profil de direction (dont l'avatar) | `school_admin` | ❌ | `users`, `active_storage_*` | `GET /schoolstaff/profile`, `GET /schoolstaff/profile/edit`, `PATCH /schoolstaff/profile`, `PUT /schoolstaff/profile` | `inventaire/identity-communication.md#c-schoolstaffprofile-et-schoolstaffsettings` |
| ID-20 | Changer son code secret depuis les réglages de direction | `school_admin` | ❌ | `users` | `GET /schoolstaff/settings`, `PATCH /schoolstaff/settings`, `PUT /schoolstaff/settings` ; `GET /schoolstaff/settings/edit` 💀 | `inventaire/identity-communication.md#c-schoolstaffprofile-et-schoolstaffsettings` |
| ID-21 | Lister tous les utilisateurs de la plateforme | `team` | ⚠️ | `users` | `GET /users` | `inventaire/identity-communication.md#annuaire-et-suppression-des-utilisateurs` |
| ID-22 | Consulter la fiche d'un utilisateur | Tout connecté | ⚠️ | `users` | `GET /users/:public_id` | `inventaire/identity-communication.md#annuaire-et-suppression-des-utilisateurs` |
| ID-23 | Supprimer un utilisateur et ses données | `team` | ⚠️ | `users` + cascade `students`, `teachers`, `teams`, `school_staffs`, `exercise_sessions`, `exercise_badges`, `knowledge_gaps`, `classroom_students`, `teacher_schools`, `teacher_classrooms` | `DELETE /users/:public_id` | `inventaire/identity-communication.md#annuaire-et-suppression-des-utilisateurs` |
| ID-24 | Changer de rôle | — | ❌ absent | — | — | `inventaire/identity-communication.md#changement-de-rôle` |
| ID-25 | Accéder à un espace parent | Parent | ❌ absent (rôle déclaré seul) | `users` (`role = 3`) | — | `inventaire/identity-communication.md#le-rôle-parent` |
| ID-26 | Proposer, reporter ou marquer comme installée l'application (bannière PWA) | Tout connecté sur mobile | ⚠️ (corrigé, était ✅) | `users.install_banner_status`, `users.install_banner_last_changed_at` | `PATCH /install_banner` | `inventaire/identity-communication.md#bannière-dinstallation-pwa` |
| ID-27 | Enseigner dans plusieurs établissements | Enseignant | ⚠️ | `teacher_schools` | — | `inventaire/identity-communication.md#multi-établissements-pour-les-enseignants-adr-0004` |
| ID-28 | Normaliser et valider le numéro de contact | Système | ⚠️ | `users.contact` | — | `inventaire/identity-communication.md#format-du-contact-téléphonique-adr-0002` |
| ID-29 | Générer l'identifiant public et le slug d'un utilisateur | Système | ⚠️ | `users.public_id`, `users.slug`, `friendly_id_slugs` | — | `inventaire/identity-communication.md#2-règles-métier-implicites-à-rendre-explicites` (n° 5, 6, 21) |
| ID-30 | Créer des comptes élèves de démonstration qui occupent des numéros de téléphone | Système (job de démo) | ⚠️ | `users` (`is_demo`), `students` (`matricule`) | — | nouveau (côté identity ; le parcours relève de la mission 2) |
| ID-31 | Refonte visuelle des pages de connexion et d'inscription | Tous | ⚠️ non fusionné | — | `GET /login`, `GET /student-signup`, `GET /teacher-signup`, `GET /team-signup`, `GET /staff-signup` | nouveau (branche `feature/ticket-4-auth`) |
| ID-32 | Délégation « au vol » des méthodes métier des modèles ORM vers les entités `Entities::Identity::*` | Système | ❌ non fusionné, cassé | `users`, `students`, `teachers`, `teams` | — | nouveau (branche `feature/ticket-4-auth`) |
| ID-33 | Plan « Ticket 4 — Authentification & rôles » | Équipe | ❌ jamais livré | — | — | nouveau (branche `feature/ticket-4-auth`, `docs/tickets/TICKET-4-auth.md`) |
| ID-34 | Afficher l'en-tête et le tableau des examens sur le fil équipe | `team` | ⚠️ non fusionné | lecture catalogue | `GET /teams` | nouveau (branche `feature/ticket-4-auth-dashboard`) — à rattacher aussi à la mission 5 (`TR`) |

### 1.2 Communication

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| CO-01 | Publier une annonce (titre, texte riche, image, audio, audience, statut, date) | `team` | ⚠️ | `messages`, `action_text_rich_texts`, `active_storage_attachments`, `active_storage_blobs`, `active_storage_variant_records`, `friendly_id_slugs` | `GET /messages/new`, `POST /messages` | `inventaire/identity-communication.md#publication-dune-annonce` |
| CO-02 | Modifier une annonce | `team` | ⚠️ | idem CO-01 | `GET /messages/:id/edit`, `PATCH /messages/:id`, `PUT /messages/:id` | `inventaire/identity-communication.md#modification-dune-annonce` |
| CO-03 | Supprimer une annonce | `team` | ⚠️ | idem CO-01 | `DELETE /messages/:id` | `inventaire/identity-communication.md#suppression-dune-annonce` |
| CO-04 | Parcourir les annonces qui me sont destinées | Tout connecté | ⚠️ | `messages` | `GET /messages` | `inventaire/identity-communication.md#consultation-des-annonces` |
| CO-05 | Lire le détail d'une annonce | Tout connecté | ⚠️ | `messages` | `GET /messages/:id` | nouveau (l'inventaire ne la cite qu'en faille n° 14) |
| CO-06 | Voir les annonces récentes dans son fil (élève, enseignant, équipe) | Élève, enseignant, `team` | ⚠️ | `messages` | `GET /students`, `GET /teachers`, `GET /teams` | `inventaire/identity-communication.md#annonces-dans-les-fils-dactualité-feeds` |
| CO-07 | Écarter une annonce de la page des annonces | Tout connecté | ⚠️ | — (cookie de session) | `DELETE /messages/:id/dismiss` | `inventaire/identity-communication.md#écarter-une-annonce-de-son-fil` |
| CO-08 | Recevoir une annonce sans recharger la page | Tout connecté | ❌ absent | `solid_cable_messages` (jamais alimentée) | — | `inventaire/identity-communication.md#diffusion-temps-réel` |
| CO-09 | Voir les confirmations et les erreurs sous forme de toasts | Tous | ⚠️ (corrigé, était ✅) | — | toutes | `inventaire/identity-communication.md#toasts-notifications-dinterface` |
| CO-10 | Programmer ou archiver une annonce | `team` | ❌ (statuts sans effet) | `messages.message_status`, `messages.published_at` | — | `inventaire/identity-communication.md#2-règles-métier-implicites-à-rendre-explicites` (n° 15, 16) |
| CO-11 | Voir les annonces dans l'espace direction | `school_admin` | ❌ (bloc présent, toujours vide) | — | `GET /schoolstaff` | nouveau |
| CO-12 | Voir les 3 dernières annonces dans un widget du tableau de bord équipe | `team` | 💀 | `messages` | — | nouveau |
| CO-13 | Afficher des annonces factices et un formulaire pré-rempli en développement | Développeur | ⚠️ | — | `GET /messages`, `GET /messages/new` | `inventaire/identity-communication.md#consultation-des-annonces` |

**Total : 47 features — 34 `ID`, 13 `CO` — dont 11 absentes de l'inventaire** (ID-06, ID-07, ID-08, ID-30, ID-31, ID-32, ID-33, ID-34, CO-05, CO-11, CO-12). Deux autres (ID-29, CO-10) n'existaient dans l'inventaire que comme règles implicites ; elles reçoivent ici un identifiant pour la traçabilité.

---

## 2. Features absentes de l'inventaire

### ID-06 — S'inscrire comme enseignant depuis la page d'acquisition « Prépa BAC »

- **Acteur** : un enseignant prospect, **anonyme** — aucune garde sur `new` ni `create` ; seul `download` exige une session (`app/controllers/teachers/prepa_acquisitions_controller.rb:13`).
- **Parcours** : `GET /teachers/prepa_acquisitions/new` (page publique, aucun lien interne n'y mène : `grep -rn prepa_acquisition app/views` ne trouve que ses propres vues) → formulaire nom complet, téléphone, matière, DRENA, école → `POST /teachers/prepa_acquisitions` → compte enseignant créé, session ouverte (`:47`) → `GET /teachers/prepa_acquisitions/download` avec « Inscription réussie ! Voici votre ressource. » → page « Votre analyse pour la matière X est prête », fichier affiché `Analyse_Recurrence_<matière>_2026.pdf` (`app/views/teachers/prepa_acquisitions/download.html.erb:16,27`).
- **Règles métier (valeurs exactes)** :
  - Même use case que `/teacher-signup` : `UseCases::Identity::RegisterTeacher` (`prepa_acquisitions_controller.rb:23`), donc création transactionnelle et rattachement à une seule école.
  - **Le formulaire ne contient aucun champ de code secret** (`app/views/teachers/prepa_acquisitions/new.html.erb:50-91` : `fullname`, `contact`, `material_id`, `drena_id`, `school_id`). Le contrôleur remplace un code vide par le numéro : `user_attrs[:password] = user_attrs[:contact] if user_attrs[:password].blank?` (`:30`). **Tout enseignant inscrit par ce chemin a pour secret son propre numéro de téléphone** — 10 chiffres, pas 4, égal à l'identifiant.
  - Aucun champ genre : `gender` reste `nil`.
  - `material_id`, `drena_id`, `school_id` sont lus à la racine des paramètres (`select_tag`, `:34-36`), pas sous `user`.
  - `download` affiche `current_teacher&.material` (`:59`) ; aucune ressource réelle n'est servie par le contrôleur.
- **Données** : `users`, `teachers`, `teacher_schools`.
- **État** : ❌ — le parcours aboutit, mais il crée systématiquement un compte dont le secret est l'identifiant public. Même défaut que la faille n° 4 de l'inventaire, en pire : il n'y a même pas de champ pour l'éviter.
- **À refaire différemment** : ne pas reproduire un parcours d'inscription parallèle à `/teacher-signup` avec ses propres règles ; ne jamais dériver un secret de l'identifiant (ADR-0025, compensation 4).

### ID-07 — Vérifier en direct un code de classe

- **Acteur** : visiteur anonyme, sur `/student-signup`.
- **Parcours** : saisie du code dans le champ « Code de classe » → le contrôleur Stimulus `classrooms` appelle `GET /api/v1/classrooms/lookup?unique_code=…` (`app/javascript/controllers/classrooms_controller.js:109`) → la réponse affiche la classe trouvée.
- **Règles métier** :
  - `skip_before_action :authenticate_user!` (`app/controllers/api/v1/classrooms_controller.rb`) : route publique.
  - Code `strip.downcase` ; vide → `400 { error: "Code requis" }` ; inconnu → `404 { error: "Classe introuvable" }`.
  - Réponse : `id`, `name`, `school_id`, `school_name`, `level_id`, `level_name` (niveau + série) (`app/infrastructure/queries/api_classroom_query.rb`, méthode `find_by_unique_code`).
  - Espace des codes : 3 lettres parmi 24 (`a`–`z` sans `i` ni `o`) + 2 chiffres parmi 8 (`2`–`9`) = **884 736 codes** (`app/infrastructure/orm/classroom.rb:54-61`). Aucune limitation de requêtes.
- **Données** : lecture de `classrooms`, `schools`, `levels`, `series`.
- **État** : ⚠️ — fonctionne ; l'espace des codes est énumérable sans limite, ce qui expose l'association code → classe → école.
- **À refaire différemment** : ne pas exposer une résolution de code d'adhésion sans limitation de débit.

### ID-08 — Listes en cascade DRENA → écoles et niveau + école → classes

- **Acteur** : visiteur anonyme, sur `/teacher-signup`, `/staff-signup`, `/student-signup`, `/teachers/prepa_acquisitions/new`.
- **Parcours** : choix d'une DRENA → `GET /api/v1/schools?drena_id=…` (`app/javascript/controllers/schools_controller.js:45`) ; choix d'un niveau et d'une école → `GET /api/v1/classrooms?level_id=…&school_id=…` (`classrooms_controller.js:82`).
- **Règles métier** : `drena_id` absent → `400 { error: "Drena ID is required" }` (message en anglais) (`app/controllers/api/v1/schools_controller.rb`) ; classes : `[]` si niveau ou école manquant, tri par nom, libellé « Nom (Série) » (`api_classroom_query.rb`, `get_classrooms_by_level_and_school`). Routes publiques (`skip_before_action :authenticate_user!, raise: false`).
- **Données** : lecture de `schools`, `classrooms`, `series`.
- **État** : ✅.
- **À refaire différemment** : la cascade manuelle permet de rejoindre **n'importe quelle classe de n'importe quelle école sans connaître son code** (`register_student.rb:71` recopie `classroom_id` tel quel ; `student_repository.rb:43-50` crée l'adhésion principale). Ne pas reproduire un contournement du code d'adhésion sans décision explicite (voir §4).

### ID-30 — Comptes élèves de démonstration qui occupent des numéros

- **Acteur** : système — `Catalog::GenerateSchoolDemoDataJob` appelle `UseCases::Classroom::GenerateDemoStudents` (`app/jobs/catalog/generate_school_demo_data_job.rb:24,43`) ; `ClassroomRepository#bulk_create_classrooms_and_demo_students` fait de même en masse (`app/infrastructure/repositories/classroom/classroom_repository.rb:123`).
- **Parcours** : aucun parcours utilisateur ; insertion par `insert_all!`, donc **sans validation ni callback** d'`Orm::User`.
- **Règles métier (valeurs exactes)** :
  - `GenerateDemoStudents` : 40 à 45 élèves par classe (`generate_demo_students.rb:38`), **numéros au format réel** `01|05|07` + 8 chiffres aléatoires (`:53-54`), **code secret commun `"12345678"`** (`:45`), `is_demo: true` (`:72`), `firstname` = premier mot et `lastname` = second (`:59-66`) — **l'inverse de la règle de découpage** appliquée partout ailleurs.
  - Seule l'unicité *à l'intérieur du lot* est vérifiée (`generated_contacts`, `:41-57`) ; un numéro déjà pris en base fait échouer tout le lot sur l'index unique, et un numéro tiré ici **n'est plus disponible pour la personne réelle** qui le possède.
  - `ClassroomRepository` : contact = `<unique_code><5 chiffres>` (`classroom_repository.rb:185`, contient des lettres, donc ne passe pas la normalisation de connexion), code secret `"123456"` (`:130`), `gender: "M"|"F"` (`:181`, hors de `male|female`), `matricule: "MAT-<contact>"` (`:214`).
- **Données** : `users.is_demo`, `students.matricule`.
- **État** : ⚠️ — les comptes du use case sont **connectables** avec un code connu de tout lecteur du dépôt.
- **À refaire différemment** : ne pas générer de comptes de démonstration dans l'espace des vrais numéros ni avec un secret partagé ; ne pas contourner les validations d'identité par `insert_all!`.

### ID-31 — Refonte visuelle des pages de connexion et d'inscription (branche)

- **Acteur** : tous les visiteurs.
- **Parcours** : identique à `HEAD`, seule la présentation change. Commits `c42bd61` (uniformisation sur le style de `/student-signup`), `3659673` (logo centré, une colonne), `93b46b4` (retour à deux colonnes), `f9d3c82` (sous-titre de connexion), tous du 2026-09-03.
- **Règles métier** :
  - **Connexion : le code secret devient masqué** — `password_field_tag :password`, `autocomplete: "current-password"` (`git show feature/ticket-4-auth:app/views/identity/sessions/new.html.erb`, l. 95-102), contre `text_field_tag :password` sur `HEAD` (`app/views/identity/sessions/new.html.erb:95`).
  - Les quatre formulaires d'inscription gardent `f.text_field :password` sur la branche (l. 140 direction, 210 élève, 112 enseignant, 90 équipe).
  - Aides ajoutées : « 10 chiffres, numéro CI sans espace. », « 4 chiffres uniquement. ».
  - Le formulaire équipe affiche un bloc d'erreurs (l. 39) — déjà présent sur `HEAD` (`app/views/teams/registrations/new.html.erb:63-71`).
- **Données** : aucune.
- **État** : ⚠️ non fusionné. Techniquement fusionnable (le `git merge-tree` à trois voies ne signale aucun conflit sur les vues), mais **indissociable du commit `93b46b4`, qui embarque ID-32**.
- **À refaire différemment** : ne pas mêler dans un même commit « UI » une réécriture de couche de persistance (voir ID-32).

### ID-32 — Délégation « au vol » ORM → entités `Entities::Identity::*` (branche)

- **Acteur** : système.
- **Parcours** : aucun. Code introduit par le commit `93b46b4`, intitulé « UI: Revert à un layout 2-colonnes », qui modifie aussi 7 fichiers de persistance et **supprime `test/domain/use_cases/exercise_use_cases_test.rb` (211 lignes)** sans rapport avec l'UI.
- **Règles métier** (`git diff HEAD...feature/ticket-4-auth -- app/infrastructure`) :
  - `Orm::Student` perd `primary_classroom`, `level`, `school`, `average_score`, `unpaid?`… au profit de `delegate … to: :domain_entity`, où `domain_entity = Repositories::Identity::StudentRepository.new.find_by_id(id)`.
  - `Orm::Teacher#school` et `#school_id` délégués de même.
  - `Orm::User#set_public_id` appelle `Entities::Identity::User.new(role:).public_id`.
  - Les repositories `User`, `Student`, `Teacher`, `Team` produisent désormais des `Entities::Identity::*` ; `payment_status: "paid"` est **codé en dur** (« Todo: logic réelle »).
- **Données** : `users`, `students`, `teachers`, `teams`.
- **État** : ❌ — **cassé sur la branche elle-même**, par trois défauts indépendants, vérifiés en lecture :
  1. Les classes `Entities::Identity::User`, `::Student`, `::Teacher`, `::Team` **n'existent pas sur la branche** : `git ls-tree -r feature/ticket-4-auth app/domain/entities/identity` ne liste que `classroom.rb`, `drena.rb`, `school.rb`. Elles n'apparaissent qu'après le point de divergence `380b9e2`, sur `HEAD`. Toute création d'utilisateur lève donc `NameError` dans `set_public_id`.
  2. `UserRepository#map_to_entity` lit `record.email` et `map_to_record_attributes` écrit `email:` : **la table `users` n'a pas de colonne `email`** (`db/schema.rb:548-567`, confirmé par `Orm::User.column_names`). Toute lecture d'utilisateur par le repository lève `NoMethodError`.
  3. `map_to_record_attributes` n'écrit plus `fullname` (colonne `NOT NULL`, `db/schema.rb:552`) ni `is_demo` ; `TeamRepository#save` lit `team_entity.user&.id` alors que `RegisterTeamMember` construit toujours un `Entities::Team.new(user_id:)` legacy (`register_team_member.rb:40`) → `user_id` nul.
  Même après fusion sur `HEAD` (où les entités existent), les défauts 2 et 3 casseraient **les cinq inscriptions, la connexion par le repository et chaque appel délégué** depuis une vue.
- **À refaire différemment** : ne pas déclarer une migration « terminée » sans qu'un test la traverse ; ne pas faire dépendre un modèle ORM d'un repository (dépendance circulaire ORM → repository → ORM).

### ID-33 — Plan « Ticket 4 » (branche)

- **Acteur** : équipe de développement.
- **Contenu** (`git show feature/ticket-4-auth:docs/tickets/TICKET-4-auth.md`, 40 lignes, commit `d5ee08a` du 2026-09-02) : migrer `User`, `Student`, `Teacher`, `Team`, `SchoolStaff` vers `app/domain/entities/identity/` en 4 étapes (entités, ports et repositories, nettoyage ORM, adaptation des contrôleurs). Prévoit de « mettre à jour l'ADR-0016 (Gestion de l'Identité) ».
- **Règles** : « La vérification stricte du mot de passe […] peut rester une responsabilité de la couche Delivery », « toute création, modification ou vérification des permissions métiers doit passer par nos Use Cases ».
- **Données** : aucune.
- **État** : ❌ jamais livré. `docs/MIGRATION_MAP.md` sur la branche marque pourtant le ticket « Terminé (Délégation au vol activée) » ; ce fichier **n'existe plus sur `HEAD`** (la fusion à trois voies le signale « removed in local » : conflit modification/suppression).
- **À refaire différemment** : le plan se trompe de numéro d'ADR (voir §4) et suppose Devise (« L'application utilise probablement Devise »), retiré par ADR-0002.

### ID-34 — En-tête et tableau des examens sur le fil équipe (branche)

- **Acteur** : `team`.
- **Parcours** : `GET /teams`. Le commit `cd348fc` (2026-09-03) dé-commente deux partiels dans `app/views/teams/feed/index.html.erb` : `teams/feed/content/feed_header` et `teams/feed/content/examen_dashboard`.
- **Règles** : les partiels lisent `@drenas`, `@levels`, `@catalog_stats`, que `Teams::FeedController` fournit déjà (`app/controllers/teams/feed_controller.rb:21-25`).
- **Données** : lecture du catalogue.
- **État** : ⚠️ non fusionné ; sans risque technique identifié.
- **À refaire différemment** : relève de l'écran `/teams` (mission 5) ; signalé ici parce que la branche est dans ma mission.

### CO-05 — Lire le détail d'une annonce

- **Acteur** : tout utilisateur connecté (`before_action :authenticate_user!`, `app/controllers/messages_controller.rb:15`).
- **Parcours** : `GET /messages/:slug`. **Aucune carte n'y mène** : `components/messages/_card` ne contient aucun lien vers `message_path` (seul `dismiss_message_path`, `app/views/components/messages/_card.html.erb:18`). Seul le widget mort CO-12 y liait.
- **Règles métier** :
  - `set_message` : `Orm::Message.friendly.find(params[:id])`, **sans filtre de statut ni d'audience** (`messages_controller.rb:147-149`).
  - La page rend le partiel équipe `messages/_message` (badges `humanize` de statut et d'audience, date, slug en clair, boutons « Détails / Éditer / Supprimer ») **puis** deux boutons en anglais « Edit this message » et « Destroy this message » (`app/views/messages/show.html.erb:11-15`), **sans garde `team?`** : un élève voit des boutons d'édition qui le renvoient vers `/` avec « Accès réservé à l'équipe Lnclass. ».
- **Données** : `messages`, `action_text_rich_texts`, `active_storage_*`.
- **État** : ⚠️.
- **À refaire différemment** : ne pas servir un contenu sans appliquer la même règle de visibilité que la liste ; ne pas afficher d'actions interdites au rôle courant.

### CO-11 — Annonces dans l'espace direction

- **Acteur** : `school_admin`.
- **Parcours** : `GET /schoolstaff` rend `schoolstaff/feed/content/_messages` (`app/views/schoolstaff/feed/index.html.erb:31`), carrousel de cartes.
- **Règles métier** : le contrôleur fixe **`@messages = []`** en dur (`app/controllers/schoolstaff/feed_controller.rb:29`, avec `@student_activities`, `@exam_assignments`, `@essentials_in_classrooms` également vides) → le bloc affiche toujours « Aucun message ».
- **Données** : aucune.
- **État** : ❌ — l'emplacement existe, la donnée n'est jamais chargée ; un `school_admin` ne voit d'annonce **que** sur `/messages` (audience `all`).
- **À refaire différemment** : ne pas livrer un bloc d'écran branché sur une constante vide.

### CO-12 — Widget « annonces » du tableau de bord équipe

- **Acteur** : `team` (en intention).
- **Parcours** : aucun — `teams/dashboard/shared/_messages_widget.html.erb` **n'est rendu nulle part** (`grep -rn messages_widget app/views` ne trouve que le fichier lui-même).
- **Règles** : affiche les 3 premières annonces dans un `turbo_frame_tag "messages"` (l. 11), chacune liée à `message_path` (l. 16), titre lu par `message.title` (l. 17) — **attribut inexistant** (`Orm::Message` porte `name`) : le partiel lèverait `NoMethodError` s'il était rendu avec des annonces.
- **Données** : `messages`.
- **État** : 💀 — et c'est **la seule cible `id="messages"` du projet**, celle que visent `create.turbo_stream.erb` et `destroy.turbo_stream.erb` (voir §3, C-06).
- **À refaire différemment** : sans objet ; à ne pas reprendre.

---

## 3. Corrections de l'inventaire

### 3.1 Sondage des règles chiffrées

Onze règles vérifiées, **toutes exactes** :

| Règle de l'inventaire | Preuve |
|---|---|
| Contact : `/\A(01\|05\|07)\d{8}\z/` | `app/models/concerns/contact_concern.rb:34` |
| Retrait de `00225` (5 caractères) puis de `225` (3) | `contact_concern.rb:21-25` et `:53-57` |
| `users.contact` `string(10)`, index unique | `db/schema.rb:549,563` |
| `users.fullname` `string(150)` | `db/schema.rb:552` |
| Enum des rôles `team: 0 … school_admin: 4`, défaut `0` | `app/infrastructure/orm/user.rb:40`, `db/schema.rb:560` |
| `public_id` = préfixe de rôle + `SecureRandom.base58(14)` | `orm/user.rb:73-81` |
| Bannière : re-proposée après **3 jours** si refusée | `app/models/concerns/install_bannerable.rb:30` |
| Titre d'annonce : **100 caractères** max | `app/infrastructure/orm/message.rb:27`, `db/schema.rb:280` |
| Tri des annonces `published_at DESC, created_at DESC` | `orm/message.rb:37` |
| Limites des fils : **5** élève, **5** enseignant, **10** équipe | `queries/student_feed_query.rb:65`, `queries/teachers_feed_query.rb:39`, `queries/teams_feed_query.rb:23` |
| Code de classe : 5 caractères | `db/schema.rb:97` |

### 3.2 Affirmations fausses ou incomplètes

| # | L'inventaire dit | Ce que montre le code |
|---|---|---|
| C-01 | Inscription équipe : « les erreurs ne sont pas ré-affichées » | **Partiellement faux.** `@user = result.user` (`app/controllers/teams/registrations_controller.rb:45`) porte les erreurs recopiées par `UserRepository#save` (`app/infrastructure/repositories/identity/user_repository.rb:60`), et la vue les affiche (`app/views/teams/registrations/new.html.erb:63-71`). Seul le message « Erreur lors de la création du profil équipe. », qui ne vit que dans `result.errors` (`register_team_member.rb:54`), est perdu. |
| C-02 | `school_staffs` : « Aucune contrainte d'unicité sur `[user_id, school_id]` : un même membre peut être inséré plusieurs fois » | **Incomplet.** Pas d'index en base (`db/schema.rb:321-330`), mais une validation applicative existe : `validates :user_id, uniqueness: { scope: :school_id, message: "est déjà membre du staff de cette école" }` (`app/infrastructure/orm/school_staff.rb:20`). Le doublon n'est possible qu'en concurrence ou par `insert_all`. |
| C-03 | Faille n° 20 : le PIN est en clair sur « les formulaires enseignant, équipe, administrateur d'établissement et élève » | **Incomplet : la page de connexion aussi** — `text_field_tag :password` (`app/views/identity/sessions/new.html.erb:95`). Et le parcours ID-06 n'a aucun champ. Le compte « 4 sur 5 » repris par ADR-0025 et `securite.md` n° 11 oublie donc le formulaire le plus utilisé. |
| C-04 | Inscription élève : « les classes sont chargées en AJAX via `GET /api/v1/classrooms/lookup` » | **Faux.** La liste vient de `GET /api/v1/classrooms?level_id=…&school_id=…` (`app/javascript/controllers/classrooms_controller.js:82`) ; `lookup` sert à vérifier un code saisi (`:109`). |
| C-05 | Inscription élève : rattachement « mutuellement exclusif » par code ou par cascade | **Incomplet.** Sans code et sans `classroom_id`, `resolve_profile_attrs` renvoie un hash vide (`app/domain/use_cases/identity/register_student.rb:71`) et `StudentRepository#save` ne crée **aucune** adhésion (`student_repository.rb:43`) : un élève sans classe est créé. Le `required` du `select` n'existe que dans le navigateur. |
| C-06 | Suppression / création : « le carrousel entier est reconstruit » ; « après création ou suppression, le carrousel se reconstruit avec les seules annonces de l'auteur » (règle n° 18) | **Faux dans les faits.** (a) `create` redirige toujours en cas de succès (`messages_controller.rb:95-96`) : `create.turbo_stream.erb` n'est **jamais rendu** 💀. (b) `destroy.turbo_stream.erb` cible `turbo_stream.update "messages"` (l. 6) ; le seul élément `id="messages"` du projet est dans le widget mort CO-12. Sur `/messages` et sur `/messages/:slug`, la réponse ne remplace donc rien : seul le toast apparaît, et l'annonce supprimée reste affichée jusqu'au rechargement. |
| C-07 | Consultation : « contrôleur Stimulus `carousel`, flèches `_carousel_nav` », « état vide dédié (`_empty_state`) », carte avec « badges de statut et d'audience, date formatée » | **Faux pour `/messages`.** L'index utilise `message-carousel` (`app/views/messages/index.html.erb:34`), un état vide **en ligne** (`:38-57`), aucun `_carousel_nav`. La carte `components/messages/_card` n'a ni badge ni date (aucun `humanize` ni `published_at` dans le fichier). Badges et date n'existent que dans `messages/_message` (partiel équipe), rendu seulement par `show` et par les flux Turbo morts. **L'équipe n'a donc aucun bouton « Éditer » ou « Supprimer » depuis `/messages`** : elle doit connaître l'URL `/messages/<slug>`. |
| C-08 | Toasts : « État ✅ » ; `render_turbo_error` prépend un toast d'erreur | **Faux.** `render_turbo_error` passe `locals: { message:, type: :danger }` (`app/controllers/concerns/current_user_concern.rb:94-97`) à `layouts/_toast_message`, qui **n'utilise aucune de ces variables** et ne lit que `flash` (`app/views/layouts/_toast_message.html.erb:13`). Le message « Veuillez vous connecter pour continuer. » n'est jamais affiché, et un second `#toast-container` est inséré dans le premier (l. 4). → ⚠️. |
| C-09 | Bannière PWA : « État ✅ » | **Faux.** (a) Sans événement `beforeinstallprompt` — donc **toujours sur iOS**, que la bannière cible explicitement (`iphone`, `ipad`) — le bouton « installer » enregistre `installed` sans rien installer (`app/javascript/controllers/install_app_controller.js:45-50`) : la bannière ne revient plus jamais. (b) Si l'utilisateur ferme la boîte native (`outcome !== "accepted"`), rien n'est enregistré (`:39-44`). (c) Les statuts `not_shown` et `visible` ne sont jamais écrits par le client. → ⚠️. |
| C-10 | « `/schoolstaff` n'affiche pas d'annonces du tout » | **Imprécis.** Le bloc existe et est rendu (`app/views/schoolstaff/feed/index.html.erb:31`) ; il est vide parce que `@messages = []` est codé en dur (`app/controllers/schoolstaff/feed_controller.rb:29`). Voir CO-11. |
| C-11 | Règle n° 23 : « les entités namespacées ne sont référencées que par leurs tests » | **Partiellement faux.** Vrai pour `Entities::Identity::User`, `::Student`, `::Teacher`, `::Team`. Mais `Entities::Identity::SchoolStaff` (`repositories/identity/school_staff_repository.rb:51`), `::School` et `::Drena` (`repositories/identity/school_repository.rb:66,74`, `app/controllers/catalog/schools_controller.rb:19`, `app/domain/use_cases/identity/manage_school.rb:20`) et `::Classroom` (`repositories/identity/classroom_repository.rb:43-46`) sont exécutés. |
| C-12 | `/users/:public_id/edit` : décrit comme un chemin de modification fonctionnel, « le rôle n'est jamais modifiable par ce chemin » | **Le chemin est cassé depuis l'interface.** Le formulaire `form_with(model: @user, …)` porte sur un `Entities::User` (`app/views/identity/users/edit.html.erb:9`), dont la clé de paramètres est `entities_user` (vérifié : `Entities::User.model_name.param_key`), alors que le contrôleur exige `params.require(:user)` (`app/controllers/identity/users_controller.rb:87`) → `ActionController::ParameterMissing`, **400**. Même avec la bonne clé, le formulaire n'envoie que `firstname`, `lastname`, `contact` (`edit.html.erb:17-28`) alors que `Dtos::UserDto` exige `fullname` (`app/domain/dtos/user_dto.rb:21`) → 422. |
| C-13 | `/schoolstaff/profile` : « `avatar` n'est jamais enregistré » (entité sans setter) | **Le problème est en amont.** Les deux formulaires utilisent `form_with model: current_user` (`app/views/schoolstaff/profiles/edit.html.erb:14`, `app/views/schoolstaff/settings/show.html.erb:20`), clé `orm_user` (vérifié : `Orm::User.model_name.param_key`), contre `params.require(:user)` (`schoolstaff/profiles_controller.rb:35`, `schoolstaff/settings_controller.rb:32`) → **400 à chaque envoi** : ni profil, ni code secret ne peuvent être changés par la direction. → ID-19 et ID-20 passent de ⚠️/❌ partiel à ❌. |
| C-14 | Avatar : cassé seulement dans l'espace direction | **Incomplet.** `/profile/edit` propose aussi un champ avatar (`app/views/profiles/edit.html.erb:45`) que `profile_params` ne permet pas (`app/controllers/profiles_controller.rb:42-46`) : il est jeté en silence. **Aucun chemin du projet n'enregistre un avatar.** |
| C-15 | Routes de `/schoolstaff/settings` : `show`, `update` | **Incomplet.** `resource :settings, only: [:show, :edit, :update]` (`config/routes.rb:177`) déclare aussi `GET /schoolstaff/settings/edit`, sans action ni vue (`app/views/schoolstaff/settings/` ne contient que `show.html.erb`) → route morte. |
| C-16 | Faille n° 16 : `creator?` provoque une « erreur 500 sur toute page appelant ce helper » | **La panne est latente, pas effective.** L'unique appelant est `app/views/catalog/courses/_empty_state.html.erb:13`, rendu seulement par `catalog/courses/destroy.turbo_stream.erb:11`, action réservée à `team` (`app/controllers/catalog/courses_controller.rb:13`) : `team?` est vrai, `admin?` n'est jamais évalué. 💀 plutôt que ❌. |
| C-17 | Annuaire : `DELETE /users/:public_id` accessible à `team` | **Aucun bouton ne l'appelle.** `index`, `_user` et `show` n'offrent que « Voir » et « Modifier » (`app/views/identity/users/_user.html.erb:11`, `show.html.erb:13`), et aucune navigation ne mène à `/users` (`grep users_path app/views/layouts` : rien). Suppression et annuaire ne sont joignables que par URL. |
| C-18 | « Ce que je n'ai pas pu déterminer » : `users.is_demo` et `students.matricule` | **Déterminé.** `is_demo: true` est posé par la génération de démonstration (`generate_demo_students.rb:72`, `classroom_repository.rb:199`) ; `matricule = "MAT-<contact>"` (`classroom_repository.rb:214`). Aucun formulaire ne renseigne l'un ou l'autre. Voir ID-30. |
| C-19 | Inscription « prepa » : « si le mot de passe est laissé vide, il est remplacé par le numéro » | **Exact, à nuancer** : le champ est `required` dans le formulaire (`app/views/students/prepa_registrations/new.html.erb:95`), la substitution ne se produit que sur un POST direct. Le cas **systématique** existe ailleurs : ID-06. |
| C-20 | En-tête : « Branche inspectée : `docs/process-v2` » ; « `feature/ticket-5-messaging` » incluse | Sans effet sur le contenu : `HEAD` (`Teamprocess`) = `Develop`, et `feature/ticket-5-messaging` est un ancêtre de `HEAD` (0 commit hors `HEAD`). **Mais l'inventaire ne dit rien de `feature/ticket-4-auth` ni de `feature/ticket-4-auth-dashboard`**, non fusionnées : voir ID-31 à ID-34. |

---

## 4. Écarts avec les décisions

Je constate ; je ne tranche pas.

| Sujet | Source A dit | Source B dit | Qui devrait trancher |
|---|---|---|---|
| Rotation de session | **ADR-0002 §3.3** : « cookies chiffrés, rotation de session » gérés par `SessionsController` | **Code** : ni `reset_session` ni rotation, ni à la connexion ni à la déconnexion (`app/controllers/identity/sessions_controller.rb:32,42` ; `grep reset_session app` : rien) | ADR de fondation « session et authentification » (complète ADR-0002/0025) |
| Longueur du contact | **ADR-0002 §5** : `length: { minimum: 10, maximum: 15 }`, normalisation limitée aux espaces | **Code et ADR-0002 §3.2** : exactement 10 chiffres, `01/05/07` (`contact_concern.rb:34`) ; normalisation des indicatifs (`:18-27`) | Réviser les notes d'implémentation d'ADR-0002 (ADR de remplacement ou correctif) |
| Opérateurs couverts | **ADR-0002 §1** : « réseaux Orange, MTN, Moov, Wave » | **Code** : trois préfixes seulement (`contact_concern.rb:16`) ; Wave n'a pas de préfixe propre | ADR-0002 (correctif) |
| Authentification par use case | **ADR-0002 §2-4** : authentifier via `UseCases::AuthenticateUser` et le port | **Code** : use case jamais appelé 💀, le contrôleur lit `Orm::User` (`sessions_controller.rb:28-31`) | Blueprint / ADR de la vague identity |
| Mécanisme de récupération | **ADR-0002 §4** : réinitialisation « nécessite l'envoi d'un code de vérification par SMS » | **ADR-0025 §3 option B** écarte le SMS (coût, couverture) comme mode de connexion, et **§4 compensation 6** exige un parcours de récupération sans en fixer le canal | ADR à écrire : « récupération de compte » |
| Qui est un rôle privilégié | **ADR-0025 §4 compensation 5** : second facteur pour `team` seulement | **Code** : `school_admin` accède aux listes nominatives de mineurs et rattache des comptes (`schoolstaff/students_controller.rb:16-19`, `teachers_controller.rb:24-27`) ; **`feature_listing.md:4`** prévoit des sous-profils équipe (Tech, Marketing, Drena Manager, agents de terrain) qu'aucun rôle ne distingue | ADR de fondation « modèle d'autorisation » |
| Création des comptes privilégiés | **ADR-0025** impose un second facteur à `team` | **Code** : `team` et `school_admin` s'auto-inscrivent sur une route publique (`config/routes.rb:18-22`) ; l'ADR ne dit pas comment ces comptes naissent | ADR « modèle d'autorisation » |
| Compte des formulaires à PIN visible | **ADR-0025 §6** et **`securite.md` n° 11** : « quatre des cinq formulaires d'inscription » | **Code** : + la connexion (`sessions/new.html.erb:95`) ; + ID-06 sans champ du tout | Mettre à jour `securite.md` ; ADR-0025 reste valide sur le fond |
| Secret dérivé de l'identifiant | **ADR-0025 compensation 4**, **`securite.md` n° 5** : un seul chemin (`/c/<code>`) | **Code** : aussi `/teachers/prepa_acquisitions` (`prepa_acquisitions_controller.rb:30`), systématique | Mettre à jour `securite.md` |
| État de la migration Identity | **ADR-0021 §2-3** (Accepté) : « nous avons mis en place » la délégation, « l'ORM est redevenu purement anémique » | **Code `HEAD`** : `Orm::Student` porte encore toute la logique (`orm/student.rb:33-83`), `Orm::Teacher#school` aussi (`orm/teacher.rb:35-41`) ; la délégation n'existe que sur une branche non fusionnée et cassée (ID-32) ; `docs/MIGRATION_MAP.md` de la branche la dit « Terminé » | Remplacer ADR-0021 (statut réel : non implémenté) |
| Numéro de l'ADR Identity | **TICKET-4** : « Mettre à jour l'ADR-0016 (Gestion de l'Identité) » | **Index des ADR** : ADR-0016 = conservation de l'historique des assignations ; l'identité est ADR-0021 (non daté) | Aucun arbitrage : document de branche obsolète, à écarter |
| Devise | **ADR-0002** : Devise retiré | **TICKET-4** : « L'application utilise probablement Devise » | Idem, document obsolète |
| Entité de référence de `User` | **Glossaire §1** : `User` → `Orm::User`, `Entities::Identity::User` | **Code** : l'exécution n'utilise que `Entities::User` (legacy racine) ; `Entities::Identity::User` n'est chargé que par les tests | Glossaire, après décision sur ADR-0021 |
| Unicité du personnel d'établissement | **Glossaire §1** : « un utilisateur ne peut être membre du staff d'une école qu'une fois » | **Inventaire** : « aucune contrainte d'unicité » ; **schéma** : pas d'index (`db/schema.rb:321-330`) ; **ORM** : validation (`orm/school_staff.rb:20`) | Pas de conflit de décision ; l'unicité en base est à décider par l'ADR de la vague (cf. `securite.md` n° 15) |
| Identifiant public | **Glossaire §7** : `public_id` exposé « à la place de l'ID séquentiel » ; **ADR-0017** : identifiant aléatoire de 14 caractères | **Code** : repli sur l'ID entier (`users_controller.rb:31`) ; le préfixe expose le rôle dans l'URL (`orm/user.rb:73-79`) | ADR « identifiants publics » |
| Rôles couverts par l'interface | **UDR-0004 §1** : « 5 types de rôles » accèdent à la plateforme ; §3 : chaque rôle est redirigé vers son tableau de bord | **Code** : `parent` n'a ni profil ni espace et retombe sur `/` (`application_controller.rb:19,32`) ; **ADR-0002 §2** cite aussi les parents comme acteurs | UDR de remplacement + ADR « rôle parent » (garder ou retirer) |
| Erreurs d'autorisation en toast | **UDR-0004 §3** : « les toasts Hotwire continuent d'afficher les erreurs d'autorisation » | **Code** : en réponse Turbo Stream, le message est perdu (C-08) | UDR de remplacement |
| Avatar dans les composants | **UDR-0004 §3** : `_drawer` et `_sidebar` lisent `current_user.avatar`, à ne pas altérer | **Code** : aucun chemin n'enregistre d'avatar (C-13, C-14) | UDR « profil » |
| « Zero-break migration » | **UDR-0004 §2** : aucune régression d'interface pendant la migration Identity | **Branche `feature/ticket-4-auth`** : casserait toutes les inscriptions (ID-32) | Constat de branche ; rien à trancher si la branche est écartée |
| Suppression d'un compte élève | **ADR-0005 §1-2** : aucune suppression de compte ne doit « anéantir […] des résultats d'examen » (moteur : intégrité de la scolarité) | **Code** : `DELETE /users/:public_id` détruit en cascade sessions, badges, lacunes (`db/schema.rb:585,587,592,613`) sans archivage ; ADR-0005 ne vise que les créateurs `team` | ADR « suppression, archivage et anonymisation des comptes » |
| Anti-cascade sur les annonces | **ADR-0005 §3** : FK nullable, `on_delete: :nullify`, `optional: true`, jamais `dependent: :destroy` | **Code** : conforme pour `messages.team_id` (`db/schema.rb:283,597`, `orm/message.rb:20`, `orm/team.rb:23`) | Aucun écart — noté pour mémoire |
| Code d'adhésion contournable | **Inventaire** et **ADR-0003** (mission 2) : le code d'adhésion rattache l'élève à la classe comme appartenance principale | **Code** : la cascade manuelle rejoint n'importe quelle classe sans code (ID-08, C-05) | ADR de la vague classroom (mission 2) |
| Interface en français via `t(".key")` | **`conventions.md:12`** | **Code** : aucun `t(".…")` dans `identity/`, `messages_controller.rb`, `app/views/messages`, `app/views/identity` ; libellés anglais « Edit this message », « Destroy this message » (`messages/show.html.erb:13,15`), « Drena ID is required » (`api/v1/schools_controller.rb`) | Aucun arbitrage : règle établie, à appliquer |
| Messagerie promise | **`docs/MIGRATION_MAP.md` (branche)** : « TICKET-5 : La Messagerie Interne & Notifications (Inbox/Toasts) » | **Code** : annonces descendantes seulement, aucune messagerie (inventaire, avertissement de cadrage) | PRD du programme : périmètre de `communication` |

---

## 5. Couverture

### 5.1 Tables

| Table | ID | Remarque |
|---|---|---|
| `users` | ID-01 à ID-06, ID-12 à ID-29, ID-30 | |
| `students` | ID-01, ID-02, ID-10, ID-11, ID-23, ID-30 | |
| `teachers` | ID-03, ID-06, ID-09, ID-23 | |
| `teams` | ID-04, ID-23, CO-01 | |
| `school_staffs` | ID-05, ID-19, ID-23 | rôles d'école : mission 2 |
| `school_roles` | ID-05 | écran `/schools/:id/school_roles` : mission 2 |
| `teacher_schools` | ID-03, ID-06, ID-09, ID-11, ID-27 | |
| `classroom_students` | ID-01, ID-02, ID-10, ID-11 | frontière avec la mission 2 |
| `messages` | CO-01 à CO-07, CO-10, CO-12 | |
| `action_text_rich_texts` | CO-01, CO-02, CO-04 | seul usage du projet dans mon périmètre |
| `active_storage_attachments`, `active_storage_blobs`, `active_storage_variant_records` | CO-01, CO-02, ID-19 | avatars jamais écrits (C-14) |
| `friendly_id_slugs` | ID-29, CO-01 | |
| `solid_cable_messages` | CO-08 | **morte** : aucun `broadcast_*` ni `turbo_stream_from` dans `app/` (inventaire, vérifié) |
| `sessions`, `parents`, `notifications`, `message_dismissals`, `password_reset_tokens` | ID-12, ID-25, CO-07, CO-08, ID-15 | **absentes** du schéma ; citées pour la traçabilité des besoins |

Lignes de `docs/feature_listing.md` de mon périmètre : « Users » → ID-01…ID-29 ; « team » → ID-04 ; « teacher » → ID-03, ID-06 ; « student » → ID-01, ID-02 ; « classroom_students » → ID-01, ID-10 ; « messages » → CO-01…CO-13 ; « AddInstallBannerStatusToUsers » → ID-26 ; « school_roles », « school_staffs » → ID-05 (et mission 2) ; « solid_cable_messages » → CO-08.

### 5.2 Routes (`config/routes.rb`)

| Route | ID |
|---|---|
| `GET /login`, `POST /login` (l. 4-5) | ID-12 |
| `DELETE /logout` (l. 6) | ID-14 |
| `GET`, `POST /student-signup` (l. 8-9) | ID-01 |
| `GET /users` (l. 11) | ID-21 |
| `GET /users/:public_id` | ID-22 |
| `GET /users/:public_id/edit`, `PATCH`/`PUT /users/:public_id` | ID-18 |
| `DELETE /users/:public_id` | ID-23 |
| `GET`, `POST /teacher-signup` (l. 15-16) | ID-03 |
| `GET`, `POST /staff-signup` (l. 18-19) | ID-05 |
| `GET`, `POST /team-signup` (l. 21-22) | ID-04 |
| `GET`, `POST /c/:unique_code` (l. 25-26) | ID-02 |
| `GET /api/v1/schools` (l. 87) | ID-08 |
| `GET /api/v1/classrooms` (l. 88) | ID-08 |
| `GET /api/v1/classrooms/lookup` (l. 90) | ID-07 |
| `GET /messages`, `GET /messages/new`, `POST /messages` (l. 107) | CO-04, CO-13, CO-01 |
| `GET /messages/:id` | CO-05 |
| `GET /messages/:id/edit`, `PATCH`/`PUT /messages/:id` | CO-02 |
| `DELETE /messages/:id` | CO-03 |
| `DELETE /messages/:id/dismiss` (l. 109) | CO-07 |
| `GET /students`, `GET /teachers`, `GET /teams` (l. 115, 129, 161) | CO-06 (écrans : mission 5) |
| `GET /teachers/prepa_acquisitions/new`, `POST /teachers/prepa_acquisitions`, `GET /teachers/prepa_acquisitions/download` (l. 145-149) | ID-06 (écran : aussi mission 5) |
| `GET /schoolstaff` (l. 175) | CO-11 (écran : mission 5) |
| `GET /schoolstaff/profile`, `GET /schoolstaff/profile/edit`, `PATCH`/`PUT /schoolstaff/profile` (l. 176) | ID-19 |
| `GET /schoolstaff/settings`, `PATCH`/`PUT /schoolstaff/settings` (l. 177) | ID-20 |
| `GET /schoolstaff/settings/edit` (l. 177) | **morte** : ni action dans `schoolstaff/settings_controller.rb`, ni vue `edit` |
| `GET /schoolstaff/teachers`, `GET …/new`, `POST /schoolstaff/teachers` (l. 179) | ID-11, ID-09 |
| `GET /schoolstaff/students`, `GET …/new`, `POST /schoolstaff/students` (l. 180) | ID-11, ID-10 |
| `GET /profile/edit`, `PATCH`/`PUT /profile` (l. 183) | ID-17 |
| `PATCH /install_banner` (l. 185) | ID-26 |
| `GET /manifest`, `GET /service-worker` (l. 188-189) | ID-26 en partie ; PWA : mission 5 |
| `GET /` (l. 192) | ID-13 (page d'accueil : mission 5) |
| `GET /schools/:id/school_roles…`, `…/school_staffs…` (l. 61-62) | hors périmètre → mission 2 |

### 5.3 Branches non fusionnées de ma mission

| Branche | Commits hors `HEAD` | Rattachement |
|---|---|---|
| `feature/ticket-4-auth` | `d5ee08a`, `c42bd61`, `3659673`, `93b46b4`, `f9d3c82` + la fusion `0a77d5a` (dont les deux parents sont déjà dans `HEAD`) | ID-31, ID-32, ID-33 |
| `feature/ticket-4-auth-dashboard` | les mêmes + `cd348fc` | ID-31 à ID-34 |

---

## 6. Ce que je n'ai pas pu déterminer

- **Le comportement réel à l'exécution des défauts déduits par lecture** (C-06, C-12, C-13, ID-32) : je n'ai lancé ni serveur ni test. Les clés de paramètres (`entities_user`, `orm_user`) sont vérifiées par `bin/rails runner` ; la réponse exacte (400 attendu pour `ParameterMissing`) ne l'est pas.
- **La mise à jour d'une annonce sans nouveau contenu** : `ManageMessage#execute_update` recharge une entité dont `content` est un objet `ActionText::RichText` (`message_repository.rb:74`), puis `save` le réaffecte à `record.content=` (`:46`). Je n'ai pas pu établir si cette réaffectation d'un objet `RichText` sur lui-même est neutre ou altère le contenu.
- **Ce que voit un élève créé sans classe** (C-05) sur `/students` : dépend de `GetStudentFeed` et des vues, hors de mon périmètre ; non vérifié.
- **L'intention de la page d'acquisition « Prépa BAC »** (ID-06) : aucune ressource n'est servie, aucun lien interne n'y mène ; campagne en cours, abandonnée ou future — indéterminable depuis le code.
- **Pourquoi `93b46b4` supprime `test/domain/use_cases/exercise_use_cases_test.rb`** : le message du commit n'en dit rien.
- **La suite donnée aux branches `feature/ticket-4-*`** : ni `journal.md` ni `memo.md` ne les mentionnent à ma connaissance ; je n'ai pas vérifié si une décision de les abandonner existe ailleurs.
- **L'usage réel des comptes de démonstration connectables** (ID-30) en production : le code montre qu'ils le sont, pas s'ils ont été générés sur une base réelle.
