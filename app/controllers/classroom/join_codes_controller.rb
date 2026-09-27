# 🌐 DELIVERY · Classroom::JoinCodesController
# Rôle : « Rejoindre une classe » : le code saisi, normalisé, ouvre /c/<code> ; aucune recherche ici (le débit se limite là-bas)
# ADR  : 0041 · UDR : 0009
module Classroom
  class JoinCodesController < ApplicationController
    # Saisie du seul champ, porteuse de son erreur pour ui_field.
    Entry = Data.define(:code, :errors)

    allow_unauthenticated_access

    def new
      @entry = Entry.new(code: nil, errors: ActiveModel::Errors.new(nil))
    end

    def create
      raw = params.fetch(:join, {}).permit(:code)[:code].to_s
      code = Entities::Classroom::JoinCode.normalize(raw)
      return redirect_to(join_classroom_path(code), status: :see_other) if Entities::Classroom::JoinCode.valid?(code)

      @entry = Entry.new(code: raw, errors: ActiveModel::Errors.new(nil))
      @entry.errors.add(:code, t(".#{refusal(code)}"))
      render :new, status: :unprocessable_entity
    end

    private

    def refusal(code)
      return :blank if code.empty?

      :invalid
    end
  end
end
