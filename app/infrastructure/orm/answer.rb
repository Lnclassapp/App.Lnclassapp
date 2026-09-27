# 🔌 INFRA · Orm::Answer
# Rôle : table answers, propositions d'une question (UDR-0007)
# ADR  : 0054
module Orm
  class Answer < ApplicationRecord
    self.table_name = "answers"

    belongs_to :question, class_name: "Orm::Question", inverse_of: :answers
  end
end
