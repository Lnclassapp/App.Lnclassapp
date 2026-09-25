# ADR-0043 : Remédiation déclenchée par le seul use case de clôture, session de remédiation marquée, une lacune en attente par fiche garantie en base

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-21**, bloque la V5 |
| **Remplace** | [ADR-0018](./0018-remediation-just-in-time-et-historique-lacunes.md) §3 |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0018 §3.1 annonce qu'une ou plusieurs lacunes naissent de l'échec d'une session, et qu'une session de remédiation est reconnaissable. Le code crée une lacune au plus, la déclenche depuis une simulation jamais appelée, et aucune colonne ne marque la session de remédiation (**C-47**).

L'ADR-0018 §3.2 nomme ses classes à la racine (**C-49**, fermée par l'ADR-0027). Sa clé primaire est une chaîne nanoid (**C-15**, fermée par l'ADR-0029).

## 2. Moteurs de décision

1. Une lacune naît au même endroit que le score : la clôture.
2. Une lacune en double est impossible, même sous double clic.
3. Une session de remédiation se reconnaît en base, sans heuristique.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Reprendre l'ADR-0018 tel quel | Écrit | Jamais appliqué ; déclencheur flou |
| B — **Reconception autour de la clôture** | Un seul point de décision, testable | Toute la V5 est à écrire |

## 4. Décision

> **Nous détectons et résolvons les lacunes dans `Assessment::CloseExerciseSession` uniquement, nous marquons la session de remédiation par une colonne, et nous garantissons en base une seule lacune en attente par élève et par fiche.**

**Table `knowledge_gaps`** (contexte `assessment`, clé `bigint`) :

| Colonne | Contrainte |
|---|---|
| `public_id` | ADR-0029 |
| `student_id` | `NOT NULL`, FK `users` |
| `essential_id` | `NOT NULL`, FK `essentials` (`restrict`) |
| `source_session_id` | `NOT NULL`, FK `exercise_sessions` |
| `status` | `CHECK IN ('pending','remediated','self_corrected')` |
| `failed_sessions_count` | `integer NOT NULL DEFAULT 1` |
| `resolved_at` | `datetime NULL` |
| `resolved_by_session_id` | FK `exercise_sessions`, `NULL` |

Index unique partiel `(student_id, essential_id) WHERE status = 'pending'`.

**Colonnes sur `exercise_sessions`** (ADR-0054) : `kind` (`string NOT NULL DEFAULT 'standard'`, `CHECK IN ('standard','remediation')`) et `knowledge_gap_id` (FK `NULL`). Contrainte : `CHECK ((kind = 'remediation') = (knowledge_gap_id IS NOT NULL))`.

**À la clôture**, dans la transaction de `CloseExerciseSession`, sur la fiche de l'exercice :

| Cas | Effet |
|---|---|
| `score_percent < PASS_THRESHOLD` (ADR-0033), aucune lacune en attente | création d'une lacune `pending` |
| `score_percent < PASS_THRESHOLD`, une lacune en attente | `failed_sessions_count + 1` |
| `score_percent >= PASS_THRESHOLD`, lacune en attente, session `remediation` | `remediated` |
| `score_percent >= PASS_THRESHOLD`, lacune en attente, session `standard` | `self_corrected` |

Une création concurrente qui heurte l'index unique est traitée comme le cas « une lacune en attente ».

**Démarrage d'une remédiation** : `Assessment::StartRemediationSession(actor:, gap_public_id:)`. La policy exige que l'élève soit le propriétaire de la lacune et que celle-ci soit `pending`. La génération est *just-in-time* : rien n'est créé avant le clic, ce principe de l'ADR-0018 est conservé.

On choisit un exercice `published` de la même fiche, de préférence `fixation` et différent de l'exercice source, à défaut l'exercice source ; aucun exercice publié : `:not_found`, et la lacune reste `pending`. La session créée est `kind: 'remediation'`.

**Visibilité** : l'élève voit ses lacunes `pending` en V5 ; l'enseignant voit celles des élèves de ses classes (`Assessment::ReadSessionPolicy`).

## 5. Conséquences

### 🟢 Positives

- C-47 est fermée : un déclencheur, un marquage, un invariant en base.
- La lacune et le score sortent de la même transaction : jamais de lacune sans session close.

### 🔴 Coûts consentis

- Une lacune par fiche, pas par question : la granularité reste celle de l'ADR-0018.
- La remédiation réutilise des exercices existants. Une fiche sans second exercice repropose le même.
- `CloseExerciseSession` porte trois responsabilités (score, badge, lacune). Elles sont extraites en services de domaine appelés par lui, mais il reste le seul point d'entrée.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Assessment::GapDecision
# Rôle : décide de l'effet d'une clôture sur la lacune d'une fiche
# ADR  : 0033, 0043
module Entities
  module Assessment
    module GapDecision
      def self.call(score_percent:, pending_gap:, session_kind:)
        passed = score_percent >= Grading::PASS_THRESHOLD
        return pending_gap ? :increment : :open unless passed
        return :none unless pending_gap

        session_kind == :remediation ? :remediated : :self_corrected
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test unitaire de `GapDecision` sur les quatre cas.
- Test de repository : deux lacunes `pending` pour la même fiche lèvent `RecordNotUnique`.
- `grep -rn "knowledge_gap" app/domain/use_cases` ne trouve d'écriture que dans `close_exercise_session.rb` et `start_remediation_session.rb`.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0018 §3 (C-47). Le principe *just-in-time* et l'historique des lacunes sont conservés ; les noms (C-49) et la clé (C-15) sont traités par les ADR-0027 et 0029.

## 9. Points à confirmer par le porteur

- Une lacune en attente par élève **et par fiche** : l'unicité par élève seul, que suggérerait la lettre du registre, serait trop restrictive.
- La remédiation réutilise un exercice existant, sans génération de questions.
