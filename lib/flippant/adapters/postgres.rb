# frozen_string_literal: true

require "active_record"
require "pg"

module Flippant
  module Adapter
    class Postgres
      DEFAULT_TABLE = "flippant_features"

      attr_reader :pool, :table

      def initialize(pool: ActiveRecord::Base.connection_pool, table: DEFAULT_TABLE)
        @pool = pool
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
        if values.empty?
          exec("UPDATE #{table} SET rules = rules - $1 WHERE name = $2", [group, feature])
        else
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

        result.values.first == [true]
      end

      def features(group = :all)
        result =
          if group == :all
            exec("SELECT name FROM #{table} ORDER BY name ASC")
          else
            exec("SELECT name FROM #{table} WHERE rules ? $1 ORDER BY name ASC", [group])
          end

        result.values.flatten
      end

      def load(loaded)
        transaction do |client|
          loaded.each do |feature, rules|
            client.exec_params(
              "INSERT INTO #{table} AS t (name, rules) VALUES ($1, $2)",
              [feature, encode_json(rules)]
            )
          end
        end
      end

      def rename(old_name, new_name)
        transaction do |client|
          client.exec_params("DELETE FROM #{table} WHERE name = $1",
                             [new_name])

          client.exec_params("UPDATE #{table} SET name = $1 WHERE name = $2",
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

      def conn
        pool.with_connection do |connection|
          client = connection.raw_connection

          yield client
        end
      end

      def exec(sql, params = [])
        conn do |client|
          if params.empty?
            client.exec(sql)
          else
            client.exec_params(sql, params)
          end
        end
      end

      def transaction(&block)
        conn do |client|
          client.transaction(&block)
        end
      end

      def encode_array(value)
        PG::TextEncoder::Array.new.encode(value)
      end

      def encode_json(value)
        PG::TextEncoder::JSON.new.encode(value)
      end
    end
  end
end
