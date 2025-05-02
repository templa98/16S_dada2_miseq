# Modules

Each file inside the `modules/` directory is a support script that serves a purpose (e.g. timer, input/output, etc.). Each file has the following template:

`file_name.R` where the module name is `file_name` and all the functions are available though the `d2w_file_name` environment. Here, `d2w` is shorthand for **d**ada**2 w**orkflow and the rest is the module name.

For example:

```r
    # import the "timer" module from "timer.R" file
    source("./modules/timer.R")

    # call a public function from d2w_timer environment in the "timer" module
    # which will print the current time in milliseconds
    d2w_timer$current_runtime_ms()
    d2w_timer$current_systime_ms()
```

**Note:** you can use `ls(environment_name)` to find all of the function attached to that specific environment.
