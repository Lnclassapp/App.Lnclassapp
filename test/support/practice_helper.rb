# Une notion avec son entraînement, comme l'écrit la fiche (clé practice), pour juger sans base de données.
module PracticeHelper
  ActiveSupport::TestCase.include(self)

  EXPLANATION = "On applique la méthode de la notion pas à pas, puis on vérifie le résultat obtenu.".freeze

  # Lot A (jugement par case) pas encore fusionné : le test à plusieurs cases attend `blank_results` sur les kinds chiffré, trous et liste.
  def skip_until_lot_a_blank_results
    return if Entities::Assessment::Question.kind_for("numeric").respond_to?(:blank_results)

    skip "En attente du Lot A : Question#blank_results (jugement par case) n'est pas encore porté par les types de question"
  end

  def numeric_question(content: "AN (cm) = ___", value: "4,8", unit: "cm")
    { "content" => content, "question_type" => "numeric", "unit" => unit, "tolerance" => 0.01, "explanation" => EXPLANATION,
      "answers" => [ { "content" => value, "correct" => true, "blank" => 0 } ] }
  end

  def two_blank_numeric_question
    { "content" => "AN (cm) = ___   MN (cm) = ___", "question_type" => "numeric", "unit" => "cm", "tolerance" => 0.01,
      "explanation" => EXPLANATION, "hint" => "Écris l'égalité des trois rapports.",
      "answers" => [ { "content" => "4,8", "correct" => true, "blank" => 0 }, { "content" => "3", "correct" => true, "blank" => 1 } ] }
  end

  def choice_question
    { "content" => "Quelle est la racine carrée de 49 ?", "question_type" => "single_choice", "explanation" => EXPLANATION,
      "answers" => [ { "content" => "7", "correct" => true }, { "content" => "8", "correct" => false }, { "content" => "6", "correct" => false } ] }
  end

  def ordering_question
    { "content" => "Remets les étapes dans l'ordre.", "question_type" => "ordering", "explanation" => EXPLANATION,
      "answers" => [ { "content" => "Décomposer" }, { "content" => "Séparer" }, { "content" => "Calculer" } ] }
  end

  def matching_question
    { "content" => "Relie chaque racine à sa valeur.", "question_type" => "matching", "explanation" => EXPLANATION,
      "answers" => [ { "content" => "racine de 9", "match" => "3" }, { "content" => "racine de 16", "match" => "4" },
                     { "content" => "racine de 25", "match" => "5" } ] }
  end

  def fill_blank_question
    { "content" => "Le côté opposé à l'angle droit s'appelle l'___.", "question_type" => "fill_blank", "explanation" => EXPLANATION,
      "answers" => [ { "content" => "hypoténuse" } ] }
  end

  def written_question
    { "content" => "Explique pourquoi la racine ne se distribue pas.", "question_type" => "written", "explanation" => EXPLANATION, "answers" => [] }
  end

  # Une leçon d'un niveau, une notion publiée avec son entraînement ; retourne la notion (Orm::Essential).
  def create_practice_notion(course:, questions: [ numeric_question ], name: "Simplifier une racine carrée", **attributes)
    notion = revision_notion(name)
    sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"],
              "practice" => raw_practice(*questions) }
    create_essential(course:, name: notion["name"], sheet:, **attributes)
  end

  def check_practice_with(notions)
    UseCases::Catalog::CheckPractice.new(notions:, policy: Policies::Catalog::ReadPublishedPolicy.new, level_policy: Policies::Catalog::ReadOwnLevelPolicy.new)
  end

  def raw_practice(*questions) = { "statement" => "Dans le triangle ABC, la droite (MN) est parallèle à (BC).", "questions" => questions }

  def practice_of(*questions) = Entities::Catalog::NotionPractice.from_raw(raw_practice(*questions))

  # L'indice d'affichage de la proposition d'identifiant `id` dans la liste mélangée de l'entraînement (ce que la fiche poste).
  def display_index(practice, question, id) = UseCases::Catalog::CheckPractice.display_ids(practice.digest, question).index(id)
end
