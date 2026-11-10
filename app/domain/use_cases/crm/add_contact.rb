# 🧠 DOMAINE · UseCases::Crm::AddContact
# Rôle : ajoute un contact (nom, fonction, numéro facultatif à 10 chiffres, note) à une école, pour un membre admin ou field
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class AddContact
      def initialize(contacts:, policy:)
        @contacts = contacts
        @policy = policy
      end

      # → Result(Contact) | :forbidden | :invalid (errors: full_name, position, phone, note)
      def call(actor:, school_id:, full_name:, position:, phone:, note:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        name = full_name.to_s.squish
        note = note.to_s.strip.presence
        number = phone.to_s.strip.presence && Entities::Identity::Contact.normalize(phone)
        errors = validate(name:, position:, note:, phone_given: !phone.to_s.strip.empty?, number:)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        @contacts.create(contact: Entities::Crm::Contact.new(
          public_id: nil, school_id:, full_name: name, position:, phone: number, note:, created_by_id: actor.user_id, archived_at: nil
        ))
      end

      private

      def validate(name:, position:, note:, phone_given:, number:)
        errors = {}
        errors[:full_name] = [ name.empty? ? :blank : :too_long ] if name.empty? || name.length > Entities::Crm::Contact::NAME_MAX
        errors[:position] = [ :inclusion ] unless Entities::Crm::Contact::POSITIONS.include?(position)
        errors[:phone] = [ :invalid ] if phone_given && number.nil?
        errors[:note] = [ :too_long ] if note && note.length > Entities::Crm::Contact::NOTE_MAX
        errors
      end
    end
  end
end
