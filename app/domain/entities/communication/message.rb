# 🧠 DOMAINE · Entities::Communication::Message
# Rôle : une annonce (carte courte et signée) de l'équipe, d'une direction ou d'un enseignant ; listes fermées et bornes
# ADR  : 0045, 0078, 0081 · UDR : 0071, 0075
module Entities
  module Communication
    # Contrat gelé au Lot 0 (ADR-0078 §6). « Terminée » n'est pas un statut : une annonce publiée dont ends_at est passée
    # l'est, la lecture la filtre. Les longueurs sont validées par le DTO ; la base les borne aussi (ADR-0078 §4.1).
    # ADR-0081 §4.2 et §4.3 (Lot 0 d'annonces-v2) : un thème, et soit une clé de base (illustration), soit une
    # illustration de l'équipe (illustration_id, la clé est alors nil) ; la base impose exactement l'une des deux.
    Message = Data.define(:id, :public_id, :author_id, :title, :body, :audience, :school_id, :classroom_ids,
                          :illustration, :status, :published_at, :ends_at, :edited_at, :withdrawn_at, :withdrawn_by_id,
                          :theme, :illustration_id) do
      # Une annonce à créer n'a ni id ni public_id ; une annonce par rôle n'a aucune classe ; sans thème, « Ciel ».
      def initialize(author_id:, title:, body:, audience:, illustration:, status:, id: nil, public_id: nil, school_id: nil,
                     classroom_ids: [], published_at: nil, ends_at: nil, edited_at: nil, withdrawn_at: nil,
                     withdrawn_by_id: nil, theme: Message::DEFAULT_THEME, illustration_id: nil)
        super
      end

      # Archivée ou retirée : ni modification, ni republication (ADR-0078 §4.2).
      def frozen? = %w[archived withdrawn].include?(status)
      def by_classrooms? = audience == "classrooms"

      # Officielle = écrite par une direction ; rien ne le stocke (ADR-0078 §4.2).
      def official?(author_role:) = author_role == :school_admin

      # Qui peut la retirer : l'équipe, toute annonce d'un autre auteur ; la direction, celles des enseignants de son
      # établissement. Le statut (déjà figée) est l'affaire de la policy.
      def moderatable_by?(actor, author_role:)
        case actor.role
        when :team then author_id != actor.user_id
        when :school_admin then author_role == :teacher && school_id == actor.school_id
        else false
        end
      end
    end
    Message::AUDIENCES = %w[all students teachers school_admins classrooms].freeze
    Message::STATUSES = %w[draft scheduled published archived withdrawn].freeze
    Message::ILLUSTRATIONS = %w[info calendar homework sheets exam meeting celebration holidays].freeze # UDR-0071 §3.3
    Message::TITLE_MAX = 60
    Message::BODY_MAX = 140
    # Le plus grand côté d'une image jointe, en pixels : une photo de téléphone (4032 px) passe (ADR-0060).
    Message::IMAGE_MAX_SIDE = 4096
    # ADR-0081 §4.2, UDR-0075 §3.1 : la liste fermée des thèmes, dans cet ordre ; libellés communication.themes.<clé>.
    Message::THEMES = %w[ciel lagune menthe citron mangue corail hibiscus lavande indigo nuit].freeze
    Message::DEFAULT_THEME = "ciel"
    # ADR-0081 §4.1 : une annonce reste en ligne 30 jours après sa parution ; un auteur en a 3 en ligne au plus.
    Message::DURATION = 30.days
    Message::LIVE_CAP = 3
  end
end
