# 🌐 DELIVERY · SchoolAdmin::SchoolsController
# Rôle : « Établissement » de la direction : lien d'inscription des enseignants, bloc « Direction », bloc « Classes par niveau »
# ADR  : 0006, 0071, 0077 · UDR : 0056, 0070 · l'établissement est celui du compte, jamais un paramètre
module SchoolAdmin
  class SchoolsController < BaseController
    def show
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      @level_classrooms = Queries::School::LevelClassroomsQuery.new.call(public_id: @school.public_id)
      load_school_staff
    end

    private

    # Bloc « Direction » (UDR-0070 §3.4) : le menu ⋮ d'une ligne est la RemoveSchoolStaffPolicy évaluée sur elle, jamais une
    # règle recopiée dans la vue. La direction lit sa propre ligne parmi les actives : BaseController a refusé un compte archivé.
    def load_school_staff
      query = Queries::School::SchoolStaffQuery.new
      @staff = query.active_for(school_id: current_actor.school_id)
      @by_code_count = query.by_code_count(school_id: current_actor.school_id)
      now = Time.current
      viewer = staff_entity(@staff.find { it.user_id == current_actor.user_id })
      policy = Policies::School::RemoveSchoolStaffPolicy.new
      @removable = ->(row) { policy.call(actor: current_actor, school: @school, target: staff_entity(row), actor_staff: viewer, now:).success? }
      @newcomer = @school.active? && viewer.newcomer?(now)
    end

    def staff_entity(row)
      Entities::School::Staff.new(user_id: row.user_id, user_public_id: row.public_id, school_id: current_actor.school_id,
                                  joined_via: row.joined_via, joined_at: row.joined_at, archived_at: nil, archived_by_id: nil)
    end
  end
end
