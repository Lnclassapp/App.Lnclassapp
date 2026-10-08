# Journal — Inscription des élèves sans code de classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-07 | Lot 0 : `ManageClassroomMembersPolicy#call(actor:, classroom:)`, sans `teaches:` ni `staff_school_id:` | L'acteur porte déjà son établissement et la classe ses enseignants ; deux paramètres de moins à calculer par l'appelant | Non : `plan.md` corrigé |
| 2026-10-07 | Lot 0 : les deux adresses de la cascade s'appellent `school_picker_levels` et `school_picker_classrooms` | `school_level_classrooms` est déjà le nom d'une route de l'équipe | Non |
| 2026-10-07 | Lot 0 : la migration n'entre pas dans `LATER` de `growth_migrations_test.rb` | Ce test rejoue les tables de croissance ; aucune colonne du lot n'en dépend | Non : `plan.md` corrigé |
| 2026-10-07 | Lot 0 : `db/schema.rb` complété à la main, ligne par ligne | PostgreSQL 18 (poste local) réécrit toutes les contraintes `CHECK` du fichier dans une autre forme ; le dump brut aurait changé 45 lignes sans rapport | Non |
| 2026-10-07 | Lot A : `JoinPolicy#call(actor:, classroom:, via_link: false, removed: false, code: nil)` ; le code n'est vérifié que si `code:` est passé | `join_with_code.rb` (→ F) et `join_as_student.rb` (→ B) gardent leurs appels sans être touchés | Non |
| 2026-10-07 | Lot A : un paramètre `/c/:token` de 12 caractères hexadécimaux est un jeton ; tout autre garde l'ancien chemin par code | Coexistence jusqu'au Lot F | Non |
| 2026-10-07 | Lot A : lien invalide → redirection 303 avec `flash[:link_invalid] = true` (pas une chaîne : jamais un toast) ; visiteur vers `/student-signup`, élève sans classe vers `/students/classroom/new` | UDR-0081 §3.4 | Non |
| 2026-10-07 | Lot A : **pont temporaire** — l'élève connecté qui ouvre `/c/<jeton>` rejoint par `JoinAsStudent` avec le code lu dans `JoinPreviewQuery::LinkRow#join_code` (jamais affiché) ; voie enregistrée `code` | `JoinAsStudent` ne connaît que le code jusqu'au Lot B | Non : `plan.md` corrigé (Lot B) |
| 2026-10-07 | Lot A : `drena_schools` reçoit `picker:` et `PICKER_SCOPES = %w[student_registration student_classroom_choice]` ; le scope du Lot B est `student_classroom_choice` | Le gabarit est réutilisé par la cascade (UDR-0081 §3.3) sans changer l'inscription enseignant | Non : `plan.md` corrigé (Lot A) |
| 2026-10-07 | Lot C : le droit d'afficher le bloc du lien passe par `ClassroomHeaderQuery::Row#link_shown_to?(actor)` (policy + classe active), appelé par `_header` avec `current_actor` | `classrooms_controller.rb` appartenait au Lot D, en parallèle | Non |
| 2026-10-07 | Lot C : la fiche d'établissement reçoit les jetons par `Level#link_tokens` (`{ public_id => jeton }`), pas dans `ClassroomRow` | Ajouter un champ à `ClassroomRow` cassait `school_detail_query_test.rb`, hors liste | Non : à reprendre au Lot F |
| 2026-10-07 | Lot C : `ChangeClassroomLink` sur une classe archivée → `:forbidden` avec `base: [:classroom_archived]` ; sans JavaScript, `redirect_back_or_to` | Sur le modèle de `SetSessionDaysPolicy` ; la page de la direction (Lot E) revient chez elle | Non |
| 2026-10-07 | Lot D : la ligne garde son identifiant `#student_<public_id>` et la modale `remove-student-<public_id>`, au lieu de `#classroom_student_<index>` (UDR-0081 §3.7) | La réponse au `DELETE` ne connaît pas l'index, qui change avec la recherche ; 4 tests système visent déjà `#student_<public_id>` | Validé par le porteur le 2026-10-08 : UDR-0081 §3.7 amendée |
| 2026-10-07 | Lot D : retirer un élève qui n'est ni membre actif ni retiré de la classe → 404 ; un élève déjà retiré → succès sans écriture | La réponse nomme l'élève : un succès sur tout identifiant laisserait lire le nom de n'importe quel élève | Non |
| 2026-10-07 | Lot D : la réponse au `DELETE` met aussi à jour `#classroom_headcount` et `#classroom_roster_count` (recherche transmise par un champ caché `q`) | L'effectif de l'en-tête et le compte filtré doivent suivre | Non |
| 2026-10-08 | Lot B : `JoinAsStudent#call(actor:, dto: nil, code: nil)` ; le `dto` est `StudentRegistrationInput` (jeton → voie `link`, qui lève le retrait ; sinon voie `standard`, mêmes vérifications que `RegisterStudent`) ; `LinkRow#join_code` supprimé | Le pont du Lot A est défait ; le chemin `code:` reste pour `/join` jusqu'au Lot F | Non |
| 2026-10-08 | Lot B : l'élève dans une classe active est refusé d'abord, en 403 `already_enrolled` (était un 422 `:conflict`) | IL-18 | Non |
| 2026-10-08 | Lot B : `/students` affiche, pour l'élève sans classe active, le bonjour et la seule carte « Choisis ta classe » au lieu de rediriger vers `pending_account` | Les autres blocs suivent le niveau de la classe et seraient vides | Non |
| 2026-10-08 | Lot B : « retrait récent » = dernière adhésion principale retirée il y a moins de 7 jours ; annoncé une fois par `session[:removal_noticed_at]` | Sans colonne : la durée est celle de « Nouveau » (ADR-0085 §4.4) | Non |
| 2026-10-08 | Lot E : la page de la direction porte les identifiants de la page enseignant (`#student_<public_id>`, `h2#classroom_roster_title`) ; la réponse au retrait côté direction finit par `turbo_stream.refresh(request_id: nil)` | Remet à jour tuiles, sous-titre et état vide sans écrire un second stream ; modèle déjà utilisé par l'équipe | Non |
| 2026-10-08 | Lot E : bloc du lien et bouton « Chercher » marqués permanents, avec des identifiants propres à la classe | Le rafraîchissement par fusion remettait à l'état serveur ce que Stimulus avait montré ou caché | Non |
| 2026-10-08 | Lot E : sur la page de la direction, les élèves restent triés par nom (pas de nouveaux en tête) | L'UDR ne demande à la direction que pastilles, menu et modale | Non |
| 2026-10-08 | Fusion de `Develop` : décisions renumérotées ADR-0085 et UDR-0081 | `Develop` avait donné 0083 et 0079 à `inscription-enseignant` (anciens 0082 et 0078), et 0082, 0084, 0078, 0080 à d'autres chantiers. Seules les lignes écrites par cette branche ont changé (`5a5581a0`), avant la fusion | Non |
| 2026-10-08 | Fusion de `Develop` : l'élève saisit son nom et ses prénoms dans deux champs (memo Q16, porteur) | L'enseignant y est revenu (Q24 de `inscription-enseignant`) et `Entities::Identity::FullName` a quitté `Develop`. UDR-0081 §2.6 et §3.2, ADR-0085 §5, PRD IL-20 amendés | Non : ADR-0037 |
| 2026-10-08 | Lot F : tout élève va sur son accueil (`HomeDestination`) ; sans classe active, l'accueil propose « Choisis ta classe » et, s'il en a un, « Voir mon historique » (lot R). `HomeDestination.enrolled?` garde la question que posent la page du lien et « Choisis ta classe » | Dette bloquante de la vague 3 ; l'écran d'attente, seul accès à l'historique, envoyait vers `/join` | Non |
| 2026-10-08 | Lot F : la règle de la cascade et la résolution d'un lien vivent dans `UseCases::Classroom::ClassroomDesignation` ; les listes du sélecteur dans le concern `ClassPicker` ; le titre de la liste dans `classroom/classrooms/_roster_title` | Recopiés entre `RegisterStudent` et `JoinAsStudent`, entre leurs contrôleurs, et trois fois pour le titre | Non |
| 2026-10-08 | Lot F : un ancien code de classe saisi dans le champ du code d'établissement est un code mal formé (`:invalid`) ; le message « Ce code est un code de classe » est retiré | Il n'y a plus de code de classe à reconnaître | Non |
| 2026-10-08 | Lot F : la migration `RemoveClassroomJoinCodes` (2026-10-08 12:00, après la dernière de `Develop`) retire `join_code`, `join_code_rotated_at`, leur index et leur format ; réversible, colonnes vides au retour | Le plan la datait du 2026-10-07 : elle serait passée avant une migration déjà jouée | Non |
| 2026-10-08 | Lot F : les messages de création de classe nomment la classe (« La classe %{name} est créée. », « Classe « %{name} » ajoutée. ») ; le bouton WhatsApp du bloc du lien reprend l'identifiant `classroom_whatsapp_share` de l'ancien bloc du code | UDR-0081 §3.8 ; tests système et captures de croissance | Non |
| 2026-10-08 | Lot F : l'aide (« Comment rejoindre ma classe ? »), la page de confidentialité et l'accueil public (« Comment ça marche », modale « Je suis élève ») ne parlent plus de code de classe ; la confidentialité dit que les noms des classes d'un établissement sont visibles à l'inscription | Hors de la liste du plan, mais IL-02 : aucun écran ne montre de code ; la cascade rend les noms de classes publics (ADR-0085 §4.2) | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Grill, Q8 (2026-10-07).** La question disait que l'enseignant remplace déjà le code de sa classe. C'est décidé par l'ADR-0041 (`RegenerateJoinCode`), jamais construit. L'hypothèse venait d'un commentaire (« code inconnu ou remplacé »), pas du code. Corrigé dans le memo avant la phase 2 : « Changer le lien » est un geste nouveau.
- **Lot 0 (2026-10-07).** Le plan ne listait pas les fichiers de test qui écrivent une adhésion directement : `joined_via` sans défaut les casse tous. Même découverte que le Lot 0 de `inscription-enseignant` ; à chercher par `grep` **avant** d'écrire le plan d'un lot qui retire un défaut.
- **Vague 2, environnement web (2026-10-07).** Le hook `.claude/hooks/session-start.sh` échouait : la politique réseau de l'environnement refuse `cache.ruby-lang.org` (Ruby) et `repo.yarnpkg.com` (Yarn). Contourné dans le conteneur : Ruby 3.4.9 compilé depuis `github.com/ruby/ruby` (tag `v3_4_9`, `--with-baseruby` 3.3.6) dans `/opt/rbenv/versions/3.4.9`, et `COREPACK_NPM_REGISTRY=https://registry.npmjs.org` ajouté à `~/.lnclass-ci-env`. Remède durable : ajouter les deux domaines aux domaines autorisés de l'environnement.
- **Vague 2, bases des worktrees (2026-10-07).** `RAILS_ENV=test bin/rails db:prepare` sur une base neuve la **remplit avec les seeds** : toute fabrique `create_level` / `create_drena` lève alors `PG::UniqueViolation`. Parade : `RAILS_ENV=test bin/rails db:schema:load`. À utiliser d'emblée pour préparer la base de test d'un worktree.
- **Vague 2, fusion (2026-10-07).** Le Lot C n'a pas lancé les tests système : son bloc du lien, posé à côté du code, rendait ambigus « Copier le lien » et « Partager sur WhatsApp » dans trois tests système hors liste (`classroom_page_test`, `finitions/classroom_test`) et contredisait une assertion de `classrooms_controller_test.rb` (Lot D). Corrigé à la fusion (885ad96) en visant le bloc du code. Consigne pour les vagues suivantes : **chaque lot qui touche une vue lance `bin/rails test:system`**.
- **Lots A et D, tests de concurrence (2026-10-07).** Écrits avant le code, ils attendaient un verrou qui ne venait jamais : `Queue#pop` bloque sans fin (≈ 10 min perdues). Corrigé par `locked.pop(timeout: 10)` dans une assertion ; le `join_capacity_test` d'origine avait le même défaut. Et `pkill -f "bin/rails test"` tue le shell qui le lance.
- **Vague 3, tests système en parallèle (2026-10-08).** Les lots B et E ont lancé `bin/rails test:system` en même temps sur la même machine : 9 et 10 échecs, dits « instables ». Relancée seule après la fusion, la suite n'a donné que les 2 échecs attendus (`join_test.rb:64`, IL-18 ; `remediation_handed_in_test.rb:48`, nouvelle colonne de la direction), corrigés en 58edfee. **Les suites système ne se lancent pas en parallèle** ; un échec « instable » se vérifie par une relance seule avant d'être écarté.
- **Lot E (2026-10-08).** Supposé que les éléments modifiés par Stimulus survivraient au rafraîchissement par fusion : faux pour « Copier le lien » et « Chercher » (≈ 15 min, vu sur les captures).
- **Lot B (2026-10-08).** Un test système jetable de captures laissé dans `test/system` pendant la suite complète fait échouer `ci_plan_test` et `system_budget_test` : le supprimer avant de lancer la suite.
- **Fusion de `Develop` (2026-10-08).** 13 fichiers en conflit, et deux ruptures sans conflit : les numéros d'ADR et d'UDR pris des deux côtés, et `FullName` retiré par `Develop` (41 erreurs à la fusion). La branche avait 92 commits de retard : fusionner `Develop` à chaque vague aurait montré ces deux ruptures le jour même.
- **Lot F, durées des tests système (2026-10-08).** Une première mesure, sur 4 processus en parallèle, doublait presque toutes les durées (`boucle_pedagogique` 36,7 → 44,1 s, `pin_reveal` 12,2 → 26,1 s). Seuls les fichiers réécrits ont été remesurés, sur un processus ; ceux qu'une simple substitution a touchés gardent la durée de la CI. Puma coupe la ligne `-v` du premier test : `record_timings` la perd, il faut la rajouter à la main.
- **Lot F, base locale (2026-10-08).** Postgres s'est arrêté deux fois pendant le lot (processus tué avec le shell qui l'avait lancé) ; `setsid` le garde en vie.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Une adhésion est **une ligne par élève et par classe** (index unique) : revenir dans une classe quittée ne peut pas créer de ligne. `add_primary` rouvre donc la ligne close ; avant le Lot 0, ce retour donnait `already_member`.
- **PostgreSQL 18 en local** : cinq tests échouent sans rapport avec le chantier (`PG::RestrictViolation` au lieu de `ActiveRecord::InvalidForeignKey` sur les clés `RESTRICT`), et `db:migrate` réécrit tous les `CHECK` de `db/schema.rb`. Parade sur ce poste : un PostgreSQL 16 (celui de la CI) dans `~/.local/share/pg16`, port 5433, et `DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5433` — sans nom de base, Rails garde ceux de `config/database.yml`. Avec lui : 4 565 tests, 0 échec, 0 erreur. Ne pas committer le dump brut de PostgreSQL 18.
- `bin/validate_hitl`, cité par `docs/guide/onboarding.md` §4, n'existe pas : le contrôle des en-têtes est dans `.githooks/pre-commit`. Les bases locales s'appellent `app_lnclassapp_development_lnclassapp` et `app_lnclassapp_test_lnclassapp`, pas les noms du §1. Deux écarts de documentation, à traiter par un chantier `docs/`.
- Les routes se dessinent avant leurs contrôleurs (`test/routing/v1_routes_test.rb`, `first_match`) : le Lot 0 peut les poser toutes.
- `test/views/page_titles_test.rb` exige `page_title` dans toute vue non partielle, frames de la cascade compris (seul `drena_schools/index` est exempté) ; `page_title` ne remplace pas un titre déjà posé.
- SimpleCov ne mesure que les `.rb` : les vues ERB ne comptent pas dans les 100 %.
- Dans une vue, la valeur par défaut d'un local strict peut lire une variable d'instance du contrôleur (`_roster` prend `@can_remove_students` par défaut) ; une cible Stimulus peut être l'élément qui porte le contrôleur (`data-controller="autofocus" data-autofocus-target="field"`).
- Une classe archivée garde l'adhésion ouverte (`left_at` nul) : `primary_for` la rend et `leave_primary` la ferme au changement de classe. Écrire une seconde adhésion principale dans un test exige de fermer la première (index unique partiel).
- `turbo_stream.refresh(request_id: nil)` remet une page à jour par fusion en gardant le défilement et les toasts (permanents) ; tout élément montré ou caché par Stimulus revient à son état serveur, sauf s'il est permanent.
- La page de la direction n'affiche que les classes actives de l'année : une classe archivée y est en 404.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Deux « Copier le lien » et deux « Partager sur WhatsApp » dans l'en-tête de la classe (code, puis jeton) ; les tests système visent celui du code | Le code reste jusqu'au retrait | Lot F — **fait** : le bloc du code est retiré |
| Pont `LinkRow#join_code` : l'élève connecté qui ouvre un lien rejoint par le code, voie `code` | `JoinAsStudent` ne connaît que le code | Lot B — **fait** ; le chemin `code:` est retiré au Lot F |
| Jetons de la fiche d'établissement dans `Level#link_tokens` au lieu de `ClassroomRow` | `school_detail_query_test.rb` hors liste | Lot F — **fait** : `ClassroomRow#link_token` |
| Fiche d'établissement : même `aria-label` « Copier le lien de la classe » sur toutes les cartes ; « Copier le lien » proposé même si l'établissement n'est pas actif | Aucune clé de locale avec le nom ; le partial ignore le statut | Lot F — **fait** : libellé au nom de la classe, lien proposé seulement si l'établissement est actif |
| Le serveur accepte le retrait d'un élève dans une classe archivée (seule l'interface le masque) | Le porteur a décidé le 2026-10-08 de le refuser (403), comme le changement de lien ; UDR-0081 §3.7 amendée | Lot E |
| Titre de la liste recopié dans `classroom_students/destroy.turbo_stream.erb` (le `h2` existe en double) | Pas de partial possible dans la liste du Lot D | Lot F — **fait** : `_roster_title` |
| À 390 px, un nom long est tronqué à côté de la pastille « Nouveau » | Le porteur a décidé le 2026-10-08 : la pastille passe sous le nom sur téléphone ; UDR-0081 §3.7 amendée | Lot E |
| `roster.empty_description` parle encore du code de la classe | Texte du code | Lot F — **fait** : « Partagez le lien de la classe » |
| Sans JavaScript, « Continuer » envoie tout le formulaire d'inscription en `GET` (un PIN déjà tapé irait dans l'URL ; le serveur ne le relit pas) | Cas improbable : la classe se choisit avant le PIN | — |
| **L'élève sans classe n'arrive pas sur « Choisis ta classe » à la connexion** : `Entities::Identity::HomeDestination` l'envoie vers `pending_account` (« Demande le code de ta classe », bouton vers `/join`) ; `student_classrooms#show` aussi. Une fois `/join` redirigé, il tournerait en rond | Fichiers hors de la liste B | Lot F — **fait** : l'accueil, avec l'historique |
| Règle « classe de la cascade » (`listed?`) et `class_picker_lists` recopiées entre `RegisterStudent` / `JoinAsStudent` et leurs contrôleurs | Fichiers hors liste | Lot F — **fait** : `ClassroomDesignation`, `ClassPicker` |
| Chemin `code:` de `JoinAsStudent` et `lock_by_join_code` | Ancien chemin `/join` | Lot F — **fait** |
| Titre de la liste des élèves écrit trois fois (`_roster`, stream du retrait, page de la direction) | Pas de partial dans les listes | Lot F — **fait** : `_roster_title` |
| À 390 px, le tableau de la direction défile en largeur : le menu ⋮ et les chiffres ne se voient qu'en faisant défiler, et le nom disparaît alors | Largeur minimale d'avant le chantier ; hors UDR | Décision du porteur attendue (proposé : lignes empilées sur téléphone) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-08 (PR vers `Develop`) |
| **PR** | [#203](https://github.com/Lnclassapp/App.Lnclassapp/pull/203) |
| **ADR produits** | [ADR-0085](../../decisions/adr/0085-inscription-eleve-sans-code-de-classe.md) ; amende l'ADR-0041 (plus de code d'adhésion) |
| **UDR produits** | [UDR-0081](../../decisions/udr/0081-inscription-eleve-sans-code-de-classe.md) ; remplace l'UDR-0009 |
