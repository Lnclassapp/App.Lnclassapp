# 🌐 DELIVERY · Teams::AnswerKeysController
# Rôle : le corrigé d'une leçon pour l'équipe, page pleine en lecture seule ; tout autre acteur, comme une leçon inconnue, reçoit 404
# ADR  : 0028, 0113 (§4.6), 0115 · UDR : XXXX-fiche-de-revision-en-quatre-blocs §3.5
module Teams
  class AnswerKeysController < AuthenticatedController
    def show
      return render_not_found unless Policies::Catalog::ManageContentPolicy.new.call(actor: current_actor).success?

      @key = Queries::Catalog::LessonAnswerKeyQuery.new.call(course_slug: params[:slug])
      render_not_found if @key.nil?
    end
  end
end
