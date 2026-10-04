# 🧠 DOMAINE · Dtos::Communication::MessageInput
# Rôle : la saisie d'une annonce : titre (60), texte (140), destinataires, illustration, image et audio lus dans leurs octets, dates
# ADR  : 0045, 0060, 0078 · UDR : 0071
module Dtos
  module Communication
    class MessageInput
      include ActiveModel::Model

      MESSAGE = Entities::Communication::Message
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
      # Les formats se lisent dans les 12 premiers octets (« RIFF....WEBP », « ....ftypM4A »).
      HEADER_BYTES = 12
      # Format d'un champ datetime-local.
      TIME_FORMAT = "%Y-%m-%dT%H:%M".freeze
      BOOLEAN = ActiveModel::Type::Boolean.new

      # published_at : chaîne datetime-local, vide = dès l'envoi ; visible_until : date ISO, dernier jour d'affichage
      # inclus ; image, audio : tout objet qui répond à size, read et rewind (fichier téléversé, StringIO), ou nil ;
      # commit : "draft" (brouillon) ou "publish".
      attr_accessor :scope, :school_public_id, :audience, :illustration, :image, :audio, :remove_image, :remove_audio,
                    :published_at, :visible_until, :commit
      attr_writer :title, :body, :classroom_public_ids

      validates :title, presence: true, length: { maximum: MESSAGE::TITLE_MAX }
      validates :body, presence: true, length: { maximum: MESSAGE::BODY_MAX }
      validates :illustration, inclusion: { in: MESSAGE::ILLUSTRATIONS }
      validate :files_are_accepted
      validate :dates_hold

      # Le formulaire d'une nouvelle annonce : la première illustration, visible 30 jours ; l'équipe venue de la fiche d'un
      # établissement le vise d'abord.
      def self.blank(today:, school_public_id: nil)
        new(illustration: MESSAGE::ILLUSTRATIONS.first, scope: ("school" if school_public_id), school_public_id:,
            visible_until: default_last_day(today).iso8601)
      end

      # Le formulaire d'une annonce existante, dans les formats des champs. Les public_id viennent de la lecture.
      def self.for(message, school_public_id:, classroom_public_ids:, today:)
        last_day = message.ends_at ? (message.ends_at - 1).to_date : default_last_day(message.published_at&.to_date || today)
        new(title: message.title, body: message.body, scope: message.school_id ? "school" : "national", school_public_id:,
            audience: message.audience, classroom_public_ids:, illustration: message.illustration,
            published_at: message.published_at&.strftime(TIME_FORMAT), visible_until: last_day.iso8601)
      end

      # Le dernier jour d'une annonce qui commence ce jour-là et dure la durée par défaut (30 jours).
      def self.default_last_day(from) = from + MESSAGE::DEFAULT_DURATION - 1.day

      def title = @title.to_s.squish
      # Un saut de ligne compte un caractère, comme maxlength le compte dans le navigateur (qui envoie \r\n).
      def body = @body.to_s.gsub("\r\n", "\n").strip
      # Le champ caché vide du groupe de cases retiré, chaque classe une fois.
      def classroom_public_ids = Array(@classroom_public_ids).map(&:to_s).compact_blank.uniq

      def remove?(kind) = BOOLEAN.cast(public_send(:"remove_#{kind}")) == true

      # Valide la saisie à l'heure `now`. live_since : la date de publication d'une annonce déjà publiée, qu'une
      # modification garde ; la date demandée et le brouillon sont alors ignorés.
      def valid_at?(now:, live_since: nil)
        @now = now
        @live_since = live_since
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

      # Le lendemain du dernier jour d'affichage à 00:00, dans le fuseau de l'application ; sans jour choisi, 30 jours
      # après la publication ; aucune pour un brouillon (ADR-0078 §4.1).
      def ends_at
        return if draft?

        last_day ? (last_day + 1).in_time_zone : publication_time + MESSAGE::DEFAULT_DURATION
      end

      # → Upload | nil, après une validation réussie ; le fichier est rendu depuis son début.
      def upload(kind)
        file = public_send(kind)
        return if file.nil?

        content_type, filename = FILES.dig(kind, :formats).fetch(format_of(kind))
        file.rewind
        Upload.new(io: file, content_type:, filename:)
      end

      private

      def scheduled? = @live_since.nil? && requested_time.is_a?(Time) && requested_time > @now
      def requested_time = @live_since ? nil : read_time(published_at)
      def last_day = read_date(visible_until)

      # Le poids est vérifié avant toute lecture : un fichier trop lourd n'est jamais lu.
      def files_are_accepted
        FILES.each do |kind, rule|
          file = public_send(kind)
          next if file.nil?
          next errors.add(kind, :too_large, count: rule[:megabytes]) if file.size > rule[:megabytes] * 1024 * 1024

          errors.add(kind, :unsupported) if format_of(kind).nil?
        end
      end

      def format_of(kind)
        (@formats ||= {}).fetch(kind) do
          file = public_send(kind)
          file.rewind
          @formats[kind] = FILES.dig(kind, :header).format_of(file.read(HEADER_BYTES).to_s.b)
        end
      end

      # Une date illisible est refusée sous son champ ; un brouillon n'est pas confronté à l'horloge, ni à la fenêtre
      # de publication (ADR-0078 §4.1 : 30 jours par défaut, 90 au plus).
      def dates_hold
        errors.add(:published_at, :invalid) if requested_time == :invalid
        errors.add(:visible_until, :invalid) if last_day == :invalid
        return if draft? || errors.include?(:published_at) || errors.include?(:visible_until)
        return errors.add(:published_at, :past) if requested_time && requested_time < @now.beginning_of_minute

        window
      end

      def window
        if ends_at <= publication_time
          errors.add(:visible_until, :before_publication)
        elsif ends_at > publication_time + MESSAGE::MAX_DURATION
          errors.add(:visible_until, :too_late)
        end
      end

      # → Time, nil (vide) ou :invalid
      def read_time(value)
        value.blank? ? nil : Time.zone.iso8601(value.to_s)
      rescue ArgumentError
        :invalid
      end

      # → Date, nil (vide) ou :invalid
      def read_date(value)
        value.blank? ? nil : Date.iso8601(value.to_s)
      rescue ArgumentError
        :invalid
      end
    end
  end
end
