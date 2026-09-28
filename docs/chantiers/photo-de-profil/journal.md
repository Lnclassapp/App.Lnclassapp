# Journal — Photo de profil

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros ADR-0060 et UDR-0047 (plus haut existant + 4) | Consigne du porteur : éviter les collisions avec les chantiers parallèles (0057, 0058, UDR 0044, 0045 déjà pris dans d'autres worktrees) | non |
| 2026-09-28 | Lecture par un contrôleur authentifié plutôt que par une URL `rails_storage_proxy` signée | Le proxy d'Active Storage répond `Cache-Control: public` pour toujours, et une URL signée est un laissez-passer sans session | oui, ADR-0060 |
| 2026-09-28 | Refuser (et non nettoyer) une image qui porte encore des métadonnées | Le canvas les retire toujours ; seul un navigateur sans recadrage en envoie, et sa photo dépasse de toute façon 1 Mo | oui, ADR-0060 |
| 2026-09-28 | Pas de photo dans la liste des enseignants d'un établissement | `SchoolDetailQuery::TeacherRow` n'a pas d'identifiant public et le fichier est modifié par `feature/code-etablissement` en parallèle | non (dette) |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- `ui_avatar` acceptait déjà `src:` et le shell passait déjà `user.avatar_url` : l'en-tête et la barre latérale n'avaient besoin que d'une donnée.
- `config.active_storage.resolve_model_to_route = :rails_storage_proxy` est posé mais rien ne sert de fichier Active Storage au navigateur.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Photo dans la liste des enseignants d'un établissement (équipe) | Collision avec `feature/code-etablissement` ; la requête n'expose pas l'identifiant public | à ouvrir après le merge |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0060 |
| **UDR produits** | UDR-0047 |
