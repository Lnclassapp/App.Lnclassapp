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

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
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
