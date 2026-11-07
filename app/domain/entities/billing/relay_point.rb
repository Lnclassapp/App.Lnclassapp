# 🧠 DOMAINE · Entities::Billing::RelayPoint
# Rôle : un point relais partenaire qui vend les cartes en espèces, rattaché à des écoles
# ADR  : cartes-activation (contexte billing, §4.1)
module Entities
  module Billing
    RelayPoint = Data.define(:id, :public_id, :name, :location, :phone, :active, :school_ids) do
      def initialize(id: nil, public_id: nil, name: nil, location: nil, phone: nil, active: true, school_ids: []) = super
    end
  end
end
