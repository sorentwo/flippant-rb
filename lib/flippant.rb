# frozen_string_literal: true

module Flippant
  autoload :Registry, "flippant/registry"

  module Adapter
    autoload :Memory, "flippant/adapters/memory"
  end

  extend Forwardable
  extend self

  attr_writer :adapter, :registry

  def_delegators :adapter,
                 :add,
                 :remove,
                 :enable,
                 :enabled?,
                 :disable,
                 :features,
                 :breakdown,
                 :clear

  def_delegators :registry,
                 :register,
                 :registered,
                 :clear

  def adapter
    @adapter ||= Flippant::Adapter::Memory.new
  end

  def registry
    @registry ||= Flippant::Registry.new
  end

  def configure
    yield self
  end

  def clear(selection = nil)
    case selection
    when :features then adapter.clear
    when :groups then registry.clear
    else adapter.clear && registry.clear
    end
  end
end
