require "test_helper"

# AN-16, AN-17, ADR-0078 §4.2 and §4.5, UDR-0071 §3.7: the team withdraws any announcement of another author, a direction
# those of the teachers of its school. In Turbo Stream, the line leaves the list and a toast says « Annonce retirée. »;
# without Turbo, back to the list with the toast. The announcement disappears for its audience, files included, and its
# author sees it « Retirée », frozen. Outside the right, or once frozen, the answer is 404 and nothing is written.
module Communication
  class MessageWithdrawalsControllerTest < ActionDispatch::IntegrationTest
    NOW = Time.zone.local(2026, 10, 4, 12)
    MP3 = ("ID3".b + ("\x00".b * 64)).freeze

    setup do
      travel_to NOW
      @lauriers = create_school(name: "Collège Les Lauriers")
      @bouake = create_school(name: "Lycée de Bouaké")
      @b3 = create_classroom(school: @lauriers, name: "3ème B")
      @awa = create_student(classroom: @b3, first_name: "Awa")
      @kouassi = create_teacher(school: @lauriers, material: create_material(name: "SVT"), classrooms: [ @b3 ], gender: "male",
                                last_name: "Kouassi")
      @kamate = create_school_admin(school: @lauriers, gender: "female", last_name: "Kamaté")
      @fatou = create_team_member(first_name: "Fatou")
      @fiches = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ],
                               published_at: 1.day.ago)
      Repositories::Communication::AttachmentStore.new.attach(message_id: @fiches.id, kind: :audio, io: StringIO.new(MP3),
                                                              content_type: "audio/mpeg", filename: "fiches.mp3")
    end

    def withdraw(message = @fiches, **) = post(announcement_withdrawal_path(message.public_id), **)
    def streams = css_select("turbo-stream").map { [ it["action"], it["target"] ] }
    def withdrawn_events = Orm::AuditEvent.where(action: "message.withdrawn")

    test "AN-16 — Fatou withdraws « Nouvelles fiches »: the line leaves « Toutes », a toast says « Annonce retirée. »" do
      sign_in_as @fatou

      withdraw(as: :turbo_stream)

      assert_response :success
      assert_equal [ [ "remove", "moderated_announcement_#{@fiches.public_id}" ], %w[append toasts] ], streams
      assert_select "turbo-stream[target=toasts] template", text: /Annonce retirée\./
      assert_equal [ "withdrawn", NOW, @fatou.id ], @fiches.reload.values_at(:status, :withdrawn_at, :withdrawn_by_id)
      assert_equal [ [ @fatou.id, @fiches.id, { "author_id" => @kouassi.id } ] ], withdrawn_events.pluck(:actor_id, :subject_id, :metadata)
    end

    test "AN-16 — withdrawn, no student reads it nor its audio; M. Kouassi sees it « Retirée » and can neither modify nor republish it" do
      sign_in_as @awa
      get announcements_path
      assert_select "#announcement_#{@fiches.public_id}"
      sign_out
      sign_in_as @fatou
      withdraw(as: :turbo_stream)
      sign_out

      sign_in_as @awa
      get announcements_path
      assert_select "#announcement_#{@fiches.public_id}", 0
      get announcement_file_path(@fiches.public_id, kind: "audio")
      assert_response :not_found
      sign_out

      sign_in_as @kouassi
      get my_announcements_path
      assert_select "li#my_announcement_#{@fiches.public_id}" do
        assert_select "span.ui-badge", text: "Retirée"
        assert_select "p.text-mute", text: /Retirée le 4 oct\./
        assert_select "[role=menu]", 0
      end
      get edit_announcement_path(@fiches.public_id)
      assert_redirected_to my_announcements_path
      patch announcement_path(@fiches.public_id),
            params: { announcement: { title: "Republiée", body: "Lundi.", illustration: "info", classroom_public_ids: [ @b3.public_id ],
                                      visible_until: "2026-11-02" }, commit: "publish" }
      assert_redirected_to my_announcements_path
      assert_equal "Cette annonce est archivée ou retirée : elle ne peut plus être modifiée.", flash[:alert]
      post announcement_archive_path(@fiches.public_id)
      assert_equal "Cette annonce est déjà archivée ou retirée.", flash[:alert]
      assert_equal [ "withdrawn", "Nouvelles fiches" ], @fiches.reload.values_at(:status, :title)
    end

    test "AN-16 — without Turbo, back to « Toutes », with the toast from the flash" do
      sign_in_as @fatou

      withdraw

      assert_redirected_to moderated_announcements_path
      assert_equal "Annonce retirée.", flash[:notice]
      follow_redirect!
      assert_select "#toasts", text: /Annonce retirée\./
      assert_select "#moderated_announcement_#{@fiches.public_id}", 0
    end

    test "AN-17 — Mme Kamaté withdraws the announcement of a teacher of her college" do
      sign_in_as @kamate

      withdraw(as: :turbo_stream)

      assert_response :success
      assert_equal [ "withdrawn", @kamate.id ], @fiches.reload.values_at(:status, :withdrawn_by_id)
      assert_equal [ @kamate.id ], withdrawn_events.pluck(:actor_id)
    end

    test "AN-17 — Mme Kamaté receives 404 for a teacher of Bouaké, for the team and for M. Diallo; nothing changes" do
      others = [
        create_message(author: create_teacher(school: @bouake, classrooms: [ create_classroom(school: @bouake) ]), audience: "classrooms",
                       classrooms: Orm::Classroom.where(school: @bouake).to_a),
        create_message(author: @fatou, audience: "all"),
        create_message(author: create_school_admin(school: @lauriers, last_name: "Diallo"), school: @lauriers)
      ]
      sign_in_as @kamate

      others.each do |message|
        withdraw(message)
        assert_response :not_found
        withdraw(message, as: :turbo_stream)
        assert_response :not_found
        assert_select "turbo-stream[action=append][target=toasts] template", text: /Page introuvable\./
      end
      assert_equal %w[published published published], others.map { it.reload.status }
      assert_empty withdrawn_events
    end

    test "AN-17 — M. Kouassi receives 404 when he tries to withdraw the announcement of a colleague" do
      colleague = create_message(author: create_teacher(school: @lauriers, classrooms: [ @b3 ]), audience: "classrooms", classrooms: [ @b3 ])
      sign_in_as @kouassi

      withdraw(colleague)

      assert_response :not_found
      assert_equal "published", colleague.reload.status
    end

    test "already withdrawn, the announcement is no longer withdrawable: 404 and an error toast, nothing more is journaled" do
      sign_in_as @fatou
      withdraw(as: :turbo_stream)

      withdraw(as: :turbo_stream)

      assert_response :not_found
      assert_select "turbo-stream[action=append][target=toasts] template", text: /Page introuvable\./
      assert_equal 1, withdrawn_events.count
    end

    test "an unknown announcement is 404" do
      sign_in_as @fatou

      post announcement_withdrawal_path("inconnue")

      assert_response :not_found
    end

    test "a student receives 403 and a visitor is sent to sign in; nothing changes" do
      sign_in_as @awa
      withdraw
      assert_response :forbidden
      sign_out

      withdraw
      assert_redirected_to new_session_path
      assert_equal "published", @fiches.reload.status
    end
  end
end
