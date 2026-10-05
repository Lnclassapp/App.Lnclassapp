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

      class FakeIllustrations
        include Ports::Communication::IllustrationRepositoryPort

        attr_reader :created

        def initialize = @created = []

        def create(illustration:)
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

      test "un nom de 30 caractères est accepté" do
        assert add(Input.new(name: "B" * 30, file: svg)).success?
      end
    end
  end
end
