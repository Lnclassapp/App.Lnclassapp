# 🔌 INFRASTRUCTURE · ApplicationJob
# Rôle : job parent, exécuté par Solid Queue dans Puma
# ADR  : 0010, 0052
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
