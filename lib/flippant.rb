# frozen_string_literal: true

require "json"

module Flippant
  autoload :Error, "flippant/errors"
  autoload :Registry, "flippant/registry"
  autoload :Rules, "flippant/rules"

  module Adapter
    autoload :Memory, "flippant/adapters/memory"
    autoload :Postgres, "flippant/adapters/postgres"
    autoload :Redis, "flippant/adapters/redis"
  end

  extend Forwardable
  extend self

  attr_writer :adapter, :registry, :serializer

  def_delegators :adapter,
                 :breakdown,
                 :clear,
                 :features

  def_delegators :registry,
                 :register,
                 :registered,
                 :registered?,
                 :clear

  # Guarded Delegation

  def add(feature)
    adapter.add(normalize(feature))
  end

  def exists?(features, group = nil)
    adapter.exists?(normalize(features), group)
  end

  def enable(feature, group, values = [])
    raise Flippant::Error, "Unknown group: #{group}" unless registered?(group)

    adapter.enable(normalize(feature), group, values)
  end

  def enabled?(feature, actor)
    adapter.enabled?(normalize(feature), actor)
  end

  def disable(feature, group, values = [])
    adapter.disable(normalize(feature), group, values)
  end

  def rename(old_name, new_name)
    adapter.rename(normalize(old_name), normalize(new_name))
  end

  def remove(feature)
    adapter.remove(normalize(feature))
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

  private

  def normalize(feature)
    feature.to_s.downcase.strip
  end
end
