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
