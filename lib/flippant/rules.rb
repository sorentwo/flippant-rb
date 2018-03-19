# frozen_string_literal: true

module Flippant
  module Rules
    def self.enabled_for_actor?(rules, actor, groups = Flippant.registered)
      rules.any? do |name, values|
        if (block = groups[name])
          block.call(actor, values)
        end
      end
    end
  end
end
