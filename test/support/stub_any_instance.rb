# Remplacent une méthode le temps d'un bloc, puis la rétablissent :
#   stub_any_instance(Repositories::School::SchoolRepository, :code_regeneration_batch, ->(**) { raise "x" }) { … }
#   stub_method(Rails.logger, :warn, ->(message) { messages << message }) { … }
module StubAnyInstance
  def stub_any_instance(klass, method, replacement)
    original = klass.instance_method(method)
    klass.define_method(method) { |*args, **options| replacement.call(*args, **options) }
    yield
  ensure
    klass.define_method(method, original)
  end

  def stub_method(object, method, replacement)
    singleton = object.singleton_class
    owned = singleton.instance_methods(false).include?(method)
    original = singleton.instance_method(method)
    singleton.define_method(method) { |*args, **options| replacement.call(*args, **options) }
    yield
  ensure
    owned ? singleton.define_method(method, original) : singleton.remove_method(method)
  end
end

ActiveSupport::TestCase.include(StubAnyInstance)
