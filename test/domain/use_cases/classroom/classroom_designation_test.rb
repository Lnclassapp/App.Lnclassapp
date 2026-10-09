require "test_helper"

module UseCases
  module Classroom
    # IL-01, IL-08, IL-09 (ADR-0085 §4.1, §4.2): the classroom a student designates, by a valid link (way « link ») or by
    # the cascade (way « standard »), the rule RegisterStudent and JoinAsStudent share. Both read under the lock.
    class ClassroomDesignationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 8, 12)
      YEAR = "2026-2027".freeze
      TOKEN = "0a1b2c3d4e5f".freeze

      Clock = Data.define(:now)
      School = Data.define(:id, :public_id, :status) { def active? = status == "active" }
      Level = Data.define(:id)

      class FakeClassrooms
        attr_reader :locks

        def initialize(classrooms)
          @classrooms = classrooms
          @locks = []
        end

        def lock_by_public_id(public_id:)
          @locks << public_id
          @classrooms.find { it.public_id == public_id }
        end

        def lock_by_link_token(token:)
          @locks << token
          @classrooms.find { it.link_token == token }
        end
      end

      class FakeSchools
        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      class FakeTaxonomy
        def find_level(slug:) = (Level.new(id: 2) if slug == "3eme")
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "3e 2", school_id: 3, level_id: 2, school_year: YEAR,
                                           link_token: TOKEN, **overrides)
      end

      def designation(classrooms: [ classroom ], school: School.new(id: 3, public_id: "sch-3", status: "active"))
        @classrooms = FakeClassrooms.new(classrooms)
        ClassroomDesignation.new(classrooms: @classrooms, schools: FakeSchools.new(school), taxonomy: FakeTaxonomy.new,
                                 clock: Clock.new(NOW))
      end

      def choice(**attributes)
        Dtos::Classroom::StudentRegistrationInput.new(school_public_id: "sch-3", level_slug: "3eme", classroom_public_id: "cls-7",
                                                      **attributes)
      end

      test "IL-08: a valid link designates its classroom, way « link », under the lock" do
        destination = designation.linked(TOKEN)

        assert_equal [ 7, "link" ], [ destination.classroom.id, destination.via ]
        assert_equal [ TOKEN ], @classrooms.locks
      end

      test "IL-09: no token, an unknown token, an archived classroom or a school that is not active designate nothing" do
        assert_nil designation.linked(nil)
        assert_empty @classrooms.locks
        assert_nil designation.linked("ffffffffffff")
        assert_nil designation(classrooms: [ classroom(status: "archived") ]).linked(TOKEN)
        assert_nil designation(school: School.new(id: 3, public_id: "sch-3", status: "inactive")).linked(TOKEN)
      end

      test "IL-01: the classroom chosen in the cascade, way « standard », under the lock" do
        destination = designation.chosen(choice)

        assert_equal [ 7, "standard" ], [ destination.classroom.id, destination.via ]
        assert_equal [ "cls-7" ], @classrooms.locks
      end

      test "a classroom outside the cascade is refused under the field, a missing one too, nothing locked for the latter" do
        assert_equal [ :invalid, { classroom_public_id: [ :blank ] } ],
                     designation.chosen(choice(classroom_public_id: nil)).then { [ it.code, it.errors ] }
        assert_empty @classrooms.locks

        {
          "unknown" => [ designation, choice(classroom_public_id: "cls-9") ],
          "archived" => [ designation(classrooms: [ classroom(status: "archived") ]), choice ],
          "last year" => [ designation(classrooms: [ classroom(school_year: "2025-2026") ]), choice ],
          "other level" => [ designation, choice(level_slug: "tle") ],
          "other school" => [ designation, choice(school_public_id: "sch-4") ],
          "inactive school" => [ designation(school: School.new(id: 3, public_id: "sch-3", status: "draft")), choice ]
        }.each do |label, (subject, dto)|
          assert_equal [ :invalid, { classroom_public_id: [ :unavailable ] } ], subject.chosen(dto).then { [ it.code, it.errors ] },
                       label
        end
      end
    end
  end
end
