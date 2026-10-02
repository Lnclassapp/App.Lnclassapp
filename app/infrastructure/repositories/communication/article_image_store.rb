# 🔌 INFRA · Repositories::Communication::ArticleImageStore
# Rôle : images d'article en lignes article_images et fichiers sur le service Active Storage (bucket) : envoyer, servir, purger
# ADR  : 0047, 0060, 0073
module Repositories
  module Communication
    class ArticleImageStore
      include Ports::Communication::ArticleImageStorePort

      EXTENSIONS = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp" }.freeze

      # Le domaine a déjà lu le format dans les octets : pas d'identification, et le blob naît analysé, sans quoi
      # AnalyzeJob chercherait libvips, absent en production (comme la photo de profil, ADR-0060).
      def store(data:, content_type:, width:, height:)
        image = Orm::ArticleImage.create!(content_type:, byte_size: data.bytesize, width:, height:,
                                          file: { io: StringIO.new(data), filename: "image.#{EXTENSIONS.fetch(content_type)}",
                                                  content_type:, identify: false, metadata: { analyzed: true } })
        StoredImage.new(public_id: image.public_id, sgid: image.attachable_sgid, width:, height:)
      end

      # L'état de l'article se lit dans la même requête que la ligne.
      def read(public_id:)
        image = Orm::ArticleImage.left_joins(:article).select("article_images.*", "articles.status AS article_status")
                                 .find_by(public_id:)
        image && ServedImage.new(content_type: image.content_type, data: image.file.download, article_status: image.article_status)
      end

      # Une couverture n'est jamais purgée, même détachée. Le fichier part après validation (purge_later, ADR-0047).
      def purge_orphans(before:)
        Orm::ArticleImage.where(article_id: nil, created_at: ...before)
                         .where.not(id: Orm::Article.where.not(cover_image_id: nil).select(:cover_image_id))
                         .each(&:destroy!).size
      end
    end
  end
end
