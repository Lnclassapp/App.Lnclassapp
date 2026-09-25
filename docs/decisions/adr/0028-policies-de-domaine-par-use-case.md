# ADR-0028 : Une policy de domaine par use case, appelée en premier, qui refuse par `:forbidden`

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-04**, bloque la V1 |
| **Complète** | [ADR-0004](./0004-autorisation-multi-etablissements-enseignants.md) §3.3 · [ADR-0015](./0015-strategie-de-tests-metier-isolement-des-policies.md) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancien dépôt n'a qu'une policy, `Policies::ClassroomAccessPolicy`, qui renvoie un booléen ; le reste de l'autorisation est absent ou dans les contrôleurs. L'exploration du 2026-09-22 a trouvé des trous que l'ancien `securite.md` ne cite pas : tout compte connecté peut créer, modifier, supprimer ou importer des fiches (CA-12 à CA-15) et des établissements (SC-06 à SC-08) ; on gère le personnel d'une autre école (SC-11 à SC-14) ; `GET /classrooms` renvoie la liste nationale (CL-28) ; `GET /users/:id` expose le contact de n'importe quel compte (TR-21).

Le PRD cadre exige une policy par use case et un test de refus.

## 2. Moteurs de décision

1. Aucune écriture sans décision d'autorisation explicite et testée.
2. La règle vit dans le domaine, pas dans un `before_action`.
3. Le refus a la même forme partout.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — `before_action` dans les contrôleurs | Rapide | Invisible depuis le domaine ; c'est ce qui a laissé les trous |
| B — Pundit | Outillé | Couplé aux modèles ActiveRecord, hors domaine |
| C — **Policy de domaine par use case** | Pure, testable, injectée | Un fichier de plus par use case |

## 4. Décision

> **Nous donnons à chaque use case une policy de domaine, injectée et appelée avant toute écriture, qui renvoie un `Shared::Result` : succès, ou échec `:forbidden`.**

**Forme** : `Policies::<Contexte>::<Nom>Policy`, dans `app/domain/policies/<contexte>/`, méthode unique `call(actor:, **faits)`. Aucune lecture en base : la policy reçoit des entités déjà chargées (par exemple une `classroom` qui porte ses `teacher_ids`).

**Acteur** : `Entities::Identity::Actor`, un `Data` construit par le contrôleur à partir de la session : `user_id`, `role` (`:student`, `:teacher`, `:school_admin`, `:team`), `team_role` (ADR-0038), `school_id` (école de rattachement ou `nil`). Un visiteur anonyme est `actor: nil`.

**Ordre dans un use case** : valider le DTO (`:invalid`) → charger les faits (`:not_found`) → appeler la policy (`:forbidden`) → écrire. Rien n'est écrit avant la dernière étape.

**Lectures** : le contrôleur appelle la policy de lecture (`…::Read…Policy`) sur la `Row` renvoyée par la query avant de rendre la page. Une query de liste reçoit l'acteur et filtre par lui : aucune liste n'est nationale par défaut.

**Traduction** : `RendersResult` (ADR-0026) répond `:forbidden` par une 403, ou par une redirection vers la connexion si `actor` est `nil`. Une policy de **lecture** peut répondre `:not_found` au lieu de `:forbidden` quand la réponse ne doit pas confirmer que la ressource existe (brouillon, ADR-0035).

**Use cases d'authentification**, seuls exemptés de policy, listés nommément dans le test d'architecture avec leur raison : `Identity::Authenticate`, `Identity::ResetPinWithCode` et `Identity::AcceptInvitation`, exemptions acceptées par le porteur le 2026-09-25. Ils sont l'acte même d'établir l'identité ; leur protection est la limitation de débit et le verrouillage (ADR-0050, ADR-0032, ADR-0038).

**Adhésion par code** : `Classroom::JoinWithCode` **a** une policy, `Classroom::JoinPolicy`, qui accepte un acteur anonyme (`actor: nil`) ou un élève. Elle vérifie que la classe est `active` (donc non archivée), que le code saisi est égal au `join_code` courant (valide et non révoqué, ADR-0041) et que l'effectif actif est sous `max_students`. Sinon elle répond `:forbidden`, avec `errors[:base]` qui nomme la raison (`classroom_archived`, `join_code_revoked`, `classroom_full`). Un code qui ne correspond à aucune classe donne `:not_found` avant la policy.

**Policies de la V1** (les autres vagues ajoutent les leurs sur le même modèle) :

| Policy | Autorise |
|---|---|
| `Catalog::ReadPublishedPolicy` | tout acteur connecté sur un contenu `published` ; `team` sur tout statut |
| `Catalog::ManageContentPolicy` | `team` : contenu, imports de cours, de fiches et d'exercices (ADR-0039) |
| `Catalog::ManageTaxonomyPolicy` | `team` (sous-rôles `admin` et `content` à partir de la V4) : niveaux, séries, `level_series`, matières (ADR-0034) |
| `Assessment::StartSessionPolicy` | `student`, sur un exercice publié dont les parents sont publiés |
| `Assessment::ReadSessionPolicy` | l'élève propriétaire ; l'enseignant d'une classe active de l'élève ; `team` |
| `Assessment::RevealAnswersPolicy` | l'élève, pour une question déjà tentée dans sa session ; `team` |
| `Classroom::JoinPolicy` | acteur anonyme ou `student` ; classe active, code valide et non révoqué, effectif sous le plafond |
| `Classroom::TeachPolicy` / `Classroom::AssignPolicy` | l'enseignant présent dans `teacher_classrooms` pour la classe ; `team` |
| `School::ManageSchoolPolicy` | `team` (sous-rôles `admin` et `field` à partir de la V4) : DRENA, établissements, imports d'établissements (ADR-0030, ADR-0034, ADR-0039) |
| `Classroom::ManageClassroomPolicy` | `team` en V1 ; la direction de l'école à partir de la V2 (ADR-0030) |
| `Identity::ReadUserPolicy` | soi-même ; l'enseignant pour les élèves de ses classes (sans le contact) ; `team` |
| `Identity::InviteTeamPolicy`, `Identity::DeleteUserPolicy` | `team` (sous-rôle `admin` à partir de la V4, ADR-0038) |
| `Identity::UpdateSelfPolicy` | soi-même |

## 5. Conséquences

### 🟢 Positives

- Les trous CA-12 à CA-15, SC-06 à SC-14, CL-28 et TR-21 deviennent chacun un test de refus, écrit avant le code.
- Une policy se teste sans base, en quelques millisecondes (ADR-0015).

### 🔴 Coûts consentis

- Un fichier de policy et un fichier de test par use case, même quand la règle tient en une ligne.
- Le contrôleur doit charger un acteur complet (rôle, école) à chaque requête.
- `Policies::ClassroomAccessPolicy#authorized?` n'est pas reprise : elle est remplacée par `Classroom::TeachPolicy`.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Policies::Classroom::TeachPolicy
# Rôle : autorise l'enseignant de la classe et l'équipe à agir sur une classe
# ADR  : 0028, 0030
module Policies
  module Classroom
    class TeachPolicy
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.role == :team
        return Shared::Result.success if actor.role == :teacher && classroom.teacher_ids.include?(actor.user_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/architecture/use_case_policy_test.rb` échoue si le constructeur d'une classe de `UseCases::` n'accepte pas `policy:`, sauf pour les trois use cases d'authentification listés. `Classroom::JoinPolicy` a un test de refus pour chacune des trois raisons.
- Chaque policy a son test dans `test/domain/policies/<contexte>/`, avec au moins un cas de refus par rôle non autorisé.
- Chaque use case a un test « refus → le repository double n'a rien enregistré ».

## 8. Remplace, complète, amende

- **Complète** l'ADR-0004 §3.3 : la forme booléenne devient un `Result`, et la règle est étendue à tous les use cases.
- **Complète** l'ADR-0015 : le test de refus est obligatoire, et un test par use case vérifie qu'un refus n'écrit rien.

## 9. Points à confirmer par le porteur

- L'enseignant voit le nom de ses élèves, mais pas leur contact téléphonique (`Identity::ReadUserPolicy`).

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

Huit policies s'ajoutent au tableau du §4.

| Policy | Autorise |
|---|---|
| `Identity::SessionPolicy` | le porteur du jeton, sur **sa** session : reprise et déconnexion ; refus si la session est absente |
| `Identity::SecondFactorPolicy` | un compte `team` : l'enrôlement si le second facteur n'est pas confirmé ; la vérification s'il l'est et que la session n'est pas encore vérifiée (ADR-0031) |
| `Identity::RegisterTeacherPolicy` | un acteur anonyme seulement : seul un visiteur s'inscrit comme enseignant |
| `Identity::IssuePinRecoveryCodePolicy` | l'enseignant, pour un élève de ses classes ; `team`, pour tout compte sauf le sien (ADR-0032) |
| `Identity::ResetSecondFactorPolicy` | `team`, sur un autre compte `team`, jamais le sien (ADR-0031) |
| `Classroom::DeclareTeachingPolicy` | l'enseignant, sur une classe active de son école principale (ADR-0030) |
| `Classroom::ReadClassroomPolicy` | `team` ; l'enseignant de la classe ; l'élève dont c'est la classe principale active. La liste nominative n'est montrée qu'à `team` et à l'enseignant |
| `Assessment::SubmitAttemptPolicy` | l'élève propriétaire d'une session `started` (ADR-0054) |

- Les mécanismes de session (reprise, déconnexion, second facteur) ont donc une policy : les exemptions restent les trois use cases d'authentification listés au §4.
- La lecture d'un rapport d'import applique la policy de son type (`School::ManageSchoolPolicy` ou `Catalog::ManageContentPolicy`) : aucune policy n'est propre aux rapports.
