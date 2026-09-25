# ADR-0034 : Aucune reprise de l'ancienne base, un référentiel ivoirien seedé dès la V1

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-12**, bloque la V1 (seed), la V2 et la V4 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancienne application n'a jamais été mise en ligne pour de vrais élèves. Ses données sont des comptes de test, des comptes démo (retirés du plan le 2026-09-22) et des contenus importés à la main. Elle crée la taxonomie à la volée à chaque import : « Physique Chimie » et « Physique-Chimie » y sont deux matières distinctes. Les classes par défaut sont générées d'après un barème de niveaux et de séries jamais écrit. Le nouveau projet a besoin, dès la V1, d'un référentiel stable, sur lequel les classes et le contenu s'appuient.

## 2. Moteurs de décision

1. Rien d'incertain n'entre dans la nouvelle base.
2. Le référentiel est versionné, relu en revue, et rejouable sans doublon.
3. Chaque source de données a sa vague.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Migrer l'ancienne base | Rien à ressaisir | Importe les doublons, les comptes démo et des mots de passe faibles |
| B — **Base vide, référentiel seedé, imports par vague** | Propre et reproductible | Le contenu est réimporté en V4 |

## 4. Décision

> **Nous ne reprenons aucune donnée de l'ancienne base, nous seedons le référentiel pédagogique ivoirien dès la V1, et nous importons DRENA et écoles en V2, puis le contenu en V4.**

**Préalable** : le porteur confirme par écrit, dans le journal du chantier, qu'aucune donnée utilisateur réelle n'existe dans l'ancienne base. Sans cette confirmation, cet ADR ne peut pas être accepté.

**Seeds**, rangés par contexte :

- `db/seeds.rb` charge `db/seeds/<contexte>.rb` dans l'ordre `catalog`, `school`, `identity` ;
- chaque fichier est idempotent : `find_or_create_by!` sur le slug ;
- `bin/rails db:seed` est rejoué à chaque déploiement de recette et de production.

**`db/seeds/catalog.rb`** :

| Référentiel | Valeurs |
|---|---|
| `levels` (nom, `position`, `cycle`) | `6ème` 1, `5ème` 2, `4ème` 3, `3ème` 4 — `cycle: first` ; `2nd` 5, `1ère` 6, `Tle` 7 — `cycle: second` |
| `series` | `A1`, `A2`, `C`, `D` |
| `level_series` | `1ère` et `Tle` × `A1`, `A2`, `C`, `D` ; aucune série en `2nd` ni au premier cycle |
| `materials` (nom, `shortname`, `category`) | Mathématiques `MATHS` science · Physique-Chimie `PC` science · SVT `SVT` science · Français `FR` literature · Anglais `ANG` literature · Histoire-Géographie `HG` literature · Philosophie `PHILO` literature |

Contraintes :

- `levels.name`, `series.name`, `materials.name` et `materials.shortname` sont uniques ;
- `materials.category` est `CHECK IN ('literature','science','other')` ;
- une série n'est acceptée sur une classe ou un cours que si le couple existe dans `level_series`, ce que vérifie le use case.

**`db/seeds/identity.rb`** : crée la première invitation `team` pour `ENV["TEAM_BOOTSTRAP_CONTACT"]` si aucun compte `team` n'existe (ADR-0038). Le lien est affiché une fois dans la sortie du déploiement. Aucun compte n'est créé avec un PIN connu.

**`db/seeds/development.rb`** : comptes et contenus fictifs, chargés seulement si `Rails.env.development?`. Le fichier lève une erreur s'il est évalué en production.

**Par vague** :

| Vague | Données | Moyen |
|---|---|---|
| V1 | référentiel ci-dessus | seed |
| V2 | DRENA et écoles | import JSON par l'équipe, rapport dans `import_reports` (`kind: 'schools'`, ADR-0039) |
| V4 | cours, fiches et exercices | import du format arbre (ADR-0039) |

## 5. Conséquences

### 🟢 Positives

- Aucun doublon de taxonomie ni compte démo ne passe dans le nouveau projet.
- Le référentiel se lit dans le dépôt et se rejoue à l'identique en recette.

### 🔴 Coûts consentis

- Tout le contenu de l'ancien est réimporté en V4. D'ici là, la V1 n'a que le contenu saisi par l'équipe.
- Les fichiers JSON de l'ancien qui écrivent « Physique Chimie » passent par la résolution par slug de l'ADR-0039. Ceux qui écrivent autre chose sont corrigés à la main.
- Ajouter une matière demande une PR sur le seed, pas un écran, jusqu'au back-office de la V4.

## 6. Notes d'implémentation

```ruby
# db/seeds/catalog.rb
LEVELS = [["6ème", 1, "first"], ["5ème", 2, "first"], ["4ème", 3, "first"], ["3ème", 4, "first"],
          ["2nd", 5, "second"], ["1ère", 6, "second"], ["Tle", 7, "second"]].freeze

LEVELS.each do |name, position, cycle|
  Orm::Level.find_or_create_by!(slug: name.parameterize) do |level|
    level.name = name
    level.position = position
    level.cycle = cycle
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/db/seeds_test.rb` : deux exécutions successives de `db:seed` donnent les mêmes comptes de lignes ; le référentiel attendu est présent.
- Le même test échoue si `db/seeds/development.rb` est chargé avec `RAILS_ENV=production`.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il fixe le contenu du référentiel que l'ADR-0022 modélisait sans le lister.

## 9. Points à confirmer par le porteur

- **Aucune donnée utilisateur réelle** n'existe dans l'ancienne base (préalable).
- Libellé du niveau : `2nd` (celui de l'ancien) ou `2nde` (forme correcte).
- Séries en seconde (`2nde A`, `2nde C`) : absentes de cette version.
- Liste des matières : EDHC, Espagnol, Allemand et EPS ne sont pas seedés.
