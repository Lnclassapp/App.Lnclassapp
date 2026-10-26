# UDR-XXXX : Palette froide et texte sans gras — les jetons `@theme` du pilote
<!-- index
titre: Palette froide, une seule police, texte sans gras
statut: Accepté *(porteur, 2026-10-23)*
adr-lie: —
problematique: Les premières maquettes « Wave » ont été refusées (trop de bleu foncé, trop de couleurs, pas assez de contraste, police trop grosse et trop grasse). Les neutres passent du crème au blanc froid, une seule police reste, la graisse plafonne à 500 et l'échelle de texte descend à 18/16/14/13/12 px.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : « 1. oui 2. oui 3. oui » ; couleurs v3 validées par le porteur le 2026-10-23 sur 4 écrans, appliquées aux 18 écrans élève) |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | — |
| **Remplacé par** | — |

---

## 1. Contexte

L'app a des neutres chauds (fond crème #faf8f4, gris brun #5e5a54) et deux polices, dont Bricolage Grotesque pour les titres, aux formes lourdes. Le porteur a refusé trois versions de suite : trop de bleu foncé, trop de couleurs, pas assez de contraste, puis police trop grosse, puis texte trop gras. Ses références sont Wave (simplicité) et Djamo (page blanche, ronds d'icône d'une seule teinte claire). Les élèves lisent sur des Android d'entrée de gamme, souvent au soleil.

## 2. Décision

1. **Neutres froids** : page blanche, gris bleutés. Le crème disparaît.
2. **Le bleu se dose** : `brand` (#00a0ff) seulement en aplat de bandeau et en barre de progression ; `brand-strong` (#0070b3) pour les boutons principaux et les liens ; `brand-soft` (#e5f5ff) pour tous les ronds d'icône et les cartes d'annonce.
3. **L'ambre veut dire « retard », rien d'autre.** Les notes ne sont jamais rouges.
4. **Une seule police, DM Sans.** Graisse 400 pour le texte, 500 au plus pour les titres. Aucun texte en 600, 700 ou 800.
5. **Échelle de texte réduite**, minimum 12 px.

Pourquoi changer les neutres pour toute l'app et pas pour l'élève seul : un jeu de neutres par rôle doublerait les jetons et casserait le test des jetons. L'enseignant hérite du blanc froid sans autre changement (son orange reste un accent fin, décision du 2026-10-22).

## 3. Règles d'implémentation

### 3.1 Jetons modifiés ou ajoutés dans `@theme` (`app/assets/stylesheets/application.tailwind.css`)

| Jeton | Avant | Après (clair) | Après (sombre) | Usage |
|---|---|---|---|---|
| `--color-ink` | #262626 | **#1f2128** | #eef1f5 (inchangé) | texte principal |
| `--color-mute` | #5e5a54 | **#5f6470** | #a3acb9 (inchangé) | texte secondaire, méta, libellés |
| `--color-line` | #e6e1d8 | **#e3eef7** | #2c3542 (inchangé) | bordures de carte, séparateurs, piste de progression |
| `--color-line-strong` | — | **#c3d8e8** (nouveau) | #3a4655 | bordures de champ, case à cocher, interrupteur éteint |
| `--color-mist` | #f2eee7 | **#f4f8fb** | #222a35 (inchangé) | section en retrait (bande des annonces), squelettes |
| `--color-paper` | #faf8f4 | **#ffffff** | #0f1218 (inchangé) | fond de page |
| `--color-warning` | #9a5200 | **#8a4a00** | #ffbf73 (inchangé) | texte de la pastille « En retard » |
| `--color-warning-dot` | — | **#f08c00** (nouveau) | #ffa94d | point de retard (grille, pastille) |
| `--color-band-ink` | — | **#0b2a40** (nouveau) | #ffffff | texte et icônes posés sur le bandeau `brand` |
| `--font-display` | Bricolage Grotesque | **DM Sans** (même valeur que `--font-sans`) | — | titres |
| `--text-meta` | — | **0.8125rem** (13 px, nouveau) | — | méta, aide, libellés de grille |

Inchangés : `brand` #00a0ff, `brand-soft` #e5f5ff, `brand-strong` #0070b3, `success` #18723f, `warning-soft` #fff1dc, rayons, ombres, espacements, conteneurs. Le fichier de police Bricolage Grotesque cesse d'être chargé.

### 3.2 Échelle de texte (classes Tailwind)

| Rôle | Taille | Classe | Graisse |
|---|---|---|---|
| Titre de carte, titre de fiche | 18 px | `text-lg` | `font-medium` |
| Titre de page et de section | 16 px | `text-base` | `font-medium` |
| Corps, titre de ligne, bouton | 14 px | `text-sm` | `font-normal` (bouton : `font-medium`) |
| Méta, aide, libellé de grille | 13 px | `text-meta` | `font-normal` |
| Petit libellé en majuscules | 12 px | `text-xs` | `font-normal` (`font-medium` admis) |

`text-2xs` (11 px) est interdit sur les écrans élève.

### 3.3 Règles d'usage

- Bouton principal : `bg-brand-strong`, texte `text-white` (5,29:1), pilule, 44 px. Secondaire : `bg-white`, bordure `border-line-strong`, texte `text-brand-strong`.
- **Aucun texte blanc sur `brand`** (2,81:1). Sur le bandeau : `text-band-ink` (5,26:1). Une carte bleue avec du texte blanc est en `bg-brand-strong`.
- Ronds d'icône (grille, lignes, carte du haut) : **tous** `bg-brand-soft`, illustration en couleur ; une icône au trait y est en `text-brand-strong`.
- Pastilles : échéance et état en `bg-brand-soft text-brand-strong` (4,75:1) ; retard en `bg-warning-soft text-warning` (6,17:1) avec point `bg-warning-dot`.
- Notes : `text-success` à 14/20 et plus, sinon `text-ink`. « Fragile » et « Mauvaise réponse » : pastille neutre `bg-mist text-mute`. Rouge interdit sur une note.

### 3.4 Garde-fous

- `test/design/design_tokens_test.rb` reste l'arbitre : aucune couleur en dur, aucune valeur arbitraire. Ajouter au test le refus de `font-semibold`, `font-bold`, `font-extrabold` et `font-black` dans `app/views` et `app/helpers`.
- Les composants partagés (`ui_button`, `ui_card`, `ui_badge`, `ui_field`) prennent ces jetons : la correction se fait dans `components_helper.rb` et les classes `ui-button*`, pas écran par écran.

### 3.5 États

Sans objet (jetons). Chaque écran vérifie ses quatre états dans son UDR.

### 3.6 Accessibilité

Contrastes vérifiés (WCAG AA, texte normal ≥ 4,5:1) : `ink`/blanc 16,1 ; `mute`/blanc 5,93 ; `mute`/`brand-soft` 5,32 ; `brand-strong`/blanc 5,29 ; `brand-strong`/`brand-soft` 4,75 ; `band-ink`/`brand` 5,26 ; `warning`/`warning-soft` 6,17 ; `success`/blanc 5,97 ; blanc/`brand-strong` 5,29. Minimum 12 px.

## 4. Conséquences

- **Toute l'app** passe au blanc froid, enseignant, direction et équipe compris : leurs écrans changent de fond sans autre retouche. À montrer au porteur en captures avant la fusion.
- Les titres perdent Bricolage Grotesque partout ; les éléments en `font-bold` ou `font-semibold` existants doivent descendre à `font-medium` au plus (balayage à faire dans le lot des jetons).
- Interdit : du texte blanc sur `brand`, de l'ambre hors retard, du rouge sur une note, une deuxième police, une graisse au-dessus de 500, un texte sous 12 px.
- **Écrans élève sur ordinateur (≥ lg)** : fond de page `mist` (#f4f8fb) et contenus en cartes blanches, au lieu de `paper` (porteur, 2026-10-24, option A). Le téléphone et les autres rôles gardent `paper`.
- **Exception : la page d'accueil publique** (chantier `page-d-accueil-photo`) garde son titre gras et sa vague jaune (porteur, 2026-10-23). Elle prend les neutres et les bleus de cette UDR pour tout le reste.
