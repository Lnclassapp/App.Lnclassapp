require "test_helper"

module UseCases
  module Communication
    # ADR-0078 §4.1, §4.2 and §6: only its author modifies an announcement. Published, it keeps its date of publication,
    # is marked edited and comes back to those who had dismissed it, in the same transaction. A draft or a scheduled one
    # can be published or rescheduled. Archived or withdrawn, it is frozen. ADR-0081 §4.1 (annonces-v2): a published
    # one keeps its end and archives nothing; a draft or a scheduled one published by its author archives the oldest
    # live ones of the author, in the same transaction, and the result names them.
    class UpdateMessageTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 3, 9)
      Clock = Data.define(:now)
      MP3 = ("ID3".b + ("\x00".b * 64)).freeze

      # Reads the announcement, then lets another request change it before the use case writes (ADR-0078 §4.2).
      class Racing < SimpleDelegator
        def initialize(repository, &race) = super(repository).tap { @race = race }
        def find_by_public_id(public_id:) = __getobj__.find_by_public_id(public_id:).tap { @race.call }
      end

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers")
        @b3 = create_classroom(school: @lauriers, name: "3ème B")
        @c3 = create_classroom(school: @lauriers, name: "3ème C")
        @a3 = create_classroom(school: @lauriers, name: "3ème A")
        @kouassi = create_teacher(school: @lauriers, classrooms: [ @b3, @c3 ], last_name: "Kouassi")
        @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
        @fiches = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ],
                                 published_at: Time.zone.local(2026, 10, 1, 8), ends_at: Time.zone.local(2026, 10, 31))
        @awa = create_student(classroom: @b3, first_name: "Awa")
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)

      # Records, at each call of live_of, whether the transaction of the use case is open (AV-05).
      class SpyTransaction < Repositories::Shared::Transaction
        attr_reader :open

        def call(&)
          @open = true
          super
        ensure
          @open = false
        end
      end

      class WatchedMessages < SimpleDelegator
        attr_reader :live_of_calls

        def initialize(repository, transaction) = super(repository).tap { @transaction = transaction }
        def live_of(**) = __getobj__.live_of(**).tap { (@live_of_calls ||= []) << @transaction.open }
      end

      def use_case(messages: Repositories::Communication::MessageRepository.new, transaction: Repositories::Shared::Transaction.new)
        UpdateMessage.new(
          messages:, attachments: Repositories::Communication::AttachmentStore.new,
          schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
          teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          illustrations: Repositories::Communication::IllustrationRepository.new, transaction:,
          policy: Policies::Communication::ManageOwnPolicy.new, publish_policy: Policies::Communication::PublishPolicy.new,
          clock: Clock.new(NOW)
        )
      end

      def update(user, message = @fiches, messages: Repositories::Communication::MessageRepository.new,
                 transaction: Repositories::Shared::Transaction.new, **attributes)
        dto = Dtos::Communication::MessageInput.new(title: message.title, body: "Les fiches du chapitre 4 sont en ligne.",
                                                    illustration: "sheets", classroom_public_ids: [ @b3.public_id ],
                                                    commit: "publish", **attributes)
        use_case(messages:, transaction:).call(actor: actor(user), public_id: message.public_id, dto:)
      end

      # Three live announcements of the direction, published on September 25th, 27th and 29th (the oldest first).
      def three_live(author = @kamate)
        [ 25, 27, 29 ].map do |day|
          create_message(author:, title: "Du #{day} septembre", school: @lauriers, published_at: Time.zone.local(2026, 9, day, 8))
        end
      end

      def statuses(records) = records.map { it.reload.status }

      test "ADR-0078 §4.2 — withdrawn while its author was saving it, the announcement stays withdrawn: conflict" do
        dismiss_message(message: @fiches, user: @awa)
        team = create_team_member(second_factor: false)
        racing = Racing.new(Repositories::Communication::MessageRepository.new) do
          Orm::Message.where(id: @fiches.id).update_all(status: "withdrawn", withdrawn_at: NOW, withdrawn_by_id: team.id)
        end

        assert_equal :conflict, update(@kouassi, messages: racing).code
        assert_equal [ "withdrawn", "Ils commencent lundi.", nil ], @fiches.reload.values_at(:status, :body, :edited_at)
        assert Orm::MessageDismissal.exists?(message: @fiches, user: @awa)
      end

      def published_events = Orm::AuditEvent.where(action: "message.published")

      test "AN-14, AV-02 — a published announcement modified comes back to those who dismissed it, marked edited, its end kept" do
        dismiss_message(message: @fiches, user: @awa)

        result = update(@kouassi, classroom_public_ids: [ @b3.public_id, @c3.public_id ])

        assert result.success?
        @fiches.reload
        assert_equal [ "published", Time.zone.local(2026, 10, 1, 8), NOW, Time.zone.local(2026, 10, 31) ],
                     [ @fiches.status, @fiches.published_at, @fiches.edited_at, @fiches.ends_at ]
        assert_equal "Les fiches du chapitre 4 sont en ligne.", @fiches.body
        assert_equal [ @b3.id, @c3.id ].sort, @fiches.message_classrooms.pluck(:classroom_id).sort
        assert_not Orm::MessageDismissal.exists?(message_id: @fiches.id)
        assert_equal [ NOW, [] ], [ result.value.message.edited_at, result.value.archived ]
        assert_equal 0, published_events.count, "une modification n'est pas une nouvelle publication"
      end

      test "a published announcement cannot go back to draft, and its date of publication is not asked again" do
        update(@kouassi, commit: "draft", published_at: "2026-12-01T08:00")

        assert_equal [ "published", Time.zone.local(2026, 10, 1, 8) ], @fiches.reload.values_at(:status, :published_at)
      end

      test "AN-15 — another teacher, a direction of the same school and the team receive not_found; nothing changes" do
        [ create_teacher(school: @lauriers, classrooms: [ @b3 ]), @kamate, create_team_member(second_factor: false) ].each do |other|
          assert_equal :not_found, update(other).code, other.role
        end
        assert_equal [ "Ils commencent lundi.", nil ], @fiches.reload.values_at(:body, :edited_at)
      end

      test "an unknown announcement is not_found" do
        assert_equal :not_found, use_case.call(actor: actor(@kouassi), public_id: "inconnue", dto: Dtos::Communication::MessageInput.new).code
      end

      test "AN-19 — archived or withdrawn, the announcement is frozen: neither modified nor republished" do
        archived = create_message(author: @kamate, status: "archived")
        withdrawn = create_message(author: @kouassi, audience: "classrooms", classrooms: [ @b3 ], status: "withdrawn")

        assert_equal :conflict, update(@kamate, archived, audience: "students", classroom_public_ids: []).code
        assert_equal :conflict, update(@kouassi, withdrawn).code
        assert_equal [ "archived", "withdrawn" ], [ archived.reload.status, withdrawn.reload.status ]
      end

      test "a forged classroom on modification is refused, and nothing changes" do
        assert_equal :forbidden, update(@kouassi, classroom_public_ids: [ @a3.public_id ]).code
        assert_equal [ @b3.id ], @fiches.reload.message_classrooms.pluck(:classroom_id)
      end

      test "an invalid modification changes nothing" do
        result = update(@kouassi, title: "", classroom_public_ids: [])

        assert_equal :invalid, result.code
        assert_equal [ :title, :classroom_public_ids ], result.errors.keys
        assert_equal "Nouvelles fiches", @fiches.reload.title
      end

      test "a draft published now: published from now on, journaled once, with no mark of modification" do
        draft = create_message(author: @kamate, status: "draft", published_at: nil)

        result = update(@kamate, draft, audience: "teachers", classroom_public_ids: [])

        assert_equal [ "published", NOW, NOW + 30.days, nil ], draft.reload.values_at(:status, :published_at, :ends_at, :edited_at)
        assert_equal [ [ @kamate.id, draft.id ] ], published_events.pluck(:actor_id, :subject_id)
        assert_nil result.value.message.edited_at
      end

      test "a scheduled announcement is rescheduled, or kept as a draft" do
        scheduled = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 10, 8))

        update(@kamate, scheduled, audience: "students", classroom_public_ids: [], published_at: "2026-10-12T07:30")
        assert_equal [ "scheduled", Time.zone.local(2026, 10, 12, 7, 30), Time.zone.local(2026, 11, 11, 7, 30) ],
                     scheduled.reload.values_at(:status, :published_at, :ends_at)

        update(@kamate, scheduled, audience: "students", classroom_public_ids: [], commit: "draft", published_at: "")
        assert_equal [ "draft", nil, nil ], scheduled.reload.values_at(:status, :published_at, :ends_at)
        assert_equal 0, published_events.count
      end

      test "the image is replaced or removed, the audio added, in the same modification" do
        store = Repositories::Communication::AttachmentStore.new
        store.attach(message_id: @fiches.id, kind: :image, io: StringIO.new(file_fixture("photos/photo.png").binread),
                     content_type: "image/png", filename: "image.png")

        update(@kouassi, image: StringIO.new(file_fixture("photos/photo.jpg").binread), audio: StringIO.new(MP3), remove_audio: "1")
        assert_equal [ "image/jpeg", "audio/mpeg" ], [ @fiches.reload.image.content_type, @fiches.audio.content_type ]

        update(@kouassi, remove_image: "1")
        assert_not @fiches.reload.image.attached?
        assert @fiches.audio.attached?
      end

      test "AV-03 — a draft published by its author archives the oldest live one, in its transaction; the result names it" do
        live = three_live
        draft = create_message(author: @kamate, title: "Sortie au musée", status: "draft", published_at: nil, school: @lauriers)

        result = update(@kamate, draft, audience: "students", classroom_public_ids: [])

        assert_equal [ "archived", "published", "published" ], statuses(live)
        assert_equal [ [ live.first.public_id, "archived" ] ], result.value.archived.map { [ it.public_id, it.status ] }
        assert_equal "published", draft.reload.status
        assert_equal 3, Orm::Message.where(author: @kamate, status: "published").count
      end

      test "AV-03 — a scheduled announcement its author publishes now archives the oldest live one" do
        live = three_live
        scheduled = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 10, 8), school: @lauriers)

        result = update(@kamate, scheduled, audience: "students", classroom_public_ids: [], published_at: "")

        assert_equal [ live.first.public_id ], result.value.archived.map(&:public_id)
        assert_equal "published", scheduled.reload.status
      end

      test "AV-04 — modifying a published announcement, rescheduling or keeping a draft archives nothing" do
        live = three_live
        scheduled = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 10, 8), school: @lauriers)
        draft = create_message(author: @kamate, status: "draft", published_at: nil, school: @lauriers)

        results = [ update(@kamate, live.last, audience: "students", classroom_public_ids: []),
                    update(@kamate, scheduled, audience: "students", classroom_public_ids: [], published_at: "2026-10-12T07:30"),
                    update(@kamate, draft, audience: "students", classroom_public_ids: [], commit: "draft") ]

        assert_equal [ [], [], [] ], results.map { it.value.archived }
        assert_equal %w[published published published], statuses(live)
      end

      test "AV-03 — a draft archived while its author was publishing it: conflict, and no live announcement is archived" do
        live = three_live
        draft = create_message(author: @kamate, status: "draft", published_at: nil, school: @lauriers)
        racing = Racing.new(Repositories::Communication::MessageRepository.new) do
          Orm::Message.where(id: draft.id).update_all(status: "archived")
        end

        assert_equal :conflict, update(@kamate, draft, audience: "students", classroom_public_ids: [], messages: racing).code
        assert_equal %w[published published published], statuses(live)
        assert_equal 0, published_events.count
      end

      test "AV-05 — the live announcements of the author are read inside the transaction of the publication" do
        three_live
        draft = create_message(author: @kamate, status: "draft", published_at: nil, school: @lauriers)
        transaction = SpyTransaction.new
        messages = WatchedMessages.new(Repositories::Communication::MessageRepository.new, transaction)

        update(@kamate, draft, audience: "students", classroom_public_ids: [], messages:, transaction:)

        assert_equal [ true ], messages.live_of_calls
      end

      test "AV-07 — the theme is changed; an unknown one is refused, and nothing changes" do
        update(@kouassi, theme: "nuit")
        assert_equal "nuit", @fiches.reload.theme

        assert_equal({ theme: [ "Choisissez un thème de la liste." ] }, update(@kouassi, theme: "rose", body: "Piraté.").errors)
        assert_equal [ "nuit", "Les fiches du chapitre 4 sont en ligne." ], @fiches.reload.values_at(:theme, :body)
      end

      test "AV-08 — a drawing of the team replaces the base illustration, and the other way round" do
        bus = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false))

        update(@kouassi, illustration: bus.public_id)
        assert_equal [ nil, bus.id ], @fiches.reload.values_at(:illustration, :illustration_id)

        update(@kouassi, illustration: "exam")
        assert_equal [ "exam", nil ], @fiches.reload.values_at(:illustration, :illustration_id)
      end

      test "AV-10 — a retired drawing chosen by a forged form is refused under « Illustration »; nothing changes" do
        retired = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false), retired_at: 1.day.ago)

        result = update(@kouassi, illustration: retired.public_id, body: "Piraté.")

        assert_equal [ :invalid, { illustration: [ "Choisissez une illustration de la bibliothèque." ] } ], [ result.code, result.errors ]
        assert_equal [ "info", nil, "Ils commencent lundi." ], @fiches.reload.values_at(:illustration, :illustration_id, :body)
      end

      # Decision of the orchestrator (annonces-v2, Lot E): the drawing an announcement carries stays served until its end
      # (AV-10), so a modification keeps it even once retired; only choosing a retired drawing anew is refused.
      test "AV-10 — a modified announcement keeps its drawing of the team retired since; choosing another retired one is refused" do
        fatou = create_team_member(second_factor: false)
        bus = create_illustration(name: "Bus scolaire", created_by: fatou)
        cantine = create_illustration(name: "Cantine", created_by: fatou, retired_at: 1.day.ago)
        @fiches.update!(illustration: nil, library_illustration: bus)
        draft = create_message(author: @kouassi, status: "draft", published_at: nil, illustration: bus, audience: "classrooms",
                               classrooms: [ @b3 ])
        bus.update!(retired_at: 1.hour.ago)

        assert update(@kouassi, illustration: bus.public_id, body: "Gardée.").success?
        assert_equal [ nil, bus.id, "Gardée." ], @fiches.reload.values_at(:illustration, :illustration_id, :body)
        assert update(@kouassi, draft, illustration: bus.public_id).success?
        assert_equal [ "published", bus.id ], draft.reload.values_at(:status, :illustration_id)

        result = update(@kouassi, illustration: cantine.public_id, body: "Piraté.")

        assert_equal [ :invalid, { illustration: [ "Choisissez une illustration de la bibliothèque." ] } ], [ result.code, result.errors ]
        assert_equal [ bus.id, "Gardée." ], @fiches.reload.values_at(:illustration_id, :body)
      end

      test "AV-10 — an announcement carrying a retired drawing cannot choose an unknown one, nor its own once it has left it" do
        bus = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false))
        @fiches.update!(illustration: nil, library_illustration: bus)
        bus.update!(retired_at: 1.hour.ago)
        refused = [ :invalid, { illustration: [ "Choisissez une illustration de la bibliothèque." ] } ]

        result = update(@kouassi, illustration: "Bq7xK2mN9pR4sT")
        assert_equal refused, [ result.code, result.errors ]
        assert update(@kouassi, illustration: "exam").success?
        result = update(@kouassi, illustration: bus.public_id)

        assert_equal refused, [ result.code, result.errors ]
        assert_equal [ "exam", nil ], @fiches.reload.values_at(:illustration, :illustration_id)
      end
    end
  end
end
