# 🧠 DOMAINE · Entities::Identity::BackupCodes
# Rôle : dix codes de secours à usage unique du second facteur
# ADR  : 0031
module Entities
  module Identity
    module BackupCodes
      COUNT = 10
      LENGTH = 10

      def self.generate = Array.new(COUNT) { SecureRandom.base58(LENGTH) }
    end
  end
end
