# 🧠 DOMAINE · Dtos::Catalog::ImportUploadInput
# Rôle : forme d'un envoi d'import : type connu, 1 à N fichiers JSON dans les plafonds du type, empreinte SHA-256
# ADR  : 0039, 0047, 0068
module Dtos
  module Catalog
    class ImportUploadInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      MAX_MEGABYTES = Entities::Catalog::ImportKind::MAX_BYTES / (1024 * 1024)
      MEGABYTE = 1024 * 1024

      # Un fichier téléversé. io : tout objet qui répond à read, rewind et size (fichier téléversé, StringIO).
      Upload = Data.define(:io, :filename) do
        def byte_size = io.size

        # Lu une fois, puis rembobiné pour le stockage.
        def checksum_sha256
          io.rewind
          Digest::SHA256.hexdigest(io.read).tap { io.rewind }
        end
      end

      attribute :kind, :string
      attr_reader :files

      validates :kind, inclusion: { in: Entities::Catalog::ImportKind::KINDS }
      validate :within_limits

      def files=(uploads)
        @files = Array(uploads)
      end

      def files = @files || []

      def byte_size = files.sum(&:byte_size)

      # Un fichier : son empreinte. Plusieurs : l'empreinte de leurs empreintes, dans l'ordre d'envoi (ADR-0068).
      def checksum_sha256
        @checksum_sha256 ||= begin
          checksums = files.map(&:checksum_sha256)
          checksums.one? ? checksums.first : Digest::SHA256.hexdigest(checksums.join("\n"))
        end
      end

      private

      # Un seul message à la fois, du plus simple à corriger au plus global.
      def within_limits
        return errors.add(:files, :blank) if files.empty?
        return unless Entities::Catalog::ImportKind.valid?(kind)

        definition = Entities::Catalog::ImportKind.fetch(kind)
        return errors.add(:files, :too_many, count: definition.max_files, value: files.size) if files.size > definition.max_files

        file_error || total_error(definition)
      end

      def file_error
        not_json = files.find { |file| !file.filename.to_s.match?(/\.json\z/i) }
        return errors.add(:files, :not_json, filename: not_json.filename.to_s) if not_json

        too_large = files.find { |file| file.byte_size > Entities::Catalog::ImportKind::MAX_BYTES }
        errors.add(:files, :too_large, filename: too_large.filename, count: MAX_MEGABYTES) if too_large
      end

      def total_error(definition)
        return if byte_size <= definition.max_total_bytes

        errors.add(:files, :total_too_large, count: definition.max_total_bytes / MEGABYTE,
                                             value: (byte_size.to_f / MEGABYTE).round(1).to_s.tr(".", ","))
      end
    end
  end
end
