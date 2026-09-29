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

## Lot B — Second facteur et codes de secours (2026-09-29)

Branche `feature/finitions-ux-lot-b`, depuis `feature/finitions-ux` (Lot 0 fusionné). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_field(autofocus:)`, `ui_info_tip`, `ui_copy_button`, contrôleurs `autosubmit` et `download`) ; `SecretResponse` réutilisé sans rien y toucher (le contrôleur d'activation n'est pas modifié, aucun en-tête posé).

Critères couverts : FU-12, FU-34, FU-35, FU-36, FU-37, FU-38, FU-39, FU-40, FU-41, FU-42, FU-43, FU-53 (vérification, codes de secours) — `test/system/finitions/second_factor_test.rb` (9 cas), `test/controllers/identity/second_factors_controller_test.rb`, `test/controllers/identity/second_factor_enrollments_controller_test.rb`, `test/system/identity/sign_in_test.rb`.

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
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
