# 🧠 DOMAINE · UseCases::Classroom::InviteClassmates
# Rôle : « Invite tes camarades » : le code d'invitation de l'élève (créé au premier envoi, stable ensuite) et ce qu'il faut pour écrire le message ; sans classe active, rien n'est créé
# ADR  : 0028, attribution-des-inscriptions-eleves (§4.3) · UDR : partage-de-classe-qr-affiche-invitation (§3.3)
module UseCases
  module Classroom
    class InviteClassmates
      Invitation = Data.define(:classroom_name, :school_name, :link_token, :code)

      def initialize(invite_codes:, policy:)
        @invite_codes = invite_codes
        @policy = policy
      end

      # classroom : la classe principale active de l'élève (name, school_name, link_token), nil s'il n'en a pas.
      # → Result(Invitation) | :forbidden | :not_found (sans classe active) | :unavailable
      def call(actor:, classroom:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:not_found) if classroom.nil?

        code = @invite_codes.code_for(student_id: actor.user_id)
        return code if code.failure?

        Shared::Result.success(Invitation.new(classroom_name: classroom.name, school_name: classroom.school_name,
                                              link_token: classroom.link_token, code: code.value))
      end
    end
  end
end
