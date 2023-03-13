# Exporting Benchmark Results

Export Benchmarks into other formats to analyze or visualize the data.

## Overview

Benchmark supports exporting its results into a variety of formats including text formats, Java Microbenchmark Harness (JMH), Influx, and as a serialized [HDR Histogram](http://hdrhistogram.org).
This allows for tracking performance over time or analyzing/visualizing with other tools such as [JMH visualizer](https://jmh.morethan.io), [Gnuplot](http://www.gnuplot.info), [YouPlot](https://github.com/red-data-tools/YouPlot), [HDR Histogram analyzer](http://hdrhistogram.github.io/HdrHistogram/plotFiles.html) and more.

To export the benchmark information, add the desired format with the `--format` option when running the benchmarks.
For example, to export your benchmarks into JMH format, use the command:

```bash
swift package --allow-writing-to-package-directory benchmark --format jmh
```

### Streaming Text formats

- term `text`: The default output, displaying a textual grid of information for your benchmarks, suitable for use in the console. 
- term `markdown`: The same content as `text`, but extended with explicit markdown support, suitable for use as output from e.g. a GitHub workflow action.

The default text output from Benchmark is oriented around [the five-number summary](https://en.wikipedia.org/wiki/Five-number_summary) percentiles, plus the last decile (`p90`) and the last percentile (`p99`) - it's thus a variation of a [seven-figure summary](https://en.wikipedia.org/wiki/Seven-number_summary) with the focus on the 'bad' end of results (as those are what we typically care about addressing).
The output streams to the terminal, allowing you to easily capture it to write to a file or preserve in an environment variable, which can be useful in continuous integration scenarios.
For more information on using this output within continuous integration, see the examples in <doc:ComparingBenchmarksCI>.

### Saved Formats

- term `percentiles`: Each benchmark and metric combination is written to a file with the file name extension `txt`. Each file contains a sequence of percentiles for that metric combination, as well as statistical summary information. 
- term `tsv`: Each benchmark and metric combination is written to a file with the file name extension `tsv`.
- term `influx`: A single file is generated with the file name extension `csv` with the values encoded as metrics using the [Influx Line Protocol](https://docs.influxdata.com/influxdb/v1.8/write_protocols/line_protocol_reference/).
- term `jmh`: A single file is generated with the file name extension `jmh` encoded in the [java microbenchmark harness](https://openjdk.org/projects/code-tools/jmh/) format. You can quickly compare the contained metrics by dropping the file into the [JMH visualizer](https://jmh.morethan.io) using a browser.
- term `encodedHistogram`:  Each benchmark and metric combination is written to a file with the file name extension `json`, containing the serialized [HdrHistogram](https://github.com/ordo-one/package-histogram)) in JSON format.

