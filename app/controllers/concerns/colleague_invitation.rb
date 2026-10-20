# 🌐 DELIVERY · ColleagueInvitation — le bloc « Inviter un collègue » de l'enseignant connecté, s'il peut inviter
# Rôle : demande à InviteColleaguePolicy, puis lit ReferralQuery (les deux liens) ; nil pour qui ne peut pas inviter
# ADR  : 0028, 0063, 0094 (§11) · UDR : 0050, 0098 (§3.6)
module ColleagueInvitation
  extend ActiveSupport::Concern

  private

  # MET-8 : le lien de l'établissement courant, et le lien de parrainage sans établissement (ADR-0094 §11).
  def colleague_invite
    school = Repositories::School::SchoolRepository.new.find_by_id(id: current_actor.school_id)
    return unless Policies::Identity::InviteColleaguePolicy.new.call(actor: current_actor, school:).success?

    Queries::Identity::ReferralQuery.new.call(teacher_id: current_actor.user_id, school_id: current_actor.school_id)
  end
end
