# MersenneBoy

A 32 KiB Game Boy ROM that runs the Lucas–Lehmer primality test on 2ⁿ − 1, for exponents from 2 to 2047.

By default on startup it tests 2¹²⁷ − 1, which is prime. For a quick result, try 2¹¹ − 1

## Controls
Right/Left: Increment/Decrement n by 1
Up/Down: Increment/Decrement n by 10
A / Start: Runs the test.
B: resets n to 127, hold during a calculation to stop after current iteration.


Composite exponents finish instantly because if n = ab with a,b > 1, then 2ᵃ − 1 divides 2ⁿ − 1. Odd prime exponents get all (n−2) Lucas–Lehmer iterations. 

# Build
 Build with [RGBDS 1.0.3](https://github.com/gbdev/rgbds/releases/tag/v1.0.3) and `make`; the output rom should be `build/MersenneBoy.gb`.

At the original Game Boy clock, exponent 127 takes about seven seconds and 521 takes about seven minutes. Large exponents take hours. I have not tested this on the original gameboy because I do not have one :( 
I did test it on a TI-nspire CX II CAS though.

Licensed under the MIT license.
