require "test_helper"

module Dtos
  module Communication
    # ADR-0045 §4, ADR-0078 §4.1 and §4.4, UDR-0071 §3.8: the form of an announcement. Lengths, files read in their
    # first bytes (the weight before any read), dates in the time zone of the application.
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

      def checked(now: NOW, live_since: nil, **attributes)
        input(**attributes).tap { it.valid_at?(now:, live_since:) }
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

      test "AN-18 — a PDF renamed « affiche.png » and a WAV are refused: the error names the refused file" do
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: photo("document.pdf")))
        assert_equal({ audio: [ "Ce fichier n'est pas accepté." ] }, errors(audio: StringIO.new(WAV)))
        assert_equal({ image: [ "Ce fichier n'est pas accepté." ] }, errors(image: StringIO.new("")))
        assert_equal({ audio: [ "Ce fichier n'est pas accepté." ] }, errors(audio: photo("photo.png")))
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
        assert_equal [ "Saisissez une date valide." ], errors(visible_until: "99999-01-20")[:visible_until]
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

      test "AN-08 — published on October 1st without an end chosen, it ends on October 31st" do
        assert_equal Time.zone.local(2026, 10, 31, 10, 0, 30), checked(visible_until: "").ends_at
      end

      test "a future date schedules it; the end is the day after the last day shown, at midnight" do
        dto = checked(published_at: "2026-10-05T10:00", visible_until: "2026-11-01")

        assert_equal [ "scheduled", Time.zone.local(2026, 10, 5, 10), Time.zone.local(2026, 11, 2) ],
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

      test "AN-08 — an end on October 1st (shown until September 30) or on December 31st is refused" do
        assert_equal({ visible_until: [ "Choisissez un jour qui suit la publication." ] }, errors(visible_until: "2026-09-30"))
        assert_equal({ visible_until: [ "L'annonce reste visible 90 jours au plus." ] }, errors(visible_until: "2026-12-31"))
        assert_equal({ visible_until: [ "L'annonce reste visible 90 jours au plus." ] }, errors(visible_until: "2026-12-30"))
        assert checked(visible_until: "2026-10-01").errors.empty?, "visible le jour même de sa publication"
        assert checked(visible_until: "2026-12-29").errors.empty?
      end

      test "unreadable dates are refused, each under its field" do
        assert_equal({ published_at: [ "Saisissez une date valide." ], visible_until: [ "Saisissez une date valide." ] },
                     errors(published_at: "2026-13-45T99:00", visible_until: "le 31"))
      end

      test "a draft keeps its date, has no end and is not checked against the clock" do
        dto = checked(commit: "draft", published_at: "2026-09-01T08:00", visible_until: "2027-06-01")

        assert dto.errors.empty?
        assert_equal [ "draft", Time.zone.local(2026, 9, 1, 8), nil ], [ dto.status, dto.publication_time, dto.ends_at ]
        assert_nil checked(commit: "draft").publication_time
        assert_equal({ published_at: [ "Saisissez une date valide." ] }, errors(commit: "draft", published_at: "demain"))
      end

      test "an announcement already published keeps its publication date and stays published" do
        live_since = Time.zone.local(2026, 9, 20, 8)
        dto = checked(live_since:, commit: "draft", published_at: "n'importe quoi", visible_until: "2026-10-31")

        assert dto.errors.empty?
        assert_equal [ "published", live_since, Time.zone.local(2026, 11, 1) ], [ dto.status, dto.publication_time, dto.ends_at ]
        assert_equal({ visible_until: [ "L'annonce reste visible 90 jours au plus." ] },
                     errors(live_since:, visible_until: "2026-12-19"))
      end

      test "the form of a new announcement: the first illustration, shown for 30 days" do
        dto = MessageInput.blank(today: Date.new(2026, 10, 1))

        assert_equal [ "info", "2026-10-30", nil, nil ], [ dto.illustration, dto.visible_until, dto.scope, dto.school_public_id ]
        assert_equal [ "school", "lauriers" ], MessageInput.blank(today: Date.new(2026, 10, 1), school_public_id: "lauriers")
                                                           .then { [ it.scope, it.school_public_id ] }
      end

      test "the form of an existing announcement shows its values, its dates in the formats of the fields" do
        message = Entities::Communication::Message.new(
          id: 1, author_id: 2, title: "Devoirs communs", body: "Lundi.", audience: "students", illustration: "exam",
          status: "scheduled", school_id: 10, published_at: Time.zone.local(2026, 10, 5, 10), ends_at: Time.zone.local(2026, 11, 2)
        )
        dto = MessageInput.for(message, school_public_id: "lauriers", classroom_public_ids: [], today: Date.new(2026, 10, 1))

        assert_equal [ "Devoirs communs", "Lundi.", "school", "lauriers", "students", "exam", "2026-10-05T10:00", "2026-11-01" ],
                     [ dto.title, dto.body, dto.scope, dto.school_public_id, dto.audience, dto.illustration, dto.published_at,
                       dto.visible_until ]
      end

      test "a national draft without dates: no publication date, shown for 30 days from today" do
        draft = Entities::Communication::Message.new(author_id: 2, title: "Rentrée", body: "Bientôt.", audience: "all",
                                                     illustration: "info", status: "draft", classroom_ids: [ 3 ])
        dto = MessageInput.for(draft, school_public_id: nil, classroom_public_ids: [ "b3" ], today: Date.new(2026, 10, 1))

        assert_equal [ "national", nil, "2026-10-30", [ "b3" ] ], [ dto.scope, dto.published_at, dto.visible_until, dto.classroom_public_ids ]
      end

      test "a dated draft is shown for 30 days from its date of publication" do
        draft = Entities::Communication::Message.new(author_id: 2, title: "Rentrée", body: "Bientôt.", audience: "all",
                                                     illustration: "info", status: "draft", published_at: Time.zone.local(2026, 11, 2, 8))
        dto = MessageInput.for(draft, school_public_id: nil, classroom_public_ids: [], today: Date.new(2026, 10, 1))

        assert_equal [ "2026-11-02T08:00", "2026-12-01" ], [ dto.published_at, dto.visible_until ]
      end
    end
  end
end
