# Beware: only meant for use to build ruby appimages

FROM centos:7 as ruby-appimage-builder

MAINTAINER "Andrey Vasilyev <andrey.vasilyev@fruct.org>"

ARG IMAGE_DATE=2021-07-23

ARG BUILD_JOBS=1
ARG RUBY_VERSION=3.0.2
ARG RUBY_INSTALL_VERSION=0.8.2

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

# Download the AppImage functions
RUN wget -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O "$WORKSPACE/functions.sh"

# Make the file executable
RUN chmod 755 $WORKSPACE/gen_appimage.sh $WORKSPACE/scl_wrapper.sh

# Allow to run sudo without password for all users
# Create a builder user that will govern the appimage build process
# Grant all access to WORKSPACE directory to the builder
RUN echo "ALL ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
  groupadd -g 1000 group0 && \
  useradd -u 1000 -g 1000 builder && \
  chown -R builder: "$WORKSPACE"

USER builder

ENTRYPOINT ["/build/scl_wrapper.sh"]
