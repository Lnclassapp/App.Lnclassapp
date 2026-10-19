# 🌐 DELIVERY · JoinsSchool — le use case « rejoindre un établissement », monté une fois pour ses trois écrans
# Rôle : écran d'attente, « Mes établissements » et lien /i/<jeton> ouvert connecté appellent le même JoinSchoolWithCode
# ADR  : 0083, 0094 · UDR : 0079, 0099
module JoinsSchool
  extend ActiveSupport::Concern

  private

  def join_school
    UseCases::School::JoinSchoolWithCode.new(
      schools: Repositories::School::SchoolRepository.new, drenas: Repositories::School::DrenaRepository.new,
      departures: Repositories::School::TeacherDepartureRepository.new,
      join_requests: Repositories::School::JoinRequestRepository.new,
      invite_links: Repositories::Identity::InviteLinkRepository.new, sessions: Repositories::Identity::SessionRepository.new,
      audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::JoinSchoolWithCodePolicy.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    )
  end
end
