# 🔌 INFRA · Queries::Communication::ModerationQuery
# Rôle : « Toutes » (équipe, filtre par établissement) et « Enseignants » (direction) : les annonces en cours qu'on peut retirer
# ADR  : 0026, 0078 (§4.2) · UDR : 0054 (§3.9), 0071 (§3.7)
module Queries
  module Communication
    class ModerationQuery
      PER_PAGE = 20
      # Programmées ou publiées ; « terminée » se déduit de la date de fin (ADR-0078 §4.1).
      LIVE = %w[scheduled published].freeze
      SEARCHED = %w[schools.name schools.sigle].freeze
      # card : la carte de « Reçues » (InboxQuery::MessageCard) ; school_name : nil pour une annonce nationale ;
      # at : la date de publication, faite ou programmée ; last_day : le dernier jour d'affichage (la veille de ends_at).
      Row = Data.define(:card, :school_name, :status, :at, :last_day)
      Page = Data.define(:rows, :page, :pages)

      def initialize(inbox: InboxQuery.new)
        @inbox = inbox
      end

      # actor : Entities::Identity::Actor ; q : nom ou sigle d'établissement, lu pour l'équipe seulement. Quatre
      # requêtes, quel que soit le nombre d'annonces : le compte, les cartes et leurs fichiers, puis les établissements.
      def page(actor:, q:, page:, now:)
        scope = moderated(actor, q, now)
        pages = [ scope.count.fdiv(PER_PAGE).ceil, 1 ].max
        number = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 donne un tableau
        records = scope.order(published_at: :desc, id: :desc).offset((number - 1) * PER_PAGE).limit(PER_PAGE)
        details = records.left_joins(:school)
                         .pluck("messages.public_id", "schools.name", "messages.status", "messages.published_at", "messages.ends_at")
                         .to_h { |public_id, *values| [ public_id, values ] }
        Page.new(rows: @inbox.cards(records).map { row(it, *details.fetch(it.public_id)) }, page: number, pages:)
      end

      private

      # Ce que WithdrawPolicy laisse retirer, en cours : l'équipe, toute annonce d'un autre auteur ; la direction, celles
      # des enseignants de son établissement. Un autre rôle n'a rien à retirer.
      def moderated(actor, q, now)
        live = Orm::Message.where(status: LIVE).where("messages.ends_at > ?", now).where.not(author_id: actor.user_id)
        return searched(live, q) if actor.team?
        return Orm::Message.none unless actor.school_admin?

        live.where(school_id: actor.school_id, author_id: Orm::User.where(role: "teacher").select(:id))
      end

      # Les annonces d'un établissement dont le nom ou le sigle contient q, sans casse ni accents (comme la liste des
      # établissements) ; sans q, toutes, nationales comprises.
      def searched(scope, q)
        return scope if Queries::Shared::TextSearch.normalize(q).empty?

        scope.where(school_id: Queries::Shared::TextSearch.apply(Orm::School.all, q, columns: SEARCHED).select(:id))
      end

      def row(card, school_name, status, published_at, ends_at)
        Row.new(card:, school_name:, status:, at: published_at, last_day: (ends_at - 1).to_date)
      end
    end
  end
end
