# coding: utf-8
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/plugin/filter_influxdb_deduplication'
require 'test/unit'

class InfluxdbDeduplicationFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    @tag = 'test.tag'
  end

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::InfluxdbDeduplicationFilter).configure(conf)
  end

  def test_configure
    d = create_driver %[
      time_key my_time_key
    ]

    time_key = d.instance.instance_variable_get(:@time_key)
    assert time_key == "my_time_key"

    assert_raises Fluent::ConfigError do
      create_driver ""
    end
  end

  def test_in_sequence
    d = create_driver %[
      time_key time_key
    ]

    time0 = Fluent::EventTime.new(1613910640)
    time1 = Fluent::EventTime.new(1613910643)

    d.run(default_tag: @tag) do
      d.feed(time0, { "k1" => 0 })
      d.feed(time0, { "k1" => 1 })
      d.feed(time0, { "k1" => 2 })
      d.feed(time1, { "k1" => 3 })
      d.feed(time1, { "k1" => 4 })
    end

    assert_equal [
                   [time0, { "k1" => 0, "time_key" => 1613910640000000000 }],
                   [time0, { "k1" => 1, "time_key" => 1613910640000000001 }],
                   [time0, { "k1" => 2, "time_key" => 1613910640000000002 }],
                   [time1, { "k1" => 3, "time_key" => 1613910643000000000 }],
                   [time1, { "k1" => 4, "time_key" => 1613910643000000001 }]
                 ], d.filtered
  end

  def test_out_of_sequence_dropped
    d = create_driver %[
      time_key time_key
    ]

    time0 = Fluent::EventTime.new(1613910640)
    time1 = Fluent::EventTime.new(1613910643)

    d.run(default_tag: @tag) do
      d.feed(time0, { "k1" => 0 })
      d.feed(time1, { "k1" => 1 })
      d.feed(time0, { "k1" => 2 })
      d.feed(time1, { "k1" => 3 })
      d.feed(time1, { "k1" => 4 })
    end

    assert_equal [
                   [time0, { "k1" => 0, "time_key" => 1613910640000000000 }],
                   [time1, { "k1" => 1, "time_key" => 1613910643000000000 }],
                   [time1, { "k1" => 3, "time_key" => 1613910643000000001 }],
                   [time1, { "k1" => 4, "time_key" => 1613910643000000002 }]
                 ], d.filtered
  end

  def test_out_of_sequence_field
    d = create_driver %[
      time_key time_key
      out_of_order ooo_field
    ]

    time0 = Fluent::EventTime.new(1613910640)
    time1 = Fluent::EventTime.new(1613910643)

    d.run(default_tag: @tag) do
      d.feed(time0, { "k1" => 0 })
      d.feed(time1, { "k1" => 1 })
      d.feed(time0, { "k1" => 2 })
      d.feed(time1, { "k1" => 3 })
      d.feed(time1, { "k1" => 4 })
    end

    assert_equal [
                   [time0, { "k1" => 0, "time_key" => 1613910640000000000, "ooo_field" => false }],
                   [time1, { "k1" => 1, "time_key" => 1613910643000000000, "ooo_field" => false }],
                   [time0, { "k1" => 2, "time_key" => 1613910640000000000, "ooo_field" => true }],
                   [time1, { "k1" => 3, "time_key" => 1613910643000000001, "ooo_field" => false }],
                   [time1, { "k1" => 4, "time_key" => 1613910643000000002, "ooo_field" => false }]
                 ], d.filtered
  end

end
