# Inventaire fonctionnel — contextes bornés **classroom** et **school**

> Document d'entrée pour la réécriture complète de Lnclass dans un nouveau projet Rails.
> Il décrit **ce que l'application fait**, pas comment elle le fait. Chaque feature doit pouvoir être recodée à partir de cette seule lecture.
>
> Périmètre : classes, adhésion par code, assignation polymorphe de ressources, élèves de démonstration, DRENA, écoles, personnel scolaire.
> Hiérarchie administrative de référence : **DRENA ➔ École ➔ Classe** (ADR-0023).

**Légende d'état** : ✅ fonctionne · ⚠️ fonctionne mais fragile ou incomplet · ❌ cassé à l'exécution · 💀 code mort (jamais atteint)

---

# A. CONTEXTE SCHOOL

## A1. Créer un établissement scolaire dans une DRENA

- **Acteur** : tout utilisateur connecté (l'intention était « équipe Lnclass »)
- **Parcours** : `/drenas/:drena_slug` → bouton « Nouvelle école » → `/drenas/:drena_id/schools/new` → formulaire (nom, sigle, statut, type) → POST → redirection vers la fiche DRENA avec toast « École créée avec succès. » Immédiatement après la création, **les classes par défaut et les élèves de démonstration sont générés en synchrone** (voir A5).
- **Règles métier** :
  - `name` obligatoire, max 200 caractères, **unique globalement** (index unique sur `schools.name`), normalisé par `strip` puis `titleize`
  - `schoolsigle` max 10 caractères, facultatif
  - `schoolstatus` ∈ `{draft, active, inactive}` (stocké en string), obligatoire en base
  - `schooltype` ∈ `{privée: 0, public: 1, mixte: 2}` (enum entier), obligatoire en base
  - `slug` généré par FriendlyId à partir du nom, regénéré si le nom change ; unique globalement
  - `public_id` = `SecureRandom.base58(14)`, posé avant création
  - `drena_id` obligatoire (NOT NULL) ; `team_id` facultatif, renseigné avec l'équipe courante
  - **Aucune vérification de rôle** : seul `authenticate_user!` est posé — un élève connecté peut créer, modifier et supprimer une école
- **Données** : `schools`
- **État** : ⚠️ (trou d'autorisation ; le DTO ne valide que `name` alors que l'ORM exige aussi statut et type, donc la moitié des échecs remontent en erreurs ORM brutes)
- **À refaire différemment** : aligner les validations DTO / entité / base, et réserver la création à l'équipe.

## A2. Consulter, modifier, supprimer une école

- **Acteur** : tout utilisateur connecté
- **Parcours** : `/schools` (liste avec recherche plein texte `name ILIKE %query%`) → `/schools/:slug` affiche l'école et **la liste de ses classes**, filtrable par nom, commutable grille/liste via `params[:view]`, en Turbo Stream. Édition et suppression depuis la même page.
- **Règles métier** :
  - Le filtre de classes s'applique **en mémoire Ruby**, insensible à la casse (pas de requête SQL)
  - Chaque carte de classe affiche **son code d'adhésion en clair**
  - La suppression d'une école **détruit en cascade** : toutes ses classes → leurs `classroom_students`, `teacher_classrooms`, `classroom_assignments` ; ainsi que `teacher_schools`, `school_roles`, `school_staffs`. Aucune confirmation métier, aucun soft delete.
- **Données** : `schools`, `classrooms`
- **État** : ✅ (fonctionne, mais destructeur et non protégé)

## A3. Importer des écoles en masse depuis un fichier JSON

- **Acteur** : tout utilisateur connecté, depuis la fiche d'une DRENA
- **Parcours** : upload d'un ou plusieurs fichiers → écriture dans `tmp/imports/<uuid>_<nom>` → un job asynchrone par fichier → redirection « L'import de vos établissements est en cours. »
- **Règles métier** :
  - Clés JSON acceptées avec alias français : `name|nom`, `schoolsigle|sigle`, `schoolstatus|status|statut` (défaut `"active"`), `schooltype|type` (défaut `"public"`)
  - Une ligne est **ignorée silencieusement** si le nom est vide ou si une école existe déjà avec le slug `name.parameterize`
  - Chaque école importée déclenche **aussi** la génération des classes par défaut + élèves de démonstration (A5) — un import de 50 écoles crée des milliers de comptes élèves
  - Le fichier temporaire est supprimé dans un `ensure`
- **Données** : `schools`, `classrooms`, `users`, `students`, `classroom_students`
- **État** : ✅
- **À refaire différemment** : aucun rapport d'import — l'utilisateur ne sait jamais ce qui a été ignoré ni pourquoi.

## A4. S'inscrire comme administrateur d'établissement

- **Acteur** : visiteur anonyme
- **Parcours** : `/staff-signup` → choix d'une DRENA puis d'une école (liste rechargée en AJAX via `/api/v1/schools?drena_id=`) + nom complet, contact, mot de passe, genre → compte créé, **session ouverte immédiatement**, redirection vers `/schoolstaff` avec « Bienvenue ! Votre compte a été créé avec succès. »
- **Règles métier** :
  - Rôle forcé à `school_admin`
  - Création **transactionnelle** : `users` + `school_staffs`. Si le staff échoue, rollback complet.
  - Le rôle interne attribué est **« Direction »**, créé à la volée (`find_or_create_by(school_id:, name: "Direction")`) si l'école n'en possède pas encore
  - Unicité : un utilisateur ne peut être staff qu'une fois par école (message : « est déjà membre du staff de cette école »)
  - **Aucune validation d'appartenance réelle** : n'importe qui peut se déclarer administrateur de n'importe quel établissement du pays
- **Données** : `users`, `school_staffs`, `school_roles`
- **État** : ⚠️ (fonctionne, ouvert à tous)
- **À refaire différemment** : passer par une invitation émise par l'établissement, ou une validation par l'équipe Lnclass.

## A5. Générer automatiquement les classes par défaut d'un nouvel établissement

- **Acteur** : le système, à la création d'une école (A1 et A3)
- **Parcours** : invisible pour l'utilisateur — les classes apparaissent déjà créées et peuplées sur la fiche école
- **Règles métier — table de configuration exacte** :

  | Niveau | École **public** | École **privée** |
  |---|---|---|
  | 6ème | 4 classes | 2 |
  | 5ème | 4 | 2 |
  | 4ème | 10 | 4 |
  | 3ème | 10 | 4 |
  | 2nd | 6 **par série** | 3 par série |
  | 1ère | 6 **par série** | 3 par série |
  | Tle | C:2, D:6, A1:3, A2:2 | C:1, D:3, A1:2, A2:2 |

  - La clé de configuration est `"public"` si `schooltype == "public"`, **sinon** `"privée"` — donc une école **mixte reçoit la configuration privée**
  - Si le nom de l'école contient « collège » ou « college » (insensible à la casse et aux accents), les niveaux **2nd, 1ère et Tle sont exclus**
  - Pour Tle, une série n'est retenue que si elle est réellement rattachée au niveau via la table `level_series`
  - Nommage : `"<Niveau> <n>"` sans série (ex. « 6ème 1 ») ; `"<Niveau> <Série> <n>"` avec un espace si le nom de série se termine par un chiffre (« 1ère A1 1 »), sans espace sinon (« 2nd C1 »)
  - Une classe dont le nom existe déjà dans l'école est ignorée
  - Insertion de masse : un seul `insert_all!` par table (ADR-0020)
- **Données** : `classrooms`, `levels`, `series`, `level_series`
- **État** : ✅
- **À refaire différemment** : le nombre de classes est codé en dur dans le domaine ; ce devrait être un paramètre modifiable de l'établissement.

## A6. Gérer les rôles internes d'un établissement

- **Acteur** : tout utilisateur connecté
- **Parcours** : `/schools/:school_slug/school_roles` → liste → « Nouveau rôle » → nom → création → retour liste. Suppression depuis la liste.
- **Règles métier** :
  - `name` obligatoire, max 100 caractères ; `school_id` obligatoire
  - **Pas d'unicité du nom dans une école** : deux rôles « Proviseur » peuvent cohabiter
  - Un rôle **ne peut pas être supprimé** s'il est porté par un membre du personnel (`dependent: :restrict_with_error`) — mais le contrôleur affiche quand même « Rôle supprimé. » : **échec silencieux**
  - La liste des rôles est mise en cache **12 heures** (clé `roles/school/<id>`) **sans invalidation à la création** : un rôle créé peut rester invisible jusqu'à 12 h dans les écrans qui passent par ce cache
- **Données** : `school_roles`
- **État** : ⚠️
- **À refaire différemment** : rôles de référence globaux (Proviseur, Censeur, Éducateur, Secrétaire) plutôt qu'un texte libre par établissement.

## A7. Rattacher un membre du personnel à un établissement

- **Acteur** : tout utilisateur connecté
- **Parcours** : `/schools/:school_slug/school_staffs` → liste (nom, rôle) → « Ajouter » → saisie du **numéro de contact** d'un utilisateur existant + choix d'un rôle → rattachement.
- **Règles métier** :
  - L'utilisateur doit **déjà exister**, identifié par son `contact` ; sinon « Utilisateur non trouvé avec ce contact. »
  - `user_id`, `school_id` et `school_role_id` obligatoires — le rôle est NOT NULL en base
  - Un utilisateur ne peut être staff qu'une fois par école (validation Rails, **pas d'index unique**)
  - **Aucune vérification du rôle de l'utilisateur rattaché** : on peut faire d'un élève un membre de la direction
  - Le retrait supprime définitivement la ligne (hard delete)
- **Données** : `school_staffs`
- **État** : ✅
- **À refaire différemment** : rattacher quelqu'un par son numéro de téléphone sans son consentement est un vecteur d'usurpation.

## A8. Espace Direction — tableau de bord de l'établissement

- **Acteur** : utilisateur de rôle `school_admin`
- **Parcours** : `/schoolstaff` → si l'utilisateur n'est rattaché à aucune école, une page « en attente d'affectation » s'affiche ; sinon un tableau de bord avec trois compteurs et les niveaux actifs
- **Règles métier — permissions** :
  - Garde d'accès en deux temps : `authenticate_user!`, puis `current_user.role == "school_admin"` sinon redirection racine avec « Accès non autorisé. »
  - `@school = current_user.profile.school` — le profil `SchoolStaff` est récupéré par un `find_by` sur `user_id`, donc **une seule école** : le multi-établissement est impossible pour la direction, même si la table le permettrait
  - Les écrans classes / élèves / enseignants exigent en plus `@school` présent, sinon redirection vers le feed avec « Vous devez être affecté à une école pour voir cette page. »
- **Règles métier — contenu** :
  - Compteur 1 : nombre de classes de l'école
  - Compteur 2 : nombre d'élèves **distincts** rattachés à une classe de l'école — **toutes appartenances confondues**, primaires et secondaires
  - Compteur 3 : nombre d'enseignants rattachés à l'école
  - « Niveaux actifs » = niveaux ayant au moins une classe dans l'école
  - Le flux d'activité, les messages, les examens assignés et les fiches en classe sont **des tableaux vides codés en dur**
- **Données** : `school_staffs`, `classrooms`, `classroom_students`, `students`, `teacher_schools`, `levels`
- **État** : ⚠️ (le feed est une coquille vide)

## A9. Espace Direction — consulter les classes de son école

- **Acteur** : `school_admin`
- **Parcours** : `/schoolstaff/classrooms` (liste, filtrable par `?level_id=`) → `/schoolstaff/classrooms/:slug` : tableau de bord complet de la classe — code d'adhésion avec bouton copier, effectif, % d'élèves actifs, moyenne, badges, onglets Programme / Élèves / Exercices
- **Règles métier** :
  - La **liste** est strictement scopée à `@school.classrooms`
  - La **fiche**, en revanche, est chargée par le tableau de bord générique **sans re-vérifier l'appartenance à l'école** → un directeur peut ouvrir la fiche d'une classe d'un autre établissement en connaissant son slug
- **Données** : `classrooms`, `classroom_students`, `classroom_assignments`, `exercise_sessions`, `exercise_badges`
- **État** : ⚠️ (fuite d'accès inter-établissements)

## A10. Espace Direction — créer une classe

- **Acteur** : `school_admin`
- **Parcours** : `/schoolstaff/classrooms/new` → nom, niveau, série → création → redirection vers la fiche de la classe
- **Règles métier** : l'école est imposée (celle du staff, non modifiable dans le formulaire). Les règles de la classe elle-même sont décrites en B1.
- **État** : ❌ — emprunte le use case dont la génération de code produit **6 caractères pour une colonne `limit: 5`** (bug connu)

## A11. Espace Direction — élèves et enseignants de l'établissement

- **Acteur** : `school_admin`
- **Parcours** :
  - `/schoolstaff/students` : liste de tous les élèves distincts rattachés à une classe de l'école. « Ajouter » → saisie du **contact** d'un élève existant + choix d'une classe de l'école → l'élève rejoint la classe
  - `/schoolstaff/teachers` : liste des enseignants rattachés. « Ajouter » → saisie du **contact** d'un enseignant existant → rattachement à l'école
- **Règles métier** :
  - L'ajout d'élève exige un utilisateur existant **ayant déjà un profil élève** et une classe appartenant à l'école ; sinon « Élève ou classe introuvable. »
  - L'ajout est idempotent (aucun doublon si l'élève est déjà dans la classe)
  - L'adhésion créée par cette voie porte **`primary: false`** (défaut de colonne) et `joined_at: nil` — l'élève est dans la classe, mais celle-ci n'est pas sa classe officielle. Si c'est sa seule classe, la délégation retombe dessus et le comportement reste correct ; s'il en a déjà une autre, la nouvelle reste secondaire et **invisible pour lui**.
  - Le rattachement d'enseignant est idempotent, sans rôle ni matière
  - **Aucun moyen de retirer** un élève d'une classe ni un enseignant d'une école depuis cet espace
- **Données** : `classroom_students`, `teacher_schools`
- **État** : ⚠️
- **À refaire différemment** : ajout par numéro de téléphone sans consentement + absence de retrait = une liste qu'on ne peut jamais corriger.

## A12. Espace Direction — profil et paramètres

- **Acteur** : `school_admin`
- **Parcours** : `/schoolstaff/profile` (nom complet, contact, genre, avatar) et `/schoolstaff/settings` (mot de passe + confirmation)
- **État** : ✅

## A13. API — lister les écoles d'une DRENA

- **Acteur** : **anonyme** (authentification explicitement contournée)
- **Parcours** : `GET /api/v1/schools?drena_id=X` → JSON `[{id, name, slug}]` trié par nom. `drena_id` manquant → 400 « Drena ID is required »
- **Usage** : cascade DRENA → école des formulaires d'inscription (administrateur d'école, élève)
- **État** : ✅

---

# B. CONTEXTE CLASSROOM

## B1. Créer une classe dans une école

- **Acteur** : membre de l'équipe Lnclass via `/schools/:school_id/classrooms/new` ; ou `school_admin` via son espace (A10)
- **Parcours** : formulaire nom + niveau + série → POST → redirection vers la fiche école avec « Classe créée avec succès. » (HTML ou Turbo Stream)
- **Règles métier** :
  - Accès : `authenticate_user!` pour la consultation, `authenticate_team!` pour `new/create/edit/update/destroy`
  - `name` obligatoire, **max 15 caractères en base**, normalisé par `titleize`, **unique par école** (index unique `(school_id, name)`)
  - `level_id` obligatoire en base (NOT NULL) mais **non validé** par le DTO ni par l'entité → un formulaire sans niveau produit une erreur ORM brute
  - `series_id` facultatif
  - `unique_code` obligatoire, unique globalement, généré automatiquement (voir B3)
  - `slug` FriendlyId sur le nom, **unique globalement** : la deuxième « Terminale D1 » de la plateforme reçoit un slug suffixé. Les classes créées en masse reçoivent `<ecole-slug>-<classe>-<code>`.
  - `public_id` = `SecureRandom.base58(14)`
  - **Aucune limite** du nombre de classes par école, ni d'élèves par classe
  - **Aucune notion d'année scolaire** : ni colonne, ni filtre, ni archivage
- **Données** : `classrooms`
- **État** : ❌ (bug du code à 6 caractères)

## B2. Modifier / supprimer une classe

- **Acteur** : membre de l'équipe Lnclass
- **Parcours** : `/classrooms/:id/edit` → nom, niveau, série, slug → redirection vers la fiche école. Suppression depuis la fiche école ou la fiche classe.
- **Règles métier** :
  - La mise à jour ne touche **jamais** `unique_code` ni `school_id` : le code d'adhésion est **immuable** après création, et une classe ne peut pas changer d'établissement
  - La suppression est un **hard delete** : elle détruit `classroom_students`, `teacher_classrooms` et `classroom_assignments` — donc tout l'historique d'assignations, à rebours de l'esprit de l'ADR-0016. Les sessions d'exercices des élèves survivent, orphelines de classe.
  - Aucun garde-fou sur une classe peuplée
- **État** : ⚠️
- **À refaire différemment** : il faut un **archivage de classe** (fin d'année scolaire) plutôt qu'une suppression.

## B3. Code d'adhésion d'une classe — génération et partage

- **Acteur** : le système à la création ; l'enseignant ou la direction pour le partage
- **Parcours** : le code s'affiche en gros sur la fiche classe (enseignant, direction, équipe) avec un **bouton copier**, et sur le feed enseignant avec un **bouton de partage WhatsApp** pré-rempli : « Bonjour chers élèves, rejoignez notre classe sur Lnclass pour préparer votre BAC efficacement. Cliquez ici : https://…/c/<code> »
- **Règles métier — format exact** :
  - **3 lettres + 2 chiffres**, soit exactement 5 caractères
  - Alphabet des lettres : a–z **privé de `i` et `o`** → **24 lettres** (évite la confusion avec 1 et 0)
  - Alphabet des chiffres : **2–9** → **8 chiffres** (évite 0 et 1)
  - Espace total : 24³ × 8² = **884 736 codes possibles**
  - **Stocké en minuscules**, **affiché en majuscules** dans toute l'interface
  - Boucle de regénération tant que le code existe déjà en base
  - Index unique sur `classrooms.unique_code`, colonne `limit: 5`
  - Toute recherche par code normalise `.strip.downcase`
  - Le formulaire d'inscription élève annonce explicitement « Code de classe (5 caractères) »
  - **Le chemin de création par use case produit à la place `SecureRandom.alphanumeric(6).downcase`** : 6 caractères, alphabet complet (avec i, o, 0, 1), **sans vérification de collision** — incompatible avec la colonne (bug connu)
- **Données** : `classrooms.unique_code`
- **État** : ⚠️ (impeccable côté ORM, cassé côté use case)

## B4. Rejoindre une classe avec le code — inscription express « prépa »

- **Acteur** : visiteur anonyme muni d'un lien `/c/:unique_code`
- **Parcours** : le lien ouvre une page de pré-inscription affichant **le nom de la classe, l'école, et le premier enseignant de la classe en preuve sociale** → formulaire nom complet, contact, genre, mot de passe → compte créé, **session ouverte**, redirection `/students` avec « Bienvenue dans la classe de révision ! ». Code inconnu → redirection racine, « Code de classe invalide. »
- **Règles métier** :
  - Le code est résolu en amont ; la classe donne l'école, le niveau et la série de l'élève
  - **Si le mot de passe est laissé vide, le numéro de contact devient le mot de passe** — inscription en un champ, mais mot de passe déductible par construction
  - Attributs posés à l'inscription : `prepa_status: "unpaid"` et `prepa_joined_at: Time.current` — **ces deux attributs n'existent dans aucune table ni entité** et sont silencieusement perdus
  - L'adhésion créée porte **`primary: true`** et `joined_at: Time.current`
  - **Pas de transaction** : si la création du profil élève échoue après celle de l'utilisateur, un compte orphelin sans profil subsiste (limitation assumée dans le code)
  - Aucune limite d'effectif, aucune expiration du code, aucune validation par l'enseignant
- **Données** : `users`, `students`, `classroom_students`
- **État** : ⚠️
- **À refaire différemment** : le mot de passe égal au numéro de téléphone est indéfendable ; prévoir un code à usage unique ou une validation SMS.

## B5. Inscription élève classique

- **Acteur** : visiteur anonyme · `/student-signup`
- **Parcours** : deux voies dans le même formulaire — soit saisir un **code de classe** (vérifié en direct par un appel JS à l'API de lookup, qui affiche le nom de la classe et de l'école avant validation), soit choisir en cascade école → niveau → classe
- **Règles métier** :
  - Si un code est fourni, il **prime** et fixe classe / école / niveau / série ; code invalide → « Code de classe invalide »
  - Sinon, les identifiants du formulaire sont repris tels quels, **sans vérifier que la classe choisie appartient bien à l'école choisie**
  - Rôle forcé à `student`, session ouverte, redirection `/students`
- **Données** : `users`, `students`, `classroom_students`
- **État** : ✅

## B6. API — vérifier un code de classe

- **Acteur** : **anonyme** (authentification explicitement contournée)
- **Parcours** :
  - `GET /api/v1/classrooms/lookup?unique_code=xxx` → `{id, name, school_id, school_name, level_id, level_name}`, `level_name` concaténant niveau + série s'il y a une série. Code vide → 400 « Code requis » ; code inconnu → 404 « Classe introuvable ».
  - `GET /api/v1/classrooms?level_id=&school_id=` → `[{id, name}]`, le nom étant suffixé de la série entre parenthèses. Retourne `[]` si un paramètre manque.
- **Règles métier** : **aucune authentification, aucune limitation de débit** — les 884 736 codes possibles sont énumérables, et chaque code révèle l'établissement et le niveau de la classe
- **État** : ⚠️
- **À refaire différemment** : limiter le débit et ne renvoyer que le strict nécessaire.

## B7. L'enseignant déclare les classes qu'il enseigne

- **Acteur** : enseignant
- **Parcours** : `/teachers/classrooms` → page « Quelles classes enseignez-vous ? » listant **toutes les classes de son école groupées par niveau**, avec cases à cocher, un « Tout cocher » par niveau et un compteur de sélection en direct → « Terminer la configuration » → redirection `/teachers` avec « Vos classes ont été mises à jour avec succès. »
- **Règles métier — permissions** :
  - `authenticate_user!` + rôle enseignant + rattachement à au moins une école, sinon redirection racine avec « Veuillez d'abord rejoindre un établissement. »
  - **L'enseignant n'a qu'un seul établissement visible** : la méthode qui expose son école retourne `schools.first`. Bien que `teacher_schools` soit une vraie table n-n, toute l'interface ne connaît que le premier établissement rattaché. Le multi-établissement est modélisé mais inaccessible.
- **Règles métier — sélection** :
  - La soumission **remplace intégralement** la sélection : décocher une classe supprime le lien correspondant
  - Une sélection **vide est refusée** (« Veuillez sélectionner au moins une classe. ») → **on ne peut jamais se retirer de toutes ses classes**
  - Les identifiants soumis sont re-filtrés sur les classes de l'école de l'enseignant : impossible de s'attribuer la classe d'un autre établissement
  - Unicité `(teacher_id, classroom_id)`
  - **Aucune matière associée au couple enseignant-classe** : un enseignant rattaché à une classe y a tous les droits, quelle que soit sa discipline
  - À la connexion, un enseignant **sans aucune classe** est envoyé sur cette page ; sinon sur son feed
- **Données** : `teacher_classrooms`, `teacher_schools`, `classrooms`, `levels`
- **État** : ✅ (la redirection `/` ↔ `/teachers/classrooms` boucle pour l'enseignant sans école — bug connu)

## B8. Espace classe de l'enseignant

- **Acteur** : enseignant
- **Parcours** :
  - `/teachers/classrooms/:slug` → en-tête avec nom de la classe et **code d'adhésion en majuscules**, statistiques, élèves, cours assignés, sujets d'examen assignés
  - `/teachers/classrooms/:id/courses/:course_id` → les fiches essentielles du cours, chacune avec son état d'assignation
  - `/teachers/classrooms/:id/essentials/:essential_id` → les exercices de la fiche, avec état d'assignation
  - `/teachers/classrooms/:classroom_id/students/:public_id` → fiche d'un élève : ses sessions terminées triées par date décroissante, et ses badges
- **Règles métier — permissions (le scope le plus solide de l'application)** :
  - **Toutes** les classes sont chargées depuis la collection des classes de l'enseignant : il ne peut ouvrir **que** les classes qu'il a déclarées en B7
  - La fiche élève est **doublement** scopée : l'élève doit appartenir à cette classe, sinon 404
  - L'élève est identifié par `public_id`, jamais par son identifiant interne
- **Données** : `classrooms`, `classroom_students`, `classroom_assignments`, `exercise_sessions`, `exercise_badges`, `users`
- **État** : ❌ — la fiche classe et l'écran « fiche essentielle » lisent des associations reposant sur les trois `belongs_to` scopés défectueux (`PG::UndefinedTable`, bug connu)

## B9. Tableau de bord générique d'une classe

- **Acteur** : **tout utilisateur connecté** — `/classrooms/:id`
- **Parcours** : fil d'Ariane, en-tête avec code d'adhésion copiable, 4 compteurs (élèves, % actifs, moyenne, badges), 4 onglets (Vue d'ensemble / Programme / Élèves / Exercices), encart « Prochaines étapes » (« Partagez le code… », « Assignez des cours… »)
- **Règles métier — permissions** :
  - **Aucune vérification d'appartenance.** Seul `authenticate_user!` est posé, et la classe est trouvée par slug puis par identifiant. **Un élève quelconque peut ouvrir n'importe quelle classe du pays, y lire le code d'adhésion et la liste nominative de ses élèves.** C'est le trou de sécurité le plus large des deux contextes.
- **Règles métier — calculs** :
  - **% d'élèves actifs** = élèves distincts ayant au moins une session terminée ÷ effectif × 100, arrondi ; 0 si la classe est vide
  - **Moyenne de classe** = moyenne du champ `percentage` sur toutes les sessions terminées de la classe, **tronquée à l'entier**
  - **Badges** = total des badges de tous les élèves de la classe
  - Classe introuvable → redirection racine avec « Classe introuvable »
  - Les compteurs de l'onglet Programme comptent uniquement les assignations **non archivées**
- **Données** : `classrooms`, `classroom_students`, `classroom_assignments`, `exercise_sessions`, `exercise_badges`
- **État** : ⚠️ (fonctionne, non protégé)

## B10. Liste paginée des élèves d'une classe

- **Acteur** : tout utilisateur connecté · `GET /classrooms/:id/students`
- **Parcours** : tableau (Élève, Moyenne, Progression, Badges) avec avatar-initiale, ancienneté d'inscription en relatif, **3 badges maximum** affichés, **défilement infini** avec lien « Charger la suite » en Turbo Stream. Classe vide → « Aucun élève inscrit / Partagez le code de la classe pour voir les premiers inscrits ici. »
- **Règles métier** :
  - Pagination **en mémoire** : la liste complète des élèves est chargée à chaque page
  - Tri par date de création croissante
  - **« Progression » est affichée mais aucun modèle n'expose cette valeur** : la colonne affiche systématiquement 0 %
  - « Moyenne » = moyenne entière des pourcentages des sessions terminées de l'élève
  - Chaque ligne est mise en cache individuellement
  - La liste inclut **toutes** les adhésions, primaires et secondaires
  - Le bouton d'action en fin de ligne pointe sur `"#"` — il ne fait rien
- **État** : ⚠️

## B11. Assigner une ressource pédagogique à une classe (assignation polymorphe)

- **Acteur** : enseignant
- **Parcours** : depuis la fiche d'un cours (`/classrooms/:classroom_id/courses/:course_id`) ou d'une fiche essentielle, un bouton bascule « Ajouter / Retirer » met à jour la zone par Turbo Stream et affiche un toast « <Nom> ajouté à <Classe>. » / « <Nom> retiré de <Classe>. »
- **Règles métier — modèle** :
  - Types de ressources autorisés : **`Course`, `Essential`, `ExamSubject`, `Exercise`**
  - Le domaine manipule les noms courts (`"Course"`), la persistance stocke `"Orm::Course"` — traduction dans les deux sens au passage du repository
  - **Unicité stricte en base** : index unique `(classroom_id, resource_type, resource_id)`
  - Statuts : `added`, `active` (défaut de colonne), `validated`, `archived`
  - Assigner une ressource **déjà assignée est idempotent** : renvoie l'assignation existante sans erreur
  - Réassigner une ressource **archivée la réactive** au statut `"added"` (ADR-0016)
  - Le retrait est un **soft delete** : `status = "archived"`. Toutes les lectures filtrent sur « non archivé ».
  - `assigned_by_id` conserve **qui** a assigné (traçabilité ADR-0007) — mais on y écrit l'identifiant du **profil enseignant** alors que la colonne est déclarée comme référence à un **utilisateur** : la traçabilité désigne aujourd'hui le mauvais compte
- **Règles métier — autorisation (policy exacte)** :
  - `ClassroomAccessPolicy#authorized?(teacher_id:, classroom_id:)` retourne **vrai si et seulement si** la classe figure dans la liste des classes de cet enseignant, c'est-à-dire s'il existe une ligne `teacher_classrooms` reliant les deux
  - Retourne **faux** si l'un des deux identifiants est nul
  - La comparaison se fait en `to_s` pour tolérer indifféremment un entier ou une chaîne
  - **Aucune condition d'école, de matière, de statut ou d'ancienneté.** Un enseignant multi-établissements est donc pleinement autorisé sur les classes des deux écoles — la policy le permet, seule l'interface (B7) l'en empêche.
  - Refus → « Accès refusé à cette classe. »
  - Garde du contrôleur : `authenticate_user!` seulement, puis usage du profil enseignant → un utilisateur connecté **non-enseignant** provoque une erreur 500 au lieu d'un refus propre
- **Données** : `classroom_assignments`
- **État** : ❌ — le use case instancie par défaut la policy **sans son argument obligatoire** → `ArgumentError` à chaque assignation depuis ces contrôleurs

## B12. Assigner cours / fiches / sujets d'examen depuis l'espace enseignant

- **Acteur** : enseignant · `POST|DELETE /teachers/classroom_course_assignments`, `…_essential_assignments`, `…_exam_assignments`
- **Parcours prévu** : boutons d'assignation dans le catalogue de cours et la liste des sujets d'examen, avec Turbo Stream et toasts de confirmation
- **État** : 💀 — ces trois contrôleurs invoquent **six use cases qui n'existent nulle part** dans le code (assigner/retirer cours, fiche, examen). Toute requête lève `NameError`. Par ailleurs, le bouton qui y mène dans la fiche de cours dépend d'une variable jamais affectée (bug connu) : les routes sont donc de toute façon inatteignables depuis l'interface.
- **À refaire différemment** : un **seul** use case polymorphe suffit — c'est ce que fait déjà B11. Ces six-là sont le vestige de la modélisation d'avant l'ADR-0007.

## B13. Ma classe (espace élève)

- **Acteur** : élève · `/students/classroom`
- **Parcours** : nom de la classe, école, **code d'adhésion en majuscules**, puis la liste des cours assignés à la classe avec leur nombre de fiches essentielles et leur vignette
- **Règles métier** :
  - Garde : rôle élève ; profil incomplet (pas de classe ou pas d'école) → redirection racine avec « Veuillez compléter votre profil. »
  - **L'élève ne voit qu'une seule classe : sa classe principale.** La classe affichée est l'adhésion `primary: true`, ou à défaut la première adhésion créée. Malgré l'ADR-0003, **aucun écran ne permet de basculer entre ses classes** ni même d'en voir la liste : un élève inscrit à un cours du soir en plus de sa classe officielle ne verra jamais le contenu du second.
  - Le nombre de fiches par cours est calculé en SQL groupé ; cours triés par nom
- **Données** : `classroom_students`, `classrooms`, `classroom_assignments`, `courses`, `essentials`
- **État** : ✅ (l'écran fonctionne ; la limitation mono-classe est structurelle)
- **À refaire différemment** : c'est la promesse centrale de l'ADR-0003 qui n'est pas tenue côté interface.

## B14. Feed de l'élève

- **Acteur** : élève · `/students`
- **Parcours** : école, niveau, classe, effectif, matières de la classe, exercices assignés avec progression personnelle (session en cours, badge, meilleur score, nombre de tentatives), messages récents destinés aux élèves, activité récente
- **Règles métier** :
  - Profil sans classe → redirection racine avec « Veuillez compléter votre profil. »
  - Effectif = tous les élèves de la classe principale, **adhésions secondaires comprises**
  - Messages : les **5** derniers messages destinés au rôle élève
  - Activité : les **10** dernières sessions terminées, par date décroissante
- **État** : ❌ — la requête de feed référence une classe de persistance **supprimée par l'ADR-0007** et une association inexistante sur les cours. Le feed lève une erreur dès que l'élève a une classe. **C'est l'écran d'accueil de tous les élèves.** (La boucle de redirection `/` ↔ `/students` — bug connu — masque probablement cette erreur.)

## B15. Élèves de démonstration — génération

- **Acteur** : le système, à la création d'un établissement. **Jamais déclenchable par un humain.**
- **Objectif (ADR-0019)** : déclencher l'« aha moment » de l'enseignant, qui ne doit pas découvrir un tableau de bord vide. **Aucune marque visuelle ne distingue un élève de démonstration** — choix explicite : « l'enseignant doit avoir l'illusion d'une vraie classe ».
- **Parcours** : invisible. L'enseignant qui ouvre sa nouvelle classe y trouve une quarantaine d'élèves aux noms ivoiriens.
- **Règles métier — valeurs exactes du chemin réellement exécuté** :
  - **Seules les 2 premières classes de chaque niveau** reçoivent des élèves (limitation volumétrique)
  - **40 à 45 élèves** par classe (tirage aléatoire dans cet intervalle)
  - Genre tiré à pile ou face ; prénom tiré parmi **22 prénoms masculins** ou **19 féminins** ; nom de famille parmi **24 patronymes ivoiriens** (Kouassi, Bamba, Diarrassouba, Koné, Traoré, Coulibaly, Ouattara, Touré, N'Guessan, Fofana, Bakayoko, Cissé, Keita, Camara…)
  - **Contact déterministe** : `<code_classe_5_car><index_sur_5_chiffres>` = exactement **10 caractères** (ex. `kaz4700001`). C'est ce qui garantit l'unicité sans collision (« paradoxe des anniversaires » évité) — et c'est aussi **l'identifiant de connexion** de ces comptes.
  - Mot de passe : **`123456`**, haché en BCrypt **coût 4** (coût volontairement abaissé pour la vitesse d'insertion)
  - `is_demo: true` sur la table `users`
  - `matricule` = `"MAT-<contact>"`
  - `public_id` = `"stdt_" + SecureRandom.base58(14)` ; `slug` = `<nom-complet-parameterize>-<hex 2 octets>`
  - Adhésion créée avec **`primary: true`** et `joined_at` renseigné
  - Tout en insertions de masse, dans une transaction unique (classes, utilisateurs, élèves, adhésions)
- **Données** : `users` (colonne `is_demo`), `students`, `classroom_students`, `classrooms`
- **État** : ✅ pour ce chemin
- **À refaire différemment** : mot de passe `123456` et identifiant prévisible sur des comptes réels — quiconque connaît un code de classe peut se connecter en tant qu'élève de démonstration de cette classe et voir ce qu'il voit.

## B16. Élèves de démonstration — les deux autres implémentations

- **Deuxième générateur** (`GenerateDemoStudents`) : 40–45 élèves, mot de passe **`12345678`**, contacts **aléatoires** de préfixe `01`/`05`/`07` + 8 chiffres, **15 prénoms et 11 noms** (listes différentes de celles de B15), pas de genre. Il appelle une méthode d'insertion de masse **absente du repository et absente du port**.
  **État : ❌ / 💀** — son seul appelant, un job de génération de données de démonstration, **n'est enqueué nulle part**.
- **Simulation d'activité** (`SimulateClassroomExerciseJob`) : devait faire « passer » chaque exercice nouvellement assigné par tous les élèves de démonstration de la classe, avec des durées mockées de **5 à 20 minutes** et un **boost de +60 %** de taux de réussite en remédiation, pour produire des courbes de progression crédibles (ADR-0019 §2.3).
  **État : 💀** — **jamais enqueué.** Les élèves de démonstration existent dans les classes mais **ne produisent aucune activité** : toutes les statistiques de classe restent à 0 %. La raison d'être de la fonctionnalité n'est pas atteinte.

## B17. Élèves de démonstration — purge

- **Acteurs prévus** : l'enseignant quand il invite ses vrais élèves ; l'équipe commerciale à la fin d'une démonstration terrain
- **Règles métier prévues** : suppression **définitive** de tous les comptes `is_demo: true` d'une classe **ou** d'une école ; refus si aucun des deux identifiants n'est fourni (« Veuillez fournir un classroom_id ou un school_id ») ; retour d'un compteur `purged_count`
- **État** : 💀 — le use case n'est appelé **par aucun contrôleur, aucune route, aucun job, aucune tâche rake**, et il repose de toute façon sur une méthode de repository inexistante.
  **Il n'existe aucun moyen, dans l'application, de retirer les élèves de démonstration d'une classe.** Un enseignant qui invite ses vrais élèves les verra noyés parmi 40 faux, et ses moyennes de classe resteront faussées définitivement.

---

# C. Synthèse des permissions — qui peut voir quoi

| Écran / action | Garde posée | Portée effective |
|---|---|---|
| `/schools`, `/schools/:slug`, création/édition/suppression d'école | `authenticate_user!` | **Toute personne connectée**, y compris un élève |
| `/schools/:id/school_roles`, `/schools/:id/school_staffs` | `authenticate_user!` | **Toute personne connectée** |
| `/drenas` écritures | `authenticate_team!` | Équipe Lnclass |
| `/classrooms/:id` (fiche), `/classrooms/:id/students` | `authenticate_user!` | **Toute personne connectée, sur n'importe quelle classe du pays** |
| `/classrooms/:id` new/create/edit/update/destroy | `authenticate_team!` | Équipe Lnclass |
| `/classrooms/:id/courses/:id` create/destroy | `authenticate_user!` + policy | Enseignant **de cette classe** (500 si non-enseignant) |
| `/teachers/classrooms*` | rôle enseignant + école + scope sur ses classes | **Uniquement ses propres classes** — le scope le plus solide |
| `/teachers/classroom_*_assignments` | rôle enseignant + policy | 💀 inatteignable (use cases absents) |
| `/schoolstaff/*` | rôle `school_admin` + école rattachée | **Son unique école** — sauf la fiche de classe, non re-vérifiée |
| `/students/*` | rôle élève | **Sa seule classe principale** |
| `/api/v1/schools`, `/api/v1/classrooms`, `/api/v1/classrooms/lookup` | **aucune** | **Anonyme, sans limitation de débit** |

**Policy unique du contexte** — `Policies::ClassroomAccessPolicy#authorized?(teacher_id:, classroom_id:)` :
`false` si l'un des deux identifiants est nul ; sinon `true` si et seulement si la classe apparaît dans les classes rattachées à cet enseignant via `teacher_classrooms`. Comparaison en `to_s`. **Aucune condition d'école, de matière, de statut.**

**Enseignant multi-établissements** : autorisé par la policy et par le schéma (`teacher_schools` est une vraie table n-n), mais **impossible en pratique** : l'interface n'expose que `schools.first`.

**Élève multi-classes** : autorisé par le schéma (`classroom_students` + colonne `primary`), mais **impossible en pratique** : tous les écrans élève ne lisent que la classe principale, sans sélecteur.

---

# D. Les tables des deux contextes

## `schools`

| Colonne | Type | Contraintes |
|---|---|---|
| id | bigint | PK |
| name | string(150) | NOT NULL, **unique** |
| slug | string | NOT NULL, **unique** |
| public_id | string | **unique** |
| schoolsigle | string(10) | nullable |
| schoolstatus | string | NOT NULL — `draft` / `active` / `inactive` |
| schooltype | integer | enum `privée:0`, `public:1`, `mixte:2` |
| drena_id | bigint | NOT NULL, indexé |
| team_id | bigint | nullable, indexé |
| created_at / updated_at | datetime | NOT NULL |

Index : `name` (unique), `public_id` (unique), `slug` (unique), `drena_id`, `team_id`.

## `classrooms`

| Colonne | Type | Contraintes |
|---|---|---|
| id | bigint | PK |
| name | string(**15**) | NOT NULL |
| slug | string | **unique** |
| public_id | string | **unique** |
| unique_code | string(**5**) | NOT NULL, **unique** |
| school_id | bigint | NOT NULL, indexé |
| level_id | bigint | NOT NULL, indexé |
| series_id | bigint | nullable, indexé |
| created_at / updated_at | datetime | NOT NULL |

Index : `unique_code` (unique), `slug` (unique), `public_id` (unique), **`(school_id, name)` unique**, `school_id`, `level_id`, `series_id`.

**Absent du schéma** : année scolaire, statut ou archivage, effectif maximal, dates d'ouverture/fermeture.

## `classroom_students`

| Colonne | Type | Contraintes |
|---|---|---|
| id | bigint | PK |
| student_id | bigint | NOT NULL, indexé |
| classroom_id | bigint | NOT NULL, indexé |
| primary | boolean | NOT NULL, **défaut `false`** |
| joined_at | datetime | nullable |
| created_at / updated_at | datetime | NOT NULL |

Index : **`(student_id, classroom_id)` unique**, `student_id`, `classroom_id`.

**Aucune contrainte ne garantit qu'un élève n'a qu'une seule adhésion `primary: true`.**

## `classroom_assignments`

| Colonne | Type | Contraintes |
|---|---|---|
| id | bigint | PK |
| classroom_id | bigint | NOT NULL, indexé |
| resource_type | string | NOT NULL — `Orm::Course` / `Orm::Essential` / `Orm::Exercise` / `Orm::ExamSubject` |
| resource_id | bigint | NOT NULL |
| status | string | NOT NULL, **défaut `"active"`** — `added` / `active` / `validated` / `archived` |
| assigned_by_id | bigint | nullable, **non indexé** |
| created_at / updated_at | datetime | NOT NULL |

Index : **`(classroom_id, resource_type, resource_id)` unique**, `classroom_id`, `(resource_type, resource_id)`.

Note : le défaut de colonne est `"active"` alors que le code écrit `"added"` — deux valeurs coexistent en base pour le même sens.

## `teacher_classrooms`

`id`, `teacher_id` NOT NULL, `classroom_id` NOT NULL, timestamps.
Index : `(teacher_id, classroom_id)` unique, `teacher_id`, `classroom_id`.
**Pas de matière, pas de date de début ni de fin.**

## `teacher_schools`

`id`, `teacher_id` NOT NULL, `school_id` NOT NULL, timestamps.
Index : `(teacher_id, school_id)` unique, `teacher_id`, `school_id`.

## `school_roles`

`id`, `name` (nullable en base, obligatoire côté code, max 100), `school_id` NOT NULL, timestamps.
Index : `school_id`. **Pas d'unicité du nom par école.**

## `school_staffs`

`id`, `user_id` NOT NULL, `school_id` NOT NULL, `school_role_id` **NOT NULL**, timestamps.
Index : `user_id`, `school_id`, `school_role_id`.
**L'unicité `(user_id, school_id)` n'est qu'une validation applicative, sans index unique — contournable en concurrence.**

## Tables voisines nécessaires à la compréhension

- `drenas` : `name` (50, unique), `slug` (unique), `public_id` (unique), `team_id`
- `students` : `user_id` NOT NULL, `matricule` (15, indexé **non unique**)
- `teachers` : `user_id` NOT NULL, `material_id` (nullable)
- `levels` : `name` (20, unique), `slug` (unique), `public_id` (unique), `team_id`
- `series` : `name`, `slug`, `public_id` — tous uniques et NOT NULL
- `level_series` : couple `(level_id, series_id)` unique

---

# E. Règles métier implicites à rendre explicites

1. **Un élève n'a qu'une seule classe visible.** Le schéma autorise le multi-classes, l'interface n'en expose jamais qu'une : la `primary`, ou à défaut la plus ancienne. À trancher : veut-on vraiment le multi-classes ? Si oui, il faut un sélecteur de classe partout ; sinon, simplifier le schéma.
2. **Un enseignant n'a qu'un seul établissement visible** (`schools.first`). Même arbitrage à trancher.
3. **Une seule adhésion primaire par élève** : jamais garanti, ni en base ni en code. L'ajout par la direction crée `primary: false`, l'inscription par code crée `primary: true` — rien n'empêche deux `primary: true` simultanés.
4. **Une classe vit indéfiniment.** Pas d'année scolaire, pas de passage de niveau, pas d'archivage. Que se passe-t-il en septembre ? Aujourd'hui, rien : les Terminales de l'an dernier restent dans la classe.
5. **Le code d'adhésion est éternel et sans effectif maximal.** Une fois partagé sur WhatsApp, il circule sans fin. Prévoir expiration, révocation, régénération, et un plafond d'élèves.
6. **Le rôle `school_admin` vaut pour une école et une seule.** Un fondateur possédant trois établissements ne peut pas les gérer.
7. **Une classe appartient à un enseignant sans notion de matière.** Un professeur de maths rattaché à une classe peut y assigner et retirer les cours de français.
8. **Le retrait d'une assignation est réversible, la suppression d'une classe ne l'est pas.** L'ADR-0016 protège l'historique des assignations, mais supprimer la classe les détruit toutes.
9. **Les élèves de démonstration sont des comptes réels et connectables**, avec un identifiant déterministe et le mot de passe `123456`. Ce ne sont pas des données de test : ce sont des utilisateurs.
10. **`assigned_by_id` reçoit un identifiant de profil enseignant dans une colonne déclarée comme référence à un utilisateur.** La traçabilité d'audit de l'ADR-0007 désigne aujourd'hui le mauvais compte.
11. **Le statut par défaut d'une assignation est `"active"` en base et `"added"` en code** : deux valeurs pour le même état.
12. **La clé d'accès à une classe dans les URL est le slug**, globalement unique et devinable — alors que `public_id` existe, est généré systématiquement, et n'est jamais utilisé.
13. **Les compteurs d'élèves incluent les adhésions secondaires** partout (feed direction, effectif de classe, liste d'élèves). Un élève de cours du soir compte dans l'effectif officiel de l'établissement.
14. **La « progression » affichée dans la liste d'élèves est un indicateur inventé par la vue** : la valeur n'existe nulle part, la colonne affiche toujours 0 %.
15. **Les statistiques de classe sont recalculées à chaque affichage** ; les rapports d'exercice, eux, sont mis en cache 1 h sans invalidation.
16. **La suppression d'un rôle porté par du personnel échoue silencieusement** tout en affichant « Rôle supprimé. »
17. **La création d'une école est synchrone et lourde** : elle crée jusqu'à une quarantaine de classes et plus de mille comptes élèves dans la requête HTTP.

---

# F. Ce que je n'ai pas pu déterminer

1. **`prepa_status` et `prepa_joined_at`** sont posés à l'inscription par code mais n'existent dans aucune table ni entité. Y a-t-il eu un modèle de paiement retiré ? `Student#unpaid?` retourne `false` en dur, `paid_students_count` est câblé à 0 avec le commentaire « les statuts de paiement ne sont pas implémentés », et un écran paywall existe mais reste inatteignable. **Y a-t-il un modèle économique élève à reproduire ?**
2. **Rôle réel de `classrooms.public_id`** : généré systématiquement, lu nulle part. Résidu, ou prévu pour l'application mobile ?
3. **Le statut d'assignation `"validated"`** est prévu par l'entité et par l'ORM mais **aucun code ne l'écrit jamais**. Que devait signifier une assignation « validée » ? (l'ADR-0011 sur la validation collaborative est un lien plausible mais non établi dans le code)
4. **Pourquoi deux modélisations parallèles du même objet** : `Entities::Classroom` + son repository d'un côté, `Entities::Identity::Classroom` + le sien de l'autre ; idem pour School et SchoolStaff. Migration ADR-0023 interrompue, ou découpage intentionnel ? **Les deux sont utilisées simultanément** : la fiche école lit les classes via `Identity`, tout le reste via `Classroom`.
5. **Le DTO de classe accepte un `unique_code` fourni par l'utilisateur** — aucun formulaire ne l'expose. Entrée volontaire pour un import, ou reliquat ?
6. **Le « profil caché Fort / Moyen / En difficulté »** des élèves de démonstration, décrit par l'ADR-0019 §2.2, n'apparaît nulle part dans le code. Où devait-il être stocké ?
7. **Y a-t-il eu une reprise de données** lors de la migration `classroom_courses` / `classroom_essentials` / `classroom_exercises` → `classroom_assignments` (ADR-0007) ? Le schéma n'en garde aucune trace, mais plusieurs requêtes interrogent encore les anciennes tables par leur nom.
8. **Pourquoi `students.matricule` n'est pas unique**, alors que les élèves de démonstration reçoivent un matricule déterministe. Un matricule officiel d'établissement est-il prévu ?
