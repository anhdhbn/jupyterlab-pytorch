FROM nvidia/cuda:11.0.3-devel-ubuntu20.04

# cuda
LABEL com.nvidia.volumes.needed="nvidia_driver"
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}

ARG PYTHON_VERSION=3.8
ARG TORCH_VERSION=1.7.1

ENV USER anhdh
ENV HOME "/home/$USER"
ENV NOTEBOOKS "$HOME/notebooks"
ENV CONDA_ROOT "${HOME}/.conda"
ENV TZ=Asia/Ho_Chi_Minh

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget sudo

# Create user
RUN useradd -U ${USER} -m -s /bin/bash -G sudo && passwd -d ${USER} && \
    sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^#includedir.*/## Removed the #include directive! ##"/g' && \
    echo "Customized the sudoers file for passwordless access!" && \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR ${HOME}
USER ${USER}

RUN bash -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh)" -- \
    -t robbyrussell \
    -a 'CASE_SENSITIVE="true"' \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-completions \
    -p https://github.com/zsh-users/zsh-syntax-highlighting \
    -p autojump

RUN sudo chsh -s $(which zsh) ${USER}
RUN zsh
RUN echo $SHELL

RUN sudo apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
    locales \
    zip \
    unzip \
    libjpeg-dev \
    libpng-dev \    
    ffmpeg \
    libsm6 \
    libxext6 \
    zsh \
    autojump \
    htop \
    tmux \
    nano && \
    sudo apt-get autoremove -y && \
    sudo apt-get clean -y && \
    sudo rm -rf /var/lib/apt/lists/*

# install miniconda
RUN curl -o ~/miniconda.sh -O  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p ${CONDA_ROOT} && \
    rm ~/miniconda.sh && \
    ${CONDA_ROOT}/bin/conda config --system --prepend channels conda-forge && \
    ${CONDA_ROOT}/bin/conda config --system --set show_channel_urls true && \
    ${CONDA_ROOT}/bin/conda install conda-build && \
    ${CONDA_ROOT}/bin/conda update --all --quiet --yes && \
    ${CONDA_ROOT}/bin/conda clean -ay && \
    rm -rf /home/$USER/.cache/yarn && \
    source ${CONDA_ROOT}/etc/profile.d/conda.sh

ENV PATH ${CONDA_ROOT}/bin/:$PATH

# Create Environment
RUN conda update -n base -c defaults conda && \
    conda create -n torch -y python=${PYTHON_VERSION}

ENV PATH ${CONDA_ROOT}/envs/torch/bin:$PATH

RUN echo "source ${CONDA_ROOT}/bin/activate torch" >> ~/.zshrc

RUN \
    conda install -n torch pytorch=${TORCH_VERSION} torchvision cudatoolkit=11.0 -c pytorch && \
    conda install -n torch -c conda-forge jupyter jupyterlab jupyter_contrib_nbextensions jupyter_nbextensions_configurator tensorboard && \
    conda install -n torch -c conda-forge scikit-image scikit-learn tqdm imageio matplotlib seaborn pandas
    
RUN conda install -n torch -c conda-forge nodejs --repodata-fn=repodata.json
RUN ${CONDA_ROOT}/envs/torch/bin/pip3 install torchsummary requests opencv-python

# jupyter
RUN jupyter-lab --generate-config
RUN \
    # sed -i '/c.ServerApp.root_dir/c\c.ServerApp.root_dir = "'"${NOTEBOOKS}"'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.ip/c\c.ServerApp.ip = "'"0.0.0.0"'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.LabApp.open_browser/c\c.LabApp.open_browser = False' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.quit_button/c\c.ServerApp.quit_button = True' ~/.jupyter/jupyter_lab_config.py && \
    # sed -i '/c.ServerApp.token/c\c.ServerApp.token = "'""'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.terminado_settings/c\c.ServerApp.terminado_settings = {"'"shell_command"'":["'"zsh"'"]}' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.trust_xheaders/c\c.ServerApp.trust_xheaders = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.disable_check_xsrf/c\c.ServerApp.disable_check_xsrf = False' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.allow_remote_access/c\c.ServerApp.allow_remote_access = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/\<c.ServerApp.allow_origin\>/c\c.ServerApp.allow_origin = "'"*"'"' ~/.jupyter/jupyter_lab_config.py && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager

EXPOSE 8888

# WORKDIR ${NOTEBOOKS}

# fix warning jupyter
RUN conda install -n torch "nbconvert=5.6.1"

# fix zsh paperspace
RUN sed -i 's/source $ZSH/ZSH_DISABLE_COMPFIX=true\nsource $ZSH/' ${HOME}/.zshrc

# apex
RUN git clone https://github.com/NVIDIA/apex ${HOME}/apex
RUN echo "pip install -v --disable-pip-version-check --no-cache-dir --global-option=\"--cpp_ext\" --global-option=\"--cuda_ext\" ${HOME}/apex && rm -rf ${HOME}/apex" >> ${HOME}/apex.sh

CMD ["jupyter", "lab" , "--ip=0.0.0.0", "--ServerApp.token=\"\""]
