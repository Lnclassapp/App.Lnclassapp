# Journal — Espace direction

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros réservés : ADR-0065 à 0067, UDR-0052 et 0053. `annuaire-equipe` prendra à partir d'ADR-0068 et d'UDR-0054 | Relevé sur toutes les branches distantes (plus haut : ADR-0064, UDR-0051) ; deux chantiers V2 en parallèle | — |
| 2026-09-28 | Trois ADR au lieu d'un : matricule (0065), droits et gestes (0066), tableau de bord (0067) | Trois décisions qui vieillissent différemment : le format du matricule peut changer seul ; les définitions du tableau de bord suivent l'ADR-0062 | ADR-0065, 0066, 0067 |
| 2026-09-28 | Une policy à gestes, `School::StaffPolicy`, plutôt qu'élargir `ManageSchoolPolicy` | `ManageSchoolPolicy` autorise aussi la validation des comptes en attente (refusée par Q1), l'import et les DRENA : l'élargir aurait donné ces gestes à la direction | ADR-0066 §3 |
| 2026-09-28 | La direction a le « + » mais pas le « − » des classes | Q3 : « ajoute la classe suivante d'un niveau » ; le retrait n'a pas été demandé. Point à confirmer | ADR-0066 §9 |
| 2026-09-28 | Index unique de `classroom_students` rendu partiel (`WHERE left_at IS NULL`) | Le cas du grill « erreur de classe » est un aller-retour, que l'index de l'ADR-0040 interdisait | ADR-0066, amende ADR-0040 |
| 2026-09-28 | Obligation du matricule posée en deux migrations (0a : format, unicité, rôle ; F : obligatoire) | Poser l'obligation au Lot 0a casserait l'inscription élève jusqu'à la fusion du Lot F ; la branche doit rester verte entre les lots | ADR-0065 §6 |
| 2026-09-28 | L'anonymisation efface le matricule ; il redevient libre | Minimisation des données de mineurs (ADR-0036) ; « jamais réattribué » = jamais porté par deux comptes vivants. Point à confirmer | ADR-0065, amende ADR-0036 |
| 2026-09-28 | Une invitation de direction ne vise qu'un numéro sans compte | Rattacher un compte existant (enseignant qui devient Censeur) demande un parcours d'authentification à l'acceptation ; hors V2 | ADR-0066 (coûts) |
| 2026-09-28 | Un enseignant retiré revient par un code d'établissement depuis l'écran d'attente (`RejoinSchoolWithCode`) | Grill 7 : « peut rejoindre un autre établissement par son code » ; aucun parcours ne le permettait pour un compte existant | ADR-0066 §4.4 |
| 2026-09-28 | Cinquième destination « Établissement » (code et personnel) | Le code et le personnel n'avaient pas de place dans les quatre destinations prévues par l'UDR-0006 ; cinq est le maximum | UDR-0052, amende UDR-0006 |
| 2026-09-28 | Les listes de la direction affichent les initiales, pas la photo | Élargir `ReadUserPolicy` (ADR-0060) toucherait une policy que `annuaire-equipe` va modifier | ADR-0066 (coûts) |
| 2026-09-28 | Deux socles séquentiels (0a données et contrats, 0b accès et fichiers partagés) | Le socle dépasse une poignée de fichiers : un nouveau rôle actif et sept contrats. Chaque moitié reste démontrable | — |
| 2026-09-28 | Accueil de la direction : squelette au Lot 0b, repris par le seul Lot D | `HomeDestination` mène la direction à son accueil dès le Lot 0b : sans page, la connexion aboutirait à une erreur jusqu'à la fusion de D. Relevé en relecture du plan | — |
| 2026-09-28 | Challenge 1 ([`challenge-1.md`](challenge-1.md)) : 20 KO, 10 à améliorer, tous traités dans les documents | Voir « Ce qui a dérapé » | ADR-0065, 0066, 0067 amendés avant acceptation |
| 2026-09-28 | Seule l'équipe invite un Proviseur (point 8) | Un seul Proviseur actif : un Proviseur ne peut jamais en inviter un second ; le geste était mort. Passation à confirmer | ADR-0066 §4.3 |
| 2026-09-28 | Table `teacher_school_departures` ; retour par code refusé vers l'établissement qui a retiré (point 10) | Le code est diffusé : sans ce refus, le retrait n'a aucun effet. Coût : un retrait par erreur ne se défait pas en V2 | ADR-0066 §4.4 |
| 2026-09-28 | Invitations bornées à 10 par heure et par compte (point 11) | L'invitation dit si un numéro a un compte : oracle des numéros de mineurs | ADR-0066 |
| 2026-09-28 | `q` filtré des journaux ; repli sans matricule dans l'URL (point 12) | Passer de `contact` à `q` aurait fait régresser le filtrage du numéro | ADR-0065 |
| 2026-09-28 | Moyenne « — » sous 5 élèves ayant rendu (point 26) | Croisée avec la liste des élèves, la moyenne d'un ou deux élèves est une note nominative | ADR-0067 |
| 2026-09-28 | « Changer de classe » par identifiant public, hors compteur (point 25) | L'élève est déjà dans l'établissement : rien à sonder ; la limite bloquait la correction d'un lot d'élèves | ADR-0066 §4.4, UDR-0052 §3.6 |
| 2026-09-28 | Adaptateurs des nouvelles méthodes de port, écran d'attente, `DirectionClassroomsQuery`, second facteur, garde de la direction et `role_homes_test` remontés aux socles (points 1, 3, 5, 16, 17, 27) | `port_contracts_test` et les fichiers touchés par plusieurs lots | — |
| 2026-09-28 | Profil (`_information`, `ProfileQuery`) et écran d'attente attribués chacun à un seul lot (0b, C) | Deux lots les auraient touchés (profil : direction et matricule ; attente : direction et enseignant retiré) | — |
| 2026-09-28 | Relecture de la phase Décider par le porteur : ADR-0065, 0066, 0067, UDR-0052, 0053 **acceptés avec retours** ; amendements datés passés à « accepté » ; C-31 fermée dans la feuille de route | Porteur | Statuts et index |
| 2026-09-28 | **Réintégration** d'un enseignant retiré par le Proviseur ou le Censeur (`School::ReinstateTeacher`, `:reinstate_teacher`), depuis « Enseignants retirés » ; `teacher_school_departures` gagne `reinstated_at`/`reinstated_by_id` et un index unique partiel « un départ ouvert » ; `departed?` = départ ouvert | Porteur : « aucun écran ne permet d'annuler un retrait » ; le code d'établissement refuse toujours le retour seul | ADR-0066 §4.3, §4.4 ; ED-60 à ED-63 |
| 2026-09-28 | La réintégration rend l'établissement, **pas les classes** : l'enseignant se redéclare (`DeclareTeaching`) | Délégué par le porteur ; garder les déclarations dans le départ ajouterait une table ou une colonne sérialisée | ADR-0066 §9 (amendable) |
| 2026-09-28 | Un enseignant retiré qui a rejoint un autre établissement, ou anonymisé, n'est plus réintégrable ; `:not_found` neutre, absent de la liste | Une seule école par enseignant en V2 ; ne rien dire d'un autre établissement | ADR-0066 §4.4 |
| 2026-09-28 | Invitations : 30 par heure et par compte (au lieu de 10) | Porteur : un lycée a beaucoup de personnel | ADR-0066 §4.6 ; ED-58 réécrit |
| 2026-09-28 | Code d'adhésion d'une classe : critère ED-64 (présent dès la création d'une classe ajoutée par la direction) | Porteur ; déjà vrai dans `ClassroomRepository#insert`, le critère le prouve | UDR-0052 §2.10, §3.3 |
| 2026-09-28 | **Seul l'élève corrige son matricule**, depuis son profil, sous PIN actuel (`Identity::ChangeOwnStudentNumber`, 10 par heure et par compte, autres sessions gardées) ; `Identity::ChangeStudentNumber`, `Teams::StudentNumbersController` et la recherche par matricule de « Débloquer un compte » supprimés ; `q` n'est plus filtré (le paramètre reste `contact`) | Porteur ; la recherche par matricule ne servait pas au déblocage (l'élève connaît toujours son numéro) | ADR-0065, UDR-0053 ; ED-52, ED-53, ED-54 réécrits, ED-65 |
| 2026-09-28 | La recherche d'un matricule par l'équipe passe à `annuaire-equipe` (recherche exacte, pour anonymiser un usurpateur), qui ne modifie jamais un matricule | Un matricule usurpé ne se libère que par l'anonymisation | PRD §8 |
| 2026-09-28 | **La direction ne cherche que les élèves de son établissement** ; le rattachement d'un élève venu d'ailleurs disparaît ; `PlaceStudent` ne reçoit plus que l'identifiant public ; route `POST …/students/placement` supprimée (20 routes avec les deux de la réintégration) ; le compteur de débit ne porte plus que sur `lookup` | Porteur | ADR-0065, ADR-0066 §4.4, UDR-0052 §3.6 ; ED-40, 41, 43, 44, 47, 59 réécrits |
| 2026-09-28 | Critères : IDs gardés, réécrits en place, nouveaux à partir d'ED-60 ; aucun supprimé | Éviter de renuméroter les références croisées des ADR, UDR et du plan | — |
| 2026-09-28 | La matrice fonction × geste est une matrice de départ, à revoir avec des directions réelles | Porteur : « ne connaît pas bien le fonctionnement de l'administration » | ADR-0066 §9 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Le premier plan ne passait pas `bin/ci` au Lot 0** (challenge 1, points 3 à 5) : un port gelé sans son adaptateur casse `test/architecture/port_contracts_test.rb` ; un champ ajouté à un `Data.define` sans défaut casse tous ses appelants ; dessiner des routes rend actives des entrées que `role_homes_test` voulait inactives. Leçon : avant de geler un contrat, lire `test/architecture/` et chercher les appelants (`grep -rn "Membership.new"`).
- **Des écrans existants renvoyaient en dur vers l'équipe** (`team_home_path` après le second facteur) : « même parcours que l'équipe » ne se vérifie qu'en lisant les contrôleurs de ce parcours.
- **Une règle déléguée contradictoire** (« seul un Proviseur invite un Proviseur » + « un seul Proviseur actif ») est passée du memo à l'ADR sans être vue ; le challenger l'a trouvée en déroulant le cas.
- **Le retrait d'un enseignant était sans effet** tant que le code d'établissement, diffusé à tous, permettait de revenir aussitôt.
- La feuille de route contredisait encore Q1 dans la porte de la V2 ; corrigée.
- **Relecture adverse des retours du porteur** (2026-09-28, sans sous-agent disponible : relue en rôle de challenger) : le retrait du rattachement d'un élève venu d'ailleurs laisse **bloqué** un élève dont la classe de l'an dernier est restée `active` (ni déplacé, ni admis par code) — noté en point ouvert ; l'ordre des vérifications de la correction du matricule devait suivre `ChangeOwnPin` (sinon l'oracle « déjà utilisé » répondait sans PIN) ; ED-54 n'était pas testable (« ne propose pas ») ; l'ADR-0055 n'avait pas d'amendement daté ; le compte des critères réécrits était faux. Tous corrigés.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La table `school_staffs` de l'ADR-0044 **n'existe pas** : seul le type d'invitation `school_staff` a été posé en V1. `Actor` ne porte pas la fonction ; `HomeDestination` envoie tout `school_admin` sur l'écran d'attente ; `SecondFactorPolicy` et `ResolveSession` ne connaissent que `team` (C-20 décidé, jamais codé).
- `AcceptInvitation` refuse explicitement toute invitation qui n'est pas `team` (« ne s'accepte pas par cet écran »).
- `ManageSchoolPolicy` sert à la fois l'import, les DRENA, la génération des classes, la régénération du code **et** la validation des comptes en attente : c'est pourquoi on ne l'élargit pas.
- `ManageClassroomPolicy#call(actor:)` ne reçoit pas l'établissement : impossible de borner la direction sans changer la signature ; d'où `StaffPolicy#call(actor:, school:, gesture:)`.
- L'index unique `(classroom_id, student_id)` de `classroom_students` interdit le retour d'un élève dans une classe quittée.
- Les classes de l'an dernier gardent le statut `active` tant que l'archivage de fin d'année (V3) n'existe pas : « classe active » ne suffit pas, il faut aussi « de l'année en cours » pour dire qu'un élève est pris ailleurs.
- `JoinRequestRepositoryPort` n'a aucune lecture par enseignant ; `school_join_requests.teacher_id` est unique : un enseignant approuvé puis retiré ne peut plus refaire de demande.
- L'écran d'attente affiche « Votre demande est en cours de validation » pour une demande **approuvée** d'un enseignant sans école (état jamais atteint avant ce chantier).
- `create_user(role: "school_admin")` est utilisé par une dizaine de tests de refus ; avec le second facteur exigé, ils recevraient une redirection au lieu d'un 403 : la fabrique lui donne un second facteur par défaut (Lot 0a).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rattacher par invitation un numéro qui a déjà un compte | Parcours d'authentification à l'acceptation | À ouvrir si le porteur le demande |
| Lister et révoquer les invitations de direction en cours | Le lien s'affiche une fois ; une invitation perdue attend 72 h | Idem |
| Photos dans les listes de la direction | `ReadUserPolicy` non élargie | `annuaire-equipe` ou suivant |
| Taux de rendu par devoir (élève × devoir) | Déplier cours et fiches en exercices | `rapports-de-classe` (V3) |
| Régénérer ou fermer le code d'adhésion d'une classe par la direction | Non demandé ; ADR-0041 le prévoyait | V3, `vie-de-la-classe` |
| Élève dont la classe de l'an dernier reste `active` : ni déplacé par la direction, ni admis dans une nouvelle classe par code | Rattachement d'un élève venu d'ailleurs retiré par le porteur ; archivage de fin d'année en V3 | V3 ou `changement-etablissement-eleve` (à trancher avant la première rentrée) |
| Rendre ses anciennes classes à un enseignant réintégré | Délégué : il se redéclare | À rouvrir si le porteur le demande |
| Écran de réintégration pour l'équipe | L'équipe a le geste dans `StaffPolicy`, pas d'écran | À ouvrir si besoin |
| Retirer un élève de l'établissement (départ en cours d'année) | Hors V2 (memo) | V3, avec CL-02 |

## Lot 0a — Schéma et contrats (2026-09-29)

Branche `feature/espace-direction-lot-0a`. Quatre migrations (matricule **nullable**, `school_staffs`, index partiel de `classroom_students`, `teacher_school_departures`), entités, ports gelés et leurs adaptateurs, `StaffPolicy`, fabriques, seed. Aucun écran.

**Décisions en route**

| Décision | Pourquoi |
|---|---|
| `Entities::School::StaffMember` gagne `active?` et `principal?` | Lecture directe des règles « seul l'équipe retire un Proviseur » (Lot B) ; aucune donnée de plus |
| `SessionState#privileged?` posé ici (équipe, direction), testé dans `session_policy_test` ; `ResolveSession` et `SecondFactorPolicy` ne l'utilisent qu'au Lot 0b | `session_state.rb` est au Lot 0a ; le comportement ne change qu'avec le Lot 0b |
| `SchoolRepository#detach_teacher` supprime la seule ligne `teacher_schools` **principale** de cet établissement ; `:not_found` sinon, rien d'écrit | ADR-0066 §4.4 : `:not_found` pour un enseignant dont l'école principale n'est pas celle-ci |
| `reinstate_teacher` verrouille le départ ouvert, puis clôt le départ et recrée la ligne principale dans un même point de sauvegarde : l'index « une école principale » refusé annule aussi la clôture (`:conflict other_school`, départ toujours ouvert) | « Rien d'écrit sur un refus » (ADR-0066 §4.4) |
| `StaffRepository#attach` distingue le conflit par le nom de l'index (`index_school_staffs_one_principal` → `principal_taken`, sinon `other_school`) | Même procédé que `SchoolRepository#persist` |
| `school_staffs` : index `(school_id, left_at)` en plus des deux index uniques de l'ADR-0044 | Lectures « membres actifs d'un établissement » (Lot B, `principal_active?`) |
| `Orm::SchoolStaff` n'a pas d'`inverse_of` vers `Orm::School` | `app/infrastructure/orm/school.rb` n'est pas dans le champ du lot ; l'association inverse peut venir avec un lot qui le touche |
| Scope `Orm::TeacherSchoolDeparture.not_reinstated` (et non `open`) | `open` est une méthode de `Kernel` |
| `create_user(role: "school_admin")` reçoit un second facteur confirmé (`second_factor:` désactivable) ; `create_team_member` passe par la même aide `confirm_second_factor` ; `create_student` pose un matricule unique par défaut (`student_number: nil` pour s'en passer) | Plan, « Done quand » |
| Seed : Proviseur `0700000002` (Mariam Bamba), second facteur à activer, rattaché au Lycée Moderne de Treichville ; matricule `12345678A` de l'élève du seed, complété s'il manque | Plan, « Détail des contrats » |

**Écarts au champ `Fichiers` (tests seulement)**

- `test/infrastructure/orm/models_test.rb` : le compte des modèles `Orm::` passe de 34 à 36 (`school_staffs`, `teacher_school_departures`). Le tableau de collision range `test/infrastructure/orm/*` au Lot F ; la modification est une ligne, séquentielle, sans conflit possible.
- `test/system/role_homes_test.rb` (au Lot 0b) : le cas `school_admin` passe `second_factor: false`. Sans cela, `sign_in_as` attend le formulaire du second facteur, que la direction ne voit qu'à partir du Lot 0b. **Le Lot 0b retire ce `second_factor: false`** en réécrivant le cas.
- Tests existants complétés : `user_test`, `audit_action_test`, `session_policy_test`, `test/support/factories_test.rb` (couverture des nouveautés des fichiers du lot).

**Dérapages**

- Le schéma régénéré par `db:migrate` réécrivait **toutes** les contraintes `CHECK … = ANY (ARRAY[…])` (rendu de la version locale de PostgreSQL) : `db/schema.rb` a été reconstruit à la main à partir de `HEAD`, avec les seuls ajouts du lot (vérifié : même contenu que le dump, hors ce rendu). À surveiller par chaque lot qui migre (Lot F).
- Première passe complète : un échec (`models_test`, compte des modèles) et une erreur système (`role_homes_test`, ci-dessus) ; corrigés, puis vérification complète rejouée.

**Pour le Lot 0b**

- Retirer `second_factor: false` du cas `school_admin` de `role_homes_test` (le réécrire : cinq entrées actives, écran d'attente).
- `create_user(role: "school_admin")` a déjà son second facteur : les tests de refus (403) resteront verts une fois le second facteur exigé, puisque `sign_in_as` le saisit.
- `SessionState#privileged?` est prêt pour `ResolveSession` et `SecondFactorPolicy`.
- `Actor#position` et `UserRepository#actor_for` (rattachement actif, établissement `active`) sont prêts pour `HomeDestination` et `hold_detached_school_admin`.

**Dette**

- `reinstate_teacher` renverrait `:conflict other_school` si l'enseignant avait une ligne `teacher_schools` **non principale** dans cet établissement (index `(teacher_id, school_id)`) ; aucun parcours n'en crée en V2.

## Lot 0b — Garde d'accès et fichiers partagés (2026-09-29)

Branche `feature/espace-direction-lot-0b`. Second facteur de la direction, acteur et accueil, garde de la direction sans établissement, 27 routes (20 de la direction, 4 de l'équipe, 1 d'identité, 2 du profil de l'élève), navigation à cinq entrées, écran d'attente entier, profil (fonction, établissement, matricule), page « Établissement », squelette de l'accueil, `DirectionSchoolQuery` et `DirectionClassroomsQuery`.

**Décisions en route**

| Décision | Pourquoi |
|---|---|
| `Authentication#forget_resolution` après la vérification du second facteur, puis `redirect_to_home` | La résolution mémorisée avant la vérification n'a pas d'acteur : `redirect_to_home` renvoyait vers le second facteur |
| `helper_method :current_session` ; « J'ai noté mes codes » mène à `home_path_for(current_session.role)` | `second_factor_enrollments_controller.rb` n'est pas dans le lot : l'acteur y est lu avant l'activation, `current_actor` vaut `nil` dans la vue des codes |
| La garde `hold_detached_school_admin` est dans `AuthenticatedController` (exemptions par `controller_path` : `identity/pending_accounts`, `identity/profile*`, `identity/account_photos`) ; `SchoolAdmin::BaseController` n'a que `allow_roles :school_admin` | La garde du parent s'exécute avant tout filtre de `BaseController` : le renvoi « sans établissement » de l'ADR-0066 §6 y serait du code mort (couverture 100 %) |
| Écran d'attente : `@case` ∈ `:student`, `:school_admin_without_school`, `:teacher` (demande en attente ou refusée), `:teacher_without_school`, `:other` ; une demande **approuvée** ne compte plus (cas 3) ; un enseignant ou une direction rattachés qui ouvrent l'adresse à la main lisent le cas générique | UDR-0052 §3.9 ; corrige l'affichage « en cours de validation » d'une demande approuvée |
| Libellé de la fonction traduit par la delivery (`AuthenticatedController#shell_detail`, `_information`) ; les queries renvoient `position` | Aucun `I18n` dans `app/infrastructure` |
| Rattachement lu en ligne dans `ShellUserQuery` et `ProfileQuery` (rattachement actif, établissement `active`, comme `actor_for`) | Un fichier partagé entre les deux aurait été hors du champ du lot |
| `GET`/`PATCH school/code` et `POST teachers/:public_id/reinstatement` écrits à la main | `resource :code` ajoute un `PUT` (21 routes) ; une ressource imbriquée nomme le paramètre `teacher_public_id` au lieu de `public_id` (UDR-0052 §3.0) |
| Squelette de l'accueil titré par `shared.home.sections.overview.title` | `school_admin/homes.fr.yml` appartient au Lot D |
| `school_admin.shared.refusals.forbidden` / `not_found` posés, sans méthode dans `BaseController` | Aucun contrôleur du 0b ne rend un refus en Turbo Stream : une méthode non appelée casserait la couverture |

**Écart au plan : frames sans `src` tant que leur contrôleur manque.** Le plan supposait des frames « en erreur de routage ». Une route dont le contrôleur n'existe pas lève `ActionDispatch::MissingController` (erreur 500, non « rescuable ») : Capybara la remonte, et **cinq tests système existants** ouvrent la fiche d'un établissement côté équipe. Les frames `school_code`, `school_staff` (direction) et `school_staff` (équipe) ne reçoivent donc leur `src` que si leur contrôleur est défini (`defined?(…Controller)`), et gardent leur squelette sinon. À la fusion des Lots G et B, le `src` apparaît sans toucher ces vues ; la condition, devenue toujours vraie, est à retirer à la clôture du chantier (porteur).

**Écarts au champ `Fichiers` (tests seulement)**

- `test/controllers/teams/{homes,dashboards,drenas,school_classrooms,level_classrooms}_controller_test.rb` : `create_user(role: "school_admin")` → `create_school_admin`. Une direction **sans établissement** est désormais renvoyée vers l'écran d'attente avant `allow_roles :team` (redirection au lieu de 403) ; une direction rattachée reçoit toujours 403. Un mot par fichier ; `level_classrooms_controller_test.rb` est au Lot D, qui part de cette version.

**Pour les lots A à G**

- Tout contrôleur `SchoolAdmin::` hérite de `SchoolAdmin::BaseController` : `current_actor.school_id` est **toujours** un établissement actif (sinon l'acteur est déjà sur l'écran d'attente).
- `Queries::School::DirectionClassroomsQuery#call(school_id:)` → `[Level(name, classrooms: [Row(public_id, name, level_name, students_count, capacity)])]`, triées par niveau, série, numéro ; `#includes?(school_id:, public_id:)` pour ignorer un filtre d'une classe étrangère (C, E) ou refuser un choix (E).
- `Queries::School::DirectionSchoolQuery#call(school_id:)` → `Row(public_id, name, drena_name, school_type, status, school_code)` et `school_code_display` (G peut le relire).
- Refus en Turbo Stream : `t("school_admin.shared.refusals.forbidden")` (« Votre fonction ne permet pas ce geste. ») et `…not_found` ; libellés : `t("school_admin.shared.positions.<position>")`.
- **Lot C** : re-rendre `identity/pending_accounts/show` avec `@case = :teacher_without_school` et `@rejoin`, un objet qui répond à `school_code` (la **saisie brute**, re-rendue) et à `errors` (sur `:school_code`) ; le formulaire est `form_with model: @rejoin || false, scope: :school_rejoin` (paramètre `school_rejoin[school_code]`). `Identity::SchoolRejoinsController` doit `skip_before_action :hold_pending_teacher`.
- **Lots B et G** : les frames de la page « Établissement » (et `school_staff` de la fiche équipe) se branchent seuls à la fusion (voir l'écart ci-dessus).
- **Lot D** : reprendre `school_admin/homes_controller.rb` et `homes/show.html.erb` (squelette `shared/home/_skeleton`) ; `HOME_SECTIONS[:school_admin]` ne servira plus.
- `test/integration/school_admin_access_test.rb` couvre chaque route `school_admin/` dont le contrôleur est chargé : un lot qui livre un contrôleur y est testé sans rien écrire (ED-01, ED-02, ED-03).
- `test/system/role_homes_test.rb` ne suit que « Accueil » et « Établissement » de la direction ; C, D, E ouvrent leurs pages dans leurs propres tests système.

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
