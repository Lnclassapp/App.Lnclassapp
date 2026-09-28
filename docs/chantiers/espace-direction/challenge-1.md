# Challenge 1 — Décisions et plan de l'espace direction

| | |
|---|---|
| **Chantier** | `espace-direction`, phases 2 et 3 |
| **Commit relu** | `605e5401` de `feature/espace-direction` |
| **Date** | 2026-09-28 |
| **Rôle** | Challenger, en lecture seule. Aucun fichier existant n'est modifié ; ce rapport est le seul fichier ajouté |
| **Relu** | `memo.md`, `prd.md`, `plan.md`, ADR-0065, 0066, 0067 et les amendements de 0030, 0031, 0036, 0040, 0044, 0057 ; UDR-0052, 0053 et les amendements de 0002, 0006, 0009, 0019, 0020, 0036, 0041, 0050 ; confrontés au code (`app/`, `config/`, `db/schema.rb`, `test/`) |

Légende : **KO** = bloquant (faux, contradictoire, intestable, collision, fichier oublié qui empêche un lot de passer `bin/ci`). **À AMÉLIORER** = non bloquant.

---

## Ce qui a été vérifié et tient

- **Commande de collision du plan** : `awk '/^## Vérification de collision/{exit} 1' docs/chantiers/espace-direction/plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d` renvoie **`db/schema.rb`** seul (0a et F, jamais en parallèle). Aucune collision entre A et G parmi les fichiers *listés*. Les collisions cachées, entre fichiers non listés, sont traitées plus bas.
- **56 critères** ED-01 à ED-56 : tous présents dans le PRD, tous rattachés à un lot et à au moins un fichier de test (tableau « Rattachement »).
- **Quatre champs** présents sur chacun des 9 lots (conventions §6).
- **Q1 respecté par construction** : `ManageSchoolPolicy` reste `actor&.team?` ; `VouchPolicy` exige `actor&.teacher?` (`app/domain/policies/school/vouch_policy.rb:10`). Donner un `school_id` à l'acteur `school_admin` n'ouvre donc pas la validation du garant. ED-23 est testable au Lot 0a.
- **Aucun port recréé** : `StaffRepositoryPort` est bien nouveau ; les méthodes ajoutées (`lock_by_public_id`, `withdraw_all_in_school`, `detach_teacher`, `pending_for`, `find_student_by_number`, `update_student_number`) n'existent pas encore ; les méthodes réutilisées existent (`find_by_contact`, `revoke_expired`, `leave_primary`, `add_primary`, `find_by_id`, `replace_school_code`, `attach_teacher`, `destroy_all_for`).
- **Existant cité exact** : `school_staffs` absente de `db/schema.rb` ; `invitations` porte déjà `kind`, `school_id`, `position` et `invitations_staff_has_school` ; `school_join_requests.teacher_id` est unique ; `classroom_students` a l'index complet `index_classroom_students_on_classroom_id_and_student_id` ; `AcceptInvitation` refuse tout `kind != "team"` ; `HomeDestination` envoie `school_admin` sur `:pending_account` ; `SessionLifetime::ABSOLUTE_TTL` connaît déjà `school_admin`.
- **Composants `ui_*` des UDR** : tous existent dans `app/helpers/components_helper.rb` avec les options citées (`ui_modal size: :sm, trigger_icon:`, `ui_dropdown_item tone: :danger, dialog:`, `ui_loading_state variant: :skeleton`, `ui_error_state retry_href:`, `ui_pagination page:, pages:`, `ui_field as: :tel / :select`, `ui_badge tone: :info / :neutral / :success / :warning`, `ui_empty_state action: { label:, href: }`).
- **Icônes** : `home`, `squares-2x2`, `user-group`, `users`, `building-library`, `plus`, `academic-cap`, `clipboard-document`, `magnifying-glass`, `user-plus`, `arrow-path`, `pencil-square`, `ellipsis-vertical` et `lock-open` sont présentes dans `vendor/heroicons/24/outline`.
- **Tokens** : `bg-school`, `text-brand-strong`, `bg-brand-soft`, `bg-error-soft`, `bg-warning-soft`, `text-mute`, `border-line`, `text-2xs`, `rounded-ln`, `min-h-tap` et `font-display` sont tous définis dans `app/assets/stylesheets/application.tailwind.css`.
- **Contrôleurs Stimulus** : `classroom--join-code-copy`, `modal` et `dropdown` existent ; la frame `modal` est dans `app/views/layouts/application.html.erb:39`.
- **ADR** : les sections 1 à 7 du gabarit sont présentes et remplies ; les §5 (coûts) sont honnêtes. Réserves en 8 et 10.

---

## Points

### KO — bloquants

**1. KO — Le second facteur de la direction renvoie vers l'accueil de l'équipe (fichiers absents de tous les lots)**
- *Où* : ADR-0066 §4.2 (« sans changement d'écran ») ; plan, Lot 0b ; PRD ED-01, ED-12 ; UDR-0052 §3.8.
- *Preuve* : `app/controllers/identity/second_factors_controller.rb:17` → `redirect_to main_app.team_home_path` après une vérification réussie ; `app/views/identity/second_factor_enrollments/backup_codes.html.erb:15` → `ui_button t(".done"), href: team_home_path` ; locale des écrans : « Obligatoire pour les comptes de l'équipe. ». Pour un `school_admin`, `team_home_path` répond 403 (`Teams::BaseController`). Ni ces deux fichiers, ni leur locale, ni leurs tests ne sont listés dans un lot. Le « Done quand » du 0b (« active son second facteur, voit les cinq entrées ») et ED-12 (« arrive sur le tableau de bord ») ne peuvent pas être atteints. Le toast « Bienvenue dans l'espace de <établissement>. » (UDR-0052 §3.8) n'a aucun fichier qui le pose.
- *Correction* : au Lot 0b, ajouter `app/controllers/identity/second_factors_controller.rb` (`redirect_to_home`), `app/views/identity/second_factor_enrollments/backup_codes.html.erb` (`home_path_for(current_actor.role)`), `config/locales/identity/second_factor*.fr.yml` (libellé neutre, par exemple « Obligatoire pour l'équipe et la direction. ») et `test/controllers/identity/second_factors_controller_test.rb` et `second_factor_enrollments_controller_test.rb`. Corriger « sans changement d'écran » dans l'ADR-0066 §4.2, et amender l'UDR qui porte ces écrans (UDR-0019, qui décrit l'activation à la première connexion). Préciser qui pose le toast de §3.8, ou le retirer.

**2. KO — Dépendance cachée de tous les lots envers le Lot D : l'accueil de la direction n'a pas de contrôleur avant D**
- *Où* : plan, Lot 0b (`home_destination.rb`, `authentication.rb` `HOME_ROUTES`) et Lot D (`school_admin/homes_controller.rb`).
- *Preuve* : au 0b, `HomeDestination` envoie un `school_admin` rattaché sur `:school_admin_home`, et `redirect_to_home` y redirige après chaque connexion. Or `SchoolAdmin::HomesController` n'arrive qu'au Lot D. Entre 0b et la fusion de D, un Proviseur rattaché qui se connecte atterrit sur une erreur de routage (`uninitialized constant`, pas une 404). En dépendent : le « Done quand » du 0b, le test système ED-12 (Lot A), et les tests système des lots B, C, E et G, qui passent tous par la connexion. Même symptôme, en plus faible, pour les deux frames de la page Établissement (« répondent 404 » : c'est en réalité une erreur de routage).
- *Correction* : poser `SchoolAdmin::HomesController#show` et une vue minimale (en-tête et état vide) au Lot 0b, que le Lot D remplit ; ou ne faire changer `HomeDestination` pour la direction qu'au Lot D. Écrire « erreur de routage » au lieu de « 404 » dans le « Done quand » du 0b.

**3. KO — Le Lot 0a ne peut pas passer `bin/ci` : `test/architecture/port_contracts_test.rb` exige l'adaptateur de chaque nouvelle méthode de port**
- *Où* : plan, Lot 0a (ports gelés) et Lots C et E (adaptateurs).
- *Preuve* : `port_contracts_test.rb`, « each adapter defines every method of its port » (`next "#{adapter}##{name} n'est pas implémentée" if method.owner == port`). Le 0a ajoute `SchoolRepositoryPort#detach_teacher`, `JoinRequestRepositoryPort#pending_for`, `TeachingRepositoryPort#withdraw_all_in_school` et `ClassroomRepositoryPort#lock_by_public_id`, mais `school_repository.rb`, `join_request_repository.rb`, `teaching_repository.rb` (Lot C) et `classroom_repository.rb` (Lot E) n'ont pas encore ces méthodes : quatre échecs après la fusion du 0a.
- *Correction* : implémenter ces quatre méthodes au Lot 0a, ce qui fait quelques lignes chacune, et y déplacer les quatre adaptateurs et leurs tests de repository. C et E les consomment, sans les modifier. Ou bien déclarer chaque méthode de port dans le lot qui l'implémente, ce qui contredit la règle gelée 1 : à éviter.

**4. KO — Ajouter `school_id` et `school_year` à `Membership` casse cinq fichiers qu'aucun lot ne liste**
- *Où* : ADR-0066 §4.5 (« `Membership` gagne `school_id` et `school_year` ») ; plan, Lot 0a.
- *Preuve* : `Entities::Classroom::Membership = Data.define(:classroom_id, :student_id, :primary, :joined_at, :left_at, :classroom_status)`, sans `initialize` à défauts : tout `Membership.new` sans les nouveaux mots-clés lève `ArgumentError`. Appelants hors du 0a : `app/infrastructure/queries/identity/home_destination_query.rb` (d'ailleurs annoncée comme « modifiée » au PRD §5, mais absente du plan), `test/domain/use_cases/identity/issue_pin_recovery_code_test.rb`, `test/domain/use_cases/identity/read_account_photo_test.rb`, `test/domain/use_cases/assessment/start_exercise_session_test.rb` et `test/domain/use_cases/classroom/join_as_student_test.rb`.
- *Correction* : fixer au §4.5 un `initialize` à défauts (`school_id: nil, school_year: nil`, comme `Actor`), ou ajouter ces cinq fichiers au Lot 0a.

**5. KO — `test/system/role_homes_test.rb` casse au Lot 0b, mais il est attribué au Lot D**
- *Où* : plan, Lot D (« Test associé ») et tableau de collision (« `test/system/role_homes_test.rb` — Lot D »).
- *Preuve* : `role_homes_test.rb:57-62` vérifie `assert_navigation inactive: %i[home classrooms teachers students]` pour un `school_admin`. Une entrée est inactive seulement si sa route n'existe pas (`NavigationHelper#nav_path` : `respond_to?(destination.route)`). Or le 0b dessine toutes les routes : ce test échoue dès le 0b, qui ne passe donc pas `bin/ci`.
- *Correction* : attribuer `test/system/role_homes_test.rb` au Lot 0b (direction sans établissement : écran d'attente et cinq entrées actives). Le Lot D ajoute son cas dans son propre fichier de test système.

**6. KO — Lot F : trois fichiers de test réels cassent et ne sont pas listés**
- *Où* : plan, Lot F.
- *Preuve* :
  - `test/integration/classroom/join_capacity_test.rb` appelle `JoinWithCode` avec un `JoinWithCodeInput` sans matricule, rejeté au Lot F (`presence`) ;
  - `test/infrastructure/orm/user_test.rb:5` (`Orm::User.create!(... role: "student", pin: "1234")`) et `test/infrastructure/orm/models_test.rb:24` (`user("student", …)`) créent un élève sans matricule, que la contrainte `users_student_number_required` du Lot F refuse.
- *Correction* : ajouter ces trois fichiers au Lot F. Documenter aussi, au Lot F, qu'une base de développement existante échoue à la migration, parce que l'élève du seed y est déjà créé sans matricule et que le seed (`find_by || create!`) ne le complète pas : `bin/setup --reset`, ou un seed qui complète le matricule.

**7. KO — Le contrat gelé de `Membership` ne permet ni l'audit `student.placed`, ni « Actuellement en <classe> »**
- *Où* : ADR-0066 §4.4 (audit `{ classroom_public_id:, from_classroom_public_id: }`) et §4.5 ; UDR-0052 §3.6, étape 2 (« Actuellement en <classe> »).
- *Preuve* : `Membership` ne porte que `classroom_id`, qui est un identifiant interne, et `classroom_status`. `ClassroomRepositoryPort` n'offre que `find_by_public_id` et le nouveau `lock_by_public_id`, pas de lecture par identifiant. Le Lot E ne peut produire ni le `public_id` ni le nom de la classe d'origine sans changer un port, ce que la règle gelée 1 lui interdit.
- *Correction* : au §4.5, faire porter `classroom_public_id` et `classroom_name` à `Membership`, rendus par `primary_for`, en plus de `school_id` et `school_year`.

**8. KO — `:invite_principal` est un geste mort : un Proviseur ne peut jamais inviter un Proviseur**
- *Où* : ADR-0066 §4.3 (✅ Proviseur sur `:invite_principal`) et §4.4 (refus `principal_taken` quand un Proviseur est actif) ; PRD §2 (« un Proviseur seulement si aucun n'est actif ») ; UDR-0052 §3.7 (bouton radio « Proviseur » proposé à un Proviseur).
- *Preuve* : l'acteur Proviseur a lui-même une ligne `school_staffs` active (`actor_for`, §4.1). Son invitation d'un Proviseur est donc toujours refusée (`position: [:principal_taken]`), comme le confirme ED-09. La cellule ✅ n'est jamais atteignable, et l'interface propose un choix qui échoue toujours. Le memo le dit aussi : « Seul un Proviseur invite un Proviseur, et il n'y a qu'un Proviseur actif », et « Départ du Proviseur : seule l'équipe le retire ou le remplace ».
- *Correction* : réserver `:invite_principal` à l'équipe (retirer la ✅ du Proviseur et la valeur de `GESTURES["principal"]`), n'afficher « Proviseur » que côté équipe, et réécrire ED-09 en « le Proviseur ne se voit pas proposer la fonction Proviseur ; forcée, elle répond 403 ». Si le porteur veut une passation (le Proviseur invite son successeur), c'est une autre règle, qui porte sur l'acceptation : à trancher.

**9. KO — `RejoinSchoolWithCode` n'a pas de policy, et `test/architecture/use_case_policies_test.rb` l'exige**
- *Où* : ADR-0066 §4.4 (« Geste : — ») ; plan, Lot C.
- *Preuve* : `use_case_policies_test.rb` : tout use case hors de la liste `EXEMPT` (Authenticate, ResetPinWithCode, AcceptInvitation) doit prendre `policy:` en mot-clé requis. Aucune policy n'est nommée, et aucun fichier de policy n'est listé au Lot C. Par ailleurs, l'ADR ne refuse que l'enseignant « rattaché ou en attente », alors que l'UDR-0052 §3.9, cas 2, ne montre pas le formulaire à un enseignant dont la demande est `rejected` : c'est un écart.
- *Correction* : nommer `Policies::School::RejoinSchoolPolicy` (un enseignant, sans école principale, sans demande `pending`, et trancher le cas `rejected`), et l'ajouter au Lot C avec son test.

**10. KO (sécurité) — Un enseignant retiré se rattache de nouveau au même établissement dans la minute**
- *Où* : ADR-0066 §4.4 (`RejoinSchoolWithCode` : « code inconnu, remplacé, établissement inactif ou brouillon » refusés, rien d'autre) ; UDR-0052 §3.9.
- *Preuve* : le code d'établissement est connu de tous les enseignants : il est « diffusé » (PRD §3, étape 3). Rien n'empêche l'enseignant retiré par le Censeur de saisir le code de **A** sur son écran d'attente et d'être rattaché aussitôt, sans validation (`attach_teacher`, comme l'inscription par code). Le retrait (grill 7 : « L'enseignant perd l'accès à l'établissement ») n'a alors plus d'effet, sauf si la direction régénère le code, ce qui casse tous les liens partagés. Aucun critère, aucun coût consenti ne le mentionne.
- *Correction* : refuser `RejoinSchoolWithCode` vers l'établissement qui a retiré l'enseignant (lecture de la dernière ligne `teacher.detached`, ou colonne de retrait), avec le message neutre du code invalide, et ajouter un critère ED de refus. À défaut, l'écrire en coût consenti et faire proposer « Régénérer le code » dans la confirmation du retrait.

**11. KO (sécurité) — L'invitation fait de la direction un oracle des numéros de téléphone, sans limite de débit**
- *Où* : ADR-0066 §4.4 (`InviteStaffMember` : `contact: [:taken]`) ; UDR-0052 §3.7 (« Ce numéro a déjà un compte Lnclass. ») ; memo, grill 1 (« Le numéro de téléphone n'est jamais une clé de recherche pour la direction »).
- *Preuve* : un Proviseur ou un Censeur peut saisir n'importe quel numéro et apprendre s'il a un compte Lnclass, numéros d'élèves mineurs compris. Aucune limite de débit n'est prévue sur `staff_invitations#create`, alors que l'inscription enseignant, qui porte le même oracle, est bornée à 5 par minute et par adresse (`teacher_registrations_controller.rb:9`).
- *Correction* : poser un `rate_limit` par compte sur `SchoolAdmin::StaffInvitationsController#create`, par exemple 10 par heure, avec un critère ED ; journaliser les refus `contact_taken` ; inscrire l'oracle résiduel dans les coûts consentis de l'ADR-0066.

**12. KO (sécurité) — Le paramètre `q` de « Débloquer un compte » expose le matricule et le numéro dans l'URL et dans les journaux**
- *Où* : UDR-0053 §3.3 (GET `?q=`, repli « 303 vers `/teams/accounts?q=<nouveau matricule>` ») ; ADR-0065 (« le matricule n'apparaît jamais dans les journaux de requêtes… jamais dans une URL ») ; PRD ED-56.
- *Preuve* : `config/initializers/filter_parameter_logging.rb` filtre `:contact` et `:student_number`, pas `q`. Passer de `contact` à `q` fait **régresser** le filtrage du numéro de téléphone, qui est aujourd'hui masqué, et écrit le matricule en clair dans `log/` et dans l'historique du navigateur. C'est une contradiction directe avec l'ADR-0065.
- *Correction* : ajouter `/\Aq\z/` à `filter_parameters` au Lot 0a (une expression rationnelle, pour ne pas masquer tout paramètre qui contient « q »), avec un cas dans le test existant `test/integration/parameter_filtering_test.rb` ; limiter la phrase de l'ADR-0065 à la direction, ou faire passer la recherche de l'équipe en `POST` ; ne jamais mettre le matricule dans l'URL de repli.

**13. KO — UDR-0053 : le nom de route donné ne correspond pas à la déclaration**
- *Où* : UDR-0053 §3.3 (« Routes » et `_result`).
- *Preuve* : dans `namespace :teams`, `get …, as: :edit_account_student_number` produit `teams_edit_account_student_number_path`, pas `edit_teams_account_student_number_path`. L'existant le montre : `as: :member_second_factor_reset` (`config/routes/teams.rb:51`) donne `teams_member_second_factor_reset_path` (`_result.html.erb:58`). Un agent qui applique l'UDR à la lettre obtient une `NoMethodError`.
- *Correction* : déclarer `resources :accounts, only: [], param: :user_public_id do resource :student_number, only: %i[edit update], path: "student-number" end`, ce qui donne `edit_teams_account_student_number_path` et `teams_account_student_number_path` ; ou corriger le nom du helper dans l'UDR et dans `test/routing/school_admin_routes_test.rb`.

**14. KO — ED-41 est intestable tel qu'écrit : les trois corps de réponse ne peuvent pas être identiques**
- *Où* : PRD ED-41 (« le même corps de réponse, jeton CSRF excepté ») ; ADR-0065 §7 (« octet pour octet ») ; UDR-0052 §3.6, étape 1.
- *Preuve* : les trois recherches portent sur trois matricules différents. Si l'étape 1 re-rendue en échec garde la saisie (c'est la convention des formulaires en 422, et l'UDR-0053 §3.1 l'écrit pour l'inscription), les corps diffèrent par la valeur du champ. L'UDR-0052 §3.6 ne dit pas si le champ est vidé.
- *Correction* : écrire dans l'UDR-0052 §3.6 que l'échec neutre re-rend le champ **vide**, ce qui retire en plus le matricule de la réponse ; ou comparer les corps hors jeton CSRF **et** hors valeur du champ, en le disant dans ED-41.

**15. KO — La feuille de route contredit encore Q1 dans la porte de la V2**
- *Où* : `docs/chantiers/refonte-application/feuille-de-route.md`, V2, lignes « Porte » et « Ajouts venus des chantiers hors plan ».
- *Preuve* : « Porte : … une direction ne valide que les enseignants en attente de son établissement (test de refus) » et « La direction valide ou refuse les enseignants en attente de son établissement ». Q1 (memo) et ED-23 disent l'inverse. La ligne « Reste » liste encore ID-09 et SC-23, sortis par le grill 6. Le commit a touché ce fichier (C-31) sans corriger ces lignes : la porte de la vague n'est pas franchissable telle qu'écrite.
- *Correction* : réécrire la porte en « la direction ne valide pas les enseignants en attente (Q1, ED-23) », barrer l'ajout reporté par `croissance-parrainage` en renvoyant à Q1, et faire passer ID-09 et SC-23 en V3.

**16. KO — Dépendance cachée du Lot B envers le Lot C (écran d'attente de la direction)**
- *Où* : plan, Lot B (`test/system/school_admin/staff_test.rb`, ED-15 : « il voit l'écran d'attente « Aucun établissement » ») et Lot C (propriétaire de `identity/pending_accounts/show` et de sa locale).
- *Preuve* : le texte « Aucun établissement » n'existe qu'après le Lot C. Aujourd'hui, un `school_admin` voit la variante `other` (`pending_accounts_controller.rb`, `CASES = %i[student teacher]`). Le test système de B échoue tant que C n'est pas fusionné. ED-03 (Lot 0b) évite le piège : il ne vérifie que la redirection.
- *Correction* : déplacer la variante « direction sans établissement » de l'écran d'attente (vue, locale, cas du contrôleur) au Lot 0b, qui en a besoin pour son propre « Done quand » (« un Proviseur retiré atterrit sur l'écran d'attente ») ; le Lot C garde la variante « enseignant retiré ». Sinon, ED-15 au Lot B ne vérifie que `pending_account_path`.

**17. KO — Dépendance cachée des Lots C et E envers le Lot D : la liste des classes de l'année**
- *Où* : UDR-0052 §3.5 (filtre « les classes de l'année groupées par niveau en `optgroup` »), §3.6 (filtre et `select` « 6ème 2 — 34 / 80 ») ; plan, `Queries::School::DirectionClassroomsQuery` au Lot D.
- *Preuve* : les Lots C et E ont besoin de la même lecture « classes actives de l'année de l'établissement, par niveau, avec effectif et plafond », mais la seule query prévue appartient au Lot D. Il ne reste que deux issues : le dupliquer, ou attendre D.
- *Correction* : déplacer `direction_classrooms_query.rb` et son test au Lot 0b, qui en est le socle ; D, C et E la lisent sans la modifier.

**18. KO — Fichiers de locale oubliés pour les partiels partagés**
- *Où* : plan, Lot A (`app/views/shared/staff_invitations/_form`, `_created`) et Lot B (`app/views/shared/staff_members/_member`).
- *Preuve* : `t(".key")` (CLAUDE.md, règle 3) dans ces partiels cherche `shared.staff_invitations.form.*`, `shared.staff_invitations.created.*` et `shared.staff_members.member.*`, qui doivent vivre dans `config/locales/shared/staff_invitations.fr.yml` et `config/locales/shared/staff_members.fr.yml`. Aucun lot ne liste ces fichiers ; les agents ont interdiction de toucher un fichier hors de leur champ (plan, « Dispatch »).
- *Correction* : ajouter `config/locales/shared/staff_invitations.fr.yml` au Lot A et `config/locales/shared/staff_members.fr.yml` au Lot B.

**19. KO — UDR-0052 §3.10 : identifiant DOM en double sur la fiche équipe**
- *Où* : UDR-0052 §3.10.
- *Preuve* : `turbo_frame_tag "school_staff"` contient `ui_card#school_staff`, et le retrait fait `replace "school_staff"`. La réponse de la frame porte donc deux éléments `id="school_staff"`. Le `replace` cible le premier, c'est-à-dire la frame elle-même, et remplace la frame par la carte : les rechargements suivants de la frame ne marchent plus.
- *Correction* : nommer la carte `#teams_school_staff` (comme `#direction_staff` côté direction) et faire cibler le `replace` sur elle.

**20. KO — Les signatures des use cases ne sont pas gelées, et les codes de refus se contredisent**
- *Où* : ADR-0066 §4.4 ; PRD ED-38 et ED-47 (« le cas d'usage … répond « forbidden » s'il reçoit l'établissement B »).
- *Preuve* : le §4.4 ne donne aucun paramètre d'entrée. « Recevoir l'établissement B » suppose un paramètre `school_id:` ou `school_public_id:` que rien ne déclare. De plus, le §4.4 dit que `PlaceStudent` répond `:not_found` pour une « classe d'un autre établissement », alors qu'ED-47 attend `forbidden`.
- *Correction* : ajouter au §4.4 une colonne « Signature » (par exemple `DetachTeacher#call(actor:, school_id:, teacher_public_id:)`, `PlaceStudent#call(actor:, school_id:, dto:)`), et écrire la règle : établissement ≠ celui de l'acteur → `:forbidden` (policy) ; ressource hors de l'établissement → `:not_found`.

### À AMÉLIORER — non bloquants

**21. À AMÉLIORER — Le refus « Éducateur **et** Secrétaire » n'est testé que pour l'un des deux**
- *Où* : PRD §4, en-tête (« chaque geste sensible son refus Éducateur et Secrétaire (ED-08, ED-16, ED-21, ED-37) »).
- *Preuve* : ED-16 ne nomme que l'Éducateur, ED-21 que l'Éducateur, ED-37 que la Secrétaire ; seul ED-08 nomme les deux. La table de `StaffPolicy` est testée cellule par cellule, mais pas au niveau du contrôleur, où se joue le 403 annoncé.
- *Correction* : « Étant donné l'Éducateur de A et la Secrétaire de A … Alors chacun reçoit 403 » dans ED-16, ED-21 et ED-37. Ajouter aussi le refus inter-établissements de `FindStudentForPlacement` (absent de la liste des sept) et un test de use case pour `DetachStaffMember` avec un membre de B (ED-18 n'a que le 404 du contrôleur).

**22. À AMÉLIORER — `StaffPolicy`, exemple de code : le geste inconnu ne lève que pour un membre**
- *Où* : ADR-0066 §6 et §7 (« geste inconnu → `ArgumentError` »).
- *Preuve* : pour l'équipe, `ALL_GESTURES.include?(gesture)` faux → on tombe dans `member_of?` → `:forbidden`, sans exception ; pour un non-membre, `member_of?` échoue avant `allows?`. Le test du §7 ne passe qu'avec un membre.
- *Correction* : vérifier le geste en première ligne de `call` (`raise ArgumentError unless ALL_GESTURES.include?(gesture)`).

**23. À AMÉLIORER — « Rien n'est créé » exige une annulation que `TransactionPort#call` ne fait pas sur un `Result` en échec**
- *Où* : ADR-0066 §4.4 (`AcceptInvitation`, et aussi `PlaceStudent`).
- *Preuve* : `Repositories::Shared::Transaction#call` n'annule que sur exception. Si `StaffRepositoryPort#attach` rend `failure(:conflict)` après la création du compte, le compte reste. Le motif existe : `JoinWithCode` fait `raise Aborted, added if added.failure?`.
- *Correction* : nommer ce motif au §4.4, ou vérifier `principal_active?` et le statut de l'établissement avant toute écriture.

**24. À AMÉLIORER — Le compteur `school_code` n'est pas partagé entre deux contrôleurs**
- *Où* : UDR-0052 §3.9 (« compteur `school_code` de `/e/<code>` »).
- *Preuve* : sous Rails 8.1 (`Gemfile.lock` : actionpack 8.1.3.1), la clé de `rate_limit` inclut par défaut la portée du contrôleur (option `scope:`, qui vaut `controller_path`). Le même `name:` dans `Identity::SchoolRejoinsController` crée donc un second compteur. Je n'ai pas pu le vérifier dans les sources, les gems n'étant pas installées dans cet environnement ; à confirmer par le lot.
- *Correction* : écrire `scope: "identity/teacher_registrations"` si le partage est voulu, ou dire « compteur propre, 10 par minute et par adresse ».

**25. À AMÉLIORER — « Changer de classe » consomme la limite anti-sondage**
- *Où* : UDR-0052 §3.6 (l'item du menu fait un `POST lookup` avec le matricule) ; ADR-0065 (10 par minute, recherche et rattachement confondus).
- *Preuve* : chaque changement de classe coûte deux appels (`lookup` puis `create`) : une Secrétaire qui corrige les classes d'un lot d'élèves reçoit 429 dès le cinquième élève de la minute, alors que l'élève est déjà dans son établissement et qu'il n'y a rien à sonder.
- *Correction* : pour un élève déjà listé, ouvrir l'étape 2 par son `public_id` (lecture bornée à l'établissement), sans matricule et hors compteur. Préciser aussi `role="menuitem"` et `tabindex="-1"` sur ce `button_to` placé dans le `ui_dropdown` (UDR-0042).

**26. À AMÉLIORER (données de mineurs) — La moyenne d'une petite classe révèle une note nominative**
- *Où* : ADR-0067 §4 ; UDR-0052 §3.4 ; ED-30.
- *Preuve* : une classe d'un seul élève, ou dont un seul élève a rendu, affiche sa moyenne sur la page de la classe, et la liste des élèves filtrée par cette classe (Lot E) donne son nom. Chaque page, prise seule, respecte ED-30, mais leur croisement contredit le moteur 2 de l'ADR-0067 (« Aucune note nominative »).
- *Correction* : afficher « — » quand moins de N élèves (par exemple 5) ont rendu, et l'écrire comme définition de l'ADR-0067, avec un test. Ce n'est pas une remise en cause du grill 9, délégué : c'est le moyen de tenir sa règle.

**27. À AMÉLIORER — Une direction sans établissement lit encore le catalogue**
- *Où* : PRD §2 (« Direction sans établissement … ne peut pas : tout le reste ») ; ED-03.
- *Preuve* : `test/controllers/catalog/courses_controller_test.rb:210` (« a school staff member reads the catalogue ») : `courses_path` n'a pas de garde de rôle, et aucune garde du type `hold_pending_teacher` n'est prévue pour la direction.
- *Correction* : ajouter une garde `hold_detached_school_admin` dans `AuthenticatedController` (Lot 0b), ou réduire le PRD à « tout l'espace direction ».

**28. À AMÉLIORER — Détails de l'UDR-0052**
- §3.2 : `grid grid-cols-3` pour les trois chiffres, alors que le §3.0 impose `grid-cols-2 sm:grid-cols-4` à 390 px ; trancher.
- Amendement de l'UDR-0006 : « Les quatre routes de la direction sont dessinées » ; il y en a cinq.
- §3.3 : le focus « via `autofocus` » après un `replace` en Turbo Stream n'est pas garanti ; nommer le mécanisme (contrôleur Stimulus existant, ou `data-turbo-permanent`).
- ED-20 et `test/system/school_admin/school_code_test.rb` : `/e/<code>` redirige un visiteur connecté vers son accueil (`teacher_registrations_controller.rb:24`) ; le test doit se déconnecter avant de vérifier la 404.

**29. À AMÉLIORER — ADR-0065 : un point de vérification et un point à confirmer manquent**
- §7 cite « `test/integration/filter_parameters_test.rb` (ou l'existant) » : le fichier existant est `test/integration/parameter_filtering_test.rb`, et il n'est dans aucun lot ; l'ajouter au Lot 0a.
- Le journal marque « l'anonymisation efface le matricule ; il redevient libre » comme **point à confirmer**, et le grill 3 dit « jamais réattribué ». Le §9 ne le reprend pas ; l'ajouter.
- ED-41 fabrique « le matricule d'un compte anonymisé », un état que `AnonymizeUser` (amendement de l'ADR-0036) rendra impossible. Garder le cas, mais le dire.
- `school_staffs` n'a aucune garantie que `user_id` est un `school_admin` (un `CHECK` ne peut pas lire `users`). L'écrire en coût, ou le faire vérifier par `StaffRepository#attach`.

**30. À AMÉLIORER — La taille des socles**
- *Où* : plan, Lots 0a (29 fichiers) et 0b (21 fichiers) ; `.claude/skills/plan-lots/SKILL.md` : « Si le Lot 0 dépasse une poignée de fichiers, c'est qu'il contient du métier qui appartient à un lot vertical. Redécoupe. »
- *Preuve* : la scission 0a/0b est justifiée (journal). Les points 1 à 5, 16 et 17 ajoutent pourtant environ 15 fichiers aux socles.
- *Correction* : accepter explicitement la taille dans le journal, ou isoler un lot séquentiel « second facteur de la direction » (point 1) entre 0a et 0b.

---

## Verdict global

**Non prêt pour le Lot 0a.** Le fond est solide : le cadrage du porteur est respecté (Q1, Q2, Q3, grills 1 à 9), `StaffPolicy` est la bonne option, l'existant est cité exactement, les UDR n'utilisent que des composants, icônes et tokens réels, et la commande de collision du plan passe.

Mais **20 points bloquants** empêchent l'exécution telle qu'écrite :

- **Des socles qui ne passent pas `bin/ci` seuls** : `port_contracts_test` (3), `Membership` (4), `role_homes_test` (5) ;
- **Le parcours nominal est cassé dès le 0b** : second facteur renvoyé vers l'équipe (1), accueil sans contrôleur avant D (2) ;
- **Des dépendances cachées entre lots parallèles** (16, 17) et **des fichiers oubliés** (6, 9, 18) ;
- **Des contrats incomplets ou faux** (7, 13, 20), un geste mort (8), un critère intestable (14), une identité DOM en double (19) et une porte de vague contradictoire (15) ;
- **Trois trous de sécurité** : retour immédiat de l'enseignant retiré (10), oracle des numéros sans limite de débit (11), matricule et numéro en clair dans l'URL et les journaux (12).

Presque tous se corrigent **dans les documents** : ajouter des fichiers aux listes, déplacer quelques-uns vers 0b, ajouter une colonne ou un défaut à un contrat. Seuls les points 8, 10 et 11 demandent un arbitrage du porteur. Une fois ces corrections faites, un second challenge court sur les seuls points KO suffit.
