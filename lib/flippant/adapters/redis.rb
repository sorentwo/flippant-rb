# frozen_string_literal: true

require "redis"

module Flippant
  module Adapter
    class Redis
      extend Forwardable

      DEFAULT_KEY = "flippant-features"

      attr_reader :client, :key, :serializer

      def_delegators :serializer, :dump, :load

      def initialize(client: ::Redis.current,
                     key: DEFAULT_KEY,
                     serializer: Flippant.serializer)
        @client = client
        @key = key
        @serializer = serializer
      end

      def add(feature)
        client.sadd(key, normalize(feature))
      end

      def remove(feature)
        client.multi do
          client.srem(key, feature)
          client.del(namespace(feature))
        end
      end

      def enable(feature, group, values = [])
        add(feature)

        change_values(namespace(feature), group) do |old|
          (old | values).sort
        end
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

      def rename(old_feature, new_feature)
        old_feature = normalize(old_feature)
        new_feature = normalize(new_feature)
        old_namespaced = namespace(old_feature)
        new_namespaced = namespace(new_feature)

        client.watch(old_namespaced, new_namespaced) do
          client.multi do
            client.srem(key, old_feature)
            client.sadd(key, new_feature)
            client.rename(old_namespaced, new_namespaced)
          end
        end
      end

      def enabled?(feature, actor, registered = Flippant.registered)
        client.hgetall(namespace(feature)).any? do |group, values|
          if (block = registered[group])
            block.call(actor, load(values))
          end
        end
      end

      def exists?(feature, group = nil)
        if group.nil?
          client.sismember(key, feature)
        else
          client.hexists(namespace(feature), group)
        end
      end

      def features(filter = :all)
        if filter == :all
          client.smembers(key).sort
        else
          features(:all).select do |fkey|
            client.hexists(namespace(fkey), filter)
          end
        end
      end

      def breakdown(actor = nil)
        features(:all).each_with_object({}) do |fkey, memo|
          memo[fkey] = actor.nil? ? feature_rules(fkey) : enabled?(fkey, actor)
        end
      end

      def clear
        client.smembers(key).each { |fkey| remove(fkey) }
      end

      private

      def feature_rules(feature)
        namespaced = namespace(feature)

        client.hgetall(namespaced).each_with_object({}) do |(key, val), memo|
          memo[key] = load(val)
        end
      end

      def get_values(namespaced, group)
        load(client.hget(namespaced, group)) || []
      end

      def maybe_cleanup(feature)
        namespaced = namespace(feature)

        client.srem(key, feature) if client.hkeys(namespaced).empty?
      end

      def namespace(feature)
        "#{key}-#{normalize(feature)}"
      end

      def normalize(feature)
        feature.to_s.downcase.strip
      end

      def change_values(namespaced, group)
        client.watch(namespaced) do
          old_values = get_values(namespaced, group)
          new_values = yield(old_values)

          client.multi do
            client.hset(namespaced, group, dump(new_values))
          end
        end
      end
    end
  end
end
