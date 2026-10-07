require "test_helper"

module UseCases
  module Classroom
    # IL-14, IL-21, IL-12 pour le retrait (ADR-0083 §4.5) : sous le verrou de la classe et ManageClassroomMembersPolicy,
    # l'adhésion active est close et retient qui l'a retirée ; le compte n'est pas touché. Idempotent : un élève déjà
    # retiré (retrait simultané, double envoi) donne un succès sans écriture. Un élève qui n'est pas dans la classe : 404,
    # son nom ne sort pas.
    class RemoveStudentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 7, 9)
      Clock = Data.define(:now)
      Actor = Entities::Identity::Actor

      class FakeTransaction
        include Ports::Shared::TransactionPort

        def initialize(journal) = @journal = journal

        def call
          @journal << :begin
          yield.tap { @journal << :commit }
        end
      end

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(journal, classroom)
          @journal = journal
          @classroom = classroom
        end

        def lock_by_public_id(public_id:)
          @journal << [ :lock, public_id ]
          @classroom if @classroom.public_id == public_id
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users
        def find_by_public_id(public_id:) = @users.find { it.public_id == public_id }
      end

      # Une adhésion par élève et par classe : [classroom_id, student_id] => { left_at:, removed_at:, removed_by_id: }.
      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        attr_reader :rows

        def initialize(journal, rows)
          @journal = journal
          @rows = rows
        end

        def remove(classroom_id:, student_id:, removed_by_id:, at:)
          @journal << [ :remove, classroom_id, student_id, removed_by_id, at ]
          row = @rows[[ classroom_id, student_id ]]
          return false if row.nil? || row[:left_at]

          row.merge!(left_at: at, removed_at: at, removed_by_id:)
          true
        end

        def removed_from?(classroom_id:, student_id:) = !@rows.dig([ classroom_id, student_id ], :removed_at).nil?
      end

      setup do
        @journal = []
        @classroom = Entities::Classroom::Classroom.new(id: 7, public_id: "cls-3e2", name: "3e 2", school_id: 31, level_id: 2,
                                                        school_year: "2026-2027", teacher_ids: [ 5 ], active_students_count: 2)
        @koffi = user(41, "usr-koffi", "Koffi", "Yao")
        @awa = user(42, "usr-awa", "Awa", "Bamba")
        @outsider = user(43, "usr-ailleurs", "Zoé", "Ailleurs")
        @colleague = user(44, "usr-prof", "Jean", "Kouadio", role: "teacher")
        @memberships = FakeMemberships.new(@journal, { [ 7, 41 ] => { left_at: nil }, [ 7, 42 ] => { left_at: nil },
                                                       [ 8, 43 ] => { left_at: nil } })
        @teacher = Actor.new(user_id: 5, role: :teacher, school_id: 31)
      end

      def user(id, public_id, first_name, last_name, role: "student")
        Entities::Identity::User.new(id:, public_id:, first_name:, last_name:, gender: "male", role:)
      end

      def remove(student_public_id, actor: @teacher, classroom_public_id: "cls-3e2")
        RemoveStudent.new(classrooms: FakeClassrooms.new(@journal, @classroom), memberships: @memberships,
                          users: FakeUsers.new(@koffi, @awa, @outsider, @colleague),
                          policy: Policies::Classroom::ManageClassroomMembersPolicy.new,
                          transaction: FakeTransaction.new(@journal), clock: Clock.new(NOW))
                     .call(actor:, classroom_public_id:, student_public_id:)
      end

      test "IL-14 : l'enseignant de la classe retire Koffi, sous le verrou de la classe ; Awa reste" do
        result = remove("usr-koffi")

        assert result.success?
        assert_equal RemoveStudent::Removal.new(classroom: @classroom, student: @koffi, removed: true), result.value
        assert_equal "Koffi Yao", result.value.student.display_name
        assert_equal [ :begin, [ :lock, "cls-3e2" ], [ :remove, 7, 41, 5, NOW ], :commit ], @journal
        assert_equal({ left_at: NOW, removed_at: NOW, removed_by_id: 5 }, @memberships.rows[[ 7, 41 ]])
        assert_equal({ left_at: nil }, @memberships.rows[[ 7, 42 ]])
      end

      test "IL-12 : la direction de l'établissement et l'équipe retirent aussi, chacune retenue comme auteur" do
        assert remove("usr-koffi", actor: Actor.new(user_id: 60, role: :school_admin, school_id: 31)).success?
        assert_equal 60, @memberships.rows[[ 7, 41 ]][:removed_by_id]

        assert remove("usr-awa", actor: Actor.new(user_id: 70, role: :team)).success?
        assert_equal 70, @memberships.rows[[ 7, 42 ]][:removed_by_id]
      end

      test "IL-21 : un second retrait du même élève réussit sans rien écrire ; un seul départ, celui du premier" do
        assert remove("usr-koffi").value.removed

        second = remove("usr-koffi", actor: Actor.new(user_id: 60, role: :school_admin, school_id: 31))

        assert second.success?
        assert_equal RemoveStudent::Removal.new(classroom: @classroom, student: @koffi, removed: false), second.value
        assert_equal({ left_at: NOW, removed_at: NOW, removed_by_id: 5 }, @memberships.rows[[ 7, 41 ]])
      end

      test "IL-12 : un enseignant d'une autre classe, une direction d'un autre établissement : 404, rien n'est écrit" do
        assert_equal :not_found, remove("usr-koffi", actor: Actor.new(user_id: 6, role: :teacher, school_id: 31)).code
        assert_equal :not_found, remove("usr-koffi", actor: Actor.new(user_id: 61, role: :school_admin, school_id: 32)).code
        assert_nothing_removed
      end

      test "IL-12 : un élève, même de la classe, et un visiteur : 403, rien n'est écrit" do
        assert_equal :forbidden, remove("usr-koffi", actor: Actor.new(user_id: 42, role: :student)).code
        assert_equal :forbidden, remove("usr-koffi", actor: nil).code
        assert_nothing_removed
      end

      test "une classe inconnue : 404, avant toute policy" do
        assert_equal :not_found, remove("usr-koffi", classroom_public_id: "cls-inconnue").code
        assert_equal :not_found, remove("usr-koffi", actor: nil, classroom_public_id: "cls-inconnue").code
        assert_nothing_removed
      end

      test "un compte inconnu ou qui n'est pas un élève : 404, rien n'est écrit" do
        assert_equal :not_found, remove("usr-inconnu").code
        assert_equal :not_found, remove("usr-prof").code
        assert_nothing_removed
      end

      test "un élève qui n'est pas dans la classe, ou l'a quittée sans en être retiré : 404, son nom ne sort pas" do
        @memberships.rows[[ 7, 42 ]] = { left_at: NOW - 30.days }

        assert_equal :not_found, remove("usr-ailleurs").code
        assert_equal :not_found, remove("usr-awa").code
        assert_equal({ left_at: nil }, @memberships.rows[[ 8, 43 ]])
        assert_equal({ left_at: NOW - 30.days }, @memberships.rows[[ 7, 42 ]])
      end

      private

      def assert_nothing_removed
        assert_equal [ { left_at: nil } ], @memberships.rows.values.uniq
      end
    end

    # IL-21 sur PostgreSQL : l'enseignant et la direction retirent Koffi au même moment. Le second attend le verrou de la
    # classe, puis trouve Koffi parti : un seul départ, celui du premier, et aucun des deux ne voit d'erreur.
    class RemoveStudentConcurrencyTest < ActiveSupport::TestCase
      # Deux connexions doivent voir leurs écritures : pas de transaction de test englobante.
      self.use_transactional_tests = false

      PAUSE = 0.5

      # Garde le verrou un instant une fois pris, et le dit.
      class SlowLockClassrooms < Repositories::Classroom::ClassroomRepository
        def initialize(locked:)
          super()
          @locked = locked
        end

        def lock_by_public_id(public_id:)
          super.tap do
            @locked << true
            sleep PAUSE
          end
        end
      end

      setup do
        @classroom = create_classroom
        @teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ])
        @admin = create_school_admin(school: @classroom.school)
        @koffi = create_student(classroom: @classroom)
      end

      teardown do
        connection = ActiveRecord::Base.connection
        connection.truncate_tables(*(connection.tables - %w[schema_migrations ar_internal_metadata]))
      end

      def remove(user, role:, classrooms: Repositories::Classroom::ClassroomRepository.new)
        actor = Entities::Identity::Actor.new(user_id: user.id, role:, school_id: @classroom.school_id)
        RemoveStudent.new(classrooms:, memberships: Repositories::Classroom::MembershipRepository.new,
                          users: Repositories::Identity::UserRepository.new,
                          policy: Policies::Classroom::ManageClassroomMembersPolicy.new,
                          transaction: Repositories::Shared::Transaction.new, clock: Time.zone)
                     .call(actor:, classroom_public_id: @classroom.public_id, student_public_id: @koffi.public_id)
      end

      test "IL-21 : deux retraits simultanés, un seul départ, deux succès" do
        locked = Queue.new
        first = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            remove(@teacher, role: :teacher, classrooms: SlowLockClassrooms.new(locked:))
          end
        end
        assert locked.pop(timeout: 10), "le premier retrait n'a pas pris le verrou"
        second = Thread.new { ActiveRecord::Base.connection_pool.with_connection { remove(@admin, role: :school_admin) } }
        results = [ first.value, second.value ]

        assert results.all?(&:success?)
        assert_equal [ true, false ], results.map { it.value.removed }
        row = Orm::ClassroomStudent.find_by!(classroom: @classroom, student: @koffi)
        assert_equal @teacher.id, row.removed_by_id
        assert_not_nil row.left_at
        assert_equal 1, Orm::ClassroomStudent.where(student: @koffi).count
      end
    end
  end
end
