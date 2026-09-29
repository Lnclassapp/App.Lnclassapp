# 🌐 DELIVERY · Classroom::JoinCodesController
# Rôle : « Rejoindre une classe » : le code saisi, normalisé, n'ouvre /c/<code> que s'il y mène ; sinon 422 dans le champ
# ADR  : 0041 · UDR : 0009
module Classroom
  class JoinCodesController < ApplicationController
    # Saisie du seul champ, porteuse de son erreur pour ui_field.
    Entry = Data.define(:code, :errors)

    allow_unauthenticated_access
    # ADR-0041 : la vérification partage le compteur de /c/<code> ; un code se devine aussi mal ici que là-bas.
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse(:rate_limited, :too_many_requests) },
               scope: "classroom/joins", only: :create

    def new
      @entry = Entry.new(code: nil, errors: ActiveModel::Errors.new(nil))
    end

    # Un code qui ne mène à aucun aperçu (inconnu, remplacé, fermé, classe archivée) est refusé ici, sans en dire
    # plus que /c/<code> : Turbo n'affiche pas une page 404 atteinte après la redirection d'un formulaire.
    def create
      code = Entities::Classroom::JoinCode.normalize(entry_code)
      return refuse(refusal(code)) unless Entities::Classroom::JoinCode.valid?(code)
      return refuse(:unknown) unless Queries::Classroom::JoinPreviewQuery.new.call(code:)

      redirect_to join_classroom_path(code), status: :see_other
    end

    private

    def entry_code = params.fetch(:join, {}).permit(:code)[:code].to_s

    def refuse(reason, status = :unprocessable_entity)
      @entry = Entry.new(code: entry_code, errors: ActiveModel::Errors.new(nil))
      @entry.errors.add(:code, t(".#{reason}"))
      render :new, status:
    end

    def refusal(code)
      return :blank if code.empty?

      :invalid
    end
  end
end
