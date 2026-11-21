# Memo — Aucune page au-dessus de 600 ms côté serveur

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours — mesure avant et diagnostic faits ; garde (lot B) à livrer |
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

### Navigateur, 390 px (avant)

Chromium headless, production locale servie par Puma sans compression, médiane de 3 passes. La première page d'une
passe charge les assets (cache vide) ; en production, JS 62 Ko et CSS 20 Ko compressés.

TABLEAU_NAVIGATEUR

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

Voir le [plan](plan.md) : lots fermés (cible tenue avant), garde livrée par le lot B.
