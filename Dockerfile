# Dockerfile for the "Who Holds Government Debt?" REMARK
# (Yiran Emma Ma, Johns Hopkins University)
#
# Purpose
# -------
# Provide a self-contained Linux image in which `./reproduce.sh --all`
# runs successfully. The empirical Stata pipeline cannot run inside the
# container (Stata is proprietary); the script falls back to the
# committed `Code/empirical_debt_composition/results/*.txt` logs in that
# case, exactly as documented in README.md. The paper PDF is rebuilt from
# source in either case.
#
# Build (from the repo root):
#     docker build -t emma0502606:latest .
#
# Run (mount the repo and reproduce):
#     docker run --rm -v "$PWD":/workspace emma0502606:latest \
#         ./reproduce.sh --all
#
# Or just compile the paper:
#     docker run --rm -v "$PWD":/workspace emma0502606:latest \
#         ./reproduce.sh --docs
#
# Editor note: this Dockerfile is intentionally minimal so that
# `econ-ark/REMARK`'s `cli.py build docker` and `cli.py execute docker`
# can build and run it without bespoke setup.

FROM python:3.10-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# System dependencies
#   * git, make, perl, build-essential, fontconfig: general build tooling
#   * latexmk + texlive-* : same packages declared in binder/apt.txt,
#     extended with -extra and -bibtex-extra so econark template
#     packages and the bibliography style resolve.
#   * ca-certificates, curl: TLS for any pip fetch
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        make \
        perl \
        build-essential \
        fontconfig \
        latexmk \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-fonts-recommended \
        texlive-bibtex-extra \
        biber \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install Python dependencies first to maximise Docker layer cache hits.
# Mirror binder/requirements.txt (which mirrors pyproject.toml's
# [project.dependencies]).
COPY binder/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt \
    && pip install linearmodels>=6.0 pyreadstat>=1.2 \
    && rm /tmp/requirements.txt

COPY . /workspace/

# Make reproduce.sh executable in case the host filesystem stripped the bit.
RUN chmod +x reproduce.sh \
    && find reproduce -name '*.sh' -exec chmod +x {} +

# Default: run the full reproduction.
# This will (a) attempt the Stata empirical step, (b) detect Stata is not
# on PATH and skip with a clear message, falling back to committed logs,
# and (c) compile emma0502606.pdf via reproduce/reproduce_documents.sh.
CMD ["./reproduce.sh", "--all"]
