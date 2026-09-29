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

## Lot A — Entrée publique et invitation (2026-09-29)

Branche `feature/finitions-ux-lot-a`, depuis `feature/finitions-ux` (Lot 0 fusionné). Critères : FU-03, FU-13, FU-17, FU-19, FU-30, FU-31, FU-32, FU-33, FU-44, FU-53 (acceptation d'une invitation). Briques du Lot 0 utilisées telles quelles (`page_title`, `ui_back_link`, `ui_info_tip`, `ui_field(autofocus:)`, contrôleurs `autofocus` et `autosubmit`) ; aucune modifiée.

### Ce qui a été fait

- **Invitation** : `InvitationsController#accept` pose `session[:login_contact]` (numéro normalisé du compte créé) avant le 303 vers « Se connecter » ; aucune session d'authentification, rien dans l'URL ni dans le flash. « Nom » est la cible `field` de l'auto-focus. Titre « Créer mon compte · Lnclass » pour les deux variantes (équipe, direction), comme le dit l'amendement de l'UDR-0019 ; les deux anciennes clés `team.page_title` et `school_staff.page_title` sont retirées.
- **Se connecter** : `SessionsController#new` lit **et supprime** `session[:login_contact]` (avant la redirection d'une personne déjà connectée, pour qu'il ne survive pas) ; numéro valide → champ rendu groupé par deux, cible `field` sur le PIN ; sinon cible sur le numéro. Numéro `autocomplete="username"` (UDR-0054 §3.8). Infobulle du PIN.
- **Pages publiques** : le logo (les deux, colonne large et en-tête mobile) est un lien « Lnclass, accueil » vers `root_path`, `alt=""` sur l'image (le lien porte le nom). « PIN oublié » gagne un logo (il n'en avait pas) et le lien de retour « Se connecter » remplace le lien texte (la clé `back` est gardée, sa valeur devient « Se connecter » : `test/system/error_paths_test.rb` la lit).
- **`/join`** : `autosubmit` (motif de l'UDR-0054 §3.6), aide « 3 lettres puis 2 chiffres. La classe s'ouvre dès le code complet. », région `status` ; « Continuer » reste.
- **Inscription enseignant** : infobulle « Code d'établissement » ; focus sur le champ fautif après un 422.
- **Titres** : « Connexion », « PIN oublié », « Inscription enseignant », « Rejoindre une classe », « Rejoindre ma classe », « Accès interdit », « Page introuvable », « Accueil » (landing), par `page_title`, sans suffixe dans les locales.

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | `<main data-action="turbo:morph@document->autofocus#focus">` sur les six pages publiques à formulaire | Le re-rendu 422 est un **morphing** (`turbo_refreshes_with method: :morph`) : `<body>` n'est pas reconnecté, `autofocus#connect` ne repasse pas, le focus reste sur le bouton (FU-17 et FU-33 rouges pour cette raison). L'action appelle l'API gelée (`autofocus#focus`) sans toucher au contrôleur | Non — **à remonter** : le contrat du Lot 0 (« re-rendu 422 compris ») ne tient pas en page ; le contrôleur devrait écouter `turbo:morph` lui-même, et ces attributs deviendraient superflus (inoffensifs) |
| 2026-09-29 | Infobulles (PIN, code d'établissement) **sous** le champ, pas dans le libellé | `ui_field` rend le libellé dans un `<label>` et n'a pas d'emplacement après lui ; un `<details>` dans un `<label>` est du contenu interactif interdit | Non |
| 2026-09-29 | Landing : titre « Accueil · Lnclass » (au lieu du slogan) | UDR-0054 §3.1 : un seul segment, libellé court de l'écran | Non |

### Ce qui a dérapé

- Base de test : `db:prepare` sur une base neuve a chargé les seeds (181 classes, niveaux « 6ème »…) ; les tests système qui créent un niveau « 6ème » tombaient en `UniqueViolation`. `bin/rails db:test:prepare` a rendu une base vide.

### Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `test/system/error_paths_test.rb` : lignes 17-18, 29-30 et 50-51, `click_on "Continuer"` après un code **bien formé** tapé sur `/join` : l'envoi automatique part avant le clic, qui touche un bouton périmé (`StaleElementReferenceError`, 1 fois sur 3 pour le test l. 12, 2 fois sur 3 pour le test l. 44). Retirer ces trois clics (garder celui de « k1 », l. 26, qui ne part pas seul) | Fichier hors du champ du Lot A (règle 4 du plan) | Lot Z |
| `autofocus` en mode page ne suit pas un re-rendu 422 morphé (voir décisions) | Brique gelée du Lot 0 | Lot 0 rouvert ou Lot Z |

### Vérifications (ciblées, règle de la vague)

- `COVERAGE=0 bin/rails test` sur `test/controllers/{homepage_controller,homepage_redirection}_test.rb`, `test/controllers/classroom/{join_codes,joins}_controller_test.rb`, `test/controllers/identity/{invitations,pending_teacher_registrations,pin_resets,sessions,teacher_registrations}_controller_test.rb` : 109 runs, 0 échec.
- `COVERAGE=0 bin/rails test test/system/finitions/public_pages_test.rb test/system/identity/team_invitation_test.rb test/system/identity/teacher_signup_test.rb test/system/classroom/join_test.rb` : 22 runs, 139 assertions, 0 échec.
- `test/system/homepage_test.rb`, `error_paths_test.rb:130` (PIN oublié) : verts ; `error_paths_test.rb:12` et `:44` : instables, voir la dette.
- `bin/rubocop` sur les fichiers Ruby du lot : aucune offense ; garde HITL (`test/guards/repository_rules_test.rb`) : verte.
