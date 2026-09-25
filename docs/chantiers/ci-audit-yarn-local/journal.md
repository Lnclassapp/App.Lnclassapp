# Journal — Audit Yarn conditionnel en local

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Comparer à `origin/Develop` plutôt qu'au dernier commit | Une branche de lot qui ajoute une dépendance doit déclencher l'audit à chaque passage local, pas seulement dans le commit qui l'ajoute | Non |
| 2026-09-25 | Garder une seule liste d'étapes dans `config/ci.rb` | Le fichier reste la source unique de `bin/ci` et de la CI GitHub (`.github/workflows/ci.yml`) | Non |

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
| **PR** | à venir |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
