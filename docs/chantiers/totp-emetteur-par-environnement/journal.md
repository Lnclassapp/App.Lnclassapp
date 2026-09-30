# Journal — Émetteur TOTP par environnement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | « Lnclass » en production, « Lnclass (<environnement>) » ailleurs, d'après `RAILWAY_ENVIRONMENT_NAME` puis l'environnement Rails | Décision du porteur ; la production garde l'entrée de ses comptes déjà activés | Oui : amendement du 2026-09-30 de l'ADR-0031 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- L'environnement de session n'avait ni Ruby 3.4.9, ni gemmes, ni assets compilés : sans `yarn build` et `yarn build:css`, 127 tests d'intégration tombaient sur « application.css not found », sans lien avec le correctif. À préparer avant tout rouge ou vert.
- La CI GitHub est bloquée par le quota de minutes jusqu'au 2026-10-03 : la preuve est locale (suite complète, RuboCop, Brakeman) et empirique (challenger).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Rapport de root cause (2026-09-30)

**Cause, en une phrase** : le nom qui identifie le compte dans l'application d'authentification ne dépend que du numéro, jamais de l'environnement qui l'émet.

**Chaîne d'appels** : `GET /identity/second-factor/enrollment` → `Identity::SecondFactorEnrollmentsController#new` → `UseCases::Identity::BeginSecondFactorEnrollment#call`, qui prend le numéro du compte comme libellé (`app/domain/use_cases/identity/begin_second_factor_enrollment.rb:18`) → `Repositories::Identity::SecondFactorRepository#begin_enrollment` (`app/infrastructure/repositories/identity/second_factor_repository.rb:23`), qui construit l'adresse du QR code avec l'émetteur **constant** `ISSUER = "Lnclass"` (même fichier, ligne 9).

**Point fautif** : `app/infrastructure/repositories/identity/second_factor_repository.rb:9`. Émetteur et libellé forment la clé d'une entrée dans les applications d'authentification. Deux environnements donnent donc la même clé avec deux secrets différents, et l'application remplace l'un par l'autre.

**Pourquoi aucun test ne l'a vu** : les tests tournent dans un seul environnement et vérifient l'adresse exacte avec l'émetteur « Lnclass » écrit en dur (`test/infrastructure/repositories/identity/second_factor_repository_test.rb:25`). Aucun test ne fait varier l'environnement. Le test de reproduction se place donc au même niveau (infrastructure), en fixant le nom de l'environnement.

**Écarté** : le secret n'est pas partagé entre environnements. Chaque compte tire le sien à l'activation, chiffré dans sa propre base (rapport `pentest-develop`, garantie n°7). Le domaine n'est pas en cause : il transmet un libellé, pas un émetteur.

- Les gemmes ne sont pas installées dans l'environnement de cadrage (Ruby 3.3 au lieu de 3.4, pas de `rotp`) : les tests se lancent à l'exécution, après `bin/setup`.

### Trou de test comblé et effets de bord écartés

- **Comblé** : quatre tests fixent l'environnement Railway (`Develop`, `production`, absent, nom avec « : ») et lisent l'émetteur décodé. L'ancien test figeait « Lnclass » écrit en dur ; il attend désormais « Lnclass (test) ».
- **Écarté** : le contrôleur n'accepte en retour qu'une adresse commençant par `otpauth://totp/` ; les parenthèses encodées passent (challenger : 422 avec le même QR code).
- **Écarté** : la page rouverte garde le même secret et le même émetteur (correctif `enrolement-secret-stable` intact).
- **Écarté** : la production garde « Lnclass » ; un compte déjà activé n'y voit aucun changement.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Réactivation du second facteur du porteur sur l'environnement dont l'entrée a été écrasée | Action manuelle sur un compte, pas du code | aucun : réinitialisation par un autre membre de l'équipe (ADR-0031) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-30 |
| **PR** | [#114](https://github.com/Lnclassapp/App.Lnclassapp/pull/114) |
| **ADR produits** | Amendement du 2026-09-30 de l'ADR-0031 |
| **UDR produits** | Aucun : aucune vue ne change |
