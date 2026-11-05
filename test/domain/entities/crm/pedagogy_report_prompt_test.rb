require "test_helper"

# CA-29, CA-30 (ADR-XXXX modèles de langage, « Données envoyées ») : le modèle ne reçoit que des agrégats ; la synthèse est du texte nettoyé.
module Entities
  module Crm
    class PedagogyReportPromptTest < ActiveSupport::TestCase
      def build(students: 12, assignments: 4, **overrides)
        PedagogyReportPrompt.new(school_id: 7, active_students_count: students, assignments_count: assignments, submission_rate: 62,
                                 average_percent: 71, subjects: [ { name: "Mathématiques", average_percent: 64, sessions_count: 30 } ],
                                 gaps: [ { name: "Les fractions", course_name: "Maths 6e", students_count: 9 } ], **overrides)
      end

      test "activity means at least one active student or one assignment" do
        assert build.activity?
        assert build(students: 0).activity?
        assert build(assignments: 0).activity?
        assert_not build(students: 0, assignments: 0).activity?
      end

      test "the messages carry the figures and nothing that names a person or the school" do
        sent = build.messages.map { it[:content] }.join("\n")

        assert_includes sent, "Élèves actifs : 12"
        assert_includes sent, "Taux de rendu des devoirs : 62 %"
        assert_includes sent, "Mathématiques : 64 %"
        assert_includes sent, "Les fractions (Maths 6e) : 9 élèves"
        assert_equal %w[system user], build.messages.map { it[:role].to_s }
      end

      test "an unknown rate is said so, not shown as zero" do
        assert_includes build(submission_rate: nil, average_percent: nil).messages.last[:content], "Taux de rendu des devoirs : non disponible"
      end

      test "the fingerprint changes with a figure and is stable otherwise" do
        assert_equal build.fingerprint, build.fingerprint
        assert_match(/\A\h{64}\z/, build.fingerprint)
        assert_not_equal build.fingerprint, build(students: 13).fingerprint
        assert_not_equal build.fingerprint, build(gaps: []).fingerprint
      end

      test "summarize strips tags and bullets and keeps six lines at most" do
        text = "<b>Un</b>\n- Deux\n\n3) Trois\n* Quatre\nCinq\nSix\nSept"

        assert_equal %w[Un Deux Trois Quatre Cinq Six], PedagogyReportPrompt.summarize(text).split("\n")
      end

      test "summarize caps each line and returns nil for an empty answer" do
        assert_equal 400, PedagogyReportPrompt.summarize("a" * 900).length
        assert_nil PedagogyReportPrompt.summarize("  \n <br> ")
        assert_nil PedagogyReportPrompt.summarize(nil)
      end
    end
  end
end
