require 'active_record/connection_adapters/planetscale_api_ruby/mysql2/result'
require 'active_record/connection_adapters/planetscale_api_ruby/mysql2/client'
require 'active_record/connection_adapters/planetscale_api_ruby/mysql2/connection_handling'
# require 'active_record/connection_adapters/planetscale_api_ruby/gem_hack'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PlanetscaleApiRubyAdapter < Mysql2Adapter
      include PlanetscaleApiRuby::Abstract

      def self.name
        'Mysql2Adapter'
      end if ENV['AASA_ENV'] == 'test'

      def mysql2_connection(config)
        aurora_serverless_connection(config)
      end

      # Abstract Mysql Adapter

      def supports_advisory_locks?
        false
      end


      private

      def connect
        @connection = ConnectionHandling.aurora_serverless_connection_from_config(@config)
        configure_connection
      end

      # Abstract Mysql Adapter

      def translate_exception(exception, message:, sql:, binds:)
        msg = exception.message
        case msg
        when /Duplicate entry/
          RecordNotUnique.new(msg, sql: sql, binds: binds)
        when /foreign key constraint fails/
          InvalidForeignKey.new(msg, sql: sql, binds: binds)
        when /Cannot add foreign key constraint/,
             /referenced column .* in foreign key constraint .* are incompatible/
          mismatched_foreign_key(msg, sql: sql, binds: binds)
        when /Data too long for column/
          ValueTooLong.new(msg, sql: sql, binds: binds)
        when /Out of range value for column/
          RangeError.new(msg, sql: sql, binds: binds)
        when /Column .* cannot be null/,
             /Field .* doesn't have a default value/
          NotNullViolation.new(msg, sql: sql, binds: binds)
        when /Deadlock found when trying to get lock/
          Deadlocked.new(msg, sql: sql, binds: binds)
        when /Lock wait timeout exceeded/
          LockWaitTimeout.new(msg, sql: sql, binds: binds)
        when /max_statement_time exceeded/, /Sort aborted/
          StatementTimeout.new(msg, sql: sql, binds: binds)
        when /Query execution was interrupted/
          QueryCanceled.new(msg, sql: sql, binds: binds)
        else
          ActiveRecord::StatementInvalid.new(msg, sql: sql, binds: binds)
        end
      end

      # Database Statements

      def execute_batch(sql, name = nil)
        execute(sql, name)
      end

      def multi_statements_enabled?(flags)
        false
      end

      def with_multi_statements
        yield
      end

      def combine_multi_statements(total_sql)
        total_sql
      end

      def max_allowed_packet
        65536
      end

    end
  end
end
