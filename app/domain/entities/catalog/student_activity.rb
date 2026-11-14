# 🧠 DOMAINE · Entities::Catalog::StudentActivity
# Rôle : les traces d'élèves rattachées à une leçon, par source ; une seule suffit à refuser sa suppression
# ADR  : 0036, XXXX-suppression-d-une-lecon-sans-activite-eleve
module Entities
  module Catalog
    # Un compte par source : séances d'exercice, réponses, badges, lectures de notion, lacunes, packs hors ligne livrés, devoirs envoyés
    # (actifs ou archivés). « Je m'entraîne » n'écrit rien : il n'a pas de source.
    StudentActivity = Data.define(:sessions, :attempts, :badges, :reads, :gaps, :offline_packs, :assignments) do
      def self.none = new(**members.to_h { [ it, 0 ] })

      def any? = to_h.values.any?(&:positive?)
    end
  end
end
