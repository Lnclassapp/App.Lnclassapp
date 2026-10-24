# Journal — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-24 | Lot 0 : `classrooms.join_code` a un défaut en base (6 symboles tirés de `gen_random_uuid`, comme le jeton du lien), en plus de la génération du domaine | Le `insert_all!` des classes générées, le SQL brut des tests de contraintes et les graines n'appellent pas le générateur ; sans défaut, le `NOT NULL` les casse tous | Non (précision de l'ADR code de classe §4.2) |
| 2026-10-24 | Lot 0 : `find_by_join_code` et `regenerate_link_and_code` sont **implémentés** dans le repository, pas seulement posés dans le port | `test/architecture/port_contracts_test.rb` exige que l'adaptateur définisse chaque méthode du port ; le Lot A n'a plus qu'à les brancher | Non |
| 2026-10-24 | Lot 0 : l'enseignant n'a plus d'entrée « Annonces » dans la barre latérale (`DESTINATIONS[:teacher]` : accueil, classes, cours) | CA-K1 : aucune entrée de navigation ne lui propose les annonces ; routes et code gardés | Non |
| 2026-10-24 | Lot A : le code passe par le DTO (`StudentRegistrationInput#join_code`) et `ClassroomDesignation#coded` / `#coded_or_chosen`, partagés par `RegisterStudent`, `JoinAsStudent` et `ChangeClassroom` ; priorité lien valide > code > cascade, un code inconnu ne retombe pas sur la cascade | Une seule règle de désignation pour les trois cas d'usage ; un code archivé ou d'un établissement inactif répond « inconnu » comme à la vérification (CA-B3) | Non (précision de l'ADR code de classe §4.6) |
| 2026-10-24 | Lot A : `POST /students/classroom` est limité au même compteur `classroom/joins` (10 par minute et par IP) | Sinon un élève connecté devine des codes sans limite par ce POST : l'ADR ne le disait pas, la vérification seule ne suffit pas | Non |
| 2026-10-24 | Lot A : « Changer le lien et le code » est journalisé en `school.changed` (`change: classroom_link_and_code_changed`, classe, acteur, date), sans le jeton ni le code | Réutilise l'action d'audit existante des changements de classe ; aucun secret dans le journal | Non |
| 2026-10-24 | Lot B : un seul formulaire, trois `fieldset` ; `signup_steps_controller.js` ne cache les étapes qu'à sa connexion (sans JavaScript, les trois restent visibles) ; le formulaire est `novalidate` et le serveur juge | Un `required` caché (liste DRENA de la cascade, étapes quittées) bloquerait l'envoi en silence ; le serveur renvoie déjà chaque erreur sous son champ et rouvre l'étape qui la porte | Non (UDR inscription §3.1, §3.5) |
| 2026-10-24 | Lot B : le bouton « Créer mon compte » n'attend plus une classe cochée (`class-picker#submit` retiré) ; « Création… » vient de `data-turbo-submits-with` | Avec le code, aucune classe n'est cochée ; la classe est exigée par le serveur | Non |
| 2026-10-24 | Lot B : le rappel de classe de l'étape 2 montre « Ta classe » + nom + établissement (sigle ou nom), pas le niveau ; le visiteur d'un lien n'a pas d'étape 1 (« Ce n'est pas ta classe ? » est un vrai lien vers `/student-signup`), l'inscription par code garde l'étape 1 (« Ce n'est pas ta classe ? » vide le code et y revient) | UDR §3.3 ; l'aperçu du code (Turbo Frame du Lot A) porte `data-classroom-name` et `data-school-label` pour nourrir le rappel | Non |
| 2026-10-24 | Lot B : l'envoi de l'inscription partage le compteur `classroom/joins` (10 par minute et par IP) ; au-delà, le formulaire revient en 429 avec « Trop de tentatives. Attends une minute, ou coche « Je n'ai pas de code ». » à l'étape 1 (étape 2 par un lien, sans la mention de la case) ; le code n'est pas cherché pour un 429 | CA-B4 ; rendre l'aperçu d'un code sur un envoi refusé en serait une devinette de plus | Non (ADR code de classe §4.5) |
| 2026-10-24 | Lot B, revue sécurité : l'envoi garde aussi son plafond propre de 5 par minute et par IP (`signup`, ADR-0085 §4.6), en plus du compteur partagé `classroom/joins` | Sans lui, le plafond de l'envoi doublait (5 → 10) : deux fois plus de numéros sondés (« déjà inscrit ») et de comptes fictifs par minute | Non |
| 2026-10-24 | Lot B : captures validées ; sans JavaScript, un code tapé l'emporte sur « Je n'ai pas de code » cochée (porteur, 2026-10-24 : « oui pour 1, 2 et 3 ») | Le serveur suit la priorité lien > code > cascade ; avec JavaScript, cocher la case vide et désactive le champ du code | Non |
| 2026-10-24 | Lot B : l'étape ouverte après une erreur est calculée dans la vue (première étape qui porte une erreur, au moins l'étape 2 par un lien) | Le contrôleur Stimulus reçoit `start`, et le re-rendu 422 (morphing) le relit | Non |
| 2026-10-24 | Lot D : l'ordre des états de la carte suit la table de l'UDR (6, 2, 1, 3, 4, 5) : une fiche à revoir passe donc avant « Aucun exercice assigné » (« tout l'assigné est terminé » est vrai sans assignation) | Un élève sans travail de l'enseignant mais avec une fiche à revoir voit « À revoir » plutôt que l'exercice du jour ; l'inverse cacherait sa fiche, plus listée sur l'accueil | Non |
| 2026-10-24 | Lot D : sous lg, le bandeau (`content_for :home_band`) est rendu par le shell au-dessus de la colonne et l'en-tête est masqué (`max-lg:hidden`) ; l'avatar du bandeau mène à `student_menu_path` (page « Mon compte » de E1), le menu déroulant de l'en-tête reste celui de lg | `_avatar_menu` est à E1 : ancré à droite, il déborderait de l'écran depuis le bandeau à gauche ; la page du panneau existe déjà et E1 la met à la liste de l'UDR | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : l'ADR code de classe dit « 31 symboles, sans i, l, o, 0, 1 » et « 31⁶ ≈ 887 millions », mais la contrainte qu'il prescrit (`^[a-hj-np-z2-9]{6}$`) et `SchoolCode` en admettent 32 (le `l` est dans `j-n`). Le Lot 0 suit la contrainte et `SchoolCode` (32 symboles, 32⁶ ≈ 1,07 milliard) ; le PRD CA-B1 dit « sans i, l, o, 0, 1 » : à trancher par le porteur (retirer `l` impose la contrainte `[a-hj-kmnp-z2-9]`). **Tranché le 24 octobre** : le porteur retire le `l` ; fait au Lot A (31 symboles, contrainte `[a-hjkmnp-z2-9]`, défaut SQL sur deux octets modulo 31). `SchoolCode` garde ses 32 symboles.

- Lot A : l'ADR et CA-B4 écrivent « Trop d'essais » ; `test/i18n/locale_files_test.rb` interdit « essai » à l'écran (UDR-0007). Le message est « Trop de tentatives. Attends une minute, puis réessaie. » (comme `/c/<jeton>`) ; PRD, ADR et UDR inscription alignés sur « Trop de tentatives » (UDR-0007).
- Lot A : la fiche ne listait ni `ClassroomDesignation`, ni `StudentRegistrationInput`, ni `StudentArrivalChannel`, ni `ClassroomLinksController` ; ils sont inséparables de « RegisterStudent résout par code » (aucun autre lot ne les touche). `StudentRegistrationsController` (Lot B) doit encore accepter `join_code` dans `FIELDS` et partager le compteur à l'envoi.
- Lot B : le texte « code inconnu » de la vérification (Lot A : « …Vérifie-le, ou demande-le à ton enseignant. ») différait de l'UDR §3.2 (« …Vérifie-le avec ton enseignant. ») ; aligné sur l'UDR dans `classroom_codes.fr.yml` et `student_classroom_choices.fr.yml`. Le 429 de l'aperçu dit aussi « …ou coche « Je n'ai pas de code » » (UDR §3.2).
- Lot B : cinq tests système hors fiche remplissaient l'ancien formulaire d'une page (`pin_reveal_test`, `boucle_pedagogique_test`, `error_paths_test`, `public_pages_test` x2) ; ils passent par l'étape 2 puis l'étape 3, ou cherchent le rappel de classe (`#signup-classroom-recap`) à la place de `#classroom-preview`. La suite complète du train les rejoue.
- Lot B : `form_with novalidate: true` n'écrit pas l'attribut (Rails l'écarte) : il faut `html: { novalidate: true }`. Sans lui, le navigateur refusait l'envoi à l'étape 3 pour un `required` caché de la cascade.
- Lot D : la fiche demande de supprimer `_invite_teacher`, mais « Ma classe » (`student_classrooms/_no_teacher`) le rend encore en `standalone` : gardé, ainsi que `_pending_gaps` (E2). La « durée » du méta (« Maths · M. Kouassi · 15 min ») n'a aucune donnée (pas de colonne sur `exercises`) : le méta s'arrête à l'enseignant. « cette semaine » (état 4) est omis : rien ne borne l'assigné à la semaine. La pastille d'échéance non en retard est celle de `due_badge` (neutre sous deux jours), non le `brand-soft` de l'UDR : `DueDateHelper` n'est pas au lot.
- Lot D : l'erreur « code inconnu » de l'état 6 n'a pas de champ où s'afficher : le formulaire de l'accueil poste vers `student_classroom_choices#create`, qui re-rend `new` (la cascade), laquelle ne montre que `errors[:base]`. À corriger dans `student_classroom_choices/new` (hors fiche).
- Lot D : l'historique ne dit pas « Lue » (les fiches lues, `essential_reads`, ne sont pas dans `recent_sessions`) et n'a pas l'état d'erreur « Réessayer » du frame (il demande un contrôleur Stimulus).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La garde `test/guards/migration_rules_test.rb` compare à `origin/main` : sans cette référence locale (`git fetch origin main`), elle échoue sur d'anciennes migrations. La migration `20261008120000_remove_classroom_join_codes` porte maintenant l'exception `# migration-en-deux-temps:` (la colonne de 5 caractères part, celle de 6 revient dans la même livraison).
- `ActiveRecord insert_all!` ne lit ni les `attribute … default:` ni les callbacks : tout défaut d'une colonne `NOT NULL` ajoutée doit être en base.
- `test/design/design_tokens_test.rb` interdit toute valeur arbitraire Tailwind (`text-[13px]`, `group-has-[…]`) : la sous-ligne « 13 px » de l'UDR devient `text-sm` (aucun jeton de 13 px), et l'ouverture de la cascade se fait dans le contrôleur Stimulus, pas par une variante `:has` du CSS.
- `test/guards/system_budget_test.rb` : un test système nouveau doit être enregistré dans `script/ci/test_timings.yml` (`script/ci/record_timings`) ; `student_signup_steps_test.rb` y ajoute 10,5 s ; le test ajouté par la revue (un code, puis « Je n'ai pas de code ») a été fondu dans celui de la cascade, sinon le fichier pesait 20 s, au-delà du budget.
- La base de test d'un worktree créée par `db:prepare` est **seedée** (niveaux « Tle »…) : les factories échouent sur `index_levels_on_name`. `db:drop db:create db:schema:load RAILS_ENV=test` donne une base vide.
- Une carte `rounded-card shadow-card` va bord à bord sous 640 px (`data-bleed`) : `data-bleed-keep` sur la colonne de l'accueil la garde arrondie dans la marge, à cheval sur le bandeau.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `_class_picker.html.erb` garde `font-display font-bold` (légendes, nom de l'établissement) | Partagé avec « Choisis ta classe » et « Changer de classe », hors de la fiche du Lot B ; le balayage des graisses est le Lot Z | Lot Z |
| Les trois étapes s'affichent un instant avant la connexion de Stimulus | Report accepté par le porteur (2026-10-24, point 3) | Lot de finition |
| Sous-ligne des étapes en `text-sm` (14 px) au lieu de 13 px | Aucun jeton de 13 px, les valeurs arbitraires sont interdites | À trancher avec la palette (Lot P) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
