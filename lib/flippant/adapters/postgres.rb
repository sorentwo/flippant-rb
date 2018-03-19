# frozen_string_literal: true

require "monitor"
require "pg"

module Flippant
  module Adapter
    class Postgres
      DEFAULT_TABLE = "flippant_features"
      DEFAULT_URL = "postgres:///flippant_test"

      attr_reader :client, :monitor

      def initialize(client: nil, options: {}, table: DEFAULT_TABLE)
        @client = client || connect(options)
        @monitor = Monitor.new
        @table = table
      end

      def add(feature)
        exec("INSERT INTO #{table} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING", [feature])
      end

      def breakdown(actor = :all)
        result = exec("SELECT jsonb_object_agg(name, rules) FROM #{table}")
        object = JSON.parse(result.values.flatten.first || "{}")

        object.each_with_object({}) do |(fkey, rules), memo|
          memo[fkey] = actor == :all ? rules : Rules.enabled_for_actor?(rules, actor)
        end
      end

      def clear
        exec("TRUNCATE #{table} RESTART IDENTITY")
      end

      def disable(feature, group, values)
        if values.any?
          disable_some(feature, group, values)
        else
          disable_all(feature, group)
        end
      end

      def enable(feature, group, values)
        command = <<~SQL
          INSERT INTO #{table} AS t (name, rules) VALUES ($1, $2)
          ON CONFLICT (name) DO UPDATE
          SET rules = jsonb_set(t.rules, $3, array_to_json(
            ARRAY(
              SELECT DISTINCT(UNNEST(ARRAY(
                SELECT jsonb_array_elements(COALESCE(t.rules#>$3, '[]'::jsonb))
              ) || $4))
            )
          )::jsonb)
        SQL

        exec(command, [feature,
                       encode_json(group => values),
                       encode_array([group]),
                       encode_array(values)])
      end

      def enabled?(feature, actor)
        result = exec("SELECT rules FROM #{table} WHERE name = $1", [feature])
        object = JSON.parse(result.values.flatten.first || "[]")

        Rules.enabled_for_actor?(object, actor)
      end

      def exists?(feature, group = nil)
        result =
          if group.nil?
            exec("SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1)",
                 [feature])
          else
            exec("SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1 " \
                 "AND rules ? $2)",
                 [feature, group])
          end

        result.values.first == ["t"]
      end

      def features(group = :all)
        (group == :all ? all_rules : some_rules(group)).values.flatten
      end

      def rename(old_name, new_name)
        transaction do |conn|
          conn.exec_params("DELETE FROM #{table} WHERE name = $1",
                           [new_name])

          conn.exec_params("UPDATE #{table} SET name = $1 WHERE name = $2",
                           [new_name, old_name])
        end
      end

      def remove(feature)
        exec("DELETE FROM #{table} WHERE name = $1", [feature])
      end

      def setup
        exec <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            name text NOT NULL CHECK (name <> ''),
            rules jsonb NOT NULL DEFAULT '{}'::jsonb,
            CONSTRAINT unique_name UNIQUE(name)
          )
        SQL
      end

      private

      def connect(options)
        uri = URI.parse(options.fetch(:url, DEFAULT_URL))

        PG.connect(uri.hostname,
                   uri.port,
                   nil,
                   nil,
                   uri.path[1..-1],
                   uri.user,
                   uri.password)
      end

      def table
        client.quote_ident(@table)
      end

      # Connection Helpers

      def encode_array(value)
        PG::TextEncoder::Array.new.encode(value)
      end

      def encode_json(value)
        PG::TextEncoder::JSON.new.encode(value)
      end

      def exec(sql, params = nil)
        monitor.synchronize do
          if params.nil?
            client.exec(sql)
          else
            client.exec_params(sql, params)
          end
        end
      end

      def transaction(&block)
        monitor.synchronize do
          client.transaction(&block)
        end
      end

      # Query Helpers

      def all_rules
        client.exec("SELECT name FROM #{table} ORDER BY name ASC")
      end

      def some_rules(group)
        client.exec_params(
          "SELECT name FROM #{table} WHERE rules ? $1 ORDER BY name ASC",
          [group]
        )
      end

      def disable_all(feature, group)
        exec("UPDATE #{table} SET rules = rules - $1 WHERE name = $2", [group, feature])
      end

      def disable_some(feature, group, values)
        command = <<~SQL
          UPDATE #{table} SET rules = jsonb_set(rules, $1, array_to_json(
            ARRAY(
              SELECT UNNEST(ARRAY(SELECT jsonb_array_elements(COALESCE(rules#>$1, '[]'::jsonb))))
              EXCEPT
              SELECT UNNEST(ARRAY(SELECT jsonb_array_elements($2)))
            )
          )::jsonb)
          WHERE name = $3
        SQL

        exec(command, [encode_array([group]), encode_json(values), feature])
      end
    end
  end
end
