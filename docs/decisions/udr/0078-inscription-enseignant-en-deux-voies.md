# UDR-0078 : Inscription enseignant en deux voies — page réordonnée, nom complet corrigeable, numéro et code secret vérifiés en direct, liens d'invitation sans code

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-07)* |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/inscription-enseignant`](../../chantiers/inscription-enseignant/prd.md) — critères IE-01 à IE-19 |
| **ADR lié** | [ADR-0082](../adr/0082-inscription-enseignant-en-deux-voies.md) · [ADR-0037](../adr/0037-nom-et-prenoms-en-deux-champs.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0054](0054-finitions-d-interface.md) · remplace [UDR-0044](0044-inscription-enseignant-par-code-d-etablissement.md) côté enseignant (le bloc du code sur la fiche de l'équipe reste, amendé §3.7) ; amende [UDR-0024](0024-inscription-enseignant.md), [UDR-0050](0050-inviter-un-collegue-et-croissance.md), [UDR-0056](0056-gestes-de-la-direction.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant arrive sur `/teacher-signup` et rencontre aussitôt un champ « Code d'établissement » qu'il n'a pas. Il cherche alors le lien « Je n'ai pas de code », qui ouvre une autre page avec la DRENA ou le code national. La page commence par l'identité et finit par l'établissement, et elle demande le nom et les prénoms dans deux champs. Sur téléphone, c'est long, et l'enseignant ne sait pas quelle entrée prendre (memo, Q1 et Q2).

## 2. Décision

1. **Une seule page**, dans l'ordre du parcours (Q15, Q16), en trois rubriques : **Établissement** (DRENA, établissement, matière), **Vous** (nom complet, genre, numéro), **Code secret** (code, confirmation). Pas d'étapes : il n'y a pas d'état intermédiaire à garder, et la page marche sans JavaScript.
2. **Par un lien d'invitation** (`/i/<jeton>`), la même page s'ouvre avec l'établissement **déjà affiché** dans le bandeau existant (`_school_preview`), et « Ce n'est pas votre établissement ? » ramène à la page standard. La DRENA et la liste n'apparaissent pas.
3. **Nom et prénoms en deux champs** (amendement du 2026-10-07 : le nom complet avec aperçu et « Corriger » de la première version est retiré, memo Q24).
4. **Le numéro et la confirmation du code secret sont vérifiés en direct** (Q16, Q18). Le serveur reste la garantie : sans JavaScript, il nettoie le numéro et refuse des codes différents.
5. Erreur : la page est re-rendue en 422 par Turbo, sans rechargement (UDR-0024 §2.5). Succès : la page change, l'enseignant arrive sur la déclaration des classes avec « Bienvenue ! ». Aucun `*.turbo_stream.erb`.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Page `identity/teacher_registrations/new`

**Structure**

- La structure en deux colonnes, les deux `h1` (UDR-0054) et la carte `ui_card(padding: :lg)` ne changent pas.
- Titre de la carte (`h2`) : « Créer un compte enseignant ».
- Sous-titre de la carte : « Trois rubriques, une minute. ».
- Les clés `pending_title`, `pending_subtitle` et `invalid_code.*`, et la carte `#invalid-school-code`, sont **supprimées**.
- `@rate_limited` garde son `ui_error_state`.
- **Lien invalide** (`@invite_invalid`) : en tête du formulaire, avant tout `fieldset`, ce bloc :

```erb
<div id="invite-link-invalid" role="alert" class="flex items-start gap-2 rounded-ln bg-warning-soft px-4 py-3 text-sm font-medium text-ink">
  <%= ui_icon "exclamation-triangle", variant: :mini, size: :sm, class: "mt-0.5 shrink-0 text-warning" %>
  <p>Ce lien n'est plus valable. Choisissez votre établissement.</p>
</div>
```

  Le texte passe par `t(".invite_invalid")`.

### 3.2 Formulaire `identity/teacher_registrations/_form`

**Structure**

- Un seul `form_with model: @form, scope: :teacher_registration, url: teacher_registrations_path, id: "teacher-registration-form"`.
- `data-controller="school--drena-schools identity--phone-digits identity--pin-match"` ; la valeur `school--drena-schools-url-value` reste `drena_schools_path("__drena__")`.
- Avant le formulaire principal, toujours : `<form id="teacher-signup-drena" action="<%= new_teacher_registration_path %>" method="get"></form>` (repli sans JavaScript de l'UDR-0024 §2.4).
- Le bloc `role="alert"` des erreurs `base` reste en tête du formulaire.
- Champ caché `invite_token`, seulement quand l'établissement vient d'un lien valide.
- Trois `<fieldset class="space-y-4">`, dans cet ordre. Chaque `<legend>` garde la classe actuelle : `mb-3 text-xs font-semibold tracking-wider text-mute uppercase`.

| # | Légende (`t`) | Contenu, dans l'ordre |
|---|---|---|
| 1 | « Établissement » (`.school`) | **Voie standard** : sélecteur DRENA, `<noscript>` « Afficher les établissements », frame `schools`, puis matière. **Voie lien** : bandeau `_school_preview`, lien « Ce n'est pas votre établissement ? », puis matière. |
| 2 | « Vous » (`.you`) | Nom, Prénom(s), genre (radios actuelles, inchangées), numéro |
| 3 | « Code secret » (`.security`) | « Code secret » (aide « 4 chiffres, que vous seul connaissez. »), « Confirmation du code secret », statut de concordance |

- Puis `ui_button t(".submit")` (« Créer mon compte »), `brand`, `lg`, `full: true`.

**Voie standard, rubrique Établissement** : on reprend `identity/pending_teacher_registrations/_school_fields` **sans** le code national ni le séparateur « ou ». Le partial est déplacé vers `identity/teacher_registrations/_school_fields`.

- DRENA : `form.select :drena_public_id, drena_options, { prompt: t(".drena_prompt") }`, avec `form: "teacher-signup-drena"` et `data-action="change->school--drena-schools#load"`. Le libellé reste « DRENA ».
- `<noscript>` : le bouton secondaire « Afficher les établissements », `form: "teacher-signup-drena"`.
- `render template: "school/drena_schools/index", locals: { schools:, drena_public_id:, scope: :teacher_registration }`.
- Matière : `ui_field form, :material_slug, as: :select`, sans changement.

**Voie lien, rubrique Établissement** :

- `render "identity/teacher_registrations/school_preview", preview: @preview`. Le libellé « Votre établissement » est inchangé.
- `link_to t(".other_school"), new_teacher_registration_path, id: "other-school"`, avec la classe actuelle de `#other-school-code`. Texte : « Ce n'est pas votre établissement ? ».
- Puis la matière.

### 3.3 Nom et prénoms (amendement du 2026-10-07, memo Q24)

> La version d'origine de cette section prévoyait un « Nom complet » avec aperçu et `<details>` « Corriger ». Elle est retirée : retour à deux champs.

- Rubrique « Vous », dans l'ordre : `ui_field form, :last_name, required: true, maxlength: 50, autocomplete: "family-name", placeholder: t(".last_name_placeholder")` puis `ui_field form, :first_name, required: true, maxlength: 80, autocomplete: "given-name", placeholder: t(".first_name_placeholder")`, puis le genre, puis le numéro.
- Libellés « Nom » et « Prénom(s) » (inchangés depuis l'ADR-0037). Placeholders : « Ex. : KOUASSI » et « Ex. : Aya Marie ».
- Aucun aperçu, aucun `<details>`, aucun contrôleur Stimulus pour le nom ; erreurs sous chaque champ (messages existants).

### 3.4 Numéro

```erb
<%= ui_field form, :contact, as: :tel, required: true, value: @form.raw_contact, maxlength: 20, inputmode: "numeric",
             autocomplete: "tel-national", placeholder: t(".contact_placeholder"), hint: t(".contact_hint"),
             data: { identity__phone_digits_target: "input", action: "input->identity--phone-digits#clean" } %>
```

- `contact_hint` : « 10 chiffres, par ex. 0701020304. ».
- `maxlength: 20` laisse coller « +225 07 01 02 03 04 » **sans** JavaScript : c'est le serveur qui le nettoie (`Entities::Identity::Contact.normalize`).
- Pas d'attribut `pattern` : il bloquerait l'envoi sans JavaScript.

**Stimulus `identity/phone_digits_controller.js`** (nouveau), à chaque `input` (frappe et collage) :

1. Retirer tout ce qui n'est pas un chiffre.
2. Si le résultat commence par `00225`, retirer ces 5 chiffres ; sinon, s'il commence par `225`, retirer ces 3 chiffres. Un numéro ivoirien commence par `0`, donc un `225` en tête est toujours l'indicatif.
3. Garder les 10 premiers chiffres.
4. N'écrire `input.value` que si la valeur change, puis placer le curseur en fin de champ.
5. Au `connect`, appliquer `clean()` une fois : une valeur re-rendue en 422 est nettoyée.

### 3.5 Concordance du code secret

- Les deux `ui_field … as: :password, reveal: true` actuels ne changent pas. On ajoute `data-identity--pin-match-target="pin"` et `"confirmation"`, et `data-action="input->identity--pin-match#check"` sur les deux.
- Juste sous le champ de confirmation, ce paragraphe :

```erb
<p id="pin_match_status" data-identity--pin-match-target="status" aria-live="polite" hidden
   class="flex items-center gap-1.5 text-sm font-medium"></p>
```

**Stimulus `identity/pin_match_controller.js`** (nouveau) :

- `check()` :
  - Tant que la confirmation a moins de 4 chiffres : `status.hidden = true`, aucune classe ajoutée au champ.
  - Si elle a 4 chiffres et qu'elle est égale au code : icône `check-circle` (mini), texte « Les codes concordent. », classe `text-success` sur le statut, classe `border-success` sur le champ de confirmation.
  - Sinon : icône `x-circle` (mini), texte « Les codes ne concordent pas. », classe `text-error` sur le statut, `border-error` et `aria-invalid="true"` sur le champ de confirmation.
  - Quand la vérification repasse au vert, retirer `aria-invalid`.
- L'icône vient d'un `<template>` rendu par `ui_icon` dans la vue : `data-identity--pin-match-target="okIcon"` et `"koIcon"`. Les deux textes viennent de `data-identity--pin-match-ok-value` et `-ko-value`, avec les clés `t(".pin_match.ok")` et `t(".pin_match.ko")`.
- Ajouter `pin_match_status` à `aria-describedby` de la confirmation au `connect`, sans retirer les identifiants déjà présents.
- Changer le **code** relance aussi `check()`.
- L'erreur serveur actuelle (422, message existant sous la confirmation) ne change pas.

### 3.6 Lien d'invitation `GET /i/:token`

- Jeton valide :
  - rend `new`, avec `@preview` (nom de l'établissement et nom de sa DRENA, rien d'autre) et `@form.invite_token` ;
  - DRENA et frame absents ;
  - le titre de la carte est le même.
- Jeton invalide : rend `new` en **200**, avec `@invite_invalid = true`, sur la voie standard. Jamais de 404, jamais la cause.
- Personne connectée : renvoyée vers son accueil (règle actuelle).
- Limite : 10 requêtes par minute et par adresse ; au-delà, 429 avec `ui_error_state` (règle de l'ancien `/e/`).

### 3.7 Blocs de lien

| Vue | Changement |
|---|---|
| `identity/referrals/_invite`, `identity/referrals/_sidebar_card` | `link = teacher_invite_link_url(invite.referral_token)` (`/i/<jeton>`). Aucun autre changement de texte ni de geste. |
| `school_admin/schools/_link` | `link = teacher_invite_link_url(school.direction_invite_token)`. **Retirer** le paragraphe du code (`#school_code_value`) et toute la modale « Changer le lien » (`change-school-link`, son formulaire). « Copier le lien » et « Partager sur WhatsApp » restent. `school_admin/school_links/update.turbo_stream.erb` est supprimé. |
| `classroom/teacher_homes/_course_levels`, bulle « Inviter » (`#course_level_invite`) | `href: whatsapp_share_url(message)` avec `message = t("identity.referrals.invite.message", school:, link: teacher_invite_link_url(invite.referral_token))`, `link_html: { target: "_blank", rel: "noopener", data: { action: "identity--share#record", "identity--share-channel-param": "whatsapp" } }`. Le `<li>` porte `data-controller="identity--share"` et les valeurs `url` (`teacher_referral_shares_path`), `link` et `text`, comme `#referral_share_actions`. Le libellé reste « Inviter » ; `sr_suffix` : « sur WhatsApp ». La page « Inviter un collègue » ne change pas. |
| `teams/schools/_header`, bloc `#school_code` | Le bloc garde le code, « Copier le code » et « Régénérer le code », mais l'aide devient « Pour l'inscription de la direction. » (`school_code_hint`). « Copier le lien » et `#school_code_link` montrent `teacher_invite_link_url(school.team_invite_token)`, sous un libellé « Lien d'invitation des enseignants » (`invite_link`). |

`ui_subject_bubble` reçoit une option `link_html:` (attributs fusionnés sur le `<a>` : `target`, `rel`, `data`), vide par défaut ; les bulles existantes ne changent pas.

### 3.8 Liste « Enseignants » de la fiche équipe (`teams/schools/show`)

Sous le nom de chaque enseignant, ajouter une ligne `text-xs text-mute` : « Inscription : <voie> » (`t("teams.schools.show.joined_via.#{via}")`).

| Clé | Texte |
|---|---|
| `standard` | « inscription standard » |
| `colleague` | « lien d'un collègue (%{name}) », avec `name` = « NOM Prénoms » du parrain, ou « lien d'un collègue » si le parrain est anonymisé |
| `direction` | « lien de la direction » |
| `team` | « lien de l'équipe » |
| `code` | « code d'établissement » |

La formule « Inscription : … » ne s'accorde pas : il n'y a pas de « arrivé(e) » (UDR-0007).

### 3.8 bis Tableau des établissements de l'équipe (`teams/schools/index`, `_school_row`, `_filters`) — ajout du 2026-10-07 (memo Q21)

- Retirer la colonne `school_code` du `<thead>` (et son `ui_info_tip`) et la cellule correspondante de `_school_row` ; l'ordre des colonnes restantes ne change pas.
- Recherche : libellé « Nom ou sigle » (`teams.schools.filters.search`), exemple « Ex. : Lycée Classique, LCA » (`search_placeholder`). La recherche ne porte plus sur le code national.

### 3.8 ter Liste des élèves d'une classe : numéro masqué (phase 5, memo Q23)

- `classroom/classrooms/_roster` : la cellule du numéro affiche la valeur masquée rendue par la requête (« 07 •• •• •• 04 »), telle quelle, en `font-mono text-mute`, sans lien `tel:`, sans bouton de copie, sans reformatage par paires. `title` « Numéro masqué pour protéger les élèves » (`t(".contact_masked")`) ; la valeur masquée en `aria-hidden`, la même mention en `sr-only` (un `aria-label` est interdit sur un `<p>`). Aucune autre différence de rendu.

### 3.9 Écran d'attente (`identity/pending_accounts/show`, enseignant sans établissement)

- Le champ `school_code` est remplacé par la même rubrique « Établissement » que la voie standard, **sans** la matière : sélecteur DRENA, `<noscript>`, frame `schools`. Le formulaire `GET` de repli s'appelle `school-join-drena` et pointe vers `pending_account_path`.
- `render template: "school/drena_schools/index", locals: { …, scope: :school_join }`. Le frame reçoit un local `scope`, qui vaut `:teacher_registration` par défaut, et n'écrit plus le scope en dur.
- Bouton « Rejoindre cet établissement » (`brand`, `full`). L'erreur neutre « Cet établissement ne peut pas être rejoint. » s'affiche sous l'établissement (`school_public_id.inclusion`).
- Les clés `school_code_placeholder` et `school_code_hint` de l'écran sont supprimées.

**États obligatoires** (toutes les vues ci-dessus)

| État | Rendu |
|---|---|
| Vide | Sans DRENA : liste désactivée, aide « Choisissez d'abord votre DRENA. » ; DRENA sans établissement actif : « Aucun établissement actif dans cette DRENA. Vérifiez la DRENA choisie. » (UDR-0024, inchangé) ; statut du code secret masqué. |
| Chargement | Frame `schools` en `aria-busy` à 50 % d'opacité (UDR-0024, inchangé). |
| Erreur | 422 re-rendu, saisies gardées sauf les codes secrets ; chaque message sous son champ (`aria-invalid`, `aria-describedby`) ; erreurs `base` et 429 dans le bloc `role="alert"` ; lien invalide : `#invite-link-invalid`. |
| Succès | Session ouverte ; redirection vers `/teachers/classrooms` avec le toast « Bienvenue ! Sélectionnez vos classes pour commencer. » ; écran d'attente : accueil enseignant. |

**Accessibilité**

- Cibles tactiles ≥ 48 px (`min-h-tap`), y compris `summary` et « Ce n'est pas votre établissement ? ».
- `aria-live="polite"` sur le statut du code secret : ils sont annoncés sans voler le focus.
- Ordre de tabulation = ordre visuel : DRENA → établissement → matière → nom → prénoms → genre → numéro → code secret → confirmation → bouton.
- Codes secrets : règles actuelles de l'UDR-0024 (`type="password"`, `inputmode="numeric"`, `maxlength="4"`, `autocomplete="new-password"`, jamais renvoyés).
- Parcours prouvé à 390 px et sur ordinateur, avec et sans lien.

## 3.11 Vocabulaire « code secret » (amendement du 2026-10-07, memo Q25)

- Dans **toute** l'interface (connexion, profil, changement et réinitialisation, codes de récupération, inscriptions élève, enseignant et direction, invitations, aide), le secret à 4 chiffres s'appelle « code secret », jamais « PIN ». Formes : « votre code secret », « Code secret oublié ? », « Confirmation du code secret », « Nouveau code secret », « Les deux codes secrets ne sont pas identiques. », « Code secret ou numéro incorrect. ». Accords au masculin.
- Les libellés accessibles (`aria-label`, `title`, textes `sr-only`) suivent la même règle. Le code (classes, méthodes, routes, clés de traduction, colonnes) garde `pin`.

## 4. Conséquences

- L'**UDR-0044** (inscription par code d'établissement) est remplacée côté enseignant ; son bloc du code sur la fiche de l'équipe reste, pour la direction, avec le §3.7. Côté enseignant, plus aucun écran ne montre un code d'établissement.
- **UDR-0024** : les §2.2 à §2.4 (frame DRENA, formulaire `GET` sans JavaScript) s'appliquent de nouveau. L'amendement du 2026-09-28 ne vaut plus pour l'enseignant. Les rubriques passent de quatre à trois.
- **UDR-0050** et **UDR-0056** : le lien partagé est `/i/<jeton>`. « Changer le lien » disparaît de l'espace direction.
- Le nettoyage du numéro et la concordance du code secret sont **propres à l'inscription enseignant**. Les autres formulaires (élève, direction, invitation, changement de code) ne les reçoivent pas dans ce chantier. Ils pourront réutiliser les deux contrôleurs Stimulus, qui ne dépendent d'aucune clé propre à l'enseignant.
- Interdit désormais : afficher ou demander un code d'établissement dans un écran destiné à l'enseignant ; construire un lien d'inscription enseignant avec le code d'établissement.
