haemosphere README (Documentation for haemosphere development and maintenance)

Last updated 2018-08-07 by Jarny

Overview
--------
Haemosphere is a pyramid application designed for gene expression dataset analyses. It was first developed as "Guide" by Jarny Choi at WEHI, then later re-branded to Haemosphere, with Nick Seidenman also working on it while he worked at WEHI. This document records some details of development and maintenance not found elsewhere. ~/projects/Notes.txt on my current laptop also has some notes I've made with regard to various program installations.

There are two separate servers of Haemosphere, referred as "private" and "public". The private server is accessible only to WEHI and CSL computers (and some CSIRO collaborators' computers), and contain private datasets which are now mainly CSL derived datasets. The public server can be accessed from any computer and contains a smaller subset of datasets, all published (including haemopedia). Both servers are hosted at WEHI machines (Jakub Szarlet knows about the server setup).


Servers
-------
private server is hosted at vcpubhl01.wehi.edu.au. Username guideadm owns all the relevant files. There is a conda environment called "heamosphere" set to store all the relevant code. Production code is in /data/www/haemosphere.
Apache config files: /etc/httpd/conf.d/haemosphere.conf
Apache log files: /var/log/httpd/

public server is hosted at vcpub-haemosphere-org.wehi.edu.au. Username haemosphere owns all the relevant files. There is a conda environment called "heamosphere" set to store all the relevant code. Production code is in /home/haemosphere/haemosphere.
Apache config files: /etc/httpd/conf.d/haemosphere.conf
Apache log files: /var/log/httpd/

On each server, there is a start_pyramid_server.py script which acts to start the server after checking to see if it's running or not. However, this script won't work on the private server, because it's running a newer version of pserve, which does not accept daemon mode used in the call inside the script. This needs to be fixed. Meanwhile the full command used for each server is:

private server:
```bash
> source activate haemosphere
> nohup pserve production-private.ini
```

public server:
```bash
> source activate haemosphere
> python /home/haemosphere/haemosphere/start_pyramid_server.py production-public.ini > /home/haemosphere/crontab.log
```

Cron is used to have this script running every 5 mins on the public server, so if the server crashes it can be restarted automatically. Note that PATH variable needs to be set on the cron job.


To restart the public server, first check that nobody might be using the server at that moment:
```bash
> tail data/access.log
```
Since we don't have a failover server, as soon as you kill the process the server will be down. So I at least check that there's been some time since last acess by looking at the log here. If not, I normally wait a bit.

Now kill server and then restart.
```bash
> ps -fu haemosphere
> kill xxxx (after finding the process number from ps command)
> python /home/haemosphere/haemosphere/start_pyramid_server.py production-public.ini > /home/haemosphere/crontab.log
```

Check that it's running OK. There is a very small chance that you may have run start_pyramid_server.py just after the cron job has automatically restarted the server. If that happened, that last command won't do anything anyway, as it first checks that it's running before starting it.


Version control
---------------
All haemosphere code and data are under git version control, and remotely held at bitbucket.org under username jarny.
There are separate git repositories of relevance:

- haemosphere: Repository for haemosphere code without the datasets.
private server: /data/www/haemosphere
public server: /home/haemosphere/haemosphere

- haemosphere-data-private: Repo for datasets used by the private server.
private server: /data/www/haemosphere/data

- haemosphere-data-public: Repo for datasets used by the public server.
public server: /home/haemosphere/haemosphere/data


Workflow for updating haemosphere code
-----------------------------
Workflow to update haemosphere code is the following:

1. Code change happens locally on development machine. Each type of change should be committed to the git repo, and each is recorded in CHANGES.txt file under a new version number. When a bunch of changes are ready to be released as a new version, date is recorded for the version number in CHANGES.txt and committed.

2. Run nosetests -s from haemosphere directory to run unit tests.

3. Push the latest commit to bitbucket:
```bash
    > git push
```
4. Go to each of private and public server and pull:
```bash
	> git pull
```
5. Check current server pid by ps then kill it (private server example):
```bash
	> ps -fu guideadm | grep log
	> kill 20342
```
6. Restart the server:
```bash
	> python /data/www/prod/haemosphere/start_pyramid_server.py production-private.ini > /data/home/guideadm/crontab.log
```

Workflow for creating/updating a haemosphere dataset
-----------------------------

A dataset in haemosphere consists of a single file in hdf format. For example, the hiltonlab-rnaseq-plus dataset on the private server points to hiltonlab-rnaseq-plus.1.5.h5, where 1.5 here denotes the version number of the dataset, which can be updated whenever the dataset changes (new samples added, or changed sample annotations, etc). Note that each hdf file actually consists of multiple objects referenced by different keys (eg. "counts", "tpm").

Hence creating a new dataset consists of creating a new hdf file with the correct keys and objects. See haemosphere/models/hsdataset.py for details of required keys and objects. Usually, I do this creation in a jupyter notebook and keep adding to the notebook for subsequent versions, thereby keeping the history of that dataset in the one file.

Note that dataset directory is under separate version control (read the version control section above). However if dataset upgrade is the only change in the version of haemosphere, remember to update CHANGES.txt file and also commit it, otherwise the users won't see the comment on the change when viewing the release notes.

User and group access for a dataset is controlled by placement of the hdf file in the correct directory and creating symbolic links. Example of hiltonlab-rnaseq-plus dataset which is private:

	File resides here
	
	> haemosphere/data/datasets/F0r3sT/PRIVATE/USERS/hilton/hiltonlab-rnaseq-plus.1.5.h5
	
	And is accessible to all users in HiltonLab group, because of this symlink under haemosphere/data/datasets/F0r3sT/PRIVATE/GROUPS/HiltonLab/
	
	> hiltonlab-rnaseq-plus.1.5.h5 -> ../../USERS/hilton/hiltonlab-rnaseq-plus.1.5.h5

Public datasets are simpler - just place them under haemosphere/data/datasets/F0r3sT/PUBLIC.

After a dataset change, go into the .ini config file and increment the number here:
haemosphere.datasetAttributesRebuildVersion = 1
This ensures that dataset attributes which are cached under request.session are rebuilt and the change reflected.

Installing Locally
------------------

### Initializing public data

The public haemosphere dataset has been made a submodule of this git repository. To get the repo with the data:

```bash
	git clone git@bitbucket.org:jarny/haemosphere.git -b docker --recursive
```

This will switch to the `docker` branch and update the public dataset. If you've run `git clone` without the `-b` and `--recursive` flags, make sure to change to the correct branch and update the submodule to get the public data. Do this by:

```bash
	git checkout docker  # switches to the docker branch
	git submodule init   # initializes submodules
	git submodule update # pulls the submodules
```

Which will download the public data to `haemosphere-public-data` which can be used by the server.

### Docker setup

Haemosphere is now containerized to make it easier to deploy. 
This will require Docker installed. See the [official instructions for your OS](https://docs.docker.com/engine/install/).
You will either need sudo priveledges or to be added to the `docker` group on the machine to use Docker.

To run the container:

```bash
	docker compose up -d
```

This parses the `docker-compose.yml` and starts haemosphere using the public data. `-d` tells Docker compose to start the service in "detached" mode.
By default, the docker compose setup will map the 6544 port on the host to 6544 inside the container. 
It will also mount `config` in this repo to `/config` in the container; and `haemosphere-public-data` in this repo, to `/data` inside the container.

Inspect the logs of the container with

```bash
	docker logs haemosphere-container
```

To shut down the container, inside this repo, run

```bash
	docker compose down
```

#### Changing to production

In the `docker-compose.yml` file, uncomment

```yml
	- "8090:8090"
```

And if preferred, remove or comment out the 6544 port mapping. Then, change the command to make use of the appopriate production config:

```yml
	command: pserver /config/production-public.ini
```

If you wish to change the dataset being used, change the volume being mounted.

```yml
	./my-other-data:/data
```

Changes to `docker-compose.yml` require a shutdown and start:

```bash
	docker compose down
	docker compose up
```

Changes to the config file or dataset contents should only need a restart:

```bash
	docker compose restart
```

#### Developing with Docker

Updating the dataset contents shouldn't require a restart of the containers - although a live update might cause active users' queries to fail. 
To update haemosphere itself, perform the necessary changes to the haemosphere package (and/or dependencies in `environment.yml` or `requirements.txt`) and rebuild
the container:

```bash
	docker build -t edoyango/haemosphere .
```

Which will rebuild the docker container using the `Dockerfile` file in this repo. See the recipe for details on how this container was built.
	
### Apptainer setup

In case you wish to test or develop in a shared environment where docker is not available, you can also use apptainer.
If working on an HPC facility, Apptainer or Singularity should already be installed. Otherwise, see the [official installation instruction](https://apptainer.org/docs/admin/main/installation.html) (which will need `sudo`).
Get the container by

```bash
    apptainer pull docker://edoyango/haemosphere:latest
```

which will create the `haemosphere_latest.sif` image. Run the image by

```bash
    apptainer run \
	    -B $(pwd -P)/config:/config \ 
	    -B $(pwd -P)/haemosphere-data-public:/data \
		haemosphere_latest.sif pserve /config/development.ini
```

and the container will be running on the host on port 6544, as specified in the config file.

### Manual setup

If you want to install Haemosphere locally for development/testing purposes,
the easiest way is probably using Miniconda for environment management. Thus I
suggest the following steps:

1.  Download and install Miniconda (https://docs.conda.io/en/latest/miniconda.html#installing)

2.  Clone this repository.

3.  Change to the repository directory and run
        
```bash
	conda env create -f environment.yml
	source activate haemosphere
	pip install -r requirements.txt
	Rscript r_packages.r
```

This will first create a conda environment named `haemosphere` (conda will create a subdirectory under miniconda3/envs/ where all the packages listed in environment.yml will go).
the `source activate` command activates this new environmet, so all commands will try to run from anaconda/envs/haemosphere/bin first, and all installations will go into this environment.
And finally, `pip install` is used to install packages that are not available via conda.
The `Rscript` command runs the `r_packages.r` script, which contains commands needed to install prerequisite limma, edgeR packages.
The package versions specified in the `environment.yml`, `requirements.txt`, and `r_packages.r` have been checked to work at the time of writing.
If you encounter errors during this stage, it may be due to unavailability of certain versions of packages. Useful commands are (using pyramid package as an example here):

```bash
    conda list | grep pyramid	(shows all 'pyramid' packages across all envs)
    conda info pyramid	(shows all available versions of pyramid package)
    conda remove --name haemosphere --all	(removes the entire environment so you can start again)
    conda remove pyramid	(to uninstall the package)
    conda install pyramid	(to install the package from conda)
    pip install pyramid	(to install the package from pip, for those packages not available in conda)
```

If the `environment.yml`, `requirements.txt`, or `r_packages.r` becomes out-of-date due to packages being available, an alternative version of a package needs to found and these files should be updated to reflect this so that haemosphere can run without error in future.

4.  Run `pip install -e .` to install the haemosphere package.

5.  Update `config/development.ini` to reflect where the datasets and session data is supposed to be stored. For example, to use the public data initiated above, change the following lines:
	* `session.data_dir = /data/sessions/data` to `%(here)s/haemosphere-data-public/sessions/data`
	* `session.lock_dir = /data/sessions/lock` to `%(here)s/haemosphere-data-public/sessions/lock`
	* `haemosphere.model.users.datafile = /data/users.h5` to `%(here)s/haemosphere-data-public/users.h5`
	* `sqlalchemy.url = sqlite:////data/users.sqlite` to `sqlite:///%(here)s/haemosphere-data-public/users.sqlite`
	* `haemosphere.model.datasets.root = /data/datasets` to `%(here)s/haemosphere-data-public/datasets`
	* `haemosphere.model.grouppages = /data/grouppages` to `%(here)s/haemosphere-data-public/grouppages`
	* `sqlalchemy2.url = sqlite:////data/labsamples.sqlite` to `sqlite:///%(here)s/data/labsamples.sqlite`

6.  Run `pserve config/development.ini` to test that you can serve Haemosphere, and
    then run `nosetests` from the main directory to run unit and functional
    tests. From the browser you can view Haemosphere by going to `http://localhost:6544` or whatever the port is
    
Some notes based on problems encountered:
- Debug the dependency issues that will inevitably arise. One problem I've had is that there sometimes seems to be problems finding the HDF5 library when installing `PyTables`. You may need to set the `HDF5_DIR` environment variable to point to the directory of your `haemosphere` environment (i.e. a directory containing `lib` and `include` subdirectories, which contain the HDF5 files.)

- If you want to run jupyter notebook from within haemosphere env, run conda install jupyter first, as it isn't one of the required installations from environment.yml.


Bitbucket tips
------------------

Note that to make a repo writable by the haemosphere user on vcpub-haemosphere-org.wehi.edu.au, I had to add its public ssh key to the list of ssh keys under my bitbucket user settings. It doesn't work to add this key to the specific repo for writing.
