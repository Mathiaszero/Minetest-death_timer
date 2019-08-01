# death_timer
Players are forced to wait an amount of time on re-spawn. 

On death players are cloaked and their interact privilege is removed. 

Players are held in place by a entity.

# config

The initial timeout on respawn.

``` lua
death_timer.initial_timeout = 8
```

The extra timeout values to add after the initial timeout (disable this by setting it to zero)

``` lua
death_timer.timeout = 1
```

The time it takes to reduce the death timeout (disable this by setting it to zero)

``` lua
death_timer.timeout_reduce_loop = 3600
```

The amount to reduce from the death timer timeout (disable this by setting it to zero)

``` lua
death_timer.timeout_reduce_rate = 1
```
