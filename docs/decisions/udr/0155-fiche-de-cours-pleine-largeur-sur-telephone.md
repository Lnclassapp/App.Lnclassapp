# UDR-0155 : Sur téléphone, le cahier de la fiche de cours occupe toute la largeur de l'écran
<!-- index
titre: Fiche de cours pleine largeur sur téléphone
statut: Accepté
adr-lie: —
problematique: Sur téléphone, la fiche de révision dans la page d'une fiche de cours perd 66 à 88 px de chaque côté en marges empilées : les lignes sont courtes et la fiche est longue.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/cours-pleine-largeur` |
| **ADR lié** | — |
| **Remplacé par** | — |

Amende l'UDR-0139 §3.2 (cahier dans la page de la leçon, `data-embedded`) et l'UDR-0137 §4 (téléphone) **sous 640 px seulement**. Au-delà de 640 px, la mise en page ne change pas. Même principe que l'UDR-0154 pour les feuilles.

---

## 1. Contexte

À 390 px, cinq marges s'empilent avant le texte d'une étape de « La méthode » :

| Marge | Valeur |
|---|---|
| Marge de page de l'application (`px-gutter`) | 16 px |
| Cadre gris du cahier (`.sheet-screen[data-embedded]`) | 16 px |
| Page du cahier (`.sheet-page-body`) | 16 px |
| Encadré (`.sheet-box`) | 16 px + 2 px de bord |
| Liste des étapes (`.sheet-steps`) | 22 px |

Le texte d'un encadré commence ainsi à 66 px du bord, et une étape à 88 px. Le pilote a demandé que la fiche de cours remplisse l'écran comme les feuilles. Il a validé l'essai à 390 px le 2026-11-04, sur les captures « après ».

## 2. Décision

Sous 640 px, le cahier affiché dans la colonne de l'application va bord à bord :
- la marge de page est annulée et le cadre gris perd ses coins arrondis ;
- les marges intérieures de la page du cahier, des encadrés et des listes sont réduites ;
- la marge rouge et les lignes Seyès restent.

## 3. Règles d'implémentation

**Où** : seulement dans `app/assets/stylesheets/course_sheet.css`, dans un bloc `@media (max-width: 639px)` placé après les règles `.sheet-screen[data-embedded]`. Aucune vue, aucun contrôleur, aucun style en ligne.

**Pages concernées** : toutes celles qui rendent `.sheet-screen` avec `data-embedded`, sans changement de leur code :
- `catalog/courses/show`, par `catalog/revision_sheets/_sheet` ;
- `catalog/practice_checks/show`.

La fiche ouverte seule (sans `data-embedded`) ne change pas.

**Règles sous 640 px**, toutes préfixées par `.sheet-screen[data-embedded]` :

| Élément | Règle sous 640 px |
|---|---|
| `.sheet-screen[data-embedded]` | `margin-inline: calc(-1 * var(--spacing-gutter)); padding: 12px 0; gap: 12px; border-radius: 0` |
| `.sheet-page-body` | `padding: 16px 12px 16px 16px` (16 px à gauche pour rester à droite de la marge rouge, à 8 px) |
| `.sheet-box` et `.sheet-box[data-tone]` | `padding: 18px 12px 12px` (le bord de 2 px et l'étiquette restent) |
| `.sheet-steps` et `.sheet-practice-questions` | `padding-left: 20px` |
| `.sheet-card` | `padding: 10px` |

**Mesure de conformité**, à 390 px sur « Propriétés de Thalès dans un triangle » :
- le bord gauche de `.sheet-screen[data-embedded]` vaut 0 et son bord droit 390 ;
- le texte du premier encadré commence à 30 px ;
- la première étape de « La méthode » commence à 50 px ;
- `document.documentElement.scrollWidth <= 390`, fiche repliée et dépliée.

À 1280 px, les mesures sont les mêmes qu'avant le chantier.

**États** : inchangés (fiche repliée, dépliée, sans fiche de révision, UDR-0139 §3.6).

**Accessibilité** : inchangée ; « Voir plus » garde sa cible de 48 px.

## 4. Conséquences

- Sur téléphone, chaque ligne d'un encadré gagne environ 70 px : moins de retours à la ligne, une page plus courte (3 396 px → 3 238 px pour Thalès repliée).
- Le cahier n'a plus de cadre gris autour de lui sur téléphone ; il le garde sur ordinateur.
- Interdit : réintroduire une marge de page autour du cahier `data-embedded` sous 640 px.
