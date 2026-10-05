require "test_helper"

module Repositories
  module Communication
    # ADR-0081 §4.3 et §6 : le port gelé de la bibliothèque d'illustrations de l'équipe. Une illustration se lit par son
    # public_id, s'écrit avec ses formes reconstruites, se renomme, se retire ; elle n'est jamais supprimée.
    class IllustrationRepositoryTest < ActiveSupport::TestCase
      Illustration = Entities::Communication::Illustration
      NOW = Time.utc(2026, 10, 5, 10)
      RECT = { "name" => "rect", "attributes" => { "x" => "8", "y" => "8", "width" => "48", "height" => "48", "rx" => "6" },
               "children" => [] }.freeze
      PATH = { "name" => "path", "attributes" => { "d" => "M4 4h56v56H4z", "fill-rule" => "evenodd" }, "children" => [] }.freeze
      GROUP = { "name" => "g", "attributes" => { "transform" => "translate(2,2)" }, "children" => [ PATH ] }.freeze

      setup do
        @repository = IllustrationRepository.new
        @team = create_team_member(second_factor: false)
      end

      def drawing(**changes)
        Illustration.new(name: "Bus scolaire", view_box: "0 0 64 64", shapes: [ RECT, GROUP ], created_by_id: @team.id).with(**changes)
      end

      def read(row) = @repository.find_by_public_id(public_id: row.public_id)

      test "AV-08 — create writes the drawing and gives it back with its id and an opaque public_id; its shapes keep their format" do
        created = @repository.create(illustration: drawing)

        assert_kind_of Integer, created.id
        assert_equal 14, created.public_id.size
        assert_equal [ "Bus scolaire", "0 0 64 64", [ RECT, GROUP ], @team.id, nil ],
                     [ created.name, created.view_box, created.shapes, created.created_by_id, created.retired_at ]
        assert_equal created, read(created)
        assert(created.shapes.all? { Illustration.valid_shape?(it, depth: 1) })
      end

      test "create keeps a public_id drawn by the domain" do
        assert_equal "abcdefghijkmno", @repository.create(illustration: drawing(public_id: "abcdefghijkmno")).public_id
        assert Orm::MessageIllustration.exists?(public_id: "abcdefghijkmno")
      end

      test "find_by_public_id reads every field of the row, and nil for an unknown drawing" do
        row = create_illustration(name: "Cantine", created_by: @team, view_box: "0 0 32 32", shapes: [ PATH ], retired_at: NOW)

        assert_equal Illustration.new(id: row.id, public_id: row.public_id, name: "Cantine", view_box: "0 0 32 32",
                                      shapes: [ PATH ], created_by_id: @team.id, retired_at: NOW), read(row)
        assert_nil @repository.find_by_public_id(public_id: "inconnue")
      end

      test "AV-10 — available gives the drawings still offered, the oldest first, then by id; a retired one is not offered" do
        later = create_illustration(name: "Cantine", created_by: @team, created_at: NOW - 1.day)
        sooner = create_illustration(name: "Bus", created_by: @team, created_at: NOW - 3.days)
        tied = Array.new(2) { create_illustration(name: "Sortie #{it}", created_by: @team, created_at: NOW - 2.days) }
        create_illustration(name: "Ancienne", created_by: @team, created_at: NOW - 4.days, retired_at: NOW)

        available = @repository.available

        assert_equal [ sooner, *tied.sort_by(&:id), later ].map(&:public_id), available.map(&:public_id)
        assert_equal read(later), available.last
      end

      test "available is empty while the team has added nothing" do
        assert_empty @repository.available
      end

      test "AV-10 — find_all_by_ids gives each drawing by its id, a retired one included, in one query" do
        offered = create_illustration(name: "Bus", created_by: @team)
        retired = create_illustration(name: "Cantine", created_by: @team, retired_at: NOW)
        found = nil

        assert_queries_count(1) { found = @repository.find_all_by_ids(ids: [ offered.id, retired.id, 0, offered.id ]) }
        assert_equal({ offered.id => read(offered), retired.id => read(retired) }, found)
        assert_equal({}, @repository.find_all_by_ids(ids: []))
      end

      test "rename writes the new name only, and gives the drawing back; nil for an unknown id" do
        row = create_illustration(name: "Bus", created_by: @team)

        renamed = @repository.rename(id: row.id, name: "Bus scolaire")

        assert_equal read(row), renamed
        assert_equal [ "Bus scolaire", "0 0 64 64", row.shapes ], [ renamed.name, renamed.view_box, renamed.shapes ]
        assert_nil @repository.rename(id: 0, name: "Bus")
      end

      test "AV-10 — retire dates the retirement once and never deletes the drawing; nil for an unknown id" do
        row = create_illustration(name: "Bus", created_by: @team)

        retired = @repository.retire(id: row.id, at: NOW)

        assert_equal [ NOW, true ], [ retired.retired_at, retired.retired? ]
        assert_equal retired, read(row)
        assert_equal NOW, @repository.retire(id: row.id, at: NOW + 1.day).retired_at
        assert Orm::MessageIllustration.exists?(row.id)
        assert_nil @repository.retire(id: 0, at: NOW)
      end

      test "the factories: a drawing of the team, and a message that carries it instead of a base key" do
        row = create_illustration(name: "Bus scolaire", created_by: @team)
        message = create_message(author: @team, audience: "all", illustration: row, theme: "mangue")
        base = create_message(author: @team, audience: "all")

        assert_equal [ "0 0 64 64", 1, nil, @team ], [ row.view_box, row.shapes.size, row.retired_at, row.created_by ]
        assert(row.shapes.all? { Illustration.valid_shape?(it, depth: 1) })
        assert_equal [ nil, row.id, "mangue", row ], [ message.illustration, message.illustration_id, message.theme, message.library_illustration ]
        assert_equal [ "info", nil, "ciel", nil ], [ base.illustration, base.illustration_id, base.theme, base.library_illustration ]
      end
    end
  end
end

module Repositories
  module Communication
    # Phase 5 of annonces-v2 (F3): lock_library locks the library in the caller's transaction, so that two additions
    # follow each other; another connection cannot take that lock before the transaction ends, and still reads the
    # library. Outside any test transaction: each thread has its own connection.
    class IllustrationLibraryLockTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      setup do
        @repository = IllustrationRepository.new
        @team = create_team_member(second_factor: false)
        create_illustration(name: "Bus scolaire", created_by: @team)
      end

      teardown do
        Orm::MessageIllustration.where(created_by_id: @team.id).delete_all
        Orm::User.where(id: @team.id).delete_all
      end

      def other_connection(&) = Thread.new { ActiveRecord::Base.connection_pool.with_connection(&) }.value

      # From another connection, which waits 300 ms at most: true when it could lock the library.
      def lockable?
        other_connection do
          Orm::MessageIllustration.transaction do
            Orm::MessageIllustration.connection.execute("SET LOCAL lock_timeout = '300ms'")
            IllustrationRepository.new.lock_library
          end
        rescue ActiveRecord::LockWaitTimeout
          false
        end
      end

      test "F3 — lock_library holds the library until the end of the caller's transaction, without blocking its reading" do
        held = Orm::MessageIllustration.transaction do
          @repository.lock_library
          [ lockable?, other_connection { IllustrationRepository.new.available.map(&:name) } ]
        end

        assert_equal [ false, [ "Bus scolaire" ] ], held
        assert lockable?
      end
    end
  end
end
