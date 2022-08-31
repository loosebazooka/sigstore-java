#!/bin/bash
set -e
set -x
RELEASE_INFO=$(curl -s -H "Accept: application/vnd.github+json" https://api.github.com/repos/loosebazooka/sigstore-java/releases/latest)
RELEASE_DIR="release_$(echo $RELEASE_INFO | jq -r '.tag_name')"

if [ -d $RELEASE_DIR ]; then
  echo "Directory '$RELEASE_DIR' already exists"
  exit 1
fi

ASSET_URLS=$(echo $RELEASE_INFO | jq -r '.assets[].browser_download_url')
for i in ${ASSET_URLS[@]}
do
  wget -q --directory-prefix $RELEASE_DIR "$i"
done
cd $RELEASE_DIR

mv pom-default.xml sigstore-java-0.1.0.pom
mv attestation.intoto.jsonl sigstore-java-0.1.0.intoto.jsonl
rm module.json

# cosign sign all the files
for file in *; do
  COSIGN_EXPERIMENTAL=1 cosign sign-blob --yes $file --output-signature=$file.sig --output-certificate=$file.pem
done
# then gpg sign all the files (including sigstore files)
# this command uses gpgs default password acceptance mechansim accept a passcode
for file in *; do
  gpg --batch --detach-sign --armor -o $file.asc $file
done

POM=$(ls *.pom)
BUNDLE_NAME=${POM%.pom}-bundle.jar
jar -cvf "${BUNDLE_NAME}" *
