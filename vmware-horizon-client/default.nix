{
  stdenv,
  lib,
  pkgs,
  buildFHSEnv,
  copyDesktopItems,
  fetchurl,
  gsettings-desktop-schemas,
  makeDesktopItem,
  makeWrapper,
  opensc,
  writeTextDir,
  configText ? "",
}:
let
  version = "2506";

  sysArch =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      "x64"
    else
      throw "Unsupported system: ${stdenv.hostPlatform.system}";

  mainProgram = "horizon-client";

  vmwareHorizonClientFiles = stdenv.mkDerivation {
    pname = "vmware-horizon-files";
    inherit version;
    src = fetchurl {
      url = "https://download3.omnissa.com/software/CART26FQ2_LIN_2506_TARBALL/Omnissa-Horizon-Client-Linux-2506-8.16.0-16536624989.tar.gz";
      sha256 = "5515e79188e2605ced5a95c3a3829865b567be5d7a8de00a57455f7b5b2ae392";
    };
    installPhase = ''
      mkdir ext
      find ${sysArch} -type f -print0 | xargs -0n1 tar -Cext --strip-components=1 -xf

      chmod -R u+w ext/usr/lib
      mv ext/usr $out
      cp -r ext/${sysArch}/include $out/
      cp -r ext/${sysArch}/lib $out/

      # Remove bundled libraries that conflict with system libraries
      rm -f "$out/lib/vmware/gcc/libstdc++.so.6"
      rm -f "$out/lib/vmware/libpng16.so.16"

      # Set up opensc for smartcard support
      mkdir -p $out/lib/vmware/view/pkcs11
      ln -s ${opensc}/lib/pkcs11/opensc-pkcs11.so $out/lib/vmware/view/pkcs11/libopenscpkcs11.so
    '';
  };

  vmwareFHSUserEnv =
    pname:
    buildFHSEnv {
      inherit pname version;

      # Create a wrapper script that sets environment and runs the binary
      runScript = pkgs.writeScript "${pname}-wrapper" ''
        #!${pkgs.bash}/bin/bash
        export GTK_THEME=Adwaita
        export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:$XDG_DATA_DIRS"
        exec ${vmwareHorizonClientFiles}/bin/${pname} "$@"
      '';

      targetPkgs =
        pkgs: with pkgs; [
          at-spi2-atk
          atk
          cairo
          dbus
          file
          fontconfig
          freetype
          gdk-pixbuf
          glib
          gtk2
          gtk3-x11
          harfbuzz
          liberation_ttf
          libjpeg
          libpng
          libpulseaudio
          libtiff
          libudev0-shim
          libuuid
          libv4l
          libxml2
          pango
          pcsclite
          pixman
          udev
          vmwareHorizonClientFiles
          xorg.libX11
          xorg.libXau
          xorg.libXcursor
          xorg.libXext
          xorg.libXi
          xorg.libXinerama
          xorg.libxkbfile
          xorg.libXrandr
          xorg.libXrender
          xorg.libXScrnSaver
          xorg.libXtst
          zlib

          (writeTextDir "etc/vmware/config" configText)
        ];
    };

  desktopItem = makeDesktopItem {
    name = "horizon-client";
    desktopName = "VMware Horizon Client";
    icon = "${vmwareHorizonClientFiles}/share/icons/horizon-client.png";
    exec = "${vmwareFHSUserEnv mainProgram}/bin/${mainProgram} %u";
    mimeTypes = [ "x-scheme-handler/horizon-client" ];
  };

in
stdenv.mkDerivation {
  pname = "vmware-horizon-client";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ln -s ${vmwareFHSUserEnv "horizon-client"}/bin/horizon-client $out/bin/
    ln -s ${vmwareFHSUserEnv "vmware-usbarbitrator"}/bin/vmware-usbarbitrator $out/bin/
    runHook postInstall
  '';

  unwrapped = vmwareHorizonClientFiles;

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    inherit mainProgram;
    description = "Allows you to connect to your VMware Horizon virtual desktop";
    homepage = "https://www.vmware.com/go/viewclients";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
