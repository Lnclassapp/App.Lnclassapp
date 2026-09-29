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

## Lot D1 — Équipe : établissements (2026-09-29)

Branche `feature/finitions-ux-lot-d1`, depuis `feature/finitions-ux` (Lot 0 fusionné). Critères : FU-01, FU-09, FU-25, FU-26 (fiche), FU-45, FU-46 ; FU-51 vérifié sur la liste.

### Ce qui a été fait

- **Liste** : `page_title` (« Établissements · Équipe · Lnclass ») ; `form#schools-filters` porte le contrôleur `search` (frappe → `search#queue`, quatre listes → `search#submit`, « Filtrer » en cible `button`, gardé sans JavaScript) ; frame `schools` estompé pendant l'envoi (`aria-busy:opacity-50`) ; infobulle du statut dans l'en-tête de la colonne « Statut » (une fois, pas par ligne).
- **Fiche** : titre = nom de l'établissement ; retour `ui_back_link "Établissements", href: back_href(schools_path, from: schools_path)` posé dans `show`, **hors** de `#school_header` (les streams modification, désactivation et régénération du code remplacent l'en-tête et gardent le retour) ; l'ancien `nav` « Fil d'Ariane » de `_header` disparaît ; copies du code et du lien `/e/<code>` passées à `ui_copy_button` (plus de `classroom--join-code-copy` ici, toasts `shared.clipboard.*`) ; infobulles du code d'établissement (texte UDR-0054 §3.4) et du statut.
- **Modales** : modifier l'établissement, ajouter une classe, inviter la direction, invitation créée : `page_title` passé à `ui_modal(document_title:)`. `content_for :title` retiré des vues du lot.
- **Invitation de la direction** : « Copier le lien » (`ui_copy_button`, nom accessible « Copier le lien d'invitation », toast « Lien copié. ») sous le lien affiché, dans la modale et la page de repli.

### Mesure du PRD §7

`GET /teams/schools?search=coc` avec `Turbo-Frame: schools`, base de démonstration (`db:prepare` de développement) + 3 000 établissements (6 types de noms × 20 villes, dont « Cocody »), 150 résultats, 50 lignes rendues ; session d'intégration connectée (équipe, second facteur), 3 appels d'échauffement puis **médiane de 20 appels**, durée `process_action.action_controller`. Machine à 4 cœurs partagée avec les autres lots.

| Code | Mode | Médiane | dont SQL | Charge |
|---|---|---|---|---|
| Avant (`feature/finitions-ux`) | développement | 130,0 ms | 24,7 ms | ~1,3 |
| Avant | proche production (classes chargées, gabarits en cache) | 121,7 ms · 128,4 ms | 24,9 ms · 25,7 ms | ~1,2 |
| Après (Lot D1) | développement | 124,1 ms · 130,1 ms | 24,8 ms · 24,6 ms | ~1,3 |
| Après | proche production | 123,4 ms · 133,9 ms | 25,5 ms · 25,7 ms | ~1,2 |
| Après, liste sans recherche (3 004) | proche production | 108,9 ms | 6,8 ms | ~1,2 |

- **Sous la cible de 150 ms** à charge normale, avant comme après : le lot ne change pas la requête. Premier essai sous forte charge (moyenne de charge 12, dix lots en parallèle) : 174 ms en développement ; non retenu, mais la marge est mince (~20 ms).
- La recherche coûte **~19 ms de SQL** (25 ms contre 7 ms sans filtre, `translate(lower(…)) LIKE` sur 3 000 lignes) ; le reste (~100 ms) est le **rendu** des 50 lignes (menu ⋮ et deux confirmations `<dialog>` par ligne). Un index trigramme ne gagnerait que la part SQL : pas de quoi arrêter le lot. Si la cible devait être tenue sous charge, le levier est le rendu de la ligne, pas un index (à voir avec `perf/cache-ecrans-lourds`).
- Requêtes par frappe : 0 sous 2 caractères, une par pause de 300 ms (test système FU-51).
- Scripts (hors dépôt) : `seed_schools.rb` (3 000 lignes marquées « (mesure) », `insert_all!`) et `measure.rb` (session d'intégration, abonnement à `process_action`).

### Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | Le retour de la fiche vit dans `show`, pas dans `_header` | Trois streams remplacent `#school_header` ; dans l'en-tête, `back_href` y aurait lu le `Referer` de la fiche et perdu les filtres | Non |
| 2026-09-29 | Infobulle du statut dans l'en-tête de colonne de la liste, pas sur chaque badge | Une aide par ligne répèterait 50 fois le même texte | Non |
| 2026-09-29 | `role` et `aria-label` du formulaire passés par `html:` | `form_with` ignore ces options au premier niveau : le `role="search"` existant n'était jamais rendu (relevé par le Lot G) | Non |
| 2026-09-29 | Modales : `page_title(t(".title"))`, pas de clé `page_title` dédiée | Le titre de l'onglet est celui de la modale ; une seconde clé répèterait le même texte | Non |

### Écarts

- **`Queries::Shared::TextSearch` non branché sur `SchoolsQuery`** : `app/infrastructure/queries/school/schools_query.rb` n'est pas dans le champ `Fichiers` du lot. La recherche des établissements garde ses `ACCENTED`/`PLAIN` (même comportement). Dette du Lot 0 reportée à un refactor ou au Lot Z.
- **État d'erreur dans le frame** (PRD §3, « Erreur serveur pendant une recherche ») : aucune brique du Lot 0 ne rend `ui_error_state` dans un frame sur une réponse non 2xx (il faudrait un écouteur `turbo:frame-missing` ou une page d'erreur qui porte le frame). Non fait ici (hors champ, brique gelée) : à trancher au Lot Z.
- `_school_row`, `schools/_form`, `school_classrooms/_form` : rien à changer (l'auto-focus passe déjà par `ui_field autofocus:`, les confirmations visent « Annuler » par `_modal`).

### Vérification (tests du lot seulement)

- `COVERAGE=0 bin/rails test test/controllers/teams/schools_controller_test.rb test/controllers/teams/staff_invitations_controller_test.rb test/controllers/teams/school_classrooms_controller_test.rb test/integration/i18n_configuration_test.rb`
- `COVERAGE=0 bin/rails test test/system/finitions/schools_search_test.rb test/system/teams/schools_test.rb test/system/teams/school_code_test.rb test/system/teams/staff_invitation_test.rb test/system/teams/school_classroom_creation_test.rb`
- `bin/rubocop` sur les fichiers Ruby du lot ; garde HITL (`test/guards/repository_rules_test.rb`).
