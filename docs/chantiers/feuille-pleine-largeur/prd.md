# PRD — La feuille remplit l'écran du téléphone

## 1. Contexte

Sur téléphone, la feuille perd 36 à 51 px de chaque côté. Sous 640 px, elle va désormais bord à bord, avec des marges intérieures réduites (valeurs validées par le pilote sur un essai à 390 px). Rien ne change au-delà de 640 px.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | lire et remplir ses feuilles en pleine largeur sur téléphone | — (aucune permission ne change) |
| Teacher | lire une feuille en pleine largeur sur téléphone | — |

Aucune règle d'autorisation touchée.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre une feuille de « Propriétés de Thalès dans un triangle » sur un téléphone de 390 px : l'épreuve touche les deux bords de l'écran, le texte commence à 12 px.
2. Il clique « Commencer » : la feuille à remplir touche les deux bords, l'énoncé du premier exercice commence à 21 px au plus.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Écran de 640 px ou plus | Mise en page d'avant (fond gris, ombre, marges) |
| Formule plus large que l'écran | Défile dans sa case, la page ne défile pas en largeur |

## 4. Critères d'acceptation

```gherkin
Étant donné un élève sur un écran de 390 px
Quand il ouvre l'épreuve d'une feuille, puis la feuille à remplir
Alors la feuille blanche va du bord gauche (0) au bord droit (390) de l'écran
Et la page ne défile pas en largeur

Étant donné un élève qui n'a jamais ouvert la feuille « Prépare devoirs n°1 »
Quand il lit son sujet
Alors le bouton sous l'épreuve dit « Commencer l'exercice »

Étant donné un élève qui a déjà vérifié un exercice de la feuille
Quand il relit son sujet
Alors le bouton sous l'épreuve dit encore « Commencer l'exercice »
Et « Continuer Prépare devoirs » n'apparaît nulle part

Étant donné un élève sur un écran de 1280 px
Quand il ouvre la même feuille
Alors la feuille garde ses marges et son ombre d'avant
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | — |
| UI | `app/assets/stylesheets/prepare_sheet.css` (bloc `@media (max-width: 639px)`) |

## 6. Décisions rattachées

- Pas d'ADR : aucune architecture ne bouge.
- UDR-0154 — amende UDR-0149 §3 et UDR-0152 §3 sous 640 px.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Début du texte de l'épreuve à 390 px | 36 px | 12 px | |
| Début de l'énoncé de la feuille à remplir à 390 px | 51 px | ≤ 21 px | |
