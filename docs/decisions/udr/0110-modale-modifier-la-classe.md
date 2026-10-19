# UDR-0110 : Modale « Modifier la classe » — préfixe fixe, suffixe et plafond
<!-- index
titre: Modale « Modifier la classe » : préfixe fixe, suffixe et plafond
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0098](../adr/0098-modifier-une-classe-nom-au-prefixe-du-bareme-et-plafond.md)
problematique: Comment l'équipe et la direction changent le nom et le plafond d'une classe sans pouvoir sortir du préfixe du barème, avec l'effectif sous les yeux et les refus sous leur champ.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16)* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/vie-de-la-classe`](../../chantiers/vie-de-la-classe/memo.md) |
| **ADR lié** | [ADR-0098](../adr/0098-modifier-une-classe-nom-au-prefixe-du-bareme-et-plafond.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe (fiche d'un établissement) et la direction (page d'un niveau) doivent corriger le nom et le plafond d'une classe. Un champ « nom » libre laisserait écrire « Tle C 3 » pour une Tle D, ce que l'ADR-0098 interdit ; un plafond saisi sans l'effectif sous les yeux provoque un refus incompris.

## 2. Décision

- Une **modale** servie dans le frame `modal`, comme « Ajouter une classe » (UDR-0031) : le geste est court, il ne mérite pas une page, et la carte reste visible derrière.
- Le nom se saisit en **deux morceaux visuels** : le préfixe affiché en texte fixe, collé au champ du suffixe (un « préfixe d'entrée »). L'utilisateur voit le nom complet sans pouvoir toucher au préfixe.
- Le plafond est un champ nombre, avec l'**effectif présent écrit dans son aide** : la borne basse se lit avant l'envoi.

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**
- Formulaire partagé : `app/views/shared/_classroom_settings_form.html.erb`, `locals: (input:, url:, settings:)`, `settings` étant la ligne de `Queries::Classroom::ClassroomSettingsQuery` (nom, préfixe, suffixe, place du suffixe, effectif) *(précisé à l'exécution, 2026-10-16)*. Rendu par `teams/classroom_settings/edit` et `school_admin/classroom_settings/edit`.
- `edit.html.erb` (chaque espace) : `turbo_frame_tag "modal"` → `ui_modal title: t(".title", name: <nom actuel>), id: "classroom-settings-modal", open: true, size: :sm, document_title: page_title(t(".title", name:))`.
- Pied : « Annuler » (`ui_button variant: :secondary, data: { action: "modal#close" }`) · « Enregistrer » (`ui_button type: :submit, form: "classroom-settings-form", icon: "check"`).
- Corps, dans l'ordre :
  1. Alerte `role="alert"` des erreurs `base` (même balisage que `teams/school_classrooms/_form`), seulement si elles existent.
  2. Champ **Nom** : `<label for="classroom_settings_suffix">Nom</label>`, puis une ligne `flex` : `<span id="classroom-settings-prefix">` contenant le préfixe (« Tle D »), fond `bg-mist`, bordure `border-line` à gauche, `rounded-l-ln`, `px-3`, `font-medium text-ink` ; le champ `ui_field form, :suffix, label: false` collé à droite (`rounded-r-ln`), `maxlength` = 15 − longueur du préfixe − 1, `autocomplete: "off"`, `autofocus: true`, `aria-describedby: "classroom-settings-prefix classroom-settings-suffix-hint"`. Aide : « Le niveau et la série ne changent pas. 15 caractères au plus en tout. »
  3. Champ **Plafond d'élèves** : `ui_field form, :max_students, as: :number, required: true, min: [headcount, 1].max, max: 150, step: 1`, aide `t(".max_students_hint", count: headcount)` : « La classe compte 42 élèves. Entre 42 et 150. » (zéro : « La classe n'a pas encore d'élève. Entre 1 et 150. »).
- Suffixe prérempli par `ClassroomNumbering.suffix_of` ; vide quand le nom actuel ne vient pas du préfixe, avec l'aide supplémentaire « Le nom actuel, « <nom> », sera remplacé. »

**Tokens**
- Couleurs : `bg-mist`, `border-line`, `text-ink`, `text-mute`, `bg-error-soft`, `text-error` uniquement.
- Typographie : libellés du composant `ui_field` ; préfixe en `font-medium`.
- Espacements : `space-y-5` entre champs, comme `teams/school_classrooms/_form`.

**Comportement**
- Ouverture : lien `edit` avec `data-turbo-frame="modal"` (UDR-0111). Sans JavaScript : la même adresse rend une page complète (le frame `modal` n'est pas requis pour lire).
- Envoi : `form_with model: input, scope: :classroom_settings, url:, method: :patch, id: "classroom-settings-form"`.
- Échec de validation (`:invalid`, `:conflict` sur `suffix` ou `max_students`) : la modale est re-rendue en **422** avec la saisie, l'erreur sous son champ.
- `:conflict` `archived` : `turbo_stream` qui ferme la modale, toast neutre « Cette classe est archivée : restaurez-la pour la modifier. », page rafraîchie (`turbo_stream.refresh`).
- Succès : `turbo_stream` qui ferme la modale, re-demande la page par morphing (`turbo_stream.refresh`, comme « Ajouter une classe » ; la carte y prend son nouveau nom) *(précisé à l'exécution, 2026-10-16)* et émet le toast « Classe <nouveau nom> enregistrée. ». Sans JavaScript : redirection 303 vers la fiche (équipe) ou la page du niveau (direction), message flash identique.
- Aucun contrôleur Stimulus nouveau : `modal` existant.

**États obligatoires**
- Vide : sans objet (les champs sont toujours préremplis, sauf le suffixe d'un nom libre).
- Chargement : bouton « Enregistrer » désactivé pendant l'envoi (`data-turbo-submits-with`, libellé « Enregistrement… »).
- Erreur : sous le champ — « Saisissez la fin du nom. » · « Le nom complet tient en 15 caractères au plus (<préfixe> + <n>). » · « Ce nom est déjà pris dans l'établissement cette année (classes archivées comprises). » · « Entre 1 et 150 élèves. » · « La classe compte déjà <n> élèves : le plafond ne peut pas être plus bas. »
- Succès : toast ci-dessus, annoncé par la région `aria-live="polite"` des toasts.

**Accessibilité**
- Cibles ≥ 48 × 48 px pour les deux boutons et les deux champs ; à 390 px, la modale tient sans défilement horizontal (préfixe et suffixe sur une ligne, le suffixe prend la place restante, `min-w-0`).
- `<dialog>` avec `aria-labelledby` (titre) ; focus d'ouverture sur le suffixe ; Échap = Annuler ; focus rendu au ⋮ à la fermeture.
- Le préfixe est lu avec le champ (`aria-describedby`) : un lecteur d'écran annonce « Nom, Tle D, … ».
- Erreurs liées à leur champ par `aria-describedby` et `aria-invalid="true"` (comportement de `ui_field`).

## 4. Conséquences

- Toute modification d'une classe passe par cette modale ; aucun champ de nom libre n'existe hors d'« Ajouter une classe » (équipe).
- Le formulaire est partagé entre l'équipe et la direction : un changement de champ se fait une fois.
