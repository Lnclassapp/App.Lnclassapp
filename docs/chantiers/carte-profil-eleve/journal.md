# Journal — Carte de profil de l'élève dans la barre latérale

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Sigle de l'établissement plutôt que son nom | Le nom entier passait sur deux lignes : carte plus haute que celle de l'enseignant (capture à 1280 px) | Non (UDR-0132 §3.1) |
| 2026-10-30 | Teinte des initiales tirée de l'identifiant public pour l'élève | Même couleur que l'avatar de la barre du haut | Non |
| 2026-10-30 | Le détail du shell garde le nom de l'établissement ; le sigle part à part | « Mon compte » au téléphone lit ce détail : il ne doit pas changer | Non |

## Ce qui a dérapé

- La skill `/feature` s'arrête après le plan et attend « Je lance les lots ? » ; la demande allait jusqu'à la PR, sans porteur joignable en direct. Le cadrage, le grill et le code ont été faits dans la même session, d'après la demande écrite.
- Le code de la vue a été écrit avant les tests ; le rouge a été prouvé après coup en retirant le code (6 tests rouges sur 7).
- Premier jet avec le nom de l'établissement : vu trop haut en capture, corrigé avec le sigle.

## Ce qu'on a appris sur la codebase

- Les tests système demandent `yarn build` et `yarn build:css` dans un conteneur neuf (sinon `application.css` introuvable).
- Quatre tests (accueil élève, en-tête élève, photo de profil) affirmaient l'absence de carte : ils affirment maintenant sa présence.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| — | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 |
| **PR** | voir la PR de `feature/carte-profil-eleve` |
| **ADR produits** | aucun |
| **UDR produits** | UDR-0132 amendée (§3.1) |
