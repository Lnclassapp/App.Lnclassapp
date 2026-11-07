# Journal — La fiche de cours remplit l'écran du téléphone

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | Règle limitée au cahier `data-embedded` (fiche de cours, « Je m'entraîne ») | la fiche ouverte seule va déjà bord à bord sous 1 000 px | non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Rien de notable. La méthode de `feuille-pleine-largeur` (essai par CSS injecté, captures avant / après, choix du pilote, puis chantier) a évité tout aller-retour.
- Le pilote a dit préférer « la 3e capture » : c'était une capture « après » du même essai, aucune valeur à changer.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `course_sheet.css` a déjà un bloc `@media (max-width: 999px)` qui met `.sheet-screen` bord à bord, mais `.sheet-screen[data-embedded]` (déclaré après) le remet à `margin-inline: 0` : un nouveau bloc téléphone doit venir après les règles `data-embedded`.
- `course_sheet/reading.css` est importé en tête de `course_sheet.css` : ses règles passent avant, et les préfixes `.sheet-screen[data-embedded]` suffisent à les dominer.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Revues (sécurité, pannes, tests) non lancées | 29 lignes de CSS et 5 de test, sans use case, policy, route ni téléversement | — |
| « Je m'entraîne » non ouvert par le challenger | la règle est la même (`data-embedded`) ; `practice_in_sheet_test` à 390 px reste vert | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-04 |
| **PR** | [#471](https://github.com/Lnclassapp/App.Lnclassapp/pull/471) vers `Develop` |
| **ADR produits** | — |
| **UDR produits** | UDR-0155 (amende UDR-0139 §3.2 et UDR-0137 §4 sous 640 px) |
