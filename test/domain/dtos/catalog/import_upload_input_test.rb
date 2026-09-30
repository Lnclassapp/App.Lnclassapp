require "test_helper"

module Dtos
  module Catalog
    class ImportUploadInputTest < ActiveSupport::TestCase
      Upload = ImportUploadInput::Upload
      MEGABYTE = 1024 * 1024

      def upload(content = %({"format":"lnclass.schools"}), filename: "ecoles.json") = Upload.new(io: StringIO.new(content), filename:)

      def input(*files, kind: "schools") = ImportUploadInput.new(kind:, files: files.empty? ? [ upload ] : files)

      def error_of(form) = form.tap(&:valid?).errors.details[:files].sole.then { [ it[:error], it.except(:error) ] }

      test "un fichier JSON d'un type connu est valide ; sa taille et son empreinte viennent de son contenu" do
        form = input
        form.files.first.io.read(3)

        assert form.valid?
        assert_equal 28, form.byte_size
        assert_equal Digest::SHA256.hexdigest(%({"format":"lnclass.schools"})), form.checksum_sha256
        assert_equal 0, form.files.first.io.pos
      end

      # ADR-0068 : l'empreinte de plusieurs fichiers est celle de leurs empreintes, dans l'ordre d'envoi.
      test "plusieurs fichiers : la taille est la somme, l'empreinte dépend de l'ordre" do
        a = upload("{}", filename: "a.json")
        b = upload("[]", filename: "b.json")
        checksums = [ "{}", "[]" ].map { Digest::SHA256.hexdigest(it) }

        form = input(a, b, kind: "course_tree")

        assert form.valid?
        assert_equal 4, form.byte_size
        assert_equal Digest::SHA256.hexdigest(checksums.join("\n")), form.checksum_sha256
        assert_not_equal form.checksum_sha256, input(upload("[]", filename: "b.json"), upload("{}", filename: "a.json"), kind: "course_tree").checksum_sha256
      end

      test "20 Mo par fichier passent, 20 Mo et un octet sont refusés et nomment le fichier" do
        limit = Entities::Catalog::ImportKind::MAX_BYTES

        assert input(upload("x" * limit)).valid?
        assert_equal [ :too_large, { filename: "gros.json", count: 20 } ], error_of(input(upload("x" * (limit + 1), filename: "gros.json")))
        assert_equal [ "« gros.json » dépasse 20 Mo." ], input(upload("x" * (limit + 1), filename: "gros.json")).tap(&:valid?).errors.to_hash[:files]
      end

      # IM-07 : les plafonds de l'envoi, par type.
      test "50 fichiers et 50 Mo passent pour les cours complets ; 51 fichiers ou 50 Mo et un octet sont refusés" do
        assert input(*Array.new(50) { upload("{}", filename: "c#{it}.json") }, kind: "course_tree").valid?
        assert_equal [ :too_many, { count: 50, value: 51 } ],
                     error_of(input(*Array.new(51) { upload("{}", filename: "c#{it}.json") }, kind: "course_tree"))

        full = [ 20, 20, 10 ].each_with_index.map { |megabytes, index| upload("x" * (megabytes * MEGABYTE), filename: "#{index}.json") }
        assert input(*full, kind: "course_tree").valid?
        assert_equal [ :total_too_large, { count: 50, value: "50,0" } ],
                     error_of(input(*full, upload("x", filename: "un-octet.json"), kind: "course_tree"))
      end

      # IM-09 : un seul fichier pour les autres types.
      test "deux fichiers pour un type à un seul fichier sont refusés" do
        assert_equal [ :too_many, { count: 1, value: 2 } ], error_of(input(upload, upload(filename: "b.json")))
      end

      test "un type inconnu, aucun fichier ou un fichier qui n'est pas du JSON sont refusés" do
        assert input(kind: "regions").tap(&:valid?).errors.of_kind?(:kind, :inclusion)
        assert_equal [ :blank, {} ], error_of(ImportUploadInput.new(kind: "schools", files: nil))
        assert_equal [ :blank, {} ], error_of(ImportUploadInput.new(kind: "schools"))
        assert_equal [ :not_json, { filename: "ecoles.csv" } ], error_of(input(upload(filename: "ecoles.csv")))
        assert_equal [ :not_json, { filename: "" } ], error_of(input(upload(filename: nil)))
      end
    end
  end
end
