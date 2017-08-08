# frozen_string_literal: true

module Flippant
  class Registry
    def initialize
      clear
    end

    def register(group, fun = nil, &block)
      table[group.to_s] = fun || block
    end

    def registered
      table
    end

    def registered?(group)
      table.key?(group.to_s)
    end

    def clear
      @table = {}
    end

    private

    attr_reader :table
  end
end
