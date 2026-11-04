# 🧠 DOMAINE · Entities::Crm::Interaction
# Rôle : échange noté avec une école (appel, visite, démo…) ; ajout seul, aucune modification ni suppression
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    Interaction = Data.define(:public_id, :school_id, :author_id, :kind, :occurred_at, :contact_id, :contact_name, :outcome,
                              :next_step, :note, :source)
    Interaction::KINDS = %w[call whatsapp visit demo other].freeze
    Interaction::OUTCOMES = %w[positive neutral negative].freeze
    Interaction::SOURCES = %w[manual dictation].freeze
    Interaction::NEXT_STEP_MAX = 200
    Interaction::NOTE_MAX = 2000
  end
end
