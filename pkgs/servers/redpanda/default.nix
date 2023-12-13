{ lib
, newScope
, overrideCC
, fetchFromGitHub
, fetchgit
  # dependencies
, abseil-cpp_202206
, avro-cpp
, boost175
, bzip2
, fmt_8
, gtest
, icu
, llvmPackages_16
, lzma
, protobuf_21
, python3
, python310
, re2
, yaml-cpp
, zlib
, zstd
, cryptopp
, liburing
}:

lib.makeScope newScope (self: let inherit (self) callPackage; in {

  redpanda_version = "23.2.17";
  # see redpanda/cmake/dependencies.cmake
  seastar_version = "23.2.x";
  # 23.2.x is a branch; in nix we have to pin to a particular commit
  seastar_ref = "1e2ad26ac57c1130190f3f41237af0907aab17d8";

  redpanda-client = callPackage ./redpanda.nix { };

  redpanda-server = callPackage ./server.nix { };

  llvmPackages = llvmPackages_16;

  redpanda_src = fetchFromGitHub {
    owner = "redpanda-data";
    repo = "redpanda";
    rev = "v${self.redpanda_version}";
    hash = "sha256-oyPqXdnoh2i6EDa0IPowgXBlOk7mG8JYkXeb4XAxbm8=";
  };

  seastar = callPackage ./seastar.nix { };

  stdenv = self.llvmPackages.libcxxStdenv;
  #stdenv = overrideCC self.llvmPackages.libcxxStdenv (
  #  self.llvmPackages.libcxxStdenv.cc.override {
  #    inherit (self.llvmPackages) bintools;
  #  }
  #);

  boost = boost175.override {
    inherit (self) stdenv;
    enablePython = true;
    # Build fails with python 3.11, should be fixed in more recent boost versions
    python = python310.withPackages (ps: [ ps.jinja2 ]);
  };

  base64 = callPackage ./base64.nix { };

  hdr-histogram = callPackage ./hdr-histogram.nix { };

  avro-cpp = (avro-cpp.override { inherit (self) stdenv boost; }).overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs or [] ++ [ zlib icu bzip2 lzma zstd ];
  }); #callPackage ./avro-cpp.nix { };

  abseil-cpp = abseil-cpp_202206.override { inherit (self) stdenv; };
  yaml-cpp = yaml-cpp.override { inherit (self) stdenv; };
  fmt_8 = fmt_8.override { inherit (self) stdenv; };
  cryptopp = cryptopp.override { inherit (self) stdenv; };


  re2 = (re2.override {
    inherit (self) stdenv;
  }).overrideAttrs (oldAttrs: rec {
    # re2 needs to be < 2023-06-01
    version = "2023-03-01";
    src = fetchFromGitHub {
      owner = "google";
      repo = "re2";
      rev = version;
      hash = "sha256-T+P7qT8x5dXkLZAL8VjvqPD345sa6ALX1f5rflE0dwc=";
    };
  });

  protobuf = protobuf_21.override { inherit (self) stdenv abseil-cpp gtest; };
  gtest = gtest.override { inherit (self) stdenv; };

# c-ares
# gnutls
# hwloc
# libsystemtap
# libtasn1
liburing = (liburing.override { inherit (self) stdenv; }).overrideAttrs (oldAttrs: rec {
  pname = "liburing";
  version = "2.2";

  src = fetchgit {
    url    = "http://git.kernel.dk/${pname}";
    rev    = "liburing-${version}";
    sha256 = "sha256-M/jfxZ+5DmFvlAt8sbXrjBTPf2gLd9UyTNymtjD+55g=";
  };
});
# libxfs
# lksctp-tools
# lz4
# numactl
# openssl
# pkg-config
# python3
# ragel
# valgrind

  kafka-codegen-venv = python3.withPackages (ps: [
    ps.jinja2
    ps.jsonschema
  ]);

  rapidjson = callPackage ./rapidjson.nix { };
})
