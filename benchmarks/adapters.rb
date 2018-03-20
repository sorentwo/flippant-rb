# frozen_string_literal: true

require "benchmark/ips"
require "flippant"
require "active_record"

ActiveRecord::Base.establish_connection("postgres:///flippant_test")

memory = Flippant::Adapter::Memory.new
postgres = Flippant::Adapter::Postgres.new
redis = Flippant::Adapter::Redis.new

memory_enabled = lambda do
  Flippant.adapter = memory unless Flippant.adapter == memory

  Flippant.enabled?("search", nil)
end

postgres_enabled = lambda do
  Flippant.adapter = postgres unless Flippant.adapter == postgres

  Flippant.enabled?("search", nil)
end

redis_enabled = lambda do
  Flippant.adapter = redis unless Flippant.adapter == redis

  Flippant.enabled?("search", nil)
end

Flippant.configure do |config|
  config.adapter = Flippant::Adapter::Postgres.new
end

Flippant.register("everybody", ->(_, _) { true })
Flippant.enable("search", "everybody")

Benchmark.ips do |x|
  x.report "memory:enabled?", &memory_enabled
  x.report "postgres:enabled?", &postgres_enabled
  x.report "redis:enabled?", &redis_enabled
  x.compare!
end
