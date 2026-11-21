# 🌐 UI · Classroom::JoinQrHelper — les QR : lien de classe, adresse d'établissement
# Rôle : SVG du lien /c/<jeton>?s=qr (sans autre secret que le lien de classe) ; SVG de /ecole/<identifiant public> de l'établissement
# ADR  : attribution-des-inscriptions-eleves (§4.4), adresse-publique-etablissement (§4)
module Classroom
  module JoinQrHelper
    def class_join_qr_svg(link_token)
      url = join_classroom_url(link_token, s: Entities::Classroom::SignupSource::QR_TAG)
      RQRCode::QRCode.new(url, level: :m)
                     .as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true, color: "000", fill: "fff")
                     .html_safe
    end

    # L'adresse de l'établissement ne porte ni élève, ni classe, ni jeton (M2) ; elle ne change pas tant que l'identifiant vit.
    def school_signup_qr_svg(school_public_id)
      Rails.cache.fetch([ "school-signup-qr", school_public_id ]) do
        RQRCode::QRCode.new(school_signup_link_url(school_public_id), level: :m)
                       .as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true, color: "000", fill: "fff")
      end.html_safe
    end
  end
end
