# ADR-0065 : Le matricule MENA de l'élève, colonne unique de `users`, saisi à l'inscription, corrigé par l'élève seul sous son PIN, cherché exactement par la direction parmi les élèves de son établissement

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, avec ses retours)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-40 à ED-43, ED-48 à ED-54, ED-56, ED-59, ED-65 |
| **Remplace** | — |
| **Amende** | [ADR-0036](./0036-suppression-archivage-et-anonymisation.md) (l'anonymisation efface le matricule) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La direction d'un établissement doit pouvoir changer de classe un élève de son établissement (ID-10, SC-21) : un élève inscrit dans la mauvaise classe, un élève qu'on déplace en cours d'année. Il faut donc qu'elle **désigne** un élève existant, sur place, parfois sans parcourir une liste de mille noms.

Aujourd'hui, un élève n'est identifié que par son numéro de téléphone (`users.contact`), son nom et son `public_id` (ADR-0029). Aucun ne convient :

- **le numéro** est une donnée de contact d'un mineur. Laisser la direction chercher par numéro ferait d'elle un annuaire des numéros d'élèves, qu'on sonde en essayant des numéros (l'ADR-0062 a déjà dû borner la recherche de l'équipe) ;
- **le nom** n'est pas unique et ouvre la recherche partielle, donc la liste ;
- **le `public_id`** n'est connu que de l'application.

Le porteur a tranché au grill (memo, grill 1 à 4) : la direction désigne l'élève par son **matricule**, l'identifiant que le ministère (MENA) attribue à chaque élève et que l'établissement connaît déjà. L'élève le saisit **obligatoirement** à l'inscription. La connexion reste par téléphone. Le matricule servira aussi, plus tard, à identifier le compte pour un **paiement** et un **abonnement** : il doit être stable.

À la relecture de la phase Décider (2026-09-28), le porteur a resserré deux règles : **seul l'élève corrige son matricule**, depuis son profil et sous son PIN actuel (plus l'équipe) ; **la direction ne cherche que les élèves de son établissement** (inscrits dans une de ses classes de l'année en cours). Rattacher un élève venu d'ailleurs sort de la V2 ; le changement d'établissement d'un élève est au backlog (`changement-etablissement-eleve`).

Lnclass ne connaît aucun matricule aujourd'hui. **Aucun élève n'est inscrit en production** (porteur, 2026-09-28, à revérifier juste avant la mise en production) : la donnée peut être obligatoire dès sa création, sans écran de rattrapage.

Le format est supposé : **8 chiffres suivis d'une lettre** (`12345678A`). Il doit être confirmé sur un vrai matricule avant le Lot 0 (§9).

## 2. Moteurs de décision

1. La direction ne peut **pas** se servir du matricule pour découvrir des élèves : recherche exacte seulement, parmi les élèves de son établissement, réponse neutre pour tout le reste, débit borné.
2. Un matricule désigne **un seul** compte vivant ; la base le garantit, pas seulement le code.
3. Le matricule ne change que par l'élève lui-même, sous son PIN actuel, et chaque changement est tracé : c'est la future clé des paiements.
4. Minimisation : un compte anonymisé ne garde pas le matricule d'un mineur (ADR-0036).
5. Aucun nouveau contexte, aucune table si une colonne suffit.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Chercher l'élève par numéro de téléphone | Donnée déjà là, déjà unique | Fait de la direction un annuaire des numéros de mineurs ; le numéro change, il ne peut pas porter un paiement. Refusé par le porteur (grill 1) |
| B — **Colonne `users.student_number`**, unique partielle, contraintes en base | Une seule lecture ; l'unicité et la présence garanties par PostgreSQL ; rien à joindre pour la recherche | Une colonne propre aux élèves dans une table partagée par tous les rôles (voir coûts) |
| C — Table `student_profiles` (1-1 avec `users`, comme `teacher_profiles`) | Isole les données propres à l'élève ; y ranger plus tard d'autres données scolaires | Une jointure à chaque recherche et à chaque inscription ; la présence obligatoire ne se garantit plus par un `CHECK` (il faudrait un trigger) ; aucune autre donnée d'élève n'est prévue |
| D — Matricule tiré par Lnclass | Format maîtrisé, aucune erreur de saisie | Ce n'est plus le matricule que l'établissement connaît : la direction ne pourrait pas s'en servir |

Option B retenue.

## 4. Décision

> **Nous ajoutons à `users` une colonne `student_number`, le matricule MENA de l'élève : obligatoire pour tout élève non anonymisé, unique, au format vérifié par la base, saisi par l'élève à l'inscription, corrigé seulement par l'élève lui-même depuis son profil sous son PIN actuel, effacé à l'anonymisation, et cherché par la direction seulement en entier, parmi les élèves de son établissement, avec une réponse neutre et sous limite de débit.**

### Donnée

| Élément | Règle |
|---|---|
| Colonne | `users.student_number`, `string(12) NULL` (12 pour absorber un format plus long sans migration de type) |
| Format | `CHECK (student_number ~ '^[0-9]{8}[A-Z]$')` — `users_student_number_format` |
| Réservé aux élèves | `CHECK (student_number IS NULL OR role = 'student')` — `users_student_number_only_students` |
| Obligatoire | `CHECK (role <> 'student' OR anonymized_at IS NOT NULL OR student_number IS NOT NULL)` — `users_student_number_required` |
| Unique | index unique partiel `index_users_on_student_number` `(student_number) WHERE student_number IS NOT NULL` |

**Entité** `Entities::Identity::StudentNumber` (module pur, comme `SchoolCode`) :

- `normalize(raw)` : retire espaces, points, tirets et barres obliques, met en majuscules ; `" 1234 5678-a "` → `"12345678A"` ; une saisie vide donne `nil` ;
- `valid?(value)` : le format ci-dessus ;
- `mask(value)` : `"••••5678A"`, pour tout écran qui n'a pas besoin du matricule entier (journal, toast).

`Entities::Identity::User` gagne l'attribut `student_number` (format validé s'il est présent ; la présence est exigée par le DTO d'inscription et par la base, pas par l'entité, pour ne pas imposer un matricule à chaque test qui construit un élève en mémoire).

### Inscription (`Classroom::JoinWithCode`)

- `Dtos::Classroom::JoinWithCodeInput` gagne `student_number` : normalisé à l'affectation, `presence`, format.
- `RegistrationRepositoryPort#create_student(user:, pin:)` écrit `user.student_number`. Sa réponse de conflit distingue l'index violé : `failure(:conflict, errors: { contact: [:taken] })` ou `failure(:conflict, errors: { student_number: [:taken] })`. Le message ne nomme jamais le compte qui détient le matricule.
- Un élève déjà inscrit qui rejoint une nouvelle classe (`JoinAsStudent`) ne ressaisit rien.

### Correction par l'élève (`Identity::ChangeOwnStudentNumber`)

- Depuis « Mon profil », comme le changement de PIN (ADR-0055, UDR-0041 amendée par l'UDR-0053) : **PIN actuel** exigé, vérifié par `VerifyOwnPin` (un PIN faux compte comme un échec de connexion, même verrouillage) ; nouveau matricule normalisé, même format, même unicité.
- Policy `Policies::Identity::ChangeOwnStudentNumberPolicy` : acteur `student`, cible = le compte de l'acteur (profil sans identifiant, ADR-0055). L'équipe, la direction et l'enseignant sont refusés : **aucun écran ne leur permet de modifier un matricule**, et `Identity::ChangeStudentNumber` (correction par l'équipe) n'existe pas.
- `UserRepositoryPort#update_student_number(user_id:, student_number:)` → `Result | failure(:conflict, errors: { student_number: [:taken] })`.
- Refus : format → `:invalid` ; matricule inchangé → `:invalid` (`student_number: [:unchanged]`) ; déjà porté par un autre compte → `:conflict`, message neutre « Ce matricule est déjà utilisé… », **sans jamais dire à qui** (le même qu'à l'inscription).
- **Débit** : 10 tentatives par heure et **par compte** (`by: current_actor.user_id`, compteur propre) : la réponse « déjà utilisé » est un oracle, au plus aussi ouvert que celui de l'inscription.
- Le changement ne ferme pas les autres sessions (le matricule n'est pas un secret d'authentification, ADR-0055) et ne renouvelle pas la session.
- Audit `student_number.changed`, acteur et sujet l'élève, métadonnées `{ previous: StudentNumber.mask(ancien), current: StudentNumber.mask(nouveau) }`.
- **L'équipe ne cherche pas un compte par matricule dans « Débloquer un compte »** : le déblocage part toujours du numéro de téléphone, que l'élève connaît (c'est son identifiant de connexion) ; le matricule n'y sert à rien. Un matricule usurpé se libère par l'**anonymisation** du compte usurpateur (`annuaire-equipe`, ID-23), dont la recherche de comptes retrouve un élève par son matricule entier (exigence transmise, PRD §8).

### Recherche par la direction (`School::FindStudentForPlacement`, ADR-0066)

- **Périmètre** : les seuls élèves **de l'établissement de l'acteur**, c'est-à-dire dont l'adhésion principale active (`left_at IS NULL`) est dans une classe **active**, de l'**année scolaire en cours**, de cet établissement (définition « élève placé » de l'ADR-0062, restreinte à l'établissement). Le geste qui suit est « changer de classe dans l'établissement » ; il n'y a plus de rattachement d'un élève venu d'ailleurs en V2.
- `UserRepositoryPort#find_student_by_number(student_number:)` → `Entities::Identity::User | nil`, élèves non anonymisés seulement ; égalité stricte sur la valeur normalisée, **jamais** de `LIKE`. Le use case lit ensuite l'adhésion principale (`MembershipRepositoryPort#primary_for`) et applique la règle d'établissement (ADR-0066 §4.4).
- Une saisie hors format reçoit un message de format (le format n'est pas un secret), **sans lecture en base**.
- Matricule inconnu, compte anonymisé, élève sans classe de l'année, élève d'un autre établissement reçoivent **la même réponse** : même statut HTTP, même texte, même gabarit. La direction n'apprend rien d'un matricule qui n'est pas celui d'un de ses élèves — qu'elle voit déjà, avec leur matricule, dans sa liste.
- **Débit** : la recherche a un compteur **par compte** de la direction, pas par adresse (une salle des professeurs partage une adresse, UDR-0020) : **10 par minute et 100 par jour**. Au-delà, 429, sans lecture. Le changement de classe lui-même passe par l'identifiant public de l'élève et n'est pas compté.
- `student_number` rejoint `filter_parameters` : le matricule n'apparaît jamais dans les journaux de requêtes. La recherche est un `POST` et le changement de classe passe par l'identifiant public de l'élève : le matricule n'est jamais dans une URL ; le champ re-rendu après un refus neutre est **vide**.

### Anonymisation (amendement de l'ADR-0036)

`Identity::AnonymizeUser` (chantier `annuaire-equipe`) met `student_number` à `NULL`, comme `contact`. La contrainte `users_student_number_required` l'y autorise (`anonymized_at` posé).

### Paiement et abonnement (hors V2, contrainte posée maintenant)

- Une future table de paiement ou d'abonnement référence **`users.id`** (clé étrangère `RESTRICT`), jamais le matricule ; elle **copie** le matricule du moment si un reçu doit l'imprimer.
- Le matricule est la **référence** qu'un élève ou un parent donne à un opérateur de paiement ; sa correction par l'élève ne casse aucune ligne.

## 5. Conséquences

### 🟢 Positives

- La direction désigne un élève de son établissement sans jamais voir ni sonder un numéro de téléphone, ni apprendre quoi que ce soit d'un élève d'ailleurs.
- L'élève corrige lui-même une faute de saisie, sans appeler personne.
- L'unicité et la présence sont tenues par PostgreSQL : un oubli du code ne crée ni doublon ni élève sans matricule.
- Une clé stable existe pour les paiements futurs, sans migration de données plus tard.
- L'effacement à l'anonymisation garde la règle de l'ADR-0036 : un compte anonymisé ne garde aucune donnée qui identifie un mineur.

### 🔴 Coûts consentis

- **Le format est fixé** sur l'exemple donné par le porteur le 2026-09-28 (`12345678A` : 8 chiffres puis une lettre). Un matricule MENA d'une autre forme serait refusé ; l'élucider ensuite demanderait une migration de la contrainte.
- **L'inscription dit qu'un matricule est pris.** C'est un oracle : quiconque a un code de classe valide peut tester si un matricule est déjà inscrit (sans apprendre à qui). Il est borné par la limite de débit de `/c/<code>` (10 par minute et par adresse, ADR-0041), la même qui borne déjà l'oracle « ce numéro est déjà utilisé ».
- **Un matricule peut être usurpé** : un tiers qui connaît le matricule d'un élève s'inscrit avec avant lui. L'élève légitime est refusé et doit contacter l'équipe. Personne d'autre que l'usurpateur ne peut corriger le matricule du compte usurpateur : il ne se libère que par l'**anonymisation** de ce compte, livrée par `annuaire-equipe` (ID-23). Les deux chantiers de la V2 doivent donc être en production **avant** l'ouverture aux élèves (§9).
- **Un élève peut remplacer son matricule par celui d'un autre** encore libre (un camarade pas encore inscrit) : c'est la même usurpation qu'à l'inscription, sous PIN et sous limite de débit, tracée par `student_number.changed` ; elle se règle de la même façon.
- **L'élève peut changer de matricule autant qu'il veut** (sous la limite de débit) : la « stabilité » voulue pour les paiements futurs tient à `users.id` (ci-dessus), pas au matricule.
- **Après anonymisation, le matricule redevient libre** : la personne à qui il appartient peut recréer un compte. « Jamais réattribué » s'entend donc ainsi : jamais porté par deux comptes vivants, jamais changé sans le PIN de l'élève.
- **Un élève sans classe cette année** (redoublant dont la classe de l'an dernier est archivée, élève venu d'ailleurs) **n'est pas trouvable par la direction** : il rejoint sa classe par son code d'adhésion, comme en V1 (ADR-0040). Tant que l'archivage de fin d'année (V3) n'existe pas, un élève dont la classe de l'an dernier est restée `active` ne peut pas rejoindre une nouvelle classe par code (`JoinAsStudent`) : ce cas attend la V3 ou `changement-etablissement-eleve` (point à confirmer, §9).
- Une colonne propre à un rôle dans `users`, table partagée par les quatre rôles : deux `CHECK` de plus à lire pour qui découvre la table.
- La migration **échoue** si un élève sans matricule existe (contrainte `users_student_number_required` validée). C'est voulu : c'est le contrôle « aucun élève en production ». En développement, les seeds et les fabriques reçoivent un matricule.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/identity/student_number.rb
# 🧠 DOMAINE · Entities::Identity::StudentNumber
# Rôle : matricule MENA de l'élève : 8 chiffres et une lettre, normalisé en majuscules, masqué hors des écrans qui l'exigent
# ADR  : 0065 · UDR : 0052, 0053
module Entities
  module Identity
    module StudentNumber
      FORMAT = /\A[0-9]{8}[A-Z]\z/
      SEPARATORS = %r{[\s./-]+}
      VISIBLE = 5

      # « 1234 5678-a » → « 12345678A » ; vide → nil
      def self.normalize(raw) = raw.to_s.gsub(SEPARATORS, "").upcase.presence
      def self.valid?(value) = FORMAT.match?(value.to_s)
      def self.mask(value) = value && "••••#{value[-VISIBLE..]}"
    end
  end
end
```

Migration du Lot 0 (`db/migrate/20260929090000_add_student_number_to_users.rb`), en une transaction (table `users` petite, aucun élève en production) :

```ruby
class AddStudentNumberToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :student_number, :string, limit: 12
    add_index :users, :student_number, unique: true, where: "student_number IS NOT NULL"
    add_check_constraint :users, "student_number ~ '^[0-9]{8}[A-Z]$'", name: "users_student_number_format"
    add_check_constraint :users, "student_number IS NULL OR role = 'student'", name: "users_student_number_only_students"
  end
end
```

Migration du Lot F (`db/migrate/20260929091000_require_student_number.rb`), posée avec le champ d'inscription pour que la branche reste verte entre les deux lots :

```ruby
class RequireStudentNumber < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :users, "role <> 'student' OR anonymized_at IS NOT NULL OR student_number IS NOT NULL",
                         name: "users_student_number_required"
  end
end
```

```ruby
# config/initializers/filter_parameter_logging.rb — ajout
:student_number
```

```ruby
# app/controllers/school_admin/student_placements_controller.rb — un compteur par compte, pour la seule recherche
rate_limit to: 10, within: 1.minute, only: :lookup, name: "student-number-minute", by: -> { current_actor.user_id },
           with: -> { refuse_rate_limited }
rate_limit to: 100, within: 1.day, only: :lookup, name: "student-number-day", by: -> { current_actor.user_id },
           with: -> { refuse_rate_limited }

# app/controllers/identity/profile_student_numbers_controller.rb — correction par l'élève
rate_limit to: 10, within: 1.hour, only: :update, name: "own-student-number", by: -> { current_actor.user_id },
           with: -> { render_rate_limited(:edit) }
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/identity/student_number_test.rb` : normalisation (espaces, tirets, points, minuscules), format refusé (7 chiffres, lettre en tête, deux lettres), masque.
- `test/db/schema_constraints_test.rb` : un élève sans matricule refusé ; un enseignant avec matricule refusé ; deux élèves au même matricule refusés ; un élève anonymisé sans matricule accepté ; format refusé.
- `test/infrastructure/repositories/identity/registration_repository_test.rb` : le conflit nomme `student_number` ou `contact` selon l'index violé.
- `test/domain/use_cases/classroom/join_with_code_test.rb` : matricule absent ou hors format → `:invalid` ; pris → `:conflict` sans compte créé.
- `test/domain/use_cases/identity/change_own_student_number_test.rb` : refus de l'équipe, de la direction, de l'enseignant ; PIN actuel faux (échec de connexion compté) ; format ; inchangé ; conflit sans nom ; audit masqué.
- `test/controllers/identity/profile_student_numbers_controller_test.rb` : 11ᵉ tentative dans l'heure → 429.
- `test/controllers/school_admin/student_placements_controller_test.rb` : matricule inconnu, élève sans classe de l'année et élève d'un autre établissement → réponse identique octet pour octet hors jeton CSRF ; 11ᵉ recherche en une minute → 429 sans lecture ; aucun matricule dans `log/test.log`.
- `test/integration/parameter_filtering_test.rb` (existant, Lot 0a) : `student_number` filtré, y compris imbriqué (`student_lookup[student_number]`).
- Le cas « compte anonymisé » de la recherche neutre (ED-41) est fabriqué en base par le test : une fois `AnonymizeUser` livré (`annuaire-equipe`), un compte anonymisé n'a plus de matricule, et le cas reste couvert par « matricule inconnu ».

## 8. Remplace, complète, amende

- **Amende l'ADR-0036** : l'anonymisation met aussi `student_number` à `NULL`.
- **Complète l'ADR-0040** : l'élève inscrit par code porte désormais son matricule.
- **Complète l'ADR-0066** : c'est la clé de la recherche « changer un élève de classe ».
- **Complète l'ADR-0055** : l'élève modifie aussi son matricule sous PIN actuel, sans fermer ses autres sessions.

## 9. Points à confirmer par le porteur

- ~~Le format exact du matricule MENA~~ : **confirmé le 2026-09-28** par le porteur sur l'exemple `12345678A` (8 chiffres puis une lettre).
- **Aucun élève en production** : dit par le porteur (grill 3) ; **à revérifier juste avant** la migration du Lot F (sinon elle échoue, et il faut un écran de rattrapage).
- Un matricule usurpé ne se libère que par l'anonymisation (`annuaire-equipe`) : **les deux chantiers de la V2 sont livrés avant l'ouverture aux élèves**.
- ~~L'équipe corrige un matricule~~ : **tranché par le porteur le 2026-09-28** : seul l'élève corrige son matricule, depuis son profil, sous son PIN actuel. L'équipe ne cherche plus par matricule dans « Débloquer un compte ».
- ~~La direction cherche tout élève rattachable~~ : **tranché par le porteur le 2026-09-28** : seulement les élèves de son établissement (classe de l'année en cours).
- Débit de la direction : 10 recherches par minute et 100 par jour, par compte (délégué). Débit de la correction par l'élève : 10 par heure et par compte (délégué).
- **Élève dont la classe de l'an dernier reste `active`** : il ne peut ni être déplacé par la direction (hors de son établissement de l'année), ni rejoindre une nouvelle classe par code tant que l'archivage de fin d'année (V3) n'existe pas. Aucun élève n'est en production : à trancher avant la première rentrée (V3 ou `changement-etablissement-eleve`).
- **L'anonymisation efface le matricule, qui redevient libre** : « jamais réattribué » (grill 3) est lu comme « jamais porté par deux comptes vivants, jamais changé sans le PIN de l'élève ». Garder le matricule d'un compte anonymisé contredirait l'ADR-0036 ; le garder sous forme d'empreinte demanderait une table de plus.
