# 🌐 DELIVERY · SchoolSearchField — le champ « Ton établissement » d'un formulaire hôte : saisie relue, résultats, établissement choisi
# Rôle : rend au partial school/school_searches/_field ses locals ; déduit la DRENA de l'établissement choisi avant le DTO (les use cases la gardent)
# ADR  : 0142-recherche-etablissement (§4.4, §4.5) · UDR : 0177-champ-etablissement
module SchoolSearchField
  extend ActiveSupport::Concern

  included { helper_method :school_search_locals, :school_error }

  private

  # Les locals du partial pour l'établissement choisi (school_public_id) et la saisie relue en GET (repli sans JavaScript).
  # Une recherche qui ne contient plus l'établissement choisi le retire : sa liste ne l'envoie plus. → Hash
  def school_search_locals(school_public_id)
    @school_search_locals ||= begin
      term = params[:school_q].is_a?(String) ? params[:school_q].strip.presence : nil
      result = school_search.call(term:) if term
      chosen = school_search.find(public_id: school_public_id)
      chosen = nil if result && chosen && result.rows.none? { it.public_id == chosen.public_id }
      { chosen:, result:, term: }
    end
  end

  # La DRENA de l'établissement envoyé, s'il est actif ; sinon aucune (jamais celle du client) : le DTO la dit manquante, et
  # school_error porte ce refus sur le champ établissement, sous le message neutre de la DRENA (locales des DTO).
  def with_school_drena(attributes)
    school = school_search.find(public_id: attributes[:school_public_id])
    attributes.merge(drena_public_id: school&.drena_public_id)
  end

  # L'erreur affichée sous le champ : celle de l'établissement, sinon celle de la DRENA déduite (établissement introuvable).
  def school_error(errors) = errors[:school_public_id].first || errors[:drena_public_id].first

  def school_search = @school_search ||= Queries::School::SchoolSearchQuery.new
end
