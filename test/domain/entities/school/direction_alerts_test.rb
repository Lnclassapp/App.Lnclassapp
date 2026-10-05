require "test_helper"

# AD-03, AD-04, AD-05 (UDR-0074 §3.3): the alerts of the school card, in a fixed order, each present only when its count
# is positive; a classroom alert names its first three classrooms, in the order received, then counts the others.
module Entities
  module School
    class DirectionAlertsTest < ActiveSupport::TestCase
      Facts = DirectionAlerts::ClassroomFacts
      Alert = DirectionAlerts::Alert

      def facts(name, students: 20, teachers: 2, rate: 80) = Facts.new(name:, students_count: students, teachers_count: teachers,
                                                                       submission_rate: rate)

      def alerts(school_active: true, classrooms: [], teachers_without_classroom: 0)
        DirectionAlerts.call(school_active:, classrooms:, teachers_without_classroom:)
      end

      test "AD-05: an active school whose classrooms are taught, filled and above the red signal has no alert" do
        assert_empty alerts(classrooms: [ facts("6ème 1"), facts("3ème 2", rate: 40), facts("Tle D", rate: nil) ])
        assert_empty alerts
      end

      test "AD-03, AD-04: the five alerts come in order: inactive, without teacher, without students, red signal, idle teachers" do
        found = alerts(school_active: false, teachers_without_classroom: 2,
                       classrooms: [ facts("6ème 1", teachers: 0), facts("5ème 1", students: 0, rate: nil), facts("3ème 2", rate: 31) ])

        assert_equal [ Alert.new(kind: :inactive, names: [], others: 0, count: 1),
                       Alert.new(kind: :without_teacher, names: [ "6ème 1" ], others: 0, count: 1),
                       Alert.new(kind: :without_students, names: [ "5ème 1" ], others: 0, count: 1),
                       Alert.new(kind: :red_signal, names: [ "3ème 2" ], others: 0, count: 1),
                       Alert.new(kind: :teachers_without_classroom, names: [], others: 0, count: 2) ], found
      end

      test "AD-04: an inactive school alone gives the inactive alert alone" do
        assert_equal [ Alert.new(kind: :inactive, names: [], others: 0, count: 1) ], alerts(school_active: false)
      end

      test "AD-03: an alert names three classrooms at most, in the order received, and counts the others" do
        names = [ "6ème 1", "6ème 2", "5ème 1", "4ème 3", "3ème 2" ]

        { 2 => [ names.first(2), 0 ], 3 => [ names.first(3), 0 ], 4 => [ names.first(3), 1 ], 5 => [ names.first(3), 2 ] }
          .each do |size, (named, others)|
          alert = alerts(classrooms: names.first(size).map { facts(it, teachers: 0) }).sole

          assert_equal [ :without_teacher, named, others, size ], alert.to_h.values_at(:kind, :names, :others, :count), "#{size} classrooms"
        end
      end

      test "AD-03: a classroom with a teacher, a student, or a rate from 40 % is not in an alert; a rate under 40 % is" do
        found = alerts(classrooms: [ facts("A", teachers: 1, students: 1, rate: 40), facts("B", rate: 39), facts("C", rate: 0),
                                     facts("D", rate: nil), facts("E", rate: 70) ])

        assert_equal [ Alert.new(kind: :red_signal, names: %w[B C], others: 0, count: 2) ], found
      end

      test "AD-03: a classroom can be in several alerts" do
        found = alerts(classrooms: [ facts("6ème 1", teachers: 0, students: 0, rate: nil) ])

        assert_equal %i[without_teacher without_students], found.map(&:kind)
      end

      test "AD-03: idle teachers are counted, never named, and only when there is at least one" do
        assert_equal [ Alert.new(kind: :teachers_without_classroom, names: [], others: 0, count: 5) ],
                     alerts(teachers_without_classroom: 5)
        assert_empty alerts(teachers_without_classroom: 0)
      end
    end
  end
end
