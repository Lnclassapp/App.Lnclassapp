# ADR-0079 : La compréhension d'un exercice assigné se lit au meilleur score de chaque élève, avec un signe de progrès, sur les seules sessions de l'assignation

| | |
|---|---|
| **Statut** | Accepté (2026-10-04, porteur, avec le plan du chantier) |
| **Date** | 2026-10-04 |
| **Chantier** | [`docs/chantiers/rapports-exercices`](../../chantiers/rapports-exercices/memo.md) — tranche « exercices » de `rapports-de-classe` (V3) |
| **Remplace** | — *(complète ADR-0033, ADR-0048, ADR-0072 ; tranche la question ouverte de l'ADR-0072 sur les élèves pas encore faits)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis l'ADR-0072, l'enseignant voit pour chaque exercice assigné combien d'élèves l'ont **fait**, et qui l'a rendu en retard. Il ne sait pas s'ils l'ont **compris**. L'ancienne application avait deux rapports par exercice (AS-21, AS-22). Ils sont cassés, et leurs chiffres étaient faux :

- un taux de réussite par question dont le dénominateur était l'effectif de la classe, et qui dépassait 100 % dès qu'un élève recommençait ;
- trois seuils non nommés (50, 70, 80) ;
- des badges Bronze invisibles ;
- un cache d'une heure jamais invalidé.

Le porteur veut **mesurer la compréhension et la présenter à l'enseignant au bon moment**, avec trois couleurs et un cercle de la couleur dominante. Il veut aussi **montrer le progrès des élèves**, l'atout de Lnclass (grill du 2026-10-04).

Quatre questions n'avaient pas de réponse :
- quel essai d'un élève compte, quand il peut recommencer sans limite et que la correction s'affiche après chaque question (AS-10) ;
- comment dire le progrès ;
- quand une lecture de classe est fiable ;
- quelles sessions comptent.

## 2. Moteurs de décision

0. **La mission de Lnclass : aider chaque acteur du système éducatif à progresser** (porteur, 2026-10-04). Une lecture qui ne débouche sur aucun geste de l'enseignant (reprendre une question, aider un élève) n'aide personne : chaque chiffre affiché doit en appeler un.
1. **Une seule vérité par écran** : le cercle, les badges et le compte « faits » d'un même exercice ne se contredisent jamais.
2. **Le progrès se voit**, sans brouiller le niveau atteint.
3. **Pas d'alerte sur trop peu de données** : deux élèves sur quarante-cinq ne décrivent pas une classe.
4. Les seuils ont un nom et une seule définition (ADR-0033).
5. Le budget de 100 ms par écran (ADR-0067) tient sans cache.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Premier essai | Mesure la compréhension avant la correction ; stable | Cache tout progrès (refusé par le porteur) |
| B — Moyenne des trois premiers essais | Lisse ; tient compte de l'apprentissage | 30-60-90 et 60-60-60 donnent tous deux 60 : la moyenne efface le progrès qu'elle voulait montrer ; un élève Argent peut y être jaune |
| C — **Meilleur score pour la couleur, signe de progrès à part** | La couleur suit le badge ; le signe porte le progrès ; trois nombres suffisent (premier, meilleur, dernier) | Un élève qui récite le corrigé peut atteindre 100 % : le signe le montre en partie, le bachotage n'est pas détecté |
| D — Dernier essai | Suit la tendance | Un dernier essai bâclé fait retomber un bon élève, et la couleur contredit le badge |

**Option C retenue par le porteur le 2026-10-04.**

## 4. Décision

> **Nous lisons la compréhension d'un exercice assigné sur les seules sessions faites de cette assignation. Nous classons chaque élève par son meilleur score dans les trois catégories de maîtrise de l'ADR-0033. Nous lui donnons un signe de progrès, calculé sur son premier, son meilleur et son dernier essai avec une marge de 10 points. Nous colorons la classe par sa catégorie dominante, la plus fragile à égalité, dès 5 élèves. Tout se lit en direct, sans cache.**

### 4.1 Ce qui compte

- **Unité** : une assignation active (un exercice assigné à une classe). Pas l'exercice seul.
- **Sessions** : la définition de « fait » de l'ADR-0048 et de l'ADR-0072 §4.4, élargie à la remédiation :
  - `completed`, **quel que soit son `kind`** (`standard` ou `remediation`) ;
  - rattachées à l'assignation (`classroom_assignment_id`) ;
  - d'un élève présent : adhésion non quittée, compte non anonymisé.

  **Une session de remédiation sur l'exercice assigné, c'est faire cet exercice.** `StartExerciseSession` ouvre une session `remediation` dès que l'élève a une lacune en attente sur la fiche (ADR-0043), pour **tous** les exercices de la fiche, et la rattache à l'assignation. Ne compter que `standard` cachait le travail de l'élève à l'enseignant :
  - un élève qui rate à 25 % puis réussit à 75 % en remédiation restait « En difficulté », à une seule session, sans signe de progrès ;
  - un élève dont la lacune venait d'un autre exercice de la fiche faisait l'exercice assigné en remédiation automatique et restait « pas encore fait » : la page de suivi demandait à l'enseignant de le relancer, à tort.

  Les scores (première, meilleure et dernière session, taux par question) et les comptes faits, en retard et pas encore faits incluent donc la remédiation. Le « rendu en retard » se lit sur la première session faite, quel que soit son `kind`.

  Une session lancée depuis une autre classe ou hors assignation (remédiation comprise), une session commencée : ne comptent pas.

  *Complément du 2026-10-04 : la première version de ce paragraphe excluait la remédiation. Le défaut a été trouvé en navigateur réel pendant le chantier ; l'orchestrateur a tranché par mandat du porteur.*
- **Effectif** : les élèves présents. Le « 18/25 » du cercle est le même nombre que le « 18 faits » de la page.

### 4.2 Catégorie d'un élève

- `best` = le plus haut `score_percent` de ses sessions faites.
- La catégorie est `Grading.mastery_for(best)` :
  - `:struggling` (« En difficulté ») sous 50 ;
  - `:fragile` (« Fragile ») de 50 à 69 ;
  - `:acquired` (« Acquis ») à partir de 70.
- Aucun seuil nouveau : `PASS_THRESHOLD` et `MASTERY_THRESHOLD`.
- **Badges** : le palier `Grading.badge_for(best)` de chaque élève. Ils sont comptés par palier ; un élève sous 50 n'a pas de palier.
- On ne lit pas la table `exercise_badges` : un badge obtenu hors de l'assignation ne compte pas ici. La couleur et le badge viennent ainsi du même score.

### 4.3 Signe de progrès

Les sessions faites de l'élève sont prises dans l'ordre de `completed_at` : `first` est le score de la première, `last` celui de la dernière, `best` le plus haut. Les règles s'appliquent **dans cet ordre** :

| Signe | Condition |
|---|---|
| aucun | une seule session faite |
| `:decline` (« en baisse ») | `best − last ≥ PROGRESS_MARGIN` |
| `:progress` (« en progrès ») | `best − first ≥ PROGRESS_MARGIN` |
| `:stable` (« stable ») | sinon, et `best ≥ MASTERY_THRESHOLD` |
| `:stagnant` (« stagne ») | sinon |

`PROGRESS_MARGIN = 10`. Sur 20 questions, une bonne réponse vaut 5 points ; 10 points correspondent à environ une question sur dix.

**Synthèse de la classe** : « N en progrès · N sans évolution · N en baisse ». « Sans évolution » regroupe `:stable` et `:stagnant`. Les élèves sans signe n'y sont pas.

### 4.4 Lecture de la classe

- **Fiable** dès `MIN_DONE_FOR_READING = 5` élèves ayant fait l'exercice. C'est la valeur de `MIN_STUDENTS_FOR_AVERAGE` (ADR-0065), avec une définition propre au domaine.
- En dessous, le cercle est gris, sans catégorie.
- **Dominante** : la catégorie qui compte le plus d'élèves. À égalité, la plus fragile l'emporte (`:struggling`, puis `:fragile`, puis `:acquired`) : l'enseignant est alerté plutôt que rassuré à tort.

### 4.5 Taux par question d'une catégorie

- Pour chaque élève de la catégorie, on prend son **meilleur essai** : la session faite de score `best`, la plus récente à égalité.
- Pour chaque question de l'exercice, dans l'ordre de `position`, le taux est la part arrondie des tentatives justes (`correct`) parmi les tentatives de ces sessions sur cette question.
- Pas de tentative : « — ».
- Le dénominateur compte des tentatives, une au plus par session et par question (index unique) : le taux **ne peut pas dépasser 100 %**.
- **Progrès par question** : le même taux, lu sur le **premier essai** (première session faite) de chaque élève de la catégorie. Il n'est donné que si au moins un élève de la catégorie a deux essais ou plus ; sinon il serait égal au premier. Dans une catégorie qui mêle des élèves à une session et des élèves à plusieurs, il se lit sur la première session de **chaque** élève de la catégorie, y compris ceux qui n'en ont qu'une : leur première session est bien leur première, et « 1re session » dit ainsi où était toute la catégorie au départ (décision de l'orchestrateur, 2026-10-04).
- **Question à reprendre** : une question dont le taux au meilleur essai est **sous `PASS_THRESHOLD` (50)** est marquée « À reprendre en classe ». C'est l'« alerte révision » de l'ancien rapport, avec un seuil nommé.

### 4.7 Ordre des élèves d'une catégorie

Ceux qui ont le plus besoin de l'enseignant d'abord : `:decline`, puis `:stagnant`, puis sans signe (un seul essai), puis `:stable`, puis `:progress` ; à égalité, par nom (`last_name`, `first_name`). Un élève en progrès n'a pas besoin qu'on le cherche.

### 4.6 Lecture, autorisation, cache

- Lecture seule, en CQRS (ADR-0026) : aucune table, aucun port, aucun use case.
- Les lectures s'appellent après `Policies::Classroom::FollowAssignmentPolicy` (ADR-0072 §4.5), **inchangée** : l'équipe et l'enseignant de la classe, jamais l'élève, un autre enseignant ni la direction.
- **Aucun cache.** L'ordre des leviers de l'ADR-0062 s'applique : index, puis requête, puis cache par ADR.
- La page classe lit les résumés de toutes ses assignations en un nombre de requêtes constant.

### 4.8 Élèves qui n'ont pas encore fait l'exercice

Décision du porteur (2026-10-04) : pour qu'il aide chaque élève à progresser, l'enseignant doit savoir **qui relancer**. La page de suivi **nomme** les élèves présents sans session faite sur l'assignation, triés par nom (`last_name`, `first_name`, `id`). Même policy que les rendus en retard (`FollowAssignmentPolicy`) : un élève ne voit jamais ces noms. Un élève qui a seulement une session commencée y figure. Cela tranche la question laissée ouverte par l'ADR-0072 (UDR-0062 §3.5 : « les pas encore faits ne sont pas nommés »).

## 5. Conséquences

### 🟢 Positives

- Le cercle, les badges et les « faits » d'un exercice viennent des mêmes sessions et du même score : ils ne se contredisent plus.
- Le progrès a sa propre lecture, au lieu d'être noyé dans une moyenne.
- Le taux par question ne dépasse plus 100 %. Il désigne la question à reprendre, catégorie par catégorie, et montre ce que la classe a appris entre le premier et le meilleur essai.
- Chaque lecture appelle un geste : reprendre une question marquée, aller voir d'abord l'élève en baisse ou qui stagne, relancer un élève qui n'a pas encore fait l'exercice.
- Aucun cache à invalider : le défaut de l'ancien rapport disparaît avec lui.
- Les règles tiennent dans un module pur, testable aux bornes et réutilisable par la V5 (suivi des remédiations, AS-17).

### 🔴 Coûts consentis

- **Bachotage** : un élève qui recommence jusqu'à 100 % en récitant le corrigé devient « Acquis ». Il apparaît « en progrès », pas « en baisse ». La détection (essais enchaînés en quelques minutes) est hors périmètre.
- Un élève qui a obtenu un badge plus haut hors de cette assignation apparaît ici à son palier de l'assignation. Le badge affiché sur ses propres pages peut différer.
- La marge de 10 points et le seuil de 5 élèves sont des premières valeurs, à revoir après usage. Chacun a une seule définition.
- Un exercice fait avant d'être assigné, ou depuis la fiche hors assignation, ne compte pas : l'enseignant ne voit que le travail donné à sa classe.
- **Les pages de la direction comptent encore « fait » sans la remédiation.** `Queries::School::StudentWorkQuery` et `Queries::School::DepartedStudentsQuery` filtrent toujours `kind = 'standard'` : leur correction demande un nouvel index (l'index partiel `index_exercise_sessions_handed_in` ne couvre que `standard`). Elle part dans le chantier de correction `remediation-comptee-faite`. D'ici là, un élève qui n'a fait l'exercice assigné qu'en remédiation est « fait » pour l'enseignant et pas pour la direction.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/comprehension.rb
# 🧠 DOMAINE · Entities::Assessment::Comprehension
# Rôle : lecture de la compréhension d'un exercice assigné : catégorie, signe de progrès, dominante, seuil de lecture
# ADR  : 0033, 0079
module Entities
  module Assessment
    module Comprehension
      PROGRESS_MARGIN = 10
      MIN_DONE_FOR_READING = 5
      # Du plus fragile au plus solide : l'ordre tranche les égalités de la dominante.
      CATEGORIES = %i[struggling fragile acquired].freeze
      # Ordre des élèves d'une catégorie (§4.7) : qui a le plus besoin de l'enseignant d'abord ; nil = un seul essai.
      TREND_ORDER = [ :decline, :stagnant, nil, :stable, :progress ].freeze

      def self.category_for(best) = Grading.mastery_for(best)

      # scores : score_percent des sessions faites, dans l'ordre de completed_at. → nil | :decline | :progress | :stable | :stagnant
      def self.trend_for(scores)
        return if scores.size < 2

        best = scores.max
        return :decline if best - scores.last >= PROGRESS_MARGIN
        return :progress if best - scores.first >= PROGRESS_MARGIN

        best >= Grading::MASTERY_THRESHOLD ? :stable : :stagnant
      end

      # counts : { struggling: n, fragile: n, acquired: n } → la catégorie la plus nombreuse, la plus fragile à égalité ; nil sans élève.
      def self.dominant(counts)
        return if counts.values.sum.zero?

        CATEGORIES.max_by { |category| [ counts.fetch(category, 0), -CATEGORIES.index(category) ] }
      end

      def self.readable?(done) = done >= MIN_DONE_FOR_READING

      def self.to_revisit?(rate) = !rate.nil? && rate < Grading::PASS_THRESHOLD
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/comprehension_test.rb` :
  - meilleurs scores 49, 50, 69 et 70 ;
  - séries 30-60-90, 60-60-60, 30-90-40, 90-40, 100-100, 50-59, 50-60, 80-90-81, 80-90-80 et un seul essai ;
  - égalités Acquis/Fragile et En difficulté/Acquis ;
  - ordre des signes pour le tri des élèves ;
  - 4 et 5 élèves.
- Tests des queries `Queries::Assessment::*` et `Queries::Classroom::AssignmentFollowUpQuery` : une session de remédiation rattachée à l'assignation compte (25 % puis 75 % en remédiation donnent un meilleur score de 75, « Acquis », « en progrès », et des taux lus sur la remédiation ; un élève dont la seule session est une remédiation est fait, en retard après l'échéance, absent des « pas encore faits ») ; une session d'une autre classe, une session hors assignation, une session commencée, un élève parti et un élève anonymisé ne comptent pas. Un élève qui recommence ne fait pas dépasser 100 % au taux d'une question. À égalité de meilleur score, la session la plus récente compte. Le taux au premier essai lit la première session, et il est absent sans élève à deux essais. Une question à 49 % est « À reprendre en classe », à 50 % elle ne l'est pas.
- Test de contrôleur : élève de la classe, enseignant d'une autre classe et direction reçoivent 403 sur la page de suivi.
- Budget : `script/perf/measure_screens.rb` sur la page classe et la page de suivi (ADR-0067).
- `grep -rn "Rails.cache" app/infrastructure/queries/assessment` ne renvoie rien.
