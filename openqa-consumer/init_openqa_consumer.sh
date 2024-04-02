#!/bin/bash

set -e
function cleanup() {
  kill $(ps aux | grep fedora-messaging | awk '{print $2}' | head -n 1)
  exit
}
trap cleanup SIGTERM SIGINT

function get_fedora_openqa() {
  fedora_openqa_dir='/fedora-openqa'
  if [ ! -e "$fedora_openqa_dir/fedora-openqa.py" ]; then
    git clone https://pagure.io/fedora-qa/fedora_openqa.git "$fedora_openqa_dir"
    git config --global --add safe.directory /fedora_openqa
  else
    # Update any changes to the fedora tests scheduler if available
    git -C "$fedora_openqa_dir" pull || true
  fi

  # temporarily for development purposes just use scheme='http'
  schedule_path="/fedora-openqa/src/fedora_openqa/schedule.py"
  if [ -f "$schedule_path" ]; then
    sed -i 's/client = OpenQA_Client(openqa_hostname)/client = OpenQA_Client(openqa_hostname, scheme='"'"'http'"'"')/' $schedule_path
  fi
}

configure() {
  config_file="/conf/fedora_openqa_scheduler.toml"
  if [ ! -f "$config_file" ]; then
      echo "Missing $config_file"
      exit
  fi

  # each queue needs a unique uuid
  new_uuid=$(uuidgen)
  touch "/fedora-messaging-logs/$new_uuid.log"

  # editing the config_file directly, not the symlink since editing the symlink will break it
  sed -i "/^\[queues\.[0-9a-f-]\{36\}\]/s/\[queues\.[0-9a-f-]\{36\}\]/\[queues\.$new_uuid\]/" "$config_file";
  sed -i "/^queue = \"[0-9a-f-]\{36\}\"/s/queue = \"[0-9a-f-]\{36\}\"/queue = \"$new_uuid\"/" "$config_file";
  sed -i "s|^filename =.*$|filename = \"/fedora-messaging-logs/$new_uuid.log\"|" "$config_file";

  mkdir -p /venv/etc/
  symlink="venv/etc/fedora_openqa_scheduler.toml"
  ln -s "$config_file" $symlink

  config_file="/conf/client.conf"
  if [ ! -f "$config_file" ]; then
      echo "Missing $config_file"
      exit
  fi
  mkdir -p /etc/openqa/
  symlink_client="/etc/openqa/client.conf"
  ln -s "$config_file" $symlink_client
}

get_fedora_openqa
rm -rf /fedora-messaging-logs/*

configure

source /venv/bin/activate
pip install "$fedora_openqa_dir"
/venv/bin/fedora-messaging --conf "$symlink" consume

cleanup