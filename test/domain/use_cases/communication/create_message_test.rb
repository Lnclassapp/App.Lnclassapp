require "test_helper"

module UseCases
  module Communication
    # ADR-0078 §4.1, §4.2, §4.5 and §6: the team, a direction or a teacher writes an announcement: a draft, scheduled or
    # published now. The policy decides who writes for whom, on the values received, forged or not; nothing is written
    # when it refuses or when the form is invalid. On the real repositories: the constraints of the base answer too.
    # ADR-0081 §4.1 (annonces-v2): published now, it archives the oldest live ones of its author, under his lock, until
    # he has 3 live; the result names them. A theme, and a drawing of the team chosen by its public_id (§4.2, §4.3).
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

      # Says whether the transaction of the use case is open (AV-05).
      class SpyTransaction < Repositories::Shared::Transaction
        attr_reader :open

        def call(&)
          @open = true
          super
        ensure
          @open = false
        end
      end

      # Records each call to the repository, and whether the transaction is open: the order of the calls is all a spy
      # proves. The lock itself is proven on two connections (message_publication_concurrency_test.rb).
      class WatchedMessages < SimpleDelegator
        attr_reader :calls

        def initialize(repository, transaction)
          super(repository)
          @transaction = transaction
          @calls = []
        end

        def live_of(**) = watched(:lock) { __getobj__.live_of(**) }
        def update(message:) = watched(message.status) { __getobj__.update(message:) }
        def create(message:) = watched(:create) { __getobj__.create(message:) }

        private

        def watched(call) = yield.tap { @calls << [ call, @transaction.open == true ] }
      end

      def use_case(messages: Repositories::Communication::MessageRepository.new, transaction: Repositories::Shared::Transaction.new,
                   attachments: Repositories::Communication::AttachmentStore.new)
        CreateMessage.new(
          messages:, attachments:,
          schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
          teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          illustrations: Repositories::Communication::IllustrationRepository.new, transaction:,
          policy: Policies::Communication::PublishPolicy.new, clock: Clock.new(NOW)
        )
      end

      def create(user, messages: Repositories::Communication::MessageRepository.new, transaction: Repositories::Shared::Transaction.new,
                 attachments: Repositories::Communication::AttachmentStore.new, **attributes)
        dto = Dtos::Communication::MessageInput.new(title: "Rentrée numérique", body: "Tout le monde en ligne lundi.",
                                                    illustration: "info", commit: "publish", **attributes)
        use_case(messages:, transaction:, attachments:).call(actor: user && actor(user), dto:)
      end

      # A storage that fails on each file it receives, after the cap has archived (test analysis of phase 5, 2.1).
      class FailingAttachments < Repositories::Communication::AttachmentStore
        Down = Class.new(StandardError)

        def attach(**) = raise(Down, "le stockage ne répond pas")
      end

      # Three live announcements of the direction, published on September 25th, 27th and 29th (the oldest first).
      def three_live(author = @kamate)
        [ 25, 27, 29 ].map do |day|
          create_message(author:, title: "Du #{day} septembre", school: @lauriers, published_at: Time.zone.local(2026, 9, day, 8))
        end
      end

      def statuses(records) = records.map { it.reload.status }

      def published_events = Orm::AuditEvent.where(action: "message.published")

      test "AN-01 — the team publishes now a national announcement for everyone, journaled with its author" do
        result = create(@fatou, scope: "national", audience: "all")

        assert result.success?
        message = Orm::Message.find(result.value.message.id)
        assert_equal [ "published", "all", nil, @fatou.id, NOW, NOW + 30.days, "ciel", "info", nil ],
                     [ message.status, message.audience, message.school_id, message.author_id, message.published_at, message.ends_at,
                       message.theme, message.illustration, message.illustration_id ]
        assert_equal [ [ @fatou.id, "Message", message.id, NOW ] ], published_events.pluck(:actor_id, :subject_type, :subject_id, :created_at)
        assert_equal [ message.public_id, [] ], [ result.value.message.public_id, result.value.archived ]
      end

      test "AN-02 — the team publishes for one school, chosen by its public_id, to its students" do
        result = create(@fatou, scope: "school", school_public_id: @lauriers.public_id, audience: "students")

        assert_equal [ @lauriers.id, "students" ], Orm::Message.find(result.value.message.id).values_at(:school_id, :audience)
      end

      test "the team is refused a school scope without a known school, and a national scope with one" do
        assert_equal :forbidden, create(@fatou, scope: "school", school_public_id: "inconnu", audience: "students").code
        assert_equal :forbidden, create(@fatou, scope: "school", audience: "students").code
        assert_equal :forbidden, create(@fatou, audience: "classrooms", classroom_public_ids: [ @b3.public_id ]).code
        assert_equal 0, Orm::Message.count
      end

      test "the national form of the team sends no scope: national by default" do
        assert_nil Orm::Message.find(create(@fatou, audience: "teachers").value.message.id).school_id
      end

      test "AN-03 — the direction publishes for its school: no scope nor school sent, its own" do
        result = create(@kamate, audience: "students", title: "Devoirs communs")

        assert_equal [ @lauriers.id, "students", "Devoirs communs" ], Orm::Message.find(result.value.message.id).values_at(:school_id, :audience, :title)
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

        message = Orm::Message.find(result.value.message.id)
        assert_equal [ "classrooms", @lauriers.id ], [ message.audience, message.school_id ]
        assert_equal [ @b3.id, @c3.id ].sort, message.message_classrooms.pluck(:classroom_id).sort
        assert_equal [ @b3.id, @c3.id ].sort, result.value.message.classroom_ids
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

      test "a direction or the team sending no audience is refused: only the teacher has a default one, his classrooms" do
        assert_equal :forbidden, create(@kamate).code
        assert_equal :forbidden, create(@fatou, scope: "national").code
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

      test "AV-02 — a future date schedules the announcement, ending 30 days after it, without journaling a publication" do
        result = create(@kamate, audience: "teachers", published_at: "2026-10-05T10:00")

        message = Orm::Message.find(result.value.message.id)
        assert_equal [ "scheduled", Time.zone.local(2026, 10, 5, 10), Time.zone.local(2026, 11, 4, 10) ],
                     [ message.status, message.published_at, message.ends_at ]
        assert_equal 0, published_events.count
      end

      test "a draft is saved without an end, nor a publication" do
        result = create(@kouassi, commit: "draft", classroom_public_ids: [ @b3.public_id ], body: "À relire.")

        message = Orm::Message.find(result.value.message.id)
        assert_equal [ "draft", nil, nil ], [ message.status, message.published_at, message.ends_at ]
        assert_equal 0, published_events.count
      end

      test "AN-18 — the image and the audio are stored with the type read in their content" do
        image = StringIO.new(file_fixture("photos/photo.png").binread)
        result = create(@kamate, audience: "students", image:, audio: StringIO.new(MP3))

        record = Orm::Message.find(result.value.message.id)
        assert_equal [ "image/png", "image.png" ], [ record.image.content_type, record.image.filename.to_s ]
        assert_equal [ "audio/mpeg", "audio.mp3", MP3 ], [ record.audio.content_type, record.audio.filename.to_s, record.audio.download ]
      end

      test "AN-18 — an audio of 12 MB is refused, and nothing is written" do
        result = create(@kamate, audience: "students", audio: StringIO.new(MP3 + ("\x00".b * (12 * 1024 * 1024))))

        assert_equal({ audio: [ "Ce fichier est trop lourd (10 Mo au plus)." ] }, result.errors)
        assert_equal 0, Orm::Message.count
      end

      test "AV-03 — a 4th announcement published now archives the oldest live one, in its transaction; the result names it" do
        live = three_live
        colleague = create_school_admin(school: @lauriers)
        others = [ create_message(author: colleague, school: @lauriers, published_at: Time.zone.local(2026, 9, 20, 8)),
                   create_message(author: @kouassi, audience: "classrooms", classrooms: [ @b3 ], published_at: Time.zone.local(2026, 9, 21, 8)),
                   create_message(author: @fatou, audience: "all", published_at: Time.zone.local(2026, 9, 22, 8)) ]

        result = create(@kamate, audience: "students", title: "Sortie au musée")

        assert_equal [ "archived", "published", "published" ], statuses(live)
        assert_equal [ live.first.public_id ], result.value.archived.map(&:public_id)
        assert_equal [ "archived", "Du 25 septembre" ], result.value.archived.first.then { [ it.status, it.title ] }
        assert_equal 3, Orm::Message.where(author: @kamate, status: "published").count
        assert_equal %w[published published published], statuses(others), "un collègue, un enseignant ou l'équipe : intouchés"
        assert_equal [ [ @kamate.id, result.value.message.id ] ], published_events.pluck(:actor_id, :subject_id), "l'archivage n'est pas journalisé"
      end

      # Phase 5 (test analysis 2.1), on the real base: the archiving by the cap, the announcement and its journal are
      # written in one transaction, which the failure of its file undoes entirely.
      test "AV-03 — a publication whose file cannot be stored writes nothing: the oldest live one stays live" do
        live = three_live

        assert_raises(FailingAttachments::Down) do
          create(@kamate, audience: "students", audio: StringIO.new(MP3), attachments: FailingAttachments.new)
        end
        assert_equal %w[published published published], statuses(live)
        assert_equal [ 3, 0, 0 ], [ Orm::Message.where(author: @kamate).count, published_events.count, ActiveStorage::Blob.count ]
      end

      test "AV-04 — 2 live, 1 scheduled, 1 draft, 1 archived, 1 withdrawn and 1 ended: publishing archives nothing" do
        counted = [ 25, 27 ].map { create_message(author: @kamate, school: @lauriers, published_at: Time.zone.local(2026, 9, it, 8)) }
        ignored = [ create_message(author: @kamate, status: "scheduled", school: @lauriers, published_at: Time.zone.local(2026, 10, 2, 8)),
                    create_message(author: @kamate, status: "draft", school: @lauriers, published_at: nil),
                    create_message(author: @kamate, status: "archived", school: @lauriers),
                    create_message(author: @kamate, status: "withdrawn", school: @lauriers),
                    create_message(author: @kamate, school: @lauriers, published_at: Time.zone.local(2026, 8, 1, 8),
                                   ends_at: Time.zone.local(2026, 8, 31, 8)) ]

        result = create(@kamate, audience: "students")

        assert_equal [], result.value.archived
        assert_equal %w[published published], statuses(counted)
        assert_equal %w[scheduled draft archived withdrawn published], statuses(ignored)
      end

      test "AV-03 — a draft or a scheduled announcement is not a publication: nothing is archived" do
        live = three_live

        assert_equal [], create(@kamate, audience: "students", commit: "draft").value.archived
        assert_equal [], create(@kamate, audience: "students", published_at: "2026-10-05T10:00").value.archived
        assert_equal %w[published published published], statuses(live)
      end

      test "AV-03 — a refused publication archives nothing" do
        live = three_live

        assert_equal :invalid, create(@kamate, audience: "students", title: "").code
        assert_equal :forbidden, create(@kamate, audience: "all").code
        assert_equal %w[published published published], statuses(live)
      end

      test "AV-05 — in the transaction of the publication: the author locked first, then the oldest archived, then the creation" do
        three_live
        transaction = SpyTransaction.new
        messages = WatchedMessages.new(Repositories::Communication::MessageRepository.new, transaction)

        create(@kamate, audience: "students", messages:, transaction:)

        assert_equal [ [ :lock, true ], [ "archived", true ], [ :create, true ] ], messages.calls
      end

      test "AV-07 — the theme chosen is written; an unknown one is refused, and nothing is written" do
        result = create(@kamate, audience: "students", theme: "mangue")

        assert_equal "mangue", Orm::Message.find(result.value.message.id).theme
        assert_equal({ theme: [ "Choisissez un thème de la liste." ] }, create(@kamate, audience: "students", theme: "rose").errors)
        assert_equal 1, Orm::Message.count
      end

      test "AV-08 — a drawing of the team, chosen by its public_id, is written as the illustration of the announcement" do
        bus = create_illustration(name: "Bus scolaire", created_by: @fatou)

        result = create(@kamate, audience: "students", illustration: bus.public_id)

        message = Orm::Message.find(result.value.message.id)
        assert_equal [ nil, bus.id ], [ message.illustration, message.illustration_id ]
        assert_equal bus.id, result.value.message.illustration_id
      end

      test "AV-10 — a retired drawing or an unknown public_id is refused under « Illustration », and nothing is written" do
        retired = create_illustration(name: "Bus scolaire", created_by: @fatou, retired_at: 1.day.ago)

        [ retired.public_id, "Bq7xK2mN9pR4sT" ].each do |forged|
          result = create(@kamate, audience: "students", illustration: forged, title: "")

          assert_equal :invalid, result.code, forged
          assert_equal({ title: [ "Saisissez un titre." ], illustration: [ "Choisissez une illustration de la bibliothèque." ] },
                       result.errors, forged)
        end
        assert_equal 0, Orm::Message.count
      end
    end

    # ADR-0081 §4.1 (AV-05): two publications of the same author at the same instant, through the use case, on two
    # connections. Outside any test transaction: each thread sees what the other one committed. The first one keeps the
    # author's lock until the second one waits on it: their order is the lock's, never a sleep's.
    class CreateMessageConcurrencyTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      # Says when it holds the author's lock, and keeps it until the test releases it: without the lock, the second
      # publication would read the same 3 live and never wait.
      class Holding < Repositories::Communication::MessageRepository
        def initialize(held:, release:)
          super()
          @held = held
          @release = release
        end

        def live_of(author_id:, now:)
          super.tap do
            @held << true
            @release.pop(timeout: 10)
          end
        end
      end

      setup do
        @now = Time.current.change(usec: 0)
        @fatou = create_team_member(second_factor: false)
        @live = [ 5, 3, 1 ].map { create_message(author: @fatou, audience: "all", title: "#{it} jours", published_at: @now - it.days) }
      end

      teardown do
        Orm::AuditEvent.where(actor_id: @fatou.id).delete_all
        Orm::Message.where(author_id: @fatou.id).delete_all
        Orm::User.where(id: @fatou.id).delete_all
      end

      # backend : a queue that receives the pid of the connection, when given.
      def publish(title, messages: Repositories::Communication::MessageRepository.new, backend: nil)
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          backend&.push(connection.select_value("SELECT pg_backend_pid()"))
          CreateMessage.new(
            messages:, attachments: Repositories::Communication::AttachmentStore.new,
            schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
            teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
            illustrations: Repositories::Communication::IllustrationRepository.new, transaction: Repositories::Shared::Transaction.new,
            policy: Policies::Communication::PublishPolicy.new, clock: Data.define(:now).new(@now)
          ).call(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: @fatou.id),
                 dto: Dtos::Communication::MessageInput.new(title:, body: "Le texte.", illustration: "info", audience: "all",
                                                            commit: "publish"))
        end
      end

      # Uncached: the query cache of the test would give the first answer again.
      def waiting?(pid)
        Orm::Message.uncached do
          Orm::Message.connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_locks WHERE pid = #{Integer(pid)} AND NOT granted)")
        end
      end

      test "AV-05 — two publications of the same author at the same instant: 3 live after both, never 4" do
        held = Queue.new
        release = Queue.new
        backend = Queue.new
        threads = [ Thread.new { publish("Première", messages: Holding.new(held:, release:)) } ]
        assert held.pop(timeout: 5), "la première publication ne lit pas les annonces en ligne de son auteur"
        threads << Thread.new { publish("Seconde", backend:) }
        pid = backend.pop(timeout: 5)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until !threads.last.alive? || waiting?(pid)
          flunk "la seconde publication n'attend pas le verrou de l'auteur" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.01
        end
        release << true
        results = threads.map(&:value)

        assert results.all?(&:success?)
        assert_equal [ [ @live[0].public_id ], [ @live[1].public_id ] ], results.map { it.value.archived.map(&:public_id) }
        assert_equal [ "1 jours", "Première", "Seconde" ],
                     Orm::Message.where(author_id: @fatou.id, status: "published").order(:id).pluck(:title)
      ensure
        release << true
        threads&.each { it.join(10) }
      end
    end
  end
end
