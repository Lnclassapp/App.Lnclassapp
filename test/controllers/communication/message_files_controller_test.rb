require "test_helper"

# AN-09, AN-08, AN-19 (ADR-0069 §4.4): without a detail page, the files are the only addressable surface of a message.
# The application serves them after the reading rule, in private no-store cache, by byte range for the audio; any
# refusal is a 404, and a visitor is sent to « Se connecter ».
module Communication
  class MessageFilesControllerTest < ActionDispatch::IntegrationTest
    AUDIO = ("ID3".b + (0..255).map(&:chr).join.b).freeze

    setup do
      @school = create_school(name: "Collège Les Lauriers")
      @troisieme_b = create_classroom(school: @school, name: "3ème B")
      @troisieme_a = create_classroom(school: @school, name: "3ème A")
      @awa = create_student(classroom: @troisieme_b)
      @kouassi = create_teacher(school: @school, classrooms: [ @troisieme_b ])
      @message = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @troisieme_b ])
      @png = file_fixture("photos/photo.png").binread
      attach(@message, :image, @png, "image/png")
      attach(@message, :audio, AUDIO, "audio/mpeg")
    end

    def attach(message, kind, data, content_type)
      Repositories::Communication::AttachmentStore.new.attach(message_id: message.id, kind:, io: StringIO.new(data),
                                                              content_type:, filename: "fichier")
    end

    def file_path(kind, message = @message) = announcement_file_path(message.public_id, kind:)

    def assert_not_served(user, message = @message)
      sign_in_as user
      %w[image audio].each do |kind|
        get file_path(kind, message)

        assert_response :not_found, kind
      end
      sign_out
    end

    test "AN-09 — a student of 3ème B receives the image and the audio, inline, in private no-store cache" do
      sign_in_as @awa

      get file_path("image")

      assert_response :success
      assert_equal [ @png, "image/png" ], [ response.body.b, response.media_type ]
      assert_match(/\Ainline/, response.headers["Content-Disposition"])
      assert_equal [ "no-store", "private" ], response.headers["Cache-Control"].split(/,\s*/).sort
      assert_equal "bytes", response.headers["Accept-Ranges"]

      get file_path("audio")

      assert_equal [ 200, AUDIO, "audio/mpeg" ], [ response.status, response.body.b, response.media_type ]
      assert_nil response.headers["Content-Range"]
    end

    test "AN-09 — a student of 3ème A receives 404 for the image and the audio" do
      assert_not_served create_student(classroom: @troisieme_a)
    end

    test "AN-09 — 404 before the publication, after the end, once archived and once withdrawn" do
      [ { status: "scheduled", published_at: 1.hour.from_now }, { published_at: 31.days.ago, ends_at: 1.second.ago },
        { status: "archived" }, { status: "withdrawn" } ].each do |state|
        message = create_message(author: @kouassi, audience: "classrooms", classrooms: [ @troisieme_b ], **state)
        attach(message, :image, @png, "image/png")
        attach(message, :audio, AUDIO, "audio/mpeg")

        assert_not_served @awa, message
      end
    end

    test "AN-09, AN-19 — M. Kouassi and the team receive the files, even of an archived message" do
      archived = create_message(author: @kouassi, audience: "classrooms", classrooms: [ @troisieme_b ], status: "archived")
      attach(archived, :audio, AUDIO, "audio/mpeg")

      [ @kouassi, create_team_member ].each do |user|
        sign_in_as user
        get file_path("audio", archived)

        assert_equal [ 200, AUDIO ], [ response.status, response.body.b ], user.role
        sign_out
      end
    end

    test "the direction of the school receives the files of its teacher's message; another direction does not" do
      sign_in_as create_school_admin(school: @school)
      get file_path("image")

      assert_response :success
      sign_out
      assert_not_served create_school_admin
    end

    test "a message without this file, or an unknown message: 404" do
      without = create_message(author: @kouassi, audience: "classrooms", classrooms: [ @troisieme_b ])
      sign_in_as @awa

      get file_path("audio", without)
      assert_response :not_found

      get announcement_file_path("inconnu", kind: "image")
      assert_response :not_found
    end

    test "ADR-0069 §4.4 — a byte range is answered by 206, with its Content-Range" do
      sign_in_as @awa

      { "bytes=0-3" => [ 0, 3 ], "bytes=250-" => [ 250, 258 ], "bytes=-4" => [ 255, 258 ] }.each do |range, (first, last)|
        get file_path("audio"), headers: { "Range" => range }

        assert_response :partial_content, range
        assert_equal "bytes #{first}-#{last}/#{AUDIO.bytesize}", response.headers["Content-Range"], range
        assert_equal [ AUDIO.byteslice(first..last), "bytes" ], [ response.body.b, response.headers["Accept-Ranges"] ], range
      end
    end

    test "a malformed or unsatisfiable range gives the whole file" do
      sign_in_as @awa

      [ "bytes=-", "bytes=-0", "items=0-3", "bytes=0-3,5-6", "bytes=9000-", "bytes=5-2" ].each do |range|
        get file_path("audio"), headers: { "Range" => range }

        assert_equal [ 200, AUDIO ], [ response.status, response.body.b ], range
        assert_nil response.headers["Content-Range"], range
      end
    end

    test "AN-09 — a visitor is sent to « Se connecter »" do
      get file_path("audio")

      assert_redirected_to new_session_path
    end
  end
end
