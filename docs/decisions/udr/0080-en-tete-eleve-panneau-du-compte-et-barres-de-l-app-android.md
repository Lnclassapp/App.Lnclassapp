# UDR-0080 : En-tête élève (avatar à gauche, aide à droite), panneau du compte, barres natives de l'app Android
<!-- index
titre: En-tête élève, panneau du compte, barres natives de l'app Android
statut: Proposé
adr-lie: [0084](../adr/0084-coque-android-eleves-hotwire-native.md), [0070](../adr/0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md)
problematique: Élève : avatar à gauche ouvrant un panneau (`ui_modal placement: :drawer`, aussi servi à `/students/menu`), « Besoin d'aide ? » et interrupteur à droite, sans logo ; app : barre native (avatar, aide), trois onglets natifs cachés pendant un exercice ; message `:wrong_app`. Amende UDR-0006, 0065, 0061, 0078
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-08 |
| **Chantier** | [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md) |
| **ADR lié** | [ADR-0084](../adr/0084-coque-android-eleves-hotwire-native.md) (coque, pont, chemins) · [ADR-0070](../adr/0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (poids) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (l'en-tête de l'élève diffère des trois autres rôles) · [UDR-0065](0065-mode-sombre-par-les-tokens.md) (l'interrupteur est visible sur téléphone pour l'élève) · [UDR-0061](0061-carte-d-aide-et-faq.md) (« Besoin d'aide ? » quitte le menu du compte de l'élève pour l'en-tête) · [UDR-0078](0078-bandeau-d-installation-et-page-pas-de-connexion.md) (aucune pop-up d'installation dans l'app) |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur a fixé, le 2026-10-08, la navigation de l'élève sur le site et dans l'app Android « Lnclass ».

- **Sur le site**, l'en-tête de l'élève change :
  - l'avatar passe à gauche, à la place du logo ;
  - « Besoin d'aide ? » et l'interrupteur clair/sombre vont à droite ;
  - le logo quitte l'en-tête ;
  - la barre basse ne change pas.
- **L'avatar ouvre un panneau** qui glisse depuis la gauche : nom et classe, thème, Profil, Cours, déconnexion.
- **Dans l'app**, la coque cache l'en-tête et la barre basse du site. Elle affiche sa propre barre en haut (l'avatar à gauche, « Besoin d'aide ? » à droite) et sa propre barre d'onglets en bas (Accueil, Cours, Ma classe). Les onglets disparaissent pendant un exercice.
- **Les trois autres rôles** gardent l'en-tête actuel.

## 2. Décision

1. **Un seul panneau du compte, deux portes.** Le contenu est un partial unique. Sur le site, il s'ouvre dans une `<dialog>` latérale depuis l'avatar de l'en-tête. Dans l'app, la coque ouvre l'adresse `/students/menu` en modale, et cette page rend le même partial. Une évolution du panneau vaut donc pour les deux.
2. **L'aide garde sa carte existante** (UDR-0061). L'en-tête de l'élève rend le déclencheur de la carte, désormais visible à toutes les largeurs. Dans l'app, le bouton natif ouvre `/aide` en modale.
3. **Sans logo dans l'en-tête de l'élève.** La marque reste portée par le filet de couleur du rôle, par l'écran de démarrage de l'app et par son icône. Ce coût est consenti (§4).
4. **Pendant un exercice, rien ne distrait.** Dans l'app, la séance s'ouvre en modale plein écran, sans onglets (ADR-0084 §4.3). Sur le site, rien ne change.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 En-tête de l'élève — `shared/navigation/_header`, branche `student`

Le partial existant garde sa structure pour les autres rôles. Pour un élève (`user.role.to_s == "student"` : le rôle du shell est un symbole), la rangée intérieure devient :

```
header (inchangé : sticky top-0 z-40 h-bar border-b border-line bg-paper/90 backdrop-blur, filet du rôle)
  div.flex.h-full.items-center.justify-between.gap-3.px-gutter.lg:px-8
    render "shared/navigation/account_panel", user:      (le panneau du §3.2 et son déclencheur)
      a[href=/students/menu][aria-haspopup=dialog][aria-controls=account_panel][data-action="modal#open"]
          (déclencheur-lien de ui_modal, trigger_href:, UDR-0061 ; suivi sans JavaScript, intercepté avec)
        ui_avatar(user.name, src: user.avatar_url, size: :sm)          aria-hidden
        span.hidden.text-sm.font-medium.md:inline → user.name           aria-hidden
        nom accessible → t("shared.navigation.account_panel.open")   « Ouvrir le menu du compte »
    div.flex.items-center.gap-1
      render "shared/help_sheet", trigger_class: nil       (« Besoin d'aide ? » + icône question-mark-circle, ghost, sm ; visible partout)
      render "shared/theme_switch", variant: :icon, wrapper: nil   (visible partout, plus seulement lg+)
```

- Le badge de rôle et le menu déroulant du compte ne sont plus rendus pour l'élève.
- L'entrée « Besoin d'aide ? » que l'accueil élève ajoutait au menu du compte (`content_for :account_menu`, UDR-0061) n'a plus d'objet. Elle est retirée de `classroom/student_homes/show`, ainsi que le second rendu de la carte d'aide sur cette page : la carte n'est rendue qu'une fois, par l'en-tête.
- À 390 px, la rangée tient sur une ligne : l'avatar seul (sans le nom), « Besoin d'aide ? » en petit bouton fantôme, puis l'interrupteur. Aucun défilement horizontal.

### 3.2 Panneau du compte — `shared/navigation/_account_panel`, locals `(user:)`

**Sur le site** : `ui_modal id: "account_panel", title: t(".title"), size: :sm, placement: :drawer`, rendu à gauche de l'en-tête : son déclencheur-lien est l'avatar (le contrôleur `modal` n'ouvre qu'un déclencheur qu'il contient). Avec `page: true`, le partial rend le contenu seul, pour `/students/menu`.
- Le titre est « Mon compte ».
- Le nouveau placement **`:drawer`** de `ui_modal` est une feuille ancrée à gauche :
  - `dialog.dialog-drawer` : `margin: 0 auto 0 0`, `height: 100dvh`, `max-height: none`, `width: min(20rem, 85vw)`, `border-radius: 0 var(--radius-sheet) var(--radius-sheet) 0` ;
  - glissement depuis la gauche en `motion-safe` uniquement ;
  - même fond, même croix, même gestion d'Échap et du fond que les autres `ui_modal`.

**Contenu** (dans le corps de la modale, et seul contenu de la page `/students/menu`) :

```
div.flex.items-center.gap-3.pb-4.border-b.border-line          (identité)
  ui_avatar(user.name, src: user.avatar_url, size: :lg)
  div.min-w-0
    p.truncate.font-display.font-extrabold.text-ink → user.name
    p.truncate.text-sm.text-mute → user.detail   (« Tle D 1 · Lycée moderne 2 », déjà fourni par ShellUser)
nav[aria-label=t(".label")].py-2                                (« Menu du compte »)
  ul
    li → ui_dropdown_item-like lien : icône user-circle, t("shared.navigation.profile"), href profile_path
    li → lien : icône book-open, t("shared.navigation.courses"), href courses_path
div.py-3.border-t.border-line.flex.items-center.justify-between (thème)
  span.text-sm.text-ink → t("shared.theme_switch.label")
  render "shared/theme_switch", variant: :icon
div.pt-3.border-t.border-line
  button_to session_path, method: :delete → icône arrow-right-start-on-rectangle, t("shared.navigation.sign_out"), ton danger
```

- Les liens ont une cible tactile de 48 px (`min-h-tap`), toute la ligne cliquable, et un focus visible `outline-brand`.
- **Page `/students/menu`** (`GET`, route `student_menu`, contrôleur `Classroom::StudentMenusController#show`, élève seulement) :
  - rend le même partial dans le shell ;
  - est faite pour l'app, où le shell est sans en-tête ;
  - sur le site, elle s'affiche normalement si on l'ouvre, par exemple sans JavaScript.
- Sans JavaScript, l'avatar est un lien vers `/students/menu` (déclencheur-lien de l'UDR-0061) ; la ligne du thème y montre son libellé sans l'interrupteur, caché sans JavaScript (UDR-0065).

### 3.3 Barres de l'app Android (coque, ADR-0084)

**Barre du haut**, en barre d'outils native Material :
- à gauche, sur une page racine d'onglet, l'**avatar** : cercle de 32 dp avec les initiales sur la teinte de l'avatar du site, ou la photo si l'élève en a une ;
- sur une page intérieure, la flèche retour remplace l'avatar ;
- au centre, le titre de la page (`<title>` du site, sans « · Lnclass ») ;
- à droite, un bouton texte « Besoin d'aide ? » avec l'icône `question-mark-circle`.

Toucher l'avatar ouvre `/students/menu` en modale, et toucher « Besoin d'aide ? » ouvre `/aide` en modale.

Les données de l'avatar viennent du pont. Le shell rend, dans la coque et pour un élève seulement :

```erb
<div data-controller="bridge--account" hidden
     data-bridge--account-initials-value="AK" data-bridge--account-photo-url-value="…"
     data-bridge--account-menu-url-value="/students/menu" data-bridge--account-help-url-value="/aide"></div>
```

**Barre d'onglets du bas**, en `BottomNavigationView` native :
- trois onglets : Accueil (`home`), Cours (`book-open`), Ma classe (`academic-cap`), avec les libellés de `shared.navigation` ;
- couleur active : le bleu de marque `#00A0FF` ;
- cachée pendant une séance d'exercice (modale plein écran).

**Écran de démarrage** : l'icône de l'app (baobab sur bleu), sur un fond `#00A0FF`.

**Couleurs** : la barre d'état et la barre du haut suivent le thème du système (clair : fond blanc, texte `#1F2128` ; sombre : fond `#0F1218`, texte `#EEF1F5`).

### 3.4 Message de refus dans l'app (ADR-0084 §4.5)

Sur la page de connexion, quand le use case rend `:wrong_app`, le formulaire est rendu en `422` avec une alerte `ui_toast`-like en tête du formulaire, au ton `:warning` :
- titre : « Cette app est réservée aux élèves » ;
- texte : « Enseignants, direction et équipe : continuez sur le site. » ;
- un lien « Ouvrir lnclass.com » (`target="_blank"` : la coque l'ouvre dans le navigateur).

Le PIN et le numéro ne sont pas réaffichés.

### 3.5 États

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Panneau (site) | — (toujours un compte) | aucun (contenu rendu avec la page) | — | ouvert, focus sur la croix |
| `/students/menu` (app) | — | indicateur natif de chargement de Hotwire Native | page « Pas de connexion » (ADR-0082) | contenu |
| Barres natives | — | indicateur natif | écran d'erreur natif de Hotwire Native avec « Réessayer » | — |

### 3.6 Accessibilité

- Le lien de l'avatar est nommé (« Ouvrir le menu du compte ») et porte `aria-haspopup="dialog"` et `aria-controls`.
- Le panneau est une `<dialog>` modale nommée par son titre. Le focus y est piégé, et Échap le ferme.
- Les cibles tactiles font au moins 48 px (site) et 48 dp (app).
- L'interrupteur garde son `role="switch"` (UDR-0065).

## 4. Conséquences

- L'élève n'a plus de menu déroulant du compte : Profil et déconnexion vivent dans le panneau.
- **Sans logo dans l'en-tête de l'élève**, une capture d'écran de l'app ou du site ne porte plus « Lnclass ». Ce coût est accepté par le porteur ; on le réexaminera sur les captures.
- Toute nouvelle entrée du compte de l'élève se fait dans `_account_panel`, et vaut pour le site comme pour l'app.
- Le placement `:drawer` de `ui_modal` devient un composant du design system, réutilisable.
- Interdit : réécrire en natif une page de l'élève, ou ajouter un onglet natif sans entrée équivalente dans la barre basse du site.
