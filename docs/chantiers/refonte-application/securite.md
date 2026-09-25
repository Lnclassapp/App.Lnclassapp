# Prérequis de sécurité — bloquants avant toute mise en ligne

> **Statut : l'application n'est pas en ligne au 2026-09-18.** C'est la seule raison pour laquelle ce document n'est pas un hotfix. Aucune des trois conditions du [cycle hotfix](../../workflows/hotfix.md) n'est remplie — la production n'est pas cassée, elle n'existe pas encore.
>
> **Ce document est une porte de sortie, pas une liste de souhaits.** La nouvelle application ne se déploie pas tant que les points 🔴 ne sont pas traités et vérifiés par un test.

Tous les constats ci-dessous ont été vérifiés dans le code du dépôt actuel, pas déduits. Ils décrivent des défauts à **ne pas reproduire** dans le nouveau projet, et servent de liste de contrôle à sa mise en ligne.

---

## 🔴 Bloquants — l'application ne se déploie pas avant

### 1. Inscription publique au rôle le plus privilégié

`GET|POST /team-signup` est une route publique. `Teams::RegistrationsController` ne contient **aucun `before_action`** — lu intégralement, vérifié. Il force `role: ROLES[:team]` et ouvre la session.

Le rôle `team` garde 11 contrôleurs, dont `Identity::UsersController` :

```ruby
# app/controllers/identity/users_controller.rb:20
before_action :authenticate_team!, only: %i[index destroy]
```

Chaîne complète, sans étape manquante :

```
inconnu ─► POST /team-signup ─► compte team ─► GET /users ─► DELETE /users/:public_id
                                                             └─► destroy en cascade
```

**Règle pour le nouveau projet** : aucun rôle privilégié ne se crée par formulaire public. Les comptes `team` naissent par seed ou par invitation d'un `team` existant. Un test vérifie qu'aucune route publique ne crée un rôle autre que l'apprenant.

### 2. Administration d'un établissement sans lien avec lui

`GET|POST /staff-signup` est publique. Le `school_id` est choisi librement dans une liste publique, et **rien ne vérifie que le demandeur ait le moindre lien avec l'établissement**. Le compte obtenu donne la liste nominative des élèves, avec leurs numéros de téléphone — il s'agit de mineurs.

**Règle** : le rattachement à un établissement est validé par un tiers déjà rattaché, ou par un code d'établissement à usage unique.

### 3. HTTPS non forcé en production

```
config/environments/production.rb:28   # config.assume_ssl = true
config/environments/production.rb:31   # config.force_ssl = true
```

Les deux sont commentés. Le cookie de session porte à lui seul toute l'authentification : sans HTTPS forcé, il circule en clair. Le contexte d'usage — wifi partagé, cybercafé, établissement scolaire — rend l'interception banale plutôt que théorique.

**Règle** : `force_ssl` actif dès le premier déploiement. Non négociable.

### 4. Comptes forçables en quelques minutes

Trois faits qui se composent :

| Fait | Conséquence |
|---|---|
| L'identifiant est le **numéro de téléphone** | public, et fortement structuré : 10 chiffres, préfixes `01`/`05`/`07` |
| Le mot de passe est un **PIN à 4 chiffres** | 10 000 combinaisons, imposé uniquement par `maxlength` et `pattern` **côté navigateur** — aucune validation serveur |
| **Aucune limitation de tentatives** | `grep -rn "rate_limit" app/controllers/` ne retourne rien, alors que Rails 8 le fournit en natif |

Une classe entière tombe en une nuit.

**Règle** : `rate_limit` sur l'authentification, validation serveur du secret, et une politique de mot de passe décidée par ADR — si le PIN à 4 chiffres est maintenu pour des raisons d'usage (et l'argument est recevable sur téléphone en Côte d'Ivoire), il doit être compensé par la limitation de tentatives, un verrouillage progressif et un second facteur sur les rôles privilégiés.

### 5. Le mot de passe peut devenir l'identifiant

Sur le parcours d'inscription par lien de classe :

```ruby
user_attrs[:password] = user_attrs[:contact]   # si le champ est laissé vide
```

Le mot de passe devient identique au numéro de téléphone, qui est l'identifiant de connexion. Ce parcours n'utilise pas non plus de DTO — il envoie un `Hash` brut au use case, donc sans aucune validation.

**Règle** : aucun secret n'est jamais dérivé d'un identifiant. Un champ de mot de passe vide est une erreur de validation, jamais un défaut silencieux.

---

## 🟠 Élevés — à traiter avant l'ouverture aux utilisateurs réels

### 6. Rien ne referme une session

- **Aucun `reset_session`** à la connexion (fixation de session possible) ni à la déconnexion. Vérifié : aucune occurrence dans tout `app/`.
- **Aucune expiration** : ni `expire_after`, ni `last_seen_at`, ni révocation. Un cookie volé vaut indéfiniment.
- À la déconnexion, seul `session[:user_id]` est effacé — le reste du contenu de session passe d'un utilisateur à l'autre sur le même navigateur, ce qui compte sur un poste partagé en salle de classe.

### 7. Le mot de passe se change sans le mot de passe actuel

Sur **trois écrans** : `PATCH /profile`, `PATCH /users/:public_id`, `PATCH /schoolstaff/settings`. Une session volée devient donc une prise de contrôle définitive.

Aggravant : **`password_confirmation` est accepté par les formulaires mais jamais transmis à l'ORM** — la confirmation est silencieusement ignorée. Une faute de frappe verrouille le compte, et **il n'existe aucun parcours de récupération de mot de passe dans toute l'application** : ni route, ni mailer, ni table de jetons.

### 8. Assignation dynamique sans liste blanche dans le domaine

`UseCases::Identity::UpdateUser` et `UseCases::UpdateUserProfile` :

```ruby
attributes.each { |key, value| user.send("#{key}=", value) if user.respond_to?("#{key}=") }
```

La seule barrière est le `permit` du contrôleur. Or `Entities::User` expose `role=` et `public_id=` : ajouter `:role` à un `permit`, ou appeler ce use case depuis un nouveau point d'entrée, donne une élévation de privilèges immédiate.

**Règle** : le domaine n'accepte jamais un sac d'attributs. Un use case déclare ses paramètres.

### 9. Annuaire énumérable

`GET /users/:public_id` n'est protégé que par `authenticate_user!` — tout compte connecté affiche la fiche de n'importe qui : nom, téléphone, rôle. Et `set_user` accepte l'identifiant entier en repli :

```ruby
find_by_public_id(params[:public_id]) || find_by_id(params[:public_id])
```

`/users/1`, `/users/2`… parcourt l'annuaire complet et annule l'intérêt du `public_id` opaque.

### 10. Annonces lisibles hors de leur audience

`MessagesController#show` charge une annonce par son slug **sans filtrer** ni `message_status` ni `audience`. Un élève peut lire un brouillon, une archive, ou une annonce destinée aux enseignants — les slugs étant dérivés du titre, donc devinables, et affichés en clair sur chaque carte.

`edit`, `update` et `destroy` ne vérifient jamais l'auteur : tout membre `team` modifie et supprime les annonces des autres.

---

## 🟡 Moyens — à ne pas reproduire

| # | Constat | Règle pour le nouveau projet |
|---|---|---|
| 11 | Mot de passe saisi en `text_field`, **visible à l'écran**, sur 4 formulaires d'inscription sur 5 | `password_field`, toujours |
| 12 | Aucune validation des pièces jointes (type MIME, taille, nombre) alors que `active_storage_validations` est au Gemfile | valider tout téléversement |
| 13 | Énumération de comptes via `/schoolstaff/teachers/new` : « Enseignant introuvable avec ce numéro » | message unique, comme le fait déjà `/login` |
| 14 | Inscription élève **non transactionnelle** — un `User` orphelin occupe le numéro (index unique) et empêche toute réinscription | transaction obligatoire |
| 15 | Aucun index unique sur `students.user_id`, `teachers.user_id`, `teams.user_id`, `school_staffs.user_id`, alors que les associations sont des `has_one` | l'unicité se garantit en base |
| 16 | `creator?` appelle `admin?`, méthode inexistante → 500 pour tout utilisateur qui n'est ni enseignant ni équipe | un helper d'autorisation est couvert par un test |
| 17 | **Aucun journal d'audit** : ni connexion, ni changement de mot de passe, ni suppression de compte | tracer les actions sensibles |
| 18 | `session[:dismissed_messages]` grossit sans borne dans le cookie (limite 4 Ko) — au-delà, déconnexion inexpliquée | l'état utilisateur persistant va en base |

---

## Ajouts de l'exploration du 2026-09-22

L'exploration du 2026-09-22 a trouvé les défauts ci-dessous. Chaque preuve `chemin:ligne` est dans le complément cité. La gravité suit l'échelle de ce document. Les numéros continuent ceux ci-dessus, pour que les références existantes restent justes.

| # | Gravité | Constat | Preuve | Règle pour le nouveau projet |
|---|---|---|---|---|
| 19 | 🔴 | `/teachers/prepa_acquisitions` est une route **publique** sans champ de PIN : chaque compte enseignant qu'elle crée a pour secret son numéro de téléphone. C'est un second chemin du n° 5, **systématique** cette fois | [IC](inventaire/complements-identity-communication.md) ID-06 ; [TR](inventaire/complements-transverse.md) §5.2 (sonde : `authenticate(contact)` vrai) | Même règle que le n° 5 |
| 20 | 🔴 | Tout compte connecté peut **modifier, supprimer ou importer** des établissements : aucune garde de rôle | [SC](inventaire/complements-school-classroom.md) SC-06 à SC-08 | Une policy par use case (PRD cadre §3, `School::ManageSchoolPolicy`) |
| 21 | 🔴 | Rôles et personnel d'un établissement : tout compte connecté les crée ou les supprime. La suppression n'est pas scopée à l'école de l'URL, et un rôle d'une autre école est accepté | [SC](inventaire/complements-school-classroom.md) SC-11 à SC-14 | Même règle que le n° 2 |
| 22 | 🟠 | Tout compte connecté, **élève compris**, peut créer, modifier, supprimer ou importer des fiches | [CA](inventaire/complements-catalog.md) CA-12 à CA-15 | `Catalog::ManageContentPolicy` |
| 23 | 🟠 | `GET /classrooms` renvoie la liste nationale des classes à tout compte connecté. `GET /classrooms/:id` et `/classrooms/:id/students` ouvrent n'importe quelle classe, liste d'élèves comprise | [SC](inventaire/complements-school-classroom.md) CL-14, CL-15, CL-28 | `Classroom::AccessPolicy` |
| 24 | 🟠 | Le CRUD générique du catalogue (`ManageResource`) affecte tout attribut reçu par `send("#{key}=")`, pour toutes les ressources. Le n° 8 ne visait que les comptes | [CA](inventaire/complements-catalog.md) §4 | Même règle que le n° 8 |
| 25 | 🟡 | Le PIN s'affiche aussi **en clair sur la page de connexion**, en plus des formulaires du n° 11 | [IC](inventaire/complements-identity-communication.md) §4 | `password_field`, toujours |
| 26 | 🟡 | Le PDF « Analyse de récurrence » se télécharge sans contrôle de rôle | [TR](inventaire/complements-transverse.md) TR-18 | Toute ressource réservée à un rôle a sa policy |
| 27 | 🟡 | L'espace équipe charge en iframe un artefact externe non inspecté (« LnclassAI ») | [TR](inventaire/complements-transverse.md) TR-14 | CSP stricte ; aucun contenu tiers sans décision |
| 28 | 🟡 | Le nom de fichier fourni par le client entre dans un chemin disque (`tmp/imports/<uuid>_<original_filename>`). Le nettoyage de Rack n'est pas vérifié | [TR](inventaire/complements-transverse.md) §6 n° 8 | Nom de fichier généré côté serveur |

| 29 | 🔴 | **Les bonnes réponses fuient vers les élèves.** La liste des questions de la carte d'exercice est un fragment mis en cache dont la clé ne dépend que de la question, pas du rôle, et ce cache est actif en production. Un élève qui ouvre une fiche après un enseignant reçoit les réponses cochées. Constaté à la lecture du code, non exécuté | [AS](inventaire/complements-assessment.md) AS-39 (`_questions_list.html.erb:24`, `:80` ; `production.rb:16`, `:50`) | Toute clé de cache d'un fragment qui dépend du rôle inclut le rôle ; test : le HTML servi à un élève ne contient aucune bonne réponse, **cache actif** ([PRD cadre §5](prd.md#5-critères-dacceptation-transverses)) |
| 30 | 🟠 | Un élève peut re-soumettre une question déjà corrigée : la réponse est écrasée, le doublon compte dans le score et peut clore la session trop tôt | [AS](inventaire/complements-assessment.md) AS-09 | Une tentative par question et par session, garantie en base (F-34) |
| 31 | 🟡 | L'import de sujets d'examen interpole le message d'erreur et les titres du JSON dans un attribut HTML marqué `html_safe` : injection HTML par un fichier importé | [AS](inventaire/complements-assessment.md) E-25 | Jamais de `html_safe` sur une donnée externe. Feature retirée du plan, règle valable pour tout import |

Le n° 9 est **confirmé à l'exécution** : un élève connecté lit `/users/3016`, contact compris ([TR](inventaire/complements-transverse.md) §5.2).

---

## Le motif, et ce qu'on en retient

Sur six contextes inventoriés, le même défaut revient partout : **l'application vérifie systématiquement l'authentification, et presque jamais l'autorisation.** `before_action :authenticate_user!` répond à « es-tu connecté ? », jamais à « as-tu le droit ? ».

`app/domain/policies/` est annoncé dans `CLAUDE.md`. Le répertoire ne contient aucune policy pour `identity` ni pour `communication`. Il n'y a ni Pundit, ni CASL, ni objet de politique : l'autorisation est un empilement de `before_action` déclarés contrôleur par contrôleur — et un contrôleur qui oublie d'en déclarer est ouvert à tous. C'est exactement ce qui s'est passé pour `/team-signup`.

**La règle qui en découle, pour le nouveau projet :**

> Chaque use case déclare sa policy. Chaque policy a son test. Un use case sans policy ne passe pas la revue.

Ce n'est pas une préférence de style. C'est la seule contre-mesure qui tienne quand 97 % du code est écrit par des agents : un garde-fou déclaré au niveau du métier, testé, et impossible à oublier — au lieu d'une ligne à ne pas oublier en haut d'un fichier.
