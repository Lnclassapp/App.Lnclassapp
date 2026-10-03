# Journal — Politique de cache

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Protocole

Rejouable par le challenger sans poser de question. Les deux premiers scripts n'ont besoin d'aucun compte ni d'aucune base : ils mesurent la production depuis la machine qui les lance. **Pour le lot R, ils doivent être lancés depuis la Côte d'Ivoire.**

```bash
# 1. Trajet : requêtes jusqu'au serveur comparées au cache de Cloudflare (Ruby seul, sans Rails)
ruby script/perf/measure_network.rb                      # https://lnclass.com ; une autre URL en argument
# 2. Navigateur : premier octet, DOMContentLoaded et load, en première visite et en visite répétée
NODE_PATH=$(npm root -g) node script/perf/measure_browser.cjs
# 3. Requêtes en série par parcours : base de développement, comptes de db/seeds (PIN 2468), mode production
bin/rails db:prepare
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=warn \
BUCKET_NAME=bench BUCKET_ENDPOINT=http://127.0.0.1:9 BUCKET_ACCESS_KEY_ID=x BUCKET_SECRET_ACCESS_KEY=x \
DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_development<suffixe> \
bin/rails runner script/perf/count_round_trips.rb
```

- **Trois exécutions** de chaque script, et la médiane des 3 par ligne et par colonne. `PERF_RUNS` fixe le nombre de requêtes (30 par défaut) ou de visites (10 par défaut).
- `measure_network.rb` : 3 requêtes de chauffe, puis 30 mesurées sur **une connexion gardée ouverte**, comme une navigation Turbo. La feuille de style sert de témoin du cache de Cloudflare : son nom est lu dans `/login`, et la chauffe la met en `HIT`. « Hors serveur » = durée − `x-runtime`. Le PoP de Cloudflare se lit à la fin de `cf-ray`.
- `measure_browser.cjs` : Chromium headless (Playwright global, `/opt/pw-browsers`). Un navigateur neuf par visite pour la « première visite », puis une seconde visite dans le même navigateur. Ce sont les valeurs de la Navigation Timing (ms depuis le début de la navigation). `HTTPS_PROXY` est transmis à Chromium.
- `count_round_trips.rb` : `Integration::Session` simule ce que fait Turbo 8. Une visite envoie `X-Turbo-Request-Id`, fetch suit les redirections, `turbo-visit-control: reload` recharge le document, et chaque `<turbo-frame src>` est demandé avec `Turbo-Frame`. Le compte ne dépend ni de la machine ni du réseau ; le temps serveur affiché est local. Une passe de chauffe précède la mesure. Chaque parcours se connecte depuis une adresse privée tirée au hasard, à cause de `rate_limit` (5 connexions par minute et par adresse).
- **Conteneur de mesure** : Chromium n'y faisait confiance à aucune autorité (`ERR_CERT_AUTHORITY_INVALID`), parce que sa base NSS était vide. On y a importé le paquet d'autorités du conteneur (`certutil -A -t "C,,"`, paquet `libnss3-tools`). La vérification TLS reste active.

## Où part le temps

### Côté serveur : presque rien

- **Railway, production** (`http-response-time`, GET 200, 96 h) : p50 19 et 25 ms, p95 102 et 100 ms, p99 194 et 223 ms, selon les deux tranches. Sur 7 jours, toutes réponses GET : p50 de 6 à 15 ms. La première tranche (2026-09-29) fait exception, avec des p90 à 15 s et 196 réponses 5xx, autour du premier déploiement.
- **Railway, Develop** (GET 200, 7 jours) : p50 39 à 45 ms, p95 195 à 224 ms, p99 jusqu'à 584 ms. Dans les journaux HTTP de Develop, `/` atteint 394 ms en p95, `/teams/schools` a un p50 de 125 ms, et `POST /session` dure de 326 à 451 ms (bcrypt). Develop est plus lent que la production, mais reste loin de ce que le client attend.
- **`x-runtime` des pages publiques** en production : `/up` 1,7 ms, `/login` 6,4 ms, `/` 8,7 ms (médianes de `measure_network.rb`).

### Côté réseau : presque tout

`measure_network.rb`, 3 exécutions, PoP `ORD`, edge Railway `ord1` (p50 en ms) :

| Cible | Exéc. 1 | Exéc. 2 | Exéc. 3 | **Médiane** | Serveur p50 |
|---|--:|--:|--:|--:|--:|
| `/up` (serveur) | 247,2 | 252,4 | 248,9 | **248,9** | 1,7 |
| `/login` (serveur) | 256,8 | 260,8 | 256,5 | **256,8** | 6,4 |
| `/` (serveur) | 256,5 | 263,1 | 261,2 | **261,2** | 8,7 |
| feuille de style (`HIT` Cloudflare) | 20,8 | 27,5 | 24,4 | **24,4** | — |
| connexion neuve, `/login` | 423,9 | 348,1 | 318,6 | **348,1** | 5,3 |
| **Surcoût du serveur sur le cache** | 227 | 227 | 227 | **227** | |

- Les durées journalisées par Railway pour ces mêmes requêtes (repérées par l'agent `curl/8.5.0` à 20:03–20:05 UTC) vont de **10 à 28 ms**. Le proxy de Railway mesure depuis la région de l'application : le trajet entre l'edge et Singapour n'y figure pas.
- Avec `curl`, sur un autre PoP (`IAD`, edge `iad1`), on observe les mêmes ordres de grandeur : environ 330 ms entre la fin du TLS et le premier octet pour une page servie par le serveur, et environ 50 ms pour un asset en `HIT`.

`measure_browser.cjs`, 3 exécutions × 10 visites (médianes, ms) :

| Page | Visite | Premier octet | DOMContentLoaded | load | Ressources hors cache |
|---|---|--:|--:|--:|--:|
| `/` | première (cache vide) | 395 | 782 | 943 | 10 |
| `/` | répétée (cache chaud) | **360** | 403 | **403** | 0 |
| `/login` | première (cache vide) | 369 | 871 | 875 | 6 |
| `/login` | répétée (cache chaud) | **358** | 393 | **393** | 0 |

Sur une visite répétée, **89 à 91 % du chargement est l'attente du premier octet**, et le serveur en occupe moins de 9 ms. Sur une première visite, 390 à 550 ms de plus passent après le premier octet : téléchargement et analyse des assets.

### Requêtes en série par parcours

`count_round_trips.rb`, 3 exécutions identiques :

| Parcours | Requêtes | Dont en série | Détail |
|---|--:|--:|---|
| Connexion élève | 4 | 4 | `POST /session` → 303 · `GET /students` (Turbo) · `GET /students` (rechargement : `turbo-visit-control`) · `GET /students` [`student_home_recent_activity`] |
| Connexion enseignant | 3 | 3 | `POST /session` → 303 · `GET /teachers` · `GET /teachers` (rechargement) |
| Ouvrir `lnclass.com` connecté (élève) | 3 | 3 | `GET /` → 302 · `GET /students` · frame de l'activité |
| Clic vers l'accueil élève | 2 | 2 | `GET /students` · frame de l'activité |
| Clic vers l'accueil enseignant | 1 | 1 | `GET /teachers` |
| Clic vers l'accueil équipe | 2 | 2 | `GET /teams` · frame `team_home_recent_content` |
| Clic vers le catalogue (élève) | 1 | 1 | `GET /courses` |
| Déconnexion | 3 | 3 | `DELETE /session` → 303 · `GET /` · `GET /` (rechargement) |

- Le rechargement forcé vient de l'[ADR-0049, amendement du 2026-09-26](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md#amendement-du-2026-09-26--un-nonce-par-session). Une nouvelle session tire un nouveau nonce CSP, et la page d'arrivée d'une visite Turbo recharge le document pour l'appliquer. Le coût : une requête et un rendu complet de plus, à chaque connexion, inscription et déconnexion.
- `POST /session` coûte ~290 ms côté serveur (bcrypt, `Repositories::Identity::UserRepository`), c'est-à-dire autant qu'un aller-retour. Hors périmètre (ADR-0025).

### En-têtes de cache relevés en production

| Réponse | `cache-control` | Cloudflare | Thruster (`x-cache`) |
|---|---|---|---|
| HTML (`/`, `/login`, `/up`) | `max-age=0, private, must-revalidate` | `DYNAMIC` | `miss` |
| Assets digérés (`/assets/*-<digest>.*`) | `public, max-age=31556952` (un an, sans `immutable`) | `MISS` au premier appel d'un PoP, puis `HIT` | `hit` |
| `/icon.png`, `/favicon.ico` | idem (règle de `config.public_file_server.headers`) | idem | — |

Le HTML ne porte pas d'`ETag` utile : le nonce CSP (par session) et le jeton CSRF le rendent propre à chaque session.

### Turbo 8.0.23 (source lue)

- `LinkPrefetchObserver` n'écoute que `mouseenter`, avec un délai de 100 ms (`PREFETCH_DELAY`) et une durée de vie de 10 s. Un clic vide le préchargement en attente (`prefetchCache.clear()`), donc pas de requête en double au toucher, mais pas de gain non plus.
- L'aperçu des pages déjà vues est actif (10 instantanés). Seules les pages `secret_response` en sont exclues (ADR-0031).

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Mesurer côté client, en production, sans compte | Railway ne voit pas le trajet ; les pages publiques suffisent à mesurer le trajet, qui ne dépend pas de la page | non |
| 2026-10-03 | Compter les requêtes en série par parcours, en local | Le compte ne dépend ni de la machine ni du lieu : c'est la seule métrique que le challenger retrouve à l'identique partout | non |
| 2026-10-03 | Aucun cache serveur dans ce chantier | Le serveur pèse moins de 5 % de l'attente | ADR-0075 (proposé) |
| 2026-10-03 | Scripts dans `script/perf/`, comme ceux de `cache-ecrans-lourds` | Ils ne doivent jamais tourner dans la suite, et `measure_network.rb` doit se lancer avec Ruby seul, depuis n'importe quel poste | non |
| 2026-10-03 | `count_round_trips.rb` lit le balisage réel (`data-turbo` du formulaire de connexion, lien ou formulaire de déconnexion) | Le banc doit suivre un changement de balisage sans être réécrit | non |
| 2026-10-03 | **Porteur** : lots A et B refusés, on garde les UDR-0010, 0018 et l'ADR-0049 | Les décisions d'interface (frame différé) et de sécurité (rechargement à chaque nouvelle session) priment sur un aller-retour | ADR-0075 §4.2 : le compte d'aujourd'hui devient un plafond |
| 2026-10-03 | **Porteur** : région étudiée, Develop et Staging d'abord ; Early Hints et Tiered Cache activés par lui | Seuls leviers restants, tous deux hors du dépôt | ADR-0075 §4.3 |
| 2026-10-03 | Lot C fermé | Sa clause de fermeture s'applique : WebKit n'est pas installable dans le conteneur, et Chromium ne revalide pas les sous-ressources | non |

## Leviers abandonnés, et pourquoi

| Levier | Gain mesuré ou calculé | Pourquoi il est abandonné |
|---|---|---|
| Cache serveur (Solid Cache, fragments, ETag) pour la latence | ≤ 9 ms sur 360 ms d'attente | Le calcul n'est pas le goulot. Un 304 paie le même aller-retour, et le HTML est propre à chaque session |
| Cache du HTML chez Cloudflare | un aller-retour par page publique | Il servirait le jeton CSRF, le nonce et le cookie d'une session à une autre personne |
| Préchargement au toucher | 0 à 50 ms par clic | Borné par la durée d'un appui moins les 100 ms de Turbo ; chaque défilement sur un lien coûterait des données mobiles |
| A — activité récente rendue avec la page | −1 requête en série sur les accueils élève et équipe (≈ −250 ms au point de mesure) | Refusé par le porteur : l'UDR-0010 et l'UDR-0018 gardent le frame différé |
| B — connexion et déconnexion hors Turbo | −1 requête en série et un rendu de moins par connexion | Refusé par le porteur : l'ADR-0049 garde le rechargement à chaque nouvelle session |
| C — `immutable` | un aller-retour vers Cloudflare au rechargement, sous Safari et Firefox seulement | Non mesurable dans le conteneur (pas de WebKit) |
| Supprimer la redirection de `/` pour une personne connectée | −1 requête à chaque ouverture | Change l'adresse de l'accueil : c'est une `feature` |

## Ce qui a dérapé

- `bin/rails runner` en environnement de développement plantait dès la deuxième requête de `Integration::Session` (`ActiveSupport::ExecutionContext.to_h` vaut `nil` dans les tags de requête SQL). Contourné en mode production, comme `measure_screens.rb`. C'est d'ailleurs plus fidèle : pas de Debugbar, gabarits compilés.
- Ruby 3.4.9 absent du conteneur (seuls 3.1 à 3.3 sont installés). Compilé par `rbenv install`, environ 10 minutes.

- **Un changement de région a été préparé sur Develop pendant le chantier** : patch non appliqué, créé le 2026-10-03 à 20:36 UTC, qui déplace **l'application seule** en `europe-west4-drams3a`. Repéré parce que `describe-environment` de Railway montre la configuration **avec** les changements en attente. Vérification : le `x-runtime` de Develop restait à 3–15 ms, donc rien n'avait bougé. Le patch n'a pas été touché ; le porteur est prévenu de ne pas l'appliquer sans PostgreSQL (plan, lot R).

## Ce qu'on a appris sur la codebase

- La production, Staging et Develop tournent tous en `asia-southeast1` (Singapour), un réplica chacun, PostgreSQL au même endroit. Cloudflare proxifie `lnclass.com`, `app-develop.lnclass.com` et `app-staging.lnclass.com`.
- `describe-environment` de Railway affiche la configuration avec les changements **en attente** : une région qui y apparaît n'est pas forcément appliquée. `get-staged-changes` fait la différence.
- Les métriques de Railway (`http-response-time`, `totalDuration` des journaux HTTP) excluent le trajet entre l'edge et la région. Une latence vécue de 250 à 360 ms y apparaît comme 10 à 28 ms.
- Sur 7 jours, 84 % des réponses de production sont des 4xx (9 147 sur 10 893). Dans les journaux consultés, ce sont des robots qui cherchent `wp-admin`, `.env` ou `phpinfo.php` ; elles coûtent quelques ms chacune. Non analysé plus avant : sans effet sur ce chantier.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `/` redirige une personne connectée vers son accueil (+1 requête en série à chaque ouverture) | Changer l'adresse de l'accueil est une `feature` | à ouvrir si le porteur le souhaite |
| Mise en veille de Develop et Staging | Réglage de recette, non mesuré | à voir avec le porteur |
| Mesure depuis Abidjan | Aucun point de mesure en Côte d'Ivoire depuis le conteneur | question 1 du memo, bloquante pour le lot R |

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | [ADR-0075](../../decisions/adr/0075-politique-de-cache-reglee-sur-les-allers-retours.md) (proposé) |
| **UDR produits** | — |
