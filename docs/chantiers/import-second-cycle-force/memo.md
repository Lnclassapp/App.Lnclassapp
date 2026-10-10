# Memo — Import des établissements : second cycle pour tous

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-09 |
| **Branche** | `Develop` (branche désignée de la session ; pas de `fix/<slug>`) |
| **Programme** | — |

---

## Symptôme

Après l'import des établissements, plusieurs d'entre eux n'ont que les classes de la 6ème à la 3ème : aucune 2nde, 1ère ni Tle.

## Reproduction

1. Acteur : Team, écran Imports → établissements.
2. Fichier : un établissement dont le nom contient « collège » (ex. `{ "name": "Collège Moderne", "type": "public" }`), sans colonne `cycle`, ou avec `"cycle": "first"`.
3. Résultat : `cycle = first`, 28 classes (public), aucune de second cycle. Attendu : 6ème à Tle, comme tout établissement.

## Portée

- Depuis l'ADR-0030 / ADR-0034 (règle « un collège ne prend que le premier cycle »), à chaque import.
- Tous les établissements importés dont le nom contient « collège », ou dont le fichier donne `cycle = first`.
- **Données déjà écrites fausses : oui** (établissements `first` déjà en base). Réparation à décider : passer en `both` et générer les classes manquantes (`GenerateMissingClassrooms` ne traite que les établissements sans aucune classe de l'année : à vérifier).

## Comportement attendu (source : décision du porteur, 2026-10-09)

Tout établissement importé reçoit le second cycle (6ème à Tle). Direction et équipe archiveront ensuite les classes en trop, après des mois de terrain ; une classe qui a des élèves ne s'archive pas (retirer les élèves d'abord).

## Test du bug déguisé

La règle actuelle est **spécifiée et testée** (ADR-0030, `import_schools_test.rb:121`) : ce n'est donc pas un bug au sens strict mais un changement de décision. Le porteur a demandé un bugfix : on le traite comme tel, avec un ADR court qui amende l'ADR-0030.

L'**archivage d'une classe** n'existe pas (aucun cas d'usage, seulement la colonne `status` et le badge) : c'est une **spec manquante**, donc hors périmètre de ce bugfix.

## Hors périmètre

- Cas d'usage « archiver une classe » (+ refus si élèves, droits direction et équipe, bouton) → chantier de suivi.
- Le champ « cycle » de l'établissement (le garder ou non) et les écrans de modification.
- Niveaux/séries sautés faute de barème.

## Questions encore ouvertes

- ~~Archivage~~ : chantier `archivage-classes` ouvert (feature).
- ~~Réparation des établissements existants~~ : décidée par le porteur, livrée en Lot A (`GrantSecondCycle`, `bin/rails schools:grant_second_cycle`).
