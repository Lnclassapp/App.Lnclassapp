# 🌐 DELIVERY · ColleagueInvitation — le bloc « Inviter un collègue » de l'enseignant connecté, s'il peut inviter
# Rôle : demande à InviteColleaguePolicy, puis lit ReferralQuery ; nil pour qui ne peut pas inviter
# ADR  : 0028, 0063 · UDR : 0050
module ColleagueInvitation
  extend ActiveSupport::Concern

  private

  def colleague_invite
    # Un enseignant sans école n'arrive pas jusqu'ici (écran d'attente, ADR-0063) : son école principale existe.
    school = Repositories::School::SchoolRepository.new.find_by_id(id: current_actor.school_id)
    return unless Policies::Identity::InviteColleaguePolicy.new.call(actor: current_actor, school:).success?

    Queries::Identity::ReferralQuery.new.call(teacher_id: current_actor.user_id)
  end
end
