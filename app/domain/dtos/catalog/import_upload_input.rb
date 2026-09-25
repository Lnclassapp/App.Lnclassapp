# 🧠 DOMAINE · Dtos::Catalog::ImportUploadInput
# Rôle : forme du fichier téléversé pour un import : type connu, fichier JSON de 20 Mo au plus, empreinte SHA-256
# ADR  : 0039, 0047
module Dtos
  module Catalog
    class ImportUploadInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      MAX_MEGABYTES = Entities::Catalog::ImportKind::MAX_BYTES / (1024 * 1024)

      attribute :kind, :string
      attribute :filename, :string
      # io : tout objet qui répond à read, rewind et size (fichier téléversé, StringIO).
      attr_accessor :io

      validates :kind, inclusion: { in: Entities::Catalog::ImportKind::KINDS }
      validates :io, presence: true
      validates :filename, presence: true, format: { with: /\.json\z/i, allow_blank: true }
      validate :within_size_limit

      def byte_size = io.size

      # Lu une fois, puis rembobiné pour le stockage.
      def checksum_sha256
        @checksum_sha256 ||= begin
          io.rewind
          Digest::SHA256.hexdigest(io.read).tap { io.rewind }
        end
      end

      private

      def within_size_limit
        return if io.nil? || byte_size <= Entities::Catalog::ImportKind::MAX_BYTES

        errors.add(:io, :too_large, count: MAX_MEGABYTES)
      end
    end
  end
end
