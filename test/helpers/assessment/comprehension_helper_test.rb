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
      %w[categories_label questions_title students_title question_number no_attempt first_rate first_rate_label to_revisit
         to_revisit_label].each { assert I18n.exists?("#{scope}.section.#{it}", :fr), it }
      %w[no_trend unreliable empty.title empty.description empty_category].each { assert I18n.exists?("#{scope}.#{it}", :fr), it }
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

    test "the large circle of an unreadable class: grey dot, label in display font, the ratio under it" do
      render partial: "assessment/comprehension/circle", locals: { category: nil, done: 4, present: 25, size: :lg }

      assert_dom "span.rounded-full.size-14.bg-line[aria-hidden=true]", count: 1
      assert_dom "span.font-display.text-xl.font-extrabold.text-ink", text: "Pas encore lisible"
      assert_dom "span.text-sm.text-mute.tabular-nums", text: "4/25"
      assert_dom "span.size-4", count: 0
    end

    test "the badge counts: always the four tiers in order, a zero faded, each tier told to screen readers" do
      render partial: "assessment/comprehension/badge_counts", locals: { counts: { bronze: 0, silver: 1, gold: 2, diamond: 3 } }

      assert_dom "ul.flex.items-center.gap-2[aria-label=?]", "Badges de la classe" do
        assert_dom "li", count: 4
        assert_equal [ "0 Bronze", "1 Argent", "2 Or", "3 Diamant" ], css_select("li span.sr-only").map(&:text)
        assert_dom "li:nth-child(1) svg.text-line[aria-hidden=true]"
        assert_dom "li:nth-child(1) span.text-sm.tabular-nums.text-line[aria-hidden=true]", text: "0"
        assert_dom "li:nth-child(2) svg.text-mute"
        assert_dom "li:nth-child(3) svg.text-gold"
        assert_dom "li:nth-child(4) svg.text-info"
        assert_dom "li:nth-child(4) span.text-sm.tabular-nums.text-ink", text: "3"
      end
    end

    test "the trophy is defined once per page, then reused: a <symbol>, and one <use> per tier" do
      counts = { bronze: 1, silver: 0, gold: 0, diamond: 2 }
      2.times { render partial: "assessment/comprehension/badge_counts", locals: { counts: } }

      assert_dom "symbol#comprehension-trophy[viewBox='0 0 20 20'] path", count: 1
      assert_dom "svg use[href='#comprehension-trophy']", count: 8
      assert_dom "svg.absolute.size-0[aria-hidden=true] symbol", count: 1
    end

    test "the small circle never breaks nor truncates: the label makes the colour readable" do
      render partial: "assessment/comprehension/circle", locals: { category: nil, done: 4, present: 25 }

      assert_dom "span.inline-flex.shrink-0:not(.flex-wrap)" do
        assert_dom "span.whitespace-nowrap.text-sm.text-ink", text: "Pas encore lisible · 4/25"
      end
      assert_dom ".truncate", count: 0
    end
  end
end
