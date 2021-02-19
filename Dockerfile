FROM nvidia/cuda:11.0.3-devel-ubuntu20.04

ENV LANG C.UTF-8
ENV USER anhdh
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV PYTHON_VERSION=3.8
ENV HOME "/home/$USER"
ENV NOTEBOOKS "$HOME/notebooks"
ENV CONDA_ROOT "${HOME}/conda"
ENV TZ=Asia/Ho_Chi_Minh
LABEL com.nvidia.volumes.needed="nvidia_driver"

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
    libjpeg-dev \
    zip \
    unzip \
    libpng-dev \
    zsh \
    htop \
    tmux \
    sudo &&\
    rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -rm -d ${HOME} -s /bin/bash -g root -G sudo -u 1699 $USER
RUN echo "${USER}:." | chpasswd
USER $USER

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

# zsh
WORKDIR ${HOME}
RUN curl -L http://install.ohmyz.sh | sh
RUN zsh
USER root
RUN chsh -s $(which zsh)
RUN sed -i '4s/^/auth       sufficient   pam_wheel.so trust group=chsh\n/' /etc/pam.d/chsh
RUN groupadd chsh
RUN usermod -a -G chsh ${USER}
USER $USER
RUN git clone git://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
RUN echo "source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
RUN chmod 771 ~/.oh-my-zsh

# Create Environment
RUN conda update -n base -c defaults conda && \
    conda create -n torch -y python=${PYTHON_VERSION}

ENV PATH ${CONDA_ROOT}/envs/torch/bin:$PATH

RUN echo "source ${CONDA_ROOT}/bin/activate torch" >> ~/.zshrc

CMD source ~/.zshrc

RUN conda install -n torch  pytorch torchvision cudatoolkit=11.0 -c pytorch
RUN conda install -n torch  -c conda-forge scikit-image scikit-learn tqdm imageio matplotlib seaborn pandas
RUN conda install -n torch  -c conda-forge jupyter jupyterlab jupyter_contrib_nbextensions tensorboard
RUN conda install -n torch  -c conda-forge nodejs --repodata-fn=repodata.json
RUN pip3 install torchsummary requests opencv-python

# jupyter
WORKDIR ${HOME}
RUN jupyter-lab --generate-config
RUN sed -i '/c.ServerApp.notebook_dir/c\c.ServerApp.notebook_dir = "'"${NOTEBOOKS}"'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.allow_root/c\c.ServerApp.allow_root = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.ip/c\c.ServerApp.ip = "'"0.0.0.0"'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.open_browser/c\c.ServerApp.open_browser = False' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.quit_button/c\c.ServerApp.quit_button = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.token/c\c.ServerApp.token = "'""'"' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.terminado_settings/c\c.ServerApp.terminado_settings = {"'"shell_command"'":["'"zsh"'"]}' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.trust_xheaders/c\c.ServerApp.trust_xheaders = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.disable_check_xsrf/c\c.ServerApp.disable_check_xsrf = False' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.allow_remote_access/c\c.ServerApp.allow_remote_access = True' ~/.jupyter/jupyter_lab_config.py && \
    sed -i '/c.ServerApp.allow_origin/c\c.ServerApp.allow_origin = "'"*"'"' ~/.jupyter/jupyter_lab_config.py && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager

EXPOSE 8888

# fix warning jupyter
RUN conda install -n torch "nbconvert=5.6.1"

# apex
RUN git clone https://github.com/NVIDIA/apex ${HOME}/apex
RUN echo "pip install -v --disable-pip-version-check --no-cache-dir --global-option=\"--cpp_ext\" --global-option=\"--cuda_ext\" ${HOME}/apex" >> ${HOME}/apex.sh

# link folder paperspace
RUN echo "ln -s /notebooks ~/" >> ${HOME}/link.sh

# fix zsh paperspace
RUN sed -i 's/source $ZSH/ZSH_DISABLE_COMPFIX=true\nsource $ZSH/' ${HOME}/.zshrc

# WORKDIR ${NOTEBOOKS}

CMD ["jupyter", "lab"]
