# 🌐 UI · Teams::AccountLookupsHelper — gestes permis sur le compte trouvé par la recherche
# Rôle : le code de récupération et la réinitialisation du second facteur ne s'affichent que si la policy les permet
# ADR  : 0031, 0032, 0038 · UDR : 0020 · B-001 : content n'a aucun geste, field pas sur un membre de l'équipe
module Teams
  module AccountLookupsHelper
    # account : Queries::Identity::AccountLookupQuery::Row. Le compte de l'acteur (own_account) n'arrive jamais ici : la vue
    # l'écarte avant, et la policy le refuse de toute façon à l'action.
    def can_issue_pin_recovery_code?(account)
      Policies::Identity::IssuePinRecoveryCodePolicy.new.call(actor: current_actor, target: gesture_target(account)).success?
    end

    def can_reset_second_factor?(account)
      Policies::Identity::ResetSecondFactorPolicy.new.call(actor: current_actor, target: gesture_target(account)).success?
    end

    private

    def gesture_target(account)
      Entities::Identity::User.new(role: account.role.to_s, team_role: account.team_role)
    end
  end
end
