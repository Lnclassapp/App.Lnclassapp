# Journal — Accès complet gratuit pendant la bêta

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Réglage = constante `BETA_OPEN_ACCESS` de l'offre, lue par l'accès | le plus simple ; le domaine reste pur | oui, ADR acces-beta |
| 2026-11-12 | Le booléen devient une date, `BETA_ENDS_ON` (nil = ouverte) ; les 7 jours partent de la fin de bêta | réponse du porteur ci-dessous ; la date de fin n'est pas connue, un seul réglage reste | oui, ADR acces-beta |
| 2026-11-12 | Le bandeau reste rendu par l'accueil ; il se masque lui-même en bêta | retirer l'appel aurait fait deux points à rallumer | oui, UDR acces-beta |
| 2026-11-12 | Mon abonnement garde la saisie de code et les points relais en bêta | une carte déjà achetée doit pouvoir s'activer | non |

## À trancher

- [x] 2026-11-12 · acces-beta · À la fin de la bêta, les élèves inscrits pendant la bêta sont bloqués aussitôt (leurs 7 jours sont écoulés) : leur redonner 7 jours à partir de la fin de bêta ? — appliqué : rien (règle d'origine) ; autres : déplacer `Offer::LAUNCH_ON` à la date de fin de bêta en même temps que `BETA_OPEN_ACCESS = false` ; recommandé : déplacer `LAUNCH_ON` — **porteur : déplacer `LAUNCH_ON` à la fin de la bêta.** Fait : `Offer::BETA_ENDS_ON` porte la date de fin, les 7 jours partent d'elle.
- [x] 2026-11-12 · acces-beta · Mon abonnement reste joignable à la main pendant la bêta, avec points relais et saisie de code — appliqué : garder (une carte achetée s'active) ; autres : masquer la vente en bêta ; recommandé : garder — **porteur : garder les points relais et la saisie de code.**

## Retouches

- …

## Ce qui a dérapé

- Les tests ont d'abord échoué faute d'assets compilés (`yarn build && yarn build:css` manquants dans le conteneur), puis par interblocage PostgreSQL après l'arrêt d'une première série : relancés avec `PARALLEL_WORKERS=1`.

## Ce qu'on a appris sur la codebase

- Le blocage n'a qu'une source : `Access#blocked?`, lu par les deux use cases ; aucun écran élève ne lie Mon abonnement hors bandeau et refus.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Date de fin de bêta | décision commerciale | poser `Offer::BETA_ENDS_ON` (une ligne, PR) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-12 |
| **PR** | (voir PR `feature/acces-beta`) |
| **ADR produits** | ADR-XXXX-acces-beta-reglage-unique |
| **UDR produits** | UDR-XXXX-acces-beta-sans-abonnement |
