# valgrind-wrapper

VALGRIND(1) allows to find file descriptor leaks with `--track-fds=yes` by showing how many file descriptors are opened at exit. As described in this [stack overflow post](https://stackoverflow.com/questions/72977881/valgrind-track-fds-yes-exit-code-0-even-when-there-are-fd-leaks), you can't use this option easily to integrate the check in CI.

This wrapper script solves this by parsing the output of valgrind to see how many FDs are opened at exit, and exits with (non-zero) error code if there are any leaks.

Additionally, the wrapper allows to analyze applications that run in the infinite loop by sending SIGINT after a given timeout. Note that you would have to handle `SIGINT` signal in your C/C++ programs to exit nicely, otherwise a bunch of leaks will be reported by valgrind.

Also, since valgrind 3.17 the output of `--track-fds=yes` changes. Before 3.17:
```
==874818== FILE DESCRIPTORS: 4 open at exit.
```

After 3.17:
```
==874818== FILE DESCRIPTORS: 4 open (3 std) at exit.
```

This is why there are two script versions provided.
