# 🧠 DOMAINE · Entities::Classroom::SignupSource
# Rôle : les cinq sources d'une inscription élève et leur résolution depuis la voie d'arrivée, l'étiquette du QR et l'invitant
# ADR  : attribution-des-inscriptions-eleves (§4.2, §6)
module Entities
  module Classroom
    module SignupSource
      QR = "qr"
      STUDENT_INVITE = "student_invite"
      TEACHER_LINK = "teacher_link"
      CODE = "code"
      COLD = "cold"
      ALL = [ QR, STUDENT_INVITE, TEACHER_LINK, CODE, COLD ].freeze
      QR_TAG = "qr" # valeur du paramètre s

      def self.resolve(via:, qr:, inviter_id:)
        case via
        when "link" then inviter_id ? STUDENT_INVITE : (qr ? QR : TEACHER_LINK)
        when "code" then CODE
        else COLD
        end
      end
    end
  end
end
