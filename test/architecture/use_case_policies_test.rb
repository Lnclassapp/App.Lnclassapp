require "test_helper"

# ADR-0028: every use case authorizes its actor. The policy is injected (`policy:`, a Policies:: object wired by
# the controller or the job), or read from the import registry, whose every kind names its Policies:: class.
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
    injected = name.constantize.instance_method(:initialize).parameters.include?([ :keyreq, :policy ])
    injected || REGISTRY.all? { source.include?(it) }
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
end
