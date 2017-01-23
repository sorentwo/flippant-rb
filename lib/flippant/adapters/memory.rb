# frozen_string_literal: true

module Flippant
  module Adapter
    class Memory
      def initialize
        clear
      end

      def add(feature)
        table[feature] ||= {}
      end

      def remove(feature)
        table.delete(feature)
      end

      def enable(feature, group, values = [])
        add(feature)

        table[feature][group] = values
      end

      def disable(feature, to_remove)
        table[feature].reject! { |(group, _)| group == to_remove }
      end

      def enabled?(feature, actor, registered = Flippant.registered)
        rules = table[feature] || {}

        rules.any? do |group, values|
          if block = registered[group.to_s]
            block.call(actor, values)
          end
        end
      end

      def features(filter = :all)
        filter = filter.to_s

        matching = if filter == "all"
          table
        else
          table.select do |name, pairs|
            pairs.any? { |(group, _)| group == filter }
          end
        end

        matching.keys.sort
      end

      def breakdown(actor = nil)
        return table if actor.nil?

        table.each_with_object({}) do |(feature, _), memo|
          memo[feature] = enabled?(feature, actor)
        end
      end

      def clear
        @table = {}
      end

      private

      attr_reader :table
    end
  end
end
