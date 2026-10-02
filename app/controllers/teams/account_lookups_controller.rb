# 🌐 DELIVERY · Teams::AccountLookupsController
# Rôle : débloquer un compte : l'équipe trouve un compte par son numéro exact ; le résultat vit dans le frame « account_lookup »
# ADR  : 0028, 0031, 0032 · UDR : 0006, 0020
module Teams
  class AccountLookupsController < BaseController
    LOOKUP_FRAME = "account_lookup".freeze

    helper_method :lookup_frame_request?

    def show
      render_result Policies::Identity::ReadUserPolicy.new.call(actor: current_actor), success: lambda { |_|
        @contact = params[:contact].to_s.strip
        @account = lookup.call(contact: @contact, viewer_id: current_actor.user_id) if @contact.present?
      }
    end

    private

    def lookup_frame_request? = turbo_frame_request_id == LOOKUP_FRAME
    def lookup = Queries::Identity::AccountLookupQuery.new
  end
end
