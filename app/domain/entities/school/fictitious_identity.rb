# 🧠 DOMAINE · Entities::School::FictitiousIdentity
# Rôle : contacts déterministes dans la plage fictive 0[157]0000xxxx et noms tirés des listes du jeu de test standard
# ADR  : standard-de-test, 0050
module Entities
  module School
    class FictitiousIdentity
      # La plage fictive : préfixe 01, 05 ou 07, puis 0000, puis quatre chiffres. Compatible avec Identity::Contact::FORMAT.
      RANGE = /\A0[157]0000\d{4}\z/
      # rôle => [préfixe, premier numéro, capacité]. Les rôles qui partagent le préfixe 07 occupent des tranches disjointes.
      ROLES = {
        student: [ "01", 0, 10_000 ],
        teacher: [ "05", 0, 10_000 ],
        direction: [ "07", 0, 1_000 ],
        admin: [ "07", 1_000, 1_000 ],
        content: [ "07", 2_000, 1_000 ],
        field: [ "07", 3_000, 1_000 ]
      }.freeze
      GENDERS = %w[male female].freeze
      Name = Data.define(:first_name, :last_name, :gender)

      def self.fictitious_contact?(contact) = contact.is_a?(String) && contact.match?(RANGE)

      # names : le contenu parsé de db/seeds/standard/noms.yml.
      def initialize(names)
        @first_names = GENDERS.index_with { names.fetch("prenoms").fetch(it) }
        @last_names = names.fetch("noms")
        @schools = names.fetch("etablissements")
        raise ArgumentError, "listes de noms vides" if @first_names.values.any?(&:empty?) || @last_names.empty?
      end

      def contact(role:, index:)
        prefix, start, capacity = role_spec(role)
        raise ArgumentError, "index hors plage pour #{role} : #{index}" unless index.is_a?(Integer) && index >= 0 && index < capacity

        format("%s0000%04d", prefix, start + index)
      end

      def fictitious_contact?(contact) = self.class.fictitious_contact?(contact)

      # Un genre sur deux. Le rang k du genre parcourt toutes les paires (prénom, nom) avant d'en répéter une : le nom varie
      # à chaque pas, le prénom change tous les « nombre de noms » pas, d'un pas premier avec la taille de sa liste.
      # Le décalage par rôle évite que l'élève n et l'enseignant n portent le même nom.
      def name(role:, index:)
        role_spec(role)
        shift = ROLES.keys.index(role)
        gender = GENDERS[index % 2]
        firsts = @first_names.fetch(gender)
        rank = index / 2
        first = firsts[((rank / @last_names.size) * coprime_step(firsts.size) + shift) % firsts.size]
        Name.new(first_name: first, last_name: @last_names[(rank + shift * 3) % @last_names.size], gender:)
      end

      def school_name(key) = @schools.fetch(key)

      private

      def role_spec(role) = ROLES.fetch(role) { raise ArgumentError, "rôle inconnu : #{role.inspect}" }

      def coprime_step(size) = (7..).find { it.gcd(size) == 1 }
    end
  end
end
