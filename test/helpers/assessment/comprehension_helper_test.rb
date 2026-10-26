require "test_helper"

# UDR-0072 §3.2, §3.3 et §3.7 : couleurs, icônes et libellés de la compréhension, et les deux partiels partagés.
module Assessment
  class ComprehensionHelperTest < ActionView::TestCase
    helper ComponentsHelper
    helper Assessment::BadgesHelper

    CATEGORIES = [ :struggling, :fragile, :acquired, nil ].freeze
    TRENDS = [ :progress, :decline, :stable, :stagnant, nil ].freeze

    test "each category has its dot, its soft background and its label; nil is not readable yet" do
      assert_equal %w[bg-struggling bg-fragile bg-success bg-line], CATEGORIES.map { comprehension_dot_class(it) }
      assert_equal %w[bg-struggling-soft bg-fragile-soft bg-success-soft bg-mist], CATEGORIES.map { comprehension_soft_class(it) }
      assert_equal [ "En difficulté", "Fragile", "Acquis", "Pas encore lisible" ], CATEGORIES.map { comprehension_label(it) }
    end

    test "an unknown category is an error, not a silent grey" do
      assert_raises(KeyError) { comprehension_dot_class(:unknown) }
      assert_raises(KeyError) { comprehension_soft_class(:unknown) }
    end

    test "each sign has its icon and its label; a single attempt has a label and no icon" do
      assert_equal [ "arrow-trending-up", "arrow-trending-down", "arrow-long-right", "arrow-long-right", nil ],
                   TRENDS.map { trend_icon(it) }
      assert_equal [ "En progrès", "En baisse", "Stable", "Stagne", "1 session" ], TRENDS.map { trend_label(it) }
      assert_raises(KeyError) { trend_icon(:unknown) }
    end

    test "a badge tier keeps its tone, and fades to the line colour at zero" do
      assert_equal %w[text-warning text-mute text-gold text-info], %i[bronze silver gold diamond].map { comprehension_badge_class(it, 1) }
      assert_equal "text-line", comprehension_badge_class(:bronze, 0)
    end

    test "the labels of the section, of the summary and of the pending students, consumed by the lots A and B" do
      scope = "assessment.comprehension"

      assert_equal "Compréhension", t("#{scope}.section.title")
      assert_equal "Question 1 : 50 % de réussite", t("#{scope}.section.question_label", number: 1, rate: "50 %")
      assert_equal "8 en progrès · 7 sans évolution · 1 en baisse",
                   t("#{scope}.trends_summary.sentence_html", **%i[progress flat decline].zip([ 8, 7, 1 ]).to_h { |key, count| [ key, t("#{scope}.trends_summary.#{key}", count:) ] })
      assert_equal [ "Pas encore fait · 1", "Pas encore faits · 7" ], [ 1, 7 ].map { t("#{scope}.pending.title", count: it) }
      %w[badges_label questions_title students_title question_number no_attempt first_rate first_rate_label to_revisit
         to_revisit_label].each { assert I18n.exists?("#{scope}.section.#{it}", :fr), it }
      %w[no_trend empty.title empty.description empty_category].each { assert I18n.exists?("#{scope}.#{it}", :fr), it }
    end

    test "the small circle: a dot of the category, then « label · done/present »" do
      render partial: "assessment/comprehension/circle", locals: { category: :fragile, done: 6, present: 25 }

      assert_dom "span.inline-flex.items-center.gap-2" do
        assert_dom "span.rounded-full.size-4.bg-fragile[aria-hidden=true]", count: 1
        assert_dom "span.text-sm.text-ink", text: "Fragile · 6/25" do
          assert_dom "span.tabular-nums", text: "6/25"
        end
      end
    end

    # UDR enseignant §3.8 : le grand cercle du rapport disparaît, ne reste que le petit format de la page classe.
    test "the large circle is gone: the circle partial no longer accepts a size" do
      assert_raises(ActionView::Template::Error) do
        render partial: "assessment/comprehension/circle", locals: { category: nil, done: 4, present: 25, size: :lg }
      end
    end

    test "the badge boxes: five links in the order, a count and a label each, read « 3 élèves Or », the active one links back to all" do
      counts = { none: 4, bronze: 6, silver: 1, gold: 3, diamond: 0 }
      classroom = Struct.new(:public_id).new("cls-1")
      render partial: "assessment/comprehension/badge_boxes",
             locals: { counts:, selected: :gold, classroom:, assignment_public_id: "asg-1" }

      assert_dom "nav[aria-label='Élèves par badge'] a", count: 5
      assert_equal [ "Pas encore", "Bronze", "Argent", "Or", "Diamant" ], css_select("nav a span.text-xs").map { it.text.strip }
      assert_equal %w[4 6 1 3 0], css_select("nav a span.font-display").map { it.text.strip }
      assert_dom "nav a[href='/classrooms/cls-1/assignments/asg-1?badge=bronze']"
      assert_dom "nav a[aria-current=true][href='/classrooms/cls-1/assignments/asg-1']", count: 1
      assert_dom "nav a .sr-only", text: "3 élèves Or"
      assert_dom "nav a .sr-only", text: "1 élève Argent"
      assert_dom "nav a .sr-only", text: "0 élève Diamant"
    end

    test "the small circle never breaks nor truncates: the label makes the colour readable" do
      render partial: "assessment/comprehension/circle", locals: { category: nil, done: 4, present: 25 }

      assert_dom "span.inline-flex.shrink-0:not(.flex-wrap)" do
        assert_dom "span.whitespace-nowrap.text-sm.text-ink", text: "Pas encore lisible · 4/25"
      end
      assert_dom ".truncate", count: 0
    end

    # rapports-de-classe, Lot C (AS-23 ; ADR-0097 §4.6, UDR-0109 §3.2) : la vue ne choisit pas, elle traduit.
    def detail(done:, present:, dominant: nil, decline: 0)
      Queries::Assessment::ComprehensionDetailQuery::Detail.new(
        done:, present:, category: dominant, readable: Entities::Assessment::Comprehension.readable?(done),
        badge_counts: { none: 4, bronze: 0, silver: 0, gold: 0, diamond: 0 }, trend_counts: { progress: 0, flat: 0, decline: }, selected: nil, questions: [], students: []
      )
    end

    def next_step_sentence(comprehension)
      step, options = comprehension_next_step(comprehension)
      t("assessment.comprehension.next_step.#{step}", **options)
    end

    test "the next step speaks in badges, never in the old categories" do
      %w[remind look_at_each revisit_notion revisit_questions watch_decline move_on].each do |step|
        texts = I18n.t("assessment.comprehension.next_step.#{step}", locale: :fr, count: 2, min: 5)
        Array(texts.is_a?(Hash) ? texts.values : texts).each { assert_no_match(/difficulté|Fragile|Acquis/i, it, step) }
      end
    end

    test "the warning « pas encore fiable » is gone: the next step says the bound (UDR-0109 §3.3)" do
      assert_not I18n.exists?("assessment.comprehension.unreliable", :fr)
    end

    test "the next step: nothing when nobody did it; the counts and the bound interpolated" do
      assert_nil comprehension_next_step(detail(done: 0, present: 25))
      assert_equal [ :remind, { count: 22, min: 5 } ], comprehension_next_step(detail(done: 3, present: 25))
      assert_equal "Relancez les 22 élèves qui ne l'ont pas encore fait : les badges de la classe se liront à partir de 5 élèves.",
                   next_step_sentence(detail(done: 3, present: 25))
      assert_equal "Relancez l'élève qui ne l'a pas encore fait : les badges de la classe se liront à partir de 5 élèves.",
                   next_step_sentence(detail(done: 4, present: 5))
      assert_equal [ :look_at_each, {} ], comprehension_next_step(detail(done: 4, present: 4))
      assert_equal [ :revisit_notion, { count: 4 } ], comprehension_next_step(detail(done: 6, present: 6, dominant: :struggling))
      assert_equal [ :revisit_questions, {} ], comprehension_next_step(detail(done: 6, present: 9, dominant: :fragile))
      assert_equal "Tous les élèves l'ont fait. La classe est trop petite pour comparer les badges : regardez chaque élève.",
                   next_step_sentence(detail(done: 4, present: 4))
      assert_equal "4 élèves n'ont pas encore de badge. Reprenez la notion en classe avant d'avancer, puis relancez-les.",
                   next_step_sentence(detail(done: 6, present: 6, dominant: :struggling))
      assert_equal "La plupart des élèves en sont au Bronze : reprenez en classe les questions marquées, puis avancez.",
                   next_step_sentence(detail(done: 6, present: 9, dominant: :fragile))
      assert_equal "La classe a atteint l'Argent ou mieux. 2 élèves sont en baisse : voyez-les dans la liste.",
                   next_step_sentence(detail(done: 9, present: 9, dominant: :acquired, decline: 2))
      assert_equal "La classe a atteint l'Argent ou mieux. Un élève est en baisse : voyez-le dans la liste.",
                   next_step_sentence(detail(done: 9, present: 9, dominant: :acquired, decline: 1))
      assert_equal "La classe a atteint l'Argent ou mieux : vous pouvez avancer.", next_step_sentence(detail(done: 9, present: 9, dominant: :acquired))
    end
  end
end
