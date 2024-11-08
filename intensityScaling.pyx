# tag: openmp

# distutils: language=c++
# distutils: extra_compile_args=-fopenmp
# distutils: extra_link_args=-fopenmp

import numpy as np
from scipy.optimize import least_squares
from tqdm import trange, tqdm

cimport cython
from cython cimport boundscheck, wraparound
from cython.parallel import prange, parallel
from libc.stdlib cimport abort, malloc, free

from intensityScaling cimport intensityScaling


print('Hello')

exit(0)

