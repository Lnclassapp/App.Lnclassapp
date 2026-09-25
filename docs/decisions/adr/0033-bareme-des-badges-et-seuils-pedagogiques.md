# ADR-0033 : Un barème unique des badges, des seuils pédagogiques nommés, l'avancement et le score dans deux champs

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décisions de fondation **F-10** et **F-11**, bloque la V1 (Lot C) |
| **Remplace** | [ADR-0008](./0008-moteur-evaluation-et-gamification.md) §3 (barème et remplacement des badges) et §4 (échelles affichées) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Quatre barèmes coexistent : l'ADR-0008 (or ≥ 80 %, remplacement si `>=`), le code (or = 100, argent ≥ 80, bronze ≥ 50, remplacement si `>`), l'UDR-0003 et la landing (Argent / Or / **Diamant**), le glossaire (bronze 50, argent 80, or 100). C'est la contradiction **C-02**. L'architecture §2.7 présente l'or à 100 % comme une règle (**C-14**). Le code contient cinq seuils non nommés (50, 70, 75, 80, 100) ; l'élève ne voit que le pourcentage, alors que l'ADR-0008 §4 promettait aussi une note sur 20 (**C-46**). Enfin, la colonne `percentage` mesure l'avancement pendant la session, puis le score à la clôture.

## 2. Moteurs de décision

1. Un seul barème, lisible par un élève.
2. Chaque seuil a un nom et une seule définition dans le code.
3. Un champ n'a qu'un seul sens pendant toute sa vie.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Barème de l'ADR-0008 (or ≥ 80) | Plus d'or décerné | Contredit le code et le glossaire |
| B — **Barème du code et du glossaire (or = 100)** | Déjà implémenté et documenté ; l'or veut dire « sans faute » | Or rare sur les longs exercices |
| C — Quatre paliers avec Diamant | Promis par la landing | Aucun seuil n'a jamais été défini |

## 4. Décision

> **Nous retenons trois badges, bronze à 50 %, argent à 80 % et or à 100 %, un badge par élève et par exercice qui ne monte que d'un palier strictement supérieur, et nous supprimons « Diamant ».**

**Constantes**, dans `Entities::Assessment::Grading` (`app/domain/entities/assessment/grading.rb`) :

| Constante | Valeur | Sens |
|---|---|---|
| `PASS_THRESHOLD` | 50 | session réussie ; au-dessous, une lacune peut naître (ADR-0043) |
| `MASTERY_THRESHOLD` | 70 | maîtrise : « Acquis » ≥ 70, « Fragile » de 50 à 69, « En difficulté » < 50 |
| `BADGE_THRESHOLDS` | `{ gold: 100, silver: 80, bronze: 50 }` | palier le plus haut atteint |

Le seuil 75 (sujets d'examen) disparaît avec la feature.

**Score** :

- `score_percent = (correct_count * 100) / question_count`, en division entière, donc arrondi vers le bas : l'or exige toutes les réponses justes ;
- la note sur 20 vaut `(score_percent / 5.0).round`.

L'entité expose les deux ; l'affichage est tranché par l'UDR de la V1 (Lot C).

**Deux champs** sur `exercise_sessions` (ADR-0054) : `progress_percent` (`integer NOT NULL DEFAULT 0`, `CHECK 0..100`, questions répondues sur questions totales) et `score_percent` (`integer NULL`, `CHECK 0..100`, posé **uniquement** à la clôture). Contrainte `CHECK (status <> 'completed' OR score_percent IS NOT NULL)`. La colonne `percentage` n'existe plus.

**Table `exercise_badges`** : `student_id` (FK `users`), `exercise_id`, `level` (`CHECK IN ('bronze','silver','gold')`), `exercise_session_id` (la session qui l'a obtenu), `awarded_at`, tous `NOT NULL`. Index unique `(student_id, exercise_id)`.

**Attribution** : faite par le seul use case de clôture (ADR-0054).

- Aucun palier atteint : aucune écriture.
- Aucun badge existant : création.
- Palier **strictement** supérieur au badge existant : mise à jour de `level`, `exercise_session_id` et `awarded_at`.

**Historique** : la table ne garde que le meilleur badge. L'historique se relit dans les sessions, immuables (ADR-0054).

## 5. Conséquences

### 🟢 Positives

- C-02, C-14 et C-46 sont fermées : un barème, trois noms, une règle de remplacement.
- Un tableau de bord lit l'avancement ou le score sans deviner.
- Les seuils se changent à un seul endroit, avec un test.

### 🔴 Coûts consentis

- L'or est rare sur un exercice de 20 questions : c'est voulu, mais cela peut décourager.
- « Diamant » disparaît de la landing, de l'UDR-0003 et des vues : la promesse marketing est retirée.
- L'historique des badges n'existe pas en tant que tel : il faut le reconstituer depuis les sessions.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Assessment::Grading
# Rôle : seuils pédagogiques nommés et palier de badge
# ADR  : 0033
module Entities
  module Assessment
    module Grading
      PASS_THRESHOLD = 50
      MASTERY_THRESHOLD = 70
      BADGE_THRESHOLDS = { gold: 100, silver: 80, bronze: 50 }.freeze
      BADGE_ORDER = %i[bronze silver gold].freeze

      def self.badge_for(score_percent) = BADGE_THRESHOLDS.find { |_, min| score_percent >= min }&.first
      def self.upgrade?(current, candidate) = BADGE_ORDER.index(candidate) > BADGE_ORDER.index(current)
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test unitaire de `Grading` aux bornes : 49, 50, 79, 80, 99 et 100.
- `test/architecture/magic_thresholds_test.rb` échoue si `app/` contient une comparaison à un littéral 50, 70, 80 ou 100 à côté de `score` ou `percent` hors de `grading.rb`.
- `test/i18n/vocabulary_test.rb` (UDR-0007) refuse « Diamant ».

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0008 §3 pour les badges (C-02) ; les statuts de session du même §3 passent à l'ADR-0054.
- **Remplace** l'ADR-0008 §4 pour les échelles affichées (C-46).
- **Rend obsolètes** la mention « Diamant » de l'UDR-0003 et l'or présenté comme règle en architecture §2.7 (C-14).

## 9. Points à confirmer par le porteur

- L'or exige 100 %, comme dans le code actuel et le glossaire.
- La table des badges ne garde que le meilleur badge ; pas d'historique séparé.
