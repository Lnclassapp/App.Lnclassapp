# ADR-0076 : La politique de cache se règle sur les allers-retours jusqu'au serveur, pas sur le temps serveur

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/politique-cache`](../../chantiers/politique-cache/memo.md) |
| **Complète** | [ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md) (budgets de temps serveur) · [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le 2026-10-03, le porteur trouve l'application lente : les pages mettent plus de 500 ms à charger. Il demande une révision de la politique de cache.

Jusqu'ici, le cache n'avait été pensé que côté serveur. L'ADR-0062 a refusé puis admis un cache de 5 minutes pour le pilotage « année ». L'ADR-0067 a fixé des budgets de temps serveur et prescrit l'ordre des leviers : « index d'abord, requête réécrite ensuite, cache en dernier recours ». Le chantier `politique-cache` a mesuré ce que la personne attend vraiment, depuis le navigateur :

- **Le serveur répond en 2 à 9 ms** sur les pages publiques. Railway mesure un p50 de 19 à 25 ms sur tout le trafic de production.
- **Une page déjà visitée met 393 à 403 ms à charger**, dont **358 à 360 ms d'attente du premier octet**, au point de mesure (Chicago). Une requête qui va jusqu'au serveur coûte **227 ms de plus** qu'une réponse servie par le cache de Cloudflare (251 contre 24 ms).
- L'application et PostgreSQL tournent à **Singapour** (`asia-southeast1`), loin des utilisateurs ivoiriens.
- **Les parcours enchaînent des requêtes en série** : 4 pour la connexion d'un élève (dont un rechargement complet forcé par l'ADR-0049 et un frame différé), 3 pour l'ouverture de `lnclass.com` quand on est déjà connecté, 2 pour un clic vers l'accueil élève ou équipe.
- **Railway ne voit pas ce trajet** : il journalise 10 à 28 ms pour des requêtes que le client a attendues ~260 ms.

Un cache serveur ne retire que les 2 à 9 ms du calcul. Ce qui coûte, c'est chaque aller-retour jusqu'à Singapour.

## 2. Moteurs de décision

1. **Ce que la personne attend**, c'est le nombre de requêtes en série multiplié par le trajet jusqu'au serveur, plus le calcul. On mesure côté client, pas dans Railway.
2. **Sécurité** : aucune page personnelle, aucun jeton CSRF, aucun nonce CSP, aucun secret dans un cache partagé ([ADR-0031](./0031-second-facteur-totp-pour-l-equipe.md), [ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [ADR-0050](./0050-authentification-et-session.md)).
3. Ne pas ajouter de complexité sans gain mesuré : un cache serveur garde l'ordre de l'ADR-0067.
4. Aucun service tiers ajouté au navigateur (ADR-0049) : Cloudflare est déjà le DNS et le proxy de `lnclass.com`.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Cache serveur généralisé : fragments, Solid Cache, `fresh_when` / ETag | C'est ce que « politique de cache » évoque d'abord, et les outils sont en place (Solid Cache) | Le calcul pèse 2 à 9 ms sur 360. Un 304 paie quand même l'aller-retour. Le nonce et le jeton CSRF rendent chaque HTML propre à une session. Le gain serait inférieur au bruit de la mesure |
| B — Cache du HTML chez Cloudflare, au moins pour les pages publiques | Il supprimerait l'aller-retour des visiteurs de `/` et `/login` | Ces pages posent le cookie de session et portent le jeton CSRF et le nonce de la session : un cache partagé les donnerait à une autre personne. Contraire au moteur 2 |
| **C — Un plafond de requêtes en série par parcours, le cache réservé à ce qui ne dépend pas de la personne (assets), et un serveur rapproché des utilisateurs** | Il agit sur le coût réel : chaque requête en série retirée vaut un aller-retour, et rapprocher la région réduit tous les allers-retours | **Retenue** |
| D — Statu quo | Rien à faire | La lenteur constatée par le porteur reste entière, et invisible dans Railway |

## 4. Décision

> **Nous mesurons la vitesse d'une page en requêtes en série jusqu'au serveur et en millisecondes vues du navigateur, pas en temps serveur.** Le cache sert à éviter un aller-retour, jamais à gagner quelques millisecondes de calcul sur une page personnelle.

### 4.1 Ce que chaque couche garde

| Couche | Ce qu'elle garde | Ce qu'elle ne garde jamais |
|---|---|---|
| **Navigateur** | Les assets digérés et les fichiers de `public/` : `public, max-age=31536000` (un an). Pas d'`immutable` : son gain (Safari et Firefox au rechargement) n'a pas pu être mesuré, lot C fermé | Le HTML : `private, max-age=0, must-revalidate` (le défaut de Rails). Les écrans secrets : `no-store` (ADR-0031) |
| **Cloudflare** | Les mêmes assets, en périphérie. *Early Hints* et *Tiered Cache* activés dans la zone (lot D, action du porteur) | Le HTML, même public (option B refusée) : `cf-cache-status: DYNAMIC` |
| **Turbo** | Les 10 dernières pages vues, en aperçu, et le préchargement au survol (Turbo 8, réglages par défaut, conservés) | Les pages `secret_response` (ADR-0031). Pas de préchargement au toucher |
| **Serveur** (Solid Cache) | Les seuls agrégats qui dépassent leur budget de l'ADR-0067 malgré index et requêtes réécrites (aujourd'hui : le pilotage « année », 5 minutes) | Aucun fragment ni ETag destiné à gagner de la latence |

### 4.2 Plafond de requêtes en série

Le porteur garde, le 2026-10-03, le frame différé des accueils élève et équipe (UDR-0010, UDR-0018) et le rechargement du document à chaque nouvelle session (ADR-0049). Le compte d'aujourd'hui devient donc un **plafond** : aucun parcours ne le dépasse.

| Parcours | Plafond |
|---|--:|
| Clic vers une page (navigation Turbo), sauf les accueils élève et équipe | **1** |
| Clic vers l'accueil élève ou équipe (frame différé de l'activité récente) | **2** |
| Connexion d'un enseignant, déconnexion (rechargement de l'ADR-0049) | **3** |
| Connexion d'un élève (rechargement et frame différé) | **4** |
| Ouverture de `lnclass.com` par une personne connectée (redirection, accueil, frame) | **3** |

- Un nouveau frame différé (`loading: :lazy`) ajoute une requête en série. Il n'est justifié que si son contenu coûte, côté serveur, plus qu'un aller-retour, ou s'il est hors de l'écran à l'arrivée sur la page.
- Le plafond se vérifie avec `script/perf/count_round_trips.rb`. Un parcours qui le dépasse ouvre un chantier `optimize`.

### 4.3 Région

> **L'application et sa base vivent ensemble dans la région Railway la plus proche des utilisateurs.** Le choix se fait sur une mesure prise depuis la Côte d'Ivoire (`script/perf/measure_network.rb`). À vol d'oiseau, la candidate est `europe-west4` (Amsterdam).

**Décision du porteur, 2026-10-03 : `europe-west4` pour les trois environnements, avec leurs bases et leurs fichiers.** C'est appliqué en production et en Staging le 2026-10-04 ; la base de Develop reste à déplacer. Au point de mesure, le surcoût d'un aller-retour jusqu'au serveur est passé de 227 à 107 ms, et le chargement d'une page déjà visitée de 403 à 238 ms. La mesure depuis Abidjan reste à prendre. Les fichiers d'Active Storage vivent dans un bucket `ams` par environnement (`lnclass-fichiers-eu-<environnement>`), car la région d'un bucket ne change jamais. On ne déplace jamais l'application sans sa base : chaque page fait 4 à 25 requêtes SQL, et une traversée Europe–Asie par requête SQL coûterait plus que tout le reste.

## 5. Conséquences

### 🟢 Positives

- « Lent » se mesure là où la personne le vit. Les trois scripts se rejouent sans compte (réseau et navigateur) ou sur la base de développement (requêtes en série).
- Le cache reste limité à ce qui ne dépend de personne : aucun risque de servir la page, le jeton ou le nonce d'une session à une autre.
- Chaque requête en série retirée accélère le parcours sur tous les réseaux, en 3G encore plus qu'au point de mesure.

### 🔴 Coûts consentis

- **Le gain principal n'est pas dans le code.** Rapprocher la région demande une migration de PostgreSQL avec interruption, et le chiffre qui la justifie doit venir d'Abidjan. Tant qu'il manque, chaque aller-retour reste de l'ordre de 250 ms ou plus.
- **Le plafond garde deux requêtes en série évitables.** La connexion recharge le document (ADR-0049) et les accueils élève et équipe différent leur activité récente (UDR-0010, UDR-0018). Les supprimer ferait gagner un aller-retour à chacun de ces parcours ; le porteur a choisi de garder ces décisions.
- **Deux réglages vivent hors du dépôt**, dans le tableau de bord Cloudflare (*Early Hints*, *Tiered Cache*). Rien ne les vérifie automatiquement ; le script navigateur les met en évidence (première visite).
- **Le plafond de requêtes n'est pas vérifié en CI**, comme les budgets de l'ADR-0067 : il se rejoue avant la recette et dans tout chantier qui touche un parcours.
- Le point de mesure de référence (conteneur cloud, PoP de Chicago) n'est pas celui des utilisateurs. Les chiffres en millisecondes valent pour ce point ; seul le compte de requêtes vaut partout.

## 6. Notes d'implémentation

```ruby
# config/environments/production.rb — aujourd'hui (un an, sans immutable)
config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
```

```erb
<%# app/views/layouts/application.html.erb — la page d'arrivée d'une visite Turbo recharge le document (ADR-0049) %>
<%= document_reload_tag %>
```

```bash
ruby script/perf/measure_network.rb                       # trajet : serveur contre cache Cloudflare
NODE_PATH=$(npm root -g) node script/perf/measure_browser.cjs   # premier octet, DOMContentLoaded, load
RAILS_ENV=production … bin/rails runner script/perf/count_round_trips.rb   # requêtes en série par parcours
```

## 7. Comment vérifier que la décision est respectée

- `script/perf/count_round_trips.rb` : aucun parcours au-dessus de son plafond (§4.2).
- `curl -sI https://lnclass.com/` : HTML en `private, max-age=0` et `cf-cache-status: DYNAMIC` ; `curl -sI` d'un asset digéré : `public, max-age=31536000`, puis `HIT` au second appel.
- `script/perf/measure_network.rb` lancé depuis la Côte d'Ivoire, avant et après tout changement de région.
- Toute PR qui ajoute un `Rails.cache.fetch`, un cache de fragment ou un `fresh_when` cite l'écran et le budget de l'ADR-0067 qu'il fait tenir.
