require "test_helper"

# AN-12, AN-13, UDR-0071 §3.5 to §3.7: the cross hides a message for the student on all their devices, « Annuler » and
# « Réafficher » give it back. The Turbo Stream answer replaces the card (in the list) and the carousel (on the home),
# whichever the page holds; an official or unreadable message is refused without writing anything.
module Communication
  class MessageDismissalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @lauriers = create_school(name: "Collège Les Lauriers")
      @troisieme_b = create_classroom(school: @lauriers, name: "3ème B")
      @awa = create_student(classroom: @troisieme_b, first_name: "Awa")
      kouassi = create_teacher(school: @lauriers, classrooms: [ @troisieme_b ], gender: "male", last_name: "Kouassi")
      @fiches = create_message(author: kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @troisieme_b ])
      @devoirs = create_message(author: create_school_admin(school: @lauriers), title: "Devoirs communs", school: @lauriers)
      @rentree = create_message(author: create_team_member(second_factor: false), title: "Rentrée numérique", audience: "all")
    end

    def path(message = @fiches) = announcement_dismissal_path(message.public_id)
    def dismissed?(message = @fiches) = Orm::MessageDismissal.exists?(message:, user: @awa)
    def streams = css_select("turbo-stream").map { [ it["action"], it["target"] ] }
    def tc(key) = I18n.t("communication.#{key}")

    test "AN-12 — the student hides a message: the card is marked « Masquée », the carousel loses it, a toast offers « Annuler »" do
      sign_in_as @awa

      post path, as: :turbo_stream

      assert_response :success
      assert dismissed?
      assert_equal [ [ "replace", "announcement_#{@fiches.public_id}" ], %w[replace student_home_announcements], %w[append toasts] ],
                   streams
      assert_select "turbo-stream[target=announcement_#{@fiches.public_id}] template" do
        assert_select "article span", tc("card.dismissed")
        assert_select "form[action=?] button", path, text: tc("card.restore")
      end
      assert_select "turbo-stream[target=student_home_announcements] template" do
        assert_select "section#student_home_announcements[data-communication--carousel-refocus-value=true]"
        assert_equal [ "Devoirs communs", "Rentrée numérique" ], css_select("li article h3").map(&:text)
      end
      assert_select "turbo-stream[target=toasts] template" do
        assert_select "p", tc("dismissal.title")
        assert_select "p", tc("dismissal.message")
        assert_select "form[action=?] input[name=_method][value=delete]", path
        assert_select "form button", tc("dismissal.undo")
      end
    end

    test "AN-12 — hidden in one session, the message is marked « Masquée » in another session of the student" do
      sign_in_as @awa
      post path, as: :turbo_stream
      phone = open_session
      phone.post session_path, params: { session: { contact: @awa.contact, pin: "2468" } }

      phone.get announcements_path

      assert_equal [ tc("card.dismissed") ], phone.css_select("#announcement_#{@fiches.public_id} span.ui-badge").map(&:text)
      assert_empty phone.css_select("#announcement_#{@devoirs.public_id} span.ui-badge")
    end

    test "AN-12 — « Annuler » removes the dismissal: the card and the carousel get it back, without a new toast" do
      dismiss_message(message: @fiches, user: @awa)
      sign_in_as @awa

      delete path, as: :turbo_stream

      assert_response :success
      assert_not dismissed?
      assert_equal [ [ "replace", "announcement_#{@fiches.public_id}" ], %w[replace student_home_announcements] ], streams
      assert_select "turbo-stream[target=announcement_#{@fiches.public_id}] template" do
        assert_select "span", text: tc("card.dismissed"), count: 0
        assert_select "form[action=?] button[aria-label=?]", path, I18n.t("communication.card.dismiss", title: "Nouvelles fiches")
      end
      assert_select "turbo-stream[target=student_home_announcements] template li article h3", text: "Nouvelles fiches"
    end

    test "AN-13 — a forged dismissal of an official message is refused, nothing is written, the toast says why" do
      sign_in_as @awa

      post path(@devoirs), as: :turbo_stream

      assert_response :forbidden
      assert_not dismissed?(@devoirs)
      assert_equal [ %w[append toasts] ], streams
      assert_select "turbo-stream[target=toasts] template p", tc("dismissal.refused")
    end

    test "AN-13 — a forged « Annuler » on an official message is refused too: the row stays" do
      dismiss_message(message: @devoirs, user: @awa)
      sign_in_as @awa

      delete path(@devoirs), as: :turbo_stream

      assert_response :forbidden
      assert dismissed?(@devoirs)
    end

    test "a message the student does not read is refused, without writing anything" do
      other = create_message(author: create_team_member(second_factor: false), audience: "teachers")
      sign_in_as @awa

      post path(other), as: :turbo_stream

      assert_response :forbidden
      assert_not Orm::MessageDismissal.exists?
    end

    test "without Turbo: back to the page of the cross, the toast by the flash; the home by default" do
      sign_in_as @awa

      post path, headers: { "HTTP_REFERER" => "http://www.example.com#{announcements_path}" }

      assert_redirected_to announcements_path
      follow_redirect!
      assert_select "#toasts", text: /#{tc('dismissal.title')}/
      assert dismissed?

      delete path

      assert_redirected_to student_home_path
      assert_not dismissed?
    end

    test "AN-13 — without Turbo, a refused dismissal comes back with its reason" do
      sign_in_as @awa

      post path(@devoirs), headers: { "HTTP_REFERER" => "http://www.example.com#{announcements_path}" }

      assert_redirected_to announcements_path
      assert_equal tc("dismissal.refused"), flash[:alert]
      assert_not dismissed?(@devoirs)
    end

    test "an unknown message: 404" do
      sign_in_as @awa

      post announcement_dismissal_path("inconnu"), as: :turbo_stream

      assert_response :not_found
    end

    test "a teacher, a direction and the team receive 403" do
      [ create_teacher(school: @lauriers), create_school_admin(school: @lauriers), create_team_member ].each do |user|
        sign_in_as user

        post path(@rentree)

        assert_response :forbidden, user.role
        sign_out
      end
      assert_not Orm::MessageDismissal.exists?
    end

    test "a visitor is sent to « Se connecter »" do
      post path

      assert_redirected_to new_session_path
    end
  end
end
