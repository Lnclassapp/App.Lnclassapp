# Journal — Émetteur TOTP par environnement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Rapport de root cause (2026-09-30)

**Cause, en une phrase** : le nom qui identifie le compte dans l'application d'authentification ne dépend que du numéro, jamais de l'environnement qui l'émet.

**Chaîne d'appels** : `GET /identity/second-factor/enrollment` → `Identity::SecondFactorEnrollmentsController#new` → `UseCases::Identity::BeginSecondFactorEnrollment#call`, qui prend le numéro du compte comme libellé (`app/domain/use_cases/identity/begin_second_factor_enrollment.rb:18`) → `Repositories::Identity::SecondFactorRepository#begin_enrollment` (`app/infrastructure/repositories/identity/second_factor_repository.rb:23`), qui construit l'adresse du QR code avec l'émetteur **constant** `ISSUER = "Lnclass"` (même fichier, ligne 9).

**Point fautif** : `app/infrastructure/repositories/identity/second_factor_repository.rb:9`. Émetteur et libellé forment la clé d'une entrée dans les applications d'authentification. Deux environnements donnent donc la même clé avec deux secrets différents, et l'application remplace l'un par l'autre.

**Pourquoi aucun test ne l'a vu** : les tests tournent dans un seul environnement et vérifient l'adresse exacte avec l'émetteur « Lnclass » écrit en dur (`test/infrastructure/repositories/identity/second_factor_repository_test.rb:25`). Aucun test ne fait varier l'environnement. Le test de reproduction se place donc au même niveau (infrastructure), en fixant le nom de l'environnement.

**Écarté** : le secret n'est pas partagé entre environnements. Chaque compte tire le sien à l'activation, chiffré dans sa propre base (rapport `pentest-develop`, garantie n°7). Le domaine n'est pas en cause : il transmet un libellé, pas un émetteur.

- Les gemmes ne sont pas installées dans l'environnement de cadrage (Ruby 3.3 au lieu de 3.4, pas de `rotp`) : les tests se lancent à l'exécution, après `bin/setup`.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Réactivation du second facteur du porteur sur l'environnement dont l'entrée a été écrasée | Action manuelle sur un compte, pas du code | aucun : réinitialisation par un autre membre de l'équipe (ADR-0031) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
