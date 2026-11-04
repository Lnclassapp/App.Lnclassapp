# PRD — La fiche de cours remplit l'écran du téléphone

## 1. Contexte

Sur téléphone, la fiche de révision dans la page d'une fiche de cours perd 66 à 88 px de chaque côté avant le texte. Sous 640 px, elle va désormais bord à bord, avec des marges intérieures réduites. Le pilote a validé ces valeurs sur un essai à 390 px. Rien ne change au-delà de 640 px.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | lire la fiche de révision en pleine largeur sur téléphone | — (aucune permission ne change) |
| Teacher | idem | — |

Aucune règle d'autorisation touchée.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Propriétés de Thalès dans un triangle » sur un téléphone de 390 px.
2. Le cahier touche les deux bords de l'écran.
3. Le texte d'un encadré commence à 30 px du bord, une étape de « La méthode » à 50 px.
4. Il déplie la fiche avec « Voir plus » : la page ne défile toujours pas en largeur.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Écran de 640 px ou plus | Mise en page d'avant (cadre, coins arrondis, marges) |
| Formule plus large que l'écran | Défile dans sa ligne, la page ne défile pas en largeur |

## 4. Critères d'acceptation

```gherkin
Étant donné un élève sur un écran de 390 px
Quand il ouvre une fiche de cours qui a une fiche de révision
Alors le cahier va du bord gauche (0) au bord droit (390) de l'écran
Et la page ne défile pas en largeur, fiche repliée comme dépliée

Étant donné un élève sur un écran de 1280 px
Quand il ouvre la même fiche de cours
Alors le cahier garde son cadre et ses marges d'avant
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | — |
| UI | `app/assets/stylesheets/course_sheet.css` (bloc `@media (max-width: 639px)`) |

## 6. Décisions rattachées

- Pas d'ADR : aucune architecture ne bouge.
- UDR-XXXX-fiche-de-cours-pleine-largeur-sur-telephone : amende l'UDR-0139 §3.2 et l'UDR-0137 §4 sous 640 px.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Début du texte d'un encadré à 390 px | 66 px | 30 px | |
| Début d'une étape de « La méthode » à 390 px | 88 px | 50 px | |
| Hauteur de la page de Thalès repliée à 390 px | 3 396 px | moins | |
