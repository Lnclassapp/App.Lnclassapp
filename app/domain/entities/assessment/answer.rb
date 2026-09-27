# 🧠 DOMAINE · Entities::Assessment::Answer
# Rôle : une proposition de réponse ; correct vaut nil dans une copie sans correction
# ADR  : 0054
module Entities
  module Assessment
    Answer = Data.define(:id, :position, :content, :correct)
  end
end
