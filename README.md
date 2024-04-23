
## Table of Contents

- [About](#about)
  
- [The openqa-database](#The-openqa-database)
    - [Host Directories for database](#host-directories-for-database)
    - [Building openqa-database](#building-openqa-database)
    - [Run the openqa-database locally](#start-the-openqa-database-locally)
    - [Start the openqa-database as a service](#start-the-openqa-database-as-a-service)

- [The openqa-webserver](#The-openqa-webserver)
    - [Host Directories for Webserver](#host-directories-for-webserver)
    - [Web Configuration](#web-configuration)
    - [Building openqa-webserver](#building-openqa-webserver)
    - [Start the openqa-webserver locally](#start-the-openqa-webserver-locally)
    - [Start the openqa-webserver as a service](#start-the-openqa-webserver-as-a-service)
    - [Login](#login)
    - [Loading Tests](#loading-tests)
      
- [The openqa-reverse-proxy](#The-openqa-reverse-proxy)
    - [Generating certificates](#generating-certificates)
    - [Reverse Proxy Configuration](#reverse-proxy-configuration)
    - [Start the openqa-reverse-proxy as a service](#start-the-openqa-reverse-proxy-as-a-service)

- [The openqa-consumer](#The-openqa-consumer)  
    - [Host Directories for Consumer](#host-directories-for-consumer)
    - [Consumer Configuration](#consumer-configuration)
    - [Building openqa-consumer](#building-openqa-webserver)
    - [Start the consumer locally](#start-the-consumer-locally)
    - [Start the consumer as a service](#start-the-consumer-as-a-service)
    - [Scheduling Tests](#scheduling-tests)
- [The openqa-worker](#The-openqa-worker)
    - [Host Directories for Worker](#host-directories-for-worker)
    - [Worker Configuration](#worker-configuration)
    - [Building the openqa-worker](#building-the-openqa-worker)
    - [Start workers locally](#start-workers-locally)
    - [Start the openqa-worker service](#start-the-openqa-worker-service)

# About  
This repository contains scripts to build and run a containerized deployment of [openQA](https://github.com/os-autoinst).  The containers are specifically designed to leverage cloud resources and are customized to support [Fedora](https://fedoraproject.org/wiki/OpenQA) release and update testing. 


# The openqa-database

### Host Directories for database
 
* `data/`: The full database shared with the container host. Database logs are in `data/log`.  

### Building openqa-database
`/home/fedora/openqa-containers/openqa-database/build-database-image.sh`  

### Run the openqa-database locally
`/home/fedora/openqa-containers/openqa-database/start-openqa-database.sh`  
`/home/fedora/openqa-containers/openqa-database/stop-openqa-database.sh`  

### Start the openqa-database as a service
```
sudo cp /home/fedora/openqa-containers/openqa-database/openqa-database.service /etc/systemd/system/;
sudo cp /home/fedora/openqa-containers/openqa-database/start-openqa-database.sh /usr/bin/start-openqa-database.sh;
sudo cp /home/fedora/openqa-containers/openqa-database/stop-openqa-database.sh /usr/bin/stop-openqa-database.sh;
sudo systemctl daemon-reload;
sudo systemctl start openqa-database;
```

# The openqa-webserver  

The openqa-webserver container runs a backend web server on non-privileged port 8080.  

### Host Directories for Webserver
The openqa-webserver container shares these directories with its host:  

* `tests/`: The full [os-autoinst-distri-fedora](https://pagure.io/fedora-qa/os-autoinst-distri-fedora) repository.
* `testresults`
* `images`: screenshots
* `logs`: httpd access and error logs  
* `hdd/`: holds OS images for testing.
    * `hdd/fixed`:  Images in this subdir are exempt from cleanup.  Store images that are manually created through [createhdds](https://pagure.io/fedora-qa/createhdds) in this subdir.  
    > Note:  
    >   - Createhdds has to be run on a Fedora host machine.  
    >   - If the host machine is already virtualized as in a cloud instances, it must support nested virtualization, which you can check for by the presence of `/dev/kvm`
    >   - If copying the images generated by `createhdds` from another machine, keep them small by preserving sparse allocation. Don't use sftp or scp; instead, use:  
    >     ```
    >     rsync -avz --sparse fedora@171.1.1.1:<source dir> <dest>/hdd/fixed
    >     ```

  Host packages necessary to run createhdds:  
      `sudo dnf install -y python3-libguestfs  libvirt-devel virt-install fedfind vim git edk2-ovmf`  
      Helper script to create images for hdd directory:  
      `./run_createhdds.sh`
      
* `iso/`: holds iso files for testing.
    *  `iso/fixed`:  Images in this subdir are exempt from cleanup.  `cloudinit.iso` is stored here.  
  
### Web Configuration    
In the `openqa-webserver/conf` subdirectory copy `client.conf.template` to `client.conf` and fill in host and api keys/secrets.
```
cp /home/fedora/openqa-containers/openqa-webserver/conf/client.conf.template /home/fedora/openqa-containers/openqa-webserver/conf/client.conf;
```
### Building Openqa Webserver
`/home/fedora/openqa-containers/openqa-webserver/build-webserver-image.sh`   

### Start the openqa-webserver locally
`DETACHED=yes /home/fedora/openqa-containers/openqa-webserver/start-openqa-webserver.sh`  

### Start the openqa-webserver as a service

The webserver runs as `fedora` user so make sure that the user will survive closing the session:  
`sudo loginctl enable-linger fedora`  

Copy service files and scripts where systemd expects to find them:  
```
sudo cp /home/fedora/openqa-containers/openqa-webserver/openqa-webserver.service /etc/systemd/system/;
sudo cp /home/fedora/openqa-containers/openqa-webserver/start-openqa-webserver.sh /usr/bin/start-openqa-webserver.sh;
sudo systemctl daemon-reload;
sudo systemctl start openqa-webserver;
```
Verify:  
`journalctl -f`  
`curl localhost:8080`   
 Logs: `/home/fedora/openqa-containers/openqa-webserver/logs`  

### Login
Login through the web UI using a Fedora Account.  
https://accounts.fedoraproject.org  

To create the first administrator in a new database, from within the openqa-webserver container:    
`su geekotest; /usr/share/openqa/script/create_admin fake_admin`  

### Loading Tests  
Manually login through the web UI, then load the tests from inside the openqa-webserver container:  
```bash
cd /var/lib/openqa/share/tests/fedora/;
./fifloader.py --load  templates.fif.json templates-updates.fif.json;
```
Reload the tests:  
```bash
cd /var/lib/openqa/share/tests/fedora/;
su geekotest -c "git pull";
./fifloader.py --load -u  templates.fif.json templates-updates.fif.json
```
# The openqa-reverse-proxy  

Use the reverse-proxy container to expose standard HTTP and HTTPS ports.  It is the only container that needs to be run as root.  It's not necessary to run this container if you're running this locally or without ssl/tls certificates and can use non-privileged ports instead.  

### Generating Certificates

If all certificate configurations are removed from the config files, then mod_md will fetch certificates from the  MDCertificateAuthority as specified in openqa-proxy-ssl.conf.
If successful then `/home/fedora/openqa-containers/openqa-reverse-proxy/log/error_log` should say:  
```
AH10085: Init: openqa.fedorainfracloud.org:443 will respond with '503 Service Unavailable' for now. There are no SSL certificates configured and no other module contributed any.
AH00489: Apache/2.4.58 (Fedora Linux) OpenSSL/3.0.9 configured -- resuming normal operations
AH00094: Command line: 'httpd -D SSL'
AH10059: The Managed Domain openqa.fedorainfracloud.org has been setup and changes will be activated on next (graceful) server restart.

```
Kill the httpd process and restart the server:  
`httpd -DSSL`  

Error log should say:  
```
AH00489: Apache/2.4.58 (Fedora Linux) OpenSSL/3.0.9 configured -- resuming normal operations
```
Remove old symlinks:
```
rm /etc/httpd/conf.d/privkey.pem;
 rm /etc/httpd/conf.d/pubcert.pem;
```
Copy the new certificates into the config directory within the openqa-reverse-proxy container:  
```
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/privkey.pem /etc/httpd/conf.d/privkey.pem;
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/pubcert.pem /etc/httpd/conf.d/pubcert.pem;
```
Also copy the new certificates into the config directory so that they will be available to the host when the container stops:  
```
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/privkey.pem /conf/privkey.pem;
cp /var/lib/httpd/md/domains/openqa.fedorainfracloud.org/pubcert.pem /conf/pubcert.pem;
```

### Reverse Proxy Configuration
Makes copies of the configuration templates:  
```
cp /home/fedora/openqa-containers/openqa-reverse-proxy/conf/openqa-proxy.conf.template /home/fedora/openqa-containers/openqa-reverse-proxy/conf/openqa-proxy.conf;
cp /home/fedora/openqa-containers/openqa-reverse-proxy/conf/openqa-proxy-ssl.conf.template /home/fedora/openqa-containers/openqa-reverse-proxy/conf/openqa-proxy-ssl.conf;
```
* Configure the ServerName to the public ip of the host, if the ServerName isn't `openqa.fedorainfracloud.org`     
* Configure all of the rewrite and proxy rules to pass traffic to the private ip of the host `hostname -I`  
* If applicable, place the private ssl/tls certificate key into `/home/fedora/openqa-containers/openqa-reverse-proxy/conf/`.  Otherwise local certificates will be generated and used.    
  >Note: check and change the SELinux context of of keys if necessary
```
sudo chcon -t container_file_t  /home/fedora/openqa-containers/openqa-reverse-proxy/conf/privkey.pem;
sudo chcon -t container_file_t  /home/fedora/openqa-containers/openqa-reverse-proxy/conf/pubcert.pem;
ls -laZ /home/fedora/openqa-containers/openqa-reverse-proxy/conf/;
```

### Start the openqa-reverse-proxy as a service
.
Pull the apache server container:  
`sudo podman pull quay.io/fedora/httpd-24:latest`  

Start the service:  
```
sudo cp /home/fedora/openqa-containers/openqa-reverse-proxy/openqa-reverse-proxy.service /etc/systemd/system/;
sudo cp /home/fedora/openqa-containers/openqa-reverse-proxy/start-openqa-reverse-proxy.sh /usr/bin/;
sudo systemctl daemon-reload;
sudo systemctl start openqa-reverse-proxy.service;
```
Verify:  
`journalctl -f`  
`curl localhost`  
 Logs: `/home/fedora/openqa-containers/openqa-reverse-proxy/logs`  

# The openqa-consumer 

The openqa-consumer uses fedora-messaging to listen for new builds on the public fedora messaging service and schedules tests for those builds using fedora-openqa.  

[fedora-messaging](https://fedora-messaging.readthedocs.io/en/stable/)  
[fedora-openqa](https://pagure.io/fedora-qa/fedora_openqa)  

### Host Directories for Consumer
Create sure these subdirectories on the host in `openqa-consumer/`:    
```
mkdir -p /home/fedora/openqa-containers/openqa-consumer/fedora-messaging-logs;
mkdir -p /home/fedora/openqa-containers/openqa-consumer/fedora-openqa;
```

### Consumer Configuration

Make local copies of the config files:  
```
cp /home/fedora/openqa-containers/openqa-consumer/conf/client.conf.template /home/fedora/openqa-containers/openqa-consumer/conf/client.conf;
cp /home/fedora/openqa-containers/openqa-consumer/conf/fedora_openqa_scheduler.toml.template /home/fedora/openqa-containers/openqa-consumer/conf/fedora_openqa_scheduler.toml;
```

* `client.conf` needs the openqa-webserver plus api keys/secrets. This will authorize `fedora-openqa.py` to schedule tests.
* `fedora_openqa_scheduler.toml` also needs the `openqa_hostname` to be set to webserver ip if not using the default `openqa.fedorainfracloud.org`.  It's not necessary to change the queue ids, because these will be configured by `/init_openqa_consumer.sh` each time the consumer is run.
 
### Building openqa-consumer  
`/home/fedora/openqa-containers/openqa-consumer/build-consumer-image.sh`    

### Start the consumer locally
Run the ExecStart command available in the `openqa-consumer.service` config.  
> Note add to the podman run command the --detach or --tty option depending on whether you want to see the standard output
> Note define `USE_HTTPS=false` if the webserver does not have valid certificates

### Start the consumer as a service
```bash
sudo cp /home/fedora/openqa-containers/openqa-consumer/openqa-consumer.service /etc/systemd/system/;
sudo systemctl daemon-reload;
sudo systemctl start openqa-consumer;
```
Verify:
`journalctl -f`  
Logs: `/home/fedora/openqa-containers/openqa-consumer/fedora-messaging-logs`  

### Scheduling Tests

The openqa-consumer container will schedule tests automatically.  To schedule tests manually get a BUILDURL from the "Settings" tab of any test by clicking through the test's coloured dot [https://openqa.fedoraproject.org/](https://openqa.fedoraproject.org/):   

```bash
podman exec -it openqa-consumer /bin/bash
source /venv/bin/activate
fedora-openqa fcosbuild -f  https://builds.coreos.fedoraproject.org/prod/streams/testing-devel/builds/39.20240401.20.0/x86_64
fedora-openqa compose -f https://odcs.fedoraproject.org/composes/odcs-29778
fedora-openqa compose -f https://kojipkgs.fedoraproject.org/compose/rawhide/Fedora-Rawhide-20240401.n.0/compose
fedora-openqa update -f  FEDORA-2024-937be154d8
```
Alternatively, tests can also be schduled manually with `openqa-cli`, but using this tool requires a manual check of the variables expected by the tests as set out in `os-autoinst-distri-fedora/templates.fif.jsontemplates.fif.json`.  
For example, these commands schedule two tests that must be run in parallel:  

```bash
openqa-cli api -X POST isos \
ARCH=x86_64 \
BUILD=Fedora-Rawhide-20240206.n.0 \
UP1REL=39 \
DISTRI=fedora \
FLAVOR=universal \
TEST=upgrade_server_domain_controller \
VERSION=Rawhide

openqa-cli api -X POST isos \
ARCH=x86_64 \
BUILD=Fedora-Rawhide-20240206.n.0 \
UP1REL=39 \
DISTRI=fedora \
FLAVOR=universal \
TEST=upgrade_realmd_client \
VERSION=Rawhide
```

Use openqa-cli to cancel jobs:  
```bash
for JOB_ID in {226..342}; do openqa-cli api -X POST jobs/$JOB_ID/cancel; done
```

# The openqa-worker

### Host Directories for Worker
The openqa-worker container shares this directory with its host:  

* `tests/`: The full [os-autoinst-distri-fedora](https://pagure.io/fedora-qa/os-autoinst-distri-fedora) repository.
  
### Worker Configuration    
```
cp /home/fedora/openqa-containers/openqa-worker/conf/client.conf.template /home/fedora/openqa-containers/openqa-worker/conf/client.conf;
cp /home/fedora/openqa-containers/openqa-worker/conf/workers.ini.template /home/fedora/openqa-containers/openqa-worker/conf/workers.ini;
```
* In `client.conf` and fill in host and api keys/secrets.
* In  `workers.ini` and  fill in these values:  

|                            workers.ini    |    |
|----------------------------------------------------------------|---------------------------------|
| `HOST = http://172.31.1.1`      | The openqa-webserver host. It's wrong to use `localhost` since this is the container's localhost.   Add port `8080` if not using openqa-reverse-proxy.    |
| `WORKER_HOSTNAME = 172.31.1.1`        | For developer mode: the worker's location for receiving livelog. Don't use `localhost` |
| `AUTOINST_URL_HOSTNAME = 172.31.1.1`   | For logging: the worker's location for receiving qemu logs. This is only important for parallel tests. |


### Building the Openqa Worker
To build the openqa worker image:  
`cd /home/fedora/openqa-containers/openqa-worker/;`
`./build-worker-image.sh`  

### Start workers locally

The script `./start-openqa-worker.sh` will kill any existing workers and then start ten new workers by default.  
Change the default behaviour by defining values on the command line e.g.

|                           Example    |    |
|----------------------------------------------------------------|---------------------------------|
| `KEEP_EXISTING_WORKERS=yes NUMBER_OF_WORKERS=3 ./start-openqa-worker.sh`  | Run three more workers without killing the existing workers.         |
| `NUMBER_OF_WORKERS=0 ./start-openqa-worker.sh`    | Stop all existing workers.         |


### Start the openqa-worker service

openqa-worker service runs as `fedora` user so make sure that the user will survive closing the session:  
`sudo loginctl enable-linger fedora`  

First set up, but don't start, the `openqa-worker.timer` to restart the openqa-worker.service workers every 12 hours to avoid filling up the disk with their asset caches.    

```bash
sudo cp /home/fedora/openqa-containers/openqa-worker/openqa-worker.timer /usr/lib/systemd/system/openqa-worker.timer;
sudo rm -rf /etc/systemd/system/timers.target.wants/openqa-worker.timer;
sudo ln -s /usr/lib/systemd/system/openqa-worker.timer /etc/systemd/system/timers.target.wants/;
```

Next set up, but don't start, the `openqa-worker.service`:      
```bash
sudo cp /home/fedora/openqa-containers/openqa-worker/openqa-worker.service /etc/systemd/system/;
sudo cp /home/fedora/openqa-containers/openqa-worker/start-openqa-worker.sh /usr/bin/start-openqa-worker.sh;
sudo systemctl daemon-reload;
```
Finally, start the timer followed by the workers:  
```bash
sudo systemctl start openqa-worker.timer;
sudo systemctl start openqa-worker;
```
 
The `openqa-worker.service` will exit, but verify the workers and their ports with `podman ps -a`.  
See also `journalctl -f` and `sudo systemctl status openqa-worker` and `systemctl list-timers --all;` .    


