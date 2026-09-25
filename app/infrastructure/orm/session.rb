# 🔌 INFRA · Orm::Session
# Rôle : table sessions, session serveur révocable (empreinte du jeton seulement)
# ADR  : 0031, 0050
module Orm
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user, class_name: "Orm::User", inverse_of: :sessions
  end
end
