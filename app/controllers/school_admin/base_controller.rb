# 🌐 DELIVERY · SchoolAdmin::BaseController
# Rôle : parent de l'espace direction : réservé à une direction rattachée (403 sinon) ; ses gestes se montrent par leur policy
# ADR  : 0028, 0065, 0092 · UDR : 0052, 0092 (§3.5)
module SchoolAdmin
  class BaseController < AuthenticatedController
    # Ce que les policies de gestes lisent de l'établissement de la direction : son id et son statut.
    GestureSchool = Data.define(:id, :status)

    # L'établissement lu est toujours current_actor.school_id, jamais un paramètre (ADR-0065).
    before_action { render_result Policies::School::ReadOwnSchoolPolicy.new.call(actor: current_actor), success: ->(_) { } }

    private

    # UDR-0092 §3.5 : un geste n'est montré que si sa policy l'accorde ; jamais une règle de rang ou de statut recopiée dans
    # la vue. school : ce qui répond à status (OwnSchoolQuery::Row).
    def gesture_allowed?(policy_class, school)
      policy_class.new.call(actor: current_actor, school: GestureSchool.new(id: current_actor.school_id, status: school.status)).success?
    end

    # La note « Votre fonction (…) ne permet pas ces gestes » : sur un établissement actif dont la policy refuse le geste à
    # cette direction, c'est sa fonction qui l'en prive (rang « vie scolaire »). → String | nil
    def rank_note(school, allowed)
      return if allowed || school.status != Policies::School::ManageSchoolStructurePolicy::ACTIVE

      key = Entities::School::StaffPosition.label_key(current_actor.staff_position, school_type: school.school_type)
      t("school_admin.shared.rank_note", position: t("shared.staff_positions.#{key}"))
    end
  end
end
