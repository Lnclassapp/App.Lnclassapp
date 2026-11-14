---
name: test-ecrans
description: Teste les écrans Lnclass demandés (Develop, Staging ou production) par captures à 390, 768 et 1440 px en thème clair et sombre, puis rend des recommandations classées par gravité d'après la skill lnclass-design-system. Ne code pas ; peut proposer une /retouche. Utilise-la quand l'utilisateur tape /test-ecrans, ou demande de tester, vérifier ou auditer des écrans, pages ou le rendu mobile et le thème sombre.
---

# Test des écrans

Tu constates et tu recommandes. **Tu ne modifies aucun fichier de l'application.** Argument : `<cible> <pages…>` — cible `develop`, `staging` ou `prod` (défaut `staging`) ; pages : chemins (`/`, `/login`, `/teams/imports`), ou un rôle du jeu standard (`docs/recette/<rôle>.md` donne ses écrans).

| Cible | Adresse |
|---|---|
| `develop` | `https://app-develop.lnclass.com` |
| `staging` | `https://app-staging.lnclass.com` |
| `prod` | `https://lnclass.com` — **lecture seule** : pages publiques, ou connectée sans aucun envoi de formulaire |

## 1. Accès

- Pages publiques : aucun compte.
- Pages connectées : comptes du jeu standard (élève, enseignant, direction : PIN public `2468`, listés dans `docs/recette/README.md`). Compte équipe : `LNCLASS_TEAM_CONTACT` / `LNCLASS_TEAM_PIN` ; variable absente → donne son nom, saute les pages équipe. Le code à six chiffres du compte équipe ne vient que du porteur, envoyé par lui (CLAUDE.md) ; sans lui, saute ces pages.
- Jamais un contact, PIN ou code dans une capture, un fichier ou le chat : connecte-toi, puis capture. Navigation seule, aucun clic sur une action qui écrit.

## 2. Captures

Playwright préinstallé (`require('playwright')`). Script et images dans le scratchpad, **jamais commités**, envoyés au porteur (SendUserFile).

Pour chaque page : 3 largeurs × 2 thèmes = 6 captures pleine page.

- Largeurs : 390×844, 768×1024, 1440×900 ; `deviceScaleFactor: 2` (image regardée par une personne).
- Thème : `colorScheme: 'light'` puis `'dark'` (`page.emulateMedia`). Si l'écran propose un réglage de thème, vérifie aussi qu'il l'emporte.
- Mesure en même temps, par page et largeur : défilement horizontal (`scrollWidth > clientWidth`), éléments dont le bas dépasse l'écran sans défilement possible, cibles tactiles < 44 px à 390 px, erreurs console, requêtes en échec, textes non traduits (clé `translation missing`).
- Menus et modales : ouvre ceux de la page (menu ⋮, navigation) et capture-les à 390 px et 1440 px.

Nomme `<page>-<largeur>-<clair|sombre>.png`.

## 3. Analyse

Charge la skill `anthropic-skills:lnclass-design-system` et compare : tokens (couleurs, contrastes dans les deux thèmes), en-tête et logo, grille, listes, dates, boutons, espacements. Regarde chaque image (Read), ne te fie pas aux seules mesures. Pour l'accueil, la matière et la leçon de l'élève, l'UDR « écrans minimalistes, style Wave » (`docs/decisions/udr/`) prime sur la charte : pas de carte « Prochain exercice », pas de section vide, pas de barre de navigation sur la matière et la leçon.

Gravité :

| Niveau | Critère |
|---|---|
| **Bloquant** | Contenu illisible ou inaccessible : texte coupé, débordement horizontal, contraste insuffisant, action hors d'atteinte, erreur affichée |
| **Majeur** | Écart net au design system, ou thème sombre cassé (fond clair résiduel, icône invisible) |
| **Mineur** | Espacement, alignement, cible tactile limite, incohérence d'un libellé |
| **Suggestion** | Amélioration sans défaut |

## 4. Rendu

Un tableau par gravité : `page · largeur · thème · constat · recommandation · capture`. Pas de détail technique sauf demande. En tête : cible, pages, nombre de captures, compte par gravité.

Pour chaque constat corrigeable en retouche (libellé, espacement, classe CSS, icône, clé I18n — voir `/retouche`), propose-le en une ligne : `/retouche <slug>`. Les autres (règle, route, droit, motif nouveau) : indique le cycle (`/bugfix`, `/feature`). **Ne lance rien.** Une session lancée par une autre écrit les propositions dans `## À trancher` du journal du chantier.

## Fin

Une ligne : `N pages · M captures · B bloquants / J majeurs / m mineurs` et le chemin complet du dossier des captures.
