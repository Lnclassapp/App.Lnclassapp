# 🔌 INFRA · Orm::Referral
# Rôle : table referrals, un parrain par filleul enseignant (lien ou garant), dans l'établissement du parrainage
# ADR  : 0063
module Orm
  class Referral < ApplicationRecord
    self.table_name = "referrals"

    belongs_to :referrer, class_name: "Orm::User"
    belongs_to :referee, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School"
  end
end
