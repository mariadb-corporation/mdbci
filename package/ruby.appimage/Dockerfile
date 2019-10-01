# Beware: only meant for use to build ruby appimages

FROM ubuntu:12.04 as ruby-appimage-builder

MAINTAINER "Andrey Vasilyev <andrey.vasilyev@fruct.org>"

ARG BUILD_JOBS=1
ARG RUBY_VERSION=2.6.3
ARG RUBY_INSTALL_VERSION=0.7.0

# Please update the ENTRYPOINT if changing the WORKSPACE variable
ENV DEBIAN_FRONTEND=noninteractive \
        DOCKER_BUILD=1 \
        RUBY_DIR=/build/ruby-dir \
        WORKSPACE=/build

RUN apt-get update && \
        apt-get install -y apt-transport-https software-properties-common python-software-properties

# Install and configure GCC 9 to build ruby and packages
# Inspiried by https://gist.github.com/application2000/73fd6f4bf1be6600a2cf9f56315a2d91
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
        apt-get update && \
        apt-get install -y \
        build-essential \
        g++-9 \
        g++-9 \
        curl \
        wget \
        sudo \
        vim && \
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 --slave /usr/bin/g++ g++ /usr/bin/g++-9 && \
        wget -O ruby-install-$RUBY_INSTALL_VERSION.tar.gz https://github.com/postmodern/ruby-install/archive/v$RUBY_INSTALL_VERSION.tar.gz && \
        tar -xzvf ruby-install-$RUBY_INSTALL_VERSION.tar.gz && \
        cd ruby-install-$RUBY_INSTALL_VERSION && \
        make install && \
        install -m 0755 -d $WORKSPACE && \
        ruby-install --cleanup --jobs $BULID_JOBS --prefix $RUBY_DIR/usr ruby $RUBY_VERSION -- --disable-install-doc --disable-debug --disable-dependency-tracking --enable-shared --enable-load-relative

# Install and configure the Rust compilation toolchain
ENV RUSTUP_HOME=/opt/rustup \
        PATH="/opt/cargo/bin:${PATH}" \
        WRAPPER_BUILD_DIR="${WORPSPACE}/ruby-exec-wrapper"

RUN wget https://sh.rustup.rs -O /tmp/install-rust.sh && \
        sh /tmp/install-rust.sh -y --no-modify-path && \
        mv /root/.cargo/ /opt/cargo

# Build the appimage wrapper
COPY ruby-exec-wrapper $WRAPPER_BUILD_DIR
WORKDIR $WRAPPER_BUILD_DIR
RUN cargo build --release && \
        cp target/release/ruby-appimage-wrapper $RUBY_DIR/usr/bin/

# Put gen_appimage.sh script into the root
COPY gen_appimage.sh $WORKSPACE

# Make the file executable
RUN chmod +x $WORKSPACE/gen_appimage.sh

# Allow to run sudo without password for all users
# Create seveal users for common UIDs (need to fix it in the future)
RUN echo "ALL ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
        groupadd -g 1000 group0 && \
        useradd -u 1000 -g 1000 user0 && \
        groupadd -g 1001 group1 && \
        useradd -u 1001 -g 1001 user1 && \
        groupadd -g 1002 group2 && \
        useradd -u 1002 -g 1002 user2 && \
        groupadd -g 1003 group3 && \
        useradd -u 1003 -g 1003 user3 && \
        groupadd -g 1004 group4 && \
        useradd -u 1004 -g 1004 user4

ENTRYPOINT ["/build/gen_appimage.sh"]
