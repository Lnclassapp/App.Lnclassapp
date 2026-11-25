require "test_helper"

module Queries
  module Classroom
    # Chantier partage-classe-k-factor, lot E : k élève par classe et par établissement, agrégats seulement.
    class SignupKFactorQueryTest < ActiveSupport::TestCase
      FROM = Time.zone.local(2026, 11, 1)
      TO = Time.zone.local(2026, 12, 1)
      AT = Time.zone.local(2026, 11, 10, 9)

      def result(from: FROM, to: TO) = SignupKFactorQuery.new.call(from:, to:)

      def attribute(classroom, source, at: AT, student: create_student)
        Orm::SignupAttribution.create!(student:, classroom:, source:, created_at: at)
        student
      end

      def seed(classroom, qr: 0, invite: 0, link: 0, code: 0, cold: 0, at: AT)
        { "qr" => qr, "student_invite" => invite, "teacher_link" => link, "code" => code, "cold" => cold }.each do |source, count|
          count.times { attribute(classroom, source, at:) }
        end
      end

      test "the PRD example: 10 sign-ups, 4 QR, 2 invitations, 3 link, 1 cold give k = 0.6" do
        classroom = create_classroom(name: "3e B")
        seed(classroom, qr: 4, invite: 2, link: 3, cold: 1)

        line = result.classrooms.sole

        assert_equal "3e B", line.name
        assert_equal classroom.school.name, line.school_name
        assert_equal [ 10, 4, 2, 3, 0, 1 ], [ line.signups, line.qr, line.student_invite, line.teacher_link, line.code, line.cold ]
        assert_in_delta 0.6, line.k
        assert_equal 10, result.total.signups
        assert_in_delta 0.6, result.total.k
        assert_equal AT.to_date, result.since.to_date
      end

      test "a school aggregates its classrooms" do
        school = create_school
        seed(create_classroom(school:, name: "6e A"), qr: 2, cold: 2)
        seed(create_classroom(school:, name: "6e B"), invite: 2, code: 1)

        line = result.schools.sole

        assert_equal school.name, line.name
        assert_equal [ 7, 2, 2, 0, 1, 2 ], [ line.signups, line.qr, line.student_invite, line.teacher_link, line.code, line.cold ]
        assert_in_delta 4 / 7.0, line.k
      end

      test "k is nil without a sign-up and lines sort by sign-ups then name" do
        assert_nil result.total.k
        assert_nil result.since
        a = create_classroom(name: "B classe")
        b = create_classroom(name: "A classe")
        c = create_classroom(name: "C classe")
        seed(a, cold: 1)
        seed(b, cold: 1)
        seed(c, cold: 2)

        assert_equal [ "C classe", "A classe", "B classe" ], result.classrooms.map(&:name)
      end

      test "the period is [from, to): the lower bound counts, the upper one does not" do
        classroom = create_classroom
        seed(classroom, qr: 1, at: FROM)
        seed(classroom, qr: 1, at: TO)
        seed(classroom, qr: 1, at: FROM - 1.second)

        assert_equal 1, result.total.signups
      end

      test "anonymized students are excluded" do
        classroom = create_classroom
        attribute(classroom, "qr")
        attribute(classroom, "qr", student: create_student(anonymized_at: Time.current))

        assert_equal 1, result.total.signups
      end

      test "tables are capped at 20 lines with the rest counted" do
        22.times { |i| seed(create_classroom(name: format("Classe %02d", i)), cold: 1) }

        r = result

        assert_equal 20, r.classrooms.size
        assert_equal 2, r.classrooms_more
        assert_equal 20, r.schools.size
        assert_equal 2, r.schools_more
        assert_equal 22, r.total.signups
      end

      test "the number of queries does not depend on the data" do
        count = lambda do
          n = 0
          ActiveSupport::Notifications.subscribed(->(*, p) { n += 1 unless p[:name] == "SCHEMA" }, "sql.active_record") { result }
          n
        end
        empty = count.call
        3.times { seed(create_classroom, qr: 1, invite: 1) }

        assert_equal empty, count.call
      end
    end
  end
end
