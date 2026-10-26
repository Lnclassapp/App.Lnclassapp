# 🌐 DELIVERY · Identity::ProfileMaterialsController
# Rôle : l'enseignant remplace ses matières de l'établissement courant (modale « Mes matières » ; écran de retrait « Retirer ») ; succès en Turbo Stream, repli HTML
# ADR  : 0055, 0094 (§4.2), 0103 (§4.4) · UDR : 0006, 0041, 0125 (§3.3), écrans enseignant sans répétition (§3.4)
module Identity
  class ProfileMaterialsController < AuthenticatedController
    helper_method :material_options, :profile

    # L'écran de retrait (UDR §3.4) : une ligne par matière, « Retirer » rejoue update sans elle ; la dernière n'a pas de bouton.
    def show
      render_result policy.call(actor: current_actor), success: ->(_) { }
    end

    def edit
      render_result policy.call(actor: current_actor), success: lambda { |_|
        @form = Dtos::Identity::TeacherMaterialsInput.new(material_slugs: profile.materials.map(&:slug))
      }
    end

    def update
      @form = Dtos::Identity::TeacherMaterialsInput.new(material_slugs: params.dig(:profile_materials, :material_slugs))
      result = update_teacher_materials.call(actor: current_actor, dto: @form, ip: request.remote_ip)
      render_result result, form: (removal? ? :show : :edit), success: lambda { |_|
        next redirect_to(profile_materials_path, notice: t(".removed"), status: :see_other) if removal?

        respond_to do |format|
          format.turbo_stream { @profile = profile }
          format.html { redirect_to profile_path, notice: t(".updated"), status: :see_other }
        end
      }
    end

    private

    # Le formulaire de l'écran de retrait le dit : un refus se lit sous sa liste, pas dans la modale.
    def removal? = params.dig(:profile_materials, :screen) == "removal"

    def policy = Policies::Identity::ManageOwnMaterialsPolicy.new
    def profile = (@profile ||= Queries::Identity::ProfileQuery.new.call(user_id: current_actor.user_id, current_school_id: current_actor.school_id))
    # UDR-0125 §3.3 : toutes les matières du référentiel, par nom, comme l'inscription.
    def material_options = Queries::Catalog::ReferentialOptionsQuery.new.call.materials.map { [ it.name, it.slug ] }

    def update_teacher_materials
      UseCases::Identity::UpdateTeacherMaterials.new(
        teacher_materials: Repositories::Identity::TeacherMaterialRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, clock: Time.zone
      )
    end
  end
end
