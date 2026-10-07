# Journal — Inscription des élèves sans code de classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-07 | Lot 0 : `ManageClassroomMembersPolicy#call(actor:, classroom:)`, sans `teaches:` ni `staff_school_id:` | L'acteur porte déjà son établissement et la classe ses enseignants ; deux paramètres de moins à calculer par l'appelant | Non : `plan.md` corrigé |
| 2026-10-07 | Lot 0 : les deux adresses de la cascade s'appellent `school_picker_levels` et `school_picker_classrooms` | `school_level_classrooms` est déjà le nom d'une route de l'équipe | Non |
| 2026-10-07 | Lot 0 : la migration n'entre pas dans `LATER` de `growth_migrations_test.rb` | Ce test rejoue les tables de croissance ; aucune colonne du lot n'en dépend | Non : `plan.md` corrigé |
| 2026-10-07 | Lot 0 : `db/schema.rb` complété à la main, ligne par ligne | PostgreSQL 18 (poste local) réécrit toutes les contraintes `CHECK` du fichier dans une autre forme ; le dump brut aurait changé 45 lignes sans rapport | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Grill, Q8 (2026-10-07).** La question disait que l'enseignant remplace déjà le code de sa classe. C'est décidé par l'ADR-0041 (`RegenerateJoinCode`), jamais construit. L'hypothèse venait d'un commentaire (« code inconnu ou remplacé »), pas du code. Corrigé dans le memo avant la phase 2 : « Changer le lien » est un geste nouveau.
- **Lot 0 (2026-10-07).** Le plan ne listait pas les fichiers de test qui écrivent une adhésion directement : `joined_via` sans défaut les casse tous. Même découverte que le Lot 0 de `inscription-enseignant` ; à chercher par `grep` **avant** d'écrire le plan d'un lot qui retire un défaut.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Une adhésion est **une ligne par élève et par classe** (index unique) : revenir dans une classe quittée ne peut pas créer de ligne. `add_primary` rouvre donc la ligne close ; avant le Lot 0, ce retour donnait `already_member`.
- **PostgreSQL 18 en local** : cinq tests échouent sans rapport avec le chantier (`PG::RestrictViolation` au lieu de `ActiveRecord::InvalidForeignKey` sur les clés `RESTRICT`), et `db:migrate` réécrit tous les `CHECK` de `db/schema.rb`. Parade sur ce poste : un PostgreSQL 16 (celui de la CI) dans `~/.local/share/pg16`, port 5433, et `DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5433` — sans nom de base, Rails garde ceux de `config/database.yml`. Avec lui : 4 565 tests, 0 échec, 0 erreur. Ne pas committer le dump brut de PostgreSQL 18.
- `bin/validate_hitl`, cité par `docs/guide/onboarding.md` §4, n'existe pas : le contrôle des en-têtes est dans `.githooks/pre-commit`. Les bases locales s'appellent `app_lnclassapp_development_lnclassapp` et `app_lnclassapp_test_lnclassapp`, pas les noms du §1. Deux écarts de documentation, à traiter par un chantier `docs/`.
- Les routes se dessinent avant leurs contrôleurs (`test/routing/v1_routes_test.rb`, `first_match`) : le Lot 0 peut les poser toutes.

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
