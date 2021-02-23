require 'fluent/plugin/filter'

module Fluent
  class Plugin::InfluxdbDeduplicationFilter < Plugin::Filter
    Fluent::Plugin.register_filter('influxdb_deduplication', self)

    config_param :time_key, :string, default: nil,
                 desc: <<-DESC
The output time key to use.
    DESC

    config_param :out_of_order, :string, default: nil,
                 desc: <<-DESC
If not nil, the field takes the value true if the record arrives in order and false otherwise
    DESC

    def configure(conf)
      super

      unless @time_key
        raise Fluent::ConfigError, "a time key must be set"
      end
    end

    def start
      super

      @last_timestamp = 0
      @sequence = 0
    end

    def filter(tag, time, record)
      if time.is_a?(Integer)
        input_time = Fluent::EventTime.new(time)
      elsif time.is_a?(Fluent::EventTime)
        input_time = time
      else
        @log.error("unreadable time")
        return nil
      end

      nano_time = input_time.sec * 1000000000

      if input_time.sec < @last_timestamp
        @log.debug("out of sequence timestamp")
        if @out_of_order
          record[@out_of_order] = true
          record[@time_key] = nano_time
        else
          @log.debug("out of order record dropped")
          return nil
        end
      elsif input_time.sec == @last_timestamp && @sequence < 999999999
        @sequence = @sequence + 1
        record[@time_key] = nano_time + @sequence
        if @out_of_order
          record[@out_of_order] = false
        end
      elsif input_time.sec == @last_timestamp && @sequence == 999999999
        @log.error("received more then 999999999 records in a second")
        return nil
      else
        @sequence = 0
        @last_timestamp = input_time.sec
        record[@time_key] = nano_time
        if @out_of_order
          record[@out_of_order] = false
        end
      end

      record
    end

  end
end
