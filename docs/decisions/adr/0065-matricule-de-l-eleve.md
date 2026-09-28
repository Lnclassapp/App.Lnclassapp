# ADR-0065 : Le matricule MENA de l'élève, colonne unique de `users`, saisi à l'inscription, corrigé par l'équipe seule, cherché exactement par la direction sous limite de débit

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-40 à ED-43, ED-48 à ED-54, ED-56, ED-59 |
| **Remplace** | — |
| **Amende** | [ADR-0036](./0036-suppression-archivage-et-anonymisation.md) (l'anonymisation efface le matricule) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La direction d'un établissement doit pouvoir rattacher à une de ses classes un élève qui a déjà un compte Lnclass (ID-10, SC-21) : un redoublant, un élève arrivé d'un autre établissement, un élève inscrit dans la mauvaise classe. Il faut donc qu'elle **désigne** un élève existant.

Aujourd'hui, un élève n'est identifié que par son numéro de téléphone (`users.contact`), son nom et son `public_id` (ADR-0029). Aucun ne convient :

- **le numéro** est une donnée de contact d'un mineur. Laisser la direction chercher par numéro ferait d'elle un annuaire des numéros d'élèves, qu'on sonde en essayant des numéros (l'ADR-0062 a déjà dû borner la recherche de l'équipe) ;
- **le nom** n'est pas unique et ouvre la recherche partielle, donc la liste ;
- **le `public_id`** n'est connu que de l'application.

Le porteur a tranché au grill (memo, grill 1 à 4) : la direction désigne l'élève par son **matricule**, l'identifiant que le ministère (MENA) attribue à chaque élève et que l'établissement connaît déjà. L'élève le saisit **obligatoirement** à l'inscription. La connexion reste par téléphone. Le matricule servira aussi, plus tard, à identifier le compte pour un **paiement** et un **abonnement** : il doit être stable.

Lnclass ne connaît aucun matricule aujourd'hui. **Aucun élève n'est inscrit en production** (porteur, 2026-09-28, à revérifier juste avant la mise en production) : la donnée peut être obligatoire dès sa création, sans écran de rattrapage.

Le format est supposé : **8 chiffres suivis d'une lettre** (`12345678A`). Il doit être confirmé sur un vrai matricule avant le Lot 0 (§9).

## 2. Moteurs de décision

1. La direction ne peut **pas** se servir du matricule pour découvrir des élèves : recherche exacte seulement, réponse neutre, débit borné.
2. Un matricule désigne **un seul** compte vivant ; la base le garantit, pas seulement le code.
3. Le matricule ne change que par l'équipe, et chaque changement est tracé : c'est la future clé des paiements.
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

> **Nous ajoutons à `users` une colonne `student_number`, le matricule MENA de l'élève : obligatoire pour tout élève non anonymisé, unique, au format vérifié par la base, saisi par l'élève à l'inscription, corrigé seulement par l'équipe, effacé à l'anonymisation, et cherché par la direction seulement en entier, avec une réponse neutre et sous limite de débit.**

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

### Correction par l'équipe (`Identity::ChangeStudentNumber`)

- Policy `Policies::Identity::ChangeStudentNumberPolicy` : acteur `team` (tout sous-rôle en V2 ; la matrice de la V4 la rangera avec « Émettre un code de récupération », ADR-0038), cible élève non anonymisé.
- `UserRepositoryPort#update_student_number(user_id:, student_number:)` → `Result | failure(:conflict, errors: { student_number: [:taken] })`.
- Audit `student_number.changed`, sujet le compte, métadonnées `{ previous: StudentNumber.mask(ancien), current: StudentNumber.mask(nouveau) }`.
- Le compte se retrouve par son matricule exact sur « Débloquer un compte » (UDR-0020, amendée par l'UDR-0053) : `Queries::Identity::AccountLookupQuery` accepte un numéro **ou** un matricule entier, en `GET ?q=` (filtré des journaux), comme la recherche par numéro l'était déjà en `?contact=`.
- Personne d'autre ne modifie un matricule : ni l'élève (profil en lecture seule), ni la direction, ni l'enseignant.

### Recherche par la direction (`School::FindStudentForPlacement`, ADR-0066)

- `UserRepositoryPort#find_student_by_number(student_number:)` → `Entities::Identity::User | nil`, élèves non anonymisés seulement ; égalité stricte sur la valeur normalisée, **jamais** de `LIKE`.
- Une saisie hors format reçoit un message de format (le format n'est pas un secret), **sans lecture en base**.
- Matricule inconnu, compte anonymisé et élève non rattachable (ADR-0066 §4) reçoivent **la même réponse** : même statut HTTP, même texte, même gabarit.
- **Débit** : la recherche et le rattachement (qui reprend le matricule) partagent un compteur **par compte** de la direction, pas par adresse (une salle des professeurs partage une adresse, UDR-0020) : **10 par minute et 100 par jour**. Au-delà, 429, sans lecture.
- `student_number` et le paramètre de recherche de l'équipe `q` (expression `/\Aq\z/`, pour ne masquer rien d'autre) rejoignent `filter_parameters` : le matricule n'apparaît jamais dans les journaux de requêtes. **Côté direction**, la recherche est un `POST` et le changement de classe passe par l'identifiant public de l'élève : le matricule n'est jamais dans une URL ; le champ re-rendu après un refus neutre est **vide**.

### Anonymisation (amendement de l'ADR-0036)

`Identity::AnonymizeUser` (chantier `annuaire-equipe`) met `student_number` à `NULL`, comme `contact`. La contrainte `users_student_number_required` l'y autorise (`anonymized_at` posé).

### Paiement et abonnement (hors V2, contrainte posée maintenant)

- Une future table de paiement ou d'abonnement référence **`users.id`** (clé étrangère `RESTRICT`), jamais le matricule ; elle **copie** le matricule du moment si un reçu doit l'imprimer.
- Le matricule est la **référence** qu'un élève ou un parent donne à un opérateur de paiement ; sa correction par l'équipe ne casse aucune ligne.

## 5. Conséquences

### 🟢 Positives

- La direction désigne un élève sans jamais voir ni sonder un numéro de téléphone.
- L'unicité et la présence sont tenues par PostgreSQL : un oubli du code ne crée ni doublon ni élève sans matricule.
- Une clé stable existe pour les paiements futurs, sans migration de données plus tard.
- L'effacement à l'anonymisation garde la règle de l'ADR-0036 : un compte anonymisé ne garde aucune donnée qui identifie un mineur.

### 🔴 Coûts consentis

- **Le format est une hypothèse.** Si le vrai matricule MENA diffère (longueur, lettre en tête, chiffres seuls), le `CHECK` et l'entité changent avant le Lot 0 ; après, il faut une migration de la contrainte.
- **L'inscription dit qu'un matricule est pris.** C'est un oracle : quiconque a un code de classe valide peut tester si un matricule est déjà inscrit (sans apprendre à qui). Il est borné par la limite de débit de `/c/<code>` (10 par minute et par adresse, ADR-0041), la même qui borne déjà l'oracle « ce numéro est déjà utilisé ».
- **Un matricule peut être usurpé** : un tiers qui connaît le matricule d'un élève s'inscrit avec avant lui. L'élève légitime est refusé et doit contacter l'équipe. L'équipe corrige le compte usurpateur si elle connaît son vrai matricule ; sinon, le matricule ne se libère que par l'**anonymisation** de ce compte, livrée par `annuaire-equipe` (ID-23). Les deux chantiers de la V2 doivent donc être en production **avant** l'ouverture aux élèves (§9).
- **Après anonymisation, le matricule redevient libre** : la personne à qui il appartient peut recréer un compte. « Jamais réattribué » s'entend donc ainsi : jamais porté par deux comptes vivants, jamais changé sans l'équipe.
- **La direction lit le nom d'un élève dont elle connaît le matricule entier**, s'il n'est dans aucune classe active d'un autre établissement cette année : c'est la confirmation voulue par le porteur.
- **La recherche de l'équipe porte le matricule dans l'URL** (`?q=`, historique du navigateur de l'équipe), comme elle y portait déjà le numéro : l'équipe est protégée par son second facteur, les journaux le filtrent.
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
# app/controllers/school_admin/student_placements_controller.rb — un compteur par compte, partagé par la recherche et le rattachement
rate_limit to: 10, within: 1.minute, only: %i[lookup create], name: "student-number-minute", by: -> { current_actor.user_id },
           with: -> { refuse_rate_limited }
rate_limit to: 100, within: 1.day, only: %i[lookup create], name: "student-number-day", by: -> { current_actor.user_id },
           with: -> { refuse_rate_limited }
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/identity/student_number_test.rb` : normalisation (espaces, tirets, points, minuscules), format refusé (7 chiffres, lettre en tête, deux lettres), masque.
- `test/db/schema_constraints_test.rb` : un élève sans matricule refusé ; un enseignant avec matricule refusé ; deux élèves au même matricule refusés ; un élève anonymisé sans matricule accepté ; format refusé.
- `test/infrastructure/repositories/identity/registration_repository_test.rb` : le conflit nomme `student_number` ou `contact` selon l'index violé.
- `test/domain/use_cases/classroom/join_with_code_test.rb` : matricule absent ou hors format → `:invalid` ; pris → `:conflict` sans compte créé.
- `test/domain/use_cases/identity/change_student_number_test.rb` : refus hors équipe (direction, enseignant, élève), cible non élève, conflit, audit masqué.
- `test/controllers/school_admin/student_placements_controller_test.rb` : matricule inconnu et élève d'un autre établissement → réponse identique octet pour octet hors jeton CSRF ; 11ᵉ requête en une minute → 429 sans lecture ; aucun matricule dans `log/test.log`.
- `test/integration/parameter_filtering_test.rb` (existant, Lot 0a) : `student_number` et `q` filtrés, `quantity` (ou tout paramètre qui contient « q ») non filtré.
- Le cas « compte anonymisé » de la recherche neutre (ED-41) est fabriqué en base par le test : une fois `AnonymizeUser` livré (`annuaire-equipe`), un compte anonymisé n'a plus de matricule, et le cas reste couvert par « matricule inconnu ».

## 8. Remplace, complète, amende

- **Amende l'ADR-0036** : l'anonymisation met aussi `student_number` à `NULL`.
- **Complète l'ADR-0040** : l'élève inscrit par code porte désormais son matricule.
- **Complète l'ADR-0066** : c'est la clé de la recherche « rattacher un élève ».

## 9. Points à confirmer par le porteur

- **Le format exact du matricule MENA**, sur un vrai matricule, avant le Lot 0 (hypothèse : 8 chiffres et une lettre).
- **Aucun élève en production** au moment de la migration du Lot F (sinon elle échoue, et il faut un écran de rattrapage).
- Un matricule usurpé ne se libère que par l'anonymisation (`annuaire-equipe`) : **les deux chantiers de la V2 sont livrés avant l'ouverture aux élèves**.
- L'équipe (tout sous-rôle) corrige un matricule ; la matrice de la V4 la réservera à `admin` et `field`.
- Débit de la direction : 10 recherches par minute et 100 par jour, par compte.
- **L'anonymisation efface le matricule, qui redevient libre** : « jamais réattribué » (grill 3) est lu comme « jamais porté par deux comptes vivants, jamais changé sans l'équipe ». Garder le matricule d'un compte anonymisé contredirait l'ADR-0036 ; le garder sous forme d'empreinte demanderait une table de plus.
