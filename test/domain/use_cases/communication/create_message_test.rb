require "test_helper"

module UseCases
  module Communication
    # ADR-0078 §4.1, §4.2, §4.5 and §6: the team, a direction or a teacher writes an announcement: a draft, scheduled or
    # published now. The policy decides who writes for whom, on the values received, forged or not; nothing is written
    # when it refuses or when the form is invalid. On the real repositories: the constraints of the base answer too.
    class CreateMessageTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 1, 10)
      Clock = Data.define(:now)
      MP3 = ("ID3".b + ("\x00".b * 64)).freeze

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers")
        @bouake = create_school(name: "Lycée de Bouaké")
        @b3 = create_classroom(school: @lauriers, name: "3ème B")
        @c3 = create_classroom(school: @lauriers, name: "3ème C")
        @a3 = create_classroom(school: @lauriers, name: "3ème A")
        @kouassi = create_teacher(school: @lauriers, classrooms: [ @b3, @c3 ], last_name: "Kouassi", gender: "male")
        @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
        @fatou = create_team_member(second_factor: false, first_name: "Fatou")
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)

      def use_case
        CreateMessage.new(
          messages: Repositories::Communication::MessageRepository.new, attachments: Repositories::Communication::AttachmentStore.new,
          schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
          teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::PublishPolicy.new, clock: Clock.new(NOW)
        )
      end

      def create(user, **attributes)
        dto = Dtos::Communication::MessageInput.new(title: "Rentrée numérique", body: "Tout le monde en ligne lundi.",
                                                    illustration: "info", commit: "publish", **attributes)
        use_case.call(actor: user && actor(user), dto:)
      end

      def published_events = Orm::AuditEvent.where(action: "message.published")

      test "AN-01 — the team publishes now a national announcement for everyone, journaled with its author" do
        result = create(@fatou, scope: "national", audience: "all")

        assert result.success?
        message = Orm::Message.find(result.value.id)
        assert_equal [ "published", "all", nil, @fatou.id, NOW, NOW + 30.days ],
                     [ message.status, message.audience, message.school_id, message.author_id, message.published_at, message.ends_at ]
        assert_equal [ [ @fatou.id, "Message", message.id, NOW ] ], published_events.pluck(:actor_id, :subject_type, :subject_id, :created_at)
        assert_equal message.public_id, result.value.public_id
      end

      test "AN-02 — the team publishes for one school, chosen by its public_id, to its students" do
        result = create(@fatou, scope: "school", school_public_id: @lauriers.public_id, audience: "students")

        assert_equal [ @lauriers.id, "students" ], Orm::Message.find(result.value.id).values_at(:school_id, :audience)
      end

      test "the team is refused a school scope without a known school, and a national scope with one" do
        assert_equal :forbidden, create(@fatou, scope: "school", school_public_id: "inconnu", audience: "students").code
        assert_equal :forbidden, create(@fatou, scope: "school", audience: "students").code
        assert_equal :forbidden, create(@fatou, audience: "classrooms", classroom_public_ids: [ @b3.public_id ]).code
        assert_equal 0, Orm::Message.count
      end

      test "the national form of the team sends no scope: national by default" do
        assert_nil Orm::Message.find(create(@fatou, audience: "teachers").value.id).school_id
      end

      test "AN-03 — the direction publishes for its school: no scope nor school sent, its own" do
        result = create(@kamate, audience: "students", title: "Devoirs communs")

        assert_equal [ @lauriers.id, "students", "Devoirs communs" ], Orm::Message.find(result.value.id).values_at(:school_id, :audience, :title)
      end

      test "AN-04 — the direction sending for the Lycée de Bouaké, the national scope or « Tous » creates nothing" do
        [ { school_public_id: @bouake.public_id, audience: "students" }, { scope: "national", audience: "students" },
          { audience: "all" } ].each do |forged|
          assert_equal :forbidden, create(@kamate, **forged).code, forged.inspect
        end
        assert_equal 0, Orm::Message.count
        assert_equal 0, published_events.count
      end

      test "AN-05 — the teacher publishes for the 3ème B and the 3ème C, in his school" do
        result = create(@kouassi, title: "Nouvelles fiches", classroom_public_ids: [ "", @c3.public_id, @b3.public_id ])

        message = Orm::Message.find(result.value.id)
        assert_equal [ "classrooms", @lauriers.id ], [ message.audience, message.school_id ]
        assert_equal [ @b3.id, @c3.id ].sort, message.message_classrooms.pluck(:classroom_id).sort
        assert_equal [ @b3.id, @c3.id ].sort, result.value.classroom_ids
      end

      test "AN-06 — the teacher targeting the 3ème A, where he does not teach, creates nothing" do
        assert_equal :forbidden, create(@kouassi, classroom_public_ids: [ @b3.public_id, @a3.public_id ]).code
        assert_equal 0, Orm::Message.count
      end

      test "AN-06 — the teacher targeting no classroom creates nothing, and is asked to choose one" do
        result = create(@kouassi, classroom_public_ids: [ "" ], title: "a" * 61)

        assert_equal :invalid, result.code
        assert_equal({ title: [ "Le titre compte 60 caractères au plus." ], classroom_public_ids: [ "Choisis au moins une de tes classes." ] },
                     result.errors)
        assert_equal 0, Orm::Message.count
      end

      test "the teacher is refused an archived classroom, a classroom of another school and an unknown one" do
        archived = create_classroom(school: @lauriers, status: "archived")
        elsewhere = create_classroom(school: @bouake)
        Orm::TeacherClassroom.create!(teacher: @kouassi, classroom: archived)
        Orm::TeacherClassroom.create!(teacher: @kouassi, classroom: elsewhere)

        [ archived.public_id, elsewhere.public_id, "inconnue" ].each do |public_id|
          assert_equal :forbidden, create(@kouassi, classroom_public_ids: [ public_id ]).code, public_id
        end
        assert_equal :forbidden, create(@kouassi, audience: "students", classroom_public_ids: [ @b3.public_id ]).code
        assert_equal 0, Orm::Message.count
      end

      test "a student and a visitor write nothing" do
        assert_equal :forbidden, create(create_student(classroom: @b3), audience: "students").code
        assert_equal :forbidden, create(nil, audience: "students").code
        assert_equal 0, Orm::Message.count
      end

      test "an invalid form writes nothing and journals nothing" do
        result = create(@fatou, audience: "all", body: "", image: StringIO.new("%PDF-1.7".b))

        assert_equal :invalid, result.code
        assert_equal({ body: [ "Saisissez le texte de l'annonce." ], image: [ "Ce fichier n'est pas accepté." ] }, result.errors)
        assert_equal [ 0, 0, 0 ], [ Orm::Message.count, published_events.count, ActiveStorage::Attachment.count ]
      end

      test "a future date schedules the announcement, without journaling a publication" do
        result = create(@kamate, audience: "teachers", published_at: "2026-10-05T10:00", visible_until: "2026-10-20")

        message = Orm::Message.find(result.value.id)
        assert_equal [ "scheduled", Time.zone.local(2026, 10, 5, 10), Time.zone.local(2026, 10, 21) ],
                     [ message.status, message.published_at, message.ends_at ]
        assert_equal 0, published_events.count
      end

      test "a draft is saved without an end, nor a publication" do
        result = create(@kouassi, commit: "draft", classroom_public_ids: [ @b3.public_id ], body: "À relire.")

        message = Orm::Message.find(result.value.id)
        assert_equal [ "draft", nil, nil ], [ message.status, message.published_at, message.ends_at ]
        assert_equal 0, published_events.count
      end

      test "AN-18 — the image and the audio are stored with the type read in their content" do
        image = StringIO.new(file_fixture("photos/photo.png").binread)
        result = create(@kamate, audience: "students", image:, audio: StringIO.new(MP3))

        record = Orm::Message.find(result.value.id)
        assert_equal [ "image/png", "image.png" ], [ record.image.content_type, record.image.filename.to_s ]
        assert_equal [ "audio/mpeg", "audio.mp3", MP3 ], [ record.audio.content_type, record.audio.filename.to_s, record.audio.download ]
      end

      test "AN-18 — an audio of 12 MB is refused, and nothing is written" do
        result = create(@kamate, audience: "students", audio: StringIO.new(MP3 + ("\x00".b * (12 * 1024 * 1024))))

        assert_equal({ audio: [ "Ce fichier est trop lourd (10 Mo au plus)." ] }, result.errors)
        assert_equal 0, Orm::Message.count
      end
    end
  end
end
