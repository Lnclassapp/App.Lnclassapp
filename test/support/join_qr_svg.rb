# Le SVG que le helper produit pour le jeton d'une classe, avec l'hôte des tests d'intégration (lien /c/<jeton>?s=qr).
module JoinQrSvg
  def join_qr_svg_for(link_token)
    helper = ActionView::Base.empty.extend(Classroom::JoinQrHelper)
    helper.define_singleton_method(:join_classroom_url) do |token, **options|
      Rails.application.routes.url_helpers.join_classroom_url(token, host: "www.example.com", **options)
    end
    helper.class_join_qr_svg(link_token)
  end
end

ActionDispatch::IntegrationTest.include(JoinQrSvg)
