# 🔌 INFRA · Orm::SignupAttribution
# Rôle : table signup_attributions, la source de l'inscription d'un élève (une ligne, écrite une fois)
# ADR  : attribution-des-inscriptions-eleves
module Orm
  class SignupAttribution < ApplicationRecord
    self.table_name = "signup_attributions"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :classroom, class_name: "Orm::Classroom"
    belongs_to :inviter, class_name: "Orm::User", optional: true
  end
end
