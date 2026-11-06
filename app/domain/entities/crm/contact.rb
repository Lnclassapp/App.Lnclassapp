# 🧠 DOMAINE · Entities::Crm::Contact
# Rôle : personne à appeler dans une école ; se retire par archivage, jamais par suppression
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    Contact = Data.define(:public_id, :school_id, :full_name, :position, :phone, :note, :created_by_id, :archived_at) do
      def archived? = !archived_at.nil?
    end
    Contact::POSITIONS = %w[director censor educator teacher founder other].freeze
    Contact::PHONE_FORMAT = /\A0[157][0-9]{8}\z/
    Contact::NAME_MAX = 80
    Contact::NOTE_MAX = 500
  end
end
