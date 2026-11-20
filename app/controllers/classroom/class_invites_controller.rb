# 🌐 DELIVERY · Classroom::ClassInvitesController
# Rôle : « Invite tes camarades » : le code de l'élève, puis 303 vers WhatsApp avec le lien de sa classe ; sans classe active, retour à l'accueil, sans code créé
# ADR  : 0026, attribution-des-inscriptions-eleves (§4.3) · UDR : partage-de-classe-qr-affiche-invitation (§3.3)
module Classroom
  class ClassInvitesController < AuthenticatedController
    allow_roles :student

    def create
      result = invite.call(actor: current_actor, classroom: Queries::Classroom::StudentHomeQuery.new.active_classroom(student_id: current_actor.user_id))
      return redirect_to(student_home_path, status: :see_other) if result.code == :not_found

      render_result result, success: ->(invitation) { redirect_to helpers.whatsapp_share_url(message(invitation)), allow_other_host: true, status: :see_other }
    end

    private

    # Aucun nom d'élève dans le message : le code est opaque.
    def message(invitation)
      t("classroom.class_invites.message", classroom: invitation.classroom_name, school: invitation.school_name,
                                           link: join_classroom_url(invitation.link_token, i: invitation.code))
    end

    def invite
      UseCases::Classroom::InviteClassmates.new(invite_codes: Repositories::Classroom::InviteCodeRepository.new,
                                                policy: Policies::Classroom::InviteClassmatesPolicy.new)
    end
  end
end
