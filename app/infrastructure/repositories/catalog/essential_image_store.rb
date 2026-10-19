# 🔌 INFRA · Repositories::Catalog::EssentialImageStore
# Rôle : images de fiche en lignes essential_images et fichiers sur le service Active Storage (bucket) : envoyer, compter, servir, purger
# ADR  : 0047, 0060, 0104
module Repositories
  module Catalog
    class EssentialImageStore
      include Ports::Catalog::EssentialImageStorePort

      EXTENSIONS = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp" }.freeze

      # Le domaine a déjà lu le format dans les octets : pas d'identification, et le blob naît analysé (pas de libvips, ADR-0060).
      def store(data:, content_type:, width:, height:)
        image = Orm::EssentialImage.create!(content_type:, byte_size: data.bytesize, width:, height:,
                                            file: { io: StringIO.new(data), filename: "image.#{EXTENSIONS.fetch(content_type)}",
                                                    content_type:, identify: false, metadata: { analyzed: true } })
        StoredImage.new(public_id: image.public_id, sgid: image.attachable_sgid, width:, height:)
      end

      def count_for(essential_slug:)
        Orm::EssentialImage.joins(:essential).where(essentials: { slug: essential_slug }).count
      end

      # La fiche se lit dans la même requête que la ligne ; le fichier, jamais.
      def find(public_id:)
        image = Orm::EssentialImage.left_joins(:essential).select("essential_images.content_type", "essentials.slug AS essential_slug")
                                   .find_by(public_id:)
        image && ImageState.new(content_type: image.content_type, essential_slug: image.essential_slug)
      end

      def download(public_id:)
        ActiveStorage::Blob.joins(:attachments)
                           .find_by(active_storage_attachments: { name: "file", record_type: Orm::EssentialImage.name,
                                                                  record_id: Orm::EssentialImage.where(public_id:).select(:id) })
                           &.download
      end

      # Le fichier part après validation (purge_later, ADR-0047).
      def purge_orphans(before:)
        Orm::EssentialImage.where(essential_id: nil, created_at: ...before).each(&:destroy!).size
      end
    end
  end
end
