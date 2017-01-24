# frozen_string_literal: true

require "redis"

module Flippant
  module Adapter
    class Redis
      extend Forwardable

      DEFAULT_KEY = "features"

      attr_reader :client, :key, :serializer

      def_delegators :serializer, :dump, :load

      def initialize(client = ::Redis.current,
                     key = DEFAULT_KEY,
                     serializer = Flippant.serializer)
        @client = client
        @key = key
        @serializer = serializer
      end

      def add(feature)
        client.sadd(key, feature)
      end

      def remove(feature)
        client.multi do
          client.srem(key, feature)
          client.del(namespace(feature))
        end
      end

      def enable(feature, group, values = [])
        add(feature)

        client.hset(namespace(feature), group, dump(values))
      end

      def disable(feature, group)
        namespaced = namespace(feature)

        client.hdel(namespaced, group)
        client.srem(key, feature) if client.hgetall(namespaced).empty?
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

      def namespace(feature)
        "#{key}-#{feature}"
      end
    end
  end
end
