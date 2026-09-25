# ADR-0033 : Quatre badges de Bronze à Diamant, des seuils pédagogiques nommés, l'avancement et le score dans deux champs

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décisions de fondation **F-10** et **F-11**, bloque la V1 (Lot C) |
| **Remplace** | [ADR-0008](./0008-moteur-evaluation-et-gamification.md) §3 (barème et remplacement des badges) et §4 (échelles affichées) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Quatre barèmes coexistent :

- l'ADR-0008 : or ≥ 80 %, remplacement si `>=` ;
- le code : or = 100, argent ≥ 80, bronze ≥ 50, remplacement si `>` ;
- l'UDR-0003 et la landing : Argent / Or / **Diamant** ;
- le glossaire : bronze 50, argent 80, or 100.

C'est la contradiction **C-02**. L'architecture §2.7 présente l'or à 100 % comme une règle (**C-14**). Le code contient cinq seuils non nommés (50, 70, 75, 80, 100). L'élève ne voit que le pourcentage, alors que l'ADR-0008 §4 promettait aussi une note sur 20 (**C-46**). Enfin, la colonne `percentage` mesure l'avancement pendant la session, puis le score à la clôture.

## 2. Moteurs de décision

1. Un seul barème, lisible par un élève, avec un palier réservé au sans-faute.
2. Chaque seuil a un nom et une seule définition dans le code.
3. Un champ n'a qu'un seul sens pendant toute sa vie.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Trois badges, or à 80 % (ADR-0008) | Or accessible | Rien ne distingue le sans-faute |
| B — Trois badges, or à 100 % (code, glossaire) | Déjà implémenté | Or rare sur les longs exercices ; « Diamant » promis par la landing disparaît |
| C — **Quatre badges, Diamant = sans faute** | Or accessible **et** sans-faute distingué ; tient la promesse de la landing | Un palier de plus à dessiner |

Option C retenue par le porteur le 2026-09-25.

## 4. Décision

> **Nous retenons quatre badges : Bronze à 50 %, Argent à 70 %, Or à 80 % et Diamant à 100 %. Un élève a au plus un badge par exercice, qui ne monte que vers un palier strictement supérieur.**

**Constantes**, dans `Entities::Assessment::Grading` (`app/domain/entities/assessment/grading.rb`) :

| Constante | Valeur | Sens |
|---|---|---|
| `PASS_THRESHOLD` | 50 | session réussie, badge Bronze ; au-dessous, une lacune peut naître (ADR-0043) |
| `MASTERY_THRESHOLD` | 70 | maîtrise, badge Argent : « Acquis » ≥ 70, « Fragile » de 50 à 69, « En difficulté » < 50 |
| `GOLD_THRESHOLD` | 80 | badge Or |
| `PERFECT_THRESHOLD` | 100 | sans faute, badge Diamant |

Le seuil 75 (sujets d'examen) disparaît avec la feature.

**Score** :

- `score_percent = (correct_count * 100) / question_count`, en division entière, donc arrondi vers le bas : le Diamant exige toutes les réponses justes ;
- la note sur 20 vaut `(score_percent / 5.0).round`.

L'entité expose les deux ; l'affichage est tranché par l'UDR de la V1 (Lot C).

**Deux champs** sur `exercise_sessions` (ADR-0054) :

- `progress_percent` : `integer NOT NULL DEFAULT 0`, `CHECK 0..100`, questions répondues sur questions totales ;
- `score_percent` : `integer NULL`, `CHECK 0..100`, posé **uniquement** à la clôture.

Contrainte `CHECK (status <> 'completed' OR score_percent IS NOT NULL)`. La colonne `percentage` n'existe plus.

**Table `exercise_badges`** : `student_id` (FK `users`), `exercise_id`, `level` (`CHECK IN ('bronze','silver','gold','diamond')`), `exercise_session_id` (la session qui l'a obtenu), `awarded_at`, tous `NOT NULL`. Index unique `(student_id, exercise_id)`.

**Attribution**, faite par le seul use case de clôture (ADR-0054) :

- aucun palier atteint : aucune écriture ;
- aucun badge existant : création ;
- palier **strictement** supérieur au badge existant : mise à jour de `level`, `exercise_session_id` et `awarded_at`.

**Historique** : la table ne garde que le meilleur badge. L'historique se relit dans les sessions, qui sont immuables (ADR-0054).

## 5. Conséquences

### 🟢 Positives

- C-02, C-14 et C-46 sont fermées : un barème, quatre noms, une règle de remplacement.
- Le sans-faute a son badge, et l'Or reste atteignable sur un long exercice.
- Un tableau de bord lit l'avancement ou le score sans deviner.
- Les seuils se changent à un seul endroit, avec un test.

### 🔴 Coûts consentis

- Deux seuils coïncident avec deux badges (50 et Bronze, 70 et Argent) : changer l'un change l'autre, et c'est voulu.
- Un quatrième palier à dessiner et à rendre accessible (UDR-0007).
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
      GOLD_THRESHOLD = 80
      PERFECT_THRESHOLD = 100
      BADGE_THRESHOLDS = { diamond: PERFECT_THRESHOLD, gold: GOLD_THRESHOLD,
                           silver: MASTERY_THRESHOLD, bronze: PASS_THRESHOLD }.freeze
      BADGE_ORDER = %i[bronze silver gold diamond].freeze

      def self.badge_for(score_percent) = BADGE_THRESHOLDS.find { |_, min| score_percent >= min }&.first
      def self.upgrade?(current, candidate) = current.nil? || BADGE_ORDER.index(candidate) > BADGE_ORDER.index(current)
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test unitaire de `Grading` aux bornes : 49, 50, 69, 70, 79, 80, 99 et 100.
- `test/architecture/magic_thresholds_test.rb` échoue si `app/` compare `score` ou `percent` à un littéral 50, 70, 80 ou 100 hors de `grading.rb`.
- Test de use case : un Or suivi d'un Argent laisse l'Or ; un Or suivi d'un Diamant donne le Diamant.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0008 §3 pour les badges (C-02) ; les statuts de session du même §3 passent à l'ADR-0054.
- **Remplace** l'ADR-0008 §4 pour les échelles affichées (C-46).
- **Définit** le « Diamant » que l'UDR-0003 et la landing citaient sans seuil.
- **Corrige** l'or présenté comme règle en architecture §2.7 (C-14).

## 9. Arbitrage du porteur (2026-09-25)

- Quatre paliers : Bronze ≥ 50 %, Argent ≥ 70 %, Or ≥ 80 %, Diamant = 100 %. Cela remplace la proposition initiale à trois paliers (or à 100 %, Diamant supprimé).
- La table des badges ne garde que le meilleur badge ; pas d'historique séparé.
