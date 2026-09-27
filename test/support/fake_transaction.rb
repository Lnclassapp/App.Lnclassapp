# Transaction en mémoire pour les tests du domaine : `call` exécute le bloc, `attempt` traduit un refus
# simulé (FakeTransaction::Refused, levé par un faux repository) en failure(:conflict, write_failed),
# comme Repositories::Shared::Transaction pour une violation de contrainte. Toute autre exception remonte.
class FakeTransaction
  include Ports::Shared::TransactionPort

  class Refused < StandardError; end

  attr_reader :calls, :attempts

  def initialize
    @calls = 0
    @attempts = 0
  end

  def call
    @calls += 1
    yield
  end

  def attempt
    @attempts += 1
    Shared::Result.success(yield)
  rescue Refused
    Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
  end
end
