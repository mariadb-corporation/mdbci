# Beware: only meant for use to build ruby appimages

FROM centos:7 as ruby-appimage-builder

MAINTAINER "Andrey Vasilyev <andrey.vasilyev@fruct.org>"

ARG IMAGE_DATE=2020-12-05

ARG BUILD_JOBS=1
ARG RUBY_VERSION=3.0.1
ARG RUBY_INSTALL_VERSION=0.8.1

# Please update the ENTRYPOINT if changing the WORKSPACE variable
ENV DOCKER_BUILD=1 \
  RUBY_DIR=/build/ruby-dir \
  WORKSPACE=/build

RUN yum install -y \
  centos-release-scl

RUN yum install -y \
  bzip2 \
  devtoolset-9 \
  cmake \
  curl \
  file \
  wget \
  sudo \
  patch \
  vim && \
  wget -O ruby-install-$RUBY_INSTALL_VERSION.tar.gz https://github.com/postmodern/ruby-install/archive/v$RUBY_INSTALL_VERSION.tar.gz && \
  tar -xzvf ruby-install-$RUBY_INSTALL_VERSION.tar.gz && \
  cd ruby-install-$RUBY_INSTALL_VERSION && \
  make install && \
  install -m 0755 -d $WORKSPACE && \
  scl enable devtoolset-9 "ruby-install --cleanup --jobs $BUILD_JOBS --prefix $RUBY_DIR/usr ruby $RUBY_VERSION -- --disable-install-doc --disable-debug --disable-dependency-tracking --enable-shared --enable-load-relative"

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
RUN scl enable devtoolset-9 'cargo build --release' && \
  cp target/release/ruby-appimage-wrapper $RUBY_DIR/usr/bin/

# Put gen_appimage.sh script into the root
WORKDIR $WORKSPACE
COPY gen_appimage.sh $WORKSPACE
COPY functions.sh $WORKSPACE
COPY scl_wrapper.sh $WORKSPACE

# Make the file executable
RUN chmod 755 $WORKSPACE/gen_appimage.sh $WORKSPACE/scl_wrapper.sh

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


ENTRYPOINT ["/build/scl_wrapper.sh"]
