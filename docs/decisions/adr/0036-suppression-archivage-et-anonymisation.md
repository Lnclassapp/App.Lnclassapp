# ADR-0036 : Aucune cascade vers la production des élèves — archiver le contenu et les classes, refuser la suppression de la taxonomie référencée, anonymiser les comptes

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-14**, bloque la V1 (Lot B) et la V2 |
| **Complète** | [ADR-0005](./0005-decouplage-audit-admin-et-integrite-donnees.md) · [ADR-0016](./0016-conservation-historique-assignations.md) |
| **Amende** | [ADR-0005](./0005-decouplage-audit-admin-et-integrite-donnees.md) : `on_delete: :nullify` des créateurs devient `:restrict` |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0005 ne protège que les créateurs `team`. Dans l'ancien :

- `DELETE /users/:id` détruit en cascade les sessions, les badges et les lacunes de l'élève (**C-24**) ;
- une classe détruit ses assignations, un niveau ses classes (**C-26**) ;
- les clés étrangères `courses → levels/materials`, `essentials → courses`, `exercises → essentials` et `knowledge_gaps → essentials` sont en `ON DELETE CASCADE` : supprimer une matière efface des résultats d'élèves.

Le PRD cadre interdit toute cascade destructrice vers la production élève. Une suppression d'exercice doit conserver les sessions.

## 2. Moteurs de décision

1. Aucune action d'un adulte n'efface le travail d'un élève.
2. La base refuse, même si le code oublie.
3. Un compte peut disparaître de la vue, sans que ses résultats disparaissent des statistiques.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Suppression physique partout | Simple | C-24, C-26 |
| B — Suppression logique partout (`deleted_at`) | Uniforme | Chaque query doit filtrer ; un oubli fait réapparaître |
| C — **Une règle par nature de donnée** | Chaque donnée a le traitement qui lui convient | Quatre règles à connaître |

## 4. Décision

> **Nous interdisons toute cascade vers la production des élèves, et nous traitons chaque nature de donnée par une seule règle : archiver, refuser, ou anonymiser.**

**En base** :

- Toute clé étrangère est en `on_delete: :restrict` (valeur par défaut, ADR-0027). `:cascade` n'est permis que d'un parent vers ses lignes techniques, selon cette liste fermée :
  - `sessions`, `login_attempts`, `totp_credentials`, `backup_codes` et `pin_recovery_codes` → `users` ;
  - `message_dismissals` → `messages`.
- Côté ORM, aucune association `dependent: :destroy` ni `:delete_all` vers `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps`, `classroom_students` ou `classroom_assignments` ; utiliser `dependent: :restrict_with_error`.

**Par nature** :

| Donnée | Règle | Use case | Erreur |
|---|---|---|---|
| Cours, fiche, exercice, question, réponse | **archiver** dès qu'ils ont été publiés (ADR-0035). Suppression physique seulement d'un brouillon jamais publié ni référencé | `Catalog::DeleteDraftCourse`… | `:conflict` sinon |
| Niveau, série, matière, `level_series`, DRENA, école | suppression **refusée** tant qu'une ligne la référence ; une école se passe en `inactive` | `Catalog::DeleteLevel`… | `:conflict` |
| Compte (`users`) | **anonymiser**, jamais supprimer | `Identity::AnonymizeUser` | — |
| Classe | **archiver** en fin d'année (ADR-0041) ; jamais supprimée dès qu'un élève l'a rejointe ou qu'une assignation existe | `Classroom::ArchiveClassroom` | `:conflict` pour une suppression |
| Assignation | **archiver** (ADR-0048) | `Classroom::ArchiveAssignment` | — |
| Annonce | **archiver** (ADR-0045) | `Communication::ArchiveMessage` | — |
| Données techniques | purge planifiée (§6) | jobs récurrents | — |

**Anonymisation** (`Identity::AnonymizeUser`, policy `Identity::DeleteUserPolicy` : `team`), en une transaction :

- `first_name` = « Compte », `last_name` = « supprimé » (valeurs conformes à l'ADR-0037) ;
- `contact` = `NULL` (index unique partiel `WHERE contact IS NOT NULL`) ;
- PIN remplacé par un secret aléatoire jamais communiqué ;
- `anonymized_at` posé ;
- sessions, second facteur, codes et invitations supprimés ;
- adhésions terminées (`left_at`).

Sessions, tentatives, badges et lacunes sont conservés. Un compte anonymisé ne se connecte plus et n'apparaît plus dans les listes nominatives. Le journal (`user.anonymized`) garde l'acteur, pas les données effacées.

## 5. Conséquences

### 🟢 Positives

- C-24 et C-26 sont fermées, par la base autant que par le code.
- Les statistiques d'un exercice restent exactes après le départ d'un élève.

### 🔴 Coûts consentis

- La base garde des lignes que plus personne ne voit (comptes anonymisés, contenu archivé).
- Corriger une erreur de taxonomie référencée demande un renommage, pas une suppression.
- Un droit à l'effacement total, s'il était exigé, demanderait un ADR de plus : l'anonymisation garde les résultats pseudonymes.

## 6. Notes d'implémentation

Purges dans `config/recurring.yml`, exécutées par le worker de l'[ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) :

```yaml
production:
  purge_login_attempts:
    class: Identity::PurgeLoginAttemptsJob      # lignes de plus de 90 jours
    schedule: every day at 3am
  purge_expired_credentials:
    class: Identity::PurgeExpiredCredentialsJob # codes de récupération et invitations périmés depuis 30 jours
    schedule: every day at 3:15am
```

## 7. Comment vérifier que la décision est respectée

- `test/architecture/schema_conventions_test.rb` échoue sur toute clé étrangère `on_delete: :cascade` ou `:nullify` hors de la liste fermée du §4.
- `test/architecture/orm_associations_test.rb` échoue sur un `dependent: :destroy` vers les tables protégées.
- Test d'intégration du PRD : archiver un exercice laisse ses sessions intactes ; supprimer une matière référencée donne `:conflict`.

## 8. Remplace, complète, amende

- **Complète** l'ADR-0005 : la règle anti-cascade s'étend de l'auteur `team` à toute la production élève (C-24).
- **Amende** l'ADR-0005 : `on_delete: :nullify` sur les auteurs devient `:restrict`, puisqu'aucun compte n'est plus supprimé.
- **Complète** l'ADR-0016 : l'archivage s'applique aussi aux classes, au contenu et aux annonces (C-26).

## 9. Points à confirmer par le porteur

- L'anonymisation garde les résultats pseudonymes : ce n'est pas un effacement total.

## Amendement du 2026-09-28 — matricule et rattachements de la direction (ADR-0065, ADR-0066, proposé)

*Chantier [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) ; mise en œuvre par `annuaire-equipe` (ID-23). Statut : **proposé** avec l'[ADR-0065](./0065-matricule-de-l-eleve.md). Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- L'anonymisation met aussi **`users.student_number` à `NULL`** (matricule d'un mineur), comme `contact`.
- Elle termine aussi le **rattachement actif à la direction** (`school_staffs.left_at`), comme les adhésions.
- Retirer un enseignant de l'établissement (ADR-0066) supprime des **liaisons** (`teacher_schools`, `teacher_classrooms`), pas une production : la règle « aucune cascade vers la production des élèves » est tenue.
