# 🧠 DOMAINE · Policies::School::StaffPolicy
# Rôle : geste de la direction sur son établissement actif, selon sa fonction ; l'équipe a tous les gestes partout
# ADR  : 0028, 0044, 0066
module Policies
  module School
    class StaffPolicy
      # school : Entities::School::School ; gesture ∈ Entities::School::StaffPosition::ALL_GESTURES, sinon ArgumentError.
      def call(actor:, school:, gesture:)
        raise ArgumentError, "geste inconnu : #{gesture.inspect}" unless Entities::School::StaffPosition::ALL_GESTURES.include?(gesture)
        return Shared::Result.success if actor&.team?
        return Shared::Result.failure(:forbidden) unless member_of?(actor, school)
        return Shared::Result.failure(:forbidden, errors: { base: [ :position ] }) unless
          Entities::School::StaffPosition.allows?(actor.position, gesture)

        Shared::Result.success
      end

      private

      # Le rôle d'abord : pour un enseignant, school_id est son école principale, pas un rattachement de direction.
      def member_of?(actor, school)
        actor&.school_admin? && !actor.position.nil? && !school.nil? && actor.school_id == school.id && school.active?
      end
    end
  end
end
