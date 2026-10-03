# Memo — Retrait de debugbar

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `fix/retrait-debugbar` |
| **Programme** | — |

---

## Le problème

### Symptôme

En développement, après l'envoi d'une image, **toutes** les requêtes répondent `500`, `/up` compris, jusqu'au redémarrage du serveur. Le journal du serveur porte, à chaque requête :

```
Rack app ("GET /up" - (127.0.0.1)): #<JSON::GeneratorError: "\xFF" from ASCII-8BIT to UTF-8>
```

(octet `"\xD0"` ou `"\xFF"` selon l'image). Constaté par le challenger du chantier `blog` le 2026-10-03 (photo de profil et image d'article), reproduit le jour même sur ce worktree.

### Reproduction

1. `RAILS_ENV=development bin/rails db:create db:schema:load db:seed`, puis `bin/rails server -e development`.
2. Se connecter comme l'élève de démonstration `0100000001`, PIN `2468`.
3. « Mon profil » → photo (`/profile/photo/edit`), envoyer une photo JPEG → `200`, la photo s'affiche.
4. N'importe quelle requête suivante : `/up`, `/`, `/students` → `500`. Seul le redémarrage du serveur rétablit.

Relevé avant correctif (2026-10-03, Chromium headless) :

```
student landed http://127.0.0.1:3210/students | /up -> 200
profile photo upload status 200
after upload: /up -> 500 | / -> 500 | /students (browser) -> 500
```

### Portée

- **Développement seulement.** La gem est au groupe `:development, :test` ; en test elle est chargée mais désactivée (`config.enabled = Rails.env.development?`) ; la production ne l'a pas.
- Tous les développeurs et agents qui lancent `bin/dev` et touchent à une image : photo de profil (ADR-0060), images d'article du chantier `blog`.
- Aucune donnée corrompue : le défaut vit dans la mémoire du processus.

### Cause

`Debugbar::TrackCurrentRequest` (middleware de la gem, 0.4.3) garde les dernières requêtes dans un tampon en mémoire (`RequestBuffer`) et, **à chaque requête**, diffuse le tampon entier en JSON sur Action Cable (`ActionCable.server.broadcast("debugbar_channel", RequestBuffer.to_h)`). La requête qui sert l'image (`GET /accounts/:id/photo`) y dépose une chaîne binaire (`ASCII-8BIT`) que le générateur JSON refuse. Elle reste dans le tampon : toutes les diffusions suivantes lèvent, donc toutes les requêtes. Aucun test ne l'a vu, parce que la gem n'est active qu'en développement.

Debugbar imposait en outre `config.action_cable.disable_request_forgery_protection = true` en développement (et le forçait en test, avec un avertissement, si on ne le posait pas) : Action Cable acceptait toute origine pour le seul besoin de la barre. L'application n'ouvre aucun canal Action Cable (aucun `turbo_stream_from`).

## Décision du porteur

« Retire debugbar du repo » (porteur, 2026-10-03) : **retrait complet**, plutôt qu'un contournement (`ignore_request`, filtrage des corps binaires) ou une montée de version. La barre n'apporte rien que les journaux, `web-console` et `bullet` ne donnent déjà.

Comportement attendu : celui de Rails sans la gem. Le développement démarre et sert des pages après un envoi d'image ; Action Cable revient au réglage par défaut de Rails (protection contre les origines étrangères active).

## Pour qui

Développeurs et agents, en environnement de développement. Aucun acteur de l'application n'est touché.

## Hors périmètre

- **Pas de remplacement** de la barre par un autre outil (`rack-mini-profiler`, etc.) : demande séparée si le besoin revient.
- **Pas de réglage Action Cable de substitution** (origines autorisées, `127.0.0.1`) : rien ne l'utilise aujourd'hui. Le chantier [`mise-a-jour-en-direct`](../mise-a-jour-en-direct/memo.md), s'il passe par Action Cable, partira du défaut Rails (en développement : `http://localhost:<port>` seulement).
- **Pas de réécriture** des inventaires historiques de `refonte-application` qui citent `/_debugbar` : ils décrivent l'ancienne application.
- `bullet`, `web-console` : inchangés.

## Ce que le grill a révélé

Pas de grill : un memo de bug se reproduit, il ne se grille pas ([`bugfix.md`](../../workflows/bugfix.md#modulateur-déquipage)). `prd.md` et `pr-faq.md` du gabarit sont retirés : un bugfix n'a pas de PRD, le comportement attendu est celui de Rails sans la gem.

## Portes de sortie

Voir [`plan.md`](plan.md).
