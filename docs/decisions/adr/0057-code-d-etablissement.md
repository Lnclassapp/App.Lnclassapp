# ADR-0057 : Un code d'établissement unique, obligatoire à l'inscription enseignant, régénérable par l'équipe

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/code-etablissement`](../../chantiers/code-etablissement/prd.md) — critères CE-01 à CE-10 |
| **Remplace** | — *(amende [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) : « l'enseignant choisit son école »)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0030 laisse l'enseignant choisir son école pendant l'inscription, dans la liste des établissements actifs d'une DRENA (UDR-0024). Rien ne prouve qu'il y enseigne. Son coût consenti le dit : un enseignant peut se déclarer dans n'importe quelle classe de son école et lire la liste nominative des élèves. Avec une liste nationale ouverte, ce « son école » est n'importe laquelle des ~3 900 établissements de production.

Les élèves, eux, n'entrent dans une classe qu'avec un code que leur donne leur professeur (ADR-0041, UDR-0009). Le porteur demande le même mécanisme pour les enseignants (2026-09-28). La production est ouverte, les inscriptions arrivent : la décision doit valoir pour les établissements déjà en base, sans interrompre le service.

## 2. Moteurs de décision

1. Seul quelqu'un à qui l'établissement a transmis le code peut s'y inscrire comme enseignant.
2. Un code qui a fui se ferme en un geste, sans toucher aux enseignants déjà inscrits.
3. Le code ne se devine pas, et ne se confond pas avec un code de classe.
4. Tous les établissements existants en reçoivent un, sans verrou long sur `schools` en production.
5. Le domaine tire les codes ; la base garantit l'unicité et le format.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder la liste DRENA → établissement, le code en option | Aucune rupture pour l'enseignant | La porte ouverte reste ouverte : un code facultatif ne protège rien |
| B — Invitation nominative par enseignant (comme l'équipe, ADR-0038) | Traçable, révocable une à une | L'équipe ne connaît pas les enseignants des 3 900 établissements ; c'est l'établissement qui les connaît |
| C — **Code par établissement, obligatoire, régénérable** | Même geste que l'élève ; l'établissement le diffuse à son équipe ; un seul geste le ferme | Un code partagé fuit plus facilement qu'une invitation : on le régénère |
| D — Réutiliser le format du code de classe (5 caractères) | Un seul format à apprendre | Confusion garantie entre les deux codes ; 884 736 valeurs seulement |

## 4. Décision

> **Nous donnons à chaque établissement un code d'établissement unique de 6 caractères, obligatoire à l'inscription enseignant, lu par l'équipe sur la fiche de l'établissement, régénérable par elle, et cherché seulement derrière une limite de débit.**

**Colonnes de `schools`** :

| Colonne | Contrainte |
|---|---|
| `school_code` | `string(6) NOT NULL`, index unique `index_schools_on_school_code`, `CHECK (school_code ~ '^[a-hj-np-z2-9]{6}$')` (`schools_school_code_format`) |
| `school_code_rotated_at` | `datetime NULL` : date de la dernière régénération |

**Format** (`Entities::School::SchoolCode`) :

- 6 symboles parmi 32 : les lettres sans `i` ni `o`, les chiffres de 2 à 9 (les mêmes symboles que le code de classe, pour les mêmes confusions évitées) ; 32⁶ ≈ 1,07 milliard de valeurs ;
- stocké en minuscules ; affiché en majuscules, en deux groupes de trois séparés d'un tiret : `K7M-4QZ` ;
- la saisie est normalisée : espaces et tirets retirés, minuscules (`k7m 4QZ` → `k7m4qz`) ;
- distinct du code de classe (5 caractères, 3 lettres puis 2 chiffres) par sa longueur et son affichage ; une saisie au format d'un code de classe reçoit un message dédié, sans recherche ;
- lien à partager : `/e/<code>` (minuscules), comme `/c/<code>` pour une classe.

**Génération** :

- à l'import (`School::ImportSchools#write`), chaque établissement reçoit son code **dans la même insertion** ; les codes déjà pris sont chargés une fois (`taken_school_codes`), complétés lot après lot, comme les codes de classe (ADR-0041) ;
- aucun écran ne crée d'établissement (amendement de l'ADR-0030) : le contrat d'écriture unitaire (`SchoolRepositoryPort#create`) exige un code fourni par l'appelant ; les seeds et les fabriques de test en tirent un ;
- **établissements existants** : la migration `AddSchoolCodes` (voir §6).

**Inscription** (`Identity::RegisterTeacher`) :

- le DTO ne porte plus ni DRENA ni établissement, mais `school_code` ;
- l'établissement est lu par son code ; **inconnu, remplacé, inactif ou en brouillon : la même erreur** `school_code: [:inclusion]`, « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » ;
- le rattachement reste celui de l'ADR-0030 : une ligne `teacher_schools` principale, dans la transaction de création du compte.

**Régénération** (`School::RegenerateSchoolCode`) :

- policy `School::ManageSchoolPolicy` (équipe en V1 ; la direction en V2 fera l'objet d'un amendement) ;
- tire un nouveau code, l'écrit avec `school_code_rotated_at`, et trace `school.changed` (`change: "code_regenerated"`) au journal d'audit, en une transaction ; l'ancien code est invalide immédiatement ;
- une collision (index unique) fait retirer un code, cinq fois au plus, puis `:conflict` ;
- les enseignants déjà rattachés ne sont pas touchés.

**Anti-énumération** :

- `GET /e/:code` (aperçu : nom de l'établissement et de sa DRENA, rien d'autre) : **10 requêtes par minute et par adresse**, compteur propre ; au-delà, 429 sans aperçu (le mécanisme `rate_limit` de `/c/`, ADR-0041) ;
- `POST /teacher-signup` : 5 par minute et par adresse (inchangé, ADR-0050) ;
- `/e/<code>` répond 404 pour tout code refusé, sans distinguer les causes ;
- avec ~3 900 codes sur 1,07 milliard, un essai a une chance sur 275 000 ; à 10 essais par minute, une adresse en trouve un en 19 jours en moyenne, et le code trouvé se régénère.

**Enseignants déjà inscrits** : aucun changement, aucun code à ressaisir.

## 5. Conséquences

### 🟢 Positives

- Plus personne ne se déclare d'un établissement sans que celui-ci lui ait transmis son code.
- Un code diffusé par erreur se ferme en un geste, sans recréer l'établissement ni détacher les enseignants.
- L'enseignant ne cherche plus son établissement parmi des centaines : il tape 6 caractères ou ouvre un lien.
- Le coût consenti de l'ADR-0030 (déclaration dans n'importe quelle classe de « son » école) est borné à l'établissement qui a transmis le code.

### 🔴 Coûts consentis

- **L'équipe doit transmettre 3 900 codes** avant que les enseignants de ces établissements puissent s'inscrire. Sans canal d'envoi en V1, c'est un travail manuel ; un export ou un envoi groupé reste à faire.
- Un code partagé dans une salle des professeurs fuit plus facilement qu'une invitation nominative : la régénération est la seule parade, et elle impose de retransmettre le code.
- Un enseignant sans code ne peut plus s'inscrire seul : il passe par son établissement.
- `/drenas/:drena_public_id/schools` (frame HTML et JSON) n'a plus de consommateur dans l'application ; il reste en service comme API publique (SC-26).
- La migration n'a pas de transaction globale : interrompue, elle laisse une colonne nulle en partie remplie, et doit être relancée (elle est idempotente). Un import d'établissements lancé pendant le déploiement la ferait échouer.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/school_code.rb
# 🧠 DOMAINE · Entities::School::SchoolCode
# Rôle : code d'établissement de l'inscription enseignant : 6 symboles parmi 32 (sans i, o, 0 ni 1), affiché « K7M-4QZ »
# ADR  : 0057 · UDR : 0044
module Entities
  module School
    module SchoolCode
      SYMBOLS = ((("a".."z").to_a - %w[i o]) + ("2".."9").to_a).freeze
      LENGTH = 6
      FORMAT = /\A[a-hj-np-z2-9]{6}\z/
      SPACE = SYMBOLS.size**LENGTH
      GROUP = 3

      def self.generate(random: SecureRandom) = Array.new(LENGTH) { SYMBOLS.sample(random:) }.join

      # Tire `count` codes distincts, absents de `taken` (Set), qu'il complète.
      def self.generate_unique(count:, taken:, random: SecureRandom)
        raise ArgumentError, "plus assez de codes d'établissement libres" if count > SPACE - taken.size

        Array.new(count) do
          code = generate(random:)
          code = generate(random:) while taken.include?(code)
          taken << code
          code
        end
      end

      # Saisie tolérante : « k7m 4QZ », « K7M-4QZ » → « k7m4qz ».
      def self.normalize(raw) = raw.to_s.gsub(/[\s-]+/, "").downcase
      def self.valid?(code) = FORMAT.match?(code.to_s)

      # Un code de classe saisi par erreur : reconnu à sa forme, sans aucune recherche.
      def self.classroom_code?(code) = Entities::Classroom::JoinCode.valid?(code)

      def self.display(code)
        code && "#{code[0, GROUP]}-#{code[GROUP..]}".upcase
      end
    end
  end
end
```

Migration `db/migrate/20260928110000_add_school_codes.rb`, **sans transaction DDL** (`disable_ddl_transaction!`) :

1. `add_column :schools, :school_code, :string, limit: 6` (nulle : instantané) et `school_code_rotated_at` ;
2. remplissage par lots de 500 : `UPDATE schools SET school_code = v.code FROM (VALUES …) … WHERE school_code IS NULL`, chaque lot dans sa propre transaction courte ; les codes sont tirés en Ruby par un générateur **recopié dans la migration** (une migration ne dépend pas du domaine, qui pourra changer), contre l'ensemble des codes déjà pris ;
3. `add_index :schools, :school_code, unique: true, algorithm: :concurrently` (ne bloque pas les écritures) ;
4. `CHECK (school_code IS NOT NULL)` posée `NOT VALID`, puis validée (verrou `SHARE UPDATE EXCLUSIVE`, qui laisse passer les écritures), puis `change_column_null … false`, que PostgreSQL applique sans relire la table grâce à la contrainte validée, puis retrait de la contrainte ;
5. `CHECK` de format, posée `NOT VALID` puis validée.

Chaque étape vérifie ce qui existe déjà (`if_not_exists` pour la colonne et l'index, `check_constraint_exists?` par nom pour les contraintes, que PostgreSQL réécrit) : relancer la migration reprend là où elle s'était arrêtée.

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/school/school_code_test.rb` : format, alphabet, tirage unique, normalisation, affichage, distinction avec le code de classe.
- `test/db/schema_constraints_test.rb` : index unique, `NOT NULL` et `CHECK` de format de `schools.school_code`.
- `test/db/add_school_codes_migration_test.rb` : des établissements sans code en reçoivent chacun un, valide et distinct ; les codes existants ne bougent pas.
- `test/domain/use_cases/identity/register_teacher_test.rb` : code inconnu, établissement inactif ou en brouillon → la même erreur ; aucun port DRENA.
- `test/domain/use_cases/school/regenerate_school_code_test.rb` : policy, collision puis nouveau tirage, audit.
- `test/controllers/identity/teacher_registrations_controller_test.rb` : 404 neutre et 429 de `/e/<code>`.

## Amendement du 2026-09-28 — liens de parrainage (ADR-0063)

*Chantier `docs/chantiers/croissance-parrainage`. Le texte ci-dessus reste tel quel ; en cas d'écart, cette section fait foi.*

- Le code n'est plus transmis par la seule équipe : chaque enseignant d'un établissement **actif** le diffuse dans son lien de parrainage `/e/<code>?ref=<jeton>` (ADR-0063).
- **Régénérer le code casse aussi tous les liens de parrainage** de l'établissement : les enseignants doivent repartager leur lien.
