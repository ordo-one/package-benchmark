#  Workflows

## Local developer workflow
Typical workflow for a developer who wants to track performance metrics on the local machine while during performance work, would be to store one or more baselines (either default or named baselines), with e.g:

`swift package --allow-writing-to-package-directory benchmark baseline update`
or
`swift package --allow-writing-to-package-directory benchmark baseline update alpha`

then while working, simply compare current state of local repo with the previously recorded baseline:

`swift package benchmark baseline compare`
or
`swift package benchmark baseline compare alpha`

If you have stored multiple baselines (for example for different approaches to solving a given performance issue), you can easily compare the two approaches by using named baselines for each and then compare them:

`swift package benchmark baseline compare alpha beta`

## Debugging

### Debugging crashing benchmarks
The benchmark executables are set up to automatically run all tests when run standalone with simple debug output - this is to enable workflows where the benchmark is run in the Xcode debugger or with Instruments if desired - or with `lldb` on the command line on Linux to support debugging in problematic performance tests.

```
swift build
lldb .build/debug/MyBenchmark
```

The debug benchmark also takes the `--filter` and `--skip` flags, so if you have a specific benchmark that you want to debug:

```
.build/debug/MyBenchmark --filter "RunThis.*"
```

### Debugging the BenchmarkTool if it crashes
In case the BenchmarkTool that is the benchmark runner itself would crash, it is easily debuggable using:

```
swift package benchmark <all the options as usual here> --debug
```

This prints out detaile debug instructions how to run in the debugger to ge a proper backtrace.

## GitHub CI workflow

For GitHub, there are sample workflows provided: 

* Delta comparison workflow, which will run the benchmark on both the pull request and the `main` branch and compare the results with the specified thresholds and fail/succeed the workflow accordingly. It also makes a comment into the PR with the results (which will be updated with subsequent runs of the workflow for the PR)
* Simple benchmark - simply runs the benchmark test suite on the pull request and update a separate PR commend with a link to the results.

For reproducible and good comparable results, it is *highly* recommended to set up a private GitHub runner that is
dedicated to performance benchmark runs.
