# 🔌 INFRA · Orm::ReferralShare
# Rôle : table referral_shares, un clic « Partager » d'un enseignant et son canal ; ni adresse IP ni agent (ADR-0049)
# ADR  : 0049, 0063
module Orm
  class ReferralShare < ApplicationRecord
    self.table_name = "referral_shares"

    belongs_to :user, class_name: "Orm::User"
  end
end
