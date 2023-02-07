#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"
cd ..
BS_ROOT="$(pwd)"

BLOCK_SCOUT_WEB="$BS_ROOT/apps/block_scout_web/assets"
EXPLORER_WEB="$BS_ROOT/apps/explorer"

DB_DATA_DIR="$SCRIPT_DIR/db"
DB_DOCKER_NAME='bs_postgres'
DB_USER=tolar
DB_PASS=tolar
DB_PORT=5432


Help() {
   echo "options:"
   echo "h     Print this Help."
   echo "a     Rebuild all."
   echo "c     Clean and rebuild all."
   echo
}

CleanAll() {
  echo "Cleaning all"

  cd "$BS_ROOT"
  mix clean
  mix clean --deps

  rm -rf "$BS_ROOT/_build"
  rm -rf "$BS_ROOT/deps"

  rm -rf "$BLOCK_SCOUT_WEB/node_modules"
  rm -rf "$EXPLORER_WEB/node_modules"

  docker rm --force "$DB_DOCKER_NAME" > /dev/null 2>&1
  sleep 2
  echo "For removing database directory root access is needed"
  sudo rm -rf "$DB_DATA_DIR"
  rm -rf "$BS_ROOT/logs"
}

LoadEnvVariables() {
  echo "Loading environment variables"

  export $(grep -v '^#' "$SCRIPT_DIR/local_dev.env" | xargs -d '\n')
  DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost:$DB_PORT/blockscout?ssl=false"
}

RunDepService() {
  echo "Running dependencies services"

  mkdir -p "$DB_DATA_DIR"
  if [ ! "$(docker ps -qf name=$DB_DOCKER_NAME)" ]; then
      if [ "$(docker ps -aq -f status=exited -f name=$DB_DOCKER_NAME)" ]; then
          docker rm --force "$DB_DOCKER_NAME" > /dev/null 2>&1
      fi

      docker run -d --name "$DB_DOCKER_NAME" -p "$DB_PORT:$DB_PORT" -e POSTGRES_USER="$DB_USER" \
        -e POSTGRES_PASSWORD="$DB_PASS" -e PGDATA=/data/postgres -v "$DB_DATA_DIR":/data/postgres postgres:15.1-alpine
      sleep 3
  fi

  CONTRACT_VERIFIER_PID="$(ps -ef | grep -E "(^|\s)smart-contract-verifier-http($|\s)" | awk '{print $2}')"
  if ! ps -p "$CONTRACT_VERIFIER_PID" > /dev/null 2>&1
  then
    smart-contract-verifier-http &>/dev/null &
    sleep 3
  fi
}

SetupSsl() {
  echo "Setting up SSL"

  # Generate selfsigned certificates
  if ! test -f "$BS_ROOT/_build/dev/lib/block_scout_web/priv/cert/selfsigned.pem"
  then
    cd "$BLOCK_SCOUT_WEB"
    mix phx.gen.cert blockscout blockscout.local
  fi

  # Append entries to etc hosts
  HOSTS_ENTRY='\n127.0.0.1       localhost blockscout blockscout.local\n255.255.255.255 broadcasthost\n::1             localhost blockscout blockscout.local\n'
  HOSTS_PATH='/etc/hosts'
  if ! grep -Pzl "$HOSTS_ENTRY" $HOSTS_PATH > /dev/null 2>&1
  then
    echo "For editing $HOSTS_PATH root access is needed"
    echo -e "$HOSTS_ENTRY" | sudo tee -a "$HOSTS_PATH"
  fi
}

BuildDependencies() {
  echo "Building dependencies"

  cd "$BS_ROOT"
  mix do deps.get, local.rebar --force, deps.compile
}

Build() {
  echo "Building"
  RunDepService

  mix phx.digest.clean
  mix compile
  mix do ecto.create, ecto.migrate
}

BuildStaticAssets() {
  echo "Building static assets"

  cd "$BLOCK_SCOUT_WEB"
  npm install
  "$BLOCK_SCOUT_WEB/node_modules/webpack/bin/webpack.js" --mode development

  cd "$EXPLORER_WEB"
  npm install

  cd "$BS_ROOT"
  mix phx.digest
}

Run() {
  cd "$BS_ROOT"
  echo "Running web at http://localhost:4000/"
  mix phx.server
}

BuildAll() {
  echo "Building all"

  LoadEnvVariables
  BuildDependencies
  Build
  BuildStaticAssets

  SetupSsl
  Run
}

while getopts "hac" option; do
   case $option in
      h) Help
         exit;;

      a) BuildAll
         exit;;

      c) CleanAll
         BuildAll
         exit;;

     \?) echo "Invalid option"
         exit;;
   esac
done


LoadEnvVariables
Build
Run
