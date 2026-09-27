# ADR-0027 : Six contextes bornés, une arborescence par couche puis par contexte, et des conventions de schéma communes

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-02**, bloque la V1 |
| **Remplace** | [ADR-0023](./0023-modelisation-de-l-organisation-scolaire.md) · [ADR-0014](./0014-standardisation-namespaces-et-validation-frontiere.md) §2.2 |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Trois sources placent les mêmes concepts à trois endroits : l'ADR-0023 met DRENA, école et classe dans `Identity`, les conventions dans `school` et `classroom`, l'architecture §5 la DRENA dans `catalog` (**C-03**).

L'ADR-0014 §2.2 prévoit `app/presentation/` et `adapters/`, qui n'existent pas (**C-07**). L'ADR-0018 nomme `Entities::KnowledgeGap` à la racine (**C-49**). Les types assignables à une classe divergent (**C-04**, tranchée par l'ADR-0048 sur la base de ce découpage). Dans l'ancien code, une colonne `assigned_by_id`, clé étrangère vers `users`, reçoit un identifiant de profil enseignant : la même clé désigne deux choses.

## 2. Moteurs de décision

1. Un fichier se range sans hésitation : couche, puis contexte.
2. Une table appartient à un seul contexte.
3. Pas de dossier vide « pour plus tard ».

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — ADR-0023 : organisation scolaire dans `identity` | Déjà écrit | `identity` devient un fourre-tout |
| B — **Six contextes des conventions** | Déjà les dossiers du garde-fou | Il faut corriger l'architecture §5 |
| C — Dossiers par contexte d'abord (`app/catalog/…`) | Contexte isolé | Casse Zeitwerk et tous les blueprints |

## 4. Décision

> **Nous découpons le métier en six contextes bornés, nous rangeons chaque fichier par couche puis par contexte, et nous faisons référencer toute personne par `users.id`.**

| Contexte | Contenu | Tables |
|---|---|---|
| `identity` | comptes, profils, authentification, sessions, invitations, journal d'audit | `users`, profils 1-1 par rôle, `sessions`, `login_attempts`, `pin_recovery_codes`, `totp_credentials`, `backup_codes`, `invitations`, `audit_events` |
| `school` | DRENA, écoles, personnel de direction, rattachement des enseignants | `drenas`, `schools`, `school_staffs`, `teacher_schools` |
| `classroom` | classes, adhésions, enseignement, assignations | `classrooms`, `classroom_students`, `teacher_classrooms`, `classroom_assignments` |
| `catalog` | taxonomie et contenu lisible | `levels`, `series`, `level_series`, `materials`, `courses`, `essentials`, `import_reports` |
| `assessment` | exercices, sessions, badges, lacunes | `exercises`, `questions`, `answers`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps` |
| `communication` | annonces | `messages`, `message_dismissals` |

**Arborescence** :

| Emplacement | Namespace |
|---|---|
| `app/domain/shared/` | `Shared::` (`Result`, `TransactionPort`) |
| `app/domain/{entities,use_cases,ports,dtos,policies}/<contexte>/` | `Entities::<Contexte>::…`, etc. |
| `app/infrastructure/orm/` | `Orm::<Modèle>`, à plat, un modèle par table |
| `app/infrastructure/repositories/<contexte>/` | `Repositories::<Contexte>::…` |
| `app/infrastructure/queries/<contexte>/` | `Queries::<Contexte>::…Query` |
| `app/controllers/<contexte>/` ; espace équipe `app/controllers/teams/` | `<Contexte>::…Controller` ; `Teams::…` hérite de `Teams::BaseController` |
| `app/jobs/<contexte>/`, `config/routes/<contexte>.rb`, `config/locales/<contexte>/<écran>.fr.yml`, `db/seeds/<contexte>.rb` | selon la [boucle de travail](../../chantiers/refonte-application/boucle-de-travail.md) |

**Interdits** : `app/presentation/`, `adapters/`, `app/services/`, `app/models/` hors `ApplicationRecord`, et tout fichier à la racine de `entities/`, `use_cases/`, `ports/`, `policies/`, `repositories/`, `queries/`.

**Relations entre contextes** : un use case peut dépendre du port d'un autre contexte, injecté, et ne connaît que les entités que ce port renvoie. Les queries peuvent joindre des tables de plusieurs contextes : la lecture n'est pas découpée.

**Conventions de schéma** :

- Clés primaires `bigint` (ADR-0029).
- Toute clé étrangère a sa contrainte en base, `on_delete: :restrict` par défaut (ADR-0036).
- Toute énumération est une colonne `string` avec une contrainte `CHECK` sur la liste des valeurs.
- Toute table de liaison et toute colonne d'auteur (`author_id`, `assigned_by_id`, `invited_by_id`…) référence `users.id`, jamais un profil.
- Les attributs propres à un rôle vivent dans une table de profil 1-1 clé `user_id`.

## 5. Conséquences

### 🟢 Positives

- Une seule place par fichier, vérifiable par un test d'arborescence.
- La confusion profil / utilisateur de l'ancien `assigned_by_id` ne peut plus exister.
- La DRENA quitte `catalog` : la taxonomie pédagogique ne dépend plus de l'administration.

### 🔴 Coûts consentis

- `teacher_schools` vit dans `school` et `teacher_classrooms` dans `classroom` : le rattachement d'un enseignant touche deux contextes.
- `Orm::` reste à plat : on ne voit pas le contexte d'un modèle à son nom. Le tableau ci-dessus fait foi.
- [`architecture.md`](../../guide/architecture.md) §5 et le glossaire §1-2 sont corrigés le 2026-09-25.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Ports::Assessment::KnowledgeGapRepositoryPort
# Rôle : contrat de persistance des lacunes
# ADR  : 0027, 0043
module Ports
  module Assessment
    module KnowledgeGapRepositoryPort
      def find_pending(student_id:, essential_id:) = raise(NotImplementedError)
      def create_pending(student_id:, essential_id:, source_session_id:) = raise(NotImplementedError)
    end
  end
end
```

Fichier : `app/domain/ports/assessment/knowledge_gap_repository_port.rb` (C-49 : fini `Entities::KnowledgeGap` à la racine).

## 7. Comment vérifier que la décision est respectée

- `test/architecture/layout_test.rb` échoue si un fichier `.rb` est à la racine d'un dossier de couche, si un sous-dossier n'est pas l'un des six contextes (ou `shared`), ou si `app/presentation`, `app/adapters` ou `app/services` existent.
- `test/architecture/schema_conventions_test.rb` lit `db/schema.rb` et échoue sur une clé primaire non `bigint`, une clé étrangère sans contrainte, ou une colonne `*_by_id` ou `author_id` qui ne référence pas `users`.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0023 en entier (C-03) et l'ADR-0014 §2.2 (C-07).
- **Remplace** les noms à la racine de l'ADR-0018 §3.2 (C-49).
- Fournit le découpage sur lequel l'ADR-0048 ferme C-04.

## 9. Points à confirmer par le porteur

- `teacher_schools` est rangé dans `school` (rattachement à l'établissement), et non dans `classroom`.
- `audit_events` est rangé dans `identity` : le journal est centré sur l'acteur.

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Erratum — emplacement de `TransactionPort`.** L'arborescence du §4 le range dans `app/domain/shared/`, sous `Shared::`. Il vit dans **`app/domain/ports/shared/transaction_port.rb`**, sous le nom **`Ports::Shared::TransactionPort`**, comme le nomme l'ADR-0026 : c'est un port, rangé avec les autres ports. Son adaptateur est `Repositories::Shared::Transaction`.
- `app/domain/shared/` ne contient que `Shared::Result`.
