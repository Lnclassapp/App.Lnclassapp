# 🧠 DOMAINE · Entities::Identity::ViralCoefficient
# Rôle : k-factor enseignant d'une cohorte : k = i × c (partages par enseignant × filleuls par partage) ; cible 0,75, ambition 2
# ADR  : 0063 · UDR : 0050
module Entities
  module Identity
    ViralCoefficient = Data.define(:cohort_size, :shares, :referees) do
      def invitations_per_user = cohort_size.zero? ? nil : shares.fdiv(cohort_size)
      # Un partage peut toucher tout un groupe WhatsApp : la conversion peut dépasser 1.
      def conversion_rate = shares.zero? ? nil : referees.fdiv(shares)
      # Filleuls par lien de la cohorte, par enseignant : égal à i × c dès qu'il y a des partages.
      def k = cohort_size.zero? ? nil : referees.fdiv(cohort_size)
      def on_target? = !k.nil? && k >= ViralCoefficient::TARGET
    end
    ViralCoefficient::TARGET = 0.75
    ViralCoefficient::AMBITION = 2
  end
end
