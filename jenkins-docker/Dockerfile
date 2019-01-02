FROM ubuntu 

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt-get update && apt-get install -y curl zip

# Install Java.

RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:webupd8team/java -y
RUN add-apt-repository ppa:git-core/ppa -y

RUN apt-get update --fix-missing


RUN apt-get install  -y git

RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections

RUN apt-get install -y oracle-java8-installer ca-certificates

RUN apt-get install -y sshpass

RUN apt-get install -y bzip2

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle 

# && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000


# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "/home/${user}" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home
VOLUME /home/${user}/.ssh
VOLUME /home/${user}/.m2
VOLUME /var/workspaces
VOLUME /home/${user}/.m2_release
VOLUME /home/${user}/.m2_release_xap
VOLUME /home/${user}/xap_scripts


# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.32.1}
ARG JENKINS_SHA
ENV JENKINS_SHA ${JENKINS_SHA:-1b65dc498ba7ab1f5cce64200b920a8716d90834}


# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins.sh /usr/local/bin/jenkins.sh

ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh

USER root
RUN apt-get -y install wget
RUN wget --no-verbose -O /tmp/apache-maven-3.3.9.tar.gz \
    http://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz

# stop building if md5sum does not match
RUN echo "516923b3955b6035ba6b0a5b031fbd8b  /tmp/apache-maven-3.3.9.tar.gz" | \
    md5sum -c

# add gspaces.com to resolv.conf
RUN echo "search gspaces.com" >> /etc/resolv.conf

# Install sbt
ENV SBT_VERSION 0.13.11
RUN \
  curl -L -o sbt-$SBT_VERSION.deb http://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  sbt sbtVersion && \
  echo >> /home/${user}/.bashrc && \
  echo 'export PATH=/usr/share/sbt-launcher-packaging/bin:$PATH' >> /home/${user}/.bashrc


# install in /opt/maven
RUN mkdir -p /opt/maven

RUN tar xzf /tmp/apache-maven-3.3.9.tar.gz --strip-components=1 \
    -C /opt/maven

RUN ln -s /opt/maven/bin/mvn /usr/local/bin
RUN rm -f /tmp/apache-maven-3.3.9.tar.gz

#install gcc 7
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update
RUN apt-get install gcc-7 g++-7 -y

#install make
RUN apt-get install build-essential -y

RUN apt-get install net-tools

RUN apt-get install python2.7 python-pip -y

RUN pip2 install -I ansible==2.2.1.0

RUN pip install requests
RUN pip install spotinst

# get node
RUN echo 'get node tar.gz'
RUN wget --no-verbose -O /tmp/node-v8.9.3-linux-x64.tar.gz \
    https://nodejs.org/dist/v8.9.3/node-v8.9.3-linux-x64.tar.gz

RUN mkdir /opt/node

# unpack node tar.gz
RUN echo 'unpacking node tar.gz' && \
    tar zxvf /tmp/node-v8.9.3-linux-x64.tar.gz --strip-components=1 \
    -C /opt/node && \
    rm -f /tmp/node-v8.9.3-linux-x64.tar.gz

RUN ln -s /opt/node/bin/node /usr/local/bin && ln -s /opt/node/bin/npm /usr/local/bin

RUN node --version && \
     npm --version

RUN echo 'installing helm' && \
 echo 'Current directory' && \
 pwd && \
 wget https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz && \
 tar -zxvf helm-v2.11.0-linux-amd64.tar.gz && \
 mv linux-amd64/helm /usr/local/bin/helm && \
 rm -rf linux-amd64 helm-v2.11.0-linux-amd64.tar.gz

USER ${user}

RUN helm init --client-only

RUN echo 'installing elm' && \
    mkdir /home/${user}/.npm-global && \
     npm config set prefix "/home/${user}/.npm-global"

ENV PATH=/home/${user}/.npm-global/bin:$PATH

RUN npm install -g elm@0.18.0

#RUN mkdir -p /var/jenkins_home/build/ssh
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt

COPY gitconfig /home/${user}/.gitconfig

