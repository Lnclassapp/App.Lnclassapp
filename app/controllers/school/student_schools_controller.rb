# 🌐 DELIVERY · School::StudentSchoolsController
# Rôle : « Mon établissement » de l'élève (ordinateur) : nom, sigle, DRENA, type de l'établissement de sa classe, en lecture seule
# ADR  : 0006, 0028 · UDR : écrans élève sans répétition §3.6 bis · élève seulement ; l'établissement vient du compte de la session, aucun paramètre n'est lu
module School
  class StudentSchoolsController < AuthenticatedController
    allow_roles :student

    def show
      @school = Queries::School::StudentSchoolQuery.new.call(student_id: current_actor.user_id)
      redirect_to student_home_path if @school.nil?
    end
  end
end
