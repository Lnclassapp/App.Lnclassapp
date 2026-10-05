# 🧠 DOMAINE · Dtos::Communication::MessageInput
# Rôle : la saisie d'une annonce : titre (60), texte (140), destinataires, thème, illustration, image et audio lus dans leurs octets, parution
# ADR  : 0045, 0060, 0078, 0081 · UDR : 0071, 0075
module Dtos
  module Communication
    class MessageInput
      include ActiveModel::Model

      MESSAGE = Entities::Communication::Message
      IMAGE_HEADER = Entities::Shared::ImageHeader
      # Une année de plus de 4 chiffres dépasse ce que la base garde : la date est illisible.
      LAST_YEAR = 9999
      # La forme d'un public_id (14 caractères alphanumériques) : la valeur d'une illustration de l'équipe (ADR-0081 §4.3).
      LIBRARY_ID = /\A[0-9A-Za-z]{14}\z/
      # Une pièce jointe vérifiée, telle que Ports::Communication::AttachmentStorePort#attach la reçoit.
      Upload = Data.define(:io, :content_type, :filename)
      # Par fichier : poids maximal, lecteur du format dans les premiers octets, puis type et nom par format (ADR-0045 §4).
      # Le nom envoyé n'est jamais gardé : il est choisi ici, d'après le contenu.
      FILES = {
        image: { megabytes: 2, header: Entities::Shared::ImageHeader,
                 formats: { png: %w[image/png image.png], jpeg: %w[image/jpeg image.jpg], webp: %w[image/webp image.webp] } },
        audio: { megabytes: 10, header: Entities::Communication::AudioHeader,
                 formats: { mpeg: %w[audio/mpeg audio.mp3], mp4: %w[audio/mp4 audio.m4a] } }
      }.freeze
      # Les formats se lisent dans les 4096 premiers octets : un MP3 de téléphone peut commencer par du remplissage
      # (ADR-0081 §4.4) ; une image, dans ses 12 premiers (« RIFF....WEBP »).
      HEADER_BYTES = 4096
      # Format d'un champ datetime-local.
      TIME_FORMAT = "%Y-%m-%dT%H:%M".freeze
      BOOLEAN = ActiveModel::Type::Boolean.new

      # published_at : chaîne datetime-local, vide = dès l'envoi ; aucune date de fin, elle est calculée (ADR-0081 §4.1) ;
      # illustration : une clé de base, ou le public_id d'un dessin de l'équipe ; image, audio : tout objet qui répond à
      # size, read et rewind (fichier téléversé, StringIO), ou nil ; commit : "draft" (brouillon) ou "publish".
      attr_accessor :scope, :school_public_id, :audience, :illustration, :image, :audio, :remove_image, :remove_audio,
                    :published_at, :commit
      attr_writer :title, :body, :classroom_public_ids, :theme

      validates :title, presence: true, length: { maximum: MESSAGE::TITLE_MAX }
      validates :body, presence: true, length: { maximum: MESSAGE::BODY_MAX }
      validates :theme, inclusion: { in: MESSAGE::THEMES }
      validate :illustration_is_offered
      validate :files_are_accepted
      validate :image_is_clean
      validate :dates_hold

      # Le formulaire d'une nouvelle annonce : la première illustration, « Ciel » ; l'équipe venue de la fiche d'un
      # établissement le vise d'abord.
      def self.blank(school_public_id: nil)
        new(illustration: MESSAGE::ILLUSTRATIONS.first, theme: MESSAGE::DEFAULT_THEME, scope: ("school" if school_public_id),
            school_public_id:)
      end

      # Le formulaire d'une annonce existante, dans les formats des champs. Les public_id viennent de la lecture ; celui
      # d'un dessin de l'équipe devient la valeur de l'illustration.
      def self.for(message, school_public_id:, classroom_public_ids:, illustration_public_id:)
        new(title: message.title, body: message.body, scope: message.school_id ? "school" : "national", school_public_id:,
            audience: message.audience, classroom_public_ids:, theme: message.theme,
            illustration: illustration_public_id || message.illustration, published_at: message.published_at&.strftime(TIME_FORMAT))
      end

      def title = @title.to_s.squish
      # Un saut de ligne compte un caractère, comme maxlength le compte dans le navigateur (qui envoie \r\n).
      def body = @body.to_s.gsub("\r\n", "\n").strip
      # Le champ caché vide du groupe de cases retiré, chaque classe une fois.
      def classroom_public_ids = Array(@classroom_public_ids).map(&:to_s).compact_blank.uniq

      # Sans thème envoyé, « Ciel » (UDR-0075 §3.3) ; un thème envoyé hors de la liste est refusé.
      def theme = @theme || MESSAGE::DEFAULT_THEME

      # La clé d'une illustration de base, ou nil : la valeur désigne alors un dessin de l'équipe.
      def base_illustration = (illustration if MESSAGE::ILLUSTRATIONS.include?(illustration))

      # Vrai si la valeur a la forme du public_id d'un dessin de l'équipe ; le use case vérifie qu'il est offert (AV-10).
      def library_illustration? = base_illustration.nil? && LIBRARY_ID.match?(illustration.to_s)

      def remove?(kind) = BOOLEAN.cast(public_send(:"remove_#{kind}")) == true

      # Valide la saisie à l'heure `now`. live_since, live_until : les dates de publication et de fin d'une annonce déjà
      # publiée, qu'une modification garde (ADR-0081 §4.1) ; la date demandée et le brouillon sont alors ignorés.
      def valid_at?(now:, live_since: nil, live_until: nil)
        @now = now
        @live_since = live_since
        @live_until = live_until
        valid?
      end

      # Ce qui suit se lit après valid_at?.
      def draft? = @live_since.nil? && commit == "draft"

      # → "draft" | "scheduled" | "published"
      def status
        return "draft" if draft?

        scheduled? ? "scheduled" : "published"
      end

      # La date de publication à écrire : celle de l'annonce déjà publiée, la date demandée (brouillon, programmée), ou
      # maintenant.
      def publication_time
        return @live_since if @live_since
        return requested_time if draft?

        scheduled? ? requested_time : @now
      end

      # ADR-0081 §4.1 : la parution + 30 jours, sans rien à choisir ; une annonce déjà publiée garde sa fin ; un brouillon
      # n'en a pas.
      def ends_at
        return @live_until if @live_since
        return if draft?

        publication_time + MESSAGE::DURATION
      end

      # → Upload | nil, après une validation réussie ; l'audio est rendu depuis son début, l'image sans ses métadonnées.
      def upload(kind)
        file = public_send(kind)
        return if file.nil?

        content_type, filename = FILES.dig(kind, :formats).fetch(format_of(kind))
        file.rewind
        Upload.new(io: kind == :image ? StringIO.new(image_data) : file, content_type:, filename:)
      end

      private

      def scheduled? = @live_since.nil? && requested_time.is_a?(Time) && requested_time > @now
      def requested_time = @live_since ? nil : read_time(published_at)

      # Une clé de base, ou une valeur qui peut désigner un dessin de l'équipe ; rien d'autre (ADR-0081 §4.3).
      def illustration_is_offered
        errors.add(:illustration, :inclusion) unless base_illustration || library_illustration?
      end

      # Le poids est vérifié avant toute lecture : un fichier trop lourd n'est jamais lu.
      def files_are_accepted
        FILES.each do |kind, rule|
          file = public_send(kind)
          next if file.nil?
          next errors.add(kind, :too_large, count: rule[:megabytes]) if file.size > rule[:megabytes] * 1024 * 1024

          errors.add(kind, :unsupported) if format_of(kind).nil?
        end
      end

      # ADR-0060, comme l'image d'un article : l'image est lue en entier (2 Mo au plus, déjà vérifiés), gardée sans Exif, GPS
      # ni XMP, et relue sans métadonnées ; ses côtés sont bornés, l'accueil élève la décode sur un téléphone modeste.
      def image_is_clean
        return if image.nil? || errors.include?(:image)

        facts = IMAGE_HEADER.read(image_bytes)
        clean = IMAGE_HEADER.read(image_data)
        return errors.add(:image, :unsupported) unless facts && clean && clean.metadata == false

        errors.add(:image, :too_wide, count: MESSAGE::IMAGE_MAX_SIDE) if [ facts.width, facts.height ].max > MESSAGE::IMAGE_MAX_SIDE
      end

      def image_bytes
        @image_bytes ||= begin
          image.rewind
          image.read.b
        end
      end

      def image_data = @image_data ||= IMAGE_HEADER.strip(image_bytes)

      def format_of(kind)
        (@formats ||= {}).fetch(kind) do
          file = public_send(kind)
          file.rewind
          @formats[kind] = FILES.dig(kind, :header).format_of(file.read(HEADER_BYTES).to_s.b)
        end
      end

      # Une date illisible est refusée sous son champ ; un brouillon n'est pas confronté à l'horloge. La fin n'est plus
      # choisie : aucune fenêtre à vérifier (ADR-0081 §4.1).
      def dates_hold
        return errors.add(:published_at, :invalid) if requested_time == :invalid

        errors.add(:published_at, :past) if !draft? && requested_time && requested_time < @now.beginning_of_minute
      end

      # → Time, nil (vide) ou :invalid
      def read_time(value)
        value.blank? ? nil : within_years(Time.zone.iso8601(value.to_s))
      rescue ArgumentError
        :invalid
      end

      def within_years(value) = value.year > LAST_YEAR ? :invalid : value
    end
  end
end
