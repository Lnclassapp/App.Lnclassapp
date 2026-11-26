require "test_helper"

# ADR-0146 §3.2 ; PRD §3.1 « annonce de l'équipe » : publiée par un compte de l'équipe, depuis moins de
# 48 h, ni retirée ni terminée, lue par l'élève (ADR-0078 §4.3) et non masquée ; élèves abonnés, non coupés, non anonymisés.
module Queries
  module Communication
    class PushCandidates
      class AnnouncementTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        setup do
          @school = create_school
          @classroom = create_classroom(school: @school)
          @team = create_team_member(second_factor: false)
          @student = student_in(@classroom)
        end

        def student_in(classroom, subscribed: true)
          create_student(classroom:).tap { |student| create_push_subscription(user: student) if subscribed }
        end

        def announce(author: @team, push_requested: true, **) = create_message(author:, published_at: NOW - 1.hour, push_requested:, **)
        def candidates = Announcement.new.for(now: NOW)

        test "annonce nationale de l'équipe pour les élèves : un candidat avec sa clé, /announcements, aucune variable, valable 48 h" do
          message = announce(title: "Maintenance ce soir")

          found = candidates.sole

          assert_equal @student.id, found.user_id
          assert_equal "announcement", found.motive
          assert_equal "announcement:#{message.public_id}", found.object_key
          assert_equal "/announcements", found.url
          assert_equal({}, found.variables)
          assert_equal NOW - 1.hour + 48.hours, found.valid_until
          assert_not_includes found.to_h.values.map(&:to_s).join, "Maintenance"
        end

        test "une annonce sans « Prévenir les élèves » : aucun candidat" do
          announce(push_requested: false)

          assert_empty candidates
        end

        test "user_ids limits the candidates to the given students" do
          announce
          other = student_in(@classroom)

          assert_equal [ @student.id, other.id ].sort, candidates.map(&:user_id).sort
          assert_equal [ other.id ], Announcement.new.for(now: NOW, user_ids: [ other.id ]).map(&:user_id)
        end

        test "une annonce d'enseignant ou de direction : aucun candidat" do
          announce(author: create_teacher, audience: "students", school: nil)
          announce(author: create_school_admin(school: @school), audience: "students", school: @school)

          assert_empty candidates
        end

        test "plus de 48 h, retirée, brouillon, terminée ou pas encore publiée : rien" do
          create_message(author: @team, published_at: NOW - 49.hours)
          announce(status: "withdrawn")
          announce(status: "draft")
          announce(ends_at: NOW - 1.minute)
          create_message(author: @team, published_at: NOW + 1.hour)

          assert_empty candidates
        end

        test "l'annonce masquée par l'élève : rien pour lui, le candidat reste pour un autre" do
          message = announce
          other = student_in(@classroom)
          dismiss_message(message:, user: @student)

          assert_equal [ other.id ], candidates.map(&:user_id)
        end

        test "un élève non abonné, qui a coupé ou anonymisé : rien" do
          @student.update_columns(anonymized_at: NOW)
          student_in(@classroom, subscribed: false)
          off = student_in(@classroom)
          create_push_preference(user: off, turned_off_at: NOW - 1.day)
          announce

          assert_empty candidates
        end

        test "sans annonce ou sans élève abonné : vide" do
          assert_empty candidates

          Orm::Communication::PushSubscription.delete_all
          announce

          assert_empty candidates
        end

        test "parité avec la règle de lecture de l'ADR-0078 : audience, école, classes, élève sans classe" do
          other_school = create_school
          other_classroom = create_classroom(school: other_school)
          second = create_classroom(school: @school)
          left = student_in(@classroom)
          Orm::ClassroomStudent.find_by!(student: left).update!(left_at: NOW - 1.day)
          secondary = student_in(second)
          Orm::ClassroomStudent.find_by!(student: secondary).update!(primary: false)
          outsiders = [ student_in(other_classroom), student_in(second), left, secondary, create_student.tap { create_push_subscription(user: it) } ]
          announce(title: "tous", audience: "all")
          announce(title: "élèves", audience: "students")
          announce(title: "école", audience: "students", school: @school)
          announce(title: "autre école", audience: "students", school: other_school)
          announce(title: "profs", audience: "teachers")
          announce(title: "classe", audience: "classrooms", classrooms: [ @classroom ])
          announce(title: "classes", audience: "classrooms", classrooms: [ second, other_classroom ])
          rule = Queries::Communication::ReadableMessages.new

          expected = ([ @student ] + outsiders).flat_map do |student|
            reader = rule.reader_for(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: student.id))
            rule.scope(reader:, now: NOW).where(author: @team).pluck(:public_id).map { [ student.id, "announcement:#{it}" ] }
          end

          assert_equal expected.sort, candidates.map { [ it.user_id, it.object_key ] }.sort
          assert_operator expected.size, :>, 8
        end

        def query_count
          count = 0
          counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
          count
        end

        test "un nombre fixe de lectures quel que soit le nombre d'élèves, de classes et d'annonces" do
          announce(audience: "classrooms", classrooms: [ @classroom ])
          few = query_count { candidates }
          3.times { student_in(create_classroom(school: @school)) }
          announce
          announce(audience: "classrooms", classrooms: [ create_classroom(school: @school) ])

          assert_equal few, query_count { candidates }
          assert_equal 5, few
        end
      end
    end
  end
end
