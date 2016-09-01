{ fetchurl, fetchFromGitHub, buildDotnetPackage, dotnetPackages, mono, z3}:

let boogie = buildDotnetPackage rec {
  baseName = "boogie";
  version = "undefined";

  xBuildFiles = [ "Source/Boogie.sln" ];

  buildInputs = with dotnetPackages; [ NUnit ];

  dllFiles = [ "Binaries/*.dll" ]; # Hey, vim */
  outputFiles = [ "*" ];

  src = fetchFromGitHub {
    owner = "boogie-org";
    repo = "boogie";
    rev = "master";
    sha256 = "0a0lhn3nizk509lgbk8wf3bqxq7nliiz3nn1ghw4dahq0y574ysz";
  };
};

in buildDotnetPackage rec {
  baseName = "dafny";
  version = "1.9.8";

  inherit boogie;

  preUnpack = ''
    ln -s ${boogie}/lib/dotnet/boogie boogie
  '';

  preBuild = ''
    ln -s ${z3} Binaries/z3
    cd .. # get out of unpacked dir.
  '';
    
  postFixup = ''
    mkdir -p $out/bin
    rm -f $out/bin/*
    mv $out/lib/dotnet/dafny/dafny $out/bin
    sed -i $out/bin/dafny \
      -e 's,MONO=.*,MONO=${mono}/bin/mono,' \
      -e "s,DAFNY=.*,DAFNY=$out/lib/dotnet/dafny/Dafny.exe," \
      -e "/MONO.*DAFNY.*@/ s,^,export PATH=\"${mono}/bin:\$PATH\"\n,"
  '';
  xBuildFiles = [ "dafny-1.9.8/Source/Dafny.sln" ];
  xBuildFlags = [ ];

  buildInputs = [ boogie ];

  outputFiles = [ "dafny-1.9.8/Binaries/*" ]; # Hey, vim */
  outputBinaries = [ ];

  src = fetchurl {
    url = "https://github.com/Microsoft/dafny/archive/v${version}.tar.gz";
    sha256 = "0n4pk4cv7d2zsn4xmyjlxvpfl9avq79r06c7kzmrng24p3k4qj6s";
  };
}

