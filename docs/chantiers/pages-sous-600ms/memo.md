# Memo — Aucune page au-dessus de 600 ms côté serveur

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré (PR vers Develop) — cible tenue ; constats d'hébergement dans « À trancher » du journal |
| **Ouvert le** | 2026-11-21 |
| **Branche** | `perf/pages-sous-600ms` |

---

## Le problème

Le porteur trouve l'application « très très lente », sur **lnclass.com (production)** comme sur **develop.lnclass.com**,
depuis le passage de l'hébergement au VPS Hostinger (production le 2026-11-17, ADR-0140 ; Develop et Staging sur le même
serveur ; déploiement continu depuis le 2026-11-21, ADR-0144).

## Pour qui

L'élève d'abord (/student, /students, matière, leçon, exercice), puis l'enseignant et la direction.

## Hors périmètre

- Les vues de /student, /students et de l'inscription : une autre session (`entree-et-accueil-eleve-allegees`) les réécrit.
- L'infrastructure de production : constats chiffrés et recommandations ici, toute correction passe par une PR à part.
- Les pages de l'équipe (`/teams/...`) : chantiers `cache-ecrans-lourds` et `ecrans-direction-lents`.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Temps serveur p95, pire page, 3 rôles | jeu standard, grand établissement (Groupe Scolaire Modèle Savane, 42 classes), production locale (`RAILS_ENV=production`, assets précompilés, Solid Cache), machine de la session (4 cœurs) | **200 ms** (élève · ma classe) | < 600 ms | `script/mesure/pages` (20 passes après 2 de chauffe) |
| Même mesure, plafonds CPU de Develop simulés (base 0,1 CPU, application 0,4 CPU, `deploy/hostinger/test.yaml`) | même volume, cgroups `cpu.cfs_quota_us` | **608 ms** (élève · ma classe) ; accueil enseignant 363 ms | < 600 ms | `script/mesure/pages`, processus Ruby et PostgreSQL dans des cgroups plafonnés |
| Démarrage de Develop après un déploiement (site en 502 pendant ce temps) | develop.lnclass.com, déploiement du 2026-11-21 | **16 min 36 s** (conteneur démarré 18:02:57, Puma à l'écoute 18:19:33) | — (constat d'hébergement) | journaux du projet `lnclass-develop` (API Hostinger, lecture seule) |
| Temps serveur des pages publiques en production | lnclass.com, journaux du 2026-11-21 17:28–18:20 | **26–30 ms** (dont ~25 ms de base de données pour 1 à 4 requêtes) | — | ligne `Completed` et `dur` de Thruster, API Hostinger |
| Occupation du VPS | 2 vCPU, 8 Go, 2026-11-18 → 21 | CPU **4 %** en moyenne horaire, pointes horaires 12–15 % aux constructions d'image ; RAM 2,3 Go (pointe 3,0) | — | `GET /virtual-machines/{id}/metrics` |

Le tableau complet, page par page, est plus bas. **La cible est déjà tenue en production locale, à l'état de départ** :
aucune page des trois rôles ne dépasse 600 ms p95 côté serveur. Le code de l'application n'explique pas la lenteur
ressentie (voir [Cause](#cause)).

### Protocole (reproductible)

```bash
bin/jeu-standard                        # une fois, base locale
script/mesure/pages                     # temps serveur, SQL, allocations, poids (tmp/mesure-pages.json)
script/mesure/pages --navigateur        # puis Chromium à 390 px (tmp/mesure-pages-navigateur.json)
```

Plafonds de Develop simulés (conteneur Linux, cgroups v1, root) :

```bash
mkdir -p /sys/fs/cgroup/cpu/simdb /sys/fs/cgroup/cpu/simapp
echo 10000 > /sys/fs/cgroup/cpu/simdb/cpu.cfs_quota_us    # 0,1 CPU, comme db dans test.yaml
echo 40000 > /sys/fs/cgroup/cpu/simapp/cpu.cfs_quota_us   # 0,4 CPU, comme app
for pid in $(pgrep -f postgres); do echo $pid > /sys/fs/cgroup/cpu/simdb/tasks; done
sh -c 'echo $$ > /sys/fs/cgroup/cpu/simapp/tasks; exec script/mesure/pages'
```

### Page par page (avant)

Production locale, 20 passes par page, médiane de 3 exécutions ; « Dev. p95 » : même mesure sous les plafonds de
Develop (10 passes). Base locale après chargement des leçons de Develop (463 leçons du manifeste, comme develop.lnclass.com).
Ko : HTML non compressé (Caddy le compresse en zstd/gzip devant l'application).

| Rôle | Page | p50 ms | p95 ms | Dev. p95 ms | SQL | Allocations | Ko |
|---|---|--:|--:|--:|--:|--:|--:|
| visiteur | accueil public | 10.6 | 21.4 | 71.5 | 1 | 3856 | 15.8 |
| visiteur | entrée élève | 11.8 | 33.5 | 93.7 | 1 | 4176 | 16.4 |
| visiteur | connexion | 5.7 | 17.0 | 72.7 | 1 | 4257 | 17.7 |
| eleve | accueil | 44.7 | 64.6 | 222.7 | 26 | 17341 | 38.9 |
| eleve | accueil (historique différé) | 13.8 | 21.9 | 76.1 | 7 | 5209 | 6.6 |
| eleve | ma classe | 160.1 | 199.7 | 608.5 | 91 | 114957 | 76.2 |
| eleve | archive | 18.5 | 28.2 | 85.5 | 9 | 14565 | 41.5 |
| eleve | menu | 9.9 | 15.9 | 77.1 | 6 | 7667 | 28.1 |
| eleve | annonces | 15.3 | 24.2 | 90.4 | 9 | 8615 | 24.7 |
| eleve | catalogue | 35.6 | 49.7 | 305.0 | 15 | 24951 | 84.0 |
| eleve | matière | 18.1 | 23.4 | 94.5 | 13 | 8969 | 12.8 |
| eleve | profil | 12.1 | 16.0 | 74.8 | 8 | 9192 | 32.3 |
| eleve | leçon | 60.4 | 75.6 | 203.8 | 39 | 31188 | 22.4 |
| eleve | exercice | 30.5 | 46.7 | 109.1 | 23 | 14044 | 34.9 |
| enseignant | accueil | 107.9 | 134.2 | 362.7 | 30 | 99647 | 313.5 |
| enseignant | mes classes | 27.2 | 77.9 | 102.2 | 12 | 19336 | 77.8 |
| enseignant | menu | 13.5 | 17.5 | 77.6 | 8 | 10092 | 34.5 |
| enseignant | classe | 77.1 | 91.2 | 299.0 | 30 | 65346 | 131.7 |
| enseignant | jours de séance | 16.6 | 22.5 | 71.9 | 12 | 10101 | 32.8 |
| enseignant | annonces | 17.4 | 21.5 | 69.9 | 10 | 9770 | 27.5 |
| enseignant | catalogue | 39.8 | 50.7 | 105.1 | 15 | 31861 | 114.7 |
| enseignant | profil | 17.3 | 22.8 | 78.0 | 11 | 11806 | 34.2 |
| enseignant | assigner (modale) | 18.2 | 24.9 | 74.4 | 14 | 10727 | 32.8 |
| enseignant | élève de la classe | 34.0 | 42.2 | 184.7 | 22 | 19536 | 57.4 |
| enseignant | leçon de la classe | 52.1 | 62.4 | 169.1 | 26 | 43698 | 83.1 |
| enseignant | suivi d'un devoir | 38.6 | 47.8 | 175.2 | 23 | 20168 | 49.9 |
| direction | activité | 10.4 | 16.2 | 68.6 | 6 | 6465 | 12.5 |
| direction | classes | 17.7 | 23.0 | 77.2 | 10 | 12602 | 40.1 |
| direction | classe | 65.1 | 93.8 | 189.4 | 18 | 71008 | 263.4 |
| direction | niveau | 28.4 | 33.9 | 94.2 | 14 | 17172 | 60.4 |
| direction | enseignants | 18.5 | 21.9 | 69.3 | 10 | 12296 | 41.2 |
| direction | chercher un élève | 23.7 | 27.4 | 172.0 | 7 | 11960 | 43.4 |
| direction | élèves partis | 16.0 | 21.7 | 76.4 | 8 | 8560 | 27.7 |
| direction | enseignants partis | 15.1 | 18.5 | 71.9 | 9 | 7856 | 24.7 |
| direction | établissement | 25.6 | 37.3 | 98.6 | 14 | 22447 | 82.0 |
| direction | annonces | 13.5 | 18.1 | 65.7 | 8 | 8488 | 25.3 |

### Navigateur, 390 px

Chromium headless, production locale servie par Puma **sans compression** (Ko = HTML brut ; Caddy compresse en
production), médiane de 3 passes, après le lot C. La première page d'une passe charge les assets (cache vide) ; en
production, JS 62 Ko et CSS 20 Ko compressés. Avant le lot C, une seule passe : « Ma classe » à 593 ms
DOMContentLoaded (227 ms après).

| Rôle | Page | Ko transférés | Requêtes réseau | DOMContentLoaded ms | load ms |
|---|---|--:|--:|--:|--:|
| visiteur | accueil public (cache vide) | 432 | 6 | 71 | 71 |
| visiteur | entrée élève | 17.1 | 1 | 67 | 68 |
| visiteur | connexion | 18.3 | 1 | 42 | 44 |
| eleve | accueil (cache vide) | 508.8 | 15 | 130 | 131 |
| eleve | ma classe | 76.8 | 1 | 227 | 227 |
| eleve | archive | 42.1 | 1 | 59 | 61 |
| eleve | menu | 28.8 | 1 | 49 | 51 |
| eleve | annonces | 25.3 | 1 | 58 | 59 |
| eleve | catalogue | 85.7 | 1 | 79 | 82 |
| eleve | matière | 13.9 | 1 | 58 | 60 |
| eleve | profil | 32.9 | 1 | 54 | 56 |
| eleve | leçon | 22.8 | 1 | 102 | 102 |
| eleve | exercice | 35.7 | 1 | 80 | 81 |
| enseignant | accueil (cache vide) | 761.7 | 10 | 221 | 229 |
| enseignant | mes classes | 84.3 | 1 | 90 | 91 |
| enseignant | menu | 35.3 | 1 | 50 | 52 |
| enseignant | classe | 132.3 | 1 | 123 | 130 |
| enseignant | jours de séance | 33.5 | 1 | 79 | 81 |
| enseignant | annonces | 28.2 | 1 | 73 | 74 |
| enseignant | catalogue | 115.3 | 1 | 94 | 95 |
| enseignant | profil | 34.8 | 1 | 61 | 62 |
| enseignant | assigner (modale) | 33.6 | 1 | 60 | 62 |
| enseignant | élève de la classe | 58.3 | 1 | 82 | 82 |
| enseignant | leçon de la classe | 84.4 | 1 | 128 | 137 |
| enseignant | suivi d'un devoir | 50.5 | 1 | 84 | 87 |
| direction | activité (cache vide) | 12.8 | 1 | 32 | 32 |
| direction | classes | 492.8 | 14 | 102 | 111 |
| direction | classe | 268.8 | 1 | 201 | 204 |
| direction | niveau | 61.4 | 1 | 86 | 87 |
| direction | enseignants | 41.7 | 1 | 60 | 64 |
| direction | chercher un élève | 43.9 | 1 | 62 | 64 |
| direction | élèves partis | 28.2 | 1 | 49 | 51 |
| direction | enseignants partis | 25.2 | 1 | 54 | 54 |
| direction | établissement | 86.4 | 1 | 85 | 86 |
| direction | annonces | 25.8 | 1 | 53 | 56 |


## Cause

1. **Le code n'est pas en cause en production locale** : pire page à 200 ms p95. Les pages les plus coûteuses sont « Ma
   classe » de l'élève (91 requêtes, 115 000 allocations : la feuille de chaque leçon assignée est relue,
   `StudentAssignedSheetsQuery#exercises` → `PrepareSheetsQuery`, ×6) et l'accueil de l'enseignant (102 000 allocations,
   318 Ko de HTML).
2. **Develop est plafonné à 0,1 CPU pour sa base et 0,4 CPU pour l'application** (`deploy/hostinger/test.yaml`). Simulé,
   le plafond multiplie le temps des pages par 2 à 6 (p95 : « ma classe » 200 → 608 ms ; catalogue de l'élève 50 → 305 ms ; accueil enseignant 134 → 363 ms)
   et ajoute des pointes de throttling (une page à 30 ms monte à 75 ms p95, quota de 10 ms par période de 100 ms).
3. **Develop est indisponible ~16 min à chaque déploiement** : `db:prepare db:seed` (chargement automatique des leçons et
   jeu standard) puis un second `db:prepare` et le démarrage de Puma, sous ces mêmes plafonds. Avec le déploiement
   continu (ADR-0144), chaque fusion vers `Develop` coupe le site un quart d'heure ; un clic pendant ce temps reçoit
   un 502 de Thruster/Caddy, ce qui se lit comme « très lent ».
4. **Production : le serveur répond en ~30 ms et le VPS est au repos (4 % CPU)**. Les ~25 ms de base de données pour
   une seule requête, constants quel que soit le nombre de requêtes, signent une reconnexion à PostgreSQL : le trafic
   est espacé de plusieurs minutes et la connexion inactive est fermée entre deux visites. Ce n'est pas « très lent ».
   La lenteur ressentie en production vient donc d'entre le navigateur et le serveur (réseau Abidjan → Cloudflare →
   Paris, téléphone) : **à mesurer par le porteur** avec les commandes ci-dessous, la session n'ayant pas accès à
   lnclass.com (proxy : 403).
5. **Cache et en-têtes, vérifiés** : Solid Cache en production ; assets avec empreinte et `cache-control: public,
   max-age=31536000` ; compression zstd/gzip par Caddy ; pages HTML `private, must-revalidate` avec ETag (défaut Rails,
   aucune donnée d'élève en cache partagé) ; service worker « réseau d'abord » pour le HTML, « cache d'abord » pour les
   assets avec empreinte : il ne sert pas de vieux contenu quand le réseau répond. Poids JS/CSS : 62 + 20 Ko compressés.

### Commandes pour le porteur (depuis Abidjan, sur son ordinateur)

```bash
# Temps de chaque étape, 5 fois par page (DNS, connexion, TLS, premier octet, total)
for u in https://lnclass.com/ https://lnclass.com/login https://develop.lnclass.com/ https://develop.lnclass.com/login; do
  for i in 1 2 3 4 5; do
    curl -s -o /dev/null -H 'Accept-Encoding: gzip, br, zstd' \
      -w "$u dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n" "$u"
  done
done
# Le temps passé dans l'application (Rails) pour la même page : en-tête x-runtime, en secondes
curl -s -o /dev/null -D - https://lnclass.com/login | grep -i -E 'x-runtime|cf-cache-status|server-timing|cf-ray'
```

Lecture : `ttfb − tls` ≈ trajet + serveur ; si `x-runtime` est petit (< 0,05 s) et `ttfb` grand, le temps est sur le
réseau, pas dans l'application.

## Mesure après

Même machine, même volume, même méthode ; 3 exécutions de 20 passes, médiane (10 passes sous plafonds, élève).

| Métrique | Avant | Cible | **Après** | Tenu ? |
|---|--:|--:|--:|:-:|
| Pire page, p95, production locale (élève · ma classe) | 200 ms | < 600 ms | **167 ms** | oui |
| « Ma classe », p95 sous les plafonds de Develop | 608 ms | < 600 ms | **514 ms** | oui |
| « Ma classe », allocations | 114 957 | −30 % | **54 480 (−53 %)** | oui |
| « Ma classe », requêtes SQL | 91 | — | 91 | — |
| Pire page sous plafonds de Develop, tous rôles | 608 ms | < 600 ms | **514 ms** (élève) ; enseignant 363 ms avant, non rejoué | oui |
| Garde : budget de requêtes par page (15 pages, 3 rôles) | aucune | un test | `test/integration/budget_requetes_pages_test.rb` | oui |

Page par page (les autres pages ne changent pas : aucun autre code touché, écarts dans le bruit de mesure) :

| Rôle | Page | p95 avant | p95 après | Dev. p95 avant | Dev. p95 après | SQL avant → après | Allocations avant → après |
|---|---|--:|--:|--:|--:|--:|--:|
| visiteur | accueil public | 21.4 | 27.6 | 71.5 | 89.3 | 1 → 1 | 3856 → 3847 |
| visiteur | entrée élève | 33.5 | 32.1 | 93.7 | 91.1 | 1 → 1 | 4176 → 4182 |
| visiteur | connexion | 17.0 | 24.1 | 72.7 | 86.9 | 1 → 1 | 4257 → 4254 |
| eleve | accueil | 64.6 | 54.2 | 222.7 | 192.4 | 26 → 26 | 17341 → 17338 |
| eleve | accueil (historique différé) | 21.9 | 17.8 | 76.1 | 76.7 | 7 → 7 | 5209 → 5218 |
| eleve | ma classe | 199.7 | 166.8 | 608.5 | 514.3 | 91 → 91 | 114957 → 54480 |
| eleve | archive | 28.2 | 32.8 | 85.5 | 87.9 | 9 → 9 | 14565 → 14553 |
| eleve | menu | 15.9 | 17.9 | 77.1 | 76.8 | 6 → 6 | 7667 → 7670 |
| eleve | annonces | 24.2 | 22.4 | 90.4 | 74.0 | 9 → 9 | 8615 → 8609 |
| eleve | catalogue | 49.7 | 48.9 | 305.0 | 297.8 | 15 → 15 | 24951 → 24955 |
| eleve | matière | 23.4 | 26.0 | 94.5 | 100.9 | 13 → 13 | 8969 → 8980 |
| eleve | profil | 16.0 | 16.4 | 74.8 | 73.4 | 8 → 8 | 9192 → 9192 |
| eleve | leçon | 75.6 | 75.4 | 203.8 | 185.0 | 39 → 39 | 31188 → 31191 |
| eleve | exercice | 46.7 | 39.0 | 109.1 | 105.8 | 23 → 23 | 14044 → 14048 |
| enseignant | accueil | 134.2 | 128.7 | 362.7 | — | 30 → 30 | 99647 → 99641 |
| enseignant | mes classes | 77.9 | 34.2 | 102.2 | — | 12 → 12 | 19336 → 19340 |
| enseignant | menu | 17.5 | 16.9 | 77.6 | — | 8 → 8 | 10092 → 10092 |
| enseignant | classe | 91.2 | 86.3 | 299.0 | — | 30 → 30 | 65346 → 65349 |
| enseignant | jours de séance | 22.5 | 26.1 | 71.9 | — | 12 → 12 | 10101 → 10107 |
| enseignant | annonces | 21.5 | 21.3 | 69.9 | — | 10 → 10 | 9770 → 9779 |
| enseignant | catalogue | 50.7 | 46.3 | 105.1 | — | 15 → 15 | 31861 → 31854 |
| enseignant | profil | 22.8 | 24.0 | 78.0 | — | 11 → 11 | 11806 → 11816 |
| enseignant | assigner (modale) | 24.9 | 25.9 | 74.4 | — | 14 → 14 | 10727 → 10718 |
| enseignant | élève de la classe | 42.2 | 40.0 | 184.7 | — | 22 → 22 | 19536 → 19548 |
| enseignant | leçon de la classe | 62.4 | 67.4 | 169.1 | — | 26 → 26 | 43698 → 43704 |
| enseignant | suivi d'un devoir | 47.8 | 44.7 | 175.2 | — | 23 → 23 | 20168 → 20170 |
| direction | activité | 16.2 | 17.2 | 68.6 | — | 6 → 6 | 6465 → 6483 |
| direction | classes | 23.0 | 23.3 | 77.2 | — | 10 → 10 | 12602 → 12616 |
| direction | classe | 93.8 | 79.7 | 189.4 | — | 18 → 18 | 71008 → 71003 |
| direction | niveau | 33.9 | 31.9 | 94.2 | — | 14 → 14 | 17172 → 17175 |
| direction | enseignants | 21.9 | 21.4 | 69.3 | — | 10 → 10 | 12296 → 12299 |
| direction | chercher un élève | 27.4 | 24.3 | 172.0 | — | 7 → 7 | 11960 → 11966 |
| direction | élèves partis | 21.7 | 20.2 | 76.4 | — | 8 → 8 | 8560 → 8554 |
| direction | enseignants partis | 18.5 | 18.5 | 71.9 | — | 9 → 9 | 7856 → 7850 |
| direction | établissement | 37.3 | 33.9 | 98.6 | — | 14 → 14 | 22447 → 22453 |
| direction | annonces | 18.1 | 16.3 | 65.7 | — | 8 → 8 | 8488 → 8490 |

« — » : rôle non rejoué sous plafonds après le lot C (seul « Ma classe » de l'élève a changé).
