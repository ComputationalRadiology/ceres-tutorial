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

from nls_solver cimport evaluate_t1

def init_t1(imgs, TI):
    pd = np.maximum(500, imgs[..., -1])
    t1 = np.zeros_like(pd, dtype=np.float64)

    for i in range(imgs.shape[0]):
        for j in range(imgs.shape[1]):
            for k in range(imgs.shape[2]):
                y = np.array(imgs[i, j, k, :])

                ti = np.array(TI[:-1])
                tmp = 0.5 - 0.5 * y[:-1]/pd[i, j, k]
                L = tmp > 0
                if np.all(L):
                    t10 = np.mean(ti[L] / -np.log(tmp[L]))
                    if t10 < 0:
                        t10 = 500
                elif np.any(L):
                    t10 = np.mean(ti[L] / -np.log(tmp[L]))
                else:
                    t10 = 0

                if not t10:
                    t10 = 0

                t1[i, j, k] = max(0.1, min(t10, 5000))

    return (t1, pd)

def cost_t1(x, ti, fa, y):
    t1 = np.clip(x[1], np.finfo(np.float32).eps, None)
    return x[0] * (1 - (1 - np.cos(fa)) * np.exp(-ti / t1)) - y

def compute_cy(imgs, ti, fa):
    n_imgs = imgs.shape[-1]
    #t1, pd = init_t1(imgs, ti)
    pd = np.maximum(500., imgs[..., -1])
    t1 = np.zeros_like(pd, dtype=np.float64)

    ni = imgs.shape[0]
    nj = imgs.shape[1]
    nk = imgs.shape[2]
    nl = imgs.shape[3]

    for i in range(ni):
        for j in trange(nj):
            for k in range(nk):
                r0 = [pd[i,j,k], 50.]#t1[i,j,k]]
                res = least_squares(cost_t1, r0,
                        args=(ti, fa, np.squeeze(imgs[i,j,k,:])), loss='linear',
                        bounds=([0, 0], [np.inf, 5000]))
                pd[i,j,k] = res.x[0]
                t1[i,j,k] = res.x[1]
    return (t1, pd)

    
@cython.boundscheck(False)
@cython.wraparound(False)
def compute_mt(double[:,:,:,:] imgs, double[:] ti, double[:] fa):
    n_imgs = imgs.shape[3]
    t1, pd = init_t1(imgs, ti)

    cdef:
        double[:,:,::1] t1_view = t1
        double[:,:,::1] pd_view = pd

        int ni = imgs.shape[0]
        int nj = imgs.shape[1]
        int nk = imgs.shape[2]
        int nl = imgs.shape[3]

        int i, j, k, l
        double s
        int n

        double* data_view
        int data_view_sz = sizeof(double) * n_imgs * 3

    with nogil, parallel():
        data_view = <double*> malloc(data_view_sz)
        if data_view is NULL:
            abort()

        for j in prange(nj, schedule="guided"):
            for i in range(ni):
                for k in range(nk):
                    for l in range(nl):
                        data_view[l * 3] = imgs[i, j, k, l]
                        data_view[l * 3 + 1] = ti[l]
                        data_view[l * 3 + 2] = fa[l]

                    evaluate_t1(&t1_view[i, j, k], &pd_view[i, j, k], &data_view[0], nl)

        free(data_view)

    return (t1, pd)
