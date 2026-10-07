# 🔌 INFRA · Queries::Communication::IllustrationLibraryQuery
# Rôle : la bibliothèque d'illustrations d'annonce lue par l'équipe : sa liste (retirées comprises) et le compte de la tuile
# ADR  : 0026, 0081 (§4.3) · UDR : 0075 (§3.5, §3.6)
module Queries
  module Communication
    class IllustrationLibraryQuery
      # illustration : Entities::Communication::Illustration, que Communication::IllustrationsHelper rend depuis ses
      # formes ; added_at : la date d'ajout (« Ajoutée le 5 oct. »).
      Row = Data.define(:illustration, :added_at)

      # Les illustrations de l'équipe, retirées comprises, par date d'ajout : l'ordre du choix des auteurs.
      def call
        Orm::MessageIllustration.order(:created_at, :id).map { |record| Row.new(illustration: entity(record), added_at: record.created_at) }
      end

      # La tuile du Référentiel : les 8 de base et les illustrations de l'équipe encore proposées.
      def count = Entities::Communication::Message::ILLUSTRATIONS.size + Orm::MessageIllustration.where(retired_at: nil).count

      private

      def entity(record)
        Entities::Communication::Illustration.new(
          id: record.id, public_id: record.public_id, name: record.name, view_box: record.view_box, shapes: record.shapes,
          created_by_id: record.created_by_id, retired_at: record.retired_at
        )
      end
    end
  end
end
