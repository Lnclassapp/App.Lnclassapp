# ADR-XXXX : L'exercice d'entraînement d'une notion vit dans sa fiche et le serveur le corrige sans rien écrire
<!-- index
titre: Entraînement de notion dans la fiche, corrigé par le serveur sans trace
statut: Accepté
problematique: L'élève doit s'exercer dans la fiche de révision, avec une correction sur place, sans que l'exercice noté ni sa correction n'y soient exposés et sans laisser de trace.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/je-m-entraine-dans-la-fiche` |
| **Remplace** | — (amende ADR-0116 §4.1 : une notion porte, en plus de son exercice noté, un entraînement facultatif dans sa fiche) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le 2026-10-30, le porteur veut une section « Je m'entraîne » dans chaque notion de la fiche de révision, entre l'exemple corrigé et le piège, avec un exercice que l'élève fait sur place et dont il voit la correction. Ce n'est pas la première fois. `contenu-en-blocs` avait livré un tel bloc, corrigé dans le navigateur à partir des réponses écrites dans la page (`data-answer`) et accompagné d'un « Entraînement illimité ». `refonte-contenus-maths` (#362) l'a retiré, et l'UDR-0141 l'a sorti du cahier.

Le grill du chantier a fixé cinq contraintes :

1. Rien de ce qui se fait dans la fiche ne compte : ni copie, ni note, ni maîtrise, ni pause (grill 1).
2. La fiche ne montre jamais l'exercice noté de « Prépare interros ». Sinon, la première copie notée se ferait les réponses en tête et la pause de l'ADR-0115 ne servirait à rien (grill 2). L'entraînement est donc un exercice à part, propre à la notion.
3. Les types de questions sont communs à la fiche, aux interrogations et aux devoirs. Une même réponse doit recevoir le même verdict partout, d'où une correction faite par le serveur (grill 6 bis).
4. L'entraînement ne s'assigne pas et n'apparaît nulle part hors de la fiche (grill 16).
5. La correction ne s'affiche qu'après un premier « Vérifier » (grill 13).

Aujourd'hui, une notion porte **exactement un** exercice noté (`ImportCourseTree#essential_exercise_count`), et une quinzaine de requêtes listent les lignes de `exercises` : Prépare interros, prochain exercice, exercice du jour, accueil élève, cibles d'assignation, garde d'assignation, accueil de l'équipe, corrigé de l'équipe, détail de leçon…

## 2. Moteurs de décision

1. Une seule règle de correction par type de question (grill 6 bis) : celle qui donne la note.
2. Aucune bonne réponse dans le HTML avant « Vérifier » (CA-3).
3. Aucune écriture en base depuis la fiche (grill 1), donc rien à purger, à protéger ni à suivre.
4. L'entraînement ne doit pouvoir apparaître dans aucune liste d'exercices : une exclusion oubliée le rendrait assignable.
5. Le JavaScript commun ne grossit pas : le plafond de 61 Ko (ADR-0114) n'a que quelques octets de marge.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une ligne de `exercises` de type « entraînement » | Réutilise l'entité `Exercise`, ses questions et ses images | Il faut l'exclure de 15 requêtes, et de toute requête future. Le check SQL `exercise_type` et la règle « un exercice par notion » changent. Un oubli le rend assignable, l'inverse du grill 16 |
| B — Correction dans le navigateur, réponses dans la page | Instantané, hors ligne, c'est la maquette | Écartée au grill 6 bis : deux règles par type, des verdicts qui divergent, et les réponses lisibles dans le source |
| C — **L'entraînement dans la fiche de la notion (`essentials.sheet`, clé `practice`), jugé par le serveur avec les règles de `Entities::Assessment::Question`, sans écriture** | Aucune table, aucune exclusion : il n'est pas un `exercise`. Une seule règle de correction. Rien en base | **Retenue** |
| D — Une table `practice_exercises` / `practice_questions` | Données relationnelles, images possibles | Deux tables et leurs adaptateurs pour un contenu lu d'un bloc et jamais référencé par une copie. Le contenu de la fiche vit déjà en jsonb (ADR-0116) |

## 4. Décision

> **Nous rangeons l'exercice d'entraînement d'une notion dans sa fiche (`essentials.sheet["practice"]`), facultatif, importé avec elle.**

Forme (schéma `lnclass.course-tree.v3.json`, clé `notions[].practice`) :

```json
"practice": {
  "statement": "Les droites (MN) et (BC) sont parallèles…",
  "questions": [
    { "content": "AN (cm) = ___   MN (cm) = ___", "question_type": "numeric", "unit": "cm", "tolerance": 0.01,
      "hint": "Écris l'égalité des trois rapports.", "explanation": "AN = AC × AM / AB = 4,8 cm ; MN = …",
      "answers": [ { "content": "4,8", "correct": true, "blank": 0 }, { "content": "3", "correct": true, "blank": 1 } ] }
  ]
}
```

- 1 à 6 questions, de tous les types connus. Chaque question est validée par `Entities::Assessment::Question.structure_errors_for`, la règle des exercices notés, cases et indice compris (ADR-XXXX-questions-a-plusieurs-cases-et-indice).
- Sans `points`, `image` ni `criteria` : l'entraînement n'est pas noté et la fiche ne porte pas de fichier téléversé. L'import refuse ces clés dans `practice`.
- Une `explanation` obligatoire par question (le corrigé), comme pour un exercice noté.
- La règle « une notion = un exercice noté » de l'ADR-0116 §4.1 ne change pas.

> **Nous jugeons l'entraînement sur le serveur, sans rien écrire : `UseCases::Catalog::CheckPractice`.**

- Le use case reçoit l'acteur, le slug de la leçon, le slug de la notion, l'empreinte de version vue par l'élève et les réponses par question et par case. Il applique `ReadPublishedPolicy` et le niveau de l'élève, comme la page de la leçon.
- Il reconstruit les questions en entités `Entities::Assessment::Question` (sans `id` en base : l'identifiant est la position) et rend, pour chaque case, `:correct`, `:wrong` ou `:blank`, puis le corrigé (bonne réponse de chaque case et explication).
- **Empreinte** : `NotionPractice#digest`, les 16 premiers caractères hexadécimaux du SHA-256 du JSON canonique de `practice`. Elle est posée dans le formulaire. Si elle diffère de celle en base, le use case répond `:conflict` (409, CA-7) et ne juge rien.
- Aucun port d'écriture n'est injecté dans le use case : l'absence d'écriture tient à la construction, pas à une consigne.
- Frein : `rate_limit to: 30, within: 1.minute, by: -> { Current.user.id }` sur le contrôleur (CA-8).

> **Nous ne mettons dans la page de la fiche que l'énoncé, les cases et les propositions, jamais `correct`, la valeur attendue ni l'explication.** L'indice, qui n'est pas une réponse, est dans la page (CA-16).

`RevisionSheetQuery` construit `NotionPractice#without_correction` : les propositions d'une liste ou d'un QCM gardent leur texte et perdent `correct`, et un chiffré, un trou ou un rédigé perd ses réponses.

## 5. Conséquences

### 🟢 Positives

- Aucune table, aucune exclusion à maintenir : un entraînement ne peut pas être assigné, listé ni suivi, puisqu'il n'est pas un exercice.
- Une seule règle de correction : la fiche et la copie notée jugent « 4,8 cm » de la même façon (CA-5).
- Le JavaScript commun ne bouge pas : un formulaire Turbo Frame et un `<details>` suffisent.

### 🔴 Coûts consentis

- Chaque « Vérifier » fait un aller-retour au serveur : environ une demi-seconde sur réseau mobile, et aucune vérification hors ligne.
- Une route qui juge sans écrire reste une route : elle est ouverte aux comptes connectés, freinée à 30 envois par minute, et chaque envoi relit la notion.
- Un compte connecté peut toujours obtenir le corrigé en envoyant des cases vides. C'est voulu (grill 13), puisque rien n'est noté.
- Pas d'image téléversée dans une question d'entraînement : une figure paramétrée de la notion reste possible dans l'énoncé de la fiche, au-dessus.
- `essentials.sheet` grossit, de quelques Ko par notion, et il est lu à chaque affichage de la page de la leçon.
- `Entities::Catalog` dépend de `Entities::Assessment::Question` pour juger. La dépendance existe déjà pour valider l'import (`ContentNode.structure_errors`) et reste de domaine à domaine.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/notion_practice.rb
module Entities
  module Catalog
    # questions : [Entities::Assessment::Question], id = position (0..n-1), jamais en base.
    NotionPractice = Data.define(:statement, :questions, :digest) do
      QUESTIONS = (1..6)
      FORBIDDEN_KEYS = %w[points image criteria].freeze

      def self.from_raw(raw)
        return nil unless raw.is_a?(Hash)

        new(statement: raw["statement"].to_s.strip,
            questions: Array(raw["questions"]).each_with_index.map { |question, index| question_from(question, index) },
            digest: Digest::SHA256.hexdigest(JSON.generate(raw.sort.to_h))[0, 16])
      end

      def without_correction = with(questions: questions.map(&:without_correction))
    end
  end
end
```

```ruby
# app/domain/use_cases/catalog/check_practice.rb — juge, n'écrit rien (aucun port d'écriture injecté)
def call(actor:, course_slug:, notion_slug:, digest:, responses:)
  notion = @notions.practice_for(course_slug:, notion_slug:, statuses: statuses_for(actor))
  return failure(:not_found) if notion.nil? || refused?(actor, notion)
  return failure(:conflict, base: [ :changed ]) unless notion.practice.digest == digest

  success(notion.practice.questions.map { |question| verdict(question, responses[question.id.to_s]) })
end
```

```ruby
# app/controllers/catalog/practice_checks_controller.rb
rate_limit to: 30, within: 1.minute, by: -> { Current.user.id }, with: -> { render_rate_limited(:show) }
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/catalog/check_practice_test.rb` : le use case est construit sans port d'écriture, et le test compte les lignes de toutes les tables avant et après (CA-4).
- `test/controllers/catalog/practice_checks_controller_test.rb` : 404 (brouillon, autre niveau), 409 (empreinte), 429 (31e envoi), redirection vers la connexion d'un visiteur.
- `test/views/catalog/revision_sheets/practice_leak_test.rb` : le HTML de la fiche ne contient ni l'explication, ni la valeur attendue, ni `correct` (CA-3).
- `test/domain/entities/assessment/practice_parity_test.rb` : une même table de réponses jugée dans la fiche et dans une copie notée donne les mêmes verdicts (CA-5).
- Un `grep` de `practice` dans `app/infrastructure/queries/` ne doit trouver que `revision_sheet_query.rb` et l'adaptateur de lecture de la notion.
