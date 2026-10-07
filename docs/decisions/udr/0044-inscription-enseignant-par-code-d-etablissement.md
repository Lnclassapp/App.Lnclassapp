# UDR-0044 : Inscription enseignant par code d'établissement, et code sur la fiche de l'établissement

> ⚠️ **Remplacée côté enseignant par [UDR-0078](0078-inscription-enseignant-en-deux-voies.md)** (2026-10-07, chantier `inscription-enseignant`) : plus de champ ni de lien `/e/<code>` pour l'enseignant. Le bloc du code sur la fiche de l'équipe reste, pour l'inscription de la direction, amendé par l'UDR-0078 §3.7.

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/code-etablissement`](../../chantiers/code-etablissement/prd.md) — critères CE-01 à CE-08 |
| **ADR lié** | [ADR-0057](../adr/0057-code-d-etablissement.md) · [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) · [ADR-0050](../adr/0050-authentification-et-session.md) · amende [UDR-0024](0024-inscription-enseignant.md) et [UDR-0036](0036-gestion-des-etablissements.md) · [UDR-0009](0009-rejoindre-une-classe.md) (patron du code) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) (menu ⋮) · [UDR-0005](0005-design-system-fondateur.md) |
| **Remplacé par** | [UDR-0078](0078-inscription-enseignant-en-deux-voies.md) *(côté enseignant)* |

---

## 1. Contexte

L'enseignant qui s'inscrit cherche son établissement : une DRENA, puis une liste de dizaines d'établissements, rechargée dans un frame (UDR-0024). Il peut choisir n'importe lequel. L'élève, lui, tape le code de sa classe ou ouvre un lien, et ne choisit rien (UDR-0009). L'équipe, de son côté, n'a aucun moyen de dire à un établissement « voici comment vos enseignants s'inscrivent ».

## 2. Décision

1. **Le code remplace la recherche.** Dans la rubrique « Établissement et matière », le sélecteur de DRENA et la liste des établissements disparaissent ; un seul champ, « Code d'établissement », puis la matière. Le formulaire reste le même formulaire, dans la même page (UDR-0024 §1, §5, §6 inchangés).
2. **Le lien `/e/<code>` ouvre le même formulaire, déjà résolu** : un bandeau « Votre établissement » (nom, DRENA) remplace le champ, le code voyage en champ caché. Comme l'aperçu d'une classe, il ne montre que deux noms, jamais un identifiant ni un effectif. Un lien discret ramène au champ : l'enseignant n'est jamais coincé sur un mauvais lien.
3. **Code refusé : un seul message**, que le code soit inconnu, remplacé, ou celui d'un établissement inactif ou en brouillon. Sur `/e/<code>`, la même neutralité : 404, « Code d'établissement invalide. », bouton « Saisir le code ».
4. **Après une erreur de saisie**, si le code était bon, le bandeau remplace le champ : l'enseignant voit qu'il a le bon établissement et n'a rien à retaper.
5. **Sur la fiche de l'établissement**, l'équipe lit le code dans l'en-tête, le copie, copie le lien, et le **régénère depuis le menu ⋮** (UDR-0042 : c'est une modification de l'objet), avec une confirmation qui dit la conséquence. Le code n'est pas une action de page : il vit dans l'en-tête, comme celui d'une classe sur sa page (UDR-0027).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### Inscription — `identity/teacher_registrations`

**Structure**
- `new.html.erb` : inchangé (UDR-0024), sauf la colonne droite, qui rend dans cet ordre le premier état applicable : `@rate_limited` → `ui_error_state` « Trop de tentatives » (`errors.codes.rate_limited`) ; `@invalid_code` → carte `#invalid-school-code` (icône `exclamation-triangle` dans `bg-error-soft text-error`, `h2` « Code d'établissement invalide. », aide, `ui_button` « Saisir le code » `brand` pleine largeur vers `/teacher-signup`, icône `arrow-path`) ; sinon la carte du formulaire.
- `_form.html.erb` : `form#teacher-registration-form` (scope `teacher_registration`, `POST /teacher-signup`), **sans** `form#teacher-signup-drena`, sans `data-controller`, sans frame `schools`. Rubrique « Établissement et matière » :
  - avec `@preview` : partiel `_school_preview` (`#school-preview`, icône `building-library`, « Votre établissement » en petites capitales, nom en `font-display font-extrabold`, « DRENA : <nom> » en `text-sm text-mute`), puis `hidden_field :school_code` (valeur affichée `K7M-4QZ`), puis le lien `#other-school-code` « Ce n'est pas votre établissement ? Saisir un autre code » vers `/teacher-signup` ;
  - sinon : `ui_field :school_code`, requis, `maxlength` 12, `autocomplete="off"`, `autocapitalize="characters"`, `spellcheck=false`, `placeholder` « K7M-4QZ », aide « 6 caractères, transmis par votre établissement. », classes `font-display tracking-widest uppercase` ; la valeur re-rendue est la saisie brute ;
  - puis `ui_field :material_slug` (inchangé).
- Aucun champ `drena_public_id` ni `school_public_id`, aucun attribut `role`.

**Tokens**
- `ui_*` et tokens `@theme` seulement. Bandeau : `rounded-ln border border-brand/30 bg-brand-soft px-4 py-3`, pastille `bg-white text-brand-strong` (celui de l'aperçu d'une classe, UDR-0009). Lien : `text-brand-strong underline-offset-4 hover:underline`.

**Comportement**
- `GET /teacher-signup` : formulaire vide ; personne connectée → son accueil.
- `GET /e/:code` (`school_code_signup_path`) : personne connectée → son accueil ; code normalisé, cherché par `Queries::School::SchoolCodePreviewQuery` (établissement **actif** seulement) ; trouvé → 200, formulaire avec bandeau ; sinon → 404, carte `#invalid-school-code`. **10 requêtes par minute et par adresse**, compteur `school_code` distinct de celui de l'envoi ; au-delà, 429 et `ui_error_state`, sans aperçu.
- `POST /teacher-signup` : 5 par minute (inchangé) ; échec → 422 re-rendu par Turbo, saisies gardées sauf les PIN, bandeau si le code n'a pas d'erreur et désigne un établissement actif ; succès → `/teachers/classrooms` avec le toast de bienvenue (inchangé).

**États obligatoires**
- Vide : le champ du code et son aide.
- Chargement : sans objet (rendu serveur ; Turbo pose `aria-busy` sur le formulaire).
- Erreur : sous le champ du code — vide « Saisissez le code de votre établissement. » ; format « Code d'établissement invalide. Il compte 6 caractères, par exemple K7M-4QZ. » ; format de classe « Ce code est un code de classe. Demandez le code d'établissement à votre établissement. » ; refusé « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » ; lien invalide : carte 404 ; débit : 429.
- Succès : toast sur la page d'arrivée (inchangé).

**Accessibilité**
- Le champ du code a son `label` visible ; erreur reliée par `aria-describedby`, `aria-invalid` (via `ui_field`).
- Le bandeau n'est pas interactif ; le lien « Saisir un autre code » a une cible `min-h-tap`.
- Parcours prouvé à 390 px.

### Fiche de l'établissement — `teams/schools/_header`

**Structure**
- Dans la `ui_card` de `div#school_header`, après la rangée existante, un bloc `div#school_code` séparé par `mt-5 border-t border-line pt-5` : `p#school_code_label` « Code d'établissement » (petites capitales `text-xs font-semibold tracking-wider text-mute uppercase`), `span#school_code_value` (`aria-labelledby="school_code_label"`, `font-mono text-2xl font-bold tracking-widest text-ink`) qui affiche `K7M-4QZ`, puis deux `ui_button` `secondary` `sm` : « Copier le code » (`clipboard-document`) et « Copier le lien » (`link`) ; dessous, l'aide « À transmettre aux enseignants de l'établissement : ils saisissent ce code à l'inscription, ou ouvrent le lien » suivie du lien `a#school_code_link` (URL complète de `/e/<code>`, `break-all`). Si l'établissement n'est pas actif : une seconde aide `text-warning`, « Tant que l'établissement n'est pas actif, ce code ne permet pas de s'inscrire. ».
- Copie : chaque bouton est enveloppé de `data-controller="classroom--join-code-copy"` avec `…-code-value` = le code affiché (`K7M-4QZ`) ou l'URL complète ; ses deux `<template>` portent les toasts « Code copié » / « Lien copié » et « La copie a échoué… ».
- Menu ⋮ `#school-header-actions` : « Modifier », puis **« Régénérer le code »** (`arrow-path`, `dialog: "regenerate-school-code"`), puis « Désactiver » si actif (UDR-0042 : Modifier d'abord, destruction en dernier).
- `ui_modal` `regenerate-school-code` (`size: :sm`, sans `trigger:`), titre « Régénérer le code de « <nom> » ? », texte « L'ancien code <K7M-4QZ> cessera aussitôt de fonctionner : transmettez le nouveau aux enseignants qui ne sont pas encore inscrits. Les enseignants déjà inscrits ne sont pas touchés. », pied « Annuler » (`secondary`, `modal#close`) et « Régénérer le code » (`type: :submit`, `form: "regenerate-school-code-form"`) ; `form#regenerate-school-code-form` en `PATCH school_code_path(public_id)`.

**Comportement**
- `PATCH /teams/schools/:school_public_id/code` → `Teams::SchoolCodesController#update` (`Teams::BaseController`) : succès → Turbo Stream : toast `success` « Nouveau code d'établissement : <K7M-4QZ>. », `replace "school_header"` (ce qui referme la confirmation) ; repli HTML : redirection vers la fiche avec `notice`. Refus → `render_result` : 403 / 404 en toast, `:conflict` en toast d'erreur.
- La ligne de la liste n'affiche pas le code (hors périmètre).

**États obligatoires**
- Vide : sans objet (tout établissement a un code, ADR-0057).
- Chargement : sans objet.
- Erreur : toast `error` (écriture refusée, droit manquant) ; copie impossible → toast `warning`.
- Succès : toast, en-tête remplacé avec le nouveau code.

**Accessibilité**
- Chaque bouton de copie porte un `aria-label` qui nomme ce qu'il copie (« Copier le code K7M-4QZ », « Copier le lien d'inscription ») ; cibles ≥ 48 px dans la rangée (`min-h-tap` des `ui_button`).
- Le code est lu par son libellé (`aria-labelledby`).
- À 390 px, le bloc passe sous l'en-tête sans défilement horizontal ; le lien se coupe (`break-all`).

## 4. Conséquences

- Aucun écran ne propose plus de choisir un établissement dans une liste pour s'y rattacher. `school/drena_schools/index` et `school--drena-schools` n'ont plus de consommateur dans l'inscription ; l'adresse reste une API (UDR-0024 §4).
- Tout futur code partagé (par exemple pour la direction, V2) suit ce patron : saisie normalisée, lien court `/<lettre>/<code>` limité en débit, un seul message pour tout refus, lecture et régénération sur la fiche de l'objet, régénération dans le menu ⋮ avec confirmation.
- La fiche de l'établissement a désormais trois entrées de menu ; « Régénérer le code » s'intercale entre « Modifier » et « Désactiver ».

## Amendement du 2026-09-28 — jeton de parrainage et inscription sans code (UDR-0050)

*Chantier `docs/chantiers/croissance-parrainage`.* `/e/<code>?ref=<jeton>` porte le jeton du parrain dans un champ caché `teacher_registration[ref]` (mal formé : absent). Sous le champ du code, le lien `#no-school-code` « Mon établissement n'a pas encore de code Lnclass » mène à l'inscription sans code. Contrat : UDR-0050 §3.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Copie** : les boutons « Copier le code » et « Copier le lien » de la fiche passent de `classroom--join-code-copy` à `ui_copy_button` (contrôleur `clipboard`) ; libellés, valeurs et toasts inchangés.
- **Inscription** : « Code d'établissement » est suivi d'une infobulle (où le trouver) ; après un 422, focus sur le premier champ en erreur ; le logo mène à l'accueil public.
