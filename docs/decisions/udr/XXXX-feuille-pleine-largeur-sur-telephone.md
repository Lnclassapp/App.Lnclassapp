# UDR-XXXX : Sur téléphone, la feuille occupe toute la largeur de l'écran
<!-- index
titre: Feuille pleine largeur sur téléphone
statut: Accepté
adr-lie: —
problematique: Sur téléphone, la feuille (épreuve à lire ou feuille à remplir) perd 36 à 51 px de chaque côté en marges empilées : le texte et les champs sont serrés.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/feuille-pleine-largeur` |
| **ADR lié** | — (ADR-0121 pour les feuilles) |
| **Remplacé par** | — |

Amende l'UDR-0149 §3 (« Tokens » : fond, feuille blanche, ombre) et l'UDR-0152 §3 (épreuve) **sous 640 px seulement** ; au-delà de 640 px, la mise en page ne change pas. Amende aussi l'UDR-0151 §3 pour le libellé du bouton sous l'épreuve (toutes largeurs).

---

## 1. Contexte

À 390 px, trois marges s'empilent avant le texte : la marge de page de l'application (16 px, `px-gutter`), la marge intérieure de la feuille blanche (`.ps-sheet`, environ 20 px) et, sur la feuille à remplir, celle du cadre de l'exercice (`.ps-exercise`, 14 px + 1 px de bord). Le texte de l'épreuve commence à 36 px du bord, celui de la feuille à remplir à 51 px. Le pilote a demandé que la feuille remplisse l'écran ; il a validé l'essai à 390 px (2026-11-04, capture de l'épreuve « après »).

## 2. Décision

Sous 640 px, la feuille va bord à bord : la page des feuilles annule la marge de page de l'application, la feuille blanche perd son ombre et sa marge intérieure passe à 12 px, le cadre d'un exercice garde son bord avec une marge intérieure de 10 px × 8 px.

## 3. Règles d'implémentation

**Où** : `app/assets/stylesheets/prepare_sheet.css` seulement, dans un bloc `@media (max-width: 639px)`. Aucune vue, aucun contrôleur, aucun style en ligne.

**Pages concernées** (toutes rendent `div.ps-page`, sans changement de leur code) : `catalog/prepare_sheets/show` et `fill`, `classroom/student_assigned_sheets/show` et `fill`, `classroom/classroom_prepare_sheets/show`.

**Règles sous 640 px**
- `.ps-page` : `margin-inline: calc(-1 * var(--spacing-gutter))` (la feuille touche les deux bords de l'écran ; le lien de retour au-dessus reste dans la marge de page).
- `.ps-sheet` : `padding: 16px 12px 32px` ; `box-shadow: none`.
- `.ps-exercise` : `padding: 10px 8px` (le bord 1 px `#999` reste).
- `.ps-page .ps-start` (« Commencer l'exercice » sous l'épreuve) : `width: auto; align-self: stretch; margin-inline: 12px` (aligné sur le texte de la feuille, pas collé aux bords).
- Le bandeau fixe d'un devoir composé (`.ps-batch`) et les cases de la leçon (`.ps-cards`) ne changent pas.

**Libellé du bouton sous l'épreuve** (toutes largeurs ; amende l'UDR-0151 §3, choix du pilote le 2026-11-04) : sur la page de lecture (`catalog/prepare_sheets/show`, `classroom/student_assigned_sheets/show`), le bouton `.ps-start` dit toujours « Commencer l'exercice » (`catalog.courses.sheets.start`), que la feuille soit interros ou devoirs et qu'un exercice ait déjà une copie ou non. « Commencer Prépare … » et « Continuer Prépare … » ne sont plus affichés ; les clés devenues inutiles sont retirées.

**Mesure de conformité** : à 390 px, sur l'épreuve et la feuille à remplir de « Propriétés de Thalès dans un triangle » (sujet 3), sur un devoir de « Ma classe » et sur la page de l'enseignant : le bord gauche de `.ps-sheet` vaut 0, son bord droit vaut 390, le premier énoncé commence à 12 px (épreuve) et à 21 px au plus (feuille à remplir), et `document.documentElement.scrollWidth <= 390`. À 1280 px, les mêmes mesures qu'avant le chantier.

**États** : inchangés (succès, vide, erreur, chargement de l'UDR-0149 et de l'UDR-0152).

**Accessibilité** : inchangée ; la cible de « Commencer » garde sa hauteur.

## 4. Conséquences

- Sur téléphone, chaque ligne gagne de 48 à 60 px : moins de retours à la ligne dans les énoncés, les tableaux de QCM et les champs.
- La feuille n'a plus l'allure d'une page posée sur un fond gris sur téléphone ; elle la garde sur ordinateur.
- Interdit : réintroduire une marge de page autour de `.ps-page` sous 640 px.
