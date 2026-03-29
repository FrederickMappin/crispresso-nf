FROM continuumio/miniconda3:24.1.2-0

LABEL maintainer="FrederickMappin"
LABEL description="CRISPResso v1 (BSD License) — https://github.com/lucapinello/CRISPResso"

# Create an isolated Python 2.7 environment with all system-level deps.
# FLASH merges paired-end reads; EMBOSS provides the needle aligner.
# Pre-installing them means setup.py skips its own auto-download logic.
RUN conda create -y -n crispresso -c bioconda -c conda-forge \
        python=2.7 \
        flash \
        emboss \
        numpy \
        pandas \
        "matplotlib<2" \
        biopython \
        seaborn \
    && conda clean -afy

ENV PATH=/opt/conda/envs/crispresso/bin:$PATH

# Install CRISPResso v1 from source.
# Using pip install --no-deps so setuptools does NOT trigger the external
# dependency download block in setup.py (deps are already on PATH).
RUN apt-get update -qq && apt-get install -y --no-install-recommends git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 https://github.com/lucapinello/CRISPResso.git /tmp/CRISPResso \
    && cd /tmp/CRISPResso \
    && pip install --no-deps . \
    && rm -rf /tmp/CRISPResso

RUN CRISPResso --version

WORKDIR /data

ENTRYPOINT ["CRISPResso"]
CMD ["--help"]
