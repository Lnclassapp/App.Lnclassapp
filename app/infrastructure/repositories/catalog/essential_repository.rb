# 🔌 INFRA · Repositories::Catalog::EssentialRepository
# Rôle : traduit Orm::Essential, son contenu riche (Action Text) et ses images ↔ Entities::Catalog::Essential, avec le statut du cours
# ADR  : 0029, 0035, 0039, 0105
module Repositories
  module Catalog
    class EssentialRepository
      include Ports::Catalog::EssentialRepositoryPort

      ATTACHMENT = Repositories::Shared::RichTextSanitizer::ATTACHMENT
      IMAGE_MODEL = "Orm::EssentialImage"
      # Une pièce jointe dont le sgid ne se vérifie pas : l'assainir la retirerait, et l'image qu'elle désignait serait
      # détruite comme n'étant plus citée. Le texte est refusé, rien n'est écrit (comme un article, ADR-0074).
      UNREADABLE = ::Shared::Result.failure(:invalid, errors: { content: [ :invalid ] })
      # Un sgid valide dont l'image n'est plus admise (celle d'une autre fiche, d'un autre type, ou purgée) : l'assainir la retirerait sans
      # rien dire. Le texte est refusé, rien n'est écrit.
      IMAGE_UNAVAILABLE = ::Shared::Result.failure(:invalid, errors: { content: [ :image_unavailable ] })
      # Une image citée, prise entre-temps par une autre fiche : le geste se refait (elle ne sera plus admise).
      WRITE_FAILED = ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })

      # Plus d'images citées que le plafond (30) : refusé avant tout rattachement. Le plafond de l'envoi ne compte que les
      # images déjà rattachées à la fiche : des images orphelines (envoyées sans slug) le contourneraient (menace.md, n° 11).
      TOO_MANY_IMAGES = ::Shared::Result.failure(:invalid, errors: { content: [ :too_many_images ] })

      class ImageTaken < StandardError; end

      def find_by_slug(slug:)
        # A single record: no eager loading, which Bullet reports as unused (lot B2). Rich text and course cost one query each.
        record = Orm::Essential.find_by(slug:)
        record && map_to_entity(record)
      end

      def create(essential:)
        save(Orm::Essential.new(slug: essential.slug, course_id: essential.course_id, author_id: essential.author_id,
                                position: essential.position || next_position(course_id: essential.course_id),
                                status: essential.status || "draft"), essential)
      end

      # La ligne est verrouillée avant d'être lue : le statut que voit le use case est celui qui sera écrit (menace.md, n° 15).
      def update(essential:)
        save(Orm::Essential.lock.find(essential.id), essential)
      end

      def lock(id:)
        Orm::Essential.lock.find(id)
        true
      end

      # La première publication pose published_at ; l'archivage pose archived_at (ADR-0035).
      def transition(id:, to:, at:)
        scope = Orm::Essential.where(id:)
        case to
        when "published"
          scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
        when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
        else raise ArgumentError, "transition impossible vers #{to.inspect}"
        end
        true
      end

      def existing_keys(course_ids: nil)
        scope = course_ids.nil? ? Orm::Essential.all : Orm::Essential.where(course_id: course_ids)
        scope.pluck(:course_id, :name).to_set { |course_id, name| [ course_id, Entities::Shared::NaturalKey.normalize(name) ] }
      end

      def next_position(course_id:)
        Orm::Essential.where(course_id:).maximum(:position).to_i + 1
      end

      def draft_slugs(course_id:)
        Orm::Essential.where(course_id:, status: "draft").order(:position, :id).pluck(:slug)
      end

      def taken_slugs
        Orm::Essential.pluck(:slug).to_set
      end

      private

      # ADR-0105 : le contenu est canonisé (figures de Trix → pièces jointes) et refusé s'il cite un sgid illisible. Puis,
      # dans un point de sauvegarde, il est assaini avec les seules images admises (celles de la fiche et celles qui ne
      # sont encore à personne), la fiche écrite, les images citées rattachées avec leurs textes de remplacement, celles
      # qu'il ne cite plus supprimées (fichier purgé après validation).
      def save(record, essential)
        canonical = essential.content.nil? ? nil : ActionText::Content.new(essential.content).to_html
        return UNREADABLE if unreadable?(canonical)
        return TOO_MANY_IMAGES if cited_ids(canonical).size > Entities::Shared::ContentImage::MAX_PER_ESSENTIAL
        return IMAGE_UNAVAILABLE if foreign_attachment?(canonical) || !all_admissible?(canonical, record)

        Orm::Essential.transaction(requires_new: true) do
          previous = record.new_record? ? [] : record.images.ids
          content = sanitized_content(canonical, record)
          record.assign_attributes(name: essential.name, subtitle: essential.subtitle, content:)
          record.save!
          cited = cited_ids(content)
          attach(record, cited, essential.images)
          destroy_uncited(previous - cited)
        end
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      rescue ImageTaken
        WRITE_FAILED
      end

      def admissible(record) = Orm::EssentialImage.where(essential_id: [ nil, record.id ].uniq)

      # Une pièce jointe lisible qui n'est pas une image de fiche (celle d'un article, d'une question) : l'assainir la
      # retirerait sans rien dire. Le texte est refusé, rien n'est écrit.
      def foreign_attachment?(html)
        Nokogiri::HTML5.fragment(html.to_s).css(ATTACHMENT).any? do |node|
          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid && gid.model_name != IMAGE_MODEL
        end
      end

      def all_admissible?(canonical, record)
        cited = cited_ids(canonical)
        cited.empty? || admissible(record).where(id: cited).count == cited.size
      end

      # Les images que le texte ne cite plus partent avec leur fichier ; le journal garde lesquelles.
      def destroy_uncited(ids)
        uncited = Orm::EssentialImage.where(id: ids).to_a
        return if uncited.empty?

        uncited.each(&:destroy!)
        Rails.logger.info("[EssentialRepository] images supprimées ids=#{uncited.map(&:id)} public_ids=#{uncited.map(&:public_id)}")
      end

      def sanitized_content(canonical, record)
        cited = cited_ids(canonical)
        admitted = cited.empty? ? nil : admissible(record).where(id: cited).ids.to_set
        return Repositories::Shared::RichTextSanitizer.call(canonical) if admitted.nil?

        Repositories::Shared::RichTextSanitizer.call(canonical, image_ids: admitted, image_model: IMAGE_MODEL)
      end

      def unreadable?(html)
        Nokogiri::HTML5.fragment(html.to_s).css(ATTACHMENT).any? do |node|
          node["sgid"].present? && SignedGlobalID.parse(node["sgid"], for: ActionText::Attachable::LOCATOR_NAME).nil?
        end
      end

      # Les images de fiche que cite le texte, dans son ordre, lues dans les sgid sans requête.
      def cited_ids(html)
        Nokogiri::HTML5.fragment(html.to_s).css(ATTACHMENT).filter_map do |node|
          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid.model_id.to_i if gid&.model_name == IMAGE_MODEL
        end.uniq
      end

      # Les images citées sont prises en une requête, seulement si elles sont encore à personne ou à cette fiche. Un texte
      # de remplacement absent de la saisie garde sa valeur ; vidé, il s'efface.
      def attach(record, cited, images)
        raise ImageTaken unless admissible(record).where(id: cited).update_all(essential_id: record.id, updated_at: Time.current) == cited.size

        alts = images.to_h { [ it.public_id, it.alt ] }
        Orm::EssentialImage.where(id: cited, public_id: alts.keys).find_each { it.update_columns(alt: alts[it.public_id]) }
      end

      # Le HTML du contenu riche, assaini à l'écriture (RichTextSanitizer) puis de nouveau au rendu par Action Text.
      def map_to_entity(record)
        content = record.content.body&.to_html
        Entities::Catalog::Essential.new(
          id: record.id, slug: record.slug, course_id: record.course_id, name: record.name, subtitle: record.subtitle,
          position: record.position, author_id: record.author_id, status: record.status,
          published_at: record.published_at, archived_at: record.archived_at, content:,
          course_status: record.course.status, images: cited_images(record, content)
        )
      end

      # Sans pièce jointe citée, aucune requête : une fiche en texte seul coûte ce qu'elle coûtait.
      def cited_images(record, content)
        cited = cited_ids(content)
        return [] if cited.empty?

        images = Orm::EssentialImage.where(essential_id: record.id, id: cited).index_by(&:id)
        cited.filter_map { images[it] }.map do |image|
          Entities::Shared::ContentImage.new(public_id: image.public_id, id: image.id, owner_id: image.essential_id, alt: image.alt,
                                             content_type: image.content_type, byte_size: image.byte_size,
                                             width: image.width, height: image.height)
        end
      end
    end
  end
end
