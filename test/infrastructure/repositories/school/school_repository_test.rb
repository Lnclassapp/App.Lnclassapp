require "test_helper"

module Repositories
  module School
    class SchoolRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = SchoolRepository.new
        @drena = create_drena
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def school(name: "Lycée Classique", school_code: Entities::School::SchoolCode.generate, **attributes)
        Entities::School::School.new(drena_id: @drena.id, name:, sigle: "LCA", school_type: "public", cycle: "both",
                                     status: "active", school_code:, **attributes)
      end

      def row(name, school_code: Entities::School::SchoolCode.generate, **overrides)
        { public_id: SecureRandom.base58(14), drena_id: @drena.id, name:, sigle: nil, school_type: "public", cycle: "both",
          status: "active", school_code:, **overrides }
      end

      test "crée puis retrouve un établissement par public_id" do
        created = @repository.create(school: school(school_code: "k7m4qz")).value

        found = @repository.find_by_public_id(public_id: created.public_id)

        assert_instance_of Entities::School::School, found
        assert_equal [ "Lycée Classique", "LCA", "public", "both", "active", @drena.id, "k7m4qz" ],
                     [ found.name, found.sigle, found.school_type, found.cycle, found.status, found.drena_id, found.school_code ]
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      # IE-21 (ADR-0082 §4.5) : le dépôt ne cherche plus par code national ; l'import lit encore les codes pris.
      test "CP-09 : liste les codes nationaux pris (ADR-0063)" do
        create_school(drena: @drena, national_code: "012345")
        create_school(drena: @drena, national_code: nil)

        assert_equal Set["012345"], @repository.taken_national_codes
      end

      test "CP-10 : un code national déjà pris est un conflit sur le code national, pas sur le nom" do
        create_school(drena: @drena, national_code: "012345")
        school = @repository.find_by_public_id(public_id: create_school(drena: @drena).public_id)
        school.national_code = "012345"

        assert_equal [ :conflict, { national_code: [ :taken ] } ], @repository.update(school:).then { [ it.code, it.errors ] }
        school.national_code = "023456"
        assert_equal "023456", @repository.update(school:).value.national_code
      end

      test "CP-07: retrouve un établissement par son id, quel que soit son statut ; nil pour un id inconnu (ADR-0063)" do
        draft = create_school(drena: @drena, status: "draft")

        assert_equal [ draft.id, "draft" ], @repository.find_by_id(id: draft.id).then { [ it.id, it.status ] }
        assert_nil @repository.find_by_id(id: 0)
      end

      test "CE-01: retrouve un établissement par son code, quel que soit son statut ; nil pour un code inconnu (ADR-0057)" do
        active = create_school(drena: @drena, school_code: "k7m4qz")
        inactive = create_school(drena: @drena, school_code: "abc234", status: "inactive")

        assert_equal [ active.id, "active" ], @repository.find_by_school_code(school_code: "k7m4qz").then { [ it.id, it.status ] }
        assert_equal "inactive", @repository.find_by_school_code(school_code: "abc234").status
        assert_equal inactive.public_id, @repository.find_by_school_code(school_code: "abc234").public_id
        assert_nil @repository.find_by_school_code(school_code: "zzz999")
      end

      test "CE-10: donne l'ensemble des codes d'établissement déjà pris" do
        create_school(drena: @drena, school_code: "k7m4qz")
        create_school(school_code: "abc234")

        assert_equal Set["k7m4qz", "abc234"], @repository.taken_school_codes
      end

      test "CE-07: remplace le code et date la régénération ; un code déjà pris donne :conflict sans rien changer" do
        record = create_school(drena: @drena, school_code: "k7m4qz")
        create_school(school_code: "abc234")

        replaced = @repository.replace_school_code(id: record.id, school_code: "xyz789", at: @at)

        assert replaced.success?
        assert_equal [ "xyz789", record.public_id ], [ replaced.value.school_code, replaced.value.public_id ]
        assert_equal [ "xyz789", @at ], record.reload.attributes.values_at("school_code", "school_code_rotated_at")

        taken = @repository.replace_school_code(id: record.id, school_code: "abc234", at: @at + 1.hour)

        assert_equal :conflict, taken.code
        assert_equal [ "xyz789", @at ], record.reload.attributes.values_at("school_code", "school_code_rotated_at")
      end

      test "la modification d'un établissement ne touche pas à son code" do
        entity = @repository.create(school: school(school_code: "k7m4qz")).value
        edited = Entities::School::School.new(id: entity.id, public_id: entity.public_id, drena_id: @drena.id, name: "Lycée B",
                                              school_type: "public", cycle: "both", status: "active")

        assert @repository.update(school: edited).success?
        assert_equal "k7m4qz", Orm::School.find(entity.id).school_code
      end

      test "un nom déjà pris dans la DRENA donne :conflict" do
        @repository.create(school: school)

        result = @repository.create(school: school)

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
      end

      test "met à jour un établissement" do
        entity = @repository.create(school: school).value
        entity.school_type = "mixed"
        entity.name = "Lycée Classique d'Abidjan"

        result = @repository.update(school: entity)

        assert result.success?
        assert_equal [ "mixed", "Lycée Classique d'Abidjan" ], Orm::School.find(entity.id).attributes.values_at("school_type", "name")
      end

      test "supprime un établissement et ses classes inutilisées" do
        record = create_school(drena: @drena)
        classroom = create_classroom(school: record)

        assert @repository.delete_if_unreferenced(id: record.id).success?
        assert_not Orm::School.exists?(record.id)
        assert_not Orm::Classroom.exists?(classroom.id)
      end

      test "refuse de supprimer un établissement dont une classe a un élève, un enseignant ou une assignation" do
        uses = {
          student: ->(classroom) { create_student(classroom:) },
          teacher: ->(classroom) { Orm::TeacherClassroom.create!(teacher: create_user(role: "teacher"), classroom:) },
          assignment: ->(classroom) { create_assignment(classroom:) }
        }

        uses.each do |use, make|
          record = create_school(drena: @drena)
          make.call(create_classroom(school: record))

          result = @repository.delete_if_unreferenced(id: record.id)

          assert_equal({ base: [ :referenced ] }, result.errors, use)
          assert Orm::School.exists?(record.id), use
        end
      end

      test "refuse de supprimer un établissement rattaché à un enseignant ou visé par une invitation" do
        attached = create_teacher.then { |teacher| Orm::TeacherSchool.find_by(teacher:).school }
        invited = create_invitation(kind: "school_staff").school

        [ attached, invited ].each do |record|
          assert_equal :conflict, @repository.delete_if_unreferenced(id: record.id).code
        end
      end

      test "B1 : refuse de supprimer un établissement visé par une demande d'enseignant (même refusée) ou un parrainage (ADR-0063)" do
        requested = create_join_request(status: "rejected").school
        sponsored = create_school
        create_referral(school_id: sponsored.id)

        [ requested, sponsored ].each do |record|
          assert_equal :conflict, @repository.delete_if_unreferenced(id: record.id).code
          assert Orm::School.exists?(record.id)
        end
      end

      test "donne les clés de doublon (DRENA, nom normalisé) des DRENA demandées" do
        create_school(drena: @drena, name: "Lycée  Moderne de Cocody")
        create_school(name: "Collège ailleurs")

        keys = @repository.existing_keys(drena_ids: [ @drena.id ])

        assert_equal Set[[ @drena.id, "lycee moderne de cocody" ]], keys
      end

      test "insère en masse et renvoie de quoi générer les classes" do
        rows = [ [ "Lycée A", "k7m4qz" ], [ "Collège B", "abc234" ] ].map do |name, school_code|
          row(name, school_code:, school_type: "private", cycle: Entities::School::School.cycle_for(name:))
        end

        inserted = @repository.insert_many(rows:, at: @at)

        assert_equal [ "Lycée A", "Collège B" ], inserted.map(&:name)
        assert_equal %w[k7m4qz abc234], Orm::School.where(id: inserted.map(&:id)).order(:id).pluck(:school_code)
        assert_equal %w[both first], inserted.map(&:cycle)
        assert_instance_of Ports::School::SchoolRepositoryPort::Inserted, inserted.first
        assert_equal @at, Orm::School.find(inserted.first.id).created_at
        assert_equal [], @repository.insert_many(rows: [], at: @at)
      end

      test "une insertion en masse qui heurte l'index unique lève" do
        create_school(drena: @drena, name: "Lycée A")
        create_school(drena: @drena, name: "Lycée B", school_code: "k7m4qz")

        [ row("Lycée A"), row("Lycée C", school_code: "k7m4qz") ].each do |taken|
          assert_raises(ActiveRecord::RecordNotUnique, taken[:name]) do
            Orm::School.transaction(requires_new: true) { @repository.insert_many(rows: [ taken ], at: @at) }
          end
        end
      end

      test "candidates of the generation: active or draft, without any classroom of the year, by id (ADR-0056, GC-05)" do
        year = current_school_year
        active = create_school(drena: @drena, name: "Lycée sans classe")
        draft = create_school(drena: @drena, name: "Lycée brouillon", status: "draft", school_type: "private", cycle: "first")
        create_school(drena: @drena, name: "Lycée désactivé", status: "inactive")
        archived = create_school(drena: @drena, name: "Lycée à la classe archivée")
        create_classroom(school: archived, status: "archived", join_code: nil)
        last_year = create_school(drena: @drena, name: "Lycée de l'an dernier")
        create_classroom(school: last_year, school_year: current_school_year(on: 1.year.ago.to_date))
        equipped = create_school(drena: @drena, name: "Lycée doté")
        create_classroom(school: equipped)

        candidates = @repository.without_classrooms(school_year: year, after_id: 0, limit: 10)

        assert_equal [ active.id, draft.id, last_year.id ], candidates.map(&:id)
        assert_instance_of Ports::School::SchoolRepositoryPort::Inserted, candidates.first
        assert_equal [ draft.public_id, @drena.id, "Lycée brouillon", "private", "first" ],
                     candidates.second.to_h.values_at(:public_id, :drena_id, :name, :school_type, :cycle)
        assert_equal [ active.id ], @repository.without_classrooms(school_year: year, after_id: 0, limit: 1).map(&:id)
        assert_equal [ last_year.id ], @repository.without_classrooms(school_year: year, after_id: draft.id, limit: 10).map(&:id)
        assert_equal [ archived.id, last_year.id, equipped.id ],
                     @repository.without_classrooms(school_year: "2020-2021", after_id: draft.id, limit: 10).map(&:id)
      end

      test "rattache un enseignant ; une seconde école principale donne :conflict (ADR-0030)" do
        teacher = create_user(role: "teacher")
        first = create_school
        second = create_school

        assert @repository.attach_teacher(teacher_id: teacher.id, school_id: first.id, primary: true, at: @at).success?
        assert_equal :conflict, @repository.attach_teacher(teacher_id: teacher.id, school_id: second.id, primary: true, at: @at).code
        assert @repository.attach_teacher(teacher_id: teacher.id, school_id: second.id, primary: false, at: @at).success?
        assert_equal first.id, @repository.primary_school_id_for(teacher_id: teacher.id)
        assert_nil @repository.primary_school_id_for(teacher_id: create_user(role: "teacher").id)
      end

      # ADR-0071 §4.5 : retirer un enseignant de cet établissement, sans toucher à un autre.
      test "detach_teacher supprime le rattachement à cet établissement seulement, et compte les lignes supprimées" do
        here, elsewhere = create_school, create_school
        teacher = create_teacher(school: here)
        Orm::TeacherSchool.create!(teacher:, school: elsewhere, primary: false)
        colleague = create_teacher(school: here)

        assert_equal 1, @repository.detach_teacher(teacher_id: teacher.id, school_id: here.id)
        assert_equal [ elsewhere.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
        assert Orm::TeacherSchool.exists?(teacher: colleague, school: here)
        assert_equal 0, @repository.detach_teacher(teacher_id: teacher.id, school_id: here.id)
      end
    end
  end
end
