FROM ubuntu:22.04

# setup and install prerequisite system packages
ENV LANGUAGE=en_AU.UTF-8 DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install wget make -y

# install miniconda3 (also cleans up afterward)
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /miniconda3 && \
    rm -rf Miniconda3-latest-Linux-x86_64.sh /root/.cache
ENV PATH="/haemosphere-env/bin:/miniconda3/bin:${PATH}"

# create /haemosphere-env conda environment and install  prerequisite packages
# (also cleans up afterward)
COPY environment.yml /haemosphere/environment.yml
RUN conda env update --solver libmamba --file /haemosphere/environment.yml -p /haemosphere-env && \
    conda clean --all  && rm -rf /root/.cache

# continue installing prerequisite packages with pip
COPY requirements.txt /haemosphere/requirements.txt
RUN pip install -r /haemosphere/requirements.txt

# install prerequisite R packages
# note: MAKEFILES="-j" will have R use all CPUs when compiling packages
COPY r_packages.r /haemosphere/r_packages.r
RUN MAKEFLAGS="-j" Rscript /haemosphere/r_packages.r

# copy haemosphere pip package files and install into /haemosphere-env
COPY ./setup.py /haemosphere/setup.py
COPY ./haemosphere /haemosphere/haemosphere
COPY ./README.md /haemosphere/README.md
COPY ./CHANGES.txt /haemosphere/CHANGES.txt
COPY ./MANIFEST.in /haemosphere/MANIFEST.in
RUN pip install -e /haemosphere && rm -rf /root/.cache

WORKDIR /
