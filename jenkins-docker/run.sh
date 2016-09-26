#!/bin/bash
docker run -e JAVA_OPTS=-Duser.timezone=Asia/Jerusalem -d -p 8080:8080 -p 50000:50000 --volume `pwd`/../jenkins_home:/var/jenkins_home --volume `pwd`/../workspaces:/var/workspaces --volume /home/${USER}/.ssh:/home/jenkins/.ssh  --volume `pwd`/../m2:/home/jenkins/.m2 --volume `pwd`/../spark:/home/jenkins/spark --volume `pwd`/../scala:/home/jenkins/scala -e SCALA_HOME=/home/jenkins/scala/scala-latest -e SPARK_DIST=/home/jenkins/spark/spark.tgz --name build-jenkins xap/jenkins

