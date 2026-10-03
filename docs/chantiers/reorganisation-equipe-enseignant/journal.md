# Journal — Réorganisation des espaces Équipe et Enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Le chantier vit directement sur `Develop`, sans branche de chantier ni PR | Décision du porteur, contraire à `conventions.md` §3 ; les lots restent sur des branches locales et rien n'est poussé avant les portes vertes | Non |
| 2026-10-03 | « Versement » et le lien de parrainage vers d'autres établissements sont retirés | Grill G1 et G2 | Non |
| 2026-10-03 | Pas de nouvel ADR ; amendement de l'ADR-0062 pour la lecture « Par établissement » | Aucun port, table, dépendance ni contrat ; UDR-0049 §4 exige qu'un indicateur ajouté passe par l'ADR-0062 | Amendement ADR-0062 |
| 2026-10-03 | « Aucun cours ne doit être assigné hors de son niveau » (G12 révisée, G13) : pas de signal « Hors niveau » (aucune assignation en base), refus de changer le niveau d'un cours assigné | Le porteur est revenu sur G12 après le plan ; l'invariant n'avait qu'un trou, la modification d'un cours | ADR-0075 |
| 2026-10-03 | Recherche d'établissement côté serveur sous filtre DRENA | Avec la pagination de G10, un filtre dans le navigateur ne verrait que la page affichée ; à confirmer par le porteur | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Exploration sur un clone périmé** : le dépôt local avait 296 commits de retard sur `origin/Develop` pendant la première exploration et le début du grill. Deux questions (G6, G12) sont parties de prémisses fausses : l'assignation de cours existait encore, la règle de niveau n'était pas appliquée. Corrigé dans le memo avant le PRD. Leçon : `git fetch` et comparer à `origin/<branche>` **avant** d'explorer, pas au premier `push` refusé.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La barre latérale du shell est masquée sous `lg` : tout contenu qui n'y vit que disparaît du téléphone. D'où le bloc d'invitation gardé sur téléphone et le menu « Plus » de l'équipe.
- La bascule d'assignation et ses streams ne dépendent pas de la page : ils remplacent un identifiant. On les réutilise tels quels au catalogue.
- La règle de niveau de l'élève existe déjà en SQL (`Queries::Catalog::AudienceFilter`) et en domaine (`Entities::Catalog::LevelAudience`) : le filtre « Série » du catalogue et le refus de changer le niveau d'un cours assigné (ADR-0075) reprennent la même règle.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
