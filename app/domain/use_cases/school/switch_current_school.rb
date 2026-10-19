# 🧠 DOMAINE · UseCases::School::SwitchCurrentSchool
# Rôle : l'enseignant passe sa session dans un autre de ses établissements ; un choix d'affichage, sans audit
# ADR  : 0028, 0094 · UDR : 0098
module UseCases
  module School
    class SwitchCurrentSchool
      def initialize(schools:, sessions:, policy:)
        @schools = schools
        @sessions = sessions
        @policy = policy
      end

      # session_id : la session courante, jamais un paramètre. → Result(Entities::School::School) | :forbidden | :not_found
      #   (établissement inconnu, ou session révoquée entre-temps : rien n'est écrit, rien n'est annoncé)
      def call(actor:, session_id:, school_public_id:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?

        school = @schools.find_by_public_id(public_id: school_public_id) if school_public_id
        return Shared::Result.failure(:not_found) if school.nil?

        allowed = @policy.call(actor:, attached: @schools.school_ids_for(teacher_id: actor.user_id).include?(school.id))
        return allowed if allowed.failure?

        return Shared::Result.failure(:not_found) if @sessions.set_current_school(id: session_id, school_id: school.id).zero?

        Shared::Result.success(school)
      end
    end
  end
end
