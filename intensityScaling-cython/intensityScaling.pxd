# intensityScaling.pxd

cdef extern from "../intensityScaling/intensityScaling.h":
  int intensityScaling(int argc, char *argv[]) nogil

