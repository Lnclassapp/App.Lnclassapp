# Compléments d'inventaire — Transverse et écrans sans feature

> Mission n° 5 du brief [`prompt-exploration.md`](../prompt-exploration.md) — explorateur **transverse**.
>
> | | |
> |---|---|
> | **Chantier** | `refonte-application` |
> | **Établi le** | 2026-09-22 |
> | **Source** | dépôt `Lnclassapp`, branche `Teamprocess`, commit `684ae16` |
> | **Vérifie** | [`transverse.md`](transverse.md) et [`ui-design-system.md` §3](ui-design-system.md#3-les-écrans-par-rôle) |
> | **Préfixe d'ID** | `TR` |
> | **Nature** | constat — aucune décision, aucune recommandation d'implémentation |
>
> **Code inchangé depuis l'inventaire** : `git diff --stat 2449373 HEAD -- app db config` est vide. Les écarts de numéros de ligne relevés au §3 ne viennent donc pas d'une évolution du code.
>
> **Méthode de preuve.** En plus de la lecture du code, les états ont été **vérifiés à l'exécution** avec un test d'intégration jetable, lancé contre la base de test puis annulé (transaction), placé hors du dépôt dans le répertoire temporaire de la session : `COVERAGE=0 bin/rails test <scratchpad>/probe_test.rb`. Il crée une DRENA, une école, une classe, un compte de chaque rôle, puis appelle chaque écran. Dans ce document, « **sonde** » renvoie à ce test. Aucun fichier du dépôt n'a été modifié.

---

## 1. Catalogue des features avec identifiant

Légende : ✅ marche · ⚠️ fragile · ❌ cassé · 💀 jamais exécuté ou sans effet.

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| TR-01 | Découvrir Lnclass sur la landing et ouvrir la modale « élève » ou « enseignant » (Se connecter / Créer un compte) | visiteur | ✅ | — | `GET /` | `inventaire/ui-design-system.md#3.1` |
| TR-02 | Être redirigé vers son espace selon son rôle (depuis `/` et après connexion) | tout connecté | ⚠️ | `users`, `students`, `teachers`, `teams`, `school_staffs`, `teacher_classrooms` | `GET /`, `POST /login` | nouveau |
| TR-03 | Ouvrir l'« Espace Etabl. » (offre « 2000 FCFA ») depuis la landing | visiteur | ❌ | — | lien relatif `etabl` (aucune route) | nouveau |
| TR-04 | Consulter son fil élève : ma classe, matières, messages, exercices assignés | `student` | ❌ | `classrooms`, `classroom_students`, `classroom_assignments`, `materials`, `courses`, `exercise_sessions`, `exercise_badges`, `messages`, `action_text_rich_texts`, `active_storage_*` | `GET /students` | `inventaire/ui-design-system.md#3.2` |
| TR-05 | Consulter son fil enseignant : classes, niveaux, messages, activités des élèves | `teacher` | ❌ | `teachers`, `teacher_schools`, `teacher_classrooms`, `classrooms`, `levels`, `messages`, `exercise_sessions`, `classroom_assignments` | `GET /teachers` | `inventaire/ui-design-system.md#3.3` |
| TR-06 | Voir ses gains « Prepa » en FCFA (1 000 FCFA par élève payant, partagés entre les enseignants de la classe) | `teacher` | 💀 | aucune (compteur forcé à 0) | `GET /teachers` | nouveau |
| TR-07 | Ouvrir le tableau de bord enseignant | `teacher` | 💀 | — | `GET /teachers/dashboard` | `inventaire/ui-design-system.md#3.3` |
| TR-08 | Passer l'écran d'accueil « première connexion » enseignant | `teacher` | 💀 | — | `GET /teachers/setup` | `inventaire/ui-design-system.md#3.3` |
| TR-09 | Consulter son fil équipe : DRENA récentes, niveaux, messages, activités (cours et messages créés) | `team` | ✅ | `drenas`, `schools`, `levels`, `level_series`, `series`, `messages`, `courses`, `exercises`, `action_text_rich_texts`, `active_storage_*` | `GET /teams` | `inventaire/ui-design-system.md#3.4` |
| TR-10 | Consulter le « Control Center » : KPI plateforme, inscrits récents, onglets Pilotage / Communauté / Académie / Régions | `team` | ❌ | `users`, `students`, `teachers`, `teacher_schools`, `schools`, `courses`, `classroom_students`, `classrooms`, `levels`, `materials`, `series`, `drenas` | `GET /teams/dashboard` | `inventaire/ui-design-system.md#3.4` |
| TR-11 | Rechercher un élève ou un enseignant par nom depuis le tableau de bord équipe | `team` | ❌ | `users` | `GET /teams/dashboard?query=` | nouveau |
| TR-12 | Voir la répartition des élèves par niveau | `team` | 💀 | `students`, `classroom_students`, `classrooms` | `GET /teams/dashboard`, `GET /teams/setup` | nouveau |
| TR-13 | Ouvrir la page « Configuration Plateforme » (coquille à onglets ; le contenu taxonomie est CA-25, l'onglet messages est un lien vers la création CO) | `team` | ✅ | `levels`, `level_series`, `materials`, `series`, `drenas`, `schools`, `classroom_students` | `GET /teams/setup` | `inventaire/ui-design-system.md#3.4`, `complements-catalog.md` CA-25 |
| TR-14 | Ouvrir « LnclassAI » | `team` | ⚠️ | — | `GET /teams/lnclassai` | `inventaire/ui-design-system.md#3.4` |
| TR-15 | Consulter le tableau de bord de son établissement (nombre de classes, d'élèves, d'enseignants ; niveaux actifs) | `school_admin` | ⚠️ | `school_staffs`, `schools`, `classrooms`, `classroom_students`, `students`, `teacher_schools`, `levels` | `GET /schoolstaff` | `inventaire/ui-design-system.md#3.5` |
| TR-16 | Voir l'écran « En attente d'affectation » tant qu'on n'est rattaché à aucune école | `school_admin` | ✅ | `school_staffs` | `GET /schoolstaff` | `inventaire/ui-design-system.md#3.5` |
| TR-17 | Créer un compte enseignant via le formulaire « Prepa BAC — Ressources Enseignants » | visiteur | ⚠️ | `users`, `teachers`, `teacher_schools` (lecture `materials`, `drenas`, `schools`) | `GET /teachers/prepa_acquisitions/new`, `POST /teachers/prepa_acquisitions` | `inventaire/ui-design-system.md#3.3` |
| TR-18 | Télécharger le PDF « Analyse de récurrence » de sa matière | `teacher` (tout connecté en fait) | 💀 | `teachers`, `materials` | `GET /teachers/prepa_acquisitions/download` | `inventaire/ui-design-system.md#3.3` |
| TR-19 | Être bloqué par le paywall « Prepa BAC 2026 » (2 000 FCFA) et l'activer via Wave ou WhatsApp | `student` | 💀 | aucune (aucune colonne de paiement) | `GET /students/examens/:id` | `inventaire/ui-design-system.md#3.2`, `assessment.md:331` |
| TR-20 | Consulter l'annuaire de tous les comptes | `team` | ⚠️ | `users` | `GET /users` | `inventaire/ui-design-system.md#3.6` |
| TR-21 | Consulter la fiche d'un compte (nom, contact, rôle, genre, `public_id`) | tout connecté | ⚠️ | `users` | `GET /users/:public_id` | `inventaire/ui-design-system.md#3.6` |
| TR-22 | Modifier ou supprimer un compte depuis l'annuaire | `team` ; propriétaire pour la modification | ⚠️ | `users` + cascades des profils | `GET /users/:public_id/edit`, `PATCH\|PUT\|DELETE /users/:public_id` | `inventaire/ui-design-system.md#3.6` |
| TR-23 | Basculer entre thème clair et sombre | `student`, `teacher`, `team` | 💀 | — (`localStorage`) | toutes les pages connectées | `inventaire/ui-design-system.md#4.3` |
| TR-24 | Installer Lnclass comme application (manifeste PWA, service worker) | tout visiteur | ⚠️ | — | `GET /manifest(.json)`, `GET /service-worker(.js)` | `inventaire/transverse.md#6.6` |
| TR-25 | Voir le bandeau d'installation sur mobile, le reporter ou l'accepter, et que le choix soit mémorisé | tout connecté (mobile) | ⚠️ | `users` (`install_banner_status`, `install_banner_last_changed_at`) | `PATCH /install_banner` | `inventaire/ui-design-system.md#5.9` ; détail métier : périmètre CO |
| TR-26 | Mesurer l'audience (Google Tag Manager, Microsoft Clarity) | visiteur (subi) | ⚠️ | — | toutes les pages, en production | `inventaire/transverse.md#6.8` |
| TR-27 | Naviguer dans son espace (en-tête, barre latérale, tiroir mobile, barre du bas), selon son rôle | tout connecté | ⚠️ | `students`, `classroom_students`, `classrooms`, `teacher_schools` (école du lien « École ») | toutes | `inventaire/ui-design-system.md#5.9` |
| TR-28 | Importer en masse des cours ou des établissements par fichiers JSON, traités en arrière-plan | `team` | ⚠️ | `courses`, `essentials`, `exercises`, `questions`, `answers`, `levels`, `materials`, `series`, `level_series`, `schools`, `solid_queue_*` | `POST /courses/import_json`, `POST /drenas/:drena_id/schools/import_json` | `inventaire/transverse.md#3` ; détail métier : CA-08 et périmètre SC |
| TR-29 | Importer en masse des DRENA par fichiers JSON, en arrière-plan | `team` | 💀 | `drenas` | aucune (action non routée) | `inventaire/transverse.md#3` (déclaré vivant à tort) |
| TR-30 | Générer les classes et élèves de démonstration d'une école ; simuler leurs sessions d'exercice | système | 💀 | `classrooms`, `students`, `users`, `classroom_students`, `exercise_sessions`, `question_attempts` | aucune | `inventaire/transverse.md#3` ; détail : périmètres CL et AS (ADR-0019) |
| TR-31 | Purger toutes les heures les jobs terminés | système | ⚠️ | `solid_queue_recurring_tasks`, `solid_queue_recurring_executions`, `solid_queue_jobs` et tables d'exécution | — | `inventaire/transverse.md#3.1` |
| TR-32 | Mettre en cache les agrégats et les référentiels (Solid Cache) | système | ✅ | `solid_cache_entries` | — | `inventaire/transverse.md#3.1` |
| TR-33 | Pousser des mises à jour en temps réel (Action Cable sur Solid Cable) | système | 💀 | `solid_cable_messages` | — | `inventaire/transverse.md#3.1` |
| TR-34 | Répondre à la sonde de santé de l'hébergeur | Railway | ❌ | — | `GET /up` (absente) | `inventaire/transverse.md#1.13` |
| TR-35 | Refuser les navigateurs jugés anciens (page 406) | tout visiteur | ✅ | — | toutes | nouveau |
| TR-36 | Déployer en production (image Docker, Thruster, migrations au démarrage, Railway) | équipe | ⚠️ | toutes (via `db:prepare`) | — | `inventaire/transverse.md#5.3` |
| TR-37 | Conserver les fichiers téléversés (avatars, couvertures, audios) | tout connecté | ⚠️ | `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records` | `/rails/active_storage/*` | `inventaire/transverse.md#5.2` |
| TR-38 | Envoyer ou recevoir des e-mails | système | 💀 | — | `/rails/action_mailbox/*` | `inventaire/transverse.md#3`, `#1.12` |
| TR-39 | Journaliser les requêtes sans exposer de donnée sensible | système | ⚠️ | — | — | `inventaire/transverse.md#5.2` |
| TR-40 | Afficher l'interface en français, avec des clés de traduction | tout visiteur | ⚠️ | — | — | `inventaire/transverse.md#4` |
| TR-41 | Rendre les formules mathématiques (KaTeX chargé depuis un CDN) | tout visiteur | ✅ | — | — | `inventaire/transverse.md#5.5` |
| TR-42 | Exposer l'utilisateur courant aux couches basses (`Current.user`) | système | 💀 | — | — | nouveau |

**42 features**, dont **7 nouvelles** (TR-02, TR-03, TR-06, TR-11, TR-12, TR-35, TR-42) et une **reclassée** (TR-29, morte alors que l'inventaire la dit vivante).

---

## 2. Features absentes de l'inventaire

### TR-02 — Être redirigé vers son espace selon son rôle

- **Acteur** : tout utilisateur connecté.
- **Parcours** : `POST /login` → `redirect_to after_sign_in_path_for(user)` (`app/controllers/identity/sessions_controller.rb:33`) ; tout `GET /` d'un utilisateur connecté qui a un profil subit la même redirection (`app/controllers/homepage_controller.rb:20-21`).
- **Règles métier** (`app/controllers/application_controller.rb:18-34`) :
  - sans profil → `/` ;
  - `student` → `/students` ;
  - `teacher` → `/teachers/classrooms` **si** `teacher.classrooms` est vide, sinon `/teachers` ;
  - `team` → `/teams` ; `school_admin` → `/schoolstaff` ; tout autre rôle (`parent`) → `/`.
- **Données** : lecture `users.role`, le profil (`students`, `teachers`, `teams`, `school_staffs`), `teacher_classrooms`.
- **État** : ⚠️ — le routage par rôle marche (sonde : `team` → `/teams`, `student` → `/students`, `school_admin` → `/schoolstaff`, enseignant sans classe → `/teachers/classrooms`). Mais **deux boucles de redirection infinies** :
  - **enseignant sans école**, vérifiée par la sonde : `/teachers/classrooms` → `/` (`ensure_teacher_has_school`, `app/controllers/classroom/teachers/classrooms_controller.rb:107-110`) → `/teachers/classrooms` (`application_controller.rb:25-26`) → … ;
  - **élève sans classe**, prouvée par lecture : `GetStudentFeed` renvoie `require_student?` (`app/domain/use_cases/identity/get_student_feed.rb:46`) → `/` (`app/controllers/students/feed_controller.rb:23-25`) → `/students` (`homepage_controller.rb:20-21`) → … .

  Déjà signalées par `docs/chantiers/queries-constantes-orm-disparues/memo.md:40,47`, mais absentes de `transverse.md`, qui traite la méthode de « vestige Devise à vérifier » (`transverse.md:1441`).
- **À refaire différemment** : ne pas nommer le routage post-connexion d'après une signature Devise ; ne pas rediriger vers une page dont un garde-fou renvoie à la page d'origine ; chaque état incomplet (sans école, sans classe, sans profil) doit avoir un écran de sortie.

### TR-03 — Ouvrir l'« Espace Etabl. » depuis la landing

- **Acteur** : visiteur, sur la version bureau de la landing.
- **Parcours** : encart orange « Etablissement — Réussis pour seulement 2000 FCFA » → bouton « Espace Etabl. » (`app/views/homepage/index.html.erb:112-121`).
- **Règles métier** : prix affiché **2000 FCFA** (`index.html.erb:119`), le même que le paywall élève (TR-19).
- **Données** : aucune.
- **État** : ❌ — `link_to "Espace Etabl.", "etabl"` (`index.html.erb:121`) est un lien **relatif** vers `/etabl`, qu'aucune route ne déclare (`config/routes.rb`). La landing n'offre par ailleurs **aucun lien** vers `/staff-signup` ni `/team-signup` (aucune occurrence de `new_staff_registration_path` ni de `new_team_registration_path` dans `app/views`).
- **À refaire différemment** : aucun lien d'interface vers une chaîne littérale ; chaque rôle qui peut s'inscrire doit avoir un point d'entrée visible, ou son inscription doit être déclarée volontairement cachée.

### TR-06 — Voir ses gains « Prepa » en FCFA

- **Acteur** : enseignant.
- **Parcours** : fil `/teachers` → encart « examen dashboard » (`app/views/teachers/feed/content/_examen_dashboard.html.erb:38`, `number_with_delimiter(@prepa_gains)` + « FCFA ») ; cet encart propose aussi un partage WhatsApp du lien `/c/:unique_code` de la classe (`_examen_dashboard.html.erb:49`).
- **Règles métier** : `Entities::Teacher#prepa_gains` (`app/domain/entities/teacher.rb:48-60`) — pour chaque classe, `(élèves payants × 1000) / nombre d'enseignants de la classe`, division entière, classe ignorée si elle n'a aucun enseignant.
- **Données** : aucune — `paid_students_count` est **forcé à 0** au mappage (`app/infrastructure/repositories/classroom/classroom_repository.rb:326,329`) ; aucune colonne de paiement n'existe (`db/schema.rb`).
- **État** : 💀 — double mort : l'encart est commenté (`app/views/teachers/feed/index.html.erb:11`) et le calcul renvoie toujours 0. En amont, le fil lui-même lève (TR-05).
- **À refaire différemment** : ne pas coder une règle de rémunération sans source de vérité du paiement ; ne pas afficher un montant calculé sur une donnée simulée.

### TR-11 — Rechercher un élève ou un enseignant par nom

- **Acteur** : `team`.
- **Parcours** : onglet « Communauté » de `/teams/dashboard` → champ « Rechercher un membre (nom, établissement...) », soumission GET dans le turbo-frame `community_results` à chaque frappe (Stimulus `filter`) (`app/views/teams/dashboard/_tab_community.html.erb:4-16`).
- **Règles métier** : `fullname ILIKE '%query%'`, **50** résultats au plus par rôle (`app/infrastructure/queries/teams_dashboard_query.rb:45-51`). Le placeholder promet une recherche par établissement, que la requête ne fait pas. Les boutons de filtre « Tous / Enseignants / Élèves » n'ont aucune action (`_tab_community.html.erb:21-23`).
- **Données** : lecture `users`.
- **État** : ❌ — la page lève `NoMethodError` avant même la recherche (TR-10 ; sonde sur `/teams/dashboard?query=Aa`). Même réparée, les résultats `@students` / `@teachers` (`app/controllers/teams/dashboard_controller.rb:41-44`) ne sont lus par **aucune** vue : le frame réaffiche les inscrits récents.
- **À refaire différemment** : ne pas calculer un résultat qu'aucune vue n'affiche ; ne pas promettre un critère de recherche non implémenté ; pas de boutons de filtre décoratifs.

### TR-12 — Voir la répartition des élèves par niveau

- **Acteur** : `team`.
- **Parcours** : aucun écran vivant. Le calcul tourne à chaque `GET /teams/dashboard` et `GET /teams/setup` (`before_action :set_setup_data`, `dashboard_controller.rb:13,79`).
- **Règles métier** : nombre d'élèves groupés par `classrooms.level_id`, **classe principale seulement** (`classroom_students.primary = true`), mis en cache **1 h** sous la clé `teams_dashboard_students_per_level` (`teams_dashboard_query.rb:36-43`). C'est l'exemple de code cité par l'ADR-0006 §5.
- **Données** : lecture `students`, `classroom_students`, `classrooms`.
- **État** : 💀 — `@students_per_level` n'est lu que par `app/views/teams/dashboard/shared/_levels_widget.html.erb:19`, partial jamais rendu (`ui-design-system.md` §2.4).
- **À refaire différemment** : pas de requête d'agrégat exécutée pour un widget absent ; pas de cache sans invalidation sur un compteur métier.

### TR-35 — Refuser les navigateurs jugés anciens

- **Acteur** : tout visiteur, connecté ou non, API comprise.
- **Parcours** : toute requête passe par `allow_browser versions: :modern` (`app/controllers/application_controller.rb:16`) ; un navigateur non retenu reçoit `public/406-unsupported-browser.html`.
- **Règles métier** : seuil `:modern` de Rails 8.1 (support des images webp, web push, badges, import maps, CSS nesting et `:has`, selon le commentaire `application_controller.rb:15`).
- **Données** : aucune.
- **État** : ✅ — le mécanisme fonctionne (sonde : `GET /` avec un Chrome 99 Android → **406**). Mais il exclut précisément les smartphones d'entrée de gamme que l'ADR-0009 §1-2 désigne comme public cible (voir §4).
- **À refaire différemment** : ne pas laisser une valeur par défaut du générateur décider quels élèves peuvent se connecter ; pas de filtre de navigateur sur les endpoints JSON.

### TR-42 — Exposer l'utilisateur courant aux couches basses

- **Acteur** : système.
- **Parcours** : `before_action :set_current_user` → `Current.user = current_user` (`app/controllers/concerns/current_user_concern.rb:18,89-91`) ; `Current < ActiveSupport::CurrentAttributes` (`app/models/current.rb:13`).
- **Règles métier** : aucune.
- **Données** : aucune.
- **État** : 💀 — `Current.user` n'est lu nulle part dans `app/` (la seule autre occurrence est l'écriture ci-dessus).
- **À refaire différemment** : pas d'état global par requête sans lecteur ; l'auteur d'une écriture (`assigned_by_id`, `team_id`) doit être passé explicitement au use case.

---

## 3. Corrections de l'inventaire

### 3.1 Affirmations fausses ou incomplètes

| # | Affirmation de l'inventaire | Constat | Preuve |
|---|---|---|---|
| 1 | « **46 tables** — 27 métier, 5 d'infrastructure Rails, **14** de la Solid Suite » (`transverse.md:410`, volumétrie `:27`) | **45 tables** : 27 + 5 + **13**. L'inventaire lui-même n'en liste que 13 (`transverse.md:816-828`), comme `docs/feature_listing.md` | `grep -c create_table db/schema.rb` → 45 ; la base de dev compte 47 tables, soit ces 45 plus `schema_migrations` et `ar_internal_metadata` |
| 2 | `action_text_rich_texts` : « Aucun `has_rich_text` dans `app/` », table déclarée morte (`transverse.md:870,1306`) | **Faux** : trois modèles déclarent `has_rich_text :content`, et trois formulaires écrivent dans cette table | `app/infrastructure/orm/message.rb:22`, `course.rb:24`, `essential.rb:22` ; écriture `repositories/communication/message_repository.rb:46`, `repositories/catalog/course_repository.rb:45,84` ; formulaires `views/messages/_form.html.erb:69`, `views/catalog/courses/_form.html.erb:98`, `views/catalog/essentials/_form.html.erb:64` |
| 3 | `teacher_classrooms` : « **aucune écriture** dans `app/` », table morte (`transverse.md:871,1308`) | **Faux** : l'affectation `has_many :through` écrit la table | `app/controllers/classroom/teachers/classrooms_controller.rb:81` `current_teacher.classrooms = verified_classrooms` ; sonde : `POST /teachers/classrooms` → 1 ligne créée |
| 4 | `level_series` : table morte (`transverse.md:1307`) | **Faux**, et l'inventaire le montre lui-même (`transverse.md:868`) : l'écriture passe par l'association | `repositories/catalog/level_repository.rb:53` (`record.series = …`), `course_repository.rb:139` (`level.series << series`) ; `complements-catalog.md` CA-19 la dit ✅ |
| 5 | `ImportDrenasJsonJob` rangé parmi les 3 jobs vivants (`transverse.md:961,969`) | **Mort** : son seul appelant est `catalog/drenas#import_json`, action que l'inventaire déclare lui-même sans route (`transverse.md:389,1327`) | `app/controllers/catalog/drenas_controller.rb:19,35` ; `config/routes.rb:51-57` (seul `schools#import_json` est routé sous `drenas`) |
| 6 | `homepage_teacher_modal_controller.js` : « 0 vue le référence » (`transverse.md:1341`) | **Faux** — et contredit par `ui-design-system.md` §4.1, qui le classe vivant | `app/views/homepage/index.html.erb:9,51,107,190-194` |
| 7 | 16 méthodes de helpers « sans aucun appel » (`transverse.md:1344-1357`) | **Faux pour 9 d'entre elles** : les 7 `material_*_icon` et `default_initial_icon` sont appelées par `material_icon`, lui-même rendu dans 5 vues ; `hide_layout_components?` est appelée 3 fois. La preuve (`grep` limité à `app/views` et `app/controllers`) ignorait les appels entre helpers | `app/helpers/application_helper.rb:120-140` ; `app/views/components/courses/_course_card.html.erb:20` ; `app/helpers/layout_helper.rb:27,32,36` |
| 8 | `after_sign_in_path_for` : « vestige à vérifier » (`transverse.md:1441`) | **Vivant** : c'est le routage post-connexion par rôle (TR-02) | `app/controllers/identity/sessions_controller.rb:33`, `app/controllers/homepage_controller.rb:21` |
| 9 | « Contrôleurs Stimulus : **31** », « tous enregistrés, aucun orphelin » (`transverse.md:22,1257`) ; « 31 fichiers, **30** enregistrés » (`ui-design-system.md` §4) | **29** fichiers `*_controller.js`, **29** enregistrements dans `index.js`. Les deux inventaires se trompent, et se contredisent | `ls app/javascript/controllers/*_controller.js \| wc -l` → 29 ; `grep -c application.register app/javascript/controllers/index.js` → 29 |
| 10 | Fil élève « en 8 sections », enseignant « en 7 », équipe « en 7 » (`ui-design-system.md` §3.2-3.4) | **4 sections rendues** par rôle ; en-tête, tableau examens, examens (et activités pour l'élève) sont commentés | `app/views/students/feed/index.html.erb:11-19`, `teachers/feed/index.html.erb:10-18`, `teams/feed/index.html.erb:11-18` |
| 11 | `/teams/dashboard` décrit comme un « Control Center » fonctionnel (`ui-design-system.md` §3.4) ; « seul le rôle `team` a un espace fonctionnel » (`transverse.md:1456`) | **La page lève `NoMethodError`** : `find_courses` a été renommée `find_all` le 2026-09-01 (commit `cde1013`) sans mise à jour de l'appelant. Inversement, l'espace `school_admin` (`/schoolstaff`) répond 200 | `app/domain/use_cases/identity/get_teams_dashboard.rb:40` ; `app/infrastructure/repositories/catalog/course_repository.rb:17` ; sonde `/teams/dashboard` → `NoMethodError`, `/schoolstaff` → 200 |
| 12 | Tableau de bord direction : « 3 sections : niveaux, messages, activités » (`ui-design-system.md` §3.5) | Messages et activités sont des **tableaux vides codés en dur** : ces deux sections affichent toujours leur état vide | `app/controllers/schoolstaff/feed_controller.rb:29-32` |
| 13 | Bouton de thème dans « les 4 `_navbar` de rôle » (`ui-design-system.md` §4.1, §4.3) | **3** : élève, enseignant, équipe. La barre de navigation `schoolstaff` n'en a pas | `grep -c theme app/views/layouts/shared/*/_navbar.html.erb` → schoolstaff 0, les trois autres 4 |
| 14 | `/teachers/setup` : « Onboarding première connexion » (`ui-design-system.md` §3.3) | **Jamais atteint** : aucune redirection ni aucun lien n'y mène ; la première connexion d'un enseignant va vers `/teachers/classrooms` | `application_controller.rb:25-26` ; `grep teachers_setup_path app/` → 0 appelant |
| 15 | `/teachers/prepa_acquisitions/new` : « Formulaire d'acquisition — Commander » (`ui-design-system.md` §3.3) | C'est une **inscription enseignant** qui ouvre une session, sans rien commander ; mot de passe = numéro de téléphone (TR-17) | `app/controllers/teachers/prepa_acquisitions_controller.rb:23-48` |
| 16 | Base de développement `lnclassapp_development` (`transverse.md:1155`) | C'est la **modification locale non commitée** ; la valeur versionnée est `app_lnclassapp_development` | `git diff config/database.yml` (ligne 31) |
| 17 | Numéros de ligne | Décalés sans que le code ait changé : `production.rb:47` → **44** (`silence_healthcheck_path`), `:54` → **53** (`queue_adapter`), `:20` → **25** (`active_storage.service`), `:70` → **73** (`i18n.fallbacks`) ; `test_helper.rb:44` → **52** (`minimum_coverage`) ; `puma.rb:39` → **38** | fichiers cités |
| 18 | `app/views/pwa/manifest.json.erb` : « icône `/icon.png` » | Précision : `public/icon.png` est l'icône du générateur Rails, **un disque rouge plein**. L'application installée porte donc ce disque rouge et le nom « AppLnclassapp » | `public/icon.png`, `app/views/pwa/manifest.json.erb:2-21` |
| 19 | Service worker : non mentionné | `app/views/pwa/service-worker.js` est **entièrement commenté**, et aucun `navigator.serviceWorker.register` n'existe dans `app/javascript` ni dans `app/views` : aucun service worker n'est jamais enregistré | `app/views/pwa/service-worker.js:1-33` ; `grep -rn serviceWorker app/` → 0 |

### 3.2 Sondage des règles chiffrées de `transverse.md`

| Règle vérifiée | Verdict | Preuve |
|---|---|---|
| Bandeau PWA : après un refus, il est reproposé au bout de **3 jours** ; il n'apparaît que si le User-Agent contient `iphone`, `android` ou `ipad` | ✅ exact | `app/models/concerns/install_bannerable.rb:25-34,47-50` |
| `config/queue.yml` : dispatcher `polling_interval: 1`, `batch_size: 500` ; workers `threads: 3`, `JOB_CONCURRENCY` par défaut **1** ; identique dans les 3 environnements | ✅ exact | `config/queue.yml` |
| Tâche récurrente `every hour at minute 12`, en production seulement | ✅ exact | `config/recurring.yml` |
| Solid Cache `max_size` **256 Mo** ; Solid Cable `polling_interval` **0,1 s**, `message_retention` **1 jour** | ✅ exact | `config/cache.yml`, `config/cable.yml` |
| `filter_parameters` : **12** motifs, sans `:contact` | ✅ exact | `config/initializers/filter_parameter_logging.rb:6-8` |
| Cliquet SimpleCov **45 %** lignes / **29 %** branches | ✅ valeur exacte, ligne fausse (52, pas 44) | `test/test_helper.rb:52` |
| **19** migrations ; **315** vues `.erb` ; locales **80** lignes (31 + 25 + 24) | ✅ exact | `ls db/migrate`, `find app/views -name "*.erb"`, `wc -l config/locales/*` |
| **46** tables, dont **14** Solid | ❌ faux → 45 et 13 | correction n° 1 |
| **31** contrôleurs Stimulus | ❌ faux → 29 | correction n° 9 |

---

## 4. Écarts avec les décisions

| Sujet | Source A dit | Source B dit | Qui devrait trancher |
|---|---|---|---|
| Lecture des feeds et tableaux de bord par use case | **ADR-0012 §3.1** : suppression des use cases « pass-through », `GetStudentFeed` cité nommément ; les contrôleurs appellent directement les Queries. **ADR-0006 §3.2** : les pages de feed et de tableau de bord « n'appellent **jamais** de Use Case » | Le code passe par `UseCases::Identity::GetStudentFeed`, `GetTeacherFeed`, `GetTeamsFeed`, `GetTeamsDashboard` (`students/feed_controller.rb:16`, `teachers/feed_controller.rb:17`, `teams/feed_controller.rb:15`, `teams/dashboard_controller.rb:26`) ; `Schoolstaff::FeedController` interroge l'ORM directement, sans Query (`schoolstaff/feed_controller.rb:19-26`) | ADR de fondation « chemin de lecture » : confirmer ADR-0006/0012 ou les remplacer |
| Contrat de sortie d'une lecture | **ADR-0012 §3.1** : les Queries renvoient des `ViewObjects` typés | **0 occurrence** de `ViewObjects` dans `app/` ; les feeds renvoient des `OpenStruct` (14 dans `app/domain/use_cases/identity/get_*.rb`) ou des relations ActiveRecord ; **conventions §2** ne prévoit d'emplacement ni pour les `ViewObjects` ni pour `app/domain/strategies/`, qui existe | Même ADR, plus mise à jour de conventions §2 |
| Contexte borné des écrans d'accueil | **Conventions §2** : « tout est namespacé par contexte borné », six contextes | Les feeds de lecture pédagogique vivent dans `UseCases::Identity::*` alors qu'ils agrègent classroom, assessment, communication ; les Queries sont à plat (`Queries::StudentFeedQuery`), ce que la même table des conventions autorise (`Queries::ClassroomReportQuery`) | ADR « découpage des contextes » : rattacher les tableaux de bord à un contexte ou en créer un |
| Dépendance du domaine vers l'infrastructure | **ADR-0001 §3** : la communication passe **exclusivement** par injection de dépendances | **20 fichiers** de `app/domain/` instancient `Repositories::…` par défaut (ex. `get_student_feed.rb:31-33`) ; le test de pureté ne cherche que `ActiveRecord`, `ApplicationRecord` et `Orm::`, et tolère une violation connue (`test/domain/domain_purity_test.rb:19-31`) | ADR-0001 à compléter : liste exhaustive de ce que le domaine ne peut pas référencer |
| Emplacements de la couche présentation | **ADR-0014 §2.2** : `app/presentation` avec `presenters/` et `serializers/`, plus `app/infrastructure/adapters` | **Conventions §2** et `CLAUDE.md` : delivery dans `app/controllers/` ; **conventions §8** : `app/presenters/` « inexistant — créer à la première vraie nécessité, sinon retirer des docs ». Aucun de ces répertoires n'existe | Un ADR qui remplace explicitement ADR-0014 §2.2 (ADR contre conventions : pas d'arbitrage silencieux) |
| DTO namespacés | **Conventions §2** : `Dtos::<Contexte>::…` ; **ADR-0014 §2.1** : DTO systématiques | `Dtos::UserDto` à la racine, utilisé par `identity/users_controller.rb:54` et `teachers/prepa_acquisitions_controller.rb:39` ; `InstallBannerController` lit `params[:status]` brut (`install_banner_controller.rb:15`) | Lot de migration (conventions §8 « namespaces dupliqués ») |
| Public cible et navigateurs | **ADR-0009 §1-2** : smartphones Android d'entrée de gamme en 3G/4G, JavaScript minimal | `allow_browser versions: :modern` (`application_controller.rb:16`) renvoie 406 à un Chrome 99 Android (sonde) ; bundle JS de 622 Ko ; KaTeX, GTM et Clarity chargés depuis des CDN tiers (`layouts/application.html.erb:42-44`, `shared/analytics/_analytics.html.erb`) | ADR « support navigateurs et budget de performance » |
| Mode sombre | **ADR-0013 §2.1** (qui remplace ADR-0009 §3.3) : le thème sombre est un état géré par Stimulus, donc une fonction attendue | Contrôleur `theme`, script anti-FOUC et persistance présents, mais **0** variante `dark:` et aucune palette sombre (`ui-design-system.md` §4.3) ; absent de l'espace `school_admin` | UDR « mode sombre : livré ou retiré » |
| Worker des jobs | **ADR-0010 §3.1** : « un processus de worker léger intégré à Puma dépile les tâches » ; §4 « développement local en 1 clic… jobs asynchrones » ; §5 montre `adapter: solid_queue` dans `queue.yml` | Le plugin n'est chargé que si `SOLID_QUEUE_IN_PUMA` est posé (`config/puma.rb:38`), variable non versionnée ; en développement et en test, ActiveJob reste sur `:async` (seul `production.rb:53` pose `:solid_queue`) ; `queue.yml` n'a pas de clé `adapter` | ADR-0010 à amender : où tourne le worker, en dev comme en production |
| Temps réel et SMS | **ADR-0010 §3.1 et §3.3** : SMS de confirmation par jobs ; notifications broadcastées par Solid Cable | Aucun SMS, aucun mailer, aucun `broadcast` ni `turbo_stream_from` dans `app/` | ADR-0010 à amender, ou features à inscrire au registre |
| Thruster | **ADR-0010 §5** : « Kamal et Thruster ne sont pas requis » | `Dockerfile:91` : `CMD ["./bin/thrust", "./bin/rails", "server"]` | ADR-0010 à amender |
| Branche déployée | **ADR-0010 §2-3** : déploiement Railway à chaque push sur la branche principale | `main` a **58 commits de retard** sur `HEAD` (dernier commit applicatif le 2026-08-19) ; la configuration Railway n'est pas versionnée : impossible de savoir quelle branche tourne en production | ADR de fondation « chaîne de livraison » (phase 0, `programme.md`) |
| Tableau de bord « `/admin` » | **ADR-0006 §1** : cite un tableau de bord administrateur `/admin` | Aucune route `/admin` ; l'équivalent est `/teams/dashboard`, qui lève (TR-10) | Correction documentaire d'ADR-0006 |
| Couverture de tests | **ADR-0024** : aucune ligne non exécutée par un test ne doit atteindre la production | Les 4 feeds et le tableau de bord équipe n'ont **aucun** test ; seul `GET /` est testé (`test/controllers/homepage_controller_test.rb`). C'est ce qui a laissé `find_courses` et les constantes ORM disparues casser TR-04, TR-05 et TR-10 sans alerte | Pas de conflit de règle : constat à reporter dans le PRD cadre (tests système par rôle dès la vague 1) |
| Unicité du personnel d'établissement | **Glossaire** (`docs/guide/glossaire.md:34`) : « un utilisateur ne peut être membre du staff d'une école qu'une fois » | Aucun index unique sur `school_staffs` (`transverse.md` §2.10 n° 4) ; `set_school` prend le premier profil (`schoolstaff/base_controller.rb:32-33`) | ADR du périmètre SC |
| Paiement « Prepa BAC » | Aucun ADR ni UDR ne décrit de modèle de paiement | Le code affiche un prix (2 000 FCFA, `paywall.html.erb:28` ; 2000 FCFA, `homepage/index.html.erb:119`), une règle de rémunération des enseignants (1 000 FCFA par élève, `entities/teacher.rb:58`) et un statut `unpaid` jamais persisté (`students/prepa_registrations_controller.rb:54`) | Décision produit puis ADR : le modèle économique est un besoin qu'aucune source ne tranche |
| Analytique et consentement | Aucun ADR ; `CLAUDE.md` et conventions §1 imposent l'interface en français sans rien dire du traçage | GTM `GTM-N8FK5T78` et Clarity `fhs9um41ic` codés en dur, sans consentement ni CSP (`shared/analytics/_analytics.html.erb:9,18`) | ADR « mesure d'audience et consentement » |
| Écrans par rôle | Aucune UDR sur la navigation, les feeds, les tableaux de bord, la PWA ni le mode sombre (les UDR 0001 à 0004 couvrent catalogue, organisation scolaire, évaluation, identité) | 4 × 4 partials de navigation divergents ; couverture bureau / mobile incohérente (`ui-design-system.md` §5.9) | UDR de fondation « shell applicatif par rôle » (le brief interdit d'écrire une vue sans UDR) |
| Écarts listés par les conventions | **Conventions §8** annonce trois écarts connus | Ce document en ajoute au moins dix (ci-dessus), non inscrits au §8 | Mise à jour de conventions §8, ou renvoi explicite vers le registre des contradictions de la feuille de route |

---

## 5. Couverture

### 5.1 Chaque table de `docs/feature_listing.md`

Les ID `TR` sont ceux de ce document. `CA-nn` renvoie à [`complements-catalog.md`](complements-catalog.md). Les autres contextes sont cités par leur préfixe (ID, CO, SC, CL, AS) : leurs fichiers de compléments n'existaient pas encore à la rédaction.

| Ligne de `feature_listing.md` | Table réelle | Écrite par | Lue par | Remarque |
|---|---|---|---|---|
| `Users` | `users` | ID (5 inscriptions, profil, mot de passe), CL (élèves de démo, TR-30 💀), **TR-17**, **TR-22**, **TR-25** | **TR-02**, **TR-10**, **TR-11**, **TR-20**, **TR-21**, CO (bandeau), SC (personnel) | `contact` limité à 10 caractères (ID) |
| `team` | `teams` | ID (inscription équipe) | **TR-10** (`current_team.firstname`), CA et CO (`team_id` des DRENA, écoles, exercices, messages) | — |
| `teacher` | `teachers` | ID (`/teacher-signup`), **TR-17**, SC (`/schoolstaff/teachers`) | **TR-05**, **TR-10**, **TR-15**, **TR-18**, CL | `material_id` sans clé étrangère ; TR-17 accepte une matière vide (sonde) |
| `student` | `students` | ID (`/student-signup`, `/c/:unique_code`), SC (`/schoolstaff/students`), CL (démo 💀) | **TR-04**, **TR-10**, **TR-12**, **TR-15**, AS | — |
| `Drena` | `drenas` | CA et SC (CRUD) ; import **TR-29 💀** | **TR-09**, **TR-10** (onglet Régions), **TR-13**, **TR-17** (liste déroulante), ID (cascade d'inscription), API | — |
| `Schools` | `schools` | SC (CRUD), **TR-28** (import) | **TR-10** (KPI), **TR-15**, **TR-17**, **TR-27** (lien « École »), CL | — |
| `series` | `series` | CA-24, **TR-28** (création implicite à l'import) | **TR-13**, CA | — |
| `Level` | `levels` | CA-18, **TR-28** (création implicite) | **TR-05**, **TR-09**, **TR-13**, **TR-15** | `TR-17` charge `@levels` sans l'afficher (`prepa_acquisitions_controller.rb:18`) |
| `level_series` | `level_series` | CA-19, **TR-28** (`course_repository.rb:139`) | **TR-09**, **TR-13**, CA-16/17 | vivante (correction n° 4) |
| `classrooms` | `classrooms` | SC, CL, CL démo 💀 | **TR-04**, **TR-05**, **TR-15**, **TR-12** | `unique_code` 5 contre 6 caractères générés (CL) |
| `teacher_classrooms` | `teacher_classrooms` | CL (`POST /teachers/classrooms`) | **TR-02**, **TR-05**, CL | vivante (correction n° 3) |
| `classroom_students` | `classroom_students` | ID (inscription élève), SC, CL | **TR-04**, **TR-10**, **TR-12**, **TR-15** | ADR-0003 |
| `materials` | `materials` | CA-22, **TR-28** | **TR-04** (lève), **TR-17**, **TR-18**, CA | — |
| `courses` | `courses` | CA-05/06/07, **TR-28** | **TR-09** (activités), **TR-10** (KPI `courses_total`), **TR-04** (lève) | — |
| `essentials` | `essentials` | CA-12/13/14, **TR-28** | **TR-05** (via la constante disparue), CA, AS | — |
| `classroom_courses` | **n'existe plus** | — | reste appelée comme association d'`Orm::Course` par **TR-04** (`student_feed_query.rb:23-24`) → `ActiveRecord::ConfigurationError` | fusionnée dans `classroom_assignments` par `20260829202238_create_classroom_assignments.rb` |
| `classroom_essentials` | **n'existe plus** | — | **TR-05** (`teachers_feed_query.rb:49`, `Orm::ClassroomEssential`) → `NameError` | idem |
| `exercises` | `exercises` | CA, AS, **TR-28** | **TR-09** (`orphan_exercises_count`, `teams_feed_query.rb:61`), AS | — |
| `questions` | `questions` | AS, **TR-28** | AS | hors périmètre TR |
| `answers` | `answers` | AS, **TR-28** (import) | AS | hors périmètre TR |
| `classroom_exercises` | **n'existe plus** | — | **TR-04** (`student_feed_query.rb:30`), AS (`teachers/classroom_exercises_controller.rb:76`) → `NameError` | idem |
| `exercise_sessions` | `exercise_sessions` | AS, CL/AS démo 💀 | **TR-04**, **TR-05** | — |
| `question_attempts` | `question_attempts` | AS | AS | hors périmètre TR |
| `exercise_badges` | `exercise_badges` | AS | **TR-04** | — |
| `messages` | `messages` | CO | **TR-04**, **TR-05**, **TR-09** (liste et activités) ; **jamais TR-15** (tableau vide en dur) | l'audience n'a pas de valeur pour `school_admin` (`orm/message.rb:33,40-44`) : même câblé, le personnel ne verrait que `all` |
| `AddInstallBannerStatusToUsers` | colonnes `users.install_banner_status` (integer, défaut 0, non nul) et `users.install_banner_last_changed_at` (migration `20260814170350`) | **TR-25** (`install_banner_controller.rb:21-24`) | **TR-25** (`layouts/application.html.erb:99` → `install_bannerable.rb:25-34`) ; détail métier CO | la sonde montre qu'un client peut poser n'importe quelle valeur de l'enum, y compris `visible`, que le serveur n'utilise jamais ; sur iOS, « Installer » enregistre `installed` sans rien installer (`install_app_controller.js:45-50`) |
| `school_roles` | `school_roles` | SC | SC | hors périmètre TR |
| `school_staffs` | `school_staffs` | SC (`/schools/:id/school_staffs`) | **TR-15**, **TR-16** (`schoolstaff/base_controller.rb:32-33`) | aucun index unique (écart glossaire, §4) |
| `knowledge_gaps` | `knowledge_gaps` | AS | AS | hors périmètre TR |
| `classroom_assignments` | `classroom_assignments` | CL, AS | **TR-04** et **TR-05** devraient la lire ; ils appellent encore les trois anciennes constantes | ADR-0007, ADR-0016 |
| `solid_cache_entries` | idem | **TR-32**, production seulement (`production.rb:50`) : KPI équipe 1 h (`teams_dashboard_query.rb:24,37`), référentiels 12 h (CA), rapports de classe (AS) | idem | `:memory_store` en dev, `:null_store` en test |
| `solid_cable_messages` | idem | **jamais** : aucun `broadcast`, aucun `turbo_stream_from` dans `app/` | — | **TR-33 💀** |
| `solid_queue_jobs` | idem | **TR-28** (2 appels `perform_later` atteignables), **TR-31** ; production seulement | worker | dev et test en `:async` : la table n'y est jamais écrite |
| `solid_queue_ready_executions` | idem | chaque job mis en file (**TR-28**, **TR-31**) | worker | — |
| `solid_queue_scheduled_executions` | idem | aucun appelant applicatif ne programme de job différé (aucun `set(wait:)`, aucun `retry_on`) | — | écriture applicative non identifiée |
| `solid_queue_claimed_executions` | idem | worker, pendant l'exécution | worker | — |
| `solid_queue_blocked_executions` | idem | **jamais** : aucun `limits_concurrency` dans `app/` | — | morte en pratique |
| `solid_queue_failed_executions` | idem | tout job qui lève, faute de `retry_on` / `discard_on` (`application_job.rb:10-16`) — ex. un import JSON invalide (**TR-28**) | personne : aucune interface de supervision | les échecs restent invisibles |
| `solid_queue_pauses` | idem | **jamais** : pas de Mission Control ni de commande de pause | — | morte en pratique |
| `solid_queue_processes` | idem | battement de cœur du superviseur (`bin/jobs` ou plugin Puma) | Solid Queue | dépend de `SOLID_QUEUE_IN_PUMA` ou d'un second service Railway (non versionné) |
| `solid_queue_recurring_executions` | idem | **TR-31**, une ligne par exécution horaire | Solid Queue | — |
| `solid_queue_recurring_tasks` | idem | **TR-31**, au démarrage du planificateur, depuis `config/recurring.yml` | Solid Queue | — |
| `solid_queue_semaphores` | idem | **jamais** (aucun `limits_concurrency`) | — | morte en pratique |

**Tables du schéma absentes de `feature_listing.md`**, à ajouter à la traçabilité :

| Table | Écrite par | Lue par | Statut |
|---|---|---|---|
| `teacher_schools` | ID (`/teacher-signup`), **TR-17** (`teacher_repository.rb:28-31`), SC | **TR-05**, **TR-10**, **TR-15**, **TR-02** (école de l'enseignant) | vivante, ADR-0004 |
| `action_text_rich_texts` | CO (messages), CA-05 et CA-13 (cours, fiches) | **TR-04**, **TR-05**, **TR-09** (`includes(:rich_text_content)`), CA | vivante (correction n° 2) |
| `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records` | **TR-37** : avatars (ID), couvertures de cours et de fiches (CA), image et audio des messages (CO) | **TR-04**, **TR-05**, **TR-09** (`with_attached_*`) | vivantes, mais stockage `:local` éphémère en production |
| `friendly_id_slugs` | jamais (`use: :slugged` sans `:history`, `orm/user.rb:31`, `models/concerns/sluggable.rb:20`) | — | morte (confirmé) |
| `schema_migrations`, `ar_internal_metadata` | Rails | Rails | internes |

### 5.2 Routes du périmètre

| Route | ID | Statut vérifié (sonde) |
|---|---|---|
| `GET /` | TR-01, TR-02 | 200 (visiteur) ; 302 vers l'espace du rôle (connecté) |
| `GET /students` | TR-04 | lève `ActiveRecord::ConfigurationError` |
| `GET /teachers` | TR-05 (TR-06) | 302 vers `/teachers/classrooms` sans classe ; lève `NameError` avec une classe |
| `GET /teachers/dashboard` | TR-07 | 200, page d'échafaudage |
| `GET /teachers/setup` | TR-08 | 200, orpheline |
| `GET /teams` | TR-09 | 200 |
| `GET /teams/dashboard` | TR-10, TR-11, TR-12 | lève `NoMethodError` |
| `GET /teams/setup` | TR-13, TR-12 | 200 |
| `GET /teams/lnclassai` | TR-14 | 200 (iframe vers `https://claude.site/public/artifacts/f0e52a4a-…/embed`, `teams/dashboard/lnclassai.html.erb:4`) |
| `GET /schoolstaff` | TR-15, TR-16 | 200 |
| `GET /teachers/prepa_acquisitions/new` | TR-17 | 200 sans connexion ; aucun lien dans l'application n'y mène |
| `POST /teachers/prepa_acquisitions` | TR-17 | 302 vers `download` ; compte `teacher` créé, mot de passe = contact (sonde : `authenticate(contact)` vrai) |
| `GET /teachers/prepa_acquisitions/download` | TR-18 | 302 vers `/` sans connexion ; 200 pour tout connecté, rôle non vérifié ; bouton `href="#"` (`download.html.erb:29`) |
| `GET /users` | TR-20 | 200 (`team`) ; 302 pour les autres rôles |
| `GET /users/:public_id` | TR-21 | 200 pour **tout** connecté, élève compris, **y compris avec l'identifiant numérique** (sonde : `/users/3016` en élève) |
| `GET /users/:public_id/edit`, `PATCH`, `PUT`, `DELETE /users/:public_id` | TR-22 | détail : périmètre ID |
| `GET /manifest(.json)` | TR-24 | 200, contenu du générateur |
| `GET /service-worker(.js)` | TR-24 | 200, fichier entièrement commenté |
| `PATCH /install_banner` | TR-25 | 204 pour un statut de l'enum ; 422 sinon |
| `GET /up` | TR-34 | **404** |
| `/etabl` (lien de la landing) | TR-03 | aucune route |
| (paywall, rendu dans `GET /students/examens/:id`) | TR-19 | inatteignable : la route lève avant (`Orm::ExamSubject`, AS), et `unpaid?` renvoie toujours `false` (`orm/student.rb:77-79`, `entities/student.rb:65-67`) |
| `turbo/native/navigation#recede\|resume\|refresh` (3) | — | **mortes** : aucune application Hotwire Native dans le dépôt |
| `action_mailbox/ingresses/*` (6) et `rails/conductor/action_mailbox/*` (8, dev) | TR-38 | **mortes** : aucune boîte de réception |
| `active_storage/*` (9) | TR-37 | vivantes |
| `/_debugbar` (5, dev) | — | outillage de développement (gem du groupe `:development`, `Gemfile:59-65`) |
| `POST /courses/import_json`, `POST /drenas/:drena_id/schools/import_json` | TR-28 | routes : périmètres CA et SC |
| `/api/v1/*` (3) | — | hors périmètre TR : cascades d'inscription (ID, SC, CL) |

### 5.3 Branches locales et distantes comparées à `HEAD` (`684ae16`)

Commandes : `git for-each-ref refs/heads refs/remotes`, `git rev-list --count HEAD..<b>`, `git diff --stat HEAD...<b> -- app db config`. Aucun `fetch` : l'état des branches distantes est celui du dernier fetch local.

**Branches à 0 commit d'avance** — entièrement contenues dans `HEAD`, rien à récupérer : `CASL`, `Config`, `Design-with-ui-ux-pro-max`, `Develop`, `Feature_remediation_and_demo_student`, `Lnclass-school`, `Staging`, `Testedapp`, `bounded-context`, `ch`, `docs/process-v2`, `feature/ticket-1-catalog`, `feature/ticket-2-schools`, `feature/ticket-3-assessment`, `feature/ticket-5-messaging`, `refactoring`, ainsi que leurs homologues `origin/*`. `Develop`, `Teamprocess` et `docs/process-v2` pointent sur `HEAD`. **`Staging` a 58 commits de retard** (dernier commit le 2026-08-19).

**Branches en avance :**

| Branche (locale = distante) | Avance / retard | Contenu en avance | Diff `app db config` | Rattachement |
|---|---|---|---|---|
| `main` | +4 / −58 | 3 merges `Staging` et `67bd08b Add Graphify` (2026-08-18) : `generate_graph.py`, `generate_json.py` et 796 fichiers `graphify-out/` (graphe de code généré) | **vide** | Aucune feature. Outillage d'analyse, mort pour la refonte. **À noter** : si Railway déploie `main` (ADR-0010), la production tourne sur le code du 2026-08-19 |
| `feature/ticket-4-auth` | +6 / −17 | refonte visuelle des 5 écrans connexion / inscription, plan du ticket 4 ; côté infra, `Orm::Student` et `Orm::Teacher` délèguent à un `domain_entity` chargé par le repository, `set_public_id` passe par `Entities::Identity::User`, `StudentRepository` mappe vers `Entities::Identity::Student` avec `payment_status: "paid"` en dur | 12 fichiers, +316 / −493 | **Périmètre ID** (mission 1). Touche TR-19 : le paywall y resterait inatteignable (`payment_status` forcé) |
| `feature/ticket-4-auth-dashboard` | +7 / −17 | les 6 commits ci-dessus, plus `cd348fc` : réactive `feed_header` et `examen_dashboard` sur `/teams` (`app/views/teams/feed/index.html.erb`) | 13 fichiers, +319 / −496 | ID ; ce dernier commit touche **TR-09** |
| `origin/dependabot/bundler/active_storage_validations-4.1.1` | +5 / −58 | branche issue de `main` (donc Graphify) + montée **majeure** 3.0.6 → 4.1.1 | vide (seuls `Gemfile.lock` et Graphify) | TR-37, dépendance |
| `origin/dependabot/bundler/bootsnap-1.26.0` | +5 / −58 | 1.25.0 → 1.26.0 | vide | TR-36 |
| `origin/dependabot/bundler/image_processing-2.1.0` | +5 / −58 | montée **majeure** 1.14.0 → 2.1.0 | vide | TR-37 |
| `origin/dependabot/bundler/selenium-webdriver-4.49.0` | +5 / −58 | 4.47.0 → 4.49.0 | vide | outillage de test |
| `origin/dependabot/bundler/solid_queue-1.7.0` | +5 / −58 | 1.6.0 → 1.7.0 | vide | TR-28, TR-31 |
| `origin/dependabot/bundler/thruster-0.1.26` | +5 / −58 | 0.1.25 → 0.1.26 | vide | TR-36 |
| `origin/dependabot/github_actions/actions/cache-6` | +1 / −68 | `actions/cache` v4 → v6 (`ci.yml`) | vide | CI (phase 0) |
| `origin/dependabot/github_actions/actions/checkout-7` | +1 / −68 | `actions/checkout` → v7 (`ci.yml`, `hitl_audit.yml`) ; `HEAD` mélange déjà v6 (`ci.yml`) et v4 (`hitl_audit.yml:16`, `security.yml:10`) | vide | CI (phase 0) |
| `origin/dependabot/github_actions/actions/upload-artifact-7` | +1 / −68 | `actions/upload-artifact` v4 → v7 | vide | CI (phase 0) |

Aucune branche en avance ne porte de feature applicative absente de `HEAD`, à l'exception des deux branches `feature/ticket-4-*` (périmètre ID). Les versions de gems de `HEAD` sont bien celles d'avant les montées Dependabot (`Gemfile.lock:50,92,146,334,350,367`).

### 5.4 Jobs

| Job | ID | Appelant | Statut |
|---|---|---|---|
| `ImportCoursesJsonJob` | TR-28 | `catalog/courses_controller.rb:183` (routé) | ⚠️ vivant ; échec silencieux ; fichier dans `tmp/imports` local au conteneur |
| `ImportSchoolsJsonJob` | TR-28 | `catalog/schools_controller.rb:99` (routé) | ⚠️ idem |
| `ImportDrenasJsonJob` | TR-29 | `catalog/drenas_controller.rb:35`, action **non routée** | 💀 |
| `SimulateClassroomExerciseJob` | TR-30 | aucun | 💀 |
| `Catalog::GenerateSchoolDemoDataJob` | TR-30 | aucun | 💀 |
| `clear_solid_queue_finished_jobs` (récurrent) | TR-31 | `config/recurring.yml`, production | ⚠️ dépend d'un worker lancé |

---

## 6. Ce que je n'ai pas pu déterminer

1. **Quelle branche et quelle configuration tournent en production.** Railway n'est pas versionné (`transverse.md` §5.3) : ni la branche déployée (`main` a 58 commits de retard, `Staging` aussi), ni la présence de `SOLID_QUEUE_IN_PUMA` ou d'un second service `bin/jobs`, ni la sonde de santé réellement configurée. Sans ces réponses, on ne sait pas si TR-28 et TR-31 s'exécutent en production.
2. **Le comportement du tag GTM `GTM-N8FK5T78`** : la configuration du conteneur vit chez Google. Impossible de savoir s'il suit les navigations Turbo (historique) ou seulement le premier chargement, ni quelles balises il injecte.
3. **L'installabilité réelle de la PWA** : sans service worker enregistré, l'émission de `beforeinstallprompt` dépend de la version du navigateur. Non testé sur un appareil.
4. **Le contenu de l'iframe LnclassAI** (`claude.site/public/artifacts/f0e52a4a-…`) : ressource externe, non inspectée ; on ne sait ni ce qu'elle fait, ni si elle reçoit des données de l'application.
5. **Le rendu complet des vues de TR-09, TR-13 et TR-15** a été vérifié sur une base presque vide : un seul enregistrement par table, sans message, sans cours, sans session. Les branches de vue qui ne s'affichent qu'avec des données (cartes de messages, activités) n'ont pas été exercées.
6. **La destination prévue du paywall** : le numéro WhatsApp `2250000000000` (`paywall.html.erb:51`) est fictif, alors que la modale de support utilise un vrai numéro (`layouts/shared/_support_modal.html.erb:74`). Le moyen de paiement cible (Wave, WhatsApp manuel) n'est décrit nulle part.
7. **L'intention de `/teachers/dashboard` et `/teachers/setup`** : écran jamais implémenté pour le premier, onboarding contourné pour le second. Aucun document ne dit s'ils étaient prévus ou abandonnés.
8. **La neutralité des noms de fichiers d'import** : `tmp/imports/<uuid>_<original_filename>` (`drenas_controller.rb:30`, idem pour cours et écoles) insère un nom fourni par le client dans un chemin disque. Je n'ai pas vérifié jusqu'où Rack nettoie `original_filename` dans cette version.
9. **Les fuseaux horaires** : `config.time_zone` n'est pas posé (`config/application.rb:25`), donc UTC. Cela coïncide avec l'heure d'Abidjan (UTC+0), mais je n'ai trouvé aucune décision qui le dise voulu.
