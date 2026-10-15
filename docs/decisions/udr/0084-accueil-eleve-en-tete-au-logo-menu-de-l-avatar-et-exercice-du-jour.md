# UDR-0084 : Accueil élève — en-tête au logo, menu de l'avatar sans barre du bas, blocs redessinés, exercice du jour et « fait seul »
<!-- index
titre: Accueil élève : en-tête au logo, menu de l'avatar, exercice du jour
statut: Proposé
adr-lie: [0089](../adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md)
problematique: Élève sur le web : logo à gauche, aide/thème/avatar à droite, menu déroulant de l'avatar (Accueil, Cours, Ma classe sous 1 024 px), plus de barre du bas ; accueil en une colonne (Ma classe, Mes matières, Annonces, À faire, activités) ; carte de l'exercice du jour en trois états ; « Fait seul (7 j) » chez l'enseignant et la direction. Amende UDR-0080, 0058, 0006, 0061, 0076
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/accueil-eleve`](../../chantiers/accueil-eleve/memo.md) |
| **ADR lié** | [ADR-0089](../adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) (exercice du jour, « fait seul », invitation) · [ADR-0084](../adr/0084-coque-android-eleves-hotwire-native.md) (coque Android, inchangée) |
| **Amende** | [UDR-0080](0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) §3.1–3.2 (en-tête et panneau du compte de l'élève sur le web) · [UDR-0058](0058-accueil-eleve.md) (blocs et ordre de l'accueil) · [UDR-0006](0006-shell-applicatif-par-role.md) (plus de barre du bas pour l'élève) · [UDR-0061](0061-carte-d-aide-et-faq.md) (l'aide revient dans le menu du compte au téléphone) · [UDR-0076](0076-organisation-des-ecrans-eleve.md) (Accueil, Cours, Ma classe passent dans le menu de l'avatar) |
| **Remplacé par** | — |

---

## 1. Contexte

L'accueil élève a été redessiné sur la toile « Lnclass Accueil élève » (Claude Design, `Main.dc.html` v11 : téléphone, tablette, ordinateur, états du jour, sans classe, sombre, menu ouvert). Le porteur a tranché chaque point le 2026-10-15 (memo du chantier) : le logo revient à gauche, l'avatar seul ouvre un menu, la barre d'onglets du bas disparaît, les blocs actuels gardent leur ordre en une colonne, et « À faire » accueille l'exercice du jour quand l'enseignant n'a rien donné.

## 2. Décision

> **Sur le web, l'élève a un en-tête « logo · aide · thème · avatar », un menu déroulant de l'avatar qui porte la navigation sous 1 024 px, aucune barre du bas, et un accueil en une colonne dont « À faire » montre l'exercice du jour en trois états. L'enseignant et la direction voient un chiffre « Fait seul (7 j) » séparé du travail donné.**

## 3. Règles d'implémentation

### 3.1 En-tête (`shared/navigation/_header`, branche élève)

| Largeur | Gauche | Droite |
|---|---|---|
| < 700 px | logo Lnclass (lien vers `/students`) | thème · avatar |
| ≥ 700 px | logo Lnclass | « Besoin d'aide ? » · thème · avatar |

- **« Besoin d'aide ? »** : texte gras `text-brand-strong`, précédé de l'icône du casque de support. Il ouvre `shared/_help_sheet`, comme aujourd'hui.
- **Icônes maison** : ni le casque (`headset`) ni la porte ouverte (`door-open`, §3.5) n'existent dans Heroicons.
  - Elles sont dessinées dans le style « outline » 24 px de Heroicons : trait de 1,5, `currentColor`.
  - Elles sont rangées dans `vendor/lnclass-icons/24/outline/`.
  - `ui_icon` les cherche là après `vendor/heroicons/`.
- **L'avatar est seul**, sans nom à côté. C'est un `button` (`aria-haspopup="menu"`, `aria-expanded`) qui ouvre le menu §3.2.
- L'en-tête des autres rôles ne change pas (UDR-0082 pour l'enseignant).

### 3.2 Menu de l'avatar (remplace le tiroir `_account_panel` de l'élève sur le web)

Un menu déroulant ancré sous l'avatar, à droite : largeur 288 px, `shadow-pop`, `rounded-card`. Dans l'ordre :

1. **Identité** : avatar `md`, nom complet, classe (« 6e A · Lycée … »).
2. **Navigation**, seulement sous 1 024 px : Accueil, Cours, Ma classe. La page en cours est en surbrillance (`bg-brand-soft`, `aria-current="page"`).
3. **Mon profil**.
4. **Mon historique**.
5. **Ajouter ma photo**, seulement sans photo (`edit_profile_photo_path`).
6. **Besoin d'aide ?**, seulement sous 700 px.
7. **Se déconnecter**, ton `danger`, séparé par un filet.

**Fermeture** : Échap, clic dehors ou choix d'un lien. Le focus revient sur l'avatar.

**Android** : `/students/menu` (`page: true`) garde le panneau actuel, avec les liens 3 à 7. Les onglets natifs ne changent pas (UDR-0080 §3.3).

### 3.3 Barre du bas et menu de gauche

- **Barre du bas** : `_bottom_bar` n'est plus rendue pour l'élève. Le shell reçoit un opt-out par rôle.
  - `DESTINATIONS[:student]` reste la source des liens du menu §3.2 et du menu de gauche.
  - Les autres rôles gardent leur barre.
- **Marge** : pour l'élève, `main#main` perd `pb-28` et prend `pb-12`.
- **Menu de gauche** : dès 1 024 px (`w-rail`, 288 px), contenu inchangé.

### 3.4 Avatar (`ui_avatar`)

- **Avec photo** : `account_photo_src`, inchangé.
- **Sans photo** : les initiales (prénom, nom ; « KA ») sur une couleur stable. Elle est choisie par `user.public_id` parmi les tons de `AVATAR_TONES` qui passent AA avec leur texte.
- **Badge « + »** : l'option `add_photo: true` ajoute une pastille ronde « + » en bas à droite, seulement sans photo.
  - Style : `bg-brand-strong text-white`, 16 px à la taille `sm`.
  - Elle est décorative : le libellé « Ajouter ma photo » est dans le menu.

### 3.5 Accueil (`classroom/student_homes/show`)

- **Mise en page** :
  - une colonne pleine largeur sous 700 px ;
  - une colonne de 720 px centrée dès 700 px ;
  - dès 1 024 px, à droite du menu de gauche, une colonne de 960 px au plus.
- **Ordre des blocs**, identique à toutes les tailles :
  1. Ma classe ;
  2. Mes matières ;
  3. Annonces ;
  4. À faire, avec les fiches à revoir ;
  5. Mes activités récentes, dans le cadre lazy existant.

  Pas de « Bonjour » ni de prénom en haut de page.
- **Ma classe** (`_classroom_card`) :
  - nom de la classe, établissement, nombre de camarades ;
  - bouton « Entrer en classe », avec `ui_icon "door-open"` devant et `arrow-right` après.
- **Mes matières** (`_subjects`, `nav#student_home_subject_bubbles`) :
  - grille de 4 colonnes au téléphone, de 6 dès 700 px ;
  - dans la grille seulement, les libellés courts « PC » (Physique-Chimie) et « HG » (Histoire-Géographie), avec le nom complet en `sr-only` et en `title` ;
  - partout ailleurs, le nom complet.
- **Annonces** : le carrousel partagé, inchangé. L'id `student_home_announcements` est conservé, car les masquages font un `turbo_stream.replace`.
- **À faire** (`ui_card id: "student_home_exercises"`) : la priorité stricte d'ADR-0089.
  - D'abord le travail de l'enseignant : en retard, puis par date limite.
  - Sinon, la carte de l'exercice du jour (§3.6).
  - Les fiches à revoir (`_pending_gaps`) restent sous la liste.
- **Bandeau d'installation** : il reste en dernier.

### 3.6 Carte de l'exercice du jour (`_daily_exercise`)

| État | Contenu |
|---|---|
| `:proposed` | Pastille « Exercice du jour » · icône et nom de la matière · titre de l'exercice · bouton principal « Commencer », qui démarre la session comme depuis Mes matières |
| `:done_today` | Icône `check-circle` en `text-success` · « Bravo, à demain ! » · « Demain : %{matière} » · pas de bouton |
| `:none` | « Rien à te proposer aujourd'hui. » · pas de bouton |

- **Sous la carte**, dans les trois états, une ligne secondaire : « Ton enseignant n'est pas encore sur Lnclass ? », puis le bouton secondaire « Inviter mon enseignant » (icône `chat-bubble-left-right`).
  - Le bouton ouvre `whatsapp_share_url` (ADR-0089 §4.3) dans un nouvel onglet.
  - Partial : `_invite_teacher`.
- La carte n'apparaît jamais à côté d'un travail de l'enseignant.

### 3.7 « Fait seul » chez l'enseignant et la direction

- **Page de la classe** (liste des élèves, `ClassroomOverviewQuery`) :
  - une colonne « Fait seul (7 j) » avec un entier ; 0 s'affiche « — » en `text-mute` ;
  - au téléphone, une ligne « Fait seul : N cette semaine » sous le nom.
- **Accueil de la direction** : dans la ligne de chaque niveau, à côté du taux de rendu, « Faits seul (7 j) : N ».
- Les comptes « faits / en retard / pas encore faits » d'un exercice donné ne changent ni de libellé ni de valeur.

### 3.8 Tokens

Pas de nouveau token de couleur.

| Usage | Tokens existants |
|---|---|
| Couleurs | `paper`, `white`, `ink`, `mute`, `line`, `brand`, `brand-soft`, `brand-strong`, `success` |
| Rayons | `rounded-card`, `rounded-sheet` |
| Ombres | `shadow-card`, `shadow-pop` |
| Largeur du menu de gauche | `w-rail` |

Les visuels de la toile qui n'ont pas de token (illustrations, dégradé de la carte de classe) sont remplacés par ces tokens. Ils ne sont pas ajoutés.

### 3.9 États obligatoires

- Élève avec ou sans photo, avec ou sans travail donné, en retard.
- Les trois états de la carte du jour.
- Sans classe (`_no_classroom`, avec le nouvel en-tête).
- Thème clair et thème sombre.
- Menu de l'avatar ouvert, au téléphone et sur ordinateur.
- App Android : inchangée.

### 3.10 Accessibilité

- **Menu de l'avatar** : `role="menu"` et `menuitem`, clavier (flèches, Échap), focus rendu à l'avatar.
- **Avatar** : son nom accessible est « Mon compte, %{nom} ».
- **Grille** : les abréviations PC et HG ont leur nom complet en `sr-only`.
- **Cibles tactiles** : au moins `spacing-tap`.
- **Contraste** : AA dans les deux thèmes, y compris pour les initiales sur couleur.
- **Carte du jour** : une `section` titrée, avec `aria-live="polite"` sur son état.

## 4. Conséquences

- **Navigation** : l'élève perd la barre du bas et gagne un menu, à un toucher de plus, comme le porteur l'a décidé. La navigation principale reste visible sur ordinateur.
- **Tests à réécrire** :
  - `integration/identity/student_header_test` CA-7 et CA-8 ;
  - `system/classroom/student_home_test` l.183–193 ;
  - `system/role_homes_test` l.99–107 ;
  - `system/identity/account_panel_test` ;
  - `student_menus_controller_test` ;
  - `helpers/navigation_helper_test`.
- **UDR-0080** : §3.1–3.2 ne valent plus pour le web élève ; §3.3 (Android) reste.
- **Shell** : il gagne un opt-out de la barre du bas par rôle, réutilisable par l'enseignant si UDR-0082 suit le même chemin.
