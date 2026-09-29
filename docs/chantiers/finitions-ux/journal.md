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
| État d'erreur du frame (`ui_error_state` + « Réessayer » sur une réponse non 2xx, UDR-0054 §3.9) non posé sur le catalogue | Aucune brique du Lot 0 ne le porte (le contrôleur `search` ne gère pas l'échec, le frame reçoit la page d'erreur sans frame) ; aucun critère FU du lot | Lot Z (ou réouverture du Lot 0) |
| Infobulle par ligne sur `_exercise_progress` et `_assigned_exercise` | Hors champ `Fichiers` | Si le porteur la veut par ligne : Lot Z |

### Vérification (règle de la vague : tests du lot seulement)

- `COVERAGE=0 bin/rails test test/infrastructure/queries/catalog/course_catalog_query_test.rb test/controllers/catalog test/controllers/assessment test/controllers/classroom/student_homes_controller_test.rb test/controllers/classroom/student_classrooms_controller_test.rb test/i18n test/helpers` : 208 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/catalog_and_student_test.rb test/system/catalog/course_catalog_test.rb test/system/catalog/essential_page_test.rb test/system/classroom/student_home_test.rb test/system/classroom/student_classroom_test.rb test/system/assessment/` : 28 runs, 0 échec.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense.
