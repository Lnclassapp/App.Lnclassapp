# 🔌 INFRA · Orm::Message
# Rôle : table messages, les annonces ; image et audio en pièces jointes servies par l'application, jamais par Active Storage
# ADR  : 0029, 0045, 0047, 0078
module Orm
  class Message < ApplicationRecord
    include HasPublicId

    self.table_name = "messages"

    belongs_to :author, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School", optional: true
    belongs_to :withdrawn_by, class_name: "Orm::User", optional: true

    # Classes ciblées par une annonce d'enseignant ; la base les efface avec l'annonce (ON DELETE CASCADE).
    has_many :message_classrooms, class_name: "Orm::MessageClassroom", inverse_of: :message, dependent: nil

    # Fichiers servis après la règle de lecture (ADR-0078 §4.4), par Communication::MessageFilesController.
    has_one_attached :image
    has_one_attached :audio
  end
end
