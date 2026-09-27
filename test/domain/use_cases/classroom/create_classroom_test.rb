require "test_helper"

module UseCases
  module Classroom
    class CreateClassroomTest < ActiveSupport::TestCase
      Clock = Data.define(:now)
      NOW = Time.utc(2026, 9, 25, 10)

      # Comme l'index unique de la table : un nom par école et par année ; le code est tiré par le repository.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :created

        def initialize(taken: [])
          @taken = taken
          @created = []
        end

        def create(classroom:)
          key = [ classroom.school_id, classroom.school_year, classroom.name ]
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @taken.include?(key)

          classroom.id = 31
          classroom.public_id = "abcdefghijkmno"
          classroom.join_code = "kfm37"
          @created << classroom
          Shared::Result.success(classroom)
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(schools) = @schools = schools
        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def lookup = Entities::Catalog::TaxonomyFixture.lookup
      end

      def school(public_id, status: "active", cycle: "both", id: 5)
        Entities::School::School.new(id:, public_id:, drena_id: 1, name: "Lycée Classique", school_type: "public", cycle:, status:)
      end

      setup do
        @classrooms = FakeClassrooms.new(taken: [ [ 5, "2026-2027", "Tle D 1" ] ])
        @schools = FakeSchools.new([ school("lycee"), school("ferme", status: "inactive", id: 6),
                                     school("brouillon", status: "draft", id: 7), school("college", cycle: "first", id: 8) ])
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def create(actor: @team, now: NOW, **overrides)
        dto = Dtos::Classroom::ClassroomInput.new(school_public_id: "lycee", level_slug: "tle", series_slug: "d", name: "Tle D 7",
                                                  max_students: 60, **overrides)
        CreateClassroom.new(classrooms: @classrooms, schools: @schools, taxonomy: FakeTaxonomy.new,
                            policy: Policies::Classroom::ManageClassroomPolicy.new, clock: Clock.new(now)).call(actor:, dto:)
      end

      test "l'équipe crée une classe active pour l'année scolaire en cours, avec le code tiré par le repository" do
        result = create

        assert result.success?
        classroom = @classrooms.created.sole
        assert_same classroom, result.value
        assert_equal [ 5, 7, 105, "2026-2027", "Tle D 7", 60, "active", "kfm37" ],
                     [ classroom.school_id, classroom.level_id, classroom.series_id, classroom.school_year, classroom.name,
                       classroom.max_students, classroom.status, classroom.join_code ]
      end

      test "l'année scolaire suit la date : le 15 août 2027 est encore en 2026-2027" do
        assert_equal "2026-2027", create(now: Time.utc(2027, 8, 15)).value.school_year
        assert_equal "2027-2028", create(now: Time.utc(2027, 9, 1), name: "Tle D 8").value.school_year
      end

      test "un niveau sans série, sans série donnée" do
        result = create(level_slug: "6eme", series_slug: nil, name: "6ème 5")

        assert result.success?
        assert_equal [ 5, 1, nil ], [ result.value.school_id, result.value.level_id, result.value.series_id ]
      end

      test "un établissement en brouillon ne reçoit pas de classe : :conflict, il faut d'abord l'activer" do
        result = create(school_public_id: "brouillon")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :school_draft ] }, result.errors)
        assert_empty @classrooms.created
      end

      test "hors de l'équipe : :forbidden, rien n'est écrit, avant même de lire la saisie" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 5)

        assert_equal :forbidden, create(actor: teacher).code
        assert_equal :forbidden, create(actor: nil, name: "").code
        assert_empty @classrooms.created
      end

      test "une saisie invalide donne :invalid, avec les erreurs du formulaire" do
        result = create(name: "", max_students: 200)

        assert_equal :invalid, result.code
        assert_equal %i[name max_students], result.errors.keys
        assert_empty @classrooms.created
      end

      test "un établissement inconnu donne :not_found" do
        assert_equal :not_found, create(school_public_id: "inconnu").code
      end

      test "un établissement désactivé ne reçoit plus de classe : :conflict" do
        result = create(school_public_id: "ferme")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :school_inactive ] }, result.errors)
        assert_empty @classrooms.created
      end

      test "un niveau inconnu, ou du second cycle dans un collège, est refusé" do
        assert_equal({ level_slug: [ :inclusion ] }, create(level_slug: "cp").errors)
        assert_equal({ level_slug: [ :not_allowed ] }, create(school_public_id: "college").errors)
        assert_equal :invalid, create(level_slug: "cp").code
        assert_empty @classrooms.created
      end

      test "série incompatible : la série D n'est pas ouverte à la 6ème" do
        result = create(level_slug: "6eme")

        assert_equal :invalid, result.code
        assert_equal({ series_slug: [ :not_allowed ] }, result.errors)
      end

      test "série inconnue, ou absente alors que le niveau a des séries" do
        assert_equal({ series_slug: [ :inclusion ] }, create(series_slug: "z").errors)
        assert_equal({ series_slug: [ :blank ] }, create(series_slug: nil).errors)
        assert_empty @classrooms.created
      end

      test "nom déjà pris dans l'établissement et l'année : :conflict sur le nom" do
        result = create(name: "Tle D 1")

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
      end
    end
  end
end
