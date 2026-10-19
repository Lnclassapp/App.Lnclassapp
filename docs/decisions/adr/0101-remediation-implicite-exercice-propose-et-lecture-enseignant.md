# ADR-0101 : La remédiation se lance par `StartExerciseSession`, l'exercice proposé se choisit à la lecture, l'enseignant lit les lacunes de sa classe sous `ReadClassroomPolicy`
<!-- index
titre: Remédiation implicite, exercice proposé à la lecture, lecture des lacunes par l'enseignant
statut: Accepté — *amende 0043 §4 et §7*
problematique: AS-16 et AS-17 sans `StartRemediationSession` : qui lance une remédiation, quel exercice proposer, ce que l'enseignant lit des lacunes.
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-16, porteur : recommandations Q1 à Q12 acceptées) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/remediation-ciblee`](../../chantiers/remediation-ciblee/memo.md), programme `refonte-application`, V5 |
| **Remplace** | — |
| **Amende** | [ADR-0043](0043-remediation-declenchee-par-la-cloture.md) §4 (« Démarrage d'une remédiation », « Visibilité ») et §7 |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0043 prévoit que l'élève lance une remédiation par un use case dédié, `Assessment::StartRemediationSession(actor:, gap_public_id:)`, qui choisit un exercice et ouvre une session `kind: 'remediation'`.

La V1 a branché la remédiation autrement : `StartExerciseSession#new_session` ouvre une session `remediation`, rattachée à la lacune, dès que l'élève a une lacune en attente sur la fiche de l'exercice. C'est vrai pour **tous** les exercices de la fiche et pour « Recommencer ». Deux décisions acceptées s'appuient sur ce fonctionnement : l'ADR-0079 §4.1 (la remédiation compte comme « fait ») et le chantier `remediation-comptee-faite`.

Il en résulte trois constats (inventaire du 2026-10-16) :

1. `StartRemediationSession` n'a plus rien à faire : l'élève lance déjà une remédiation en démarrant un exercice de la fiche.
2. Le bouton « Refaire un exercice » de la fiche mène au premier exercice de la liste, souvent celui qui a été raté. La règle de choix de l'ADR-0043 n'est appliquée nulle part.
3. L'enseignant ne lit rien : aucune query de l'enseignant ne touche `knowledge_gaps`. L'ADR-0043 confiait cette lecture à `ReadSessionPolicy`, mais les pages concernées sont des pages de classe.

Un fait découle du point 1 : `self_corrected` n'arrive plus que pour une session `standard` commencée **avant** l'ouverture de la lacune et terminée après. L'écran « Auto-corrigés / Remédiation réussie » de l'ancienne application n'a donc plus de sens pour l'enseignant.

## 2. Moteurs de décision

1. Un seul chemin pour ouvrir une session : pas deux use cases qui écrivent la même ligne.
2. Pas de migration ni de route : le schéma de l'ADR-0043 et les routes existantes suffisent.
3. Une règle de choix pure, testable aux bornes, sans base.
4. La confidentialité des pages de classe : seuls l'enseignant de la classe et l'équipe lisent des noms (ADR-0072 §4.5).

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Écrire `StartRemediationSession` et `POST /remediation_sessions`, comme l'ADR-0043 | Fidèle à la lettre | Deux chemins pour une même session ; le use case reproduirait `StartExerciseSession` (assignation, double clic, reprise) ; une route à sécuriser en plus |
| B — **Entériner la remédiation implicite** ; le choix de l'exercice devient une lecture | Un seul chemin ; aucune route ; la règle reste pure | L'élève peut lancer une remédiation sur un autre exercice que celui proposé (c'est voulu : tout exercice de la fiche y travaille) |
| C — Empêcher les exercices non proposés d'être des remédiations | Une remédiation « ciblée » au sens strict | Casse l'ADR-0079 §4.1 et `remediation-comptee-faite` ; un élève qui fait l'exercice assigné ne lèverait pas sa fiche |

## 4. Décision

> **Nous lançons la remédiation par `StartExerciseSession`, sans use case ni route dédiés ; nous choisissons à la lecture l'exercice proposé à l'élève par une règle de domaine pure ; nous lisons les lacunes d'une classe dans une query unique, appelée après `ReadClassroomPolicy` quand `show_roster` est vrai.**

### 4.1 Démarrage (remplace « Démarrage d'une remédiation » de l'ADR-0043 §4)

- Toute session ouverte par `StartExerciseSession` sur un exercice d'une fiche où l'élève a une lacune `pending` est `kind: 'remediation'`, rattachée à cette lacune. Ce comportement existe ; il devient la règle.
- `StartRemediationSession` n'est pas écrit. Le principe *just-in-time* est conservé : rien n'est créé avant le clic.
- Le bouton de la fiche poste vers la route existante `POST /exercises/:exercise_public_id/sessions`, sans `restart` : une session commencée est reprise.

### 4.2 Exercice proposé

`Entities::Assessment::RemediationPick.call(exercises:, source_exercise_id:)` : parmi les exercices **publiés** de la fiche, rangés par `(position, id)`, il retient le premier qui satisfait, dans l'ordre :

1. différent de l'exercice source **et** de type `fixation` ;
2. différent de l'exercice source ;
3. l'exercice source.

Il renvoie `nil` sans exercice publié. L'exercice source est celui de `knowledge_gaps.source_session_id`. `Queries::Catalog::EssentialDetailQuery` applique la règle et expose l'exercice dans `GapRow`.

### 4.3 Effet d'une session sur sa fiche (lecture du résultat)

`Entities::Assessment::GapOutcome.call(session_id:, session_kind:, knowledge_gap_id:, gap:)`, où `gap` est la lacune de la fiche que la session a ouverte, levée ou ciblée :

| Situation | Effet |
|---|---|
| `gap.source_session_id == session_id` | `:opened` |
| `gap.resolved_by_session_id == session_id` | `:lifted` (quel que soit le statut, `remediated` ou `self_corrected`) |
| session `remediation`, `gap.id == knowledge_gap_id`, `gap` encore `pending` | `:still_pending` |
| sinon | `nil` |

La règle ne lit que des colonnes existantes. Elle parle de **cette** session : relu plus tard, un résultat dont la fiche a été levée par une autre session ne dit rien.

### 4.4 Lecture par l'enseignant (remplace « Visibilité » de l'ADR-0043 §4, côté enseignant)

`Queries::Assessment::ClassroomGapsQuery`, appelée seulement après `Policies::Classroom::ReadClassroomPolicy`, quand `Access#show_roster` est vrai (enseignant de la classe, équipe) :

- **Élèves** : les présents de la classe, c'est-à-dire adhésion non quittée et compte non anonymisé (`AssignmentFollowUpQuery.present_students`, ADR-0079).
- **À revoir** : toutes leurs lacunes `pending`, quelle que soit leur date d'ouverture.
- **Fiche levée** : leurs lacunes `remediated` **ou** `self_corrected` dont `resolved_at` tombe dans l'année scolaire de la classe (ADR-0041). Les deux statuts ne sont pas distingués à l'écran ; la base les garde.
- **Fiches** : publiées, d'un cours publié. `summary` se limite aux cours que la page de classe affiche déjà (`ClassroomOverviewQuery#courses` : niveau, série, matière de l'enseignant ; toutes les matières pour l'équipe).
- `summary(classroom_id:, course_slugs:)` → `[EssentialGaps(essential_slug, essential_name, course_slug, pending_count)]`, trié par `pending_count` décroissant, puis par nom.
- `detail(classroom_id:, essential_id:, school_year:)` → `Detail(pending: [PendingRow(display_name, opened_on, failed_sessions_count)], lifted: [LiftedRow(display_name, resolved_on)])`. `pending` est trié de la plus ancienne lacune à la plus récente, `lifted` de la plus récente à la plus ancienne.
- Chaque méthode fait **une** requête, quel que soit le nombre d'élèves. Les index existants suffisent : `index_knowledge_gaps_one_pending` (élève, fiche, partiel `pending`) et `index_knowledge_gaps_on_essential_id`.

La direction ne lit rien (ADR-0072 §4.5). L'élève ne lit que ses propres lacunes, comme aujourd'hui.

## 5. Conséquences

### 🟢 Positives

- Aucune migration, aucune route, aucun use case : le risque se concentre dans deux règles pures et une query.
- La remédiation reste comptée « faite » partout (ADR-0079, `remediation-comptee-faite`), sans exception à gérer.
- Le choix de l'exercice et l'effet d'une session se testent sans base, aux bornes.

### 🔴 Coûts consentis

- La remédiation n'est pas « ciblée » au sens strict : l'exercice proposé est une suggestion, et tout exercice de la fiche lève la lacune.
- `self_corrected` devient un statut presque mort. On le garde en base pour ne pas migrer, mais aucun écran ne l'affiche.
- La règle de choix ignore la difficulté et l'historique de l'élève : elle ne retient pas « l'exercice qu'il n'a pas encore fait ».
- La lecture de `ADR-0043 §7` (« écriture seulement dans `close_exercise_session.rb` et `start_remediation_session.rb` ») change : voir §7.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/remediation_pick.rb
# 🧠 DOMAINE · Entities::Assessment::RemediationPick
# Rôle : l'exercice proposé pour lever une fiche à revoir : un autre que le raté, de fixation de préférence
# ADR  : 0043, 0101
module Entities
  module Assessment
    module RemediationPick
      # exercises : exercices publiés de la fiche, rangés par (position, id), répondant à id et exercise_type.
      def self.call(exercises:, source_exercise_id:)
        others = exercises.reject { it.id == source_exercise_id }
        others.find { it.exercise_type == "fixation" } || others.first || exercises.find { it.id == source_exercise_id }
      end
    end
  end
end
```

```ruby
# app/domain/entities/assessment/gap_outcome.rb
# 🧠 DOMAINE · Entities::Assessment::GapOutcome
# Rôle : ce qu'une session terminée a fait de la fiche à revoir : ouverte, levée, encore à revoir, ou rien
# ADR  : 0043, 0101
module Entities
  module Assessment
    module GapOutcome
      # gap : répond à id, status, source_session_id, resolved_by_session_id ; nil sans lacune liée.
      def self.call(session_id:, session_kind:, knowledge_gap_id:, gap:)
        return if gap.nil?
        return :opened if gap.source_session_id == session_id
        return :lifted if gap.resolved_by_session_id == session_id
        return :still_pending if session_kind == "remediation" && gap.id == knowledge_gap_id && gap.status == "pending"

        nil
      end
    end
  end
end
```

`SessionResultQuery` lit la lacune liée en une requête : `source_session_id = :id OR resolved_by_session_id = :id OR id = :knowledge_gap_id`, priorité dans cet ordre.

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/remediation_pick_test.rb` : fixation autre que la source ; autre que la source sans fixation ; source seule ; source de type fixation ignorée au profit d'une autre ; liste vide → `nil`.
- `test/domain/entities/assessment/gap_outcome_test.rb` : les quatre cas, plus `self_corrected` lu `:lifted`, plus une remédiation dont la lacune a été levée par une autre session → `nil`.
- `grep -rn "knowledge_gap" app/domain/use_cases` ne trouve d'**écriture** que dans `close_exercise_session.rb`, et de **lecture** que dans `start_exercise_session.rb` (remplace la vérification de l'ADR-0043 §7).
- `test -e app/domain/use_cases/assessment/start_remediation_session.rb` échoue.
- `test/infrastructure/queries/assessment/classroom_gaps_query_test.rb` : élève parti, élève anonymisé, lacune levée l'année précédente, autre matière (enseignant) contre équipe, fiche dépubliée ; nombre de requêtes constant (`assert_queries_count`) à 1 et à 30 élèves.

## 8. Remplace, complète, amende

- **Amende** l'ADR-0043 §4 : « Démarrage d'une remédiation » est remplacé par §4.1 et §4.2 ; « Visibilité » côté enseignant par §4.4. Le §7 est remplacé par le §7 ci-dessus. Le reste de l'ADR-0043 et son amendement du 2026-09-27 (seuil 75) sont inchangés.
- **S'appuie sur** l'ADR-0079 §4.1 (la remédiation compte comme « fait »), l'ADR-0041 (année scolaire), l'ADR-0072 §4.5 (la direction ne lit pas de noms).
