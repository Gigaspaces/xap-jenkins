#!/usr/bin/env bash
MODE="-d"
if [[ -n "$1" ]]; then
	if [[ "$1" == "-iii" ]]; then
		MODE=""
	else
		MODE="$1"
	fi
fi

WORKSPACES=`pwd`/../workspaces
if [[ ! -e "${WORKSPACES}" ]]; then
    mkdir -p ${WORKSPACES}
fi
M2=`pwd`/../m2
if [[ ! -e "${M2}" ]]; then
    mkdir -p ${M2}
fi

M2S=`pwd`/../m2s
if [[ ! -e "${M2S}" ]]; then
    mkdir -p ${M2S}
fi

#NEWMAN_SERVER_IP is the IP of the host machine
NEWMAN_SERVER_IP=$(hostname -I | awk '{ print $1 }')

docker run -e JAVA_OPTS=-Duser.timezone=Asia/Jerusalem ${MODE} -p 8080:8080 -p 50000:50000 --rm \
    --volume `pwd`/../jenkins_home:/var/jenkins_home \
    --volume ${WORKSPACES}:/var/workspaces \
    --volume ${M2S}:/var/m2s \
    --volume `pwd`/../ssh:/home/jenkins/.ssh \
    --volume ${M2}:/home/jenkins/.m2 \
    --volume `pwd`/../m2_release:/home/jenkins/.m2_release \
    --volume `pwd`/../m2_release_xap:/home/jenkins/.m2_release_xap \
    --volume `pwd`/../m2_ie_release:/home/jenkins/.m2_ie_release \
    --volume `pwd`/../xap_scripts:/home/jenkins/xap_scripts  \
    --volume `pwd`/../ie_scripts:/home/jenkins/ie_scripts \
    --volume `pwd`/../spark:/home/jenkins/spark \
    --volume `pwd`/../scala:/home/jenkins/scala \
    -e SCALA_HOME=/home/jenkins/scala/scala-latest \
    -e SPARK_DIST=/home/jenkins/spark/spark.tgz \
    --add-host "newman-server:${NEWMAN_SERVER_IP}" \
    --name build-jenkins xap/jenkins
