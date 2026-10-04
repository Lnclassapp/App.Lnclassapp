# 🔌 INFRA · Repositories::Communication::ArticleRepository
# Rôle : traduit Orm::Article, son texte Action Text et ses images ↔ Entities::Communication::Article ; slug figé, lectures comptées
# ADR  : 0029, 0035, 0047, 0074
module Repositories
  module Communication
    class ArticleRepository
      include Ports::Communication::ArticleRepositoryPort

      ATTACHMENT = Repositories::Shared::RichTextSanitizer::ATTACHMENT
      IMAGE_MODEL = "Orm::ArticleImage"
      SLUG_INDEX = "index_articles_on_slug"
      # Deux collisions de slug concurrentes de suite, ou une image prise entre-temps par un autre article : le geste se
      # refait (il trouvera un slug libre ; l'image prise ne sera plus admise).
      WRITE_FAILED = ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      # Une pièce jointe dont le sgid ne se vérifie pas (altéré, ou signé par une autre clé) : l'assainir la retirerait,
      # et l'image qu'elle désignait serait détruite comme n'étant plus citée. Le texte est refusé, rien n'est écrit.
      UNREADABLE = ::Shared::Result.failure(:invalid, errors: { body: [ :image_unreadable ] })

      # Levées dans la transaction, rattrapées par save hors d'elle : rien n'est écrit.
      class SlugTaken < StandardError; end
      class ImageTaken < StandardError; end

      def find_by_public_id(public_id:)
        # Un seul article : pas de chargement anticipé, que Bullet signalerait inutile sans couverture.
        record = Orm::Article.find_by(public_id:)
        record && map_to_entity(record)
      end

      def create(dto:, author_id:, at:)
        save(Orm::Article.new(author_id:, created_at: at), dto:, at:)
      end

      def update(id:, dto:, at:)
        save(Orm::Article.find(id), dto:, at:)
      end

      # La première publication pose published_at, une remise en ligne le garde (BL-11) ; l'archivage pose archived_at.
      # Seulement depuis un état de départ admis : un geste concurrent qui l'a déjà fait laisse 0 ligne, et false.
      def transition(id:, to:, at:)
        scope = Orm::Article.where(id:, status: departures(to))
        changed =
          case to
          when "published"
            scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
          when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
          else raise ArgumentError, "transition impossible vers #{to.inspect}"
          end
        changed == 1
      end

      # Une requête, sans transaction ni verrou ; updated_at intact, donc le lastmod du plan du site aussi (ADR-0074 §4.7).
      def increment_reads(article_id:)
        Orm::Article.where(id: article_id, status: "published").update_all("reads_count = reads_count + 1") == 1
      end

      private

      # Le texte est canonisé (figures de Trix → pièces jointes) et refusé s'il cite un sgid illisible. Puis, dans une
      # transaction, il est assaini avec les seules images admises (celles de l'article et celles qui ne sont encore à
      # personne), l'article écrit, la couverture et les images citées rattachées, celles qu'il ne cite plus supprimées
      # (fichier purgé après validation).
      def save(record, dto:, at:)
        canonical = ActionText::Content.new(dto.body).to_html
        return UNREADABLE if unreadable?(canonical)

        cover = dto.cover_public_id && admissible(record).find_by(public_id: dto.cover_public_id)
        return ::Shared::Result.failure(:invalid, errors: { cover_public_id: [ :invalid ] }) if dto.cover_public_id && cover.nil?

        # requires_new : dans la transaction du use case, un échec rattrapé ici n'annule que ce point de sauvegarde.
        Orm::Article.transaction(requires_new: true) do
          previous = record.images.ids
          body = sanitized_body(canonical, record)
          record.assign_attributes(title: dto.title, excerpt: dto.excerpt, signature: dto.signature, cover_image: cover,
                                   cover_alt: dto.cover_alt, body:, updated_at: at)
          persist(record)
          cited = cited_ids(body)
          attach(record, cited, cover, dto.image_alts, at)
          Orm::ArticleImage.where(id: previous - cited - [ cover&.id ]).each(&:destroy!)
        end
        ::Shared::Result.success(map_to_entity(record))
      rescue SlugTaken, ImageTaken
        WRITE_FAILED
      end

      # ADR-0029 : deux créations simultanées peuvent lire le même slug libre ; l'index unique refuse la seconde, dont
      # le slug est recalculé une fois ; une seconde collision lève SlugTaken (:conflict, jamais un 500). Toute autre
      # violation (public_id), ou une collision sur un article déjà enregistré (slug figé), remonte telle quelle.
      # Savepoint : l'échec ne casse pas la transaction englobante. Le texte enregistré ne touche pas l'article :
      # updated_at reste l'heure du geste (at).
      def persist(record, retried: false)
        Orm::Article.transaction(requires_new: true) { Orm::Article.no_touching { record.save! } }
      rescue ActiveRecord::RecordNotUnique => error
        raise unless error.message.include?(SLUG_INDEX) && record.new_record?
        raise SlugTaken if retried

        record.slug = nil
        persist(record, retried: true)
      end

      def departures(to) = Entities::Shared::ContentStatus::TRANSITIONS.filter_map { |from, targets| from if targets.include?(to) }

      def admissible(record) = Orm::ArticleImage.where(article_id: [ nil, record.id ].uniq)

      def sanitized_body(canonical, record)
        admitted = admissible(record).where(id: cited_ids(canonical)).ids.to_set
        Repositories::Shared::RichTextSanitizer.call(canonical, image_ids: admitted)
      end

      def unreadable?(html)
        Nokogiri::HTML5.fragment(html).css(ATTACHMENT).any? do |node|
          node["sgid"].present? && SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME).nil?
        end
      end

      # Les images que cite le texte, dans son ordre, lues dans les sgid sans requête.
      def cited_ids(html)
        Nokogiri::HTML5.fragment(html).css(ATTACHMENT).filter_map do |node|
          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid.model_id.to_i if gid&.model_name == IMAGE_MODEL
        end.uniq
      end

      # Les images citées et la couverture sont prises en une requête, seulement si elles sont encore à personne ou à cet
      # article : un article concurrent qui en a pris une depuis leur lecture fait lever ImageTaken (rien n'est écrit).
      # Un texte de remplacement absent de la saisie garde sa valeur ; vidé, il s'efface.
      def attach(record, cited, cover, alts, at)
        ids = (cited + [ cover&.id ]).compact.uniq
        raise ImageTaken unless admissible(record).where(id: ids).update_all(article_id: record.id, updated_at: at) == ids.size

        Orm::ArticleImage.where(id: cited, public_id: alts.keys).find_each { it.update_columns(alt: alts[it.public_id]) }
        cover&.reload # l'entité rendue lit la couverture déjà chargée
      end

      def map_to_entity(record)
        body = record.body.body.try(:to_html).to_s
        Entities::Communication::Article.new(
          id: record.id, public_id: record.public_id, slug: record.slug, title: record.title, excerpt: record.excerpt, body:,
          signature: record.signature, status: record.status, author_id: record.author_id, cover_alt: record.cover_alt,
          cover: record.cover_image && image_entity(record.cover_image), images: cited_images(record, body),
          published_at: record.published_at, archived_at: record.archived_at, reads_count: record.reads_count,
          created_at: record.created_at, updated_at: record.updated_at
        )
      end

      def cited_images(record, body)
        cited = cited_ids(body)
        images = Orm::ArticleImage.where(article_id: record.id, id: cited).index_by(&:id)
        cited.filter_map { images[it] }.map { image_entity(it) }
      end

      def image_entity(image)
        Entities::Communication::ArticleImage.new(public_id: image.public_id, id: image.id, article_id: image.article_id,
                                                  alt: image.alt, content_type: image.content_type, byte_size: image.byte_size,
                                                  width: image.width, height: image.height)
      end
    end
  end
end
