# 🔌 INFRA · Orm::HasFrozenSlug
# Rôle : slug dérivé du nom à la création (-2, -3… en cas de collision), jamais régénéré
# ADR  : 0029
module Orm
  module HasFrozenSlug
    extend ActiveSupport::Concern

    class_methods do
      # `from` : l'attribut source, ou un bloc évalué sur l'enregistrement.
      def has_frozen_slug(from:)
        before_validation(on: :create) { self.slug ||= frozen_slug_for(from.is_a?(Proc) ? instance_exec(&from) : public_send(from)) }
        validates :slug, presence: true
      end
    end

    def to_param = slug

    private

    # Un nom sans lettre latine (« π », « ??? ») donne un slug vide : le nom du modèle le remplace (course, course-2…).
    def frozen_slug_for(source)
      return if source.blank?

      base = source.to_s.parameterize.presence || self.class.model_name.element
      candidate = base
      suffix = 1
      candidate = "#{base}-#{suffix += 1}" while self.class.exists?(slug: candidate)
      candidate
    end
  end
end
