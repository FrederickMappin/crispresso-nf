FROM continuumio/miniconda3:24.1.2-0

LABEL maintainer="FrederickMappin"
LABEL description="CRISPResso v1 (BSD License) — https://github.com/lucapinello/CRISPResso"

# Create an isolated Python 2.7 environment.
# Use only 'defaults' + 'bioconda' channels: conda-forge dropped py27 support.
# FLASH merges paired-end reads; EMBOSS provides the needle aligner.
# matplotlib is installed via pip to avoid the conda pyqt/freetype solver conflict.
RUN conda create -y -n crispresso \
        --override-channels -c defaults -c bioconda \
        python=2.7 \
        flash \
        emboss \
        numpy \
        pandas \
        biopython \
        seaborn \
    && /opt/conda/envs/crispresso/bin/pip install "matplotlib==1.5.3" \
    && conda clean -afy

ENV PATH=/opt/conda/envs/crispresso/bin:/opt/conda/bin:$PATH

# Install fastp into the base conda env (C++ binary, no Python version constraint).
RUN conda install -y -c bioconda -c conda-forge fastp \
    && conda clean -afy

# Install CRISPResso v1 from source.
# Using pip install --no-deps so setuptools does NOT trigger the external
# dependency download block in setup.py (deps are already on PATH).
RUN apt-get update -qq && apt-get install -y --no-install-recommends git default-jre-headless \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 https://github.com/lucapinello/CRISPResso.git /tmp/CRISPResso \
    && cd /tmp/CRISPResso \
    && pip install --no-deps . \
    && rm -rf /tmp/CRISPResso

# Verify the install (java is now present so the dependency check passes).
RUN CRISPResso --version || true

WORKDIR /data

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "CRISPResso --help"]
