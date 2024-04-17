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
}

configure() {
  scheduler_config_file="/conf/fedora_openqa_scheduler.toml"
  if [ ! -f "$scheduler_config_file" ]; then
      echo "Missing $scheduler_config_file"
      exit
  fi

  # each queue needs a unique uuid
  new_uuid=$(uuidgen)
  touch "/fedora-messaging-logs/$new_uuid.log"

  # editing the config_file directly, not the symlink since editing the symlink will break it
  # add the unique queue id to the config
  sed -i "/^\[queues\.[0-9a-f-]\{36\}\]/s/\[queues\.[0-9a-f-]\{36\}\]/\[queues\.$new_uuid\]/" "$scheduler_config_file";
  sed -i "/^queue = \"[0-9a-f-]\{36\}\"/s/queue = \"[0-9a-f-]\{36\}\"/queue = \"$new_uuid\"/" "$scheduler_config_file";
  # add the unique log file
  sed -i "s|^filename =.*$|filename = \"/fedora-messaging-logs/$new_uuid.log\"|" "$scheduler_config_file";

  scheduler_symlink="/venv/etc/fedora_openqa_scheduler.toml"
  ln -s "$scheduler_config_file" $scheduler_symlink

  client_config_file="/conf/client.conf"
  if [ ! -f "$client_config_file" ]; then
      echo "Missing $client_config_file"
      exit
  fi

  client_symlink="/etc/openqa/client.conf"
  ln -s "$client_config_file" $client_symlink
}

get_fedora_openqa

# Clean up log files. Always keep the three most recent log files.
# Delete the remaining log files if they are older than a week
# This is needed because openqa-consumer will restart itself on error and create a log file each time.
rm -rf $(ls -t /fedora-messaging-logs | tail -n +4 | while read file; do find /fedora-messaging-logs -name "$file" -type f -mtime +7 -exec ls {} \;; done)

mkdir -p /venv/etc/ /etc/openqa/
configure
source /venv/bin/activate

if [[ "$USE_HTTPS" == "false" ]] || [[ "$USE_HTTPS" == "no" ]]; then
  schedule_path="/fedora-openqa/src/fedora_openqa/schedule.py"
  sed -i 's/client = OpenQA_Client(openqa_hostname)/client = OpenQA_Client(openqa_hostname, scheme='"'"'http'"'"')/' $schedule_path
fi

pip install "$fedora_openqa_dir"
/venv/bin/fedora-messaging --conf "$scheduler_symlink" consume

cleanup