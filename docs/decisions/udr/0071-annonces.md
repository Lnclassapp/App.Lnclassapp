# UDR-0071 : Annonces — une carte courte et signée, un carrousel sur l'accueil élève, une page « Annonces » par rôle

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-10-03)* |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/annonces`](../../chantiers/annonces/prd.md) |
| **ADR lié** | [ADR-0045](../adr/0045-annonces-publication-programmee-et-audience.md) · [ADR-0078](../adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (navigation des quatre rôles, sections de l'accueil élève, toast avec action) · [UDR-0052](0052-espace-direction-simple.md) (la direction a un bouton et un formulaire) · [UDR-0036](0036-gestion-des-etablissements.md) (menu de la fiche d'établissement) |
| **Source de design** | Maquette « Accueil élève multi-écrans » du porteur et design system Lnclass §10 (annonces), **traduits dans les tokens de l'UDR-0005** — voir §2, écarts |
| **Remplacé par** | — |

---

## 1. Contexte

Lnclass n'a aucune annonce. Le porteur a validé une maquette de l'accueil élève où les annonces sont des **cartes courtes et signées**, en carrousel : « Mme Kamaté · ACE » avec un badge officiel et sans croix, « M. Kouassi · SVT » avec une croix, « Lnclass » avec le logo ; une illustration à droite, un bouton ▶ dessous ; une croix qui masque, et un toast « Message masqué · Annuler ».

L'élève lit au téléphone, souvent sur un Android d'entrée de gamme, avec un forfait cher. L'enseignant et la direction veulent prévenir vite ; l'équipe veut pouvoir retirer ce qui est déplacé.

## 2. Décision

1. **La carte est l'annonce** : signature, titre, texte de 140 caractères, illustration ou image, audio facultatif. Pas de page de détail (ADR-0078). La même carte sert au carrousel, à la liste et à la modération.
2. **Un carrousel sur l'accueil élève**, deuxième section après « À faire » : l'élève vient d'abord pour son travail (design system §1, « un écran = une tâche principale »). Cinq cartes au plus, défilement horizontal natif (CSS `scroll-snap`), sans JavaScript pour défiler.
3. **Une page « Annonces »** dans la navigation de l'enseignant, de la direction et de l'équipe, à onglets **par URL** (un onglet = une route, une requête) : les listes de l'équipe sont trop longues pour un rendu de tous les panneaux. L'élève y arrive par « Toutes les annonces ».
4. **Le formulaire est une page**, pas une modale : deux fichiers, une bibliothèque d'illustrations et des destinataires ne tiennent pas dans une modale sur téléphone (comme le formulaire d'exercice, UDR-0017).
5. **Masquer se fait en un geste, et s'annule** : croix → la carte part, toast « Annonce masquée » avec un bouton « Annuler ». Dans la liste, une annonce masquée garde un bouton « Réafficher » : l'annulation n'est pas limitée à 5 secondes.
6. **Retirer et archiver se confirment** dans une `<dialog>` (UDR-0042), jamais en un clic.

**Écarts assumés avec la maquette et le design system §10** (décidés au grill du chantier) :

| Maquette | Ici | Raison |
|---|---|---|
| ▶ lit le texte par la synthèse vocale du téléphone, sur chaque carte | ▶ joue le **fichier audio téléversé**, et n'existe que si l'annonce en a un | Choix du porteur (grill, question « Audio ») |
| Couleurs `--msg-bg #d6eeff`, `--msg-fg #002a4f`, bande `#f1f1f1` | `bg-brand-soft`, `text-school`, bande `bg-mist` | UDR-0005 : aucune couleur hors tokens ; teintes voisines |
| Signature « Mme Kamaté · ACE » | « Mme Kamaté · Direction » | Aucune fonction de direction n'est en base (grill) |
| Colonne « Annonces » collante à droite sur ordinateur | Deux cartes côte à côte dès 640 px, dans le flux de l'accueil | L'accueil de l'application n'est pas encore celui de la maquette ; ne pas refaire l'accueil ici |

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement. Tokens : UDR-0005 seulement — aucune valeur arbitraire, aucun `#hex`, aucun attribut `style`, y compris dans les SVG.

### 3.1 Navigation et sections — Lot 0

`NavigationHelper::DESTINATIONS` gagne une entrée `[:announcements, <route>, "megaphone"]`, **en dernier** :

| Rôle | Route de l'entrée |
|---|---|
| `teacher` | `:announcements_path` |
| `school_admin` | `:announcements_path` |
| `team` | `:my_announcements_path`, dernière entrée de `SECONDARY_DESTINATIONS` (amendement du Lot D) |
| `student` | aucune entrée |

Libellé `shared.navigation.announcements` : « Annonces ». Toute page de ce chantier déclare `content_for :nav_key, "announcements"`.

`HOME_SECTIONS[:student]` devient `[[:todo, …], [:announcements, "megaphone"], [:classroom, …], [:courses, …]]`.

### 3.2 La carte — `communication/messages/_card.html.erb` — Lot B

Locaux : `card:` (objet de lecture `Queries::Communication::MessageCard`, ADR-0078 §6), `context:` (`:carousel`, `:list` ou `:moderation`), `dismissible:` (vrai seulement dans le carrousel et la liste de l'élève, et jamais pour une annonce officielle).

```
article#announcement_<public_id>  aria-labelledby="announcement_<public_id>_title"
  class="relative flex min-h-40 gap-2 rounded-ln bg-brand-soft py-3 pr-2 pl-4 text-school"
├─ div.flex.min-w-0.flex-1.flex-col.justify-center.gap-1
│  ├─ p.flex.min-w-0.items-center.gap-1.5.text-xs.font-bold.text-school/80          ← signature
│  │    équipe    : image_tag("lnclass/icon.svg", alt: "", class: "size-5 shrink-0 rounded-sm") + span "Lnclass"
│  │    personne  : ui_icon("user", variant: :mini, size: :sm) + span.truncate "<signature>"
│  │    officielle: + ui_icon("check-badge", variant: :solid, size: :sm, class: "text-brand-strong")
│  │                + span.sr-only ", annonce officielle"
│  ├─ h3#announcement_<public_id>_title.text-base.leading-snug.font-bold   ← titre
│  ├─ p.text-sm                                                               ← texte, échappé (`<%= %>`, jamais `raw`)
│  ├─ (modifiée)            ui_badge "Modifiée", tone: :neutral, size: :sm
│  ├─ (liste, masquée)      ui_badge "Masquée", tone: :neutral, size: :sm  + bouton « Réafficher » (§3.5)
│  └─ p.text-xs.text-school/80  aria-live="polite"  data-communication--audio-target="status"   ← vide par défaut
├─ div.flex.w-24.shrink-0.flex-col.items-center.justify-end.gap-1.5
│  ├─ image si présente : img.size-16.rounded-ln.object-cover  src=announcement_file_path(public_id, kind: "image")
│  │                      alt="" loading="lazy" decoding="async"
│  │   sinon            : announcement_illustration(card.illustration, class: "size-16")   (aria-hidden)
│  └─ audio si présent  : §3.4
└─ croix si dismissible : button_to announcement_dismissal_path(public_id), method: :post,
                          form: { class: "absolute top-0 right-0" }, data: { turbo_stream: true },
                          class: "grid size-tap place-items-center rounded-tr-ln rounded-bl-card text-school hover:bg-school/5",
                          "aria-label": "Masquer l'annonce « <titre> »"   → ui_icon "x-mark", size: :sm
```

- **Signature** (`Communication::MessagesHelper#announcement_signature`, Lot B) : équipe → « Lnclass » ; enseignant → « M. Kouassi · SVT » (civilité tirée du genre : `male` « M. », `female` « Mme » ; nom de famille ; nom de la matière) ; direction → « Mme Kamaté · Direction ». Auteur anonymisé → la fonction seule (« SVT », « Direction »).
- La carte n'est **jamais** un lien.
- `context: :moderation` ajoute sous la carte (hors de l'`article`) la ligne du §3.7.

### 3.3 Bibliothèque d'illustrations — Lot 0

Huit clés, **liste fermée** (contrainte `CHECK` de l'ADR-0078, constante `Entities::Communication::Message::ILLUSTRATIONS` dans cet ordre) : `info`, `calendar`, `homework`, `sheets`, `exam`, `meeting`, `celebration`, `holidays`. Libellés `communication.illustrations.<clé>` : Information, Date, Devoirs, Fiches, Examen, Réunion, Félicitations, Congés.

Une illustration = un partiel `communication/messages/illustrations/_<clé>.html.erb`, rendu par `announcement_illustration(key, class:)` : `<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="<class>">`, aplats, 2 ou 3 tons, couleurs par **classes de tokens** (`fill-white`, `fill-brand`, `fill-brand-strong`, `fill-school`, `fill-teacher`, `fill-gold`, `fill-success`, `fill-error`), aucun personnage dessiné, aucun texte.

| Clé | Composition |
|---|---|
| `info` | disque `fill-brand` ; « i » en deux formes `fill-white` (point, barre arrondie) |
| `calendar` | rectangle arrondi `fill-white` ; bandeau haut `fill-error` ; deux anneaux `fill-school` ; pastille ronde `fill-success` en bas à droite avec coche `fill-white` |
| `homework` | feuille `fill-white` ; trois lignes `fill-brand` ; crayon oblique `fill-gold`, mine `fill-school` |
| `sheets` | feuille arrière inclinée `fill-brand-strong` ; feuille avant `fill-white` ; deux lignes `fill-brand` ; feuille végétale `fill-success` en bas à droite |
| `exam` | copie `fill-white` ; chronomètre `fill-teacher` (cadran `fill-white`, aiguille `fill-school`) en bas à droite |
| `meeting` | table `fill-school` ; trois chaises arrondies `fill-teacher`, `fill-brand`, `fill-gold` |
| `celebration` | coupe `fill-gold` ; pied `fill-teacher` ; trois éclats `fill-brand` |
| `holidays` | soleil `fill-gold` ; deux vagues `fill-brand` et `fill-brand-strong` |

### 3.4 Audio — contrôleur Stimulus `communication--audio` — Lot B

Rendu seulement si l'annonce a un fichier audio :

```
div  data-controller="communication--audio"
     data-communication--audio-labels-value='{"new":"Écouter le message","playing":"Arrêter la lecture","played":"Réécouter le message"}'
     data-communication--audio-unavailable-value="Audio indisponible sur ce téléphone."
     data-communication--audio-key-value="<public_id>"
├─ button[type=button].grid.size-tap.place-items-center.rounded-full.text-school  data-state="new"
│        aria-label="Écouter le message"  data-action="communication--audio#toggle"  data-communication--audio-target="button"
│  └─ span.grid.size-8.place-items-center.rounded-full.border-2.border-white
│       ui_icon "play" (solid, size :sm) · ui_icon "pause" (solid, size :sm, hidden)
├─ audio  preload="none"  src=announcement_file_path(public_id, kind: "audio")  data-communication--audio-target="player"
└─ noscript : link_to "Écouter", announcement_file_path(public_id, kind: "audio"), class: "text-xs font-bold underline"
```

- `toggle` : à l'arrêt → `play()` ; en lecture → `pause()`. Un seul audio joue à la fois : lancer une lecture met en pause les autres (événement `communication--audio:play` sur `window`).
- États : `new` (▶), `playing` (⏸, libellé « Arrêter la lecture »), `played` (▶, `opacity-60` sur le bouton, libellé « Réécouter le message »). `played` est mémorisé dans `localStorage` sous `lnclass.announcements.played` (objet `{ "<public_id>": true }`), **toujours** dans un `try/catch` : sans stockage, l'état reste `new`.
- Échec (`error` de l'élément, ou promesse de `play()` rejetée) : la cible `status` reçoit « Audio indisponible sur ce téléphone. », effacé après 4 s ; le bouton revient à son état d'arrêt. Jamais d'échec silencieux.

### 3.5 Carrousel de l'accueil élève — `communication/messages/_carousel.html.erb` — Lot B

Rendu par `classroom/student_homes/show`, branche `key == :announcements`, **seulement si** l'élève a au moins une annonce lisible (masquée ou non). Le contrôleur de l'accueil charge `@announcements` par la query de lecture (cartes du carrousel + drapeau « en a d'autres »).

```
section#student_home_announcements  aria-labelledby="student_home_announcements_title"
        class="rounded-card bg-mist p-2.5"  data-controller="communication--carousel"
├─ h2#student_home_announcements_title.sr-only  tabindex="-1"  "Annonces"
├─ ul.scrollbar-none.flex.snap-x.snap-mandatory.gap-2.overflow-x-auto  data-communication--carousel-target="track"
│   └─ li.shrink-0.basis-11/12.snap-start.sm:basis-1/2  ← une carte (§3.2, context: :carousel, dismissible: !officielle)
├─ div.hidden.justify-center.gap-1.5.pt-2  aria-hidden="true"  data-communication--carousel-target="pager"
│   └─ un span par carte : span.h-1.5.w-1.5.rounded-full.bg-line ; actif : span.h-1.5.w-4.rounded-full.bg-brand-strong
└─ p.flex.justify-end : link_to "Toutes les annonces", announcements_path,
        class: "inline-flex min-h-tap items-center gap-1 px-2 text-sm font-medium text-brand-strong"
        + ui_icon "arrow-right", variant: :mini, size: :sm
```

- Ordre et plafond : ADR-0078 §4.3 (direction, enseignants, équipe ; 5 au plus ; masquées exclues). Si toutes sont masquées : la `ul` et le `pager` ne sont pas rendus, le lien reste.
- `communication--carousel` : montre le `pager` (retire `hidden`, ajoute `flex`) s'il y a au moins 2 cartes ; met à jour le point actif au défilement (`scroll`, passif). Sans JavaScript : pas de points, le défilement marche.
- **Masquer** (croix, `POST`, Turbo Stream) : la réponse **remplace** `#student_home_announcements` par le carrousel recalculé (`turbo_stream.replace`), et ajoute le toast du §3.6. Le carrousel rendu par la réponse porte `data-communication--carousel-refocus-value="true"` : à sa connexion, le contrôleur place le focus sur `#student_home_announcements_title`. Sans Turbo : redirection vers l'accueil, toast par le flash.
- **Annuler** (bouton du toast, `DELETE` sur la même adresse, Turbo Stream) : même remplacement du carrousel, sans nouveau toast ; le toast se ferme (`toast#dismiss`).

### 3.6 Toast avec action — amende `ui_toast` (UDR-0006) — Lot 0

`ui_toast(message, type:, title:, persistent:, action: nil)` et `turbo_stream_toast(..., action: nil)`. `action: { label:, href:, method: }` ajoute, entre le texte et la croix, un `button_to label, href, method:, data: { turbo_stream: true, action: "toast#dismiss" }, class: "min-h-tap shrink-0 rounded-ln px-3 text-sm font-bold text-brand-strong hover:bg-brand-soft"`.

Toast du masquage : `type: :info`, titre « Annonce masquée », message « Elle reste dans « Toutes les annonces ». », action « Annuler » (`DELETE announcement_dismissal_path`). Durée : celle du type `info` (5 s).

### 3.7 Page « Annonces » — onglets par URL

Partiel commun `communication/shared/_tabs.html.erb` (**Lot 0**), local `current:` :

```
nav#announcement-tabs  aria-label="Annonces"  class="scrollbar-none mb-5 flex gap-1 overflow-x-auto border-b border-line"
  a  (une par onglet du rôle)  aria-current="page" sur l'onglet courant
     class="inline-flex min-h-tap items-center border-b-2 border-transparent px-4 text-sm font-medium whitespace-nowrap text-mute hover:text-ink"
     courant : + "border-brand text-ink"
```

| Rôle | Onglets, dans l'ordre |
|---|---|
| `student` | aucun (`nav` non rendue) |
| `teacher` | Reçues (`announcements_path`) · Mes annonces (`my_announcements_path`) |
| `school_admin` | Reçues · Mes annonces · Enseignants (`moderated_announcements_path`) |
| `team` | Mes annonces · Toutes (`moderated_announcements_path`) |

Chaque page : `page_title "<onglet> · Annonces · Lnclass"` (« Annonces · Lnclass » pour l'élève), `ui_page_header title: "Annonces"`, puis les onglets, puis son contenu.

**« Reçues » / « Toutes les annonces »** — `GET /announcements`, `communication/inboxes/show` — **Lot B**

- Équipe : redirigée vers `my_announcements_path`.
- Sous-titre : élève « Les annonces de tes enseignants, de ta direction et de Lnclass. » ; adultes « Les annonces qui vous sont adressées. »
- `ul#announcements.grid.gap-3.sm:grid-cols-2`, un `li` par carte (`context: :list`), **plus récente d'abord** (`published_at` décroissant), 20 par page (`ui_pagination`).
- Élève : une carte masquée porte le badge « Masquée » et `button_to "Réafficher", announcement_dismissal_path(public_id), method: :delete, data: { turbo_stream: true }` (`ui_button` `variant: :secondary`, `size: :sm`) ; la réponse remplace `#announcement_<public_id>` par la carte non masquée. Une carte non masquée et non officielle porte la croix (même geste qu'au §3.5 ; la réponse remplace la carte par sa version « Masquée », avec le toast du §3.6).
- Vide : `ui_empty_state title: "Aucune annonce pour le moment.", icon: "megaphone"`, description élève « Les annonces de tes enseignants, de ta direction et de Lnclass apparaîtront ici. », adulte « Les annonces de l'équipe Lnclass et de votre direction apparaîtront ici. »

**« Mes annonces »** — `GET /announcements/mine`, `communication/authored_messages/index` — **Lot A**

- En-tête : bloc d'action de `ui_page_header` → `ui_button "Nouvelle annonce", href: new_announcement_path, icon: "plus", variant: :primary`.
- `ui_card#my_announcements` → `ul.-mx-5.divide-y.divide-line.sm:-mx-6`, une ligne `li#my_announcement_<public_id>.flex.items-center.gap-3.px-5.py-3.sm:px-6` :
  - vignette `span.grid.size-10.shrink-0.place-items-center.overflow-hidden.rounded-full.bg-brand-soft` (image `object-cover` si présente, sinon illustration `size-7`) ;
  - `div.min-w-0.flex-1` : titre `p.truncate.font-medium.text-ink` ; sous-ligne `p.truncate.text-sm.text-mute` « <destinataires> · <dates> » ;
  - statut `ui_badge` : Brouillon (`neutral`), Programmée (`info`), Publiée (`success`), Terminée (`neutral`), Archivée (`neutral`), Retirée (`error`) ;
  - menu `ui_dropdown label: "Actions pour « <titre> »"` : « Modifier » (`href: edit_announcement_path`, `icon: "pencil-square"`) et « Archiver » (`dialog: "archive-<public_id>"`, `icon: "archive-box"`, `tone: :danger`). Pas de menu pour une annonce terminée, archivée ou retirée.
- Destinataires : « Tout le pays · Tous », « Tout le pays · Élèves », « Collège Les Lauriers · Enseignants », « 3ème B, 3ème C ». Dates : « Brouillon », « Programmée le 5 oct. à 10:00 », « Publiée le 3 oct. · jusqu'au 1ᵉʳ nov. », « Terminée le 2 nov. », « Archivée le 4 oct. », « Retirée le 4 oct. » (formats du design system §12).
- Confirmation d'archivage : `ui_modal(id: "archive-<public_id>", title: "Archiver cette annonce ?")` sans déclencheur ; texte « Elle disparaîtra pour tous ses destinataires et ne pourra plus être publiée. » ; pied « Annuler » (`ghost`, ferme) et `button_to "Archiver", announcement_archive_path(public_id), method: :post` (`variant: :danger`). Réponse : redirection vers « Mes annonces », toast « Annonce archivée. ».
- Vide : `ui_empty_state title: "Vous n'avez encore publié aucune annonce.", icon: "megaphone", action: { label: "Nouvelle annonce", href: new_announcement_path, icon: "plus" }`.
- 20 par page, plus récente d'abord (`created_at`).

**« Enseignants » (direction) / « Toutes » (équipe)** — `GET /announcements/moderation`, `communication/moderations/index` — **Lot C**

- Contenu : les annonces **programmées ou publiées non terminées** d'autres auteurs que soi ; direction : celles des enseignants de son établissement ; équipe : toutes.
- Équipe seulement : `form#moderation-filter` (GET, contrôleur `search` de l'UDR-0054) avec `ui_field :q, label: "Établissement", hint: "Nom ou sigle"` ; le filtre lit les annonces portant cet établissement ; résultats dans `turbo_frame_tag "moderated_announcements"`.
- `ul#moderated_announcements.grid.gap-3.sm:grid-cols-2`, un `li#moderated_announcement_<public_id>` par annonce : la carte (`context: :moderation`), puis `div.flex.items-center.justify-between.gap-3.pt-2` : `p.text-sm.text-mute` « <établissement ou « Tout le pays »> · <dates> » et `ui_modal(id: "withdraw-<public_id>", title: "Retirer cette annonce ?", trigger: "Retirer", trigger_variant: :secondary, trigger_icon: "no-symbol")` (le déclencheur est rendu par le composant) : texte « Elle disparaîtra pour tous ses destinataires. Son auteur la verra « Retirée » et ne pourra pas la republier. » ; pied « Annuler » et `button_to "Retirer", announcement_withdrawal_path(public_id), method: :post, data: { turbo_stream: true }` (`variant: :danger`).
- Réponse au retrait (Turbo Stream) : `turbo_stream.remove "moderated_announcement_<public_id>"` + `turbo_stream_toast "Annonce retirée.", type: :success`. Sans Turbo : redirection, toast par le flash.
- Vide : direction « Vos enseignants n'ont aucune annonce en cours. », équipe « Aucune annonce en cours. » ; avec un filtre sans résultat : « Aucune annonce pour cet établissement. » ; icône `megaphone`.
- 20 par page, plus récente d'abord.

### 3.8 Formulaire — `communication/authored_messages/new`, `edit`, `_form` — Lot A

Page entière. `ui_page_header title: "Nouvelle annonce"` (ou « Modifier l'annonce »), `back:` vers « Mes annonces ». `ui_card` → `form_with model:, scope: :announcement, url:, multipart: true, id: "announcement-form", class: "grid gap-5 max-w-form"`.

En modification d'une annonce publiée, en tête : `div.rounded-ln.bg-info-soft.p-4.text-sm.text-info` « Cette annonce est publiée : la modifier la fera réapparaître chez les élèves qui l'avaient masquée. »

Champs, dans l'ordre :

1. `ui_field :title, required: true, maxlength: 60, hint: "60 caractères au plus."` — libellé « Titre ».
2. `ui_field :body, as: :textarea, rows: 3, required: true, maxlength: 140, hint: "140 caractères au plus. Les détails peuvent aller dans l'audio."` — « Texte ».
3. **Destinataires** :
   - équipe : si elle vient d'une fiche d'établissement (`?school=<public_id>`), `ui_radio_group :scope, choices: [["Tout le pays", "national"], ["<nom de l'établissement>", "school"]]` ; sinon, champ caché `scope=national` et la phrase `p.text-sm.text-mute` « Pour un seul établissement, partez de sa fiche. » Puis `ui_radio_group :audience, choices: [["Tous", "all"], ["Élèves", "students"], ["Enseignants", "teachers"], ["Directions", "school_admins"]], columns: 2`.
   - direction : `p.text-sm.text-mute` « Pour <établissement> » ; `ui_radio_group :audience` sans « Tous ».
   - enseignant : `ui_checkbox_group :classroom_public_ids, choices: [[nom de la classe, public_id]…], label: "Classes", hint: "Les élèves de ces classes la verront."` (ses classes actives, par nom). **`ui_checkbox_group`** (Lot 0) est le pendant de `ui_radio_group` : même `fieldset`/`legend`, mêmes options de 48 px (`RADIO_OPTION`), `input type="checkbox"`.
4. **Illustration** : `fieldset` `legend` « Illustration » ; `div.grid.grid-cols-4.gap-2` ; une option par clé du §3.3 : `label.flex.min-h-tap.cursor-pointer.flex-col.items-center.gap-1.rounded-ln.border.border-line.bg-white.p-2.text-xs.font-medium.has-checked:border-brand.has-checked:bg-brand-soft` contenant `radio_button :illustration` (`sr-only peer`), l'illustration `size-12` et son libellé. Première clé cochée par défaut. Focus visible : `has-focus-visible:outline-2 has-focus-visible:outline-brand`.
5. `ui_field :image, as: :file, accept: "image/png,image/jpeg,image/webp", hint: "PNG, JPEG ou WebP, 2 Mo au plus. Elle remplace l'illustration."` — « Image (facultative) ». En modification avec une image : vignette `size-16 rounded-ln object-cover` et case « Retirer l'image » (`:remove_image`).
6. `ui_field :audio, as: :file, accept: "audio/mpeg,audio/mp4,.mp3,.m4a", hint: "MP3 ou M4A, 10 Mo au plus."` — « Audio (facultatif) ». En modification avec un audio : `audio controls preload="none"` et case « Retirer l'audio » (`:remove_audio`).
7. `ui_field :published_at, as: :datetime_local, hint: "Laissez vide pour publier dès l'envoi."` — « Publier le ». Absent en modification d'une annonce déjà publiée.
8. `ui_field :visible_until, as: :date, required: true, hint: "30 jours par défaut, 90 au plus."` — « Visible jusqu'au » (dernier jour d'affichage inclus ; préremplie à la date de publication + 29 jours).

Pied (`div.flex.flex-wrap.justify-end.gap-3`) : `ui_button "Annuler", variant: :ghost, href: my_announcements_path` ; `ui_button "Enregistrer le brouillon", type: :submit, variant: :secondary, name: "commit", value: "draft"` (absent pour une annonce déjà publiée) ; `ui_button "Publier", type: :submit, variant: :primary, name: "commit", value: "publish"`.

- Erreurs : 422, formulaire re-rendu, erreur sous chaque champ (`ui_field`) ; un fichier refusé : « Ce fichier n'est pas accepté. » ou « Ce fichier est trop lourd (2 Mo au plus). » / « (10 Mo au plus). » Les fichiers déjà choisis sont à re-sélectionner (le navigateur ne les garde pas) : la phrase d'aide le dit en cas d'erreur.
- Succès : redirection vers « Mes annonces », toast `success` : « Annonce publiée. », « Annonce programmée pour le 5 oct. à 10:00. », « Brouillon enregistré. », « Annonce modifiée. »
- Fiche d'établissement (équipe, `teams/schools/show`) : le menu ⋮ `#school-header-actions` gagne `ui_dropdown_item "Publier une annonce", href: new_announcement_path(school: public_id), icon: "megaphone"` (établissement actif seulement).

### États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Carrousel | Section non rendue (aucune annonce lisible) ; lien seul (toutes masquées) | Aucun : rendu avec l'accueil | Masquer refusé (officielle forgée) : toast `error` « Cette annonce ne peut pas être masquée. » ; audio : message du §3.4 | Cartes ; toast « Annonce masquée » |
| « Reçues » | §3.7 | Barre de progression de Turbo | Page d'erreur commune ; 404 hors droit | Liste paginée |
| « Mes annonces » | §3.7, avec action | Idem | Idem | Toast de l'action |
| Modération | §3.7 (trois textes) | Frame du filtre : `ui_loading_state variant: :skeleton` | 404 si l'annonce n'est plus retirable ; toast `error` | Ligne retirée, toast « Annonce retirée. » |
| Formulaire | — | Bouton `loading` pendant l'envoi (`aria-busy`) | 422, erreurs sous les champs | Redirection, toast |

### Accessibilité

- Un seul `h1` par page (`ui_page_header`) ; `h2` sr-only du carrousel ; chaque carte est un `article` étiqueté par son `h3`.
- Cibles ≥ 48 px (`size-tap`, `min-h-tap`) : croix, ▶, onglets, « Toutes les annonces », options du formulaire.
- Le caractère officiel n'est pas porté par la seule couleur : `sr-only` « , annonce officielle ».
- La croix et le bouton ▶ ont un `aria-label` qui nomme l'annonce ou l'action ; le statut audio est annoncé (`aria-live="polite"`).
- Focus : après un masquage, sur le titre de section du carrousel (§3.5) ; après une confirmation, la `<dialog>` rend le focus au déclencheur (UDR-0042).
- `prefers-reduced-motion` : `motion-safe:scroll-smooth` seulement sur la `ul` du carrousel.
- L'image téléversée est décorative (`alt=""`) : son contenu doit être redit par le texte ou l'audio — voir §4.

## 4. Conséquences

- La navigation de l'équipe passe à 6 entrées en barre basse (libellés courts en `text-2xs`) ; une 7ᵉ entrée imposera de regrouper.
- L'espace direction n'est plus « sans bouton » (UDR-0052 §2.6) : il a un formulaire, des menus et des confirmations, **dans les pages d'annonces seulement**.
- Interdit : une page de détail d'annonce, un lien sur une carte, un fichier d'annonce servi par une URL signée, une annonce rendue en HTML de l'auteur, la synthèse vocale du texte.
- L'image n'a pas de texte alternatif saisi : une annonce dont l'information est dans l'image seule est inaccessible. Un champ « description de l'image » est la suite naturelle si les auteurs s'en servent ainsi.
- Le jour où l'accueil élève de la maquette (carte « Prochain exercice », grille des matières) est construit, son UDR reprend le carrousel tel quel et peut le déplacer après la grille, comme dans la maquette.

## Amendement du 2026-10-04 — toast avec action et onglets, constatés au Lot 0

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot 0. Cette section fait foi en cas d'écart avec le §3.*

- **§3.6** : le bouton d'action du toast ne porte pas `data-action="toast#dismiss"`. Le toast se ferme sur `turbo:submit-start` de son formulaire (`form: { data: { action: "turbo:submit-start->toast#dismiss" } }`) : retiré au clic, le formulaire quitterait la page avant d'être envoyé. Turbo rend la réponse même quand le formulaire n'est plus dans la page.
- **§3.7, onglets** : l'onglet courant **remplace** `border-transparent text-mute` par `border-brand text-ink` (au lieu de les ajouter, ce qui laissait deux classes en conflit), et chaque onglet porte le contour de focus visible de l'UDR-0005 (`focus-visible:outline-2 focus-visible:outline-brand`).
- **§3.8, `ui_checkbox_group`** : `required:` marque le groupe (astérisque) sans rendre chaque case obligatoire ; un champ caché vide envoie le tableau même sans case cochée, pour que l'erreur « Choisis au moins une de tes classes. » vienne du serveur.
- Les titres des §3.2 (carte) et §3.4 (audio) disaient « Lot 0 » : ils sont au **Lot B**, comme le plan. Corrigé ci-dessus.

## Amendement du 2026-10-04 — renumérotation, accueil élève de l'UDR-0058, mode sombre

*Chantier [`annonces`](../../chantiers/annonces/journal.md). Statut inchangé (`Accepté`).*

- Cette UDR a été écrite et acceptée sous le numéro **0056**, déjà pris sur `Develop` par « Gestes de la direction ». Elle devient l'**UDR-0071** ; son ADR devient l'**ADR-0078**.
- **Accueil élève.** L'[UDR-0058](0058-accueil-eleve.md) (acceptée le 2026-10-02) dessine l'accueil de la maquette du porteur sous `lg` et en retire les annonces, « fonction absente ». Elle n'est pas encore construite : l'accueil de `Develop` garde la boucle `HOME_SECTIONS` épurée (UDR-0057), où le carrousel du §3.5 se branche tel quel, deuxième section. Quand la famille téléphone de l'UDR-0058 sera construite, son chantier **rend le carrousel** à la place que lui donne la maquette (entre la grille des matières et « À faire ensuite », bande pleine largeur) : la fonction n'est plus absente.
- **Mode sombre.** Le §3 n'emploie que des tokens (`bg-brand-soft`, `text-school`, `bg-mist`, `fill-*`) : l'[UDR-0065](0065-mode-sombre-par-les-tokens.md) les fait changer de valeur sans classe `dark:`. Toute nouvelle couleur de ce chantier passe par un token, jamais par une valeur en dur.
- **Navigation.** Depuis l'[UDR-0068](0068-configuration-et-pilotage-par-etablissement.md), l'équipe a 4 destinations principales (Imports et Référentiel passent dans `SECONDARY_DESTINATIONS`, menu « Plus ») et la direction 3 (UDR-0056 de `Develop`, « Gestes de la direction »). « Annonces », ajoutée **en dernier** dans `DESTINATIONS`, donne 4 entrées à l'enseignant et à la direction, 5 à l'équipe : `NAV_GRIDS` ne change pas (le §3.1 et le §4 prévoyaient 6 entrées pour l'équipe, ce n'est plus le cas).

## Amendement du 2026-10-04 — formulaire, constaté au Lot A

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot A. Cette section fait foi en cas d'écart avec le §3.8.*

- `ui_field` ne connaît ni `as: :file` ni `as: :datetime_local` : les champs « Image », « Audio » et « Publier le » passent par `ui_field f, :image, type: "file", value: nil` et `type: "datetime-local"`. Libellé, aide, erreur et `aria-describedby` restent ceux de `ui_field`. Ajouter ces deux constructeurs à `ui_field` relève d'un chantier de composants, pas de celui-ci.
- La confirmation d'archivage est un `form_with` dont le bouton est un `ui_button` `danger` (au lieu d'un `button_to`) : même requête `POST`, styles du design system.
- « Archivée le … » est datée par la dernière mise à jour de l'annonce : la table n'a pas de date d'archivage, et l'archivage est la dernière écriture d'une annonce figée.
- Une direction ou l'équipe qui n'envoie aucune audience (requête forgée : le groupe est obligatoire dans le formulaire) reçoit 403 ; un enseignant sans classe cochée reçoit 422 « Choisis au moins une de tes classes. ».

## Amendement du 2026-10-04 — lecture, carrousel et masquage, constatés au Lot B

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot B. Cette section fait foi en cas d'écart avec les §3.2 à §3.7.*

- La section du carrousel porte aussi `min-w-0` : sans lui, dans la grille de l'accueil, la page défilait en largeur sur téléphone (vu par le test système).
- La zone de statut de l'audio est dans l'`article`, hors de l'élément du contrôleur `communication--audio` : le contrôleur la retrouve par l'`article` de la carte.
- La croix et ▶ portent le contour de focus visible de l'UDR-0005.
- La réponse à un masquage (et à « Annuler », « Réafficher ») remplace à la fois `#announcement_<public_id>` et `#student_home_announcements` : un remplacement sans cible dans la page ne fait rien, la même réponse sert l'accueil et la liste.
- Les textes du masquage sont ceux de `communication.dismissal.*` (Lot 0) ; aucune locale `message_dismissals.fr.yml`.
- Le titre d'onglet suit le helper de titre : « Reçues · Annonces · Enseignant · Lnclass ».
- L'équipe n'est l'audience d'aucune annonce dans la règle de lecture : elle lit les fichiers au titre de sa policy (`ReadFilePolicy`), et sa page « Reçues » la renvoie à « Mes annonces ».

## Amendement du 2026-10-04 — modération, constatée au Lot C

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot C. Cette section fait foi en cas d'écart avec le §3.7.*

- Le §3.7 donnait l'id `moderated_announcements` au frame **et** à la liste : le frame le garde, la liste devient `ul#moderated_announcements_list` (comme `schools` / `schools_list`).
- Pendant un filtre ou un changement de page, Turbo pose `aria-busy` sur le frame (`class: "group block"`) : le squelette (`ui_loading_state variant: :skeleton`) s'affiche par `group-aria-busy:block` et la liste se masque.
- Un retrait sur une annonce déjà archivée ou retirée répond 404, avec le toast d'erreur commun « Page introuvable. ».
- La page « Enseignants » / « Toutes » est fermée à l'enseignant et à l'élève (403). Le **retrait**, lui, laisse entrer l'enseignant pour lui répondre 404 (ADR-0078 §4.2, AN-17) ; l'élève reçoit 403.
- Retirer la dernière ligne d'une page n'affiche l'état vide qu'au rechargement.

## Amendement du 2026-10-04 — navigation de l'équipe, constatée au Lot D

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot D. Décision du porteur. Cette section fait foi en cas d'écart avec le §3.1, le §4 et l'amendement « renumérotation ».*

- L'amendement « renumérotation » comptait 5 entrées pour l'équipe en oubliant la case « Plus » : la barre du bas en aurait eu 6, contre le plafond de 5 de l'[UDR-0068](0068-configuration-et-pilotage-par-etablissement.md), et à 360 px les libellés se chevauchaient.
- **Chez l'équipe, « Annonces » est la dernière entrée de `SECONDARY_DESTINATIONS`** (après Référentiel et Imports) : 2ᵉ carte de la barre latérale sur ordinateur, menu « Plus » sur téléphone, vers « Mes annonces ». `DESTINATIONS[:team]` et `NAV_GRIDS` ne changent pas ; la barre du bas de l'équipe garde 5 cases.
- L'enseignant et la direction ont « Annonces » en dernier dans `DESTINATIONS` (4 entrées chacun).
- Sur « Toutes » et « Nouvelle annonce », la 2ᵉ carte et le bouton « Plus » sont marqués courants (`nav_key`), mais l'entrée du menu « Plus » ne l'est que sur « Mes annonces » : `ui_dropdown_item` lit `current_page?`, pas `nav_key`.

## Amendement du 2026-10-04 — formulaire, constaté à la phase 5

*Chantier [`annonces`](../../chantiers/annonces/journal.md). Complète le §3.8.*

- Une image de plus de 4096 px de côté est refusée sous le champ « Image » : « L'image mesure 4096 pixels de côté au plus. » (ADR-0078, amendement de la phase 5).
- Une image que seuls ses premiers octets font ressembler à une image, ou tronquée, reçoit « Ce fichier n'est pas accepté. ».

## Amendement du 2026-10-04 — le carrousel sans croix, pour l'accueil de la direction

*Chantier [`docs/chantiers/accueil-direction`](../../chantiers/accueil-direction/prd.md), [UDR-0074](0074-accueil-de-la-direction.md) §3.10. Le texte ci-dessus reste tel qu'accepté.*

- `communication/messages/_carousel` accepte un local `dismissible:` (vrai par défaut) : faux, aucune carte ne porte de croix. L'accueil de la direction le passe à faux ; l'accueil élève ne change pas (la croix des annonces non officielles reste).
- Les règles de lecture et de masquage (ADR-0078 §4.2, §4.3) ne changent pas.


## Amendement du 2026-10-06 — l'accueil élève sans « Toutes les annonces »

*Chantier [`docs/chantiers/ux-pages-eleve`](../../chantiers/ux-pages-eleve/README.md), point 13. Demande du porteur du 2026-10-06 : « sur /students, supprime « Toutes les annonces » ». Elle complète sa décision du même jour : pas d'onglet « Annonces » pour l'élève, les annonces restent sur l'Accueil. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- `communication/messages/_carousel` accepte un local `link:` (vrai par défaut). L'accueil élève et les deux réponses au masquage (`message_dismissals/create`, `destroy`) le passent à faux : plus de lien « Toutes les annonces » sous la bande. Les accueils de l'enseignant et de la direction gardent le leur.
- **Toutes masquées** (§3.5, États obligatoires) : sans lien, la section n'a plus rien à montrer. Elle reste rendue, avec l'attribut `hidden`, pour qu'« Annuler » ait encore une cible à remplacer. Le titre ne reprend donc pas le focus quand la dernière carte part : le toast annonce le masquage.
- **Toast du masquage** (§3.6) : « Elle n'apparaît plus sur ton accueil. » au lieu de « Elle reste dans « Toutes les annonces ». », que l'élève ne peut plus ouvrir depuis son accueil.
- **Conséquence acceptée** : la page « Annonces » de l'élève (§3.7) n'est plus liée. Elle reste servie à son adresse, avec un retour « Accueil » (UDR-0054, amendement du 2026-10-06). Une annonce masquée ne se réaffiche plus depuis l'accueil, sauf par « Annuler » dans les 5 s du toast.
- **Vérification** : `test/views/communication/carousel_test.rb`, `test/controllers/classroom/student_homes_controller_test.rb`, `test/controllers/communication/message_dismissals_controller_test.rb`, `test/system/communication/student_announcements_test.rb`, `test/system/communication/announcements_journey_test.rb`.
