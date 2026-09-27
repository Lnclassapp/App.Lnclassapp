# Journal — Page profil de chaque utilisateur

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-27 | Lot 0 : les routes du profil sont déclarées et « Mon profil » devient actif dès ce lot ; `test/system/role_homes_test.rb` attend désormais un lien vers `profile_path` (sans le suivre). `NavigationHelper` n'est pas touché. | Le plan fait de `profile_path` le contrat qui active l'entrée d'elle-même. Garder l'entrée inactive aurait demandé un cas spécial dans `NavigationHelper`, que le Lot A aurait dû défaire. Le chantier part en **une seule PR** vers `Develop` : aucun utilisateur ne voit l'entrée active avant que `Identity::ProfilesController` existe. Le Lot A garde la propriété du test des accueils pour y ajouter le clic vers la page. | Non (ADR-0055 couvre le contrat) |
| 2026-09-27 | `VerifyOwnPin#call(actor:, user:, pin:, ip:)` rend `:locked` dès l'échec qui verrouille (et pas seulement à la tentative suivante, comme la connexion). Il enregistre aussi le succès, sur le compteur `pin` de la connexion (`KIND = Authenticate::KIND`). | Le PRD renvoie vers la connexion le compte verrouillé par ces échecs (PR-07) : le contrôleur doit le savoir tout de suite. Le succès remet le compteur à zéro comme une connexion réussie. La logique de palier reste celle de `Entities::Identity::Lockout`, partagée, et `login.locked` est audité au même palier. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Hypothèse fausse du plan (Lot 0, « Done quand ») : une route déclarée sans contrôleur ne répond **pas** 404. Rails lève `ActionDispatch::MissingController` (un `NameError`, absent des `rescue_responses`) : exception en test, **500** en production. Conséquence : la branche ne se déploie pas entre le Lot 0 et le Lot A ; le Lot A livre `Identity::ProfilesController` en premier. La preuve retenue au Lot 0 est un test de routage qui reconnaît les quatre routes sans charger leur contrôleur (`test/routing/v1_routes_test.rb`).
- `test/routing/v1_routes_test.rb` était instable avant ce chantier : selon la graine, `first_match` interrogeait le routeur avant que les routes paresseuses de Rails 8 soient dessinées (`nil` au lieu de `teams/courses#new`). Corrigé au passage en lisant `Rails.application.routes.routes` d'abord.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `test/routing/v1_routes_test.rb` affirmait que `profile_path` n'existait pas en V1 : il fallait le modifier au Lot 0 (fichier absent du plan). `profile_path` passe dans `FROZEN`.
- Une fois `profile_path` dessinée, plus aucune route de `NavigationHelper::ACCOUNT_LINKS` ne manque : la branche « entrée inactive » d'`account_links` n'était plus couverte (99,92 % de branches). Un test de `test/helpers/navigation_helper_test.rb` la couvre, sans toucher au helper.
- `UseCasePoliciesTest` exige une `policy:` injectée dans tout use case : `VerifyOwnPin` prend `UpdateSelfPolicy`, même si `ChangeOwnContact` et `ChangeOwnPin` l'appellent déjà.
- `Orm::User` n'a aucune validation : l'unicité du numéro repose sur l'index `index_users_on_contact`. `update_contact` écrit dans un point de sauvegarde pour que le refus n'invalide pas la transaction du use case (même motif que `RegistrationRepository`).

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
