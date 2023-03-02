# Laundry list 

These are a set of known missing features/functionality where help would be highly appreciated with PR:s.

## Dependencies
It would be nice to remove the strict requirement on jemalloc if you don't want/need memory performance metrics, 
unclear if we can get conditional import of module if its available somehow?

## Misc
* Try to add support for missing metrics from both platforms
* Add support for printing the distribution graphs (linear and power-of-two) that we have instead of tables.
* Add support to Linux for using perf\_events to capture context switches, cache hit rate, IPC, instructions, ... (need physical machine for most, only context switches are available from virtualized hosts)
* Validate why some measurements provides 0 to Statistics (enable fatalError() and troubleshoot - likely malloc and time)
