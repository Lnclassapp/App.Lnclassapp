# ADR-0041 : Une classe vit une année scolaire, s'archive en fin d'année, a un code d'adhésion régénérable et un plafond d'effectif

> ⚠️ **Amendée par [ADR-0085](0085-inscription-eleve-sans-code-de-classe.md)** (2026-10-08, Lot F du chantier `inscription-eleve-sans-code`) : le code d'adhésion est retiré, de la base comme des écrans ; une classe a un lien `/c/<jeton>` remplaçable. L'année scolaire, l'archivage, le plafond d'effectif et le verrou de la classe à chaque adhésion restent.

| | |
|---|---|
| **Statut** | Accepté — *amendé le 2026-10-08 par l'ADR-0085 : plus de code d'adhésion* |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-19**, bloque la V3 (colonnes posées dès la V1) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Dans l'ancien, une classe est éternelle : pas d'année scolaire, pas de fin. Son code d'adhésion (3 lettres parmi 24, puis 2 chiffres de 2 à 9, soit 884 736 valeurs) ne se change pas : un code qui fuit ouvre la classe à tout le monde, pour toujours. Aucun plafond d'effectif n'existe. Supprimer une classe détruit ses assignations, et supprimer un niveau détruit ses classes (**C-26**). À la rentrée, rien ne distingue la « 3ème 2 » de l'an dernier de celle de cette année.

## 2. Moteurs de décision

1. Les résultats d'une année restent lisibles l'année suivante.
2. Un code d'adhésion compromis se ferme en un geste.
3. Les colonnes existent dès la V1, pour éviter une migration de données en V3.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Classe éternelle (ancien) | Rien à faire | Mélange les années, C-26 |
| B — **Année scolaire et archivage** | Historique propre | Recréer les classes chaque rentrée |

## 4. Décision

> **Nous rattachons chaque classe à une année scolaire, nous l'archivons en fin d'année, nous rendons son code d'adhésion révocable et régénérable, et nous plafonnons son effectif.**

**Colonnes de `classrooms`**, posées en V1 :

| Colonne | Contrainte |
|---|---|
| `school_year` | `string(9) NOT NULL`, format `AAAA-AAAA` avec la seconde année égale à la première plus un (`CHECK`) |
| `status` | `string NOT NULL DEFAULT 'active'`, `CHECK IN ('active','archived')` |
| `archived_at` | `datetime NULL` |
| `join_code` | `string(5) NULL` |
| `join_code_rotated_at` | `datetime NULL` |
| `max_students` | `integer NOT NULL DEFAULT 80`, `CHECK BETWEEN 1 AND 150` |
| `name` | `string(15) NOT NULL` (limite de l'ancien) |

**Index** :

- unique `(school_id, school_year, name)` ;
- unique partiel `(join_code) WHERE join_code IS NOT NULL`.

**Année courante** : `Entities::Classroom::SchoolYear.current(date)`. L'année commence le 1er septembre (`START_MONTH = 9`). Une classe créée le 2026-10-01 appartient à `2026-2027`.

**Code d'adhésion** :

- format de l'ancien, sans `i` ni `o`, sans `0` ni `1` ;
- `Classroom::RegenerateJoinCode` remplace le code, et l'ancien est invalide immédiatement ;
- `Classroom::CloseJoinCode` le met à `NULL` : plus personne ne rejoint ;
- policy : enseignant de la classe (`Classroom::TeachPolicy`), direction de l'école (V2), `team` ;
- `/c/:code` est limité à 10 requêtes par minute et par IP.

**Plafond** : `Classroom::JoinWithCode` compte les adhésions actives (`left_at IS NULL`) sous verrou de ligne de la classe (`SELECT … FOR UPDATE`) et passe ce nombre à `Classroom::JoinPolicy` (ADR-0028). Celle-ci vérifie aussi que la classe est `active` et que le code est le `join_code` courant. Plafond atteint : `:forbidden`, `errors[:base]` = « Cette classe est complète ».

**Archivage** : `Classroom::ArchiveSchoolYear(school_year:)`, par `team` en V3.

- En une transaction, toutes les classes de l'année passent `archived`, et `join_code` passe à `NULL`.
- Les adhésions, les assignations et les sessions sont conservées.
- Une classe archivée est en lecture seule : aucune assignation, aucune adhésion.
- Ses élèves rejoignent une classe de la nouvelle année avec leur compte existant (ADR-0040).

Une classe n'est jamais supprimée dès qu'elle a une adhésion ou une assignation (ADR-0036).

## 5. Conséquences

### 🟢 Positives

- C-26 est fermée pour les classes : l'archivage remplace la destruction.
- Un code d'adhésion diffusé par erreur se révoque sans recréer la classe.
- Les statistiques d'une année restent justes après la rentrée suivante.

### 🔴 Coûts consentis

- Les classes sont recréées à chaque rentrée. Un outil de reconduction reste à faire (V3).
- 884 736 codes : l'espace suffit, mais le code reste devinable sans la limite de débit. Le plafond borne l'effet d'une intrusion.
- La date de rentrée est une constante : une année décalée demande un ADR.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Classroom::SchoolYear
# Rôle : année scolaire ivoirienne (septembre → août) d'une date
# ADR  : 0041
module Entities
  module Classroom
    module SchoolYear
      START_MONTH = 9

      def self.current(date)
        first = date.month >= START_MONTH ? date.year : date.year - 1
        "#{first}-#{first + 1}"
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test unitaire : `SchoolYear.current(Date.new(2027, 8, 31)) == "2026-2027"` et `SchoolYear.current(Date.new(2027, 9, 1)) == "2027-2028"`.
- Test de use case : le 81ᵉ élève reçoit `:forbidden` (`classroom_full`). Deux adhésions concurrentes au 80ᵉ siège : une seule passe (test de concurrence avec deux connexions).
- Test de policy : une classe archivée refuse assignation et adhésion.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il **ferme** C-26 avec l'ADR-0036, et **complète** l'ADR-0016 : l'archivage s'étend à la classe.

## 9. Points à confirmer par le porteur

- Plafond par défaut de 80 élèves, avec un maximum de 150.
- Début de l'année scolaire au 1er septembre.
- Archivage par l'équipe seule.
