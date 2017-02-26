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
        mutex = Mutex.new

        mutex.synchronize do
          table[fkey][gkey] ||= []
          table[fkey][gkey] = (table[fkey][gkey] | values).sort
        end
      end

      def disable(feature, group, values = [])
        rules = table[feature.to_s]
        mutex = Mutex.new

        mutex.synchronize do
          if values.any?
            remove_values(rules, group, values)
          else
            remove_group(rules, group)
          end
        end
      end

      def rename(old_feature, new_feature)
        old_feature = old_feature.to_s
        new_feature = new_feature.to_s

        table[new_feature] = table.delete(old_feature)
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
          table.key?(feature.to_s)
        else
          table.dig(feature.to_s, group.to_s)
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

      private

      def remove_group(rules, to_remove)
        rules.reject! { |(group, _)| group == to_remove.to_s }
      end

      def remove_values(rules, group, values)
        rules[group] = (rules[group] - values)
      end
    end
  end
end
