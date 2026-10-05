require "test_helper"

module Entities
  module Communication
    # ADR-0078 §4 et §6 : l'annonce, ses listes fermées, ses bornes, et ce qu'elle dit d'elle-même (figée, par classes,
    # officielle, retirable par qui).
    class MessageTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor

      def announcement(**changes)
        Message.new(id: 7, public_id: "abcdefghijkmno", author_id: 1, title: "Nouvelles fiches", body: "Elles sont en ligne.",
                    audience: "classrooms", school_id: 3, classroom_ids: [ 11, 12 ], illustration: "sheets",
                    status: "published", published_at: Time.utc(2026, 10, 1), ends_at: Time.utc(2026, 10, 31),
                    edited_at: nil, withdrawn_at: nil, withdrawn_by_id: nil).with(**changes)
      end

      test "porte chaque champ du contrat gelé, dans l'ordre de l'ADR ; le thème et l'illustration de l'équipe à la fin" do
        assert_equal %i[id public_id author_id title body audience school_id classroom_ids illustration status published_at
                        ends_at edited_at withdrawn_at withdrawn_by_id theme illustration_id], Message.members
        assert_equal [ 11, 12 ], announcement.classroom_ids
      end

      test "une annonce à créer n'a ni id, ni public_id, ni classes, ni dates par défaut ; elle est « Ciel »" do
        draft = Message.new(author_id: 1, title: "Rentrée", body: "Lundi.", audience: "all", illustration: "info", status: "draft")

        assert_equal [ nil, nil, nil, [] ], [ draft.id, draft.public_id, draft.school_id, draft.classroom_ids ]
        assert_equal [ nil ] * 5, [ draft.published_at, draft.ends_at, draft.edited_at, draft.withdrawn_at, draft.withdrawn_by_id ]
        assert_equal [ "ciel", nil ], [ draft.theme, draft.illustration_id ]
      end

      # ADR-0081 §4.3 : une illustration de l'équipe se désigne par son id ; la clé de base est alors nil.
      test "une annonce porte une clé de base, ou l'illustration de l'équipe qu'elle désigne" do
        drawn = Message.new(author_id: 1, title: "Sortie", body: "Le bus part à 8 h.", audience: "all", illustration: nil,
                            illustration_id: 5, theme: "mangue", status: "draft")

        assert_equal [ nil, 5, "mangue" ], [ drawn.illustration, drawn.illustration_id, drawn.theme ]
      end

      test "AV-07 — dix thèmes, dans l'ordre de l'ADR-0081, « Ciel » par défaut" do
        assert_equal %w[ciel lagune menthe citron mangue corail hibiscus lavande indigo nuit], Message::THEMES
        assert Message::THEMES.frozen?
        assert_equal "ciel", Message::DEFAULT_THEME
        assert_equal Message::THEMES.first, Message::DEFAULT_THEME
      end

      test "AV-02 et AV-03 — une annonce dure 30 jours, et un auteur en a 3 en ligne au plus (ADR-0081 §4.1)" do
        assert_equal [ 30.days, 3 ], [ Message::DURATION, Message::LIVE_CAP ]
      end

      test "les listes fermées, dans l'ordre de l'UDR-0071" do
        assert_equal %w[all students teachers school_admins classrooms], Message::AUDIENCES
        assert_equal %w[draft scheduled published archived withdrawn], Message::STATUSES
        assert_equal %w[info calendar homework sheets exam meeting celebration holidays], Message::ILLUSTRATIONS
        assert [ Message::AUDIENCES, Message::STATUSES, Message::ILLUSTRATIONS ].all?(&:frozen?)
      end

      test "AN-20 — le titre tient en 60 caractères, le texte en 140" do
        assert_equal [ 60, 140 ], [ Message::TITLE_MAX, Message::BODY_MAX ]
      end

      test "AN-08 — une annonce dure 30 jours par défaut, 90 au plus" do
        assert_equal [ 30.days, 90.days ], [ Message::DEFAULT_DURATION, Message::MAX_DURATION ]
      end

      test "une annonce archivée ou retirée est figée ; brouillon, programmée et publiée ne le sont pas" do
        assert announcement(status: "archived").frozen?
        assert announcement(status: "withdrawn").frozen?
        %w[draft scheduled published].each { assert_not announcement(status: it).frozen?, it }
      end

      test "seule l'annonce d'enseignant cible des classes" do
        assert announcement.by_classrooms?
        assert_not announcement(audience: "students", classroom_ids: []).by_classrooms?
      end

      test "officielle quand son auteur est une direction, et seulement alors" do
        assert announcement.official?(author_role: :school_admin)
        %i[team teacher student].each { assert_not announcement.official?(author_role: it), it }
      end

      test "l'équipe retire toute annonce d'un autre auteur, jamais la sienne" do
        team = Actor.new(user_id: 9, role: :team, team_role: "admin")

        assert announcement.moderatable_by?(team, author_role: :teacher)
        assert announcement(audience: "students").moderatable_by?(team, author_role: :school_admin)
        assert_not announcement(author_id: 9).moderatable_by?(team, author_role: :team)
      end

      test "la direction retire l'annonce d'un enseignant de son établissement, rien d'autre" do
        admin = Actor.new(user_id: 4, role: :school_admin, school_id: 3)

        assert announcement.moderatable_by?(admin, author_role: :teacher)
        assert_not announcement(school_id: 5).moderatable_by?(admin, author_role: :teacher)
        assert_not announcement(audience: "students").moderatable_by?(admin, author_role: :school_admin)
        assert_not announcement(audience: "all", school_id: nil).moderatable_by?(admin, author_role: :team)
      end

      test "un enseignant ou un élève ne retire rien" do
        assert_not announcement.moderatable_by?(Actor.new(user_id: 2, role: :teacher, school_id: 3), author_role: :teacher)
        assert_not announcement.moderatable_by?(Actor.new(user_id: 3, role: :student), author_role: :teacher)
      end
    end
  end
end
