# 🧠 DOMAINE · Dtos::Identity::DeletionRequestInput
# Rôle : la date à laquelle l'élève ou son parent a demandé au support la suppression du compte (traitée sous 30 jours)
# ADR  : 0025, 0036
module Dtos
  module Identity
    class DeletionRequestInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Une saisie qui n'est pas une date devient nil : « blank ».
      attribute :requested_on, :date

      validates :requested_on, presence: true
    end
  end
end
