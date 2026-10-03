# PRD — Mode sombre de l'application

## 1. Contexte

Voir le [memo](memo.md). Décision du porteur du 2026-10-03 : « ajoute le mode sombre ». Le mode suit le réglage du téléphone.

## 2. Acteurs et permissions

| Acteur | Ce qu'il voit |
|---|---|
| Tout visiteur, tout rôle connecté | Les mêmes pages ; en thème sombre, les couleurs des tokens en version sombre |

Aucune permission ne change.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève a réglé son téléphone en thème sombre.
2. Il ouvre Lnclass : le fond est sombre dès le premier affichage, le texte clair, les boutons et les badges lisibles.
3. Il ouvre une modale : un voile sombre couvre la page.

### Chemins alternatifs et erreurs

- Le téléphone est en thème clair : rien ne change.
- Il imprime une page (codes de secours) : la page imprimée est claire.

## 4. Critères d'acceptation

```gherkin
# MS-01 — Chaque couleur a sa valeur sombre
Étant donné la feuille de style de l'application
Alors chaque couleur littérale du @theme a sa valeur dans le bloc sombre, et le bloc ne redéfinit rien d'autre

# MS-02 — Lisible dans les deux modes
Étant donné les paires texte/fond qu'emploient les composants (boutons, badges, toasts, textes sur surfaces)
Alors chacune garde un contraste d'au moins 4,5:1, en clair comme en sombre
Et le contour de focus garde au moins 3:1 sur les surfaces sombres

# MS-03 — Le téléphone en thème sombre reçoit l'interface sombre
Étant donné un navigateur en thème sombre sur /design
Alors le fond de la page est le papier sombre, le texte l'encre claire, et la marque son bleu profond

# MS-04 — Une page imprimée reste claire
Étant donné un navigateur en thème sombre qui imprime
Alors le fond de la page est le papier clair

# MS-05 — Le voile d'une modale reste sombre, les ombres aussi
Étant donné le bloc sombre
Alors le voile d'une modale est noir translucide et les trois ombres sont redéfinies

# MS-06 — Pas d'éclair blanc au chargement
Étant donné le gabarit de l'application
Alors il déclare les deux thèmes au navigateur (meta color-scheme)

# MS-07 — Aucun écran ne contourne les tokens
Étant donné les vues, les helpers et le JavaScript
Alors aucune variante `dark:` n'y figure (le garde du design system existant)
```

## 5. Modélisation préliminaire

| Couche | Ce qui change |
|---|---|
| Domaine, infrastructure, contrôleurs | rien |
| UI | `application.tailwind.css` (bloc sombre, hors couche, écran seulement) ; `layouts/application` (meta `color-scheme`) |
| Tests | `test/design/dark_mode_test.rb` (MS-01, 02, 04 côté feuille, 05, 06) ; `test/system/design_system_test.rb` (MS-03, MS-04) ; `test/design/design_tokens_test.rb` (MS-07, existant) |

## 6. Décisions rattachées

- [UDR-0065](../../decisions/udr/0065-mode-sombre-par-les-tokens.md) — mode sombre par les tokens.
- [UDR-0005](../../decisions/udr/0005-design-system-fondateur.md), amendement du 2026-10-03 — sa décision 4 (« pas de mode sombre en V1 ») est levée ; l'interdiction de `dark:` reste.
- Pas d'ADR : aucun port, aucune table, aucune dépendance. Aucune ressource tierce (ADR-0049), poids négligeable (ADR-0051).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Vues modifiées | — | 0 | 0 |
| Paires de contraste vérifiées (clair + sombre) | 0 | toutes ≥ seuil | 25 en clair, 27 en sombre, toutes au-dessus du seuil |
| Durée ajoutée à la suite système | — | ≤ 15 s (ADR-0069 §9) | 1,3 s |
