# Journal — Tests système alignés sur le numéro en chiffres de la connexion

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Les tests suivent UDR-0060 §3.2 (chiffres seuls, aide du PIN visible) | Le changement du 2026-10-11 est voulu par le porteur ; seuls les tests système n'avaient pas suivi | Non |

## Ce qui a dérapé

- Le commit `94fc2d0d` a mis à jour le test de contrôleur mais pas les tests système, qui ne tournent qu'en local depuis la coupure de la CI GitHub.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `boucle_pedagogique_test.rb:37` rouge sur `Develop` | Cause différente (fenêtre modale introuvable) | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
