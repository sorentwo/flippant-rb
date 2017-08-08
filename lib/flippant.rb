# frozen_string_literal: true

require "json"

module Flippant
  autoload :Error, "flippant/errors"
  autoload :Registry, "flippant/registry"

  module Adapter
    autoload :Memory, "flippant/adapters/memory"
    autoload :Redis, "flippant/adapters/redis"
  end

  extend Forwardable
  extend self

  attr_writer :adapter, :registry, :serializer

  def_delegators :adapter,
                 :add,
                 :breakdown,
                 :clear,
                 :disable,
                 :enabled?,
                 :exists?,
                 :features,
                 :remove,
                 :rename

  def_delegators :registry,
                 :register,
                 :registered,
                 :registered?,
                 :clear

  # Guarded Delegation

  def enable(feature, group, values = [])
    raise Flippant::Error, "Unknown group: #{group}" unless registered?(group)

    adapter.enable(feature, group, values)
  end

  # Configuration

  def adapter
    @adapter ||= Flippant::Adapter::Memory.new
  end

  def registry
    @registry ||= Flippant::Registry.new
  end

  def serializer
    @serializer ||= JSON
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
