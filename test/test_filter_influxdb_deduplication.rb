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

  def test_configure_time
    create_driver %[
      <time>
        key my_time_key
      </time>
    ]

    assert_raises Fluent::ConfigError do
      create_driver %[
        <time>
        </time>
      ]
    end

    assert_raises Fluent::ConfigError do
      create_driver %[
        <time>
          key
        </time>
      ]
    end
  end

  def test_configure_tag
    create_driver %[
      <tag>
        key my_tag_key
      </tag>
    ]

    assert_raises Fluent::ConfigError do
      create_driver %[
        <tag>
        </tag>
      ]
    end

    assert_raises Fluent::ConfigError do
      create_driver %[
        <tag>
          key
        </tag>
      ]
    end
  end

  def test_configuration_needed
    assert_raises Fluent::ConfigError do
      create_driver ""
    end
  end

  def test_time_and_tag_exclusivity
    assert_raises Fluent::ConfigError do
      create_driver %[
        <time>
          key my_time_key
        </time>
        <tag>
          key my_tag_key
        </tag>
      ]
    end
  end

  def test_time_in_sequence
    d = create_driver %[
      <time>
        key time_key
      </time>
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

  def test_time_out_of_sequence_dropped
    d = create_driver %[
      <time>
        key time_key
      </time>
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

  def test_time_order_field
    d = create_driver %[
      order_key order_field
      <time>
        key time_key
      </time>
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
                   [time0, { "k1" => 0, "time_key" => 1613910640000000000, "order_field" => true }],
                   [time1, { "k1" => 1, "time_key" => 1613910643000000000, "order_field" => true }],
                   [time0, { "k1" => 2, "time_key" => 1613910640000000000, "order_field" => false }],
                   [time1, { "k1" => 3, "time_key" => 1613910643000000001, "order_field" => true }],
                   [time1, { "k1" => 4, "time_key" => 1613910643000000002, "order_field" => true }]
                 ], d.filtered
  end

  def test_time_max_sequence
    d = create_driver %[
      <time>
        key time_key
      </time>
    ]

    time0 = Fluent::EventTime.new(1613910640)
    time1 = Fluent::EventTime.new(1613910641)

    d.run(default_tag: @tag) do
      d.feed(time0, { "k1" => 0 })
      d.instance.instance_variable_set(:@sequence, 999999998)
      d.feed(time0, { "k1" => 1 })
      d.feed(time0, { "k1" => 2 })
      d.feed(time1, { "k1" => 3 })
      d.feed(time1, { "k1" => 4 })
    end

    assert_equal [
                   [time0, { "k1" => 0, "time_key" => 1613910640000000000 }],
                   [time0, { "k1" => 1, "time_key" => 1613910640999999999 }],
                   [time1, { "k1" => 3, "time_key" => 1613910641000000000 }],
                   [time1, { "k1" => 4, "time_key" => 1613910641000000001 }]
                 ], d.filtered
  end

  def test_tag_in_sequence
    d = create_driver %[
      <tag>
        key tag_key
      </tag>
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
                   [time0, { "k1" => 0, "tag_key" => 0 }],
                   [time0, { "k1" => 1, "tag_key" => 1 }],
                   [time0, { "k1" => 2, "tag_key" => 2 }],
                   [time1, { "k1" => 3, "tag_key" => 0 }],
                   [time1, { "k1" => 4, "tag_key" => 1 }]
                 ], d.filtered
  end

  def test_tag_out_of_sequence_dropped
    d = create_driver %[
      <tag>
        key tag_key
      </tag>
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
                   [time0, { "k1" => 0, "tag_key" => 0 }],
                   [time1, { "k1" => 1, "tag_key" => 0 }],
                   [time1, { "k1" => 3, "tag_key" => 1 }],
                   [time1, { "k1" => 4, "tag_key" => 2 }]
                 ], d.filtered
  end

  def test_tag_order_field
    d = create_driver %[
      order_key order_field
      <tag>
        key tag_key
      </tag>
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
                   [time0, { "k1" => 0, "tag_key" => 0, "order_field" => true }],
                   [time1, { "k1" => 1, "tag_key" => 0, "order_field" => true }],
                   [time0, { "k1" => 2, "order_field" => false }],
                   [time1, { "k1" => 3, "tag_key" => 1, "order_field" => true }],
                   [time1, { "k1" => 4, "tag_key" => 2, "order_field" => true }]
                 ], d.filtered
  end
end
