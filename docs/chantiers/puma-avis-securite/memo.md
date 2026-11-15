# Memo — Avis de sécurité Puma

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `fix/puma-avis-securite` |

## Le problème

`Gemfile.lock` de `Develop` épingle puma 8.0.2. `bundler-audit` y relève 5 avis, tous corrigés en puma 8.0.3 : l'étape « Security: Gem audit » de `bin/ci-quiet` est rouge pour toute PR (#636, #637, #638 en attente). Puma est le serveur web de production (Railway).

| Avis | Effet |
|---|---|
| GHSA-m5xw-3hrw-qcmf | connexion au délai du réacteur dépassé gardée ouverte par un client qui continue d'envoyer |
| GHSA-xw3h-pgr9-3vg7 | le réacteur se bloque en écrivant `100 Continue` ou `408` à un client qui ne lit plus |
| GHSA-x646-wp7c-h9mg | pas de délai d'écriture sur les réponses TLS et les fichiers de plus de 64 Ko |
| GHSA-rf6g-xhmp-gm7v | `accept` à court de descripteurs : boucle sans repli ni limite de journalisation |
| GHSA-r885-m39c-939g | `+` dans `ssl_cipher_filter` élargit la liste de chiffrements |

Puma 8.0.3 corrige deux autres avis que l'audit local ne signale pas encore : GHSA-jm4r-w4xx-qxw7 (arrêt gracieux), GHSA-86xc-wrr9-xmmq (`pumactl` sur `ssl://`).

## Correctif

`bundle update puma --conservative --patch` : **puma 8.0.3**. Seules les deux lignes de puma bougent dans `Gemfile.lock` (version et somme de contrôle) ; `Gemfile` inchangé, aucune autre gemme.

Version retenue : 8.0.3 et non 8.1.1. `--conservative` seul aurait donné 8.1.1 (publiée le jour même, mineure : nouveautés, durcissements HTTP comme le 400 sur `Host` absent ou vide, rejet de caractères dans le chemin). Les 5 avis sont déjà clos en 8.0.3 ; on garde le correctif au plus petit pas. Passage à 8.1.x : chantier séparé, voir `## À trancher` du journal.

## Ce qui a été vérifié

- **`ssl_cipher_filter` n'est utilisé nulle part** (`git grep -n ssl_cipher_filter` : aucune ligne). Puma n'écoute pas en TLS chez nous : Thruster/Railway terminent TLS devant. Le cinquième avis ne nous touche donc pas directement ; les quatre autres (épuisement de ressources) restaient exposés, d'où l'urgence.
- **Journal des changements 8.0.2 → 8.0.3** relu : rien dans `config/puma.rb` ne dépend d'un comportement changé. Le fichier n'utilise que `threads`, `port`, `http_content_length_limit`, `plugin :tmp_restart`, `plugin :solid_queue` et `pidfile`. Seule nouveauté de configuration : `shutdown_body_timeout` (25 s par défaut), qui borne l'arrêt gracieux ; le délai d'arrêt de Railway est supérieur, aucun réglage à poser. Aucune option Puma dans `Dockerfile`, `Procfile.dev` ni `bin/`.
- **Démarrage** : `bin/rails server -p 3000` en développement lève Puma 8.0.3 (`Puma version: 8.0.3`), `GET /up` 200, `GET /` 200 (« Accueil · Lnclass »), puis arrêt gracieux (`Gracefully stopping`), plus aucun process Puma.
- `bin/bundler-audit` : « No vulnerabilities found ».

## Hors périmètre

Aucun code applicatif, aucun réglage Puma. Pas de montée vers 8.1.x.
