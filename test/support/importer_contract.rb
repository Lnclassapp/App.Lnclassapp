# assert_importer_contract (plan boucle-pedagogique, 0e.e2) : ce que RunImport attend de tout adaptateur d'import.
# Avec `adapter:`, `root:` et `context:`, vérifie aussi que validate_root n'écrit rien en base.
module ImporterContract
  ActiveSupport::TestCase.include(self)

  SIGNATURES = {
    resolve_target: [ [ :keyreq, :document ] ],
    prepare: [ [ :keyreq, :target ] ],
    validate_root: [ [ :keyreq, :root ], [ :keyreq, :path ], [ :keyreq, :context ] ],
    write: [ [ :keyreq, :items ], [ :keyreq, :author_id ], [ :keyreq, :at ] ]
  }.freeze

  def assert_importer_contract(adapter_class, adapter: nil, root: nil, context: nil)
    assert_includes adapter_class.ancestors, UseCases::Catalog::Importer
    assert_includes Entities::Catalog::ImportKind::KINDS, adapter_class::KIND
    SIGNATURES.each do |name, parameters|
      method = adapter_class.instance_method(name)
      assert_not_equal UseCases::Catalog::Importer, method.owner, "#{adapter_class} doit définir ##{name}"
      assert_equal parameters, method.parameters, "#{adapter_class}##{name}"
    end
    assert_match(/Policies::\w+::\w+Policy/, File.read(adapter_class.instance_method(:validate_root).source_location.first),
                 "#{adapter_class} doit référencer sa policy")
    assert_importer_module_raises
    assert_validate_root_writes_nothing(adapter, root, context) if adapter
  end

  private

  def assert_importer_module_raises
    bare = Class.new { include UseCases::Catalog::Importer }.new
    assert_raises(NotImplementedError) { bare.resolve_target(document: {}) }
    assert_raises(NotImplementedError) { bare.prepare(target: nil) }
    assert_raises(NotImplementedError) { bare.validate_root(root: {}, path: "$", context: nil) }
    assert_raises(NotImplementedError) { bare.write(items: [], author_id: nil, at: nil) }
  end

  def assert_validate_root_writes_nothing(adapter, root, context)
    before = table_counts
    adapter.validate_root(root:, path: "racines[0]", context:)
    assert_equal before, table_counts, "validate_root ne doit rien écrire"
  end

  def table_counts
    connection = ActiveRecord::Base.connection
    connection.tables.sort.index_with { connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(it)}") }
  end
end
