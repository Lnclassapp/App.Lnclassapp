# Journal — Finitions UX

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Lot 0 — Socle : briques des finitions (2026-09-29)

Branche `feature/finitions-ux-lot-0`, depuis `feature/finitions-ux`. UDR-0054 acceptée par le porteur le 2026-09-29 (textes d'infobulles à valider dans la PR) : statut et index mis à jour.

### API gelées (UDR-0054 §3)

Un lot vertical qui aurait besoin d'en changer une s'arrête : le Lot 0 rouvre.

**Ruby**

| Brique | Signature | Contrat |
|---|---|---|
| Titre | `page_title(page)` (`PageTitleHelper`) | Renvoie « Page · Espace · Lnclass », échappé une fois (`SafeBuffer`). Le **premier** appel d'un rendu nomme la page (`content_for :page_title`) ; les suivants composent seulement (une modale rendue dans sa page ne prend pas le titre de la page). Vide ou blanc → `ArgumentError` « page_title : titre vide ». |
| Titre | `document_title` | `[page, espace, "Lnclass"].compact_blank.join(" · ")` ; espace = `shared.page_title.spaces.<current_actor.role>`, aucun sans acteur. Layout : `document_title`, sauf une vue qui pose encore `content_for :title` sans `page_title` (repli jusqu'au Lot Z). |
| Retour | `ui_back_link(label, href:)` → `components/_back_link` | `nav[aria-label="Retour"]` › `a.min-h-tap` chevron + `span.truncate`. |
| Retour | `ui_page_header(title:, subtitle: nil, back: { label:, href: })` | Le retour est rendu **avant** le bloc du `h1`. |
| Retour | `back_href(default, from:)` (`NavigationHelper`) | `request.referer` s'il est du même hôte et que son chemin vaut exactement `from` → son chemin **et** sa chaîne de requête ; sinon (absent, autre hôte, autre chemin, illisible) `default`. |
| Infobulle | `ui_info_tip(text, label:)` → `components/_info_tip` | `details` › `summary.summary-plain.size-tap` (icône + `sr-only` « Aide : <label> ») + panneau dans le flux. |
| Copie | `ui_copy_button(text, label:, copied:, failed: t("shared.clipboard.failed"), aria_label: nil, variant: :secondary, size: :sm, icon: "clipboard-document")` → `components/_copy_button` | `span[data-controller=clipboard][data-clipboard-text-value]` › bouton `hidden` (`clipboard#copy`) + `template[data-clipboard-target=copied|failed]`. Messages : `shared.clipboard.copied_link`, `copied_code`, `copied_codes`, `failed`. |
| Modale | `ui_modal(…, document_title: nil)` | `data-modal-document-title-value` sur le contrôleur ; la `<dialog>` porte `data-controller="autofocus" data-autofocus-mode-value="dialog"` et l'action `modal:opened->autofocus#focus` ; le pied porte `data-autofocus-footer`. |
| Champ | `ui_field(…, autofocus: true)` | Pose `data-autofocus-target="field"`, jamais l'attribut `autofocus`. Les 14 `autofocus: true` existants sont devenus des cibles du contrôleur sans toucher aux vues. |
| Recherche | `Queries::Shared::TextSearch.apply(scope, term, columns:)` · `.normalize(term)` | `translate(lower(col), accentuées, simples) LIKE :pattern`, colonnes en `OR`, motif échappé (`sanitize_sql_like`) ; terme vide → **la même** portée. `columns` = expressions SQL écrites par le code. |

**Stimulus** (enregistrés par motif, aucun manifeste)

| Contrôleur | Posé sur | Valeurs · cibles · actions | Contrat |
|---|---|---|---|
| `autofocus` | `<body>` (layout), chaque `<dialog>` (`_modal`) | `mode` (`page` \| `dialog`) · `field`, `fallback` · `focus` | Premier `[aria-invalid=true]` de la portée, puis `field` ; en `dialog` : premier champ, puis `fallback`, puis le premier `[data-action~="modal#close"]` du pied (jamais la croix). En `page`, tout ce qui est dans une `<dialog>` **ou dans `[data-autofocus-skip]`** est ignoré. `connect()` en page ; `modal:opened` en dialog (et `connect()` si la boîte est déjà modale). |
| `clipboard` | `ui_copy_button` | `text` · `button`, `copied`, `failed` · `copy` | Montre le bouton ; succès → toast `copied` + événement `clipboard:copied` (`detail.text`, bouillonnant) ; échec → toast `failed`. |
| `autosubmit` | le `<form>` | `pattern` (sans barres), `message` · `input`, `status` | Écoute seul `input`, `submit`, `turbo:submit-start/end` sur le formulaire. Valeur sans espaces **ni tirets** ; une seule soumission par valeur, verrou pendant un envoi (un `submit` pendant le verrou est annulé). `message` écrit dans `status` (texte : `shared.autosubmit.sending`). Aides : `shared.autosubmit.hint_second_factor`, `hint_join`. |
| `search` | le `<form>` GET | `delay` (300), `minLength` (2), `digits` (faux) · `button` · `queue` (sur `input`), `submit` (sur `change`) | Cache `button` ; `queue` envoie après `delay` si vide ou ≥ `minLength` (mode `digits` : 10, 13 en `225…` ou 15 en `00225…` chiffres), avec `data-turbo-action="replace"` rendu à sa valeur d'origine à `turbo:submit-end` ; `submit` garde l'action du formulaire. |
| `download` | un conteneur | `content`, `filename` · `button`, `saved` (`<template>` de toast) · `save`, `print` | Montre les boutons ; `save` : Blob `text/plain;charset=utf-8`, `a[download]` cliqué, `revokeObjectURL`, toast `saved` ; `print` : `window.print()`. |
| `modal` (modifié) | `_modal` | `documentTitle` | Émet `modal:opened` (cible : la `<dialog>`) après `showModal()` ; pose `documentTitle` sur l'onglet à l'ouverture, rend le précédent à la fermeture ou au retrait de la boîte (sauf si une navigation l'a changé entre-temps). |

**CSS et locales** : `@utility summary-plain` ; `#toasts` masqué à l'impression. `shared.page_title.spaces.*`, `shared.clipboard.*`, `shared.autosubmit.*`, `shared.info_tips.{badges,mastery,school_status}` (textes d'infobulle communs à plusieurs écrans ; les autres vont dans la locale de l'écran), `components.back_link.label`, `components.info_tip.label`.

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | `page_title` : le premier appel nomme la page, les suivants composent seulement | `content_for` **ajoute** : une modale rendue dans sa page (`page_title` passé à `ui_modal(document_title:)`) aurait donné « Niveaux Nouveau niveau » | Non (UDR-0054 §3.1, précision) |
| 2026-09-29 | Zone `[data-autofocus-skip]` ignorée par l'auto-focus de page | `/design` montre des champs en erreur : sans elle, chaque visite du guide sautait au milieu de la page. Réservée aux démonstrations | Non |
| 2026-09-29 | `autosubmit` retire espaces **et tirets** pour tous les motifs ; valeur `message` pour la région d'état | Un seul contrôleur pour les 6 chiffres et `/join` (« KFM-37 ») ; le texte reste dans la locale | Non |
| 2026-09-29 | `print:hidden` des toasts par une règle `@media print` de `application.tailwind.css`, pas une enveloppe dans le layout | `#toasts` est dans `shared/_toasts` (hors lot) et `design_controller_test` exige `body > #toasts` | Non |
| 2026-09-29 | Trois textes d'infobulle dans `shared.info_tips` (badges, maîtrise, statut d'établissement) | Ils servent sur plusieurs écrans ; le plan interdit `shared` aux lots verticaux | Non |

### Ce qui a dérapé

- Premier jet du test d'infobulle à 390 px : `/design` défile **déjà** en largeur au téléphone (ligne d'API des toasts `flash[:notice|…]`, sans espace, et barre d'onglets), avant le chantier. Le test mesure donc l'infobulle elle-même (panneau dans l'écran, largeur de page inchangée à l'ouverture), pas la page entière.

### Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `SchoolsQuery` et `AccountSearchQuery` gardent leurs `ACCENTED`/`PLAIN` au lieu de `Queries::Shared::TextSearch` | Hors du champ `Fichiers` du Lot 0 ; comportement identique | Lot D1 (établissements) ou un refactor |
| La ligne d'API des toasts de `/design` fait défiler la page à 390 px | `app/helpers/design_helper.rb` est hors du lot | Lot Z |
| Les sections « Amendement du 2026-09-29 » des 21 UDR amendées disent encore « Statut : `Proposé` » (formule conditionnelle : « une fois l'UDR-0054 acceptée, cette section fait foi ») | Hors du champ du lot, texte déjà conditionnel | Lot Z |

### Portes (passées une seule fois, en fin de lot)

- `bin/rubocop` : 1027 fichiers, aucune offense.
- `CI=1 PARALLEL_WORKERS=2 bin/rails test` : 2464 runs, 31850 assertions, 0 échec, 0 erreur, 7 skips (tests de performance, `PERF=1`, préexistants) ; lignes 8751/8751 (100 %), branches 2137/2137 (100 %).
- `COVERAGE=0 bin/rails test:system` : 208 runs, 2562 assertions, 0 échec, 0 erreur, 0 skip.
- `bin/brakeman -q --no-pager` : 0 avertissement.
- `bin/check-asset-budget` : `application.js` 41,8 Ko gzip / 60 Ko.

## Lot H — Profil et pages de compte (2026-09-29)

Branche `feature/finitions-ux-lot-h`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles : `page_title`, `ui_page_header(back:)`, `ui_modal(document_title:)`, `home_path_for` (existant) ; aucune API modifiée.

### Ce qui est fait

| Écran | Finitions |
|---|---|
| « Mon profil » | Titre « Mon profil · <Espace> · Lnclass » ; retour « Accueil » vers l'accueil du rôle (`home_path_for(current_actor.role)`, donc « Travail des élèves » pour la direction), premier lien du `main` (FU-10) |
| Modales du nom, du numéro, du PIN, de la photo | `page_title` passé à `ui_modal(document_title:)` (FU-05 : `/profile/name/edit` ouverte par son URL → « Modifier mon nom · Élève · Lnclass ») ; `autofocus: true` retiré : le contrôleur `autofocus` (mode `dialog`) vise le premier champ (nom, PIN actuel, PIN actuel, champ photo) |
| Compte en attente | `page_title` ; suffixe « · Lnclass » retiré de la locale |
| Code de récupération (modale et repli HTML) | `page_title` ; la modale (`_code`) nomme l'onglet, aussi quand elle arrive par le Turbo Stream de `create` ; toujours **aucun** « Copier » (FU-27) |

Test : `test/system/finitions/account_pages_test.rb` (6 cas), rouge d'abord pour la bonne raison (titres sans espace ni suffixe, pas de retour), vert ensuite.

## Lot C2 — Équipe : contenu et imports (2026-09-29)

Branche `feature/finitions-ux-lot-c2`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_modal(document_title:)`, `ui_page_header(back:)`), aucune modifiée.

- **FU-05 (cours)** : les modales cours, fiche essentielle et exercice (création et modification) et le téléversement d'un import passent `page_title(...)` à `ui_modal(document_title:)` ; ouvertes par leur URL, `<title>` vaut « Nouveau cours · Équipe · Lnclass ». Leur auto-focus vient de `_modal` (premier champ, puis champ en erreur après un 422) : aucune vue n'a eu à le déclarer (`autofocus: true` du nom du cours gardé, devenu cible `field`).
- **FU-10 (Rapport d'import), FU-11** : le bouton `arrow-left` « Retour aux imports » devient le retour commun `ui_page_header(back: { label: "Imports", href: teams_imports_path })`.
- `teams/imports/index` et `show` : `content_for :title` → `page_title`.
- Titres d'onglet des imports sans deux-points : `teams.imports.new.page_titles.<type>` (« Importer des DRENA ») et `teams.imports.show.page_titles.<type>` (« Import d'établissements ») ; `show.page_title` (« Import : %{kind} ») retiré. Une clé par type plutôt qu'une interpolation : l'article français change avec le type (« des », « d' », « de »).

## Lot G — Direction (2026-09-29)

Branche `feature/finitions-ux-lot-g`, depuis `feature/finitions-ux` (Lot 0 fusionné). Critères couverts : FU-10 (classe, direction), FU-11 (direction), FU-21, FU-49 ; titres « Travail des élèves », « <classe> », « Enseignants » · Direction · Lnclass (FU-06 côté direction).

- **Retour** : le bouton `ghost` `arrow-left` de la page d'une classe devient `ui_page_header(back: { label: "Travail des élèves", href: school_admin_classrooms_path })`.
- **Infobulles** (textes de l'UDR-0054 §3.4 repris tels quels, clés `school_admin.classrooms.tips.*`) : « Taux de rendu » et « Moyenne » en en-tête de colonne (liste) et sur les tuiles (classe), « Score moyen » en en-tête de colonne, légende « — Chiffre non calculé » sous chaque tableau avec l'aide de « — ». La phrase `average_rule` de la liste est retirée : l'aide de « Moyenne » la contient.
- **Recherche d'un élève** : `form#student-work-search` (GET, `q`, contrôleur `search`, `role="search"`), frame `student_work_students` avec compteur `aria-live` et état vide « Aucun élève ne correspond » + « Effacer la recherche » (`_top`) ; absent sur une classe sans élève. Les tuiles et le sous-titre restent ceux de la classe entière.

## Lot D2 — Équipe : accueil, comptes, pilotage, croissance, invitation équipe (2026-09-29)

Branche `feature/finitions-ux-lot-d2`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles, aucune modifiée.

### Ce qui a été fait

| Écran | Finitions |
|---|---|
| Accueil équipe | `page_title` → « Accueil · Équipe · Lnclass » (FU-02) |
| Débloquer un compte | titre ; retour « Accueil » (FU-10) ; `form#account-lookup-form` sous `search` en mode `digits`, `minLength` 0, « Rechercher » caché avec JavaScript ; champ numéro cible `field` de l'auto-focus ; frame `aria-busy:opacity-50` ; aide du champ qui annonce l'envoi au numéro complet (FU-50). `_result` non touché |
| Pilotage | titre ; DRENA → `change->search#submit`, « Filtrer » caché avec JavaScript (FU-52) ; infobulles « Réussite moyenne » (tuile rendue dans `_key_figures`, `_figure` étant hors lot), « Établissements actifs » et « Élèves actifs » dans l'en-tête du tableau par DRENA (FU-21, FU-23). Aucune requête touchée |
| Croissance | titre sans suffixe dans la locale ; retour « Accueil » (FU-10) ; infobulles « k enseignant », « Conversion par partage », « Cycle viral médian », « Élèves arrivés par enseignant actif » (FU-21) |
| Invitation équipe | modale « Inviter un membre de l'équipe » et « Invitation créée » : `page_title` passé à `ui_modal(document_title:)` ; « Copier le lien » (`ui_copy_button`, icône `link`, nom accessible « Copier le lien d'invitation », toast « Lien copié. ») sous le lien, même valeur que le champ (FU-24). Flux `create.turbo_stream` (`SecretResponse`) intact |

## Lot E — Enseignant : classe, cours dans la classe, parrainage (2026-09-29)

Branche `feature/finitions-ux-lot-e`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_back_link`, `ui_page_header(back:)`, `ui_info_tip`, `ui_copy_button`, contrôleurs `clipboard` et `search`, `Queries::Shared::TextSearch`) : aucune API n'a manqué.

### Ce qui est livré

| Critère | Écran | Ce qui change |
|---|---|---|
| FU-02 | Accueil enseignant | « Accueil · Enseignant · Lnclass » |
| FU-07 | Classe (équipe) | Retour « <établissement> » vers `school_path` ; `ClassroomHeaderQuery::Row#school_public_id` |
| FU-08 | Classe (enseignant) | Retour « Accueil » vers `teacher_home_path` (`ui_back_link`) |
| FU-10 | Inviter un collègue | `ui_page_header(back: « Classes » → teacher_classrooms_path)` |
| FU-26 | Classe | « Copier » (code) et « Copier le lien » (`/c/<code>`, nouveau) par `ui_copy_button` ; `classroom--join-code-copy` n'est plus appelé ici |
| FU-28 | Inviter un collègue, accueil enseignant | « Copier le lien » = `ui_copy_button` ; `identity--share` perd `copy` et `toast`, gagne `recordCopy` sur `clipboard:copied` (une copie refusée n'est pas comptée) |
| FU-48 | Classe | `form#classroom-roster-search` (GET, `role=search`, contrôleur `search`) hors du frame `classroom_roster_list` ; compteur `aria-live` ; « Aucun élève ne correspond » + « Effacer la recherche » (`_top`) ; formulaire absent sur une classe vide ; « Générer un code de récupération » en `data-turbo-frame="_top"` ; `ClassroomOverviewQuery#call(search:)` sur `concat_ws(' ', prénom, nom)` |
| FU-53 | Classe | Aucun débordement à 390 px, infobulles ouvertes |
| — | Cours dans la classe, fiche dans la classe, assigner un cours, déclaration des classes | Titres par `page_title` (nom de l'objet, « Assigner à mes classes », « Mes classes ») ; retours « <classe> », « <cours> », « <cours> » en `ui_back_link` (fin des « Retour à … ») |
| — | Classe | Infobulles effectif (« 40 est le nombre maximum… », plafond lu) et « Dernier score » (une fois, au-dessus de la liste, pas une par ligne) |

Titre de la classe : « 3e A · Enseignant · Lnclass » (l'ancien « <classe> · <établissement> » avait un séparateur interne, interdit par UDR-0054 §3.1).

## Lot B — Second facteur et codes de secours (2026-09-29)

Branche `feature/finitions-ux-lot-b`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_field(autofocus:)`, `ui_info_tip`, `ui_copy_button`, contrôleurs `autosubmit` et `download`) ; `SecretResponse` réutilisé sans rien y toucher (le contrôleur d'activation n'est pas modifié, aucun en-tête posé).

Critères couverts : FU-12, FU-34, FU-35, FU-36, FU-37, FU-38, FU-39, FU-40, FU-41, FU-42, FU-43, FU-53 (vérification, codes de secours) — `test/system/finitions/second_factor_test.rb` (9 cas), `test/controllers/identity/second_factors_controller_test.rb`, `test/controllers/identity/second_factor_enrollments_controller_test.rb`, `test/system/identity/sign_in_test.rb`.

## Lot A — Entrée publique et invitation (2026-09-29)

Branche `feature/finitions-ux-lot-a`, depuis `feature/finitions-ux` (Lot 0 fusionné). Critères : FU-03, FU-13, FU-17, FU-19, FU-30, FU-31, FU-32, FU-33, FU-44, FU-53 (acceptation d'une invitation). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_back_link`, `ui_info_tip`, `ui_field(autofocus:)`, contrôleurs `autofocus` et `autosubmit`) ; aucune modifiée.

### Ce qui a été fait

- **Invitation** : `InvitationsController#accept` pose `session[:login_contact]` (numéro normalisé du compte créé) avant le 303 vers « Se connecter » ; aucune session d'authentification, rien dans l'URL ni dans le flash. « Nom » est la cible `field` de l'auto-focus. Titre « Créer mon compte · Lnclass » pour les deux variantes (équipe, direction), comme le dit l'amendement de l'UDR-0019 ; les deux anciennes clés `team.page_title` et `school_staff.page_title` sont retirées.
- **Se connecter** : `SessionsController#new` lit **et supprime** `session[:login_contact]` (avant la redirection d'une personne déjà connectée, pour qu'il ne survive pas) ; numéro valide → champ rendu groupé par deux, cible `field` sur le PIN ; sinon cible sur le numéro. Numéro `autocomplete="username"` (UDR-0054 §3.8). Infobulle du PIN.
- **Pages publiques** : le logo (les deux, colonne large et en-tête mobile) est un lien « Lnclass, accueil » vers `root_path`, `alt=""` sur l'image (le lien porte le nom). « PIN oublié » gagne un logo (il n'en avait pas) et le lien de retour « Se connecter » remplace le lien texte (la clé `back` est gardée, sa valeur devient « Se connecter » : `test/system/error_paths_test.rb` la lit).
- **`/join`** : `autosubmit` (motif de l'UDR-0054 §3.6), aide « 3 lettres puis 2 chiffres. La classe s'ouvre dès le code complet. », région `status` ; « Continuer » reste.
- **Inscription enseignant** : infobulle « Code d'établissement » ; focus sur le champ fautif après un 422.
- **Titres** : « Connexion », « PIN oublié », « Inscription enseignant », « Rejoindre une classe », « Rejoindre ma classe », « Accès interdit », « Page introuvable », « Accueil » (landing), par `page_title`, sans suffixe dans les locales.

## Lot F — Catalogue, exercice, élève (2026-09-29)

Branche `feature/finitions-ux-lot-f`, depuis `feature/finitions-ux` (Lot 0 fusionné). Critères : FU-02 (élève), FU-14, FU-27 (élève), FU-47, FU-53 (catalogue). Briques du Lot 0 utilisées telles quelles : `page_title`, `ui_back_link`, `ui_info_tip`, `ui_field as: :search`, contrôleur `search`, `Queries::Shared::TextSearch`, `shared.info_tips.{badges,mastery}`.

### Ce qui a été fait

- **Catalogue** : `CourseCatalogQuery#call(search:)` passe par `TextSearch.apply(…, columns: ["courses.name"])` (aucun index) ; `Catalog::CoursesController` lit `q`. Le formulaire `#courses-filters` porte `search`, le champ « Rechercher un cours » (`search#queue`), les listes en `change->search#submit`, « Filtrer » en cible `button` ; le frame `courses` s'estompe (`aria-busy`). État vide unique « Aucun cours ne correspond » + « Effacer la recherche ».
- **Page cours** : le fil complet devient `ui_back_link "Cours"` (FU-14).
- **Retours** : fiche → nom du cours, exercice → nom de la fiche, résultat → nom de la fiche, session → « Quitter la session » ; tous par `ui_back_link`.
- **Titres** (`page_title`) : « Cours », « <cours> », « <fiche> », « <exercice> » (page et session), « Résultat de <exercice> », « Accueil », « Ma classe » ; suffixes « — Session », « — Résultat », « — Cours », « Fiche essentielle : » retirés des locales.
- **Infobulles** (textes de `shared.info_tips`) : maîtrise et badge de la progression (exercice), maîtrise et palier du résultat, badges de la fiche (élève), badges et maîtrise de l'accueil élève.
- « Ma classe » : titre seulement ; le code reste sans « Copier » (FU-27, testé).

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | `page_title` appelé dans le partial `_code` (pas seulement dans `show`) | `create.turbo_stream.erb` n'est dans aucun lot : c'est le seul moyen que la modale ouverte par le flux porte son titre. Dans `show`, le premier appel nomme la page, le second compose seulement (même texte) | Non |
| 2026-09-29 | Locale du retour : `identity.profiles.show.back` (« Accueil ») | Texte propre à l'écran, `shared` fermé aux lots verticaux | Non |

### Ce qui a dérapé

- `RAILS_ENV=test bin/rails db:prepare` sur une base neuve charge les **seeds** (matière « SVT »…) : `test/system/identity/profile_test.rb` tombe alors en `PG::UniqueViolation` sur `index_materials_on_name`, sans lien avec le lot. Corrigé par `RAILS_ENV=test bin/rails db:schema:load` dans le worktree. À signaler aux autres worktrees du chantier (même commande de mise en place).

### Dette laissée derrière

Aucune.

### Vérifications (tests du lot seulement)

- `COVERAGE=0 bin/rails test test/system/finitions/account_pages_test.rb test/system/identity/profile_test.rb test/system/identity/profile_contact_test.rb test/system/identity/profile_pin_test.rb test/system/identity/profile_photo_test.rb` : 16 runs, 0 échec, 0 erreur.
- `COVERAGE=0 bin/rails test` des contrôleurs `identity/{profiles,profile_*,pending_accounts,pin_recovery_codes}` : 70 runs, 0 échec.
- `bin/rubocop` sur le test du lot : aucune offense.

| 2026-09-29 | Le deux-points disparaît du **titre de l'onglet** ; le titre **visible** de la modale (« Importer : DRENA ») et le `h1` du rapport (« Import : Établissements ») restent | UDR-0054 §3.1 vise le segment « Page » de l'onglet ; les titres visibles sont vérifiés par `test/system/teams/drena_import_test.rb` et `test/controllers/teams/imports_controller_test.rb`, hors du champ `Fichiers` du lot | Non |

| 2026-09-29 | La recherche filtre dans le contrôleur les élèves **déjà lus** par `StudentWorkQuery#classroom`, avec `Queries::Shared::TextSearch.normalize` des deux côtés (sans casse ni accents, sous-chaîne) ; `student_work_query.rb` **n'est pas modifié** (écart au champ `Fichiers` du plan, qui prévoyait `search:`) | Consigne de l'orchestrateur : un chantier perf parallèle réécrit `StudentWorkQuery`. Une classe compte au plus quelques dizaines d'élèves déjà chargés : aucune requête en plus, même résultat que le `LIKE` serveur | Non |
| 2026-09-29 | `role` et `aria-label` du formulaire passés par `html:` | `form_with` ignore ces options au premier niveau (vérifié au rendu) | Non |

### Ce qui a dérapé

- `test/infrastructure/queries/school/student_work_query_test.rb` (champ `Test associé`) n'est pas touché, la requête ne changeant pas : FU-49 est prouvé par `test/controllers/school_admin/classrooms_controller_test.rb` et `test/system/finitions/school_admin_test.rb`. Si le chantier perf veut porter la recherche en SQL, il ajoute `search:` à la requête et le contrôleur n'a plus qu'à la lui passer.
- Constaté hors lot : le formulaire de recherche de `/design` (`design/index`, Lot 0) passe `role:` et `"aria-label":` au premier niveau de `form_with` : ils ne sont pas rendus. À corriger au Lot Z (ou par les lots E et F s'ils recopient ce motif).

| 2026-09-29 | `role` et `aria-label` des formulaires de « Débloquer un compte » et du filtre DRENA passés par `html:` | Au premier niveau de `form_with`, Rails ne les rend pas (relevé par le Lot G) : les deux formulaires n'avaient en fait ni `role=search` ni nom accessible. Vérifiés par les tests | Non |
| 2026-09-29 | `Queries::Shared::TextSearch` non utilisé pour « Débloquer un compte » | La recherche reste **exacte** par numéro (UDR-0020 §2.1, UDR-0054 §3.9 « numéro exact (inchangé) ») : aucun fragment texte à appliquer ; `AccountLookupQuery` et `AccountSearchQuery` hors du champ du lot | Non |
| 2026-09-29 | Panneau d'infobulle dans un `div`, jamais dans un `p` | Le parseur HTML ferme un `<p>` ouvert devant `<details>` : le panneau sortirait de son libellé | Non |

### Ce qui a dérapé

- `RAILS_ENV=test bin/rails db:prepare` sur une base neuve l'a **semée** (niveaux, matières) : 7 tests de l'accueil en échec d'unicité. Rechargée par `db:schema:load` ; `bin/rails db:test:prepare` est la bonne commande.

### Vérification (règle de la vague : tests du lot seulement)

- Tests rouges d'abord : `test/system/finitions/team_accounts_test.rb` (7/7 en échec sur la base, pour la bonne raison), assertions ajoutées aux tests de contrôleur (4 échecs).
- `COVERAGE=0 bin/rails test` sur `test/controllers/teams/{account_lookups,invitations,dashboards,growth,homes}_controller_test.rb`, `test/system/finitions/team_accounts_test.rb`, `test/system/teams/{account_unlock,dashboard,growth,team_home}_test.rb`, `test/i18n/locale_files_test.rb` : 0 échec, 0 erreur.
- `bin/rubocop` sur les fichiers Ruby touchés : aucune offense.

| 2026-09-29 | `<main data-action="turbo:morph@document->autofocus#focus">` sur les six pages publiques à formulaire | Le re-rendu 422 est un **morphing** (`turbo_refreshes_with method: :morph`) : `<body>` n'est pas reconnecté, `autofocus#connect` ne repasse pas, le focus reste sur le bouton (FU-17 et FU-33 rouges pour cette raison). L'action appelle l'API gelée (`autofocus#focus`) sans toucher au contrôleur | Non — **à remonter** : le contrat du Lot 0 (« re-rendu 422 compris ») ne tient pas en page ; le contrôleur devrait écouter `turbo:morph` lui-même, et ces attributs deviendraient superflus (inoffensifs) |
| 2026-09-29 | Infobulles (PIN, code d'établissement) **sous** le champ, pas dans le libellé | `ui_field` rend le libellé dans un `<label>` et n'a pas d'emplacement après lui ; un `<details>` dans un `<label>` est du contenu interactif interdit | Non |
| 2026-09-29 | Landing : titre « Accueil · Lnclass » (au lieu du slogan) | UDR-0054 §3.1 : un seul segment, libellé court de l'écran | Non |

### Ce qui a dérapé

- Base de test : `db:prepare` sur une base neuve a chargé les seeds (181 classes, niveaux « 6ème »…) ; les tests système qui créent un niveau « 6ème » tombaient en `UniqueViolation`. `bin/rails db:test:prepare` a rendu une base vide.

| 2026-09-29 | Sur la fiche et l'accueil élève, une infobulle par liste (en tête de la liste), pas une par ligne | Les badges de chaque ligne sont dans `catalog/essentials/_exercise_progress` et `classroom/student_homes/_assigned_exercise`, hors du champ `Fichiers` ; une aide par liste évite aussi dix `<details>` identiques | Non |
| 2026-09-29 | Un seul état vide « Aucun cours ne correspond » (recherche ou filtres), bouton « Effacer la recherche » vers `courses_path` | FU-47 ; la clé `clear_filters` devient `clear_search` | Non |
| 2026-09-29 | `role` et `aria-label` du formulaire passés par `html:` | Au premier niveau de `form_with`, ils n'étaient pas rendus (relevé par le Lot G) ; le test du contrôleur les vérifie désormais | Non |
| 2026-09-29 | Titre de la session d'exercice = titre de l'exercice | UDR-0022 non amendée ; la règle « nom de l'objet = le `h1` » de l'UDR-0054 §3.1 | Non |
| 2026-09-29 | Test système dans `module Finitions` imbriqué (`module Finitions` / `class CatalogAndStudentTest`) | Le module n'existe pas ailleurs : `Finitions::…` au premier niveau lève `NameError` ; la forme imbriquée tient quel que soit l'ordre de chargement des fichiers des autres lots | Non |

### Ce qui a dérapé

- `db:prepare` sur la base de test neuve l'a semée : les usines butaient sur `index_levels_on_name`. `bin/rails db:schema:load` (RAILS_ENV=test) a vidé la base.
- `test/system/catalog/course_catalog_test.rb` cliquait « Filtrer » : le bouton est caché avec JavaScript, le test choisit la liste et attend la mise à jour sans clic.

### Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Titre visible « Importer : %{kind} » (modale) et `h1` « Import : %{kind} » (rapport) gardent leur deux-points | Les tests qui les vérifient sont hors du lot (voir ci-dessus) | Lot Z, si le porteur veut aligner le visible sur l'onglet |
| `create.turbo_stream` des imports (« Import : %{kind} », modale de suivi sans `document_title`) | `app/views/teams/imports/create.turbo_stream.erb` est hors du champ `Fichiers` | Lot Z |

### Ce qui a dérapé

- `test/system/teams/exercise_form_test.rb` (AS-03) a échoué une fois sur « pas de morphing » pendant que neuf autres lots tournaient sur la machine, puis est passé trois fois de suite seul : attente du `turbo:morph` sous charge, sans lien avec le lot.

### Portes (tests du lot seulement, règle de la vague)

- `COVERAGE=0 bin/rails test test/system/finitions/team_content_test.rb` : 5 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/teams/{course_management,essential_management,exercise_form,import_flow,drena_import}_test.rb test/controllers/teams/{courses,essentials,exercises,imports}_controller_test.rb test/i18n/locale_files_test.rb` : 85 runs, 0 échec (l'erreur de morphing ci-dessus mise à part, repassée verte).
- `bin/rubocop test/system/finitions/team_content_test.rb` : aucune offense.

| État d'erreur du frame `student_work_students` (UDR-0054 §3.9 : `ui_error_state` + « Réessayer » sur une réponse non 2xx) | Aucune brique du Lot 0 ne le fournit (il faudrait un gestionnaire `turbo:frame-missing`) ; une classe devenue inaccessible rend la page 404 entière | Lot 0 rouvert ou Lot Z |

### Vérifications (tests du lot seulement)

- `COVERAGE=0 bin/rails test test/controllers/school_admin/classrooms_controller_test.rb` : 14 runs, 0 échec (7 nouveaux cas écrits d'abord, rouges faute de retour, d'aides, de formulaire et de clés).
- `COVERAGE=0 bin/rails test test/system/finitions/school_admin_test.rb test/system/school_admin/student_work_test.rb` : 4 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/i18n/locale_files_test.rb test/controllers/school_admin/teachers_controller_test.rb` : 11 runs, 0 échec.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense.

## Lot C1 — Équipe : référentiel (2026-09-29)

Branche `feature/finitions-ux-lot-c1`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles, aucune redéfinie.

### Fait

- **Titre** (FU-04, FU-05) : Niveaux, Séries, Matières, DRENA et Barème appellent `page_title` (plus de `content_for :title`) ; les neuf modales (`new`/`edit` des quatre référentiels, `edit` du barème) passent `document_title: page_title(…)` à `ui_modal`. Ouvertes par leur URL, elles donnent leur `<title>` (« Nouveau niveau · Équipe · Lnclass », « Nouvelle DRENA · Équipe · Lnclass »…).
- **Retour** (FU-10) : `ui_page_header(back: { label: t(".back"), href: team_home_path })` sur les cinq écrans ; clé `back: "Accueil"` dans chaque locale d'écran.
- **Auto-focus** (FU-15, FU-16) : rien à écrire dans les vues ; le contrôleur `autofocus` de la `<dialog>` vise le premier champ, puis le champ en erreur après un 422. Les `autofocus: true` de `ui_field` (séries, matières, DRENA) restent : ce sont des cibles `field`.
- Test : `test/system/finitions/team_referential_test.rb`.

### Bloqué (non livré, à trancher par l'orchestrateur)

| Critère | Blocage | Ce qu'il faut |
|---|---|---|
| FU-18 | Les confirmations ouvertes depuis le menu ⋮ (`ui_dropdown_item dialog:` → `dropdown#openDialog`) passent par `showModal()` directement, sans `modal#open` : `modal:opened` n'est pas émis, l'auto-focus ne part pas, le navigateur pose le focus sur la croix. Sur `/design`, la confirmation s'ouvre par un déclencheur `modal#open`, d'où le vert du Lot 0. Touche aussi séries, matières, DRENA, établissements… | **Rouvrir le Lot 0** : `dropdown_controller#openDialog` doit émettre `modal:opened` sur la `<dialog>` (ou passer par le contrôleur `modal`). Aucune vue du lot n'a alors à changer. Test écrit, `skip` à retirer. |
| FU-22 | Retirer le `title=` du badge « Hors barème » casse `test/controllers/teams/levels_controller_test.rb` (l. 78-81 : exige `title` et le `.sr-only`), **hors du champ `Fichiers`** du lot. `_level_row` n'a donc pas été touché. | Ajouter ce test au lot (ou le laisser à Lot Z) : dans `_level_row`, remplacer `title` et le `.sr-only` par `ui_info_tip t(".outside_generation_tip"), label: t(".outside_generation_tip_label")` dans une enveloppe `whitespace-normal` (la cellule est `whitespace-nowrap`) ; texte UDR-0054 §3.4. Test écrit, `skip` à retirer. |

### Écart relevé

- FU-22 nomme l'aide « Aide : hors génération » alors que le badge affiche « Hors barème » (UDR-0054 §3.4 : « Aide : <libellé> »). Le test suit le PRD ; à trancher par le porteur.

### Ce qui a dérapé

- `RAILS_ENV=test bin/rails db:prepare` sur une base neuve **charge les seeds** : les tests qui appellent `seed_referential` tombent alors en `RecordNotUnique` (et un premier test « vert » s'appuyait sur les seeds sans le savoir). Base de test refaite par `db:drop db:create db:schema:load`, et le test du lot appelle `seed_referential`.

### Portes (ciblées, règle de la vague)

- `COVERAGE=0 bin/rails test test/system/finitions/team_referential_test.rb test/system/teams/{levels,series,materials,drenas,classroom_plan}_test.rb test/controllers/teams/{levels,series,materials,drenas,classroom_plans}_controller_test.rb` : 104 runs, 942 assertions, 0 échec, 0 erreur, 2 skips (FU-18, FU-22 ci-dessus).
- `bin/rubocop test/system/finitions/team_referential_test.rb` : aucune offense.

| `_figure` ne sait pas porter une infobulle : la tuile « exercices terminés » est écrite dans `_key_figures` | `_figure.html.erb` hors du champ `Fichiers` | Lot Z ou un refactor du pilotage |
| La recherche de compte du pilotage (`_search`) garde `role`/`aria-label` au premier niveau de `form_with` (non rendus) | `_search.html.erb` hors du champ `Fichiers` ; recherche non dynamique par décision du porteur | Lot Z |

| 2026-09-29 | Le titre `h2` de la liste compte l'effectif (`active_students_count`), pas le résultat filtré ; le compteur du frame annonce le résultat | Le `h2` est hors du frame : il ne bougerait pas pendant la frappe, mais mentirait sur une page filtrée rechargée sans JavaScript | Non |
| 2026-09-29 | L'infobulle « Dernier score » est posée une fois, en tête de la liste, pas sur chaque ligne | Une infobulle par élève répéterait 40 fois le même texte au lecteur d'écran | Non |
| 2026-09-29 | Toasts de copie : `shared.clipboard.*` ; les clés propres à l'écran (`copied`, `copy_failed`) sont retirées | UDR-0054 §3.5 fixe les trois messages | Non |

### Fichiers manquants au champ du lot (non modifiés, à traiter par le Lot Z ou l'orchestrateur)

Deux tests de contrôleur hors du champ `Fichiers` affirment l'ancien rendu et échouent sur cette branche :

- `test/controllers/identity/referrals_controller_test.rb:33` cherche `button[data-action='identity--share#copy']`. Remplacer par :
  `assert_select "[data-controller=clipboard][data-clipboard-text-value='#{link}'] button[data-action='clipboard#copy'][aria-label=\"#{I18n.t("#{PAGE}.invite.copy_label")}\"]"`
- `test/controllers/classroom/course_assignments_controller_test.rb:28-30` lit `tl("back")` (clé retirée : le libellé est désormais le nom du cours). Remplacer la ligne 30 par :
  `assert_select "nav[aria-label='Retour'] a[href='#{course_path(@course.slug)}']", text: "Génétique et évolution"` (la ligne 28 passe telle quelle : « Assigner à mes classes »).

### Écarts

- **Erreur serveur pendant la recherche** (UDR-0054 §3.9, « ui_error_state dans le frame ») : aucune brique du Lot 0 ne remplace une réponse non 2xx d'un frame ; le Lot E n'a pas de fichier JS pour le faire. Comportement actuel de Turbo (« Content missing »). À trancher au Lot Z, pour les quatre listes à la fois.
- `classroom/join_code_copy_controller.js` n'est plus appelé par la classe ; la fiche établissement (Lot D1) l'appelle encore jusqu'à sa fusion. Suppression au Lot Z (FU-54).
- Ordre test → code : tests de requête et de contrôleur écrits et vus rouges avant le code ; le test système `test/system/finitions/classroom_test.rb` a été écrit après les vues (non observé rouge).

### Vérification (limitée au lot, règle de la vague)

- `COVERAGE=0 bin/rails test` sur `classroom_header_query_test`, `classroom_overview_query_test`, `classrooms_controller_test` : 23 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/classroom_test.rb test/system/classroom/{classroom_page,teacher_home,teaching_selection,course_assignments,classroom_essential}_test.rb test/system/identity/invite_colleague_test.rb` : 25 runs, 0 échec.
- `error_paths_test` « locked-out student » (code de récupération depuis la liste, désormais dans un frame) : vert, sans rechargement.
- Contrôleurs voisins (`classroom_courses`, `classroom_essentials`, `teacher_homes`, `teaching_selections`, `student_classrooms`) et `locale_files_test` : verts ; les deux échecs attendus sont listés ci-dessus.
- `bin/rubocop` sur les 9 fichiers Ruby du lot : aucune offense.

| 2026-09-29 | Les liens « J'utilise un code de secours » / « Utiliser le code de l'application » sont des visites ordinaires, **sans** `data-turbo-action="replace"` (écart à UDR-0054 §3.6) | Le layout déclare `turbo_refreshes_with method: :morph` ; Turbo traite un `replace` vers le **même chemin** comme un rafraîchissement et fusionne la page (morph) : `<body>` n'est pas reconnecté, l'auto-focus ne vise pas le champ « Code de secours » (le focus restait sur le lien fusionné). Une visite `advance` remplace le `<body>` : le focus arrive sur le champ. Coût : un pas d'historique de plus | Non (à reporter dans UDR-0054 au Lot Z) |
| 2026-09-29 | Le texte du fichier téléchargé est composé dans la vue : titre, date (`l(Date.current, format: :long)`), consigne, ligne vide, les 10 codes | UDR-0054 §3.7 ; rien d'autre que ce que la page affiche déjà | Non |
| 2026-09-29 | Le paramètre `backup` est lu par un `before_action` du contrôleur de vérification (`@backup`), gardé au 422 par un champ caché | Sans JavaScript, le lien mène à la même variante ; un échec ne ramène pas au code de l'application | Non |

### Ce qui a dérapé — à traiter hors du lot (le lot s'est arrêté à sa frontière)

- **Brique du Lot 0 incomplète : l'auto-focus ne suit pas un re-rendu 422 fusionné.** Le rendu d'un formulaire en échec est lui aussi un rafraîchissement pour Turbo (`isPageRefresh` vrai sans visite) ; avec `morph`, `<body>` n'est pas reconnecté et `autofocus#connect` ne se rejoue pas. Constaté : code de secours faux envoyé par un clic sur « Vérifier » → le focus reste sur le bouton, pas sur le champ en erreur. FU-35 passe parce que la saisie garde le focus dans le champ. Correction proposée (Lot 0 rouvert ou Lot Z) : `autofocus` en mode page écoute aussi `turbo:morph` (ou `turbo:render`). Le test correspondant n'est **pas** dans ce lot (il échouerait) : à ajouter avec la correction.
- **Tests hors du champ `Fichiers` que ce lot casse** (non modifiés, conformément à la consigne) :
  - `test/support/system_authentication_helper.rb` — `sign_in_as` tape le code puis clique « Vérifier » ; avec l'envoi automatique, la page peut déjà être partie : **erreur intermittente** (1 sur 3 constatée sur `sign_in_test` avant de le contourner dans ce fichier). Tous les tests système qui connectent un membre de l'équipe en dépendent. Correction : retirer le `click_on` (le code part seul), comme `sign_in_with_second_factor` de `sign_in_test.rb`.
  - `test/system/identity/team_invitation_test.rb` (Lot A), `test/system/identity/secret_back_navigation_test.rb`, `test/system/error_paths_test.rb` (2 cas), `test/system/boucle_pedagogique_test.rb` — cliquent `identity.second_factor_enrollments.backup_codes.done` (clé retirée : le bouton est devenu « Continuer », derrière la case obligatoire « Je les ai gardés ») et/ou « Activer »/« Vérifier » après l'envoi automatique. Correction : `check "Je les ai gardés"` puis `click_on "Continuer"`, et plus de clic après les 6 chiffres.
- FU-12 : « Se déconnecter » mène, comme sur la vérification, à l'accueil public (`root_path`, `SessionsController#destroy`, hors lot), pas directement à « Se connecter ». Le test vérifie la session fermée (l'activation renvoie ensuite à « Se connecter »).
- Le titre « Accueil · Équipe · Lnclass » de l'accueil de l'équipe relève du Lot D2 : il n'est pas vérifié ici.

### Vérifications du lot

- `COVERAGE=0 bin/rails test test/controllers/identity/second_factors_controller_test.rb test/controllers/identity/second_factor_enrollments_controller_test.rb` : 22 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/second_factor_test.rb test/system/identity/sign_in_test.rb` : 14 runs, 0 échec, trois passes de suite.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense.

| `test/system/error_paths_test.rb` : lignes 17-18, 29-30 et 50-51, `click_on "Continuer"` après un code **bien formé** tapé sur `/join` : l'envoi automatique part avant le clic, qui touche un bouton périmé (`StaleElementReferenceError`, 1 fois sur 3 pour le test l. 12, 2 fois sur 3 pour le test l. 44). Retirer ces trois clics (garder celui de « k1 », l. 26, qui ne part pas seul) | Fichier hors du champ du Lot A (règle 4 du plan) | Lot Z |
| `autofocus` en mode page ne suit pas un re-rendu 422 morphé (voir décisions) | Brique gelée du Lot 0 | Lot 0 rouvert ou Lot Z |

### Vérifications (ciblées, règle de la vague)

- `COVERAGE=0 bin/rails test` sur `test/controllers/{homepage_controller,homepage_redirection}_test.rb`, `test/controllers/classroom/{join_codes,joins}_controller_test.rb`, `test/controllers/identity/{invitations,pending_teacher_registrations,pin_resets,sessions,teacher_registrations}_controller_test.rb` : 109 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/public_pages_test.rb test/system/identity/team_invitation_test.rb test/system/identity/teacher_signup_test.rb test/system/classroom/join_test.rb` : 22 runs, 139 assertions, 0 échec.
- `test/system/homepage_test.rb`, `error_paths_test.rb:130` (PIN oublié) : verts ; `error_paths_test.rb:12` et `:44` : instables, voir la dette.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense ; garde HITL (`test/guards/repository_rules_test.rb`) : verte.

| État d'erreur du frame (`ui_error_state` + « Réessayer » sur une réponse non 2xx, UDR-0054 §3.9) non posé sur le catalogue | Aucune brique du Lot 0 ne le porte (le contrôleur `search` ne gère pas l'échec, le frame reçoit la page d'erreur sans frame) ; aucun critère FU du lot | Lot Z (ou réouverture du Lot 0) |
| Infobulle par ligne sur `_exercise_progress` et `_assigned_exercise` | Hors champ `Fichiers` | Si le porteur la veut par ligne : Lot Z |

### Vérification (règle de la vague : tests du lot seulement)

- `COVERAGE=0 bin/rails test test/infrastructure/queries/catalog/course_catalog_query_test.rb test/controllers/catalog test/controllers/assessment test/controllers/classroom/student_homes_controller_test.rb test/controllers/classroom/student_classrooms_controller_test.rb test/i18n test/helpers` : 208 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/catalog_and_student_test.rb test/system/catalog/course_catalog_test.rb test/system/catalog/essential_page_test.rb test/system/classroom/student_home_test.rb test/system/classroom/student_classroom_test.rb test/system/assessment/` : 28 runs, 0 échec.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense.
