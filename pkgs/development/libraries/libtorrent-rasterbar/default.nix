{ callPackage, ... } @ args:

callPackage ./generic.nix (args // {
  version = "1.1.2";
  sha256 = "13hi8ylaigdhwprmy87c3h24h56lwr7gs054rggjc89mdimnad10";
})
