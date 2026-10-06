# ADR-0036 : Aucune cascade vers la production des élèves — archiver le contenu et les classes, refuser la suppression de la taxonomie référencée, anonymiser les comptes

| | |
|---|---|
| **Statut** | Accepté — *amendé le 2026-10-02 : suppression sur demande, demandes enregistrées et rappelées, résultats effacés (lot R de `fonctions-espace-eleve`) ; l'amendement « anonymisation automatique » du même jour est retiré* |
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

## Amendement du 2026-10-02 — anonymisation automatique 30 jours après le départ · Statut : Retiré (porteur, 2026-10-02)

> **Retiré le jour même par le porteur** : « pas d'anonymisation, les données doivent être accessibles par l'établissement et l'élève comme archive ». Les 30 jours s'appliquent à la **suppression sur demande** : une demande de suppression de compte est traitée dans les 30 jours. Aucun job d'anonymisation automatique. La règle « anonymiser, jamais supprimer » du §4 reste la manière technique de traiter une demande de suppression, sous réserve de la validation des juristes (`pages-publiques.md`, relecture). Le texte ci-dessous est conservé pour mémoire.

*Chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/plan.md), lot R ; règle de conservation donnée par le porteur le 2026-10-02 pour la page « Protection des données » ([UDR-0063](../udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md)). **Proposé** : la définition du « départ » reste à trancher (questions ci-dessous). Le texte ci-dessus reste en vigueur tant que cet amendement n'est pas accepté.*

### Constat

Le porteur fixe la conservation : **30 jours après le départ**, les **données personnelles sensibles sont anonymisées par défaut** ; les **informations d'usage** (sessions, réponses, badges, lacunes, assignations) **restent**, pour la progression et le suivi par les enseignants et l'établissement.

Le §4 ci-dessus prévoit l'anonymisation, mais seulement à la main, par l'équipe (`Identity::AnonymizeUser`, `DeleteUserPolicy`). Au 2026-10-02 :

- **`Identity::AnonymizeUser` n'existe pas** (aucun use case dans `app/domain/use_cases/identity/`) ; seule la colonne `users.anonymized_at` et la lecture `User#anonymized?` existent ;
- **aucune purge du §6 n'est programmée** : `config/recurring.yml` ne contient que la purge des fichiers non rattachés (ADR-0047) ; `PurgeLoginAttemptsJob` et `PurgeExpiredCredentialsJob` n'existent pas.

La politique de protection des données ne peut donc pas promettre « 30 jours » tant que ce qui suit n'est pas livré.

### Décision proposée

> **Nous anonymisons automatiquement un compte 30 jours après son départ, par un job quotidien, avec le même use case que l'anonymisation faite par l'équipe ; les données d'usage restent rattachées au compte anonymisé.**

- **`UseCases::Identity::AnonymizeUser`** : la transaction du §4 (nom « Compte supprimé », `contact` nul, PIN aléatoire, `anonymized_at`, sessions, second facteur, codes et invitations supprimés, adhésions terminées), **plus la photo de profil effacée** (ADR-0060, `ProfilePhotoStorePort#remove`). Deux appelants : l'équipe (`DeleteUserPolicy`, inchangée) et le système (acteur `nil`, policy `Identity::AutoAnonymizePolicy` qui n'autorise que l'appel du job). Journal : `user.anonymized`, avec `metadata.reason` = `team` ou `retention`.
- **`Identity::AnonymizeDepartedUsersJob`**, dans `config/recurring.yml` (`every day at 3:30am`) : il lit les comptes non anonymisés dont le départ date de plus de 30 jours (`Ports::Identity::UserRepositoryPort#departed_before(at:)`, par lots de 500) et appelle `AnonymizeUser` pour chacun. Idempotent : un compte déjà anonymisé est ignoré.
- **Ce qui reste** : sessions, réponses, badges, lacunes, assignations, journal d'audit (sans donnée effacée). Ils restent rattachés au compte anonymisé : les statistiques de la classe et du pilotage ne changent pas (§5, « les statistiques d'un exercice restent exactes »).
- **Hors de cet amendement** : les purges des tentatives de connexion (90 jours) et des codes périmés (30 jours) du §6 restent à programmer ; le lot R les ajoute s'il en a le temps, sinon elles sont signalées dans le journal du chantier.

### Questions à trancher avant d'accepter

1. **Qu'est-ce qu'un « départ » ?** Trois lectures possibles, non exclusives :
   - un compte **fermé à la demande** (de l'utilisateur, d'un parent, de l'établissement) ;
   - un élève **sorti de toute classe** (toutes ses adhésions ont un `left_at`) ; mais un élève qui change de classe passe par cet état un instant ;
   - une **fin d'année scolaire sans réinscription** (classe archivée, ADR-0041, sans nouvelle adhésion à la rentrée) ;
   - et, pour un enseignant : retiré de son établissement (ADR-0071) ? sans classe déclarée ?
2. **Quelles données sont « sensibles » ?** Nom et prénom(s), numéro, photo, genre ? L'adresse IP des sessions, des tentatives et du journal ? Le numéro saisi dans `login_attempts.contact` ?
3. **Sessions et badges** : rattachés au compte anonymisé (proposition, qui garde les statistiques), ou détachés ?

### Vérification prévue

- `test/domain/use_cases/identity/anonymize_user_test.rb` : chaque donnée sensible est effacée, chaque donnée d'usage reste ; refus pour un enseignant, un élève, la direction.
- `test/jobs/identity/anonymize_departed_users_job_test.rb` : un compte parti depuis 31 jours est anonymisé, un compte parti depuis 29 jours ne l'est pas, un second passage ne change rien.
- `test/config/recurring_test.rb` : le job est programmé en production.

## Amendement du 2026-10-02 (2) — suppression sur demande : demandes enregistrées, rappel avant 30 jours, résultats effacés · Statut : Accepté (porteur, 2026-10-02)

*Chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/plan.md), lots R2 et R3. Réponses du porteur aux deux questions laissées ouvertes par le lot R : « retire l'élève des stats » et « oui, une notification pour le rappel de suppression ».*

### Ce qui change dans le §4

1. **Les résultats d'un compte supprimé sont effacés** (lot R2). « Sessions, tentatives, badges et lacunes sont conservés » ne vaut plus pour un compte supprimé sur demande : `Identity::AnonymizeUser` efface aussi, dans la même transaction, ses sessions d'exercice, leurs réponses (`question_attempts`), ses badges et ses lacunes. Il ne compte plus dans aucune statistique : réussite de la classe (UDR-0029), suivi d'un exercice, « Travail des élèves », pilotage de l'équipe. La règle « aucune cascade » reste : l'effacement est explicite, ligne par ligne, dans un port dédié, jamais par `on_delete: :cascade` ni `dependent:`. Le compte lui-même reste anonymisé (« Compte supprimé »), pas supprimé, pour les auteurs et le journal.
2. **Une demande de suppression s'enregistre à sa réception** (lot R3). Table `account_deletion_requests` : le compte, la date de réception (`requested_on`), l'auteur, l'état (`pending`, `processed`, `cancelled`) et sa date ; une seule demande `pending` par compte. L'équipe `admin` (ADR-0038) l'enregistre depuis la fiche du compte, l'annule si l'élève ou son parent se rétracte, ou la traite : la modale de suppression reprend alors la date enregistrée, et l'anonymisation passe la demande en `processed` dans sa transaction. Une suppression sans demande enregistrée reste possible (la date est saisie dans la modale, comme au lot R). Journal : `user.deletion_requested`, `user.deletion_request_cancelled`, puis `user.anonymized`.
3. **Rappel** (lot R3). Échéance = date de réception + 30 jours. L'accueil de l'équipe montre à l'`admin` une carte « Demandes de suppression » : le nombre en attente et la plus proche échéance ; **en ambre** quand il reste 5 jours ou moins (à partir du 25e jour), « En retard » au-delà de 30 jours. Elle mène à la liste des demandes en attente, triée par échéance. Le rappel est lu à l'affichage, sans job. Aucun courriel : l'application n'a pas d'envoi configuré (`config.action_mailer` sans SMTP) ; un rappel par courriel ou WhatsApp serait un autre chantier.

### Conséquences

- 🟢 Un compte supprimé ne laisse plus de trace nominative ni statistique ; la promesse de la page « Protection des données » devient simple.
- 🟢 Une demande ne peut plus être oubliée : elle est visible dès sa réception et le délai de 30 jours est rappelé.
- 🔴 Les statistiques passées d'une classe changent après une suppression (un élève de moins). Accepté par le porteur.
- 🔴 Une table et trois écrans de plus pour l'équipe.

### Vérification

- `test/domain/use_cases/identity/anonymize_user_test.rb` : l'effacement des résultats et la clôture de la demande sont appelés dans la transaction ; rien n'est écrit en cas de refus.
- Un test de repository sur base réelle : les sessions, réponses, badges et lacunes de l'élève sont effacés, ceux d'un autre élève restent ; une lacune résolue par une session d'un autre élève ne bloque pas l'effacement.
- Un test de la réussite de la classe (UDR-0029) avant et après une suppression.
- Les tests des demandes : enregistrer, annuler, traiter ; une seule en attente par compte ; date future refusée ; refus pour `content`, `field` et tout autre rôle ; la carte en ambre au 25e jour, « En retard » au 31e.
