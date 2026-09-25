require "test_helper"

# ADR-0026: every port of app/domain/ports has exactly one adapter in app/infrastructure, which defines each
# method of the port itself, with the frozen parameters.
class PortContractsTest < ActiveSupport::TestCase
  PORTS_ROOT = Rails.root.join("app/domain/ports")
  INFRASTRUCTURE = Rails.root.join("app/infrastructure").to_s

  def ports
    PORTS_ROOT.glob("**/*.rb").map { "Ports::#{it.relative_path_from(PORTS_ROOT).sub_ext('').to_s.camelize}".constantize }
  end

  def adapters_of(port)
    ObjectSpace.each_object(Class).select do |klass|
      klass.name && klass.include?(port) && Object.const_source_location(klass.name).first.to_s.start_with?(INFRASTRUCTURE)
    end
  end

  # A block parameter's name is free: `&` and `&block` are the same contract.
  def signature(method) = method.parameters.map { |type, name| type == :block ? [ :block ] : [ type, name ] }

  setup { Rails.application.eager_load! }

  test "every port has exactly one adapter in app/infrastructure" do
    offenders = ports.filter_map do |port|
      adapters = adapters_of(port)
      "#{port} : #{adapters.map(&:name).presence || 'aucun'}" unless adapters.size == 1
    end

    assert_empty offenders
  end

  test "each adapter defines every method of its port, with the same parameters" do
    offenders = ports.flat_map do |port|
      adapters_of(port).flat_map do |adapter|
        port.instance_methods(false).filter_map do |name|
          method = adapter.instance_method(name)
          next "#{adapter}##{name} n'est pas implémentée" if method.owner == port
          next if signature(method) == signature(port.instance_method(name))

          "#{adapter}##{name}#{signature(method)} ≠ #{port}##{name}#{signature(port.instance_method(name))}"
        end
      end
    end

    assert_empty offenders
  end

  test "a missing or diverging method is caught" do
    port = Module.new { def call(id:, at:) = raise(NotImplementedError) }
    diverging = Class.new { include port; def call(id:) = id } # rubocop:disable Style/Semicolon

    assert_equal port, Class.new { include port }.instance_method(:call).owner
    assert_not_equal signature(port.instance_method(:call)), signature(diverging.instance_method(:call))
  end
end
