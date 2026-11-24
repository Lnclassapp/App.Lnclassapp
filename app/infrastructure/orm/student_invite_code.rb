# 🔌 INFRA · Orm::StudentInviteCode
# Rôle : table student_invite_codes, le code opaque de 8 caractères par lequel un élève invite ses camarades
# ADR  : attribution-des-inscriptions-eleves
module Orm
  class StudentInviteCode < ApplicationRecord
    self.table_name = "student_invite_codes"

    belongs_to :student, class_name: "Orm::User"
  end
end
