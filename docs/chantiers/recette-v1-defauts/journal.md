# Journal — Défauts de la recette V1

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | `/join` vérifie le code avec `JoinPreviewQuery`, la requête de `/c/<code>` | Une seule définition de « code qui mène à une classe » : `/join` n'en dit jamais plus que `/c/` | Non — amendement UDR-0009 |
| 2026-09-28 | Même compteur de débit que `/c/<code>` (`scope: "classroom/joins"`), sur l'envoi seulement | Sans cela, `/join` doublait le débit d'énumération (ID-07) ; afficher l'écran ne cherche rien | Non |
| 2026-09-28 | Message du code inconnu = titre et description de la 404 de `/c/` ; message de débit propre à l'écran, au tutoiement | Même texte que `/c/` ; `errors.codes.rate_limited` vouvoie | Non |
| 2026-09-28 | Pages d'erreur en CSS en ligne | Servies en amont du middleware CSP : aucun en-tête CSP (vérifié) | Non |

## Ce qui a dérapé

- La recette décrivait un écran resté sur `/join`, vide. En Chromium local, Turbo affiche la 404 de `/c/zzz99` : le symptôme exact dépend du navigateur et du réseau. Le test rouge vise ce qui manque dans les deux cas : le message sous le champ.

## Ce qu'on a appris sur la codebase

- `rate_limit` accepte `scope:` (Rails 8.1) : deux contrôleurs partagent un compteur par la même clé de cache.
- `public/*.html` passe par `ActionDispatch::Static` / `ShowExceptions`, avant `ContentSecurityPolicy::Middleware`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| D3 : `style-src-attr 'unsafe-inline'` à consigner dans un ADR | Hors périmètre du bugfix | à ouvrir |
