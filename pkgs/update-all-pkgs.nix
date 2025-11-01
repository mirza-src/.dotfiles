{

  nix-update,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "update-all-pkgs";

  runtimeInputs = [
    nix-update
  ];

  text = ''
    # Function to convert a string to CamelCase using sed
    toCamelCase() {
      echo "$1" | sed -E 's/-([a-z])/\U\1/g'
    }

    # Log camelCase for every *.nix file recursively in the specified directory
    cd "''${1:-.}"
    ignorelist="''${2:-}" # Pass ignorelist as the second argument

    find . -name '*.nix' ! -name 'default.nix' | while read -r file; do
      echo "Processing $file"

      filename=$(basename "$file")
      pkgName="''${filename%.nix}"
      dirPath="''${file%/*}"
      if [ "$dirPath" = "." ]; then
        pkgPath="$pkgName"
      else
        pkgPath="$(toCamelCase "$(echo "''${dirPath#./}" | tr '/' '.')").$pkgName"
      fi

      # Check if pkgPath is in ignorelist
      if [[ "$ignorelist" =~ $pkgPath ]]; then
        continue
      fi

      nix-update --override-filename "$file" "$pkgPath"
    done
  '';
}
