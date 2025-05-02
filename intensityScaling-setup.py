from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

ext_modules = [
    Extension(
            'intensityScaling',
            ['intensityScaling.pyx'],
            extra_compile_args=['-fopenmp'],
            extra_link_args=['-fopenmp'],
            libraries=['intensityScaling'],
            library_dirs=["/opt/src/intensityScaling/build"]
            )
    ]

setup(
        name='intensityScaling',
        ext_modules=cythonize(
            ext_modules,
            language_level="3",
            annotate=True),
     )
