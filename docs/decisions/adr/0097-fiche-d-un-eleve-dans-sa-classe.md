# ADR-0097 : La fiche d'un élève se lit dans sa classe, en direct, sur les exercices assignés à cette classe
<!-- index
titre: Fiche d'un élève dans sa classe, liste par trente, prochain geste
statut: Proposé
problematique: Fiche d'un élève (CL-13, AS-24) lue dans une classe, sous ReadClassroomPolicy (show_roster), élève présent seulement (404 sinon) : exercices assignés à la classe avec fait, retard, meilleur score, catégorie et signe de l'ADR-0079, badges d'après ces meilleurs scores, « fait seul » sur 30 jours ; requêtes en nombre fixe, aucun cache. Liste des élèves de la page classe par trente (cumulatif, `page`). Règle « prochain geste » en six cas sur la page de suivi (AS-23)
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/rapports-de-classe`](../../chantiers/rapports-de-classe/memo.md) |
| **S'appuie sur** | [ADR-0079](0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) (catégorie, signe, sessions de l'assignation), [ADR-0072](0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) §4.4 (fait, retard, présent), [ADR-0089](0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) §4.2 (« fait seul »), [ADR-0033](0033-bareme-des-badges-et-seuils-pedagogiques.md) (seuils, badges), [ADR-0067](0067-budgets-de-temps-serveur-des-ecrans.md) (budgets) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La V3 promet à l'enseignant de « suivre sa classe ». Depuis `rapports-exercices` (ADR-0079), il lit chaque **exercice** assigné : qui l'a fait, en retard ou non, la catégorie dominante, les questions à reprendre, les élèves en baisse. Mais il ne peut pas lire un **élève** : aucun nom ne mène à une fiche, et la seule porte vers un élève est le lien « Voir le résultat » de sa ligne, qui ouvre sa **dernière** session, quelle qu'en soit la classe ou l'assignation.

L'ancienne application avait une fiche (`/teachers/classrooms/:id/students/:public_id`), cassée dès le premier exercice assigné. Elle listait toutes les sessions de l'élève, toutes classes confondues, avec un badge lu dans une colonne jamais écrite. Elle mélangeait donc ce que l'élève avait fait pour cette classe et ce qu'il avait fait ailleurs.

Trois autres points restent ouverts dans la V3 :

- la liste des élèves de la page de la classe n'a pas de limite, alors qu'une classe va jusqu'à 150 élèves, et la page est hors budget (231,6 Ko, 153 ms p95, journal de `rapports-exercices`) ;
- le message à l'enseignant de l'ancien rapport (AS-23) était fait de 36 phrases en dur dans la vue, choisies par `exercise.id % 6` ;
- les noms de la page de suivi ne portent pas d'identifiant (UDR-0072 §3.5 bis), faute de fiche où mener.

Il faut donc dire ce que lit une fiche, qui la lit, comment elle reste dans son budget, et quelle règle choisit une phrase pour l'enseignant.

## 2. Moteurs de décision

1. **La mission** (porteur, 2026-10-04) : aider chaque acteur à progresser. La fiche doit dire à l'enseignant quoi faire pour cet élève, pas tout son passé.
2. **Un seul chiffre par fait** : le « fait », le « retard » et la catégorie d'un élève sur la fiche sont ceux de la page de suivi. Jamais deux réponses à la même question.
3. **Ne rien réinventer** : les règles de lecture existent (ADR-0072, ADR-0079, ADR-0089) et les policies aussi.
4. **Le budget de l'ADR-0067** : < 100 ms p95 et < 150 Ko, avec un nombre de requêtes fixe.
5. **La protection des élèves** : numéro masqué (ADR-0083 §4.4 bis), aucune fiche hors de la classe de l'enseignant.

## 3. Options envisagées

### 3.1 Ce que lit la fiche

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Toutes les sessions de l'élève, toutes classes (l'ancienne fiche) | Complète ; une seule requête | Mélange les classes (défaut d'AS-24) ; un « Diamant » obtenu ailleurs contredit un « Fragile » ici ; l'enseignant n'a pas assigné ces exercices |
| **B — Les exercices assignés à la classe, plus le « fait seul » récent** | Mêmes règles que la page de suivi ; dit ce qui reste à faire ; le « fait seul » répond au chiffre « 2 fait seul (7 j) » de la liste | **Retenue** (Q2, recommandation) |
| C — Les exercices assignés seulement | Plus court | Le chiffre « fait seul » de la liste reste sans détail |

### 3.2 La liste des élèves

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pas de limite, lignes allégées | Rien à paginer | Toujours ~150 lignes à 150 élèves ; le budget dépend de l'effectif |
| B — Pages numérotées (`?page=2` remplace la liste) | Classique | Les nouveaux en tête n'ont de sens que sur la page 1 ; numéros inutiles sur téléphone |
| **C — Trente, puis « Voir les 30 suivants », cumulatif** | Le budget ne dépend plus de l'effectif à l'ouverture ; marche sans JavaScript (lien qui rend les 60 premiers) ; la recherche reste le chemin court | **Retenue** (Q5, recommandation) |

### 3.3 Le message à l'enseignant

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Reprendre les 36 phrases et leur tirage par exercice | Fidèle à l'ancien | Phrases en dur, choix arbitraire, des félicitations qui ne disent pas quoi faire |
| **B — Une phrase « prochain geste » par cas, six cas, règle du domaine** | Chaque lecture appelle un geste ; testable ; une phrase par cas dans les locales | **Retenue** (Q6, recommandation) |
| C — Aucun message | La section marque déjà les questions à reprendre | Laisse l'enseignant faire la synthèse lui-même |

## 4. Décision

> **Nous lisons la fiche d'un élève dans une classe, en direct, sur les exercices assignés à cette classe et sur son « fait seul » des 30 derniers jours, avec les règles existantes. Nous paginons la liste des élèves par trente. Nous choisissons la phrase de l'enseignant par une règle du domaine à six cas.**

### 4.1 L'unité : un élève présent dans une classe active

- La fiche est celle d'un couple (classe, élève), à l'adresse `/classrooms/:classroom_public_id/students/:student_public_id`.
- **Classe** : inconnue ou archivée → 404 (ADR-0088, comme sa page).
- **Élève** : il doit être **présent** dans la classe, au sens de l'ADR-0072 §4.4 (`classroom_students.left_at IS NULL`, `users.anonymized_at IS NULL`). Sinon → 404 : parti, anonymisé, jamais membre, ou inconnu. La réponse ne distingue pas ces cas.

### 4.2 Qui la lit

- **`Policies::Classroom::ReadClassroomPolicy`**, accès accordé **avec `show_roster`** : l'enseignant de la classe et l'équipe. Une réponse sans `show_roster` (élève de la classe) est un refus.
- Refus (403) : élève, enseignant d'une autre classe, direction, compte sans rôle admis. Visiteur : connexion.
- **Aucune policy nouvelle.** La policy est appelée avant toute lecture de l'élève. Le 404 de l'élève vient après elle : un enseignant d'une autre classe reçoit 403, jamais une indication de présence.
- Les actions de la fiche gardent leurs policies : `IssuePinRecoveryCodePolicy` (code de récupération) et `ManageClassroomMembersPolicy` (retrait, classe active).

### 4.3 Les exercices de la classe

Pour chaque assignation **active** de la classe, dans l'ordre de la page de la classe (UDR-0062 §3.4 : échéance croissante, sans échéance à la fin, puis la plus récente) :

- **Fait** : au moins une session `completed` rattachée à l'assignation, standard ou de remédiation (ADR-0072 §4.4, ADR-0079 §4.1). Une session de l'élève hors de l'assignation (autre classe, « fait seul ») ne compte pas.
- **Rendu en retard** : `due_on` non nul et la date locale de la première session faite postérieure à `due_on` (ADR-0072 §4.4). La fiche lit `AssignmentFollowUpQuery.first_done`, la même définition.
- **Pas encore fait, échéance passée** : non fait et `due_on` antérieure à aujourd'hui (date d'Abidjan).
- **Meilleur score, première et meilleure session** : `Queries::Assessment::AssignmentScores` (meilleure = score maximal, la plus récente à égalité, ADR-0079 §4.5).
- **Catégorie** : `Entities::Assessment::Comprehension.category_for(best)`. **Signe** : `Comprehension.trend_for(scores)` ; une seule session, pas de signe.
- **Sessions** : le nombre de sessions faites.
- **Chiffres de tête** : faits, en retard, pas encore faits, sur les assignations actives. « Faits 7 sur 10 ».

### 4.4 « Fait seul »

- Définition de l'ADR-0089 §4.2 : session `completed`, `standard`, **sans assignation**, de cet élève. Toutes les matières : l'équipe et l'enseignant lisent le même contenu.
- **Fenêtre : 30 jours**, aujourd'hui compris, en date d'Abidjan, sur `started_at` comme l'ADR-0089. Constante nommée `StudentFileQuery::SELF_PRACTICE_DAYS = 30`, une seule définition.
- Au plus **20 lignes**, de la plus récente à la plus ancienne, et le total : la fiche reste légère.

### 4.5 Badges

- Un palier par exercice fait, `Entities::Assessment::Grading.badge_for(best)` sur le meilleur score de l'assignation (ADR-0079 §4.2). Comptés par palier ; sous 50, pas de palier.
- **La table `exercise_badges` n'est pas lue** : elle garde le record de l'élève toutes classes confondues (ADR-0033), qui contredirait la catégorie de la classe.

### 4.6 Prochain geste (AS-23)

Règle pure, `Entities::Assessment::NextStep.for(done:, pending:, readable:, dominant:, decline:)`, où `readable` est `Comprehension.readable?(done)`, `dominant` est `Comprehension.dominant(counts)` et `decline` le nombre d'élèves `:decline`. Le premier cas vrai l'emporte :

| # | Condition | Symbole | Phrase (locale `assessment.comprehension.next_step.*`) |
|---|---|---|---|
| 1 | `done == 0` | `nil` | aucune : l'état vide de la section suffit |
| 2 | non `readable` et `pending > 0` | `:remind` | « Relancez les %{count} élèves qui ne l'ont pas encore fait : la lecture de la classe sera fiable à partir de 5. » |
| 3 | non `readable` et `pending == 0` | `:look_at_each` | « Tous les élèves l'ont fait. La classe est trop petite pour une tendance : regardez chaque élève. » |
| 4 | `dominant == :struggling` | `:revisit_notion` | « La plupart des élèves sont en difficulté : reprenez la notion avant d'avancer. » |
| 5 | `dominant == :fragile` | `:revisit_questions` | « La notion se met en place : reprenez en classe les questions marquées, puis avancez. » |
| 6 | `dominant == :acquired` et `decline > 0` | `:watch_decline` | « La classe a compris. %{count} élèves sont en baisse : voyez-les dans leur catégorie. » |
| 7 | sinon (`:acquired`) | `:move_on` | « La classe a compris : vous pouvez avancer. » |

- Déterministe : même lecture, même phrase. Aucun tirage, aucune variante par exercice.
- « 5 » est `Comprehension::MIN_DONE_FOR_READING`, interpolé, jamais écrit en dur.
- La règle vit dans le domaine. La vue ne choisit pas.

### 4.7 Liste des élèves de la page de la classe

- `ClassroomOverviewQuery#call` reçoit `page:` (entier ≥ 1, 1 par défaut ; toute autre valeur vaut 1) et rend les **`page × 30`** premiers élèves, dans l'ordre existant (nouveaux en tête, puis nom, UDR-0081 §3.7), après la recherche.
- `Overview` gagne **`students_total`** : le nombre d'élèves qui répondent à la recherche, toute la classe sans recherche. Il vaut nil sans `show_roster`.
- `PER_PAGE = 30`, constante de la query.
- Les lectures par élève (dernière session, photos, « fait seul ») ne portent que sur les lignes rendues.

**Amendement du 2026-10-16 (porteur, réponse à Q5).** La liste se découpe d'abord **par note sur 20** : moyenne des meilleurs
scores de l'élève aux exercices assignés actifs de la classe, arrondie par `Grading.grade_on_20` ; groupes 0–10, 11–15, 16–20
et « pas encore de note » (`Entities::Classroom::RosterGrade`). `call` reçoit `note:` ; `Overview` gagne `grade_group` (nil avec
une recherche, qui porte sur toute la classe) et `grade_counts` ; `StudentRow` gagne `grade`. Les notes de toute la classe se
lisent en une requête ; la pagination par trente vaut à l'intérieur du groupe. Aucune moyenne de classe.

### 4.8 Lecture, cache, budget

- **Aucun cache.** Lecture en direct, comme l'ADR-0079 §4.6.
- **Nombre de requêtes fixe** pour la fiche, quel que soit le nombre d'assignations : en-tête de l'élève, assignations, scores (`AssignmentScores.for` filtré sur l'élève), premières sessions, « fait seul », photo.
- **Aucune migration.** Index utilisés : `index_exercise_sessions_on_classroom_assignment_id`, `index_exercise_sessions_on_student_id_and_completed_at`, `index_exercise_sessions_on_started_at_and_student_id`. À confirmer au budget, sinon un ADR d'index.
- Budget ADR-0067 : < 100 ms p95, < 150 Ko, pour la fiche comme pour la page de la classe.

### 4.9 Identifiants d'élève dans le HTML

Le `public_id` de l'élève apparaît dans les liens de la page de la classe et de la page de suivi. Il n'est pas un secret (ADR-0029). Les pages restent sous leurs policies. Les `Data` concernées gagnent `public_id` : `ComprehensionDetailQuery::StudentRow`, `AssignmentFollowUpQuery::LateStudent` et `PendingStudent`.

## 5. Conséquences

### 🟢 Positives

- L'enseignant passe d'un nom à un élève en un geste, depuis toutes les listes où il le croise.
- Un même élève a le même état, le même score et la même catégorie sur la fiche et sur la page de suivi.
- La page de la classe ne grossit plus avec l'effectif : son poids à l'ouverture est borné par 30 lignes.
- AS-23 devient une règle testée cas par cas, sans phrase en dur dans une vue.
- Aucune table, aucune migration, aucune policy nouvelle.

### 🔴 Coûts consentis

- Un élève qui a fait un exercice depuis une autre classe le voit « pas encore fait » sur la fiche de cette classe. C'est la règle de la page de suivi, et elle est assumée.
- Un badge obtenu ailleurs n'apparaît pas sur la fiche (Q3).
- La fiche ne dit rien des lacunes en attente : la V5 (AS-17) les y ajoutera.
- Le « Voir les suivants » cumulatif rend à nouveau les lignes déjà vues : à 150 élèves, la dernière réponse rend 150 lignes. C'est le prix d'un repli sans JavaScript simple.
- La fenêtre de 30 jours et les six phrases sont des premières valeurs, à revoir après usage.
- Déplacer le code de récupération et le retrait sur la fiche (Q4) coûte un geste de plus pour une action rare.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/next_step.rb
module Entities
  module Assessment
    module NextStep
      # → nil | :remind | :look_at_each | :revisit_notion | :revisit_questions | :watch_decline | :move_on
      def self.for(done:, pending:, readable:, dominant:, decline:)
        return if done.zero?
        return pending.positive? ? :remind : :look_at_each unless readable
        return :revisit_notion if dominant == :struggling
        return :revisit_questions if dominant == :fragile

        decline.positive? ? :watch_decline : :move_on
      end
    end
  end
end
```

```ruby
# app/infrastructure/queries/classroom/student_file_query.rb (contrat gelé au Lot 0)
module Queries
  module Classroom
    class StudentFileQuery
      SELF_PRACTICE_DAYS = 30
      SELF_PRACTICE_LIMIT = 20
      # contact : masqué (ADR-0083 §4.4 bis) ; joined_via : Entities::Classroom::StudentArrivalChannel.
      File = Data.define(:student, :counts, :badge_counts, :assignments, :self_practice, :self_practice_total)
      Student = Data.define(:public_id, :display_name, :contact, :photo_version, :joined_at, :joined_via, :newcomer)
      Counts = Data.define(:done, :late, :pending, :assigned)
      # status : :done, :late (rendu en retard), :pending, :overdue (pas fait, échéance passée).
      # best, category, trend, sessions_count, best_session_public_id : nil sans session faite ; trend nil à une session.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :status,
                                  :done_on, :best, :category, :trend, :sessions_count, :best_session_public_id)
      SelfPracticeRow = Data.define(:session_public_id, :exercise_title, :material_name, :material_category,
                                    :score_percent, :completed_at)

      # today : date d'Abidjan (Time.zone), jamais Date.today. → File | nil (élève absent de la classe : 404)
      def call(classroom_public_id:, student_public_id:, today: Time.zone.today) = raise NotImplementedError
    end
  end
end
```

```ruby
# app/controllers/classroom/classroom_students_controller.rb — ordre des gardes
def show
  @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
  return render_not_found if @header.nil? || @header.status == "archived"

  render_result read_roster_policy, success: lambda { |_|
    @file = Queries::Classroom::StudentFileQuery.new.call(classroom_public_id: @header.public_id,
                                                          student_public_id: params[:student_public_id])
    render_not_found if @file.nil?
  }
end
```

`read_roster_policy` rend un échec `:forbidden` quand `ReadClassroomPolicy` réussit sans `show_roster`. `ClassroomHeaderQuery::Row` n'a pas d'`id` : la query part du `public_id` de la classe.

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/next_step_test.rb` : les sept lignes du tableau du §4.6, plus les bornes 4 et 5 élèves faits.
- `test/infrastructure/queries/classroom/student_file_query_test.rb` : élève parti, anonymisé, d'une autre classe → nil ; session d'une autre classe ignorée ; remédiation comptée ; retard ; badges sans lecture d'`exercise_badges` ; fenêtre de 30 jours aux bornes ; **même nombre de requêtes à 1 et à 10 assignations** ; aucun numéro complet dans le résultat.
- Test croisé : pour un élève et une assignation, `StudentFileQuery` et `AssignmentFollowUpQuery` + `ComprehensionDetailQuery` donnent le même état, le même meilleur score et la même catégorie.
- `test/controllers/classroom/classroom_students_controller_test.rb` : 403 (élève, autre enseignant, direction), 404 (absent, classe archivée), 200 (enseignant, équipe).
- `test/infrastructure/queries/classroom/classroom_overview_query_test.rb` : 30 lignes, cumul à `page: 2`, `students_total` avec et sans recherche, `page` invalide.
- Budget : `script/perf/measure_screens.rb` sur la fiche et la page de la classe, consigné au journal du chantier.
