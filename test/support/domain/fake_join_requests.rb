# In-memory JoinRequestRepositoryPort for the use cases of the cold start (ADR-0063): `approve` and `reject` decide only a
# pending request, as the conditional UPDATE of the repository does; every write is kept in `writes`.
class FakeJoinRequests
  include Ports::School::JoinRequestRepositoryPort

  attr_reader :writes

  def initialize(*requests)
    @requests = requests.index_by(&:public_id)
    @writes = []
  end

  def find_by_public_id(public_id:) = @requests[public_id]

  def approve(id:, decided_by_id:, via:, at:)
    decide(id, "approved", [ :approve, id, decided_by_id, via, at ])
  end

  def reject(id:, decided_by_id:, at:)
    decide(id, "rejected", [ :reject, id, decided_by_id, at ])
  end

  private

  def decide(id, status, write)
    request = @requests.values.find { it.id == id }
    return Shared::Result.failure(:conflict, errors: { base: [ :already_decided ] }) unless request.pending?

    @requests[request.public_id] = request.with(status:)
    @writes << write
    Shared::Result.success
  end
end
