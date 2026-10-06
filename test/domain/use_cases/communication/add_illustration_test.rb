require "test_helper"

# ADR-0081 §4.3, UDR-0075 §3.5 : l'équipe ajoute un dessin à la bibliothèque. La policy d'abord ; puis le nom et le
# poids du fichier, vérifié avant toute lecture ; puis la lecture du SVG par le port, qui rend ses formes reconstruites
# ou la raison de son refus ; l'illustration s'écrit enfin, dans une transaction, avec ces seules formes.
module UseCases
  module Communication
    class AddIllustrationTest < ActiveSupport::TestCase
      Illustration = Entities::Communication::Illustration
      Input = Dtos::Communication::IllustrationInput
      SHAPES = [ { "name" => "rect", "attributes" => { "width" => "48", "height" => "48" }, "children" => [] } ].freeze
      MESSAGES = {
        unsafe: "Ce dessin n'est pas accepté : il contient autre chose que des formes.",
        not_svg: "Ce fichier n'est pas un dessin SVG.",
        empty: "Ce dessin est vide."
      }.freeze
      FULL = "La bibliothèque compte déjà 50 illustrations : retirez-en une avant d'en ajouter."

      # active : le nombre d'illustrations encore proposées (available), celles écrites ici comprises ; added_meanwhile :
      # celles qu'un autre ajout aura écrites quand le verrou de la bibliothèque est obtenu ; calls : l'ordre des appels.
      class FakeIllustrations
        include Ports::Communication::IllustrationRepositoryPort

        attr_reader :created, :calls
        attr_writer :active, :added_meanwhile

        def initialize
          @created = []
          @active = 0
          @added_meanwhile = 0
          @calls = []
        end

        def lock_library
          @calls << :lock
          @active += @added_meanwhile
          true
        end

        def available
          @calls << :count
          Array.new(@active + @created.size) { Illustration.new(name: "Dessin", view_box: "0 0 64 64", shapes: SHAPES, created_by_id: 1) }
        end

        def create(illustration:)
          @calls << :create
          @created << illustration
          illustration.with(id: @created.size, public_id: "ill0000000000#{@created.size}")
        end
      end

      # Le port de lecture : rend ce qu'on lui a dit de rendre, et garde les octets reçus.
      class FakeDrawings
        include Ports::Communication::DrawingReaderPort

        attr_reader :reads

        def initialize(result) = (@result = result) && (@reads = [])

        def read(bytes:)
          @reads << bytes
          @result
        end
      end

      # Un fichier téléversé qui ne se laisse pas lire : le poids doit être refusé sans lui.
      Unreadable = Data.define(:size) do
        def rewind = raise("le fichier ne devait pas être lu")
        def read(*) = raise("le fichier ne devait pas être lu")
      end
      # Un flux dont le poids annoncé est faux : il n'en est jamais lu plus que MAX_BYTES.
      Lying = Data.define(:size, :io) do
        def rewind = io.rewind
        def read(*) = io.read(*)
      end

      setup do
        @illustrations = FakeIllustrations.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def drawing = Shared::Result.success({ view_box: "0 0 64 64", shapes: SHAPES })
      def refused(reason) = Shared::Result.failure(:invalid, errors: { file: [ reason ] })
      def svg = StringIO.new(%(<svg viewBox="0 0 64 64"><rect width="48" height="48"/></svg>))

      def add(dto, actor: @team, read: drawing)
        @drawings = FakeDrawings.new(read)
        AddIllustration.new(illustrations: @illustrations, drawings: @drawings, transaction: @transaction,
                            policy: Policies::Communication::ManageIllustrationsPolicy.new)
                       .call(actor:, dto:)
      end

      test "AV-08 — l'équipe ajoute « Bus scolaire » : ses formes reconstruites sont écrites, à son nom, dans une transaction" do
        result = add(Input.new(name: "  Bus   scolaire ", file: svg))

        assert result.success?
        assert_equal [ Illustration.new(name: "Bus scolaire", view_box: "0 0 64 64", shapes: SHAPES, created_by_id: 7) ],
                     @illustrations.created
        assert_equal [ 1, "ill00000000001", "Bus scolaire" ], [ result.value.id, result.value.public_id, result.value.name ]
        assert_equal [ svg.read.b ], @drawings.reads
        assert_equal 1, @transaction.calls
      end

      test "AV-08 — le fichier est lu en entier jusqu'à 50 Ko, en octets bruts" do
        bytes = "<svg>#{'é' * 100}</svg>".b
        add(Input.new(name: "Bus", file: StringIO.new(bytes)))

        assert_equal [ Encoding::BINARY, bytes ], [ @drawings.reads.first.encoding, @drawings.reads.first ]
      end

      test "AV-11 — un enseignant, une direction, un élève ou un visiteur reçoit :forbidden ; rien n'est lu ni écrit" do
        [ :teacher, :school_admin, :student ].map { Entities::Identity::Actor.new(user_id: 3, role: it) }.push(nil).each do |someone|
          result = add(Input.new(name: "Bus", file: svg), actor: someone)

          assert_equal :forbidden, result.code, someone.inspect
          assert_empty @drawings.reads
        end
        assert_empty @illustrations.created
        assert_equal 0, @transaction.calls
      end

      test "AV-09 — un dessin refusé par la lecture donne sa raison sous « Dessin » ; rien n'est écrit" do
        MESSAGES.each do |reason, message|
          result = add(Input.new(name: "Bus", file: svg), read: refused(reason))

          assert_equal :invalid, result.code
          assert_equal({ file: [ message ] }, result.errors, reason)
        end
        assert_empty @illustrations.created
        assert_equal 0, @transaction.calls
      end

      test "AV-09 — un fichier de plus de 50 Ko est refusé avant toute lecture" do
        result = add(Input.new(name: "Bus", file: Unreadable.new(size: Illustration::MAX_BYTES + 1)))

        assert_equal :invalid, result.code
        assert_equal({ file: [ "Ce fichier est trop lourd (50 Ko au plus)." ] }, result.errors)
        assert_empty @drawings.reads
        assert_empty @illustrations.created
      end

      test "un fichier de 50 Ko tout juste est lu ; d'un flux au poids trompeur, jamais plus de 50 Ko ne sont lus" do
        add(Input.new(name: "Bus", file: StringIO.new("a" * Illustration::MAX_BYTES)))
        assert_equal Illustration::MAX_BYTES, @drawings.reads.first.bytesize

        add(Input.new(name: "Bus", file: Lying.new(size: 10, io: StringIO.new("a" * (Illustration::MAX_BYTES * 2)))))
        assert_equal Illustration::MAX_BYTES, @drawings.reads.first.bytesize
      end

      test "un fichier vide est confié à la lecture, qui le refuse" do
        add(Input.new(name: "Bus", file: StringIO.new("")), read: refused(:not_svg))

        assert_equal [ "" ], @drawings.reads
      end

      test "sans fichier, la saisie est refusée sans rien lire ; sans nom valide, le dessin est lu, et les raisons s'affichent ensemble" do
        assert_equal({ file: [ "Choisissez un dessin SVG." ] }, add(Input.new(name: "Bus")).errors)
        assert_empty @drawings.reads
        assert_equal({ name: [ "Saisissez un nom." ], file: [ "Choisissez un dessin SVG." ] }, add(Input.new).errors)
        assert_empty @drawings.reads

        { Input.new(name: "   ", file: svg) => { name: [ "Saisissez un nom." ] },
          Input.new(name: "B" * 31, file: svg) => { name: [ "Le nom compte 30 caractères au plus." ] } }.each do |dto, errors|
          result = add(dto)

          assert_equal [ :invalid, errors ], [ result.code, result.errors ], dto.inspect
          assert_equal 1, @drawings.reads.size
        end
        assert_equal({ name: [ "Saisissez un nom." ], file: [ MESSAGES[:unsafe] ] }, add(Input.new(file: svg), read: refused(:unsafe)).errors)
        assert_empty @illustrations.created
      end

      test "la bibliothèque est plafonnée à 50 illustrations actives : la 51ᵉ est refusée sous « Dessin », rien n'est lu ni écrit" do
        @illustrations.active = Illustration::LIBRARY_CAP

        result = add(Input.new(name: "Bus", file: svg))

        assert_equal 50, Illustration::LIBRARY_CAP
        assert_equal [ :invalid, { file: [ FULL ] } ], [ result.code, result.errors ]
        assert_empty @drawings.reads
        assert_empty @illustrations.created
        assert_equal 0, @transaction.calls
      end

      # Phase 5 (F3) : l'ordre des appels seulement ; le verrou lui-même est prouvé sur deux connexions, plus bas.
      test "le plafond est recompté sous le verrou de la bibliothèque, dans la transaction : un ajout fait entre-temps le remplit" do
        @illustrations.active = Illustration::LIBRARY_CAP - 1
        @illustrations.added_meanwhile = 1

        result = add(Input.new(name: "Bus", file: svg))

        assert_equal [ :invalid, { file: [ FULL ] } ], [ result.code, result.errors ]
        assert_equal [ :count, :lock, :count ], @illustrations.calls
        assert_empty @illustrations.created
        assert_equal 1, @transaction.calls
      end

      test "sous le verrou, une bibliothèque de 49 reçoit l'ajout : compte, verrou, recompte, écriture" do
        @illustrations.active = Illustration::LIBRARY_CAP - 1

        assert add(Input.new(name: "Bus", file: svg)).success?
        assert_equal [ :count, :lock, :count, :create ], @illustrations.calls
      end

      test "avec 49 illustrations actives, l'ajout passe ; la suivante est refusée" do
        @illustrations.active = Illustration::LIBRARY_CAP - 1

        assert add(Input.new(name: "Bus", file: svg)).success?
        assert_equal({ file: [ FULL ] }, add(Input.new(name: "Car", file: svg)).errors)
        assert_equal 1, @illustrations.created.size
      end

      # Défense en profondeur (ADR-0081 §4.3) : le domaine revérifie ce que rend le port, quel qu'en soit l'adaptateur.
      test "AV-09 — des formes interdites rendues par le port ne sont pas écrites : seules les formes permises le sont" do
        forbidden = [ { "name" => "script", "attributes" => {}, "children" => [] },
                      { "name" => "rect", "attributes" => { "onload" => "alert(1)" }, "children" => [] },
                      { "name" => "path", "attributes" => { "d" => "M0 0" }, "children" => [ SHAPES.first ] },
                      { "name" => "rect", "attributes" => { "width" => "url(#a)" }, "children" => [] },
                      "<script>alert(1)</script>" ]

        result = add(Input.new(name: "Bus", file: svg), read: Shared::Result.success({ view_box: "0 0 64 64", shapes: forbidden + SHAPES }))

        assert result.success?
        assert_equal [ SHAPES ], @illustrations.created.map(&:shapes)
      end

      test "AV-09 — si aucune forme rendue par le port ne passe la liste blanche, ou si sa viewBox n'est pas conforme : « Ce dessin est vide. »" do
        { "0 0 64 64" => [ { "name" => "script", "attributes" => {}, "children" => [] } ],
          "0 0 64 64\" onload=\"alert(1)" => SHAPES,
          nil => SHAPES,
          "0 0 64 64 " => nil }.each do |view_box, shapes|
          result = add(Input.new(name: "Bus", file: svg), read: Shared::Result.success({ view_box:, shapes: }))

          assert_equal [ :invalid, { file: [ MESSAGES[:empty] ] } ], [ result.code, result.errors ], [ view_box, shapes ].inspect
        end
        assert_empty @illustrations.created
        assert_equal 0, @transaction.calls
      end

      test "un nom de 30 caractères est accepté" do
        assert add(Input.new(name: "B" * 30, file: svg)).success?
      end
    end

    # F3 of the security review (phase 5 of annonces-v2): two additions at the same instant on a library of 49 drawings,
    # on two connections, outside any test transaction. The library is locked, then counted again, in the transaction of
    # the addition: one passes, the other one is refused under « Dessin ».
    class AddIllustrationConcurrencyTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      FULL = "La bibliothèque compte déjà 50 illustrations : retirez-en une avant d'en ajouter."

      # An addition about to write says so, and writes only once the test lets it.
      class Meeting < Repositories::Communication::IllustrationRepository
        def initialize(arrived:, go:)
          super()
          @arrived = arrived
          @go = go
        end

        def create(illustration:)
          @arrived << true
          @go.pop(timeout: 10)
          super
        end
      end

      setup do
        @fatou = create_team_member(second_factor: false)
        (Entities::Communication::Illustration::LIBRARY_CAP - 1).times { create_illustration(name: "Dessin #{it}", created_by: @fatou) }
      end

      teardown do
        Orm::MessageIllustration.where(created_by_id: @fatou.id).delete_all
        Orm::User.where(id: @fatou.id).delete_all
      end

      def add(name, illustrations)
        AddIllustration.new(illustrations:, drawings: ::Communication::DrawingReader.new,
                            transaction: Repositories::Shared::Transaction.new,
                            policy: Policies::Communication::ManageIllustrationsPolicy.new)
                       .call(actor: Entities::Identity::Actor.new(user_id: @fatou.id, role: :team, team_role: "content"),
                             dto: Dtos::Communication::IllustrationInput.new(
                               name:, file: StringIO.new(%(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="48" height="48"/></svg>))
                             ))
      end

      # Uncached: the query cache of the test would give the first answer again.
      def waiting?(pids)
        Orm::MessageIllustration.uncached do
          Orm::MessageIllustration.connection.select_value(
            "SELECT EXISTS (SELECT 1 FROM pg_locks WHERE pid IN (#{pids.map { Integer(it) }.join(', ')}) AND NOT granted)"
          )
        end
      end

      # The first addition about to write waits until the other one is about to write too, or waits on a lock: their
      # order is given by the lock of the library, never by a sleep.
      test "F3 — two additions at the same instant on a library of 49: one passes, the other one is refused under « Dessin »" do
        arrived = Queue.new
        go = Queue.new
        backends = Queue.new
        threads = [ "Bus", "Car" ].map do |name|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do |connection|
              backends << connection.select_value("SELECT pg_backend_pid()")
              add(name, Meeting.new(arrived:, go:))
            end
          end
        end
        pids = Array.new(2) { backends.pop(timeout: 5) }
        assert arrived.pop(timeout: 5), "aucun ajout n'arrive à l'écriture"
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until arrived.size.positive? || waiting?(pids) || threads.none?(&:alive?)
          flunk "le second ajout n'arrive ni à l'écriture ni au verrou" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.01
        end
        2.times { go << true }
        results = threads.map(&:value)

        assert_equal [ 1, 1 ], [ results.count(&:success?), results.count { it.code == :invalid } ]
        assert_equal({ file: [ FULL ] }, results.find(&:failure?).errors)
        assert_equal Entities::Communication::Illustration::LIBRARY_CAP, Orm::MessageIllustration.where(retired_at: nil).count
      ensure
        2.times { go << true }
        threads&.each { it.join(10) }
      end
    end
  end
end
