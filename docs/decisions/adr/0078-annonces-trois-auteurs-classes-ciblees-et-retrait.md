# ADR-0078 : Annonces — l'enseignant publie pour ses classes, toute annonce a une date de fin, la direction signe officiellement, l'équipe et la direction peuvent retirer

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-10-03)* |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/annonces`](../../chantiers/annonces/prd.md) — critères AN-01 à AN-23 · programme `refonte-application`, vague V6a |
| **Amende** | [ADR-0045](./0045-annonces-publication-programmee-et-audience.md) §4 (table, droits, lecture, pièces jointes) et §7 · [ADR-0065](./0065-espace-direction-simple-en-lecture-seule.md) §2 (moteur 2) et §4 (la direction n'écrit rien) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0045 a fixé les annonces de la V6a le 2026-09-25 : deux auteurs (l'équipe, la direction), une audience par rôle et par établissement, un job de publication, des rejets en base, une image et un audio validés. Le chantier `annonces`, ouvert le 2026-10-03, a confronté cette décision à un grill de quinze questions et à la maquette de l'accueil élève validée par le porteur (design system Lnclass §10). Sept points ne tiennent plus :

1. **L'enseignant publie.** La maquette signe « M. Kouassi · SVT » ; le porteur confirme : un enseignant écrit aux classes où il enseigne. L'ADR-0045 ne lui donnait aucun droit, et n'a pas d'audience « classes ».
2. **Rien ne reste en ligne sans fin.** Le porteur a choisi « l'auteur seul gère son annonce » ; une annonce dont l'auteur quitte l'établissement ou est anonymisé (ADR-0036) restait donc en ligne indéfiniment. Toute annonce a désormais une date de fin.
3. **Un contenu déplacé destiné à des mineurs doit pouvoir être retiré** par un autre que son auteur. L'ADR-0045 ne connaît que l'archivage par l'auteur.
4. **L'annonce de la direction est officielle** : badge vérifié, et elle ne peut pas être masquée.
5. **La carte est l'annonce** : un titre et un texte court, sans page de détail ; l'audio porte les détails. L'ADR-0045 prévoyait un corps sans limite et une page `show`.
6. **Une illustration toujours présente**, choisie dans une bibliothèque fixe ; l'image téléversée devient facultative et la remplace.
7. **Une annonce modifiée revient** chez ceux qui l'avaient masquée.

Le point 3 rouvre aussi l'ADR-0065 : l'espace direction était « en lecture seule », et la direction écrit désormais des annonces et retire celles de ses enseignants.

## 2. Moteurs de décision

1. Une annonce n'est lue que par son audience, **y compris ses fichiers par leur adresse** (inchangé depuis l'ADR-0045, et plus exposé : sans page de détail, les fichiers sont la seule surface adressable).
2. Rien ne reste en ligne sans fin, et ce qui est déplacé peut être retiré vite par un tiers responsable.
3. Chaque auteur ne modifie que ce qu'il a écrit. Retirer n'est pas modifier.
4. Aucune donnée nouvelle quand une donnée existante suffit (signature, établissement, caractère officiel).

## 3. Options envisagées

**Cibler les classes d'un enseignant**

| Option | Pour | Contre |
|---|---|---|
| A — Audience `students` de son établissement | Aucun schéma | Un enseignant écrit à toute l'école : faux |
| B — Un tableau d'identifiants de classes dans `messages` | Une table de moins | Aucune clé étrangère, aucun index utilisable par la lecture |
| C — **Une table de jointure `message_classrooms`** | Intégrité en base ; la lecture filtre par un index | Retenue |

**Mettre fin à une annonce**

| Option | Pour | Contre |
|---|---|---|
| A — Archivage manuel seul (ADR-0045) | Rien à ajouter | L'annonce d'un auteur parti reste en ligne pour toujours |
| B — Le job de publication archive aussi à échéance | L'état en base dit tout | Jusqu'à 5 minutes de lecture après la fin ; deux sens au mot « archivée » |
| C — **Une date de fin non nulle, filtrée à la lecture** | Effet à la seconde, sans job ; « Terminée » se déduit de la date | Retenue — l'état « terminée » n'est pas stocké |

**Retirer**

| Option | Pour | Contre |
|---|---|---|
| A — Le modérateur archive | Un statut de moins | L'auteur, qui peut gérer ses archives, pourrait republier ce qu'on lui a retiré |
| B — **Un statut `withdrawn`, figé, avec son auteur et sa date** | Le retrait est distinct, définitif et journalisé | Retenue |

## 4. Décision

> **Nous ajoutons l'enseignant comme troisième auteur, avec des annonces ciblant ses classes ; nous donnons à toute annonce publiée une date de fin filtrée à la lecture ; nous rendons officielle l'annonce de la direction ; nous réduisons l'annonce à une carte courte et illustrée, sans page de détail ; et nous permettons à l'équipe et à la direction de retirer, sans modifier.**

### 4.1 Table `messages` — amende le tableau de l'ADR-0045 §4

| Colonne | Contrainte | Changement |
|---|---|---|
| `public_id` | ADR-0029 | — |
| `author_id` | `NOT NULL`, FK `users` `ON DELETE RESTRICT` | — |
| `title` | `string(60) NOT NULL` | **60** au lieu de 120 (titre de carte en 15 px) |
| `body` | `string(140) NOT NULL`, texte simple rendu échappé | **140 caractères**, plus de `text` |
| `audience` | `CHECK IN ('all','students','teachers','school_admins','classrooms')` | **`classrooms`** : annonce d'enseignant |
| `school_id` | FK `NULL` `ON DELETE RESTRICT` | Renseigné aussi pour une annonce d'enseignant (son établissement), pour que la direction la retrouve |
| `status` | `CHECK IN ('draft','scheduled','published','archived','withdrawn')` | **`withdrawn`** |
| `illustration` | `string NOT NULL`, `CHECK IN` la liste fermée de l'UDR-0071 | **Nouvelle** |
| `published_at` | `datetime NULL` | — |
| `ends_at` | `datetime NULL` | **Nouvelle** : date de fin |
| `edited_at` | `datetime NULL` | **Nouvelle** : dernière modification d'une annonce déjà publiée (« Modifiée ») |
| `withdrawn_at`, `withdrawn_by_id` | `datetime NULL`, FK `users` `NULL` `ON DELETE RESTRICT` | **Nouvelles** |

Contraintes (en plus de celle de l'ADR-0045 sur `published_at`) :

- `CHECK (status NOT IN ('scheduled','published') OR ends_at IS NOT NULL)` : la date de fin est exigée des annonces en ligne (un brouillon archivé n'en a pas) ;
- `CHECK (btrim(title) <> '')` et `CHECK (btrim(body) <> '')` : ni titre ni texte vides (AN-20) ;
- `CHECK (ends_at IS NULL OR published_at IS NULL OR (ends_at > published_at AND ends_at <= published_at + interval '90 days'))` ;
- `CHECK ((status = 'withdrawn') = (withdrawn_at IS NOT NULL AND withdrawn_by_id IS NOT NULL))` ;
- `CHECK (audience <> 'classrooms' OR school_id IS NOT NULL)`.

Index : `(status, published_at)` et `(school_id)` de l'ADR-0045, plus `(author_id, created_at)` pour « Mes annonces ».

**Date de fin** : par défaut, `published_at + 30 jours` ; au plus `published_at + 90 jours`. Une annonce `published` dont `ends_at` est passée est « terminée » : rien ne la stocke, la lecture l'exclut.

**Table `message_classrooms`** (nouvelle) : `message_id` FK `ON DELETE CASCADE`, `classroom_id` FK `ON DELETE RESTRICT`, index unique `(message_id, classroom_id)`, index `(classroom_id)`. Une annonce `classrooms` a au moins une ligne (règle de domaine, vérifiée par le use case dans la même transaction). Une annonce par rôle n'en a aucune.

**Table `message_dismissals`** : celle de l'ADR-0045, inchangée. Modifier une annonce déjà publiée **supprime ses rejets** dans la même transaction et pose `edited_at`.

### 4.2 Droits — amende l'ADR-0045 §4 « Droits »

| Geste | `team` | `school_admin` | `teacher` | `student` |
|---|---|---|---|---|
| Rédiger, programmer | National ou un établissement ; `all`, `students`, `teachers`, `school_admins` | **Son** établissement ; `students`, `teachers`, `school_admins` | `classrooms` : une ou plusieurs classes **actives où il enseigne** | — |
| Modifier, archiver | Ses annonces | Ses annonces | Ses annonces | — |
| Retirer | Toute annonce d'un autre auteur | Les annonces d'enseignants de **son** établissement | — | — |
| Masquer | — | — | — | Une annonce lisible et **non officielle** |

- **Officielle** = l'auteur a le rôle `school_admin`. Rien ne la stocke.
- Une annonce `archived` ou `withdrawn` est **figée** : ni modification, ni republication.
- Un refus de gestion ou de retrait répond **404** : l'annonce n'existe pas pour qui n'a pas le droit d'y toucher.

### 4.3 Lecture — amende l'ADR-0045 §4 « Lecture »

Une annonce est lisible par un acteur si elle est `published`, si `published_at <= now < ends_at`, et si son audience le couvre :

- **par rôle** : `audience = 'all'` ou le rôle de l'acteur, et `school_id` `NULL` ou égal à l'établissement de l'acteur ;
- **par classes** : l'acteur est un élève dont la classe principale active (ADR-0040) figure dans `message_classrooms`.

L'établissement de l'acteur : la classe principale active de l'élève (ADR-0040) ; l'établissement principal de l'enseignant (ADR-0030) ; le rattachement de la direction (ADR-0065). L'auteur lit toujours les siennes ; l'équipe lit tout ; la direction lit en plus les annonces d'enseignants de son établissement (pour les retirer).

**Une seule définition** sert la liste (query), le service des fichiers (policy) et le carrousel. Il n'y a **pas de page de détail** : la route `show` de l'ADR-0045 disparaît.

**Ordre du carrousel élève** : direction, puis enseignants, puis équipe ; `published_at` décroissant dans chaque groupe ; **5 au plus** ; les annonces masquées par l'élève exclues. La liste complète garde les masquées.

### 4.4 Pièces jointes — complète l'ADR-0045 §4

Formats et tailles inchangés (image png/jpeg/webp ≤ 2 Mo ; audio mp3/m4a ≤ 10 Mo ; type lu dans le contenu). Ajouts :

- Un fichier n'est **servi qu'après la règle de lecture du §4.3** (ou au titre d'auteur, d'équipe, de direction modératrice), par l'application en mode proxy (ADR-0047), avec `Cache-Control: private, no-store`. Jamais d'URL signée Active Storage partageable. Hors droit : **404**.
- L'audio est servi avec `Accept-Ranges` (lecture et reprise sur réseau mobile) ; la page ne le précharge pas.
- L'image, si présente, remplace l'illustration dans la carte.

### 4.5 Publication et journal — complète l'ADR-0045 §4 « Publication »

Le job `Communication::PublishScheduledMessagesJob` (toutes les 5 minutes) est inchangé. Le journal d'audit reçoit `message.published` (publication immédiate ou par le job) et **`message.withdrawn`** (acteur, auteur de l'annonce, motif absent).

### 4.6 Espace direction — amende l'ADR-0065

La direction **écrit** désormais : ses annonces (§4.2) et le retrait de celles de ses enseignants. Les routes d'écriture des annonces vivent dans le contexte `communication` ; sous `/announcements`, jamais sous `/school-admin`. *(Note du 2026-10-04 : l'[ADR-0071](./0071-gestes-de-la-direction-sur-son-etablissement.md), accepté le 2026-10-01 sur une autre branche, avait déjà levé la lecture seule de l'ADR-0065 et dessiné des écritures sous `/school-admin` ; le critère DS-11 « GET seulement » n'y tient plus, du fait de l'ADR-0071 et non de celui-ci.)*

## 5. Conséquences

### 🟢 Positives

- L'élève reçoit les annonces de ceux qui comptent pour lui au quotidien : ses enseignants et sa direction.
- Rien ne traîne : au plus 90 jours en ligne, 30 par défaut, même si l'auteur a quitté l'établissement.
- Un contenu déplacé est retiré par l'équipe ou par la direction sans attendre l'auteur, et le retrait est tracé.
- La seule surface adressable (les fichiers) passe par la même règle de lecture que la liste.

### 🔴 Coûts consentis

- **Un canal enseignant → classe** rouvre en partie ce qui avait été retiré du plan le 2026-09-22 (messagerie de classe). La frontière est tenue par le sens unique : ni réponse, ni fil.
- **La modération est réactive** : rien ne signale une annonce déplacée ; l'équipe ou la direction doivent la voir, ou en être averties hors de l'application.
- **140 caractères** obligent à mettre le détail dans l'audio, que tout le monde ne peut pas écouter (classe, absence de voix) : une annonce sans audio doit se suffire à elle-même.
- **Modifier efface les masquages** : un auteur qui modifie souvent peut réimposer son annonce. Le retrait est la parade.
- « Terminée » n'est pas un statut : une requête qui oublie `ends_at` lit une annonce terminée. D'où une seule définition de lecture, testée condition par condition.
- La direction n'est plus en lecture seule : l'ADR-0065 perd une de ses garanties.

## 6. Notes d'implémentation

Formes reprises du code existant (exploration du 2026-10-03) : use case à dépendances injectées par mot-clé et `call(actor:, …)` qui commence par sa policy (`UseCases::Identity::ChangeOwnPhoto`) ; `Shared::Result` (`app/domain/shared/result.rb`, codes `forbidden not_found invalid conflict locked expired`) ; contrôleur qui construit le use case et rend par `render_result` (`app/controllers/concerns/renders_result.rb` : `not_found` → 404) ; fichier privé servi après un use case de lecture (`Identity::AccountPhotosController#show`).

**Entité et contrats** — Lot 0, gelés :

```ruby
# app/domain/entities/communication/message.rb
module Entities
  module Communication
    Message = Data.define(:id, :public_id, :author_id, :title, :body, :audience, :school_id, :classroom_ids,
                          :illustration, :status, :published_at, :ends_at, :edited_at, :withdrawn_at, :withdrawn_by_id) do
      def frozen? = %w[archived withdrawn].include?(status)
      def by_classrooms? = audience == "classrooms"
    end
    Message::AUDIENCES = %w[all students teachers school_admins classrooms].freeze
    Message::STATUSES = %w[draft scheduled published archived withdrawn].freeze
    Message::ILLUSTRATIONS = %w[info calendar homework sheets exam meeting celebration holidays].freeze # UDR-0071 §3.3
    Message::TITLE_MAX = 60
    Message::BODY_MAX = 140
    Message::DEFAULT_DURATION = 30.days
    Message::MAX_DURATION = 90.days
  end
end
```

`Entities::Communication::Reader = Data.define(:user_id, :role, :school_id, :classroom_id)` : l'acteur vu par la lecture. L'`Actor` existant ne porte pas l'établissement d'un élève (`school_id: nil`) ni sa classe : le lecteur les résout une fois par requête (classe principale active → établissement).

| Port (`app/domain/ports/communication/`) | Méthodes | Adaptateur (`app/infrastructure/`) |
|---|---|---|
| `MessageRepositoryPort` | `find_by_public_id(public_id)`, `create(message)`, `update(message)`, `clear_dismissals(message_id:)`, `due_for_publication(now:)` | `repositories/communication/message_repository.rb` |
| `DismissalRepositoryPort` | `dismiss(message_id:, user_id:, at:)`, `restore(message_id:, user_id:)` | `repositories/communication/dismissal_repository.rb` |
| `AttachmentStorePort` | `attach(message_id:, kind:, io:, content_type:)`, `remove(message_id:, kind:)`, `read(message_id:, kind:, range: nil)` → `StoredFile(content_type:, data:, byte_size:, range:)` | `repositories/communication/attachment_store.rb` (`has_one_attached :image`, `:audio`, `identify: false`, comme `ProfilePhotoStore`) |
| `ReadableMessagesPort` | `readable?(reader:, public_id:, now:)`, `reader_for(actor)` | `queries/communication/readable_messages.rb` |

Un port, un adaptateur (`test/architecture/port_contracts_test.rb`). Le journal réutilise `Ports::Identity::AuditLogPort` ; `Entities::Identity::AuditAction::ALL` gagne `message.published` et `message.withdrawn` (Lot 0). Les classes d'un enseignant viennent de `Repositories::Classroom::TeachingRepository#classroom_ids_for`, filtrées sur les classes actives.

**Une seule définition de la lecture, en SQL** : `Queries::Communication::ReadableMessages#scope(reader:, now:)` rend la relation des annonces lisibles (§4.3). L'`InboxQuery` (carrousel, liste) **et** l'adaptateur de `ReadableMessagesPort` (service des fichiers) partent de cette relation ; aucune autre requête ne réécrit la règle.

```ruby
# app/infrastructure/queries/communication/readable_messages.rb (extrait)
def scope(reader:, now:)
  published = Orm::Message.where(status: "published").where(published_at: ..now).where("ends_at > ?", now)
  by_role = published.where(audience: ["all", ROLE_AUDIENCE.fetch(reader.role)])
                     .where(school_id: [nil, reader.school_id].uniq)
  return by_role unless reader.role == :student && reader.classroom_id

  by_role.or(published.where(audience: "classrooms",
                             id: Orm::MessageClassroom.where(classroom_id: reader.classroom_id).select(:message_id)))
end
```

**Policies** (`app/domain/policies/communication/`), toutes `call(actor:, …)` → `Shared::Result` :

- `PublishPolicy#call(actor:, scope:, school_id:, audience:, classroom_ids:, teachable_classroom_ids:)` — `forbidden` pour l'élève et le visiteur ; `forbidden` pour une portée ou une audience hors du tableau du §4.2 ; enseignant : `classroom_ids` non vide et inclus dans `teachable_classroom_ids`.
- `ManageOwnPolicy#call(actor:, message:)` — `not_found` si `message.author_id != actor.user_id` ; `conflict` si `message.frozen?`.
- `WithdrawPolicy#call(actor:, message:, author_role:)` — équipe : tout message d'un autre auteur ; direction : `author_role == :teacher && message.school_id == actor.school_id` ; sinon `not_found` ; `conflict` si déjà figé.
- `DismissPolicy#call(actor:, readable:, author_role:)` — élève, annonce lisible, auteur non `school_admin` ; sinon `forbidden`.
- `ReadFilePolicy#call(actor:, message:, readable:, author_role:)` — `readable`, ou auteur, ou équipe, ou direction modératrice (`WithdrawPolicy` vraie) ; sinon `not_found`.

**Use cases** (`app/domain/use_cases/communication/`) : `CreateMessage`, `UpdateMessage` (efface les rejets et pose `edited_at` si l'annonce était publiée, dans la même transaction), `ArchiveMessage`, `WithdrawMessage` (journalise `message.withdrawn`), `DismissMessage`, `RestoreMessage`, `ReadMessageFile`, `PublishScheduledMessages`. Ce dernier, appelé par le job sans acteur, entre dans la liste `EXEMPT` de `test/architecture/use_case_policies_test.rb` : le droit a été vérifié à la programmation, la date de fin borne l'exposition, et le retrait reste possible.

**Fichiers** : le type est lu dans les premiers octets, **sans bibliothèque**, comme la photo de profil (ADR-0060), et non par Marcel (l'ADR-0045 le citait ; l'application ne l'appelle nulle part) :

```ruby
# image : réutilise app/domain/entities/identity/image_header.rb
Entities::Identity::ImageHeader.format_of(bytes) # => :png, :jpeg, :webp ou nil

# audio : app/domain/entities/communication/audio_header.rb (nouveau, Lot 0)
module Entities
  module Communication
    module AudioHeader
      def self.format_of(bytes)
        return :mpeg if bytes.start_with?("ID3".b) || (bytes.getbyte(0) == 0xFF && bytes.getbyte(1).to_i & 0xE0 == 0xE0)
        return :mp4 if bytes.byteslice(4, 4) == "ftyp".b && %w[M4A\  mp42 isom].include?(bytes.byteslice(8, 4))

        nil
      end
    end
  end
end
```

`Communication::MessageFilesController#show` (`GET /announcements/:public_id/:kind`, `kind` ∈ `image`, `audio`) appelle `ReadMessageFile`, puis `send_data …, disposition: :inline` avec `Cache-Control: private, no-store` ; pour l'audio, une en-tête `Range` donne une réponse `206` avec `Content-Range` (le port lit la plage demandée).

**Job** : `app/jobs/communication/publish_scheduled_messages_job.rb` (`Communication::PublishScheduledMessagesJob < ApplicationJob`), et dans `config/recurring.yml`, section `production` :

```yaml
publish_scheduled_messages:
  class: Communication::PublishScheduledMessagesJob
  queue: default
  schedule: every 5 minutes
```

**Schéma** : trois migrations (`messages`, `message_classrooms`, `message_dismissals`) au format de `db/migrate/20260928150200_create_school_join_requests.rb` (contraintes nommées `messages_<règle>`) ; `Orm::Message` (`include Orm::HasPublicId`), `Orm::MessageClassroom`, `Orm::MessageDismissal`.

## 7. Comment vérifier que la décision est respectée

- Tests de query de la règle de lecture, **une condition par test** : statut, `published_at` futur, `ends_at` passée, audience par rôle, établissement, classe principale, élève sans classe, annonce masquée (carrousel seulement).
- Tests de policy, **un refus par acteur** : rédiger (enseignant sur une classe étrangère, direction sur une autre école ou au national), gérer (collègue de direction, équipe, autre enseignant → 404), retirer (enseignant, direction d'une autre école, direction sur une annonce de l'équipe → 404), masquer (annonce officielle → refus).
- Tests d'intégration du service des fichiers : 404 hors audience, avant publication, après la fin, après archivage et après retrait ; 200 pour l'audience, l'auteur, l'équipe.
- Tests de schéma : chaque contrainte `CHECK` du §4.1 refuse une ligne fautive.
- Test de job (inchangé, ADR-0045 §7), plus : un retrait journalise `message.withdrawn`.
- Les routes d'écriture des annonces vivent sous `/announcements` : aucune route d'annonce sous `/school-admin` (test de routage).

## 8. Remplace, complète, amende

- **Amende l'ADR-0045** : §4 (table `messages`, droits, lecture, `show` supprimé, pièces jointes servies), §7 (les tests « par URL directe » portent sur les fichiers). Le reste de l'ADR-0045 (job, `message_dismissals`, formats, bucket) tient.
- **Amende l'ADR-0065** : §2 (moteur 2, « n'écrit rien ») et §4 — après l'[ADR-0071](./0071-gestes-de-la-direction-sur-son-etablissement.md), qui l'avait déjà amendé pour les gestes de la direction sur son établissement ; ce chantier y ajoute l'écriture des annonces.
- **Corrige le PRD cadre** du programme (§3, ligne « Publier une annonce » : la direction et l'enseignant publient) et la fiche V6 de la feuille de route (« riches » = image et audio, pas de texte mis en forme). Contradictions inscrites au registre de la feuille de route.

## 9. Points à confirmer par le porteur

- Durée maximale : **90 jours** après la publication.
- Longueurs : titre **60**, texte **140** caractères.
- L'équipe voit **toutes** les annonces des enseignants (pour pouvoir retirer), y compris celles qu'aucun signalement n'a désignées.
- Un retrait ne prévient pas l'auteur autrement que par le statut « Retirée » dans « Mes annonces ».

## Amendement du 2026-10-04 — contraintes précisées au Lot 0

*Chantier [`annonces`](../../chantiers/annonces/journal.md), Lot 0. Le §4.1 ci-dessus est corrigé en conséquence.*

- La contrainte « date de fin » visait `status = 'draft' OR ends_at IS NOT NULL` : elle interdisait d'archiver un brouillon, qui n'a pas de date de fin. Elle devient `status NOT IN ('scheduled','published') OR ends_at IS NOT NULL` (`messages_ends_at_when_live`). Une annonce archivée ou retirée après sa mise en ligne garde sa date de fin.
- Deux contraintes s'ajoutent : `messages_title_present` et `messages_body_present` (`btrim(...) <> ''`), pour qu'un titre ou un texte vide soit refusé par la base aussi (AN-20).
- `AttachmentStorePort#read` accepte une plage ouverte (`500..`) ou négative (`-500..`) ; une plage hors du fichier lit le fichier entier. C'est ce que fait HTTP pour une plage non satisfiable sans erreur.

## Amendement du 2026-10-04 — renumérotation et intégration de `Develop`

*Chantier [`annonces`](../../chantiers/annonces/journal.md). Statut inchangé (`Accepté`).*

- Cet ADR a été écrit et accepté sous le numéro **0069**, déjà pris sur `Develop` par l'ADR « CI en un job ». Il devient l'**ADR-0078** (les numéros 0069 à 0077 sont utilisés sur `Develop` ou sur d'autres branches). Son UDR, écrite sous le numéro 0056 (pris par « Gestes de la direction »), devient l'**UDR-0071**.
- Les migrations du chantier passent après celles de `Develop` (`20261004100000` à `20261004100200`) : les versions `20261003100000`, puis `20261004090000` (inscription de la direction), étaient prises.
- L'[ADR-0071](./0071-gestes-de-la-direction-sur-son-etablissement.md) avait déjà sorti la direction de la lecture seule : les §4.6, §7 et §8 sont corrigés en conséquence.
- Le contexte `communication` porte aussi le blog (ADR-0074) : les noms de ce chantier (`Message`, `Reader`, `AudioHeader`, `messages`, `message_classrooms`, `message_dismissals`) n'entrent en collision avec aucun nom du blog.

## Amendement du 2026-10-04 — constats de la phase 5 (revue de sécurité, analyse des tests)

*Chantier [`annonces`](../../chantiers/annonces/journal.md). Statut inchangé (`Accepté`). Cette section fait foi en cas d'écart avec les §4.2, §4.4 et §6.*

- **Une annonce figée n'est jamais réécrite.** `MessageRepositoryPort#update` verrouille la ligne (`SELECT … FOR UPDATE`), la relit, et ne l'écrit pas si elle est déjà archivée ou retirée : il rend `nil`. `UpdateMessage`, `ArchiveMessage` et `WithdrawMessage` répondent alors `:conflict`, et `PublishScheduledMessages` passe l'annonce, sans rien journaliser. Sans cela, une modification lue avant un retrait remettait l'annonce en ligne.
- **`ReadFilePolicy`, la direction** : seulement sur une annonce programmée ou publiée d'un enseignant de son établissement, ce que sa liste « Enseignants » montre ; ni brouillon, ni annonce archivée ou retirée (AN-19).
- **L'image jointe suit l'ADR-0060**, comme l'image d'un article : lue en entier (2 Mo au plus, vérifiés avant), refusée si `ImageHeader.read` ne la lit pas, gardée par `ImageHeader.strip` (ni Exif, ni GPS, ni XMP) puis relue sans métadonnées ; son plus grand côté est de 4096 px (`Message::IMAGE_MAX_SIDE`, une photo de téléphone de 4032 px passe).
- **Dates** : une année de plus de 4 chiffres est une date illisible (422), brouillon compris ; elle ne va plus jusqu'à la base.
- **Laissé tel quel** : l'audio n'est reconnu que par ses premiers octets (`ID3`, `ftyp`) ; le type servi vient de nos constantes et `X-Content-Type-Options: nosniff` est actif, un faux audio n'est donc jamais interprété.

