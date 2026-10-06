require "test_helper"

module Dtos
  module Communication
    # ADR-0045 §4, ADR-0078 §4.1 and §4.4, UDR-0071 §3.8: the form of an announcement. Lengths, files read in their
    # first bytes (the weight before any read), dates in the time zone of the application. ADR-0081 §4.1 to §4.3,
    # UDR-0075 §3.3 (annonces-v2): no end to choose, 30 days from the publication; a theme; a base illustration or the
    # public_id of a drawing of the team.
    class MessageInputTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 1, 10, 0, 30)
      MEGABYTE = 1024 * 1024
      MP3 = ("ID3".b + "\x04\x00\x00".b + ("\x00".b * 64)).freeze
      M4A = ("\x00\x00\x00\x20ftypM4A \x00\x00\x02\x00".b + ("\x00".b * 64)).freeze
      WAV = "RIFF\x24\x08\x00\x00WAVEfmt \x10\x00\x00\x00".b.freeze

      # A file whose content must never be read: its weight alone refuses it.
      Unread = Data.define(:size) do
        def read(*) = raise "read before the weight was checked"
        def rewind = raise "read before the weight was checked"
      end

      def input(**attributes)
        MessageInput.new(title: "Nouvelles fiches", body: "Les fiches du chapitre 3 sont en ligne.", illustration: "sheets",
                         commit: "publish", **attributes)
      end

      def checked(now: NOW, live_since: nil, live_until: nil, **attributes)
        input(**attributes).tap { it.valid_at?(now:, live_since:, live_until:) }
      end

      def errors(**) = checked(**).errors.to_hash

      def photo(name) = StringIO.new(file_fixture("photos/#{name}").binread)

      test "a title and a text within their lengths, with an illustration of the library, are valid" do
        assert checked.errors.empty?
        assert_equal "Nouvelles fiches", input(title: "  Nouvelles   fiches ").title
      end

      test "AN-20 — a title of 61 characters, a text of 141, an empty text or title are refused" do
        assert_equal({ title: [ "Le titre compte 60 caractères au plus." ] }, errors(title: "a" * 61))
        assert_equal({ body: [ "Le texte compte 140 caractères au plus." ] }, errors(body: "a" * 141))
        assert_equal({ body: [ "Saisissez le texte de l'annonce." ] }, errors(body: " \n "))
        assert_equal({ title: [ "Saisissez un titre." ] }, errors(title: nil))
        assert checked(title: "a" * 60, body: "a" * 140).errors.empty?
      end

      test "a line break counts once, as the browser counts it under maxlength" do
        dto = checked(body: "#{'a' * 69}\r\n#{'b' * 70}")

        assert dto.errors.empty?
        assert_equal 140, dto.body.length
      end

      test "an illustration outside the library is refused" do
        assert_equal({ illustration: [ "Choisissez une illustration de la bibliothèque." ] }, errors(illustration: "skull"))
        assert_equal({ illustration: [ "Choisissez une illustration de la bibliothèque." ] }, errors(illustration: nil))
      end

      test "AV-10 — the value of a drawing of the team is its public_id: its shape is checked here, its existence by the use case" do
        team = checked(illustration: "Bq7xK2mN9pR4sT")

        assert team.errors.empty?
        assert_equal [ true, nil ], [ team.library_illustration?, team.base_illustration ]
        assert_equal [ false, "sheets" ], checked.then { [ it.library_illustration?, it.base_illustration ] }
        [ "Bq7xK2mN9pR4s", "Bq7xK2mN9pR4sT5", "Bq7xK2mN9pR4s!", "<svg onload=x>" ].each do |forged|
          assert_equal({ illustration: [ "Choisissez une illustration de la bibliothèque." ] }, errors(illustration: forged), forged)
          assert_not input(illustration: forged).library_illustration?, forged
        end
      end

      test "AV-07 — the ten themes are accepted, « Ciel » by default" do
        Entities::Communication::Message::THEMES.each do |theme|
          assert checked(theme:).errors.empty?, theme
          assert_equal theme, input(theme:).theme
        end
        assert_equal "ciel", input.theme
      end

      test "AV-07 — an unknown theme sent by a forged form is refused under « Thème »" do
        [ "rose", "", "CIEL" ].each do |forged|
          assert_equal({ theme: [ "Choisissez un thème de la liste." ] }, errors(theme: forged), forged)
        end
        assert_equal "Thème", MessageInput.human_attribute_name(:theme)
      end

      test "a PNG, a JPEG and a WebP are accepted, typed by their content and renamed" do
        { "photo.png" => [ "image/png", "image.png" ], "photo.jpg" => [ "image/jpeg", "image.jpg" ],
          "photo_lossy.webp" => [ "image/webp", "image.webp" ] }.each do |name, (type, filename)|
          dto = checked(image: photo(name))

          assert dto.errors.empty?, name
          upload = dto.upload(:image)
          assert_equal [ type, filename ], [ upload.content_type, upload.filename ], name
          assert_equal file_fixture("photos/#{name}").binread, upload.io.read, "#{name} : rendu depuis son début"
        end
      end

      test "an MP3 (with or without ID3) and an M4A are accepted" do
        frame = "\xFF\xFB\x90\x64".b + ("\x00".b * 32)
        { MP3 => [ "audio/mpeg", "audio.mp3" ], frame => [ "audio/mpeg", "audio.mp3" ], M4A => [ "audio/mp4", "audio.m4a" ] }
          .each do |bytes, (type, filename)|
          upload = checked(audio: StringIO.new(bytes)).upload(:audio)

          assert_equal [ type, filename ], [ upload.content_type, upload.filename ]
        end
      end

      def recording(name) = file_fixture("audio/#{name}").binread

      # Phase 5 (test analysis 2.2), ADR-0081 §4.4: real recordings of test/fixtures/files/audio (README.txt). The frame
      # of remplissage.mp3 comes after 512 null bytes: a header read cut at 64 bytes would refuse it.
      test "AV-12 — real recordings: an MP3 whose frame follows 512 null bytes and a 3GP M4A are accepted, an AMR refused" do
        assert_operator recording("remplissage.mp3").index(/[^\x00]/n), :>=, 512
        { "remplissage.mp3" => [ "audio/mpeg", "audio.mp3" ], "marque-3gp4.m4a" => [ "audio/mp4", "audio.m4a" ] }
          .each do |name, (type, filename)|
          dto = checked(audio: StringIO.new(recording(name)))

          assert_empty dto.errors.to_hash, name
          upload = dto.upload(:audio)
          assert_equal [ type, filename, recording(name) ], [ upload.content_type, upload.filename, upload.io.read.b ], name
        end
        assert_equal({ audio: [ "Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A." ] },
                     errors(audio: StringIO.new(recording("enregistrement.amr"))))
      end

      test "AN-18 — a PDF renamed « affiche.png » and a WAV are refused: the error names the refused file" do
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: photo("document.pdf")))
        assert_equal({ audio: [ "Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A." ] }, errors(audio: StringIO.new(WAV)))
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: StringIO.new("")))
        assert_equal({ audio: [ "Ce fichier n'est pas accepté. Exportez l'enregistrement en MP3 ou M4A." ] }, errors(audio: photo("photo.png")))
      end

      test "AN-18 — an image of 3 MB and an audio of 12 MB are refused by their weight, before any read" do
        assert_equal({ image: [ "Ce fichier est trop lourd (2 Mo au plus)." ] }, errors(image: Unread.new(size: 3 * MEGABYTE)))
        assert_equal({ audio: [ "Ce fichier est trop lourd (10 Mo au plus)." ] }, errors(audio: Unread.new(size: 12 * MEGABYTE)))
      end

      # A real PNG brought to exactly `size` bytes by a comment chunk (tEXt) before IEND: a metadata the upload drops.
      def png_of(size)
        bytes = file_fixture("photos/photo.png").binread
        iend = bytes.rindex("IEND".b) - 4
        text = "Comment\x00".b + ("a".b * (size - bytes.bytesize - 12 - 8))
        chunk = [ text.bytesize ].pack("N") + "tEXt".b + text + [ Zlib.crc32("tEXt#{text}".b) ].pack("N")
        bytes.byteslice(0, iend) + chunk + bytes.byteslice(iend..)
      end

      test "the limits are inclusive: 2 MB of PNG and 10 MB of MP3 pass" do
        png = png_of(2 * MEGABYTE)
        mp3 = MP3 + ("\x00".b * ((10 * MEGABYTE) - MP3.bytesize))

        assert checked(image: StringIO.new(png), audio: StringIO.new(mp3)).errors.empty?
      end

      test "ADR-0060 — the image is kept without its metadata (Exif, GPS, XMP): JPEG, PNG and WebP" do
        %w[photo_exif.jpg photo_exif.png photo_exif.webp hostile/gps.png hostile/gps.webp].each do |name|
          dto = checked(image: photo(name))
          kept = dto.upload(:image).io.read

          assert dto.errors.empty?, name
          assert_equal false, Entities::Shared::ImageHeader.read(kept).metadata, name
          assert_operator kept.bytesize, :<, file_fixture("photos/#{name}").size, name
        end
      end

      test "ADR-0060 — an image only its first bytes make look like one is refused, and so is a truncated one" do
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: StringIO.new("\xFF\xD8".b + "<html><script>alert(1)</script>")))
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: photo("hostile/truncated.webp")))
      end

      # A real PNG of width × 1 pixels, gray: a few hundred bytes for any width.
      def png_wide(width)
        chunk = ->(type, data) { [ data.bytesize ].pack("N") + type.b + data + [ Zlib.crc32(type.b + data) ].pack("N") }
        "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [ width, 1, 8, 0, 0, 0, 0 ].pack("NNCCCCC")) +
          chunk.("IDAT", Zlib::Deflate.deflate("\x00".b * (width + 1))) + chunk.("IEND", "".b)
      end

      test "an image of more than 4096 pixels of side is refused, whatever its weight; 4096 passes" do
        assert_equal({ image: [ "L'image mesure 4096 pixels de côté au plus." ] }, errors(image: StringIO.new(png_wide(4097))))
        assert checked(image: StringIO.new(png_wide(4096))).errors.empty?
      end

      test "a date of more than four digits of year is unreadable, a draft's too: 422, never an error of the database" do
        assert_equal [ "Saisissez une date valide." ], errors(published_at: "99999-01-01T00:00")[:published_at]
        assert_equal [ "Saisissez une date valide." ], errors(commit: "draft", published_at: "99999999-01-01T00:00")[:published_at]
      end

      test "without a file, there is nothing to upload" do
        assert_nil checked.upload(:image)
        assert_nil checked.upload(:audio)
      end

      test "the removal boxes are read as booleans" do
        dto = input(remove_image: "1", remove_audio: "0")

        assert dto.remove?(:image)
        assert_not dto.remove?(:audio)
        assert_not input.remove?(:image)
      end

      test "the classrooms ticked: the empty value of the group dropped, each one once" do
        assert_equal %w[a b], input(classroom_public_ids: [ "", "a", "b", "a" ]).classroom_public_ids
        assert_equal [], input.classroom_public_ids
      end

      test "without a publication date, the announcement is published now, for 30 days" do
        dto = checked

        assert_equal [ "published", NOW, NOW + 30.days ], [ dto.status, dto.publication_time, dto.ends_at ]
      end

      test "AV-02 — published on October 6th, it ends 30 days later, on November 5th: no end is asked" do
        now = Time.zone.local(2026, 10, 6, 10, 15)

        assert_equal Time.zone.local(2026, 11, 5, 10, 15), checked(now:).ends_at
        assert_raises(ActiveModel::UnknownAttributeError) { input(visible_until: "2026-12-31") }
        assert_not MessageInput.method_defined?(:visible_until)
      end

      test "AV-02 — a future date schedules it; its end runs 30 days from its publication" do
        dto = checked(published_at: "2026-10-05T10:00")

        assert_equal [ "scheduled", Time.zone.local(2026, 10, 5, 10), Time.zone.local(2026, 11, 4, 10) ],
                     [ dto.status, dto.publication_time, dto.ends_at ]
        assert dto.errors.empty?
      end

      test "a date in the current minute publishes now" do
        dto = checked(published_at: "2026-10-01T10:00")

        assert_equal [ "published", NOW ], [ dto.status, dto.publication_time ]
        assert dto.errors.empty?
      end

      test "a past publication date is refused" do
        assert_equal({ published_at: [ "Choisissez une date à venir, ou laissez vide pour publier dès l'envoi." ] },
                     errors(published_at: "2026-10-01T09:59"))
      end

      test "an unreadable publication date is refused under its field" do
        assert_equal({ published_at: [ "Saisissez une date valide." ] }, errors(published_at: "2026-13-45T99:00"))
      end

      test "AV-02 — a draft keeps its date, has no end and is not checked against the clock" do
        dto = checked(commit: "draft", published_at: "2026-09-01T08:00")

        assert dto.errors.empty?
        assert_equal [ "draft", Time.zone.local(2026, 9, 1, 8), nil ], [ dto.status, dto.publication_time, dto.ends_at ]
        assert_nil checked(commit: "draft").publication_time
        assert_equal({ published_at: [ "Saisissez une date valide." ] }, errors(commit: "draft", published_at: "demain"))
      end

      test "AV-02 — an announcement already published keeps its publication date and its end, and stays published" do
        live_since = Time.zone.local(2026, 9, 20, 8)
        live_until = Time.zone.local(2026, 10, 20, 8)
        dto = checked(live_since:, live_until:, commit: "draft", published_at: "n'importe quoi")

        assert dto.errors.empty?
        assert_equal [ "published", live_since, live_until ], [ dto.status, dto.publication_time, dto.ends_at ]
      end

      test "the form of a new announcement: the first illustration, « Ciel »" do
        dto = MessageInput.blank

        assert_equal [ "info", "ciel", nil, nil ], [ dto.illustration, dto.theme, dto.scope, dto.school_public_id ]
        assert_equal [ "school", "lauriers" ], MessageInput.blank(school_public_id: "lauriers").then { [ it.scope, it.school_public_id ] }
      end

      test "the form of an existing announcement shows its values, its date in the format of the field" do
        message = Entities::Communication::Message.new(
          id: 1, author_id: 2, title: "Devoirs communs", body: "Lundi.", audience: "students", illustration: "exam",
          status: "scheduled", school_id: 10, published_at: Time.zone.local(2026, 10, 5, 10), ends_at: Time.zone.local(2026, 11, 4, 10),
          theme: "mangue"
        )
        dto = MessageInput.for(message, school_public_id: "lauriers", classroom_public_ids: [], illustration_public_id: nil)

        assert_equal [ "Devoirs communs", "Lundi.", "school", "lauriers", "students", "exam", "mangue", "2026-10-05T10:00" ],
                     [ dto.title, dto.body, dto.scope, dto.school_public_id, dto.audience, dto.illustration, dto.theme, dto.published_at ]
      end

      test "a national draft without date, with a drawing of the team: its public_id is the value of the illustration" do
        draft = Entities::Communication::Message.new(author_id: 2, title: "Rentrée", body: "Bientôt.", audience: "all",
                                                     illustration: nil, illustration_id: 7, status: "draft", classroom_ids: [ 3 ])
        dto = MessageInput.for(draft, school_public_id: nil, classroom_public_ids: [ "b3" ], illustration_public_id: "Bq7xK2mN9pR4sT")

        assert_equal [ "national", nil, [ "b3" ], "Bq7xK2mN9pR4sT", "ciel" ],
                     [ dto.scope, dto.published_at, dto.classroom_public_ids, dto.illustration, dto.theme ]
      end
    end
  end
end
