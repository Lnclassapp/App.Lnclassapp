# 🧠 DOMAINE · Shared::Result
# Rôle : contrat de retour unique de tout use case
# ADR  : 0026
module Shared
  Result = Data.define(:value, :code, :errors) do
    def self.success(value = nil) = new(value:, code: nil, errors: {})

    def self.failure(code, errors: {})
      raise ArgumentError, "code d'erreur inconnu : #{code}" unless Result::ERROR_CODES.include?(code)

      new(value: nil, code:, errors:)
    end

    def success? = code.nil?
    def failure? = !success?
  end
  Result::ERROR_CODES = %i[forbidden not_found invalid conflict locked expired].freeze
end
