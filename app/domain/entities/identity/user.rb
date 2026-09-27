# 🧠 DOMAINE · Entities::Identity::User
# Rôle : un compte, nom et prénom(s) en deux champs, jamais de PIN
# ADR  : 0037, 0038, 0050
module Entities
  module Identity
    class User
      include ActiveModel::Model

      NAME_FORMAT = /\A[\p{L}\p{M}'’ \-]+\z/
      ROLES = %w[student teacher school_admin team].freeze
      TEAM_ROLES = %w[admin content field].freeze
      GENDERS = %w[male female].freeze

      attr_accessor :id, :public_id, :contact, :gender, :role, :team_role, :anonymized_at
      attr_reader :last_name, :first_name

      validates :last_name, presence: true, length: { maximum: 50 }, format: { with: NAME_FORMAT, allow_blank: true }
      validates :first_name, presence: true, length: { maximum: 80 }, format: { with: NAME_FORMAT, allow_blank: true }
      validates :gender, inclusion: { in: GENDERS }
      validates :role, inclusion: { in: ROLES }
      validates :team_role, inclusion: { in: TEAM_ROLES }, if: :team?
      validates :team_role, absence: true, unless: :team?
      validates :contact, format: { with: Contact::FORMAT }, allow_nil: true

      def last_name=(value)
        @last_name = value&.squish
      end

      def first_name=(value)
        @first_name = value&.squish
      end

      def display_name = "#{first_name} #{last_name}"
      def team? = role == "team"
      def student? = role == "student"
      def anonymized? = !anonymized_at.nil?
    end
  end
end
