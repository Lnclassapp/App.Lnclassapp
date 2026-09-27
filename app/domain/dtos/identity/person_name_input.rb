# 🧠 DOMAINE · Dtos::Identity::PersonNameInput
# Rôle : valide et normalise nom et prénom(s), sans toucher à la casse ; les DTO d'inscription en héritent
# ADR  : 0037
module Dtos
  module Identity
    class PersonNameInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      NAME_FORMAT = Entities::Identity::User::NAME_FORMAT

      attribute :last_name, :string
      attribute :first_name, :string

      validates :last_name, presence: true, length: { maximum: 50 }, format: { with: NAME_FORMAT, allow_blank: true }
      validates :first_name, presence: true, length: { maximum: 80 }, format: { with: NAME_FORMAT, allow_blank: true }

      def last_name
        super&.squish
      end

      def first_name
        super&.squish
      end
    end
  end
end
