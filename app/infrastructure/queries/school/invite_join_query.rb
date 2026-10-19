# 🔌 INFRA · Queries::School::InviteJoinQuery
# Rôle : ce que voit un enseignant connecté qui ouvre un lien /i/<jeton> : rejoindre, déjà dedans, plafond, ou lien plus valable
# ADR  : 0063, 0071, 0083, 0094 · UDR : 0099 (§3.4) · lecture seule ; le POST résout de nouveau le jeton (ADR-0083 §4.1)
module Queries
  module School
    class InviteJoinQuery
      # state ∈ :confirm :already :limit :invalid :sponsor (le lien de parrainage d'un collègue, sans établissement, ADR-0094
      # §11 : il sert à inscrire, pas à rejoindre) ; channel ∈ direction team colleague ; inviter : nom du collègue, sinon nil.
      # Un établissement qui l'a retiré rend :confirm, comme un autre : le refus n'arrive qu'au POST, neutre (ADR-0071).
      Row = Data.define(:state, :school_public_id, :school_name, :drena_name, :channel, :inviter)

      INVALID = Row.new(state: :invalid, school_public_id: nil, school_name: nil, drena_name: nil, channel: nil, inviter: nil)
      SPONSOR = INVALID.with(state: :sponsor)

      # token : tel que reçu dans l'adresse (chaîne). → Row
      def call(token:, teacher_id:)
        link = Repositories::Identity::InviteLinkRepository.new.resolve(token:)
        return INVALID unless link&.valid?
        return SPONSOR if link.sponsor

        # Un lien valide désigne un établissement actif (InviteLink#valid?).
        public_id, school_name, drena_name = Orm::School.joins(:drena).where(id: link.school_id)
                                                        .pick("schools.public_id", "schools.name", "drenas.name")
        Row.new(state: state(teacher_id, link.school_id), school_public_id: public_id, school_name:, drena_name:,
                channel: link.channel, inviter: inviter(link.referrer_id))
      end

      private

      def state(teacher_id, school_id)
        attached = Orm::TeacherSchool.where(teacher_id:).pluck(:school_id)
        return :already if attached.include?(school_id)

        attached.size >= Entities::School::TeacherSchools::MAX ? :limit : :confirm
      end

      def inviter(referrer_id)
        Queries::Identity::ReferralQuery.new.referrer_name(user_id: referrer_id) if referrer_id
      end
    end
  end
end
