# Journal — Audit Yarn conditionnel en local

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Comparer à `origin/Develop` plutôt qu'au dernier commit | Une branche de lot qui ajoute une dépendance doit déclencher l'audit à chaque passage local, pas seulement dans le commit qui l'ajoute | Non |
| 2026-09-25 | Garder une seule liste d'étapes dans `config/ci.rb` | Le fichier reste la source unique de `bin/ci` et de la CI GitHub (`.github/workflows/ci.yml`) | Non |

## Mesure après

| Métrique | Contexte / volume | Avant | Après | Comment mesurée |
|---|---|---|---|---|
| Étape « Yarn vulnerability audit » | Poste local (4 cœurs), dépendances identiques à `origin/Develop` | 2 min 40 s | 0,02 s (étape sautée) | sortie de `bin/ci` |
| `bin/ci` complet | Même poste, charge moyenne entre 5 et 7 (deux autres `bin/ci` en parallèle) | 8 min 46 s | 6 min 02 s | sortie de `bin/ci` |

Le « Setup » a pris 50 s au lieu d'environ 11 s, parce que c'était le premier passage dans un nouveau worktree. Dans un worktree déjà préparé, le gain est donc légèrement plus grand.

## Ce qui a dérapé

- Rien.

## Ce qu'on a appris sur la codebase

- La durée de l'audit Yarn tient au réseau du poste, pas au nombre de paquets.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-25 |
| **PR** | [#12](https://github.com/Lnclassapp/App.Lnclassapp/pull/12) |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
