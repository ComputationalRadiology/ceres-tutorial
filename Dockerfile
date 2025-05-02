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

# Sometimes git clone can fail due to a lack of buffer space.
# This fixes that problem.
ENV export GIT_HTTP_MAX_REQUEST_BUFFER=100M

# ITK v5.3 does not compile with g++-13
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
        g++-12

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 13
RUN update-alternatives --set g++ /usr/bin/g++-12


RUN mkdir -p /opt/src/itksrc && cd /opt/src/itksrc && \
    git clone -b v5.3.0 https://github.com/InsightSoftwareConsortium/ITK ITK \
    && mkdir -p /opt/src/itksrc/itk-build

RUN cd /opt/src/itksrc/itk-build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt/itk \
        -DCMAKE_INSTALL_RPATH=${CMAKE_INSTALL_PREFIX}/lib \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
        -DBUILD_EXAMPLES:BOOL=OFF \
        -DBUILD_TESTING:BOOL=OFF \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_BUILD_TYPE:STRING=Release \
        -DCMAKE_CXX_FLAGS:STRING="-O2 -DNDEBUG -Wno-array-bounds" \
        -DCMAKE_CXX_FLAGS_RELEASE:STRING="-O3 -DNDEBUG -Wno-array-bounds" \
        /opt/src/itksrc/ITK && \
        make -j 1 && make install && \
        cd /opt/src && \
        rm -rf /opt/src/itksrc

# RUN mkdir -p /opt/src/quillsrc && cd /opt/src/quillsrc && git clone https://github.com/odygrd/quill.git && \
#    mkdir -p /opt/src/quillsrc/cmake_build && cd /opt/src/quillsrc/cmake_build && \
#    ls /opt/src/quillsrc && cmake /opt/src/quillsrc/quill && make install

RUN mkdir -p /opt/src/quillsrc
COPY quill /opt/src/quillsrc/quill
RUN cd /opt/src/quillsrc && \
   mkdir -p /opt/src/quillsrc/cmake_build && cd /opt/src/quillsrc/cmake_build && \
   ls /opt/src/quillsrc && cmake /opt/src/quillsrc/quill && make install

RUN mkdir -p /opt/src/intensityScaling
COPY intensityScaling /opt/src/intensityScaling
RUN cd /opt/src/intensityScaling && mkdir build && cd build && cmake .. && make
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/opt/src/intensityScaling/build
RUN ls /opt/src/intensityScaling/build

# Now create the cython integration:
RUN ls /opt/src
COPY nls_solver.pxd /opt/src
COPY pdate.pyx /opt/src
COPY pdate.py /opt/src
COPY setup.py /opt/src
RUN cd /opt/src/ && python3 setup.py build_ext --inplace

# Now create the cython integration:
RUN ls /opt/src
COPY intensityScaling.pxd /opt/src
COPY intensityScaling.pyx /opt/src
COPY intensityScaling.py /opt/src
COPY intensityScaling-setup.py /opt/src
RUN cd /opt/src/ && python3 intensityScaling-setup.py build_ext --inplace

RUN python3 -m venv --system-site-packages /app/venv
WORKDIR /app
RUN . /app/venv/bin/activate && pip3 install SimpleITK

# Now run the program
RUN . /app/venv/bin/activate && cd /opt/src && python3 pdate.py -h

# Now run the second program
RUN . /app/venv/bin/activate && cd /opt/src && python3 intensityScaling.py -h


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

