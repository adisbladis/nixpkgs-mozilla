{ geckoSrc ? null
, lib
, pkgs
}:

let

  inherit (lib) updateFromGitHub;
  inherit (pkgs) fetchFromGitHub pythonFull which autoconf213
    perl unzip zip gnumake yasm pkgconfig xlibs gnome2 pango dbus dbus_glib
    alsaLib libpulseaudio gstreamer gst_plugins_base gtk3 glib
    gobjectIntrospection git mercurial openssl cmake;
  inherit (pkgs) valgrind gdb rr;
  inherit (pkgs.pythonPackages) setuptools;
  inherit (pkgs.stdenv) mkDerivation;
  inherit (pkgs.lib) importJSON optionals inNixShell;
  inherit (pkgs.rust) rustc cargo;

  # Gecko sources are huge, we do not want to import them in the nix-store when
  # we use this expression for making a build environment.
  src =
    if inNixShell then
      null
    else if geckoSrc == null then
      fetchFromGitHub (importJSON ./source.json)
    else
      geckoSrc;

  version = "HEAD"; # XXX: builtins.readFile "${src}/browser/config/version.txt";

in mkDerivation {
  name = "gecko-dev-${version}";
  inherit src;
  buildInputs = [

    # Expected by "mach"
    pythonFull setuptools which autoconf213

    # Expected by the configure script
    perl unzip zip gnumake yasm pkgconfig

    xlibs.libICE xlibs.libSM xlibs.libX11 xlibs.libXau xlibs.libxcb
    xlibs.libXdmcp xlibs.libXext xlibs.libXt xlibs.printproto
    xlibs.renderproto xlibs.xextproto xlibs.xproto xlibs.libXcomposite
    xlibs.compositeproto xlibs.libXfixes xlibs.fixesproto
    xlibs.damageproto xlibs.libXdamage xlibs.libXrender xlibs.kbproto

    gnome2.libart_lgpl gnome2.libbonobo gnome2.libbonoboui
    gnome2.libgnome gnome2.libgnomecanvas gnome2.libgnomeui
    gnome2.libIDL

    pango

    dbus dbus_glib

    alsaLib libpulseaudio
    gstreamer gst_plugins_base

    gtk3 glib gobjectIntrospection

    rustc cargo

    # "mach vendor rust" wants to list modified files by using the vcs.
    git mercurial

    # needed for compiling cargo-vendor and its dependencies
    openssl cmake

  ] ++ optionals inNixShell [
    valgrind gdb rr
  ];

  # Useful for debugging this Nix expression.
  tracePhases = true;

  configurePhase = ''
    export MOZBUILD_STATE_PATH=$(pwd)/.mozbuild
    export MOZ_CONFIG=$(pwd)/.mozconfig
    export builddir=$(pwd)/builddir

    mkdir -p $MOZBUILD_STATE_PATH $builddir
    echo > $MOZ_CONFIG "
    . $src/build/mozconfig.common

    mk_add_options MOZ_OBJDIR=$builddir
    mk_add_options AUTOCONF=${autoconf213}/bin/autoconf
    ac_add_options --prefix=$out
    ac_add_options --enable-application=browser
    ac_add_options --enable-official-branding
    export AUTOCONF=${autoconf213}/bin/autoconf
    "
  '';

  AUTOCONF = "${autoconf213}/bin/autoconf";

  buildPhase = ''
    cd $builddir
    $src/mach build
  '';

  installPhase = ''
    cd $builddir
    $src/mach install
  '';

  # TODO: are there tests we would like to run? or should we package them separately?
  doCheck = false;
  doInstallCheck = false;

  shellHook = ''
    export MOZBUILD_STATE_PATH=$PWD/.mozbuild
  '';
  passthru.updateScript = updateFromGitHub {
    owner = "mozilla";
    repo = "gecko-dev";
    branch = "master";
    path = "pkgs/gecko/source.json";
  };
}
