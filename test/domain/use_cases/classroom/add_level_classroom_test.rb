require "test_helper"

module UseCases
  module Classroom
    # CN-02, CN-03, CN-04, CN-09, ADR-0059 : « + » du bloc « Classes par niveau » crée la classe suivante du couple
    # niveau/série, nommée comme au barème, avec les règles d'« Ajouter une classe », et la trace.
    # GD-08, GD-11, GD-12, ADR-0071 §4.2 : la direction le fait aussi, sur son seul établissement actif.
    class AddLevelClassroomTest < ActiveSupport::TestCase
      Clock = Data.define(:now)
      NOW = Time.utc(2026, 9, 28, 10)
      YEAR = "2026-2027".freeze

      # Comme l'index unique : un nom par école et par année. `steal` : noms pris par un autre juste avant l'écriture.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :created, :names

        def initialize(names: [], steal: [])
          @names = names.to_set
          @steal = steal.dup
          @created = []
        end

        def names_in(school_id:, school_year:)
          raise ArgumentError unless [ school_id, school_year ] == [ 5, YEAR ]

          @names.dup
        end

        def create(classroom:)
          @names << @steal.shift if @steal.any?
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @names.include?(classroom.name)

          @names << classroom.name
          classroom.id = 40 + @created.size
          classroom.public_id = "cls#{@created.size}"
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

        def initialize(lookup = Entities::Catalog::TaxonomyFixture.lookup) = @lookup = lookup
        def lookup = @lookup
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      def school(public_id, status: "active", cycle: "both", id: 5)
        Entities::School::School.new(id:, public_id:, drena_id: 1, name: "Lycée Classique", school_type: "public", cycle:, status:)
      end

      setup do
        @classrooms = FakeClassrooms.new(names: [ "6ème 1", "6ème 2", "6ème 3", "6ème 4", "Tle D 1", "Tle D 3" ])
        @schools = FakeSchools.new([ school("lycee"), school("ferme", status: "inactive", id: 6), school("brouillon", status: "draft", id: 8),
                                     school("college", cycle: "first", id: 9), school("autre", id: 12) ])
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @taxonomy = FakeTaxonomy.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def add(actor: @team, school_public_id: "lycee", level_slug: "6eme", series_slug: nil)
        AddLevelClassroom.new(classrooms: @classrooms, schools: @schools, taxonomy: @taxonomy, audit_log: @audit,
                              policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: @transaction,
                              clock: Clock.new(NOW))
                         .call(actor:, school_public_id:, level_slug:, series_slug:)
      end

      test "« + » sur la 6ème crée la « 6ème 5 », active, de l'année en cours, au plafond par défaut, et la trace" do
        result = add

        assert result.success?
        classroom = @classrooms.created.sole
        assert_same classroom, result.value
        assert_equal [ 5, 1, nil, YEAR, "6ème 5", 80, "active" ],
                     [ classroom.school_id, classroom.level_id, classroom.series_id, classroom.school_year, classroom.name,
                       classroom.max_students, classroom.status ]
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 5,
                         metadata: { change: "classroom_added", classroom_public_id: "cls0", name: "6ème 5" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "la numérotation suit le plus grand numéro de la série : « Tle D 4 » après « Tle D 1 » et « Tle D 3 »" do
        result = add(level_slug: "tle", series_slug: "d")

        assert_equal [ "Tle D 4", 7, 105 ], [ result.value.name, result.value.level_id, result.value.series_id ]
        assert_equal "Tle A1 1", add(level_slug: "tle", series_slug: "a1").value.name
      end

      test "le nom suivant pris entre-temps est recalculé une fois" do
        @classrooms = FakeClassrooms.new(names: [ "6ème 1" ], steal: [ "6ème 2" ])

        assert_equal "6ème 3", add.value.name
        assert_equal 1, @audit.events.size
      end

      test "pris deux fois de suite : :conflict name_taken, rien n'est tracé" do
        @classrooms = FakeClassrooms.new(names: [ "6ème 1" ], steal: [ "6ème 2", "6ème 3" ])

        result = add

        assert_equal :conflict, result.code
        assert_equal({ base: [ :name_taken ] }, result.errors)
        assert_empty @audit.events
      end

      test "mêmes règles qu'« Ajouter une classe » : ni désactivé, ni brouillon, premier cycle au collège, couple ouvert" do
        assert_equal({ base: [ :school_inactive ] }, add(school_public_id: "ferme").errors)
        assert_equal({ base: [ :school_draft ] }, add(school_public_id: "brouillon").errors)
        assert_equal :conflict, add(school_public_id: "brouillon").code
        assert_equal({ level_slug: [ :not_allowed ] }, add(school_public_id: "college", level_slug: "2nde", series_slug: "a").errors)
        assert_equal({ series_slug: [ :not_allowed ] }, add(level_slug: "6eme", series_slug: "d").errors)
        assert_equal({ series_slug: [ :blank ] }, add(level_slug: "tle").errors)
        assert_equal :invalid, add(level_slug: "cp").code
        assert_empty @classrooms.created
        assert_empty @audit.events
      end

      test "un nom trop long pour la classe (niveau au nom long) est refusé sans écriture" do
        levels = [ [ "Sixième du cycle un", "6eme", "first" ] ]
        @taxonomy = FakeTaxonomy.new(Entities::Catalog::TaxonomyFixture.lookup(levels:, pairs: {}))

        result = add

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_empty @classrooms.created
      end

      test "un établissement inconnu donne :not_found" do
        assert_equal :not_found, add(school_public_id: "inconnu").code
      end

      test "un établissement inconnu reste :not_found, quel que soit l'acteur (la policy lit l'établissement)" do
        assert_equal :not_found, add(actor: nil, school_public_id: "inconnu").code
        assert_equal :not_found, add(actor: direction(of: 5), school_public_id: "inconnu").code
      end

      test "ni élève, ni enseignant, ni visiteur, ni direction sans établissement : :forbidden, rien n'est écrit" do
        [ Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 5), Entities::Identity::Actor.new(user_id: 4, role: :student),
          direction(of: nil), nil ].each do |actor|
          assert_equal :forbidden, add(actor:).code, actor.inspect
        end
        assert_empty @classrooms.created
        assert_empty @audit.events
      end

      def direction(of:) = Entities::Identity::Actor.new(user_id: 11, role: :school_admin, school_id: of)

      test "GD-08 : la direction de son établissement actif ajoute la « 6ème 5 », tracée à son nom" do
        result = add(actor: direction(of: 5))

        assert result.success?
        assert_equal [ 5, "6ème 5" ], [ @classrooms.created.sole.school_id, result.value.name ]
        assert_equal [ [ "school.changed", 11, 5, { change: "classroom_added", classroom_public_id: "cls0", name: "6ème 5" } ] ],
                     @audit.events.map { it.values_at(:action, :actor_id, :subject_id, :metadata) }
      end

      test "GD-11 : la direction de A sur l'établissement B : :forbidden, rien n'est écrit ni tracé" do
        assert_equal :forbidden, add(actor: direction(of: 5), school_public_id: "autre").code
        assert_empty @classrooms.created
        assert_empty @audit.events
      end

      test "GD-12 : la direction d'un établissement inactif ou en brouillon : :forbidden (et non le conflit de l'équipe)" do
        assert_equal :forbidden, add(actor: direction(of: 6), school_public_id: "ferme").code
        assert_equal :forbidden, add(actor: direction(of: 8), school_public_id: "brouillon").code
        assert_equal :conflict, add(school_public_id: "ferme").code
        assert_empty @classrooms.created
        assert_empty @audit.events
      end
    end
  end
end
