# 🌐 DELIVERY · SchoolAdmin::BaseController
# Rôle : parent de l'espace direction : lecture seule, réservée à une direction rattachée ; 403 pour tout autre rôle
# ADR  : 0028, 0065 · UDR : 0052
module SchoolAdmin
  class BaseController < AuthenticatedController
    # L'établissement lu est toujours current_actor.school_id, jamais un paramètre (ADR-0065).
    before_action { render_result Policies::School::ReadOwnSchoolPolicy.new.call(actor: current_actor), success: ->(_) { } }
  end
end
