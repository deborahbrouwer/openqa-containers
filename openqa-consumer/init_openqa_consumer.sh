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
    pip install "$fedora_openqa_dir"
  else
    # Update any changes to the fedora tests scheduler if available
    git -C "$fedora_openqa_dir" pull || true
    pip install "$fedora_openqa_dir"
  fi

  # temporarily for development purposes just use scheme='http'
  schedule_path="/fedora_openqa/src/fedora_openqa/schedule.py"
  if [ -f "$schedule_path" ]; then
    sed -i 's/client = OpenQA_Client(openqa_hostname)/client = OpenQA_Client(openqa_hostname, scheme='"'"'http'"'"')/' $schedule_path
  fi
}

config_file="/conf/fedora_openqa_scheduler.toml"
if [ ! -f "$config_file" ]; then
    echo "Missing $config_file"
    exit
fi

new_uuid=$(uuidgen)
touch "/fedora-messaging-logs/$new_uuid.log"

sed -i "/^\[queues\.[0-9a-f-]\{36\}\]/s/\[queues\.[0-9a-f-]\{36\}\]/\[queues\.$new_uuid\]/" "$config_file";
sed -i "/^queue = \"[0-9a-f-]\{36\}\"/s/queue = \"[0-9a-f-]\{36\}\"/queue = \"$new_uuid\"/" "$config_file";
sed -i "s|^filename =.*$|filename = \"/fedora-messaging-logs/$new_uuid.log\"|" "$config_file";

python3 -m venv venv
source /venv/bin/activate
mkdir -p /venv/etc/

# Using the fedora-messaging certificates from dnf fedora-messaging, but running the pip version
pip install fedora-messaging requests

# editing the symlink directly breaks the symlink so don't do that
symlink="venv/etc/fedora_openqa_scheduler.toml"
ln -s "$config_file" $symlink

get_fedora_openqa
rm /fedora-messaging-logs/*

/venv/bin/fedora-messaging --conf "$symlink" consume

cleanup