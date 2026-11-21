# 🌐 DELIVERY · Classroom::SchoolSignupLinksController
# Rôle : /ecole/<identifiant public> (le QR de la carte de classe) garde l'établissement actif 30 minutes en session et mène à l'entrée élève ; connecté, à son accueil
# ADR  : adresse-publique-etablissement (§4), 0141-entree-eleve-revele-un-numero-inscrit · UDR : accueil-eleve-qr-fenetre-inviter (§3.1)
module Classroom
  class SchoolSignupLinksController < ApplicationController
    include StudentEntrySession

    # M4 : une classe derrière un wifi scanne en une minute ; au-delà, 429 sans rien dire.
    RATE_LIMIT = { to: 60, within: 1.minute, scope: "classroom/school_links" }.freeze

    allow_unauthenticated_access
    rate_limit **RATE_LIMIT, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

    # M1 : inconnu, inactif ou en brouillon donnent la même redirection, rien gardé.
    def show
      return redirect_to_home if authenticated?

      school = Queries::School::SchoolSearchQuery.new.find(public_id: params[:school_public_id].to_s)
      keep_entry_school(school.public_id) if school
      redirect_to new_student_entry_path
    end
  end
end
