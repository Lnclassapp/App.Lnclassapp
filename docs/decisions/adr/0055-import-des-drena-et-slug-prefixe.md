# ADR-0055 : Les DRENA s'importent par fichier, comme les établissements, et leur slug est préfixé `drena-`

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-29 |
| **Chantier** | [`docs/chantiers/import-drenas`](../../chantiers/import-drenas/memo.md) |
| **Remplace** | ADR-0039 §9, puce « les DRENA ne s'importent pas » et puce « Quatre types d'import » de l'amendement du 2026-09-25 ; ADR-0034 §4, en ce qu'il réserve la création des DRENA au formulaire *(amendement)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0034 fait démarrer la production vide, et l'équipe y crée tout. L'ADR-0039 a ouvert l'import en masse à quatre types (écoles, cours, fiches, exercices), mais a laissé les DRENA au formulaire : « les DRENA ne s'importent pas ». Il n'y en a que 41, et elles changent rarement.

Deux faits ont renversé cet arbitrage (chantier `import-drenas`) :

- **L'application est remise en service souvent** : recette, production, réinitialisations pendant la phase de test. Chaque fois, il faut saisir 41 DRENA à la main avant de pouvoir importer les écoles.
- **L'import des écoles ne pardonne rien.** Il résout la DRENA par son slug, sans jamais la créer. Une faute de frappe dans un nom décale le slug, et toutes les écoles de cette DRENA sont rejetées. Le fichier des établissements 2026 compte 3 851 écoles.

Le porteur veut aussi des slugs préfixés : `drena-abidjan-1` plutôt que `abidjan-1`. L'objection a été faite et consignée dans le memo : le slug d'une DRENA n'apparaît dans aucune URL (ADR-0029 : les URL portent le `public_id`), et les pages DRENA sont privées, donc le préfixe n'a aucun effet sur le référencement. Le porteur a maintenu le préfixe. Aucune DRENA n'existe dans un environnement à conserver : l'application sera redéployée à vide.

## 2. Moteurs de décision

1. Une seule manière d'écrire en masse : le moteur d'import de l'ADR-0039 (rapport, import partiel, doublons ignorés), et pas une commande à part.
2. Une seule règle de slug, la même au formulaire et à l'import. Sinon deux DRENA identiques porteraient deux slugs différents selon leur origine.
3. Le slug reste figé (ADR-0029) : un renommage ne casse aucun fichier d'import.
4. Ne rien migrer qui n'existe pas.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder le formulaire seul | Aucun code, 41 saisies seulement | Répété à chaque remise en service, et chaque faute casse l'import des écoles |
| B — Une tâche rake qui lit un JSON | Peu de code | Pas de rapport ni d'écran, réservée aux développeurs. Le porteur veut que l'équipe importe elle-même |
| C — **Un cinquième type d'import `drenas`** | Réutilise le moteur, le rapport, la modale et la policy existants | Retenue |
| Slug : préfixe écrit dans le nom (« DRENA Abidjan 1 ») | Aucune règle nouvelle | Le mot « DRENA » se répète à l'écran, et un oubli à la saisie donne un slug sans préfixe |
| Slug : **préfixe ajouté automatiquement** | Le nom reste « Abidjan 1 », et le préfixe ne dépend pas de la saisie | Retenue |
| Import des écoles : accepter `abidjan-1` et `drena-abidjan-1` | Les anciens fichiers restent valides | Écartée par le porteur : slug exact seulement |

## 4. Décision

> **Nous importons les DRENA par un cinquième type d'import, `drenas` (format `lnclass.drenas`, version 1), où chaque ligne ne porte que `name`. Toute DRENA, qu'elle soit importée ou créée au formulaire, reçoit le slug figé `drena-` suivi du slug de son nom. L'import des établissements ne reconnaît que ce slug exact.**

Règles de l'import `drenas` (moteur de l'ADR-0039, inchangé) :

| Règle | Valeur |
|---|---|
| Enveloppe | `{ "format": "lnclass.drenas", "version": 1, "drenas": [ { "name": "…" } ] }`, sans cible et sans autre clé (`additionalProperties: false`) |
| Plafond | 500 lignes par fichier |
| Policy | `Policies::School::ManageSchoolPolicy` (équipe) |
| Clé de doublon | le slug, calculé depuis le nom et comparé aux slugs en base et aux lignes plus haut dans le fichier. Un doublon est ignoré et compté, jamais mis à jour |
| Erreurs de ligne | `name` vide (`blank`), de plus de 80 caractères (`too_long`), sans lettre latine (`invalid_value`, sinon le slug serait « drena » nu), déjà pris en base ou plus haut dans le fichier sous un autre slug (`taken`) |
| Écriture | `insert_all` par lots, avec `public_id` et slug calculés avant l'insertion (ADR-0039 §2.1, §2.2) |

Le registre des types et la contrainte `import_reports_kind_values` passent à cinq valeurs : `schools`, `course_tree`, `essentials`, `exercises` et `drenas`.

## 5. Conséquences

### 🟢 Positives

- Un environnement se remet en service en deux imports : DRENA, puis établissements.
- Les slugs viennent d'un fichier relu une fois, et non de 41 saisies.
- Le formulaire et l'import produisent le même slug pour le même nom.

### 🔴 Coûts consentis

- **Tout fichier d'établissements qui cite l'ancien slug (`abidjan-1`) est rejeté ligne par ligne.** Le fichier 2026 est réécrit et livré par le chantier. Les exemples de l'ADR-0039 et de l'UDR-0037 deviennent faux et sont corrigés.
- Le slug s'allonge de 6 caractères sans aucun bénéfice de référencement, puisqu'il ne paraît dans aucune URL. C'est un choix du porteur, contre avis.
- Un nom sans lettre latine, jusqu'ici accepté au formulaire (slug « drena »), est désormais refusé.
- Le port des DRENA gagne deux méthodes (écriture en masse, noms pris), et chaque adaptateur doit les implémenter.
- Un cinquième job d'import, et donc une cinquième file sérialisée.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/drena.rb — seule source de la règle
SLUG_PREFIX = "drena"

# « Bouaké 1 » → « drena-bouake-1 » ; nil si le nom n'a aucune lettre latine.
def self.slug_for(name)
  base = name.to_s.parameterize
  "#{SLUG_PREFIX}-#{base}" if base.present?
end

def key = slug.presence || self.class.slug_for(name)
```

```ruby
# app/infrastructure/orm/drena.rb — le slug figé dérive de la règle du domaine
has_frozen_slug from: -> { Entities::School::Drena.slug_for(name) }
```

```ruby
# app/domain/entities/catalog/import_kind.rb — cinquième type
Definition.new(kind: "drenas", format: "lnclass.drenas", version: VERSION, roots_key: "drenas",
               target_key: nil, target_required: false, max_roots: 500,
               policy: Policies::School::ManageSchoolPolicy)
```

```ruby
# config/initializers/imports.rb
"drenas" => "School::ImportDrenasJob"
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/school/drena_test.rb` : `slug_for("Bouaké 1") == "drena-bouake-1"`, et `slug_for("???")` est nil.
- `test/infrastructure/repositories/school/drena_repository_test.rb` : une DRENA créée au formulaire reçoit le slug préfixé.
- `test/domain/use_cases/school/import_drenas_test.rb` : les critères DR-02 à DR-05 du PRD.
- `test/domain/use_cases/school/import_schools_test.rb` : `abidjan-1` donne `unknown_drena` (DR-09).
- `test/infrastructure/schema/import_reports_kind_test.rb`, ou le test existant de la contrainte : `drenas` est accepté par `import_reports_kind_values`.
- `test/domain/entities/catalog/import_kind_test.rb` : `KINDS` vaut exactement les cinq types.
