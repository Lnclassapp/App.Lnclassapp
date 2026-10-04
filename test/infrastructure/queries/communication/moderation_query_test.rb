require "test_helper"

# ADR-0078 §4.2, UDR-0071 §3.7: « Toutes » (team) and « Enseignants » (direction), the announcements a moderator may
# withdraw — scheduled or published and not ended, written by someone else; for the direction, those of the teachers of
# its school. The team filters them by the name or the sigle of their school. Each row is the card of « Reçues » with its
# school and its dates; twenty per page, newest first, in a constant number of queries.
module Queries
  module Communication
    class ModerationQueryTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 4, 10)

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers", sigle: "CLL")
        @bouake = create_school(name: "Lycée de Bouaké", sigle: "LYB")
        @b3 = create_classroom(school: @lauriers, name: "3ème B")
        @kouassi = create_teacher(school: @lauriers, material: create_material(name: "SVT"), classrooms: [ @b3 ],
                                  gender: "male", last_name: "Kouassi")
        @terminale = create_classroom(school: @bouake, name: "Terminale D")
        @traore = create_teacher(school: @bouake, classrooms: [ @terminale ], last_name: "Traoré")
        @kamate = create_school_admin(school: @lauriers, gender: "female", last_name: "Kamaté")
        @fatou = create_team_member(second_factor: false, first_name: "Fatou")
        @query = ModerationQuery.new
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)
      def page(user, q: nil, number: 1) = @query.page(actor: actor(user), q:, page: number, now: NOW)
      def titles(user, **) = page(user, **).rows.map { it.card.title }

      def fiches(title = "Nouvelles fiches", at: NOW - 1.hour, **)
        create_message(author: @kouassi, title:, audience: "classrooms", classrooms: [ @b3 ], published_at: at, **)
      end

      def bouake(at: NOW - 5.hours)
        create_message(author: @traore, title: "Fiches de Bouaké", audience: "classrooms", classrooms: [ @terminale ], published_at: at)
      end

      def devoirs(at: NOW - 2.hours) = create_message(author: @kamate, title: "Devoirs communs", school: @lauriers, published_at: at)
      def rentree(at: NOW - 4.hours, **) = create_message(author: @fatou, title: "Rentrée numérique", audience: "all", published_at: at, **)

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      test "AN-16 — the team: every scheduled or published announcement of another author, newest first" do
        fiches
        devoirs
        bouake
        rentree
        concours = create_message(author: create_team_member(second_factor: false), title: "Concours de maths", school: @lauriers,
                                  published_at: NOW - 3.hours)
        fiches("Sortie au musée", status: "scheduled", at: NOW + 1.day)

        assert_equal [ "Sortie au musée", "Nouvelles fiches", "Devoirs communs", concours.title, "Fiches de Bouaké" ], titles(@fatou)
      end

      test "AN-16 — neither a draft, an archived, a withdrawn nor an ended announcement is to moderate" do
        fiches("Brouillon", status: "draft", at: nil)
        fiches("Archivée", status: "archived")
        fiches("Retirée", status: "withdrawn")
        fiches("Terminée", at: NOW - 40.days)
        fiches("Dernier jour", at: NOW - 30.days + 1.minute)

        assert_equal [ "Dernier jour" ], titles(@fatou)
      end

      test "AN-17 — the direction: the announcements of the teachers of its school only" do
        fiches
        fiches("Sortie au musée", status: "scheduled", at: NOW + 1.day)
        devoirs
        create_message(author: create_school_admin(school: @lauriers, last_name: "Diallo"), title: "Réunion", school: @lauriers)
        rentree
        create_message(author: @fatou, title: "Concours de maths", school: @lauriers)
        bouake

        assert_equal [ "Sortie au musée", "Nouvelles fiches" ], titles(@kamate)
        assert_equal [ "Fiches de Bouaké" ], titles(create_school_admin(school: @bouake))
      end

      test "the team filters by the name or the sigle of the school, without case nor accents; a national one never matches" do
        fiches
        devoirs
        bouake
        rentree

        assert_equal [ "Nouvelles fiches", "Devoirs communs" ], titles(@fatou, q: "college LES lauriers")
        assert_equal [ "Fiches de Bouaké" ], titles(@fatou, q: " lyb ")
        assert_equal [ "Fiches de Bouaké" ], titles(@fatou, q: "Bouake")
        assert_empty titles(@fatou, q: "Abidjan")
        assert_equal [ "Nouvelles fiches", "Devoirs communs", "Fiches de Bouaké" ], titles(@fatou, q: "  ")
      end

      test "the filter is the team's: the direction keeps the teachers of its school" do
        fiches

        assert_equal [ "Nouvelles fiches" ], titles(@kamate, q: "Bouaké")
      end

      test "a teacher or a student has nothing to moderate" do
        fiches
        create_message(author: create_teacher(school: @lauriers, classrooms: [ @b3 ]), title: "D'un collègue", audience: "classrooms",
                       classrooms: [ @b3 ])

        assert_empty titles(create_teacher(school: @lauriers))
        assert_empty titles(create_student(classroom: @b3))
      end

      test "a row: the card of « Reçues », its school (none for a national one), its status and its dates" do
        fiche = fiches(edited_at: NOW - 10.minutes)
        Repositories::Communication::AttachmentStore.new.attach(message_id: fiche.id, kind: :audio, io: StringIO.new("ID3".b + "\x00".b * 64),
                                                                content_type: "audio/mpeg", filename: "fiches.mp3")
        rentree(at: Time.zone.local(2026, 10, 3, 8), ends_at: Time.zone.local(2026, 11, 2))
        create_message(author: @kouassi, title: "Sortie au musée", audience: "classrooms", classrooms: [ @b3 ], status: "scheduled",
                       published_at: Time.zone.local(2026, 10, 5, 10), ends_at: Time.zone.local(2026, 11, 1))

        rows = page(create_team_member(second_factor: false)).rows.index_by { it.card.title }

        card = rows["Nouvelles fiches"].card
        assert_kind_of InboxQuery::MessageCard, card
        assert_equal [ fiche.public_id, :teacher, "Kouassi", "SVT", true, true, false ],
                     [ card.public_id, card.author_role, card.last_name, card.material_name, card.audio?, card.edited?, card.dismissed? ]
        assert_equal [ "Collège Les Lauriers", "published", NOW - 1.hour, Date.new(2026, 11, 3) ],
                     rows["Nouvelles fiches"].to_h.values_at(:school_name, :status, :at, :last_day)
        assert_equal [ nil, "published", Time.zone.local(2026, 10, 3, 8), Date.new(2026, 11, 1) ],
                     rows["Rentrée numérique"].to_h.values_at(:school_name, :status, :at, :last_day)
        assert_equal [ "Collège Les Lauriers", "scheduled", Time.zone.local(2026, 10, 5, 10), Date.new(2026, 10, 31) ],
                     rows["Sortie au musée"].to_h.values_at(:school_name, :status, :at, :last_day)
      end

      test "twenty per page, newest first; a page out of range gives the nearest one" do
        21.times { |index| fiches("Annonce #{index}", at: NOW - (index + 1).minutes) }

        first = page(@fatou)
        second = page(@fatou, number: 2)

        assert_equal [ 20, 1, 2 ], [ first.rows.size, first.page, first.pages ]
        assert_equal "Annonce 0", first.rows.first.card.title
        assert_equal [ [ "Annonce 20" ], 2 ], [ second.rows.map { it.card.title }, second.page ]
        assert_equal 2, page(@fatou, number: 9).page
        assert_equal 1, page(@fatou, number: [ "2" ]).page
      end

      test "nothing to moderate: an empty first page" do
        assert_equal [ [], 1, 1 ], page(@fatou).to_h.values_at(:rows, :page, :pages)
      end

      test "a constant number of queries, whatever the number of announcements and of files" do
        fatou = actor(@fatou)
        moderated = -> { @query.page(actor: fatou, q: "lauriers", page: 1, now: NOW) }
        fiches
        few = count_queries(&moderated)
        6.times do |index|
          message = fiches("Annonce #{index}")
          Repositories::Communication::AttachmentStore.new.attach(message_id: message.id, kind: :image,
                                                                  io: StringIO.new(file_fixture("photos/photo.png").binread),
                                                                  content_type: "image/png", filename: "photo.png")
        end
        devoirs
        bouake

        assert_equal 8, moderated.call.rows.size
        assert_equal few, count_queries(&moderated)
        assert_operator few, :<=, 4
      end
    end
  end
end
