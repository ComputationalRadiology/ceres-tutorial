FROM ubuntu:noble

# A word about HTTP_PROXY
# On systems that need to access a proxy to download packages, the build
# should be called with a build-arg that passes in the proxy to use.
#  A symptom that this is needed is that apt-get cannot access packages.
#  pip uses a different mechanism for accessing via a proxy.
# This is not needed if building on a system that does not  use a proxy.
#
# To set the proxy variable from the build environment:
# docker build --build-arg HTTP_PROXY .
#
    
LABEL maintainer="warfield@crl.med.harvard.edu"
LABEL vendor="Computational Radiology Laboratory"

# Set the locale
RUN DEBIAN_FRONTEND=noninteractive apt-get clean && apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y locales locales-all
ENV LANG en_US.UTF-8 
ENV LC_ALL en_US.UTF-8
ENV LANGUAGE en_US.UTF-8 

# Install the prerequisite software
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential \
                       apt-utils \
                       vim \
                       nano \
                       wget \
                       git \
                       gperf bison flex \
                       unzip zip \
                       cmake

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	libgoogle-glog-dev libgflags-dev \
	libatlas-base-dev \
	libeigen3-dev \
	libsuitesparse-dev

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libceres-dev \
	ceres-solver-doc

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	python3 \
	python3-full \
	python3-pip \
	python3-venv

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	python3-matplotlib \
	python3-numpy \
	python3-scipy \
	python3-tqdm \
	cython3 cython-doc \
	python3-nibabel

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3-matplotlib


# RUN rm -rf /var/lib/apt/lists/*

LABEL org.label-schema.name="ceres" \
      org.label-schema.description="CRKit - tools for computational radiology" \
      org.label-schema.url="http://crl.med.harvard.edu" \
      org.label-schema.schema-version="1.0"

# Sometimes git clone can fail due to a lack of buffer space.
# This fixes that problem.
ENV GIT_HTTP_MAX_REQUEST_BUFFER 100M

# DEFAULT entrypoint can be changed with --entrypoint
#ENTRYPOINT ["/bin/sh", "-c", "bash"]

# DEFAULT CMD provides a list of binaries.
CMD . /app/venv/bin/activate && cd /opt/src && python3 pdate.py -h

# Assume user data volume to be mounted at /data
#   docker run --volume=/path/to/data:/data
RUN mkdir -p /opt/src
WORKDIR /opt/src

COPY nls_solver /opt/src/nls_solver
RUN cd /opt/src/nls_solver && mkdir build && cd build && cmake .. && make
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/opt/src/nls_solver/build
RUN ls /opt/src/nls_solver
RUN ls /opt/src/nls_solver/build
RUN echo ${LD_LIBRARY_PATH}

# Now create the cython integration:
RUN ls /opt/src
COPY nls_solver.pxd /opt/src
COPY pdate.pyx /opt/src
COPY pdate.py /opt/src
COPY setup.py /opt/src
RUN cd /opt/src/ && python3 setup.py build_ext --inplace

RUN python3 -m venv --system-site-packages /app/venv
WORKDIR /app
RUN . /app/venv/bin/activate && pip3 install SimpleITK

# Now run the program
RUN . /app/venv/bin/activate && cd /opt/src && python3 pdate.py -h


# Ceres Solver 2.2 requires a fully C++17-compliant compiler
# CMake 3.16 or later required.
# Eigen 3.3 or later required.

# RUN git clone --branch 2.2.0 --recurse-submodules https://github.com/ceres-solver/ceres-solver ceres-solver-2.2.0

# RUN mkdir ceres-bin && cd ceres-bin && cmake ../ceres-solver-2.2.0 && \
#     make -j3 && make test && make install

# Assume user data volume to be mounted at /data
#   docker run --volume=/path/to/data:/data


# Build for ubuntu
# Use network=host option to provide proxy for apt and pip3
# DOCKER_BUILDKIT=1 docker build --progress=plain --network=host -t crl/ceres-tutorial:latest -f Dockerfile .

# Run the container to get a shell:
# docker run -it --rm --entrypoint bash crl/ceres-tutorial
#

