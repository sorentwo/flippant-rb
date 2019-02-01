# frozen_string_literal: true

require "redis"
require "forwardable"

module Flippant
  module Adapter
    class Redis
      extend Forwardable

      DEFAULT_KEY = "flippant-features"

      attr_reader :client, :set_key, :serializer

      def initialize(client: ::Redis.current,
                     set_key: DEFAULT_KEY,
                     serializer: Flippant.serializer)
        @client = client
        @serializer = serializer
        @set_key = set_key
      end

      def setup
        true
      end

      def add(feature)
        client.sadd(set_key, feature)
      end

      def breakdown(actor = nil)
        features(:all).each_with_object({}) do |fkey, memo|
          memo[fkey] = actor.nil? ? feature_rules(fkey) : enabled?(fkey, actor)
        end
      end

      def clear
        client.smembers(set_key).each { |fkey| remove(fkey) }
      end

      def disable(feature, group, values = [])
        namespaced = namespace(feature)

        if values.any?
          change_values(namespaced, group) do |old|
            old - values
          end
        else
          client.hdel(namespaced, group)
        end

        maybe_cleanup(feature)
      end

      def enable(feature, group, values = [])
        add(feature)

        change_values(namespace(feature), group) do |old|
          (old | values).sort
        end
      end

      def enabled?(feature, actor, registered = Flippant.registered)
        client.hgetall(namespace(feature)).any? do |group, values|
          if (block = registered[group])
            block.call(actor, serializer.load(values))
          end
        end
      end

      def exists?(feature, group)
        if group.nil?
          client.sismember(set_key, feature)
        else
          client.hexists(namespace(feature), group)
        end
      end

      def features(filter = :all)
        if filter == :all
          client.smembers(set_key).sort
        else
          features(:all).select do |fkey|
            client.hexists(namespace(fkey), filter)
          end
        end
      end

      def load(loaded)
        client.multi do
          loaded.each do |feature, rules|
            client.sadd(set_key, feature)

            rules.each do |group, values|
              client.hset(namespace(feature), group, serializer.dump(values))
            end
          end
        end
      end

      def remove(feature)
        client.multi do
          client.srem(set_key, feature)
          client.del(namespace(feature))
        end
      end

      def rename(old_feature, new_feature)
        old_feature = old_feature
        new_feature = new_feature
        old_namespaced = namespace(old_feature)
        new_namespaced = namespace(new_feature)

        client.watch(old_namespaced, new_namespaced) do
          client.multi do
            client.srem(set_key, old_feature)
            client.sadd(set_key, new_feature)
            client.rename(old_namespaced, new_namespaced)
          end
        end
      end

      private

      def feature_rules(feature)
        namespaced = namespace(feature)

        client.hgetall(namespaced).each_with_object({}) do |(key, val), memo|
          memo[key] = serializer.load(val)
        end
      end

      def get_values(namespaced, group)
        serializer.load(client.hget(namespaced, group)) || []
      end

      def maybe_cleanup(feature)
        namespaced = namespace(feature)

        client.srem(set_key, feature) if client.hkeys(namespaced).empty?
      end

      def namespace(feature)
        "#{set_key}-#{feature}"
      end

      def change_values(namespaced, group)
        client.watch(namespaced) do
          old_values = get_values(namespaced, group)
          new_values = yield(old_values)

          client.multi do
            client.hset(namespaced, group, serializer.dump(new_values))
          end
        end
      end
    end
  end
end
