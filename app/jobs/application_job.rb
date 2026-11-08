# 🔌 INFRASTRUCTURE · ApplicationJob
# Rôle : job parent, exécuté par Solid Queue dans Puma
# ADR  : 0010, 0052
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  # Un use case dont le Result est un échec (:conflict, :forbidden…) laisserait le job « réussi » sans trace : l'id du
  # rapport et le code seuls sont journalisés, aucune donnée personnelle (B-043). → le Result, inchangé
  def log_failure(result, report_id:)
    if result.failure?
      level = result.code == :conflict ? :warn : :error
      Rails.logger.public_send(level, "[#{self.class.name}] use case failed: report_id=#{report_id} code=#{result.code}")
    end
    result
  end
end
