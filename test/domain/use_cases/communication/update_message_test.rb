require "test_helper"

module UseCases
  module Communication
    # ADR-0078 §4.1, §4.2 and §6: only its author modifies an announcement. Published, it keeps its date of publication,
    # is marked edited and comes back to those who had dismissed it, in the same transaction. A draft or a scheduled one
    # can be published or rescheduled. Archived or withdrawn, it is frozen.
    class UpdateMessageTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 3, 9)
      Clock = Data.define(:now)
      MP3 = ("ID3".b + ("\x00".b * 64)).freeze

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

      def use_case
        UpdateMessage.new(
          messages: Repositories::Communication::MessageRepository.new, attachments: Repositories::Communication::AttachmentStore.new,
          schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
          teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::ManageOwnPolicy.new,
          publish_policy: Policies::Communication::PublishPolicy.new, clock: Clock.new(NOW)
        )
      end

      def update(user, message = @fiches, **attributes)
        dto = Dtos::Communication::MessageInput.new(title: message.title, body: "Les fiches du chapitre 4 sont en ligne.",
                                                    illustration: "sheets", classroom_public_ids: [ @b3.public_id ],
                                                    commit: "publish", **attributes)
        use_case.call(actor: actor(user), public_id: message.public_id, dto:)
      end

      def published_events = Orm::AuditEvent.where(action: "message.published")

      test "AN-14 — a published announcement modified comes back to those who dismissed it, marked edited" do
        dismiss_message(message: @fiches, user: @awa)

        result = update(@kouassi, visible_until: "2026-11-15", classroom_public_ids: [ @b3.public_id, @c3.public_id ])

        assert result.success?
        @fiches.reload
        assert_equal [ "published", Time.zone.local(2026, 10, 1, 8), NOW, Time.zone.local(2026, 11, 16) ],
                     [ @fiches.status, @fiches.published_at, @fiches.edited_at, @fiches.ends_at ]
        assert_equal "Les fiches du chapitre 4 sont en ligne.", @fiches.body
        assert_equal [ @b3.id, @c3.id ].sort, @fiches.message_classrooms.pluck(:classroom_id).sort
        assert_not Orm::MessageDismissal.exists?(message_id: @fiches.id)
        assert_equal NOW, result.value.edited_at
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
        assert_nil result.value.edited_at
      end

      test "a scheduled announcement is rescheduled, or kept as a draft" do
        scheduled = create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 10, 8))

        update(@kamate, scheduled, audience: "students", classroom_public_ids: [], published_at: "2026-10-12T07:30")
        assert_equal [ "scheduled", Time.zone.local(2026, 10, 12, 7, 30) ], scheduled.reload.values_at(:status, :published_at)

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
    end
  end
end
