# 🌐 UI · Classroom::JoinQrHelper — le QR du lien de classe
# Rôle : SVG du lien /c/<jeton>?s=qr, sans autre secret que le lien de classe
# ADR  : attribution-des-inscriptions-eleves (§4.4)
module Classroom
  module JoinQrHelper
    def class_join_qr_svg(link_token)
      url = join_classroom_url(link_token, s: Entities::Classroom::SignupSource::QR_TAG)
      RQRCode::QRCode.new(url, level: :m)
                     .as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true, color: "000", fill: "fff")
                     .html_safe
    end
  end
end
