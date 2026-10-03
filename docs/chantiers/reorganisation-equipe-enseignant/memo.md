# Memo — Réorganisation des espaces Équipe et Enseignant

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `Develop` (directement, décision du porteur le 2026-10-03) |
| **Programme** | — |

---

## Le problème

Demande du porteur (2026-10-03) : « nous allons réorganiser certains éléments des interfaces ».

**Espace équipe.** La barre latérale mélange le quotidien (accueil, cours, établissements, pilotage) et l'outillage ponctuel (imports). L'accueil équipe porte une section « Référentiel » (DRENA, niveaux, séries, matières, barème des classes) qui relève de la configuration, pas du quotidien. Sur la page Pilotage, la recherche d'un compte est en bas de page, et le tableau « Par DRENA » ne mène nulle part : pour connaître les chiffres des établissements d'une DRENA, il faut filtrer la page entière, et aucun écran ne donne ces chiffres établissement par établissement.

**Espace enseignant.** La carte « Mes classes » porte « Modifier mes classes » dans son pied. La section « Cours » est un simple lien vers le catalogue complet, placée en dernier, alors que c'est par elle que l'enseignant trouve quoi assigner ; l'enseignant doit filtrer lui-même par niveau et par matière. L'invitation de collègues est un bloc en bas de l'accueil, qui ne sert qu'aux collègues **du même établissement**. Enfin, un exercice ne s'assigne que depuis la fiche essentielle dans la classe, et rien ne restreint l'assignation aux classes du niveau du contenu.

## Pour qui

- **Équipe** : au quotidien (accueil, pilotage) et lors des tâches de configuration (référentiel, imports).
- **Enseignant** : à chaque connexion, sur son accueil, quand il cherche quoi assigner à ses classes et quand il invite des collègues.

## Pourquoi maintenant

Retours du porteur sur les interfaces livrées (V1 à V4) : les écrans existent, leur organisation freine les deux rôles qui font vivre la plateforme.

## Hors périmètre

- Toute nouvelle donnée de configuration : le référentiel change de place, pas de contenu.
- Les espaces élève, parent et direction.
- La refonte du catalogue lui-même : on s'appuie sur ses filtres existants.
- **« Versement »** : retiré par le porteur (G1). Aucune icône, aucun montant ; il reviendra avec un chantier paiement qui aura d'abord une source de vérité.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| G1 — « Versement » : rien n'existe (aucun montant, aucun paiement) et l'accueil enseignant interdit un montant sans source de vérité. Où mène l'icône ? | « Retire simplement pour le moment. » | L'icône « Versement » sort du chantier, passe en `Hors périmètre`. La section Cours n'ajoute que « Inviter ». La règle « aucun montant » de l'accueil enseignant reste intacte. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
