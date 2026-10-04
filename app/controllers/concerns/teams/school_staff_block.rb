# 🌐 DELIVERY · Teams::SchoolStaffBlock
# Rôle : charge les blocs « Direction » et « Directions retirées » d'une fiche, pour la fiche et pour ses Turbo Streams
# ADR  : 0077 · UDR : 0070 (§3.4, §3.5) · inclus par SchoolsController, SchoolStaffMembersController, SchoolStaffRestorationsController
module Teams
  # Bloc « Direction » et « Directions retirées » de la fiche (UDR-0070 §3.4, §3.5), rechargés tels quels par les Turbo Streams
  # du retrait et de la restauration (SchoolStaffMembersController, SchoolStaffRestorationsController). Le menu ⋮ d'une ligne est
  # la RemoveSchoolStaffPolicy évaluée sur elle, « Restaurer » la RestoreSchoolStaffPolicy : jamais une règle recopiée dans la vue.
  module SchoolStaffBlock
    private

    # school : Entities::School::School, pour son id et son statut.
    def load_school_staff(school)
      query = Queries::School::SchoolStaffQuery.new
      @staff = query.active_for(school_id: school.id)
      @by_code_count = query.by_code_count(school_id: school.id)
      @archived_staff = query.archived(school_id: school.id)
      @can_restore = Policies::School::RestoreSchoolStaffPolicy.new.call(actor: current_actor).success?
      policy = Policies::School::RemoveSchoolStaffPolicy.new
      now = Time.current
      @removable = lambda { |row|
        policy.call(actor: current_actor, school:, target: staff_entity(row, school), actor_staff: nil, now:).success?
      }
    end

    def staff_entity(row, school)
      Entities::School::Staff.new(user_id: row.user_id, user_public_id: row.public_id, school_id: school.id,
                                  joined_via: row.joined_via, joined_at: row.joined_at, archived_at: nil, archived_by_id: nil)
    end
  end
end
