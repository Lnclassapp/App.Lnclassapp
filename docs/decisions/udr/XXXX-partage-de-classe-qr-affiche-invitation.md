# UDR-XXXX : Partage de la classe — QR, affiche A4, kit d'établissement, « Invite tes camarades », k-factor de l'équipe
<!-- index
titre: Partage de classe (QR, affiche, invitation élève, k-factor)
statut: Accepté
adr-lie: [XXXX](../adr/XXXX-attribution-des-inscriptions-eleves.md)
problematique: faire venir une classe entière et ses absents (QR au tableau, affiche, invitation WhatsApp) et lire le k-factor, sans section en double ni donnée d'élève exposée
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-20 |
| **Chantier** | `docs/chantiers/partage-classe-k-factor` |
| **ADR lié** | ADR-XXXX-attribution-des-inscriptions-eleves |
| **Remplacé par** | — |

---

## 1. Contexte

Jour J du playbook de lancement d'une ville : en salle, souvent sans projecteur, l'enseignant dicte un lien de 12 caractères ; les absents ne sont jamais invités ; l'affiche n'existe pas ; l'équipe ne sait pas quelle classe fait venir les autres. Quatre surfaces : la carte « Inscrire vos élèves » (enseignant, direction, équipe), une page A4 imprimable (classe, établissement), l'accueil élève, la page Croissance (équipe).

## 2. Décision

- **QR dans une fenêtre** depuis la carte existante, pas sur la carte : la carte reste courte (deux boutons + menu), le QR s'affiche en grand pour être scanné au tableau depuis le téléphone ou l'ordinateur de l'enseignant.
- **Affiche = page imprimable** (gabarit `print`, celui de la planche des cartes d'activation), pas un PDF généré : zéro dépendance, le navigateur imprime en A4.
- **Accueil élève : une seule bannière d'invitation** en bas (règle Wave n° 3). « Invite tes camarades » la prend ; l'invitation de l'enseignant ne reste que si la classe n'a aucun enseignant, sous la même forme, juste après.
- **Croissance : une section de plus**, après l'entonnoir des élèves, deux tableaux plats bornés à 20 lignes.

## 3. Règles d'implémentation

### 3.1 QR dans la carte « Inscrire vos élèves » (`app/views/classroom/classrooms/_link.html.erb`)

**Structure**
- Dans le groupe de boutons existant (`role="group"`), un troisième bouton **après** « Copier le lien » : `ui_modal title: t(".qr_title", classroom: classroom.name), id: "classroom-qr", size: :sm, trigger: t(".qr"), trigger_variant: :secondary, trigger_icon: "qr-code"`.
- Corps de la fenêtre, centré, `space-y-4` :
  1. `<figure id="classroom_qr">` : le QR en SVG (`class_join_qr_svg(classroom.link_token)`, helper du Lot 0), `class="mx-auto aspect-square w-full max-w-72"`, `role="img"`, `aria-label` = `t(".qr_label", classroom: classroom.name)`.
  2. `<p class="text-sm text-mute text-center">` : `t(".qr_hint")` = « Affichez-le au tableau : les élèves le scannent et arrivent dans la classe. »
  3. Pied de fenêtre : `ui_button t(".poster"), href: classroom_poster_path(classroom.public_id), target: "_blank", rel: "noopener", icon: "printer", variant: :primary` (« Imprimer l'affiche ») et `ui_button t(".close"), variant: :secondary, data: { action: "modal#close" }`.
- Le QR encode `join_classroom_url(classroom.link_token, s: "qr")`, niveau de correction `:m`, modules noirs sur fond blanc (`fill` du SVG = jeton `ink` sur `white` : utiliser `color: "000"` et `fill: "fff"` de rqrcode, seule valeur en dur admise, car un QR doit rester contrasté en thème sombre). Le SVG est généré côté serveur (`RQRCode::QRCode#as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true)`), comme la double authentification.
- **Avertissement du changement de lien** : `t(".change_warning")` devient « Le lien et le code actuels ne marcheront plus, ni les QR et affiches déjà imprimés. Vos élèves déjà inscrits restent dans la classe. »

**États**
- Succès : la fenêtre et son QR. Pas d'état vide ni de chargement (rendu serveur, dans la page). Erreur : sans objet (le jeton existe toujours).
- Après « Changer le lien » (Turbo Stream qui remplace `#classroom_link`), la fenêtre est reconstruite avec le nouveau QR.

**Accessibilité**
- Le bouton déclencheur a une étiquette visible (« QR code ») ; la fenêtre a son titre ; cibles ≥ 48 px (`min-h-tap`).

### 3.2 Affiche A4 d'une classe et kit d'établissement

**Routes** : `GET /classrooms/:public_id/poster` (`classroom_poster_path`) ; `GET /schools/:school_public_id/posters` (`school_posters_path`). Rendu avec `layout "print"`.

**Partial** `app/views/classroom/posters/_poster.html.erb`, locals `(poster:)` (`Queries::Classroom::PosterQuery::Poster` : `classroom_name`, `school_name`, `link_token`) — une feuille :

```
<article class="mx-auto flex max-w-180 flex-col items-center gap-8 py-8 text-center break-inside-avoid break-after-page last:break-after-auto">
  en-tête : logo Lnclass (image_tag brand_logo, size-10) + « Lnclass » (font-display text-2xl)
  h2 : nom de la classe (font-display text-6xl font-medium text-ink, centré)
  p  : nom de l'établissement (text-2xl text-mute, centré)
  figure : QR (class_join_qr_svg, size-72 print:size-96, centré), aria-label t(".qr_label")
  p  : lien court lisible, `join_classroom_url(token)` sans schéma (font-mono text-xl text-ink, break-all, centré)
  ol : 3 étapes, liste numérotée en grands chiffres pastille (size-12 rounded-full bg-brand text-on-brand text-2xl) + texte text-2xl :
       1. t(".steps.scan")    « Scanne le QR avec ton téléphone »
       2. t(".steps.student") « Touche « Je suis élève » »
       3. t(".steps.secret")  « Tape ton numéro et choisis ton code secret »
  pied : t(".footer") « Ta classe t'attend sur Lnclass. » (text-lg text-mute)
</article>
```

- Tailles : tokens d'échelle seulement, aucune valeur arbitraire. QR : `size-72 print:size-96`. La feuille tient sur une A4 par sa taille naturelle (`@page { size: A4 }` du gabarit `print`) ; `break-after-page` sépare les feuilles du kit.
- **Page d'une classe** (`posters/show`) : barre d'outils `print:hidden` (comme la planche des cartes : bouton « Imprimer » du contrôleur Stimulus `print`, lien « Retour à la classe »), puis une `_poster`.
- **Kit** (`school_posters/show`) : même barre d'outils (« Imprimer les N affiches », lien retour à l'établissement), puis une `_poster` par classe ouverte de l'année, triées par niveau puis nom. Aucune classe : `<p class="text-mute">` « Aucune classe ouverte cette année. », pas de bouton Imprimer.
- **Bouton du kit** : sur la page de l'établissement de la direction (`school_admin/schools/show`) et de l'équipe (`teams/schools/show`), à côté des actions existantes : `ui_button t(".posters"), href: school_posters_path(school.public_id), target: "_blank", rel: "noopener", icon: "printer", variant: :secondary` (« Imprimer les affiches des classes »).
- Titre du document : « Affiche · <classe> · Lnclass » ; kit : « Affiches · <établissement> · Lnclass ».

**États** : succès (les feuilles) ; vide (kit sans classe) ; erreur = 404/403 du `render_result` standard ; pas de chargement.

**Accessibilité** : un `h1` `sr-only` (« Affiche de la classe <classe> ») ; QR en `role="img"` avec `aria-label` ; texte noir sur blanc ; la barre d'outils n'apparaît pas à l'impression.

### 3.3 « Invite tes camarades » sur l'accueil élève (`app/views/classroom/student_homes/`)

**Structure**
- Nouvelle partial `_invite_classmates.html.erb`, rendue à la place actuelle de `_invite_banner` (dans `<div class="px-5 pt-6 lg:p-0">`, seulement quand `@home` existe).
- Même gabarit que `_invite_banner` (bannière `rounded-card bg-brand-soft`, pastille `user-group`, titre `h2`, phrase, bouton), **sans croix** (c'est une action du jour J, pas une suggestion) :
  - `h2#student_invite_classmates_title` : `t(".title")` = « Invite tes camarades »
  - `p` : `t(".hint", classroom: home.classroom_name)` = « Envoie le lien de la <classe> sur WhatsApp : ils arrivent directement dans ta classe. »
  - bouton : `button_to t(".action"), class_invite_path, method: :post, form: { target: "_blank", data: { turbo: false } }` rendu avec les classes de `ui_button size: :sm` primaire, `aria-label` = `t(".action_label", classroom: home.classroom_name)`.
- Le serveur répond 303 vers `whatsapp_share_url(message)` (`allow_other_host: true`), message = `t("classroom.class_invites.message", classroom:, school:, link: join_classroom_url(token, i: code))` = « Rejoins la classe %{classroom} de %{school} sur Lnclass : %{link} ». **Aucun prénom ni nom** dans le message.
- `_invite_banner` (enseignant) n'est rendu, juste après, **que si la classe n'a aucun enseignant** (`home.has_teacher` faux) ; sinon il disparaît.
- Sans classe active : ni l'une ni l'autre (l'existant pour l'enseignant, le nouveau pour les camarades).

**États** : succès (bannière) ; vide = élève sans classe → bannière absente ; erreur = envoi sans classe → 303 vers l'accueil, sans message ; pas de chargement (nouvel onglet).

**Accessibilité** : `section aria-labelledby="student_invite_classmates_title"` ; bouton ≥ 48 px de haut sur téléphone (`min-h-tap`) ; l'icône est `aria-hidden`.

### 3.4 Section « Partage entre élèves » de la page Croissance (`app/views/teams/growth/`)

**Structure**
- Partial `_signup_k.html.erb`, locals `(k:)` (`Queries::Classroom::SignupKFactorQuery::Result`), rendue juste **après** `render "funnel"`.
- `section#growth_signup_k aria-labelledby="growth_signup_k_title"` dans un `ui_card` :
  - en-tête : `h2` gris majuscules comme `growth_k_title` (`t(".title")` « Partage entre élèves (k) ») + `ui_info_tip t(".tip")` : « k = élèves venus par le QR ou l'invitation d'un camarade ÷ élèves inscrits. Seuil du playbook : 0,5 à J+14. »
  - ligne de total : grand chiffre `k` (`font-display text-5xl tabular-nums`, « — » si 0 inscrit) + badge `ui_badge` tonalité `:success` si k ≥ 0,5 sinon `:warning` + `t(".since", date:)` « Mesuré depuis le <date> » (date de la première attribution ; masquée s'il n'y en a aucune).
  - deux tableaux plats, titres `h3` `text-sm font-medium text-ink` : « Par établissement » puis « Par classe » ; colonnes : nom (établissement ; classe + établissement en `text-mute` en dessous) · Inscrits · QR · Invitation · Lien · Code · À froid · k. Nombres `tabular-nums text-right`. Tri : inscrits décroissants, puis nom. 20 lignes au plus par tableau ; au-delà, une ligne `text-mute` « et N autres ». Sous `sm`, le tableau défile horizontalement dans son conteneur (`overflow-x-auto`), la page jamais.
- Aucun nom d'élève, aucun lien vers un élève.

**États** : vide (aucune attribution sur la période) → la section reste avec `t(".empty")` « Aucune inscription attribuée sur la période. » à la place des tableaux ; succès ; erreur et chargement : sans objet (page serveur).

**Accessibilité** : `<table>` avec `<caption class="sr-only">`, `<th scope="col">` et `<th scope="row">` pour le nom ; les abréviations de colonnes n'en sont pas (mots entiers).

### Tokens (toutes les surfaces)

Classes du design system seulement (`test/design/design_tokens_test.rb`) : pas de hex (sauf le QR, §3.1), pas de `style=`, pas de `dark:`, graisse ≤ 500 sauf `font-bold` déjà admis des cartes Wave ; textes en `t(".clé")`, interface en français.

## 4. Conséquences

- L'accueil élève n'a jamais deux bannières d'invitation pour une classe qui a un enseignant.
- Toute future surface qui montre le lien de classe peut réutiliser `class_join_qr_svg`.
- Changer le lien d'une classe invalide ses affiches : l'interface le dit avant.
- La page Croissance a désormais deux k (enseignant, élève) : leurs titres les distinguent toujours.
