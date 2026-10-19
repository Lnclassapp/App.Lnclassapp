# UDR-0099 : « Mes établissements » de l'enseignant — liste, ajout par DRENA puis établissement, « Quitter » confirmé, et lien d'invitation ouvert connecté qui propose de rejoindre
<!-- index
titre: « Mes établissements » de l'enseignant — liste, ajout par DRENA puis établissement, « Quitter » confirmé, et lien d'invitation ouvert connecté qui propose de rejoindre
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md)
problematique: Page `/teachers/schools` : cartes d'établissement (principal, courant), « Aller dans cet établissement », menu ⋮ « Quitter l'établissement » confirmé en modale (pas pour le dernier) ; carte « Ajouter un établissement » (sélecteur DRENA + frame des établissements, repli sans JavaScript) masquée au plafond ; `GET /i/:token` connecté : carte « Rejoindre <établissement> ? » ou carte d'état (déjà dedans, plafond, lien plus valable). Amende UDR-0079 §3.6, 0042
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/multi-etablissements-enseignant`](../../chantiers/multi-etablissements-enseignant/prd.md) — critères ME-01 à ME-06, ME-13 à ME-16 |
| **ADR lié** | [ADR-0094](../adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant inscrit dans un établissement commence des heures dans un second. Il reçoit, souvent sur WhatsApp, le lien d'invitation de cette direction ou d'un collègue. Aujourd'hui, s'il l'ouvre connecté, il est renvoyé vers son accueil sans explication (UDR-0079 §3.6). Il n'a non plus aucun endroit où voir ses établissements, en ajouter un ou en quitter un où il s'est inscrit par erreur.

## 2. Décision

- **Une page « Mes établissements »**, liée depuis le panneau du compte (UDR-0098), plutôt qu'une rubrique du profil : la page porte trois gestes (aller, ajouter, quitter) qui alourdiraient le profil (UDR-0041).
- **Ajouter un établissement** reprend **exactement** la rubrique « Établissement » de l'écran d'attente (UDR-0079 §3.9) : sélecteur DRENA, frame des établissements, repli sans JavaScript. L'enseignant l'a déjà vue à l'inscription.
- **Quitter** passe par le menu ⋮ de la carte (UDR-0042) et une confirmation en modale, parce qu'il archive des devoirs. Le dernier établissement n'a pas de menu : on ne le quitte pas.
- **Le lien d'invitation ouvert connecté** demande une confirmation explicite (« Rejoindre <établissement> ? ») au lieu de rattacher à l'ouverture : un lien transféré ne doit pas rattacher sans un geste de l'enseignant.

## 3. Règles d'implémentation

> Contrat d'exécution. Clés de locale sous `school.teacher_schools` (page) et `identity.teacher_registrations.join` (lien connecté).

### 3.1 Page `GET /teachers/schools` (`School::TeacherSchoolsController#index`, enseignant seulement)

- `page_title` « Mes établissements » ; `ui_page_header(title: "Mes établissements", subtitle: "<n> sur 3")` (`one`/`other` : « 1 établissement sur 3 », « 2 établissements sur 3 »).
- `section#teacher_schools` → `ul.flex.flex-col.gap-3` → par établissement (le principal d'abord, puis par date de rattachement) :

```
li#teacher_school_<public_id>
  ui_card(padding: :md)
    div.flex.items-start.justify-between.gap-3
      div.min-w-0
        p.truncate.font-display.font-extrabold.text-ink → nom (sigle entre parenthèses s'il existe)
        p.text-sm.text-mute → nom de la DRENA
        div.mt-2.flex.flex-wrap.gap-1.5
          ui_badge « Principal » (size: :sm) si primary
          ui_badge « Vous êtes ici » (size: :sm, ton brand) si current
      ui_dropdown ⋮ (UDR-0042), seulement si l'enseignant a 2 établissements ou plus :
        « Quitter l'établissement » (ton danger, icône arrow-right-start-on-rectangle) → ouvre la modale §3.3
    si non courant : button_to teacher_current_school_path, method: :patch, params: { school_public_id: }
                     → ui_button « Aller dans cet établissement », variant: :secondary, size: :sm, icon: "arrow-right"
```

- Après la liste, **si l'enseignant a moins de 3 établissements** : la carte « Ajouter un établissement » (§3.2). Au plafond : à la place, `p#schools_limit.text-sm.text-mute` « Vous avez atteint 3 établissements. Quittez-en un pour en ajouter un autre. ».

### 3.2 Carte « Ajouter un établissement »

- `ui_card#add_school` avec `h2` « Ajouter un établissement » et le texte `text-sm text-mute` « Choisissez votre DRENA, puis l'établissement. Vous y serez rattaché tout de suite. ».
- Le formulaire reprend **à l'identique** celui de l'écran d'attente (`identity/pending_accounts/show`, UDR-0079 §3.9) : `form#school-join-drena` en `GET` vers `teacher_schools_path` (repli sans JavaScript), `form_with model: @school_join, scope: :school_join, url: teacher_schools_path` (`POST`), sélecteur DRENA (`school--drena-schools`), `<noscript>` « Voir les établissements », `render template: "school/drena_schools/index"` avec `scope: :school_join`, bouton `ui_button "Rejoindre l'établissement", type: :submit, variant: :brand, full: true`.
- La partie commune est extraite en partial `school/teacher_schools/_join_fields` (locals : `form`, `school_join`, `drena_options`, `school_options`, `get_form_id`, `get_url`) et rendue par les deux écrans : un seul formulaire à tenir.
- **Succès** (`POST /teachers/schools`) : `303` vers `teacher_classrooms_path`, toast `:success` « Vous avez rejoint <nom>. Sélectionnez vos classes. » (la session est passée sur le nouvel établissement, ADR-0094 §4.4).
- **Erreurs** (`422`, même page, alerte `role="alert"` en tête du formulaire, motif de l'écran d'attente) :

| Code | Message |
|---|---|
| `:invalid` (inconnu, inactif, autre DRENA, établissement qui l'a retiré) | « Choisissez un établissement de la liste. » (erreur de champ existante, neutre) |
| `:conflict` `already_attached` | « Vous êtes déjà dans cet établissement. » |
| `:forbidden` / `:conflict` `schools_limit` | « Vous avez atteint 3 établissements. » |
| limite de débit (comme l'écran d'attente) | `ui_error_state` existant `rate_limited` |

### 3.3 Quitter un établissement

- `ui_modal(id: "leave-school-<public_id>", size: :sm, title: "Quitter <nom> ?")`, texte : « Vous ne verrez plus cet établissement ni ses classes. Vos devoirs encore actifs dans ses classes seront archivés : les élèves ne les verront plus à faire. Les classes, les élèves et leurs résultats restent. Vous pourrez le rejoindre de nouveau. » ; pied « Annuler » (`secondary`) et « Quitter » (`danger`, `type: :submit`, `form: "leave-school-<public_id>-form"`) ; `form_with url: teacher_school_path(public_id), method: :delete, id: "leave-school-<public_id>-form"`.
- **Succès** : `303` vers `teacher_schools_path`, toast `:success` « Vous avez quitté <nom>. ». Si c'était l'établissement courant, la page suivante est dans le principal.
- **Refus** : dernier établissement (ne doit pas arriver, le menu est absent) → toast `:error` « Vous ne pouvez pas quitter votre seul établissement. » ; non rattaché → page 404 du shell.

### 3.4 Lien d'invitation ouvert connecté — amende l'UDR-0079 §3.6

`GET /i/:token`, **compte enseignant connecté** (les autres rôles connectés gardent le renvoi vers leur accueil) : page `identity/teacher_registrations/join`, dans le shell de l'enseignant, `page_title` « Rejoindre un établissement ».

| Cas (résolu au serveur, ADR-0083 §4.1) | Contenu |
|---|---|
| Lien valide, établissement où il n'est pas | `ui_card#join_school` : `h1` « Rejoindre <nom> ? », `p.text-sm.text-mute` « <DRENA> · invité par <la direction \| l'équipe Lnclass \| Prénom Nom> » ; texte « Vous garderez vos autres établissements. Vous pourrez passer de l'un à l'autre depuis votre compte. » ; `button_to teacher_schools_path, method: :post, params: { token: }` → `ui_button "Rejoindre l'établissement", variant: :brand, full: true` ; `ui_button "Annuler", href: teacher_home_path, variant: :secondary, full: true` |
| Déjà dans cet établissement | `ui_empty_state` « Vous êtes déjà dans <nom> », bouton « Aller dans cet établissement » (`PATCH teacher_current_school_path`) |
| Plafond atteint | `ui_empty_state` « Vous avez déjà 3 établissements », bouton « Mes établissements » |
| Lien invalide (inconnu, établissement inactif, collègue anonymisé ou sans cet établissement) | `ui_empty_state` « Ce lien n'est plus valable », texte « Ajoutez l'établissement depuis « Mes établissements ». », bouton « Mes établissements ». Jamais de 404, jamais de raison (comme l'inscription) |
| Établissement qui l'a retiré | **Même rendu que « Lien valide »** ; le `POST` répond l'erreur neutre « Ce lien n'est plus valable » (rien n'est révélé, ADR-0071) |

Le jeton voyage dans l'adresse ; le serveur le résout de nouveau au `POST` (ADR-0083 §4.1).

> **Précision d'implémentation (Lot B, 2026-10-16).** `GET /i/:token` d'un enseignant rattaché redirige vers `GET /teachers/schools/join/:token` (`School::TeacherSchoolJoinsController#new`, page `school/teacher_school_joins/new`, dans le shell de l'enseignant) ; « Rejoindre l'établissement » envoie `POST /teachers/schools/join/:token`. Un refus du `POST` re-rend la page (`422`) dans l'état qui le dit : déjà dedans, plafond, ou « Ce lien n'est plus valable ». Les autres comptes connectés gardent le renvoi vers leur accueil ; un enseignant sans établissement garde l'écran d'attente.

### États obligatoires

- **Vide** : impossible (la page exige au moins un établissement ; sans établissement, la garde mène à l'écran d'attente).
- **Chargement** : la frame des établissements garde son état de chargement existant.
- **Erreur** : alerte du formulaire (§3.2) ou toast (§3.3).
- **Succès** : toasts ci-dessus.

### Accessibilité

- Liste `aria-label` « Mes établissements » ; chaque menu ⋮ a le nom « Actions pour <nom> » ; chaque « Aller dans cet établissement » a le nom « Aller dans <nom> ».
- Cibles ≥ 48 px ; focus rendu au déclencheur à la fermeture de la modale (comportement de `ui_modal`).
- À 390 px : cartes en pleine largeur, bouton « Aller… » sous le nom, aucun défilement horizontal.

## 4. Conséquences

- L'écran d'attente et « Mes établissements » partagent un partial de rattachement : une évolution de l'un vaut pour l'autre.
- Un lien d'invitation n'est plus une impasse pour un enseignant connecté ; il ne rattache jamais sans un clic.
- Les captures du Lot B montrent la page avec un, deux et trois établissements, la modale « Quitter » ouverte et la carte « Rejoindre ? », à 390 px et sur ordinateur.
