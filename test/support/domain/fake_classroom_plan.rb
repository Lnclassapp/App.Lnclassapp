# Barème en mémoire (ADR-0058), comme Repositories::Classroom::ClassroomPlanRepository : une entrée par type, niveau et
# série ; save remplace les entrées de mêmes clés. reads compte les lectures du barème.
class FakeClassroomPlan
  include Ports::Classroom::ClassroomPlanRepositoryPort

  attr_reader :saves, :reads

  def initialize(plan = Entities::Classroom::ClassroomPlan.new(entries: []))
    @entries = plan.entries.to_h { [ key(it), it ] }
    @saves = []
    @reads = 0
  end

  def plan
    @reads += 1
    Entities::Classroom::ClassroomPlan.new(entries: @entries.values)
  end

  def save(entries:, at:)
    @saves << entries
    entries.each { @entries[key(it)] = it }
    true
  end

  private

  def key(entry) = [ entry.school_type, entry.level_id, entry.series_id ]
end
