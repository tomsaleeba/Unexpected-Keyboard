FROM ocaml/opam2:4.04

RUN sudo apt install -y android-sdk

RUN sudo apt install -y m4 gcc-multilib

# Android ndk
RUN curl -o /tmp/android-ndk.zip "http://dl.google.com/android/repository/android-ndk-r11c-linux-x86_64.zip"
RUN sudo unzip /tmp/android-ndk.zip -d /opt
ENV NDK_HOME /opt/android-ndk-r11c

RUN opam switch create 4.04.0+32bit
RUN opam install -y dune

WORKDIR ${HOME}/build

COPY libs/opam-cross-android libs/opam-cross-android
RUN opam repository add android -k local libs/opam-cross-android

run ANDROID_NDK="${NDK_HOME}" opam install -y conf-android-ndk-android

RUN ARCH=arm SUBARCH=armv7 SYSTEM=linux_eabi \
  CCARCH=arm TOOLCHAIN=arm-linux-androideabi-4.9 \
  TRIPLE=arm-linux-androideabi LEVEL=24 \
  STLVER=4.9 STLARCH=armeabi \
  opam install -y conf-android \
  && opam install -y ocaml-android

RUN opam install -y ocaml-android

ENV ANDROID_HOME /usr/lib/android-sdk/
ENV ANDROID_BUILD_TOOLS ${ANDROID_HOME}/build-tools/27.0.1
ENV ANDROID_PLATFORM ${ANDROID_HOME}/platforms/android-23
ENV NDK_PLATFORM ${NDK_HOME}/platforms/android-24/arch-arm

COPY --chown=opam:opam . .
