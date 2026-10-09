# ADR-0085 : L'élève entre dans une classe choisie ou donnée par un lien à jeton remplaçable, sans code de classe, et quiconque gère la classe peut l'en retirer

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-07 — validation rapportée par le développeur du chantier)* |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/inscription-eleve-sans-code`](../../chantiers/inscription-eleve-sans-code/prd.md) |
| **Remplace** | — *(amende ADR-0041 §4 « Code d'adhésion », ADR-0040 pour le changement de classe, ADR-0065 pour les gestes de la direction)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis la V1, **le code de classe est la seule porte** d'un élève (ADR-0041, UDR-0009) : il le saisit sur « Rejoindre une classe », ou il ouvre le lien `/c/<code>` qui le porte. Le code fait trois choses à la fois : il **désigne** la classe, il **prouve** que l'élève y a été invité, et il se **retire** (prévu par l'ADR-0041, jamais construit : ni `RegenerateJoinCode` ni `CloseJoinCode` n'existent dans le code).

Ce choix était délibéré. L'ancienne application avait une cascade niveau → école → classe qui laissait rejoindre n'importe quelle classe sans son code ; l'inventaire de la refonte l'a classée comme un défaut (ID-08, CL-08) et l'UDR-0009 l'a écartée : « Aucune cascade école + niveau → classe n'existe. »

Le constat du 2026-10-07 renverse la priorité : **des élèves veulent s'inscrire seuls, alors qu'aucun enseignant de leur classe n'est sur Lnclass** (memo Q1). Personne ne peut leur donner de code. Le porteur a décidé de retirer le code de classe et de donner à l'élève deux flux, comme à l'enseignant (ADR-0083 ; `inscription-enseignant`, Q20).

**Cet ADR rétablit donc, en connaissance de cause, la cascade que l'UDR-0009 avait écartée.** Ce qui la rend acceptable aujourd'hui n'est pas qu'elle soit devenue sûre : c'est qu'on lui ajoute une sortie (le retrait d'un élève) et une visibilité (les nouveaux arrivés), et que l'aperçu public reste aussi pauvre qu'avant.

## 2. Moteurs de décision

1. Un élève s'inscrit seul dans une classe **sans enseignant**. Aucune étape ne peut dépendre d'un enseignant (memo Q1, Q6).
2. L'entrée immédiate ouvre toute classe à quiconque : il faut pouvoir **voir** une arrivée et **défaire** une entrée, y compris dans une classe sans enseignant (memo Q6, Q11).
3. Un élève retiré ne doit pas revenir seul une minute plus tard (memo Q7).
4. Ne pas divulguer plus qu'aujourd'hui : l'aperçu d'une classe dit trois noms, jamais un effectif, un enseignant ni un élève (UDR-0009 §2.2).
5. Garder ce qui existe : la transaction de `JoinWithCode`, le verrou de la classe et le plafond (ADR-0041), la classe principale unique (ADR-0040), `Shared::Result`, la forme des jetons de l'ADR-0083. Le nom et les prénoms se saisissent dans deux champs, selon l'ADR-0037 (amendement du 2026-10-08, memo Q16 : `FullName` est retiré avec le retour de l'enseignant à deux champs).

## 3. Options envisagées

### Preuve d'appartenance

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder le code, ajouter la cascade à côté | Rien à retirer | Deux systèmes ; le code ne prouve plus rien dès que la cascade ouvre la même classe |
| B — **Entrée immédiate, retrait après coup** | Marche sans enseignant ; un seul état d'adhésion | N'importe qui entre : la protection est a posteriori |
| C — Demande en attente, acceptée par un enseignant | Protège avant l'entrée | Bloque l'élève d'une classe sans enseignant ou dont l'enseignant se tait ; essayée au grill puis abandonnée (memo Q2 à Q6) |

### Lien de classe

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `/c/<public_id>` de la classe | Aucune colonne | Ne se change pas ; l'identifiant public circule déjà dans les adresses des enseignants |
| B — **Jeton opaque remplaçable sur la classe** | Se change d'un geste ; ne dit rien de la classe | Une colonne ; les anciens liens à code meurent |
| C — Jeton stable, comme `/i/<jeton>` (ADR-0083) | Même règle que l'enseignant | Le lien de classe lève un retrait (memo Q7) : il donne un droit que la voie standard n'a pas, donc il doit pouvoir être repris (memo Q8) |

### Mémoire du retrait

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **Colonnes sur l'adhésion** (`removed_at`, `removed_by_id`) | L'index unique `(classroom_id, student_id)` garantit déjà une ligne par élève et par classe : le retrait y a sa place | Un second retrait écrase la date du premier |
| B — Table des retraits | Garde tout l'historique | Une table, un port et une jointure pour une question en oui ou non |

## 4. Décision

> **Nous inscrivons l'élève par un seul use case, `UseCases::Classroom::RegisterStudent`, sur deux voies : la classe est choisie dans une cascade DRENA → établissement → niveau → classe, ou elle est donnée par un lien `/c/<jeton>`. Il entre tout de suite. Le jeton vit sur la classe, se remplace, et n'est jamais le code.**
>
> **Nous permettons à l'enseignant de la classe, à la direction de son établissement et à l'équipe de retirer un élève. Le retrait se retient sur l'adhésion : la voie standard refuse cette classe à cet élève, le lien l'y ramène.**

### 4.1 Lien de classe

- `classrooms.link_token` : 12 caractères hexadécimaux, tirés par la base (`DEFAULT`), `NOT NULL`, uniques, avec un `CHECK` de format — la forme des jetons de l'ADR-0083. Une classe générée ou importée reçoit son jeton sans changer `GenerateMissingClassrooms` ni `ImportSchools`, qui cessent seulement de tirer un code.
- `GET /c/:token` garde son adresse et sa limite (10 requêtes par minute et par adresse). Le paramètre change de nature : un ancien code (5 caractères) ne peut pas être un jeton (12) ; il est traité comme un jeton inconnu.
- Le lien est **invalide** quand le jeton est inconnu, quand la classe est archivée, ou quand son établissement n'est pas actif. La page standard s'ouvre alors avec l'alerte, et la voie enregistrée est `standard`.
- À l'envoi, le serveur **résout de nouveau** le jeton. La classe envoyée par le formulaire est ignorée quand un jeton valide est présent.
- `UseCases::Classroom::ChangeClassroomLink` tire un nouveau jeton sous le verrou de la classe. L'ancien est invalide immédiatement. Il n'y a **qu'un lien par classe**, partagé par tous ceux qui la gèrent : aucun parrainage n'est compté pour un élève.
- `classrooms.join_code` et `join_code_rotated_at` sont **supprimées** dans le dernier lot, avec `Entities::Classroom::JoinCode`. `CloseJoinCode` (ADR-0041) n'aura jamais existé : on ne ferme pas une classe aux arrivées, on l'archive.

### 4.2 Cascade

- Deux lectures publiques, sans use case (ADR-0062) : les niveaux d'un établissement actif qui y ont une classe active de l'année courante ; les classes actives d'un niveau. Chaque classe expose son nom, son `public_id` et un booléen « complète ». **Jamais** l'effectif, le plafond, un enseignant, un élève ni le jeton.
- 30 requêtes par minute et par adresse sur chacune.
- La classe choisie voyage par son `public_id`. Le serveur vérifie de nouveau qu'elle est active, de l'année courante, du niveau et de l'établissement envoyés, et que l'établissement est actif.

### 4.3 Entrée

- `RegisterStudent` reprend la transaction de `JoinWithCode` : verrou de la classe, `JoinPolicy`, compte élève (rôle imposé), adhésion principale, session. Aucun compte sans adhésion (memo Q9).
- `JoinPolicy` refuse : un acteur qui n'est ni visiteur ni élève ; une classe archivée ; une classe complète ; **un élève retiré de cette classe, sauf si l'entrée vient du lien**. Elle ne connaît plus de code.
- `JoinAsStudent` (élève connecté sans classe active) reçoit la classe des deux mêmes façons. L'ADR-0040 est amendé sur un point : l'élève **retiré** change de classe comme l'élève dont la classe est archivée.
- Revenir par le lien dans une classe dont on a été retiré **rouvre la même adhésion** : `left_at`, `removed_at` et `removed_by_id` repassent à `NULL`, `joined_at` prend la date du retour, `joined_via` vaut `link`.

### 4.4 Voie d'arrivée et nouveaux arrivés

- `classroom_students.joined_via` : `standard`, `link`, ou `code` pour les adhésions d'avant le chantier (reprise). `CHECK` sur les trois valeurs, `NOT NULL`.
- Un élève est « nouveau » pendant **7 jours** après `joined_at`. C'est un calcul de lecture, sans colonne ni tâche : la marque ne dépend pas de qui a regardé la liste, parce que trois acteurs la regardent.

### 4.5 Retrait

- `UseCases::Classroom::RemoveStudent(actor:, classroom_public_id:, student_public_id:)`, sous `Policies::Classroom::ManageClassroomMembersPolicy` : enseignant de la classe, direction de l'établissement de la classe, équipe. La même policy garde `ChangeClassroomLink` et la lecture du lien.
- Sous le verrou de la classe : `left_at` et `removed_at` reçoivent l'heure, `removed_by_id` l'acteur. Idempotent : retirer un élève déjà parti réussit sans rien écrire.
- Le compte, les sessions, les résultats et les assignations restent (ADR-0036). L'élève n'a plus de classe principale active ; son accueil lui propose d'en choisir une.
- La direction reçoit un geste d'écriture sur un élève, ce que l'ADR-0065 excluait. Sa page de classe, aujourd'hui sans identifiant d'élève dans le HTML, porte le `public_id` de l'élève sur la seule ligne du geste.

### 4.6 Ce qui ne change pas

- Une seule classe principale active par élève (ADR-0040) ; le plafond et le verrou (ADR-0041) ; l'archivage de fin d'année.
- Le stockage du nom en deux colonnes (ADR-0037) ; la saisie suit l'ADR-0083 §4.4.
- La règle de l'inscription : 5 envois par minute et par adresse.

## 5. Conséquences

### 🟢 Positives

- Un élève s'inscrit sans que personne ne lui ait rien transmis.
- Un seul chemin d'entrée dans le domaine, pour le visiteur comme pour l'élève connecté, par cascade comme par lien.
- Le lien ne dit plus rien de la classe et se reprend d'un geste.
- Une classe sans enseignant garde deux acteurs capables d'inviter et de retirer.

### 🔴 Coûts consentis

- **N'importe qui entre dans n'importe quelle classe non complète.** Il y voit ce qu'un élève voit : ses camarades selon les écrans, les annonces de la classe, les exercices assignés. La protection est a posteriori, et elle suppose que quelqu'un ouvre la liste. Dans une classe sans enseignant dont la direction n'a pas de compte, seule l'équipe peut retirer.
- **Remplir une classe pour la fermer** : des comptes créés en série atteignent le plafond et bloquent les vrais élèves. Le débit de 5 inscriptions par minute et par adresse ralentit sans empêcher. Aucune vérification du numéro n'existe (chantier `verification-whatsapp`, au backlog).
- **Les anciens liens `/c/<code>` cessent de marcher**, y compris ceux affichés ou imprimés. Ils retombent sur l'inscription standard, pas sur une erreur.
- **Un lien de classe qui fuit lève les retraits** jusqu'à ce que quelqu'un le change.
- **Un second retrait écrase la date du premier** : l'historique des retraits n'est pas gardé.
- **La liste des classes d'un établissement devient publique**, nom par nom. Elle était lisible un code à la fois.
- **Dépendance** à `inscription-enseignant` pour les contrôleurs de saisie et la forme des jetons.
- *Ajouté le 2026-10-08 (relecture sécurité de la PR 203).* **Un enseignant non confirmé gère la classe qu'il s'est déclarée** : l'enseignant est rattaché dès l'inscription (ADR-0083) et se déclare enseignant d'une classe sans validation ; `ManageClassroomMembersPolicy` ne lit que les enseignants de la classe. Il peut donc retirer tous ses élèves et changer le lien en boucle. Chantier de suivi proposé : ne donner ces gestes qu'à un enseignant confirmé (ADR-0063).
- *Ajouté le 2026-10-08.* **Le débit par adresse se contourne en IPv6** : une plage /64 donne autant d'adresses que voulu, et les 5 inscriptions par minute n'y freinent plus le remplissage d'une classe. Chantier de suivi proposé : compter le débit par /64.
- *Ajouté le 2026-10-08.* **Changer le lien et retirer un élève ne laissent pas de trace d'audit** : le retrait garde son auteur sur l'adhésion, le changement de lien rien. Chantier de suivi proposé : `classroom.link_changed` et `classroom.student_removed` dans le journal d'audit.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/classroom/join_policy.rb
# via_link : l'entrée vient d'un jeton de lien valide ; removed : l'élève a été retiré de cette classe
def call(actor:, classroom:, via_link:, removed:)
  return Shared::Result.failure(:forbidden) unless actor.nil? || actor.student?
  return refuse(:classroom_archived) unless classroom.active?
  return refuse(:removed_from_classroom) if removed && !via_link
  return refuse(:classroom_full) if classroom.full?

  Shared::Result.success
end
```

```ruby
# app/domain/ports/classroom/classroom_repository_port.rb
# → Entities::Classroom::Classroom | nil, sous verrou de ligne, avec active_students_count
def lock_by_public_id(public_id:)
def lock_by_link_token(token:)
# → String (le nouveau jeton)
def rotate_link_token(id:)

# app/domain/ports/classroom/membership_repository_port.rb
# via : "standard" | "link" ; rouvre l'adhésion d'un élève retiré au lieu d'en créer une
def add_primary(classroom_id:, student_id:, via:, at:)
# → true si une adhésion active a été close, false si l'élève était déjà parti
def remove(classroom_id:, student_id:, removed_by_id:, at:)
# → Boolean
def removed_from?(classroom_id:, student_id:)
```

```ruby
# db/migrate/2026100711xxxx_add_classroom_link_tokens_and_student_removal.rb (extrait)
TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze
add_column :classrooms, :link_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }
add_index  :classrooms, :link_token, unique: true
add_column :classroom_students, :joined_via, :string, null: false, default: "code"
change_column_default :classroom_students, :joined_via, from: "code", to: nil
add_column :classroom_students, :removed_at, :datetime
add_reference :classroom_students, :removed_by, foreign_key: { to_table: :users, on_delete: :restrict }
# CHECK : removed_at IS NULL OR left_at IS NOT NULL ; (removed_at IS NULL) = (removed_by_id IS NULL)
```

## 7. Comment vérifier que la décision est respectée

- `test/routing/v1_routes_test.rb` : `/join` redirige ; `/student-signup`, `/c/:token` et les deux adresses de la cascade sont routées.
- `test/db/schema_constraints_test.rb` : `link_token` refuse un format invalide et un doublon ; `joined_via` refuse une valeur hors liste ; `removed_at` sans `left_at` est refusé. Après le dernier lot : `classrooms` n'a plus de colonne `join_code`.
- `test/domain/policies/classroom/join_policy_test.rb` : un élève retiré est refusé sans lien, accepté avec ; une classe complète refuse dans les deux cas.
- `test/domain/policies/classroom/manage_classroom_members_policy_test.rb` : les trois acteurs accordés, et chaque refus (enseignant d'une autre classe, direction d'un autre établissement, élève, visiteur).
- `test/domain/use_cases/classroom/register_student_test.rb` : chaque voie enregistre sa valeur ; un `classroom_public_id` envoyé avec un jeton valide est ignoré ; aucun compte ne survit à un refus.
- Un test de garde échoue si `join_code` réapparaît sous `app/` après le dernier lot.
- **Non vérifiable automatiquement** : qu'un intrus soit effectivement retiré. La décision tient à l'usage que les enseignants, la direction et l'équipe font de la liste.
