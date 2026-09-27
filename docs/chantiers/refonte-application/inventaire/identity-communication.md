# Inventaire fonctionnel — contextes `identity` et `communication`

> **Objet** : décrire **ce que l'application fait** dans les contextes bornés `identity` et `communication`, afin de pouvoir la recoder intégralement dans un nouveau projet Rails sans relire le code actuel.
>
> **Périmètre lu** : `app/domain/**/identity/`, `app/domain/**/communication/`, `app/domain/entities/` (legacy racine), `app/infrastructure/repositories/identity/`, `app/infrastructure/repositories/communication/`, `app/infrastructure/orm/`, `app/infrastructure/queries/`, `app/controllers/` (sessions, registrations, users, profils, schoolstaff, messages), `app/views/` correspondantes, `app/models/concerns/`, `config/routes.rb`, `db/schema.rb`.
>
> **Branche inspectée** : `docs/process-v2`. Vérification faite : `git log docs/process-v2..feature/ticket-5-messaging` ne renvoie **aucun commit** — la branche courante est un sur-ensemble strict de la branche messagerie. Ce document décrit donc l'état final et complet de la feature.
>
> **Légende des états** : ✅ fonctionne · ⚠️ fonctionne avec réserves · ❌ cassé ou absent · 💀 mort (code présent, jamais exécuté)

---

## Table des matières

1. [Contexte identity — inscriptions](#contexte-identity--inscriptions)
2. [Contexte identity — sessions](#contexte-identity--sessions)
3. [Format du contact téléphonique (ADR-0002)](#format-du-contact-téléphonique-adr-0002)
4. [Contexte identity — autorisation](#contexte-identity--autorisation)
5. [Contexte identity — profils et comptes](#contexte-identity--profils-et-comptes)
6. [Contexte communication](#contexte-communication)
7. [Tables, colonnes et index](#1-tables-colonnes-et-index)
8. [Règles métier implicites à rendre explicites](#2-règles-métier-implicites-à-rendre-explicites)
9. [Failles et fragilités de sécurité](#3-failles-et-fragilités-de-sécurité)
10. [Ce que je n'ai pas pu déterminer](#4-ce-que-je-nai-pas-pu-déterminer)

---

# Contexte identity — inscriptions

## Inscription d'un élève (formulaire public)

- **Acteur** : un élève, seul, depuis `/student-signup`
- **Parcours** : `GET /student-signup` → formulaire unique en 2 blocs → `POST /student-signup` → le compte est créé, la session est ouverte immédiatement (pas de confirmation, pas d'email, pas de SMS) → redirection vers `/students` (feed élève) avec le toast « Bienvenue sur Lnclass ! »

- **Règles métier** :
  - Deux façons **mutuellement exclusives** de rattacher l'élève à une classe :
    1. **Code de classe** : champ `unique_code`, 5 caractères max, `strip.downcase` appliqué par le use case. S'il est renseigné, **il prime sur tout le reste** et résout `classroom_id`, `school_id`, `level_id`, `series_id` depuis la classe trouvée. Code inconnu → échec avec l'erreur « Code de classe invalide ».
    2. **Cascade manuelle** : `level_id`, `school_id`, `classroom_id` (les classes sont chargées en AJAX via `GET /api/v1/classrooms/lookup` après le choix de l'école), `series_id`.
  - `fullname` : obligatoire, **au moins deux mots** sinon « doit contenir au moins deux mots (nom et prénom). ». Normalisé : `strip`, chaque mot `capitalize`, espaces multiples réduits à un seul.
  - **Découpage du nom (règle ivoirienne inversée)** : `firstname` = **dernier** mot, `lastname` = **tous les mots précédents**. Ex. « Koffi Jules » → `lastname` = « Koffi », `firstname` = « Jules ».
  - `contact` : obligatoire, unique en base. Voir [Format du contact téléphonique](#format-du-contact-téléphonique-adr-0002).
  - `password` : `maxlength: 4`, `pattern "\d{4}"`, `inputmode: numeric` → **code PIN à 4 chiffres**. Contrainte purement HTML : **aucune validation serveur** de longueur ni de format.
  - `gender` : `male` ou `female` uniquement (valeur vide tolérée par le DTO, mais le `select` envoie toujours une valeur, `male` présélectionné).
  - Rôle forcé à `student` côté serveur.
  - Après création du `Orm::User`, un `Orm::Student` est créé, puis un `Orm::ClassroomStudent` avec `primary: true` et `joined_at: Time.current`.
  - **Pas de transaction** : si la création du profil `Student` échoue, l'utilisateur reste créé orphelin. Le code le reconnaît explicitement : *« Cleanup user if student fails? (Simple version: no) »*.
  - Validation en amont par `Dtos::UserDto` (`fullname`, `role`, `contact` obligatoires ; `gender` dans `%w[male female]`, vide toléré).

- **Données** : `users`, `students`, `classroom_students`
- **État** : ⚠️
- **À refaire différemment** : transaction obligatoire + validation serveur du PIN. Les `level_id` / `school_id` / `series_id` saisis **ne sont jamais persistés** — ils ne servent qu'à filtrer la liste des classes, ce qui est trompeur pour qui lit le formulaire.

---

## Inscription d'un élève via lien de classe (« prepa »)

- **Acteur** : un élève qui reçoit d'un enseignant un lien court `https://…/c/<unique_code>`
- **Parcours** : `GET /c/:unique_code` → si le code est inconnu, redirection racine avec « Code de classe invalide. ». Sinon, page de landing affichant l'école et **le premier enseignant de la classe** (preuve sociale, purement cosmétique — le code l'assume) + formulaire réduit à 4 champs → `POST /c/:unique_code` → session ouverte → `/students` avec « Bienvenue dans la classe de révision ! »

- **Règles métier** :
  - Champs : `fullname`, `gender`, `contact`, `password` (4 chiffres — **ici en `password_field` masqué**, contrairement aux autres formulaires).
  - **Si le mot de passe est laissé vide, il est remplacé par le numéro de contact** (`user_attrs[:password] = user_attrs[:contact] if user_attrs[:password].blank?`). Le mot de passe devient donc identique à l'identifiant de connexion.
  - `classroom_id`, `school_id`, `level_id`, `series_id` viennent de la classe résolue par le code.
  - Deux attributs sont passés au use case mais **jamais persistés** : `prepa_status: "unpaid"` et `prepa_joined_at: Time.current` — aucune colonne ne les porte.
  - Ce chemin **ne passe pas par `Dtos::UserDto`** : il envoie un `Hash` brut au use case. Aucune validation DTO, contrairement à `/student-signup`.
  - La page de landing charge `Orm::Classroom.find(@classroom.id).teachers.first` directement en ActiveRecord (contournement assumé de la couche domaine).

- **Données** : `users`, `students`, `classroom_students`
- **État** : ⚠️
- **À refaire différemment** : ne jamais dériver le mot de passe du numéro ; unifier avec `/student-signup` (aujourd'hui : un même use case, deux formulaires, **deux niveaux de validation différents**).

---

## Inscription d'un enseignant

- **Acteur** : un enseignant, seul, depuis `/teacher-signup` (route publique)
- **Parcours** : `GET /teacher-signup` → formulaire une page → `POST /teacher-signup` → compte créé, `session[:user_id]` posée immédiatement → redirection vers `/teachers/classrooms` avec « Bienvenue ! Sélectionnez vos classes pour commencer. » L'onboarding force donc le choix des classes juste après l'inscription.

- **Règles métier** :
  - Champs : `fullname`, `gender`, `contact`, `drena_id`, `school_id`, `material_id`, `password`.
  - `drena_id` : obligatoire (`required`), `collection_select` sur `Orm::Drena.order(:name)`. **Jamais persisté** — il ne sert qu'à filtrer les écoles.
  - `school_id` : obligatoire, `collection_select` sur `Orm::School.where(drena_id:).order(:name)`, **désactivé tant qu'aucune DRENA n'est choisie**. La liste est rechargée en AJAX par le contrôleur Stimulus `schools` (`change->schools#loadSchoolsByDrena`), qui interroge `GET /api/v1/schools`.
  - `material_id` : obligatoire, la matière enseignée. **Une seule matière par enseignant** (colonne `teachers.material_id`).
  - `fullname` : mêmes règles que pour l'élève — au moins deux mots, `strip`, chaque mot `capitalize`, `firstname` = dernier mot, `lastname` = tout ce qui précède.
  - `contact` : obligatoire, unique, `maxlength: 10`, `pattern "\d{10}"`, `oninput` qui supprime tout caractère non numérique à la frappe.
  - `password` : `f.text_field` (**saisie visible à l'écran**), `maxlength: 4`, `pattern "\d{4}"`, `inputmode: numeric`, `autocomplete: new-password`. Aucune validation serveur.
  - `gender` : `male` / `female`, `male` présélectionné.
  - Rôle forcé à `teacher` côté serveur (`Entities::User::ROLES[:teacher]`).
  - **Création transactionnelle** : `@user_repo.transaction do … end` avec `raise Ports::RollbackError` si le profil enseignant échoue → l'utilisateur est annulé. (`UserRepository#transaction` enveloppe `ActiveRecord::Base.transaction` et convertit `Ports::RollbackError` en `ActiveRecord::Rollback`.)
  - Après création du `Orm::Teacher`, un `Orm::TeacherSchool` est créé par `find_or_create_by!(teacher_id:, school_id:)` → **un enseignant peut appartenir à plusieurs écoles** (ADR-0004), mais l'inscription n'en rattache qu'une.
  - Hack de validation dans le use case : `teacher_entity.user_id = 0` pour faire passer `validates :user_id, presence: true` avant que l'utilisateur n'existe, puis remise à `nil`, puis au vrai id.
  - En cas d'échec : re-rendu `422`, collections rechargées avec la DRENA soumise, erreurs poussées dans `@user.errors[:base]` (dédoublonnées).

- **Données** : `users`, `teachers`, `teacher_schools`
- **État** : ⚠️
- **À refaire différemment** : introduire une école principale explicite au lieu de `schools.first` ; supprimer le hack `user_id = 0` ; persister ou supprimer `drena_id`.

---

## Inscription d'un membre de l'équipe Lnclass

- **Acteur** : **n'importe qui**, depuis `/team-signup` — route publique, sans invitation, sans code, sans authentification préalable
- **Parcours** : `GET /team-signup` → formulaire 4 champs → `POST` → session ouverte → `/teams` avec « Bienvenue dans l'équipe Lnclass ! »

- **Règles métier** :
  - Champs : `fullname`, `gender`, `contact`, `password` (4 chiffres, en `text_field` visible). Aucun rattachement à une école ni à une matière.
  - Rôle forcé à `team`.
  - Création transactionnelle (même mécanique que l'enseignant, via `Ports::RollbackError`).
  - En cas d'échec, `@user = result.user` puis `render :new, status: :unprocessable_entity` — **les erreurs ne sont pas ré-affichées** ici, contrairement aux autres inscriptions (pas de boucle `result.errors.each`).
  - **Ce que le rôle `team` donne concrètement** : écriture complète du catalogue (`courses`, `essentials`, `exercises`, `levels`, `materials`, `series`, `drenas`, `schools`, `exam_subjects`, imports JSON), `index` et `destroy` sur **tous** les utilisateurs, création / édition / suppression de **toutes** les annonces, accès au tableau de bord `/teams` et à `/teams/lnclassai`.

- **Données** : `users`, `teams`
- **État** : ❌ (faille d'élévation de privilèges — voir §3, faille n°1)
- **À refaire différemment** : supprimer la route publique ; création uniquement par un `team` existant, par invitation, ou par seed.

---

## Inscription d'un administrateur d'établissement

- **Acteur** : n'importe qui, depuis `/staff-signup` (route publique)
- **Parcours** : `GET /staff-signup` → formulaire → `POST` → session ouverte → `/schoolstaff` avec « Bienvenue ! Votre compte a été créé avec succès. »

- **Règles métier** :
  - Champs : `fullname`, `gender`, `contact`, `drena_id` (filtre, non persisté), `school_id` (obligatoire), `password` (4 chiffres, `f.text_field` visible, placeholder `****`).
  - Rôle forcé à `school_admin`.
  - Création transactionnelle.
  - Un `Orm::SchoolRole` **nommé « Direction »** est créé ou retrouvé pour l'école (`SchoolRoleRepository#find_or_create_default_role` → `Orm::SchoolRole.find_or_create_by(school_id:, name: "Direction")`), puis affecté au `school_staff`. **Le demandeur ne choisit jamais son rôle d'école**, alors que la table `school_roles` et l'écran `/schools/:id/school_roles` existent.
  - `school_staffs.school_role_id` est `NOT NULL` — d'où cette auto-création.
  - Même hack de validation : `user_id = 0` et `school_role_id = 0`, puis remise à `nil`, puis aux vraies valeurs.
  - **Aucune vérification que le demandeur a le moindre lien avec l'école choisie.**

- **Données** : `users`, `school_staffs`, `school_roles`
- **État** : ❌ (n'importe qui devient directeur de n'importe quelle école — voir §3, faille n°2)
- **À refaire différemment** : validation par un tiers, ou code d'établissement à usage unique.

---

## Rattachement d'un enseignant existant à un second établissement

- **Acteur** : un `school_admin`, depuis `/schoolstaff/teachers/new`
- **Parcours** : formulaire à un champ (numéro de contact) → `POST /schoolstaff/teachers` → si un `Orm::User` porte ce contact **et** possède un profil `teacher`, il est ajouté à `@school.teachers` → « Enseignant rattaché à l'établissement avec succès. » Sinon → « Enseignant introuvable avec ce numéro de contact. »

- **Règles métier** :
  - Idempotent : `unless @school.teachers.include?(user.teacher)`.
  - `@school` vient de `Schoolstaff::BaseController#set_school` = `current_user.profile&.school`.
  - **Le contact saisi n'est pas normalisé** avant `find_by(contact:)` → un numéro au format `+225…` ou avec des espaces ne trouve rien.
  - Écrit directement via ActiveRecord, sans use case ni repository.

- **Données** : `teacher_schools`
- **État** : ⚠️

---

## Rattachement d'un élève existant à une classe par la direction

- **Acteur** : un `school_admin`, depuis `/schoolstaff/students/new`
- **Parcours** : contact de l'élève + choix d'une classe de l'école → si l'utilisateur existe avec un profil `student` **et** que la classe appartient à l'école, `classroom.students << user.student` → « Élève ajouté à la classe avec succès. » Sinon → « Élève ou classe introuvable. »

- **Règles métier** :
  - Idempotent.
  - La classe est cherchée dans `@school.classrooms` — pas d'accès aux classes d'une autre école.
  - Contact non normalisé.
  - **Le `ClassroomStudent` créé par `<<` n'a ni `primary: true` ni `joined_at`**, contrairement au chemin d'inscription qui les positionne. Un élève ajouté par la direction n'a donc pas de classe principale marquée : le repli `classrooms.first` s'applique.

- **Données** : `classroom_students`
- **État** : ⚠️

---

## Consultation des élèves et enseignants de l'établissement

- **Acteur** : `school_admin`
- **Parcours** : `/schoolstaff/teachers` liste `@school.teachers.includes(:user)` · `/schoolstaff/students` liste `Orm::Student.joins(classrooms: :school).where(schools: { id: @school.id }).includes(:user).distinct`
- **Règles métier** : `require_school!` bloque l'accès si le `school_staff` n'a pas d'école (« Vous devez être affecté à une école pour voir cette page. »). **Aucune pagination.** Accès direct à l'ORM, sans repository.
- **État** : ⚠️

---

# Contexte identity — sessions

## Connexion

- **Acteur** : tout utilisateur, depuis `/login`
- **Parcours** : `GET /login` → page 2 colonnes (visuel à gauche en desktop, formulaire à droite), 2 champs → `POST /login`.
  - **Succès** : `session[:user_id] = user.id` + redirection par rôle + flash notice « Connexion réussie ! »
  - **Échec** : rendu `422` avec `flash.now[:alert]` = **« Numéro de contact ou mot de passe incorrect. »** (message unique, pas d'énumération de comptes) et `@contact` repeuplé avec la saisie brute.

- **Règles métier** :
  - Formulaire en `form_with url: session_path, method: :post, data: { turbo: false }` → soumission HTML classique, jetons CSRF Rails par défaut (`config.load_defaults 8.1`).
  - Champ contact : `telephone_field_tag :contact`, `autofocus`, `required`, `maxlength: 10`, `inputmode: tel`, `autocomplete: tel`, placeholder « 07 00 00 00 00 ».
  - Le contact est normalisé par `ContactConcern.normalize_for_lookup(params[:contact])` **avant** le `find_by(contact:)`. Cette normalisation **ne valide rien** : la valeur nettoyée est utilisée telle quelle.
  - Mot de passe vérifié par `user.authenticate(params[:password])` (bcrypt via `has_secure_password`).
  - **Aucune limitation de tentatives**, aucun verrouillage, aucun délai progressif, aucun journal d'échec.
  - **Aucun `reset_session`** : l'identifiant de session n'est pas régénéré à la connexion.
  - `UseCases::Identity::AuthenticateUser` existe (contrat : `execute(contact:, password:)` ; erreur « Contact et mot de passe requis » si l'un est vide, « Contact ou mot de passe invalide » sinon) mais **n'est appelé nulle part** 💀. Le contrôleur tape directement dans `Orm::User`, ce que son propre en-tête assume comme « pragmatisme ».

- **Redirection post-connexion** — `ApplicationController#after_sign_in_path_for(resource)` :

  | Condition | Destination |
  |---|---|
  | `resource.profile` absent | `/` |
  | rôle `student` | `/students` |
  | rôle `teacher` **et aucune classe** | `/teachers/classrooms` |
  | rôle `teacher` avec au moins une classe | `/teachers` |
  | rôle `team` | `/teams` |
  | rôle `school_admin` | `/schoolstaff` |
  | rôle `parent` ou inconnu | `/` |

- **Données** : `users`
- **État** : ⚠️
- **À refaire différemment** : `reset_session` + rate limiting (`rate_limit` natif Rails 8) + brancher le use case existant.

---

## Déconnexion

- **Acteur** : tout utilisateur connecté, `DELETE /logout`
- **Parcours** : `session[:user_id] = nil` → redirection `/` avec « Déconnexion réussie ! »
- **Règles métier** : **pas de `reset_session`**. L'identifiant de session survit, ainsi que tout le reste du contenu de session — notamment `session[:dismissed_messages]`, qui persiste donc **d'un utilisateur à l'autre** sur le même navigateur.
- **État** : ⚠️

---

## Mot de passe oublié / réinitialisation

- **Il n'existe aucun parcours de récupération de mot de passe.** Aucune route, aucun contrôleur, aucun mailer, aucune table de jetons, aucun envoi de SMS.
- Un utilisateur qui perd son PIN à 4 chiffres n'a **aucun moyen de reprendre son compte** — sauf à passer par un membre `team` qui édite son mot de passe via `/users/:public_id/edit`.
- **État** : ❌ (absent)

---

# Format du contact téléphonique (ADR-0002)

C'est le pivot de tout le contexte identity : **le numéro de téléphone est l'identifiant de connexion**. Il n'y a ni email, ni pseudo, ni identifiant alternatif.

## Entrées acceptées

Ce qu'un utilisateur peut taper, toutes formes confondues :

```
0700000000
07 00 00 00 00
07-00-00-00-00
07.00.00.00.00
+2250700000000
2250700000000
002250700000000
```

Tout caractère non numérique est supprimé avant traitement.

## Normalisation

`ContactConcern#normalize_contact!`, exécuté en `before_validation` sur `Orm::User` :

1. `contact.to_s.gsub(/\D/, "")` → on ne garde que les chiffres.
2. Si la chaîne commence par `00225` → on retire les **5** premiers caractères.
   Sinon si elle commence par `225` → on retire les **3** premiers.
3. La chaîne obtenue est réaffectée à `contact`, **quelle que soit sa forme**.

> ⚠️ Le bloc `if digits.length == 10 && ALLOWED_PREFIXES.include?(digits[0, 2])` et son `else` affectent **la même valeur**. La constante `ALLOWED_PREFIXES = %w[01 05 07]` est donc déclarée mais **sans effet réel**. Le commentaire du code annonce « laisser les chiffres pour que la validation échoue proprement ».

## Validation

Bloc `included do` de `ContactConcern` :

| Règle | Détail |
|---|---|
| `presence` | obligatoire |
| `uniqueness` | doublée d'un index unique en base |
| `format` | `/\A(01\|05\|07)\d{8}\z/` — message : « doit être 10 chiffres commençant par 01, 05 ou 07 » |

→ **Exactement 10 chiffres, commençant par `01`, `05` ou `07`** : les trois préfixes mobiles ivoiriens (Moov, MTN, Orange). Les numéros fixes et les numéros étrangers sont refusés.

## Stockage

`users.contact` · `string limit: 10` · `NOT NULL` · index unique `index_users_on_contact`.
Format en base : **toujours les 10 chiffres locaux**, jamais l'indicatif.

## Recherche (connexion)

`ContactConcern.normalize_for_lookup(raw)` — méthode de module dupliquant les étapes 1 et 2 ci-dessus, **sans aucune validation**. Elle est exposée en trois endroits :

- comme méthode de module (`ContactConcern.normalize_for_lookup`) ;
- comme méthode de classe sur les modèles incluant le concern (`Orm::User.normalize_for_lookup`) ;
- appelée directement dans `Identity::SessionsController#create` et `Repositories::Identity::UserRepository#find_by_contact`.

## Fragilités du mécanisme

- La logique est **dupliquée** entre `normalize_contact!` (instance, avec validation) et `normalize_for_lookup` (module, sans validation). Deux chemins à maintenir.
- L'ordre `00225` puis `225` est correct, mais un numéro local ne peut de toute façon pas commencer par `225` (préfixes limités à 01/05/07) — la logique est plus complexe que nécessaire.
- **Deux points d'entrée contournent complètement la normalisation** : `Schoolstaff::TeachersController#create` et `Schoolstaff::StudentsController#create` font `Orm::User.find_by(contact: params[...])` sur la saisie brute. Un directeur qui colle un numéro au format `+225 07 00 00 00 00` ne trouvera jamais l'enseignant.
- Les formulaires imposent en plus, **côté navigateur seulement**, `maxlength: 10` + `pattern "\d{10}"` + un `oninput` qui filtre les caractères non numériques à la frappe — ce qui **empêche l'utilisateur de coller un numéro au format international**, alors que le serveur sait le traiter.

---

# Contexte identity — autorisation

## Mécanique générale

Tout passe par `CurrentUserConcern`, inclus dans `ApplicationController`.

> **Il n'y a ni Pundit, ni CASL, ni objet Policy.** `app/domain/policies/` est annoncé dans le `CLAUDE.md` mais ne contient **aucun fichier** pour identity ou communication. L'autorisation est entièrement faite de `before_action` déclarés contrôleur par contrôleur.

**À chaque requête, sans exception** :

- `before_action :set_current_user` → `Current.user = current_user`
- `current_user` = `Orm::User.find_by(id: session[:user_id]) if session[:user_id]`, mémoïsé dans `@current_user`
- `current_profile` = `current_user&.profile`, mémoïsé

La session est le **cookie signé Rails par défaut** ; il ne contient qu'un entier. **Aucune table `sessions`, aucun jeton, aucune empreinte de navigateur, aucune date d'expiration.**

**Rien d'autre n'est vérifié par défaut.** Il n'existe pas de `before_action :authenticate_user!` global : chaque contrôleur doit déclarer ses gardes, et un contrôleur qui oublie de le faire est ouvert à tous.

## Rôles et helpers générés

`ROLES = %i[student teacher team school_admin parent]`

Pour chacun, le concern définit dynamiquement et expose en `helper_method` :

| Helper | Comportement |
|---|---|
| `student?`, `teacher?`, `team?`, `school_admin?`, `parent?` | `current_user_role == role` |
| `current_student`, `current_teacher`, `current_team`, `current_school_admin`, `current_parent` | renvoient `current_profile` **si et seulement si** le rôle correspond, sinon `nil` |
| `authorize_<role>!` | si le rôle ne correspond pas : `redirect_to root_path, alert: "Accès non autorisé."` |
| `authenticate_<role>!` | `authenticate_user!` puis `authorize_<role>!` si connecté |

Autres helpers : `user_signed_in?`, `current_user_role` (symbole), `creator?`.

**`authenticate_user!`** : si non connecté, répond selon le format —
- HTML : `redirect_to root_path, alert: "Veuillez vous connecter pour continuer."`
- Turbo Stream : `render_turbo_error(...)` → `turbo_stream.prepend("toast-container", partial: "layouts/toast_message", type: :danger)`

**`creator?` = `teacher? || team? || admin?`** — ⚠️ **`admin?` n'est défini nulle part** (le rôle s'appelle `school_admin`, pas `admin`). Conséquence exacte : pour tout utilisateur qui n'est **ni** enseignant **ni** équipe, l'évaluation atteint `admin?` et lève un `NoMethodError` → **erreur 500** sur toute page appelant ce helper. `authorize_creator!` est donc lui aussi cassé pour ces utilisateurs.

## Distinction effective entre rôles

| Zone | Garde déclarée | Rôle effectivement exigé |
|---|---|---|
| `/` (racine) | aucune | public ; redirige si connecté **et** profil présent |
| `/login`, `/logout` | aucune | public |
| `/student-signup`, `/teacher-signup`, `/team-signup`, `/staff-signup`, `/c/:code` | **aucune** | **public** |
| `/students/**` | contrôleurs dédiés | `student` |
| `/teachers/**` | contrôleurs dédiés | `teacher` |
| `/teams/**` | contrôleurs dédiés | `team` |
| `/schoolstaff/**` | `Schoolstaff::BaseController` : `authenticate_user!` + `require_school_admin!` + `set_school` | `school_admin` ; `require_school!` ajoute « école rattachée » sur classrooms / teachers / students |
| `/users` (index, destroy) | `authenticate_team!` | `team` |
| `/users/:public_id` (show) | `authenticate_user!` **seulement** | **tout utilisateur connecté** |
| `/users/:public_id` (edit, update) | `authorize_user_access!` | `team` **ou** le propriétaire |
| `/profile` (edit, update) | `authenticate_user!` | tout connecté, sur soi-même uniquement |
| `/messages` (new, create, edit, update, destroy) | `require_team!` | `team` — alerte « Accès réservé à l'équipe Lnclass. » |
| `/messages` (index, show, dismiss) | `authenticate_user!` | **tout utilisateur connecté** |
| `/install_banner` | `authenticate_user!` | tout connecté |

`Schoolstaff::BaseController#require_school_admin!` compare `current_user.role.to_s == "school_admin"` **en dur**, sans passer par le helper `school_admin?`.

## Le rôle `parent`

Déclaré dans l'enum `Orm::User` (valeur `3`), dans les deux entités `User`, dans `ROLES` du concern, et dans le préfixe `prnt_` du `public_id`.

Mais : **aucune table, aucun contrôleur d'inscription, aucune route, aucun espace, aucun profil**.

`Orm::User#profile` ne traite pas ce cas → renvoie `nil` → `after_sign_in_path_for` renvoie `/` → `HomepageController#user_authentication` ne redirige pas (il exige `current_profile.present?`). Un compte `parent` peut donc exister en base, se connecter, et **rester bloqué sur la page d'accueil publique**.

## Multi-établissements pour les enseignants (ADR-0004)

- **Modèle** : `teacher_schools(teacher_id, school_id)` avec **index unique `[teacher_id, school_id]`**. `Orm::Teacher has_many :schools, through: :teacher_schools`. Un enseignant peut donc légitimement appartenir à N écoles.
- **Comment on y arrive** : une école à l'inscription ; les suivantes **uniquement** par l'action d'un `school_admin` sur `/schoolstaff/teachers/new`. **L'enseignant lui-même ne peut pas ajouter une école.**
- **Ce qui manque** : il n'y a **aucune notion d'école courante ni d'école principale**. `Orm::Teacher#school` et `Entities::Identity::Teacher#school` renvoient tous deux `schools.first`, c'est-à-dire l'ordre d'insertion en base. Il n'y a ni sélecteur d'établissement dans l'interface, ni `session[:current_school_id]`, ni scope par école.
- **Conséquence concrète** : `GetTeacherFeed` appelle `@feed_query.get_levels_for_school(teacher_entity.school_id)` — le feed d'un enseignant multi-établissements n'affiche donc **que les niveaux de sa première école**. Les classes, elles, viennent de `classroom_repo.find_by_teacher(teacher.id)` et sont **toutes écoles confondues**. Le tableau de bord mélange donc deux périmètres différents.
- **Aucune vérification d'appartenance** : rien ne vérifie, quand un enseignant ouvre `/teachers/classrooms/:id`, que la classe appartient à l'une de ses écoles — le contrôle se fait par la liaison `teacher_classrooms`, pas par l'école. (Le détail relève du contexte `classroom`, hors de ce périmètre ; signalé car il conditionne l'ADR-0004.)
- **État** : ⚠️ — le modèle de données supporte le multi-établissements, l'application ne l'exploite pas.

---

# Contexte identity — profils et comptes

## Modification de son profil — trois chemins concurrents

### a) `/profile/edit` → `PATCH /profile` (`ProfilesController`)

- Garde : `authenticate_user!`. Cible : toujours `current_user`.
- Paramètres acceptés depuis **trois emplacements possibles** (`params[:profile]`, `params[:user]`, ou la racine) : `fullname`, `contact`, `gender`, `password`, `password_confirmation`. `compact_blank` retire les valeurs vides.
- Passe par `UseCases::UpdateUserProfile#call(user_id:, attributes:)` → assignation dynamique `user.public_send("#{key}=", value) if user.respond_to?("#{key}=")` → `repository.update`.
- `password_confirmation` est permis mais **jamais transmis à l'ORM** (`UserRepository#map_to_record_attributes` n'envoie que `password`) → **la confirmation est silencieusement ignorée**.
- **Le mot de passe actuel n'est jamais demandé.**
- Succès : redirection `edit_profile_path` + « Profil mis à jour avec succès. »
  Échec : redirection avec un `alert` concaténant les erreurs. Un `rescue StandardError => e` avale toute exception et l'affiche dans le flash.

### b) `/users/:public_id/edit` → `PATCH /users/:public_id` (`Identity::UsersController`)

- Gardes : `authenticate_user!` + `authorize_user_access!` — autorisé si `team?` **ou** `current_user.id == @user.id`, sinon `/` + « Action non autorisée ».
- Permis : `firstname`, `lastname`, `fullname`, `contact`, `gender`, `password`.
- Le rôle courant est ré-injecté dans le DTO (`.merge(role: @user.role)`) pour satisfaire `validates :role, presence: true` → **le rôle n'est jamais modifiable par ce chemin**.
- Chaque attribut n'est affecté que `if dto.<attr>.present?`.
- Succès : `/users/:public_id` + « Profil mis à jour avec succès. »

### c) `/schoolstaff/profile` et `/schoolstaff/settings`

- Profil : permis `fullname`, `contact`, `gender`, `avatar`.
  Réglages : permis `password`, `password_confirmation` **uniquement**.
- Les deux passent par `UseCases::Identity::UpdateUser#execute(id:, attributes:)` → `attributes.each { user.send("#{key}=", value) if user.respond_to?(setter) }`.
- ⚠️ **`avatar` n'est jamais enregistré** : l'entité de domaine `Entities::User` n'a pas de setter `avatar=`, donc le `respond_to?` échoue silencieusement et le fichier est jeté.
- Succès : « Votre profil a été mis à jour. » / « Vos paramètres ont été mis à jour. »
  Échec : `current_user.assign_attributes(...)` (sur l'objet ActiveRecord, dans un contrôleur) + `render … status: :unprocessable_entity`.

- **État global** : ❌ — trois implémentations divergentes de la même intention, avatar cassé, confirmation ignorée, mot de passe actuel jamais exigé.
- **À refaire différemment** : un seul use case, un seul écran, `current_password` obligatoire pour toute modification de mot de passe ou de contact.

---

## Changement de rôle

- **Il n'existe aucun parcours de changement de rôle.** `role` n'est présent dans aucun `permit`, et `Identity::UsersController#update` le ré-injecte depuis l'enregistrement existant.
- Le rôle est fixé **définitivement** à l'inscription, par le contrôleur d'inscription choisi.
- Un utilisateur qui est à la fois enseignant et parent d'élève devrait créer deux comptes — **impossible**, puisque le contact est unique.
- **État** : ❌ (absent)

---

## Annuaire et suppression des utilisateurs

- **Acteur** : `team` (garde `authenticate_team!` sur `index` et `destroy`)
- **Parcours** :
  - `/users` liste `Orm::User.order(created_at: :desc)` mappé en entités — **tous les utilisateurs, sans pagination**, alors que `Pagy::Backend` est inclus dans `ApplicationController`.
  - `/users/:public_id` affiche une fiche.
  - `DELETE /users/:public_id` → « Utilisateur supprimé avec succès. » ou « Erreur lors de la suppression. »
- **Règles métier** :
  - `set_user` fait `find_by_public_id(params[:public_id]) || find_by_id(params[:public_id])` — **l'identifiant entier séquentiel est accepté en repli**.
  - La suppression est un `destroy` en cascade : `dependent: :destroy` sur `student` / `teacher` / `team` / `school_staff`, qui cascadent à leur tour sur `exercise_sessions`, `exercise_badges`, `knowledge_gaps`, `classroom_students`, `teacher_schools`, `teacher_classrooms`.
  - Les objets créés par un `team` (drenas, niveaux, matières, écoles, exercices, messages) sont en `dependent: :nullify` et **survivent**.
  - Aucune confirmation métier, aucun archivage, aucune anonymisation.
- **État** : ⚠️

---

## Bannière d'installation PWA

- **Acteur** : tout utilisateur connecté, `PATCH /install_banner`
- **Règles métier** :
  - Statuts : `not_shown` (0, défaut) · `visible` (1) · `installed` (2) · `refused` (3). Un statut hors enum renvoie `422`.
  - `should_see_install_banner?(user_agent)` renvoie vrai si : **pas** `installed`, **et** le User-Agent contient `iphone`, `android` ou `ipad`, **et** — si `refused` — que `install_banner_last_changed_at` date de **plus de 3 jours**.
  - Le contrôleur écrit directement `current_user.update!` (rien ne passe par le domaine), puis renvoie `204 No Content`.
- **Données** : `users.install_banner_status`, `users.install_banner_last_changed_at`
- **État** : ✅

---

# Contexte communication

> ## ⚠️ Avertissement de cadrage
>
> **Il n'existe aucune messagerie de classe, aucune conversation, aucun échange entre utilisateurs dans ce code.**
>
> Le contexte `communication` est un système **d'annonces unidirectionnelles** publiées par l'équipe Lnclass et diffusées par audience de rôle.
>
> Concrètement, il n'y a : ni destinataire individuel, ni fil de discussion, ni réponse, ni accusé de lecture, ni brouillon partagé, ni table de destinataires, ni table de notifications, ni mention, ni recherche.
>
> Un `message` est une **annonce**, comme le confirment le titre de la page (« Annonces & Messages ») et la formulation des vues.

## Publication d'une annonce

- **Acteur** : un membre `team` **exclusivement**. `before_action :require_team!` sur `new`, `create`, `edit`, `update`, `destroy` → sinon `redirect_to root_path, alert: "Accès réservé à l'équipe Lnclass."`
- **Parcours** : `/messages` → bouton de création (visible uniquement `if team?`) → `GET /messages/new` : formulaire « studio » en 2 colonnes, éditeur riche Trix à gauche, réglages et aperçu live à droite (contrôleur Stimulus `preview`, actions `change->preview#previewImage` et `previewAudio`) → `POST /messages` → redirection `/messages` avec « Message créé avec succès. »

- **Règles métier — exhaustif** :

  | Champ | Libellé | Règle |
  |---|---|---|
  | `name` | « Titre accrocheur » | **obligatoire**, **100 caractères max** (validé sur l'entité *et* sur l'ORM). Normalisé par `Sluggable#normalize_name` en `before_validation` : `strip.titleize` → chaque mot prend une majuscule |
  | `slug` | — | généré par friendly_id depuis `name`, **unique en base**, régénéré dès que `name` change (`should_generate_new_friendly_id?` → `name_changed?`). Sert de `to_param` → URL `/messages/mise-a-jour-du-programme`. **Affiché en clair sur chaque carte** de la vue `_message` |
  | `content` | « Corps du message » | ActionText (`has_rich_text :content`), mise en forme riche via Trix. **Non obligatoire** — aucune validation de présence. Affiché en extrait via `to_plain_text` |
  | `published_at` | « Date de diffusion » | **obligatoire**, `f.date_field`, défaut `Date.today`. Colonne de type **`date`** : pas d'heure → **aucune planification intra-journalière possible** |
  | `audience` | « Audience cible » | **obligatoire**, `f.select`, enum `all: 0`, `students: 1`, `teachers: 2`, `teams: 3` (préfixe `audience_`) |
  | `message_status` | « Statut de publication » | **obligatoire**, boutons radio, enum `draft: 0`, `scheduled: 1`, `published: 2`, `archived: 3` (préfixe `message_`) |
  | `team_id` | — | renseigné par le use case depuis `current_team.id`. `optional: true` côté ORM, `dependent: :nullify` côté `Orm::Team` |
  | `image_cover` | « Image d'illustration » | `has_one_attached`, `f.file_field`, aperçu live. **Aucune validation** de type MIME, de taille ni de dimensions |
  | `message_audio` | « Message vocal » | `has_one_attached`, `f.file_field`, aperçu live. **Aucune validation** non plus |

  - **L'enum `audience` n'a que quatre valeurs** : il n'y a ni audience `school_admin`, ni audience `parent`, ni ciblage par école, par classe, par niveau ou par individu.
  - **Aucun job ni tâche planifiée ne bascule un `scheduled` en `published`** — le statut est purement déclaratif. `archived` n'est déclenché par aucune action d'interface non plus.
  - Supprimer un membre de l'équipe (`team_id` → `nullify`) **conserve ses annonces**, orphelines.
  - La gem `active_storage_validations` est au Gemfile (v4.1.1) mais **n'est utilisée nulle part** sur les messages.
  - Le repository n'assigne une pièce jointe que `if message_entity.image_cover.present?` → **une pièce jointe ne peut jamais être retirée** par une mise à jour, seulement remplacée.
  - En cas d'échec : `@message = Orm::Message.new(message_params)`, erreurs poussées dans `errors[:base]`, rendu `422`.
  - En développement uniquement, `new` pré-remplit le formulaire avec un exemple (« Nouvelle fonctionnalité disponible ! »).

- **Données** : `messages`, `action_text_rich_texts`, `active_storage_attachments` + `active_storage_blobs`
- **État** : ⚠️
- **À refaire différemment** : `published_at` en `datetime` + job de publication des `scheduled` ; valider type et taille des pièces jointes ; permettre le retrait d'une pièce jointe.

---

## Modification d'une annonce

- **Acteur** : `team`
- **Parcours** : `GET /messages/:slug/edit` (même formulaire) → `PATCH /messages/:slug`
  - **HTML** : redirection `/messages` + « Message mis à jour. »
  - **Turbo Stream** : `turbo_stream.replace @message, partial: "messages/message"` — **la carte concernée est remplacée en place**, sans rechargement, plus `render_flash_stream`.
- **Règles métier** :
  - `set_message` fait `Orm::Message.friendly.find(params[:id])` — **aucun filtrage par auteur** : n'importe quel membre `team` édite les annonces de tous les autres.
  - `ManageMessage#execute_update(id:, attributes:)` recharge l'entité via le repository, puis applique dynamiquement chaque clé de `message_params` par `send("#{key}=", value) if message.respond_to?(setter)`, valide, et sauvegarde.
  - Changer le titre **change le slug**, donc casse tout lien déjà partagé vers l'annonce.
- **État** : ⚠️

---

## Suppression d'une annonce

- **Acteur** : `team`
- **Parcours** : bouton « Supprimer » (`button_to`) sur la carte → `DELETE /messages/:slug`
  - **HTML** : redirection `/messages` + « Message supprimé. »
  - **Turbo Stream** : **le carrousel entier est reconstruit** (`turbo_stream.update "messages"` avec le markup complet de la section — contrôleur `carousel`, `snap-x snap-mandatory`, styles `scrollbar-hide` inline), avec rendu de `messages/_empty_state` s'il ne reste rien.
- **Règles métier** :
  - **Suppression physique et immédiate**, sans confirmation métier, sans corbeille, sans archivage. Le statut `archived` existe mais **aucune action ne l'utilise**.
  - Les pièces jointes ActiveStorage et le `ActionText::RichText` suivent en cascade.
  - Aucune vérification d'auteur.
  - `ManageMessage#execute_delete` renvoie `{ success?: false, errors: ["Introuvable"] }` si l'enregistrement n'existe pas — mais **le contrôleur ignore le résultat** et répond systématiquement « Message supprimé. »
  - ⚠️ **Incohérence notable** : le rebuild du carrousel après création ou suppression liste `current_team.messages.ordered`, c'est-à-dire **uniquement les annonces de l'auteur courant**, alors que `index` liste celles de toute l'équipe filtrées par audience. L'affichage change donc de périmètre selon qu'on a agi ou simplement chargé la page.
- **État** : ⚠️
- **À refaire différemment** : soft delete via `archived` ; un seul et même chemin de rendu pour la liste.

---

## Consultation des annonces

- **Acteur** : **tout utilisateur connecté**, quel que soit son rôle — `before_action :authenticate_user!` uniquement
- **Parcours** : `GET /messages` → carrousel horizontal de cartes. Chaque carte est enveloppée dans un `turbo_frame_tag "message_card_<id>"` et rendue par `components/messages/_card` avec `allow_dismiss: true`. Navigation par contrôleur Stimulus `carousel` (défilement fluide, `snap-x snap-mandatory`, flèches `_carousel_nav`), pastilles de pagination affichées `if @messages.size > 1`. État vide dédié (`_empty_state`) si rien à afficher, avec un appel à l'action différent `if team?`.

- **Contenu d'une carte** : image de couverture (ou l'initiale majuscule du titre en repli), titre, extrait du contenu en texte brut, bouton de lecture audio si `message_audio.attached?` (contrôleur Stimulus `audio-player`, source via `rails_blob_path`), badges de statut et d'audience (`humanize`), date formatée, bouton de rejet. La vue `_message` destinée à l'équipe ajoute les liens « Détails », « Éditer » et « Supprimer ».

- **Règles métier — qui voit quoi, exhaustif** (scope `Orm::Message.for_user_role(role)`) :
  - Filtre `published_only` → **seul le statut `published` est visible**. Les `draft`, `scheduled` et `archived` n'apparaissent dans aucune liste.
  - Correspondance rôle → audiences visibles, via `ROLE_TO_AUDIENCE = { "student" => :students, "teacher" => :teachers, "team" => :teams }` :

    | Rôle | Audiences visibles |
    |---|---|
    | `student` | `all`, `students` |
    | `teacher` | `all`, `teachers` |
    | `team` | `all`, `teams` |
    | `school_admin` | **`all` uniquement** |
    | `parent` | **`all` uniquement** |

    (la clé n'existant pas dans la table, le scope retombe sur `audiences = [:all]`)
  - Tri : `published_at DESC`, puis `created_at DESC`.
  - Les annonces écartées en session sont exclues (`where.not(id: dismissed_ids)`).
  - Chargement anticipé : `includes(:rich_text_content).with_attached_image_cover.with_attached_message_audio`.
  - ⚠️ **`index` interroge directement `Orm::Message`**, pas le repository — violation de couche assumée. Le repository expose pourtant `find_for_user_role(role, dismissed_ids:)`, qui fait exactement cela et **n'est appelé nulle part** 💀.
  - En développement uniquement, si la liste est vide, **trois annonces factices** sont injectées (« Mise à jour du programme de Terminale C », « Fermeture exceptionnelle ce vendredi », « Bienvenue sur le nouveau tableau de bord »), avec des **méthodes de singleton définies à la volée** (`def m.content`, `def m.image_cover`, `def m.message_audio`) pour imiter l'interface de l'ORM dans la vue.

- **Historique** : il n'y en a pas au sens propre. Toutes les annonces `published` restent visibles indéfiniment, **sans pagination**, sans archivage automatique, sans limite de date. La seule réduction du volume est le rejet en session.

- **Données** : `messages`
- **État** : ⚠️

---

## Annonces dans les fils d'actualité (feeds)

- **Acteur** : élève, enseignant, équipe — sur leur page d'accueil respective
- **Parcours** : les annonces récentes sont un bloc de `/students`, `/teachers` et `/teams`, en plus de la page `/messages` dédiée.

- **Règles métier** — **trois Query Objects distincts, aux comportements différents** :

  | Query | Méthode | Filtrage | Limite |
  |---|---|---|---|
  | `StudentFeedQuery` | `get_recent_messages(limit: 5)` | `for_user_role("student")` → `published` + `[all, students]` | 5 |
  | `TeachersFeedQuery` | `get_recent_messages(limit: 5)` | `for_user_role("teacher")` → `published` + `[all, teachers]` | 5 |
  | `TeamsFeedQuery` | `get_recent_messages(limit: 10)` | **aucun** — `Orm::Message.ordered` seulement | 10 |

  - ⚠️ **Le feed équipe ne filtre ni par statut, ni par audience** : il affiche les brouillons, les annonces planifiées, les archivées et celles destinées aux élèves ou aux enseignants. Défendable pour un back-office, mais ce n'est écrit nulle part et le comportement **diverge de `/messages` pour le même utilisateur**.
  - Les trois appliquent le même chargement anticipé (`rich_text_content`, `image_cover`, `message_audio`).
  - **Le rejet en session n'est pas appliqué dans les feeds** : une annonce écartée sur `/messages` réapparaît sur le fil d'actualité.
  - `/schoolstaff` n'affiche **pas d'annonces du tout**.

- **État** : ⚠️
- **À refaire différemment** : une seule source de vérité pour « les annonces visibles par cet utilisateur ».

---

## Écarter une annonce de son fil

- **Acteur** : tout utilisateur connecté
- **Parcours** : bouton croix en haut de la carte → `DELETE /messages/:slug/dismiss` (`button_to`, `form: { data: { turbo_frame: "message_card_<id>" } }`) → réponse Turbo Stream `turbo_stream.remove("message_card_<id>")` → la carte disparaît sans rechargement.
- **Règles métier** :
  - L'identifiant est ajouté à **`session[:dismissed_messages]`**, un tableau dans le cookie de session, dédupliqué par `uniq!`.
  - Conséquences : le rejet est **perdu à la déconnexion** (et, faute de `reset_session`, il **survit même au changement d'utilisateur** sur le même navigateur), n'est **pas partagé entre appareils**, n'est **pas persisté en base**, et n'est **pas réversible** (aucun « réafficher »).
  - Le tableau croît **sans borne** dans un cookie limité à 4 Ko.
  - **Aucune vérification** que l'annonce était visible par cet utilisateur : n'importe quel identifiant est accepté.
  - `dismiss` ne répond qu'en `format.turbo_stream` — un appel HTML classique échoue.
- **Données** : aucune — uniquement la session
- **État** : ⚠️
- **À refaire différemment** : table `message_dismissals (user_id, message_id, dismissed_at)` avec index unique sur le couple.

---

## Diffusion temps réel

**Réponse nette : il n'y en a aucune.**

- `solid_cable` est déclaré dans `config/cable.yml` (`adapter: solid_cable`), et c'est la **seule** occurrence du mot dans tout le projet.
- **Aucun `broadcast_to`, `broadcast_replace_to`, `broadcast_append_to`** ou équivalent dans `app/`.
- **Aucun `turbo_stream_from`** dans aucune vue.
- **Aucun canal ActionCable** exploité.
- Tous les Turbo Streams du contexte sont des **réponses synchrones à la requête de leur propre auteur** : `create.turbo_stream.erb`, `update.turbo_stream.erb`, `destroy.turbo_stream.erb` et la réponse de `dismiss`. **Personne d'autre que l'auteur ne reçoit quoi que ce soit.**

**Conséquence pratique** : un élève connecté ne verra une nouvelle annonce **qu'au prochain chargement de page**. Aucune notification poussée, aucun badge de compteur, aucun son.

- **État** : ❌ — capacité provisionnée dans la configuration, jamais branchée dans le code.

---

## Toasts (notifications d'interface)

- **Acteur** : le système, sur toute page
- **Parcours** : `app/views/layouts/_toast_message.html.erb` rend trois choses :
  1. un conteneur `#toast-container` fixé en haut à droite (`data-controller="toast-container"`, `data-turbo-permanent` pour survivre aux navigations Turbo) ;
  2. le composant `components/_toast` ;
  3. un bloc `#flash-handler` qui traduit chaque entrée de `flash` en élément déclencheur Stimulus (`data-controller="toast-trigger"`, avec `type-value` et `message-value`).
- **Règles métier** :
  - Mapping **unique et binaire** : `flash[:notice]` → type `success` ; **toute autre clé** (`alert`, `warning`, `error`, …) → type `danger`. Il n'existe donc que **deux apparences possibles**, quelle que soit la clé utilisée.
  - En réponse Turbo Stream, `CurrentUserConcern#render_turbo_error(message)` fait un `turbo_stream.prepend("toast-container", partial: "layouts/toast_message", locals: { message:, type: :danger })`. Un helper `render_flash_stream` est utilisé par les trois vues Turbo Stream des annonces.
- **Données** : **aucune**. Ce ne sont pas des notifications persistées : rien n'est stocké, rien n'est relisable, il n'existe **aucune table `notifications`** dans le projet.
- **État** : ✅ pour ce que c'est — un affichage éphémère de flash, **à ne pas confondre avec un système de notifications**.

---

## Ce qu'il faut retenir pour la refonte du contexte communication

Le besoin réellement couvert aujourd'hui est :

> **« L'équipe Lnclass publie une annonce riche — titre, texte formaté, image, audio — ciblée sur une catégorie de rôle, et chaque utilisateur peut la masquer de son fil. »**

Rien de plus.

Si « messagerie de classe » est l'objectif du nouveau projet, alors **tout est à construire** : modèle de conversation, destinataires, persistance des lectures et des rejets, diffusion temps réel (solid_cable est prêt mais vierge), pièces jointes validées, et un modèle d'autorisation qui réponde à la question **« qui peut écrire à qui »** — question qui **ne se pose pas** dans le code actuel, puisque seule l'équipe écrit et que personne ne répond.

---

# 1. Tables, colonnes et index

## `users`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `contact` | string(10) | NOT NULL · **index unique** `index_users_on_contact` |
| `firstname` | string | NOT NULL |
| `lastname` | string | NOT NULL |
| `fullname` | string(150) | NOT NULL |
| `gender` | string | nullable · validé `male`/`female` au DTO seulement, **aucune contrainte en base** |
| `password_digest` | string | NOT NULL · bcrypt via `has_secure_password` |
| `public_id` | string | NOT NULL · **index unique** `index_users_on_public_id` |
| `slug` | string | NOT NULL · **index unique** `index_users_on_slug` · friendly_id sur `fullname` |
| `role` | integer | NOT NULL · défaut `0` · **index** `index_users_on_role` |
| `is_demo` | boolean | NOT NULL · défaut `false` |
| `install_banner_status` | integer | NOT NULL · défaut `0` |
| `install_banner_last_changed_at` | datetime | nullable |
| `created_at`, `updated_at` | datetime | NOT NULL |

- Enum `role` : `team: 0`, `teacher: 1`, `student: 2`, `parent: 3`, `school_admin: 4`.
  ⚠️ **Défaut `0` = `team`** — un enregistrement créé sans rôle explicite devient membre de l'équipe.
- **Aucune colonne `email`** (l'entité `Entities::Identity::User` expose pourtant un attribut `email`, toujours `nil`).
- Avatar via `active_storage_attachments` (`record_type: "Orm::User"`, `name: "avatar"`).
- Scopes : `student`, `teacher`, `team` (pas de scope pour `school_admin` ni `parent`).

## `students`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | bigint | NOT NULL · index `index_students_on_user_id` — **non unique** |
| `matricule` | string(15) | nullable · index `index_students_on_matricule` — non unique |
| `created_at`, `updated_at` | datetime | NOT NULL |

## `teachers`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | bigint | NOT NULL · index — **non unique** |
| `material_id` | bigint | nullable · index `index_teachers_on_material_id` |
| `created_at`, `updated_at` | datetime | NOT NULL |

## `teacher_schools`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `teacher_id` | bigint | NOT NULL · index |
| `school_id` | bigint | NOT NULL · index |
| `created_at`, `updated_at` | datetime | NOT NULL |

**Index unique `[teacher_id, school_id]`** (`index_teacher_schools_on_teacher_id_and_school_id`) — la seule contrainte composite correcte du contexte.

## `teams`

`id` (PK) · `user_id` bigint NOT NULL, index **non unique** · `created_at`, `updated_at` NOT NULL.
Aucune autre colonne : le rôle `team` ne porte **aucune donnée propre**.

## `school_staffs`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | bigint | NOT NULL · index — non unique |
| `school_id` | bigint | NOT NULL · index |
| `school_role_id` | bigint | **NOT NULL** · index |
| `created_at`, `updated_at` | datetime | NOT NULL |

Aucune contrainte d'unicité sur `[user_id, school_id]` : un même membre peut être inséré plusieurs fois dans la même école.

## `school_roles`

`id` (PK) · `name` string **nullable** · `school_id` bigint NOT NULL, index · timestamps.

Pas d'unicité sur `[school_id, name]`, alors que `find_or_create_by(school_id:, name: "Direction")` s'appuie dessus → doublons possibles en concurrence.

## `classroom_students` — frontière identity / classroom

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `student_id` | bigint | NOT NULL · index |
| `classroom_id` | bigint | NOT NULL · index |
| `primary` | boolean | NOT NULL · défaut `false` |
| `joined_at` | datetime | nullable |
| `created_at`, `updated_at` | datetime | NOT NULL |

**Index unique `[student_id, classroom_id]`**.
Aucune contrainte ne garantit **un seul** `primary: true` par élève — ni index partiel, ni validation applicative.

## `messages`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | string(100) | NOT NULL |
| `slug` | string | NOT NULL · **index unique** `index_messages_on_slug` |
| `audience` | integer | NOT NULL · **pas de défaut** |
| `message_status` | integer | NOT NULL · **pas de défaut** |
| `published_at` | **date** | NOT NULL — type `date`, pas `datetime` |
| `team_id` | bigint | nullable · index · `dependent: :nullify` |
| `created_at`, `updated_at` | datetime | NOT NULL |

- Enum `audience` : `all: 0`, `students: 1`, `teachers: 2`, `teams: 3` (préfixe `audience_`).
- Enum `message_status` : `draft: 0`, `scheduled: 1`, `published: 2`, `archived: 3` (préfixe `message_`).
- ⚠️ **Aucun index sur `audience`, `message_status` ni `published_at`** — le scope `for_user_role` filtre pourtant sur les trois et trie sur `published_at`.
- Contenu riche : `action_text_rich_texts` (`record_type: "Orm::Message"`, `name: "content"`, index unique `[record_type, record_id, name]`).
- Pièces jointes : `active_storage_attachments` (`name` = `image_cover` ou `message_audio`).

## Tables absentes du projet

`sessions` · `parents` · `notifications` · `message_recipients` · `message_reads` · `message_dismissals` · `conversations` · `password_reset_tokens` · `audit_logs` · `roles` / `permissions`.

---

# 2. Règles métier implicites à rendre explicites

1. **Le dernier mot du nom complet est le prénom ; tout ce qui précède est le nom de famille.** Convention ivoirienne inversée, nulle part documentée, appliquée par `UsernameConcern#set_fullname_fields` **et** dupliquée dans `Entities::User#set_name_fields`. Elle casse sur tout prénom composé : « Kouassi Jean Baptiste » → prénom « Baptiste », nom « Kouassi Jean ».
2. **Le nom complet doit contenir au moins deux mots**, sinon « doit contenir au moins deux mots (nom et prénom). » — un nom mononymique est impossible.
3. **Le nom est re-capitalisé mot par mot** (`strip.split.map(&:capitalize).join(" ")`) : « KOFFI JULES » devient « Koffi Jules », « d'Almeida » devient « D'almeida ».
4. **Le mot de passe est un code PIN à 4 chiffres** — imposé uniquement par `maxlength: 4` et `pattern "\d{4}"` côté navigateur. **Aucune validation serveur** de longueur, de format ni de complexité : `has_secure_password` n'impose que la présence et la limite bcrypt de 72 octets.
5. **Le `public_id` encode le rôle en clair** : `team_`, `tch_`, `stdt_`, `prnt_`, `sadm_`, suivis de 14 caractères base58. Il est utilisé comme `to_param` → le rôle de chaque utilisateur est lisible dans toutes les URL.
6. **La génération du `public_id` est dupliquée** en trois endroits (`Orm::User#set_public_id` en `before_create`, `Entities::Identity::User#generate_public_id!` dans le constructeur, et la table de préfixes elle-même). Seule celle de l'ORM fait foi en pratique.
7. **L'école, le niveau et la série d'un élève ne sont jamais stockés** : ils sont dérivés à la volée de `primary_classroom`. Changer un élève de classe réécrit rétroactivement son école et son niveau dans tout l'historique affiché.
8. **La classe principale d'un élève** = première liaison `primary: true`, sinon `classrooms.first`. Le drapeau n'est posé que par le chemin d'inscription ; l'ajout par la direction ne le pose pas.
9. **L'école d'un enseignant** = `schools.first`, c'est-à-dire l'ordre d'insertion. Pas d'école principale, pas d'école courante, pas de sélecteur.
10. **Un `school_admin` reçoit d'office un rôle d'école nommé « Direction »**, créé à la volée. Le concept de `school_role` existe en base et a son propre écran, mais n'est jamais choisi à l'inscription.
11. **Le rôle `parent` existe dans l'enum, les entités, les helpers et les préfixes de `public_id`, sans aucune table, aucun formulaire et aucun espace.**
12. **Un enseignant sans classe est renvoyé vers la sélection de classes à chaque connexion.** La complétion de l'onboarding est déduite de `classrooms.empty?` — ce n'est pas un état persisté, donc un enseignant qui retire toutes ses classes retombe en onboarding.
13. **Le rôle par défaut en base est `team`** (`role` integer, défaut `0`).
14. **Un `school_admin` et un `parent` ne voient que les annonces d'audience « Tous »** — aucune valeur de l'enum `audience` ne leur correspond.
15. **Le statut `scheduled` d'une annonce ne fait rien** : aucun job, aucune tâche planifiée ne bascule une annonce de `scheduled` à `published`.
16. **`published_at` est une date, pas un instant** : deux annonces du même jour sont départagées par `created_at DESC`.
17. **Les annonces « écartées » le sont pour la durée de la session seulement**, dans le cookie, non partagé entre appareils.
18. **`current_team.messages` (Turbo Stream) et `Orm::Message.for_user_role` (chargement de page) sont deux définitions concurrentes de « les annonces »** : après création ou suppression, le carrousel se reconstruit avec les seules annonces de l'auteur courant, puis redevient global au rechargement.
19. **`valid_password?` recharge l'enregistrement depuis la base à chaque appel** — l'entité de domaine ne porte jamais le condensat, par choix.
20. **`UserRepository#map_to_entity` ne mappe ni `created_at`, ni `updated_at`, ni `password_digest`, ni `install_banner_*`** : une entité rechargée puis re-sauvegardée sans mot de passe conserve l'ancien. Comportement voulu, mais nulle part écrit.
21. **`Orm::User#should_generate_new_friendly_id?` renvoie `fullname_changed?`** : changer son nom change son `slug`, donc casse toute URL déjà partagée.
22. **`Sluggable#normalize_name` applique `titleize`** au titre des annonces : « Fermeture exceptionnelle ce vendredi » devient « Fermeture Exceptionnelle Ce Vendredi ». Aucune interface ne prévient l'auteur.
23. **Deux jeux d'entités coexistent** : `Entities::User` / `Entities::Student` / `Entities::Teacher`… à la racine (legacy, avec `user_id` scalaire) et `Entities::Identity::User` / `::Student`… namespacés (ADR-0021, avec un objet `user` composé). **Tout le code d'exécution utilise les entités legacy de la racine** ; les entités namespacées ne sont référencées que par leurs tests 💀. La migration ADR-0021 est écrite mais pas branchée.

---

# 3. Failles et fragilités de sécurité

> Section descriptive : les points ci-dessous sont **nommés**, pas exploités.

## Critiques

1. **`/team-signup` est une route publique et non authentifiée qui crée un compte au rôle `team`** — le plus privilégié de la plateforme : écriture complète du catalogue, `index` et `destroy` sur tous les utilisateurs, publication d'annonces. Aucune invitation, aucun code, aucune validation. **Élévation de privilèges en un formulaire de quatre champs.**
2. **`/staff-signup` permet à n'importe qui de se déclarer administrateur de n'importe quel établissement** : `school_id` est choisi librement dans une liste publique. Donne accès à la liste nominative des élèves et enseignants de cette école, et au rattachement d'enseignants.
3. **PIN à 4 chiffres (10 000 combinaisons) + identifiant = numéro de téléphone public + aucune limitation de tentatives sur `/login`.** Aucun `rate_limit` (pourtant natif en Rails 8), aucun verrouillage, aucun délai, aucun journal d'échec. Un compte donné est forçable en quelques minutes ; l'ensemble des comptes d'une classe l'est en masse, les numéros ivoiriens étant fortement structurés.
4. **Inscription « prepa » : mot de passe vide → le mot de passe devient le numéro de téléphone** (`user_attrs[:password] = user_attrs[:contact]`), c'est-à-dire l'identifiant de connexion lui-même, qui est public. Tout élève inscrit par ce chemin sans saisir de PIN a un compte ouvert.
5. **`config.force_ssl` est commenté en production** (`config/environments/production.rb:31`) : le cookie de session, qui porte à lui seul toute l'authentification, peut transiter en clair.

## Élevées

6. **Aucun `reset_session` à la connexion** → fixation de session possible : un identifiant de session posé avant l'authentification reste valide après.
7. **Aucun `reset_session` à la déconnexion** : seul `session[:user_id]` est effacé. L'identifiant de session reste valide et le reste du contenu (`dismissed_messages`) passe d'un utilisateur à l'autre sur le même navigateur.
8. **Aucune expiration de session** : pas de `expire_after`, pas de `last_seen_at`, pas de révocation. Un cookie volé vaut indéfiniment.
9. **Changement de mot de passe sans le mot de passe actuel**, sur trois écrans (`PATCH /profile`, `PATCH /users/:public_id`, `PATCH /schoolstaff/settings`). Une session volée devient une prise de contrôle définitive du compte.
10. **`password_confirmation` est accepté par les formulaires mais jamais transmis à l'ORM** : `UserRepository#map_to_record_attributes` n'envoie que `password`. La confirmation est silencieusement ignorée — une faute de frappe verrouille définitivement le compte, et **il n'existe aucun parcours de récupération**.
11. **Assignation dynamique non filtrée dans les use cases** : `UseCases::Identity::UpdateUser` et `UseCases::UpdateUserProfile` font `attributes.each { user.send("#{key}=", value) if user.respond_to?(setter) }`. Aucune liste blanche au niveau du domaine — la seule barrière est le `permit` du contrôleur. Ajouter `:role` ou `:public_id` à un `permit`, ou appeler ces use cases depuis un nouveau point d'entrée, donne une élévation de privilèges immédiate. `Entities::User` expose bien `role=` et `public_id=`.
12. **`GET /users/:public_id` n'est protégé que par `authenticate_user!`** : tout utilisateur connecté, y compris un élève de sixième, peut afficher la fiche de n'importe quel autre utilisateur — nom complet, numéro de téléphone, rôle. `authorize_user_access!` ne couvre que `edit` et `update`.
13. **`set_user` accepte l'identifiant entier en repli** : `find_by_public_id(params[:public_id]) || find_by_id(params[:public_id])`. L'identifiant séquentiel annule l'intérêt du `public_id` opaque et permet d'énumérer tous les comptes de la plateforme par incrément (`/users/1`, `/users/2`…).
14. **`MessagesController#show` charge n'importe quelle annonce par son slug sans aucun filtre** — ni sur `message_status`, ni sur `audience`. Un élève peut lire un brouillon, une annonce archivée ou une annonce destinée aux enseignants s'il en connaît le slug. Or les slugs sont dérivés du titre (donc devinables) **et affichés en clair sur chaque carte** de `/messages`.
15. **`MessagesController#edit|update|destroy` ne vérifient jamais l'auteur** : `set_message` fait `Orm::Message.friendly.find(params[:id])` sans scope. Tout membre `team` modifie et supprime les annonces de tous les autres.

## Moyennes

16. **`creator?` appelle `admin?`, méthode inexistante** → `NoMethodError` (500) pour tout utilisateur qui n'est ni `teacher` ni `team`, sur toute page utilisant ce helper. Panne fonctionnelle doublée d'un risque de fuite de trace selon la configuration d'environnement.
17. **Aucune validation des pièces jointes** `image_cover` et `message_audio` : ni type MIME, ni taille, ni nombre — alors que la gem `active_storage_validations` est au Gemfile (v4.1.1). Dépôt de fichier arbitraire par un compte `team`, dont on a vu qu'il est librement créable (faille n°1).
18. **`session[:dismissed_messages]` grossit sans borne** dans le cookie de session (limite 4 Ko). Au-delà, le cookie est rejeté par le navigateur et l'utilisateur est déconnecté sans explication. `dismiss` accepte de plus n'importe quel identifiant sans vérifier que l'annonce était visible.
19. **Énumération de comptes** via `/schoolstaff/teachers/new` et `/schoolstaff/students/new` : « Enseignant introuvable avec ce numéro de contact. » distingue explicitement l'existence d'un compte. (`/login` est correct sur ce point, avec un message unique.)
20. **Mot de passe affiché en clair à l'écran** : les formulaires enseignant, équipe, administrateur d'établissement et élève utilisent `f.text_field :password`, pas `f.password_field`. Seul le formulaire « prepa » masque la saisie. Sur un poste partagé ou en salle de classe, le PIN est lisible par-dessus l'épaule.
21. **Inscription élève non transactionnelle** : si la création du profil `Student` échoue, l'utilisateur reste créé orphelin — il occupe le numéro de téléphone (index unique) et **empêche toute réinscription**, sans moyen de récupération. Le code le reconnaît (« Cleanup user if student fails? (Simple version: no) »).
22. **Pas d'index unique sur `students.user_id`, `teachers.user_id`, `teams.user_id`, `school_staffs.user_id`** alors que les associations sont des `has_one` : des profils dupliqués sont possibles en base, et `has_one` en choisira un arbitrairement.
23. **`MessageRepository#find_by_slug` comporte un `return` dans un bloc `ensure`** : il avale toute exception, y compris celles sans rapport avec un enregistrement manquant, et référence `record` potentiellement non défini. Toute erreur de base y devient un silence.
24. **Contact non normalisé** dans `Schoolstaff::TeachersController#create` et `StudentsController#create` — échec silencieux sur tout format international.
25. **Fuite d'objets ActiveRecord dans le domaine** (bug connu, **confirmé**) : `Repositories::Communication::MessageRepository#map_to_entity` affecte `content: record.content` (`ActionText::RichText`), `image_cover: record.image_cover` et `message_audio: record.message_audio` (`ActiveStorage::Attached::One`) à `Entities::Message`. L'entité transporte donc des objets branchés à la base, sur lesquels les vues appellent `.attached?` et `url_for(...)`. **Le contournement adopté ailleurs est pire** : `MessagesController#index` court-circuite entièrement le repository et interroge `Orm::Message` directement.
26. **`MessagesController#index` injecte des données factices en développement** avec des méthodes de singleton définies à la volée. Gardé par `Rails.env.development?` seulement — les environnements intermédiaires n'ont pas été vérifiés.
27. **Aucun journal d'audit** : ni sur les connexions, ni sur les changements de mot de passe, ni sur les suppressions d'utilisateurs, ni sur les rattachements d'enseignants à un établissement.

---

# 4. Ce que je n'ai pas pu déterminer

- **Le devenir du rôle `parent`** : présent dans l'enum, les deux entités `User`, les helpers du concern et le préfixe `prnt_`, mais sans table, formulaire, route, espace ni test. Impossible de dire s'il s'agit d'une intention abandonnée ou d'une fonctionnalité prévue — rien dans le code ni dans les ADR consultés ne tranche.
- **Pourquoi `solid_cable` est configuré** : `config/cable.yml` déclare l'adaptateur, mais il n'existe **aucun canal, aucun `broadcast_*`, aucun `turbo_stream_from`** dans `app/`. Provisionnement par défaut, préparation pour les annonces, ou vestige d'une messagerie envisagée — indéterminable.
- **L'intention derrière `prepa_status` et `prepa_joined_at`** : passés au use case d'inscription prepa, jamais persistés (aucune colonne). Un `Teachers::PrepaAcquisitionsController` existe, ainsi qu'un `teacher_entity.prepa_gains` consommé par le feed enseignant — un modèle économique (classes de révision payantes, commission enseignant ?) semble esquissé. Ce périmètre déborde de la mission et n'a pas été exploré.
- **`users.is_demo`** : présent en base, mappé dans les entités et délégué par `Orm::Student`, mais l'endroit où il est positionné à `true` et ce qu'il change fonctionnellement n'ont pas été identifiés.
- **`students.matricule`** (string 15, indexé) : renseigné par aucun formulaire ni aucun use case d'inscription lu. Le repository l'écrit s'il est fourni, mais rien ne le fournit. Origine et usage inconnus.
- **`config/initializers/content_security_policy.rb`** : le fichier existe, il n'a pas été ouvert. Aucune affirmation n'est faite sur son contenu ni sur son activation.
- **L'attribut `email`** de `Entities::Identity::User` : aucune colonne correspondante. Vestige d'un schéma antérieur ou anticipation — indéterminable.
- **Le comportement en environnement intermédiaire** : une branche `Staging` existe dans le dépôt, non inspectée. Les gardes `Rails.env.development?` (données factices des annonces, valeurs pré-remplies du formulaire de création) pourraient s'y comporter autrement.
- **L'état d'avancement de la bascule ADR-0021** : les deux jeux d'entités coexistent, seul le legacy est exécuté. Aucun chantier documenté décrivant l'échéance ou le périmètre restant n'a été trouvé.

---

# Annexe — fichiers de référence

Chemins absolus, pour retrouver une règle précise sans relire tout le code.

## Identity

| Sujet | Fichier |
|---|---|
| Connexion / déconnexion | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/identity/sessions_controller.rb` |
| Session, rôles, gardes | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/concerns/current_user_concern.rb` |
| Redirection post-connexion | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/application_controller.rb` |
| Format et normalisation du contact | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/models/concerns/contact_concern.rb` |
| Découpage du nom | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/models/concerns/username_concern.rb` |
| Modèle utilisateur, enum des rôles, `public_id` | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/orm/user.rb` |
| Inscription élève | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/identity/students/registrations_controller.rb` |
| Inscription élève par lien de classe | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/students/prepa_registrations_controller.rb` |
| Inscription enseignant | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/teachers/registrations_controller.rb` |
| Inscription équipe | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/teams/registrations_controller.rb` |
| Inscription direction | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/school_admins/registrations_controller.rb` |
| Use cases d'inscription | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/identity/` |
| Repository utilisateur (mapping, transaction) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/repositories/identity/user_repository.rb` |
| Espace direction (gardes, école) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/schoolstaff/base_controller.rb` |
| Profils (3 chemins concurrents) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/profiles_controller.rb`, `app/controllers/identity/users_controller.rb`, `app/controllers/schoolstaff/profiles_controller.rb`, `app/controllers/schoolstaff/settings_controller.rb` |

## Communication

| Sujet | Fichier |
|---|---|
| Contrôleur des annonces | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/controllers/messages_controller.rb` |
| Scope `for_user_role`, enums, `ROLE_TO_AUDIENCE` | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/orm/message.rb` |
| Entité message | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/entities/message.rb` |
| Use case CRUD | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/domain/use_cases/communication/manage_message.rb` |
| Repository (fuite ActiveRecord, `ensure`/`return`) | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/repositories/communication/message_repository.rb` |
| Feed équipe — absence de filtrage | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/queries/teams_feed_query.rb` |
| Feed élève / enseignant | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/infrastructure/queries/student_feed_query.rb`, `app/infrastructure/queries/teachers_feed_query.rb` |
| Toasts | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/layouts/_toast_message.html.erb` |
| Vues des annonces | `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/messages/` et `app/views/components/messages/_card.html.erb` |
