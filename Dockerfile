# Python version to use
ARG PYTHON_VERSION=3.11.4
ARG PYENV_ROOT=/pyenv

FROM ubuntu:20.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure apt to never install recommended packages and do not prompt for user input
RUN printf 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";\n' >> /etc/apt/apt.conf.d/01norecommends
ENV DEBIAN_FRONTEND=noninteractive

# Set locale and timezone
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install --yes locales tzdata && \
    apt-get autoremove --yes && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    locale-gen "en_US.UTF-8"
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Install prerequisites for pyenv and building python
RUN apt-get update && \
    apt-get install --yes \
        ca-certificates curl git \
        build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libncursesw5-dev libsqlite3-dev tk-dev xz-utils libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libgdbm-dev libc6-dev checkinstall

# Install pyenv
ARG PYENV_ROOT
RUN curl https://pyenv.run | bash
COPY pyenv_shell.sh ${PYENV_ROOT}/pyenv_shell.sh
RUN ${PYENV_ROOT}/plugins/python-build/install.sh

# # Install the specified python version
# ARG PYTHON_VERSION
# RUN source ${PYENV_ROOT}/pyenv_shell.sh && \
#     time env PYTHON_CONFIGURE_OPTS='--enable-optimizations --with-lto' PYTHON_CFLAGS='-march=native -mtune=native' PROFILE_TASK='-m test.regrtest --pgo -j0' pyenv install ${PYTHON_VERSION}

# # Install packages into the specified python
# COPY pip.conf ${PYENV_ROOT}/versions/${PYTHON_VERSION}/pip.conf
# COPY python-requirements.d/ /tmp/
# RUN source ${PYENV_ROOT}/pyenv_shell.sh && \
#     pyenv shell ${PYTHON_VERSION} && \
#     for req_file in $(find /tmp/python-requirements.d/ -name "*.txt"); do pip install --upgrade --requirement "${req_file}"; done && \
#     rm -rf /tmp/python-requirements.d
