# Passage d'envoi en mémoire pour les tests du domaine (ADR-0147, amendement du 2026-11-27 II) : compte les demandes.
class FakePushPass
  include Ports::Communication::PushPassPort

  attr_reader :requests

  def initialize = @requests = 0

  def request
    @requests += 1
    nil
  end
end
