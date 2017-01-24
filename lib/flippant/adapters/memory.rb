# frozen_string_literal: true

module Flippant
  module Adapter
    class Memory
      attr_reader :table

      def initialize
        clear
      end

      def add(feature)
        table[feature.to_s] ||= {}
      end

      def remove(feature)
        table.delete(feature)
      end

      def enable(feature, group, values = [])
        fkey = feature.to_s
        gkey = group.to_s

        table[fkey][gkey] ||= []
        table[fkey][gkey] = (table[fkey][gkey] | values)
      end

      def disable(feature, to_remove)
        table[feature.to_s].reject! { |(group, _)| group == to_remove.to_s }
      end

      def enabled?(feature, actor, registered = Flippant.registered)
        table[feature.to_s].any? do |group, values|
          if (block = registered[group.to_s])
            block.call(actor, values)
          end
        end
      end

      def exists?(feature, group = nil)
        if group.nil?
          table.key?(feature)
        else
          table.dig(feature, group.to_s)
        end
      end

      def features(filter = nil)
        if filter.nil?
          table.keys.sort
        else
          table.select do |_, pairs|
            pairs.any? { |(group, _)| group == filter.to_s }
          end.keys.sort
        end
      end

      def breakdown(actor = nil)
        return table if actor.nil?

        table.each_with_object({}) do |(feature, _), memo|
          memo[feature] = enabled?(feature, actor)
        end
      end

      def clear
        @table = Hash.new { |hash, key| hash[key] = {} }
      end
    end
  end
end
