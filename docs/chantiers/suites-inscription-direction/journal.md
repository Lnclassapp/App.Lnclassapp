# Journal — Suites de l'inscription de la direction

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Pas de `plan.md` : trois corrections menées l'une après l'autre par un seul exécutant, sans lot parallèle ni migration ; les portes de sortie sont dans le memo | Le cycle bugfix autorise le lot unique ; les fichiers partagés (locales) n'ont pas de concurrent | Non |
| 2026-10-04 | Port `InvitationRepositoryPort#destroy_all_for(user_id:, contact:)`, injecté dans `AnonymizeUser` et `PurgeArchivedStaff` | L'ADR-0036 §4 exigeait l'effacement, mais aucune opération ne le permettait | ADR-0077 §4.3 précisé ; l'ADR-0036 §4 est appliquée, sans changement |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le memo comptait quatre pages sans `h1` sur téléphone. « Rejoindre une classe » en a déjà un dans sa carte : le test système, qui vérifie les quatre pages, l'a montré. Le memo est corrigé.
- La fabrique `create_user` donne `gender: "female"` par défaut : les tests existants comparaient « retiré » pour Kofi comme pour Aya. Les fixtures nomment maintenant Kofi `male`.
- Le PostgreSQL du conteneur s'était arrêté entre deux sessions : `service postgresql start`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Rapport de root cause

**(1) Accord**
- Chaîne : `SchoolAdmin::StaffMembersController#destroy` et `Teams::SchoolStaffMembersController#destroy` → `t("shared.school_staff.done", name:)` ; `teams/homes/_archived_staff` et `teams/schools/_archived_staff` → `Queries::School::SchoolStaffQuery#archived` → `ArchivedRow`.
- Cause : `config/locales/shared/school_staff.fr.yml:20`, `config/locales/teams/homes.fr.yml:29` et `config/locales/teams/school_staff.fr.yml` (`line`, `due`) sont écrits au masculin. `ArchivedRow` (`app/infrastructure/queries/school/school_staff_query.rb`) ne lit pas `users.gender` : la vue ne peut pas accorder.
- En une phrase, sans les mots du symptôme : le texte ne reçoit pas le genre de la personne qu'il nomme.
- Trou de test : les tests comparent `I18n.t(...)` à lui-même, toujours avec un nom, jamais avec un genre.

**(2) Invitation**
- Chaîne : `School::PurgeArchivedStaffJob` → `UseCases::School::PurgeArchivedStaff#purge` ; `Teams::AccountDeletionsController` → `UseCases::Identity::AnonymizeUser#anonymize`.
- Cause : `app/domain/use_cases/identity/anonymize_user.rb` (`anonymize`) et `app/domain/use_cases/school/purge_archived_staff.rb` (`purge`) n'effacent aucune invitation. `Ports::Identity::InvitationRepositoryPort` n'a d'ailleurs aucune opération d'effacement, alors que l'ADR-0036 §4 l'exige.
- En une phrase : la liste des effacements a été écrite sans la table des invitations.
- Trou de test : les tests d'anonymisation vérifient chaque effacement prévu par le use case, mais aucun ne liste les tables qui portent le numéro.

**(3) Titre**
- Cause : `app/views/identity/school_staff_registrations/new.html.erb`, `identity/teacher_registrations/new.html.erb`, et `identity/invitations/show.html.erb`. (`classroom/joins/new.html.erb` a déjà un `h1` dans sa carte : le memo l'avait compté à tort.) Le seul `h1` est dans `<section class="hidden … md:flex">`, et l'en-tête mobile (`md:hidden`) n'a qu'un `<p>`.
- En une phrase : le titre principal n'existe que dans la colonne réservée aux grands écrans.
- Trou de test : les tests de page cherchent `h1` sans `visible: true` à 390 px, et les tests de contrôleur ne voient pas le CSS.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| L'IP du journal d'audit gardée 12 mois puis effacée, pour tous les comptes (décision du porteur) | Règle nouvelle et job de rétention : c'est une feature | `retention-ip-audit` |
| « %{name} a été retiré(e) de l'établissement » (enseignant retiré, `school_admin.teachers`) | Même accord, autre parcours ; hors du périmètre du memo | à ouvrir (petit `bugfix`) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
