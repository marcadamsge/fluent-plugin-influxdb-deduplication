# [Fluentd](https://www.fluentd.org/) filter plugin to deduplicate records for InfluxDB

A filter plugin that implements the deduplication techniques described in
the [InfluxDB doc](https://docs.influxdata.com/influxdb/v2.0/write-data/best-practices/duplicate-points/).

## Installation

Using RubyGems:

```
fluent-gem install fluent-plugin-influxdb-deduplication
```

## Configuration

### Deduplicate by incrementing the timestamp

Each data point is assigned a unique timestamp. The filter plugin reads the fluentd record event time with a precision
to the second, and stores it in a field with a precision to the nanosecond. Any sequence of record with the same
timestamp has a timestamp incremented by 1 nanosecond.

    <filter pattern>
      @type influxdb_deduplication

      <time>
        # field to store the deduplicated timestamp
        key my_key_field
      </time>
    </filter>

For example, the following input records:

| Fluentd Event Time | Record |
|---|---|
| 1613910640 | { "k1" => 0, "k2" => "value0" } |
| 1613910640 | { "k1" => 1, "k2" => "value1" } |
| 1613910640 | { "k1" => 2, "k2" => "value2" } |
| 1613910641 | { "k1" => 3, "k3" => "value3" } |

Would become on output:

| Fluentd Event Time | Record |
|---|---|
| 1613910640 | { "k1" => 0, "k2" => "value0", "my_key_field" => 1613910640000000000 } |
| 1613910640 | { "k1" => 1, "k2" => "value1", "my_key_field" => 1613910640000000001 } |
| 1613910640 | { "k1" => 2, "k2" => "value2", "my_key_field" => 1613910640000000002 } |
| 1613910641 | { "k1" => 3, "k3" => "value3", "my_key_field" => 1613910643000000000 } |

The time key field can then be passed as is to
the [fluent-plugin-influxdb-v2](https://github.com/influxdata/influxdb-plugin-fluent). Example configuration on nginx
logs:

    <filter nginx.access>
      @type influxdb_deduplication
    
      <time>
        # field to store the deduplicated timestamp
        key my_key_field
      </time>
    </filter>

    <match nginx.access>
        @type influxdb2

        # setup the access to your InfluxDB v2 instance
        url             https://localhost:8086
        token           my-token
        bucket          my-bucket
        org             my-org

        # the influxdb2 time_key must be set to the same value as the influxdb_deduplication time.key
        time_key my_key_field

        # the timestamp precision must be set to ns
        time_precision ns

        tag_keys ["request_method", "status"]
        field_keys ["remote_addr", "request_uri"]
    </match>

The data can then be queried as a table and viewed in [Grafana](https://grafana.com/) for example with the flux query:

    from(bucket: "my-bucket")
      |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
      |> pivot(
        rowKey: ["_time"],
        columnKey: ["_field"],
        valueColumn: "_value"
      )
      |> keep(columns: ["_time", "request_method", "status", "remote_addr", "request_uri"])

### Deduplicate by adding a sequence tag

Each record is assigned a sequence number, the output record can be uniquely identified by the pair (fluentd_event_time,
sequence_number). The event time is untouched so no precision is lost for time.

    <filter pattern>
      @type influxdb_deduplication

      <tag>
        # field to store the deduplicated timestamp
        key my_key_field
      </tag>
    </filter>

For example, the following input records:

| Fluentd Event Time | Record |
|---|---|
| 1613910640 | { "k1" => 0, "k2" => "value0" } |
| 1613910640 | { "k1" => 1, "k2" => "value1" } |
| 1613910640 | { "k1" => 2, "k2" => "value2" } |
| 1613910641 | { "k1" => 3, "k3" => "value3" } |

Would become on output:

| Fluentd Event Time | Record |
|---|---|
| 1613910640 | { "k1" => 0, "k2" => "value0", "my_key_field" => 0 } |
| 1613910640 | { "k1" => 1, "k2" => "value1", "my_key_field" => 1 } |
| 1613910640 | { "k1" => 2, "k2" => "value2", "my_key_field" => 2 } |
| 1613910641 | { "k1" => 3, "k3" => "value3", "my_key_field" => 0 } |

The sequence tag should be passed in the tag parameters
of [fluent-plugin-influxdb-v2](https://github.com/influxdata/influxdb-plugin-fluent). Example configuration on nginx
logs:

    <filter nginx.access>
      @type influxdb_deduplication
    
      <time>
        # field to store the deduplicated timestamp
        key my_key_field
      </time>
    </filter>

    <match nginx.access>
        @type influxdb2

        # setup the access to your InfluxDB v2 instance
        url             https://localhost:8086
        token           my-token
        bucket          my-bucket
        org             my-org

        # the influxdb2 time_key is not specified so the fluentd event time is used
        # time_key

        # there's no requirements on the time_precision value this time
        # time_precision ns

        # "my_key_field" must be passed to influxdb's tag_keys
        tag_keys ["request_method", "status", "my_key_field"]
        field_keys ["remote_addr", "request_uri"]
    </match>

The data can then be queried as a table and viewed in [Grafana](https://grafana.com/) for example with the flux query:

    from(bucket: "my-bucket")
      |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
      |> pivot(
        rowKey: ["_time", "my_key_field"],
        columnKey: ["_field"],
        valueColumn: "_value"
      )
      |> keep(columns: ["_time", "request_method", "status", "remote_addr", "request_uri"])

### Detecting out of order records

This filter plugin expects the fluentd event timestamps of the incoming record to increase and never decrease.
Optionally, a order key can be added to indicate if the record arrived in order or not. For example with this config

    <filter pattern>
      @type influxdb_deduplication
      
      order_key order_field
      
      <time>
        # field to store the deduplicated timestamp
        key my_key_field
      </time>
    </filter>

Without order key, out of order records are dropped to avoid previous data points being overridden. With a order key,
out of order records will still be pushed but with `order_field = false`. Out of order records are not deduplicated but
they will be apparent in influxdb.
