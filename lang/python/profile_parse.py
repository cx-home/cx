#!/usr/bin/env python3
"""Profile Python parse() at 1 MB: split FFI parse vs Python decode."""
import sys, time, cProfile, pstats, io
sys.path.insert(0, 'lang/python')
import cxlib
from cxlib.binary import ast_bin, decode_ast

with open('fixtures/bench/bench_1mb.cx') as f:
    src = f.read()

# Step-split timing
N = 20
ffi_times, dec_times = [], []
for _ in range(N):
    t0 = time.perf_counter()
    raw = ast_bin(src)
    t1 = time.perf_counter()
    decode_ast(raw)
    t2 = time.perf_counter()
    ffi_times.append((t1 - t0) * 1000)
    dec_times.append((t2 - t1) * 1000)

ffi_times.sort(); dec_times.sort()
print(f'FFI parse (cx_to_ast_bin):  median {ffi_times[N//2]:.2f} ms  min {ffi_times[0]:.2f} ms')
print(f'Python decode_ast:          median {dec_times[N//2]:.2f} ms  min {dec_times[0]:.2f} ms')
print(f'Total parse():              median {ffi_times[N//2] + dec_times[N//2]:.2f} ms')

# cProfile of the decode step
raw = ast_bin(src)
pr = cProfile.Profile()
pr.enable()
for _ in range(10):
    decode_ast(raw)
pr.disable()
s = io.StringIO()
pstats.Stats(pr, stream=s).strip_dirs().sort_stats('cumulative').print_stats(25)
print('\n--- decode_ast cProfile (10 iterations) ---')
print(s.getvalue())
