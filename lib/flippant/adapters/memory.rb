# frozen_string_literal: true

require "monitor"

module Flippant
  module Adapter
    class Memory
      attr_reader :monitor, :table

      def initialize
        @monitor = Monitor.new

        clear
      end

      def setup
        true
      end

      def add(feature)
        table[feature] ||= {}
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

      def disable(feature, group, values = [])
        rules = table[feature]

        monitor.synchronize do
          if values.any?
            remove_values(rules, group, values)
          else
            remove_group(rules, group)
          end
        end
      end

      def enable(feature, group, values = [])
        fkey = feature
        gkey = group.to_s

        monitor.synchronize do
          table[fkey][gkey] ||= []
          table[fkey][gkey] = (table[fkey][gkey] | values).sort
        end
      end

      def enabled?(feature, actor, registered = Flippant.registered)
        table[feature].any? do |group, values|
          if (block = registered[group.to_s])
            block.call(actor, values)
          end
        end
      end

      def exists?(feature, group)
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

      def load(loaded)
        monitor.synchronize do
          loaded.each do |feature, rules|
            rules.each do |group, values|
              table[feature][group] = values
            end
          end
        end
      end

      def remove(feature)
        table.delete(feature)
      end

      def rename(old_feature, new_feature)
        old_feature = old_feature
        new_feature = new_feature

        table[new_feature] = table.delete(old_feature)
      end

      private

      def remove_group(rules, to_remove)
        rules.reject! { |(group, _)| group == to_remove.to_s }
      end

      def remove_values(rules, group, values)
        rules[group.to_s] = (rules[group.to_s] - values)
      end
    end
  end
end
