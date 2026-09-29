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
