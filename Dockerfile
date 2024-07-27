ARG TIDYVERSE_TAG

FROM rocker/tidyverse:latest

# Clang seems to be more memory efficient than g++
RUN apt-get update -y && apt-get install -y --no-install-recommends libglpk-dev \
    clang-3.6 \
    curl \
    xz-utils \
    ocl-icd-libopencl1 \
    opencl-headers \
    clinfo \
RUN apt-get install nvidia-drivers-460 nvidia-cuda-toolkit clinfo
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
RUN ln -s /usr/lib/x86_64-linux-gnu/libOpenCL.so.1 /usr/lib/libOpenCL.so


RUN mkdir -p $HOME/.R/ \ 
  && echo "CXX=clang++ -stdlib=libc++ -fsanitize=address,undefined -fno-sanitize=float-divide-by-zero -fno-omit-frame-pointer -fsanitize-address-use-after-scope -fno-sanitize=alignment -frtti" >> $HOME/.R/Makevars \
  && echo "CC=clang -fsanitize=address,undefined -fno-sanitize=float-divide-by-zero -fno-omit-frame-pointer -fsanitize-address-use-after-scope -fno-sanitize=alignment" >> $HOME/.R/Makevars \
  && echo "CFLAGS=-O3 -Wall -pedantic -mtune=native" >> $HOME/.R/Makevars \
  && echo "FFLAGS=-O2 -mtune=native" >> $HOME/.R/Makevars \
  && echo "FCFLAGS=-O2 -mtune=native" >> $HOME/.R/Makevars \
  && echo "CXXFLAGS=-O3 -march=native -mtune=native -fPIC" >> $HOME/.R/Makevars \
  && echo "MAIN_LD=clang++ -stdlib=libc++ -fsanitize=undefined,address" >> $HOME/.R/Makevars \
  && echo "rstan::rstan_options(auto_write = TRUE)" >> /home/rstudio/.Rprofile \
  && echo "options(mc.cores = parallel::detectCores())" >> /home/rstudio/.Rprofile

RUN R -q -e 'Sys.setenv(DOWNLOAD_STATIC_LIBV8 = 1); install.packages("rstan")'

ENV CMDSTAN /usr/share/.cmdstan

RUN cd /usr/share/ \
  && wget --progress=dot:mega https://github.com/stan-dev/cmdstan/releases/download/v2.35.0/cmdstan-2.35.0.tar.gz \
  && tar -zxpf cmdstan-2.35.0.tar.gz && mv cmdstan-2.35.0 .cmdstan \
  && ln -s .cmdstan cmdstan && cd .cmdstan \
  && echo "CXX = clang++" >> make/local \
  && echo "STAN_OPENCL=true" >> make/local \
  && echo "OPENCL_PLATFORM_ID=0" >> make/local \
  && echo "OPENCL_DEVICE_ID=0" >> make/local \
  && make build

RUN R -q -e 'install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", getOption("repos")))'

ENV BAYES_R_PACKAGES="\
    brms \
    loo \ 
" 

RUN install2.r --error --skipinstalled $BAYES_R_PACKAGES

