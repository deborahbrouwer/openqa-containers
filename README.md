
## Table of Contents

- [About](#about)
- [The openqa-webserver](#The-openqa-webserver)
    - [Host Directories for Webserver](#host-directories-for-webserver)
    - [Web Configuration](#web-configuration)
    - [Building openqa-webserver](#building-openqa-webserver)
    - [Start the openqa-webserver locally](#start-the-openqa-webserver-locally)
    - [Start the openqa-webserver as a service](#start-the-openqa-webserver-as-a-service)
    - [Login](#login)
    - [Loading Tests](#loading-tests)
- [The openqa-database](#The-openqa-database) 
- [The openqa-consumer](#The-openqa-consumer)  
    - [Host Directories for Consumer](#host-directories-for-consumer)
    - [Consumer Configuration](#consumer-configuration)
    - [Building openqa-consumer](#building-openqa-webserver)
    - [Start the consumer locally](#start-the-container-locally)
    - [Start the consumer as a service](#start-the-container-as-a-service)
    - [Scheduling Tests Manually](#scheduling-tests-manually)
- [The openqa-worker](#The-openqa-worker)
    - [Worker Configuration](#worker-configuration)
    - [Running workers](#running-workers)
    - [Stopping workers](#stopping-workers)

# About  
This repository contains scripts to build and run a containerized deployment of [openQA](https://github.com/os-autoinst).  The containers are specifically designed to leverage cloud resources and are customized to support [Fedora](https://fedoraproject.org/wiki/OpenQA) release and update testing. 

# The openqa-webserver  

The openqa-webserver container runs an apache web server on port 8080.  It displays the live test results in a web browser and is also responsible for scheduling tests and the workers to run them; communicating with workers via REST API calls; and enabling interactive editing of tests and needles through the livehandler. The openqa-webserver acts a reverse proxy so that all communications with workers are routed to it through a single port.  

### Host Directories for Webserver
Several directories are kept on the host and are bound into the openqa-webserver container when it runs.  Make sure these directories exist:
`cd openqa-webserver; mkdir -p tests data hdd iso; cd ..`

* `tests/`: the full [os-autoinst-distri-fedora](https://pagure.io/fedora-qa/os-autoinst-distri-fedora) repository where all the Fedora tests and needles reside. When the container runs, the script `init_openqa_web.sh` will either pull the full directory or just update it so that the tests are always up-to-date.  
* `data/`: the PostgreSQL database where login information as well as test scheduling and results are stored
* `hdd/`: holds OS images for testing.  Sometimes the images will be downloaded by the test from  `fedoraproject.org` but, in other cases, the images need to be generated on the host using Fedora's [createhdds](https://pagure.io/fedora-qa/createhdds).  If the host machine isn't itself running Fedora, then `createhdds` can't be run and some, but not all, of the tests will fail to execute.  
  Host packages necessary to run createhdds:
  `sudo dnf install -y python3-libguestfs  libvirt-devel virt-install fedfind vim git`
  Helper script to create images for hdd directory:
  `./run_createhdds.sh`  
* `iso/`: holds iso files for testing.
  
### Web Configuration    
Make a copy of the client.conf.template and fill in host and api keys/secrets.  
`cp openqa-webserver/conf/client.conf.template openqa-webserver/conf/client.conf`  

### Building Openqa Webserver
`openqa-webserver/build-webserver-image.sh`  

### Start the openqa-webserver locally
```bash
SRV='/home/fedora/openqa-containers/openqa-webserver';
podman run --rm -it --name openqa-webserver \
	-p 8080:80 -p 1443:443 \
	--network=slirp4netns \
	-v ${SRV}/hdd:/var/lib/openqa/share/factory/hdd:z \
	-v ${SRV}/iso:/var/lib/openqa/share/factory/iso:z \
	-v ${SRV}/data:/var/lib/pgsql/data/:z \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/init_openqa_web.sh:/init_openqa_web.sh:z \
	localhost/openqa:latest /init_openqa_web.sh
```
And stop it with:
`/usr/bin/podman exec -it openqa-webserver /bin/bash -c "pkill -f openqa-webui-daemon"`  

### Start the openqa-webserver as a service
```
sudo cp openqa-webserver.service /etc/systemd/system/
sudo loginctl enable-linger fedora
sudo systemctl daemon-reload
sudo systemctl start openqa-webserver
```

### Login
Login through the web UI using your Fedora Account.  
https://accounts.fedoraproject.org  

Initially when you login to the web UI, you are just a `user` without any privileges.  
The administrator can promote you to `operator` using the administrator's menu in the web UI.  An operator can run and control the tests.  
There can only be one administrator.  To create the first administrator in a new database, from within the web UI container:    
`su geekotest; /usr/share/openqa/script/create_admin fake_admin`  

### Loading Tests  
```bash
/usr/bin/podman exec -it openqa-webserver sh -c 'cd /var/lib/openqa/share/tests/fedora/;
./fifloader.py --load  templates.fif.json templates-updates.fif.json'
```
# The openqa-database

# The openqa-consumer 

The openqa-consumer uses fedora-messaging to listen for new builds on the public fedora messaging service and schedules tests for those builds using fedora-openqa.  

[fedora-messaging](https://fedora-messaging.readthedocs.io/en/stable/)  
[fedora-openqa](https://pagure.io/fedora-qa/fedora_openqa)  

### Host Directories for Consumer
Several directories are kept on the host and are bound into the openqa-consumer container when it runs.  Make sure these directories exist:  
`cd openqa-consumer; mkdir -p fedora-messaging-logs fedora-openqa`

### Consumer Configuration

Make a copy of the client.conf.template and fill in host and api keys/secrets.  
`cp openqa-consumer/conf/client.conf.template openqa-webserver/conf/client.conf`

|     client.conf     |    |
|---------------------|---------------------------------|
| `[172.31.1.1:8080]` | Authorize `fedora-openqa.py` to schedule tests. It's wrong to use `localhost` since this is the container's localhost.      |  


* Make a copy of `fedora_openqa_scheduler.toml.template`  
`cp openqa-consumer/conf/fedora_openqa_scheduler.toml.template openqa-webserver/conf/fedora_openqa_scheduler.toml`   

### Building openqa-consumer  
`openqa-consumer/build-consumer-image.sh`    

### Start the consumer locally
```bash
SRV='/home/fedora/openqa-containers/openqa-consumer';
/usr/bin/podman run --rm -id --name openqa-consumer \
	-v ${SRV}/conf:/conf/:z \
	-v ${SRV}/fedora-openqa:/fedora-openqa/:z \
	-v ${SRV}/fedora-messaging-logs:/fedora-messaging-logs/:z \
	-v ${SRV}/init_openqa_consumer.sh:/init_openqa_consumer.sh:z \
	localhost/openqa-consumer:latest /init_openqa_consumer.sh
```
Stop it manually:
```bash
/usr/bin/podman exec -it openqa-consumer /bin/bash -c "pkill -f fedora-messaging"
```

### Start the consumer as a service
```bash
sudo cp openqa-consumer.service /etc/systemd/system/
sudo loginctl enable-linger fedora
sudo systemctl daemon-reload
sudo systemctl start openqa-consumer
```

### Scheduling Tests

The openqa-consumer container will schedule tests automatically.  To schedule tests manually get a BUILDURL from: 
[https://openqa.fedoraproject.org/](https://openqa.fedoraproject.org/):   

```bash
podman exec -it openqa-consumer /bin/bash
source /venv/bin/activate
fedora-openqa fcosbuild -f  https://builds.coreos.fedoraproject.org/prod/streams/testing-devel/builds/39.20240401.20.0/x86_64
fedora-openqa compose -f https://odcs.fedoraproject.org/composes/odcs-29778
fedora-openqa compose -f https://kojipkgs.fedoraproject.org/compose/rawhide/Fedora-Rawhide-20240401.n.0/compose
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

# The worker container

### Worker Configuration    
|                           client.conf    |    |
|----------------------------------------------------------------|---------------------------------|
|`[172.31.1.1]`                                | The openqa-webserver host. Authorizes workers to carry out tests.      |

|                            workers.ini    |    |
|----------------------------------------------------------------|---------------------------------|
| `HOST = http://172.31.1.1:8080`                                | The openqa-webserver host. It's wrong to use `localhost` since this is the container's localhost.       |
| `WORKER_HOSTNAME = 172.31.1.1`                                 | For developer mode: the worker's location for receiving livelog. |
| `AUTOINST_URL_HOSTNAME = 172.31.1.1`                           | For logging: the worker's location for receiving qemu logs.   |


### Running workers     
For example, this command runs three workers:  
`./openqa_worker.sh -n 3` 

If a test needs a specific `WORKER_CLASS` set the worker class like this:  
`./openqa_worker.sh -n2 -c qemu_x86_64,vde_Fedora-CoreOS-41.20240302.91.0`  

There are options for using local repositories for debugging, e.g.:  
`./openqa_worker.sh -n2 -c qemu_x86_64,vde_Fedora-CoreOS-41.20240305.91.0 -g ../../os-autoinst`  

### Stopping workers     
`./openqa_worker.sh -n 0`  
>The workers need to tell the openqa-webserver that they are stopping and will no longer be available to accept tests.  If the workers are not stopped gracefully, the openqa-webserver will slow down substantially as it continues to send tests to unavailable workers.  


