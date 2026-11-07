require "test_helper"

module Repositories
  module Billing
    class RelayPointRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = RelayPointRepository.new
        @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
        @school = create_school(name: "Collège Saint Michel")
        @other = create_school(name: "Lycée Moderne")
      end

      def entity(**attributes) = Entities::Billing::RelayPoint.new(name: "Boutique Kouassi", location: "Gare", phone: "05 01 02 03 04", **attributes)

      test "crée un point relais avec ses écoles, puis le retrouve par son identifiant public" do
        saved = @repository.save(relay_point: entity, school_ids: [ @school.id, @other.id, 0 ])

        assert saved.success?
        assert_equal [ @school.id, @other.id ].sort, saved.value.school_ids
        assert_equal saved.value, @repository.find(public_id: saved.value.public_id)
        assert_nil @repository.find(public_id: "Inconnu")
      end

      test "met à jour et remplace les écoles sans doublon" do
        @repository.save(relay_point: @repository.find(public_id: @awa.public_id), school_ids: [ @school.id ])
        updated = @repository.save(relay_point: @repository.find(public_id: @awa.public_id).with(name: "Awa 2", active: false),
                                   school_ids: [ @school.id, @other.id ])
        again = @repository.save(relay_point: updated.value, school_ids: [ @other.id ])

        assert_equal [ "Awa 2", false, [ @other.id ] ], [ again.value.name, again.value.active, again.value.school_ids ]
      end

      test "une écriture refusée par la base rend :conflict" do
        reports = []
        subscriber = Object.new
        subscriber.define_singleton_method(:report) { |error, handled:, context: {}, **| reports << [ error.class, handled, context ] }
        Rails.error.subscribe(subscriber)
        begin
          result = @repository.save(relay_point: entity(name: "x" * 81), school_ids: [])
        ensure
          Rails.error.unsubscribe(subscriber)
        end

        assert_equal [ :conflict, [ :write_failed ] ], [ result.code, result.errors[:base] ]
        assert_equal [ [ ActiveRecord::ValueTooLong, true, { relay_point_public_id: nil } ] ], reports
      end

      test "liste par nom ; for_school ne rend que les points relais actifs de l'école" do
        @repository.save(relay_point: @repository.find(public_id: @awa.public_id), school_ids: [ @school.id ])
        inactive = @repository.save(relay_point: entity(name: "Annexe", active: false), school_ids: [ @school.id ]).value

        assert_equal [ "Annexe", "Boutique Awa" ], @repository.list.map(&:name)
        assert_equal [ "Boutique Awa" ], @repository.for_school(school_id: @school.id).map(&:name)
        assert_empty @repository.for_school(school_id: @other.id)
        assert_equal [ inactive.id ], @repository.list.select { !it.active }.map(&:id)
      end

      test "lots du plus récent au plus ancien, écoles à cocher et noms d'écoles" do
        newer = Orm::Billing::CardBatch.create!(relay_point: @awa, quantity: 5, unit_price_xof: 0, valid_until: Date.new(2027, 7, 31),
                                                created_at: Time.utc(2026, 11, 10))

        assert_equal [ newer.public_id, "AwaBatch000001" ], @repository.batches_of(relay_point_id: @awa.id).map(&:public_id)
        assert_includes @repository.school_choices.map(&:last), @school.id
        assert_match(/\ACollège Saint Michel \(.+\)\z/, @repository.school_choices.to_h { [ it.last, it.first ] }.fetch(@school.id))
        assert_equal({ @school.id => "Collège Saint Michel" }, @repository.school_names(school_ids: [ @school.id ]))
      end

      test "l'école d'un élève est celle de sa classe principale active, sinon nil" do
        student = create_student(classroom: create_classroom(school: @school))

        assert_equal @school.id, @repository.school_id_of_student(student_id: student.id)
        assert_nil @repository.school_id_of_student(student_id: create_student.id)
        Orm::ClassroomStudent.where(student:).update_all(left_at: Time.current)
        assert_nil @repository.school_id_of_student(student_id: student.id)
      end
    end
  end
end
