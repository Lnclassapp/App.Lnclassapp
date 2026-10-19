# 🔌 INFRA · Repositories::Catalog::EssentialImageStore
# Rôle : images de fiche en lignes essential_images et fichiers sur le service Active Storage (bucket) : envoyer, compter, servir, purger
# ADR  : 0047, 0060, 0105
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
      rescue ActiveStorage::FileNotFoundError
        # La ligne du blob existe, pas son fichier (bucket vidé) : comme une ligne sans blob, le contrôleur répond 404 et le journalise.
        nil
      end

      # Le fichier part après validation (purge_later, ADR-0047).
      # Chaque image est verrouillée (SKIP LOCKED : une image en cours de rattachement est laissée) puis relue sans essential_id avant
      # destroy! : une image rattachée entre la lecture et la purge ne perd pas son fichier (menace.md, n° 11).
      def purge_orphans(before:)
        orphan_ids(before:).count do |id|
          Orm::EssentialImage.transaction do
            image = Orm::EssentialImage.lock("FOR UPDATE SKIP LOCKED").find_by(id:, essential_id: nil)
            image&.destroy!
          end
        end
      end

      private

      def orphan_ids(before:) = Orm::EssentialImage.where(essential_id: nil, created_at: ...before).ids
    end
  end
end
