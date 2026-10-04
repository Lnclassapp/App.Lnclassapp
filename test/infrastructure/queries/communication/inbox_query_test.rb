require "test_helper"

# ADR-0069 §4.3, UDR-0056 §3.5 and §3.7: the cards of the student's carousel (direction, teachers, team; newest first in
# each group; five at most; the dismissed ones left out) and of the « Reçues » list (every readable message, newest first,
# twenty per page, the dismissed ones marked). Both start from the single reading rule, in a constant number of queries.
module Queries
  module Communication
    class InboxQueryTest < ActiveSupport::TestCase
      AUDIO = ("ID3".b + "\x00".b * 64).freeze

      setup do
        @school = create_school(name: "Collège Les Lauriers")
        @classroom = create_classroom(school: @school, name: "3ème B")
        @awa = create_student(classroom: @classroom, first_name: "Awa")
        @kouassi = create_teacher(school: @school, material: create_material(name: "SVT"), classrooms: [ @classroom ],
                                  gender: "male", last_name: "Kouassi")
        @kamate = create_school_admin(school: @school, gender: "female", last_name: "Kamaté")
        @fatou = create_team_member(second_factor: false)
        @query = InboxQuery.new
        @now = Time.current
      end

      def reader(user = @awa)
        ReadableMessages.new.reader_for(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: user.id))
      end

      def carousel(user = @awa) = @query.carousel(reader: reader(user), now: @now)
      def page(number = 1, user = @awa) = @query.page(reader: reader(user), now: @now, page: number)
      def titles(cards) = cards.map(&:title)

      def from_direction(title, at: 1.hour.ago, **) = create_message(author: @kamate, title:, school: @school, published_at: at, **)
      def from_teacher(title, at: 1.hour.ago, **)
        create_message(author: @kouassi, title:, audience: "classrooms", classrooms: [ @classroom ], published_at: at, **)
      end
      def from_team(title, at: 1.hour.ago, **) = create_message(author: @fatou, title:, audience: "all", published_at: at, **)

      def attach(message, kind, data = AUDIO, content_type: "audio/mpeg")
        Repositories::Communication::AttachmentStore.new.attach(message_id: message.id, kind:, io: StringIO.new(data),
                                                                content_type:, filename: "fichier")
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      test "AN-10 — the carousel: the direction, then the teachers newest first, then the newest of the team, five at most" do
        from_direction("Devoirs communs", at: 5.hours.ago)
        from_teacher("Fiches 1", at: 3.hours.ago)
        from_teacher("Fiches 3", at: 1.hour.ago)
        from_teacher("Fiches 2", at: 2.hours.ago)
        from_team("Rentrée ancienne", at: 4.hours.ago)
        from_team("Rentrée numérique", at: 30.minutes.ago)

        result = carousel

        assert_equal [ "Devoirs communs", "Fiches 3", "Fiches 2", "Fiches 1", "Rentrée numérique" ], titles(result.cards)
        assert result.any_readable?
        assert_equal [ "Rentrée numérique", "Fiches 3", "Fiches 2", "Fiches 1", "Rentrée ancienne", "Devoirs communs" ],
                     titles(page.cards)
      end

      test "AN-12 — a dismissed message leaves the carousel, and stays in the list, marked dismissed" do
        fiches = from_teacher("Nouvelles fiches")
        from_team("Rentrée numérique")
        dismiss_message(message: fiches, user: @awa)
        dismiss_message(message: from_direction("Devoirs communs"), user: create_student(classroom: @classroom))

        assert_equal [ "Devoirs communs", "Rentrée numérique" ], titles(carousel.cards)
        assert_equal({ "Nouvelles fiches" => true, "Rentrée numérique" => false, "Devoirs communs" => false },
                     page.cards.to_h { [ it.title, it.dismissed? ] })
        assert_not carousel.cards.any?(&:dismissed?)
      end

      test "AN-12 — every message dismissed: no card in the carousel, which still has readable messages" do
        dismiss_message(message: from_teacher("Nouvelles fiches"), user: @awa)

        result = carousel

        assert_empty result.cards
        assert result.any_readable?
      end

      test "AN-11 — no readable message: no card and nothing readable, an empty first page" do
        create_message(author: @kouassi, title: "Pour une autre classe", audience: "classrooms",
                       classrooms: [ create_classroom(school: @school) ])

        assert_equal [ [], false ], [ carousel.cards, carousel.any_readable? ]
        assert_equal [ [], 1, 1 ], [ page.cards, page.page, page.pages ]
      end

      test "a card carries its text, its signature, whether it is official, edited, and which files it has" do
        fiches = from_teacher("Nouvelles fiches", body: "Elles sont en ligne.", illustration: "sheets", edited_at: 10.minutes.ago)
        attach(fiches, :audio)
        devoirs = from_direction("Devoirs communs")
        attach(devoirs, :image, file_fixture("photos/photo.png").binread, content_type: "image/png")
        from_team("Rentrée numérique")

        cards = page.cards.index_by(&:title)

        assert_equal [ fiches.public_id, "Elles sont en ligne.", "sheets", :teacher, "male", "Kouassi", "SVT" ],
                     cards["Nouvelles fiches"].to_h.values_at(:public_id, :body, :illustration, :author_role, :gender, :last_name, :material_name)
        assert_equal [ false, false, true, true, false ], %i[official? image? audio? edited? anonymized?].map { cards["Nouvelles fiches"].public_send(it) }
        assert_equal [ :school_admin, "female", "Kamaté", nil ], cards["Devoirs communs"].to_h.values_at(:author_role, :gender, :last_name, :material_name)
        assert_equal [ true, true, false, false ], %i[official? image? audio? edited?].map { cards["Devoirs communs"].public_send(it) }
        assert_equal [ :team, false, false, false ], [ cards["Rentrée numérique"].author_role, cards["Rentrée numérique"].official?,
                                                       cards["Rentrée numérique"].image?, cards["Rentrée numérique"].audio? ]
      end

      test "an anonymized author is marked on the card" do
        from_teacher("Nouvelles fiches")
        @kouassi.update!(anonymized_at: Time.current)

        assert page.cards.sole.anonymized?
      end

      test "the list: twenty per page, newest first; a page out of range gives the nearest one" do
        21.times { |index| from_team("Annonce #{index}", at: (index + 1).minutes.ago) }

        first = page
        assert_equal [ 20, 1, 2 ], [ first.cards.size, first.page, first.pages ]
        assert_equal "Annonce 0", first.cards.first.title
        assert_equal [ [ "Annonce 20" ], 2 ], [ titles(page(2).cards), page(2).page ]
        assert_equal 2, page("9").page
        assert_equal 1, page("abc").page
        assert_equal 1, page(nil).page
      end

      test "card: one readable card, with its dismissed flag; nil when the reader does not read it" do
        fiches = from_teacher("Nouvelles fiches")
        dismiss_message(message: fiches, user: @awa)

        card = @query.card(reader: reader, now: @now, public_id: fiches.public_id)

        assert_equal [ "Nouvelles fiches", true ], [ card.title, card.dismissed? ]
        assert_nil @query.card(reader: reader(create_student), now: @now, public_id: fiches.public_id)
      end

      test "cards: the cards of any relation of messages, in its order, unmarked without a reader" do
        older = from_team("Ancienne", at: 2.hours.ago)
        newer = from_team("Récente")
        dismiss_message(message: older, user: @awa)

        cards = @query.cards(Orm::Message.where(id: [ older.id, newer.id ]).order(:published_at))

        assert_equal [ [ "Ancienne", false ], [ "Récente", false ] ], cards.map { [ it.title, it.dismissed? ] }
      end

      test "ADR-0067 — the carousel and the list cost the same number of queries for one message or for eight" do
        build = lambda do |count|
          count.times do |index|
            message = index.even? ? from_teacher("Fiches #{index}") : from_team("Équipe #{index}")
            attach(message, :audio)
            dismiss_message(message:, user: @awa) if index == 2
          end
        end
        awa = reader
        costs = -> { [ count_queries { @query.carousel(reader: awa, now: @now) }, count_queries { @query.page(reader: awa, now: @now, page: 1) } ] }
        build.call(1)
        small = costs.call
        build.call(7)

        assert_equal 8, page.cards.size
        assert_equal small, costs.call
      end
    end
  end
end
