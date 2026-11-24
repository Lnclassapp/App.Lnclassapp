# UDR-XXXX : Accueil élève — « Inviter » et « Plus » dans la grille, feuille « Plus », entrées dans le menu de gauche
<!-- index
titre: Accueil élève, grille « Inviter » et « Plus »
statut: Accepté
adr-lie: —
problematique: Où placer l'invitation et les entrées secondaires de l'élève sans ajouter de section à l'accueil
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-24 |
| **Chantier** | `docs/chantiers/accueil-eleve-grille-plus` |
| **ADR lié** | — |
| **Remplacé par** | — |

Amende : UDR-0173 §3 (accueil, point 4 « Mes matières » : « Pas de case Inviter » est levé) et UDR-0179 accueil-eleve-qr-fenetre-inviter §3.3 (la tuile « Inviter » quitte sa section et entre dans la grille).

---

## 1. Contexte

Au téléphone, l'accueil empile deux grilles : « Mes matières », puis « Invite tes camarades » avec une seule case, qui coûte une rangée et un titre (≈ 140 px). Les entrées à venir (abonnement, salle d'étude, Littera, Composa, devoirs CI) n'ont pas de place sans ajouter une section, ce que la règle 3 de l'UDR-0173 interdit. Wave, la référence du porteur, n'a qu'une grille de 8 cases, dont la dernière, « Plus », ouvre le reste.

## 2. Décision

Une seule grille de 4 colonnes : les matières (6 au plus selon le niveau), « Inviter », « Plus ». « Plus » ouvre une **feuille basse** (le `ui_modal` en `:phone_sheet` déjà utilisé par l'application), parce qu'elle garde l'accueil en place et qu'une page à part serait un écran de plus pour cinq icônes. Sur ordinateur, pas de « Plus » (décision du porteur) : la barre latérale a la place, les entrées y vont dans une 2e carte, comme celle de l'équipe. Une entrée sans écran affiche « Bientôt disponible » (choix du porteur) : jamais un lien mort.

## 3. Règles d'implémentation

> Contrat d'exécution. Tokens seulement ; graisse 600/700 seulement dans les fichiers de `WAVE_WEIGHT_SCREENS`.

**Structure**
- **Une liste d'entrées**, constante `NavigationHelper::STUDENT_MORE`, dans cet ordre ; chaque entrée : clé, destination (nom de route ou `nil`), pictogramme du jeu d'icônes, teinte :
  1. `subscribe` — `:billing_subscription_path` — `credit-card` — `bg-tint-indigo`
  2. `study_room` — `nil` — `light-bulb` — `bg-tint-yellow`
  3. `littera` — `nil` — `language` — `bg-tint-lilac`
  4. `composa` — `nil` — `pencil-square` — `bg-tint-green`
  5. `homework_ci` — `nil` — `clipboard-document-check` — `bg-tint-lavender`
  Libellés I18n `shared.navigation.more.entries.<clé>` : « S'abonner », « Salle d'étude », « Littera », « Composa », « Devoirs CI ». Ajouter une entrée = une ligne dans la constante + une clé I18n ; donner un écran = remplacer `nil` par la route.
- **Grille** (`classroom/student_homes/_subjects`) : `ul.grid.grid-cols-4.lg:grid-cols-8`, dans l'ordre : chaque matière (limite actuelle `MAX_SUBJECTS`), puis la case `li#student_invite_cell` (le `button_to` actuel de `_invite_tile`, même format de tuile) **seulement si l'élève a une classe**, puis la case `li#student_more_cell.lg:hidden`. La section `section#student_invite_classmates` et son titre « Invite tes camarades » sont supprimés ; `show` ne rend plus `_invite_tile` à part. Locals de `_subjects` : `subjects:, late_slugs:, home:` (`home` nil sans classe).
- **Case « Plus »** : `button#student_more_button` au format exact d'une tuile de matière (disque `size-14 rounded-full bg-line text-ink`, pictogramme `squares-plus` ; libellé « Plus »), qui ouvre la feuille.
- **Feuille « Plus »** : `ui_modal title: t(".more.title")` (« Plus »), `id: "student_more_sheet"`, `placement: :phone_sheet`, `size: :sm`, rendue une fois dans `show` sous la grille. Corps : `ul.grid.grid-cols-4.gap-y-4` des entrées, même tuile que les matières (disque `size-14` à la teinte de l'entrée, pictogramme `size-6 text-brand-strong`, libellé `text-sm text-ink`, `line-clamp-2`). Sous la grille, `p#student_more_status.text-sm.text-mute.text-center[role=status][aria-live=polite]`, vide par défaut.
- **Hauteur** : deux tokens ajoutés au `@theme` (UDR-0005 §« Ajouter ou modifier »), `--spacing-sheet-quarter: 25dvh` et `--spacing-sheet-half: 50dvh` ; le panneau de la feuille porte `min-h-sheet-quarter max-h-sheet-half overflow-y-auto` : au moins un quart de l'écran (décision du porteur), au plus la moitié, puis il défile.
- **Menu de gauche** (`shared/navigation/_sidebar`, dès lg) : pour l'élève, 2e carte `nav#sidebar_secondary` comme l'équipe, titre `shared.navigation.sidebar.secondary_label.student` (« Plus »), une ligne par entrée de `STUDENT_MORE` au format des liens de la 1re carte. `secondary_navigation_for(:student)` reste vide : la barre basse de l'élève ne change pas.

**Tokens**
- Couleurs : `bg-tint-*`, `bg-line`, `text-ink`, `text-mute`, `text-brand-strong`, `bg-white` ; aucune autre.
- Typographie : libellés `text-sm` (comme les matières après la retouche #688) ; titre de la feuille celui de `ui_modal`.
- Espacements : grille `gap-y-4` ; tuile `gap-2.5` ; feuille `px-gutter pb-6`.

**Comportement**
- Ouverture et fermeture : contrôleur `modal` existant (Échap, toucher hors du panneau, croix ; focus rendu à `#student_more_button`).
- Entrée **avec destination** : un lien (`link_to`, `data-turbo-frame="_top"`).
- Entrée **sans destination** : un `button type=button` relié au nouveau contrôleur Stimulus `soon` (`data-action="soon#say"`, `data-soon-message-value` = `t("shared.navigation.more.soon")`, « Bientôt disponible ») : il écrit le message dans la cible `status` (`#student_more_status` dans la feuille ; dans le menu de gauche, un `p[role=status]` sous la carte), puis l'efface après 4 s. Pas de `popover` (Safari 16.4, cf. `components/_info_tip`). L'adresse ne change jamais.
- Aucun Turbo Frame ni requête : la feuille est dans le HTML de l'accueil.

**États obligatoires**
- **Vide** : aucune matière → « Inviter » (avec classe) et « Plus » restent ; la phrase « aucune matière » reste sous la grille. La feuille n'est jamais vide (5 entrées fixes).
- **Chargement** : aucun (rien n'est chargé).
- **Erreur** : aucune requête ; « S'abonner » mène à une page qui gère ses propres erreurs.
- **Succès** : 390 px → matières, « Inviter », « Plus » en 4 colonnes ; 1440 px → matières et « Inviter » en 8 colonnes, entrées dans le menu de gauche.
- **Sans classe** : matières du dernier niveau, puis « Plus » ; pas d'« Inviter ».

**Accessibilité**
- Cibles ≥ 48 px (`min-h-tap`) pour chaque case, entrée et la croix.
- `#student_more_button` : `aria-haspopup="dialog"`, `aria-controls="student_more_sheet"`, nom « Plus ».
- La feuille : `dialog` nommé par son titre (fourni par `ui_modal`).
- Pictogrammes décoratifs (`aria-hidden`) ; le libellé nomme la case.
- Une entrée sans écran ne porte pas l'information par la couleur : elle a l'air normale, le message est lu (`role=status`).
- Focus visible `outline-brand` ; `prefers-reduced-motion` respecté (celui de `ui_modal`).

## 4. Conséquences

- L'accueil de l'élève n'a plus de section « Invite tes camarades » : la seule porte « Inviter » est la case de la grille (règle 3 de l'UDR-0173).
- Toute nouvelle entrée secondaire de l'élève va dans `STUDENT_MORE`, jamais dans une nouvelle section de l'accueil.
- La feuille et le menu de gauche lisent la même liste : ils ne peuvent pas diverger.
- La hauteur de 25 % est un minimum : au-delà de 8 entrées (2 rangées), la feuille dépasse 25 % et défile au-delà de la moitié de l'écran.
