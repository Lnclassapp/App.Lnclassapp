# Action Text (ADR-0073 §4.5) : le rendu réassainit le contenu riche. Sans ces trois attributs, loading="lazy",
# decoding="async" et fetchpriority des images d'un article seraient retirés de la page publique (BL-21).
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a +
                                                 ActionText::Attachment::ATTRIBUTES + %w[loading decoding fetchpriority]
end
