# UDR-0162 : Le bloc « Suivi » de la fiche établissement
<!-- index
titre: Bloc « Suivi » de la fiche établissement
statut: Accepté
adr-lie: [0128](../adr/0128-contexte-crm-suivi-des-ecoles.md)
problematique: Où et comment l'équipe lit et écrit le suivi d'une école (étape, responsable, usage, contacts, relances, journal) sans alourdir la fiche
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **ADR lié** | ADR-0128 |
| **Remplacé par** | — |

---

## 1. Contexte

Avant un appel ou une visite, un membre `admin` ou `field` doit savoir en dix secondes où en est l'école, qui s'en occupe, qui appeler et ce qui s'est dit. Après l'échange, il doit le noter en moins d'une minute, souvent au téléphone, sur le terrain. La fiche établissement existe déjà (classes, direction, enseignants) et elle est longue.

## 2. Décision

Un bloc « Suivi » placé **juste sous l'en-tête** de la fiche, chargé dans un **frame Turbo paresseux** : la fiche ne paie pas le suivi pour `content`, et une erreur du suivi ne casse pas la fiche. Toutes les écritures se font dans des **modales** (`ui_modal`) et répondent en **Turbo Stream** sur le seul sous-bloc concerné, sans recharger la page. Au téléphone, l'ordre met l'action avant l'historique.

## 3. Règles d'implémentation

**Hôte** (`app/views/teams/schools/show.html.erb`, Lot 0) — juste après `render "header"` :

```erb
<% if @can_manage_crm %>
  <turbo-frame id="school_crm" src="<%= teams_school_follow_up_path(@school.public_id) %>" loading="lazy">
    <%= ui_loading_state(variant: :skeleton, lines: 4) %>
  </turbo-frame>
<% end %>
```

`@can_manage_crm` vient de `Policies::Crm::ManageCrmPolicy` dans `Teams::SchoolsController#show`. Pour `content` : rien n'est rendu (CA-01).

**Contenu du frame** (`app/views/teams/crm/accounts/show.html.erb`) :

- `<section aria-labelledby="school_crm_title" class="mb-8">`, titre `<h2 id="school_crm_title" class="mb-4 font-display text-xl font-medium">` « Suivi ».
- Grille : `grid gap-6 lg:grid-cols-3`. Colonne de droite (`lg:col-span-1`, en premier dans le DOM) : Étape et responsable → Assistants → Relances ouvertes → Contacts. Colonne de gauche (`lg:col-span-2 lg:row-start-1 lg:col-start-1`) : Usage → Journal. À 390 px, une colonne dans l'ordre du DOM : Étape et responsable, Assistants, Relances, Contacts, Usage, Journal.
- Chaque sous-bloc est un **`turbo-frame` paresseux** à `id` stable, servi par son propre contrôleur, qui contient un `ui_card(title:, heading: :h3)` ; l'`id` est aussi la cible des Turbo Streams : `school_crm_stage`, `school_crm_assistants`, `school_crm_follow_ups`, `school_crm_contacts`, `school_crm_usage`, `school_crm_journal`. Chaque frame affiche `ui_loading_state(variant: :skeleton, lines: 2)` en attendant. Ainsi chaque sous-bloc se charge, échoue et se rafraîchit seul.

**Étape et responsable** (`_stage.html.erb`)

- `ui_badge` de l'étape affichée, taille `:md`, tons : Prospect `:neutral`, Démo faite `:info`, Inscrite `:brand`, Active `:success`, Abonnée `:gold`, Perdue `:error` (le libellé est toujours écrit, la couleur n'est jamais seule).
- Si l'étape est calculée (Inscrite, Active) : `ui_info_tip` « Étape calculée d'après l'usage réel ».
- Si Perdue : motif en `text-sm text-mute` sous le badge.
- Ligne « Responsable » : nom, ou « Aucun » en `text-mute`. Si le responsable est indisponible (anonymisé ou devenu `content`) : « Aucun » + `ui_badge("Responsable indisponible", tone: :warning, size: :sm)`.
- Deux `ui_modal`, déclencheurs `trigger_variant: :secondary`, taille `sm` : « Changer l'étape » et « Changer le responsable ».
  - Étape : `ui_field(as: :radio)` sur Prospect, Démo faite, Abonnée, Perdue (jamais Inscrite ni Active) ; `ui_field(as: :select)` « Motif » avec indice « Obligatoire si Perdue ». Erreur → la modale se réaffiche en 422 avec l'erreur sous le champ.
  - Responsable : `ui_field(as: :select)` des membres `admin`/`field` non anonymisés, « Moi » en premier, puis « Aucun ».
- Succès : Turbo Stream `replace` de `school_crm_stage`, fermeture de la modale, `ui_toast` « Étape mise à jour » / « Responsable mis à jour ».

**Usage** (`_usage.html.erb`) : trois chiffres en ligne (`grid grid-cols-3 gap-4`, chiffre `font-display text-2xl`, libellé `text-xs text-mute`) : « Comptes rattachés », « Élèves actifs (14 j) », « Dernière activité » (« il y a 3 j », ou « Jamais »).

**Relances ouvertes de l'école** (`_follow_ups.html.erb`)

- Liste `<ul role="list">`, triée par échéance. Ligne : échéance (« Aujourd'hui », « Demain », date courte ; si dépassée `ui_badge("Échue", tone: :error, size: :sm)`), destinataire (« destinataire indisponible » en `text-warning` le cas échéant), motif, puis actions : `ui_button("Faite", variant: :secondary, size: :sm)` (PATCH, Turbo Stream sur `school_crm_follow_ups`), `ui_dropdown` ⋮ avec « Réattribuer » (modale) et « Rédiger un message » (UDR-0160).
- Bouton « Nouvelle relance » (`variant: :secondary`, icône `plus`) → modale : date (défaut : dans 3 jours), destinataire (défaut : le responsable, sinon moi), motif.
- Vide : `ui_empty_state(title: "Aucune relance prévue", icon: "bell")`.

**Contacts** (`_contacts.html.erb`)

- Ligne : nom (`font-medium`), fonction en `ui_badge(tone: :neutral, size: :sm)`, numéro en lien `tel:` et lien WhatsApp `https://wa.me/225<numéro>` (icône `chat-bubble-left-right`, `aria-label` « Écrire sur WhatsApp à <nom> », `target="_blank" rel="noopener"`), note en `text-sm text-mute`.
- ⋮ « Retirer » → confirmation dans le frame `modal` (patron des confirmations de `teams/schools`) → Turbo Stream sur `school_crm_contacts`.
- Bouton « Ajouter un contact » → modale : nom, fonction (select), numéro (`inputmode="tel"`, indice « 10 chiffres, ex. 0701020304 »), note.
- Vide : `ui_empty_state(title: "Aucun contact", description: "Ajoutez la direction ou un enseignant référent.", icon: "user-plus")`.

**Journal** (`_journal.html.erb`)

- Bouton `ui_button("Noter un échange", variant: :primary, icon: "pencil-square")` en tête → modale `size: :lg` : type (`as: :radio`, icônes), date et heure (défaut : maintenant), interlocuteur (select des contacts + « Autre »), résultat (`as: :radio` : Positif, Neutre, Négatif), prochaine étape (texte), note (`textarea`, 2000 caractères, compteur), case « Créer une relance » + date. Le même formulaire sert au compte rendu dicté (champ caché `source`).
- Entrées en `<ol role="list">`, plus récente en premier, 20 par page ; la suite dans un `turbo-frame` paresseux « Voir les échanges plus anciens ».
- Entrée : icône du type (`phone`, `chat-bubble-left-right`, `map-pin`, `presentation-chart-bar`, `ellipsis-horizontal`, `aria-hidden`) + libellé du type, auteur, date relative (`<time datetime>`), `ui_badge` du résultat (Positif `:success`, Neutre `:neutral`, Négatif `:error`, `size: :sm`), « avec <interlocuteur> », prochaine étape en gras, note en `whitespace-pre-line` (toujours échappée), `ui_badge("Dicté", tone: :team, size: :sm)` si `source = dictation`.
- Aucun bouton de modification ni de suppression (CA-12).
- Vide : `ui_empty_state(title: "Aucun échange noté", description: "Notez votre premier appel ou votre première visite.", icon: "chat-bubble-left-right")`.

**Tokens** : couleurs du `@theme` uniquement (`text-ink`, `text-mute`, `border-line`, `bg-paper`, `bg-mist`, tons de `ui_badge`) ; titres `font-display` ; espacements `gap-4`/`gap-6`, cartes par `ui_card`. Aucune valeur en dur.

**États obligatoires**

- Chargement : le squelette `ui_loading_state(variant: :skeleton, lines: 4)` du frame.
- Erreur du frame : `ui_error_state(title: "Le suivi n'a pas pu se charger", retry_href: teams_school_follow_up_path(...))`, la fiche reste utilisable.
- Vide : un état vide par sous-bloc (ci-dessus).
- Succès : `ui_toast` après chaque écriture ; erreurs de formulaire en 422 dans la modale.

**Accessibilité** : cibles ≥ 48 px (les `size: :sm` ont leur zone élargie) ; chaque modale porte son titre en `aria-labelledby` (fourni par `ui_modal`) et rend le focus au déclencheur ; les dates sont des `<time datetime>` ; les badges disent leur sens en texte ; l'ordre de tabulation suit l'ordre du DOM décrit plus haut.

## 4. Conséquences

- La fiche établissement accueille un frame de plus ; les blocs existants ne bougent pas.
- Toute nouvelle information de suivi entre dans un sous-bloc existant ou en crée un avec son propre `id` de cible ; jamais d'écriture qui recharge la fiche entière.
- Le formulaire « Noter un échange » est unique : le compte rendu dicté le pré-remplit, il ne le duplique pas.
