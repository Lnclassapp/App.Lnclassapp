# UDR-0070 : Inscription de la direction, bloc « Direction », retrait et restauration d'un compte direction

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-04 |
| **Chantier** | `docs/chantiers/inscription-direction` |
| **ADR lié** | [ADR-0077](../adr/0077-inscription-de-la-direction-par-le-code-et-retrait.md) |
| **Remplacé par** | — |

> Amende [UDR-0064](0064-page-d-accueil-un-ecran-une-decision.md) et [UDR-0059](0059-homepage-telephone-et-tablette.md) (page d'accueil : un lien et une section de plus), [UDR-0052](0052-espace-direction-simple.md) et [UDR-0056](0056-gestes-de-la-direction.md) (bandeau d'arrivée, bloc « Direction »), et [UDR-0018](0018-accueil-equipe.md) (bloc « Directions retirées »).

---

## 1. Contexte

Une direction qui découvre Lnclass par ses enseignants ne trouve rien pour elle : la page d'accueil ne parle qu'aux élèves et aux enseignants, et le seul chemin est une invitation de l'équipe. Une fois inscrite seule (ADR-0077), elle partage l'établissement avec d'autres comptes direction qu'elle doit pouvoir voir, et retirer s'ils sont illégitimes. L'équipe doit savoir qu'un compte a été retiré, et pouvoir l'annuler.

## 2. Décision

- **Une page d'inscription dédiée**, sur le modèle de l'inscription enseignant (deux colonnes, mêmes champs), sans matière, avec le code d'établissement. Après inscription, la session s'ouvre et la direction arrive sur « Travail des élèves ».
- **Sur la page d'accueil**, trois entrées vers cette page, choisies par le porteur (Q7) : un lien discret sous les boutons du haut de page, une **section « Établissements »** sur le modèle de la section « Enseignants », et un lien dans le pied de page vers cette section.
- **Un bloc « Direction »** sur la page Établissement de la direction et sur la fiche de l'équipe : qui est là, comment chacun est arrivé, les places restantes ; « Retirer » dans un menu ⋮ (UDR-0042) et une confirmation en `<dialog>`.
- **Un bandeau d'arrivée** sur « Travail des élèves », 7 jours. Un bandeau plutôt qu'une notification : Lnclass n'a pas de centre de notifications.
- **« Directions retirées »** pour l'équipe : un bloc sur la fiche, avec « Restaurer » ; un rappel sur l'accueil de l'équipe.

## 3. Règles d'implémentation

### 3.0 Routes et cibles

| Geste | Route | Nom | Réponse |
|---|---|---|---|
| Page d'inscription | `GET /school-staff-signup` | `new_school_staff_registration_path` | 200 ; 429 au-delà du débit |
| Inscription | `POST /school-staff-signup` | `school_staff_registrations_path` | 303 vers `school_admin_classrooms_path` ; 422 sinon |
| Retirer (direction) | `DELETE /school-admin/school/staff/:public_id` | `school_admin_staff_member_path` | Turbo Stream ; 403, 404 |
| Retirer (équipe) | `DELETE /teams/schools/:school_public_id/staff/:public_id` | `school_staff_member_path` | Turbo Stream ; 403, 404 |
| Restaurer (équipe) | `POST /teams/schools/:school_public_id/staff/:public_id/restoration` | `school_staff_member_restoration_path` | Turbo Stream ; 409 plafond |

`:public_id` est le `public_id` du **compte** de la direction. Débit de l'inscription : 10 envois par minute et par IP, comme l'inscription enseignant.

### 3.1 Page d'inscription — `identity/school_staff_registrations/new`

**Structure** : copie de `identity/teacher_registrations/new.html.erb`. `<main class="grid min-h-dvh bg-paper md:grid-cols-2">` ; colonne gauche `bg-school/10` (au lieu de `bg-brand-soft` ; le token `school` n'a pas de variante `-soft`), logo vers `root_path`, `h1` « Bienvenue, direction », texte d'accueil. Colonne droite : `ui_card padding: :lg`, `h2` « Créer votre compte de direction », sous-titre « Avec le code d'établissement que vos enseignants utilisent. ».

**Formulaire** `form_with scope: :school_staff_registration, url: school_staff_registrations_path, id: "school-staff-registration-form"`, quatre `fieldset`, mêmes classes que `teacher_registrations/_form` :

1. « Vous » : nom, prénom(s), genre (deux radios).
2. « Contact » : numéro (`as: :tel`, indice « 10 chiffres. Il vous servira à vous connecter. »).
3. « Établissement » : code (`maxlength: 12`, `font-display tracking-widest uppercase`, placeholder `K7M-4QZ`, indice « 6 caractères, celui que vos enseignants utilisent pour s'inscrire. »). **Pas de matière.**
4. « Sécurité » : PIN et confirmation (`as: :password, reveal: true, inputmode: "numeric"`).

Puis `ui_button` « Créer mon compte » (`full: true`), et « Vous avez déjà un compte ? Se connecter » vers `new_session_path`.

**Erreurs** (422, re-rendu du formulaire, alerte `role="alert"` pour `base`, message sous le champ sinon) :

| Cas | Champ | Texte |
|---|---|---|
| Code inconnu, établissement en brouillon ou désactivé | `school_code` | « Code d'établissement invalide. Vérifiez-le auprès de vos enseignants. » |
| Code de classe | `school_code` | « Ce code est un code de classe. Saisissez le code de l'établissement (6 caractères). » |
| Plafond atteint | `base` | « Votre établissement a déjà 3 comptes direction créés avec son code. Contactez l'équipe Lnclass. » |
| Numéro déjà lié à un compte | `contact` | « Ce numéro a déjà un compte Lnclass. Utilisez un autre numéro. » |
| Champs | — | Messages de l'inscription enseignant |

**États** : succès → 303 et toast « Bienvenue ! Votre compte de direction est créé. » ; débit → `ui_error_state` (titre « Trop de tentatives », `errors.codes.rate_limited`). Pas d'état vide ni de chargement : `data-turbo-submits-with` « Création… » sur le bouton.

### 3.2 Page d'accueil — `homepage/index`

- **Lien discret** : sous les deux `render "role_modal"` du haut de page, `<p class="mt-4 text-sm text-mute">` « Vous êtes la direction d'un établissement ? » suivi de `link_to` « Créer votre compte », vers `new_school_staff_registration_path`, `id: "school-staff-signup-link"`, `class: "inline-flex min-h-tap items-center font-medium text-ink underline underline-offset-4 hover:text-brand-strong"`.
- **Section** `<section id="etablissements" aria-labelledby="etablissements-title" class="scroll-mt-20 border-t border-ink/10 bg-white py-16 md:py-24">`, **après** `#enseignants`, même structure qu'elle :
  - eyebrow « Établissements » ;
  - titre « Suivez le travail de tout votre établissement » ;
  - chapeau « Proviseur, censeur, directeur des études : créez votre compte avec le code de votre établissement. » ;
  - trois points `check-circle` : « Le travail des élèves, classe par classe » · « Vos enseignants, leurs classes, leur arrivée » · « Le lien d'inscription à partager à vos professeurs » ;
  - `ui_button` « Créer mon compte de direction » (`size: :lg, full: true, icon_end: "arrow-right"`) dans `sm:max-w-xs`.
- **Pied de page** : `<li><a href="#etablissements">` « Établissements », après « Enseignants ».

### 3.3 Bandeau d'arrivée — `school_admin/classrooms/index`

Au-dessus de la carte `#student_work`, pour chaque arrivée de moins de 7 jours autre que soi (au plus 3, la plus récente d'abord) : `<div id="staff_arrivals" role="status" class="mb-6 rounded-ln bg-school/10 px-4 py-3 text-sm text-ink">`, une ligne par arrivée : « %{name} a rejoint la direction le %{date} (%{via}). », où `via` vaut « avec le code de l'établissement » ou « sur invitation de l'équipe ». Date `l(date, format: :long)`, avec « 1er » le premier du mois (règle d'UDR-0056). Aucun bouton. Aucune arrivée → rien n'est rendu.

### 3.4 Bloc « Direction » — direction (`school_admin/schools/show`) et équipe (`teams/schools/show`)

Partial partagé `shared/_school_staff.html.erb`, locals `staff:` (lignes actives), `remove_url:` (lambda public_id → URL, ou `nil`), `removable:` (lambda ligne → booléen). `ui_card id: "school_staff", title: "Direction", subtitle: "%{used} / 3 comptes créés avec le code"`.

- Placement : direction, après `#school_link` ; équipe, en tête de la section `#school_teachers`.
- Une `<ul>` ; chaque `<li id="school_staff_<public_id>" class="flex min-h-tap items-center justify-between gap-3 py-3">` porte le nom (`font-medium`), puis « Depuis le %{date} · avec le code » ou « · sur invitation », et la mention « (vous) » sur sa propre ligne.
- Le menu ⋮ (`ui_dropdown`, label « Actions pour %{name} ») contient `ui_dropdown_item` « Retirer de la direction » (`dialog: "remove-staff-<public_id>"`, icône `user-minus`), seulement si `removable.(ligne)`. Sinon, `<span class="w-tap" aria-hidden="true"></span>`.
- La direction n'a pas le menu sur sa propre ligne, ni sur aucune ligne pendant ses 7 premiers jours. Dans ce second cas, une note `text-xs text-mute` sous la liste : « Vous pourrez retirer un compte direction 7 jours après votre arrivée. »
- Établissement non actif : aucun menu côté direction.
- **Confirmation** `ui_modal` id `remove-staff-<public_id>` :
  - titre « Retirer %{name} de la direction ? » ;
  - texte « Son compte est archivé : il ne peut plus se connecter. L'équipe Lnclass est prévenue et peut l'annuler pendant 30 jours ; ensuite, le compte est supprimé. » ;
  - boutons « Annuler » et « Retirer » (`variant: :danger`), ce dernier par `button_to … method: :delete`.
- **Succès** : `turbo_stream.remove "school_staff_<public_id>"`, `turbo_stream.replace` du sous-titre (places) et toast « %{name} a été retiré de la direction. » ; côté équipe, `turbo_stream.replace "school_archived_staff"` en plus.
- **Erreurs** : 403 → toast « Vous ne pouvez pas retirer ce compte. » ; 404 → toast « Introuvable. »
- **Vide** : `ui_empty_state` « Aucun compte direction », icône `user-group`.

### 3.5 « Directions retirées » — équipe

**Sur la fiche** : `ui_card id: "school_archived_staff", title: "Directions retirées"`, sous `#school_staff`, rendu seulement s'il y a au moins une ligne, sauf après un retrait (Turbo Stream). Chaque ligne indique : nom ; « Retiré le %{date} par %{author} » ; « Supprimé le %{due} ». Puis `button_to` « Restaurer » (`variant: :secondary, size: :sm`), si l'acteur est `admin` ou `field`.
- Succès : la ligne quitte ce bloc et entre dans `#school_staff` (`turbo_stream.append`), avec le toast « %{name} est de nouveau dans la direction. »
- 409 : toast « Les 3 places de direction par le code sont prises : retirez d'abord un compte. »

**Sur l'accueil de l'équipe** (`teams/homes/show`, pour `admin` et `field`) : `ui_card id: "team_home_archived_staff", title: "Directions retirées", subtitle: "À vérifier avant leur suppression"`, après le rappel des demandes de suppression. Les 5 plus récentes : « %{name} · %{school} · retiré le %{date} », lien vers la fiche ; « Voir les N autres » si plus. Aucune ligne → la carte n'est pas rendue.

### 3.6 Accessibilité

- Cibles ≥ 48 px (`min-h-tap`, `w-tap`) ; le menu ⋮ a un `aria-label` nommé.
- Le bandeau est `role="status"` ; les toasts suivent UDR-0006.
- Les erreurs de champ sont reliées par `aria-describedby` (`ui_field`).
- La section d'accueil a son `h2` relié par `aria-labelledby`.
- La règle des 390 px s'applique : aucune page ne défile horizontalement.

## 4. Conséquences

- La page d'accueil compte trois sections tournées vers un public (élèves dans le haut de page, Enseignants, Établissements). UDR-0064 « un écran, une décision » reste vraie pour le haut de page, qui ne gagne qu'un lien texte.
- Le bloc « Direction » est le seul endroit où l'on retire un compte direction ; aucune autre page ne porte ce geste.
- Toute nouvelle façon de devenir direction doit renseigner « avec le code » ou « sur invitation », que le bloc et le bandeau affichent.
