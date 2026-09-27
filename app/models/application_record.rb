# 🔌 INFRASTRUCTURE · ApplicationRecord
# Rôle : modèle ActiveRecord abstrait ; seuls les modèles Orm:: en héritent, jamais le domaine
# ADR  : 0001
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
