# Transaction en mémoire pour les tests du domaine : `call` exécute le bloc, `attempt` traduit un refus
# simulé (FakeTransaction::Refused, levé par un faux repository) en failure(:conflict, write_failed),
# comme Repositories::Shared::Transaction pour une violation de contrainte ; OtherRefusal : un refus qui n'est pas une
# collision (contrainte, verrou), que `attempt_with_cause` distingue. Toute autre exception remonte.
class FakeTransaction
  include Ports::Shared::TransactionPort

  class Refused < StandardError; end
  class OtherRefusal < StandardError; end

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
  rescue Refused, OtherRefusal
    Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
  end

  def attempt_with_cause
    @attempts += 1
    Shared::Result.success(yield)
  rescue Refused
    Shared::Result.failure(:conflict, errors: { base: [ :write_failed ], cause: [ :collision ], exception: [ Refused.name ] })
  rescue OtherRefusal
    Shared::Result.failure(:conflict, errors: { base: [ :write_failed ], cause: [ :other ], exception: [ OtherRefusal.name ] })
  end
end
