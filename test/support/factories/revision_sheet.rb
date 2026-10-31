# Leçon v3 valide (ADR-0116 fiche de révision, refonte-contenus-maths) : le document que tous les lots importent, vérifient et dérivent.
module Factories
  module RevisionSheet
    ActiveSupport::TestCase.include(self)

    FIGURE_DESCRIPTION = "Un triangle ABC rectangle en A, avec le point D mobile sur le côté AB : la droite parallèle à BC " \
                         "passant par D coupe le côté AC en E. On lit les longueurs AD, AB, AE et AC, et leurs rapports.".freeze

    # Une question à choix unique, correction rédigée comprise.
    def revision_question(number = 1)
      { "content" => "Question #{number} : combien font $2 + 2$ ?", "question_type" => "single_choice",
        "explanation" => "On additionne les deux termes : $2 + 2 = 4$, la bonne réponse est donc 4.",
        "answers" => [ { "content" => "4", "correct" => true }, { "content" => "5", "correct" => false } ] }
    end

    def revision_exercise(title, figure: nil)
      { "title" => title, "statement" => "Résous les questions suivantes.", "exercise_type" => "fixation", "figure" => figure,
        "questions" => Array.new(5) { revision_question(it + 1) } }
    end

    def revision_notion(name, figure: nil)
      { "name" => name, "remember" => "Pour $a \\geq 0$ et $b \\geq 0$ : $\\sqrt{a \\times b} = \\sqrt{a} \\times \\sqrt{b}$.",
        "method" => [ "Décomposer le nombre en un carré parfait et un entier.", "Séparer la racine en deux racines.", "Calculer la racine du carré parfait." ],
        "example" => { "statement" => "Simplifier $\\sqrt{72}$.",
                       "steps" => [ "$72 = 36 \\times 2$ et 36 est un carré parfait.", "$\\sqrt{72} = \\sqrt{36} \\times \\sqrt{2}$.", "$\\sqrt{72} = 6\\sqrt{2}$." ] },
        "pitfall" => "$\\sqrt{a + b} \\neq \\sqrt{a} + \\sqrt{b}$ : la racine ne se distribue pas sur une somme.",
        "figure" => figure, "exercise" => revision_exercise("Exercice sur #{name}", figure:) }
    end

    def revision_figure(key: "triangle-thales")
      { "key" => key, "kind" => "geometry", "description" => FIGURE_DESCRIPTION,
        "params" => { "points" => [ { "id" => "A", "x" => 0, "y" => 0 }, { "id" => "B", "x" => 8, "y" => 0, "label" => "B" },
                                    { "id" => "C", "x" => 0, "y" => 6 }, { "id" => "D", "x" => 4, "y" => 0, "draggable" => true } ],
                      "segments" => [ [ "A", "B" ], [ "B", "C" ], [ "C", "A" ] ] },
        "controls" => [] }
    end

    # Un sujet de devoir (ADR sujets-de-devoir §4) : titre, notions mobilisées et `exercises` exercices complets, sans notion.
    def revision_subject(title, exercises: 4, notions: "Théorème de Thalès · proportionnalité")
      { "title" => title, "notions" => notions, "exercises" => Array.new(exercises) { revision_exercise("#{title} · exercice #{it + 1}") } }
    end

    # La leçon Thalès : indice sur l'exercice de chaque notion et 3 sujets de 4 exercices (CA-9). Retourne l'enveloppe complète.
    def revision_thales_document(**overrides)
      notions = [ "Théorème de Thalès", "Réciproque de Thalès" ].map do |name|
        revision_notion(name).tap { it["exercise"]["hint"] = "Commence par repérer les deux droites parallèles." }
      end
      revision_sheet_document(name: "Thalès", notions:, subjects: Array.new(3) { revision_subject("Sujet #{it + 1} · Thalès") }, **overrides)
    end

    # Une leçon : 2 notions, 1 figure, 1 exercice par notion, 4 problèmes, 5 questions chacun. Retourne l'enveloppe complète ;
    # `overrides` remplace des clés de la leçon.
    def revision_sheet_document(**overrides)
      course = { "name" => "Racines carrées", "subtitle" => "Calculer et simplifier", "level_name" => "3ème",
                 "material_name" => "Mathématiques", "theme" => "blue", "figures" => [ revision_figure ],
                 "notions" => [ revision_notion("Simplifier une racine carrée", figure: "triangle-thales"), revision_notion("Calculer avec des racines") ],
                 "exercises" => Array.new(4) { revision_exercise("Problème #{it + 1}") } }.merge(overrides.stringify_keys)
      { "format" => "lnclass.course-tree", "version" => 3, "courses" => [ course ] }
    end
  end
end
