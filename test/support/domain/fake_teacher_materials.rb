# In-memory TeacherMaterialRepositoryPort (ADR-0103): lists by [teacher_id, school_id], and the calls in order.
class FakeTeacherMaterials
  include Ports::Identity::TeacherMaterialRepositoryPort

  attr_reader :calls, :lists

  def initialize(lists = {})
    @lists = lists
    @calls = []
  end

  def material_ids_for(teacher_id:, school_id:) = @lists.fetch([ teacher_id, school_id ], [])

  def replace(teacher_id:, school_id:, material_ids:, at:)
    @calls << [ :replace, teacher_id, school_id, material_ids, at ]
    @lists[[ teacher_id, school_id ]] = material_ids
    true
  end

  def inherit(teacher_id:, school_id:, from_school_id:, at:)
    @calls << [ :inherit, teacher_id, school_id, from_school_id, at ]
    true
  end
end
