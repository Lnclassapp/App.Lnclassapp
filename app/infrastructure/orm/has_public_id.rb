# 🔌 INFRA · Orm::HasPublicId
# Rôle : génère le public_id opaque (14 caractères base58) à la création
# ADR  : 0029
module Orm
  module HasPublicId
    extend ActiveSupport::Concern

    included do
      before_validation(on: :create) { self.public_id ||= SecureRandom.base58(14) }
      validates :public_id, presence: true, length: { is: 14 }
    end

    def to_param = public_id
  end
end
