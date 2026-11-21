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
| Temps serveur p95, pire page, 3 rôles | jeu standard, grand établissement (Groupe Scolaire Modèle Savane, 42 classes), production locale (`RAILS_ENV=production`, assets précompilés, Solid Cache), machine de la session (4 cœurs) | **199 ms** (élève · ma classe) | < 600 ms | `script/mesure/pages` (20 passes après 2 de chauffe) |
| Même mesure, plafonds CPU de Develop simulés (base 0,1 CPU, application 0,4 CPU, `deploy/hostinger/test.yaml`) | même volume, cgroups `cpu.cfs_quota_us` | **496 ms** (élève · ma classe) | < 600 ms | `script/mesure/pages`, processus Ruby et PostgreSQL dans des cgroups plafonnés |
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

Production locale, médiane et p95 de 20 passes ; « Dev. p95 » : même mesure sous les plafonds de Develop (5 passes).
Ko : HTML non compressé (Caddy le compresse en zstd/gzip devant l'application).

TABLEAU_AVANT

### Navigateur, 390 px (avant)

Chromium headless, production locale servie par Puma sans compression, médiane de 3 passes. La première page d'une
passe charge les assets (cache vide) ; en production, JS 62 Ko et CSS 20 Ko compressés.

TABLEAU_NAVIGATEUR

## Cause

1. **Le code n'est pas en cause en production locale** : pire page à 199 ms p95. Les pages les plus coûteuses sont « Ma
   classe » de l'élève (91 requêtes, 115 000 allocations : la feuille de chaque leçon assignée est relue,
   `StudentAssignedSheetsQuery#exercises` → `PrepareSheetsQuery`, ×6) et l'accueil de l'enseignant (102 000 allocations,
   318 Ko de HTML).
2. **Develop est plafonné à 0,1 CPU pour sa base et 0,4 CPU pour l'application** (`deploy/hostinger/test.yaml`). Simulé,
   le plafond multiplie le temps des pages par 2 à 3 (« ma classe » 177 → 468 ms p50 ; accueil enseignant 116 → 300 ms)
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
