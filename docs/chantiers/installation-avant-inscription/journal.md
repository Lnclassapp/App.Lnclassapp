# Journal — Installation proposée avant l'inscription

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-25 | La fiche d'application (`<link rel="manifest">`) n'est déclarée qu'au compte connecté | Sans elle, aucun navigateur ne tient la page pour installable : c'est la seule parade qui vaut pour tous (Samsung Internet, Opera, Edge, Firefox, Chrome) | Amende ADR-0082 §4.1 (encadré dans l'ADR) |
| 2026-11-25 | L'annonce `beforeinstallprompt` est retenue sur toute page, dès le chargement | Chrome et les navigateurs qui le suivent montraient leur invitation sur les pages connectées hors de l'accueil ; l'annonce gardée sert encore la pop-up de l'accueil après une visite Turbo | — |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Le porteur coche `[x]` et écrit sa réponse à la suite.

- [ ] 2026-11-25 · installation-avant-inscription · Avant l'inscription, Lnclass reste-t-il installable depuis le menu du navigateur ? — appliqué : non, la fiche d'application n'est déclarée qu'au compte connecté ; autres : la garder partout et seulement retenir l'annonce (ne couvre que les navigateurs qui suivent Chrome) ; recommandé : non (réversible : une ligne du layout)

## Ce qu'on a appris sur la codebase

**Rapport de cause.**

1. Chaîne : `layouts/application.html.erb` déclare `<link rel="manifest" href="/manifest.json">` sur toute page, publique comprise (ADR-0082 §4.1) ; `pwa.js` enregistre le programme d'arrière-plan partout. La page est donc installable dès `/`. Le navigateur annonce `beforeinstallprompt` ; seul `install_controller.js` l'écoute, et il n'est branché que sur l'accueil connecté (UDR-0078, amendement du 2026-10-07).
2. Cause : `app/views/layouts/application.html.erb` (ligne du `manifest`) rend la page d'entrée installable, et personne n'y retient l'annonce (`install_controller.js` n'écoute qu'une fois connecté) : le navigateur montre alors sa propre invitation ; les navigateurs hors Chrome (Samsung Internet en tête) en montrent une même sans annonce.
3. Trou de test : `pwa_test` CA-1 exigeait la fiche sur une page publique ; les tests de la pop-up ne simulaient l'annonce que sur l'accueil connecté.

Reformulation sans les mots du symptôme : le site se déclarait application à un visiteur que rien ne prenait en charge.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| — | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-25 |
| **PR** | à venir |
| **ADR produits** | amendement d'ADR-0082 §4.1 |
| **UDR produits** | — |
