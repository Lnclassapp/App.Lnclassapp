require "test_helper"

module Queries
  module Communication
    # UDR-0071 §3.7 « Mes annonces » and §3.8: the announcements of their author, most recent first, 20 a page, in a
    # constant number of queries; « Terminée » is deduced from the end date, never stored (ADR-0078 §4.1). And what the
    # form of an announcement shows: the classrooms of the teacher, the school, the targets and files of an announcement.
    # ADR-0081, UDR-0075 §3.1 and §3.3 (annonces-v2): the theme of each row, a drawing of the team as its thumbnail, and
    # the announcement that a publication would archive, read without lock.
    class AuthoredMessagesQueryTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 4, 12)

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers")
        @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
        @query = AuthoredMessagesQuery.new
      end

      def rows(author = @kamate, page: 1) = @query.page(author_id: author.id, page:, now: NOW).rows
      def by_title(author = @kamate) = rows(author).index_by(&:title)

      def count_queries(&) = sql_of(&).size

      def sql_of(&)
        statements = []
        counter = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        statements
      end

      test "one row per announcement, with its status and the dates it shows" do
        create_message(author: @kamate, title: "Brouillon", status: "draft", published_at: nil)
        create_message(author: @kamate, title: "Programmée", status: "scheduled", published_at: Time.zone.local(2026, 10, 5, 10))
        create_message(author: @kamate, title: "Publiée", published_at: Time.zone.local(2026, 10, 3, 8), ends_at: Time.zone.local(2026, 11, 2))
        create_message(author: @kamate, title: "Archivée", status: "archived", updated_at: Time.zone.local(2026, 10, 4, 9))
        create_message(author: @kamate, title: "Retirée", status: "withdrawn", withdrawn_at: Time.zone.local(2026, 10, 4, 8))

        found = by_title.transform_values { [ it.status, it.at, it.last_day, it.manageable? ] }

        assert_equal({ "Brouillon" => [ "draft", nil, nil, true ],
                       "Programmée" => [ "scheduled", Time.zone.local(2026, 10, 5, 10), nil, true ],
                       "Publiée" => [ "published", Time.zone.local(2026, 10, 3, 8), Date.new(2026, 11, 1), true ],
                       "Archivée" => [ "archived", Time.zone.local(2026, 10, 4, 9), nil, false ],
                       "Retirée" => [ "withdrawn", Time.zone.local(2026, 10, 4, 8), nil, false ] }, found)
      end

      test "AN-08 — a published announcement whose end has passed is « Terminée », dated by its end" do
        create_message(author: @kamate, title: "Rentrée", published_at: Time.zone.local(2026, 9, 1, 8), ends_at: Time.zone.local(2026, 10, 1))
        create_message(author: @kamate, title: "Pile à l'heure", published_at: Time.zone.local(2026, 9, 10, 8), ends_at: NOW)

        assert_equal [ "ended", Time.zone.local(2026, 10, 1), nil, false ], by_title["Rentrée"].then { [ it.status, it.at, it.last_day, it.manageable? ] }
        assert_equal "ended", by_title["Pile à l'heure"].status
        assert_equal "published", Orm::Message.find_by!(title: "Rentrée").status, "« Terminée » n'est pas stocké"
      end

      test "the recipients: the country or the school with the audience, or the classrooms by name" do
        team = create_team_member(second_factor: false)
        teacher = create_teacher(school: @lauriers)
        classrooms = [ "3ème C", "3ème B", "6ème 10", "6ème 2" ].map { create_classroom(school: @lauriers, name: it) }
        create_message(author: team, title: "Nationale", audience: "all")
        create_message(author: team, title: "Lauriers", audience: "teachers", school: @lauriers)
        create_message(author: teacher, title: "Fiches", audience: "classrooms", classrooms:)

        national, school = by_title(team).values_at("Nationale", "Lauriers")
        assert_equal [ "all", nil, [] ], [ national.audience, national.school_name, national.classroom_names ]
        assert_equal [ "teachers", "Collège Les Lauriers" ], [ school.audience, school.school_name ]
        assert_equal [ "3ème B", "3ème C", "6ème 2", "6ème 10" ], by_title(teacher)["Fiches"].classroom_names
      end

      test "the row knows whether the announcement has an image, and keeps its illustration" do
        with_image = create_message(author: @kamate, title: "Avec image", illustration: "exam")
        create_message(author: @kamate, title: "Sans image", illustration: "holidays")
        Repositories::Communication::AttachmentStore.new.attach(message_id: with_image.id, kind: :image, content_type: "image/png",
                                                               io: StringIO.new(file_fixture("photos/photo.png").binread), filename: "image.png")
        Repositories::Communication::AttachmentStore.new.attach(message_id: with_image.id, kind: :audio, content_type: "audio/mpeg",
                                                               io: StringIO.new("ID3".b), filename: "audio.mp3")

        assert_equal [ true, "exam", with_image.public_id ], by_title["Avec image"].then { [ it.image, it.illustration, it.public_id ] }
        assert_equal [ false, "holidays" ], by_title["Sans image"].then { [ it.image, it.illustration ] }
      end

      test "only the announcements of their author, the most recent first" do
        create_message(author: @kamate, title: "Ancienne", created_at: 2.days.ago)
        create_message(author: @kamate, title: "Récente", created_at: 1.hour.ago)
        create_message(author: create_school_admin(school: @lauriers), title: "D'un collègue")

        assert_equal [ "Récente", "Ancienne" ], rows.map(&:title)
      end

      test "20 a page; a page out of range is the nearest one" do
        21.times { create_message(author: @kamate, title: "Annonce #{it}", created_at: it.minutes.ago) }

        first = @query.page(author_id: @kamate.id, page: "1", now: NOW)
        assert_equal [ 20, 1, 2, "Annonce 0" ], [ first.rows.size, first.page, first.pages, first.rows.first.title ]
        assert_equal [ [ "Annonce 20" ], 2 ], @query.page(author_id: @kamate.id, page: "9", now: NOW).then { [ it.rows.map(&:title), it.page ] }
        assert_equal [ 1, 1 ], @query.page(author_id: create_team_member(second_factor: false).id, page: [ "x" ], now: NOW)
                                     .then { [ it.page, it.pages ] }
      end

      test "a constant number of queries, whatever the number of announcements, classrooms and drawings of the team" do
        teacher = create_teacher(school: @lauriers)
        classrooms = Array.new(3) { create_classroom(school: @lauriers) }
        create_message(author: teacher, audience: "classrooms", classrooms: classrooms.first(1),
                       illustration: create_illustration(name: "Premier", created_by: @kamate))
        few = count_queries { rows(teacher) }
        6.times do |index|
          drawing = create_illustration(name: "Dessin #{index}", created_by: @kamate) if index.even?
          create_message(author: teacher, audience: "classrooms", classrooms:, illustration: drawing || "exam")
        end

        assert_equal few, count_queries { rows(teacher) }
        assert_equal 4, few
      end

      test "the classrooms a teacher may target: active, of his school, where he teaches, by level then by name" do
        sixth = create_level(position: 1)
        third = create_level(position: 4)
        taught = [ create_classroom(school: @lauriers, level: third, name: "3ème B"),
                   create_classroom(school: @lauriers, level: sixth, name: "6ème 10"),
                   create_classroom(school: @lauriers, level: sixth, name: "6ème 2") ]
        archived = create_classroom(school: @lauriers, level: sixth, status: "archived")
        elsewhere = create_classroom(level: sixth)
        create_classroom(school: @lauriers, level: sixth, name: "6ème 1")
        teacher = create_teacher(school: @lauriers, classrooms: [ *taught, archived, elsewhere ])

        assert_equal [ [ "6ème 2", taught[2].public_id ], [ "6ème 10", taught[1].public_id ], [ "3ème B", taught[0].public_id ] ],
                     @query.classroom_choices(teacher_id: teacher.id, school_id: @lauriers.id)
      end

      test "the school of a form, by its public_id or its id; nothing for an unknown one" do
        school = AuthoredMessagesQuery::School.new(public_id: @lauriers.public_id, name: "Collège Les Lauriers")

        assert_equal school, @query.school(public_id: @lauriers.public_id)
        assert_equal school, @query.school(id: @lauriers.id)
        assert_nil @query.school(public_id: "inconnu")
        assert_nil @query.school(id: nil)
      end

      test "what the form of an announcement shows: its school and classrooms by public_id, its files" do
        teacher = create_teacher(school: @lauriers)
        classrooms = Array.new(2) { create_classroom(school: @lauriers) }
        record = create_message(author: teacher, audience: "classrooms", classrooms:)
        Repositories::Communication::AttachmentStore.new.attach(message_id: record.id, kind: :audio, content_type: "audio/mpeg",
                                                               io: StringIO.new("ID3".b), filename: "audio.mp3")
        message = Repositories::Communication::MessageRepository.new.find_by_public_id(public_id: record.public_id)

        assert_equal AuthoredMessagesQuery::Edited.new(school_public_id: @lauriers.public_id, image: false, audio: true,
                                                       classroom_public_ids: classrooms.map(&:public_id).sort, illustration_public_id: nil),
                     @query.edited(message).then { it.with(classroom_public_ids: it.classroom_public_ids.sort) }
        national = Repositories::Communication::MessageRepository.new.find_by_public_id(public_id: create_message(author: @kamate, audience: "all").public_id)
        assert_equal [ nil, [], false, false, nil ], @query.edited(national).deconstruct
      end

      test "AV-08 — the form of an announcement with a drawing of the team names it by its public_id" do
        bus = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false))
        record = create_message(author: @kamate, illustration: bus)
        message = Repositories::Communication::MessageRepository.new.find_by_public_id(public_id: record.public_id)

        assert_equal bus.public_id, @query.edited(message).illustration_public_id
      end

      test "AV-07 — each row carries the theme of its announcement, for the dot of « Mes annonces »" do
        create_message(author: @kamate, title: "Mangue", theme: "mangue")
        create_message(author: @kamate, title: "Ciel")

        assert_equal({ "Mangue" => "mangue", "Ciel" => "ciel" }, by_title.transform_values(&:theme))
      end

      test "AV-08, AV-10 — a row with a drawing of the team carries it for its thumbnail, retired or not" do
        bus = create_illustration(name: "Bus scolaire", created_by: @kamate)
        retired = create_illustration(name: "Ancien", created_by: @kamate, retired_at: 1.day.ago)
        create_message(author: @kamate, title: "Bus", illustration: bus)
        create_message(author: @kamate, title: "Ancien", illustration: retired)

        drawings = by_title.values_at("Bus", "Ancien").map(&:illustration)
        assert drawings.all?(Entities::Communication::Illustration)
        assert_equal [ [ bus.public_id, false ], [ retired.public_id, true ] ], drawings.map { [ it.public_id, it.retired? ] }
      end

      def departing(author = @kamate) = @query.departing(author_id: author.id, now: NOW)

      test "AV-06 — with 3 live announcements, the oldest is the one a publication would archive" do
        { "Réunion parents" => 1, "Fiches chapitre 3" => 3, "Sortie au musée" => 4 }.each do |title, day|
          create_message(author: @kamate, title:, published_at: Time.zone.local(2026, 10, day, 8))
        end

        leaving = departing

        assert_equal "Réunion parents", leaving.title
        assert_equal Orm::Message.find_by!(title: "Réunion parents").public_id, leaving.public_id
      end

      test "AV-06 — with 2 live announcements, nothing would be archived" do
        [ 1, 3 ].each { create_message(author: @kamate, published_at: Time.zone.local(2026, 10, it, 8)) }

        assert_nil departing
      end

      test "AV-04, AV-06 — only the live announcements of the author count: not a draft, a scheduled, an archived, a withdrawn, an ended one" do
        [ 1, 3 ].each { create_message(author: @kamate, published_at: Time.zone.local(2026, 10, it, 8)) }
        create_message(author: @kamate, status: "draft", published_at: nil)
        create_message(author: @kamate, status: "scheduled", published_at: Time.zone.local(2026, 10, 5, 8))
        create_message(author: @kamate, status: "archived")
        create_message(author: @kamate, status: "withdrawn")
        create_message(author: @kamate, published_at: Time.zone.local(2026, 9, 1, 8), ends_at: NOW)
        3.times { create_message(author: create_school_admin(school: @lauriers), published_at: Time.zone.local(2026, 9, 20, 8)) }

        assert_nil departing
      end

      test "AV-06 — the announcement that would leave is read in one query, without lock: the publication counts again under it" do
        3.times { create_message(author: @kamate, published_at: Time.zone.local(2026, 10, it + 1, 8)) }

        statements = sql_of { departing }

        assert_equal 1, statements.size
        assert_no_match(/FOR UPDATE|FOR SHARE/i, statements.join)
      end
    end
  end
end
