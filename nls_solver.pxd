# nls_solver.pxd

cdef extern from "nls_solver/nls_solver.h":
    void evaluate_t1(double* t1, double* pd, double* data, int data_len) nogil
