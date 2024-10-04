# Creating and Comparing Benchmark Baselines

Benchmark supports storing, and comparing, benchmark baselines as you develop.

## Overview

While developing locally, you can set benchmark baselines, compare a baseline against a benchmark run, or compare two different baselines.

### Creating a Baseline

Typical workflow for a developer who wants to track performance metrics on the local machine while during performance work, would be to store one or more baselines. 

To create or update a baseline named `alpha`, run the following command:

```bash
swift package --allow-writing-to-package-directory benchmark baseline update alpha
```

### Comparing against a Baseline

As you are making performance updates to your code, compare the current state of your code against a recorded baseline with the following command:

```bash
swift package benchmark baseline compare alpha
```

If you have stored multiple baselines (for example for different approaches to solving a given performance issue), you can easily compare the two approaches by using named baselines for each and then compare them.
The following command compares a baseline named `alpha` against baseline named `beta`:

```bash
swift package benchmark baseline compare alpha beta
```

### Comparing a test run against static thresholds

The following will run all benchmarks and compare them against a previously saved static threshold.
```bash
swift package benchmark thresholds check
```
