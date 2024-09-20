# Load jarvice_mpi image as JARVICE_MPI
FROM us-docker.pkg.dev/jarvice/images/jarvice_mpi:4.1 as JARVICE_MPI

# Multistage to optimise, as image does not need to contain jarvice_mpi 
# components, these are side loaded during job containers init.
FROM ubuntu:22.04 as buffer_mpi
# Grab jarvice_mpi from JARVICE_MPI
COPY --from=JARVICE_MPI /opt/JARVICE /opt/JARVICE
# Install needed dependencies to download and build Intel MPI Benchmark
RUN apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gcc g++ git make bash; apt-get clean;
# Build IMB-MPI1 and osu which is enough for basic testing
RUN bash -c 'git clone https://github.com/intel/mpi-benchmarks.git; cd mpi-benchmarks; git checkout tags/IMB-v2019.6; \
    source /opt/JARVICE/jarvice_mpi.sh; sed -i 's/mpiicc/mpicc/' src_cpp/Makefile; \
    sed -i 's/mpiicpc/mpicxx/' src_cpp/Makefile; make IMB-MPI1;'
RUN bash -c 'wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.9.tar.gz; \
    tar xvzf osu-micro-benchmarks-5.9.tar.gz; cd osu-micro-benchmarks-5.9; source /opt/JARVICE/jarvice_mpi.sh; \
    ./configure CC=mpicc CXX=mpicxx --prefix=/osu/; make && make install;'

# Grab ffmpeg
FROM ubuntu:22.04 AS download_extract_ffmpeg
RUN apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install tar xz-utils wget -y;
RUN wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz;
RUN tar xvJf ffmpeg-release-amd64-static.tar.xz;
RUN cp ffmpeg-*/ffmpeg /usr/bin/ffmpeg;


# Create final image from Ubuntu
FROM ubuntu:22.04

# Install Nimbix desktop environment and gimp
RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install ca-certificates curl wget software-properties-common gimp --no-install-recommends && \
    curl -H 'Cache-Control: no-cache' \
        https://raw.githubusercontent.com/nimbix/jarvice-desktop/master/install-nimbix.sh \
        | bash

# Grab MPI benchmarks binaries built before using jarvice-mpi
COPY --from=download_extract_ffmpeg /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=buffer_mpi /mpi-benchmarks/IMB-MPI1 /IMB-MPI1
COPY --from=buffer_mpi /osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bw /osu_bw
COPY --from=buffer_mpi /osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency /osu_latency

# Integrate AppDef file
COPY NAE/AppDef.json /etc/NAE/AppDef.json
COPY ./NAE/screenshot.png /etc/NAE/screenshot.png

RUN mkdir -p /etc/NAE && touch /etc/NAE/AppDef.json
