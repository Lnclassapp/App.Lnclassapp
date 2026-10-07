# ADR-0082 : L'enseignant s'inscrit par la voie standard ou par un lien d'invitation à jeton, sans code d'établissement, et sa voie d'arrivée est enregistrée

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-07)* |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/inscription-enseignant`](../../chantiers/inscription-enseignant/prd.md) |
| **Remplace** | — *(amende ADR-0037 §4 pour la saisie, ADR-0057 et ADR-0063 côté enseignant, ADR-0071 §« Changer le lien », ADR-0073 pour les nouvelles inscriptions)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Au 2026-10-07, un enseignant s'inscrit par trois entrées :

1. **le code d'établissement** (ADR-0057) : un code à 6 caractères que l'équipe transmet à l'établissement, saisi sur `/teacher-signup` ou reçu dans un lien `/e/<code>` ;
2. **la voie « sans code »** (ADR-0063, ADR-0073) : `/teacher-signup/without-code`, avec la DRENA puis l'établissement, ou le code national. Elle crée une demande de rattachement (`school_join_requests`), validée aussitôt par la pause de l'ADR-0073 ;
3. **le lien d'un collègue** (ADR-0063) : c'est en fait le lien du code, `/e/<code>?ref=<referral_token>`.

Le porteur constate que le code est introuvable (personne ne le transmet), que le parcours est confus et que la page demande trop. Il décide de ne garder que deux entrées (memo, Q1 à Q15) :

- l'**inscription standard** : DRENA, établissement, matière, nom complet, genre, numéro, code secret ;
- le **lien d'invitation**, envoyé par un collègue, par la direction ou par l'équipe, qui arrive avec l'établissement déjà choisi.

Le code d'établissement disparaît partout côté enseignant : à l'inscription, dans les liens et sur l'écran d'attente (Q17). Il survit pour la seule inscription de la direction (ADR-0077), jusqu'au chantier `inscription-direction-sans-code`.

La future **certification**, qui reprendra la validation mise en pause, doit savoir par quelle voie chaque enseignant est arrivé (Q13). Aujourd'hui, seul le parrainage d'un collègue le dit (`referrals`).

Enfin, le porteur veut le nom et les prénoms dans **un seul champ** (Q2, Q3). L'ADR-0037 avait fait l'inverse, parce que l'ancien dépôt découpait au **dernier** mot, ce qui est faux pour les noms ivoiriens.

## 2. Moteurs de décision

1. Le lien ne doit plus porter le code d'établissement (Q9), et l'enseignant invité n'a pas à le connaître.
2. La voie enregistrée sert un jour à la certification. Elle ne doit donc pas pouvoir être choisie par l'inscrit en modifiant l'adresse.
3. Garder ce qui existe : le jeton de parrainage de l'enseignant, `Shared::Result`, le frame `/drenas/:id/schools`, et le stockage en deux colonnes de l'ADR-0037.
4. Ne pas casser l'inscription de la direction, qui garde le code.

## 3. Options envisagées

### Lien d'invitation

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `/teacher-signup?school=<public_id>&via=team` | Aucune donnée nouvelle : le `public_id` de l'établissement est déjà public | N'importe qui peut écrire `via=team` et se donner la voie la plus « sûre » : la voie ne vaut plus rien pour la certification (moteur 2) |
| B — **Jetons opaques `/i/<jeton>`** : le jeton de parrainage de l'enseignant, et deux jetons par établissement (direction, équipe) | La voie se déduit du jeton, que seul l'émetteur connaît ; le jeton de l'enseignant existe déjà | Deux colonnes de plus sur `schools` ; un jeton qui fuit ne se change pas (« Changer le lien » est retiré, Q10) |
| C — Une table `invite_links` (une ligne par émetteur) | Un seul modèle pour les trois émetteurs | Duplique `teacher_profiles.referral_token` ou le déplace : migration et reprise du parrainage pour un gain nul |

### Voie d'arrivée

| Option | Pour | Contre |
|---|---|---|
| D — **`teacher_profiles.joined_via`** | Une voie par compte, posée à l'inscription ; même forme que `school_staffs.joined_via` | Rien ne garde la voie d'un second rattachement (écran d'attente) : ce n'est pas demandé |
| E — `teacher_schools.joined_via` | Une voie par rattachement | L'écran d'attente devrait inventer une voie ; la certification lit l'inscription, pas le rattachement |

### Nom complet

| Option | Pour | Contre |
|---|---|---|
| F — **Un champ « Nom complet », premier mot = nom, aperçu corrigeable, stockage inchangé** | Ce que le porteur demande ; la règle suit l'ordre ivoirien (nom puis prénoms) ; deux colonnes, tri et affichage intacts | Un nom de famille en deux mots est mal coupé tant que l'enseignant ne corrige pas |
| G — Garder deux champs (ADR-0037) | Exact | Refusé par le porteur (Q2) |

## 4. Décision

> **Nous inscrivons l'enseignant par un seul use case, `UseCases::Identity::RegisterTeacher`, sur deux voies : l'établissement est choisi dans sa DRENA, ou il est donné par un lien `/i/<jeton>`.**
>
> **Le jeton du lien vient du parrainage de l'enseignant ou de l'un des deux jetons de l'établissement (direction, équipe). Il n'est jamais le code d'établissement.**
>
> **La voie d'arrivée est enregistrée dans `teacher_profiles.joined_via`. L'enseignant est rattaché à son établissement dès l'inscription, sans demande en attente.**
>
> **Le nom se saisit en un champ « Nom complet » : le premier mot est le nom, le reste les prénoms. L'enseignant peut corriger le découpage, qui est enregistré dans les deux colonnes de l'ADR-0037.**

### 4.1 Liens d'invitation

| Émetteur | Jeton | Voie enregistrée | Parrainage (`referrals`) |
|---|---|---|---|
| Collègue (« Inviter un collègue ») | `teacher_profiles.referral_token` (existant) | `colleague` | oui, `source = 'link'`, comme aujourd'hui |
| Direction (espace direction) | `schools.direction_invite_token` (nouveau) | `direction` | non |
| Équipe (fiche de l'établissement) | `schools.team_invite_token` (nouveau) | `team` | non |

- Les deux nouveaux jetons suivent la forme de `referral_token` : 12 caractères hexadécimaux, tirés par la base (`DEFAULT`), uniques, avec un `CHECK` de format. Un établissement importé reçoit donc ses jetons sans changer `ImportSchools`.
- `GET /i/:token` (10 requêtes par minute et par adresse, comme l'ancien `/e/`) résout le jeton. Il ouvre `/teacher-signup` avec l'établissement déjà choisi, et le jeton voyage en champ caché.
- Le lien est **invalide** quand le jeton est inconnu, quand l'établissement n'est pas actif, ou quand le collègue n'a plus cet établissement comme école principale. La page standard s'ouvre alors avec l'alerte « Ce lien n'est plus valable. Choisissez votre établissement. », et la voie enregistrée est `standard`. Un lien invalide ne répond jamais 404 et ne révèle pas pourquoi il est invalide.
- À l'envoi, le serveur **résout de nouveau** le jeton. L'établissement envoyé par le formulaire est ignoré quand un jeton valide est présent. « Ce n'est pas votre établissement ? » retire le jeton du formulaire.
- Les jetons sont **stables** : ni « Changer le lien » ni « Régénérer » pour eux. Ils ne donnent rien que l'inscription standard ne donne déjà, sinon une voie.

### 4.2 Voie d'arrivée

`teacher_profiles.joined_via`, `string`, `NOT NULL`, avec le `CHECK` `joined_via IN ('standard', 'colleague', 'direction', 'team', 'code')`. La valeur `code` est historique et n'est plus jamais écrite.

Reprise des enseignants existants, dans la même migration :

1. un parrainage `source = 'link'` donne `colleague` ;
2. sinon, une ligne `school_join_requests` (quelle qu'en soit la décision) donne `standard` ;
3. sinon, `code`.

### 4.3 Rattachement

`RegisterTeacher` appelle `SchoolRepositoryPort#attach_teacher(primary: true)` dans la transaction de création, comme le faisait la voie par code. Il n'écrit plus dans `school_join_requests`.

`RegisterPendingTeacher`, `PendingTeacherRegistrationsController` et les routes `/teacher-signup/without-code` disparaissent. Les tables et le circuit des demandes (`school_join_requests`, garant, revue par l'équipe) restent pour la certification, sans nouvelle écriture.

L'écran d'attente rattache par établissement choisi (`school_public_id` d'un établissement actif de la DRENA) au lieu du code. La règle des départs (ADR-0071) ne change pas : l'établissement qui a retiré l'enseignant est refusé par l'erreur neutre.

### 4.4 Nom complet

- `Entities::Identity::FullName.split(raw)` applique `squish`, puis coupe au **premier** espace. Elle renvoie `[last_name, first_name]`, ou `nil` s'il y a moins de deux mots.
- Le DTO reçoit `full_name`, `last_name` et `first_name`. Quand `last_name` **et** `first_name` sont remplis (l'enseignant a ouvert « Corriger », UDR-0078 §3.3), ils font foi. Sinon, le serveur découpe `full_name`, que l'aperçu ait tourné ou non.
- Les validations de l'ADR-0037 (motif, longueurs 50 et 80, casse gardée) s'appliquent au résultat. Un seul mot donne l'erreur `full_name: [:single_word]`.
- Les autres formulaires (élève, direction, invitation, profil) gardent leurs deux champs.

### 4.4 bis Numéros des élèves masqués dans la classe (phase 5, memo Q22 puis Q23)

- Dans la liste des élèves d'une classe (`Queries::Classroom::ClassroomOverviewQuery`), le numéro de chaque élève est remplacé par `Entities::Identity::Contact.mask` (ADR-0062) **côté serveur**, pour **tout** lecteur de cette liste : le numéro complet ne sort jamais de la requête. Raison donnée par le porteur : protéger les élèves, en particulier les filles, du harcèlement par un enseignant qui aurait leur numéro.
- La certification ne lève pas ce masque. Seuls les écrans de support de l'équipe gardent le numéro complet.
- Chaque inscription écrit une ligne d'audit `school.changed` (`change: "teacher_joined"`, `via: <voie>`), comme le rattachement par l'écran d'attente.

### 4.5 Ce qui ne change pas

- `schools.school_code`, `find_by_school_code`, `RegenerateSchoolCode`, `Teams::SchoolCodesController` et `RegisterSchoolStaff` restent, pour la direction (ADR-0077).
- `SchoolRepositoryPort#find_by_national_code` est retiré (plus d'appelant), et la recherche de la liste de l'équipe (`SchoolsQuery`) ne porte plus sur le code national (memo Q21). Le code national reste importé, modifiable et affiché sur la fiche.
- Côté direction, « Changer le lien » (`PATCH /school-admin/school/link`) est retiré : le bloc ne montre plus le code.
- `/drenas/:drena_public_id/schools` (frame et JSON) redevient la source de la liste des établissements, comme l'avait décidé l'UDR-0024.

## 5. Conséquences

### 🟢 Positives

- Deux entrées au lieu de trois, un use case au lieu de deux : la logique `Aborted`/`written` copiée entre `RegisterTeacher` et `RegisterPendingTeacher` disparaît.
- Un enseignant invité n'a plus à connaître ni à saisir aucun code.
- La certification saura qui est arrivé par qui, sans que l'inscrit puisse choisir sa voie.
- Le stockage du nom est inchangé : listes, tris, recherche par trigrammes et exports intacts.

### 🔴 Coûts consentis

- **L'inscription n'a aucune preuve** : n'importe qui peut se rattacher à n'importe quel établissement actif. La pause de l'ADR-0073 le faisait déjà pour la voie sans code ; c'est désormais la règle pour tous, jusqu'à la certification.
- **Le chemin `/i/<jeton>` est écrit dans les journaux de requêtes** (« Started GET »), comme l'était `/e/<code>`. Accepté : le jeton ne donne qu'une voie, et les journaux de production sont d'accès restreint.
- **Un inscrit sans preuve voit ses élèves et leur travail, et peut leur publier des annonces**, jusqu'à la certification. Les numéros des élèves, eux, sont masqués pour tous les enseignants (§4.4 bis).
- **Un enseignant ne peut plus joindre un élève par téléphone depuis Lnclass** : il passe par la classe, les annonces ou l'établissement.
- **Un jeton de direction ou d'équipe qui fuit ne se change pas.** Il ne donne qu'une voie, mais une voie fausse peut tromper la certification. La certification devra croiser la voie avec d'autres signaux.
- **Collision de jetons entre tables** (`teacher_profiles` et les deux colonnes de `schools`), sur 48 bits chacun. La résolution cherche d'abord le collègue, puis la direction, puis l'équipe. Le risque est négligeable, mais aucune contrainte ne l'interdit.
- **Un nom de famille en deux mots est mal coupé** si l'enseignant ne corrige pas l'aperçu. L'ADR-0037 refusait toute règle de découpage : la règle revient, du bon côté du nom, et l'enseignant garde la main.
- La voie d'un enseignant inscrit avant le chantier est **déduite** : une voie `standard` peut cacher un enseignant passé par le code national.
- Le code d'établissement vit encore dans le schéma et sur la fiche de l'équipe, pour la seule direction, jusqu'au chantier suivant.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/identity/full_name.rb
module Entities
  module Identity
    module FullName
      # Ordre ivoirien : le nom, puis un ou plusieurs prénoms. nil sous deux mots.
      def self.split(raw)
        last_name, first_name = raw.to_s.squish.split(" ", 2)
        [last_name, first_name] if first_name.present?
      end
    end
  end
end
```

```ruby
# app/domain/entities/identity/arrival_channel.rb
module Entities
  module Identity
    module ArrivalChannel
      ALL = %w[standard colleague direction team code].freeze
      WRITABLE = %w[standard colleague direction team].freeze
    end
  end
end
```

```ruby
# app/domain/ports/identity/invite_link_repository_port.rb
# resolve(token:) → InviteLink ou nil (jeton inconnu). L'appelant juge la validité avec valid?.
InviteLink = Data.define(:school_id, :school_active, :channel, :referrer_id) do
  def valid? = school_id.present? && school_active
end
```

```ruby
# db/migrate/2026100710xxxx_add_teacher_arrival_and_school_invite_tokens.rb (extrait)
TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze
add_column :schools, :direction_invite_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }
add_column :schools, :team_invite_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }
add_column :teacher_profiles, :joined_via, :string, null: false, default: "code"
# reprise : colleague, puis standard (cf. §4.2) ; puis change_column_default :teacher_profiles, :joined_via, from: "code", to: nil
```

## 7. Comment vérifier que la décision est respectée

- `test/routing/v1_routes_test.rb` : `/e/:code` et `/teacher-signup/without-code` ne sont plus routés ; `/i/:token` l'est.
- `test/db/schema_constraints_test.rb` : le `CHECK` de `teacher_profiles.joined_via` refuse une valeur hors liste ; les jetons de `schools` refusent un format invalide et un doublon.
- `test/domain/use_cases/identity/register_teacher_test.rb` : chaque voie enregistre sa valeur ; aucune écriture dans `school_join_requests` (double du port non appelé) ; un `school_public_id` envoyé avec un jeton valide est ignoré.
- `test/domain/entities/identity/full_name_test.rb` : découpage au premier mot, `nil` sous deux mots.
- `test/system/identity/teacher_signup_test.rb` : aucun champ « Code d'établissement » sur `/teacher-signup` ni sur l'écran d'attente.
- `test/db/growth_migrations_test.rb` : la nouvelle migration figure dans `LATER`.
