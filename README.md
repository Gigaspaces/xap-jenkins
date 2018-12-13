# XAP builder on docker

#### This folder contains

1. jenkins-docker -- a directory with docker file and scrip to build and to run xap image that run docker with xap jobs.
2. jenkins_home -- the jenkins configuration that should mounted to the jenkins images.
3. `.gitignore` file that ignore files in docker_home that should not committed to git (passwords, old run ,logs, etc).
4. This readme file that explain how to build the container and run it.

## Build the image.

From the `jenkins-docker` folder run ./build.sh
  
## Run the image.
For the first run you will have to create empty folders that will contains the build files.

1. Create an`m2` directory in the `xap-jenkins` folder, this folder will be mount in the container to /home/jenkins/.m2
2. Create a `workspaces`  directory in the `xap-jenkins` folder, this folder will be mount in the container to /var/workspaces and will be used as directory where all the jobs workspaces will be created.
I you don't do this, the folders will be created with root user. In this case, just chown them to the host's user.
3. Create a keypair for this user `ssh-keygen -t rsa -b 4096 -C "xap-builder@gigaspaces.com"` and upload the public key to github as xap-dev (https://github.com/settings/keys) the folder ~/.ssh will be mounted in the container to /home/jenkins/.ssh
4. Run the script `run.sh` from the `jenkins-docker` folder.
5. login to jenkins with barak:barak and update the users remove the users you do not need.
6.


## Configuration

### SSH to hercules and imc-srv server(s)

run `ssh-copy-id user@host` on each host/server that you want to ssh without password.
This will copy the ssh public key to the remote machine.

### Maven files

create settings.xml file in xap-jenkins/m2/ folder


### Email

Under "E-mail Notification" and "Extended E-mail Notification" sections (also click advanced)

smpt server: smtp.gmail.com
port: 465
Use SSL: checked
username: newman@gigaspaces.com
password: ***


		
### Extended E-mail Notification

Default content: `${SCRIPT, template="xap-groovy-html.template"}`






 
