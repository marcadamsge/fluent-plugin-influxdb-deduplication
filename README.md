# [Fluentd](https://www.fluentd.org/) filter plugin to deduplicate records for InfluxDB

A filter plugin that implements the deduplication techniques described in the [InfluxDB doc](https://docs.influxdata.com/influxdb/v2.0/write-data/best-practices/duplicate-points/).


## Installation

Using RubyGems:

```
fluent-gem install fluent-plugin-influxdb-deduplication
```


## Configuration

### Deduplicate by incrementing the timestamp

The filter plugin reads the fluentd record event time with a precision to the second, and stores it in the `time_key` field.
Any following record with the same timestamp has a `time_key` incremented by 1 nanosecond.

    <filter pattern>
      @type influxdb_deduplication
    
      # field to store the deduplicated timestamp
      time_key my_key_field
    </filter>

For example, the following input records:

    1613910640 { "k1" => 0, "k2" => "value0" }
    1613910640 { "k1" => 1, "k2" => "value1" }
    1613910640 { "k1" => 2, "k2" => "value2" }
    1613910641 { "k1" => 3, "k3" => "value3" }

Would create on output:

    1613910640 { "k1" => 0, "k2" => "value0", "my_key_field" => 1613910640000000000 }
    1613910640 { "k1" => 1, "k2" => "value1", "my_key_field" => 1613910640000000001 }
    1613910640 { "k1" => 2, "k2" => "value2", "my_key_field" => 1613910640000000002 }
    1613910641 { "k1" => 3, "k3" => "value3", "my_key_field" => 1613910643000000000 }

The time key field can then be passed as is to the [fluent-plugin-influxdb-v2](https://github.com/influxdata/influxdb-plugin-fluent).
Example configuration on nginx logs:

    <filter nginx.access>
      @type influxdb_deduplication
    
      # field to store the deduplicated timestamp
      time_key my_key_field
    </filter>

    <match nginx.access>
        @type influxdb2

        # setup the access to your InfluxDB v2 instance
        url             https://localhost:8086
        token           my-token
        bucket          my-bucket
        org             my-org

        # the influxdb2 timekey must be set to the same value as the influxdb_deduplication time_key
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
        rowKey:["_time"],
        columnKey: ["_field"],
        valueColumn: "_value"
      )
      |> keep(columns: ["_time", "request_method", "status", "remote_addr", "request_uri"])


### Deduplicate by adding a sequence tag

TODO
