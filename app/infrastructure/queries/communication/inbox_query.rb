# 🔌 INFRA · Queries::Communication::InboxQuery
# Rôle : cartes d'annonces lisibles — carrousel de l'accueil élève, liste « Reçues » paginée — en un nombre fixe de requêtes
# ADR  : 0067, 0078, 0081 · UDR : 0071 (§3.2, §3.5, §3.7), 0075 (§3.1, §3.2)
module Queries
  module Communication
    class InboxQuery
      # La carte (UDR-0071 §3.2), objet de lecture partagé par le carrousel, la liste et la modération (Lot C).
      # author_role : :team, :school_admin ou :teacher ; gender, last_name, material_name (enseignant) : la signature ;
      # anonymized : l'auteur a été anonymisé (ADR-0036), la signature ne garde que sa fonction.
      # illustration : ce que rend announcement_illustration, une clé de base (String) ou l'Entities::Communication::Illustration
      # de l'équipe, retirée ou non (ADR-0081 §4.3) ; theme : une clé de Message::THEMES (UDR-0075 §3.1).
      MessageCard = Data.define(:public_id, :title, :body, :illustration, :theme, :author_role, :gender, :last_name,
                                :material_name, :anonymized, :official, :image, :audio, :edited, :dismissed) do
        # Sans thème, la carte garde l'apparence d'avant les thèmes : « Ciel », le défaut de la base.
        def initialize(theme: Entities::Communication::Message::DEFAULT_THEME, **) = super

        def anonymized? = anonymized
        def official? = official
        def image? = image
        def audio? = audio
        def edited? = edited
        def dismissed? = dismissed
      end
      # any_readable : au moins une annonce lisible, masquées comprises (la section s'affiche, au moins son lien).
      Carousel = Data.define(:cards, :any_readable) do
        def any_readable? = any_readable
      end
      Page = Data.define(:cards, :page, :pages)

      CAROUSEL_SIZE = 5
      PAGE_SIZE = 20
      # ADR-0078 §4.3 : la direction, puis les enseignants, puis l'équipe.
      AUTHOR_ORDER = Arel.sql("CASE users.role WHEN 'school_admin' THEN 0 WHEN 'teacher' THEN 1 ELSE 2 END")
      COLUMNS = [ "messages.id", "messages.public_id", "messages.title", "messages.body", "messages.illustration",
                  "messages.illustration_id", "messages.theme", "messages.edited_at", "users.role", "users.gender",
                  "users.last_name", "users.anonymized_at", "materials.name" ].freeze
      ILLUSTRATION_ID = COLUMNS.index("messages.illustration_id")

      # illustrations : Ports::Communication::IllustrationRepositoryPort, qui rend les dessins de l'équipe des cartes.
      def initialize(readable: ReadableMessages.new, illustrations: Repositories::Communication::IllustrationRepository.new)
        @readable = readable
        @illustrations = illustrations
      end

      # Cinq cartes au plus, non masquées par le lecteur ; trois requêtes (quatre avec un dessin de l'équipe), quel que soit
      # le nombre d'annonces.
      def carousel(reader:, now:)
        readable = @readable.scope(reader:, now:)
        shown = readable.where.not(id: Orm::MessageDismissal.where(user_id: reader.user_id).select(:message_id))
                        .left_joins(:author).order(AUTHOR_ORDER, published_at: :desc, id: :desc).limit(CAROUSEL_SIZE)
        Carousel.new(cards: cards(shown), any_readable: readable.exists?)
      end

      # Toutes les lisibles, la plus récente d'abord, PAGE_SIZE par page ; une page hors bornes donne la plus proche.
      def page(reader:, now:, page:)
        readable = @readable.scope(reader:, now:)
        pages = [ (readable.count / PAGE_SIZE.to_f).ceil, 1 ].max
        number = page.to_s.to_i.clamp(1, pages)
        rows = readable.order(published_at: :desc, id: :desc).offset((number - 1) * PAGE_SIZE).limit(PAGE_SIZE)
        Page.new(cards: cards(rows, dismissed_by: reader.user_id), page: number, pages:)
      end

      # Une carte lisible par le lecteur, marquée s'il l'a masquée ; nil sinon (réponse au masquage dans la liste).
      def card(reader:, now:, public_id:)
        cards(@readable.scope(reader:, now:).where(public_id:), dismissed_by: reader.user_id).first
      end

      # Les cartes d'une relation d'annonces, dans son ordre : la ligne et son auteur, puis ses fichiers, puis les dessins
      # de l'équipe de toutes les cartes, puis les rejets du lecteur (dismissed_by), soit quatre requêtes au plus. Sans
      # dessin de l'équipe, la requête des dessins ne part pas (where(id: []) ne touche pas la base) : trois, comme avant.
      def cards(messages, dismissed_by: nil)
        rows = messages.left_joins(author: { teacher_profile: :material }).pluck(*COLUMNS)
        ids = rows.map(&:first)
        files = ActiveStorage::Attachment.where(record_type: Orm::Message.name, record_id: ids).pluck(:record_id, :name).to_set
        drawings = @illustrations.find_all_by_ids(ids: rows.filter_map { it[ILLUSTRATION_ID] }.uniq)
        dismissed = dismissed_by ? Orm::MessageDismissal.where(user_id: dismissed_by, message_id: ids).pluck(:message_id).to_set : Set.new
        rows.map { |row| card_of(row, files, drawings, dismissed) }
      end

      private

      # Une annonce porte une clé de base ou un dessin de l'équipe, jamais les deux (contrainte de la base, ADR-0081 §4.3).
      def card_of(row, files, drawings, dismissed)
        id, public_id, title, body, key, illustration_id, theme, edited_at, role, gender, last_name, anonymized_at, material_name = row
        MessageCard.new(public_id:, title:, body:, illustration: key || drawings.fetch(illustration_id), theme:,
                        author_role: role.to_sym, gender:, last_name:, material_name:,
                        anonymized: !anonymized_at.nil?, official: role == "school_admin", image: files.include?([ id, "image" ]),
                        audio: files.include?([ id, "audio" ]), edited: !edited_at.nil?, dismissed: dismissed.include?(id))
      end
    end
  end
end
