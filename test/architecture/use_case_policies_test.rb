require "test_helper"

# ADR-0028: every use case authorizes its actor. The policy is injected (`policy:`, a Policies:: object wired by
# the controller or the job), or read from the import registry, whose every kind names its Policies:: class.
# An import adapter has no actor: RunImport authorizes it through the registry entry of its KIND, whose policy
# the adapter must reference as POLICY.
class UseCasePoliciesTest < ActiveSupport::TestCase
  USE_CASES_ROOT = Rails.root.join("app/domain/use_cases")
  # The only exemptions (ADR-0028): no actor exists yet when they run.
  EXEMPT = {
    "UseCases::Identity::Authenticate" => "connexion : l'acteur n'existe pas encore",
    "UseCases::Identity::ResetPinWithCode" => "PIN oublié : la personne n'est pas connectée",
    "UseCases::Identity::AcceptInvitation" => "invitation : le compte n'existe pas encore"
  }.freeze
  # The adapter contract of the import engine is a module, not a use case.
  CONTRACTS = %w[UseCases::Catalog::Importer].freeze
  REGISTRY = [ "Entities::Catalog::ImportKind.fetch(", ".authorize(actor:" ].freeze

  def use_cases
    USE_CASES_ROOT.glob("**/*.rb").to_h do |path|
      [ "UseCases::#{path.relative_path_from(USE_CASES_ROOT).sub_ext('').to_s.camelize}", path.read ]
    end.except(*CONTRACTS)
  end

  def authorized?(name, source)
    klass = name.constantize
    injected = klass.instance_method(:initialize).parameters.include?([ :keyreq, :policy ])
    injected || registered_importer?(klass) || REGISTRY.all? { source.include?(it) }
  end

  def registered_importer?(klass)
    return false unless klass.include?(UseCases::Catalog::Importer) && klass.const_defined?(:KIND, false)
    return false unless Entities::Catalog::ImportKind.valid?(klass::KIND)

    klass.const_defined?(:POLICY, false) && klass::POLICY == Entities::Catalog::ImportKind.fetch(klass::KIND).policy
  end

  test "every use case outside the named exemptions authorizes its actor" do
    offenders = use_cases.except(*EXEMPT.keys).reject { |name, source| authorized?(name, source) }.keys

    assert_empty offenders, "ni `policy:` injectée ni ImportKind#authorize (ADR-0028)"
  end

  test "every kind of the import registry names a Policies:: class" do
    Entities::Catalog::ImportKind::ALL.each_value do |definition|
      assert_match(/\APolicies::\w+::\w+Policy\z/, definition.policy.name, definition.kind)
    end
  end

  test "a use case without policy is caught" do
    stray = Class.new { def initialize(users:) = @users = users }
    Object.const_set(:StrayUseCase, stray)

    assert_not authorized?("StrayUseCase", "class StrayUseCase; end")
    assert authorized?("StrayUseCase", "kind = Entities::Catalog::ImportKind.fetch(dto.kind)\nkind.authorize(actor:)")
  ensure
    Object.send(:remove_const, :StrayUseCase)
  end

  test "an import adapter is authorized by its registry entry, with the same policy" do
    adapter = ->(kind, policy) { Class.new { include UseCases::Catalog::Importer }.tap { it.const_set(:KIND, kind); it.const_set(:POLICY, policy) } }

    assert registered_importer?(adapter.call("schools", Policies::School::ManageSchoolPolicy))
    assert_not registered_importer?(adapter.call("schools", Policies::Catalog::ManageContentPolicy))
    assert_not registered_importer?(adapter.call("inconnu", Policies::School::ManageSchoolPolicy))
    assert_not registered_importer?(Class.new { include UseCases::Catalog::Importer })
    assert_not registered_importer?(Class.new.tap { it.const_set(:KIND, "schools") })
  end
end
