require 'fluent/plugin/filter'

module Fluent
  class Plugin::InfluxdbDeduplicationFilter < Plugin::Filter
    Fluent::Plugin.register_filter('influxdb_deduplication', self)

    desc "If not nil, the corresponding field takes the value true if the record arrived in order."
    config_param :order_key, :string, default: nil

    config_section :time, param_name: :time, multi: false, required: false do
      desc "The output time key to use."
      config_param :key, :string
    end

    config_section :tag, param_name: :tag, multi: false, required: false do
      desc "The output sequence tag to use."
      config_param :key, :string
    end

    def configure(conf)
      super

      if @time == nil and @tag == nil
        raise Fluent::ConfigError, "one of tag or time deduplication needs to be set."
      elsif @time != nil and @tag != nil
        raise Fluent::ConfigError, "tag and time deduplication are mutually exclusive."
      elsif @time != nil and (@time.key == nil or @time.key == "")
        raise Fluent::ConfigError, "an output 'key' field is required for time deduplication"
      elsif @tag != nil and (@tag == nil or @tag.key == "")
        raise Fluent::ConfigError, "an output 'key' field is required for tag deduplication"
      end
    end

    def start
      super

      @last_timestamp = 0
      @sequence = 0
    end

    def filter(tag, time, record)
      if @time
        time_deduplication(time, record)
      else
        tag_deduplication(time, record)
      end
    end

    def time_deduplication(time, record)
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
        if @order_key
          record[@order_key] = false
          record[@time.key] = nano_time
        else
          @log.debug("out of order record dropped")
          return nil
        end
      elsif input_time.sec == @last_timestamp and @sequence < 999999999
        @sequence = @sequence + 1
        record[@time.key] = nano_time + @sequence
        if @order_key
          record[@order_key] = true
        end
      elsif input_time.sec == @last_timestamp and @sequence == 999999999
        @log.error("received more then 999999999 records in a second")
        return nil
      else
        @sequence = 0
        @last_timestamp = input_time.sec
        record[@time.key] = nano_time
        if @order_key
          record[@order_key] = true
        end
      end

      record
    end

    def tag_deduplication(time, record)
      if time.is_a?(Integer)
        input_time = time
      elsif time.is_a?(Fluent::EventTime)
        input_time = time.sec * 1000000000 + time.nsec
      else
        @log.error("unreadable time")
        return nil
      end

      if input_time < @last_timestamp
        @log.debug("out of sequence timestamp")
        if @order_key
          record[@order_key] = false
        else
          @log.debug("out of order record dropped")
          return nil
        end
      elsif input_time == @last_timestamp
        @sequence = @sequence + 1
        record[@tag.key] = @sequence
        if @order_key
          record[@order_key] = true
        end
      else
        @sequence = 0
        @last_timestamp = input_time
        record[@tag.key] = 0
        if @order_key
          record[@order_key] = true
        end
      end

      record
    end
  end
end
