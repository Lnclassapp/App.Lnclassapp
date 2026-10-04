# 🌐 UI · SchoolAdmin::LevelsHelper — illustrations des niveaux de la direction
# Rôle : une illustration et une teinte par niveau, choisies par le slug figé du niveau ; tout autre → l'illustration générique
# UDR  : 0072 (§3.6) · même forme que les matières (ComponentsHelper::Illustration, UDR-0069 §3.3)
module SchoolAdmin
  module LevelsHelper
    LEVEL_ILLUSTRATIONS = {
      "6eme" => "bg-tint-yellow", "5eme" => "bg-tint-green", "4eme" => "bg-tint-lilac", "3eme" => "bg-tint-indigo",
      "2nde" => "bg-tint-lavender", "1ere" => "bg-tint-red", "tle" => "bg-tint-pink"
    }.to_h { |slug, tint| [ slug, ComponentsHelper::Illustration.new(path: "levels/#{slug}.svg", tint:) ] }.freeze

    # slug : slug figé d'un niveau (Entities::Catalog::Level::SLUGS). → ComponentsHelper::Illustration(path, tint)
    def level_illustration(slug)
      LEVEL_ILLUSTRATIONS.fetch(slug.to_s, ComponentsHelper::SUBJECT_ILLUSTRATION_FALLBACK)
    end
  end
end
