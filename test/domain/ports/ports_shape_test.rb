require "test_helper"

module Ports
  # Contrat de chaque port, sans base : toute méthode lève NotImplementedError,
  # avec un message qui la nomme, tant qu'un repository ne l'implémente pas.
  class PortsShapeTest < ActiveSupport::TestCase
    ROOT = Rails.root.join("app/domain/ports")

    def self.ports
      Dir[ROOT.join("**/*.rb")].sort.map do |file|
        file.delete_prefix("#{ROOT}/").delete_suffix(".rb").camelize.then { |name| "Ports::#{name}".constantize }
      end
    end

    def arguments_for(method)
      method.parameters.each_with_object([ [], {} ]) do |(kind, name), (positional, keywords)|
        positional << nil if kind == :req
        keywords[name] = nil if kind == :keyreq
      end
    end

    test "chaque port est un module d'arguments nommés" do
      self.class.ports.each do |port|
        assert_instance_of Module, port

        port.instance_methods(false).each do |name|
          kinds = port.instance_method(name).parameters.map(&:first)

          assert_empty kinds & %i[req opt rest], "#{port}##{name} doit prendre des arguments nommés"
        end
      end
    end

    test "chaque méthode de port lève NotImplementedError en se nommant" do
      self.class.ports.each do |port|
        subject = Class.new { include port }.new

        port.instance_methods(false).each do |name|
          positional, keywords = arguments_for(subject.method(name))
          error = assert_raises(NotImplementedError, "#{port}##{name}") { subject.public_send(name, *positional, **keywords) { nil } }

          assert_match "##{name}", error.message
        end
      end
    end

    test "chaque port déclare au moins une méthode" do
      assert_operator self.class.ports.size, :>=, 1

      self.class.ports.each { |port| assert_not_empty port.instance_methods(false), port.name }
    end
  end
end
