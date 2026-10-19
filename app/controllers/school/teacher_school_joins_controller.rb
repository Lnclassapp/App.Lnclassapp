# 🌐 DELIVERY · School::TeacherSchoolJoinsController
# Rôle : lien /i/<jeton> ouvert par un enseignant connecté : « Rejoindre <établissement> ? », puis le rattachement confirmé
# ADR  : 0028, 0063, 0083, 0094 · UDR : 0079 (§3.6, amendé), 0099 (§3.4) · un clic de l'enseignant, jamais un rattachement à l'ouverture
module School
  class TeacherSchoolJoinsController < AuthenticatedController
    include JoinsSchool

    allow_roles :teacher
    # Comme le lien ouvert sans compte (ADR-0083 §4.1) : au-delà, rien n'est cherché.
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

    # Les refus du POST, dits par l'écran de l'état correspondant (UDR-0099 §3.4).
    STATES = { already_attached: :already, schools_limit: :limit }.freeze

    def new
      @invite = invite
    end

    def create
      result = join_school.call(actor: current_actor, dto: Dtos::School::SchoolInviteJoinInput.new(token: params[:token]),
                                session_id: current_session.id)
      return redirect_to(teacher_classrooms_path, notice: t("school.teacher_schools.create.joined", school: result.value.name),
                         status: :see_other) if result.success?

      @invite = invite.with(state: STATES.fetch(Array(result.errors[:base]).first, :invalid))
      render :new, status: :unprocessable_entity
    end

    private

    def invite = Queries::School::InviteJoinQuery.new.call(token: params[:token].to_s, teacher_id: current_actor.user_id)
  end
end
