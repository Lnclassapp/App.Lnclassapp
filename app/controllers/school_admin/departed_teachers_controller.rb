# 🌐 DELIVERY · SchoolAdmin::DepartedTeachersController
# Rôle : « Enseignants retirés » de la direction, page sœur de « Enseignants » ; l'établissement est celui du compte
# ADR  : 0006, 0071, 0092 · UDR : 0056, 0092 (§3.5) · « Réintégrer » par la policy des enseignants
module SchoolAdmin
  class DepartedTeachersController < BaseController
    def index
      @overview = Queries::School::DepartedTeachersQuery.new.call(school_id: current_actor.school_id)
      school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      @manageable = gesture_allowed?(Policies::School::ManageSchoolTeachersPolicy, school)
      @rank_note = rank_note(school, @manageable, hideable: @overview.teachers.any?)
    end
  end
end
