# Creating and Comparing Benchmark Baselines

Benchmark supports storing, and comparing, benchmark results as you develop.

## Overview

While developing locally, you can set benchmark baselines, compare against a baseline, or compare two different baselines.

### Creating a Baseline

Typical workflow for a developer who wants to track performance metrics on the local machine while during performance work, would be to store one or more baselines. 
The default command to create a baseline uses the name `default`.

To create or update a default baseline, run the following command:

```bash
swift package --allow-writing-to-package-directory benchmark baseline update
```

The following command creates or updates a baseline named `alpha`:

```bash
swift package --allow-writing-to-package-directory benchmark baseline update alpha
```

### Comparing against a Baseline

As you are making performance updates to your code, compare the current state of your code against the default recorded baseline with the following command:

```bash
swift package benchmark baseline compare
```

The following command compares your current run against the baseline named `alpha`:

```bash
swift package benchmark compare alpha
```


If you have stored multiple baselines (for example for different approaches to solving a given performance issue), you can easily compare the two approaches by using named baselines for each and then compare them.
The following command compares a baseline named `alpha` against baseline named `beta`:

```bash
swift package benchmark compare alpha beta
```

