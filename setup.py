from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

ext_modules = [
    Extension(
            'pdate',
            ['pdate.pyx'],
            extra_compile_args=['-fopenmp'],
            extra_link_args=['-fopenmp'],
            libraries=['nls_solver'],
            library_dirs=["/opt/src/nls_solver/build"]
            )
    ]

setup(
        name='pdate',
        ext_modules=cythonize(
            ext_modules,
            language_level="3",
            annotate=True),
     )
