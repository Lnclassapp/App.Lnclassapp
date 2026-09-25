require "test_helper"

module Dtos
  module Catalog
    class ImportUploadInputTest < ActiveSupport::TestCase
      def input(content = %({"format":"lnclass.schools"}), kind: "schools", filename: "ecoles.json")
        ImportUploadInput.new(kind:, filename:, io: content && StringIO.new(content))
      end

      test "un fichier JSON d'un type connu est valide ; sa taille et son empreinte viennent de son contenu" do
        upload = input
        upload.io.read(3)

        assert upload.valid?
        assert_equal 28, upload.byte_size
        assert_equal Digest::SHA256.hexdigest(%({"format":"lnclass.schools"})), upload.checksum_sha256
        assert_equal 0, upload.io.pos
      end

      test "20 Mo passent, 20 Mo et un octet sont refusés avec too_large" do
        limit = Entities::Catalog::ImportKind::MAX_BYTES

        assert input("x" * limit).valid?

        upload = input("x" * (limit + 1))

        assert_not upload.valid?
        assert upload.errors.of_kind?(:io, :too_large)
        assert_equal [ "dépasse 20 Mo" ], upload.errors.to_hash[:io]
      end

      test "un type inconnu, un fichier absent ou qui n'est pas du JSON sont refusés" do
        assert input(kind: "drenas").tap(&:valid?).errors.of_kind?(:kind, :inclusion)
        assert input(nil).tap(&:valid?).errors.of_kind?(:io, :blank)
        assert input(filename: "ecoles.csv").tap(&:valid?).errors.of_kind?(:filename, :invalid)
        assert input(filename: "").tap(&:valid?).errors.of_kind?(:filename, :blank)
      end
    end
  end
end
