# 🌐 DELIVERY · School::SchoolSearchesController
# Rôle : recherche publique des établissements actifs pendant la frappe, 20 au plus, limitée en débit : frame « school_results »
# ADR  : 0029, 0050, 0142-recherche-etablissement · UDR : 0177-champ-etablissement
module School
  class SchoolSearchesController < ApplicationController
    # Les formulaires qui demandent un établissement : le nom de leurs champs ; toute autre valeur → le premier.
    SCOPES = %w[student_registration student_classroom_choice student_classroom_change teacher_registration school_join].freeze
    # Une classe de 40 élèves derrière une même adresse cherche environ 6 fois chacun (ADR-0142 §4.3).
    RATE_LIMIT = { to: 300, within: 1.minute, scope: "school/search" }.freeze

    allow_unauthenticated_access
    rate_limit **RATE_LIMIT, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # Le registre des textes : l'enseignant est vouvoyé, l'élève tutoyé.
    VOUS = %i[teacher_registration school_join].freeze

    def self.scope(raw) = (SCOPES.include?(raw) ? raw : SCOPES.first).to_sym
    def self.register(scope) = (VOUS.include?(scope.to_sym) ? :vous : :tu)

    def index
      render locals: { scope:, chosen: nil, result: Queries::School::SchoolSearchQuery.new.call(term: params[:q].to_s) }
    end

    private

    def scope = self.class.scope(params[:scope])

    def refuse_too_many
      render :index, status: :too_many_requests, locals: { scope:, chosen: nil, result: nil, rate_limited: true }
    end
  end
end
