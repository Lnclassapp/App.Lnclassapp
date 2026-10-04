# 🔌 INFRA · Orm::MessageClassroom
# Rôle : table message_classrooms, une classe ciblée par une annonce d'enseignant ; unique par annonce
# ADR  : 0078
module Orm
  class MessageClassroom < ApplicationRecord
    self.table_name = "message_classrooms"

    belongs_to :message, class_name: "Orm::Message", inverse_of: :message_classrooms
    belongs_to :classroom, class_name: "Orm::Classroom"
  end
end
