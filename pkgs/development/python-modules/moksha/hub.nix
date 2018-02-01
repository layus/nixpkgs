{ buildPythonPackage, pkgs
, mock
, moksha_common
, nose
, pyzmq
, twisted
, txWS
, txZMQ
, websocket-client
}:

buildPythonPackage rec {
    pname = "moksha.hub";
    version = "1.0.0";

    src = pkgs.fetchurl {
      url = "mirror://pypi/m/${pname}/${pname}-${version}.tar.gz";
      sha256 = "187lymb9j8c5wfvy451bkjfj4cd8xw4i0y87jx3qvckjjb9bfd2p";
    };

    propagatedBuildInputs = [
      moksha_common
      twisted
      pyzmq
      txZMQ
      txWS
    ];

    buildInputs = [
      nose
      mock
      pyzmq
      websocket-client
    ];

}

