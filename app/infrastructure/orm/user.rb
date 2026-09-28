# 🔌 INFRA · Orm::User
# Rôle : table users, comptes de tous les rôles ; PIN chiffré par bcrypt, jamais affiché
# ADR  : 0029, 0037, 0038, 0050, 0060
module Orm
  class User < ApplicationRecord
    include HasPublicId

    self.table_name = "users"
    self.filter_attributes += %i[pin_digest]

    has_secure_password :pin, reset_token: false

    has_one :teacher_profile, class_name: "Orm::TeacherProfile", inverse_of: :user, dependent: :restrict_with_error
    has_one :totp_credential, class_name: "Orm::TotpCredential", inverse_of: :user, dependent: :restrict_with_error
    has_many :sessions, class_name: "Orm::Session", inverse_of: :user, dependent: :restrict_with_error
    # Photo de profil (ADR-0060) : servie par Identity::AccountPhotosController, jamais par une route Active Storage.
    has_one_attached :photo
  end
end
